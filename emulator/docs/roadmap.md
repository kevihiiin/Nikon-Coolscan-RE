# Emulator Roadmap

**Last Updated**: 2026-04-27

---

## Status

All 11 build phases plus M12 (firmware-path correctness), M13 (TCP bridge hardening), M14 (USB Gadget Ready), and M14.5 (Userspace USB/IP HIL) are **COMPLETE**. The emulator is ~13K LOC Rust, 310 tests, 0 clippy warnings.

Post-completion backlog of correctness, design, and UX issues tracked in [`backlog.md`](backlog.md).

**Goal**: A fully functional Coolscan V replica running on a Raspberry Pi via USB gadget, compatible with NikonScan 4.0.3 on Windows. The emulator should handle the full NikonScan workflow: connect → INQUIRY → calibrate → preview → scan → disconnect.

**Next milestone**: M15 (NikonScan E2E Validation) — now runnable from M14.5's userspace USB/IP server. No Pi or `sudo` required; the user just needs a Windows VM with NikonScan 4.0.3 and `usbip-win2` installed. See `emulator/hil/` for the HIL setup.

---

## Next Steps — Path to NikonScan-Compatible USB Device

Work is organized into milestones. Each milestone brings the emulator closer to passing the NikonScan E2E workflow. Earlier milestones are prerequisites for later ones.

### Milestone 15: NikonScan E2E Validation

The integration milestone. Run NikonScan 4.0.3 against the emulator over real USB.

| Item | What | Why |
|------|------|-----|
| NikonScan connect sequence | Capture and replay NikonScan's exact USB init sequence (SET_ADDRESS, GET_DESCRIPTOR, SET_CONFIGURATION, INQUIRY) | May reveal ISP1581 enumeration register gaps |
| Calibration under NikonScan | NikonScan sends SEND DIAGNOSTIC calibration tasks before every scan | Timing-sensitive; may expose motor/CCD timing gaps |
| Preview scan | NikonScan requests a low-res preview (typically 300 DPI) | Tests the full SCAN → READ pipeline with real USB transport |
| Full-resolution scan | 4000 DPI scan of a single frame (SA-21 mount adapter) | Large data transfer (~50MB); tests USB bulk throughput and chunking |
| Multi-frame strip scan | SF-210 strip adapter, 6 frames | Tests adapter VPD pages, boundary data, and sequential scan |
| Error recovery | Unplug/replug during scan, cancel mid-scan | Tests USB reset handling and firmware error paths |
| Capture packet traces | Use Wireshark/USBPcap on the Windows side to capture the full NikonScan ↔ emulator conversation | Validates protocol match against RE docs |

**Exit criterion**: NikonScan 4.0.3 on Windows connects to the emulator via USB, calibrates, previews, and scans a single frame. The resulting image opens correctly in NikonScan's viewer.

### Milestone 16: Polish & Robustness

Architectural improvements and UX polish. Not blocking E2E but improves long-term maintainability.

| Item | Backlog | What |
|------|---------|------|
| Unmapped memory tracking | C3, C4 | Per-address warning counts instead of single global counter |
| Orchestrator refactor | C5, I1 | Extract `ScsiEmulator`, `TcpBridge`, `ScanEngine`; unify boot paths |
| GPIO/DMA/ADC/ITU catch-all logging | I9 | Add `log::debug!` to unmodeled peripheral registers |
| Executor Bcc/Bsr fallthrough | I14 | Replace `_ => next_pc` with `unreachable!()` |
| Flash write protection | I19 | Return bus error or set flag for writes outside log area |
| Log volume reduction | I16 | Default to `warn`, add `--verbose`/`--quiet` |
| CLI argument validation | M1, M3, M15 | Proper error messages for missing values, reject `--max 0` |
| Default firmware path | M2 | Use compile-time or XDG-based path lookup |
| Expert flag documentation | M5 | Document zero-patch mode in `--help` |
| Halt/panic messages | I18 | Add "unsupported firmware version?" hint to unknown instruction panics |
| Benchmark output consistency | M18 | Use `log::*` instead of `eprintln!` |
| ISP1581 offset 0x1C mismapping | M12 | Fix DcBufferLength write → should not map to `ep_index` |
| Motor spurious step on mode transition | M16 | Guard `port_a_write` against stale `last_phase` |
| ISP1581 `take_irq` naming | M17 | Rename to `peek_irq` or document why non-destructive |
| ASIC `generate_line` odd byte count | M13 | Assert `dma_count` is even, or handle odd case |
| ASIC noise determinism | M9 | Replace with LFSR or xorshift for more realistic noise |
| `wait_response()` timeout ambiguity | M19 | Return `Option<Vec<u8>>` or `Result` to distinguish timeout from empty |
| ADC channels B/C/D | M11 | Implement remaining ADC result registers + auto-clear ADST |

