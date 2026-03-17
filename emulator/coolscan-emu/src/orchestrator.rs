/// Emulator orchestrator — wires CPU, memory, peripherals, and bridges together.

use h8300h_core::cpu::Cpu;
use h8300h_core::decode;
use h8300h_core::execute;
use h8300h_core::interrupt::{InterruptController, vectors};
use h8300h_core::memory::MemoryBus;

use peripherals::asic::Asic;
use peripherals::isp1581::Isp1581;
use peripherals::bus::PeripheralBus;

use std::net::TcpListener;

use crate::config::Config;

pub struct Emulator {
    pub cpu: Cpu,
    pub bus: MemoryBus,
    pub irq: InterruptController,
    pub asic: Asic,
    pub peripherals: PeripheralBus,
    trace: bool,
    context_initialized: bool,
    /// Context switch tracing: last known good context save area values.
    last_ctx_a_sp: u32,
    last_ctx_b_sp: u32,
    /// Count of context switches observed (for debugging).
    ctx_switch_count: u64,
    /// Set of one-shot milestones already logged (by address).
    milestones_seen: std::collections::HashSet<u32>,
    /// TCP listener for the bridge (non-blocking).
    tcp_listener: Option<TcpListener>,
    /// Connected TCP client stream.
    tcp_client: Option<std::net::TcpStream>,
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
        bus.port7_override = Some(peripherals.gpio.port_7_input);

        // Install ISP1581 device model into the memory bus for behavioral I/O.
        bus.isp1581_device = Some(Box::new(Isp1581::new()));
        log::info!("ISP1581 device model installed in memory bus");

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

        // Context system and flash NOP patches are applied JIT (just before first TRAPA #0)
        // because the RAM test overwrites 0x400000-0x420000 during early boot.

        // Set up TCP listener if port configured
        let tcp_listener = if config._tcp_port > 0 {
            match TcpListener::bind(format!("127.0.0.1:{}", config._tcp_port)) {
                Ok(listener) => {
                    if let Err(e) = listener.set_nonblocking(true) {
                        log::error!("Failed to set TCP listener non-blocking: {}. Emulator may hang.", e);
                    }
                    log::info!("TCP bridge listening on port {}", config._tcp_port);
                    Some(listener)
                }
                Err(e) => {
                    log::warn!("Failed to bind TCP port {}: {}", config._tcp_port, e);
                    None
                }
            }
        } else {
            None
        };

