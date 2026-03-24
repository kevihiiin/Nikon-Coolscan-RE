//! ITU (Integrated Timer Unit) 0-4 model.
//!
//! Each timer has: TCR, TIOR, TIER, TSR, TCNT(16-bit), GRA(16-bit), GRB(16-bit).
//! TSTR (0xFFFF60) starts/stops timers with per-bit enable.
//!
//! Active timers in Coolscan V firmware:
//!   ITU2: Motor stepping (Vec 32 = IMIA2)
//!   ITU3: DMA burst counter (Vec 36 = IMIA3)
//!   ITU4: System tick (Vec 40 = IMIA4)

/// Timer interrupt vectors.
pub const ITU2_IMIA_VEC: u8 = 32;
pub const ITU3_IMIA_VEC: u8 = 36;
pub const ITU4_IMIA_VEC: u8 = 40;

pub struct Timer {
    pub tcr: u8,
    pub tior: u8,
    pub tier: u8,
    pub tsr: u8,
    pub tcnt: u16,
    pub gra: u16,
    pub grb: u16,
    /// Prescaler counter (divides CPU clock).
    prescale_count: u32,
}

impl Timer {
    pub fn new() -> Self {
        Self {
            tcr: 0,
            tior: 0,
            tier: 0,
            tsr: 0,
            tcnt: 0,
            gra: 0xFFFF,
            grb: 0xFFFF,
            prescale_count: 0,
        }
    }

    /// Get the prescaler divisor from TCR bits 2-0.
    /// H8/3003 ITU clock select: 000=φ/1, 001=φ/2, 010=φ/4, 011=φ/8, 1xx=external.
    fn prescaler(&self) -> u32 {
        match self.tcr & 0x07 {
            0 => 1,    // φ/1 (internal clock, no division)
            1 => 2,    // φ/2
            2 => 4,    // φ/4
            3 => 8,    // φ/8
            _ => 0,    // External clock sources — not emulated, timer stopped
        }
    }

    /// Returns true if compare-match A interrupt should fire.
    pub fn tick(&mut self) -> bool {
        let div = self.prescaler();
        if div == 0 {
            return false;
        }

        self.prescale_count += 1;
        if self.prescale_count < div {
            return false;
        }
        self.prescale_count = 0;

        self.tcnt = self.tcnt.wrapping_add(1);

        // Check compare-match A
        if self.tcnt == self.gra {
            self.tsr |= 0x01; // IMFA flag
            // Clear on compare-match if configured (TCR bits 5-4)
            let cclr = (self.tcr >> 5) & 0x03;
            if cclr == 1 {
                self.tcnt = 0;
            }
            // Generate interrupt if IMIEA enabled (TIER bit 0)
            if self.tier & 0x01 != 0 {
                return true;
            }
        }

        // Check compare-match B
        if self.tcnt == self.grb {
            self.tsr |= 0x02; // IMFB flag
            let cclr = (self.tcr >> 5) & 0x03;
            if cclr == 2 {
                self.tcnt = 0;
            }
        }

        false
    }
}

impl Default for Timer {
    fn default() -> Self {
        Self::new()
    }
}

/// Interrupt vectors for each timer's compare-match A (ITU0-ITU4).
const IMIA_VECTORS: [u8; 5] = [24, 28, ITU2_IMIA_VEC, ITU3_IMIA_VEC, ITU4_IMIA_VEC];

pub struct TimerUnit {
    pub tstr: u8,  // Timer start register (bit n = ITUn running)
    pub timers: [Timer; 5],
}

impl TimerUnit {
    pub fn new() -> Self {
        Self {
            tstr: 0,
            timers: core::array::from_fn(|_| Timer::new()),
        }
    }

    /// Tick all running timers. Returns interrupt vectors to fire (up to 5).
    /// Uses a fixed-size array to avoid heap allocation on every tick.
    pub fn tick(&mut self) -> [Option<u8>; 5] {
        let mut irqs = [None; 5];

        for i in 0..5 {
            if self.tstr & (1 << i) != 0 && self.timers[i].tick() {
                irqs[i] = Some(IMIA_VECTORS[i]);
            }
        }

        irqs
    }

