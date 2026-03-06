# SET WINDOW Descriptor — Byte-Level Mapping

**Status**: Complete
**Last Updated**: 2026-02-27
**Phase**: 3 (Scan Workflows)
**Confidence**: High (decompiled from FUN_100b2b30, cross-referenced with SCSI-2 Scanner standard)

## Overview

The SET WINDOW command (opcode 0x24) configures the scanner's scan parameters. The data payload is a Window Descriptor that specifies resolution, scan area, bit depth, color mode, and vendor-specific features like ICE dust removal.

This document maps every byte in the Nikon Coolscan SET WINDOW descriptor, traced from the parameter builder function `FUN_100b2b30` (1268 bytes) at `LS5000.md3:0x100B2B30`.

## CDB Format (10 bytes)

```
Byte 0: 0x24 (SET WINDOW opcode)
Bytes 1-5: Reserved
Bytes 6-8: Transfer Length (big-endian, = descriptor length + 8)
Byte 9: Control (0x80 = vendor bit set)
```

Source: CDB builder at `LS5000.md3:0x100AA400` (via `FUN_100aa400`)

## Window Descriptor Layout

### Header (Bytes 0-7)

| Offset | Size | Field | Source |
|--------|------|-------|--------|
| 0-5 | 6 | Reserved (zeros) | — |
| 6-7 | 2 | Window Descriptor Length | `param_2 - 8` (big-endian) |

### Window Identifier (Byte 8)

| Offset | Size | Field | Source |
|--------|------|-------|--------|
| 8 | 1 | Window ID | `param_3` (factory argument, window identifier) |
| 9 | 1 | Reserved (zero) | — |

### Resolution (Bytes 10-13)

| Offset | Size | Field | MAID Param ID | NikonScan4 Cap | Source |
|--------|------|-------|---------------|----------------|--------|
| 10-11 | 2 | X Resolution (DPI) | 0x121 | Resolution setting | `FUN_100aee20(this, 0x121, ...)` big-endian 16-bit |
| 12-13 | 2 | Y Resolution (DPI) | 0x122 | Resolution setting | `FUN_100aee20(this, 0x122, ...)` big-endian 16-bit |

### Scan Area (Bytes 14-29)

All coordinates are in scanner units (typically 1/DPI inches), stored as big-endian 32-bit unsigned integers.

| Offset | Size | Field | Area Index | Source |
|--------|------|-------|------------|--------|
| 14-17 | 4 | Upper Left X | 1 | `FUN_100aeeb0(this, param, 1, &val)` → `FUN_100a09e0` |
| 18-21 | 4 | Upper Left Y | 0 | `FUN_100aeeb0(this, param, 0, &val)` → `FUN_100a0990` |
| 22-25 | 4 | Width | 3 | `FUN_100aeeb0(this, param, 3, &val)` → `FUN_100a0a80` |
| 26-29 | 4 | Height | 2 | `FUN_100aeeb0(this, param, 2, &val)` → `FUN_100a0a30` |

**Note**: All area getters look up MAID param 0x123 (the scan area object) in the parameter tree, then call different vtable methods for each dimension: [0x54]=Y-top, [0x58]=X-left, [0x5c]=height, [0x60]=width.

### Image Parameters (Bytes 30-35)

| Offset | Size | Field | MAID Param ID | SCSI Standard | Source |
|--------|------|-------|---------------|---------------|--------|
| 30 | 1 | Brightness | 0x100 | Yes (standard) | Single byte |
| 31 | 1 | Threshold | 0x124 | Yes (standard) | Single byte |
| 32 | 1 | Contrast | 0x101 | Yes (standard) | Single byte |
| 33 | 1 | Image Composition | 0x125 | Yes (standard) | Color mode: 0=line-art, 1=halftone, 2=grayscale, 5=color |
| 34 | 1 | Bits Per Pixel | 0x126 | Yes (standard) | 8=8-bit, 14=14-bit, 16=16-bit per channel |
| 35 | 1 | Halftone Pattern | 0x127 | Yes (standard) | Halftone dither pattern code |

