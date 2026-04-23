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

    /// Tick the timer once. Returns a 3-slot array indicating which interrupts fire:
    ///   [0] = IMIA (compare-match A)
    ///   [1] = IMIB (compare-match B)
    ///   [2] = OVI  (overflow)
    /// Each slot is `Some(())` if the interrupt is enabled AND the condition matched.
    /// TimerUnit maps these to actual vector numbers.
    pub fn tick(&mut self) -> [Option<()>; 3] {
        let mut irqs = [None; 3];

        let div = self.prescaler();
        if div == 0 {
            return irqs;
        }

        self.prescale_count += 1;
        if self.prescale_count < div {
            return irqs;
        }
        self.prescale_count = 0;

        let old_tcnt = self.tcnt;
        self.tcnt = self.tcnt.wrapping_add(1);
        let matched = self.tcnt;

        // Overflow detection: TCNT wrapped from 0xFFFF to 0x0000
        if old_tcnt == 0xFFFF && matched == 0x0000 {
            self.tsr |= 0x04; // OVF flag (TSR bit 2)
            if self.tier & 0x04 != 0 {
                irqs[2] = Some(());
            }
        }

        // Check GRA and GRB against the pre-clear TCNT value, defer clearing
        let cclr = (self.tcr >> 5) & 0x03;
        let mut clear_tcnt = false;

        if matched == self.gra {
            self.tsr |= 0x01; // IMFA
            if cclr == 1 {
                clear_tcnt = true;
            }
            if self.tier & 0x01 != 0 {
                irqs[0] = Some(());
            }
        }

        if matched == self.grb {
            self.tsr |= 0x02; // IMFB
            if cclr == 2 {
                clear_tcnt = true;
            }
            if self.tier & 0x02 != 0 {
                irqs[1] = Some(());
            }
        }

        if clear_tcnt {
            self.tcnt = 0;
        }

        irqs
    }
}

impl Default for Timer {
    fn default() -> Self {
        Self::new()
    }
}