    /// Read a timer register.
    pub fn read(&self, offset: u8) -> u8 {
        match offset {
            0x60 => self.tstr,
            // Per-timer registers: base addresses
            // ITU0: 0x64-0x6B, ITU1: 0x6E-0x75, ITU2: 0x78-0x7F
            // ITU3: 0x82-0x89, ITU4: 0x8A-0x91 (approximate — actual layout is:
            // TSTR=0x60, TSNC=0x61, TMDR=0x62, TFCR=0x63
            // ITU0: TCR0=0x64, TIOR0=0x65, TIER0=0x66, TSR0=0x67,
            //       TCNT0H=0x68, TCNT0L=0x69, GRA0H=0x6A, GRA0L=0x6B,
            //       GRB0H=0x6C, GRB0L=0x6D
            // ITU1: TCR1=0x6E, ... GRB1L=0x77
            // ITU2: TCR2=0x78, ... GRB2L=0x81
            // ITU3: TCR3=0x82, ... GRB3L=0x8B
            // GAP: 0x8C-0x91 (Port 7, BSC regs, etc.)
            // ITU4: TCR4=0x92, ... GRB4L=0x9B
            _ => self.read_timer_reg(offset),
        }
    }

    /// Write a timer register.
    pub fn write(&mut self, offset: u8, val: u8) {
        match offset {
            0x60 => self.tstr = val,
            0x61 => {} // TSNC — ignore
            0x62 => {} // TMDR — ignore
            0x63 => {} // TFCR — ignore
            _ => self.write_timer_reg(offset, val),
        }
    }

    fn timer_index_and_reg(&self, offset: u8) -> Option<(usize, u8)> {
        match offset {
            0x64..=0x6D => Some((0, offset - 0x64)),
            0x6E..=0x77 => Some((1, offset - 0x6E)),
            0x78..=0x81 => Some((2, offset - 0x78)),
            0x82..=0x8B => Some((3, offset - 0x82)),
            0x92..=0x9B => Some((4, offset - 0x92)),
            _ => None,
        }
    }

    fn read_timer_reg(&self, offset: u8) -> u8 {
        let Some((idx, reg)) = self.timer_index_and_reg(offset) else {
            return 0;
        };
        let t = &self.timers[idx];
        match reg {
            0 => t.tcr,
            1 => t.tior,
            2 => t.tier,
            3 => t.tsr,
            4 => (t.tcnt >> 8) as u8,
            5 => t.tcnt as u8,
            6 => (t.gra >> 8) as u8,
            7 => t.gra as u8,
            8 => (t.grb >> 8) as u8,
            9 => t.grb as u8,
            _ => 0,
        }
    }

    fn write_timer_reg(&mut self, offset: u8, val: u8) {
        let Some((idx, reg)) = self.timer_index_and_reg(offset) else {
            return;
        };
        let t = &mut self.timers[idx];
        match reg {
            0 => t.tcr = val,
            1 => t.tior = val,
            2 => t.tier = val,
            3 => t.tsr &= val, // Write 0 to clear flag bits
            4 => t.tcnt = (t.tcnt & 0x00FF) | ((val as u16) << 8),
            5 => t.tcnt = (t.tcnt & 0xFF00) | val as u16,
            6 => t.gra = (t.gra & 0x00FF) | ((val as u16) << 8),
            7 => t.gra = (t.gra & 0xFF00) | val as u16,
            8 => t.grb = (t.grb & 0x00FF) | ((val as u16) << 8),
            9 => t.grb = (t.grb & 0xFF00) | val as u16,
            _ => {}
        }
    }
}

