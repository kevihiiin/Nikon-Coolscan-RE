//! H8/300H CPU state.
//!
//! Register model:
//!   ER0-ER7 are 32-bit general registers.
//!   Each ERn contains En (high 16) and Rn (low 16).
//!   Each Rn contains RnH (high 8) and RnL (low 8).
//!   ER7 is the stack pointer (SP).
//!   PC is 24-bit (stored in u32, top 8 bits always 0).
//!   CCR is 8-bit: I UI H U N Z V C (bits 7..0).

/// CCR flag bit positions.
pub const CCR_C: u8 = 0;
pub const CCR_V: u8 = 1;
pub const CCR_Z: u8 = 2;
pub const CCR_N: u8 = 3;
pub const CCR_U: u8 = 4;
pub const CCR_H: u8 = 5;
pub const CCR_UI: u8 = 6;
pub const CCR_I: u8 = 7;

#[derive(Debug, Clone)]
pub struct Cpu {
    /// General registers ER0-ER7 (ER7 = SP).
    pub er: [u32; 8],
    /// Program counter (24-bit, upper 8 bits unused).
    pub pc: u32,
    /// Condition code register.
    pub ccr: u8,
    /// CPU is in SLEEP state (halted until interrupt).
    pub sleeping: bool,
    /// Total instructions executed (for profiling/debugging).
    pub cycle_count: u64,
}

impl Cpu {
    pub fn new() -> Self {
        Self {
            er: [0; 8],
            pc: 0,
            ccr: 0,
            sleeping: false,
            cycle_count: 0,
        }
    }

    /// Initialize from reset vector. Reads PC from address 0x000000 (big-endian u32).
    pub fn reset(&mut self, reset_vector: u32) {
        self.er = [0; 8];
        self.pc = reset_vector & 0x00FF_FFFF;
        // CCR: I=1 (interrupts masked) after reset
        self.ccr = 1 << CCR_I;
        self.sleeping = false;
        self.cycle_count = 0;
    }

    // --- Register access helpers ---
    // ERn = 32-bit
    // En  = high 16 bits of ERn
    // Rn  = low 16 bits of ERn
    // RnH = high 8 bits of Rn (bits 15..8 of ERn)
    // RnL = low 8 bits of Rn (bits 7..0 of ERn)

    pub fn read_er(&self, n: u8) -> u32 {
        self.er[(n & 7) as usize]
    }

    pub fn write_er(&mut self, n: u8, val: u32) {
        self.er[(n & 7) as usize] = val;
    }

    pub fn read_r(&self, n: u8) -> u16 {
        self.er[n as usize] as u16
    }

    pub fn write_r(&mut self, n: u8, val: u16) {
        let er = &mut self.er[n as usize];
        *er = (*er & 0xFFFF_0000) | val as u32;
    }

    pub fn read_e(&self, n: u8) -> u16 {
        (self.er[n as usize] >> 16) as u16
    }

    pub fn write_e(&mut self, n: u8, val: u16) {
        let er = &mut self.er[n as usize];
        *er = ((val as u32) << 16) | (*er & 0x0000_FFFF);
    }

    /// Read 8-bit register. For H8/300H, register numbering:
    ///   0-7 = R0H..R7H (high byte of Rn)
    ///   8-15 = R0L..R7L (low byte of Rn)
    pub fn read_r8(&self, n: u8) -> u8 {
        if n < 8 {
            // RnH = bits 15..8 of ERn
            (self.er[n as usize] >> 8) as u8
        } else {
            // RnL = bits 7..0 of ER(n-8)
            self.er[(n - 8) as usize] as u8
        }
    }

    /// Write 8-bit register (same numbering as read_r8).
    pub fn write_r8(&mut self, n: u8, val: u8) {
        if n < 8 {
            let er = &mut self.er[n as usize];
            *er = (*er & 0xFFFF_00FF) | ((val as u32) << 8);
        } else {
            let er = &mut self.er[(n - 8) as usize];
            *er = (*er & 0xFFFF_FF00) | val as u32;
        }
    }

    /// Read 16-bit register (R0-R7 or E0-E7).
    /// 0-7 = R0..R7 (low 16 of ERn), 8-15 = E0..E7 (high 16 of ERn)
    pub fn read_r16(&self, n: u8) -> u16 {
        if n < 8 {
            self.er[n as usize] as u16
        } else {
            (self.er[(n - 8) as usize] >> 16) as u16
        }
    }