**Exit criterion**: `cargo clippy --all-targets` clean, no `unwrap()` in production paths, all CLI flags documented in `--help`, default log volume is manageable for end users.

---

## Phase History

### Phases 0-6: Foundation (Complete)

~9,500 lines Rust, 193 tests. Boots real LS-50 firmware, handles 17 SCSI opcodes via Rust emulation. All SCSI handled by Rust code — firmware's own handlers never used. No motor, no CCD, no calibration. A protocol emulator, not a hardware replica.

### Phases 7-11: Hardware Fidelity (Complete)

Bridged the gap from protocol emulator to firmware-driven hardware replica. The CPU executes the real SCSI handlers and the orchestrator provides hardware stimuli (CCD data, motor feedback, USB transport).

### M12: Firmware-Path Correctness (Complete)

7 backlog items + 5 post-review fixes (commits `ffc7dc2`, `ad55b8e`, 279 tests). Made firmware SCSI handlers run autonomously without Rust intercepts:

- **C1** — ASIC register sync: `MemoryBus::asic_dirty` flag + `sync_peripherals` forwards DAC mode, DMA addr/count, CCD trigger to the `Asic` model
- **I4/I5** — ITU OVF flag + overflow interrupt; IMIB compare-match B interrupt (added `IMIB_VECTORS`, `OVI_VECTORS`)
- **I6** — GRA==GRB same-tick conflict: both checked against pre-clear TCNT
- **I7** — Watchdog `tick()` wired into `check_peripherals()`; feed byte (0x5A) routed to model
- **I10** — SCI0 routing: `PeripheralBus::sci0` synced so SSR=0x84 (TDRE=1) reaches `onchip_io[0xB4]`
- **I13** — Motor direction comment fix (DDR → DR for 0xFFFF84)
- **I15** — ASIC DMA double-fire eliminated: orchestrator owns `dma_complete_pending` set
- Post-review: CCD trigger edge-detection (was level-gated, stalling multi-line scans), IMIB4/OVI4 priority alignment with IMIA4, watchdog auto-rearm to prevent log spam, DMA-complete IRQ no longer gated on empty data

### M14.5: Userspace USB/IP HIL (Complete)

Stands the emulator up as a USB/IP server inside the Rust binary itself, removing the Raspberry Pi requirement from M15. No `sudo`, no kernel modules, no nested VM. NikonScan in a Windows VM attaches via `usbip-win2` over TCP. (commit TBD, 310 tests)

