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

// --- Firmware RAM addresses (from RE analysis, see docs/kb/) ---
const FW_CMD_PENDING: u32 = 0x400082;     // CDB available flag (1 = pending)
#[allow(dead_code)]
const FW_CMD_PENDING2: u32 = 0x400087;    // Secondary command flag
#[allow(dead_code)]
const FW_CDB_LEN: u32 = 0x400088;         // CDB byte count
const FW_SENSE_CODE: u32 = 0x4007B0;      // Current sense key/ASC/ASCQ
const FW_SCSI_OPCODE: u32 = 0x4007B6;     // SCSI opcode byte for dispatch
const FW_CDB_BUFFER: u32 = 0x4007DE;      // Start of CDB buffer (16 bytes)
const FW_CTX_INDEX: u32 = 0x400764;        // Context switch index (0=A, 4=B)
const FW_CTX_A_SP: u32 = 0x400766;         // Context A saved SP
const FW_CTX_B_SP: u32 = 0x40076A;         // Context B saved SP
#[allow(dead_code)]
const FW_SYS_TICK: u32 = 0x40076E;         // System tick timestamp
#[allow(dead_code)]
const FW_WARM_BOOT: u32 = 0x400772;        // Warm-boot flag
const FW_USB_SESSION: u32 = 0x407DC7;      // USB session state (2=ready)
const FW_INQUIRY_FLASH: u32 = 0x170D6;     // INQUIRY string in flash
#[allow(dead_code)]
const FW_INQUIRY_RAM: u32 = 0x4008A2;      // INQUIRY buffer in RAM

