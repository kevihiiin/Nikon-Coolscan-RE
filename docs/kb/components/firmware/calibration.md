# Calibration Subsystem — Nikon LS-50

**Status**: Complete
**Last Updated**: 2026-02-28
**Phase**: 4 (Firmware)
**Confidence**: High (DAC modes and task codes confirmed from binary; calibration data structure inferred)

## Overview

The LS-50 calibration subsystem performs dark frame subtraction and white reference normalization to correct for CCD sensor non-uniformities. Calibration operates through three firmware task codes, four calibration routines, and factory-programmed per-pixel correction data stored in flash.

Key insight: **All pixel-level calibration correction (gamma, LUT, color balance) is performed host-side** by NikonScan software. The firmware only performs analog front-end calibration (gain/offset) and provides raw CCD data to the host.

## Task Codes

Three calibration task codes in the internal task table at `0x49910`:

| Task Code | Handler Index | Purpose |
|-----------|---------------|---------|
| `0x0500` | `0x0031` | Primary calibration |
| `0x0501` | `0x0032` | Secondary calibration |
| `0x0502` | `0x0030` | Shared handler (also used by FEED `0x0400` and POSITION `0x0300`) |

Handler `0x0030` is shared across calibration, feed, and positioning — these subsystems all reuse the scan-positioning infrastructure (motor + CCD).

## DAC Mode Register (0x2000C2)

The DAC mode register at `0x2000C2` is the **calibration mode gate**:

| Value | Mode | Context |
|-------|------|---------|
| `0x20` | Init/basic | Written during USB bus reset (`0x13AD9`) |
| `0x22` | Normal scan | Written during standard scan setup |
| `0xA2` | Calibration | Bit 7 set = calibration enable |

All four calibration routines set `0xA2` before reading CCD data:

| Address | Calibration Routine |
|---------|-------------------|
| `0x3D12D` | Calibration routine 1 |
| `0x3DE51` | Calibration routine 2 |
| `0x3EEF9` | Calibration routine 3 |
| `0x3F897` | Calibration routine 4 |

Each routine follows the same pattern:
1. Write `0xA2` to `0x2000C2` (enter calibration mode)
2. Read calibration parameters from RAM (`0x400F56`-`0x400F9D`)
3. Write to ASIC calibration registers (`0x2001CA`/`0x2001CB`, `0x20014E`/`0x200152`/`0x200153`)
4. Perform calibration scan (read CCD data via Buffer RAM at `0xC00000`)
5. Compute per-channel min/max from CCD data
6. Update calibration results in RAM (`0x400F0A`, `0x400F12`, `0x400F1A`)

## LS-50 vs LS-5000 Analog Front-End

The firmware supports both LS-50 and LS-5000 with different analog configurations. A model flag at RAM `0x404E96` distinguishes them:

| Parameter | LS-50 (`0x404E96` = 0) | LS-5000 (`0x404E96` != 0) |
|-----------|------------------------|--------------------------|
| Fine DAC (`0x2000C7`) | `0x08` | `0x00` |
| Coarse gain (`0x200142`) | `0x64` (100) | `0xB4` (180) |

The model-specific configuration function is at `FW:0x142AA`:
```
0x142AA: mov.b #0x02, r0l           ; ASIC command = configure
0x142B4: mov.b #0xA2, r0l → 0x2000C2  ; DAC calibration mode
0x142BA: mov.b @0x404E96, r0l       ; Read model type flag
0x142C0: bne   LS5000_path          ; Branch if LS-5000
; LS-50: fine DAC = 0x08, coarse = 100
; LS-5000: fine DAC = 0x00, coarse = 180
```

## CCD Characterization Data in Flash (0x4A8BC-0x528BD)

Factory-programmed per-CCD-element correction data occupies ~32KB of flash. This is an **analog correction level table** (NOT a binary defect map — the previous characterization was incorrect due to sampling only the quiet center region where values happen to be 0/1).

### Data Structure

```
Pointer table at FW:0x4A37E:
  [0] = 0x0004A8BC  → Section 1 (pointers 0 and 1 are identical)
  [1] = 0x0004A8BC  → Section 1
  [2] = 0x0004E8BD  → Section 2

Section 1 (0x4A8BC-0x4E8BC, 16,385 bytes):
  Bytes 0-1:      0x3FFF (length header = 16383)
  Bytes 2-16381:  4095 groups × 4 bytes (correction levels 0-6)
  Bytes 16382-84: 3 trailing zero bytes

Section 2 (0x4E8BD-0x528BD, 16,385 bytes):
  Bytes 0-1:      0x3FFF (length header = 16383)
  Bytes 2-16381:  4095 groups × 4 bytes (correction levels 0-11)
  Bytes 16382-84: 3 trailing zero bytes

End marker: 0xFF at 0x528BE (erased flash)
Total: 32,770 bytes (~32KB)
```

### Key Properties

