/// ISP1581 USB controller model.
///
/// Memory-mapped at 0x600000-0x6000FF. 16-bit bus, little-endian.
/// The H8/3003 is big-endian, so firmware explicitly byte-swaps when reading/writing.
///
/// Register map (7 active addresses from firmware analysis):
///   0x600008  IRQ Status (R/W) — read to check, write-back to clear
///   0x60000C  Mode (R/W) — bit 4 (SOFTCT) = soft connect
///   0x600018  DMA Config (W) — 0x8000 = host-read direction
///   0x60001C  EP Index/Count (W) — endpoint select + byte count
///   0x600020  EP Data Port (R/W) — 16-bit, LE byte order
///   0x60002C  EP Control (W) — DMA mode
///   0x600084  DMA Count (W) — transfer byte count

use std::collections::VecDeque;

/// ISP1581 IRQ status bits.
pub const IRQ_EP_EVENT: u16 = 1 << 3;

pub struct Isp1581 {
    /// IRQ status register (16-bit).
    pub irq_status: u16,
    /// Mode register.
    pub mode: u16,
    /// DMA config.
    pub dma_config: u16,
    /// EP index/count.
    pub ep_index: u16,
    /// EP control.
    pub ep_control: u16,
    /// DMA count.
    pub dma_count: u16,

    /// EP1 OUT FIFO (host → device): CDB bytes arrive here.
    pub ep1_out_fifo: VecDeque<u8>,
    /// EP2 IN FIFO (device → host): response bytes go here.
    pub ep2_in_fifo: VecDeque<u8>,

    /// Whether IRQ1 should be asserted to the CPU.
    pub irq_pending: bool,
}

impl Isp1581 {
    pub fn new() -> Self {
        Self {
            irq_status: 0,
            mode: 0,
            dma_config: 0,
            ep_index: 0,
            ep_control: 0,
            dma_count: 0,
            ep1_out_fifo: VecDeque::new(),
            ep2_in_fifo: VecDeque::new(),
            irq_pending: false,
        }
    }

    /// Read a register (called by memory bus for addresses 0x600000-0x6000FF).
    /// Address is the offset from 0x600000.
    /// Returns a 16-bit value (ISP1581 is 16-bit LE, but we return the native value;
    /// the memory bus handles byte-level access).
    pub fn read_word(&mut self, offset: u32) -> u16 {
        match offset {
            0x08 => self.irq_status,
            0x0C => self.mode,
            0x20 => {
                // EP Data Port: read 16-bit word from EP1 OUT FIFO (LE: low byte first)
                let lo = self.ep1_out_fifo.pop_front().unwrap_or(0);
                let hi = self.ep1_out_fifo.pop_front().unwrap_or(0);
                // Return as LE 16-bit: firmware will see lo in bits[7:0], hi in bits[15:8]
                // But memory bus is BE, so we need to return (hi << 8) | lo
                // and the firmware's byte-swap code extracts lo first.
                (hi as u16) << 8 | lo as u16
            }
            _ => 0,
        }
    }

    /// Write a register.
    pub fn write_word(&mut self, offset: u32, val: u16) {
        match offset {
            0x08 => {
                // Write-back clears bits
                self.irq_status &= !val;
                if self.irq_status == 0 {
                    self.irq_pending = false;
                }
            }
            0x0C => self.mode = val,
            0x18 => self.dma_config = val,
            0x1C => self.ep_index = val,
            0x20 => {
                // EP Data Port write: firmware writes to EP2 IN FIFO
                // Firmware writes LE words: low byte in bits[7:0], high byte in bits[15:8]
                self.ep2_in_fifo.push_back(val as u8);         // Low byte
                self.ep2_in_fifo.push_back((val >> 8) as u8);  // High byte
            }
            0x2C => self.ep_control = val,
            0x84 => self.dma_count = val,
            _ => {}
        }
    }

    /// Inject data from host into EP1 OUT FIFO and assert IRQ.
    pub fn host_send_ep1(&mut self, data: &[u8]) {
        for &b in data {
            self.ep1_out_fifo.push_back(b);
        }
        self.irq_status |= IRQ_EP_EVENT;
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
        // ISP1581 is 16-bit; byte reads should go through read_word.
        // But for non-FIFO registers, just return from the word value.
        let word_offset = offset & !1;
        let word = Isp1581::read_word(self, word_offset);
        if offset & 1 == 0 {
            (word >> 8) as u8
        } else {
            word as u8
        }
    }

    fn write_byte(&mut self, offset: u32, val: u8) {
        // ISP1581 writes are always 16-bit from firmware.
        // For byte writes, reconstruct the word.
        let word_offset = offset & !1;
        let old_word = Isp1581::read_word(self, word_offset);
        let new_word = if offset & 1 == 0 {
            (old_word & 0x00FF) | ((val as u16) << 8)
        } else {
            (old_word & 0xFF00) | val as u16
        };
        Isp1581::write_word(self, word_offset, new_word);
    }

    fn read_word(&mut self, offset: u32) -> u16 {
        Isp1581::read_word(self, offset)
    }

    fn write_word(&mut self, offset: u32, val: u16) {
        Isp1581::write_word(self, offset, val);
    }

    fn inject_host_data(&mut self, data: &[u8]) -> bool {
        self.host_send_ep1(data);
        true // IRQ should fire
    }

    fn drain_device_data(&mut self, max: usize) -> Vec<u8> {
        self.host_recv_ep2(max)
    }

    fn has_irq(&self) -> bool {
        self.irq_pending
    }

    fn has_data_for_host(&self) -> bool {
        self.ep2_has_data()
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
        assert_eq!(isp.irq_status & IRQ_EP_EVENT, IRQ_EP_EVENT);

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
    fn test_irq_clear() {
        let mut isp = Isp1581::new();
        isp.host_send_ep1(&[0x00]);
        assert!(isp.irq_pending);

        // Firmware reads IRQ status, then writes back to clear
        let status = isp.read_word(0x08);
        assert_eq!(status & IRQ_EP_EVENT, IRQ_EP_EVENT);
        isp.write_word(0x08, status); // Write-back clears
        assert_eq!(isp.irq_status, 0);
        assert!(!isp.irq_pending);
    }
}