// --- Firmware code addresses ---
const FW_CTX_SWITCH: u32 = 0x010876;       // Context switch handler entry
const FW_SCSI_IDLE: u32 = 0x013C70;        // SCSI dispatcher idle point
const FW_MAIN_LOOP: u32 = 0x0207F2;        // Context A main loop entry

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
    /// Pending data-out CDB: stored when a data-out command arrives before its data.
    /// When data-out arrives, the command is processed immediately.
    pending_dataout_opcode: Option<u8>,
    // --- Phase 5: Scan state ---
    /// Whether RESERVE has been called (exclusive access claimed).
    reserved: bool,
    /// Whether a scan is active (set by SCAN, cleared by completion).
    scan_active: bool,
    /// Stored SET WINDOW descriptor (up to 80 bytes).
    window_descriptor: Vec<u8>,
    /// Scan image data buffer (synthesized test pattern).
    scan_data: Vec<u8>,
    /// Current offset into scan_data for chunked READ delivery.
    scan_data_offset: usize,
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
            (0xFFFD10, FW_CTX_SWITCH),  // Vec 8:  TRAP#0 → context switch
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
                        log::error!("Failed to set TCP listener non-blocking: {}. Aborting TCP bridge.", e);
                        None
                    } else {
                        log::info!("TCP bridge listening on port {}", config._tcp_port);
                        Some(listener)
                    }
                }
                Err(e) => {
                    log::error!("Failed to bind TCP port {}: {}. No TCP bridge.", config._tcp_port, e);
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
            pending_dataout_opcode: None,
            reserved: false,
            scan_active: false,
            window_descriptor: Vec::new(),
            scan_data: Vec::new(),
            scan_data_offset: 0,
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
                // Only wake from SLEEP when a maskable IRQ is pending AND
                // interrupts are enabled (CCR.I=0). Per H8/300H spec, SLEEP
                // with I=1 remains halted until I is cleared externally.
                if !self.irq.has_pending() || self.cpu.interrupt_masked() {
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

            // Context switch tracing (entry to handler at FW_CTX_SWITCH)
            if pre_exec_pc == FW_CTX_SWITCH {
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
                self.force_usb_session_state();
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
    /// The context switch handler at FW_CTX_SWITCH reads context state from RAM
    /// at FW_CTX_INDEX (index) and FW_CTX_A_SP/FW_CTX_B_SP (saved SPs).
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
        self.bus.write_long(FW_CTX_B_SP, frame_sp);   // Context B saved SP
        self.bus.write_word(FW_CTX_INDEX, 0x0000);      // Context A is current (index 0)

        // Start ITU4 system tick timer.
        // Warm-boot path skips the timer start code. Without ITU4 running,
        // the system tick at FW_SYS_TICK never increments and the firmware
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
        // Each entry: (flash address, expected JSR bytes, description).
        // Expected bytes are JSR @aa:24 instructions (opcode 0x5E, 4 bytes total).
        // If the firmware has different bytes at an address, it's a different
        // firmware version and patching would corrupt random code — skip with a warning.
        //
        // Three categories of patches, all using the same validation logic:
        //   1. USB fast-path/init calls that block on ISP1581 enumeration state
        //   2. Dispatch-level USB response manager calls (JSR @0x01374A)
        //   3. Handler-internal USB response manager + data transfer calls
        //
        // These calls interleave USB transport with SCSI processing, which blocks
        // because our ISP1581 model doesn't implement the full DMA handshake.
        // Since all SCSI commands are emulated directly at FW_SCSI_IDLE, the dispatch
        // path and handler USB calls are never reached — but NOPing them prevents
        // hangs if the firmware accidentally enters these code paths.
        let patches: &[(u32, u32, &str)] = &[
            // USB fast-path calls in timer ISR path
            (0x012EC6, 0x5E01350A, "USB setup call (JSR @0x01350A)"),
            (0x012ECE, 0x5E013506, "USB fast-path call (JSR @0x013506)"),
            // Main loop USB init calls (block on ISP1581 enumeration state)
            (0x02080E, 0x5E010D22, "shared module init (JSR @0x010D22)"),
            (0x020820, 0x5E01233A, "USB configure (JSR @0x01233A)"),
            (0x020824, 0x5E0126EE, "USB endpoint enable (JSR @0x0126EE)"),
            // Dispatch-level USB response manager calls (JSR @0x01374A)
            (0x020B22, 0x5E01374A, "dispatch response mgr (0x020B22)"),
            (0x020B3A, 0x5E01374A, "dispatch response mgr (0x020B3A)"),
            (0x020B8C, 0x5E01374A, "dispatch response mgr (0x020B8C)"),
            (0x020BA2, 0x5E01374A, "dispatch response mgr (0x020BA2)"),
            (0x020C62, 0x5E01374A, "dispatch response mgr (0x020C62)"),
            (0x020C84, 0x5E01374A, "dispatch response mgr (0x020C84)"),
            (0x020D26, 0x5E01374A, "dispatch response mgr (0x020D26)"),
            (0x020D40, 0x5E01374A, "dispatch response mgr (0x020D40)"),
            (0x020D5A, 0x5E01374A, "dispatch response mgr (0x020D5A)"),
            (0x020D74, 0x5E01374A, "dispatch response mgr (0x020D74)"),
            (0x020D9E, 0x5E01374A, "dispatch response mgr (0x020D9E)"),
            // Handler-internal USB response manager calls (JSR @0x01374A)
            (0x026042, 0x5E01374A, "INQUIRY response manager"),
            (0x02209E, 0x5E01374A, "MODE SENSE response manager"),
            (0x021932, 0x5E01374A, "REQUEST SENSE response manager"),
            (0x0219CA, 0x5E01374A, "MODE SELECT response manager"),
            (0x026EC6, 0x5E01374A, "SET WINDOW response manager"),
            // Handler-internal USB data transfer calls (JSR @0x014090)
            (0x02604A, 0x5E014090, "INQUIRY data transfer"),
            (0x02193A, 0x5E014090, "REQUEST SENSE data transfer"),
            (0x0220A8, 0x5E014090, "MODE SENSE data transfer"),
            (0x023D22, 0x5E014090, "RECEIVE DIAG data transfer"),
            (0x0279AE, 0x5E014090, "GET WINDOW data transfer"),
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
            self.bus.flash_write_long(addr, 0x00000000); // 2x NOP
            patched += 1;
        }

        log::info!("JIT: NOPed {}/{} USB calls in flash", patched, patches.len());
    }

    // --- Context switch tracing ---

    /// Log context switch entry and validate the context save area.
    fn trace_context_switch(&mut self, insn_count: u64) {
        self.ctx_switch_count += 1;
        let ctx_idx = self.bus.read_word(FW_CTX_INDEX);
        let ctx_a_sp = self.bus.read_long(FW_CTX_A_SP);
        let ctx_b_sp = self.bus.read_long(FW_CTX_B_SP);
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
        let ctx_a_sp = self.bus.read_long(FW_CTX_A_SP);
        let ctx_b_sp = self.bus.read_long(FW_CTX_B_SP);
        if ctx_a_sp == self.last_ctx_a_sp && ctx_b_sp == self.last_ctx_b_sp {
            return;
        }
        // Only warn if we're outside the context switch handler
        if pc != FW_CTX_SWITCH && !(FW_CTX_SWITCH..=0x010900).contains(&pc) {
            let ctx_idx = self.bus.read_word(FW_CTX_INDEX);
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

    // --- Direct SCSI command emulation ---

    /// Clear sense code to GOOD status.
    fn scsi_good(&mut self) {
        self.bus.write_word(FW_SENSE_CODE, 0x0000);
    }

    /// Set sense to ILLEGAL REQUEST (SK=5, ASC=0x24).
    fn scsi_illegal_request(&mut self) {
        self.bus.write_word(FW_SENSE_CODE, 0x0524);
    }

    /// Read 24-bit big-endian transfer length from CDB bytes 6-8.
    fn cdb_xfer_len_24(&mut self) -> u32 {
        ((self.bus.read_byte(FW_CDB_BUFFER + 6) as u32) << 16)
            | ((self.bus.read_byte(FW_CDB_BUFFER + 7) as u32) << 8)
            | self.bus.read_byte(FW_CDB_BUFFER + 8) as u32
    }

    /// Handle a SCSI command directly (bypassing firmware dispatcher).
    /// Builds response data from firmware flash/RAM and pushes to EP2 IN FIFO.
    fn handle_scsi_command(&mut self, opcode: u8) {
        match opcode {
            0x00 => {
                // TEST UNIT READY: scanner is always ready in emulator
                self.scsi_good();
                log::info!("SCSI EMU: TUR → GOOD");
            }
            0x12 => {
                // INQUIRY: standard or EVPD response
                let evpd = self.bus.read_byte(FW_CDB_BUFFER + 1) & 0x01;
                let page_code = self.bus.read_byte(FW_CDB_BUFFER + 2);
                let alloc_len = self.bus.read_byte(FW_CDB_BUFFER + 4) as usize;

                if evpd != 0 {
                    // EVPD: Vital Product Data pages
                    match page_code {
                        0x00 => {
                            // Supported VPD pages (from firmware: depends on adapter)
                            // Adapter VPD pages vary: mount=C0/C1, strip=C0-C3, aps=C0-C3, feeder=C0-C4
                            let pages = [0x00u8, 0xC0, 0xC1]; // Minimal: supported pages + 2 adapter pages
                            let xfer_len = alloc_len.min(pages.len() + 4);
                            let mut data = vec![0u8; xfer_len];
                            data[0] = 0x06; // Device type: scanner
                            data[3] = pages.len() as u8; // Page length
                            for (i, &p) in pages.iter().enumerate() {
                                if 4 + i < xfer_len { data[4 + i] = p; }
                            }
                            self.bus.isp1581_push_to_host(&data);
                            log::info!("SCSI EMU: INQUIRY EVPD page 0x00 → {} bytes", xfer_len);
                        }
                        0xC0 => {
                            // VPD page 0xC0: adapter identification
                            let xfer_len = alloc_len.min(16);
                            let mut data = vec![0u8; xfer_len];
                            data[0] = 0x06; // Device type
                            data[1] = 0xC0; // Page code
                            data[3] = 8;    // Page length
                            // Adapter type byte (from current config)
                            data[4] = self.peripherals.gpio.port_7_input;
                            self.bus.isp1581_push_to_host(&data);
                            log::info!("SCSI EMU: INQUIRY EVPD page 0xC0 → {} bytes", xfer_len);
                        }
                        0xC1 => {
                            // VPD page 0xC1: adapter capabilities
                            let xfer_len = alloc_len.min(16);
                            let data = vec![0u8; xfer_len];
                            self.bus.isp1581_push_to_host(&data);
                            log::info!("SCSI EMU: INQUIRY EVPD page 0xC1 → {} bytes", xfer_len);
                        }
                        _ => {
                            self.scsi_illegal_request();
                            log::warn!("SCSI EMU: INQUIRY EVPD page 0x{:02X} → ILLEGAL REQUEST", page_code);
                            return;
                        }
                    }
                    self.scsi_good();
                } else {
                    // Standard INQUIRY
                    let xfer_len = alloc_len.min(36);
                    if xfer_len > 0 {
                        let mut data = vec![0u8; xfer_len];
                        data[0] = 0x06; // Device type: scanner
                        data[1] = 0x00;
                        data[2] = 0x02; // SCSI-2
                        data[3] = 0x02; // Response format 2
                        if xfer_len > 4 { data[4] = 0x1F; } // Additional length
                        // Vendor/product/revision from flash
                        if xfer_len >= 36 {
                            for j in 0..28 {
                                data[8 + j] = self.bus.read_byte(FW_INQUIRY_FLASH + j as u32);
                            }
                        }
                        self.bus.isp1581_push_to_host(&data);
                        log::info!("SCSI EMU: INQUIRY → {} bytes", xfer_len);
                    }
                    self.scsi_good();
                }
            }
            0x03 => {
                // REQUEST SENSE: build 18-byte sense from RAM
                let alloc_len = self.bus.read_byte(FW_CDB_BUFFER + 4) as usize;
                let xfer_len = alloc_len.min(18);
                if xfer_len > 0 {
                    let sense_code = self.bus.read_word(FW_SENSE_CODE);
                    let mut data = vec![0u8; xfer_len];
                    data[0] = 0x70; // Current errors
                    if xfer_len > 2 { data[2] = ((sense_code >> 8) & 0x0F) as u8; }
                    if xfer_len > 7 { data[7] = 10; } // Additional length
                    if xfer_len > 12 { data[12] = (sense_code & 0xFF) as u8; }
                    self.bus.isp1581_push_to_host(&data);
                    log::info!("SCSI EMU: REQUEST SENSE → SK={:X} ASC={:02X}",
                        (sense_code >> 8) & 0xF, sense_code & 0xFF);
                }
                self.scsi_good(); // Clear after reading (per SCSI spec)
            }
            0x16 => {
                // RESERVE: claim exclusive access
                self.reserved = true;
                self.scsi_good();
                log::info!("SCSI EMU: RESERVE → GOOD");
            }
            0x17 => {
                // RELEASE: release exclusive access
                self.reserved = false;
                self.scan_active = false;
                self.scsi_good();
                log::info!("SCSI EMU: RELEASE → GOOD");
            }
            0x15 => {
                // MODE SELECT(6): accept data-out, store for reference
                let param_len = self.bus.read_byte(FW_CDB_BUFFER + 4) as usize;
                // Drain data-out from EP1 OUT FIFO (host sends parameter bytes)
                let _data = self.bus.isp1581_drain_host_data(param_len);
                log::info!("SCSI EMU: MODE SELECT → GOOD ({} bytes consumed)", param_len);
                self.scsi_good();
            }
            0x1A => {
                // MODE SENSE(6): build minimal mode page response
                let alloc_len = self.bus.read_byte(FW_CDB_BUFFER + 4) as usize;
                let page_code = self.bus.read_byte(FW_CDB_BUFFER + 2) & 0x3F;
                let xfer_len = alloc_len.min(36);
                if xfer_len >= 4 {
                    let mut data = vec![0u8; xfer_len];
                    data[0] = (xfer_len - 1) as u8; // Mode data length
                    // Mode page data (simplified)
                    if xfer_len > 4 && (page_code == 0x03 || page_code == 0x3F) {
                        if xfer_len >= 16 {
                            data[4] = 0x03; // Page code
                            data[5] = 0x0A; // Page length (10)
                            data[8] = 0x01; data[9] = 0x2C; // X res = 300
                            data[10] = 0x01; data[11] = 0x2C; // Y res = 300
                        }
                    }
                    self.bus.isp1581_push_to_host(&data);
                    log::info!("SCSI EMU: MODE SENSE page=0x{:02X} → {} bytes", page_code, xfer_len);
                }
                self.scsi_good();
            }
            0x1B => {
                // SCAN: initiate scan operation
                self.handle_scan();
            }
            0x1D => {
                // SEND DIAGNOSTIC: state-dependent, always return GOOD in emulator
                self.scsi_good();
                log::info!("SCSI EMU: SEND DIAGNOSTIC → GOOD (emulated)");
            }
            0x24 => {
                // SET WINDOW: parse and store window descriptor
                self.handle_set_window();
            }
            0x25 => {
                // GET WINDOW: return stored window descriptor
                self.handle_get_window();
            }
            0x28 => {
                // READ(10): dispatch by Data Type Code
                self.handle_read();
            }
            0x2A => {
                // WRITE(10): accept data-out by DTC
                self.handle_write();
            }
            0xC0 | 0xC1 => {
                // VENDOR C0/C1: trigger operations — stub GOOD
                self.scsi_good();
                log::info!("SCSI EMU: VENDOR 0x{:02X} → GOOD (stub)", opcode);
            }
            0xE0 => {
                // VENDOR E0: write control parameters — accept data-out
                let xfer_len = self.cdb_xfer_len_24() as usize;
                let _data = self.bus.isp1581_drain_host_data(xfer_len);
                self.scsi_good();
                log::info!("SCSI EMU: VENDOR E0 → GOOD ({} bytes consumed)", xfer_len);
            }
            0xE1 => {
                // VENDOR E1: read sensor results — return zeros
                let xfer_len = self.cdb_xfer_len_24() as usize;
                let data = vec![0u8; xfer_len];
                self.bus.isp1581_push_to_host(&data);
                self.scsi_good();
                log::info!("SCSI EMU: VENDOR E1 → {} bytes (zeros)", xfer_len);
            }
            _ => {
                // Unknown/unsupported opcode: ILLEGAL REQUEST
                self.scsi_illegal_request();
                log::warn!("SCSI EMU: opcode 0x{:02X} → ILLEGAL REQUEST (sense 05/24/00)", opcode);
            }
        }
    }

    /// Handle SCAN (0x1B) command.
    fn handle_scan(&mut self) {
        let op_type = self.bus.read_byte(FW_CDB_BUFFER + 4);
        // Synthesize test image data based on window descriptor
        let (width, height, bpp, channels) = self.parse_scan_dimensions();
        let bytes_per_pixel = if bpp > 8 { 2 } else { 1 };
        let image_size = width * height * bytes_per_pixel * channels;

        // Generate gradient test pattern
        let mut data = Vec::with_capacity(image_size);
        for y in 0..height {
            for x in 0..width {
                for ch in 0..channels {
                    if bytes_per_pixel == 2 {
                        // 16-bit: gradient based on position
                        let val = ((x * 65535 / width.max(1)) as u16).to_be_bytes();
                        data.push(val[0]);
                        data.push(val[1]);
                    } else {
                        // 8-bit: RGB gradient
                        let val = match ch {
                            0 => (x * 255 / width.max(1)) as u8,        // R: left-right
                            1 => (y * 255 / height.max(1)) as u8,       // G: top-bottom
                            _ => ((x + y) * 255 / (width + height).max(1)) as u8, // B: diagonal
                        };
                        data.push(val);
                    }
                }
            }
        }

        self.scan_data = data;
        self.scan_data_offset = 0;
        self.scan_active = true;
        self.scsi_good();
        log::info!("SCSI EMU: SCAN op={} → GOOD ({}x{} {}bpp, {} bytes image)",
            op_type, width, height, bpp, self.scan_data.len());
    }

    /// Parse scan dimensions from stored window descriptor.
    /// Returns (width_pixels, height_pixels, bits_per_pixel, channels).
    fn parse_scan_dimensions(&self) -> (usize, usize, usize, usize) {
        if self.window_descriptor.len() < 48 {
            // No window set: return small default
            return (100, 100, 8, 3);
        }
        // Window descriptor layout (after 8-byte header):
        // Bytes 10-11: X resolution (BE u16)
        // Bytes 12-13: Y resolution (BE u16)
        // Bytes 14-17: upper-left X (BE u32)
        // Bytes 18-21: upper-left Y (BE u32)
        // Bytes 22-25: width (BE u32, in 1/1200 inch)
        // Bytes 26-29: height (BE u32, in 1/1200 inch)
        // Byte 33: image composition (1=gray, 5=RGB, 2=halftone)
        // Byte 34: bits per pixel
        let wd = &self.window_descriptor;
        let x_res = u16::from_be_bytes([wd[10], wd[11]]) as usize;
        let y_res = u16::from_be_bytes([wd[12], wd[13]]) as usize;
        let win_w = u32::from_be_bytes([wd[22], wd[23], wd[24], wd[25]]) as usize;
        let win_h = u32::from_be_bytes([wd[26], wd[27], wd[28], wd[29]]) as usize;
        let composition = if wd.len() > 33 { wd[33] as usize } else { 5 };
        let bpp = if wd.len() > 34 { wd[34] as usize } else { 8 };

        // Image composition determines channels
        let channels = match composition {
            5 => 3,     // RGB
            2 | 1 => 1, // Grayscale / halftone
            _ => 3,     // Default to RGB
        };

        // Convert from 1200ths of an inch to pixels
        let width = if x_res > 0 { (win_w * x_res) / 1200 } else { 100 };
        let height = if y_res > 0 { (win_h * y_res) / 1200 } else { 100 };

        // Clamp to reasonable size for emulation
        let width = width.clamp(1, 4096);
        let height = height.clamp(1, 4096);
        let bpp = if bpp == 0 { 8 } else { bpp };

        (width, height, bpp, channels)
    }

    /// Handle SET WINDOW (0x24): consume and store window descriptor.
    fn handle_set_window(&mut self) {
        let xfer_len = self.cdb_xfer_len_24() as usize;
        // Drain the window descriptor from EP1 OUT FIFO
        let data = self.bus.isp1581_drain_host_data(xfer_len);
        if !data.is_empty() {
            self.window_descriptor = data;
            log::info!("SCSI EMU: SET WINDOW → GOOD ({} bytes stored)", self.window_descriptor.len());
        } else {
            log::info!("SCSI EMU: SET WINDOW → GOOD ({} bytes, no data available)", xfer_len);
        }
        self.scsi_good();
    }

    /// Handle GET WINDOW (0x25): return stored window descriptor.
    fn handle_get_window(&mut self) {
        let alloc_len = self.cdb_xfer_len_24() as usize;
        if self.window_descriptor.is_empty() {
            // No window set: return minimal 8-byte header
            let mut data = vec![0u8; alloc_len.min(8)];
            if data.len() >= 6 {
                // Window descriptor length = 0 (no descriptor body)
                data[4] = 0x00; data[5] = 0x00;
            }
            self.bus.isp1581_push_to_host(&data);
            log::info!("SCSI EMU: GET WINDOW → {} bytes (empty)", data.len());
        } else {
            let xfer_len = alloc_len.min(self.window_descriptor.len());
            self.bus.isp1581_push_to_host(&self.window_descriptor[..xfer_len]);
            log::info!("SCSI EMU: GET WINDOW → {} bytes", xfer_len);
        }
        self.scsi_good();
    }

    /// Handle READ (0x28): dispatch by Data Type Code (CDB[2]).
    fn handle_read(&mut self) {
        let dtc = self.bus.read_byte(FW_CDB_BUFFER + 2);
        let qualifier = self.bus.read_byte(FW_CDB_BUFFER + 5);
        let xfer_len = self.cdb_xfer_len_24() as usize;

        match dtc {
            0x00 => {
                // Image data: return from scan buffer
                if !self.scan_active {
                    log::warn!("SCSI EMU: READ DTC=0x00 but no scan active → CHECK CONDITION");
                    self.bus.write_word(FW_SENSE_CODE, 0x0250); // NOT READY
                    return;
                }
                let remaining = self.scan_data.len().saturating_sub(self.scan_data_offset);
                let actual = xfer_len.min(remaining);
                if actual > 0 {
                    let end = self.scan_data_offset + actual;
                    self.bus.isp1581_push_to_host(&self.scan_data[self.scan_data_offset..end]);
                    self.scan_data_offset = end;
                }
                if self.scan_data_offset >= self.scan_data.len() {
                    self.scan_active = false;
                    log::info!("SCSI EMU: READ DTC=0x00 → {} bytes (scan complete)", actual);
                } else {
                    log::info!("SCSI EMU: READ DTC=0x00 q={} → {} bytes ({} remaining)",
                        qualifier, actual, self.scan_data.len() - self.scan_data_offset);
                }
                self.scsi_good();
            }
            0x03 => {
                // Gamma/LUT: return identity LUT
                let lut_size = xfer_len.min(4096);
                let data: Vec<u8> = (0..lut_size).map(|i| (i * 255 / lut_size.max(1)) as u8).collect();
                self.bus.isp1581_push_to_host(&data);
                self.scsi_good();
                log::info!("SCSI EMU: READ DTC=0x03 q={} → {} bytes (identity LUT)", qualifier, lut_size);
            }
            0x84 => {
                // Calibration data: return 6 bytes of zeros
                let actual = xfer_len.min(6);
                let data = vec![0u8; actual];
                self.bus.isp1581_push_to_host(&data);
                self.scsi_good();
                log::info!("SCSI EMU: READ DTC=0x84 → {} bytes", actual);
            }
            0x87 => {
                // Scan parameters: return 24-byte status block
                let actual = xfer_len.min(24);
                let mut data = vec![0u8; actual];
                // Report scan dimensions if we have them
                let (w, h, _bpp, _ch) = self.parse_scan_dimensions();
                if actual >= 4 {
                    data[0] = (w >> 8) as u8; data[1] = w as u8;
                    data[2] = (h >> 8) as u8; data[3] = h as u8;
                }
                self.bus.isp1581_push_to_host(&data);
                self.scsi_good();
                log::info!("SCSI EMU: READ DTC=0x87 → {} bytes (scan params)", actual);
            }
            0x88 => {
                // Boundary data: return per-channel calibration (up to 644 bytes)
                let actual = xfer_len.min(644);
                let data = vec![0u8; actual];
                self.bus.isp1581_push_to_host(&data);
                self.scsi_good();
                log::info!("SCSI EMU: READ DTC=0x88 q={} → {} bytes", qualifier, actual);
            }
            0xE0 => {
                // Extended config: return zeros
                let data = vec![0u8; xfer_len];
                self.bus.isp1581_push_to_host(&data);
                self.scsi_good();
                log::info!("SCSI EMU: READ DTC=0xE0 → {} bytes", xfer_len);
            }
            _ => {
                // Unsupported DTC
                self.scsi_illegal_request();
                log::warn!("SCSI EMU: READ DTC=0x{:02X} → ILLEGAL REQUEST (unsupported DTC)", dtc);
            }
        }
    }

    /// Handle WRITE (0x2A): accept data-out by DTC.
    fn handle_write(&mut self) {
        let dtc = self.bus.read_byte(FW_CDB_BUFFER + 2);
        let qualifier = self.bus.read_byte(FW_CDB_BUFFER + 5);
        let xfer_len = self.cdb_xfer_len_24() as usize;

        // Drain the data-out payload from EP1 OUT (host→device)
        let _data = self.bus.isp1581_drain_host_data(xfer_len);

        match dtc {
            0x03 => {
                // Gamma/LUT upload: accept and discard
                self.scsi_good();
                log::info!("SCSI EMU: WRITE DTC=0x03 q={} → GOOD ({} bytes)", qualifier, xfer_len);
            }
            0x84 | 0x85 => {
                // Calibration data: accept and discard
                self.scsi_good();
                log::info!("SCSI EMU: WRITE DTC=0x{:02X} → GOOD ({} bytes)", dtc, xfer_len);
            }
            0x88 => {
                // Boundary data: accept
                self.scsi_good();
                log::info!("SCSI EMU: WRITE DTC=0x88 q={} → GOOD ({} bytes)", qualifier, xfer_len);
            }
            0xE0 => {
                // Extended config: accept
                self.scsi_good();
                log::info!("SCSI EMU: WRITE DTC=0xE0 → GOOD ({} bytes)", xfer_len);
            }
            _ => {
                self.scsi_illegal_request();
                log::warn!("SCSI EMU: WRITE DTC=0x{:02X} → ILLEGAL REQUEST", dtc);
            }
        }
    }

    // --- One-shot runtime actions ---

    /// Handle address-triggered one-shot actions and logging.
    fn handle_oneshot_actions(&mut self, pc: u32, insn_count: u64) {
        // Set USB state when main loop is first reached.
        // Must be done here (not in JIT) because context init at 0x0107EC
        // overwrites RAM set during JIT.
        if pc == FW_MAIN_LOOP && self.milestones_seen.insert(0xDEAD0001) {
            self.bus.write_byte(FW_USB_SESSION, 0x02); // USB session = configured
            self.bus.write_byte(0x407DC3, 0x01); // USB connection = connected
            self.bus.write_byte(0x400084, 0x00); // Clear USB bus reset flag
            self.bus.write_byte(0x400085, 0x00); // Clear USB re-init flag
            self.bus.write_byte(0x400086, 0x00); // Clear USB status flag
            log::info!("MAIN LOOP INIT: Set USB state vars (session=02, cleared reset flags)");
        }

        // Log SCSI cmd_pending check (repeating, only when pending)
        if pc == FW_SCSI_IDLE {
            let pending = self.bus.read_byte(FW_CMD_PENDING);
            if pending != 0 {
                log::info!(
                    "SCSI: cmd_pending check at insn {} -- pending={:02X}, CDB[0]={:02X}",
                    insn_count, pending, self.bus.read_byte(FW_CDB_BUFFER)
                );
            }
        }


        // SCSI commands are processed synchronously in handle_tcp_message,
        // not via firmware interception. No cmd_pending needed.

        // One-shot: scan state check reached
        if pc == 0x02083C && self.milestones_seen.insert(0x02083C) {
            log::info!("MAIN LOOP: reached scan state check (0x02083C) at insn {}", insn_count);
            log::info!("  USB state FW_USB_SESSION={:02X}, flag 0x400084={:02X}, flag 0x400085={:02X}, flag 0x400086={:02X}",
                self.bus.read_byte(FW_USB_SESSION),
                self.bus.read_byte(0x400084),
                self.bus.read_byte(0x400085),
                self.bus.read_byte(0x400086));
        }

        // One-shot: USB bus reset handler entered
        if pc == 0x013A20 && self.milestones_seen.insert(0x013A20) {
            log::info!("MAIN LOOP: entered USB bus reset handler (0x013A20) at insn {}", insn_count);
        }
    }

    /// Force USB session state to "connected" (0x02) to prevent the
    /// main loop from entering the USB re-establish path.
    /// The dispatch code changes FW_USB_SESSION from 0x02 to 0x01 as part of
    /// USB state management. Without real ISP1581 USB enumeration, the
    /// re-establish path blocks forever. Called periodically (not every cycle).
    fn force_usb_session_state(&mut self) {
        let session = self.bus.read_byte(FW_USB_SESSION);
        if session != 0x02 {
            self.bus.write_byte(FW_USB_SESSION, 0x02);
            self.bus.write_byte(0x40049A, 0x00); // Clear USB transaction active
            self.bus.write_byte(0x407DC6, 0x00); // Clear command phase
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
    const MILESTONES: [(u32, &'static str); 30] = [
        (0x020334, "Reached main entry point"),
        (0x020374, "Past I/O init table"),
        (0x020796, "Delay loop setup"),
        (0x0207A4, "First delay loop iteration"),
        (0x0205FC, "Past trampoline install"),
        (0x020608, "Interrupts enabled"),
        (FW_MAIN_LOOP, "Reached Context A main loop"),
        (0x020AE2, "SCSI dispatcher entered"),
        (0x010D22, "Main loop: shared module init"),
        (0x01233A, "Main loop: USB configure"),
        (0x0126EE, "Main loop: USB endpoint enable"),
        (FW_SCSI_IDLE, "Main loop: cmd_pending check"),
        // SCSI dispatch flow trace (Phase 4)
        (0x013690, "SCSI: command ready check (0x013690)"),
        (0x020B48, "SCSI: opcode lookup (0x020B48)"),
        (0x020B70, "SCSI: opcode matched (0x020B70)"),
        (0x020CA0, "SCSI: permission check (0x020CA0)"),
        (0x020D94, "SCSI: exec mode check (0x020D94)"),
        (0x020DB2, "SCSI: handler call (0x020DB2)"),
        // SCSI handler entry points
        (0x0215C2, "SCSI: TEST UNIT READY handler"),
        (0x021866, "SCSI: REQUEST SENSE handler"),
        (0x025E18, "SCSI: INQUIRY handler"),
        (0x021F1C, "SCSI: MODE SENSE handler"),
        (0x02194A, "SCSI: MODE SELECT handler"),
        (0x026E38, "SCSI: SET WINDOW handler"),
        (0x0220B8, "SCSI: SCAN handler"),
        (0x023F10, "SCSI: READ handler"),
        (0x025506, "SCSI: SEND(WRITE) handler"),
        (0x023D32, "SCSI: SEND DIAGNOSTIC handler"),
        // USB response path
        (0x01374A, "SCSI: USB response manager"),
        (0x014090, "SCSI: USB data transfer"),
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
                        log::error!("Failed to set TCP client non-blocking: {}. Rejecting connection.", e);
                    } else {
                        log::info!("TCP client connected from {}", addr);
                        self.tcp_client = Some(stream);
                    }
                }
            }
        }

        // Read ALL available frames from connected client (not just one).
        // This ensures that CDB + data-out frames sent in quick succession
        // are both processed before the next SCSI idle intercept.
        // Collect frames first, then process (avoids borrow checker issues).
        let mut frames: Vec<(u8, Vec<u8>)> = Vec::new();
        let mut disconnect = false;
        if let Some(ref mut stream) = self.tcp_client {
            use std::io::Read;
            loop {
                let mut header = [0u8; 3]; // [len_hi, len_lo, type]
                match stream.read_exact(&mut header) {
                    Ok(()) => {
                        let payload_len = ((header[0] as usize) << 8) | header[1] as usize;
                        let msg_type = header[2];
                        if payload_len > 65536 {
                            log::error!("TCP: payload length {} exceeds max (65536). Disconnecting.", payload_len);
                            disconnect = true;
                            break;
                        }
                        let mut payload = vec![0u8; payload_len];
                        if payload_len > 0 {
                            if let Err(e) = stream.read_exact(&mut payload) {
                                log::warn!("TCP read payload error: {}. Disconnecting.", e);
                                disconnect = true;
                                break;
                            }
                        }
                        frames.push((msg_type, payload));
                    }
                    Err(ref e) if e.kind() == std::io::ErrorKind::WouldBlock => {
                        break; // No more data — done reading
                    }
                    Err(e) => {
                        log::info!("TCP client disconnected: {}", e);
                        disconnect = true;
                        break;
                    }
                }
            }
        }
        if disconnect {
            self.tcp_client = None;
        }
        for (msg_type, payload) in frames {
            self.handle_tcp_message(msg_type, &payload);
        }

        // Send responses back to client
        if self.bus.isp1581_has_response() {
            self.send_tcp_response();
        }
    }

    /// Handle an incoming TCP message.
    ///
    /// TCP frame protocol (host ↔ emulator):
    ///   Header: [length:2 BE] [type:1]  Payload: [N bytes]
    ///
    /// Host → Emulator:
    ///   0x01 = CDB inject (6-16 bytes)
    ///   0x02 = Phase query
    ///   0x04 = Sense query
    ///   0x05 = Data-In query (drain ISP1581 EP2 IN FIFO)
    ///   0x06 = Data-Out inject (push to ISP1581 EP1 OUT FIFO for data-out commands)
    ///   0x07 = Completion poll (check if cmd_pending returned to 0)
    ///
    /// Emulator → Host:
    ///   0x81 = Phase byte (1 byte)
    ///   0x82 = Data-In response (variable)
    ///   0x83 = Sense data (18 bytes, fixed-format REQUEST SENSE)
    ///   0x84 = Data-In from ISP1581 EP2 (variable, raw FIFO drain)
    ///   0x85 = Completion status (1 byte: 0=pending, 1=done, + 2 bytes sense)
    fn handle_tcp_message(&mut self, msg_type: u8, payload: &[u8]) {
        match msg_type {
            0x01 => {
                // CDB — inject directly into firmware RAM (bypass USB transport)
                if payload.is_empty() {
                    log::warn!("TCP: Received empty CDB, ignoring");
                    return;
                }

                log::info!("TCP: Received CDB [{:02X} {:02X} {:02X} {:02X} {:02X} {:02X}{}]",
                    payload.get(0).copied().unwrap_or(0),
                    payload.get(1).copied().unwrap_or(0),
                    payload.get(2).copied().unwrap_or(0),
                    payload.get(3).copied().unwrap_or(0),
                    payload.get(4).copied().unwrap_or(0),
                    payload.get(5).copied().unwrap_or(0),
                    if payload.len() > 6 {
                        format!(" +{} bytes", payload.len() - 6)
                    } else {
                        String::new()
                    });

                // Warn if CDB length is short for the opcode group
                let expected_len = match payload[0] >> 5 {
                    0 => 6,       // Group 0 (0x00-0x1F)
                    1 | 2 => 10,  // Group 1/2 (0x20-0x5F)
                    _ => payload.len(),
                };
                if payload.len() < expected_len {
                    log::warn!("TCP: CDB length {} < expected {} for opcode 0x{:02X}",
                        payload.len(), expected_len, payload[0]);
                }

                // Write CDB to firmware buffer at FW_CDB_BUFFER (16 bytes)
                for (j, &b) in payload.iter().enumerate().take(16) {
                    self.bus.write_byte(FW_CDB_BUFFER + j as u32, b);
                }
                // Set SCSI opcode byte at FW_SCSI_OPCODE
                self.bus.write_byte(FW_SCSI_OPCODE, payload[0]);
                // Clear sense code before new command
                self.bus.write_word(FW_SENSE_CODE, 0x0000);
                // Process SCSI commands directly — don't wait for firmware to reach
                // any specific PC. The firmware's SCSI dispatcher relies on USB
                // transport that we don't fully emulate, so we handle all commands
                // here instead. cmd_pending is never set (firmware never sees it).
                let opcode = payload[0];
                let is_data_out = matches!(opcode, 0x15 | 0x24 | 0x2A | 0xE0);
                if is_data_out {
                    self.pending_dataout_opcode = Some(opcode);
                    log::info!("TCP: CDB buffered (data-out cmd 0x{:02X}), waiting for data-out", opcode);
                } else {
                    log::info!("TCP: Processing SCSI cmd 0x{:02X} immediately", opcode);
                    self.handle_scsi_command(opcode);
                }
            }
            0x02 => {
                // Phase query — read the firmware's phase byte from RAM
                let phase = self.bus.read_byte(0x40049C);
                log::info!("TCP: Phase query → phase=0x{:02X}", phase);
                self.send_tcp_frame(0x81, &[phase]);
            }
            0x04 => {
                // Sense query — read sense data from firmware RAM and build
                // a standard REQUEST SENSE response (18 bytes).
                let sense_code = self.bus.read_word(FW_SENSE_CODE);
                log::info!("TCP: Sense query → sense_code=0x{:04X}", sense_code);
                let mut sense = [0u8; 18];
                sense[0] = 0x70; // Response code (current errors)
                sense[2] = ((sense_code >> 8) & 0x0F) as u8; // Sense key
                sense[7] = 10; // Additional sense length
                sense[12] = (sense_code & 0xFF) as u8; // ASC
                self.send_tcp_frame(0x83, &sense);
            }
            0x05 => {
                // Data-In query — drain ISP1581 EP2 IN FIFO (firmware response data)
                let data = self.bus.isp1581_drain(65536);
                log::info!("TCP: Data-In query → {} bytes from EP2 IN", data.len());
                if !data.is_empty() {
                    log::info!("TCP: Data-In first 16 bytes: {:02X?}", &data[..data.len().min(16)]);
                }
                self.send_tcp_frame(0x84, &data);
            }
            0x06 => {
                // Data-Out inject — push payload to ISP1581 EP1 OUT FIFO
                // Used for data-out SCSI commands (MODE SELECT, SET WINDOW, etc.)
                log::info!("TCP: Data-Out inject, {} bytes to EP1 OUT", payload.len());
                self.bus.isp1581_inject(payload);
                self.send_tcp_frame(0x86, &[0x01]); // ACK
                // If we have a pending data-out command, process it now
                if let Some(opcode) = self.pending_dataout_opcode.take() {
                    log::info!("TCP: Data-out received, processing cmd 0x{:02X} now", opcode);
                    self.handle_scsi_command(opcode);
                }
            }
            0x07 => {
                // Completion poll — check if cmd_pending has returned to 0
                // If a data-out command is still pending (no data-out frame arrived),
                // process it now with whatever is in EP1 OUT (might be empty).
                if let Some(opcode) = self.pending_dataout_opcode.take() {
                    log::info!("TCP: Completion poll while data-out pending — processing 0x{:02X} now", opcode);
                    self.handle_scsi_command(opcode);
                }
                // Commands are now processed synchronously, so always report done
                let sense_code = self.bus.read_word(FW_SENSE_CODE);
                let ep2_len = if self.bus.isp1581_has_response() { 1u8 } else { 0u8 };
                let done = 1u8;
                log::debug!("TCP: Completion poll → done={}, sense=0x{:04X}, ep2_has_data={}",
                    done, sense_code, ep2_len);
                let mut resp = [0u8; 4];
                resp[0] = done;
                resp[1] = (sense_code >> 8) as u8;
                resp[2] = sense_code as u8;
                resp[3] = ep2_len; // 1 if EP2 IN has data
                self.send_tcp_frame(0x85, &resp);
            }
            0x08 => {
                // RAM read — read arbitrary memory region
                // Payload: [addr:4 BE] [len:2 BE]
                if payload.len() < 6 {
                    log::warn!("TCP: RAM read needs 6 bytes (addr:4 + len:2), got {}", payload.len());
                    self.send_tcp_frame(0x88, &[]);
                    return;
                }
                let addr = u32::from_be_bytes([payload[0], payload[1], payload[2], payload[3]]);
                let len = u16::from_be_bytes([payload[4], payload[5]]) as usize;
                let len = len.min(4096); // Cap at 4KB
                let mut data = vec![0u8; len];
                for i in 0..len {
                    data[i] = self.bus.read_byte(addr + i as u32);
                }
                log::info!("TCP: RAM read 0x{:06X} +{} bytes", addr, len);
                self.send_tcp_frame(0x88, &data);
            }
            _ => {
                log::warn!("TCP: Unknown message type 0x{:02X}", msg_type);
            }
        }
    }

    /// Send a TCP frame to the connected client.
    fn send_tcp_frame(&mut self, msg_type: u8, payload: &[u8]) {
        if payload.len() > 0xFFFF {
            log::error!("TCP: payload length {} exceeds frame max (65535). Dropping.", payload.len());
            return;
        }
        if let Some(ref mut stream) = self.tcp_client {
            use std::io::Write;
            let len = payload.len() as u16;
            let header = [(len >> 8) as u8, len as u8, msg_type];
            if let Err(e) = stream.write_all(&header) {
                log::warn!("TCP write error: {}. Disconnecting.", e);
                self.tcp_client = None;
                return;
            }
            if !payload.is_empty() {
                if let Err(e) = stream.write_all(payload) {
                    log::warn!("TCP write error: {}. Disconnecting.", e);
                    self.tcp_client = None;
                }
            }
        }
    }

    /// Send pending ISP1581 EP2 IN data back to TCP client (auto-push).
    /// This fires whenever firmware writes to EP2 IN between polls.
    fn send_tcp_response(&mut self) {
        let data = self.bus.isp1581_drain(65536);
        if data.is_empty() {
            return;
        }
        log::info!("TCP: Auto-push {} bytes from EP2 IN (type 0x82)", data.len());
        self.send_tcp_frame(0x82, &data);
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

    /// Decode and execute one instruction. Returns the decoded instruction,
    /// or None if CPU is sleeping and no wake condition is met.
    /// Panics / returns Unknown if an invalid instruction is encountered.
    fn decode_execute_one(&mut self) -> Option<decode::Decoded> {
        self.irq.check_and_service(&mut self.cpu, &mut self.bus);

        let decoded = decode::decode(&mut self.bus, self.cpu.pc);

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

        Some(decoded)
    }

    /// Execute one CPU instruction with full peripheral handling.
    /// Returns false if emulation should halt (unknown instruction).
    #[allow(dead_code)]
    pub fn step_one(&mut self) -> bool {
        if self.cpu.sleeping {
            self.check_peripherals();
            // Per H8/300H spec: SLEEP with I=1 stays halted until NMI
            if !self.irq.has_pending() || self.cpu.interrupt_masked() {
                return true;
            }
        }

        let decoded = match self.decode_execute_one() {
            Some(d) => d,
            None => return true,
        };

        if let decode::Instruction::Unknown(w) = &decoded.insn {
            log::error!("step_one: HALT: Unknown instruction 0x{:04X} at PC=0x{:06X}", w, self.cpu.pc);
            self.dump_stack();
            self.dump_state();
            return false;
        }

        self.sync_peripherals();
        self.check_peripherals();
        true
    }
}
