# Firmware Data Tables — Nikon LS-50

**Status**: Complete
**Last Updated**: 2026-03-06
**Phase**: 4 (Firmware)
**Confidence**: Verified (table addresses, entry counts, and entry formats fully decoded from binary and dispatch code)

## Overview

The LS-50 firmware contains multiple data-driven tables in flash that define the scanner's behavior. These tables are concentrated in the 0x45000-0x528BE region (data tables area) and the 0x16000-0x17000 region (shared module data).

## SCSI Handler Table (0x49834)

Primary SCSI command dispatch table. 21 entries × 10 bytes each (including D0, terminated by null at 0x49906).

Entry format: `opcode:8, pad:8, perm_flags:16, handler_ptr:32, exec_mode:8, pad:8`

| Opcode | Perm Flags | Handler | Exec | Command |
|--------|------------|---------|------|---------|
| 0x00 | 0x07D4 | 0x215C2 | 0x01 | TEST UNIT READY |
| 0x03 | 0x07FF | 0x21866 | 0x03 | REQUEST SENSE |
| 0x12 | 0x07FF | 0x25E18 | 0x03 | INQUIRY |
| 0x15 | 0x0014 | 0x2194A | 0x02 | MODE SELECT |
| 0x16 | 0x07CC | 0x21E3E | 0x01 | RESERVE |
| 0x17 | 0x07FC | 0x21EA0 | 0x01 | RELEASE |
| 0x1A | 0x07D4 | 0x21F1C | 0x03 | MODE SENSE |
| 0x1B | 0x0014 | 0x220B8 | 0x00 | SCAN |
| 0x1C | 0x0014 | 0x23856 | 0x03 | RECEIVE DIAGNOSTIC |
| 0x1D | 0x0016 | 0x23D32 | 0x02 | SEND DIAGNOSTIC |
| 0x24 | 0x0014 | 0x26E38 | 0x02 | SET WINDOW |
| 0x25 | 0x0254 | 0x272F6 | 0x03 | GET WINDOW |
| 0x28 | 0x0054 | 0x23F10 | 0x03 | READ |
| 0x2A | 0x0014 | 0x25506 | 0x02 | WRITE |
| 0x3B | 0x0014 | 0x2837C | 0x02 | WRITE BUFFER |
| 0x3C | 0x0014 | 0x28884 | 0x03 | READ BUFFER |
| 0xC0 | 0x0754 | 0x28AB4 | 0x01 | Vendor: Status Query |
| 0xC1 | 0x0014 | 0x28B08 | 0x01 | Vendor: Trigger Action |
| 0xD0 | 0x07FF | 0x13748 | 0x01 | Vendor: Phase Query |
| 0xE0 | 0x0014 | 0x28E16 | 0x02 | Vendor: Data Out |
| 0xE1 | 0x0014 | 0x295EA | 0x03 | Vendor: Data In |

## Internal Task Table (0x49910)

97 entries × 4 bytes each (task_code:16, handler_index:16). Organized by subsystem:

| Prefix | Count | Subsystem | Example Tasks |
|--------|-------|-----------|---------------|
| `0x01xx` | 3 | System init | Init sequence tasks |
| `0x02xx` | 1 | High-level | Single top-level task |
| `0x03xx` | 8 | Motor position | Relative/absolute move, home |
| `0x04xx` | 4 | Focus/lens | Focus motor tasks |
| `0x05xx` | 3 | Calibration | Primary/secondary cal, shared handler |
| `0x06xx` | 10 | CCD readout | 5 basic + 5 extended configs |
| `0x08xx` | **45** | **Scan workflow** | Preview, fine, multi-pass, per-resolution modes |
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

The 0x08xx scan group is the largest (45 tasks), covering all scan modes across resolutions, color modes, and adapter types. Tasks 0x0891-0x08B4 (handler indices 133-144) appear to be extended modes added in a later firmware revision.

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

23 entries × 2 bytes each (reg_id:8, max_len:8), terminated by 0xFF. Maps E0/C1/E1 register IDs to maximum data lengths:

