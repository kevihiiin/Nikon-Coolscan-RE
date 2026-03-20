//! Watchdog Timer stub.
//!
//! Address 0xFFFFA8 (TCSR via on-chip I/O).
//! Firmware writes 0x5A00 during every context switch to reset the watchdog.
//! Disabled by default in emulator.

pub struct Watchdog {
    pub enabled: bool,
    pub counter: u32,
    pub fed: bool,
}

impl Watchdog {
    pub fn new() -> Self {
        Self {
            enabled: false,
            counter: 0,
            fed: true,
        }
    }

    pub fn read(&self) -> u8 {
        0 // TCSR value — always report OK
    }

    pub fn write(&mut self, val: u8) {
        // Writing 0x5A to high byte of TCSR = feed watchdog
        // (The firmware writes 0x5A00 as a 16-bit write)
        if val == 0x5A {
            self.fed = true;
            self.counter = 0;
        }
    }

    pub fn tick(&mut self) -> bool {
        if !self.enabled {
            return false;
        }
        self.counter += 1;
        // Timeout after ~65536 ticks if not fed
        if self.counter > 65535 && !self.fed {
            return true; // Reset!
        }
        self.fed = false;
        false
    }
}

impl Default for Watchdog {
    fn default() -> Self {
        Self::new()
    }
}
