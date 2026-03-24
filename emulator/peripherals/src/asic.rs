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

pub struct Asic {
    /// All registers stored as raw bytes (4KB).
    regs: [u8; 0x1000],
    /// DMA busy countdown (in instruction cycles). 0 = not busy.
    dma_busy_countdown: u32,
    /// Whether a CCD line trigger is pending.
    pub ccd_trigger_pending: bool,
    /// Countdown until ASIC reports ready (0x200041 bit 1).
    /// Simulates hardware init time after master enable.
    ready_countdown: u32,
    /// Cold boot mode: delay ready bit instead of setting it immediately.
    pub cold_boot_mode: bool,
}

impl Asic {
    pub fn new() -> Self {
        Self {
            regs: [0; 0x1000],
            dma_busy_countdown: 0,
            ccd_trigger_pending: false,
            ready_countdown: 0,
            cold_boot_mode: false,
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
                        // Cold boot: delay ready by ~50000 instructions
                        self.ready_countdown = 50_000;
                    } else {
                        // Warm boot: set ready immediately
                        self.regs[0x0041] |= 0x02;
                    }
                }
            }
            0x01C1 => {
                // CCD line timing trigger
                self.ccd_trigger_pending = true;
                // Start brief DMA busy period
                self.dma_busy_countdown = 50; // Clears after ~50 instructions
            }
            _ => {}
        }
    }

    /// Tick the ASIC model (call each CPU instruction).
    pub fn tick(&mut self) {
        if self.dma_busy_countdown > 0 {
            self.dma_busy_countdown -= 1;
        }
        if self.ready_countdown > 0 {
            self.ready_countdown -= 1;
            if self.ready_countdown == 0 {
                // ASIC is now ready — set bit 1 of status register 0x0041
                self.regs[0x0041] |= 0x02;
                log::info!("ASIC ready (0x200041 bit 1 set)");
            }
        }
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
        // CCD trigger starts DMA busy
        asic.write(0x01C1, 0x01);
        assert!(asic.ccd_trigger_pending);
        assert_eq!(asic.read(0x0002) & 0x08, 0x08, "DMA busy bit set");

        // Tick until busy clears
        for _ in 0..50 {
            asic.tick();
        }
        assert_eq!(asic.read(0x0002) & 0x08, 0x00, "DMA busy bit cleared after countdown");
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
}