| Reg ID | Max Length | Purpose |
|--------|-----------|---------|
| 0x40 | 11 bytes | Scan control parameters |
| 0x41 | 11 bytes | Scan control parameters |
| 0x42 | 11 bytes | Scan control parameters |
| 0x43 | 11 bytes | Scan control parameters |
| 0x44 | 5 bytes | Scan control parameters |
| 0x45 | 11 bytes | Scan control parameters |
| 0x46 | 11 bytes | Scan control parameters |
| 0x47 | 11 bytes | Scan control parameters |
| 0x80 | 0 bytes | Lamp/exposure control (trigger only) |
| 0x81 | 0 bytes | Lamp status (trigger only) |
| 0x91 | 5 bytes | CCD configuration |
| 0xA0 | 9 bytes | Exposure/focus params |
| 0xB0 | 0 bytes | Motor control (trigger only) |
| 0xB1 | 0 bytes | Motor control (trigger only) |
| 0xB3 | 13 bytes | Motor control (extended) |
| 0xB4 | 9 bytes | Motor control |
| 0xC0 | 5 bytes | CCD readout config |
| 0xC1 | 5 bytes | CCD readout config |
| 0xD0 | 0 bytes | Status readback (trigger only) |
| 0xD1 | 0 bytes | Status readback (trigger only) |
| 0xD2 | 5 bytes | Status readback |
| 0xD5 | 5 bytes | Status readback |
| 0xD6 | 5 bytes | Status readback |

Note: B2, D3, D4 register IDs are absent from the table (not contiguous ranges).

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

## CCD Characterization Map (0x4A8BC-0x528BD)

~32KB analog correction level table. Two sections of 16,385 bytes each, accessed via pointer table at `FW:0x4A37E`. Each section contains 4095 groups × 4 bytes (4 identical bytes per group = 4 CCD sub-elements). 11 distinct correction levels (0x00-0x0B), with monotonic edge-to-center decay consistent with vignetting/dark current compensation. See [Calibration](calibration.md) for full analysis.

## READ Data Type Code Table (0x49AD8)

15 entries × 12 bytes each, terminated by 0xFF at 0x49B8C. Used by the READ(10) handler dispatch at `FW:0x240E2` to validate DTC values, check qualifier categories, and route to sub-handlers.

### Entry Format (12 bytes)

```
Byte 0:    DTC value (SCSI CDB byte 2)
Byte 1:    Qualifier category (determines allowed CDB byte 5 values)
Bytes 2-3: Reserved (always 0x0000)
Bytes 4-5: Maximum transfer size (u16 big-endian; 0 = variable/handler-managed)
Bytes 6-9: Source RAM address (u32 big-endian; 0 = handler-specific source)
Byte 10:   Sub-handler dispatch index (0x00, 0x08, 0x0C, 0x10, 0x20)
Byte 11:   Padding (always 0x00)
```

### Qualifier Categories (Byte 1)

| Value | Allowed Qualifiers | Meaning |
|-------|-------------------|---------|
| `0x00` | (ignored) | No qualifier needed |
| `0x01` | Must match table | Single mode |
| `0x03` | 0, 1, 2, or 3 | Channel select: 0=all, 1=R, 2=G, 3=B |
| `0x10` | 0 or 1 | Two-mode select |
| `0x30` | 0, 1, or 3 | Three-mode select (R/G/B, skipping 2) |

### Complete Table

| DTC | Name | Qual | MaxSize | RAM Addr | SubIdx | Sub-handler |
|-----|------|------|---------|----------|--------|-------------|
| 0x00 | Image Data | 0x10 | variable | — | 0x00 | 0x2413A |
| 0x03 | Gamma/LUT | 0x01 | 32768 | — | 0x00 | 0x24156 |
| 0x81 | Film Frame Info | 0x01 | 8 | — | 0x0C | 0x243DA |
| 0x84 | Calibration Data | 0x01 | 6 | — | 0x10 | 0x24266 |
| 0x87 | Scan Parameters | 0x00 | 24 | 0x400D45 | 0x08 | 0x244D2 |
| 0x88 | Boundary/Per-Ch Cal | 0x03 | 644 | — | 0x20 | 0x2452C |
| 0x8E | Focus/Measurement | 0x10 | variable | — | 0x00 | 0x24CDE |
| 0x8F | Histogram/Profile | 0x30 | 324 | — | 0x00 | 0x248BC |
| 0x8A | Exposure/Gain | 0x03 | 14 | — | 0x20 | 0x24AF0 |
| 0x8C | Offset/Dark Current | 0x03 | 10 | — | 0x20 | 0x24BB4 |
| 0x8D | Extended Scan Line | 0x30 | variable | — | 0x00 | 0x24D60 |
| 0x90 | CCD Characterization | 0x03 | 54 | — | 0x00 | 0x24E84 |
| 0x92 | Motor/Positioning | 0x03 | 10 | — | 0x00 | 0x24F82 |
| 0x93 | Adapter/Film Type | 0x01 | 12 | — | 0x00 | 0x24FC4 |
| 0xE0 | Extended Config | 0x30 | 1030 | — | 0x00 | 0x25004 |

