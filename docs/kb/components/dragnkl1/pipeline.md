# DRAG Image Processing Pipeline

**Status**: Complete
**Last Updated**: 2026-03-05
**Phase**: 6 (DRAG/ICE)
**Confidence**: High (string analysis from DLL, export tracing, class hierarchy)

## Overview

The DRAG pipeline performs two main operations on scanned image data:
1. **Digital ROC** -- Restores faded colors in old photographs
2. **Digital GEM** -- Reduces visible film grain while preserving image detail

DRAG runs entirely on the host CPU (not in scanner firmware). It operates as a post-processing step after image data has been transferred from the scanner and (optionally) after ICE defect correction.

## Pipeline Position in Scan Workflow

```
Scanner CCD
    │
    ▼
Raw RGBI data (4 channels: Red, Green, Blue, Infrared)
    │
    ▼
LS5000.md3: ICE Processing (infrared-based defect correction)
    │  Uses DICE API to remove dust/scratches using IR channel
    │  Output: cleaned RGB data (3 channels)
    │
    ▼
NikonScan4.ds: DRAG Processing (ROC + GEM)
    │  Color restoration + grain reduction
    │  Output: enhanced RGB data
    │
    ▼
NikonScan4.ds: Strato Pipeline (standard image filters)
    │  Color space conversion, LUT application, scaling,
    │  unsharp mask, CMS/ICC profiles, cropping
    │  (StdFilters2.dll + Strato3.dll)
    │
    ▼
Final output image (TIFF/JPEG via TWAIN)
```

## DRAG Processing Phases

Extracted from DRAGNKL1.dll embedded phase description strings. The algorithm executes these phases in sequence:

### Phase 1: Image Acquisition and Normalization
```
"Acquire RED channel"
"Acquire GREEN channel"
"Acquire BLUE channel"
```
Receives per-channel image data from the scan. Data is normalized using statistics gathered from the pre-scan or a statistics-gathering pass.

### Phase 2: Downsized Analysis Image
```
"Create normalized, downsized, median filtered image"
```
Creates a smaller version of the image with median filtering for analysis. This removes fine detail/noise to analyze overall color and density characteristics.

### Phase 3: Grain Analysis
```
"Measure Grain Strength vs Density"
"Measure 3x3 Freq vs. Mag"
"Measure 3x3 Freq vs. Mag weighted by Grain Strength"
"Track Max 3x3 Freq vs. Mag"
"Track Max 3x3 Freq vs. Mag weighted by Grain Strength"
```
Uses 2D FFT (via `Exported_Complex_2D_FLPT_FFT`) to analyze the spatial frequency content of the image. Maps grain strength against image density to build a grain model. The 3x3 frequency-magnitude relationship characterizes the grain pattern.

### Phase 4: Defect Mask (L1 Only)
```
"Create downsized sandblasted mask"
```
Creates a "sandblasted" mask -- a spatially-varying map of areas with defects or anomalies. Only in DRAGNKL1.dll (the L1 variant).

### Phase 5: Scanner Revelation Mask (L1 Only)
```
"Apply Scanner Revelation Mask and LUT"
"Apply DSC/UNK Revelation Mask and LUT"
```
Applies scanner-specific knowledge about known defect patterns. The "Scanner Revelation Mask" is data from the scanner (possibly calibration-related) that identifies systematic artifacts. DSC = Digital Scanner Correction. Controlled by `SetREV_*` functions.

### Phase 6: Fade/Color Analysis
```
"Determine Fade Correction Color Leakage values"
```
Analyzes color channel cross-talk caused by dye fading. Faded slides lose dye density unevenly across color layers, causing color shifts. This phase quantifies the leakage between channels.

### Phase 7: ROC Color Restoration
```
"Apply ROC then Build and Apply Localcolor and Hist leveling LUTs"
```
Applies the Digital ROC algorithm:
1. Corrects overall color fade based on the measured color leakage
2. Builds spatially-varying (local) color correction LUTs
3. Applies histogram leveling to restore dynamic range
Strength controlled by `SetROCAdjustment()`.

### Phase 8: Combined Processing
```
"Apply grain reduction, ROC, Local Color"
"Apply Localcolor and Hist leveling LUTs"
```
Applies grain reduction simultaneously with ROC correction. The combined application avoids amplifying grain when restoring colors.

