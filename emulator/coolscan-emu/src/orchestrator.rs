/// Emulator orchestrator — wires CPU, memory, peripherals, and bridges together.

use h8300h_core::cpu::Cpu;
use h8300h_core::decode;
use h8300h_core::execute;
use h8300h_core::interrupt::{InterruptController, Priority, vectors};
use h8300h_core::memory::MemoryBus;

use peripherals::asic::Asic;
use peripherals::isp1581::Isp1581;
use peripherals::bus::PeripheralBus;

use crate::config::Config;

pub struct Emulator {
    pub cpu: Cpu,
    pub bus: MemoryBus,
    pub irq: InterruptController,
    pub asic: Asic,
    pub isp1581: Isp1581,
    pub peripherals: PeripheralBus,
    trace: bool,
    context_initialized: bool,
}

impl Emulator {
    pub fn new(firmware: &[u8], config: &Config) -> Self {
        let mut bus = MemoryBus::new();
        bus.load_firmware(firmware);
        bus.trace_enabled = config.trace;

        let mut cpu = Cpu::new();
        let reset_vector = bus.read_reset_vector();
        cpu.reset(reset_vector);

        let mut peripherals = PeripheralBus::new();
        peripherals.gpio.set_adapter(config.adapter);
        peripherals.watchdog.enabled = config.watchdog;

        // Pre-install trampolines in on-chip RAM.
        // The firmware normally installs these during cold boot (0x0204C4-0x0205F7),
        // but we take the warm-boot path (ASIC ready). Without trampolines,
        // TRAPA #0 jumps to 0xFFFD10 which would be NOPs.
        let trampolines: &[(u32, u32)] = &[
            (0xFFFD10, 0x010876),  // Vec 8:  TRAP#0 → context switch
            (0xFFFD14, 0x033444),  // Vec 15: IRQ3 → encoder
            (0xFFFD18, 0x014D4A),  // Vec 16/17: IRQ4/5 → adapter
            (0xFFFD1C, 0x010B76),  // Vec 32: IMIA2 → motor dispatcher
            (0xFFFD20, 0x02D536),  // Vec 36: IMIA3 → DMA burst
            (0xFFFD24, 0x010A16),  // Vec 40: IMIA4 → system tick
            (0xFFFD28, 0x02CEF2),  // Vec 45: DEND0B → DMA ch0 done
            (0xFFFD2C, 0x02E10A),  // Vec 47: DEND1B → DMA ch1 done
            (0xFFFD30, 0x02E9F8),  // Vec 49: CCD line readout
            (0xFFFD34, 0x02EDDE),  // Vec 60: ADI → A/D done
            (0xFFFD38, 0x02B544),  // Vec 19: IRQ7 → motor step
            (0xFFFD3C, 0x014E00),  // Vec 13: IRQ1 → ISP1581 USB
        ];
        for &(ram_addr, handler) in trampolines {
            // JMP @aa:24 = 5A [addr23:16] [addr15:8] [addr7:0]
            bus.write_byte(ram_addr, 0x5A);
            bus.write_byte(ram_addr + 1, (handler >> 16) as u8);
            bus.write_byte(ram_addr + 2, (handler >> 8) as u8);
            bus.write_byte(ram_addr + 3, handler as u8);
        }
        log::info!("Pre-installed {} trampolines in on-chip RAM", trampolines.len());

        // Context system will be initialized just before the first TRAPA.
        // We can't do it at startup because the RAM test overwrites 0x400000-0x420000.

        Self {
            cpu,
            bus,
            irq: InterruptController::new(),
            asic: Asic::new(),
            isp1581: Isp1581::new(),
            peripherals,
            trace: config.trace,
            context_initialized: false,
        }
    }

    pub fn reset_vector(&self) -> u32 {
        self.cpu.pc
    }

