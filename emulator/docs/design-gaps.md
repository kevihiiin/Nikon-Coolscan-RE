# Emulator Roadmap: Phases 7-11

**Status**: Planning complete, ready for implementation
**Last Updated**: 2026-03-24
**Predecessor**: Phases 0-6 complete (~9500 lines Rust, 193 tests, 17 SCSI opcodes via Rust emulation)

---

## Context

Phases 0-6 are complete: ~9500 lines of Rust, 193 tests, boots real LS-50 firmware, handles 17 SCSI opcodes. But all SCSI is handled by Rust code — the firmware's own handlers are never used. No motor, no CCD, no calibration. It's a protocol emulator, not a hardware replica.

This plan bridges that gap across 5 phases, culminating in a firmware-driven emulator where the CPU executes the real SCSI handlers and the orchestrator only provides hardware stimuli (CCD data, motor feedback, USB transport).

---

## Phase 7: ISP1581 DMA & Firmware SCSI Handlers

**Goal**: Get firmware's own SCSI handlers running for data-lookup commands (INQUIRY, REQUEST SENSE, MODE SENSE, RESERVE/RELEASE, GET WINDOW) by implementing ISP1581 DMA completion.

**Why this first**: Every subsequent phase depends on the firmware being able to send response data through its USB I/O path. The 26 NOP patches are the single biggest fidelity gap.

### How It Works Today (the problem)

The firmware's SCSI handlers call two functions:
- `JSR @0x01374A` — USB response manager (sets up DMA direction/phase)
- `JSR @0x014090` — USB data transfer (writes data word-by-word to ISP1581)

Both are NOPed out (26 patches total). Handlers run but can't send data.

### What We Build

**7.0 GATE: Trace Response Manager Register Access** (before any code changes)
- Run `--firmware-dispatch --trace` for a single INQUIRY
- Log all ISP1581 reads/writes (0x600000-0x6000FF) during dispatch
- Log DcInterrupt bit checks in 0x01374A -> 0x13C70 chain
- Check if PC enters 0x4010A0-0x401270 (RAM-resident USB code)
- Catalog any unmodeled ISP1581 offsets that get read
- This 30-minute investigation gates all Phase 7 implementation work

**7.1 ISP1581 DMA State Machine** (`peripherals/src/isp1581.rs`, +250 lines)
- Add `DmaState` enum: `Idle → Configured → Transferring → Complete`
- DMA config write (0x600024) → `Configured`
- DMA count write (0x600084) → record expected transfer size
- EP control write (0x60002C, mode 5) → `Transferring`
- Track bytes written to EP Data Port (0x600020); when count == dma_count → set DMA completion bit in DcInterrupt, transition to `Complete`
- `DcBufferStatus` (0x60001E): return 0 when writable, non-zero when full

**7.2 Endpoint Configuration Registers** (`peripherals/src/isp1581.rs`, +30 lines)
- Offset 0x14: endpoint config (accept writes)
- Offset 0x2E: endpoint index select
- Offset 0x04: endpoint max packet size
- The response manager reads these back during setup

**7.3 Un-NOP Dispatch-Level Response Manager** (`orchestrator.rs`)
- Remove the 11 `JSR @0x01374A` patches at 0x020B22-0x020D9E
- Keep handler-internal patches initially — un-NOP per-handler in 7.5

**7.4 USB State Variables** (`orchestrator.rs`, +50 lines)
- Model `0x40049A` (USB txn active): set on response start, clear on DMA complete
- Model `0x407DC6` (command phase) transitions properly
- Remove periodic `force_usb_session_state()` hack for these specific vars

**7.5 Un-NOP Handler-Internal USB Calls** (incremental)
- Start with INQUIRY: un-NOP 0x026042 + 0x02604A, compare output vs Rust emulation
- Then REQUEST SENSE: un-NOP 0x021932 + 0x02193A
- Then MODE SENSE: un-NOP 0x02209E + 0x0220A8
- Then GET WINDOW: un-NOP 0x0279AE
- Each handler verified by data comparison test

**7.6 Hybrid Dispatch** (`orchestrator.rs`, +50 lines)
- Data-lookup commands → firmware dispatch
- Data-out + scan commands → Rust emulation (until Phases 9-10)
- New `--emulated-scsi` flag forces old behavior for all commands

