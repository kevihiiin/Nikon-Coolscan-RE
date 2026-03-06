# Firmware Data Tables — Nikon LS-50

**Status**: Complete
**Last Updated**: 2026-03-06
**Phase**: 4 (Firmware)
**Confidence**: High (table addresses and entry counts confirmed from binary; some entry semantics inferred)

## Overview

The LS-50 firmware contains multiple data-driven tables in flash that define the scanner's behavior. These tables are concentrated in the 0x45000-0x528BE region (data tables area) and the 0x16000-0x17000 region (shared module data).

## SCSI Handler Table (0x49834)

Primary SCSI command dispatch table. 20 entries × 10 bytes each.

Entry format: `opcode:8, pad:8, flags:16, handler_ptr:32, exec_mode:8, pad:8`

| Opcode | Flags | Handler | Exec Mode | Command |
|--------|-------|---------|-----------|---------|
| 0x00 | 0x2004 | 0x215C2 | in | TEST UNIT READY |
| 0x03 | 0x2047 | 0x21866 | bidir | REQUEST SENSE |
| 0x12 | 0x2047 | 0x25E18 | bidir | INQUIRY |
| 0x15 | 0x0014 | 0x2194A | out | MODE SELECT |
| 0x16 | 0x07CC | 0x21E3E | in | RESERVE |
| 0x17 | 0x07FC | 0x21EA0 | in | RELEASE |
| 0x1A | 0x07D4 | 0x21F1C | bidir | MODE SENSE |
| 0x1B | 0x0014 | 0x220B8 | none | START/STOP UNIT |
| 0x1C | 0x0014 | 0x23856 | bidir | RECEIVE DIAGNOSTIC |
| 0x1D | 0x0016 | 0x23D32 | out | SEND DIAGNOSTIC |
| 0x24 | 0x0014 | 0x26E38 | out | SET WINDOW |
| 0x25 | 0x0254 | 0x272F6 | bidir | GET WINDOW |
| 0x28 | 0x0054 | 0x23F10 | bidir | READ |
| 0x2A | 0x0014 | 0x25506 | out | WRITE |
| 0x3B | 0x0014 | 0x2837C | out | WRITE BUFFER |
| 0x3C | 0x0014 | 0x28884 | bidir | READ BUFFER |
| 0xC0 | 0x0754 | 0x28AB4 | in | Vendor: Read Status |
| 0xC1 | 0x0014 | 0x28B08 | in | Vendor: Control |
| 0xD0 | 0x07FF | 0x13748 | in | Vendor: Phase Query |
| 0xE0 | 0x0014 | 0x28E16 | out | Vendor: Data Out |
| 0xE1 | 0x0014 | 0x295EA | bidir | Vendor: Data In |

## Internal Task Table (0x49910)

94 entries × 4 bytes each (task_code:16, handler_index:16). Organized by subsystem:

| Prefix | Count | Subsystem | Example Tasks |
|--------|-------|-----------|---------------|
| `0x01xx` | 3 | System init | Init sequence tasks |
| `0x02xx` | 1 | High-level | Single top-level task |
| `0x03xx` | 8 | Motor position | Relative/absolute move, home |
| `0x04xx` | 4 | Focus/lens | Focus motor tasks |
| `0x05xx` | 3 | Calibration | Primary/secondary cal, shared handler |
| `0x06xx` | 10 | CCD readout | 5 basic + 5 extended configs |
| `0x08xx` | **42** | **Scan workflow** | Preview, fine, multi-pass, per-resolution modes |
| `0x09xx` | 8 | Exposure/timing | Exposure sequence tasks |
| `0x0Fxx` | 6 | Error recovery | Post-scan cleanup |
| `0x10xx` | 1 | Power/lamp | Lamp control |
| `0x11xx` | 1 | Dust detection | Digital ICE support |
| `0x12xx` | 1 | Extended | Final entry |
| `0x20xx` | 1 | Startup | Boot task |
| `0x30xx` | 1 | Self-test | Hardware diagnostics |
| `0x40xx` | 1 | Eject | Media eject |
| `0x70xx` | 1 | Park/sleep | Low-power mode |
| `0x80xx` | 1 | Firmware reset | Soft restart |
| `0x90xx` | 1 | Hardware reset | Full reset |

The 0x08xx scan group is the largest (42 tasks), covering all scan modes across resolutions, color modes, and adapter types. Tasks 0x0891-0x08B4 (handler indices 133-144) appear to be extended modes added in a later firmware revision.

### Task Dispatch

Task dispatch function at `FW:0x20DBA`: linear search through the table at `0x49910`, matching the task code, returns handler index. The handler index maps to a function pointer table for the actual handler invocation.

## INQUIRY VPD Tables

### Standard VPD Table (0x49C20)

8 standard VPD pages:

| Page | Handler |
|------|---------|
| 0x00 | Supported VPD pages list |
| 0x01 | ASCII identification |
| 0x10 | Unicode identification |
| 0x40 | Scanner-specific page |
| 0x41 | Scanner-specific page |
| 0x50 | Extension page |
| 0x51 | Extension page |
| 0x52 | Extension page |

