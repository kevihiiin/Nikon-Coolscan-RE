# INQUIRY (0x12)

| Field | Value |
|-------|-------|
| **Status** | Complete |
| **Last Updated** | 2026-03-06 |
| **Phase** | 2 + 4 |
| **Confidence** | Verified (cross-validated host ↔ firmware) |

## Overview

Standard SCSI INQUIRY command. Returns scanner identification data including vendor name,
product name, and firmware revision. This is the primary way the host software identifies
which scanner model is connected and selects the appropriate .md3 module to load.

Two code paths build INQUIRY CDBs in LS5000.md3:
1. **Vtable-based builder** at `0x100aa5e0` — standard INQUIRY via the CDB builder class hierarchy
2. **Inline builder** at `0x100a4870` — direct CDB construction in scanner identification code

A dispatch function at `0x100a5030` orchestrates INQUIRY handling, including parsing the
returned data to extract vendor/product/revision strings.

## CDB Layout (6 bytes)

| Byte | Field | Value | Notes |
|------|-------|-------|-------|
| 0 | Opcode | `0x12` | INQUIRY |
| 1 | EVPD | `0x00` or `0x01` | Enable Vital Product Data. 0=standard, 1=VPD page |
| 2 | Page Code | `0x00` | VPD page code (only valid when EVPD=1) |
| 3 | Reserved | `0x00` | |
| 4 | Allocation Length | varies | Length of data the host can accept (typically 36 or more) |
| 5 | Control | `0x80` or `0x00` | Bit 7 set = Nikon vendor flag? Standard SCSI uses 0x00 |

### Control Byte Note

The Nikon driver sometimes sets the control byte (byte 5) to `0x80`. This is non-standard
for SCSI — in standard SCSI, the control byte should be `0x00` for simple commands. The
`0x80` value may be a vendor-specific extension flag that the firmware recognizes, or it may
be passed through to the USB transport layer as a signal.

## Data Phase

**Direction:** Data-In (scanner -> host)

### Standard INQUIRY Data (EVPD=0)

Minimum 36 bytes, layout per SCSI SPC spec:

| Offset | Length | Field | Expected Value |
|--------|--------|-------|----------------|
| 0 | 1 | Peripheral Qualifier + Device Type | `0x06` (scanner) |
| 1 | 1 | RMB + Device Type Modifier | |
| 2 | 1 | ISO/ECMA/ANSI Version | |
| 3 | 1 | Response Data Format | `0x02` (SPC) |
| 4 | 1 | Additional Length | N-4 |
| 5-7 | 3 | Reserved/Flags | |
| 8-15 | 8 | Vendor Identification | `"Nikon   "` (padded with spaces) |
| 16-31 | 16 | Product Identification | `"LS-50 ED        "` or `"LS-5000 ED      "` |
| 32-35 | 4 | Product Revision Level | Firmware version string |

### Known Product Strings (from firmware)

| String | Scanner |
|--------|---------|
| `LS-50 ED` | Coolscan V ED (LS-50) |
| `LS-5000` | Super Coolscan 5000 ED (LS-5000) |

Both strings are present in the LS-50 firmware binary, suggesting the firmware identifies
itself differently based on hardware configuration or model detection.

## Usage Context

- Called during scanner initialization immediately after TEST UNIT READY succeeds
- The returned product string determines which .md3 module to load
- May be called with EVPD=1 to request specific Vital Product Data pages (serial number, etc.)
- Part of the startup sequence: `TEST UNIT READY` -> **`INQUIRY`** -> `MODE SENSE`

## Firmware Handler (Phase 4)

**Handler address**: `FW:0x025E18` | **Size**: ~580 bytes | **Exec mode**: 0x03 (data-in)

### CDB Parsing (Firmware)

- CDB[1] bit 0: EVPD flag (1 = VPD page mode)
- CDB[1] bits 1-4: Reserved, must be zero → sense 0x0050
- CDB[2]: VPD page code
- CDB[5] bit 7: CMDDT flag
- CDB[5] & 0x3F: allocation length low bits

### Standard INQUIRY Response

Built at buffer `@0x4008A2`. Device type 0x06 (Scanner). Response at flash `FW:0x49E31`: `"Nikon   LS-50 ED        1.02"`.

### VPD Page Dispatch (Two-Level)

**Standard VPD table** at `FW:0x49C20` (8 entries × 6 bytes):

| Page | Handler | Description |
|------|---------|-------------|
| 0x00 | 0x0260BA | Supported VPD page list |
| 0x01 | 0x026178 | Unit serial number |
| 0x10 | 0x026178 | Device identification |
| 0x40-0x41 | 0x026178 | Vendor-specific pages |
| 0x50-0x52 | 0x026178 | Vendor-specific pages |

**Adapter-specific VPD table** at `FW:0x49C74` (8 adapters × 5 entries × 6 bytes):

| Adapter | Pages | Handler(s) |
|---------|-------|------------|
| 0 (none) | 0xF8, 0xFA, 0xFB, 0xFC | Custom: `0x026C70`, `0x026D86`, `0x026DD6`, `0x026DAA` |
| 1 (Mount) | 0x46 | `0x026178` |
| 2 (Strip) | 0x43, 0x44, 0xE2 | `0x026178`, `0x026178`, `0x026CC6` |
| 3 (240) | 0x45, 0xF1 | `0x026178`, `0x026C1C` |
| 4 (Feeder) | 0x46, 0xE2 | `0x026178`, `0x026CC6` |
| 5 (6Strip) | 0x47, 0xE2 | `0x026178`, `0x026CC6` |
| 6 (36Strip) | 0x10 | `0x026178` |
| 7 (Test) | *(none)* | Factory test jig — no VPD pages |

Adapter type 7 ("Test") is a factory manufacturing test jig. It is detected via GPIO Port 7 but has zero VPD page entries, meaning NikonScan would not recognize it as a valid adapter. See [Film Adapters](../components/firmware/film-adapters.md).

Special case: VPD page 0xC1 is handled before table lookup (returns [page_code, 0, 2, 0, 0xC1]).

## Source References

| Source | Location | Notes |
|--------|----------|-------|
| LS5000.md3 | `0x100aa5e0` | Vtable-based CDB builder |
| LS5000.md3 | `0x100a4870` | Inline CDB builder in identification code |
| LS5000.md3 | `0x100a5030` | Dispatch function — parses INQUIRY response |
| Firmware | `0x025E18` | Handler — VPD dispatch, adapter-specific pages |
| Firmware | `0x49E31` | INQUIRY response string `"Nikon   LS-50 ED        1.02"` |
| Firmware | `0x49C20` | Standard VPD dispatch table (8 entries) |
| Firmware | `0x49C74` | Adapter-specific VPD table (8 adapters × 5 entries) |

## Cross-References

- [Film Adapters](../components/firmware/film-adapters.md) — All 8 adapter types including factory test jig
- [SCSI Command Build Infrastructure](../components/ls5000-md3/scsi-command-build.md) — CDB builder vtable system
- [NKDUSCAN API](../components/nkduscan/api.md) — USB transport that sends this CDB
- [Firmware SCSI Handler](../components/firmware/scsi-handler.md) — Full dispatch table and handler details
- [TEST UNIT READY](test-unit-ready.md) — precedes INQUIRY in startup sequence
- [MODE SENSE](mode-sense.md) — follows INQUIRY in startup sequence
- [USB Protocol](../architecture/usb-protocol.md) — transport layer details