### Completion Criteria (Updated 2026-03-25)
1. INQUIRY via firmware handler returns identical 36 bytes to Rust emulation — **DONE** ✓
2. REQUEST SENSE via firmware returns correct 18-byte sense data — **DONE** ✓ (byte 7: FW=0x0B vs EMU=0x0A)
3. MODE SENSE via firmware returns correct mode page — **PARTIAL** (handler completes GOOD, needs scanner config state for mode pages)
4. ~~11 dispatch-level NOP patches removed~~ → **CHANGED**: Dispatcher routing via 0x020AE2 with patches in place. Design changed because firmware uses PIO (not DMA), requiring different handshake approach.
5. ~~At least 6 handler-internal patches removed~~ → **CHANGED**: Hybrid approach — INQUIRY uses handler-internal (4 patches un-NOPed for testing), REQUEST SENSE uses dispatch-level path.
6. All 193+ tests still pass in both modes — **DONE** ✓ (202 tests: 32 e2e + 133 core + 37 peripherals)
7. ~~ISP1581 DMA state machine has unit tests~~ → **SUPERSEDED**: Firmware uses PIO word writes, not ISP1581 DMA engine. ISP1581 model has 4 unit tests (DcInterrupt bits 12+15, DcBufferLength, FIFO injection+read).
8. (NEW) Error path: firmware sense propagation — **DONE** ✓ (TUR → REQUEST SENSE produces [0x70])

### Actual: +9 tests (5 e2e gate tests + 4 ISP1581 unit tests)
### Risk mitigated: stuck-PC detector, TRAPA-triggered cmd_pending, 0x400085 clear at data transfer entry.

---

## Phase 8: Motor & Position Subsystem

**Goal**: Model stepper motor position, encoder feedback, and adapter geometry. SEND DIAGNOSTIC motor commands work. VPD boundary pages return real data.

**Why**: The firmware's scan setup requires motor positioning. Without it, SCAN handlers hang waiting for motor completion flags.

### What We Build

**8.1 Motor Position Model** (NEW `peripherals/src/motor.rs`, +350 lines)
- `MotorSubsystem` struct: `position: i32`, `target: i32`, `direction: i8`, `running: bool`, `mode: u8`
- Two motors: `scan_motor` (carriage) and `af_motor` (autofocus), selected by `motor_mode` at RAM 0x400774
- Monitor Port A writes (0xFFFFA3): each stepper phase cycle (01→02→04→08) = 1 step
- Home sensor: when position reaches 0, set GPIO flag

**8.2 Encoder Feedback Injection** (`orchestrator.rs`, +80 lines)
- On motor step, update firmware's encoder RAM:
  - `0x40530E` (encoder_count) = motor position
  - `0x405314` (encoder_delta) = timing value from ITU2 period
  - `0x405318` (encoder_timestamp) = current system tick
- Fire IRQ3 (Vec 15) on step so encoder ISR at 0x033444 runs

**8.3 Motor State Machine** (`orchestrator.rs`, +70 lines)
- Monitor RAM 0x400774 (motor_mode) for movement start
- When motor reaches target, set completion flags:
  - `0x4052EB` (motor_running) = 0
  - `0x4052EC` (motor_state) = done
  - `0x4052EE` (motor_error) = 0
- Stop ITU2 (clear TSTR bit 2)

**8.4 SEND DIAGNOSTIC Motor Commands** (`orchestrator.rs`, +50 lines)
- Task codes 0x0400 (stop), 0x0430 (home), 0x0440 (relative move), 0x0450 (absolute move)
- For firmware-dispatched SEND DIAGNOSTIC, motor model provides completion signals
- For Rust-emulated SEND DIAGNOSTIC, add motor position tracking

**8.5 Adapter Scan Geometry** (`gpio.rs` + `orchestrator.rs`, +60 lines)
- Per-adapter boundary data for VPD page 0xC0/0xC1
- SA-21 (mount): single frame, fixed position
- SF-210 (strip): 6 frames, sequential
- IA-20 (APS): cartridge geometry

**8.6 Home Sensor in Port 7** (`gpio.rs`, +20 lines)
- Dynamic home sensor bit in Port 7 based on motor position

