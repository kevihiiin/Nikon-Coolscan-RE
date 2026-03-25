# Phase 8: Motor & Position Subsystem — Attempt Log

**Status**: COMPLETE (215 tests)
**Milestone**: Motor moves, encoder feedback, VPD pages. SEND DIAGNOSTIC motor commands complete.
**Depends**: Phase 7 (complete)

---

## Session 1 — 2026-03-25 (Phase 8 Implementation)

**Goals**: Implement motor position tracking, encoder feedback, SEND DIAGNOSTIC motor commands, VPD page 0xC0.

### 8.1 Motor Position Model (motor.rs, +180 lines, 7 unit tests)
- `MotorSubsystem` with `scan_motor` + `af_motor` (MotorState structs)
- Stepper phase detection: Port A writes (0xFFFFA3) 01→02→04→08 = 1 step
- Forward/reverse sequence detection from flash tables at 0x16E92/0x4A8A8
- Direction from Port 3 DDR (0xFFFF84) bit 0
- Motor mode from RAM 0x400774 (2/6=scan, 3=AF, 0=idle)
- Home sensor at position 0
- Pending step counter for batched encoder updates

### 8.2-8.3 Encoder Feedback + Motor State Machine (orchestrator sync_peripherals)
- On motor step: write encoder RAM 0x40530E (count), 0x405314 (delta=100), 0x405318 (timestamp from sys tick)
- Motor mode sync from RAM 0x400774 each peripheral cycle
- Completion detection: position==target → set 0x4052EB=0, 0x4052EC=1, 0x4052EE=0
- Home sensor state pushed to GPIO Port 7 each cycle

### 8.4 SEND DIAGNOSTIC Motor Commands
- Task code 0x0400: motor stop
- Task code 0x0430: motor home (drive to position 0)
- Task code 0x0440: relative move (signed step count from param bytes 2-3)
- Task code 0x0450: absolute move (target position from param bytes 2-3)
- `instant_mode` flag for fast testing (teleport to target)

### 8.5 VPD Page 0xC0 (Adapter-Specific CCD Config)
- VPD 0xC0 returns 5-byte CCD readout config per adapter type
- SA-Mount: 1 frame, CCD mode 1, frame size 36mm
- SF-Strip: 6 frames, CCD mode 1, frame size 36mm
- Default: 1 frame, CCD mode 1
- VPD 0xC1: CCD capabilities (max resolution 1200 DPI)
- Note: 0xC0/0xC1 are CCD config, NOT adapter boundary data (boundary = READ DTC 0x88)

### 8.6 Home Sensor in Port 7
- GPIO Port 7 bit 1 (0x02) = home sensor active when scan motor position == 0
- Dynamic: updates each peripheral sync cycle

### Completion Criteria
1. Motor position tracks with stepper phases → **DONE** ✓ (7 unit tests)
2. Encoder RAM vars update → **DONE** ✓ (0x40530E/0x405314/0x405318)
3. Motor home completes → **DONE** ✓ (test_motor_send_diagnostic_home)
4. SEND DIAGNOSTIC commands complete → **DONE** ✓ (4 task codes, 4 e2e tests)
5. VPD page 0xC0 adapter-appropriate → **DONE** ✓ (per-adapter CCD config, test_vpd_c0_adapter_specific)

### Tests Added
- 7 motor unit tests (forward/reverse step, home sensor, AF mode, pending steps, invalid phase, stop)
- 5 SEND DIAGNOSTIC e2e tests (home, relative, absolute, stop, home sensor in Port 7)
- 1 VPD 0xC0 e2e test (adapter-specific CCD config)
- **Total: 215 tests** (38 e2e + 133 core + 44 peripherals). Clippy clean.

