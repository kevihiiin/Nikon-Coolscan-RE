//! Emulator orchestrator — wires CPU, memory, peripherals, and bridges together.

use h8300h_core::cpu::Cpu;
use h8300h_core::decode;
use h8300h_core::execute;
use h8300h_core::interrupt::{InterruptController, vectors};
use h8300h_core::memory::MemoryBus;

use peripherals::asic::Asic;
use peripherals::isp1581::Isp1581;
use peripherals::bus::PeripheralBus;
use peripherals::gpio;

use std::net::TcpListener;

use bridge::traits::UsbBridge;
use crate::config::Config;

/// Result of a SCSI command executed via the emulator's internal handler.
pub struct ScsiResult {
    /// Sense key (0 = GOOD, 5 = ILLEGAL REQUEST, etc.)
    pub sense_key: u8,
    /// Additional sense code
    pub asc: u8,
    /// Data-in response (empty for commands with no data phase)
    pub data: Vec<u8>,
}

impl ScsiResult {
    /// Returns true if the command completed with GOOD status.
    pub fn is_good(&self) -> bool {
        self.sense_key == 0
    }
}

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

// --- SCSI dispatch table (for firmware-dispatched SCSI) ---
const FW_DISPATCH_TABLE: u32 = 0x049834;   // 21 entries, 10-byte stride
const FW_DISPATCH_ENTRIES: usize = 21;
const FW_DISPATCH_STRIDE: usize = 10;
// Table layout per entry: [opcode:1][pad:1][perm_flags:2][handler_addr:4][exec_mode:1][pad:1]
const FW_DISPATCH_SENTINEL: u32 = 0x0DEAD0; // Return address for handler hooking

pub struct Emulator {
    pub cpu: Cpu,
    pub bus: MemoryBus,
    pub irq: InterruptController,
    pub asic: Asic,
    pub peripherals: PeripheralBus,
    pub motor: peripherals::motor::MotorSubsystem,
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
    /// True if `--port` was requested and the listener bound successfully.
    /// Callers (main.rs) use this to fail-fast when TCP is required but bind
    /// failed (e.g., port already in use). Without this signal, a startup
    /// error would be buried in boot logs and the emulator would appear to
    /// start normally with a non-functional bridge.
    pub tcp_bridge_active: bool,
    /// Accumulator for partial TCP reads. Non-blocking `read()` can return
    /// fewer bytes than a full frame header + payload; we buffer partials
    /// until a complete frame is available, then drain it for processing.
    /// Fixes the silent data-loss bug where `read_exact` on a non-blocking
    /// socket discarded already-read bytes when the remainder wasn't ready.
    tcp_read_buffer: Vec<u8>,
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
    /// Scan test pattern type.
    scan_pattern: crate::config::ScanPattern,
    /// Scanner model identity.
    model: crate::config::ScannerModel,
    /// Path to raw scan data file (overrides pattern generation).
    scan_data_path: Option<std::path::PathBuf>,
    /// Cold boot mode: skip warm-boot shortcuts.
    cold_boot: bool,
    /// Full USB init: don't NOP USB init patches.
    full_usb_init: bool,
    /// Firmware dispatch: route SCSI through firmware handlers.
    firmware_dispatch: bool,
    /// Force Rust SCSI emulation (--emulated-scsi safety net).
    emulated_scsi: bool,
    /// USB gadget bridge (connects ISP1581 to real USB host).
    gadget: Option<Box<dyn UsbBridge>>,
    /// Userspace USB/IP server bridge (M14.5 — no root, no kernel modules).
    /// Mutually exclusive with `gadget` at the CLI layer; both targets the
    /// same ISP1581 FIFOs.
    usbip: Option<Box<dyn UsbBridge>>,
    /// True when the USB/IP bridge is set up and waiting for the firmware
    /// to reach main loop so we can restore INQUIRY's handler-internal
    /// data-transfer patches. Cleared after the patches are restored.
    usbip_inquiry_patches_pending: bool,
}

