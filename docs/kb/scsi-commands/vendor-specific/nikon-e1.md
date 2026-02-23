# Nikon Vendor Command 0xE1

| Field | Value |
|-------|-------|
| **Status** | In Progress |
| **Last Updated** | 2026-02-21 |
| **Phase** | 2 |
| **Confidence** | Medium |

## Overview

Nikon vendor-specific SCSI command. Opcode 0xE1 is in the vendor-specific range (0xC0-0xFF)
and uses the same 10-byte CDB structure as 0xE0 — sub-command at byte 2 and 3-byte transfer
length at bytes 6-8.

As the adjacent opcode to 0xE0 with identical CDB structure, 0xE1 likely forms a command
pair with 0xE0. The most probable relationship:
- **0xE0 = read/query** vendor parameters, **0xE1 = write/set** vendor parameters
- Both use the same sub-command codes to address the same scanner subsystems

**Purpose is currently unknown.** See the analysis approach below and the 0xE0 documentation
for shared context.

## CDB Layout (10 bytes)

| Byte | Field | Value | Notes |
|------|-------|-------|-------|
| 0 | Opcode | `0xE1` | Nikon vendor-specific |
| 1 | Reserved | `0x00` | |
| 2 | Sub-Command | varies | Selects the specific vendor operation |
| 3 | Reserved | `0x00` | |
| 4 | Reserved | `0x00` | |
| 5 | Reserved | `0x00` | |
| 6 | Transfer Length [MSB] | varies | Data payload length (big-endian) |
| 7 | Transfer Length | varies | |
| 8 | Transfer Length [LSB] | varies | |
| 9 | Control | `0x00` | |

### Sub-Command (Byte 2)

Same role as in 0xE0 — selects the vendor-specific operation. May share the same
sub-command code space as 0xE0, or may have its own independent set.

### Transfer Length (Bytes 6-8)

24-bit big-endian transfer length. Same structure as 0xE0 and standard 10-byte CDBs.

## Data Phase

**Direction:** Unknown — likely varies by sub-command. If the 0xE0/0xE1 pair follows a
read/write pattern, 0xE1 sub-commands may be predominantly data-out (host -> scanner).

## Relationship to 0xE0

| Aspect | 0xE0 | 0xE1 |
|--------|------|------|
| CDB size | 10 bytes | 10 bytes |
| Sub-command field | Byte 2 | Byte 2 |
| Transfer length | Bytes 6-8 | Bytes 6-8 |
| Builder address | `0x100aa670` | `0x100aa6a0` |
| Builder region | Main builder area | Main builder area |

The builders are adjacent in memory (`0x100aa670` and `0x100aa6a0`, just 48 bytes apart),
reinforcing that they are closely related — likely twin methods in the same class.

## Analysis Approach

To determine this command's purpose:
1. Find all call sites of the builder at `0x100aa6a0` in LS5000.md3
2. Compare sub-command values with those used by 0xE0
3. Determine if 0xE0 and 0xE1 share sub-command codes (read vs write) or have disjoint sets
4. For each sub-command, trace the data buffer to understand the payload
5. Cross-reference with firmware — find the 0xE1 opcode handler
6. Compare with 0xE0 handler to confirm the read/write pairing hypothesis

## Source References

| Source | Location | Notes |
|--------|----------|-------|
| LS5000.md3 | `0x100aa6a0` | CDB builder — same structure as 0xE0, builders are adjacent |

## Cross-References

- [Nikon 0xE0](nikon-e0.md) — sister command with same CDB structure (likely read counterpart)
- [Nikon 0xC0](nikon-c0.md) — simpler vendor command (6-byte, no parameters)
- [Nikon 0xC1](nikon-c1.md) — simpler vendor command (6-byte, no parameters)
- [SET WINDOW](../set-window.md) — standard 10-byte CDB with similar transfer length layout
- [SCSI Command Build Infrastructure](../../components/ls5000-md3/scsi-command-build.md) — CDB builder vtable system
- [NKDUSCAN API](../../components/nkduscan/api.md) — USB transport that sends this CDB
- [USB Protocol](../../architecture/usb-protocol.md) — transport layer details