impl Default for TimerUnit {
    fn default() -> Self {
        Self::new()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_timer_prescaler_div1() {
        let mut t = Timer::new();
        t.tcr = 0x00; // phi/1
        t.gra = 0x0003;
        t.tier = 0x01; // IMIEA enabled
        // Ticks: 1,2,3 → compare-match at 3
        assert!(!t.tick());
        assert!(!t.tick());
        assert!(t.tick(), "compare-match A fires at TCNT==GRA");
        assert_eq!(t.tsr & 0x01, 0x01, "IMFA flag set");
    }

    #[test]
    fn test_timer_prescaler_div8() {
        let mut t = Timer::new();
        t.tcr = 0x03; // phi/8
        t.gra = 0x0001;
        t.tier = 0x01;
        // Need 8 ticks to advance TCNT once
        for _ in 0..7 {
            assert!(!t.tick());
        }
        // 8th tick: TCNT goes from 0 to 1 → match GRA=1
        assert!(t.tick());
    }

    #[test]
    fn test_timer_clear_on_compare_match() {
        let mut t = Timer::new();
        t.tcr = 0x20; // CCLR=1 (clear on GRA match), phi/1
        t.gra = 0x0002;
        t.tier = 0x01;
        t.tick(); // TCNT=1
        t.tick(); // TCNT=2=GRA → match, TCNT cleared to 0
        assert_eq!(t.tcnt, 0, "TCNT cleared on compare-match A");
    }

    #[test]
    fn test_timer_no_irq_when_disabled() {
        let mut t = Timer::new();
        t.tcr = 0x00;
        t.gra = 0x0001;
        t.tier = 0x00; // IMIEA disabled
        assert!(!t.tick(), "tick returns false when IMIEA disabled");
        assert_eq!(t.tsr & 0x01, 0x01, "IMFA flag still set despite no IRQ");
    }

    #[test]
    fn test_timer_unit_tstr() {
        let mut tu = TimerUnit::new();
        tu.timers[2].tcr = 0x00;
        tu.timers[2].gra = 0x0001;
        tu.timers[2].tier = 0x01;

        // Timer 2 not started yet
        tu.tstr = 0x00;
        let irqs = tu.tick();
        assert!(irqs[2].is_none());

        // Start timer 2 (bit 2)
        tu.tstr = 0x04;
        let irqs = tu.tick();
        assert_eq!(irqs[2], Some(ITU2_IMIA_VEC));
    }

    #[test]
    fn test_timer_compare_match_b() {
        let mut t = Timer::new();
        t.tcr = 0x00;
        t.grb = 0x0002;
        t.tick();
        assert_eq!(t.tsr & 0x02, 0x00);
        t.tick(); // TCNT=2=GRB
        assert_eq!(t.tsr & 0x02, 0x02, "IMFB flag set");
    }

    #[test]
    fn test_timer_register_rw() {
        let mut tu = TimerUnit::new();
        // Write TSTR
        tu.write(0x60, 0x1F);
        assert_eq!(tu.read(0x60), 0x1F);

        // Write ITU2 GRA (0x7E-0x7F)
        tu.write(0x7E, 0x12); // GRA high
        tu.write(0x7F, 0x34); // GRA low
        assert_eq!(tu.timers[2].gra, 0x1234);
        assert_eq!(tu.read(0x7E), 0x12);
        assert_eq!(tu.read(0x7F), 0x34);
    }

    #[test]
    fn test_timer_tsr_clear_on_write_0() {
        let mut tu = TimerUnit::new();
        tu.timers[0].tsr = 0x03; // IMFA + IMFB set
        // TSR write: writing 0 to a bit clears it
        tu.write(0x67, 0x01); // Clear IMFB (bit 1 → write 0), keep IMFA (bit 0 → write 1)
        assert_eq!(tu.timers[0].tsr, 0x01);
    }

    #[test]
    fn test_timer_external_clock_stops() {
        let mut t = Timer::new();
        t.tcr = 0x04; // external clock
        t.gra = 0x0001;
        t.tier = 0x01;
        assert!(!t.tick(), "external clock source stops timer");
        assert_eq!(t.tcnt, 0);
    }
}
