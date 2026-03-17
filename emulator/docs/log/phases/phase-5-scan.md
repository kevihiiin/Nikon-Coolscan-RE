# Phase 5: Scan — Attempt Log

**Status**: COMPLETE — Full scan sequence verified end-to-end (300x300 8bpp RGB → 270KB)
**Last Updated**: 2026-03-17

---

## 2026-03-17 — Phase 5 Implementation (Session 9)

### Comprehensive code review performed
Before starting Phase 5, ran 4 specialized review agents across all 23 .rs files (~6800 LOC):
- **Silent Failure Hunter**: 21 findings (6 critical, 6 high, 9 medium)
- **Bug Hunter**: 4 findings (1 critical SLEEP escape bug, 3 important)
- **Code Simplifier**: 12 priority findings across 5 categories
- **Phase 5 Gap Analyzer**: 12/17 SCSI opcodes missing, 5 stale doc files

### Bug fixes applied (before Phase 5 work)
1. **BUG-1 CRITICAL**: CPU SLEEP escape when I=1 — added `interrupt_masked()` check (orchestrator.rs)
2. **BUG-2**: `RegIndirectDisp24` displacement not sign-extended — added `sign_extend_24()` helper (decode.rs)
3. **BUG-3**: 78-prefix decoder returned NOP for unknown bit ops → now returns Unknown (decode.rs)
4. **SF-1-5**: 5 executor catch-all returns now log::error instead of silent 0 (execute.rs)
5. **SF-6**: ISP1581 FIFO underrun warning upgraded from debug to warn with byte count (isp1581.rs)
6. **SF-7**: ISP1581 `irq_pending` now cleared on `ep_status` writeback too (isp1581.rs)
7. **SF-8**: TCP `set_nonblocking` failure now aborts bridge setup instead of creating blocking listener (orchestrator.rs)
8. **Config warnings**: Unknown adapter/args/parse failures now emit warnings (config.rs)

### Named constants (SIMP-1)
- Extracted ~20 firmware address constants to top of orchestrator.rs
- All magic hex literals replaced with named `FW_*` constants throughout
- Prevents hex typo bugs in future code

### Phase 5 SCSI commands implemented
All commands emulated in `handle_scsi_command()` at orchestrator level:

| Opcode | Command | Status |
|--------|---------|--------|
| 0x16 | RESERVE | GOOD stub (sets flag) |
| 0x17 | RELEASE | GOOD stub (clears flag) |
| 0x1B | SCAN | Generates test pattern image data |
| 0x1D | SEND DIAGNOSTIC | GOOD stub |
| 0x24 | SET WINDOW | Consumes + stores window descriptor |
| 0x25 | GET WINDOW | Returns stored window descriptor |
| 0x28 | READ(10) | DTC dispatch: 0x00=image, 0x03=LUT, 0x84=cal, 0x87=params, 0x88=boundary, 0xE0=extcfg |
| 0x2A | WRITE(10) | DTC dispatch: 0x03=LUT, 0x84/0x85=cal, 0x88=boundary, 0xE0=extcfg |
| 0xC0/C1 | VENDOR C0/C1 | GOOD stubs |
| 0xE0 | VENDOR E0 | Consumes data-out |
| 0xE1 | VENDOR E1 | Returns zeros |

### Scan image synthesis
- Parses window descriptor for resolution, dimensions, BPP
- Generates RGB gradient test pattern (R=left-right, G=top-bottom, B=diagonal)
- Supports 8-bit and 16-bit per channel
- Chunked READ DTC=0x00 delivers image data progressively
- Scan active flag tracks state (READ rejects if no SCAN issued)

### Test client updated
- Added 7 new functions: send_reserve, send_diagnostic, send_get_window, send_scan, send_read, send_write, run_scan_sequence
- `scan` mode: full init → reserve → calibrate → set window → scan → read image chunks
- TCP payload cap increased from 4KB to 64KB for scan data delivery

### Helpers added
- `scsi_good()`, `scsi_illegal_request()`, `cdb_xfer_len_24()` reduce duplication
- Emulator struct gains: reserved, scan_active, window_descriptor, scan_data, scan_data_offset

---

## 2026-03-17 — Phase 5 COMPLETE (Session 10)

### Critical bugs found and fixed

**Bug 1: SCSI command timing race**
- Commands processed in `handle_oneshot_actions` (after instruction execute)
- Firmware read `cmd_pending=1` BEFORE our intercept could clear it
- Firmware entered dispatcher path → hangs without USB transport
- Fix: process SCSI commands synchronously in TCP message handler
- No firmware interception needed at all

**Bug 2: Data-out flow broken**
- SET WINDOW, MODE SELECT, WRITE data-out payloads arrived as separate TCP frames
- CDB processed immediately → tried to drain EP1 OUT FIFO → empty
- Fix: buffer CDB as `pending_dataout_opcode`, defer until data-out frame arrives
- `cmd_pending` also deferred to prevent firmware from seeing premature state

**Bug 3: EP1 OUT vs EP2 IN FIFO confusion**
- Data-out handlers called `isp1581_drain()` which reads EP2 IN (device→host)
- Should read EP1 OUT (host→device) where injected data lives
- Fix: added `isp1581_drain_host_data()` method to memory bus
- Added `drain_host_data()` to MmioDevice trait
- All 4 data-out handlers (MODE SELECT, SET WINDOW, WRITE, VENDOR E0) corrected

**Bug 4: TCP single-frame polling**
- `poll_tcp()` read only ONE frame per cycle (1000 instruction interval)
- CDB + data-out as consecutive frames: data-out delayed by 1000+ instructions
- Fix: read ALL available frames per poll cycle (loop until WouldBlock)
- Collect frames first, then process (avoids borrow checker issues)

### New features

**INQUIRY EVPD (adapter detection)**
- Page 0x00: supported VPD pages list
- Page 0xC0: adapter identification (returns Port 7 GPIO value)
- Page 0xC1: adapter capabilities (stub)
- Unsupported pages return ILLEGAL REQUEST

**Image composition parsing**
- Window descriptor byte 33 = image composition (was incorrectly used as BPP)
- Byte 34 = actual bits per pixel
- Composition 5→RGB (3 channels), 1/2→grayscale (1 channel)

**Window dimension units**
- Width/height in 1/1200 inch, converted to pixels via DPI
- Test client corrected: 1200 units = 1 inch (was sending 300)

### End-to-end verification
Full scan sequence tested: TUR → INQUIRY → REQUEST SENSE → RESERVE → MODE SELECT →
SEND DIAGNOSTIC → SET WINDOW (80 bytes) → GET WINDOW → READ params → READ boundary →
WRITE gamma → SCAN → READ image data (66 chunks, 270KB) → final REQUEST SENSE

**300 DPI, 1×1 inch, 8-bit RGB = 300×300×3 = 270,000 bytes** ✓

### Phase 5 milestone: "Full scan returns image data" — COMPLETE