/// Extract complete TCP bridge frames from an accumulator buffer.
///
/// Frame wire format: `[len_hi, len_lo, msg_type, payload...]`. Length is
/// big-endian u16 (range 0..=65535), so by construction a payload claim
/// can't exceed what 16 bits encode — no per-frame ceiling is needed and
/// no error path is reachable. Combined with the per-poll read cap on the
/// caller side, the accumulator can never grow past ~65538 bytes leftover
/// after parsing (one in-flight unsatisfied claim).
///
/// Fully-parsed bytes are drained from `buf`; a trailing partial frame stays
/// put for the next call.
fn extract_tcp_frames(buf: &mut Vec<u8>) -> Vec<(u8, Vec<u8>)> {
    let mut frames = Vec::new();
    let mut pos = 0usize;
    while buf.len() - pos >= 3 {
        let len_hi = buf[pos];
        let len_lo = buf[pos + 1];
        let msg_type = buf[pos + 2];
        let payload_len = ((len_hi as usize) << 8) | len_lo as usize;
        if buf.len() - pos < 3 + payload_len {
            break; // Incomplete frame — wait for more bytes
        }
        let payload = buf[pos + 3..pos + 3 + payload_len].to_vec();
        frames.push((msg_type, payload));
        pos += 3 + payload_len;
    }
    if pos > 0 {
        buf.drain(0..pos);
    }
    frames
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

        // Pre-install trampolines in on-chip RAM (warm boot only).
        // In cold boot, the firmware installs these itself (0x0204C4-0x0205F7).
        if !config.cold_boot {
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
                bus.write_byte(ram_addr, 0x5A);
                bus.write_byte(ram_addr + 1, (handler >> 16) as u8);
                bus.write_byte(ram_addr + 2, (handler >> 8) as u8);
                bus.write_byte(ram_addr + 3, handler as u8);
            }
            log::info!("Pre-installed {} trampolines in on-chip RAM", trampolines.len());
        } else {
            log::info!("Cold boot: firmware will install its own trampolines");
        }

        // Cold boot: use ASIC ready countdown instead of immediate ready
        let mut asic = Asic::new();
        if config.cold_boot {
            asic.cold_boot_mode = true;
            log::info!("Cold boot: ASIC ready will be delayed by ~50000 instructions");
        }

        // Context system and flash NOP patches are applied JIT (just before first TRAPA #0)
        // because the RAM test overwrites 0x400000-0x420000 during early boot.

        // Set up TCP listener if port configured
        let tcp_listener = if config.tcp_port > 0 {
            match TcpListener::bind(format!("127.0.0.1:{}", config.tcp_port)) {
                Ok(listener) => {
                    if let Err(e) = listener.set_nonblocking(true) {
                        log::error!("Failed to set TCP listener non-blocking: {}. Aborting TCP bridge.", e);
                        None
                    } else {
                        log::info!("TCP bridge listening on port {}", config.tcp_port);
                        Some(listener)
                    }
                }
                Err(e) => {
                    log::error!("Failed to bind TCP port {}: {}. No TCP bridge.", config.tcp_port, e);
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
            asic,
            peripherals,
            motor: peripherals::motor::MotorSubsystem::new(),
            trace: config.trace,
            context_initialized: false,
            last_ctx_a_sp: 0,
            last_ctx_b_sp: 0,
            ctx_switch_count: 0,
            milestones_seen: std::collections::HashSet::new(),
            tcp_bridge_active: tcp_listener.is_some(),
            tcp_listener,
            tcp_client: None,
            tcp_read_buffer: Vec::new(),
            pending_dataout_opcode: None,
            reserved: false,
            scan_active: false,
            window_descriptor: Vec::new(),
            scan_data: Vec::new(),
            scan_data_offset: 0,
            scan_pattern: config.pattern,
            model: config.model,
            scan_data_path: config.scan_data_path.clone(),
            cold_boot: config.cold_boot,
            full_usb_init: config.full_usb_init,
            firmware_dispatch: config.firmware_dispatch,
            emulated_scsi: config.emulated_scsi,
            gadget: None,
            usbip: None,
            usbip_inquiry_patches_pending: false,
        }
    }

    pub fn reset_vector(&self) -> u32 {
        self.cpu.pc
    }

    /// Run the emulator for up to max_instructions.
    pub fn run(&mut self, max_instructions: u64) {
        self.run_with_shutdown(max_instructions, None);
    }

    /// Same as `run`, but checks `shutdown` periodically and exits the loop
    /// cleanly (so `Drop` impls — notably `GadgetBridge` — fire) when set.
    pub fn run_with_shutdown(
        &mut self,
        max_instructions: u64,
        shutdown: Option<&std::sync::atomic::AtomicBool>,
    ) {
        use std::sync::atomic::Ordering;
        for i in 0..max_instructions {
            if let Some(flag) = shutdown
                && i % 1000 == 0
                && flag.load(Ordering::Relaxed)
            {
                log::warn!(
                    "Shutdown signal received — exiting after {} instructions at PC=0x{:06X}",
                    i, self.cpu.pc
                );
                self.dump_state();
                return;
            }
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
            if !self.context_initialized && matches!(&decoded.insn, decode::Instruction::Trapa(0)) {
                if !self.cold_boot {
                    self.jit_context_init();
                }
                self.apply_flash_nop_patches();
                self.context_initialized = true;
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
                self.poll_gadget();
                self.poll_usbip();
                self.force_usb_session_state();
            }

            self.handle_oneshot_actions(pre_exec_pc, i);
            self.log_milestone(i);
        }

        // The for-loop only completes if it ran to max_instructions — every
        // other exit path uses early return with its own log. So reaching
        // here means the cap was hit. If the user passed `--max N`, they
        // probably want to know their run was truncated; if they passed
        // u64::MAX (default unlimited), this never fires in practice.
        if max_instructions == u64::MAX {
            log::info!(
                "Emulation completed {} instructions (unlimited cap). PC=0x{:06X}",
                max_instructions, self.cpu.pc
            );
        } else {
            log::warn!(
                "Emulation hit instruction cap ({}). PC=0x{:06X}. \
                 Pass `--max 0` for unlimited or a higher `--max` value.",
                max_instructions, self.cpu.pc
            );
        }
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
        // USB init patches — skipped when --full-usb-init is set
        let usb_init_patches: &[(u32, u32, &str)] = &[
            (0x012EC6, 0x5E01350A, "USB setup call (JSR @0x01350A)"),
            (0x012ECE, 0x5E013506, "USB fast-path call (JSR @0x013506)"),
            (0x02080E, 0x5E010D22, "shared module init (JSR @0x010D22)"),
            (0x020820, 0x5E01233A, "USB configure (JSR @0x01233A)"),
            (0x020824, 0x5E0126EE, "USB endpoint enable (JSR @0x0126EE)"),
        ];

        // SCSI dispatch/handler patches — always applied (unless firmware-dispatch changes this)
        let scsi_patches: &[(u32, u32, &str)] = &[
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
            // Post-handler dispatch response manager call in FW:0x01117A
            // (called from dispatcher at 0x020B3E). Without this NOP, the
            // dispatcher sends ADDITIONAL data after the handler already sent,
            // causing the response to appear at the wrong offset.
            (0x011186, 0x5E01374A, "post-handler response mgr (0x011186)"),
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
        let mut total = 0;

        // Zero-patch mode: --full-usb-init + --firmware-dispatch without --emulated-scsi
        // means firmware handles everything — no patches needed.
        let zero_patch = self.full_usb_init && self.firmware_dispatch && !self.emulated_scsi;

        if zero_patch {
            log::info!("JIT: ZERO PATCH MODE — firmware handles USB init + SCSI autonomously");
            return;
        }

        if !self.full_usb_init {
            for &(addr, expected, desc) in usb_init_patches {
                total += 1;
                let actual = self.bus.read_long(addr);
                if actual != expected {
                    log::warn!("JIT: SKIP patch {} at 0x{:06X}: found 0x{:08X}, expected 0x{:08X}", desc, addr, actual, expected);
                    continue;
                }
                self.bus.flash_write_long(addr, 0x00000000);
                patched += 1;
            }
        } else {
            log::info!("JIT: Skipping {} USB init patches (--full-usb-init)", usb_init_patches.len());
        }

        for &(addr, expected, desc) in scsi_patches {
            total += 1;
            let actual = self.bus.read_long(addr);
            if actual != expected {
                log::warn!("JIT: SKIP patch {} at 0x{:06X}: found 0x{:08X}, expected 0x{:08X}", desc, addr, actual, expected);
                continue;
            }
            self.bus.flash_write_long(addr, 0x00000000);
            patched += 1;
        }

        log::info!("JIT: NOPed {}/{} USB/SCSI calls in flash", patched, total);
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
        if self.ctx_switch_count <= 10 || self.ctx_switch_count.is_multiple_of(10000) {
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
                            if xfer_len > 0 { data[0] = 0x06; } // Device type: scanner
                            if xfer_len > 3 { data[3] = pages.len() as u8; } // Page length
                            for (i, &p) in pages.iter().enumerate() {
                                if 4 + i < xfer_len { data[4 + i] = p; }
                            }
                            self.bus.isp1581_push_to_host(&data);
                            log::info!("SCSI EMU: INQUIRY EVPD page 0x00 → {} bytes", xfer_len);
                        }
                        0xC0 => {
                            // VPD page 0xC0: CCD readout configuration (per-adapter).
                            // 5 bytes of CCD config data per data-tables.md.
                            let xfer_len = alloc_len.min(9);
                            let mut data = vec![0u8; xfer_len];
                            if xfer_len > 0 { data[0] = 0x06; } // Device type: scanner
                            if xfer_len > 1 { data[1] = 0xC0; } // Page code
                            if xfer_len > 3 { data[3] = 5; }    // Page length
                            // Per-adapter CCD readout config
                            let adapter = self.peripherals.gpio.adapter_type();
                            match adapter {
                                gpio::AdapterType::SaMount => {
                                    // SA-21: single frame, 24x36mm
                                    if xfer_len > 4 { data[4] = 0x01; } // frame count
                                    if xfer_len > 5 { data[5] = 0x01; } // CCD mode
                                    if xfer_len > 6 { data[6] = 0x00; } // offset high
                                    if xfer_len > 7 { data[7] = 0x00; } // offset low
                                    if xfer_len > 8 { data[8] = 0x24; } // frame size (36mm)
                                }
                                gpio::AdapterType::SfStrip => {
                                    // SF-210: 6 frames sequential
                                    if xfer_len > 4 { data[4] = 0x06; } // frame count
                                    if xfer_len > 5 { data[5] = 0x01; }
                                    if xfer_len > 8 { data[8] = 0x24; }
                                }
                                _ => {
                                    // Default: single frame
                                    if xfer_len > 4 { data[4] = 0x01; }
                                    if xfer_len > 5 { data[5] = 0x01; }
                                }
                            }
                            self.bus.isp1581_push_to_host(&data);
                            log::info!("SCSI EMU: INQUIRY EVPD page 0xC0 → {} bytes (adapter {:?})", xfer_len, adapter);
                        }
                        0xC1 => {
                            // VPD page 0xC1: CCD readout capabilities.
                            // 5 bytes per data-tables.md.
                            let xfer_len = alloc_len.min(9);
                            let mut data = vec![0u8; xfer_len];
                            if xfer_len > 0 { data[0] = 0x06; } // Device type
                            if xfer_len > 1 { data[1] = 0xC1; } // Page code
                            if xfer_len > 3 { data[3] = 5; }    // Page length
                            // Max resolution capability
                            if xfer_len > 4 { data[4] = 0x04; } // 4000 DPI max (high byte)
                            if xfer_len > 5 { data[5] = 0xB0; } // 4000 DPI max (0x04B0 = 1200)
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
                        if xfer_len > 1 { data[1] = 0x80; } // RMB: removable media (film)
                        if xfer_len > 2 { data[2] = 0x02; } // SCSI-2
                        if xfer_len > 3 { data[3] = 0x02; } // Response format 2
                        if xfer_len > 4 { data[4] = 0x1F; } // Additional length
                        // Vendor/product/revision from flash, with model override
                        if xfer_len >= 36 {
                            for j in 0..28 {
                                data[8 + j] = self.bus.read_byte(FW_INQUIRY_FLASH + j as u32);
                            }
                            // Override product string for LS-5000 model
                            if self.model == crate::config::ScannerModel::Ls5000 {
                                let product = b"LS-5000 ED      ";
                                data[16..32].copy_from_slice(product);
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
                    if xfer_len > 4 && (page_code == 0x03 || page_code == 0x3F) && xfer_len >= 16 {
                        data[4] = 0x03; // Page code
                        data[5] = 0x0A; // Page length (10)
                        data[8] = 0x01; data[9] = 0x2C; // X res = 300
                        data[10] = 0x01; data[11] = 0x2C; // Y res = 300
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
                // SEND DIAGNOSTIC: interpret motor task codes from data-out.
                // The host sends a 4-byte parameter with task code in bytes 0-1.
                let param_data = self.bus.isp1581_drain_host_data(16);
                let task_code = if param_data.len() >= 2 {
                    ((param_data[0] as u16) << 8) | param_data[1] as u16
                } else {
                    0
                };
                match task_code {
                    0x0400 => {
                        // Motor stop
                        self.motor.stop();
                        log::info!("SCSI EMU: SEND DIAGNOSTIC task 0x0400 → motor stop");
                    }
                    0x0430 => {
                        // Motor home — drive to position 0
                        self.motor.set_target(0);
                        if self.motor.instant_mode {
                            let motor = self.motor.active_motor_mut();
                            motor.position = 0;
                            motor.home_sensor = true;
                            motor.running = false;
                        }
                        log::info!("SCSI EMU: SEND DIAGNOSTIC task 0x0430 → motor home");
                    }
                    0x0440 => {
                        // Relative move — param bytes 2-3 = step count
                        let steps = if param_data.len() >= 4 {
                            ((param_data[2] as i16) << 8 | param_data[3] as i16) as i32
                        } else { 0 };
                        let pos = self.motor.active_motor().position;
                        self.motor.set_target(pos + steps);
                        if self.motor.instant_mode {
                            self.motor.active_motor_mut().position = pos + steps;
                            self.motor.active_motor_mut().home_sensor = (pos + steps) == 0;
                            self.motor.stop();
                        }
                        log::info!("SCSI EMU: SEND DIAGNOSTIC task 0x0440 → relative move {} steps", steps);
                    }
                    0x0450 => {
                        // Absolute move — param bytes 2-3 = target position
                        let target = if param_data.len() >= 4 {
                            ((param_data[2] as i16) << 8 | param_data[3] as i16) as i32
                        } else { 0 };
                        self.motor.set_target(target);
                        if self.motor.instant_mode {
                            self.motor.active_motor_mut().position = target;
                            self.motor.active_motor_mut().home_sensor = target == 0;
                            self.motor.stop();
                        }
                        log::info!("SCSI EMU: SEND DIAGNOSTIC task 0x0450 → absolute move to {}", target);
                    }
                    0x0500..=0x0502 => {
                        // Calibration tasks: dark frame, white reference, per-channel
                        // In real hardware, these trigger CCD capture in DAC mode 0xA2.
                        // We pre-populate calibration results with reasonable defaults.
                        // Firmware routines at 0x3D12D/0x3DE51/0x3EEF9/0x3F897
                        // compute min/max from CCD data, writing to:
                        //   0x400F0A (min), 0x400F12 (mid), 0x400F1A (max)
                        self.bus.write_word(0x400F0A, 0x0020); // cal min
                        self.bus.write_word(0x400F12, 0x2000); // cal mid
                        self.bus.write_word(0x400F1A, 0x3F00); // cal max
                        log::info!("SCSI EMU: SEND DIAGNOSTIC task 0x{:04X} → calibration complete", task_code);
                    }
                    _ => {
                        log::info!("SCSI EMU: SEND DIAGNOSTIC task 0x{:04X} → GOOD (unhandled)", task_code);
                    }
                }
                self.scsi_good();
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
            0x1C => {
                // RECEIVE DIAGNOSTIC RESULTS: return diagnostic data.
                // The scanner uses this after SEND DIAGNOSTIC to read results.
                // Return zeros (no diagnostic data available).
                let alloc_len = self.bus.read_byte(FW_CDB_BUFFER + 4) as usize;
                let xfer_len = alloc_len.min(256);
                if xfer_len > 0 {
                    let data = vec![0u8; xfer_len];
                    self.bus.isp1581_push_to_host(&data);
                }
                self.scsi_good();
                log::info!("SCSI EMU: RECEIVE DIAGNOSTIC → {} bytes (zeros)", xfer_len);
            }
            0x3B => {
                // WRITE BUFFER: firmware flash update attempt.
                // Not an emulation goal — return CHECK CONDITION with
                // DATA PROTECT / WRITE PROTECTED sense (SK=7, ASC=0x27).
                let xfer_len = self.cdb_xfer_len_24() as usize;
                if xfer_len > 0 {
                    let _data = self.bus.isp1581_drain_host_data(xfer_len);
                }
                self.bus.write_word(FW_SENSE_CODE, 0x0727); // SK=7 DATA PROTECT, ASC=0x27
                log::warn!("SCSI EMU: WRITE BUFFER → DATA PROTECT (write-protected, {} bytes discarded)", xfer_len);
            }
            0x3C => {
                // READ BUFFER: return buffer contents.
                // Mode 0x00 = combined header + data, mode 0x02 = data only.
                let mode = self.bus.read_byte(FW_CDB_BUFFER + 1) & 0x07;
                let alloc_len = self.cdb_xfer_len_24() as usize;
                let xfer_len = alloc_len.min(4096);
                if mode == 0x00 && xfer_len >= 4 {
                    // Combined: 4-byte header (buffer capacity) + data
                    let mut data = vec![0u8; xfer_len];
                    // Report 0 buffer capacity
                    data[1] = 0x00; data[2] = 0x00; data[3] = 0x00;
                    self.bus.isp1581_push_to_host(&data);
                } else if xfer_len > 0 {
                    let data = vec![0u8; xfer_len];
                    self.bus.isp1581_push_to_host(&data);
                }
                self.scsi_good();
                log::info!("SCSI EMU: READ BUFFER mode {} → {} bytes", mode, xfer_len);
            }
            0xD0 => {
                // PHASE QUERY: return current SCSI command phase byte.
                // NKDUSCAN.dll sends this to check if the scanner is ready
                // for data transfer. Phase byte at 0x40049C:
                //   0x00 = idle/ready, 0x01 = data-in, 0x02 = data-out
                let phase = self.bus.read_byte(0x40049C);
                self.bus.isp1581_push_to_host(&[phase]);
                self.scsi_good();
                log::info!("SCSI EMU: PHASE QUERY → phase=0x{:02X}", phase);
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
        use crate::config::ScanPattern;

        let op_type = self.bus.read_byte(FW_CDB_BUFFER + 4);
        let (width, height, bpp, channels) = self.parse_scan_dimensions();
        let bytes_per_pixel = if bpp > 8 { 2 } else { 1 };
        let image_size = width * height * bytes_per_pixel * channels;

        // Try loading scan data from file if configured
        if let Some(ref path) = self.scan_data_path {
            match std::fs::read(path) {
                Ok(file_data) => {
                    if file_data.len() < image_size {
                        log::warn!("Scan data file {} is {} bytes, expected {}. Padding with zeros.",
                            path.display(), file_data.len(), image_size);
                        let mut padded = file_data;
                        padded.resize(image_size, 0);
                        self.scan_data = padded;
                    } else {
                        self.scan_data = file_data[..image_size].to_vec();
                    }
                    self.scan_data_offset = 0;
                    self.scan_active = true;
                    self.scsi_good();
                    log::info!("SCSI EMU: SCAN op={} → GOOD ({}x{} {}bpp from file, {} bytes)",
                        op_type, width, height, bpp, self.scan_data.len());
                    return;
                }
                Err(e) => {
                    log::error!("Failed to read scan data file {}: {}", path.display(), e);
                    self.bus.write_word(FW_SENSE_CODE, 0x0440); // Hardware Error
                    self.scan_active = false;
                    return;
                }
            }
        }

        let mut data = Vec::with_capacity(image_size);
        for y in 0..height {
            for x in 0..width {
                for ch in 0..channels {
                    let val8 = match self.scan_pattern {
                        ScanPattern::Gradient => match ch {
                            0 => (x * 255 / width.max(1)) as u8,
                            1 => (y * 255 / height.max(1)) as u8,
                            _ => ((x + y) * 255 / (width + height).max(1)) as u8,
                        },
                        ScanPattern::Flat => 128,
                        ScanPattern::Checkerboard => {
                            if ((x / 8) + (y / 8)) % 2 == 0 { 255 } else { 0 }
                        }
                        ScanPattern::ColorBars => {
                            // 8 vertical bars: White, Yellow, Cyan, Green, Magenta, Red, Blue, Black
                            let bar = x * 8 / width.max(1);
                            match (bar, ch) {
                                (0, _) => 255,                         // White
                                (1, 0) | (1, 1) => 255,               // Yellow (R+G)
                                (1, _) => 0,
                                (2, 1) | (2, 2) => 255,               // Cyan (G+B)
                                (2, _) => 0,
                                (3, 1) => 255,                         // Green
                                (3, _) => 0,
                                (4, 0) | (4, 2) => 255,               // Magenta (R+B)
                                (4, _) => 0,
                                (5, 0) => 255,                         // Red
                                (5, _) => 0,
                                (6, 2) => 255,                         // Blue
                                (6, _) => 0,
                                _ => 0,                                // Black
                            }
                        }
                    };
                    if bytes_per_pixel == 2 {
                        let val16 = (val8 as u16) << 8 | val8 as u16;
                        data.push((val16 >> 8) as u8);
                        data.push(val16 as u8);
                    } else {
                        data.push(val8);
                    }
                }
            }
        }

        self.scan_data = data;
        self.scan_data_offset = 0;
        self.scan_active = true;
        self.scsi_good();
        log::info!("SCSI EMU: SCAN op={} pattern={:?} → GOOD ({}x{} {}bpp, {} bytes)",
            op_type, self.scan_pattern, width, height, bpp, self.scan_data.len());
    }

    /// Parse scan dimensions from stored window descriptor.
    /// Returns (width_pixels, height_pixels, bits_per_pixel, channels).
    fn parse_scan_dimensions(&self) -> (usize, usize, usize, usize) {
        if self.window_descriptor.len() < 48 {
            log::warn!("SCSI EMU: No window descriptor set, using default 100x100 8bpp RGB");
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
        // When full_usb_init is set, firmware manages USB state itself.
        if self.full_usb_init {
            return;
        }
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

        // --- SCI0 sync ---
        // SCI0 SSR at 0xFFFFB4 — pin TDRE=1 (transmit ready) so firmware's
        // polled serial TX exits immediately. Firmware never blocks on RX.
        self.bus.onchip_io[0xB4] = self.peripherals.sci0.ssr;

        // --- Watchdog feed sync ---
        // Firmware writes 0x5A to TCSR (0xFFFFA8) to feed the watchdog. The
        // bus stores the byte but can't call into the WDT model directly,
        // so we detect the feed pattern here and forward it. Byte is consumed
        // (cleared) so the feed fires exactly once per firmware write.
        if self.bus.onchip_io[0xA8] == 0x5A {
            self.peripherals.watchdog.write(0x5A);
            self.bus.onchip_io[0xA8] = 0;
        }

        // --- Motor sync ---
        // Detect stepper phase changes on Port A DR (0xA3) and track position.
        let port_a = self.bus.onchip_io[0xA3];
        let dir_bit = self.bus.onchip_io[0x84] & 0x01 != 0; // Port 3 DR bit 0
        let motor_mode = self.bus.read_byte(0x400774);
        if motor_mode != self.motor.active_mode && motor_mode != 0 {
            self.motor.set_mode(motor_mode);
        }
        let steps = self.motor.port_a_write(port_a, dir_bit);
        if steps > 0 {
            // Update encoder RAM variables for the firmware's encoder ISR
            let motor = self.motor.active_motor();
            self.bus.write_word(0x40530E, motor.position as u16); // encoder_count
            let sys_tick = self.bus.read_long(0x40076E);
            self.bus.write_long(0x405318, sys_tick); // encoder_timestamp
            // encoder_delta = timer period estimate (use a fixed value)
            self.bus.write_word(0x405314, 100); // reasonable step period
        }
        // Sync home sensor to GPIO Port 7
        self.peripherals.gpio.home_sensor = self.motor.scan_motor.home_sensor;

        // Check motor completion: if running and reached target position
        if self.motor.active_motor().running && self.motor.active_motor().step_count > 0 {
            let motor = self.motor.active_motor();
            if motor.position == motor.target && motor.target != 0 {
                // Motor reached target — set completion flags
                self.bus.write_byte(0x4052EB, 0); // motor_running = stopped
                self.bus.write_byte(0x4052EC, 1); // motor_state = done
                self.bus.write_byte(0x4052EE, 0); // motor_error = none
                self.motor.stop();
            }
        }

        // --- ASIC sync ---
        // Sync lamp state from GPIO to ASIC (affects calibration data)
        self.asic.lamp_on = self.peripherals.gpio.lamp_on;
        let master = self.bus.asic_reg(0x0001);
        if master != self.asic.read(0x0001) {
            self.asic.write(0x0001, master);
            self.bus.set_asic_reg(0x0041, self.asic.read(0x0041));
        }
        // Firmware writes to 0x200000-0x200FFF go into the bus's asic_regs[]
        // backing store. Forward behavioral registers to the Asic model so its
        // side effects (DMA countdown, pixel generation) run. asic_dirty is set
        // by MemoryBus::write_byte on any ASIC region write and cleared here.
        if self.bus.asic_dirty {
            self.bus.asic_dirty = false;
            // DAC mode — affects calibration pixel levels (0x22 scan, 0xA2 cal)
            let dac = self.bus.asic_reg(0x00C2);
            if dac != self.asic.read(0x00C2) {
                self.asic.write(0x00C2, dac);
            }
            // DMA buffer address (24-bit big-endian)
            for &off in &[0x0147u16, 0x0148, 0x0149] {
                let v = self.bus.asic_reg(off as usize);
                if v != self.asic.read(off) {
                    self.asic.write(off, v);
                }
            }
            // DMA transfer count (24-bit big-endian)
            for &off in &[0x014Bu16, 0x014C, 0x014D] {
                let v = self.bus.asic_reg(off as usize);
                if v != self.asic.read(off) {
                    self.asic.write(off, v);
                }
            }
        }
        // Edge-triggered CCD trigger: forward unconditionally per firmware
        // write, not per byte-value change. Repeat writes of the same byte
        // (e.g., 0x80 for every scan line) must all produce a line of pixels.
        if let Some(trig) = self.bus.ccd_trigger_write.take() {
            self.asic.write(0x01C1, trig);
        }
        self.bus.set_asic_reg(0x0002, self.asic.read(0x0002));
        let asic_dma_done = self.asic.tick();

        // DMA completion handling. Setting the pending flag here (not in tick())
        // guarantees Vec 49 fires exactly once per CCD line capture. The flag
        // is set unconditionally on completion — never gate on data presence or
        // firmware hangs waiting for an IRQ that will never come.
        if asic_dma_done {
            if self.asic.last_line_data.is_empty() {
                log::warn!("ASIC DMA completed with no pixel data — firmware \
                    likely set dma_busy_countdown without triggering via 0x01C1");
            } else {
                let dest = self.asic.dma_address();
                let data = self.asic.last_line_data.clone();
                for (i, &b) in data.iter().enumerate() {
                    self.bus.write_byte(dest + i as u32, b);
                }
                log::debug!("CCD: {} bytes written to ASIC RAM at 0x{:06X}", data.len(), dest);
            }
            self.asic.dma_complete_pending = true;
        }

        // --- DMA sync ---
        // Route on-chip I/O DMA register writes to the DMA controller model.
        // DMA registers: 0x20-0x2F (channels), 0x90 (DMAOR).
        for &offset in &[0x20u8, 0x21, 0x22, 0x23, 0x24, 0x25, 0x27,
                         0x28, 0x29, 0x2A, 0x2B, 0x2C, 0x2D, 0x2F, 0x90] {
            let bus_val = self.bus.onchip_io[offset as usize];
            let model_val = self.peripherals.dma.read(offset);
            if bus_val == model_val { continue; }
            if let Some(ch) = self.peripherals.dma.write(offset, bus_val) {
                log::debug!("DMA ch{}: triggered MAR=0x{:06X} ETCR={}",
                    ch, self.peripherals.dma.channels[ch].mar,
                    self.peripherals.dma.channels[ch].etcr);
            }
        }
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
                // ITU4 is the low-priority system tick — keep all three of its
                // interrupt sources (IMIA, IMIB, OVI) at LOW so they can't
                // preempt a running motor or DMA handler.
                vectors::IMIA4 | vectors::IMIB4 | vectors::OVI4 => vectors::PRIORITY_LOW,
                _ => vectors::PRIORITY_MEDIUM,
            };
            self.irq.assert_interrupt(vec, priority);
        }

        // Watchdog: advances the counter. Disabled by default, so existing runs
        // are unaffected; the --watchdog flag enables timeout detection.
        if self.peripherals.watchdog.tick() {
            log::error!("WATCHDOG: timeout — firmware did not feed within window");
        }

        // ISP1581 tick (bus reset, deferred state transitions)
        self.bus.isp1581_tick();

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
        if self.asic.take_ccd_trigger() {
            self.irq.assert_interrupt(vectors::VEC49, vectors::PRIORITY_MEDIUM);
        }

        // ASIC DMA completion → Vec 49 (CCD line readout complete)
        if self.asic.take_dma_complete() {
            self.irq.assert_interrupt(vectors::VEC49, vectors::PRIORITY_MEDIUM);
        }

        // H8 DMA completion → Vec 45 (DEND0B) / Vec 47 (DEND1B)
        if self.peripherals.dma.take_complete(0) {
            self.irq.assert_interrupt(vectors::DEND0B, vectors::PRIORITY_MEDIUM);
        }
        if self.peripherals.dma.take_complete(1) {
            self.irq.assert_interrupt(vectors::DEND1B, vectors::PRIORITY_MEDIUM);
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
        if self.tcp_client.is_none()
            && let Some(ref listener) = self.tcp_listener
            && let Ok((stream, addr)) = listener.accept()
        {
            if let Err(e) = stream.set_nonblocking(true) {
                log::error!("Failed to set TCP client non-blocking: {}. Rejecting connection.", e);
            } else {
                log::info!("TCP client connected from {}", addr);
                self.tcp_client = Some(stream);
                // Fresh connection — discard any residue from the previous client.
                self.tcp_read_buffer.clear();
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
            // Drain whatever bytes are available into the per-connection read
            // buffer. We bound the work per poll: a fast or adversarial peer
            // shouldn't be able to monopolize the CPU loop. Once we've taken
            // ~64 KB this poll, yield back so the firmware can run and we
            // can drain on the next 1000-instruction tick.
            let mut tmp = [0u8; 4096];
            const MAX_BYTES_PER_POLL: usize = 64 * 1024;
            let mut read_this_poll = 0usize;
            while read_this_poll < MAX_BYTES_PER_POLL {
                match stream.read(&mut tmp) {
                    Ok(0) => {
                        // Peer closed cleanly
                        log::info!("TCP client disconnected (EOF)");
                        disconnect = true;
                        break;
                    }
                    Ok(n) => {
                        self.tcp_read_buffer.extend_from_slice(&tmp[..n]);
                        read_this_poll += n;
                    }
                    Err(ref e) if e.kind() == std::io::ErrorKind::Interrupted => {
                        // EINTR (signal during syscall) — retry per Rust convention.
                        continue;
                    }
                    Err(ref e) if e.kind() == std::io::ErrorKind::WouldBlock => {
                        break; // No more data right now
                    }
                    Err(e) => {
                        log::info!("TCP client disconnected: {}", e);
                        disconnect = true;
                        break;
                    }
                }
            }
        }
        // Parse complete frames out of the accumulator. Any trailing bytes
        // that don't form a full header+payload stay buffered for next poll.
        frames.extend(extract_tcp_frames(&mut self.tcp_read_buffer));
        if disconnect {
            if !self.tcp_read_buffer.is_empty() {
                log::info!("TCP: dropping {} buffered bytes on disconnect", self.tcp_read_buffer.len());
            }
            self.tcp_client = None;
            self.tcp_read_buffer.clear();
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
                    payload.first().copied().unwrap_or(0),
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
                for (i, byte) in data.iter_mut().enumerate() {
                    *byte = self.bus.read_byte(addr + i as u32);
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
            if !payload.is_empty()
                && let Err(e) = stream.write_all(payload)
            {
                log::warn!("TCP write error: {}. Disconnecting.", e);
                self.tcp_client = None;
            }
        }
    }

    /// Send pending ISP1581 EP2 IN data back to TCP client (auto-push).
    /// This fires whenever firmware writes to EP2 IN between polls.
    fn send_tcp_response(&mut self) {
        // When gadget is active, it owns the EP2 IN FIFO. Don't drain here
        // or we'd steal response data meant for the real USB host.
        if self.gadget.is_some() {
            return;
        }
        let data = self.bus.isp1581_drain(65536);
        if data.is_empty() {
            return;
        }
        log::info!("TCP: Auto-push {} bytes from EP2 IN (type 0x82)", data.len());
        self.send_tcp_frame(0x82, &data);
    }

    /// Inject a CDB directly (for testing without TCP).
    /// Restore a previously NOPed flash location to its original instruction.
    /// Used for Phase 7 gate tracing: selectively un-NOP specific patches.
    pub fn restore_flash_patch(&mut self, addr: u32, original_bytes: u32) {
        self.bus.flash_write_long(addr, original_bytes);
        log::info!("RESTORE PATCH: 0x{:06X} = 0x{:08X}", addr, original_bytes);
    }

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

        // Pre-check: return Unknown without executing so callers can handle gracefully
        if let decode::Instruction::Unknown(_) = &decoded.insn {
            return Some(decoded);
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

        Some(decoded)
    }

    // --- Public API for integration tests ---

    /// Boot the firmware: run until main loop is reached or max_instructions exceeded.
    /// Returns true if main loop was reached.
    pub fn boot_to_main_loop(&mut self, max_instructions: u64) -> bool {
        for i in 0..max_instructions {
            if self.cpu.sleeping {
                self.check_peripherals();
                if !self.irq.has_pending() || self.cpu.interrupt_masked() {
                    continue;
                }
            }

            self.irq.check_and_service(&mut self.cpu, &mut self.bus);

            let decoded = decode::decode(&mut self.bus, self.cpu.pc);

            if let decode::Instruction::Unknown(w) = &decoded.insn {
                log::error!("boot: Unknown instruction 0x{:04X} at PC=0x{:06X} after {} insns", w, self.cpu.pc, i);
                return false;
            }

            if !self.context_initialized && matches!(&decoded.insn, decode::Instruction::Trapa(0)) {
                if !self.cold_boot {
                    self.jit_context_init();
                }
                self.apply_flash_nop_patches();
                self.context_initialized = true;
            }

            let insn_pc = self.cpu.pc;
            let new_pc = execute::execute(&mut self.cpu, &mut self.bus, &decoded.insn, insn_pc, decoded.len);
            self.cpu.pc = new_pc;
            self.cpu.cycle_count += 1;

            self.sync_peripherals();
            self.check_peripherals();
            self.handle_oneshot_actions(insn_pc, i);
            self.log_milestone(i);

            // Force USB session state periodically (same as run())
            if i.is_multiple_of(1000) {
                self.force_usb_session_state();
            }

            // Check if main loop was reached (0xDEAD0001 is the oneshot marker
            // inserted by handle_oneshot_actions when PC == FW_MAIN_LOOP)
            if self.milestones_seen.contains(&0xDEAD0001) {
                log::info!("boot: Reached main loop after {} instructions", i);
                return true;
            }
        }
        false
    }

    /// Send a SCSI command (no data-out phase) and return response data.
    pub fn scsi_command(&mut self, cdb: &[u8]) -> ScsiResult {
        assert!(!cdb.is_empty(), "scsi_command: CDB must not be empty");
        // Write CDB to all firmware-expected locations.
        self.bus.write_byte(FW_SCSI_OPCODE, cdb[0]);
        self.bus.write_word(FW_SENSE_CODE, 0x0000);
        for (j, &b) in cdb.iter().enumerate().take(16) {
            self.bus.write_byte(FW_CDB_BUFFER + j as u32, b); // 0x4007DE
            self.bus.write_byte(0x4007B6 + j as u32, b);       // Parsed CDB area
        }
        // Determine dispatch mode: firmware_dispatch unless overridden by emulated_scsi
        let use_firmware = self.firmware_dispatch && !self.emulated_scsi;

        if use_firmware {
            // Also write CDB to 0x40008A — the buffer where the response manager's
            // buffer setup (0x013DA0→0x012258) stores EP1 OUT FIFO data. The
            // dispatcher's init at 0x013E0A copies from this buffer to 0x4007DE.
            // Without this, the init overwrites 0x4007DE with zeros from a depleted FIFO.
            for (j, &b) in cdb.iter().enumerate().take(16) {
                self.bus.write_byte(0x40008A + j as u32, b);
            }
        }

        if use_firmware {
            // Inject CDB into EP1 OUT FIFO. The firmware reads from it many times:
            //   - Dispatcher CDB read via buffer setup (0x013D72→0x012258)
            //   - Dispatcher init copies CDB to 0x4007DE (0x013E0A loop)
            //   - Data transfer CDB read via 0x016458
            //   - Various other reads during USB state management
            // Inject CDB-padded data to satisfy firmware reads from EP1 OUT FIFO.
            // The dispatcher, response manager, and data transfer all read from it.
            let mut padded_cdb = vec![0u8; 384];
            for chunk_start in (0..384).step_by(128) {
                let copy_len = cdb.len().min(128);
                padded_cdb[chunk_start..chunk_start + copy_len]
                    .copy_from_slice(&cdb[..copy_len]);
            }
            self.bus.isp1581_inject(&padded_cdb);
            self.firmware_dispatch_scsi(cdb[0]);
        } else {
            self.handle_scsi_command(cdb[0]);
        }

        let sense = self.bus.read_word(FW_SENSE_CODE);
        let mut data = self.bus.isp1581_drain(256 * 1024);

        if use_firmware && data.len() > 8 {
            // The dispatch-level post-handler at FW:0x01117A sends an 8-byte
            // compact sense summary. For dispatch-level commands (like REQUEST
            // SENSE), this summary is PREPENDED to the response. For handler-
            // internal commands (like INQUIRY), the handler sends first and the
            // summary is APPENDED. Detect by checking if the first 8 bytes are
            // all zero (compact summary for GOOD/NO SENSE status) and strip them.
            // Also truncate to CDB allocation length if known.
            let alloc_len = cdb.get(4).copied().unwrap_or(0) as usize;
            if data[..8].iter().all(|&b| b == 0) {
                // Dispatch-level path: 8-byte zero header prepended → strip it
                data = data[8..].to_vec();
            }
            // Truncate to allocation length if specified and reasonable
            if alloc_len > 0 && alloc_len < data.len() {
                data.truncate(alloc_len);
            }
        }

        ScsiResult {
            sense_key: ((sense >> 8) & 0x0F) as u8,
            asc: (sense & 0xFF) as u8,
            data,
        }
    }

    /// Send a SCSI command with data-out phase (e.g., SET WINDOW, MODE SELECT, WRITE).
    pub fn scsi_command_out(&mut self, cdb: &[u8], data_out: &[u8]) -> ScsiResult {
        assert!(!cdb.is_empty(), "scsi_command_out: CDB must not be empty");
        for (j, &b) in cdb.iter().enumerate().take(16) {
            self.bus.write_byte(FW_CDB_BUFFER + j as u32, b);
        }
        self.bus.write_byte(FW_SCSI_OPCODE, cdb[0]);
        self.bus.write_word(FW_SENSE_CODE, 0x0000);

        let use_firmware = self.firmware_dispatch && !self.emulated_scsi;
        if use_firmware {
            // Inject CDB + data-out into EP1 OUT FIFO.
            let mut padded_cdb = vec![0u8; 128];
            let copy_len = cdb.len().min(128);
            padded_cdb[..copy_len].copy_from_slice(&cdb[..copy_len]);
            padded_cdb.extend_from_slice(data_out);
            self.bus.isp1581_inject(&padded_cdb);
            self.firmware_dispatch_scsi(cdb[0]);
        } else {
            self.bus.isp1581_inject(data_out);
            self.handle_scsi_command(cdb[0]);
        }

        let sense = self.bus.read_word(FW_SENSE_CODE);
        let data = self.bus.isp1581_drain(256 * 1024);

        ScsiResult {
            sense_key: ((sense >> 8) & 0x0F) as u8,
            asc: (sense & 0xFF) as u8,
            data,
        }
    }

    /// Look up an opcode in the firmware dispatch table at 0x49834.
    /// Returns the handler address if found.
    fn lookup_handler(&mut self, opcode: u8) -> Option<u32> {
        for i in 0..FW_DISPATCH_ENTRIES {
            let entry = FW_DISPATCH_TABLE + (i * FW_DISPATCH_STRIDE) as u32;
            let table_opcode = self.bus.read_byte(entry);
            if table_opcode == opcode {
                let handler_addr = self.bus.read_long(entry + 4);
                return Some(handler_addr & 0x00FFFFFF);
            }
            // Check for null handler (end of table)
            if self.bus.read_long(entry + 4) == 0 {
                break;
            }
        }
        None
    }

    /// Route a SCSI command through the firmware's own SCSI dispatcher.
    /// Uses 0x020AE2 (the dispatcher entry) so handlers get the correct
    /// stack frame, dispatch table lookup, and CDB parsing that they expect.
    fn firmware_dispatch_scsi(&mut self, opcode: u8) {
        // Verify the opcode is in the dispatch table
        if self.lookup_handler(opcode).is_none() {
            log::error!("FW DISPATCH: opcode 0x{:02X} not in firmware dispatch table", opcode);
            self.scsi_illegal_request();
            return;
        }

        // Use the firmware's SCSI dispatcher at 0x020AE2 as the entry point.
        // The dispatcher reads the CDB from EP1 OUT FIFO (via JSR @0x016458),
        // looks up the handler in the dispatch table, sets up the stack frame,
        // and calls the handler. Dispatch-level response manager calls (JSR
        // @0x01374A) are NOPed by apply_flash_nop_patches().
        let dispatcher_addr = 0x020AE2u32;
        log::info!("FW DISPATCH: opcode 0x{:02X} → dispatcher at 0x{:06X}", opcode, dispatcher_addr);

        // Save CPU state
        let saved_pc = self.cpu.pc;
        let saved_sp = self.cpu.sp();
        let saved_ccr = self.cpu.ccr;
        let saved_er: [u32; 8] = self.cpu.er;

        // Set up call frame: push sentinel return address, set PC to dispatcher.
        // Sentinel 0x0DEAD0 is in unmapped space (between flash 0x07FFFF and RAM 0x400000).
        let sp = saved_sp - 4;
        self.cpu.set_sp(sp);
        self.bus.write_long(sp, FW_DISPATCH_SENTINEL);
        self.cpu.pc = dispatcher_addr;
        // Mask interrupts during handler execution to prevent context switches
        // and TRAPA-triggered control flow changes that would derail the mini-loop.
        self.cpu.set_flag(h8300h_core::cpu::CCR_I, true);

        // Pre-populate USB endpoint max packet size at 0x407DCA. This is normally
        // set during USB enumeration (FW:0x015410) which we NOP. The data transfer
        // function at FW:0x01232E divides the transfer count by this value to
        // calculate word count for PIO writes. Value of 2 = word size for 16-bit
        // EP Data Port writes (each write_word pushes 2 bytes to EP2 IN FIFO).
        self.bus.write_word(0x407DCA, 2);

        // Pre-populate firmware state variables that handlers depend on but
        // aren't set during our abbreviated boot (USB init NOPed).
        if self.bus.read_byte(0x400773) == 0 {
            self.bus.write_byte(0x400773, 1); // Adapter type: SA-Mount (index 1)
        }
        if self.bus.read_byte(0x400877) == 0 {
            self.bus.write_byte(0x400877, 1); // Scanner initialized flag
        }
        if self.bus.read_byte(0x400880) == 0 {
            self.bus.write_byte(0x400880, 0x04); // Sense response type
        }
        // Pre-populate INQUIRY buffer at 0x4008A2 with flash template from 0x170CE.
        // The handler's copy loop at FW:0x011500 normally does this, but it requires
        // firmware init state we don't fully replicate. The template has the standard
        // SCSI INQUIRY response (device type, vendor "Nikon", product "LS-50 ED", etc.)
        if self.bus.read_byte(FW_INQUIRY_RAM + 8) == 0 { // Check if vendor byte is unset
            for i in 0..36u32 {
                let b = self.bus.read_byte(0x170CE + i); // Read from flash template
                self.bus.write_byte(FW_INQUIRY_RAM + i, b); // Write to INQUIRY RAM buffer
            }
        }

        // Pre-populate calibration input parameters at 0x400F56-0x400F9D.
        // These are read by firmware calibration routines (0x3D12D, 0x3DE51, etc.)
        // as input to the dark frame / white reference computation. Mid-range
        // defaults prevent division-by-zero in calibration math.
        if self.bus.read_word(0x400F56) == 0 {
            for offset in (0..0x48).step_by(2) {
                self.bus.write_word(0x400F56 + offset, 0x2000); // Mid-range defaults
            }
        }

        // Set model flag at 0x404E96 from --model config.
        // LS-50: 0 (default), LS-5000: non-zero. Affects analog DAC/gain config.
        if self.model == crate::config::ScannerModel::Ls5000 {
            self.bus.write_byte(0x404E96, 1);
        }

        let max_handler_insns = 5_000_000u64;
        let mut executed = 0u64;
        let mut error = false;
        let mut last_pc = 0u32;
        let mut stuck_count = 0u32;

        loop {
            if self.cpu.pc == FW_DISPATCH_SENTINEL {
                log::info!("FW DISPATCH: handler returned after {} instructions", executed);
                break;
            }
            if executed >= max_handler_insns {
                log::error!("FW DISPATCH: handler timeout after {} instructions at PC=0x{:06X}", executed, self.cpu.pc);
                error = true;
                break;
            }
            if self.cpu.sleeping {
                log::error!("FW DISPATCH: handler executed SLEEP at PC=0x{:06X}", self.cpu.pc);
                error = true;
                break;
            }

            // Stuck-PC detector: break if PC hasn't changed in 1000 iterations
            if self.cpu.pc == last_pc {
                stuck_count += 1;
                if stuck_count >= 1000 {
                    log::error!("FW DISPATCH: stuck at PC=0x{:06X} for {} iterations", self.cpu.pc, stuck_count);
                    error = true;
                    break;
                }
            } else {
                stuck_count = 0;
            }
            last_pc = self.cpu.pc;

            // Clear USB event/abort flag when entering data transfer function.
            // The response manager's exit path sets 0x400085=1 (because opcode
            // ≠ 0xD0 phase query). The data transfer loop checks it as abort.
            if self.cpu.pc == 0x014090 {
                self.bus.write_byte(0x400085, 0);
            }

            let decoded = decode::decode(&mut self.bus, self.cpu.pc);
            if let decode::Instruction::Unknown(w) = &decoded.insn {
                log::error!("FW DISPATCH: unknown instruction 0x{:04X} at PC=0x{:06X}", w, self.cpu.pc);
                error = true;
                break;
            }
            // Block TRAPA instructions — they would trigger context switches.
            // When the TRAPA is inside the response manager's yield loop
            // (FW:0x01374A-0x0137C8), simulate the host USB acknowledgment by
            // setting cmd_pending. The response manager at FW:0x01376A calls
            // JSR @0x0109E2 (yield), and 0x0109E2 contains the TRAPA. We detect
            // this by checking if the return address on the stack points back to
            // the response manager (0x01376E).
            if matches!(&decoded.insn, decode::Instruction::Trapa(_)) {
                // Check if this yield is from the response manager's loop.
                // The response manager at 0x01376A does JSR @0x0109E2 (yield).
                // Return address 0x01376E is on the stack. Only set cmd_pending
                // and clear 0x400085 for response manager yields.
                let return_addr = self.bus.read_long(self.cpu.sp()) & 0x00FFFFFF;
                if return_addr == 0x01376E {
                    self.bus.write_byte(FW_CMD_PENDING, 1);
                    self.bus.write_byte(0x400085, 0);
                }
                self.cpu.pc += decoded.len;
                executed += 1;
                continue;
            }

            let insn_pc = self.cpu.pc;
            let new_pc = execute::execute(&mut self.cpu, &mut self.bus, &decoded.insn, insn_pc, decoded.len);
            self.cpu.pc = new_pc;
            executed += 1;

            // Sync peripherals (timers tick, ASIC countdown, etc.)
            self.sync_peripherals();
            self.check_peripherals();

            // Auto-feed watchdog every 50K instructions to prevent timeout
            // during long firmware handler execution (calibration, scan setup).
            if executed.is_multiple_of(50_000) {
                self.peripherals.watchdog.write(0x5A);
            }
        }

        // On error (timeout, unknown insn, SLEEP), set hardware error sense
        // and drain any partial FIFO data to prevent stale responses.
        if error {
            self.bus.write_word(FW_SENSE_CODE, 0x0440); // SK=4 (Hardware Error), ASC=0x40
            self.bus.isp1581_drain(256 * 1024); // Discard partial data
        }

        // Restore CPU state — memory side effects remain.
        self.cpu.pc = saved_pc;
        self.cpu.set_sp(saved_sp);
        self.cpu.ccr = saved_ccr;
        self.cpu.er = saved_er;
        self.cpu.sleeping = false;
    }

    /// Check if scan is currently active.
    pub fn is_scan_active(&self) -> bool {
        self.scan_active
    }

    /// Set up the USB gadget bridge.
    /// Call this after construction if `--gadget` is enabled.
    pub fn setup_gadget(&mut self) -> Result<(), String> {
        let mut gadget = bridge::gadget::GadgetBridge::new();
        gadget.setup()?;
        self.gadget = Some(Box::new(gadget));
        log::info!("USB gadget bridge connected");
        Ok(())
    }

    /// Poll the gadget bridge for incoming data and send responses.
    /// When the gadget is active, it owns the EP2 IN FIFO — TCP bridge
    /// must not drain it (see `send_tcp_response()`).
    fn poll_gadget(&mut self) {
        let gadget = match self.gadget.as_mut() {
            Some(g) => g,
            None => return,
        };
        // Read data from host via EP1 OUT
        if let Some(cdb_data) = gadget.recv_ep1_out() {
            log::info!("GADGET: received {} bytes from host", cdb_data.len());
            // Inject into ISP1581 EP1 OUT FIFO — firmware IRQ1 will handle it
            self.bus.isp1581_inject(&cdb_data);
        }

        // Send ISP1581 EP2 IN FIFO data to host
        if self.bus.isp1581_has_response() {
            let response = self.bus.isp1581_drain(65536);
            if !response.is_empty() {
                log::info!("GADGET: sending {} bytes to host", response.len());
                gadget.send_ep2_in(&response);
            }
        }
    }

    /// Set up the userspace USB/IP server bridge (M14.5).
    /// Call this after construction if `--usbip-server` is enabled.
    /// Mutually exclusive with [`Self::setup_gadget`] — the CLI rejects
    /// the combination, but if both ever ran the second to bind the
    /// ISP1581 FIFOs would race the first.
    pub fn setup_usbip_server(&mut self, bind_addr: &str, port: u16) -> Result<(), String> {
        let bridge = bridge::UsbipServerBridge::new(bind_addr, port)?;
        self.usbip = Some(Box::new(bridge));
        // Mark that we want INQUIRY's handler-internal patches restored
        // on first poll after main loop. Done in `poll_usbip`, not here,
        // because the patches are applied at TRAPA #0 time (later than
        // construction).
        self.usbip_inquiry_patches_pending = true;
        log::info!("USB/IP server bridge attached");
        Ok(())
    }

    /// Returns true if the userspace USB/IP bridge is set up.
    /// Used by `main.rs` for the transport-summary log line.
    pub fn usbip_active(&self) -> bool {
        self.usbip.is_some()
    }

    /// Poll the USB/IP server bridge for incoming data and send responses.
    ///
    /// The autonomous-IRQ1 path used by [`Self::poll_gadget`] doesn't work
    /// here for a subtle reason: the firmware's SCSI dispatcher reads from
    /// the EP1 OUT FIFO multiple times during a single command (CDB read,
    /// dispatch init copy, data transfer setup, etc.). A single 6-byte
    /// CDB injection depletes after the first read and subsequent reads
    /// see zeros — visible as `ep1_underrun` (M14-C) and breaks INQUIRY.
    ///
    /// `scsi_command` handles this by (a) padding the CDB to 384 bytes
    /// and (b) actively driving the firmware dispatcher via
    /// `firmware_dispatch_scsi`. We do the same here: when the USB/IP
    /// client delivers a bulk-OUT URB we treat it as the CDB, run
    /// `scsi_command` synchronously, and push the response back to the
    /// bridge for the host to read on the next bulk-IN URB.
    fn poll_usbip(&mut self) {
        // Gate on firmware readiness. scsi_command needs the firmware in
        // its main loop with USB state populated; calling it before boot
        // completes returns garbage data drawn from uninitialized RAM
        // (verified during M14.5 development — INQUIRY would return the
        // context-save area pattern instead of the device strings).
        if !self.milestones_seen.contains(&0xDEAD0001) {
            return;
        }

        // First time after main loop is reached: restore the patches that
        // disable INQUIRY's handler-internal data transfer. The M14 NOP
        // patch set assumed dispatch-level data transfer is sufficient,
        // but for INQUIRY the handler builds its response in a separate
        // buffer and sends it via its own response-manager + data-transfer
        // calls. Without these restorations, INQUIRY returns sense data
        // instead of the device descriptor.
        // (See e2e_scan.rs:gate_trace_inquiry_isp1581_access for the same
        // restorations applied in unit tests.)
        if self.usbip_inquiry_patches_pending {
            self.restore_flash_patch(0x026042, 0x5E01374A);
            self.restore_flash_patch(0x02604A, 0x5E014090);
            self.usbip_inquiry_patches_pending = false;
            log::info!("USBIP: restored INQUIRY handler-internal data-transfer patches");
        }
        // Borrow the bridge briefly to drain the incoming CDB. The borrow
        // must be released before we call scsi_command (which takes &mut
        // self), so we extract the data and store it locally.
        let cdb_data = match self.usbip.as_mut() {
            Some(u) => u.recv_ep1_out(),
            None => return,
        };
        let Some(cdb) = cdb_data else { return };

        if cdb.is_empty() {
            return;
        }
        log::debug!("USBIP: received {} bytes from host (CDB[0]=0x{:02X})", cdb.len(), cdb[0]);

        // Discard any data the firmware may have written to EP2 IN during
        // boot or prior commands — `scsi_command` drains EP2 IN after the
        // handler runs, and any leftover bytes would be prepended to the
        // response we send to the host. Boot writes a fair amount of
        // context-save and response-manager bookkeeping bytes there.
        let stale = self.bus.isp1581_drain(usize::MAX);
        if !stale.is_empty() {
            log::debug!("USBIP: discarded {} stale EP2 IN bytes before CDB dispatch", stale.len());
        }

        // Run the SCSI command synchronously. This pads the CDB, drives
        // the firmware dispatcher (or Rust emulation as configured), and
        // returns the response data drained from EP2 IN.
        let result = self.scsi_command(&cdb);

        if !result.data.is_empty() {
            log::debug!("USBIP: sending {} bytes to host (sense_key={:#x}, asc={:#x})",
                        result.data.len(), result.sense_key, result.asc);
            if let Some(usbip) = self.usbip.as_mut() {
                usbip.send_ep2_in(&result.data);
            }
        } else if result.sense_key != 0 {
            log::warn!("USBIP: CDB returned sense_key=0x{:02X} asc=0x{:02X} with no data",
                       result.sense_key, result.asc);
        }
    }

    /// Inject a CDB into the ISP1581 EP1 OUT FIFO for IRQ1-driven processing.
    /// The firmware's IRQ1 ISR at 0x014E00 reads the CDB from the EP Data Port,
    /// writes it to 0x4007DE, and sets cmd_pending. The main loop dispatcher
    /// then picks it up and executes the handler.
    ///
    /// This is the "real USB" path: host → ISP1581 FIFO → IRQ1 → firmware.
    /// Use this instead of scsi_command() when running with full firmware USB.
    pub fn inject_cdb_irq1(&mut self, cdb: &[u8]) {
        log::info!("IRQ1 CDB: injecting {} bytes into EP1 OUT FIFO", cdb.len());
        self.bus.isp1581_inject(cdb);
        // The IRQ will fire on the next check_peripherals() call,
        // which happens every instruction in the run() loop.
    }

    /// Check if firmware has produced a response in the ISP1581 EP2 IN FIFO.
    pub fn has_response(&self) -> bool {
        self.bus.isp1581_has_response()
    }

    /// Drain the ISP1581 EP2 IN FIFO (host reads device response).
    pub fn drain_response(&mut self, max: usize) -> Vec<u8> {
        self.bus.isp1581_drain(max)
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

#[cfg(test)]
mod tcp_frame_tests {
    use super::extract_tcp_frames;

    #[test]
    fn test_extract_single_complete_frame() {
        let mut buf = vec![0x00, 0x02, 0x01, 0xAA, 0xBB];
        let frames = extract_tcp_frames(&mut buf);
        assert_eq!(frames, vec![(0x01, vec![0xAA, 0xBB])]);
        assert!(buf.is_empty());
    }

    #[test]
    fn test_extract_two_frames_in_one_buffer() {
        let mut buf = vec![
            0x00, 0x01, 0x01, 0xAA,             // frame 1: type 0x01, payload [0xAA]
            0x00, 0x02, 0x05, 0x11, 0x22,       // frame 2: type 0x05, payload [0x11, 0x22]
        ];
        let frames = extract_tcp_frames(&mut buf);
        assert_eq!(frames, vec![(0x01, vec![0xAA]), (0x05, vec![0x11, 0x22])]);
        assert!(buf.is_empty());
    }

    #[test]
    fn test_partial_header_stays_buffered() {
        let mut buf = vec![0x00, 0x01];
        let frames = extract_tcp_frames(&mut buf);
        assert!(frames.is_empty());
        assert_eq!(buf, vec![0x00, 0x01], "partial header preserved");
    }

    #[test]
    fn test_partial_payload_stays_buffered() {
        let mut buf = vec![0x00, 0x04, 0x01, 0xAA, 0xBB];
        let frames = extract_tcp_frames(&mut buf);
        assert!(frames.is_empty());
        assert_eq!(buf, vec![0x00, 0x04, 0x01, 0xAA, 0xBB], "partial payload preserved");
    }

    #[test]
    fn test_complete_frame_plus_trailing_partial() {
        let mut buf = vec![0x00, 0x01, 0x01, 0xAA, 0x00];
        let frames = extract_tcp_frames(&mut buf);
        assert_eq!(frames, vec![(0x01, vec![0xAA])]);
        assert_eq!(buf, vec![0x00], "trailing partial header preserved");
    }

    #[test]
    fn test_split_header_reassembly() {
        // Simulates TCP delivering bytes one at a time. Nothing parses
        // until the full frame arrives; then it comes out cleanly.
        let mut buf: Vec<u8> = Vec::new();
        for byte in [0x00u8, 0x02, 0x01] {
            buf.push(byte);
            let frames = extract_tcp_frames(&mut buf);
            assert!(frames.is_empty(), "header not yet complete after byte 0x{:02X}", byte);
        }
        buf.push(0xAA);
        let frames = extract_tcp_frames(&mut buf);
        assert!(frames.is_empty(), "payload still short after one byte");
        buf.push(0xBB);
        let frames = extract_tcp_frames(&mut buf);
        assert_eq!(frames, vec![(0x01, vec![0xAA, 0xBB])]);
    }

    #[test]
    fn test_zero_length_payload() {
        let mut buf = vec![0x00, 0x00, 0x02];
        let frames = extract_tcp_frames(&mut buf);
        assert_eq!(frames, vec![(0x02, vec![])]);
        assert!(buf.is_empty());
    }

    #[test]
    fn test_max_wire_payload_size_accepted() {
        // The wire encoding caps payload length at 16 bits — 65535 is the
        // largest single-frame payload. Verify it parses cleanly.
        let mut buf = Vec::with_capacity(3 + 0xFFFF);
        buf.extend_from_slice(&[0xFF, 0xFF, 0x01]);
        buf.extend(std::iter::repeat_n(0xAA, 0xFFFF));
        let frames = extract_tcp_frames(&mut buf);
        assert_eq!(frames.len(), 1);
        assert_eq!(frames[0].0, 0x01);
        assert_eq!(frames[0].1.len(), 0xFFFF);
    }

    #[test]
    fn test_stateful_parsing_across_calls() {
        // Drain consumed bytes, preserve incomplete tail, pick up later.
        let mut buf = vec![0x00, 0x02, 0x01, 0xAA, 0xBB, 0x00, 0x03];
        let frames = extract_tcp_frames(&mut buf);
        assert_eq!(frames, vec![(0x01, vec![0xAA, 0xBB])]);
        assert_eq!(buf, vec![0x00, 0x03], "incomplete next header preserved");
        buf.extend_from_slice(&[0x02, 0xCC, 0xDD, 0xEE]);
        let frames = extract_tcp_frames(&mut buf);
        assert_eq!(frames, vec![(0x02, vec![0xCC, 0xDD, 0xEE])]);
        assert!(buf.is_empty());
    }
}
