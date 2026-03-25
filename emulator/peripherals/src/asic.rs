//! Custom ASIC model (0x200000-0x200FFF).
//!
//! 172 register addresses across blocks 0x00-0x0F.
//! Most are write-accept/read-back. Key behavioral registers:
//!   0x200001: Master enable (0x80=enable)
//!   0x200002: Status — bit 3 = DMA busy
//!   0x2000C2: DAC mode (0x20=init, 0x22=scan, 0xA2=cal)
//!   0x200147-149: DMA buffer address (24-bit)
//!   0x20014B-14D: DMA transfer count (24-bit)
//!   0x2001C1: CCD line timing trigger

/// CCD pixel data source.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum CcdSource {
    /// Gradient test pattern (pixel value = position % 16384).
    Pattern,
    /// Fixed mid-gray value (0x2000).
    MidGray,
}

pub struct Asic {
    /// All registers stored as raw bytes (4KB).
    regs: [u8; 0x1000],
    /// DMA busy countdown (in instruction cycles). 0 = not busy.
    dma_busy_countdown: u32,
    /// Whether a CCD line trigger is pending (fires Vec 49).
    pub ccd_trigger_pending: bool,
    /// Whether DMA just completed (for DEND interrupt).
    pub dma_complete_pending: bool,
    /// Countdown until ASIC reports ready (0x200041 bit 1).
    ready_countdown: u32,
    /// Cold boot mode: delay ready bit instead of setting it immediately.
    pub cold_boot_mode: bool,
    /// CCD pixel data source for scan line generation.
    pub ccd_source: CcdSource,
    /// Scan line counter (increments on each CCD trigger).
    pub line_counter: u32,
    /// Pixel data generated on last CCD trigger (for writing to ASIC RAM).
    pub last_line_data: Vec<u8>,
}

impl Asic {
    pub fn new() -> Self {
        Self {
            regs: [0; 0x1000],
            dma_busy_countdown: 0,
            ccd_trigger_pending: false,
            dma_complete_pending: false,
            ready_countdown: 0,
            cold_boot_mode: false,
            ccd_source: CcdSource::Pattern,
            line_counter: 0,
            last_line_data: Vec::new(),
        }
    }

    pub fn read(&self, offset: u16) -> u8 {
        match offset {
            0x0002 => {
                // Status register: bit 3 = DMA busy
                let busy = if self.dma_busy_countdown > 0 { 0x08 } else { 0x00 };
                (self.regs[offset as usize] & !0x08) | busy
            }
            _ => self.regs[offset as usize],
        }
    }

    pub fn write(&mut self, offset: u16, val: u8) {
        self.regs[offset as usize] = val;

        match offset {
            0x0001 => {
                // Master enable register. Writing 0x80 = enable ASIC.
                if val & 0x80 != 0 {
                    if self.cold_boot_mode {
                        self.ready_countdown = 50_000;
                    } else {
                        self.regs[0x0041] |= 0x02;
                    }
                }
            }
            0x01C1 => {
                // CCD line timing trigger — generate one scan line of pixel data.
                self.ccd_trigger_pending = true;
                self.line_counter += 1;

                // Generate pixel data based on DMA transfer count
                let dma_count = self.dma_count() as usize;
                let byte_count = if dma_count > 0 { dma_count } else { 2660 }; // default ~665 pixels × 4 bytes
                self.last_line_data = self.generate_line(byte_count);

                // DMA busy countdown based on transfer size (1 tick per 16 bytes)
                self.dma_busy_countdown = (byte_count as u32 / 16).max(1);
            }
            _ => {}
        }
    }

    /// Tick the ASIC model (call each CPU instruction).
    /// Returns true if DMA just completed this tick.
    pub fn tick(&mut self) -> bool {
        if self.dma_busy_countdown > 0 {
            self.dma_busy_countdown -= 1;
            if self.dma_busy_countdown == 0 {
                self.dma_complete_pending = true;
                return true;
            }
        }
        if self.ready_countdown > 0 {
            self.ready_countdown -= 1;
            if self.ready_countdown == 0 {
                self.regs[0x0041] |= 0x02;
                log::info!("ASIC ready (0x200041 bit 1 set)");
            }
        }
        false
    }

    /// Generate one scan line of CCD pixel data.
    /// Format: 16-bit words, 14-bit data in bits [15:2], 4 channels (RGBI).
    fn generate_line(&self, byte_count: usize) -> Vec<u8> {
        let word_count = byte_count / 2;
        let mut data = vec![0u8; byte_count];
        let dac_mode = self.regs[0x00C2];

        for i in 0..word_count {
            let raw_14bit: u16 = match self.ccd_source {
                CcdSource::Pattern => {
                    // Gradient: varies with pixel position and line number
                    let pixel = i % 665; // ~665 pixels per channel
                    let base = ((pixel as u32 * 16383) / 665) as u16;
                    // Slight variation per line for non-uniform data
                    (base.wrapping_add(self.line_counter as u16 * 7)) & 0x3FFF
                }
                CcdSource::MidGray => 0x2000, // Mid-range 14-bit
            };

            // Apply DAC mode: calibration mode produces different levels
            let value = match dac_mode {
                0xA2 => {
                    // Calibration mode: low values for dark frame
                    (raw_14bit / 256).max(0x0010) & 0x3FFF
                }
                _ => raw_14bit, // Normal scan mode
            };

            // Pack 14-bit data into 16-bit word: data in bits [15:2]
            let packed = value << 2;
            // Store as big-endian (H8/300H byte order)
            data[i * 2] = (packed >> 8) as u8;
            data[i * 2 + 1] = packed as u8;
        }
        data
    }

