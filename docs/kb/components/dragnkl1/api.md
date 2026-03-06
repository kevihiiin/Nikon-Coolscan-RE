# DRAG DLL API Reference (DRAGNKL1.dll / DRAGNKX2.dll)

**Status**: Complete
**Last Updated**: 2026-03-05
**Phase**: 6 (DRAG/ICE)
**Confidence**: High (export analysis, string extraction, PE version info)

## Overview

DRAG = **D**igital **R**OC **A**nd **G**EM -- two image processing technologies from Applied Science Fiction, Inc. (later acquired by Kodak):

- **Digital ROC** (Restoration of Color): Corrects color fading in old slides and negatives
- **Digital GEM** (Grain Equalization and Management): Reduces film grain while preserving detail

Both DLLs provide the same core API but with different feature sets and vintages.

## DLL Variants

| Property | DRAGNKL1.dll | DRAGNKX2.dll |
|----------|-------------|-------------|
| **Size** | 484KB | 176KB |
| **Exports** | 48 | 44 |
| **Version** | 2.0.0.14 | 1.0.0.0 |
| **Build Date** | 2003-07-14 | 2000-10-05 |
| **Copyright** | 1996-2003 | 1996-2000 |
| **Source Tree** | `C:\StarTeam\DFP\Software\vectorlibs\` | (no paths embedded) |
| **Used By** | NikonScan4.ds (static import) | Not referenced by any NikonScan binary |
| **Unique Features** | Scanner Revelation Mask, REV adjustments, edge fixup, gray level adjustment | FFT Intel variant |

**NikonScan 4.03 uses DRAGNKL1.dll exclusively.** DRAGNKX2.dll is shipped but appears unused -- likely kept for backward compatibility or alternate scanner models. Both DLLs are in `Twain_Source/`.

## Lifecycle API

All DRAG functions use a C calling convention with an opaque context handle. The lifecycle follows a strict sequence:

```
DRAGNew(version) ─► DRAGLoad(ctx, ...) ─► DRAGInit(ctx, ...) ─► DRAGBegin(ctx)
    │                                                                │
    │                                            DRAGSetStatisticsImageInfo(ctx, ...)
    │                                                                │
    │                                            ┌──── DRAGProcess(ctx) ◄──── (loop per row)
    │                                            │          │
    │                                            │  DRAGSetAvailableInputRow(ctx, row)
    │                                            │  DRAGGetCurrentInputRow(ctx)
    │                                            │  DRAGGetCurrentOutputRow(ctx)
    │                                            │          │
    │                                            └──────────┘
    │                                                  │
    │                                            DRAGEnd(ctx)
    │                                                  │
    │                                            DRAGComplete(ctx) ─► returns status
    │                                                  │
    └── DRAGDelete(ctx)                          DRAGUnload(ctx)
