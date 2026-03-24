//! A/D Converter stub.
//!
//! ADCSR at 0xFFFFE8, ADDRA at 0xFFFFE0.
//! Vec 60 (ADI) fires when conversion completes.
//! Returns fixed mid-range value (0x200) for lamp intensity monitoring.

pub struct Adc {
    pub adcsr: u8,
    pub result: u16,
    /// Conversion complete flag.
    pub conversion_done: bool,
}

impl Adc {
    pub fn new() -> Self {
        Self {
            adcsr: 0,
            result: 0x0200, // Mid-range default
            conversion_done: false,
        }
    }

    pub fn read(&self, offset: u8) -> u8 {
        match offset {
            0xE0 => (self.result >> 8) as u8,  // ADDRAH
            0xE1 => self.result as u8,          // ADDRAL
            0xE8 => self.adcsr,
            _ => 0,
        }
    }

    pub fn write(&mut self, offset: u8, val: u8) {
        if offset == 0xE8 {
            self.adcsr = val;
            // If ADST bit set, start conversion (instant completion)
            if val & 0x20 != 0 {
                self.conversion_done = true;
                self.adcsr |= 0x80; // ADF = conversion complete
            }
        }
    }

    /// Check if ADI interrupt should fire.
    pub fn take_irq(&mut self) -> bool {
        if self.conversion_done && (self.adcsr & 0x40 != 0) {
            // ADIE enabled and conversion done
            self.conversion_done = false;
            true
        } else {
            false
        }
    }
}

impl Default for Adc {
    fn default() -> Self {
        Self::new()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_conversion_trigger() {
        let mut adc = Adc::new();
        // Write ADST (bit 5) to trigger conversion
        adc.write(0xE8, 0x20);
        assert!(adc.conversion_done);
        assert_eq!(adc.adcsr & 0x80, 0x80, "ADF set after conversion");
    }

    #[test]
    fn test_irq_fires_when_adie_enabled() {
        let mut adc = Adc::new();
        // ADST + ADIE (bit 6)
        adc.write(0xE8, 0x60);
        assert!(adc.take_irq(), "IRQ fires with ADIE enabled and conversion done");
        assert!(!adc.conversion_done, "conversion_done cleared after take_irq");
    }

    #[test]
    fn test_irq_no_fire_when_adie_disabled() {
        let mut adc = Adc::new();
        // ADST only (no ADIE)
        adc.write(0xE8, 0x20);
        assert!(!adc.take_irq(), "no IRQ without ADIE");
    }

    #[test]
    fn test_read_result() {
        let adc = Adc::new();
        // Default result = 0x0200
        assert_eq!(adc.read(0xE0), 0x02);  // ADDRAH
        assert_eq!(adc.read(0xE1), 0x00);  // ADDRAL
    }

    #[test]
    fn test_irq_single_shot() {
        let mut adc = Adc::new();
        adc.write(0xE8, 0x60); // ADST + ADIE
        assert!(adc.take_irq());
        assert!(!adc.take_irq(), "second take_irq returns false (no double fire)");
    }
}