- **11 distinct byte values** (0x00 through 0x0B), NOT binary 0/1
- **100% 4-byte grouping**: every group has 4 identical bytes (zero violations across 8190 groups). Each group maps to 4 CCD sub-elements (likely 4 sub-pixel positions per CCD element)
- **4095 groups per section** (2^12 − 1): matches the CCD's active element count
- **Monotonic edge-to-center decay**: correction levels decrease from edges (values 5-6) toward center (values 0-1), consistent with optical vignetting and CCD dark current falloff
- **Section 2 has higher values** than Section 1 (avg +1 across 1202 differing groups), suggesting different scan modes with different integration times
- **Localized hot pixel cluster** at Section 2 groups 144-159 (values 10-11, absent in Section 1) — a physical CCD defect requiring extra correction at one scan speed

### Firmware Access

The firmware reads this data via pointer table at `FW:0x4A37E`, using `mov.l @0x0004A37E:32, ER4` at code address `0x36E24`, followed by sequential byte reads with `mov.b @ER4+, R0L` (post-increment). The `0x3FFF` length constant is referenced at 7 firmware code locations.

### No Runtime Flash Writes to Calibration Area

**Zero direct code references** to any address in 0x4A8BC-0x528BD. The data is accessed only through the pointer table. It was written during factory flash programming and is never modified by the firmware at runtime.

The flash programming routine at `FW:0x3A300` supports multiple flash chip variants but is only used to write to the log areas (`0x60000`, `0x70000`).

## Flash Programming

The flash programming function at `FW:0x3A300` supports multiple flash chip types:

| Config Value (`0x4A3EC`) | Sector Size | Unlock Address |
|--------------------------|-------------|----------------|
| `0x200` | 512B | `0x1C7` |
| `0x400` | 1KB | `0x333` |
| `0x800` | 2KB | `0x555` |
| `0xFFF` | 4KB | `0x1FFF` (active on this board) |

The active chip (MBM29F400B) uses `0xFFF` → unlock address `0x1FFF` in 4KB sector mode (top-boot configuration).

## Calibration Scan Pipeline

During calibration, CCD data flows through Buffer RAM with **ping-pong buffering**:

```
CCD → ASIC (DAC mode = 0xA2) → ASIC RAM (0x800000)
    → DMA → Buffer RAM (0xC00000, bank A)
                        (0xC08000, bank B)
    → Firmware reads pixels → Computes min/max per channel
    → Updates calibration RAM variables
```

Buffer RAM references in calibration code:
- `0x3E265`: `mov.l #0xC00000, erN` (bank A)
- `0x3F631`: `mov.l #0xC00000, erN` (bank A)
- `0x3FFDF`: `mov.l #0xC00000, erN` (bank A)
- Secondary bank at `0xC08000` (32KB offset)

Processing limit: 16384 words (32KB), enough for 2 channels of 8192 pixels.

## Debug Labels

Calibration-related debug strings and their code references:

| Label | Flash Address | Pointer Table | Code Reference | Context |
|-------|--------------|---------------|----------------|---------|
| `DA_COARSE` | `0x49EDC` | `0x49F48` | `0x26201` | Coarse DAC display |
| `DA_FINE` | `0x49EE6` | `0x49F4C` | — | Fine DAC display |
| `EXP_TIME` | `0x49EEE` | `0x49F50` | `0x2621D` | Exposure time display |
| `GAIN` | `0x49EF7` | `0x49F54` | `0x2651B` | Gain calibration display |

The GAIN calibration is adapter-type-dependent:
```
0x26514: load GAIN string pointer indexed by adapter type
0x2651E: read adapter type from 0x400773
0x26524: compare with #0x02 (Strip holder)
0x2652A: read gain adjustment factor from 0x400790
0x26532: call gain calculation at 0x163EA
```

## ASIC Calibration Registers

| Register | Function | Written Values |
|----------|----------|---------------|
| `0x200001` | ASIC command | `0x02` (configure), `0x20` (start scan) |
| `0x2000C2` | DAC mode | `0x20` (init), `0x22` (scan), `0xA2` (calibration) |
| `0x2000C7` | DAC fine | `0x08` (LS-50), `0x00` (LS-5000) |
| `0x200142` | Ch1 coarse gain | `0x64` (LS-50), `0xB4` (LS-5000) |
| `0x20014E` | Multi-ch config | Variable from RAM |
| `0x200152` | Ch2 coarse gain | Variable from RAM |
| `0x200153` | Ch2 fine gain | Variable from RAM |
| `0x200456` | Gain mode | `0x00` (init only) |
| `0x200457` | Analog gain ch1 | `0x63` (99, init only) |
| `0x200458` | Analog gain ch2 | `0x63` (99, init only) |
| `0x2001CA` | Cal config 1 | Variable from RAM |
| `0x2001CB` | Cal config 2 | Variable from RAM |

Note: Registers `0x200457`/`0x200458` are set **only** during I/O init table processing — no runtime code writes to them. Dynamic gain adjustment during calibration uses the `0x200142`/`0x200152` path instead.

## Cross-References

- [ASIC Registers](asic-registers.md) — Full register map including calibration registers
- [Scan Data Pipeline](scan-pipeline.md) — How calibration fits into the scan data flow
- [SCSI SCAN Command](../../scsi-commands/scan.md) — Operation type 3 triggers calibration scan
- [Vendor C1](../../scsi-commands/vendor-c1.md) — Subcommand 0x80 controls lamp/exposure
- [Motor Control](motor-control.md) — Motor positioning during calibration
