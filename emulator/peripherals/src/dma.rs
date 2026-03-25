//! H8/3003 on-chip DMA controller.
//!
//! 2 channels. Firmware uses DMA for ASIC RAM → Buffer RAM transfers
//! during scan pixel processing.
//!
//! Registers (on-chip I/O):
//!   Channel 0: MAR 0xFFFF20 (4B), ETCR 0xFFFF24 (2B), DTCR 0xFFFF27 (1B)
//!   Channel 1: MAR 0xFFFF28 (4B), ETCR 0xFFFF2C (2B), DTCR 0xFFFF2F (1B)
//!   DMAOR:     0xFFFF90 (1B) — DMA Operation Register (master enable)
//!
//! Completion: Vec 45 (DEND0B, channel 0), Vec 47 (DEND1B, channel 1).

/// DMA channel state.
#[derive(Debug, Clone)]
pub struct DmaChannel {
    /// Memory Address Register (source or dest, 32-bit).
    pub mar: u32,
    /// Transfer Count Register (16-bit).
    pub etcr: u16,
    /// Data Transfer Control Register.
    pub dtcr: u8,
    /// Whether this channel has a pending completion (DEND interrupt).
    pub complete_pending: bool,
}

impl DmaChannel {
    pub fn new() -> Self {
        Self { mar: 0, etcr: 0, dtcr: 0, complete_pending: false }
    }
}

impl Default for DmaChannel {
    fn default() -> Self { Self::new() }
}

/// DMA controller with 2 channels.
pub struct DmaController {
    /// DMA Operation Register at 0xFFFF90.
    pub dmaor: u8,
    /// Two DMA channels.
    pub channels: [DmaChannel; 2],
}

impl DmaController {
    pub fn new() -> Self {
        Self { dmaor: 0, channels: [DmaChannel::new(), DmaChannel::new()] }
    }

    /// Read a DMA register from on-chip I/O offset.
    pub fn read(&self, offset: u8) -> u8 {
        match offset {
            0x20 => (self.channels[0].mar >> 24) as u8,
            0x21 => (self.channels[0].mar >> 16) as u8,
            0x22 => (self.channels[0].mar >> 8) as u8,
            0x23 => self.channels[0].mar as u8,
            0x24 => (self.channels[0].etcr >> 8) as u8,
            0x25 => self.channels[0].etcr as u8,
            0x26 => 0,
            0x27 => self.channels[0].dtcr,
            0x28 => (self.channels[1].mar >> 24) as u8,
            0x29 => (self.channels[1].mar >> 16) as u8,
            0x2A => (self.channels[1].mar >> 8) as u8,
            0x2B => self.channels[1].mar as u8,
            0x2C => (self.channels[1].etcr >> 8) as u8,
            0x2D => self.channels[1].etcr as u8,
            0x2E => 0,
            0x2F => self.channels[1].dtcr,
            0x90 => self.dmaor,
            _ => 0,
        }
    }

    /// Write a DMA register. Returns channel index if transfer triggered.
    pub fn write(&mut self, offset: u8, val: u8) -> Option<usize> {
        match offset {
            0x20 => { self.channels[0].mar = (self.channels[0].mar & 0x00FFFFFF) | ((val as u32) << 24); None }
            0x21 => { self.channels[0].mar = (self.channels[0].mar & 0xFF00FFFF) | ((val as u32) << 16); None }
            0x22 => { self.channels[0].mar = (self.channels[0].mar & 0xFFFF00FF) | ((val as u32) << 8); None }
            0x23 => { self.channels[0].mar = (self.channels[0].mar & 0xFFFFFF00) | val as u32; None }
            0x24 => { self.channels[0].etcr = (self.channels[0].etcr & 0x00FF) | ((val as u16) << 8); None }
            0x25 => { self.channels[0].etcr = (self.channels[0].etcr & 0xFF00) | val as u16; None }
            0x27 => { self.channels[0].dtcr = val; self.check_start(0) }
            0x28 => { self.channels[1].mar = (self.channels[1].mar & 0x00FFFFFF) | ((val as u32) << 24); None }
            0x29 => { self.channels[1].mar = (self.channels[1].mar & 0xFF00FFFF) | ((val as u32) << 16); None }
            0x2A => { self.channels[1].mar = (self.channels[1].mar & 0xFFFF00FF) | ((val as u32) << 8); None }
            0x2B => { self.channels[1].mar = (self.channels[1].mar & 0xFFFFFF00) | val as u32; None }
            0x2C => { self.channels[1].etcr = (self.channels[1].etcr & 0x00FF) | ((val as u16) << 8); None }
            0x2D => { self.channels[1].etcr = (self.channels[1].etcr & 0xFF00) | val as u16; None }
            0x2F => { self.channels[1].dtcr = val; self.check_start(1) }
            0x90 => {
                self.dmaor = val;
                if val & 0x01 != 0 {
                    if let Some(ch) = self.check_start(0) { return Some(ch); }
                    return self.check_start(1);
                }
                None
            }
            _ => None,
        }
    }

    /// Check if a channel should start. Transfers complete instantly.
    fn check_start(&mut self, ch: usize) -> Option<usize> {
        let channel = &mut self.channels[ch];
        if channel.dtcr & 0x80 != 0 && self.dmaor & 0x01 != 0 && channel.etcr > 0 {
            channel.complete_pending = true;
            channel.dtcr &= !0x80;
            log::debug!("DMA ch{}: transfer MAR=0x{:08X} ETCR={}", ch, channel.mar, channel.etcr);
            Some(ch)
        } else {
            None
        }
    }

    /// Take pending completion for a channel.
    pub fn take_complete(&mut self, ch: usize) -> bool {
        let pending = self.channels[ch].complete_pending;
        self.channels[ch].complete_pending = false;
        pending
    }
}

impl Default for DmaController {
    fn default() -> Self { Self::new() }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_mar_assembly() {
        let mut dma = DmaController::new();
        dma.write(0x20, 0x00);
        dma.write(0x21, 0x80);
        dma.write(0x22, 0x12);
        dma.write(0x23, 0x34);
        assert_eq!(dma.channels[0].mar, 0x00801234);
    }

    #[test]
    fn test_etcr_assembly() {
        let mut dma = DmaController::new();
        dma.write(0x24, 0x01);
        dma.write(0x25, 0x00);
        assert_eq!(dma.channels[0].etcr, 0x0100);
    }

    #[test]
    fn test_instant_transfer() {
        let mut dma = DmaController::new();
        dma.write(0x24, 0x00); dma.write(0x25, 0x10); // ETCR = 16
        dma.write(0x90, 0x01); // DMAOR enable
        let triggered = dma.write(0x27, 0x80); // DTE
        assert_eq!(triggered, Some(0));
        assert!(dma.take_complete(0));
    }

    #[test]
    fn test_channel_1() {
        let mut dma = DmaController::new();
        dma.write(0x2C, 0x00); dma.write(0x2D, 0x08);
        dma.write(0x90, 0x01);
        dma.write(0x2F, 0x80);
        assert!(dma.take_complete(1));
        assert!(!dma.take_complete(0));
    }

    #[test]
    fn test_disabled_no_transfer() {
        let mut dma = DmaController::new();
        dma.write(0x24, 0x00); dma.write(0x25, 0x10);
        let triggered = dma.write(0x27, 0x80); // DTE but DMAOR off
        assert_eq!(triggered, None);
        assert!(!dma.take_complete(0));
    }

    #[test]
    fn test_readback() {
        let mut dma = DmaController::new();
        dma.write(0x90, 0x05);
        assert_eq!(dma.read(0x90), 0x05);
    }
}
