# Nikon Vendor Command 0xC0

| Field | Value |
|-------|-------|
| **Status** | In Progress |
| **Last Updated** | 2026-02-21 |
| **Phase** | 2 |
| **Confidence** | Medium |

## Overview

Nikon vendor-specific SCSI command. Opcode 0xC0 falls in the vendor-specific range
(0xC0-0xFF) of the SCSI specification, meaning its behavior is entirely defined by
Nikon's firmware.

The CDB builder constructs a minimal 6-byte CDB with only the opcode set, suggesting
this is a simple status query or trigger command with no parameters.

**Purpose is currently unknown.** Likely candidates:
- Scanner status query (temperature, lamp hours, error state)
- Hardware reset or mode change trigger
- Scanner-specific readiness check beyond TEST UNIT READY
- Vendor-specific "ping" or keepalive

## CDB Layout (6 bytes)

| Byte | Field | Value | Notes |
|------|-------|-------|-------|
| 0 | Opcode | `0xC0` | Nikon vendor-specific |
| 1 | Reserved | `0x00` | Minimal — no parameters observed |
| 2 | Reserved | `0x00` | |
| 3 | Reserved | `0x00` | |
| 4 | Reserved | `0x00` | |
| 5 | Control | `0x00` | |

## Data Phase

**Unknown.** The minimal CDB suggests either:
- No data phase (status-only command, like TEST UNIT READY)
- Small data-in phase (short status response)

Analysis of the builder's callers is needed to determine if a data buffer is allocated.

## Usage Context

Unknown. Needs further analysis:
- When in the scan sequence is this command sent?
- Is it sent once during initialization, or repeatedly?
- What does the response (if any) contain?

## Analysis Approach

To determine this command's purpose:
1. Find all call sites of the builder at `0x100b52d0` in LS5000.md3
2. Trace backward to understand the calling context
3. Examine any data buffers passed to the transport layer
4. Cross-reference with firmware — find the 0xC0 opcode handler in the H8/300H code
5. Look for similar commands in other Nikon scanner documentation or Linux driver projects

## Source References

| Source | Location | Notes |
|--------|----------|-------|
| LS5000.md3 | `0x100b52d0` | CDB builder — minimal, opcode-only |

## Cross-References

- [Nikon 0xC1](nikon-c1.md) — related vendor command (adjacent opcode)
- [Nikon 0xE0](nikon-e0.md) — another vendor extension command
- [Nikon 0xE1](nikon-e1.md) — another vendor extension command
- [SCSI Command Build Infrastructure](../../components/ls5000-md3/scsi-command-build.md) — CDB builder vtable system
- [NKDUSCAN API](../../components/nkduscan/api.md) — USB transport that sends this CDB
- [USB Protocol](../../architecture/usb-protocol.md) — transport layer details
