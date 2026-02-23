# MODE SENSE (0x1A)

| Field | Value |
|-------|-------|
| **Status** | Complete |
| **Last Updated** | 2026-02-21 |
| **Phase** | 2 |
| **Confidence** | High |

## Overview

Standard SCSI MODE SENSE(6) command. Reads current operating mode parameters from the
scanner. This is the read-side counterpart to MODE SELECT — the host uses MODE SENSE
to query the scanner's current configuration before modifying it or to verify settings
after a MODE SELECT.

## CDB Layout (6 bytes)

| Byte | Field | Value | Notes |
|------|-------|-------|-------|
| 0 | Opcode | `0x1A` | MODE SENSE(6) |
| 1 | Flags | `0x18` | DBD=1 (bit 3), bit 4 set |
| 2 | Page Code | varies | Mode page to retrieve (bits 5-0), PC (bits 7-6) |
| 3 | Reserved | `0x00` | |
| 4 | Allocation Length | varies | Maximum data the host can accept |
| 5 | Control | `0x00` | |

### Flag Byte (Byte 1) Detail

| Bit | Name | Value | Meaning |
|-----|------|-------|---------|
| 4 | Reserved/Vendor | 1 | Non-standard — possibly Nikon vendor extension |
| 3 | DBD | 1 | Disable Block Descriptors: omit block descriptor from response |

DBD=1 means the response will not include block descriptor data, going straight from
the mode parameter header to the mode page data. This is common for scanner devices
which don't have traditional block-based media.

The additional bit 4 being set (`0x18` instead of `0x08`) is non-standard and may be
a Nikon vendor extension.

### Page Code Byte (Byte 2) Detail

| Bits | Field | Notes |
|------|-------|-------|
| 7-6 | PC (Page Control) | 00=current, 01=changeable, 10=default, 11=saved |
| 5-0 | Page Code | Which mode page to retrieve |

## Data Phase

**Direction:** Data-In (scanner -> host)

### Response Format

```
Offset  Length  Field
0x00    1       Mode Data Length (N-1, excluding this byte)
0x01    1       Medium Type (0x00 for scanners)
0x02    1       Device-Specific Parameter
0x03    1       Block Descriptor Length (0x00 when DBD=1)
0x04    N       Mode Page Data (page code + page length + parameters)
```

### Mode Page Data

Each mode page begins with:

| Offset | Length | Field |
|--------|--------|-------|
| 0 | 1 | Page Code (bit 7 = PS, bits 5-0 = page code) |
| 1 | 1 | Page Length (bytes following) |
| 2+ | varies | Page-specific parameters |

The specific mode pages supported by the Coolscan and their parameter layouts require
further analysis.

## Usage Context

- Called during scanner initialization to read default operating parameters
- Called before configuring a scan to determine current settings
- Paired with MODE SELECT for read-modify-write parameter changes
- Typical sequence: **`MODE SENSE`** (read) -> modify -> `MODE SELECT` (write)

## Open Questions

- Which mode page codes does the Coolscan support?
- What does each mode page control (lamp, motor speed, CCD settings)?
- Why is byte 1 set to `0x18` rather than standard `0x08` (DBD only)?

## Source References

| Source | Location | Notes |
|--------|----------|-------|
| LS5000.md3 | `0x100aa280` | CDB builder — sets opcode 0x1A, byte1=0x18, byte2=page_code, byte4=alloc_len |

## Cross-References

- [MODE SELECT](mode-select.md) — writes the parameters that MODE SENSE reads
- [SCSI Command Build Infrastructure](../components/ls5000-md3/scsi-command-build.md) — CDB builder vtable system
- [NKDUSCAN API](../components/nkduscan/api.md) — USB transport that sends this CDB
- [INQUIRY](inquiry.md) — INQUIRY precedes MODE SENSE in startup sequence
- [USB Protocol](../architecture/usb-protocol.md) — transport layer details