### Adapter-Specific VPD Table (0x49C74)

8 adapter types × 5 VPD page entries. See [Film Adapters](film-adapters.md) for full analysis.

| Adapter | Pages |
|---------|-------|
| 0 (none) | 0xF8, 0xFA, 0xFB, 0xFC |
| 1 (Mount) | 0x46 |
| 2 (Strip) | 0x43, 0x44, 0xE2 |
| 3 (240) | 0x45, 0xF1 |
| 4 (Feeder) | 0x46, 0xE2 |
| 5 (6Strip) | 0x47, 0xE2 |
| 6 (36Strip) | 0x10 |
| 7 (Test) | *(none — factory test jig)* |

## Vendor Register Table (0x4A134)

23 entries mapping E0/C1/E1 register IDs to maximum data lengths:

| Reg ID | Max Length | Purpose |
|--------|-----------|---------|
| 0x40-0x47 | 5-13 bytes | Scan control parameters |
| 0x80 | 9 bytes | Lamp/exposure control |
| 0x81 | 0 bytes | Lamp status (trigger only) |
| 0x91 | 9 bytes | CCD configuration |
| 0xA0 | 11 bytes | Exposure/focus params |
| 0xB0-0xB4 | 0-5 bytes | Motor control |
| 0xC0-0xC1 | 5-9 bytes | CCD readout config |
| 0xD0-0xD6 | 0-13 bytes | Status readback |

## Speed Ramp Tables

### Primary Ramp (0x16C38)

33 entries × 16-bit values, linear acceleration profile:
- Range: 56 to 312 (step 8)
- Timer compare values for stepper motor speed
- Higher value = slower step rate

### Variant Ramp Tables (0x0459D2+)

Multiple variant tables for different scan resolutions and adapter types. Each variant adjusts the ramp curve for the specific mechanical requirements.

## Stepper Phase Tables

| Address | Pattern | Direction |
|---------|---------|-----------|
| 0x16E92 | `01, 02, 04, 08` | Forward (unipolar 4-phase wave) |
| 0x4A8A8 | `08, 04, 02, 01` | Reverse |

## Numeric/Calibration Tables (0x4A200-0x4A800)

### Trigonometric Table (0x4A200-0x4A28F)
Sine/cosine values in packed 8-bit fixed-point format.

### Coefficient Tables (0x4A290-0x4A2D7)
- 0x4A290-0x4A2A5: Small coefficient array
- 0x4A2A6-0x4A2D7: Logarithmic bitmask lookup table

### BCD Encoding (0x4A394)
16-byte hex nibble encoding table for display output.

### Floating-Point Constants (0x4A430-0x4A51F)
IEEE 754 double-precision calibration factors:
- 100.0, 250.0, ~16383, 10.0, ~3276.8, ~3541
- Used in exposure/density calibration calculations

### CCD Channel Remap Table (0x4A520-0x4A55F)
6-entry repeating sequence `{04, 01, 02, 03, 05, 00}`, 8 repetitions = 48 entries.
Maps CCD physical channels to logical color channels.

## CCD Defect Map (0x4A8BE-0x528BE)

32KB lookup table with 16-bit entries (16384 entries total):
- 34 unique values, dominated by 0x0000 (47%) and 0x0001 (16%)
- Values 0x0100-0x0700 encode pixel quality classes
- Likely a **per-pixel defect classification table** for CCD readout correction

## ASIC RAM Bank Descriptor Table (0x49A94)

Null-terminated list of 24-bit addresses marking valid DMA target ranges:

```
17 entries: 0x800000, 0x808000, 0x810000, ..., 0x836000
1 entry: 0x100000 (ISP1581 aliased address)
Terminator: 0x000000
```

17 × 8KB = 136KB of the 224KB ASIC RAM is mapped for DMA operations.

## Firmware String Table & Pointer Table (0x49E30-0x49EFB / 0x49EFC)

The firmware contains null-terminated ASCII strings at `0x49E30`-`0x49EFB` referenced by a pointer table at `0x49EFC`. These strings serve four purposes: adapter type identification, film holder identification, motor/object positioning references, and calibration parameter names. See [Film Adapters](film-adapters.md) for full analysis.

**String table** (null-terminated, at `0x49E30`):

| Address | String | Category |
|---------|--------|----------|
| `0x49E31` | `Nikon   LS-50 ED        1.02` | INQUIRY response template |
| `0x49E4D` | `Mount` | Adapter name |
| `0x49E53` | `Strip` | Adapter name |
| `0x49E59` | `240` | Adapter name |
| `0x49E5D` | `Feeder` | Adapter name |
| `0x49E64` | `6Strip` | Adapter name |
| `0x49E6B` | `36Strip` | Adapter name |
| `0x49E73` | `Test` | **Factory test jig adapter** |
| `0x49E78` | `FH-3` | Film holder (standard 35mm) |
| `0x49E7D` | `FH-G1` | Film holder (glass, for curled film) |
| `0x49E83` | `FH-A1` | Film holder (medical/special) |
| `0x49E89` | `SCAN Motor` | Motor subsystem name |
| `0x49E94` | `AF Motor` | Motor subsystem name |
| `0x49E9D` | `SA_OBJECT` | Strip adapter reference position |
| `0x49EA7` | `240_OBJECT` | APS/240 reference position |
| `0x49EB2` | `240_HEAD` | APS/240 head reference |
| `0x49EBB` | `FD_OBJECT` | Feeder reference position |
| `0x49EC5` | `6SA_OBJECT` | 6-strip reference position |
| `0x49ED0` | `36SA_OBJECT` | 36-strip reference position |
| `0x49EDC` | `DA_COARSE` | Calibration: coarse DAC adjustment |
| `0x49EE6` | `DA_FINE` | Calibration: fine DAC adjustment |
| `0x49EEE` | `EXP_TIME` | Calibration: exposure time |
| `0x49EF7` | `GAIN` | Calibration: analog gain |