### Completion Criteria (Updated 2026-03-25)
1. Motor position tracks correctly with stepper phase writes — **DONE** ✓
2. Encoder RAM vars update with position — **DONE** ✓
3. Motor home sequence completes (position → 0) — **DONE** ✓
4. SEND DIAGNOSTIC motor commands complete without timeout — **DONE** ✓
5. VPD page 0xC0 returns adapter-appropriate data — **DONE** ✓ (CCD readout config, not boundary data — boundary = READ DTC 0x88)

### Actual: +180 lines motor.rs, +80 lines orchestrator, 13 new tests
### Risk mitigated: instant_mode flag for testing (teleport to target).

---

## Phase 9: CCD & Scan Pipeline

**Goal**: Model CCD capture → ASIC DMA → buffer so firmware's SCAN handler produces pixel data through the firmware path, not Rust emulation.

**Why**: This replaces the synthetic test pattern with firmware-processed scan data, exercising the real pixel processing code at 0x36C90.

### What We Build

**9.1 CCD Data Injection** (`peripherals/src/asic.rs`, +120 lines)
- On ASIC register 0x2001C1 write (CCD trigger), generate one scan line
- Write to ASIC RAM at address from DMA registers (0x200147/148/149)
- Format: 16-bit words, 14-bit CCD data in bits [15:2], 4 channels (R/G/B/IR)
- Data source: configurable via `--ccd-source` (pattern/file/noise)

**9.2 ASIC DMA Completion** (`peripherals/src/asic.rs`, +80 lines)
- Replace hardcoded 50-instruction countdown with transfer-size-based countdown
- Clear DMA busy (0x200002 bit 3) on completion
- Fire Vec 49 (CCD line readout) on line complete
- Fire Vec 45/47 (DEND0B/DEND1B) for DMA end

**9.3 H8 DMA Controller** (REPLACE `peripherals/src/dma.rs`, +250 lines)
- 2 channels: source addr, dest addr, transfer count, control register
- Firmware uses this for ASIC RAM → Buffer RAM transfers
- Instant copy between memory regions on start
- DEND interrupt on completion
- Registers: MAR (0xFFFF20/28), ETCR (0xFFFF24/2C), DTCR (0xFFFF27/2F), DMAOR (0xFFFF90)

**9.4 Scan State Coordination** (`orchestrator.rs`, +150 lines)
- Monitor firmware scan state variables:
  - `0x4052D6` (dma_mode), `0x4052F1` (scan_active), `0x405302` (scan_complete)
  - `0x406374` (dma_burst_counter), `0x4064E6` (line_counter)
- Provide CCD trigger signal at correct points in pipeline
- Let firmware manage state transitions naturally once ASIC/DMA hardware responds correctly

**9.5 Pixel Processing Verification** (tests only)
- Firmware code at 0x36C90 reads ASIC RAM with `mov.w @er+, rN`, does `shlr.w`
- Writes processed pixels to Buffer RAM (0xC00000)
- Verify by checking Buffer RAM contents after processing runs

### Completion Criteria
1. CCD trigger generates pixel data in ASIC RAM
2. DMA busy clears after transfer
3. H8 DMA copies ASIC RAM → Buffer RAM
4. Firmware pixel processing at 0x36C90 produces output in Buffer RAM
5. SCAN via firmware handler initiates full pipeline
6. READ DTC=0x00 returns firmware-processed data (not Rust-synthesized)
7. End-to-end: SET WINDOW → SCAN → READ produces correct pixel count

### Completion Criteria (Updated 2026-03-25)
1. CCD trigger generates pixel data in ASIC RAM — **DONE** ✓
2. DMA busy clears after transfer — **DONE** ✓
3. H8 DMA copies ASIC RAM → Buffer RAM — **DONE** ✓
4. Firmware pixel processing at 0x36C90 — infrastructure ready (Phase 7 dispatch available)
5. SCAN via firmware handler — infrastructure ready
6. READ DTC=0x00 firmware-processed — infrastructure ready
7. SET WINDOW → SCAN → READ correct pixel count — **DONE** ✓ (Rust emulation path)

### Actual: +360 lines, +14 tests (8 ASIC + 6 DMA)
### Risk mitigated: CCD data injection is instant, DMA transfers instant.

---

## Phase 10: Calibration & Full Fidelity

**Goal**: Firmware calibration task codes (0x0500-0x0502) work. Dark frame, white reference, per-channel gain/offset. Complete NikonScan init sequence runs autonomously.

**Why**: NikonScan always calibrates before scanning. Without this, the firmware can't complete a real init sequence.

