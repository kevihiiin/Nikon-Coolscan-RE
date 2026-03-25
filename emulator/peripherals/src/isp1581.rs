//! ISP1581 USB controller model.
//!
//! Memory-mapped at 0x600000-0x6000FF. 16-bit bus, little-endian.
//! The H8/3003 is big-endian, so firmware explicitly byte-swaps when reading/writing.
//!
//! Register map (ISP1581 datasheet Table 60):
//!   0x600000  Address (R/W) — USB device address + DEVEN bit
//!   0x600004  EndpointMaxPacketSize (R/W) — per-endpoint max packet size
//!   0x600008  EndpointType/IRQ Status (R/W) — context-dependent
//!   0x60000C  Mode (R/W) — bit 4 (SOFTCT) = soft connect
//!   0x600010  IntConfig (R/W) — interrupt configuration
//!   0x600014  IntEnable (R/W) — per-endpoint interrupt enables
//!   0x600016  DcHardwareConfiguration (R/W) — clock, analog settings
//!   0x600018  DcInterrupt (R/W) — global interrupt flags, write-back-clear
//!   0x60001C  DcBufferLength (R) — bytes in selected endpoint buffer
//!   0x60001E  DcBufferStatus (R) — endpoint buffer fill state
//!   0x600020  EP Data Port (R/W) — 16-bit, LE byte order
//!   0x600024  DMA Configuration (W) — DMA direction
//!   0x600028  ControlFunction (R/W) — CLBUF/VENDP/STATUS/STALL
//!   0x60002C  EP Control (W) — endpoint DMA mode
//!   0x600070  Chip ID (R) — returns 0x1581
//!   0x60007C  Unlock (R/W) — unlock device register
//!   0x600084  DMA Count (W) — transfer byte count

use std::collections::VecDeque;

/// ISP1581 interrupt register bits (at offset 0x18, DcInterrupt).
/// These are the global interrupt flags that the firmware polls.
pub const IRQ_EP_EVENT: u16 = 1 << 3;

/// DcInterrupt bit 12: "EP buffer available for TX".
/// The response manager at FW:0x013C8E uses BTST #4 on the high byte of
/// DcInterrupt (offset 0x18) to check this bit before data transfer.
/// Always set in our model since EP2 IN FIFO has unlimited capacity.
pub const IRQ_EP_TX_READY: u16 = 1 << 12;

/// DcInterrupt bit 15: "Host has received data" / "EP transfer complete".
/// The USB state update function at FW:0x014014 uses BTST #7 on the high byte
/// of DcInterrupt to check this bit after each packet write. Set by our model
/// after every EP Data Port write to signal instant host consumption.
pub const IRQ_EP_TX_COMPLETE: u16 = 1 << 15;

/// DcInterrupt bit 6: USB bus reset detected.
/// Set when USB host issues a bus reset. Firmware checks this in USB init.
pub const IRQ_BUS_RESET: u16 = 1 << 6;

/// DcInterrupt bit 0: VBUS detected (power present).
pub const IRQ_VBUS: u16 = 1 << 0;

/// DcInterrupt bit 5: USB suspend.
pub const IRQ_SUSPEND: u16 = 1 << 5;

/// DcInterrupt bit 8: High-speed status.
pub const IRQ_HIGH_SPEED: u16 = 1 << 8;

pub struct Isp1581 {
    /// Endpoint status register at 0x08 (per-endpoint events).
    pub ep_status: u16,
    /// Global interrupt register at 0x18 (DcInterrupt).
    /// Firmware polls this during data transfers.
    pub dc_interrupt: u16,
    /// Mode register at 0x0C.
    pub mode: u16,
    /// DMA config at 0x24 (written by firmware for DMA direction).
    pub dma_config: u16,
    /// EP index/count at 0x1C/0x22.
    pub ep_index: u16,
    /// EP control at 0x2C.
    pub ep_control: u16,
    /// DMA count at 0x84.
    pub dma_count: u16,