    /// Run the emulator for up to max_instructions.
    pub fn run(&mut self, max_instructions: u64) {
        let mut last_milestone_pc = 0u32;

        for i in 0..max_instructions {
            if self.cpu.sleeping {
                // Check for pending interrupts to wake up
                self.check_peripherals();
                if !self.irq.has_pending() {
                    continue;
                }
            }

            // Check and service interrupts
            self.irq.check_and_service(&mut self.cpu, &mut self.bus);

            // Decode
            let decoded = decode::decode(&mut self.bus, self.cpu.pc);

            if self.trace {
                let disasm = decode::disassemble(&decoded.insn);
                log::trace!(
                    "[{:06X}] {:16}  ; ER0={:08X} ER1={:08X} SP={:08X} CCR={:02X}",
                    self.cpu.pc, disasm,
                    self.cpu.read_er(0), self.cpu.read_er(1),
                    self.cpu.sp(), self.cpu.ccr
                );
            }

            // Handle unknown instructions
            if let decode::Instruction::Unknown(w) = &decoded.insn {
                log::error!(
                    "HALT: Unknown instruction 0x{:04X} at PC=0x{:06X} after {} instructions",
                    w, self.cpu.pc, i
                );
                // Dump stack to find return addresses
                let sp = self.cpu.sp();
                log::error!("Stack dump (SP=0x{:06X}):", sp);
                for j in 0..8 {
                    let addr = sp + j * 4;
                    let val = self.bus.read_long(addr);
                    log::error!("  [{:06X}] = 0x{:08X}", addr, val);
                }
                self.dump_state();
                return;
            }

            // Just-in-time context initialization before first TRAPA.
            // The context switch handler at 0x010876 reads context state from RAM
            // at 0x400764 (index) and 0x400766/0x40076A (saved SPs).
            // We initialize these just before the first context switch because
            // the RAM test (which runs earlier) would overwrite startup values.
            if !self.context_initialized {
                if let decode::Instruction::Trapa(0) = &decoded.insn {
                    self.context_initialized = true;
                    // Context B needs a valid stack with a return frame.
                    // Set up context B SP at 0x40076A pointing to a stack
                    // with a minimal frame that RTE will pop (CCR + PC).
                    // Context B entry: 0x029B16 (from our KB).
                    let ctx_b_sp = 0x0040D000u32;
                    // Build a fake stack frame at ctx_b_sp for RTE:
                    // [SP+0] = CCR (as word, 0x0000 = interrupts enabled)
                    // [SP+2] = return PC (0x029B16 = Context B entry point)
                    // Plus register save area (7 regs * 4 bytes = 28 bytes)
                    // Total frame = 6 (RTE) + 28 (registers) = 34 bytes
                    let frame_sp = ctx_b_sp - 34;
                    // Write saved registers (all 0)
                    for j in 0..7 {
                        self.bus.write_long(frame_sp + j * 4, 0);
                    }
                    // Write RTE frame at end of saved registers
                    self.bus.write_word(frame_sp + 28, 0x0000); // CCR
                    self.bus.write_long(frame_sp + 30, 0x029B16); // PC = Context B entry
                    // Store context B's SP in save area
                    self.bus.write_long(0x40076A, frame_sp);
                    // Context A index = 0 (current)
                    self.bus.write_word(0x400764, 0x0000);
                    log::info!(
                        "JIT context init: Context B SP=0x{:06X}, entry=0x029B16",
                        frame_sp
                    );
                }
            }

            // Execute
            let insn_pc = self.cpu.pc;
            let new_pc = execute::execute(
                &mut self.cpu,
                &mut self.bus,
                &decoded.insn,
                insn_pc,
                decoded.len,
            );

            // Sanity checks
            if new_pc < 0x000100 || (new_pc >= 0x080000 && new_pc < 0x200000) {
                log::error!(
                    "HALT: PC went out of range to 0x{:06X} after executing {:?} at 0x{:06X} (insn #{})",
                    new_pc, decode::disassemble(&decoded.insn), insn_pc, i
                );
                self.dump_state();
                return;
            }
            if self.cpu.sp() & 1 != 0 && !matches!(decoded.insn, decode::Instruction::Nop) {
                log::warn!(
                    "Odd SP=0x{:06X} after {:?} at 0x{:06X} (insn #{})",
                    self.cpu.sp(), decode::disassemble(&decoded.insn), insn_pc, i
                );
            }

            self.cpu.pc = new_pc;
            self.cpu.cycle_count += 1;

            // Sync peripheral writes (on-chip I/O written by CPU goes to peripherals)
            self.sync_peripherals();

            // Tick peripherals
            self.check_peripherals();

            // Log milestones
            match self.cpu.pc {
                0x020334 if last_milestone_pc < 0x020334 => {
                    log::info!("MILESTONE: Reached main entry point (0x020334) after {} instructions", i);
                    last_milestone_pc = self.cpu.pc;
                }
                0x020374 if last_milestone_pc < 0x020374 => {
                    log::info!("MILESTONE: Past I/O init table (0x020374) after {} instructions", i);
                    last_milestone_pc = self.cpu.pc;
                }
                0x020796 if last_milestone_pc < 0x020796 => {
                    log::info!(
                        "MILESTONE: Delay loop setup (0x020796) after {} instructions. ER3={:08X} ER4={:08X}",
                        i, self.cpu.read_er(3), self.cpu.read_er(4)
                    );
                    last_milestone_pc = self.cpu.pc;
                }
                0x0207A4 if last_milestone_pc < 0x0207A4 => {
                    log::info!(
                        "MILESTONE: First delay loop iteration (0x0207A4). ER4={:08X}",
                        self.cpu.read_er(4)
                    );
                    last_milestone_pc = self.cpu.pc;
                }
                0x0205FC if last_milestone_pc < 0x0205FC => {
                    log::info!("MILESTONE: Past trampoline install (0x0205FC) after {} instructions", i);
                    last_milestone_pc = self.cpu.pc;
                }
                0x020608 if last_milestone_pc < 0x020608 => {
                    log::info!("MILESTONE: Interrupts enabled (ANDC #0x7F at 0x020608) after {} instructions. CCR={:02X}", i, self.cpu.ccr);
                    last_milestone_pc = self.cpu.pc;
                }
                0x0207F2 if last_milestone_pc < 0x0207F2 => {
                    log::info!("MILESTONE: Reached Context A main loop (0x0207F2) after {} instructions", i);
                    last_milestone_pc = self.cpu.pc;
                }
                _ => {}
            }
        }

        log::info!(
            "Emulation stopped after {} instructions. PC=0x{:06X}",
            max_instructions, self.cpu.pc
        );
        self.dump_state();
    }

