//! H8/3003 interrupt controller.
//!
//! Interrupt behavior:
//!   - Between each instruction, check for pending interrupts
//!   - If CCR.I = 0 (interrupts enabled), service the highest-priority pending interrupt
//!   - On service: push [CCR:8|PC:24] packed longword (4 bytes), load PC from vector table, set CCR.I = 1
//!   - TRAPA is synchronous (handled in executor, not here)
//!   - No interrupt nesting (all ISRs set I=1 on entry)
//!
//! Vector table: vec_num * 4 = address in flash containing handler address (32-bit BE).

use crate::cpu::{Cpu, CCR_I};
use crate::memory::MemoryBus;

/// Priority levels (0 = lowest, 7 = highest). NMI is always highest.
#[derive(Debug, Clone, Copy, PartialEq, Eq, PartialOrd, Ord)]
pub struct Priority(pub u8);

/// A pending interrupt.
#[derive(Debug, Clone, Copy)]
pub struct PendingInterrupt {
    pub vector: u8,
    pub priority: Priority,
}

/// Interrupt controller state.
pub struct InterruptController {
    /// Queue of pending interrupts, sorted by priority.
    pending: Vec<PendingInterrupt>,
}

impl InterruptController {
    pub fn new() -> Self {
        Self {
            pending: Vec::new(),
        }
    }

    /// Assert an interrupt. Adds to pending queue if not already pending.
    pub fn assert_interrupt(&mut self, vector: u8, priority: Priority) {
        // Don't duplicate
        if !self.pending.iter().any(|p| p.vector == vector) {
            self.pending.push(PendingInterrupt { vector, priority });
            // Keep sorted by priority (highest first)
            self.pending.sort_by(|a, b| b.priority.cmp(&a.priority));
        }
    }

    /// Remove a pending interrupt (e.g., when the source is cleared).
    pub fn clear_interrupt(&mut self, vector: u8) {
        self.pending.retain(|p| p.vector != vector);
    }

    /// Check and service one pending interrupt if conditions are met.
    /// Returns true if an interrupt was serviced.
    pub fn check_and_service(&mut self, cpu: &mut Cpu, bus: &mut MemoryBus) -> bool {
        // If interrupts are masked, don't service
        if cpu.interrupt_masked() {
            return false;
        }

        // If sleeping, any interrupt wakes up
        if cpu.sleeping && !self.pending.is_empty() {
            cpu.sleeping = false;
        }

        // Take the highest-priority pending interrupt
        if let Some(irq) = self.pending.first().copied() {
            self.pending.remove(0);
            // H8/300H Advanced Mode: push [CCR:8][PC:24] as single longword
            let frame = ((cpu.ccr as u32) << 24) | (cpu.pc & 0x00FF_FFFF);
            let sp = cpu.sp() - 4;
            cpu.set_sp(sp);
            bus.write_long(sp, frame);

            // Set I flag to mask further interrupts
            cpu.set_flag(CCR_I, true);

            // Load PC from vector table
            let vec_addr = irq.vector as u32 * 4;
            let handler = bus.read_long(vec_addr);
            cpu.pc = handler & 0x00FF_FFFF;

            if bus.trace_enabled {
                log::info!(
                    "IRQ: vec={} (0x{:03X}) -> handler 0x{:06X}",
                    irq.vector, vec_addr, cpu.pc
                );
            }

            return true;
        }

        false
    }

    /// Check if any interrupts are pending.
    pub fn has_pending(&self) -> bool {
        !self.pending.is_empty()
    }

    /// Get count of pending interrupts.
    pub fn pending_count(&self) -> usize {
        self.pending.len()
    }
}

impl Default for InterruptController {
    fn default() -> Self {
        Self::new()
    }
}

/// Known interrupt vectors for the Coolscan V firmware.
pub mod vectors {
    use super::Priority;

