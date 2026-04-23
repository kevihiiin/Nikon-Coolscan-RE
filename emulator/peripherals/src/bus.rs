//! Memory-mapped I/O bus — routes on-chip I/O register accesses to peripheral models.
//!
//! On-chip I/O: 0xFFFF00-0xFFFFFF (256 bytes)
//! Each peripheral owns a range of addresses within this space.

use crate::itu::TimerUnit;
use crate::gpio::GpioPorts;
use crate::wdt::Watchdog;
use crate::adc::Adc;
use crate::dma::DmaController;
use crate::sci::Sci;

/// Peripheral bus managing all on-chip I/O devices.
pub struct PeripheralBus {
    pub timers: TimerUnit,
    pub gpio: GpioPorts,
    pub watchdog: Watchdog,
    pub adc: Adc,
    pub dma: DmaController,
    /// SCI channel 0 (0xFFFFB0-B5). Stub: SSR pinned to 0x84 (TDRE=1) so
    /// firmware TX-ready polling exits immediately. Firmware never blocks on SCI RX.
    pub sci0: Sci,
}

impl PeripheralBus {
    pub fn new() -> Self {
        Self {
            timers: TimerUnit::new(),
            gpio: GpioPorts::new(),
            watchdog: Watchdog::new(),
            adc: Adc::new(),
            dma: DmaController::new(),
            sci0: Sci::new(),
        }
    }

    // Note: read_io/write_io routing methods were removed — the orchestrator
    // accesses peripheral models directly via self.peripherals.timers, .gpio, etc.
    // This avoids the GPIO/timer address range overlap bug that existed in the
    // routing match arms (0x80-0x8B was claimed by both timers and GPIO).
}

impl Default for PeripheralBus {
    fn default() -> Self {
        Self::new()
    }
}
