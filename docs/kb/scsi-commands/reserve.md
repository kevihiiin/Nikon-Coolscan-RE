# RESERVE (0x16)

| Field | Value |
|-------|-------|
| **Status** | Complete |
| **Last Updated** | 2026-03-06 |
| **Phase** | 2 + 4 |
| **Confidence** | Verified (cross-validated host ↔ firmware) |

## Overview

Standard SCSI RESERVE command. Reserves the scanner for exclusive use by the initiator
(host), preventing other initiators from accessing the device. While modern USB scanners
are inherently single-host, this command may be used by the Nikon driver as part of the
SCSI protocol formality, or it may trigger scanner-specific behavior such as preventing
power-save mode or locking out front-panel controls.

## CDB Layout (6 bytes)

| Byte | Field | Value | Notes |
|------|-------|-------|-------|
| 0 | Opcode | `0x16` | RESERVE |
| 1 | Reserved | `0x00` | Third-party device ID (usually 0) |
| 2 | Reserved | `0x00` | |
| 3 | Reserved | `0x00` | Reservation list length [MSB] |
| 4 | Reserved | `0x00` | Reservation list length [LSB] |
| 5 | Control | `0x00` | |

## Data Phase

**None** for a simple RESERVE (no extent reservation). The scanner responds with
status only.

If third-party or extent reservation is used (bytes 1, 3-4 non-zero), a data-out
phase may be present, but this is unlikely for the Coolscan.

## Usage Context

- Called during scanner initialization to claim exclusive access
- May be paired with RELEASE (opcode 0x17) at the end of a session, though no RELEASE
  builder has been identified in LS5000.md3 yet
- On a USB-attached scanner, this is less critical than on shared SCSI buses, but the
  firmware may still use it to set internal state (e.g., "session active" flag)
- Typical startup sequence may include:
  `TEST UNIT READY` -> `INQUIRY` -> **`RESERVE`** -> `MODE SENSE` -> (begin operations)

## Firmware Handler (Phase 4)

**Handler address**: `FW:0x021E3E` | **Size**: ~100 bytes | **Exec mode**: 0x01 (no data) | **Perm flags**: 0x07CC

The firmware handler is small (~100 bytes), suggesting RESERVE primarily sets an internal state flag to mark the scanner as "reserved" (session active). Permission flags 0x07CC restrict it from being called during active scan/data transfer states.

RELEASE (0x17) handler at `FW:0x021EA0` is similarly small. Both exist in the firmware dispatch table, confirming the RESERVE/RELEASE pair is implemented.

### Open Questions (Resolved)

- **RELEASE exists** in the firmware at 0x021EA0 (handler for opcode 0x17, perm 0x07FC). LS5000.md3 does NOT have a CDB builder for RELEASE — confirmed by binary search. RELEASE may only be used implicitly (e.g., on disconnect) or not at all by NikonScan.
- RESERVE likely sets an internal "session active" flag, preventing power-save mode.
- RESERVE appears required — it's in the Init Phase A command sequence.

## Source References

| Source | Location | Notes |
|--------|----------|-------|
| LS5000.md3 | `0x100aa360` | CDB builder — minimal 6-byte CDB |

## RELEASE (0x17) — Companion Command

**Handler address**: `FW:0x021EA0` | **Size**: ~100 bytes | **Exec mode**: 0x01 (no data) | **Perm flags**: 0x07FC

### CDB Layout (6 bytes)

| Byte | Field | Value | Notes |
|------|-------|-------|-------|
| 0 | Opcode | `0x17` | RELEASE |
| 1 | Reserved | `0x00` | |
| 2 | Reserved | `0x00` | |
| 3 | Reserved | `0x00` | |
| 4 | Reserved | `0x00` | |
| 5 | Control | `0x00` | |

### Description

Standard SCSI RELEASE command. Clears the reservation set by RESERVE, making the scanner available again. The handler is small (~100 bytes), matching RESERVE — it likely clears the same internal state flag.

Permission flags (0x07FC) allow it in all states except initial (pre-init), which is slightly more permissive than RESERVE (0x07CC). This makes sense: you can release a scanner in more states than you can reserve it.

LS5000.md3 does **not** have a CDB builder for RELEASE — confirmed by exhaustive binary search. RELEASE may only be used implicitly (e.g., on USB disconnect) or by the USB transport layer, not by the application-level scan workflow. A driver implementation can safely omit RELEASE if it manages session lifetime via USB connect/disconnect.

## Cross-References

- [TEST UNIT READY](test-unit-ready.md) — precedes RESERVE in initialization
- [INQUIRY](inquiry.md) — identifies scanner before reservation
- [SCSI Command Build Infrastructure](../components/ls5000-md3/scsi-command-build.md) — CDB builder vtable system
- [NKDUSCAN API](../components/nkduscan/api.md) — USB transport that sends this CDB
- [USB Protocol](../architecture/usb-protocol.md) — transport layer details
