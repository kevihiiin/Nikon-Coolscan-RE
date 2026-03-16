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

        // Set Port 7 override for adapter detection reads.
        // Address 0xFFFF8E is shared with ITU4 TIER, so we use a separate field.
        bus.port7_override = peripherals.gpio.port_7_input;

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

        // Pre-copy USB fast-path code from flash to RAM.
        // The firmware normally does this during init but our warm-boot path skips it.
        // Source: flash 0x124BA, Dest: RAM 0x4010A0, Size: 414 bytes.
        // Entry point: 0x40115C (offset 0xBC into the block).
        // This MUST happen before the RAM test to survive, but the RAM test only
        // writes 0x55AA patterns and then verifies — it doesn't zero the area.
        // Actually, the RAM test DOES overwrite this area. But the firmware re-copies
        // later during init. For warm boot, we copy AFTER the JIT context init
        // (which happens after RAM test) to ensure persistence.
        // We'll do the actual copy in the JIT init block.

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
                    // Pre-start ITU4 (system tick timer) via model directly.
                    // Warm-boot path skips timer start code. Without ITU4 running,
                    // the system tick at 0x40076E never increments and the firmware
                    // hangs in a polling loop at 0x0352B0 waiting for time to advance.
                    // Configure via timer model to avoid I/O address conflicts
                    // (0xFFFF8E is shared between Port 7 and ITU4 TIER).
                    // Configure ITU4 in BOTH model AND bus so sync doesn't overwrite.
                    // ITU4 base in onchip_io: 0x8C
                    {
                        let t4 = &mut self.peripherals.timers.timers[4];
                        t4.tcr = 0xA3;   // Internal clock φ/8, clear on GRA match
                        t4.tier = 0x01;   // IMIEA enabled (compare-match A interrupt)
                        t4.gra = 0x2000;  // Compare value — fires every 8192 timer ticks (~32K insns)
                        t4.tcnt = 0;
                    }
                    // Mirror to bus (ITU4 base = 0x8C)
                    self.bus.onchip_io[0x8C] = 0xA3; // TCR4
                    // Skip 0x8E (TIER4) — conflicts with Port 7, model handles directly
                    self.bus.onchip_io[0x92] = 0x20; // GRA4H
                    self.bus.onchip_io[0x93] = 0x00; // GRA4L → GRA = 0x2000
                    self.peripherals.timers.tstr |= 0x10; // Start ITU4 (bit 4)
                    self.bus.onchip_io[0x60] |= 0x10;     // Mirror TSTR to bus
                    log::info!("JIT: Started ITU4 system tick (TCR=0xA3, GRA=0x2000, TSTR bit 4)");

                    // Pre-copy USB fast-path code from flash to RAM.
                    // Flash 0x124BA → RAM 0x4010A0, 414 bytes.
                    // This code handles USB endpoint data transfer in the ISR fast path.
                    for j in 0..414u32 {
                        let byte = self.bus.read_byte(0x124BA + j);
                        self.bus.write_byte(0x4010A0 + j, byte);
                    }
                    log::info!("JIT: Copied 414-byte USB fast-path code to RAM 0x4010A0");

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

            // Sanity checks — PC should only be in valid code regions:
            // Flash: 0x000100-0x07FFFF, RAM: 0x400000-0x41FFFF,
            // On-chip RAM: 0xFFFB80-0xFFFEFF (trampolines)
            let pc_valid = (0x000100..=0x07FFFF).contains(&new_pc)
                || (0x400000..=0x41FFFF).contains(&new_pc)
                || (0xFFFB80..=0xFFFEFF).contains(&new_pc);
            if !pc_valid {
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
                    // Dump timer registers after init
                    log::info!("  TSTR(0x60)=0x{:02X}", self.bus.onchip_io[0x60]);
                    for t in 0..5u8 {
                        let base: usize = match t {
                            0 => 0x64, 1 => 0x6E, 2 => 0x78, 3 => 0x82, 4 => 0x8C, _ => 0,
                        };
                        let tcr = self.bus.onchip_io[base];
                        let tier = self.bus.onchip_io[base + 2];
                        let gra = ((self.bus.onchip_io[base + 6] as u16) << 8)
                            | self.bus.onchip_io[base + 7] as u16;
                        if tcr != 0 || tier != 0 {
                            log::info!("  ITU{}: TCR=0x{:02X} TIER=0x{:02X} GRA=0x{:04X}", t, tcr, tier, gra);
                        }
                    }
                    log::info!("  Port7(0x8E)=0x{:02X}", self.bus.onchip_io[0x8E]);
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
    /// Called after every instruction to propagate I/O register writes to models
    /// and model outputs back to the bus.
    fn sync_peripherals(&mut self) {
        // --- Timer sync ---
        // The firmware writes timer registers (0xFFFF60-0xFFFF95) via the memory bus.
        // We sync key registers to the timer model each cycle.
        // TSTR (0xFFFF60) — timer start bits
        let tstr = self.bus.onchip_io[0x60];
        if tstr != self.peripherals.timers.tstr {
            self.peripherals.timers.tstr = tstr;
        }
        // Sync per-timer registers when that timer's TSTR bit is set
        for timer_idx in 0..5u8 {
            if tstr & (1 << timer_idx) != 0 {
                let base: usize = match timer_idx {
                    0 => 0x64,
                    1 => 0x6E,
                    2 => 0x78,
                    3 => 0x82,
                    4 => 0x8C,
                    _ => unreachable!(),
                };
                let t = &mut self.peripherals.timers.timers[timer_idx as usize];
                t.tcr = self.bus.onchip_io[base];
                t.tior = self.bus.onchip_io[base + 1];
                // TIER at base+2: skip for ITU4 (0x8E conflicts with Port 7 GPIO)
                if timer_idx != 4 {
                    t.tier = self.bus.onchip_io[base + 2];
                }
                // GRA = big-endian 16-bit at base+6..base+7
                t.gra = ((self.bus.onchip_io[base + 6] as u16) << 8)
                    | self.bus.onchip_io[base + 7] as u16;
                t.grb = ((self.bus.onchip_io[base + 8] as u16) << 8)
                    | self.bus.onchip_io[base + 9] as u16;
                // Sync TSR: firmware clears flags by writing 0 to bits.
                // Read bus TSR and AND with model TSR (bus clear takes effect).
                let bus_tsr = self.bus.onchip_io[base + 3];
                t.tsr &= bus_tsr;
                // Write back TCNT (model increments it)
                self.bus.onchip_io[base + 3] = t.tsr;
                self.bus.onchip_io[base + 4] = (t.tcnt >> 8) as u8;
                self.bus.onchip_io[base + 5] = t.tcnt as u8;
            }
        }

        // --- GPIO sync ---
        // Port 7 at 0xFFFF8E CONFLICTS with ITU4 TIER at the same address.
        // Resolution: Port 7 is read-only input. We handle it as a special case
        // in the memory bus read path instead of writing to onchip_io[0x8E].
        // The firmware reads Port 7 via BILD/BTST on @0x8E:8 or MOV.B @0xFF8E:16.
        // We intercept these reads in the memory bus rather than corrupting the timer register.
        //
        // Port A (0xFFFFA2/A3) — no conflict, sync directly
        self.peripherals.gpio.port_a_ddr = self.bus.onchip_io[0xA2];
        self.peripherals.gpio.port_a_dr = self.bus.onchip_io[0xA3];
        // Port 4 (0xFFFF85) — lamp control, no conflict
        let p4 = self.bus.onchip_io[0x85];
        if p4 != self.peripherals.gpio.port_4_dr {
            self.peripherals.gpio.port_4_dr = p4;
            self.peripherals.gpio.lamp_on = p4 & 0x01 == 0;
        }

        // --- ASIC sync ---
        let master = self.bus.asic_reg(0x0001);
        if master != self.asic.read(0x0001) {
            self.asic.write(0x0001, master);
            self.bus.set_asic_reg(0x0041, self.asic.read(0x0041));
        }
        self.bus.set_asic_reg(0x0002, self.asic.read(0x0002));
        self.asic.tick();
    }

    /// Check peripherals for interrupt conditions.
    fn check_peripherals(&mut self) {
        // Timer interrupts
        let timer_irqs = self.peripherals.timers.tick();
        for vec in timer_irqs {
            if vec == vectors::IMIA4 && !self.irq.has_pending() {
                log::debug!("ITU4 compare-match → Vec 40 queued (CCR.I={})", self.cpu.interrupt_masked() as u8);
            }
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