### Reserved Gap (Bytes 36-47)

Bytes 36-47 are zeroed (part of the standard descriptor padding).

### Nikon Vendor Fields (Bytes 48-53)

These bytes extend beyond the standard SCSI-2 Scanner Window Descriptor.

| Offset | Size | Field | MAID Param IDs | Source |
|--------|------|-------|----------------|--------|
| 48 | 1 | Color/Composition Composite | 0x128 (high nibble), 0x127 (low nibble) | `(param_0x128 << 4) \| (param_0x127 & 0xF)` |
| 49 | 1 | Scan Flags (bitfield) | Multiple (see below) | OR'd bitfield |
| 50 | 1 | Multi-Sample Count | `param_4` (scan type) | Switch table (see below) |
| 51 | 1 | Compression Type | 0x12d | Single byte |
| 52 | 1 | Compression Argument | 0x12e | Single byte |
| 53 | 1 | Reserved | 0x12f | Single byte |

#### Byte 49 — Scan Flags Bitfield

| Bit | MAID Param ID | Meaning |
|-----|---------------|---------|
| 0 | 0x129 | Padding type |
| 1 | 0x131 | Bit ordering (0=MSB first, 1=LSB first) |
| 2-4 | — | Reserved (zeros) |
| 5 | 0x12a | RIF (Reverse Image Format) |
| 6 | 299 (0x12b) | Auto background detection |
| 7 | 300 (0x12c) | Reserved flag |

#### Byte 50 — Multi-Sample Count Encoding

The multi-sample count is derived from `param_4` (the scan type code stored at object+0x44c):

| param_4 | Multi-Sample Count | Description |
|---------|-------------------|-------------|
| 0x20 | 1 | Single sample (normal) |
| 0x21 | 2 | 2× multi-sample |
| 0x22 | 4 | 4× multi-sample |
| 0x23 | 16 | 16× multi-sample |
| 0x24 | 32 | 32× multi-sample (maximum noise reduction) |
| 0x25 | 64 | 64× multi-sample |
| 0x31 | 8 | 8× multi-sample |

### Vendor Extension Area (Bytes 54+)

Starting at byte 54 (offset 0x36), the descriptor contains a variable-length vendor extension section. The size is determined by `FUN_100a0360()` which computes the total from the registered extension parameter list.

#### Dynamic Extension Discovery

**Key architectural finding**: Vendor extension parameters are NOT hardcoded. The scanner self-describes its supported vendor extensions via the GET WINDOW response. During initialization (`FUN_100a2980`, 2589 bytes at `LS5000.md3:0x100A2980`), the host:

1. Sends GET WINDOW (0x25) to read the scanner's current window descriptor
2. Parses feature flags in the response (bit-packed bytes at specific offsets)
3. For each supported feature, registers a vendor extension param with `FUN_100a2820(scanner+0x27c, param_id, data_size_from_scanner)`
4. The data size (1, 2, or 4 bytes) for each param comes from the scanner, not from the host

#### Vendor Extension Parameter IDs

The following 12 vendor extension param IDs are registered conditionally based on scanner feature flags:

| Param ID | Group | Feature Flag | Likely Purpose | State Offset |
|----------|-------|-------------|----------------|-------------|
| 0x102 | 1 | flags_1 bit 2 | Analog gain/offset control | +0x114 |
| 0x103 | 1 | flags_1 bit 3 | Film type / negative positive | +0x116 |
| 0x104 | 1 | flags_1 bit 4 | Exposure time | +0x118 |
| 0x105 | 1 | flags_1 bit 5 | Color balance | +0x11a |
| 0x106 | 1 | flags_1 bit 6 | Sharpness / edge enhancement | +0x11c |
| 0x107 | 2 | flags_2 bit 0 | Scanner-specific feature A | +0x130 |
| 0x108 | 2 | flags_2 bit 1 | Scanner-specific feature B | +0x132 |
| 0x109 | 2 | flags_2 bit 2 | Scanner-specific feature C | +0x134 |
| 0x10a | 2 | flags_2 bit 3 | Scanner-specific feature D | +0x136 |
| 0x10b | 2 | flags_2 bit 4 | Scanner-specific feature E | +0x138 |
| 0x10c | 2 | flags_2 bit 5 | Scanner-specific feature F | +0x13a |
| 0x10d | 2 | flags_2 bit 6 | Special (triggers 0xf02/0xf03 alt read) | +0x13c |