### Phase 9: Grain-Only Output
```
"Apply grain reduction only. Unnormalize the result."
```
For GEM-only mode (no ROC), applies grain reduction and reverses the normalization to produce output pixel values. Controlled by `SetGrainResidue()`.

### Phase 10: Final Corrections
```
"Apply various corrections"
```
Final cleanup pass.

## Key Algorithm Concepts

### Normalization Statistics
Before processing, image statistics are gathered (mean, variance per channel per density zone). These statistics drive the grain model and ROC correction. Functions:
- `DRAGSetStatisticsImageInfo()` -- provide image metadata
- `GetNormalizeStatistics()` / `SetNormalizeStatistics()` -- get/set statistics
- `ClearNormalizeStatistics()` -- reset for new image
- `SizeofNormalizeStatistics()` -- statistics buffer size

### FFT-Based Grain Analysis
The grain model is built using 2D Fourier analysis:
- `Exported_Complex_2D_FLPT_FFT()` -- forward FFT on image blocks
- `Exported_ArrangeForFFT()` -- prepare data layout for FFT
- `Exported_Complex_2D_FLPT_IFFT()` -- inverse FFT for grain subtraction
- `Exported_ArrangeForDRAG()` -- rearrange FFT output for DRAG processing

### Scanner Revelation Mask (REV)
L1-specific feature. The scanner provides a "revelation" data set (possibly from calibration scans or known defect maps) that guides the processing:
- `SetREVPreview()` -- preview mode with faster, approximate processing
- `SetREV_DH_Adjustment()` -- dark/highlight correction strength
- `SetREV_GT_Adjustment()` -- gray tone correction
- `SetREV_SB_Adjustment()` -- shadow/brightness correction

### Vector Library (tVec)
DRAGNKL1.dll embeds the ASF "tVec" vectorized math library for high-performance pixel operations:

| Category | Functions |
|----------|-----------|
| **Conversion** | tVecUCtoNF, tVecUStoNF, tVecNFtoUC, tVecNFtoUS (8/16-bit ↔ normalized float) |
| **Interleave** | tVecInterleaveNRGBUC/US, tVecUCInterleaveRGB (planar ↔ interleaved) |
| **Convolution** | tVecConv3x3..19x19, tVecMed3x3/5x5, tVecMean5x5 (spatial filters) |
| **Mathematical** | tVecMaskedBlend, tVecThreshold, tVecReciprocal, tVec4thRoot/4thPower |
| **Bit Ops** | tVecBitShiftLeftUS, tVecBitShiftRightUS |

Source path: `C:\StarTeam\DFP\Software\vectorlibs\SRC\tVec\tVecLib\`

## NikonScan4.ds Command Queue Flow

```
CQueueAcquireDRAGImage (coordinates scan acquisition + DRAG)
    │
    ├─ CDRAGPrepareCommand
    │  └─ DRAGNew() → DRAGLoad() → DRAGInit() → DRAGSetStatisticsImageInfo()
    │
    ├─ CDRAGProcessCommand
    │  └─ DRAGBegin() → [DRAGProcess() loop with row I/O] → DRAGEnd()
    │
    ├─ CRevProcessCommand (optional, L1 only)
    │  └─ REV mask application using SetREV_* parameters
    │
    └─ DRAGComplete() → DRAGUnload() → DRAGDelete()