**Pointer table** at `0x49EFC` (24 × 4-byte big-endian pointers):

| Index | Points To | Notes |
|-------|-----------|-------|
| 0-7 | Adapter names | GPIO Port 7 ID → adapter name mapping (includes duplicates) |
| 8-10 | FH-3, FH-G1, FH-A1 | Film holder type names |
| 11-12 | SCAN Motor, AF Motor | Motor subsystem names |
| 13-17 | *_OBJECT strings | Mechanical positioning reference points per adapter |
| 18 | NULL | Separator between positioning and calibration groups |
| 19-22 | DA_COARSE, DA_FINE, EXP_TIME, GAIN | Calibration parameter names |

The "Test" adapter (index 6 in the pointer table) is a **factory manufacturing test jig** with no VPD pages — see [Film Adapters](film-adapters.md) for details.

## MODE SENSE Default Data (0x168AF)

Page 0x03 (device-specific parameters):
- Base resolution: 1200 DPI
- Maximum: 4000 units X/Y

## Flash Layout

| Region | Address | Size | Content |
|--------|---------|------|---------|
| Vector table + boot | 0x0000-0x3FFF | 16KB | Boot code, vector table |
| Settings | 0x4000-0x5FFF | 8KB | Mostly erased (0xFF) |
| Shared module | 0x10000-0x17FFF | 32KB | ISP1581 USB, response manager |
| Erased | 0x18000-0x1FFFF | 32KB | Unused (0xFF) |
| Main firmware | 0x20000-0x52FFF | 204KB | Code + data tables |
| Erased | 0x53000-0x5FFFF | 52KB | Unused (0xFF) |
| Log area 1 | 0x60000-0x63FFF | 16KB | Usage logs (433 records) |
| Erased | 0x64000-0x6FFFF | 48KB | Unused (0xFF) |
| Log area 2 | 0x70000-0x7FFFF | 64KB | Usage logs (512+ records) |

### Flash Log Record Format

32 bytes per record. All records are type `0x01` (usage telemetry). Area 2 fills first (2048 records), then wraps to Area 1 (433 records). Total 2481 events captured on this unit.

| Offset | Size | Field | Example | Interpretation |
|--------|------|-------|---------|----------------|
| 0 | 1 | Header | `0xAA` | Fixed marker |
| 1 | 1 | Type | `0x01` | Usage telemetry (only type observed) |
| 2-3 | 2 | Sequence | `0x6001` | Global event counter (big-endian) |
| 4-5 | 2 | Slow counter | 251-257 | **Lamp degradation metric** (7 values over 2481 events) |
| 6-7 | 2 | Step counter | 0-65280 | **Motor position** (increments by 256, wraps) |
| 8-9 | 2 | Usage counter | 20474-21513 | **Cumulative scan time** (increases ~0.4/event) |
| 10-13 | 4 | Config | `0x00000007` | Hardware/firmware revision (always 7) |
| 14-17 | 4 | Lamp time | `0xXX00D903` | Upper byte = lamp hours (0x93-0xA6), `D903` = build ID |
| 18-29 | 12 | Reserved | `0x00...` | Almost always zero (10 records with data) |
| 30 | 1 | Padding | `0x00` | Zero padding |
| 31 | 1 | Footer | `0x55` | Fixed marker |

Sequence counter range: `0x5801`-`0x61B1` = **24,497 total events** (decimal). This scanner has logged approximately 24,500 usage events since manufacture.

Area transition: Area 2 (0x70000) holds records 0x5801-0x6000, Area 1 (0x60000) holds 0x6001-0x61B1. When Area 2 fills (2048 records), logging wraps to Area 1.

### Calibration Data (0x4C000-0x4EFFF)

Factory-programmed per-pixel binary map (0/1 values only). See [calibration.md](calibration.md).

## Cross-References

- [SCSI Handler](scsi-handler.md) — SCSI handler table usage
- [Calibration](calibration.md) — Calibration task codes and data
- [Motor Control](motor-control.md) — Speed ramp and phase tables
- [ASIC Registers](asic-registers.md) — Register map referenced by tables
- [Vendor C1](../../scsi-commands/vendor-c1.md) — Vendor register table usage
- [Film Adapters](film-adapters.md) — Adapter types, test jig, positioning objects, calibration params
