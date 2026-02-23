# Nikon Vendor Command 0xC1

| Field | Value |
|-------|-------|
| **Status** | In Progress |
| **Last Updated** | 2026-02-21 |
| **Phase** | 2 |
| **Confidence** | Medium |

## Overview

Nikon vendor-specific SCSI command. Opcode 0xC1 falls in the vendor-specific range
(0xC0-0xFF) of the SCSI specification. Like 0xC0, the CDB builder constructs a minimal
6-byte CDB with only the opcode set, suggesting a simple control or trigger command.

**Purpose is currently unknown.** The adjacent opcode to 0xC0 suggests these two commands
may form a pair (e.g., query/set, enable/disable, start/stop) or may be related functions
in the same subsystem.

Likely candidates:
- Scanner control command (lamp on/off, motor home, eject)
- Mode toggle (preview mode, scan mode, idle mode)
- Acknowledgment or completion signal to the scanner
- Complement to 0xC0 (if 0xC0 reads status, 0xC1 may set state)

## CDB Layout (6 bytes)

| Byte | Field | Value | Notes |
|------|-------|-------|-------|
| 0 | Opcode | `0xC1` | Nikon vendor-specific |
| 1 | Reserved | `0x00` | Minimal — no parameters observed |
| 2 | Reserved | `0x00` | |
| 3 | Reserved | `0x00` | |
| 4 | Reserved | `0x00` | |
| 5 | Control | `0x00` | |

## Data Phase

**Unknown.** Same considerations as 0xC0 — the minimal CDB suggests either no data
phase or a small data transfer.

## Usage Context

Unknown. Needs further analysis:
- When in the scan sequence is this command sent?
- Does it always accompany 0xC0, or is it used independently?
- What scanner state change does it trigger?

## Builder Location Note

The builder for 0xC1 is at `0x100aa5b0`, which is in the **main CDB builder region**
(0x100aa1d0-0x100aa6d0) alongside standard commands like INQUIRY, MODE SELECT, etc.
This contrasts with 0xC0 at `0x100b52d0`, which is in a **separate builder region**
(0x100b51b0-0x100b52d0) alongside READ, WRITE, and READ/WRITE BUFFER.

This address difference may indicate:
- 0xC1 is used in the main scan workflow (like standard commands)
- 0xC0 is used in the data transfer / buffer management subsystem
- They belong to different class hierarchies or functional groups

## Analysis Approach

To determine this command's purpose:
1. Find all call sites of the builder at `0x100aa5b0` in LS5000.md3
2. Compare calling context with 0xC0's call sites
3. Cross-reference with firmware opcode dispatch table
4. Look for vendor command documentation in SCSI scanner specs or Linux drivers

## Source References

| Source | Location | Notes |
|--------|----------|-------|
| LS5000.md3 | `0x100aa5b0` | CDB builder — minimal, opcode-only. In main builder region |

## Cross-References

- [Nikon 0xC0](nikon-c0.md) — related vendor command (adjacent opcode, different builder region)
- [Nikon 0xE0](nikon-e0.md) — another vendor extension command
- [Nikon 0xE1](nikon-e1.md) — another vendor extension command
- [SCSI Command Build Infrastructure](../../components/ls5000-md3/scsi-command-build.md) — CDB builder vtable system
- [NKDUSCAN API](../../components/nkduscan/api.md) — USB transport that sends this CDB
- [USB Protocol](../../architecture/usb-protocol.md) — transport layer details