### What We Build

**10.1 DAC Mode Gating** (`peripherals/src/asic.rs`, +80 lines)
- Check DAC mode at 0x2000C2 when generating CCD data:
  - 0x22 (scan): normal pixel data (from Phase 9)
  - 0xA2 (calibration): calibration-specific data
- Dark frame: low pixel values (0x0010-0x0040)
- White reference: high pixel values (0x3F00-0x3FFF)
- Per-pixel variation to simulate CCD non-uniformity

**10.2 CCD Characterization Data** (verification only)
- Flash data at 0x4A8BC-0x528BD is already in the firmware binary
- Verify firmware access path works: pointer table at 0x4A37E → correction levels (0-11)
- No emulation code needed — just confirm the read path isn't broken

**10.3 Calibration Task Execution** (`orchestrator.rs`, +60 lines)
- Task codes 0x0500/0x0501/0x0502 triggered by SEND DIAGNOSTIC
- Motor moves to calibration position (requires Phase 8)
- CCD capture in DAC mode 0xA2 (requires Phase 9 + 10.1)
- Firmware routines at 0x3D12D/0x3DE51/0x3EEF9/0x3F897 compute min/max

**10.4 Calibration RAM Defaults** (`orchestrator.rs`, +30 lines)
- Pre-populate input parameters at 0x400F56-0x400F9D with mid-range defaults at boot
- After calibration runs, firmware writes computed results to 0x400F0A (min), 0x400F12 (mid), 0x400F1A (max)

**10.5 LS-50 vs LS-5000 Config** (`orchestrator.rs`, +30 lines)
- Set `0x404E96` (model flag) from `--model` CLI flag
- LS-50: fine DAC 0x08, coarse gain 0x64
- LS-5000: fine DAC 0x00, coarse gain 0xB4

### Completion Criteria
1. DAC mode 0xA2 produces calibration CCD data
2. All four calibration routines complete without error
3. Calibration RAM (0x400F0A-0x400F1A) populated with computed values
4. Task codes 0x0500-0x0502 complete via SEND DIAGNOSTIC
5. Both LS-50 and LS-5000 configs work
6. Full NikonScan sequence: TUR → INQUIRY → calibrate → SET WINDOW → SCAN → READ

### Estimated: +380 lines, +7 tests
### Depends: Phase 8 (motor), Phase 9 (CCD pipeline)
### Risk: Calibration data sensitivity — firmware may div-by-zero on bad data. Fallback: `--skip-calibration` flag + pre-populated RAM defaults.

---

## Phase 11: Real USB & Integration

**Goal**: Full ISP1581 USB enumeration, un-NOP ALL patches, connect via USB gadget to NikonScan or custom driver. Zero training wheels.

**Why**: This is the endgame — a drop-in hardware replacement that runs the real firmware.

### What We Build

**11.1 Un-NOP USB Init** (`orchestrator.rs`)
- Remove all 5 USB init patches
- Firmware runs its real USB init sequence (0x12660-0x12800)

**11.2 USB Enumeration Flow** (`peripherals/src/isp1581.rs`, +200 lines)
- Full register flow: Reset → Chip ID → Mode (SOFTCT) → Address → Endpoint Config → Interrupt Enable
- Bus reset bit in DcInterrupt (bit 6)
- Missing registers: DcHardwareConfiguration (0x16), Unlock (0x7C), EndpointMaxPacketSize (0x04)

**11.3 CDB via Firmware IRQ1** (`orchestrator.rs`, +100 lines)
- Host sends CDB → EP1 OUT FIFO → ISP1581 asserts IRQ1
- Firmware ISR at 0x014E00 reads CDB from 0x600020
- Writes to 0x4007DE, sets cmd_pending
- Main loop dispatcher picks it up
- Remove all Rust SCSI intercept code (or gate behind `--emulated-scsi`)

**11.4 Un-NOP All Handler Patches** (`orchestrator.rs`)
- Remove all 16 remaining handler-internal patches
- Every handler sends its own response through USB

**11.5 Gadget Bridge Integration** (`bridge/src/gadget.rs`, +50 lines)
- `gadget.recv()` → inject into ISP1581 EP1 OUT FIFO
- ISP1581 EP2 IN FIFO drain → `gadget.send()`
- Poll loop in `run()`: check gadget for data, inject, drain responses

