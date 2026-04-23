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
        // Timeout after ~65536 ticks if not fed. Auto-rearm so a single
        // firmware hang produces one event, not a flood of per-instruction
        // spam. The caller (orchestrator) is responsible for halting or
        // surfacing the timeout if it cares.
        if self.counter > 65535 && !self.fed {
            self.counter = 0;
            self.fed = true;
            return true;
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

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_disabled_never_fires() {
        let mut wdt = Watchdog::new();
        wdt.enabled = false;
        for _ in 0..1000 {
            assert!(!wdt.tick());
        }
    }

    #[test]
    fn test_feed_resets_counter() {
        let mut wdt = Watchdog::new();
        wdt.enabled = true;
        for _ in 0..1000 {
            wdt.tick();
        }
        assert!(wdt.counter > 0);
        wdt.write(0x5A); // feed
        assert_eq!(wdt.counter, 0);
        assert!(wdt.fed);
    }

    #[test]
    fn test_timeout_fires() {
        let mut wdt = Watchdog::new();
        wdt.enabled = true;
        for i in 0..70000 {
            if wdt.tick() {
                assert!(i >= 65535, "timeout fires after 65535 ticks");
                return;
            }
        }
        panic!("watchdog did not fire within 70000 ticks");
    }

    #[test]
    fn test_feed_prevents_timeout() {
        let mut wdt = Watchdog::new();
        wdt.enabled = true;
        for i in 0..200000 {
            if i % 60000 == 0 {
                wdt.write(0x5A); // feed periodically
            }
            assert!(!wdt.tick(), "should not fire when fed regularly");
        }
    }

    #[test]
    fn test_timeout_rearms_not_spammy() {
        // After a timeout fires once, subsequent ticks must not keep firing.
        // Without auto-rearm, a single hang would log millions of identical
        // timeout warnings (orchestrator calls tick() every instruction).
        let mut wdt = Watchdog::new();
        wdt.enabled = true;
        let mut fires = 0;
        for _ in 0..200_000 {
            if wdt.tick() {
                fires += 1;
            }
        }
        // 200K ticks, no feeds → should fire ~3 times (once per 65K window),
        // not 134K+ times (every tick after first timeout).
        assert!((2..=5).contains(&fires),
            "timeout should fire periodically, not spam every tick (fires={})", fires);
    }

    #[test]
    fn test_wrong_feed_value_ignored() {
        let mut wdt = Watchdog::new();
        wdt.enabled = true;
        for _ in 0..1000 {
            wdt.tick();
        }
        let before = wdt.counter;
        wdt.write(0x42); // wrong value — should NOT feed
        assert_eq!(wdt.counter, before, "counter unchanged by non-0x5A write");
    }
}
