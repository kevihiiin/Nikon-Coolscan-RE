# RESERVE (0x16)

| Field | Value |
|-------|-------|
| **Status** | Complete |
| **Last Updated** | 2026-02-21 |
| **Phase** | 2 |
| **Confidence** | High |

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

## Open Questions

- Is there a corresponding RELEASE (0x17) command in LS5000.md3?
- Does RESERVE affect scanner behavior (e.g., power management, button lockout)?
- Is this command required, or optional?

## Source References

| Source | Location | Notes |
|--------|----------|-------|
| LS5000.md3 | `0x100aa360` | CDB builder — minimal 6-byte CDB |

## Cross-References

- [TEST UNIT READY](test-unit-ready.md) — precedes RESERVE in initialization
- [INQUIRY](inquiry.md) — identifies scanner before reservation
- [SCSI Command Build Infrastructure](../components/ls5000-md3/scsi-command-build.md) — CDB builder vtable system
- [NKDUSCAN API](../components/nkduscan/api.md) — USB transport that sends this CDB
- [USB Protocol](../architecture/usb-protocol.md) — transport layer details
