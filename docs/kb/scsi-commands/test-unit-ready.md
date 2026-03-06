# TEST UNIT READY (0x00)

| Field | Value |
|-------|-------|
| **Status** | Complete |
| **Last Updated** | 2026-02-28 |
| **Phase** | 2 + 4 |
| **Confidence** | Verified (cross-validated host ↔ firmware) |

## Overview

Standard SCSI TEST UNIT READY command. Checks whether the scanner is ready to accept
commands. Returns Good status if the device is powered on, initialized, and not busy.
No data is transferred — the caller only examines the returned SCSI status byte.

This is typically the first command sent after USB enumeration to confirm the scanner
is alive and responsive before issuing more complex operations.

## CDB Layout (6 bytes)

| Byte | Field | Value | Notes |
|------|-------|-------|-------|
| 0 | Opcode | `0x00` | TEST UNIT READY |
| 1 | Reserved | `0x00` | |
| 2 | Reserved | `0x00` | |
| 3 | Reserved | `0x00` | |
| 4 | Reserved | `0x00` | |
| 5 | Control | `0x00` | |

## Data Phase

**None.** This command has no data-in or data-out phase. The scanner responds with
status only (Good = ready, Check Condition = not ready).

## Response Interpretation

| Status | Meaning |
|--------|---------|
| Good (0x00) | Scanner is ready to accept commands |
| Check Condition (0x02) | Scanner not ready — issue REQUEST SENSE for details |

Common sense keys when not ready:
- **NOT READY (0x02)** — scanner is initializing, performing calibration, or has no media loaded
- **UNIT ATTENTION (0x06)** — scanner was reset or power-cycled since last command

## Usage Context

- Called immediately after connection establishment to verify scanner responsiveness
- Called before initiating a scan sequence to confirm readiness
- May be polled repeatedly while waiting for the scanner to finish initialization
- Part of the standard "connect and identify" sequence:
  `TEST UNIT READY` -> `INQUIRY` -> `MODE SENSE` -> (begin scan setup)

## Firmware Handler (Phase 4)

**Handler address**: `FW:0x0215C2` | **Size**: ~700 bytes | **Exec mode**: 0x01 (USB state setup)

The largest SCSI handler in the firmware. Reports scanner readiness through a comprehensive state machine check on `@0x40077C` (scanner state byte):

### Scanner State Machine

| State | Meaning | Sense Code |
|-------|---------|------------|
| 0x00 | Idle (ready) | Good (no error) |
| 0x01 | Active scan | Checks DMA/motor sub-states |
| 0x20-0x2F | Setup phase | Returns status |
| 0x80 | Ejecting film | 0x000D (Medium Removal Request) |
| 0xF0 | Sensor error | 0x0008 (Communication Failure) |
| 0xF1 | Motor error | 0x0009 (Track Following Error) |
| 0xF2 | Active scan (variant) | Checks sub-states |
| 0xF3 | Motor busy | 0x0079 (Motor Busy) |
| 0xF4 | Calibration busy | 0x007A (Calibration Busy) |

### Active Scan Sub-States

When `scanner_state=0x01/0xF2`, the handler checks DMA state `@0x40077A`:
- 0x0330: Scan buffer full (stalled — host needs to READ)
- 0x0340/0x0320: Scan complete
- 0x3000: Resolution-dependent (checks color mode `@0x400E92`)
- 0x2000: Checks sub-states 0x0110, 0x0120, 0x0121

### CDB Validation

Firmware verifies CDB bytes 2-5 are all zero, returning sense 0x0050 (Illegal Request) if not.

## Source References

| Source | Location | Notes |
|--------|----------|-------|
| LS5000.md3 | `0x100aa2d0` | CDB builder — vtable-based, sets opcode to 0x00 |
| Firmware | `0x0215C2` | Handler — state machine checker, 700+ bytes |
| Firmware | `0x40077C` | Scanner state byte (drives TUR response) |

## Cross-References

- [SCSI Command Build Infrastructure](../components/ls5000-md3/scsi-command-build.md) — CDB builder vtable system
- [NKDUSCAN API](../components/nkduscan/api.md) — USB transport that sends this CDB
- [Firmware SCSI Handler](../components/firmware/scsi-handler.md) — Full dispatch table and handler details
- [INQUIRY](inquiry.md) — typically follows TEST UNIT READY in startup sequence
- [USB Protocol](../architecture/usb-protocol.md) — transport layer details