**Note**: "Likely Purpose" labels are inferred from position and standard SCSI scanner conventions. Exact mapping requires firmware analysis (Phase 4) or USB capture data. The state offsets indicate where in the scanner state object each param's presence flag is stored.

Each registration calls `FUN_100a2820(this+0x27c, param_id, data_size)` and also `(vtable+0x24)(param_id, 0x7f, size, min, max, default, default)` to register min/max ranges.

Source: `LS5000.md3:0x100A2980` (init parser), `LS5000.md3:0x100A2820` (list add)

#### Vendor Extension Iteration (SET WINDOW Builder)

The SET WINDOW builder at `FUN_100b2b30` iterates all registered vendor extensions:

```c
for (i = 0; i < vendor_count; i++) {
    param_id = FUN_100a0370(scanner, i);    // Get param ID for extension i
    data_size = FUN_100a0bc0(scanner, i);    // Get byte count (1, 2, or 4)
    FUN_100aee20(this, param_id, ...);       // Read value by param ID

    // Special case: param 0x10d triggers reading 0xf02 or 0xf03
    if (param_id == 0x10d) {
        alt_id = (local_c != 0) ? 0xf03 : 0xf02;
        FUN_100aee20(this, alt_id, ...);
    }

    // Write value in big-endian format at current offset
    write_bytes(buf + 0x2e + offset, value, data_size);
}
```

#### ICE/DRAG Extension Area

If ICE/DRAG is supported (`FUN_1009d730()` returns true, checks scanner_state+0x84 == 1):

```
Byte at current offset: ICE/DRAG master enable (MAID param 0xa20)
Then for each ICE/DRAG parameter:
    data_size = FUN_1009fce0(scanner, index)    // 1, 2, or 4 bytes
    value = FUN_1009fc60(scanner, index, param)  // Read param value
    write_bytes(buf + 0x2e + offset, value, data_size)
```

## MAID Param ID Summary

All MAID internal parameter IDs used in SET WINDOW construction:

| Param ID | Descriptor Offset | Field Name | Data Size |
|----------|------------------|------------|-----------|
| 0x100 | 30 | Brightness | 1 byte |
| 0x101 | 32 | Contrast | 1 byte |
| 0x121 | 10-11 | X Resolution | 2 bytes |
| 0x122 | 12-13 | Y Resolution | 2 bytes |
| 0x123 | 14-29 | Scan Area (composite) | 4×4 bytes |
| 0x124 | 31 | Threshold | 1 byte |
| 0x125 | 33 | Image Composition | 1 byte |
| 0x126 | 34 | Bits Per Pixel | 1 byte |
| 0x127 | 35, 48 low | Halftone Pattern | 1 byte |
| 0x128 | 48 high | Color filter / mode | 1 byte |
| 0x129 | 49 bit 0 | Padding type | 1 bit |
| 0x12a | 49 bit 5 | RIF (Reverse Image) | 1 bit |
| 0x12b (299) | 49 bit 6 | Auto background | 1 bit |
| 0x12c (300) | 49 bit 7 | Reserved flag | 1 bit |
| 0x12d | 51 | Compression type | 1 byte |
| 0x12e | 52 | Compression argument | 1 byte |
| 0x12f | 53 | Reserved | 1 byte |
| 0x131 | 49 bit 1 | Bit ordering | 1 bit |
| 0x102 | vendor ext (54+) | Vendor feature (analog gain/offset?) | dynamic (1/2/4) |
| 0x103 | vendor ext | Vendor feature (film type?) | dynamic (1/2/4) |
| 0x104 | vendor ext | Vendor feature (exposure?) | dynamic (1/2/4) |
| 0x105 | vendor ext | Vendor feature (color balance?) | dynamic (1/2/4) |
| 0x106 | vendor ext | Vendor feature (sharpness?) | dynamic (1/2/4) |
| 0x107 | vendor ext | Vendor feature (scanner-specific) | dynamic (1/2/4) |
| 0x108 | vendor ext | Vendor feature (scanner-specific) | dynamic (1/2/4) |
| 0x109 | vendor ext | Vendor feature (scanner-specific) | dynamic (1/2/4) |
| 0x10a | vendor ext | Vendor feature (scanner-specific) | dynamic (1/2/4) |
| 0x10b | vendor ext | Vendor feature (scanner-specific) | dynamic (1/2/4) |
| 0x10c | vendor ext | Vendor feature (scanner-specific) | dynamic (1/2/4) |
| 0x10d | vendor ext | Special param (triggers 0xf02/0xf03) | dynamic (1/2/4) |
| 0xf02 | vendor ext | Alt value when 0x10d (condition false) | variable |
| 0xf03 | vendor ext | Alt value when 0x10d (condition true) | variable |
| 0xa20 | ICE/DRAG area | ICE/DRAG master enable | 1 byte |