/// Interrupt vectors for each timer's compare-match A (ITU0-ITU4).
const IMIA_VECTORS: [u8; 5] = [24, 28, ITU2_IMIA_VEC, ITU3_IMIA_VEC, ITU4_IMIA_VEC];
/// Interrupt vectors for each timer's compare-match B (ITU0-ITU4).
const IMIB_VECTORS: [u8; 5] = [25, 29, 33, 37, 41];
/// Interrupt vectors for each timer's overflow (ITU0-ITU4).
const OVI_VECTORS: [u8; 5] = [26, 30, 34, 38, 42];

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

    /// Tick all running timers. Returns interrupt vectors to fire (up to 15:
    /// 5 channels x 3 possible sources — IMIA, IMIB, OVI).
    /// Uses a fixed-size array to avoid heap allocation on every tick.
    pub fn tick(&mut self) -> [Option<u8>; 15] {
        let mut irqs = [None; 15];

        for i in 0..5 {
            if self.tstr & (1 << i) == 0 {
                continue;
            }
            let results = self.timers[i].tick();
            if results[0].is_some() {
                irqs[i * 3] = Some(IMIA_VECTORS[i]);
            }
            if results[1].is_some() {
                irqs[i * 3 + 1] = Some(IMIB_VECTORS[i]);
            }
            if results[2].is_some() {
                irqs[i * 3 + 2] = Some(OVI_VECTORS[i]);
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

    fn imia_fired(irqs: [Option<()>; 3]) -> bool { irqs[0].is_some() }
    fn imib_fired(irqs: [Option<()>; 3]) -> bool { irqs[1].is_some() }
    fn ovi_fired(irqs: [Option<()>; 3]) -> bool { irqs[2].is_some() }

    #[test]
    fn test_timer_prescaler_div1() {
        let mut t = Timer::new();
        t.tcr = 0x00; // phi/1
        t.gra = 0x0003;
        t.tier = 0x01; // IMIEA enabled
        // Ticks: 1,2,3 → compare-match at 3
        assert!(!imia_fired(t.tick()));
        assert!(!imia_fired(t.tick()));
        assert!(imia_fired(t.tick()), "compare-match A fires at TCNT==GRA");
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
            assert!(!imia_fired(t.tick()));
        }
        // 8th tick: TCNT goes from 0 to 1 → match GRA=1
        assert!(imia_fired(t.tick()));
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
        assert!(!imia_fired(t.tick()), "tick returns None when IMIEA disabled");
        assert_eq!(t.tsr & 0x01, 0x01, "IMFA flag still set despite no IRQ");
    }

    #[test]
    fn test_timer_unit_tstr() {
        let mut tu = TimerUnit::new();
        tu.timers[2].tcr = 0x00;
        tu.timers[2].gra = 0x0001;
        tu.timers[2].tier = 0x01;

        // Timer 2 not started yet — IMIA slot for channel 2 is index 6
        tu.tstr = 0x00;
        let irqs = tu.tick();
        assert!(irqs[2 * 3].is_none());

        // Start timer 2 (bit 2)
        tu.tstr = 0x04;
        let irqs = tu.tick();
        assert_eq!(irqs[2 * 3], Some(ITU2_IMIA_VEC));
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
    fn test_timer_compare_match_b_interrupt() {
        // IMIB (TIER bit 1) enabled, GRB match must fire IMIB interrupt
        let mut t = Timer::new();
        t.tcr = 0x00;
        t.grb = 0x0002;
        t.tier = 0x02; // IMIEB enabled
        assert!(!imib_fired(t.tick())); // TCNT=1
        assert!(imib_fired(t.tick()), "IMIB fires when TIER bit 1 set and TCNT==GRB");
    }

    #[test]
    fn test_timer_overflow_flag() {
        // TCNT wraps 0xFFFF → 0x0000 sets OVF (TSR bit 2)
        let mut t = Timer::new();
        t.tcr = 0x00;
        t.tcnt = 0xFFFF;
        let irqs = t.tick();
        assert_eq!(t.tcnt, 0x0000, "TCNT wrapped to 0");
        assert_eq!(t.tsr & 0x04, 0x04, "OVF flag (TSR bit 2) set");
        assert!(!ovi_fired(irqs), "no interrupt without OVIE");
    }

    #[test]
    fn test_timer_overflow_interrupt() {
        // OVIE (TIER bit 2) set — overflow fires interrupt
        let mut t = Timer::new();
        t.tcr = 0x00;
        t.tcnt = 0xFFFF;
        t.tier = 0x04; // OVIE
        let irqs = t.tick();
        assert!(ovi_fired(irqs), "OVI fires when TIER bit 2 set and TCNT wraps");
    }

    #[test]
    fn test_timer_gra_grb_same_value() {
        // When GRA == GRB, both IMFA and IMFB flags must set even if CCLR clears TCNT on GRA
        let mut t = Timer::new();
        t.tcr = 0x20; // CCLR=1 (clear on GRA match), phi/1
        t.gra = 0x0005;
        t.grb = 0x0005;
        t.tier = 0x03; // IMIEA | IMIEB
        for _ in 0..4 {
            t.tick();
        }
        // 5th tick: TCNT=5=GRA=GRB → both match before clear
        let irqs = t.tick();
        assert_eq!(t.tsr & 0x03, 0x03, "both IMFA and IMFB flags set");
        assert!(imia_fired(irqs), "IMIA fires");
        assert!(imib_fired(irqs), "IMIB fires");
        assert_eq!(t.tcnt, 0, "TCNT cleared after both checks (GRA-triggered)");
    }

    #[test]
    fn test_timer_unit_imib_and_ovi_vectors() {
        // Verify TimerUnit maps IMIB and OVI to correct vector numbers.
        let mut tu = TimerUnit::new();
        // ITU2: GRB match → Vec 33
        tu.timers[2].grb = 0x0001;
        tu.timers[2].tier = 0x02; // IMIEB
        // ITU4: overflow → Vec 42
        tu.timers[4].tcnt = 0xFFFF;
        tu.timers[4].tier = 0x04; // OVIE
        tu.tstr = 0x14; // bits 2 and 4
        let irqs = tu.tick();
        assert_eq!(irqs[2 * 3 + 1], Some(33), "ITU2 IMIB = Vec 33");
        assert_eq!(irqs[4 * 3 + 2], Some(42), "ITU4 OVI = Vec 42");
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
        assert!(!imia_fired(t.tick()), "external clock source stops timer");
        assert_eq!(t.tcnt, 0);
    }
}
