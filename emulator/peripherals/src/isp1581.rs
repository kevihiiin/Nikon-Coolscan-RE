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

use std::collections::{HashSet, VecDeque};

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

/// ControlFunction (0x28) bit 0: STALL the currently-selected endpoint.
/// Per ISP1581 datasheet Table 60. Firmware writes this when it cannot
/// service a request — host sees a STALL handshake on the next transfer
/// to that endpoint and must clear it via CLEAR_FEATURE.
pub const CTRL_FUNC_STALL: u16 = 1 << 0;

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

    /// Sticky flag set when firmware reads the EP Data Port with fewer than
    /// 2 bytes in the EP1 OUT FIFO and no `ep1_pattern` fallback is set.
    /// Distinguishes silent-corruption (phantom-TUR) cases from intentional
    /// pattern-served reads.
    pub ep1_underrun: bool,

    /// Optional CDB pattern that the read path falls back to when the
    /// EP1 OUT FIFO is empty. The cursor advances per byte read and wraps
    /// modulo `pattern.len()`, so reads return an infinitely-repeated CDB
    /// rather than fabricated zeros. Used by `scsi_command` so handlers
    /// that read the CDB more times than the injected padding covers
    /// (e.g. INQUIRY's 5188-instruction dispatch loop) see a stable
    /// repeated CDB instead of opcode 0x00 = phantom TUR. Cleared on
    /// real host data injection via `host_send_ep1`.
    pub ep1_pattern: Option<Vec<u8>>,
    /// Read cursor into `ep1_pattern`. Wraps modulo `pattern.len()`.
    ep1_pattern_cursor: usize,

    /// Set of (offset, "r"|"w") tuples we have already warned about for
    /// unmodeled register access. First touch warns; subsequent touches log
    /// at trace level. Catches firmware behavior gaps without spamming.
    unmodeled_seen: HashSet<(u32, &'static str)>,

    /// STALL state per endpoint, indexed by `ep_index` value at the time
    /// firmware wrote the STALL bit. Real hardware stalls "the selected
    /// endpoint", so the active selection at write time determines which
    /// EP gets the stall. A real USB host would see a STALL handshake on
    /// the next transfer and must issue CLEAR_FEATURE to clear it; for
    /// emulator visibility the orchestrator can inspect this map.
    pub ep_stalled: HashSet<u16>,
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
            ep1_underrun: false,
            ep1_pattern: None,
            ep1_pattern_cursor: 0,
            unmodeled_seen: HashSet::new(),
            ep_stalled: HashSet::new(),
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
                //
                // The "selected endpoint" is set via EP Control (0x2C) /
                // EndpointIndex; we do not currently track that selection, so
                // we return a single value that satisfies both code paths the
                // firmware actually exercises:
                //
                // - Response phase (IN, FW:0x013D7E): firmware writes EP
                //   Control then reads DcBufferLength. A zero would make the
                //   manager loop forever waiting for buffer space; any
                //   non-zero is read as "ready to send a packet".
                // - CDB receive (OUT): the IRQ1 path injects a fixed CDB
                //   length and the firmware reads exactly that many words,
                //   so DcBufferLength is not consulted on this path in
                //   practice.
                //
                // Returning the max-packet-size constant 64 satisfies the
                // response path and is the value real ISP1581 hardware would
                // report for an empty IN buffer ready to accept data.
                // I8 (per-EP accuracy) cannot be done correctly without
                // modeling the EP selection, and the underrun flag (C2) is
                // the more useful signal for the silent-corruption case.
                64
            }
            0x1E => {
                // DcBufferStatus — endpoint buffer fill state.
                // Return 0 (all buffers empty/available for write).
                0
            }
            0x20 => {
                // EP Data Port: read 16-bit word from EP1 OUT FIFO (LE: low byte first).
                // When the FIFO is short of bytes, fall back in this order:
                //   1. ep1_pattern (cyclic CDB pattern) — intentional, no warn
                //   2. fabricated zeros (phantom TUR risk) — sets `ep1_underrun`
                let lo = self.next_ep1_byte();
                let hi = self.next_ep1_byte();
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
                self.log_unmodeled(offset, "r", None);
                0
            }
        }
    }

    /// Warn-once-then-trace logging for unmodeled register access. Tracks
    /// a `(offset, direction)` set so each new occurrence surfaces at
    /// warn level (visible at the default log level) but tight loops
    /// don't spam.
    fn log_unmodeled(&mut self, offset: u32, dir: &'static str, val: Option<u16>) {
        let first = self.unmodeled_seen.insert((offset, dir));
        let action = if dir == "r" { "read" } else { "write" };
        if first {
            match val {
                Some(v) => log::warn!(
                    "ISP1581: unmodeled register {action} at offset 0x{offset:02X} = 0x{v:04X} (dropped; further logged at trace)"
                ),
                None => log::warn!(
                    "ISP1581: unmodeled register {action} at offset 0x{offset:02X} (returning 0; further logged at trace)"
                ),
            }
        } else {
            match val {
                Some(v) => log::trace!("ISP1581: unmodeled register {action} at offset 0x{offset:02X} = 0x{v:04X}"),
                None => log::trace!("ISP1581: unmodeled register {action} at offset 0x{offset:02X}"),
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
                //
                // STALL (bit 0): firmware asks the controller to stall the
                // currently-selected endpoint. Track it so the orchestrator
                // (or a real gadget transport) can propagate the stall to
                // the host. Writing 0 to the bit clears the stall.
                let ep = self.ep_index;
                if val & CTRL_FUNC_STALL != 0 {
                    if self.ep_stalled.insert(ep) {
                        log::warn!("ISP1581: STALL set on EP index 0x{:04X}", ep);
                    }
                } else if self.ep_stalled.remove(&ep) {
                    log::info!("ISP1581: STALL cleared on EP index 0x{:04X}", ep);
                }
            }
            0x2C => self.ep_control = val,
            0x7C => self.unlock = val,
            0x84 => self.dma_count = val,
            _ => self.log_unmodeled(offset, "w", Some(val)),
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
    ///
    /// Real host data invalidates any previously-set CDB pattern fallback —
    /// the host is now driving the FIFO and we should not paper over its
    /// data with synthetic CDB bytes.
    pub fn host_send_ep1(&mut self, data: &[u8]) {
        self.ep1_last_inject_size = data.len() as u16;
        for &b in data {
            self.ep1_out_fifo.push_back(b);
        }
        self.ep_status |= IRQ_EP_EVENT;
        self.dc_interrupt |= IRQ_EP_EVENT;
        self.irq_pending = true;
        // Fresh data clears any prior underrun condition.
        self.ep1_underrun = false;
        // Real host data takes over from any synthetic CDB pattern.
        self.ep1_pattern = None;
        self.ep1_pattern_cursor = 0;
    }

    /// Set a CDB pattern that subsequent EP1 OUT reads fall back to when
    /// the FIFO is empty. Cycles bytes modulo the pattern's length so a
    /// single 16-byte CDB supplies an unlimited stream of stable bytes.
    ///
    /// Used by `Emulator::scsi_command` to satisfy firmware dispatch loops
    /// that re-read the CDB more times than any reasonable padded
    /// injection covers (INQUIRY's response manager + dispatcher init +
    /// data-transfer paths each issue their own CDB-fetch). Without this,
    /// the firmware reads `(0, 0)` after the FIFO drains and decodes it
    /// as opcode `0x00` = TEST UNIT READY (phantom TUR) — the immediate
    /// blocker for live NikonScan-driven runs over USB/IP. See backlog
    /// item N7 for the live-run trace.
    pub fn set_ep1_pattern(&mut self, cdb: &[u8]) {
        if cdb.is_empty() {
            self.ep1_pattern = None;
            self.ep1_pattern_cursor = 0;
            return;
        }
        self.ep1_pattern = Some(cdb.to_vec());
        self.ep1_pattern_cursor = 0;
        // The pattern guarantees reads will not fabricate zeros; clear
        // any stale underrun flag from a prior dispatch.
        self.ep1_underrun = false;
    }

    /// Pop one byte from EP1 OUT FIFO, falling back to (in order) the
    /// CDB pattern then a fabricated zero. Sets `ep1_underrun` only when
    /// fabricating zeros — i.e. the silent-corruption case the warn
    /// surfaces.
    fn next_ep1_byte(&mut self) -> u8 {
        if let Some(b) = self.ep1_out_fifo.pop_front() {
            return b;
        }
        if let Some(pattern) = &self.ep1_pattern {
            // pattern is non-empty by construction (set_ep1_pattern returns early)
            let b = pattern[self.ep1_pattern_cursor % pattern.len()];
            self.ep1_pattern_cursor = self.ep1_pattern_cursor.wrapping_add(1);
            return b;
        }
        // No FIFO data, no pattern — surface the silent-corruption hazard.
        if !self.ep1_underrun {
            log::warn!(
                "ISP1581: EP1 OUT FIFO underrun (0 bytes available, no CDB pattern set) \
                 — fabricated zero may be misread as TUR opcode"
            );
        } else {
            log::trace!("ISP1581: EP1 OUT FIFO continued underrun");
        }
        self.ep1_underrun = true;
        0
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
        // Write-back-clear registers (DcInterrupt 0x18, DcEndpointStatus 0x08):
        // a normal read-modify-write would (a) include synthetic bits from
        // read_word() in the merged value and (b) cause write_word's `&= !val`
        // to clear bits in the byte the firmware wasn't writing. For these
        // registers a byte write must only clear bits in the addressed byte;
        // the other byte's stored bits stay untouched. Build a word that is
        // zero in the unaddressed byte and write it directly.
        if word_offset == 0x08 || word_offset == 0x18 {
            let word_val = if offset & 1 == 0 { (val as u16) << 8 } else { val as u16 };
            Isp1581::write_word(self, word_offset, word_val);
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

    fn set_ep1_pattern(&mut self, cdb: &[u8]) {
        Isp1581::set_ep1_pattern(self, cdb);
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
    fn test_dc_buffer_length_returns_max_packet_size() {
        // DcBufferLength returns 64 (max packet size for full-speed USB).
        // This is read by the response manager at FW:0x013D7E and must be
        // non-zero or it loops forever. Per-EP accuracy (backlog I8) cannot
        // be modeled without tracking which endpoint is selected.
        let mut isp = Isp1581::new();
        assert_eq!(isp.read_word(0x1C), 64);
    }

    #[test]
    fn test_ep1_underrun_flag_set_on_empty_read() {
        // C2 regression: reading the EP Data Port with an empty FIFO must
        // surface as a sticky underrun flag rather than silently producing a
        // zero word that firmware would parse as a TUR opcode.
        let mut isp = Isp1581::new();
        assert!(!isp.ep1_underrun, "underrun starts clear");

        // Empty FIFO read fabricates zero AND sets underrun.
        let val = isp.read_word(0x20);
        assert_eq!(val, 0x0000, "empty FIFO returns 0 (no choice from a memory read)");
        assert!(isp.ep1_underrun, "underrun flag is set");

        // Fresh injection clears the flag.
        isp.host_send_ep1(&[0xAA, 0xBB]);
        assert!(!isp.ep1_underrun, "underrun cleared by fresh data");
    }

    #[test]
    fn test_ep1_underrun_flag_set_on_partial_read() {
        // FIFO with 1 byte → reading a 16-bit word still underruns.
        let mut isp = Isp1581::new();
        isp.host_send_ep1(&[0xAA]); // 1 byte only
        let val = isp.read_word(0x20);
        assert_eq!(val & 0x00FF, 0xAA, "available byte is returned");
        assert_eq!(val & 0xFF00, 0x0000, "missing byte fabricated as 0");
        assert!(isp.ep1_underrun, "partial-word read sets underrun");
    }

    #[test]
    fn test_ep1_pattern_serves_underrun_reads_without_warning() {
        // N7 fix: when scsi_command sets a CDB pattern, EP1 OUT reads past
        // the injected FIFO bytes return cyclic CDB data instead of
        // fabricating zeros. The underrun flag stays clear because the
        // pattern is intentional, not silent corruption.
        let mut isp = Isp1581::new();
        let cdb = vec![0x12, 0x00, 0x00, 0x00, 0x24, 0x00]; // INQUIRY, 36 bytes
        isp.set_ep1_pattern(&cdb);

        // First word: lo=0x12 (cursor 0→1), hi=0x00 (cursor 1→2)
        let w0 = isp.read_word(0x20);
        assert_eq!(w0, 0x0012, "first word from pattern (lo=opcode, hi=lun)");
        assert!(!isp.ep1_underrun, "pattern reads do not set underrun");

        // Read past pattern length to verify wraparound. After 6 byte reads
        // the cursor wraps; the 4th word (cursor 6 % 6 = 0) is the same
        // (0x12, 0x00) as the first.
        let _ = isp.read_word(0x20); // cursor 2→3, 3→4
        let _ = isp.read_word(0x20); // cursor 4→5, 5→6 (wraps to 0)
        let w3 = isp.read_word(0x20); // cursor 0→1, 1→2 — same as w0
        assert_eq!(w3, w0, "pattern wraps cyclically");
        assert!(!isp.ep1_underrun, "still no underrun after wrap");
    }

    #[test]
    fn test_ep1_pattern_cleared_by_real_host_send() {
        // A real host URB takes precedence over any synthetic pattern —
        // host_send_ep1 must clear the pattern so the new data drives the
        // FIFO, not a stale CDB cycle.
        let mut isp = Isp1581::new();
        isp.set_ep1_pattern(&[0x12, 0x34]);
        assert!(isp.ep1_pattern.is_some());

        isp.host_send_ep1(&[0xAA, 0xBB]);
        assert!(isp.ep1_pattern.is_none(), "pattern cleared by real host data");

        // The fresh data is consumed; subsequent reads should fall back to
        // fabricated zeros + underrun (no pattern to draw from).
        let _ = isp.read_word(0x20); // 0xAA, 0xBB
        let _ = isp.read_word(0x20); // empty + no pattern → zeros + underrun
        assert!(isp.ep1_underrun, "no pattern → underrun after FIFO empty");
    }

    #[test]
    fn test_ep1_pattern_falls_back_after_fifo_drained() {
        // Mixed scenario: FIFO has some bytes, pattern is set. Reads consume
        // FIFO first (in pop_front order), then transition to pattern bytes
        // without any underrun warn between the two sources.
        let mut isp = Isp1581::new();
        // Inject 3 real bytes (uses host_send_ep1 which clears pattern; so
        // we set the pattern AFTER injection — this is the same ordering
        // scsi_command_out uses).
        isp.host_send_ep1(&[0x2A, 0xFF, 0xEE]);
        isp.set_ep1_pattern(&[0x12, 0x34]);

        // FIFO: [0x2A, 0xFF, 0xEE]; pattern: [0x12, 0x34]
        let w0 = isp.read_word(0x20); // lo=0x2A (FIFO), hi=0xFF (FIFO)
        assert_eq!(w0, 0xFF2A);
        let w1 = isp.read_word(0x20); // lo=0xEE (FIFO), hi=0x12 (pattern[0])
        assert_eq!(w1, 0x12EE);
        let w2 = isp.read_word(0x20); // lo=0x34 (pattern[1]), hi=0x12 (pattern[0] again — wrap)
        assert_eq!(w2, 0x1234);
        assert!(!isp.ep1_underrun, "no underrun while pattern serves");
    }

    #[test]
    fn test_ep1_set_pattern_with_empty_clears_pattern() {
        // Edge case: set_ep1_pattern(&[]) should remove any prior pattern,
        // not store an empty Vec which would crash on the modulo.
        let mut isp = Isp1581::new();
        isp.set_ep1_pattern(&[0x12, 0x34]);
        isp.set_ep1_pattern(&[]);
        assert!(isp.ep1_pattern.is_none(), "empty pattern → cleared");
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

    #[test]
    fn test_stall_set_and_cleared_per_ep() {
        // N3: firmware writes STALL to ControlFunction (0x28) bit 0 with
        // EP selected via ep_index (0x1C). Track per-EP so the orchestrator
        // can propagate stall to a real USB host.
        let mut isp = Isp1581::new();
        assert!(isp.ep_stalled.is_empty());

        // Select EP1 OUT, set STALL.
        isp.write_word(0x1C, 0x0001);
        isp.write_word(0x28, CTRL_FUNC_STALL);
        assert!(isp.ep_stalled.contains(&0x0001), "EP1 stalled");

        // Select EP2 IN, set STALL — both stalls coexist.
        isp.write_word(0x1C, 0x0082);
        isp.write_word(0x28, CTRL_FUNC_STALL);
        assert!(isp.ep_stalled.contains(&0x0082), "EP2 stalled");
        assert!(isp.ep_stalled.contains(&0x0001), "EP1 stall persists");

        // Clear STALL on EP2 IN by writing 0 to ControlFunction with EP2 selected.
        isp.write_word(0x28, 0);
        assert!(!isp.ep_stalled.contains(&0x0082), "EP2 stall cleared");
        assert!(isp.ep_stalled.contains(&0x0001), "EP1 still stalled");
    }

    #[test]
    fn test_unmodeled_register_warns_once_then_traces() {
        // I3 regression: unmodeled offsets must surface at warn level on
        // first touch so silent firmware behavior gaps are visible.
        // Subsequent touches at trace level prevent log spam in tight loops.
        let mut isp = Isp1581::new();
        // Pick offsets that aren't in the modeled set.
        let unmodeled_offset = 0x40;
        assert!(!isp.unmodeled_seen.contains(&(unmodeled_offset, "r")));
        let _ = isp.read_word(unmodeled_offset);
        assert!(isp.unmodeled_seen.contains(&(unmodeled_offset, "r")));
        // Repeated reads do not re-insert (set semantics) and log at trace.
        let _ = isp.read_word(unmodeled_offset);
        assert_eq!(isp.unmodeled_seen.len(), 1);

        // Writes track separately from reads.
        isp.write_word(unmodeled_offset, 0xDEAD);
        assert!(isp.unmodeled_seen.contains(&(unmodeled_offset, "w")));
        assert_eq!(isp.unmodeled_seen.len(), 2, "read and write tracked separately");
    }

    #[test]
    fn test_byte_write_to_dc_interrupt_does_not_clear_other_byte() {
        // Regression for I2: a byte write to one half of DcInterrupt must
        // not clear bits in the other half. Previously the read-modify-write
        // path would (a) include the synthetic IRQ_EP_TX_READY bit and (b)
        // do `dc_interrupt &= !merged_value`, clearing bits the firmware
        // never wrote.
        use h8300h_core::memory::MmioDevice;

        let mut isp = Isp1581::new();
        // Set IRQ_EP_EVENT (bit 3) — sits in the low byte.
        isp.dc_interrupt = IRQ_EP_EVENT;

        // Byte-write 0x00 to the high byte of DcInterrupt. Intent: clear
        // nothing in the high byte (and definitely don't touch the low byte).
        MmioDevice::write_byte(&mut isp, 0x18, 0x00);

        assert_eq!(
            isp.dc_interrupt & IRQ_EP_EVENT,
            IRQ_EP_EVENT,
            "low-byte bits must survive a high-byte write of 0",
        );
    }

    #[test]
    fn test_byte_write_to_dc_interrupt_clears_addressed_byte_only() {
        // Byte write of 0x08 to the low byte clears only IRQ_EP_EVENT.
        // Bits in the high byte stay put.
        use h8300h_core::memory::MmioDevice;

        let mut isp = Isp1581::new();
        // Plant a bit in each byte. IRQ_BUS_RESET (bit 6) is low byte;
        // IRQ_HIGH_SPEED (bit 8) is the lowest bit of the high byte.
        isp.dc_interrupt = IRQ_BUS_RESET | IRQ_HIGH_SPEED | IRQ_EP_EVENT;

        // Low-byte byte address is 0x19 (high byte is 0x18 since H8 is BE).
        MmioDevice::write_byte(&mut isp, 0x19, IRQ_EP_EVENT as u8);

        assert_eq!(isp.dc_interrupt & IRQ_EP_EVENT, 0, "addressed bit cleared");
        assert_eq!(
            isp.dc_interrupt & IRQ_BUS_RESET,
            IRQ_BUS_RESET,
            "other low-byte bits unchanged",
        );
        assert_eq!(
            isp.dc_interrupt & IRQ_HIGH_SPEED,
            IRQ_HIGH_SPEED,
            "high-byte bits untouched by low-byte write",
        );
    }

    #[test]
    fn test_byte_write_to_ep_status_isolates_bytes() {
        // Same regression for the other write-back-clear register (0x08).
        use h8300h_core::memory::MmioDevice;

        let mut isp = Isp1581::new();
        isp.ep_status = 0x0108; // bit 8 in high byte, bit 3 (IRQ_EP_EVENT) in low byte

        // Write 0 to high byte → high-byte bit must persist.
        MmioDevice::write_byte(&mut isp, 0x08, 0x00);
        assert_eq!(isp.ep_status, 0x0108, "byte write of 0 must be a no-op");

        // Now clear just the low byte's IRQ_EP_EVENT.
        MmioDevice::write_byte(&mut isp, 0x09, IRQ_EP_EVENT as u8);
        assert_eq!(isp.ep_status, 0x0100, "high-byte bit survives, low-byte bit cleared");
    }
}