    /// EP1 OUT FIFO (host → device): CDB bytes arrive here.
    pub ep1_out_fifo: VecDeque<u8>,
    /// Last EP1 OUT injection size (for DcBufferLength reporting).
    pub ep1_last_inject_size: u16,
    /// EP2 IN FIFO (device → host): response bytes go here.
    pub ep2_in_fifo: VecDeque<u8>,

    /// Whether IRQ1 should be asserted to the CPU.
    pub irq_pending: bool,

    // --- Configuration registers (per ISP1581 datasheet Table 60) ---
    /// Address register at offset 0x00 (device address + DEVEN bit).
    pub address: u16,
    /// Endpoint Max Packet Size at offset 0x04.
    pub ep_max_packet_size: u16,
    /// Interrupt Configuration register at offset 0x10 (debug mode + polarity).
    pub interrupt_config: u16,
    /// Interrupt Enable register at offset 0x14 (per-endpoint interrupt enables).
    pub interrupt_enable: u16,
    /// DcHardwareConfiguration at offset 0x16 (clock, analog, etc.).
    pub hw_config: u16,
    /// Control Function register at offset 0x28 (CLBUF/VENDP/STATUS/STALL).
    pub control_function: u16,
    /// Unlock register at offset 0x7C.
    pub unlock: u16,
    /// Frame Number register at offset 0x74 (read-only, increments per SOF).
    pub frame_number: u16,

    /// Whether SOFTCT has transitioned from 0→1 (device became visible on bus).
    /// Used to simulate bus reset after soft-connect.
    pub bus_reset_pending: bool,
}

impl Isp1581 {
    pub fn new() -> Self {
        // Initialize with USB connected (SOFTCT bit in Mode register)
        // The firmware checks this to determine if USB is active.
        let mut isp = Self {
            ep_status: 0,
            dc_interrupt: 0,
            mode: 0,
            dma_config: 0,
            ep_index: 0,
            ep_control: 0,
            dma_count: 0,
            ep1_out_fifo: VecDeque::new(),
            ep1_last_inject_size: 0,
            ep2_in_fifo: VecDeque::new(),
            irq_pending: false,
            address: 0,
            ep_max_packet_size: 64,
            interrupt_config: 0,
            interrupt_enable: 0,
            hw_config: 0,
            control_function: 0,
            unlock: 0,
            frame_number: 0,
            bus_reset_pending: false,
        };
        // Set SOFTCT bit (bit 4) in Mode register to indicate USB connected.
        // Without this, firmware skips all USB processing.
        isp.mode = 0x0010; // SOFTCT = 1 (connected)
        isp
    }

    /// Read a register (called by memory bus for addresses 0x600000-0x6000FF).
    /// Address is the offset from 0x600000.
    /// Returns a 16-bit value (ISP1581 is 16-bit LE, but we return the native value;
    /// the memory bus handles byte-level access).
    pub fn read_word(&mut self, offset: u32) -> u16 {
        match offset {
            0x08 => {
                // DcEndpointStatus — per-endpoint event flags.
                self.ep_status
            }
            0x0C => self.mode,
            0x18 => {
                // DcInterrupt — global interrupt flags.
                // The firmware polls this during data transfers and USB state management.
                // After firmware reads, it writes back to clear the bits it handled.
                // Always include IRQ_EP_TX_READY (bit 12): the response manager at
                // FW:0x013C8E polls this to confirm EP2 IN buffer is available.
                // In our model the FIFO has unlimited capacity so it's always ready.
                self.dc_interrupt | IRQ_EP_TX_READY
            }
            0x1C => {
                // DcBufferLength — number of bytes in the selected endpoint buffer.
                // The response manager at FW:0x013D7E reads this after writing
                // EP Control (0x2C). If 0, it returns "not ready" and the caller loops.
                // Return 64 (max packet size for full-speed USB).
                64
            }
            0x1E => {
                // DcBufferStatus — endpoint buffer fill state.
                // Return 0 (all buffers empty/available for write).
                0
            }
            0x20 => {
                // EP Data Port: read 16-bit word from EP1 OUT FIFO (LE: low byte first)
                let fifo_len = self.ep1_out_fifo.len();
                if fifo_len < 2 {
                    log::warn!("ISP1581: EP1 OUT FIFO underrun ({} bytes available, 2 needed)", fifo_len);
                }
                let lo = self.ep1_out_fifo.pop_front().unwrap_or(0);
                let hi = self.ep1_out_fifo.pop_front().unwrap_or(0);
                let val = (hi as u16) << 8 | lo as u16;
                log::trace!("ISP1581: EP1 OUT read: lo=0x{:02X} hi=0x{:02X} val=0x{:04X} fifo_remaining={}",
                    lo, hi, val, self.ep1_out_fifo.len());
                val
            }
            0x00 => self.address,
            0x04 => self.ep_max_packet_size,
            0x10 => self.interrupt_config,
            0x14 => self.interrupt_enable,
            0x16 => self.hw_config,
            0x28 => self.control_function,
            0x70 => 0x1581, // Chip ID (ISP1581 datasheet Table 60: CHIPID[15:0])
            0x74 => self.frame_number,
            0x7C => self.unlock,
            _ => {
                log::trace!("ISP1581: unmodeled register read at offset 0x{:02X}", offset);
                0
            }
        }
    }