    pub const RESET: u8 = 0;
    pub const TRAP0: u8 = 8;       // TRAPA #0 — context switch
    pub const IRQ1: u8 = 13;       // ISP1581 USB
    pub const IRQ3: u8 = 15;       // Motor encoder
    pub const IRQ4: u8 = 16;       // Adapter/status
    pub const IRQ5: u8 = 17;       // Shared with IRQ4
    pub const IRQ7: u8 = 19;       // Motor step completion
    pub const IMIA2: u8 = 32;      // ITU2 compare-match A (motor)
    pub const IMIA3: u8 = 36;      // ITU3 compare-match A (DMA burst)
    pub const IMIA4: u8 = 40;      // ITU4 compare-match A (system tick)
    pub const DEND0B: u8 = 45;     // DMA ch0B completion
    pub const DEND1B: u8 = 47;     // DMA ch1B completion
    pub const VEC49: u8 = 49;      // CCD line readout
    pub const ADI: u8 = 60;        // A/D converter done

    pub const PRIORITY_HIGH: Priority = Priority(6);
    pub const PRIORITY_MEDIUM: Priority = Priority(4);
    pub const PRIORITY_LOW: Priority = Priority(2);
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_interrupt_masked() {
        let mut ic = InterruptController::new();
        let mut cpu = Cpu::new();
        let mut bus = MemoryBus::new();
        cpu.set_flag(CCR_I, true); // Interrupts masked
        cpu.set_sp(0x410000);

        ic.assert_interrupt(13, Priority(6));
        assert!(!ic.check_and_service(&mut cpu, &mut bus)); // Should not fire
        assert!(ic.has_pending()); // Still pending
    }

    #[test]
    fn test_interrupt_fires() {
        let mut ic = InterruptController::new();
        let mut cpu = Cpu::new();
        let mut bus = MemoryBus::new();
        cpu.set_flag(CCR_I, false); // Interrupts enabled
        cpu.pc = 0x1234;
        cpu.ccr = 0x00;
        cpu.set_sp(0x410000);

        // Set up vector table: vec 13 (IRQ1) -> 0x014E00
        bus.flash_write_long(13 * 4, 0x00014E00);

        ic.assert_interrupt(13, Priority(6));
        assert!(ic.check_and_service(&mut cpu, &mut bus));
        assert_eq!(cpu.pc, 0x014E00);
        assert!(cpu.interrupt_masked());
        assert_eq!(cpu.sp(), 0x410000 - 4);
    }

    #[test]
    fn test_priority_ordering() {
        let mut ic = InterruptController::new();
        ic.assert_interrupt(40, Priority(2)); // Low priority
        ic.assert_interrupt(13, Priority(6)); // High priority
        ic.assert_interrupt(32, Priority(4)); // Medium

        let mut cpu = Cpu::new();
        let mut bus = MemoryBus::new();
        cpu.set_flag(CCR_I, false);
        cpu.set_sp(0x410000);
        bus.flash_write_long(13 * 4, 0x00014E00);
        bus.flash_write_long(32 * 4, 0x00010B76);
        bus.flash_write_long(40 * 4, 0x00010A16);

        // Should service highest priority first (vec 13)
        assert!(ic.check_and_service(&mut cpu, &mut bus));
        assert_eq!(cpu.pc, 0x014E00);
    }

    #[test]
    fn test_wake_from_sleep() {
        let mut ic = InterruptController::new();
        let mut cpu = Cpu::new();
        let mut bus = MemoryBus::new();
        cpu.sleeping = true;
        cpu.set_flag(CCR_I, false);
        cpu.set_sp(0x410000);
        bus.flash_write_long(40 * 4, 0x00010A16);

        ic.assert_interrupt(40, Priority(2));
        cpu.pc = 0x1000; // Set a valid PC to be pushed
        assert!(ic.check_and_service(&mut cpu, &mut bus));
        assert!(!cpu.sleeping);
    }
}