```

The `CProcessCommandManager` coordinates command execution with the MFC message pump (`FUN_100148b0`) to keep the UI responsive during processing.

## Strato Image Processing Framework

After DRAG, NikonScan4.ds applies standard image filters via Nikon's "Strato" framework:

**Strato3.dll** (132KB, 213 exports): Base framework interfaces
- `IStratoImage` -- image container
- `IStratoFilter` / `IStratoFilterChain` -- filter pipeline
- `IStratoManager` -- pipeline orchestrator
- `IStratoDataSource` / `IStratoDataDestination` -- I/O
- `IStratoTile` / `IStratoTileGrid` -- tiled processing

**StdFilters2.dll** (284KB, 557 exports): Standard filter implementations
- `CBGRizeFilter` -- convert to BGR pixel order
- `CCropFilter` -- crop to region of interest
- `CStratoFilterColorSpace` -- color space conversion
- `CStratoFilterCML` / `CStratoFilterCMLEngine` -- Color Management (CMS/ICC profiles)
- `CStratoFilterHistogram` -- histogram operations
- `CStratoFilterLut` -- LUT (look-up table) application
- `CStratoFilterScale` / `CFltScale` -- image scaling/resizing
- `CStratoFilterTransform` -- geometric transforms
- `CUnsharpMaskFilter` -- unsharp mask sharpening
- `CStratoFilterGrid` -- grid/tile management

**CML4.dll** (116KB, 16 exports): Nikon Color Management Library v4
- Used by StdFilters2.dll's `CStratoFilterCML` (NOT directly by NikonScan4.ds)
- API: `NKCMCreate` → `NKCMSetInputProfile` / `NKCMSetOutputProfile` → `NKCMSetIntent` → `NKCMProcessInterleavedData` → `NKCMDestroy`
- Supports input/output ICC profiles (by path or memory), LUT merging, 8/16-bit data, interleaved and planar processing
- Self-contained engine (no external CMS dependency -- KERNEL32 + C runtime only)
- NikonScan4.ds also imports `mscms.dll` but only for `GetColorDirectoryA` (ICC profile path lookup)

**NSSLang4.dll** (452KB, 8 exports): UI language resources
- Resource-only DLL providing localized strings, dialogs, bitmaps, menus
- API: `LoadExtString`, `LoadExtDialogTemplate`, `LoadExtBitmap`, `LoadExtMenu`, etc.
- NikonScan4.ds imports this statically for all UI text

## Supporting DLLs (Standalone App Only)

These DLLs are used by `Nikon Scan.exe` (the standalone scanning application) but NOT by the TWAIN data source (NikonScan4.ds). The TWAIN source delivers image data to the calling application via the TWAIN API -- file saving is the caller's responsibility.

**Asteroid5.dll** (784KB, 81 exports): "Nikon File Utility" -- image file I/O
- Classes: `CStratoLoad` (18 methods), `CStratoSave` (16), `CStratoFileStream` (12), `CStratoMemoryStream` (12), `CStratoTagControl` (14)
- Supports TIFF (uncompressed, JPEG, PackBits, ZIP), JPEG, BMP, PNG
- Uses Pegasus Imaging codecs (PICN20.dll) for JPEG compression/decompression
- Source path: `c:\dev_p4\releases\resco\resco\Release4_Win\shared\imgproc\Asteroid\`

**Pegasus Imaging** (PICN20.dll + picn1020.dll + picn1120.dll): Third-party image codecs
- PICN20.dll (41KB, 48 exports): Dispatcher/plugin manager (Pegasus Imaging Corp., 1995-2002)
- picn1020.dll (140KB, 1 export): OP_D2S -- image decompression (decode Source-to-Destination)
- picn1120.dll (148KB, 1 export): OP_S2D -- image compression (encode Source-to-Destination)

## Complete NikonScan DLL Dependency Map

```
NikonScan4.ds (TWAIN data source -- scan orchestration)
    ├── DRAGNKL1.dll .............. ROC/GEM image processing
    ├── Strato3.dll ............... Image processing framework
    ├── StdFilters2.dll ........... Standard image filters
    │   └── CML4.dll .............. ICC color management engine
    ├── NSSLang4.dll .............. UI language resources
    ├── mscms.dll (Windows) ....... ICC profile directory lookup
    └── MFC70.DLL ................. Microsoft Foundation Classes

Nikon Scan.exe (standalone application -- file I/O)
    ├── Asteroid5.dll ............. Image file load/save
    │   └── PICN20.dll ............ Pegasus codec dispatcher
    │       └── picn1020.dll ...... JPEG/TIFF decompression
    │       └── picn1120.dll ...... JPEG/TIFF compression
    ├── Strato3.dll ............... (shared framework)
    └── StdFilters2.dll ........... (shared filters)
```

## Related Docs

- [DRAG API Reference](api.md) -- function signatures and parameters
- [ICE Overview](../ice/overview.md) -- ICE defect correction (runs before DRAG)
- [Scan Workflows](../nikonscan4-ds/scan-workflows.md) -- full scan orchestration
