/// Memory-mapped I/O bus — routes on-chip I/O register accesses to peripheral models.
///
/// On-chip I/O: 0xFFFF00-0xFFFFFF (256 bytes)
/// Each peripheral owns a range of addresses within this space.

use crate::itu::TimerUnit;
use crate::gpio::GpioPorts;
use crate::wdt::Watchdog;
use crate::adc::Adc;

/// Peripheral bus managing all on-chip I/O devices.
pub struct PeripheralBus {
    pub timers: TimerUnit,
    pub gpio: GpioPorts,
    pub watchdog: Watchdog,
    pub adc: Adc,
}

impl PeripheralBus {
    pub fn new() -> Self {
        Self {
            timers: TimerUnit::new(),
            gpio: GpioPorts::new(),
            watchdog: Watchdog::new(),
            adc: Adc::new(),
        }
    }

    /// Read an on-chip I/O register (address 0xFFFF00-0xFFFFFF).
    /// Returns (value, handled).
    pub fn read_io(&mut self, addr: u32) -> (u8, bool) {
        let offset = (addr & 0xFF) as u8;
        match offset {
            // Timer registers: 0x60-0x9F
            0x60..=0x9F => {
                let val = self.timers.read(offset);
                (val, true)
            }
            // GPIO ports
            0x80..=0x8F | 0xA2..=0xA3 | 0xC7..=0xC8 => {
                let val = self.gpio.read(offset);
                (val, true)
            }
            // Watchdog: 0xA8
            0xA8 => (self.watchdog.read(), true),
            // ADC: 0xE0-0xEF
            0xE0..=0xEF => {
                let val = self.adc.read(offset);
                (val, true)
            }
            _ => (0, false),
        }
    }

    /// Write an on-chip I/O register.
    /// Returns true if handled.
    pub fn write_io(&mut self, addr: u32, val: u8) -> bool {
        let offset = (addr & 0xFF) as u8;
        match offset {
            0x60..=0x9F => {
                self.timers.write(offset, val);
                true
            }
            0x80..=0x8F | 0xA2..=0xA3 | 0xC7..=0xC8 => {
                self.gpio.write(offset, val);
                true
            }
            0xA8 => {
                self.watchdog.write(val);
                true
            }
            0xE0..=0xEF => {
                self.adc.write(offset, val);
                true
            }
            _ => false,
        }
    }
}

impl Default for PeripheralBus {
    fn default() -> Self {
        Self::new()
    }
}