        Self {
            cpu,
            bus,
            irq: InterruptController::new(),
            asic: Asic::new(),
            peripherals,
            trace: config.trace,
            context_initialized: false,
            last_ctx_a_sp: 0,
            last_ctx_b_sp: 0,
            ctx_switch_count: 0,
            milestones_seen: std::collections::HashSet::new(),
            tcp_listener,
            tcp_client: None,
        }
    }

    pub fn reset_vector(&self) -> u32 {
        self.cpu.pc
    }

    /// Run the emulator for up to max_instructions.
    pub fn run(&mut self, max_instructions: u64) {
        for i in 0..max_instructions {
            if self.cpu.sleeping {
                self.check_peripherals();
                if !self.irq.has_pending() {
                    continue;
                }
            }

            self.irq.check_and_service(&mut self.cpu, &mut self.bus);

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

            if let decode::Instruction::Unknown(w) = &decoded.insn {
                log::error!(
                    "HALT: Unknown instruction 0x{:04X} at PC=0x{:06X} after {} instructions",
                    w, self.cpu.pc, i
                );
                self.dump_stack();
                self.dump_state();
                return;
            }

            // JIT init: context system + flash patches, triggered before first TRAPA #0.
            if !self.context_initialized {
                if let decode::Instruction::Trapa(0) = &decoded.insn {
                    self.jit_context_init();
                    self.apply_flash_nop_patches();
                }
            }

            let pre_exec_pc = self.cpu.pc;

            // Context switch tracing (entry to handler at 0x010876)
            if pre_exec_pc == 0x010876 {
                self.trace_context_switch(i);
            }
            // Periodic save area integrity check
            if i > 0 && i % 10000 == 0 {
                self.check_context_save_area(i, pre_exec_pc);
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

            if !Self::is_valid_pc(new_pc) {
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

            self.sync_peripherals();
            self.check_peripherals();

            if i % 1000 == 0 {
                self.poll_tcp();
            }

            self.handle_oneshot_actions(pre_exec_pc, i);
            self.log_milestone(i);
        }

        log::info!(
            "Emulation stopped after {} instructions. PC=0x{:06X}",
            max_instructions, self.cpu.pc
        );
        self.dump_state();
    }

    // --- JIT initialization (deferred until first TRAPA #0) ---

    /// Initialize the context switch system in RAM.
    ///
    /// The context switch handler at 0x010876 reads context state from RAM
    /// at 0x400764 (index) and 0x400766/0x40076A (saved SPs).
    /// We defer this until the first TRAPA because the RAM test (which runs
    /// earlier) would overwrite any values set at startup.
    fn jit_context_init(&mut self) {
        self.context_initialized = true;

        // Context B stack frame for RTE:
        // H8/300H Advanced Mode: exception frame = [CCR:8|PC:24] packed longword
        // Plus register save area (7 regs * 4 bytes = 28 bytes)
        // Total frame = 4 (RTE) + 28 (registers) = 32 bytes
        let ctx_b_sp: u32 = 0x0040D000;
        let frame_sp = ctx_b_sp - 32;

        // Write saved registers (all 0)
        for j in 0..7 {
            self.bus.write_long(frame_sp + j * 4, 0);
        }
        // Write packed RTE frame: [CCR=0x00][PC=0x029B16] (Context B entry)
        self.bus.write_long(frame_sp + 28, 0x00029B16);
        self.bus.write_long(0x40076A, frame_sp);   // Context B saved SP
        self.bus.write_word(0x400764, 0x0000);      // Context A is current (index 0)

        // Start ITU4 system tick timer.
        // Warm-boot path skips the timer start code. Without ITU4 running,
        // the system tick at 0x40076E never increments and the firmware
        // hangs in a polling loop at 0x0352B0.
        // Configure in BOTH model AND bus so sync doesn't overwrite.
        // ITU4 base in onchip_io: 0x92 (NOT 0x8C -- there's a gap after ITU3).
        {
            let t4 = &mut self.peripherals.timers.timers[4];
            t4.tcr = 0xA3;    // Internal clock phi/8, clear on GRA match
            t4.tier = 0x01;    // IMIEA enabled (compare-match A interrupt)
            t4.gra = 0x2000;   // fires every 8192 timer ticks (~32K insns)
            t4.tcnt = 0;
        }
        self.bus.onchip_io[0x92] = 0xA3;          // TCR4
        self.bus.onchip_io[0x94] = 0x01;          // TIER4: IMIEA enabled
        self.bus.onchip_io[0x98] = 0x20;          // GRA4H
        self.bus.onchip_io[0x99] = 0x00;          // GRA4L -> GRA = 0x2000
        self.peripherals.timers.tstr |= 0x10;     // Start ITU4 (bit 4)
        self.bus.onchip_io[0x60] |= 0x10;         // Mirror TSTR to bus

        log::info!("JIT: Started ITU4 system tick (TCR=0xA3, GRA=0x2000, TSTR bit 4)");
        log::info!("JIT context init: Context B SP=0x{:06X}, entry=0x029B16", frame_sp);
    }

    /// NOP out USB-related JSR calls in flash that would hang the emulator.
    ///
    /// The USB fast-path code in RAM has wrong ISP1581 addresses (patched to
    /// 0x063621 -> erased flash). The main loop USB init calls poll ISP1581
    /// status that our model doesn't provide. Direct RAM CDB injection
    /// bypasses USB entirely, so we NOP all these calls.
    fn apply_flash_nop_patches(&mut self) {
        // Each entry: (flash address, expected original bytes, description)
        // Expected bytes are JSR @aa:24 instructions (opcode 5E, 4 bytes total).
        // If the firmware has different bytes, it's a different version and
        // patching would corrupt random code — skip with a warning.
        let patches: &[(u32, u32, &str)] = &[
            // USB fast-path calls in timer ISR path
            (0x012EC6, 0x5E01350A, "USB setup call (JSR @0x01350A)"),
            (0x012ECE, 0x5E013506, "USB fast-path call (JSR @0x013506)"),
            // Main loop USB init calls (block on ISP1581 enumeration state)
            (0x02080E, 0x5E010D22, "shared module init (JSR @0x010D22)"),
            (0x020820, 0x5E01233A, "USB configure (JSR @0x01233A)"),
            (0x020824, 0x5E0126EE, "USB endpoint enable (JSR @0x0126EE)"),
        ];

        let mut patched = 0;
        for &(addr, expected, desc) in patches {
            let actual = self.bus.read_long(addr);
            if actual != expected {
                log::warn!(
                    "JIT: SKIP patch {} at 0x{:06X}: found 0x{:08X}, expected 0x{:08X} (wrong firmware version?)",
                    desc, addr, actual, expected
                );
                continue;
            }
            self.bus.flash_write_long(addr, 0x00000000);
            patched += 1;
        }

        log::info!("JIT: NOPed {}/{} USB calls in flash", patched, patches.len());
    }

    // --- Context switch tracing ---

    /// Log context switch entry and validate the context save area.
    fn trace_context_switch(&mut self, insn_count: u64) {
        self.ctx_switch_count += 1;
        let ctx_idx = self.bus.read_word(0x400764);
        let ctx_a_sp = self.bus.read_long(0x400766);
        let ctx_b_sp = self.bus.read_long(0x40076A);
        let switching_to = if ctx_idx == 0 { "A->B" } else { "B->A" };

        // Log first 10 switches, then every 10000th
        if self.ctx_switch_count <= 10 || self.ctx_switch_count % 10000 == 0 {
            log::info!(
                "CTX#{} {} at insn {} | SP={:06X} idx={:04X} A_SP={:06X} B_SP={:06X}",
                self.ctx_switch_count, switching_to, insn_count,
                self.cpu.sp(), ctx_idx, ctx_a_sp, ctx_b_sp
            );
        }

        // Validate SP ranges
        let a_sp_valid = (0x40E000..=0x410000).contains(&ctx_a_sp) || ctx_a_sp == 0;
        let b_sp_valid = (0x40C000..=0x40D000).contains(&ctx_b_sp) || ctx_b_sp == 0;
        if !a_sp_valid || !b_sp_valid {
            log::error!(
                "CTX ANOMALY at switch #{}, insn {}: A_SP={:06X} (valid={}) B_SP={:06X} (valid={})",
                self.ctx_switch_count, insn_count, ctx_a_sp, a_sp_valid, ctx_b_sp, b_sp_valid
            );
            self.dump_registers_error();
            let target_sp = if ctx_idx == 0 { ctx_b_sp } else { ctx_a_sp };
            self.dump_memory_error("Target stack", target_sp, 10);
        }

        self.last_ctx_a_sp = ctx_a_sp;
        self.last_ctx_b_sp = ctx_b_sp;
    }

    /// Periodically check whether the context save area changed outside the handler.
    fn check_context_save_area(&mut self, insn_count: u64, pc: u32) {
        let ctx_a_sp = self.bus.read_long(0x400766);
        let ctx_b_sp = self.bus.read_long(0x40076A);
        if ctx_a_sp == self.last_ctx_a_sp && ctx_b_sp == self.last_ctx_b_sp {
            return;
        }
        // Only warn if we're outside the context switch handler
        if pc != 0x010876 && !(0x010876..=0x010900).contains(&pc) {
            let ctx_idx = self.bus.read_word(0x400764);
            log::warn!(
                "CTX SAVE AREA CHANGED outside handler! insn {} PC={:06X} idx={:04X} A_SP={:06X}->{:06X} B_SP={:06X}->{:06X}",
                insn_count, pc, ctx_idx,
                self.last_ctx_a_sp, ctx_a_sp,
                self.last_ctx_b_sp, ctx_b_sp
            );
        }
        self.last_ctx_a_sp = ctx_a_sp;
        self.last_ctx_b_sp = ctx_b_sp;
    }

    // --- One-shot runtime actions ---

    /// Handle address-triggered one-shot actions and logging.
    fn handle_oneshot_actions(&mut self, pc: u32, insn_count: u64) {
        // Set USB state when main loop is first reached.
        // Must be done here (not in JIT) because context init at 0x0107EC
        // overwrites RAM set during JIT.
        if pc == 0x0207F2 && self.milestones_seen.insert(0xDEAD0001) {
            self.bus.write_byte(0x407DC7, 0x02); // USB session = configured
            self.bus.write_byte(0x407DC3, 0x01); // USB connection = connected
            self.bus.write_byte(0x400084, 0x00); // Clear USB bus reset flag
            self.bus.write_byte(0x400085, 0x00); // Clear USB re-init flag
            self.bus.write_byte(0x400086, 0x00); // Clear USB status flag
            log::info!("MAIN LOOP INIT: Set USB state vars (session=02, cleared reset flags)");
        }

        // Log SCSI cmd_pending check (repeating, not one-shot)
        if pc == 0x013C70 {
            let pending = self.bus.read_byte(0x400082);
            log::info!(
                "SCSI: cmd_pending check at insn {} -- pending={:02X}, CDB[0]={:02X}",
                insn_count, pending, self.bus.read_byte(0x4007DE)
            );
        }

        // One-shot: scan state check reached
        if pc == 0x02083C && self.milestones_seen.insert(0x02083C) {
            log::info!("MAIN LOOP: reached scan state check (0x02083C) at insn {}", insn_count);
            log::info!("  USB state 0x407DC7={:02X}, flag 0x400084={:02X}, flag 0x400085={:02X}, flag 0x400086={:02X}",
                self.bus.read_byte(0x407DC7),
                self.bus.read_byte(0x400084),
                self.bus.read_byte(0x400085),
                self.bus.read_byte(0x400086));
        }

        // One-shot: USB bus reset handler entered
        if pc == 0x013A20 && self.milestones_seen.insert(0x013A20) {
            log::info!("MAIN LOOP: entered USB bus reset handler (0x013A20) at insn {}", insn_count);
        }
    }

    // --- Validation helpers ---

    /// Check whether a PC value is within a valid code region.
    fn is_valid_pc(pc: u32) -> bool {
        (0x000100..=0x07FFFF).contains(&pc)       // Flash
            || (0x400000..=0x41FFFF).contains(&pc) // RAM
            || (0xFFFB80..=0xFFFEFF).contains(&pc) // On-chip RAM (trampolines)
    }

    /// ITU base addresses in on-chip I/O space (ITU0-ITU4).
    /// Note: ITU4 is at 0x92, NOT 0x8C. There's a gap at 0x8C-0x91 (Port 7, BSC regs).
    const ITU_BASES: [usize; 5] = [0x64, 0x6E, 0x78, 0x82, 0x92];

    /// Sync peripheral models with memory bus state.
    /// Called after every instruction to propagate I/O register writes to models
    /// and model outputs back to the bus.
    fn sync_peripherals(&mut self) {
        // --- Timer sync ---
        // The firmware writes timer registers (0xFFFF60-0xFFFF95) via the memory bus.
        // We sync key registers to the timer model each cycle.
        let tstr = self.bus.onchip_io[0x60];
        if tstr != self.peripherals.timers.tstr {
            self.peripherals.timers.tstr = tstr;
        }
        // Sync per-timer registers when that timer's TSTR bit is set
        for (i, &base) in Self::ITU_BASES.iter().enumerate() {
            if tstr & (1 << i) != 0 {
                let t = &mut self.peripherals.timers.timers[i];
                t.tcr = self.bus.onchip_io[base];
                t.tior = self.bus.onchip_io[base + 1];
                // ITU4 is now at base 0x92, so TIER4 = 0x94 (no Port 7 conflict)
                t.tier = self.bus.onchip_io[base + 2];
                // GRA/GRB = big-endian 16-bit
                t.gra = ((self.bus.onchip_io[base + 6] as u16) << 8)
                    | self.bus.onchip_io[base + 7] as u16;
                t.grb = ((self.bus.onchip_io[base + 8] as u16) << 8)
                    | self.bus.onchip_io[base + 9] as u16;
                // Sync TSR: firmware clears flags by writing 0 to bits.
                let bus_tsr = self.bus.onchip_io[base + 3];
                t.tsr &= bus_tsr;
                // Write back model state to bus
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
        for vec in timer_irqs.into_iter().flatten() {
            if vec == vectors::IMIA4 && !self.irq.has_pending() {
                log::debug!("ITU4 compare-match -> Vec 40 queued (CCR.I={})", self.cpu.interrupt_masked() as u8);
            }
            let priority = match vec {
                vectors::IMIA4 => vectors::PRIORITY_LOW,
                vectors::IMIA2 | vectors::IMIA3 => vectors::PRIORITY_MEDIUM,
                _ => vectors::PRIORITY_MEDIUM,
            };
            self.irq.assert_interrupt(vec, priority);
        }

        // ISP1581 USB interrupt — check via bus accessor
        if self.bus.isp1581_has_irq() {
            log::debug!("ISP1581 IRQ1 asserted (CCR.I={})", self.cpu.interrupt_masked() as u8);
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

    /// Boot milestone addresses and their descriptions.
    const MILESTONES: [(u32, &'static str); 12] = [
        (0x020334, "Reached main entry point"),
        (0x020374, "Past I/O init table"),
        (0x020796, "Delay loop setup"),
        (0x0207A4, "First delay loop iteration"),
        (0x0205FC, "Past trampoline install"),
        (0x020608, "Interrupts enabled"),
        (0x0207F2, "Reached Context A main loop"),
        (0x020AE2, "SCSI dispatcher entered"),
        (0x010D22, "Main loop: shared module init"),
        (0x01233A, "Main loop: USB configure"),
        (0x0126EE, "Main loop: USB endpoint enable"),
        (0x013C70, "Main loop: cmd_pending check"),
    ];

    /// Log a boot milestone if the PC matches one we haven't seen yet.
    fn log_milestone(&mut self, insn_count: u64) {
        let pc = self.cpu.pc;
        for &(addr, desc) in &Self::MILESTONES {
            if pc == addr && self.milestones_seen.insert(addr) {
                log::info!("MILESTONE: {} (0x{:06X}) after {} instructions", desc, addr, insn_count);
                if addr == 0x020374 {
                    self.dump_timer_state();
                } else if addr == 0x020608 {
                    log::info!("  CCR={:02X}", self.cpu.ccr);
                }
                break;
            }
        }
    }

    /// Dump timer register state (used at I/O init milestone).
    fn dump_timer_state(&self) {
        log::info!("  TSTR(0x60)=0x{:02X}", self.bus.onchip_io[0x60]);
        for (i, &base) in Self::ITU_BASES.iter().enumerate() {
            let tcr = self.bus.onchip_io[base];
            let tier = self.bus.onchip_io[base + 2];
            let gra = ((self.bus.onchip_io[base + 6] as u16) << 8)
                | self.bus.onchip_io[base + 7] as u16;
            if tcr != 0 || tier != 0 {
                log::info!("  ITU{}: TCR=0x{:02X} TIER=0x{:02X} GRA=0x{:04X}", i, tcr, tier, gra);
            }
        }
        log::info!("  Port7(0x8E)=0x{:02X}", self.bus.onchip_io[0x8E]);
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

    /// Dump the top 8 longwords on the stack (for crash diagnostics).
    fn dump_stack(&mut self) {
        let sp = self.cpu.sp();
        log::error!("Stack dump (SP=0x{:06X}):", sp);
        for j in 0..8 {
            let addr = sp + j * 4;
            log::error!("  [{:06X}] = 0x{:08X}", addr, self.bus.read_long(addr));
        }
    }

    /// Dump all general registers at error level (for anomaly diagnostics).
    fn dump_registers_error(&self) {
        log::error!("  Current SP={:06X}, CCR={:02X}", self.cpu.sp(), self.cpu.ccr);
        log::error!("  ER0={:08X} ER1={:08X} ER2={:08X} ER3={:08X}",
            self.cpu.read_er(0), self.cpu.read_er(1),
            self.cpu.read_er(2), self.cpu.read_er(3));
        log::error!("  ER4={:08X} ER5={:08X} ER6={:08X}",
            self.cpu.read_er(4), self.cpu.read_er(5), self.cpu.read_er(6));
    }

    /// Dump N longwords starting at an address (error level).
    fn dump_memory_error(&mut self, label: &str, addr: u32, count: u32) {
        log::error!("  {} (0x{:06X}) dump:", label, addr);
        for j in 0..count {
            let a = addr + j * 4;
            log::error!("    [{:06X}] = {:08X}", a, self.bus.read_long(a));
        }
    }

    // --- TCP Bridge ---

    /// Poll TCP bridge for new connections and incoming data.
    /// Called periodically during emulation (every N instructions).
    fn poll_tcp(&mut self) {
        // Accept new connections
        if self.tcp_client.is_none() {
            if let Some(ref listener) = self.tcp_listener {
                if let Ok((stream, addr)) = listener.accept() {
                    if let Err(e) = stream.set_nonblocking(true) {
                        log::error!("Failed to set TCP client non-blocking: {}. Emulator may hang.", e);
                    }
                    log::info!("TCP client connected from {}", addr);
                    self.tcp_client = Some(stream);
                }
            }
        }

        // Read from connected client
        if let Some(ref mut stream) = self.tcp_client {
            use std::io::Read;
            let mut header = [0u8; 3]; // [len_hi, len_lo, type]
            match stream.read_exact(&mut header) {
                Ok(()) => {
                    let payload_len = ((header[0] as usize) << 8) | header[1] as usize;
                    let msg_type = header[2];
                    // Cap payload to prevent garbled frames from allocating huge buffers
                    if payload_len > 4096 {
                        log::error!("TCP: payload length {} exceeds max (4096). Disconnecting.", payload_len);
                        self.tcp_client = None;
                        return;
                    }
                    let mut payload = vec![0u8; payload_len];
                    if payload_len > 0 {
                        if let Err(e) = stream.read_exact(&mut payload) {
                            // Partial read: stream is now desynchronized — must disconnect
                            log::warn!("TCP read payload error: {}. Disconnecting.", e);
                            self.tcp_client = None;
                            return;
                        }
                    }
                    self.handle_tcp_message(msg_type, &payload);
                }
                Err(ref e) if e.kind() == std::io::ErrorKind::WouldBlock => {
                    // No data available — normal for non-blocking
                }
                Err(e) => {
                    log::info!("TCP client disconnected: {}", e);
                    self.tcp_client = None;
                }
            }
        }

        // Send responses back to client
        if self.bus.isp1581_has_response() {
            self.send_tcp_response();
        }
    }

    /// Handle an incoming TCP message.
    fn handle_tcp_message(&mut self, msg_type: u8, payload: &[u8]) {
        match msg_type {
            0x01 => {
                // CDB — inject directly into firmware RAM (bypass USB transport)
                log::info!("TCP: Received CDB [{:02X} {:02X} {:02X} {:02X} {:02X} {:02X}]",
                    payload.get(0).copied().unwrap_or(0),
                    payload.get(1).copied().unwrap_or(0),
                    payload.get(2).copied().unwrap_or(0),
                    payload.get(3).copied().unwrap_or(0),
                    payload.get(4).copied().unwrap_or(0),
                    payload.get(5).copied().unwrap_or(0));

                // Write CDB to firmware buffer at 0x4007DE (16 bytes)
                for (j, &b) in payload.iter().enumerate().take(16) {
                    self.bus.write_byte(0x4007DE + j as u32, b);
                }
                // Set SCSI opcode byte at 0x4007B6 (firmware reads opcode from here)
                if !payload.is_empty() {
                    self.bus.write_byte(0x4007B6, payload[0]);
                }
                // Set cmd_pending flag at 0x400082
                self.bus.write_byte(0x400082, 0x01);
                log::info!("TCP: CDB injected to RAM 0x4007DE, cmd_pending=1, opcode=0x{:02X}",
                    payload.get(0).copied().unwrap_or(0));
            }
            0x02 => {
                // Phase query — read the firmware's phase byte from RAM
                let phase = self.bus.read_byte(0x40049C);
                log::info!("TCP: Phase query → phase=0x{:02X}", phase);
                if let Some(ref mut stream) = self.tcp_client {
                    use std::io::Write;
                    let mut resp = [0x00, 0x01, 0x81u8, 0x00]; // header + phase
                    resp[3] = phase;
                    if let Err(e) = stream.write_all(&resp) {
                        log::warn!("TCP phase write error: {}. Disconnecting.", e);
                        self.tcp_client = None;
                    }
                }
            }
            0x04 => {
                // Sense query — read sense data from firmware RAM
                let sense_code = self.bus.read_word(0x4007B0);
                log::info!("TCP: Sense query → sense_code=0x{:04X}", sense_code);
                let mut buf = [0u8; 3 + 18]; // header + sense
                buf[0] = 0x00; buf[1] = 18; buf[2] = 0x83; // header
                buf[3] = 0x70; // Response code (current errors)
                buf[5] = ((sense_code >> 8) & 0x0F) as u8; // Sense key
                buf[10] = 10; // Additional sense length
                buf[15] = (sense_code & 0xFF) as u8; // ASC
                if let Some(ref mut stream) = self.tcp_client {
                    use std::io::Write;
                    if let Err(e) = stream.write_all(&buf) {
                        log::warn!("TCP sense write error: {}. Disconnecting.", e);
                        self.tcp_client = None;
                    }
                }
            }
            _ => {
                log::warn!("TCP: Unknown message type 0x{:02X}", msg_type);
            }
        }
    }

    /// Send pending response data back to the TCP client.
    fn send_tcp_response(&mut self) {
        let data = self.bus.isp1581_drain(1024);
        if data.is_empty() {
            return;
        }
        if let Some(ref mut stream) = self.tcp_client {
            use std::io::Write;
            // Determine response type based on data length
            let msg_type = match data.len() {
                1 => 0x81, // Phase byte
                18 => 0x83, // Sense data
                _ => 0x82, // Data in
            };
            let len = data.len() as u16;
            let header = [(len >> 8) as u8, len as u8, msg_type];
            if let Err(e) = stream.write_all(&header) {
                log::warn!("TCP write header error: {}", e);
                return;
            }
            if let Err(e) = stream.write_all(&data) {
                log::warn!("TCP write data error: {}", e);
            }
        }
    }

    /// Inject a CDB directly (for testing without TCP).
    #[allow(dead_code)]
    pub fn inject_cdb(&mut self, cdb: &[u8]) {
        let mut padded = vec![0u8; 32];
        let copy_len = cdb.len().min(32);
        padded[..copy_len].copy_from_slice(&cdb[..copy_len]);
        self.bus.isp1581_inject(&padded);
        log::info!("Injected CDB: {:02X} {:02X} {:02X} {:02X} {:02X} {:02X}",
            padded[0], padded[1], padded[2], padded[3], padded[4], padded[5]);
    }

    /// Wait for firmware to produce a response, then return it.
    #[allow(dead_code)]
    pub fn wait_response(&mut self, max_insns: u64) -> Vec<u8> {
        for _ in 0..max_insns {
            self.step_one();
            if self.bus.isp1581_has_response() {
                return self.bus.isp1581_drain(1024);
            }
        }
        Vec::new() // Timeout
    }

    /// Execute one CPU instruction with full peripheral handling.
    #[allow(dead_code)]
    pub fn step_one(&mut self) {
        if self.cpu.sleeping {
            self.check_peripherals();
            if !self.irq.has_pending() {
                return;
            }
        }

        self.irq.check_and_service(&mut self.cpu, &mut self.bus);

        let decoded = decode::decode(&mut self.bus, self.cpu.pc);
        if let decode::Instruction::Unknown(_) = &decoded.insn {
            return;
        }

        let insn_pc = self.cpu.pc;
        let new_pc = execute::execute(
            &mut self.cpu,
            &mut self.bus,
            &decoded.insn,
            insn_pc,
            decoded.len,
        );
        self.cpu.pc = new_pc;
        self.cpu.cycle_count += 1;

        self.sync_peripherals();
        self.check_peripherals();
    }
}