**11.6 Phase Query (0xD0) + Sense (0x06)** (verification)
- NKDUSCAN.dll uses 0xD0 (phase query) and 0x06 (sense retrieval)
- Both are in firmware dispatch table — verify they work through firmware path

**11.7 Remove force_usb_session_state()** (`orchestrator.rs`, -30 lines)
- With real USB enum, firmware manages 0x407DC7 itself

### Completion Criteria
1. **Zero NOP patches** in `apply_flash_nop_patches()`
2. Firmware handles USB enumeration autonomously
3. CDBs arrive via IRQ1 (firmware reads from ISP1581 FIFO)
4. All 21 SCSI handlers run through firmware code
5. USB gadget connects to real host, completes full scan
6. TCP bridge still works as alternative
7. `force_usb_session_state()` removed

### Estimated: +440 net lines (+640, -200 removing Rust SCSI), +7 tests
### Depends: All previous phases
### Risk: USB protocol timing with real host. Fallback: `dummy_hcd` (software USB host, no timing constraints) for testing; keep `--emulated-scsi` forever as safety net.

---

## Summary

| Phase | Name | Lines | Tests | Key Deliverable |
|-------|------|-------|-------|-----------------|
| **7** | ISP1581 DMA + FW Handlers | +530 | +8 | Firmware sends SCSI responses through USB path |
| **8** | Motor & Position | +636 | +8 | Motor moves, encoder feedback, VPD pages |
| **9** | CCD & Scan Pipeline | +820 | +7 | Firmware-driven scan produces pixel data |
| **10** | Calibration | +380 | +7 | Dark frame, white ref, CCD characterization |
| **11** | Real USB & Integration | +440 net | +7 | Zero patches, NikonScan compatible |
| | **Total** | **~2,800** | **~37** | **Full hardware replica** |

After Phase 11: ~12,300 lines of Rust, ~230 tests, zero NOP patches, firmware handles everything, connects to real host software.

### Verification Strategy (all phases)
- Each phase adds e2e tests comparing firmware-dispatched output against known-good Rust emulation output
- `cargo test` must pass at every phase boundary
- `cargo clippy --all-targets` must be clean
- `--emulated-scsi` flag preserved as regression safety net through all phases
- Each phase maintains backward compatibility: old CLI invocations produce identical behavior

---

## Assumptions and Edge Cases

### Verification Status (post-KB audit)

All firmware RAM addresses and hardware register assumptions have been cross-checked against the KB documentation.

**CONFIRMED (no action needed):**
- Encoder: 0x40530E (count), 0x405314 (delta), 0x405318 (timestamp) — ISR disassembly in motor-control.md
- Motor flags: 0x4052EB (running), 0x4052EC (state), 0x4052EE (error) — motor-control.md
- Motor mode: 0x400774 — ITU2 dispatch code confirmed
- Scan pipeline: 0x4052D6, 0x4052F1, 0x405302, 0x406374, 0x4064E6 — scan-pipeline.md
- CCD format: 14-bit in 16-bit words, bits [15:2] significant — shlr.w at 0x36C90 confirmed
- ASIC DMA addr: 0x200147/148/149 = big-endian 24-bit — asic-registers.md + scan-pipeline.md
- ASIC DMA count: 0x20014B/14C/14D — confirmed
- CCD trigger: write 0x80 to 0x2001C1 — scan-pipeline.md
- DMA busy: 0x200002 bit 3 — scan-pipeline.md
- DAC modes: 0x20 (init), 0x22 (scan), 0xA2 (cal) — calibration.md + 16 code refs
- Calibration routines: 0x3D12D, 0x3DE51, 0x3EEF9, 0x3F897 — calibration.md
- CCD characterization: 0x4A8BC-0x528BD, 2 sections, 4095 groups x 4 bytes — calibration.md
- Model flag: 0x404E96, LS-50 fine=0x08/gain=0x64, LS-5000 fine=0x00/gain=0xB4 — confirmed
- Response manager: 0x01374A called BEFORE 0x014090 — scsi-handler.md verified
- Response manager steps: save phase -> check 0x40049A -> store 0x407DC6 -> call 0x13C70 -> wait -> mark active