**Notable**: DTC 0x87 (Scan Parameters) is the only entry with a non-zero RAM address (0x400D45) — its handler simply copies 24 bytes from this RAM location to the USB response buffer. All other DTCs use handler-specific logic to compose the response.

Sub-handler indices group DTCs by response-building strategy: 0x20 = per-channel data (reads from `0x4010xx` calibration area), 0x10 = calibration readback, 0x0C = film frame info, 0x08 = RAM copy.

## WRITE Data Type Code Table (0x49B98)

7 entries × 10 bytes each, terminated by 0xFF at 0x49BDE. Used by the WRITE/SEND(10) handler dispatch at `FW:0x25622`.

### Entry Format (10 bytes)

```
Byte 0:    DTC value (SCSI CDB byte 2)
Byte 1:    Qualifier category (same encoding as READ table)
Bytes 2-3: Reserved (always 0x0000)
Bytes 4-5: Maximum transfer size (u16 big-endian; 0 = handler-managed)
Bytes 6-9: Extended parameters (usually 0x00000000)
```

### Complete Table

| DTC | Name | Qual | MaxSize | Sub-handler |
|-----|------|------|---------|-------------|
| 0x03 | Gamma/LUT | 0x01 | 32768 | 0x25650 |
| 0x84 | Calibration Upload | 0x01 | 0 (handled) | 0x25722 |
| 0x85 | Extended Cal (WRITE-only) | 0x01 | 0 (handled) | 0x25830 |
| 0x88 | Boundary/Per-Ch Cal | 0x03 | 644 | 0x258F0 |
| 0x8F | Histogram/Profile | 0x30 | 324 | 0x2591C |
| 0x92 | Motor Control | 0x03 | 4 | 0x25908 |
| 0xE0 | Extended Config | 0x30 | 1024 | 0x2591C |

**Notable**: DTC 0x8F and 0xE0 share the same sub-handler address (0x2591C), suggesting a common data upload path. DTCs 0x84 and 0x85 have max size 0 — their payload size is determined internally by the handler (6 bytes for 0x84, variable for 0x85).

See also: [READ](../../scsi-commands/read.md), [WRITE](../../scsi-commands/write.md), `scripts/python/parse_dtc_tables.py`.

## ASIC RAM Bank Descriptor Table (0x49A94)

List of 32-bit bank start addresses for DMA target validation. Entry 0 is a null sentinel, followed by 16 real ASIC RAM banks, then the terminator.

```
Entry 0:  0x000000 (null sentinel)
Entries 1-4:  0x800000, 0x808000, 0x810000, 0x818000  (32KB spacing)
Entries 5-16: 0x820000, 0x822000, 0x824000, ..., 0x836000  (8KB spacing)
Terminator:   0x000000
```

16 banks covering 0x800000-0x837FFF = 224KB of the 256KB physical ASIC RAM. Banks 1-4 use 32KB spacing (lower region, likely for large DMA bursts), banks 5-16 use 8KB spacing (upper region, finer granularity for per-channel/per-line buffers).

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

### CCD Characterization Data (0x4A8BC-0x528BD)

Factory-programmed per-CCD-element analog correction levels (0x00-0x0B). See [calibration.md](calibration.md) for full structure analysis.

## Cross-References

- [SCSI Handler](scsi-handler.md) — SCSI handler table usage
- [Calibration](calibration.md) — Calibration task codes and data
- [Motor Control](motor-control.md) — Speed ramp and phase tables
- [ASIC Registers](asic-registers.md) — Register map referenced by tables
- [Vendor C1](../../scsi-commands/vendor-c1.md) — Vendor register table usage
- [Film Adapters](film-adapters.md) — Adapter types, test jig, positioning objects, calibration params