    /// Write a register.
    pub fn write_word(&mut self, offset: u32, val: u16) {
        match offset {
            0x08 => {
                // Write-back clears endpoint status bits
                self.ep_status &= !val;
                if self.ep_status == 0 && self.dc_interrupt == 0 {
                    self.irq_pending = false;
                }
            }
            0x0C => {
                let old_softct = self.mode & 0x0010;
                self.mode = val;
                let new_softct = val & 0x0010;
                // SOFTCT 0→1: device just became visible on USB bus.
                // Schedule a bus reset on next tick (USB host resets new devices).
                if old_softct == 0 && new_softct != 0 {
                    self.bus_reset_pending = true;
                    log::info!("ISP1581: SOFTCT asserted — bus reset pending");
                }
            }
            0x18 => {
                // Write-back clears DcInterrupt bits
                self.dc_interrupt &= !val;
                if self.dc_interrupt == 0 && self.ep_status == 0 {
                    self.irq_pending = false;
                }
            }
            0x1C => self.ep_index = val,
            0x20 => {
                // EP Data Port write: firmware writes to EP2 IN FIFO.
                // Firmware writes LE words: low byte in bits[7:0], high byte in bits[15:8]
                self.ep2_in_fifo.push_back(val as u8);         // Low byte
                self.ep2_in_fifo.push_back((val >> 8) as u8);  // High byte
                // Signal that the data was accepted and host has consumed it:
                // - Bit 3 (IRQ_EP_EVENT): endpoint event
                // - Bit 12 (IRQ_EP_TX_READY): buffer available for next write
                // - Bit 15 (IRQ_EP_TX_COMPLETE): host received data (FW:0x014014
                //   polls this via BTST #7 between packet writes)
                self.dc_interrupt |= IRQ_EP_EVENT | IRQ_EP_TX_READY | IRQ_EP_TX_COMPLETE;
            }
            0x00 => self.address = val,
            0x04 => self.ep_max_packet_size = val,
            0x10 => self.interrupt_config = val,
            0x14 => self.interrupt_enable = val,
            0x16 => self.hw_config = val,
            0x24 => self.dma_config = val,
            0x28 => {
                self.control_function = val;
                // CLBUF (bit 4): clear buffer — firmware writes 0x10 to reset EP buffers.
                // VENDP (bit 3): validate endpoint — signals end of data transfer.
                // We don't need to do anything for CLBUF/VENDP in our model since
                // FIFOs are always available.
            }
            0x2C => self.ep_control = val,
            0x7C => self.unlock = val,
            0x84 => self.dma_count = val,
            _ => {
                log::trace!("ISP1581: unmodeled register write at offset 0x{:02X} = 0x{:04X}", offset, val);
            }
        }
    }