```

### Core Lifecycle Functions

| # | Export | Both DLLs | Description |
|---|--------|-----------|-------------|
| 20 | `DRAGVersion()` | Yes | Returns version string |
| 13 | `DRAGNew()` | Yes | Allocate new DRAG context |
| 12 | `DRAGLoad(ctx, ...)` | Yes | Load algorithm parameters |
| 11 | `DRAGInit(ctx, ...)` | Yes | Initialize for processing |
| 3 | `DRAGBegin(ctx)` | Yes | Begin processing session |
| 14 | `DRAGProcess(ctx)` | Yes | Process one unit of data |
| 7 | `DRAGEnd(ctx)` | Yes | End processing session |
| 4 | `DRAGComplete(ctx)` | Yes | Query completion/results |
| 6 | `DRAGDelete(ctx)` | Yes | Free DRAG context |
| 2 | `DRAGAbort(ctx)` | Yes | Cancel in-progress operation |
| 18 | `DRAGUnload(ctx)` | Yes | Unload algorithm data |

### Row-Based I/O Functions

| # | Export | Both DLLs | Description |
|---|--------|-----------|-------------|
| 15 | `DRAGSetAvailableInputRow(ctx, row)` | Yes | Signal that input row is ready |
| 8 | `DRAGGetCurrentInputRow(ctx)` | Yes | Get current input row being consumed |
| 9 | `DRAGGetCurrentOutputRow(ctx)` | Yes | Get current output row produced |
| 10 | `DRAGGetDuration(ctx)` | Yes | Get processing duration |

### Configuration Functions

| # | Export | Both DLLs | Description |
|---|--------|-----------|-------------|
| 17 | `DRAGSetStatisticsImageInfo(ctx, ...)` | Yes | Set image statistics for normalization |
| 19 | `DRAGUseDefaultParameters(ctx)` | Yes | Reset to default parameters |
| 16 | `DRAGSetFloatParameter(ctx, id, val)` | Yes | Set a float tuning parameter |
| 46 | `SetROCAdjustment(ctx, ...)` | Yes | Adjust ROC color restoration strength |
| 39 | `SetGrainResidue(ctx, ...)` | Yes | Set grain residue threshold |

### Normalization Statistics Functions

| # | Export | Both DLLs | Description |
|---|--------|-----------|-------------|
| 1 | `ClearNormalizeStatistics(ctx)` | Yes | Clear accumulated statistics |
| 31 | `GetNormalizeStatistics(ctx, ...)` | Yes | Get current normalization stats |
| 41 | `SetNormalizeStatistics(ctx, ...)` | Yes | Set normalization statistics |
| 48 | `SizeofNormalizeStatistics(ctx)` | Yes | Get statistics buffer size |

### Internal/Advanced Functions

| # | Export | Both DLLs | Description |
|---|--------|-----------|-------------|
| 5 | `DRAGCore(ctx, ...)` | Yes | Direct access to core algorithm |
| 30 | `GetDRAGProcessInstructions(ctx)` | Yes | Get processing instruction set |
| 34 | `InitDRAGCore(ctx, ...)` | Yes | Initialize core engine |
| 35 | `InitDRAGImageNormalize(ctx, ...)` | Yes | Initialize normalization stage |
| 36 | `InitDRAGImageProcess(ctx, ...)` | Yes | Initialize processing stage |
| 37 | `InitDRAGPhase(ctx, ...)` | Yes | Initialize specific phase |
| 38 | `InitDRAGRow(ctx, ...)` | Yes | Initialize row processing |
| 33 | `InitDRAGBlock(ctx, ...)` | Yes | Initialize block processing |
| 29 | `FreeDRAGCore(ctx)` | Yes | Free core engine resources |

### FFT Functions (Exported for External Use)

| # | Export | Both DLLs | Description |
|---|--------|-----------|-------------|
| 21 | `Exported_ArrangeForDRAG(...)` | Yes | Rearrange data for DRAG processing |
| 22 | `Exported_ArrangeForFFT(...)` | Yes | Rearrange data for FFT |
| 23 | `Exported_Complex_2D_FLPT_FFT(...)` | Yes | 2D floating-point FFT |
| 24 | `Exported_Complex_2D_FLPT_FFT_New(...)` | L1 only | Newer FFT variant |
| 25 | `Exported_Complex_2D_FLPT_IFFT(...)` | Yes | 2D floating-point inverse FFT |
| - | `Exported_Complex_2D_FLPT_FFT_Intel(...)` | X2 only | Intel-optimized FFT |

### L1-Only Exports

| # | Export | Description |
|---|--------|-------------|
| 26 | `FixupEdgeBuffers(...)` | Fix edge artifacts in output |
| 27 | `FixupEdgeBuffers_int(...)` | Integer variant of edge fixup |
| 28 | `FixupTopAndLeftEdges(...)` | Fix top/left edge artifacts |
| 32 | `GetVerbosity()` | Get logging verbosity level |
| 47 | `SetVerbosity(level)` | Set logging verbosity |
| 40 | `SetGrayLevelAdjustment(...)` | Adjust gray level mapping |
| 42 | `SetREVPreview(...)` | Set Revelation preview mode |
| 43 | `SetREV_DH_Adjustment(...)` | Revelation dark-highlight adjustment |
| 44 | `SetREV_GT_Adjustment(...)` | Revelation gray-tone adjustment |
| 45 | `SetREV_SB_Adjustment(...)` | Revelation shadow-brightness adjustment |

REV (Revelation) functions are related to "Scanner Revelation Mask and LUT" -- a scanner-specific defect/anomaly detection mask that guides the ROC/GEM processing. The mask identifies systematic scanner artifacts (consistent CCD defects, optical anomalies) that DRAG should correct — scanner-specific knowledge beyond what a single image can provide. NikonScan4.ds wraps this in the `CNkRevelation` RTTI class (at `NikonScan4.ds:0x10162xxx`).

## NikonScan4.ds Integration

NikonScan4.ds statically imports DRAGNKL1.dll functions and wraps them in an object-oriented command queue system:

| RTTI Class | Purpose |
|------------|---------|
| `CDRAGBase` | Base class for DRAG operations, holds DRAG context handle |
| `CDRAGProcess` | Main processing coordinator |
| `CDRAGPrepareCommand` | Command to prepare DRAG (DRAGNew → DRAGLoad → DRAGInit) |
| `CDRAGProcessCommand` | Command to execute DRAG (DRAGBegin → DRAGProcess loop → DRAGEnd) |
| `CDRAGProcessCommandQueue` | Command queue managing DRAG pipeline steps |
| `CQueueAcquireDRAGImage` | Queue for acquiring DRAG-processed images (coordinates scan+DRAG) |
| `CREVProcess` | Revelation mask processing |
| `CRevProcessCommand` | Command for Revelation processing |

Import thunks at `NikonScan4.ds:0x1011DA26-0x1011DA68` (11 functions, 6-byte jmp thunks).

## Data Format

DRAG processes row-based image data:
- **Input**: Interleaved or planar RGB pixel data (8-bit or 16-bit per channel)
- **Output**: Processed RGB data with same dimensions
- **Processing**: Streaming row-by-row with lookahead/lookbehind for spatial analysis

The tVec vector library (embedded in DLL) handles conversions:
- UC = unsigned char (8-bit), US = unsigned short (16-bit), NF = normalized float
- RGB interleave/deinterleave, bit shifting, precision conversion

Source: `C:\StarTeam\DFP\Software\vectorlibs\SRC\tVec\tVecLib\` path strings in DRAGNKL1.dll

## Related Docs

- [DRAG Processing Pipeline](pipeline.md) -- step-by-step algorithm phases
- [ICE Overview](../ice/overview.md) -- Digital ICE (runs before DRAG)
- [Scan Workflows](../nikonscan4-ds/scan-workflows.md) -- how DRAG fits in the scan workflow