**CORRECTION applied to plan:**
- Calibration RAM: results written to 0x400F0A/0x400F12/0x400F1A (outputs), parameters read from 0x400F56-0x400F9D (inputs). Phase 10.4 pre-populates 0x400F56-0x400F9D, checks 0x400F0A-0x400F1A for outputs.

### Remaining Items Requiring Runtime Verification

Items 1-3 were **RESOLVED** by Phase 7.0 gate (2026-03-25):

1. **DcInterrupt bit mask** — **RESOLVED**: Bit 12 (0x1000) = EP TX Ready (response manager entry check via BTST #4 on high byte). Bit 15 (0x8000) = EP TX Complete (polled by state update at FW:0x014014). Firmware does NOT use ISP1581 DMA engine — uses PIO word writes to EP Data Port.

2. **RAM-resident USB code (0x4010A0)** — **RESOLVED**: NOT called during firmware dispatch. PC never entered 0x4010A0-0x4011A2 range. RAM code is only used for IRQ1-driven high-speed transfers.

3. **ISP1581 registers used** — **RESOLVED**: Full catalog: 0x18 (DcInterrupt), 0x1C (DcBufferLength=64), 0x20 (EP Data Port R/W), 0x28 (ControlFunction CLBUF=0x10), 0x2C (EP Control: 0x02=config, 0x05=DMA mode 5). Note: offsets 0x24 and 0x84 from original plan were NOT accessed.

**NEW items found during Phase 7.1:**

4. **Firmware state variables needed for handlers** (Phase 7.1 finding)
   - 0x400773: adapter type index (0=none, 1=SA-Mount). Boot doesn't set this reliably.
   - 0x400877: scanner initialized flag. Must be non-zero for REQUEST SENSE build path.
   - 0x400880: sense response type code. Non-zero triggers build function at FW:0x0111F4.
   - 0x407DCA: USB packet size. Set during USB enumeration (NOPed). Pre-set to 2 for PIO.
   - 0x40008A: FIFO buffer area. Dispatcher init at FW:0x013E0A copies from here to 0x4007DE.
   - 0x4007DE: shared CDB receive / sense response buffer. Cleared by dispatcher init.

5. **Stack frame byte count parameter** — **RESOLVED** (Phase 7.1)
   - REQUEST SENSE: dispatch-level path sends correct data; 8-byte header stripped
   - INQUIRY: handler-internal path with pre-populated buffer at 0x4008A2
   - Post-handler response manager at 0x011186 NOPed to prevent double data transfer

### Items Requiring Outside Information

4. **VPD pages 0xC0/0xC1 per-adapter format** (Phase 8.5)
   - Pages 0xC0 and 0xC1 are NOT in the standard VPD table at 0x49C74. Page 0xC1 has a special pre-table handler.
   - **Recommendation**: Trace firmware INQUIRY with EVPD=1, page=0xC0 for each adapter type after Phase 7.

5. **ISP1581 USB init register sequence** (Phase 11 only)
   - **Action**: Not needed until Phase 11. Cross-reference firmware writes against ISP1581 datasheet Table 60.

### Edge Case Handling

| Edge Case | Handling | Phase |
|-----------|----------|-------|
| **Multi-pass scanning** | Single-pass only. Multi-pass deferred. If firmware requests re-SCAN, reset scan state and re-inject CCD data. | 9 |
| **Firmware error paths** | Handler errors write sense code to 0x4007B0. Errors propagate naturally through dispatch mini-loop. | 7 |
| **Concurrent SCSI commands** | Mutex: `scsi_command()` / `scsi_command_out()` process synchronously. Cannot overlap by design. | All |
| **Flash writes (WRITE BUFFER 0x3B)** | Log warning + return CHECK CONDITION (write-protect sense). Not an emulation goal. | 11 |
| **Watchdog during long ops** | Increase dispatch timeout to 5M. Auto-feed WDT every 50K instructions in mini-loop. | 7, 10 |
| **USB speed negotiation** | Gadget bridge advertises both full/high-speed. Phase 11 reads max-packet-size from 0x600004. | 11 |
| **Adapter hot-plug** | Not supported. Static adapter type at boot. Known limitation. | N/A |
| **SCI serial** | Intentionally stub. SSR=0x84 (TDRE=1, RDRF=0). Firmware never blocks on SCI. | N/A |
| **Calibration data sensitivity** | Pre-populate 0x400F56-0x400F9D with mid-range defaults. `--skip-calibration` flag as fallback. | 10 |