    /// Simulate USB bus reset. Sets bus reset bit in DcInterrupt and
    /// prepares ISP1581 state for enumeration by the USB host.
    pub fn simulate_bus_reset(&mut self) {
        self.dc_interrupt |= IRQ_BUS_RESET | IRQ_VBUS;
        self.irq_pending = true;
        self.bus_reset_pending = false;
        log::info!("ISP1581: bus reset simulated (DcInterrupt=0x{:04X})", self.dc_interrupt);
    }

    /// Tick: called each instruction cycle. Handles deferred state transitions.
    pub fn tick(&mut self) {
        // After SOFTCT transitions 0→1, simulate bus reset on next tick.
        if self.bus_reset_pending {
            self.simulate_bus_reset();
        }
    }

    /// Inject data from host into EP1 OUT FIFO and assert IRQ.
    pub fn host_send_ep1(&mut self, data: &[u8]) {
        self.ep1_last_inject_size = data.len() as u16;
        for &b in data {
            self.ep1_out_fifo.push_back(b);
        }
        self.ep_status |= IRQ_EP_EVENT;
        self.dc_interrupt |= IRQ_EP_EVENT;
        self.irq_pending = true;
    }

    /// Read data from EP2 IN FIFO (host receives this).
    pub fn host_recv_ep2(&mut self, max_bytes: usize) -> Vec<u8> {
        let count = max_bytes.min(self.ep2_in_fifo.len());
        self.ep2_in_fifo.drain(..count).collect()
    }

    /// Check if EP2 IN has data ready for host.
    pub fn ep2_has_data(&self) -> bool {
        !self.ep2_in_fifo.is_empty()
    }

    /// Push raw bytes into EP2 IN FIFO (for intercepted data transfers).
    /// Unlike write_word(0x20), this adds bytes directly without LE word packing.
    pub fn ep2_push_bytes(&mut self, data: &[u8]) {
        for &b in data {
            self.ep2_in_fifo.push_back(b);
        }
    }

    /// Check IRQ pending flag (firmware must write-back to clear IRQ status).
    pub fn take_irq(&self) -> bool {
        self.irq_pending
    }
}

impl Default for Isp1581 {
    fn default() -> Self {
        Self::new()
    }
}

/// MmioDevice implementation for ISP1581.
/// The ISP1581 is 16-bit, so byte accesses are decomposed into word operations.
/// The firmware always accesses ISP1581 registers as 16-bit words.
/// Byte reads return the high or low byte of the word at the aligned address.
impl h8300h_core::memory::MmioDevice for Isp1581 {
    fn read_byte(&mut self, offset: u32) -> u8 {
        let word_offset = offset & !1;
        // Guard: byte reads on EP Data Port (0x20) would trigger FIFO pop side effects.
        // The firmware always uses word reads here; a byte read is likely a decoder bug.
        if word_offset == 0x20 {
            log::warn!("ISP1581: byte read on EP Data Port (offset 0x{:02X}) — returning 0 to avoid FIFO corruption", offset);
            return 0;
        }
        let word = Isp1581::read_word(self, word_offset);
        let byte = if offset & 1 == 0 { (word >> 8) as u8 } else { word as u8 };
        log::trace!("ISP1581 read_byte [0x{:02X}] = 0x{:02X} (word 0x{:04X})", offset, byte, word);
        byte
    }

    fn write_byte(&mut self, offset: u32, val: u8) {
        // ISP1581 writes are always 16-bit from firmware.
        // For byte writes, reconstruct the word.
        let word_offset = offset & !1;
        // Guard: byte write on EP Data Port would read_word (popping FIFO) as side effect
        if word_offset == 0x20 {
            log::warn!("ISP1581: byte write on EP Data Port (offset 0x{:02X}) — skipping to avoid FIFO corruption", offset);
            return;
        }
        let old_word = Isp1581::read_word(self, word_offset);
        let new_word = if offset & 1 == 0 {
            (old_word & 0x00FF) | ((val as u16) << 8)
        } else {
            (old_word & 0xFF00) | val as u16
        };
        Isp1581::write_word(self, word_offset, new_word);
    }

