# Motor Subsystem — Component Attempt Log

**Status**: Complete
**Created**: 2026-03-25

---

## Attempt 1 — 2026-03-25: Motor Position Model (motor.rs)

**Goal**: Create stepper motor position tracking from Port A writes.

**Approach**: New `peripherals/src/motor.rs` with `MotorSubsystem` struct containing `scan_motor` and `af_motor` (MotorState). Detect stepper phase transitions on Port A DR (0xFFFFA3) by comparing current phase with previous — valid transitions in the forward sequence (01→02→04→08) or reverse sequence (08→04→02→01) count as steps.

**Result**: SUCCESS. 7 unit tests cover forward/reverse stepping, home sensor, AF motor mode, pending step counter, invalid phase rejection, and motor stop.

**Key decisions**:
- Direction from Port 3 DDR bit 0 (0xFFFF84), confirmed from motor-control.md
- Motor mode from RAM 0x400774 (2/6=scan, 3=AF, 0=idle), from ITU2 dispatcher
- Home sensor triggers at position == 0
- Pending step counter allows batched encoder updates

---

## Attempt 2 — 2026-03-25: Orchestrator Integration

**Goal**: Wire motor into the emulator's peripheral sync loop.

**Approach**: Added motor sync to `sync_peripherals()` after GPIO sync. Each cycle: read Port A DR for stepper phase, read Port 3 DDR for direction, check motor_mode RAM. On step detection, update encoder RAM variables (0x40530E count, 0x405314 delta, 0x405318 timestamp). Motor completion detected when position matches target.

**Result**: SUCCESS. All 215 tests pass. Motor integrates cleanly with existing peripheral sync.

---

## Attempt 3 — 2026-03-25: SEND DIAGNOSTIC Motor Commands

**Goal**: Handle motor task codes in the SEND DIAGNOSTIC handler.

**Approach**: Parse 4-byte task parameter from data-out phase. Task codes: 0x0400 (stop), 0x0430 (home to position 0), 0x0440 (relative move with signed step count), 0x0450 (absolute move to target). Added `instant_mode` flag for testing that teleports motor to target without step-by-step simulation.

**Result**: SUCCESS. 4 e2e tests verify each task code. Motor position, home sensor, and running state all update correctly.

---

## Attempt 4 — 2026-03-25: VPD 0xC0 and Home Sensor

**Goal**: Return adapter-specific data in VPD page 0xC0 and add home sensor to Port 7.

**Findings**:
- VPD 0xC0/0xC1 are CCD readout config (5 bytes each), NOT adapter boundary data
- Adapter boundary data comes from READ DTC=0x88 (already implemented)
- Home sensor is Port 7 bit 1 (0x02), active at motor position 0

**Result**: SUCCESS. VPD 0xC0 returns per-adapter CCD config (SA-Mount: 1 frame, SF-Strip: 6 frames). Home sensor bit in Port 7 tracks scan motor position dynamically.