    /// Get the DMA buffer address (24-bit from regs 0x147-0x149).
    pub fn dma_address(&self) -> u32 {
        let hi = self.regs[0x147] as u32;
        let mid = self.regs[0x148] as u32;
        let lo = self.regs[0x149] as u32;
        (hi << 16) | (mid << 8) | lo
    }

    /// Get the DMA transfer count (24-bit from regs 0x14B-0x14D).
    pub fn dma_count(&self) -> u32 {
        let hi = self.regs[0x14B] as u32;
        let mid = self.regs[0x14C] as u32;
        let lo = self.regs[0x14D] as u32;
        (hi << 16) | (mid << 8) | lo
    }

    /// Get the DAC mode register (0x00C2).
    pub fn dac_mode(&self) -> u8 {
        self.regs[0x00C2]
    }

    /// Take pending CCD trigger (resets flag).
    pub fn take_ccd_trigger(&mut self) -> bool {
        let pending = self.ccd_trigger_pending;
        self.ccd_trigger_pending = false;
        pending
    }

    /// Take pending DMA completion (resets flag).
    pub fn take_dma_complete(&mut self) -> bool {
        let pending = self.dma_complete_pending;
        self.dma_complete_pending = false;
        pending
    }
}

impl Default for Asic {
    fn default() -> Self {
        Self::new()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_master_enable() {
        let mut asic = Asic::new();
        asic.write(0x0001, 0x80);
        assert_eq!(asic.read(0x0041) & 0x02, 0x02, "ready bit set after master enable");
    }

    #[test]
    fn test_dma_busy_countdown() {
        let mut asic = Asic::new();
        // Set DMA count so the busy period is predictable
        asic.write(0x014B, 0x00);
        asic.write(0x014C, 0x01);
        asic.write(0x014D, 0x00); // 256 bytes → 16 ticks
        asic.write(0x01C1, 0x01);
        assert!(asic.ccd_trigger_pending);
        assert_eq!(asic.read(0x0002) & 0x08, 0x08, "DMA busy bit set");

        // Tick until busy clears
        let mut completed = false;
        for _ in 0..100 {
            if asic.tick() {
                completed = true;
                break;
            }
        }
        assert!(completed, "DMA should complete");
        assert_eq!(asic.read(0x0002) & 0x08, 0x00, "DMA busy bit cleared");
    }

    #[test]
    fn test_ccd_trigger_generates_data() {
        let mut asic = Asic::new();
        asic.write(0x014B, 0x00);
        asic.write(0x014C, 0x04);
        asic.write(0x014D, 0x00); // 1024 bytes
        asic.write(0x01C1, 0x80); // CCD trigger

        assert!(!asic.last_line_data.is_empty(), "Should generate pixel data");
        assert_eq!(asic.last_line_data.len(), 1024);
        assert_eq!(asic.line_counter, 1);

        // Data should be non-zero (gradient pattern)
        let nonzero = asic.last_line_data.iter().filter(|&&b| b != 0).count();
        assert!(nonzero > 0, "Pattern data should have non-zero values");
    }

    #[test]
    fn test_dma_address_assembly() {
        let mut asic = Asic::new();
        asic.write(0x0147, 0x80);
        asic.write(0x0148, 0x12);
        asic.write(0x0149, 0x34);
        assert_eq!(asic.dma_address(), 0x801234);
    }

    #[test]
    fn test_dma_count_assembly() {
        let mut asic = Asic::new();
        asic.write(0x014B, 0x00);
        asic.write(0x014C, 0x10);
        asic.write(0x014D, 0x00);
        assert_eq!(asic.dma_count(), 0x001000);
    }

    #[test]
    fn test_register_readback() {
        let mut asic = Asic::new();
        asic.write(0x00C2, 0x20);
        assert_eq!(asic.read(0x00C2), 0x20);
    }

    #[test]
    fn test_dma_complete_pending() {
        let mut asic = Asic::new();
        asic.write(0x014C, 0x01); // 256 bytes
        asic.write(0x01C1, 0x80);

        assert!(!asic.dma_complete_pending);
        // Tick until completion
        for _ in 0..100 {
            if asic.tick() { break; }
        }
        assert!(asic.take_dma_complete(), "DMA complete should be pending");
        assert!(!asic.take_dma_complete(), "Should be cleared after take");
    }

    #[test]
    fn test_line_counter_increments() {
        let mut asic = Asic::new();
        assert_eq!(asic.line_counter, 0);
        asic.write(0x01C1, 0x80);
        assert_eq!(asic.line_counter, 1);
        asic.write(0x01C1, 0x80);
        assert_eq!(asic.line_counter, 2);
    }
}