    fn read_word(&mut self, offset: u32) -> u16 {
        let val = Isp1581::read_word(self, offset);
        if offset != 0x20 || val != 0 { // Don't spam Data Port zero reads
            log::trace!("ISP1581 read  [0x{:02X}] = 0x{:04X}", offset, val);
        }
        val
    }

    fn write_word(&mut self, offset: u32, val: u16) {
        log::trace!("ISP1581 write [0x{:02X}] = 0x{:04X}", offset, val);
        Isp1581::write_word(self, offset, val);
    }

    fn inject_host_data(&mut self, data: &[u8]) -> bool {
        self.host_send_ep1(data);
        true // IRQ should fire
    }

    fn drain_device_data(&mut self, max: usize) -> Vec<u8> {
        self.host_recv_ep2(max)
    }

    fn drain_host_data(&mut self, max: usize) -> Vec<u8> {
        let count = max.min(self.ep1_out_fifo.len());
        self.ep1_out_fifo.drain(..count).collect()
    }

    fn has_irq(&self) -> bool {
        self.irq_pending
    }

    fn has_data_for_host(&self) -> bool {
        self.ep2_has_data()
    }

    fn push_to_host(&mut self, data: &[u8]) {
        self.ep2_push_bytes(data);
    }

    fn tick(&mut self) {
        Isp1581::tick(self);
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_host_send_cdb() {
        let mut isp = Isp1581::new();
        // Host sends 6-byte TUR CDB padded to 32 bytes
        let cdb = vec![0x00; 32]; // TUR = all zeros
        isp.host_send_ep1(&cdb);
        assert!(isp.irq_pending);
        assert_eq!(isp.ep_status & IRQ_EP_EVENT, IRQ_EP_EVENT);

        // Firmware reads word-by-word (16 words for 32 bytes)
        for i in 0..16 {
            let word = isp.read_word(0x20);
            // All zeros for TUR
            assert_eq!(word, 0x0000, "word {} should be 0", i);
        }
    }

    #[test]
    fn test_firmware_writes_response() {
        let mut isp = Isp1581::new();
        // Firmware writes a single phase byte (0x01)
        // It writes a 16-bit word with the byte in the low position
        isp.write_word(0x20, 0x0001); // LE: low=0x01, high=0x00

        let data = isp.host_recv_ep2(2);
        assert_eq!(data.len(), 2);
        assert_eq!(data[0], 0x01); // Phase byte
        assert_eq!(data[1], 0x00); // Padding
    }

    #[test]
    fn test_dc_interrupt_tx_ready_always_set() {
        let mut isp = Isp1581::new();
        // DcInterrupt bit 12 (IRQ_EP_TX_READY) should always be set on read
        let val = isp.read_word(0x18);
        assert_eq!(val & IRQ_EP_TX_READY, IRQ_EP_TX_READY, "TX_READY should be set");

        // Even after write-back-clear, it should still appear set
        isp.write_word(0x18, IRQ_EP_TX_READY);
        let val = isp.read_word(0x18);
        assert_eq!(val & IRQ_EP_TX_READY, IRQ_EP_TX_READY, "TX_READY persists after clear");
    }

    #[test]
    fn test_dc_interrupt_tx_complete_on_write() {
        let mut isp = Isp1581::new();
        // Before any EP Data Port write, bit 15 should not be in dc_interrupt
        assert_eq!(isp.dc_interrupt & IRQ_EP_TX_COMPLETE, 0, "TX_COMPLETE not set initially");

        // Write to EP Data Port (0x20) should set bits 3, 12, 15
        isp.write_word(0x20, 0x1234);
        assert_eq!(isp.dc_interrupt & IRQ_EP_EVENT, IRQ_EP_EVENT, "EP_EVENT set");
        assert_eq!(isp.dc_interrupt & IRQ_EP_TX_READY, IRQ_EP_TX_READY, "TX_READY set");
        assert_eq!(isp.dc_interrupt & IRQ_EP_TX_COMPLETE, IRQ_EP_TX_COMPLETE, "TX_COMPLETE set");

        // Data should be in EP2 IN FIFO (LE byte order)
        let data = isp.host_recv_ep2(2);
        assert_eq!(data, vec![0x34, 0x12], "EP2 IN data should be LE");
    }

    #[test]
    fn test_dc_buffer_length() {
        let mut isp = Isp1581::new();
        // DcBufferLength at offset 0x1C should return 64 (max packet size)
        assert_eq!(isp.read_word(0x1C), 64);
    }

    #[test]
    fn test_ep1_fifo_injection_and_read() {
        let mut isp = Isp1581::new();
        // Inject 6-byte CDB padded to 8 bytes
        isp.host_send_ep1(&[0x12, 0x00, 0x00, 0x00, 0x24, 0x00, 0x00, 0x00]);
        assert_eq!(isp.ep1_last_inject_size, 8);
        assert!(isp.irq_pending);

        // Read 4 words (8 bytes) from EP Data Port
        let w0 = isp.read_word(0x20); // lo=0x12, hi=0x00 → 0x0012
        assert_eq!(w0, 0x0012, "First word should be INQUIRY opcode");
        let w1 = isp.read_word(0x20); // lo=0x00, hi=0x00 → 0x0000
        assert_eq!(w1, 0x0000);
        let w2 = isp.read_word(0x20); // lo=0x24, hi=0x00 → 0x0024
        assert_eq!(w2, 0x0024, "Third word should contain alloc length");
        let w3 = isp.read_word(0x20); // lo=0x00, hi=0x00 → 0x0000
        assert_eq!(w3, 0x0000);
    }

    #[test]
    fn test_chip_id() {
        let mut isp = Isp1581::new();
        assert_eq!(isp.read_word(0x70), 0x1581, "Chip ID should be 0x1581");
    }

    #[test]
    fn test_usb_enum_registers() {
        let mut isp = Isp1581::new();
        // Address register
        isp.write_word(0x00, 0x0087); // address=7, DEVEN=1
        assert_eq!(isp.read_word(0x00), 0x0087);
        // EP max packet size
        isp.write_word(0x04, 512);
        assert_eq!(isp.read_word(0x04), 512);
        // HW config
        isp.write_word(0x16, 0x0042);
        assert_eq!(isp.read_word(0x16), 0x0042);
        // Unlock
        isp.write_word(0x7C, 0xAA37);
        assert_eq!(isp.read_word(0x7C), 0xAA37);
        // Interrupt enable
        isp.write_word(0x14, 0xFFFF);
        assert_eq!(isp.read_word(0x14), 0xFFFF);
    }

    #[test]
    fn test_softct_bus_reset() {
        let mut isp = Isp1581::new();
        // Start with SOFTCT=0 (mode was set to 0x0010 in new(), but let's reset it)
        isp.mode = 0x0000;
        isp.dc_interrupt = 0;
        isp.irq_pending = false;

        // Write SOFTCT=1 → should schedule bus reset
        isp.write_word(0x0C, 0x0010);
        assert!(isp.bus_reset_pending);

        // Tick should fire bus reset
        isp.tick();
        assert!(!isp.bus_reset_pending);
        assert!(isp.dc_interrupt & IRQ_BUS_RESET != 0, "Bus reset bit should be set");
        assert!(isp.dc_interrupt & IRQ_VBUS != 0, "VBUS bit should be set");
        assert!(isp.irq_pending);
    }

    #[test]
    fn test_irq_clear() {
        let mut isp = Isp1581::new();
        isp.host_send_ep1(&[0x00]);
        assert!(isp.irq_pending);

        // Firmware reads endpoint status, then writes back to clear
        let status = isp.read_word(0x08);
        assert_eq!(status & IRQ_EP_EVENT, IRQ_EP_EVENT);
        isp.write_word(0x08, status); // Write-back clears ep_status

        // Also clear dc_interrupt
        let dc_int = isp.read_word(0x18);
        isp.write_word(0x18, dc_int);

        assert_eq!(isp.ep_status, 0);
        assert!(!isp.irq_pending);
    }
}
