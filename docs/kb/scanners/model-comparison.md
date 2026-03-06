# Nikon Coolscan Model Comparison

**Status**: Complete
**Last Updated**: 2026-03-05
**Phase**: 7 (Cross-Model)
**Confidence**: High (PE analysis, INF files, string extraction)

## Scanner Model Matrix

| Property | LS-40 | LS-50 | LS-4000 | LS-5000 | LS-8000 | LS-9000 |
|----------|-------|-------|---------|---------|---------|---------|
| **Marketing Name** | Coolscan IV ED | Coolscan V ED | Super Coolscan 4000 ED | Super Coolscan 5000 ED | Super Coolscan 8000 ED | Super Coolscan 9000 ED |
| **Interface** | USB | USB | FireWire (1394) | USB | FireWire (1394) | FireWire (1394) |
| **USB PID** | 0x4000 | 0x4001 | -- | 0x4002 | -- | -- |
| **Transport DLL** | NKDUSCAN.dll | NKDUSCAN.dll | NKDSBP2.dll | NKDUSCAN.dll | NKDSBP2.dll | NKDSBP2.dll |
| **Module** | LS4000.md3 | LS5000.md3 | LS4000.md3 | LS5000.md3 | LS8000.md3 | LS9000.md3 |
| **Module Size** | 824KB | 1028KB | 824KB | 1028KB | 936KB | 1112KB |
| **Module Version** | 1.3.0.3006 | 1.0.0.3014 | 1.3.0.3006 | 1.0.0.3014 | 1.3.0.3003 | 1.0.0.3009 |
| **MAID ID** | `MD3.01IILS4000` | `MD3.50IILS5000` | `MD3.01IILS4000` | `MD3.50IILS5000` | `MD3.01IILS8000` | `MD3.01IILS9000` |
| **Film Formats** | 35mm | 35mm | 35mm | 35mm | 35mm + 120/220 | 35mm + 120/220 |
| **Module Copyright** | 1995-2007 | 2003-2007 | 1995-2007 | 2003-2007 | 1995-2007 | 1995-2007 |

## Module Sharing

Each .md3 module serves two scanner models connected via different interfaces:

| Module | Scanner 1 (USB) | Scanner 2 (1394) |
|--------|----------------|-----------------|
| LS4000.md3 | LS-40 (USB PID 4000) | LS-4000 (FireWire) |
| LS5000.md3 | LS-50 (USB PID 4001) | LS-5000 (USB PID 4002) |
| LS8000.md3 | -- (no USB model) | LS-8000 (FireWire) |
| LS9000.md3 | -- (no USB model) | LS-9000 (FireWire) |

**Note**: LS-50 and LS-5000 are both USB-only (no FireWire variants). LS-8000 and LS-9000 are FireWire-only (no USB variants). Only the LS-40/LS-4000 pair truly straddles both transports (35mm only, budget tier).

## Module Architecture (Identical Across All 4)

All modules share the same architecture:

### Exports (3, identical names)
1. `MAIDEntryPoint` -- MAID interface entry
2. `NkCtrlEntry` (mangled: `?NkCtrlEntry@@YGFFFFPAX@Z`) -- Control entry
3. `NkMDCtrlEntry` -- Module-device control entry

### Imports (7 DLLs, identical set)
KERNEL32.dll (82-85 funcs), USER32.dll (12), GDI32.dll (1), ADVAPI32.dll (3), SHFOLDER.dll (1), SETUPAPI.dll (5), WINMM.dll (1)

### Transport Selection
All modules reference both transport DLLs as string constants:
- `Nkduscan.dll` (USB transport)
- `Nkdsbp2.dll` (1394/SBP-2 transport)

The module loads the appropriate transport DLL at runtime via `LoadLibraryA`, selecting based on scanner detection (USB vs 1394 enumeration via SETUPAPI).

### ICE Integration (Identical)
All modules have the same 18 DICE function name strings for dynamic resolution via `GetProcAddress`. ICE support is uniform across the product line.

### Film Holder Support
All modules reference:
- `FH-3` -- 35mm slide mount holder
- `FH-A1` -- 35mm strip film adapter (APS adapter variant)
- `FH-G1` -- glass film holder

LS8000/LS9000 additionally support:
- `35mm Mount Film`, `35mm Strip Film` -- 35mm sub-types
- `Brownie Mount Film`, `Brownie Strip Film`, `Brownie Strip Film with G` -- 120/220 medium format ("Brownie" = Kodak 120 film designation)

### RTTI Classes
All modules have minimal RTTI: only `exception` and `type_info` (C++ exception support). The modules are written in C-style C++ without virtual class hierarchies -- function pointer tables are used instead (vtable-like but manually managed).

## SCSI Protocol Differences

Based on binary analysis, all modules implement the same 17 SCSI opcodes (verified in Phase 2 for all modules). Model-specific behavior is encoded in:

1. **MAID capability IDs** -- Different cap IDs registered per model for model-specific parameters
2. **SET WINDOW descriptor** -- Different valid ranges for resolution, scan area, bit depth
3. **Vendor extension parameters** -- Dynamically registered from GET WINDOW response, vary per firmware
4. **INQUIRY response** -- Different model identification strings

The SCSI command set is protocol-compatible across all models. A driver that works with LS-50 will work with LS-9000 at the SCSI level; the differences are in parameter ranges and supported capabilities.

## Key Differences by Model

### LS-40 / LS-4000 (LS4000.md3, 824KB)
- Smallest module (oldest design, fewer features)
- MAID version: MD3.01 (v1 protocol)
- Copyright starts 1995 (longest lineage)
- 35mm only
- Budget tier: likely lower max resolution, no multi-sample

### LS-50 / LS-5000 (LS5000.md3, 1028KB)
- Second largest module
- MAID version: MD3.50 (v5 protocol -- newer, more features)
- Copyright starts 2003 (newest design)
- 35mm only
- Mid-range: higher resolution, multi-sample, all ICE/ROC/GEM features
- Our primary RE target (most completely documented)

### LS-8000 (LS8000.md3, 936KB)
- Medium-large module
- MAID version: MD3.01
- 35mm + 120/220 medium format (Brownie film types)
- Large format scan area support
- Likely uses ICENKNX2.dll (LSA/LSB variants designed for large scanners)

### LS-9000 (LS9000.md3, 1112KB)
- Largest module (most features)
- MAID version: MD3.01
- 35mm + 120/220 medium format
- Highest resolution of all models
- Most advanced features, largest code size

## Related Docs

- [USB Protocol](../architecture/usb-protocol.md) -- USB transport (NKDUSCAN.dll)
- [SBP2 Transport](../architecture/sbp2-transport.md) -- FireWire transport (NKDSBP2.dll)
- [LS5000.md3 MAID Entry Point](../components/ls5000-md3/maid-entrypoint.md) -- detailed module architecture
- [SCSI Command Catalog](../components/ls5000-md3/scsi-command-build.md) -- 17 SCSI opcodes (shared)
