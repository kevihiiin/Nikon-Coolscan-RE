# TEST UNIT READY (0x00)

| Field | Value |
|-------|-------|
| **Status** | Complete |
| **Last Updated** | 2026-02-21 |
| **Phase** | 2 |
| **Confidence** | High |

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

## Source References

| Source | Location | Notes |
|--------|----------|-------|
| LS5000.md3 | `0x100aa2d0` | CDB builder — vtable-based, sets opcode to 0x00 |

## Cross-References

- [SCSI Command Build Infrastructure](../components/ls5000-md3/scsi-command-build.md) — CDB builder vtable system
- [NKDUSCAN API](../components/nkduscan/api.md) — USB transport that sends this CDB
- [INQUIRY](inquiry.md) — typically follows TEST UNIT READY in startup sequence
- [USB Protocol](../architecture/usb-protocol.md) — transport layer details
