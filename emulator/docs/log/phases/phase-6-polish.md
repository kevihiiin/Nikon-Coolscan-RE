# Phase 6: Polish — Attempt Log

**Status**: Complete
**Milestone**: End-to-end validation — all 63 tests pass (44 unit + 3 ISP1581 + 16 e2e integration)

---

## Session 1 — 2026-03-19

**Goals**: Code quality polish, end-to-end integration test, bug fixes

### Clippy Cleanup (45 → 0 warnings)
- Fixed 20 empty-line-after-doc-comment: converted `///` to `//!` inner doc comments across all 23 .rs files
- Fixed 11 collapsible-if: collapsed nested `if` into let-chains with `&&`
- Fixed misc: unnecessary casts (u16→u16, u32→u32), `map_or` → `is_some_and`, `unwrap` after `is_some` → `if let`, `payload.get(0)` → `payload.first()`, `% 10000 == 0` → `.is_multiple_of(10000)`, loop variable indexing → `iter_mut().enumerate()`, added `Default` impl for `GadgetBridge`, simplified `match` to `if` in ADC

### CLI Improvements
- Added `--help` / `-h` flag with full usage documentation
- Renamed `_tcp_port` field to `tcp_port` (was prefixed to suppress unused warning, now used)
- Replaced dead TcpBridge stub in `bridge/src/tcp.rs` with protocol documentation only

### Crate Restructure
- Created `coolscan-emu/src/lib.rs` to expose `config` and `orchestrator` modules
- Enables integration tests to import the emulator programmatically
- Added public API: `ScsiResult`, `boot_to_main_loop()`, `scsi_command()`, `scsi_command_out()`, `is_scan_active()`

### Bug Fix: MOV.L ERs, ERd Decoder Regression
- **Root cause**: Commit 3bf52c9 incorrectly marked `0F 9x/Bx-Fx` as Unknown
- These are valid MOV.L ERs, ERd instructions (encoding `0F (8+s)d`)
- Fixed: any nib2 with bit 3 set (except 0xA=DAA) now decodes as MOV.L
- Impact: firmware was halting at 0x0203FE (MOV.L ER6, ER0) during RAM test

### Boot Milestone Fix
- `boot_to_main_loop()` was checking for `FW_MAIN_LOOP` in milestones_seen, but `handle_oneshot_actions` uses `0xDEAD0001` as the marker
- Fixed to check for `0xDEAD0001`
- Added `force_usb_session_state()` calls (every 1000 insns) to prevent USB re-establish loop
- Added `log_milestone()` calls for milestone tracking

### End-to-End Integration Test (16 tests)
- `test_firmware_boots` — verifies firmware reaches main loop in ≤5M instructions
- `test_tur` — TEST UNIT READY returns GOOD
- `test_inquiry_standard` — INQUIRY returns 36 bytes, vendor "Nikon", product "LS-50 ED", revision "1.02"
- `test_inquiry_evpd_page_00` — VPD supported pages
- `test_request_sense` — 18-byte sense data, response code 0x70
- `test_reserve_release` — exclusive access lifecycle
- `test_mode_sense` — MODE SENSE page 0x03
- `test_mode_select` — data-out acceptance
- `test_send_diagnostic` — self-test
- `test_set_get_window` — SET WINDOW stores, GET WINDOW returns 80 bytes
- `test_read_scan_params` — READ DTC=0x87 returns 24 bytes
- `test_read_boundary` — READ DTC=0x88 returns 644 bytes
- `test_write_gamma_lut` — WRITE DTC=0x03 accepts 768-byte LUT
- `test_illegal_opcode` — unknown opcode returns ILLEGAL REQUEST (SK=5, ASC=0x24)
- `test_full_scan_sequence` — complete init→reserve→calibrate→scan→read sequence, validates 270KB image (300×300×3)
- `test_vendor_commands` — C0/C1/E0/E1 vendor commands

### Test Results
- **63 tests total**: 44 unit (CPU/decode/execute) + 3 ISP1581 + 16 e2e integration
- **0 clippy warnings**
- **Clean build** on all 4 crates