    /// Sync peripheral models with memory bus state.
    fn sync_peripherals(&mut self) {
        // Sync ASIC: check if memory bus has new writes, process through ASIC model
        // The ASIC model manages side-effects (status bits, DMA triggers)
        // Check if ASIC master enable was written
        let master = self.bus.asic_reg(0x0001);
        if master != self.asic.read(0x0001) {
            log::debug!("ASIC master enable sync: bus=0x{:02X} model=0x{:02X}", master, self.asic.read(0x0001));
            self.asic.write(0x0001, master);
            // Write back any derived values
            self.bus.set_asic_reg(0x0041, self.asic.read(0x0041));
            log::debug!("ASIC 0x200041 now = 0x{:02X}", self.bus.asic_reg(0x0041));
        }
        // Always sync status registers back
        self.bus.set_asic_reg(0x0002, self.asic.read(0x0002));
        self.asic.tick();
    }

    /// Check peripherals for interrupt conditions.
    fn check_peripherals(&mut self) {
        // Timer interrupts
        let timer_irqs = self.peripherals.timers.tick();
        for vec in timer_irqs {
            self.irq.assert_interrupt(vec, match vec {
                vectors::IMIA4 => vectors::PRIORITY_LOW,
                vectors::IMIA2 | vectors::IMIA3 => vectors::PRIORITY_MEDIUM,
                _ => vectors::PRIORITY_MEDIUM,
            });
        }

        // ISP1581 USB interrupt
        if self.isp1581.irq_pending {
            self.irq.assert_interrupt(vectors::IRQ1, vectors::PRIORITY_HIGH);
        }

        // ADC interrupt
        if self.peripherals.adc.take_irq() {
            self.irq.assert_interrupt(vectors::ADI, vectors::PRIORITY_LOW);
        }

        // CCD trigger → Vec 49
        if self.asic.ccd_trigger_pending {
            self.asic.ccd_trigger_pending = false;
            self.irq.assert_interrupt(vectors::VEC49, vectors::PRIORITY_MEDIUM);
        }
    }

    fn dump_state(&self) {
        log::info!("=== CPU State ===");
        log::info!("PC=0x{:06X}  CCR=0x{:02X} (I={} Z={} N={} C={})",
            self.cpu.pc, self.cpu.ccr,
            self.cpu.interrupt_masked() as u8,
            self.cpu.zero() as u8,
            self.cpu.negative() as u8,
            self.cpu.carry() as u8);
        for i in 0..8 {
            log::info!("ER{}=0x{:08X}", i, self.cpu.read_er(i));
        }
        log::info!("Instructions executed: {}", self.cpu.cycle_count);
        log::info!("Unmapped reads: {}, writes: {}",
            self.bus.unmapped_reads, self.bus.unmapped_writes);
    }
}
