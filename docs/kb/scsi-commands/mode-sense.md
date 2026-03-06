# MODE SENSE (0x1A)

| Field | Value |
|-------|-------|
| **Status** | Complete |
| **Last Updated** | 2026-02-28 |
| **Phase** | 2 + 4 |
| **Confidence** | Verified (cross-validated host ↔ firmware) |

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

## Firmware Handler (Phase 4)

**Handler address**: `FW:0x021F1C` | **Size**: ~420 bytes | **Exec mode**: 0x03 (data-in)

### CDB Parsing (Firmware)

- CDB[1] bit 4: DBD (Disable Block Descriptors)
- CDB[1] & 0x07: Reserved, must be zero
- CDB[2] bits 6-7: Page Control (PC) field
- CDB[2] bits 0-5: Page code
- CDB[3]: Must be zero
- CDB[4]: Allocation length (0 defaults to 256)
- CDB[5]: Must be zero

### Supported Mode Pages (ANSWERED)

| Page Code | Description | Data Source |
|-----------|-------------|-------------|
| **0x03** | Format/device-specific (resolution, max scan area) | See below |
| **0x3F** | All pages (returns all supported pages concatenated) | |

### Page Control Modes

| PC Value | Mode | Data Source |
|----------|------|-------------|
| 0 | Current values | RAM `@0x400D2A` (8 bytes per page) |
| 1 | Changeable values | RAM `@0x400D32` (8 bytes) |
| 2 | Default values | Flash `FW:0x0168AF` (8 bytes) |
| 3 | Saved values | **Not supported** → sense 0x0059 |

### Default Page Data (Flash 0x0168AF)

Page 0x03 default values:
- Page code: 0x03
- Page length: 6
- Base resolution: **1200 DPI**
- Max X: **4000 units**
- Max Y: **4000 units**

### Mode Page Header (RAM 0x400D26)

3 bytes: mode data length, medium type (0x00 for scanners), device-specific parameter.

## Open Questions (RESOLVED)

- ~~Which mode page codes does the Coolscan support?~~ **Page 0x03** (device-specific) and **0x3F** (all pages)
- ~~What does each mode page control?~~ **Page 0x03**: resolution and max scan area dimensions
- ~~Why byte 1 = 0x18 instead of 0x08?~~ Bit 4 is a vendor extension. Firmware checks CDB[1] & 0x07 only (reserved bits), so bit 4 is accepted but no specific action is taken for it.

## Source References

| Source | Location | Notes |
|--------|----------|-------|
| LS5000.md3 | `0x100aa280` | CDB builder — sets opcode 0x1A, byte1=0x18, byte2=page_code, byte4=alloc_len |
| Firmware | `0x021F1C` | Handler — page control dispatch, 420 bytes |
| Firmware | `0x0168AF` | Default mode page data (flash, page 0x03) |
| Firmware | `0x400D26` | Mode page header (RAM, 3 bytes) |
| Firmware | `0x400D2A` | Current mode page values (RAM) |

## Cross-References

- [MODE SELECT](mode-select.md) — writes the parameters that MODE SENSE reads
- [Firmware SCSI Handler](../components/firmware/scsi-handler.md) — Full dispatch table and handler details
- [SCSI Command Build Infrastructure](../components/ls5000-md3/scsi-command-build.md) — CDB builder vtable system
- [NKDUSCAN API](../components/nkduscan/api.md) — USB transport that sends this CDB
- [INQUIRY](inquiry.md) — INQUIRY precedes MODE SENSE in startup sequence
- [USB Protocol](../architecture/usb-protocol.md) — transport layer details
