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