## Parameter Reading Chain

```
FUN_100b2b30 (SET WINDOW builder)
  → FUN_100aee20(this, param_id, ...)
    → If [this+0x430] != NULL:
        FUN_100aad10([this+0x430], param_id, ...) — override path
          → tree lookup at [this+0x430]+4 by param_id
    → Else:
        FUN_100a05d0([this+0x42c], param_id, ...) — primary path
          → tree lookup at scanner_state+0x1c by param_id
          → finds parameter object, calls vtable method to get value
```

The parameter tree (`std::map<short, ParamObject*>`) at scanner_state+0x1c stores objects for each MAID param ID. These objects are populated when NikonScan4.ds sets capabilities via MAID opcode 6.

## Descriptor Size Calculation

```
base_size = 54 bytes (fixed standard + Nikon vendor)
vendor_ext_size = FUN_100a0360(scanner_state)  // sum of all vendor param sizes
ice_drag_size = FUN_1009fc20(scanner_state)    // sum of all ICE/DRAG param sizes (if present)
total = base_size + vendor_ext_size + ice_drag_size

// In FUN_100b3a50:
total = FUN_100a0360(scanner) + 0x36;  // 0x36 = 54
if (FUN_1009d730(scanner)) {           // ICE/DRAG present?
    total += FUN_1009fc20(scanner);    // add ICE/DRAG extension size
}
```

## Usage in Scan Workflows

SET WINDOW is called at these points:
- **Init Phase (Type A/Base Phase A)**: Not directly (init uses INQUIRY, RESERVE, etc.)
- **Main Scan Phase (Type A Phase B)**: Step code 0x24 → `FUN_100b3a50` prepares params → `FUN_100aa400` builds SCSI command
- **Simple Scan Phase A (Type B)**: Only SET WINDOW (step 0x24)
- **Simple Scan Phase B (Type B)**: SET WINDOW at step 0x24, plus GET WINDOW at step 0x25 for verification
- **Focus/Autofocus (Type C)**: No SET WINDOW (focus uses vendor commands E0/C1/E1)

Source: `LS5000.md3:0x100B2B30` (builder), `LS5000.md3:0x100B3A50` (prepare), `LS5000.md3:0x100AA400` (SCSI factory)

## Related KB Docs

- [SCSI Command Catalog](../components/ls5000-md3/scsi-command-build.md) — Full opcode reference
- [Scan Workflows](../components/nikonscan4-ds/scan-workflows.md) — When SET WINDOW is called
- [LS5000.md3 MAID Entry Point](../components/ls5000-md3/maid-entrypoint.md) — How params flow from NikonScan4.ds