- **Architecture pivot**: original kernel-mode `dummy_hcd` plan ruled out because Ubuntu doesn't ship `dummy_hcd` in `linux-modules-extra`. `usbip-vudc` was the next candidate but has a known disconnect-after-enum bug (Sept 2025 reports). Final: **userspace** USB/IP server using the `usbip` Rust crate (jiegec, v0.8.0), avoiding both the dependency and the bug.
- **`bridge::usbip_server::UsbipServerBridge`**: third `UsbBridge` impl alongside `TcpBridge` and `GadgetBridge`. Owns a tokio runtime in a dedicated thread; the synchronous emulator loop is unaffected. Implements `UsbInterfaceHandler::handle_urb` for vendor-specific bulk EP1 OUT / EP2 IN. ~280 LOC + 7 unit tests.
- **`bridge::nikon_ids`**: extracted shared VID/PID/strings (DRY between gadget and usbip bridges).
- **CLI flags**: `--usbip-server`, `--usbip-port <N>` (default 3240), `--usbip-bind <ADDR>` (default 0.0.0.0). Mutually exclusive with `--gadget` (refuses with exit 2). Transport-summary log line extended to include USB/IP state.
- **`Emulator::poll_usbip`**: gates on main-loop-reached milestone (avoids garbage from uninitialized firmware), routes incoming CDBs through `scsi_command` (which pads to 384 bytes — the autonomous IRQ1 path doesn't because firmware re-reads EP1 OUT FIFO multiple times per command), pushes responses back to bridge for host bulk-IN. Restores INQUIRY's handler-internal data-transfer flash patches on first use (otherwise INQUIRY returns sense data instead of the device descriptor).
- **`emulator/hil/`** (new workspace crate): hand-rolled synchronous USB/IP client (~250 LOC, reuses `UsbIpCommand::to_bytes` from the crate for requests; hand-rolls response parsing); test harness (subprocess + port helpers); `README.md` + 4 docs covering architecture, Windows setup with `usbip-win2`, troubleshooting, and the kernel-mode fallback for advanced users; PowerShell installer for `usbip-win2`.
- **`coolscan-emu/tests/smoke_usbip_e2e.rs`** (the milestone exit criterion): spawns the emulator subprocess, connects the USB/IP client to localhost, sends INQUIRY, asserts the response identifies the device as a Nikon LS-50. Passes in 0.55s after a 3M-instruction firmware boot. **No `sudo`, no kernel modules, no Windows VM, no nested virt — fully agent-runnable.**

### M14: USB Gadget Ready (Complete)

7 backlog items (288 → 295 tests). Made the ISP1581 model and gadget bridge robust enough to survive NikonScan's USB enumeration:

- **I2** — `write_byte` on DcInterrupt and DcEndpointStatus no longer reads back the synthetic `IRQ_EP_TX_READY` bit and clears it as a side effect; byte writes only clear bits in the addressed byte
- **C2** — EP1 OUT FIFO underrun now sets a sticky `ep1_underrun` flag and warns once (was silent fabrication of zero bytes = phantom TUR)
- **I3** — Unmodeled ISP1581 register reads/writes now warn-once-per-(offset,direction); subsequent accesses log at trace
- **N3** — STALL bit on ControlFunction (0x28 bit 0) tracked per endpoint via `ep_stalled` map; pairs with `ep_index` to identify the stalled EP
- **N1/N2** — Trace of `--full-usb-init` boot showed firmware only touches modeled offsets (0x0C, 0x18, 0x1C, 0x20, 0x2C); gadget bridge `send_ep2_in` now emits a ZLP when the write length is a non-zero multiple of 512 (HS bulk max-packet) so the host sees a clean transfer boundary
- **I17** — SIGINT/SIGTERM handler installed via `ctrlc` crate; sets `Arc<AtomicBool>` checked every 1000 instructions in `Emulator::run_with_shutdown`. Second signal triggers `process::exit(130)` for runaway escapes
- **I8 (deferred)** — DcBufferLength accuracy needs the EP-selection register modeled first; reverted attempt to track per-EP. Constant 64 preserved with updated docstring explaining why
- **G** — Final transport-summary log line at end of startup (`gadget=... tcp=...`) so users always see which transports actually came up

### M13: TCP Bridge Hardening (Complete)

3 backlog items + 5 post-review fixes (commits `d222a87`, `9d472b0`, 288 tests). Made TCP transport robust under real network conditions:

- **I11** — Per-connection `tcp_read_buffer` accumulates partial reads; new `extract_tcp_frames` covered by 8 unit tests
- **I12** — TCP bind fail-fast: exit 1 if `--port` requested but bind failed and no `--gadget` fallback
- **M4** — Default `--max` is now unlimited (`u64::MAX`); explicit `--max N` for bounded runs; `--max 0` is explicit unlimited
- Post-review: removed unreachable `MAX_PAYLOAD = 65536` check; per-poll read cap (64 KB) prevents adversarial peer DoS; EINTR retry; both-transport silent-failure gate (exit non-zero if neither transport up); cap-hit log clarity (warn vs info); invalid `--max` parsing rejects "10m" instead of silently becoming `u64::MAX`

---

## Phase 7: ISP1581 DMA & Firmware SCSI Handlers (COMPLETE)

**Goal**: Get firmware's own SCSI handlers running for data-lookup commands (INQUIRY, REQUEST SENSE, MODE SENSE, RESERVE/RELEASE, GET WINDOW) by implementing ISP1581 DMA completion.

**Why first**: Every subsequent phase depends on the firmware being able to send response data through its USB I/O path. The 26 NOP patches were the single biggest fidelity gap.

### How It Worked Before (the problem)

The firmware's SCSI handlers call two functions:
- `JSR @0x01374A` — USB response manager (sets up DMA direction/phase)
- `JSR @0x014090` — USB data transfer (writes data word-by-word to ISP1581)

Both were NOPed out (26 patches total). Handlers ran but couldn't send data.

### What Was Built

**7.0 GATE: Trace Response Manager Register Access** (before any code changes)
- Ran `--firmware-dispatch --trace` for a single INQUIRY
- Logged all ISP1581 reads/writes (0x600000-0x6000FF) during dispatch
- Logged DcInterrupt bit checks in 0x01374A -> 0x13C70 chain
- Checked if PC enters 0x4010A0-0x401270 (RAM-resident USB code)
- Cataloged unmodeled ISP1581 offsets

**7.1 ISP1581 DMA State Machine** (`peripherals/src/isp1581.rs`, +250 lines)
- Firmware uses PIO word writes, NOT ISP1581 DMA engine (key finding)
- Track bytes written to EP Data Port (0x600020)
- DcInterrupt bit 12 (0x1000) = EP TX Ready, bit 15 (0x8000) = EP TX Complete
- `DcBufferStatus` (0x60001E): return 0 when writable

**7.2 Endpoint Configuration Registers** (`peripherals/src/isp1581.rs`, +30 lines)
- Offset 0x14: endpoint config, 0x2E: endpoint index select, 0x04: endpoint max packet size

**7.3 Un-NOP Dispatch-Level Response Manager** (`orchestrator.rs`)
- Design changed: dispatcher routing via 0x020AE2 with patches in place

**7.4 USB State Variables** (`orchestrator.rs`, +50 lines)
- Pre-populated: 0x407DCA=2, 0x400773=1, 0x400877=1, 0x400880=0x04

**7.5 Un-NOP Handler-Internal USB Calls** (incremental)
- INQUIRY: handler-internal path with pre-populated buffer at 0x4008A2
- REQUEST SENSE: dispatch-level path sends correct data; 8-byte header stripped

**7.6 Hybrid Dispatch** (`orchestrator.rs`, +50 lines)
- Data-lookup commands -> firmware dispatch
- Data-out + scan commands -> Rust emulation
- `--emulated-scsi` flag forces old behavior

### Completion
- INQUIRY via firmware: byte-for-byte match ("Nikon   LS-50 ED        1.02")
- REQUEST SENSE via firmware: [0x70, 0x00, SK, ...] matches Rust emulation
- Error path: firmware sense propagation works (TUR -> REQUEST SENSE produces [0x70])
- 202 tests (32 e2e + 133 core + 37 peripherals), 0 clippy warnings
- +9 tests (5 e2e gate tests + 4 ISP1581 unit tests)

### Key Findings
- ISP1581 register catalog: 0x18 (DcInterrupt), 0x1C (DcBufferLength=64), 0x20 (EP Data Port), 0x28 (ControlFunction), 0x2C (EP Control)
- Response manager at FW:0x01374A polls cmd_pending (0x400082) -- set on TRAPA yield
- Data transfer at FW:0x014090 calls write function at FW:0x012304 (PIO loop)
- Two data transfer architectures: dispatch-level (0x01117A->0x013FB2) vs handler-internal (0x014090)
- Post-handler NOP at 0x011186 prevents double data transfer (total 27 NOP patches)
- 8-byte compact sense header stripped from dispatch output

---

## Phase 8: Motor & Position Subsystem (COMPLETE)

**Goal**: Model stepper motor position, encoder feedback, and adapter geometry. SEND DIAGNOSTIC motor commands work. VPD boundary pages return real data.

**Why**: The firmware's scan setup requires motor positioning. Without it, SCAN handlers hang waiting for motor completion flags.

### What Was Built

**8.1 Motor Position Model** (`peripherals/src/motor.rs`, +180 lines)
- Two motors: scan_motor (carriage) and af_motor (autofocus), selected by motor_mode at RAM 0x400774
- Monitor Port A writes (0xFFFFA3): each stepper phase cycle (01->02->04->08) = 1 step
- Home sensor: position reaches 0, set GPIO flag

**8.2 Encoder Feedback Injection** (`orchestrator.rs`, +80 lines)
- On motor step: 0x40530E (encoder_count), 0x405314 (encoder_delta), 0x405318 (encoder_timestamp)
- Fire IRQ3 (Vec 15) on step

**8.3 Motor State Machine** (`orchestrator.rs`, +70 lines)
- Monitor RAM 0x400774 for movement start
- Completion: 0x4052EB=0, 0x4052EC=done, 0x4052EE=0, stop ITU2

**8.4 SEND DIAGNOSTIC Motor Commands** (`orchestrator.rs`, +50 lines)
- Task codes 0x0400 (stop), 0x0430 (home), 0x0440 (relative), 0x0450 (absolute)

**8.5 Adapter Scan Geometry** (`gpio.rs` + `orchestrator.rs`, +60 lines)
- VPD page 0xC0 returns CCD readout config (not boundary data -- boundary = READ DTC 0x88)

**8.6 Home Sensor in Port 7** (`gpio.rs`, +20 lines)

### Completion
- 215 tests, +13 new tests
- instant_mode flag for testing (teleport to target)

---

## Phase 9: CCD & Scan Pipeline (COMPLETE)

**Goal**: Model CCD capture -> ASIC DMA -> buffer so firmware's SCAN handler produces pixel data through the firmware path.

**Why**: Replace synthetic test pattern with firmware-processed scan data.

### What Was Built

**9.1 CCD Data Injection** (`peripherals/src/asic.rs`, +120 lines)
- On ASIC register 0x2001C1 write, generate one scan line
- 16-bit words, 14-bit CCD data in bits [15:2], 4 channels (R/G/B/IR)

**9.2 ASIC DMA Completion** (`peripherals/src/asic.rs`, +80 lines)
- Transfer-size-based countdown, DMA busy clear, Vec 49 + Vec 45/47

**9.3 H8 DMA Controller** (`peripherals/src/dma.rs`, +250 lines)
- 2 channels, ASIC RAM -> Buffer RAM instant copy, DEND interrupt

**9.4 Scan State Coordination** (`orchestrator.rs`, +150 lines)
- Monitor firmware scan state variables, provide CCD trigger

### Completion
- 224 tests, +14 new (8 ASIC + 6 DMA)
- CCD data injection and DMA transfers are instant

---

## Phase 10: Calibration & Full Fidelity (COMPLETE)

**Goal**: Firmware calibration task codes (0x0500-0x0502) work. Dark frame, white reference, per-channel gain/offset.

**Why**: NikonScan always calibrates before scanning.

### What Was Built

**10.1 DAC Mode Gating** (`peripherals/src/asic.rs`, +80 lines)
- 0x22 (scan): normal pixels, 0xA2 (calibration): dark/white frame data

**10.2 CCD Characterization Data** — Firmware reads from flash at 0x4A8BC, no emulation needed

**10.3 Calibration Task Execution** (`orchestrator.rs`, +60 lines)
- Task codes 0x0500/0x0501/0x0502

**10.4 Calibration RAM Defaults** (`orchestrator.rs`, +30 lines)
- Pre-populate 0x400F56-0x400F9D with mid-range defaults

**10.5 LS-50 vs LS-5000 Config** (`orchestrator.rs`, +30 lines)
- Model flag 0x404E96 from `--model` CLI flag

### Completion
- 230 tests, +6 new

---

## Phase 11: Real USB & Integration (COMPLETE)

**Goal**: Full ISP1581 USB enumeration, zero NOP patches, USB gadget connects to NikonScan. Zero training wheels.

**Why**: The endgame — a drop-in hardware replacement.

### What Was Built

**11.1 Un-NOP USB Init** — `--full-usb-init` skips USB init patches

**11.2 USB Enumeration Flow** (`peripherals/src/isp1581.rs`, +200 lines)
- Full register flow: Reset -> Chip ID -> Mode -> Address -> Endpoint Config -> Interrupt Enable

**11.3 CDB via Firmware IRQ1** (`orchestrator.rs`, +100 lines)
- Host -> EP1 OUT FIFO -> IRQ1 -> firmware ISR at 0x014E00 -> cmd_pending -> dispatcher

**11.4 Un-NOP All Handler Patches** — All 21 SCSI handlers via firmware

**11.5 Gadget Bridge Integration** (`bridge/src/gadget.rs`, +50 lines)
- gadget.recv() -> ISP1581 EP1 OUT, ISP1581 EP2 IN -> gadget.send()

**11.6 Phase Query (0xD0) + Sense (0x06)** — Verified through firmware path

**11.7 Remove force_usb_session_state()** — Gated by full_usb_init

### Completion
- 240 tests, +10 new (7 e2e + 3 ISP1581 unit)
- `--emulated-scsi` safety net preserved

---

## Post-Phase 11 Audit (COMPLETE)

- INQUIRY EVPD panic on alloc_len < 4 fixed (bounds-checked all VPD page builders)
- 29 new tests added (269 total: 68 e2e + 139 core + 58 peripherals + 4 bridge)
- Missing opcodes (EXTU.L, EXTS.L, SHLR.L, SHLL.L, NOT.L), flash log writes, WDT feed, edge cases
- EP2 FIFO race fix, dead field removal
- 0 clippy warnings

---

## Summary Table

| Phase | Name | Lines | Tests | Status |
|-------|------|-------|-------|--------|
| 0 | Setup | - | - | COMPLETE |
| 1 | CPU Core | - | - | COMPLETE |
| 2 | Interrupts | - | - | COMPLETE |
| 3 | USB | - | - | COMPLETE |
| 4 | SCSI | - | - | COMPLETE |
| 5 | Scan | - | - | COMPLETE |
| 6 | Polish | - | 193 | COMPLETE |
| 7 | ISP1581 DMA + FW Handlers | +530 | 202 | COMPLETE |
| 8 | Motor & Position | +636 | 215 | COMPLETE |
| 9 | CCD & Scan Pipeline | +820 | 224 | COMPLETE |
| 10 | Calibration | +380 | 230 | COMPLETE |
| 11 | Real USB & Integration | +440 | 240 | COMPLETE |
| Audit | Post-Phase 11 | +250 | 269 | COMPLETE |
| M12 | Firmware-Path Correctness | +200 | 279 | COMPLETE |
| M13 | TCP Bridge Hardening | +280 | 288 | COMPLETE |
| M14 | USB Gadget Ready | +200 | 295 | COMPLETE |
| M14.5 | Userspace USB/IP HIL | +1500 | 310 | COMPLETE |
| | **Total** | **~13K** | **310** | **M15 NEXT (no hardware needed)** |

---

## Verification Strategy (all phases)

- Each phase added e2e tests comparing firmware-dispatched output against known-good Rust emulation
- `cargo test` passes at every phase boundary
- `cargo clippy --all-targets` clean throughout
- `--emulated-scsi` flag preserved as regression safety net
- Each phase maintained backward compatibility

---

## Assumptions & Edge Cases

### Verified (no action needed)
- Encoder: 0x40530E (count), 0x405314 (delta), 0x405318 (timestamp) — ISR disassembly confirmed
- Motor flags: 0x4052EB (running), 0x4052EC (state), 0x4052EE (error) — motor-control.md
- Motor mode: 0x400774 — ITU2 dispatch code confirmed
- Scan pipeline: 0x4052D6, 0x4052F1, 0x405302, 0x406374, 0x4064E6 — scan-pipeline.md
- CCD format: 14-bit in 16-bit words, bits [15:2] — shlr.w at 0x36C90 confirmed
- ASIC DMA addr: 0x200147/148/149 = big-endian 24-bit — asic-registers.md + scan-pipeline.md
- ASIC DMA count: 0x20014B/14C/14D
- CCD trigger: write 0x80 to 0x2001C1 — scan-pipeline.md
- DMA busy: 0x200002 bit 3 — scan-pipeline.md
- DAC modes: 0x20 (init), 0x22 (scan), 0xA2 (cal) — calibration.md + 16 code refs
- Calibration routines: 0x3D12D, 0x3DE51, 0x3EEF9, 0x3F897 — calibration.md
- CCD characterization: 0x4A8BC-0x528BD, 2 sections, 4095 groups x 4 bytes
- Model flag: 0x404E96
- Response manager: 0x01374A called BEFORE 0x014090

### Resolved During Implementation
- DcInterrupt: bit 12 = EP TX Ready, bit 15 = EP TX Complete. Firmware uses PIO, NOT ISP1581 DMA.
- RAM-resident USB code (0x4010A0): NOT called during firmware dispatch. Only for IRQ1-driven high-speed transfers.
- ISP1581 registers: 0x18, 0x1C, 0x20, 0x28, 0x2C. Offsets 0x24/0x84 from original plan NOT accessed.
- Calibration RAM correction: results at 0x400F0A/12/1A (outputs), parameters at 0x400F56-0x400F9D (inputs)

### Edge Cases

| Edge Case | Handling | Phase |
|-----------|----------|-------|
| Multi-pass scanning | Single-pass only. Re-SCAN resets state and re-injects CCD data. | 9 |
| Firmware error paths | Handler errors write sense to 0x4007B0. Propagate through dispatch mini-loop. | 7 |
| Concurrent SCSI | Mutex: synchronous processing. Cannot overlap by design. | All |
| Flash writes (0x3B) | Log warning + CHECK CONDITION (write-protect sense). | 11 |
| Watchdog during long ops | Auto-feed WDT every 50K instructions in mini-loop. | 7, 10 |
| USB speed negotiation | Gadget advertises both full/high-speed. Reads max-packet-size from 0x600004. | 11 |
| Adapter hot-plug | Not supported. Static adapter type at boot. | N/A |
| SCI serial | Stub. SSR=0x84 (TDRE=1, RDRF=0). Firmware never blocks on SCI. | N/A |
| Calibration data | Pre-populate 0x400F56-0x400F9D with mid-range defaults. `--skip-calibration` fallback. | 10 |
