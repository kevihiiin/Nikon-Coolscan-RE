# Nikon Vendor Command 0xE0

| Field | Value |
|-------|-------|
| **Status** | In Progress |
| **Last Updated** | 2026-02-21 |
| **Phase** | 2 |
| **Confidence** | Medium |

## Overview

Nikon vendor-specific SCSI command. Opcode 0xE0 is in the vendor-specific range (0xC0-0xFF)
and uses a 10-byte CDB with a sub-command field and transfer length, indicating a more
complex command than the minimal 0xC0/0xC1 commands.

The 10-byte CDB structure with sub-command at byte 2 and 3-byte transfer length at bytes 6-8
suggests this is a **multi-purpose vendor extension command** — a single opcode that dispatches
to different functions based on the sub-command code. This is a common pattern in vendor
SCSI extensions.

**Purpose is currently unknown**, but the structure suggests it handles scanner-specific
operations that don't map to standard SCSI commands, such as:
- Film holder/adapter control (insert, eject, position)
- LED/lamp control (color, intensity, on/off)
- Focus motor control (autofocus, manual focus position)
- Scanner-specific parameter read/write
- Digital ICE infrared channel configuration
- Multi-sample scan control

## CDB Layout (10 bytes)

| Byte | Field | Value | Notes |
|------|-------|-------|-------|
| 0 | Opcode | `0xE0` | Nikon vendor-specific |
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

The sub-command byte selects which vendor-specific operation to perform. The available
sub-commands and their meanings require analysis of:
1. All call sites of the 0xE0 builder in LS5000.md3
2. The firmware's 0xE0 opcode handler and its dispatch table

### Transfer Length (Bytes 6-8)

24-bit big-endian transfer length, same position as in standard 10-byte CDBs (SET WINDOW,
READ, etc.). This indicates the command can transfer variable-length data payloads.

## Data Phase

**Direction:** Unknown — likely varies by sub-command. Some sub-commands may be data-in
(reading scanner state), others data-out (setting parameters), and some may have no data
phase (trigger operations).

## Relationship to 0xE1

Opcodes 0xE0 and 0xE1 share the same CDB structure (sub-command at byte 2, transfer
length at bytes 6-8). They likely form a command pair:
- **0xE0 = read/query** and **0xE1 = write/set** for the same set of vendor operations, OR
- **0xE0 = Group A** and **0xE1 = Group B** of vendor operations (different sub-command spaces)

## Analysis Approach

To determine this command's purpose:
1. Find all call sites of the builder at `0x100aa670` in LS5000.md3
2. Enumerate all sub-command values used
3. For each sub-command, trace the data buffer to understand what data is sent/received
4. Cross-reference with firmware — find the 0xE0 opcode handler and its sub-command dispatch
5. Compare with 0xE1 call patterns to understand the relationship
6. Search for similar vendor extensions in other Nikon or scanner SCSI implementations

## Source References

| Source | Location | Notes |
|--------|----------|-------|
| LS5000.md3 | `0x100aa670` | CDB builder — 10-byte CDB with sub-command at byte 2, transfer length at bytes 6-8 |

## Cross-References

- [Nikon 0xE1](nikon-e1.md) — sister command with same CDB structure
- [Nikon 0xC0](nikon-c0.md) — simpler vendor command (6-byte, no parameters)
- [Nikon 0xC1](nikon-c1.md) — simpler vendor command (6-byte, no parameters)
- [SET WINDOW](../set-window.md) — standard 10-byte CDB with similar transfer length layout
- [SCSI Command Build Infrastructure](../../components/ls5000-md3/scsi-command-build.md) — CDB builder vtable system
- [NKDUSCAN API](../../components/nkduscan/api.md) — USB transport that sends this CDB
- [USB Protocol](../../architecture/usb-protocol.md) — transport layer details