    /// Write 16-bit register.
    pub fn write_r16(&mut self, n: u8, val: u16) {
        if n < 8 {
            let er = &mut self.er[n as usize];
            *er = (*er & 0xFFFF_0000) | val as u32;
        } else {
            let er = &mut self.er[(n - 8) as usize];
            *er = ((val as u32) << 16) | (*er & 0x0000_FFFF);
        }
    }

    // --- CCR flag helpers ---

    pub fn flag(&self, bit: u8) -> bool {
        (self.ccr >> bit) & 1 != 0
    }

    pub fn set_flag(&mut self, bit: u8, val: bool) {
        if val {
            self.ccr |= 1 << bit;
        } else {
            self.ccr &= !(1 << bit);
        }
    }

    pub fn carry(&self) -> bool {
        self.flag(CCR_C)
    }
    pub fn zero(&self) -> bool {
        self.flag(CCR_Z)
    }
    pub fn negative(&self) -> bool {
        self.flag(CCR_N)
    }
    pub fn overflow(&self) -> bool {
        self.flag(CCR_V)
    }
    pub fn half_carry(&self) -> bool {
        self.flag(CCR_H)
    }
    pub fn interrupt_masked(&self) -> bool {
        self.flag(CCR_I)
    }

    /// Update N and Z flags for an 8-bit result.
    pub fn update_nz_b(&mut self, result: u8) {
        self.set_flag(CCR_N, result & 0x80 != 0);
        self.set_flag(CCR_Z, result == 0);
    }

    /// Update N and Z flags for a 16-bit result.
    pub fn update_nz_w(&mut self, result: u16) {
        self.set_flag(CCR_N, result & 0x8000 != 0);
        self.set_flag(CCR_Z, result == 0);
    }

    /// Update N and Z flags for a 32-bit result.
    pub fn update_nz_l(&mut self, result: u32) {
        self.set_flag(CCR_N, result & 0x8000_0000 != 0);
        self.set_flag(CCR_Z, result == 0);
    }

    /// SP register (ER7).
    pub fn sp(&self) -> u32 {
        self.er[7]
    }

    pub fn set_sp(&mut self, val: u32) {
        self.er[7] = val;
    }
}

impl Default for Cpu {
    fn default() -> Self {
        Self::new()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_register_aliasing() {
        let mut cpu = Cpu::new();
        cpu.write_er(0, 0x12345678);

        assert_eq!(cpu.read_e(0), 0x1234);
        assert_eq!(cpu.read_r(0), 0x5678);
        assert_eq!(cpu.read_r8(0), 0x56); // R0H
        assert_eq!(cpu.read_r8(8), 0x78); // R0L
    }

    #[test]
    fn test_write_r8_preserves_other_bytes() {
        let mut cpu = Cpu::new();
        cpu.write_er(0, 0x12345678);

        cpu.write_r8(0, 0xAA); // R0H
        assert_eq!(cpu.read_er(0), 0x1234AA78);

        cpu.write_r8(8, 0xBB); // R0L
        assert_eq!(cpu.read_er(0), 0x1234AABB);
    }

    #[test]
    fn test_write_r16_preserves_upper() {
        let mut cpu = Cpu::new();
        cpu.write_er(0, 0x12345678);

        cpu.write_r(0, 0xAAAA);
        assert_eq!(cpu.read_er(0), 0x1234AAAA);

        cpu.write_e(0, 0xBBBB);
        assert_eq!(cpu.read_er(0), 0xBBBBAAAA);
    }

    #[test]
    fn test_ccr_flags() {
        let mut cpu = Cpu::new();
        cpu.set_flag(CCR_Z, true);
        cpu.set_flag(CCR_N, true);
        assert!(cpu.zero());
        assert!(cpu.negative());
        assert!(!cpu.carry());

        cpu.set_flag(CCR_Z, false);
        assert!(!cpu.zero());
        assert!(cpu.negative());
    }

    #[test]
    fn test_reset() {
        let mut cpu = Cpu::new();
        cpu.write_er(0, 0xDEADBEEF);
        cpu.reset(0x000100);
        assert_eq!(cpu.pc, 0x000100);
        assert!(cpu.interrupt_masked());
        assert_eq!(cpu.read_er(0), 0);
    }
}
