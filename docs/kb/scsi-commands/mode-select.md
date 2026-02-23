# MODE SELECT (0x15)

| Field | Value |
|-------|-------|
| **Status** | Complete |
| **Last Updated** | 2026-02-21 |
| **Phase** | 2 |
| **Confidence** | High |

## Overview

Standard SCSI MODE SELECT(6) command. Sends operating mode parameters to the scanner,
configuring its behavior for subsequent operations. This is the counterpart to MODE SENSE —
MODE SENSE reads parameters, MODE SELECT writes them.

Two builder variants exist in LS5000.md3, suggesting two distinct parameter groups:
1. **Variant 1** at `0x100aa1d0` — "Group A" parameters with a fixed 0x14-byte parameter list
2. **Variant 2** at `0x100aa490` — "Group B" parameters with variable-length data

## CDB Layout (6 bytes)

| Byte | Field | Value | Notes |
|------|-------|-------|-------|
| 0 | Opcode | `0x15` | MODE SELECT(6) |
| 1 | Flags | `0x10` | PF=1 (bit 4): page format — data conforms to page structure |
| 2 | Reserved | `0x00` | |
| 3 | Reserved | `0x00` | |
| 4 | Parameter List Length | varies | Length of data-out payload. 0x14 for variant 1 |
| 5 | Control | `0x00` | |

### Flag Byte (Byte 1) Detail

| Bit | Name | Value | Meaning |
|-----|------|-------|---------|
| 4 | PF | 1 | Page Format: data uses mode page structure (standard) |
| 0 | SP | 0 | Save Pages: 0 = do not save to non-volatile memory |

PF=1 is standard for modern SCSI devices. It indicates the parameter data uses the
standard mode page header + page data format rather than vendor-specific raw format.

## Data Phase

**Direction:** Data-Out (host -> scanner)

### Variant 1 — Group A (0x14 bytes)

Builder at `0x100aa1d0`. Fixed-length parameter list of 0x14 (20) bytes.

```
Offset  Length  Field
0x00    4       Mode parameter header (mode data length, medium type, device-specific, block descriptor length)
0x04    16      Mode page data (page code + page-specific parameters)
```

The exact mode page codes and their parameter meanings require further analysis of the
callers of this builder.

### Variant 2 — Group B (variable length)

Builder at `0x100aa490`. Parameter list length varies depending on the mode page being set.

## Usage Context

- Called during scanner initialization to configure operating modes
- Called before scan operations to set scan-specific parameters
- Often paired with MODE SENSE: read current settings, modify, write back
- Typical sequence: `MODE SENSE` (read) -> modify parameters -> `MODE SELECT` (write)

## Open Questions

- What specific mode pages does the Coolscan support? (Need to trace callers)
- What are the Group A vs Group B parameter groups? (Need to analyze both builder call sites)
- Does the scanner support SP=1 (save to non-volatile storage)?

## Source References

| Source | Location | Notes |
|--------|----------|-------|
| LS5000.md3 | `0x100aa1d0` | Variant 1 builder — Group A, param_list_len=0x14 |
| LS5000.md3 | `0x100aa490` | Variant 2 builder — Group B, variable length |

## Cross-References

- [MODE SENSE](mode-sense.md) — reads the parameters that MODE SELECT writes
- [SCSI Command Build Infrastructure](../components/ls5000-md3/scsi-command-build.md) — CDB builder vtable system
- [NKDUSCAN API](../components/nkduscan/api.md) — USB transport that sends this CDB
- [USB Protocol](../architecture/usb-protocol.md) — transport layer details
