# Image Processing Pipeline -- Complete Post-Scan Processing Reference

**Status**: Complete
**Last Updated**: 2026-03-12
**Phase**: Deep Dive (builds on Phases 1-7)
**Confidence**: High (verified from PE exports, RTTI, import analysis, embedded strings)

## Purpose

This document consolidates the complete image processing pipeline used by NikonScan 4.03, from raw scanner CCD data through to final output. It covers ICE defect correction, DRAG color restoration and grain reduction, the Strato filter framework, StdFilters2 standard filters, CML4 color management, and all supporting DLLs. A driver developer can use this to understand what host-side processing NikonScan applies and decide what to replicate, replace, or skip.

---

## 1. Pipeline Overview

```
Scanner CCD (4-channel RGBI)
    │
    │  SCSI READ (0x28, DTC 0x00) -- raw image data transfer
    │
    ▼
┌────────────────────────────────────────────────────────────┐
│  STAGE 1: ICE (Digital ICE)                                │
│  DLL: ICEDLL.dll / ICENKNL1.dll / ICENKNX2.dll            │
│  Called by: LS5000.md3 (dynamic load via GetProcAddress)   │
│  Input: RGBI (4 channels)                                  │
│  Output: Cleaned RGB (3 channels)                          │
│  Purpose: Surface defect removal (dust, scratches)         │
│  Uses infrared channel as defect map                       │
└──────────────────────────┬─────────────────────────────────┘
                           │
                           ▼
┌────────────────────────────────────────────────────────────┐
│  STAGE 2: DRAG (Digital ROC and GEM)                       │
│  DLL: DRAGNKL1.dll (static import)                         │
│  Called by: NikonScan4.ds via CDRAGProcessCommand          │
│  Input: RGB (3 channels, 8 or 16 bit)                      │
│  Output: Enhanced RGB                                      │
│  Purpose: Color fade restoration (ROC) + grain reduction   │
│           (GEM)                                            │
└──────────────────────────┬─────────────────────────────────┘
                           │
                           ▼
┌────────────────────────────────────────────────────────────┐
│  STAGE 3: Strato Filter Pipeline                           │
│  Framework: Strato3.dll (213 exports)                      │
│  Filters: StdFilters2.dll (557 exports)                    │
│  CMS: CML4.dll (16 exports)                                │
│  Called by: NikonScan4.ds via IStratoManager                │
│  Input: Enhanced RGB from DRAG                             │
│  Output: Final image data                                  │
│  Purpose: Color management, scaling, sharpening, LUTs,     │
│           cropping, color space conversion                 │
└──────────────────────────┬─────────────────────────────────┘
                           │
                           ▼
                    TWAIN delivery to calling app
                    (or Asteroid5 file save in standalone mode)
```

### Key Architectural Points

1. **ICE runs in the MAID module** (LS5000.md3), not in NikonScan4.ds. This is because ICE needs access to the raw infrared channel data before it gets stripped.
2. **DRAG runs in the TWAIN source** (NikonScan4.ds). It receives cleaned RGB from the MAID module.
3. **Strato/StdFilters2 also run in the TWAIN source**. They apply all user-configured post-processing.
4. **All three stages are optional.** ICE requires the scanner hardware to support 4-channel RGBI. DRAG is enabled via MAID cap `0x801D`. Strato filters are configured per-scan.
5. **NikonScan4.ds statically imports** DRAGNKL1.dll, Strato3.dll, and StdFilters2.dll. ICE DLLs are dynamically loaded by LS5000.md3.

---

## 2. Stage 1: ICE (Digital ICE) -- Defect Correction

### Technology

Digital ICE (Image Correction and Enhancement) from Applied Science Fiction, Inc. uses infrared light to detect surface defects on film. Film emulsion is transparent to IR, but dust, scratches, and fingerprints scatter it. The scanner captures both visible (RGB) and infrared channels simultaneously, producing 4-channel RGBI data. The IR channel becomes a defect map guiding pixel reconstruction.

### DLL Selection

Three ICE DLLs ship with NikonScan 4.03. LS5000.md3 dynamically loads the appropriate one:

| DLL | Size | Version | Algorithm Variants | Target Scanners |
|-----|------|---------|-------------------|-----------------|
| **ICEDLL.dll** | 280KB | 3.0.0.4012 (Willow 2003) | L1B, X3A, X3B | LS-50, LS-5000 (primary) |
| **ICENKNL1.dll** | 344KB | 1.0.1.3001 (durer 2001) | L1 | LS-40 (budget) |
| **ICENKNX2.dll** | 432KB | 1.0.1.3001 (durer 2001) | LSA, LSB | LS-8000, LS-9000 (large format) |

All three export the identical 36-function **DICE API**. The variant letter codes indicate algorithm sophistication:

| Variant | SDC Algorithm | Quality/Speed Tradeoff |
|---------|--------------|----------------------|
| L1 / L1B | `CSDCCoreAlg36`/`CSDCCoreAlg37` (L1) or `CSDCCoreAlgL1B` | Basic, fast |
| X3A | `CSDCCoreAlgX3A` | Advanced, multi-pass |
| X3B | `CSDCCoreAlgX3B` | Highest quality, slowest |
| LSA / LSB | `CSDCCoreAlg20`-`CSDCCoreAlg33` | Large format optimized |

SDC = Surface Defect Correction (the underlying technology name).

### DICE API (36 Exports, Identical Across All 3 DLLs)

#### Lifecycle
```c
void*  DICENew(variant_params);           // Allocate context, select algorithm
int    DICELoad(ctx, params);             // Load algorithm parameters
int    DICEInit(ctx, params);             // Initialize for processing
int    DICEBegin(ctx);                    // Begin session
int    DICEProcess(ctx);                  // Process next chunk
int    DICEEnd(ctx);                      // End session
int    DICEComplete(ctx);                 // Query completion
void   DICEUnload(ctx);                  // Unload algorithm
void   DICEDelete(ctx);                  // Free context
void   DICEAbort(ctx);                   // Cancel
char*  DICEVersion();                     // Version string
```

#### Buffer Queue (Producer-Consumer Model)
```c
void   DICEQueueInputBuff(ctx, buf);      // Enqueue RGBI row for processing
void*  DICEDequeueInputBuff(ctx);         // Get back consumed input buffer
int    DICENeedInputBuff(ctx);            // Does engine need more input?
void   DICEQueueOutputBuff(ctx, buf);     // Provide output buffer space
void*  DICEDequeueOutputBuff(ctx);        // Get completed RGB output
int    DICENeedOutputBuff(ctx);           // Does engine need output space?
int    DICEHasOverflowOutputBuff(ctx);    // Check for overflow
void*  DICEMakeOverflowOutputBuff(ctx);   // Create overflow buffer
```

#### Parameters
```c
void   DICEUseDefaultParameters(ctx);
void   DICESetFloatParameter(ctx, id, val);
void   DICESetIntParameter(ctx, id, val);
void   DICESetPtrParameter(ctx, id, ptr);
float  DICEGetFloatParameter(ctx, id);
int    DICEGetIntParameter(ctx, id);
void*  DICEGetPtrParameter(ctx, id);
```

#### Progress/Status
```c
int    DICEGetCurrentInputRow(ctx);
int    DICEGetCurrentOutputRow(ctx);
float  DICEGetDefectPercent(ctx);          // % of image with defects found
int    DICEGetDuration(ctx);
```

#### Multi-Frame
```c
void   DICEClearAllFrameInfo(ctx);
int    DICEGetMaxFrameCount(ctx);
void   DICESetMaxFrameCount(ctx, n);
```

#### Memory
```c
void*  DICEMalloc(ctx, size);
void   DICEFree(ctx, ptr);
void*  DICERealloc(ctx, ptr, size);
```

### LS5000.md3 ICE Integration

LS5000.md3 uses 18 of the 36 DICE functions (resolved via `GetProcAddress`):
```
DICENew, DICELoad, DICEInit, DICEBegin, DICEProcess, DICEEnd,
DICEComplete, DICEUnload, DICEDelete, DICEAbort, DICEVersion,
DICEQueueInputBuff, DICEDequeueInputBuff, DICENeedInputBuff,
DICEQueueOutputBuff, DICEDequeueOutputBuff, DICENeedOutputBuff,
DICEGetDefectPercent
```

The processing flow within LS5000.md3:
1. Scan orchestrator sets MAID cap `0x800C = true` (ICE enabled)
2. LS5000.md3 configures scanner for 4-channel RGBI scan (SET WINDOW includes IR params)
3. Scanner performs scan with visible light + IR LED simultaneously
4. SCSI READ transfers RGBI data row by row
5. LS5000.md3 feeds data to DICE in a streaming loop:
   - `DICEQueueInputBuff(RGBI_row)` -> `DICEProcess()` -> `DICEDequeueOutputBuff()` = cleaned RGB row
   - Flow control via `DICENeedInputBuff()` / `DICENeedOutputBuff()`
6. Cleaned RGB passed up to NikonScan4.ds for DRAG/Strato processing

### MAID Capability Hierarchy for ICE

```
0x8103 (Image Object A)
  └── 0x8005 (Scan Parameters)
       └── 0x8007 (Multi-sample)
            └── 0x800C (ICE)           <-- boolean enable/disable
                 └── 0x800E (DRAG)     <-- DRAG depends on ICE being present
```

ICE is activated via MAID cap ID `0x800C`. When enabled, the scanner automatically includes the IR channel in scan data.

---

## 3. Stage 2: DRAG (Digital ROC and GEM) -- Color/Grain Processing

### Technology

DRAG = Digital ROC And GEM, from Applied Science Fiction (later Kodak):
- **Digital ROC** (Restoration of Color): Analyzes and corrects color fading in old slides and negatives. Uses per-channel color leakage analysis and spatially-varying correction.
- **Digital GEM** (Grain Equalization and Management): Reduces visible film grain using FFT-based frequency analysis while preserving image detail.

### DLL Details

| Property | DRAGNKL1.dll (Used) | DRAGNKX2.dll (Shipped but Unused) |
|----------|--------------------|------------------------------------|
| **Size** | 484KB | 176KB |
| **Exports** | 48 | 44 |
| **Version** | 2.0.0.14 (2003) | 1.0.0.0 (2000) |
| **Source** | `C:\StarTeam\DFP\Software\vectorlibs\` | (no paths) |
| **Unique** | REV mask, edge fixup, gray adjust | Intel FFT variant |

NikonScan4.ds statically imports DRAGNKL1.dll. Import thunks at `NikonScan4.ds:0x1011DA26-0x1011DA68`.

### DRAG API (48 Exports in DRAGNKL1.dll)

#### Core Lifecycle (11 functions, shared with DRAGNKX2)
```c
void*  DRAGNew(version);                  // Allocate context
int    DRAGLoad(ctx, params);             // Load parameters
int    DRAGInit(ctx, params);             // Initialize
int    DRAGBegin(ctx);                    // Begin session
int    DRAGProcess(ctx);                  // Process one unit
int    DRAGEnd(ctx);                      // End session
int    DRAGComplete(ctx);                 // Query completion
void   DRAGDelete(ctx);                  // Free context
void   DRAGAbort(ctx);                   // Cancel
void   DRAGUnload(ctx);                  // Unload
char*  DRAGVersion();                     // Version string
```

#### Row-Based I/O (4 functions)
```c
void   DRAGSetAvailableInputRow(ctx, row); // Signal input row ready
int    DRAGGetCurrentInputRow(ctx);        // Current input row
int    DRAGGetCurrentOutputRow(ctx);       // Current output row
int    DRAGGetDuration(ctx);               // Processing time
```

#### Configuration (5 functions)
```c
void   DRAGSetStatisticsImageInfo(ctx, ...);  // Image stats for normalization
void   DRAGUseDefaultParameters(ctx);
void   DRAGSetFloatParameter(ctx, id, val);
void   SetROCAdjustment(ctx, val);            // ROC strength (0-100%)
void   SetGrainResidue(ctx, val);             // GEM strength
```

#### Normalization Statistics (4 functions)
```c
void   ClearNormalizeStatistics(ctx);
void   GetNormalizeStatistics(ctx, buf);
void   SetNormalizeStatistics(ctx, buf);
int    SizeofNormalizeStatistics(ctx);
```

#### Internal/Advanced (9 functions)
```c
void   DRAGCore(ctx, ...);                    // Direct core access
void   GetDRAGProcessInstructions(ctx);
void   InitDRAGCore(ctx, ...);
void   InitDRAGImageNormalize(ctx, ...);
void   InitDRAGImageProcess(ctx, ...);
void   InitDRAGPhase(ctx, ...);
void   InitDRAGRow(ctx, ...);
void   InitDRAGBlock(ctx, ...);
void   FreeDRAGCore(ctx);
```

#### FFT Functions (5 functions, exported for external use)
```c
void   Exported_ArrangeForDRAG(...);
void   Exported_ArrangeForFFT(...);
void   Exported_Complex_2D_FLPT_FFT(...);      // Forward FFT
void   Exported_Complex_2D_FLPT_FFT_New(...);  // L1 only, newer variant
void   Exported_Complex_2D_FLPT_IFFT(...);     // Inverse FFT
```

#### L1-Only Exports (10 functions)
```c
void   FixupEdgeBuffers(...);             // Fix edge artifacts
void   FixupEdgeBuffers_int(...);         // Integer variant
void   FixupTopAndLeftEdges(...);         // Top/left edge fix
int    GetVerbosity();                    // Debug logging level
void   SetVerbosity(level);              // Set debug logging
void   SetGrayLevelAdjustment(...);      // Gray level mapping
void   SetREVPreview(...);               // Scanner Revelation preview mode
void   SetREV_DH_Adjustment(...);        // Revelation dark-highlight
void   SetREV_GT_Adjustment(...);        // Revelation gray-tone
void   SetREV_SB_Adjustment(...);        // Revelation shadow-brightness
```

### DRAG Algorithm Phases (from embedded strings)

DRAG processes data in 10 phases sequentially:

| Phase | Description | Key Operations |
|-------|-------------|----------------|
| 1 | Image Acquisition | Acquire R/G/B channels, normalize using pre-scan statistics |
| 2 | Downsized Analysis | Create normalized, downsized, median-filtered image for analysis |
| 3 | Grain Analysis | FFT-based grain strength vs density measurement; 3x3 frequency-magnitude tracking |
| 4 | Defect Mask (L1 only) | Create downsized "sandblasted" defect mask |
| 5 | Scanner Revelation (L1 only) | Apply scanner-specific defect knowledge (REV mask + LUT) |
| 6 | Fade Analysis | Determine color leakage values from dye fading |
| 7 | ROC Correction | Apply ROC, build spatially-varying local color + histogram LUTs |
| 8 | Combined Processing | Apply grain reduction + ROC + local color simultaneously |
| 9 | GEM-Only Output | For GEM-only mode: grain reduction + un-normalize |
| 10 | Final Corrections | Various cleanup corrections |

### Scanner Revelation Mask (REV)

The `CNkRevelation` RTTI class in NikonScan4.ds wraps DRAG's Scanner Revelation Mask feature. This provides scanner-specific knowledge about systematic artifacts (consistent CCD defects, optical anomalies) that DRAG uses to improve correction beyond what single-image analysis can achieve. The mask data comes from scanner calibration.

REV control functions:
- `SetREVPreview()` -- fast/approximate mode for previews
- `SetREV_DH_Adjustment()` -- dark-highlight correction strength
- `SetREV_GT_Adjustment()` -- gray tone correction
- `SetREV_SB_Adjustment()` -- shadow-brightness correction

### tVec Vector Library (Embedded in DRAGNKL1.dll)

DRAG embeds ASF's "tVec" vectorized math library for high-performance pixel operations:

| Category | Functions | Purpose |
|----------|-----------|---------|
| Conversion | `tVecUCtoNF`, `tVecUStoNF`, `tVecNFtoUC`, `tVecNFtoUS` | 8/16-bit to/from normalized float |
| Interleave | `tVecInterleaveNRGBUC/US`, `tVecUCInterleaveRGB` | Planar to/from interleaved |
| Convolution | `tVecConv3x3..19x19`, `tVecMed3x3/5x5`, `tVecMean5x5` | Spatial filters |
| Math | `tVecMaskedBlend`, `tVecThreshold`, `tVecReciprocal`, `tVec4thRoot/4thPower` | Pixel math |
| Bit Ops | `tVecBitShiftLeftUS`, `tVecBitShiftRightUS` | Bit manipulation |

### NikonScan4.ds DRAG Integration (Command Queue)

DRAG processing is coordinated through the command queue system:

```
CQueueAcquireDRAGImage (vtable 0x1013eab4)
    │
    ├── CDRAGPrepareCommand
    │   └── DRAGNew() → DRAGLoad() → DRAGInit() → DRAGSetStatisticsImageInfo()
    │
    ├── CDRAGProcessCommand
    │   └── DRAGBegin() → [DRAGProcess() loop with row I/O] → DRAGEnd()
    │
    ├── CRevProcessCommand (optional, L1 only)
    │   └── REV mask application using SetREV_* parameters
    │
    └── DRAGComplete() → DRAGUnload() → DRAGDelete()
```

The `CProcessCommandManager` coordinates execution with MFC's message pump (`FUN_100148b0`) to keep the UI responsive during the multi-second processing.

MAID cap `0x801D` controls DRAG enable. It is set to true when batch scan mode is active and DRAG buffers are valid.

---

## 4. Stage 3: Strato Filter Pipeline

### Framework Architecture (Strato3.dll)

**Strato3.dll** (132KB, 213 exports) is Nikon's proprietary image processing framework. It provides the abstract infrastructure -- interfaces, pipeline management, tile-based processing -- but no concrete filter implementations. Those live in StdFilters2.dll.

The framework uses a COM-like design with reference counting and interface queries. All interfaces follow the `IStrato*` naming convention.

#### Core Interfaces (from 213 exports)

| Interface | Methods | Purpose |
|-----------|---------|---------|
| `IStratoManager` | Create, AddFilter, Execute, GetResult | Pipeline orchestrator: builds filter chain, coordinates execution |
| `IStratoFilter` | Init, Process, GetOutput, Release | Single filter unit in the pipeline |
| `IStratoFilterChain` | AddFilter, RemoveFilter, GetCount | Ordered list of filters to execute sequentially |
| `IStratoImage` | GetWidth, GetHeight, GetBPP, GetData, Lock, Unlock | Image container with pixel data access |
| `IStratoDataSource` | Read, GetFormat, GetSize | Input data provider |
| `IStratoDataDestination` | Write, GetFormat, SetSize | Output data consumer |
| `IStratoTile` | GetRect, GetData, GetFormat | Tile (sub-region) for tiled processing |
| `IStratoTileGrid` | GetTileCount, GetTile, GetGridSize | Grid of tiles covering the full image |
| `IStratoHistogram` | GetBins, GetChannel, Compute | Histogram computation and storage |
| `IStratoState` | Get, Set, Reset | Filter state management |
| `IStratoProgress` | SetTotal, Increment, IsCancelled | Progress reporting and cancellation |
| `IStratoColorSpace` | GetType, Convert, GetChannelCount | Color space representation |
| `IStratoLUT` | GetSize, Apply, Compose | Look-up table operations |
| `IStratoProfile` | GetPath, Load, GetRenderingIntent | ICC profile wrapper |

#### Strato Processing Model

Strato uses tile-based processing for memory efficiency on large scanned images:

1. **IStratoManager** creates the filter chain from configured filters
2. Source image is divided into tiles via **IStratoTileGrid**
3. Each tile flows through the **IStratoFilterChain** in order
4. Filters process tiles independently (enables potential parallelism)
5. Output tiles are reassembled into the final **IStratoImage**

The pipeline is pull-based: the output destination requests tiles, which triggers upstream filter execution.

Source path (embedded): `c:\dev_p4\releases\resco\resco\Release4_Win\shared\imgproc\Strato\`

---

## 5. Standard Filters (StdFilters2.dll)

**StdFilters2.dll** (284KB, 557 exports) provides all concrete filter implementations used by the Strato pipeline. Each filter class inherits from `CStratoFilterBase` (192 methods) and implements `IStratoFilter`.

### Filter Class Inventory

| Filter Class | Export Count | Purpose |
|-------------|-------------|---------|
| **CStratoFilterBase** | 192 | Abstract base: lifecycle, state, properties, tile management |
| **CBGRizeFilter** | 6 | Convert pixel order to BGR (Windows bitmap format) |
| **CCropFilter** | 17 | Crop image to a rectangular region of interest |
| **CStratoFilterColorSpace** | ~10 | Convert between color spaces (RGB, CMYK, Gray, LCH) |
| **CStratoFilterCML** | ~15 | Color management wrapper (delegates to CML4.dll) |
| **CStratoFilterCMLEngine** | 31 | CML engine integration: profile loading, intent, processing |
| **CStratoFilterGrid** | 13 | Tile grid management for tiled processing |
| **CStratoFilterHistogram** | ~10 | Compute and apply histogram operations |
| **CStratoFilterLut** | ~10 | Apply look-up tables (curves, levels, gamma) |
| **CStratoFilterScale** / **CFltScale** | 47 | Image scaling/resizing (bicubic, bilinear, nearest) |
| **CStratoFilterTransform** | ~10 | Geometric transforms (rotation, flip) |
| **CUnsharpMaskFilter** | 28 | Unsharp mask sharpening |

### CStratoFilterBase (192 Methods)

The base class provides the framework contract that all filters implement. Key method categories:

**Lifecycle** (initialization, teardown):
- `BeginProcess`, `EndProcess`, `ExecuteProcess` -- processing session management
- `Process`, `ProcessTile` -- per-tile execution

**Data Flow**:
- `FilterData` -- process raw pixel data
- `FilterColorSpace` -- transform color space
- `FilterSize` -- resize data
- `FilterTransform` -- geometric transform
- `FilterPoint`, `FilterRect` -- coordinate mapping through filter chain
- `GenerateTile` -- produce output tile from input

**Properties**:
- Get/Set for width, height, BPP, color space, resolution
- Filter enable/disable, parameter configuration
- State serialization for save/load

### CBGRizeFilter (6 Methods)

Converts RGB pixel data to BGR byte order for Windows bitmap compatibility. This is typically the last filter in the chain before TWAIN delivery.

### CCropFilter (17 Methods)

Crops the image to the user-specified scan area. Methods include:
- Set/Get crop rectangle (in pixels or scanner coordinates)
- Coordinate validation against source image bounds
- Aspect ratio locking

### CStratoFilterScale / CFltScale (47 Methods)

Image resizing with multiple interpolation algorithms. The 47 methods cover:
- Resize to specific dimensions or DPI
- Bicubic, bilinear, nearest-neighbor interpolation
- Aspect ratio preservation options
- Sub-pixel coordinate mapping
- Tile-aware scaling (computes which input tiles are needed for each output tile)

### CStratoFilterCML / CStratoFilterCMLEngine (31 Methods)

The CML (Color Management Library) filter wraps CML4.dll to apply ICC color management within the Strato pipeline. Methods include:
- Input/output profile assignment (by file path or memory buffer)
- Rendering intent selection
- Proof mode configuration
- LUT merging (combine scanner calibration LUTs with color management)
- Bit depth negotiation (8-bit or 16-bit processing)
- Interleaved vs planar data mode

### CUnsharpMaskFilter (28 Methods)

Unsharp mask sharpening with configurable parameters:
- **Amount**: Sharpening strength (0-500%)
- **Radius**: Blur radius in pixels (determines detail scale)
- **Threshold**: Minimum contrast to sharpen (avoids noise amplification)
- Per-channel or luminance-only sharpening
- Tile-aware processing with overlap handling (avoids edge artifacts at tile boundaries)

### CStratoFilterHistogram

Computes image histograms for:
- Auto-levels adjustment
- Histogram equalization
- Clipping detection
- Per-channel or luminance histogram

### CStratoFilterLut

Applies look-up tables for:
- User curves adjustments (from CToolDlgCurves dialogs)
- Gamma correction
- Levels (black point, white point, midtone)
- Per-channel or combined LUT application

### CStratoFilterTransform

Geometric transforms:
- 90/180/270 degree rotation
- Horizontal/vertical flip
- Arbitrary rotation (if supported by scan settings)

---

## 6. CML4.dll -- Color Management Engine

**CML4.dll** (116KB, 16 exports) is Nikon's self-contained ICC color management engine. It converts image data between color spaces using ICC profiles, without depending on the Windows CMS (though NikonScan4.ds also imports `mscms.dll` for `GetColorDirectoryA` to find the ICC profile directory).

### API (16 Exports)

```c
// Lifecycle
void*  NKCMCreate();                                     // Create CMS context
void   NKCMDestroy(ctx);                                // Destroy context

// Profile Assignment
int    NKCMSetInputProfile(ctx, path);                  // Input ICC profile (file path)
int    NKCMSetInputProfileFromMemory(ctx, data, size);  // Input profile (memory buffer)
int    NKCMSetOutputProfile(ctx, path);                 // Output ICC profile (file path)
int    NKCMSetOutputProfileFromMemory(ctx, data, size); // Output profile (memory buffer)

// Configuration
void   NKCMSetInputBitSize(ctx, bits);                  // Input bit depth (8 or 16)
void   NKCMSetOutputBitSize(ctx, bits);                 // Output bit depth (8 or 16)
void   NKCMSetIntent(ctx, intent);                      // Rendering intent (perceptual, relative, saturation, absolute)
void   NKCMSetProofMode(ctx, mode);                     // Proof/softproof mode

// LUT Operations
void   NKCMSetInputLUT(ctx, lut);                       // Set input LUT (applied before CMS)
void   NKCMSetOutputLUT(ctx, lut);                      // Set output LUT (applied after CMS)
void   NKCMMergeInputLUT(ctx, lut);                     // Merge with existing input LUT
void   NKCMMergeOutputLUT(ctx, lut);                    // Merge with existing output LUT

// Processing
int    NKCMProcessInterleavedData(ctx, in, out, pixels); // Process interleaved RGB/CMYK data
int    NKCMProcessPlanarData(ctx, planes, out, pixels);  // Process planar channel data
```

### CML4 Usage Pattern

```c
void* cms = NKCMCreate();

// Set profiles
NKCMSetInputProfile(cms, "C:/Windows/System32/spool/drivers/color/scanner.icc");
NKCMSetOutputProfile(cms, "C:/Windows/System32/spool/drivers/color/sRGB.icc");

// Configure
NKCMSetInputBitSize(cms, 16);     // 16-bit input from scanner
NKCMSetOutputBitSize(cms, 8);     // 8-bit output for display
NKCMSetIntent(cms, 0);            // Perceptual rendering intent

// Optional: merge scanner calibration LUT
NKCMMergeInputLUT(cms, scanner_cal_lut);

// Process
NKCMProcessInterleavedData(cms, input_rgb, output_rgb, pixel_count);

NKCMDestroy(cms);
```

### CML4 Engine Variants in NikonScan4.ds

NikonScan4.ds creates four CML engine instances for different transform directions:

| Export | Ordinal | Abbreviation | Transform Path |
|--------|---------|-------------|----------------|
| `GetCMLEngineNN` | 12 | Normal-to-Normal | Working space -> Working space |
| `GetCMLEngineSN` | 14 | Scanner-to-Normal | Scanner profile -> Working space |
| `GetCMLEngineNS` | 13 | Normal-to-Scanner | Working space -> Scanner profile |
| `GetCMLEngineSS` | 15 | Scanner-to-Scanner | Scanner profile -> Scanner profile |

The `SN` (Scanner-to-Normal) engine is the primary one used during scanning -- it converts from the scanner's native color space to the user's selected working space (sRGB, Adobe RGB, etc.).

### Dependencies

CML4.dll imports only from KERNEL32.dll and the C runtime (MSVCRT). It is fully self-contained with no external CMS dependency. This means it embeds its own ICC profile parsing and color transform math.

---

## 7. NikonScan4.ds Filter Integration

### RTTI Classes for Image Processing

NikonScan4.ds contains these RTTI classes for Strato integration:

| Class | Purpose |
|-------|---------|
| `IStratoDataDestination` | Output interface for filter results |
| `IStratoDataSource` | Input interface providing scan data |
| `IStratoImage` | Image container used by filters |
| `CNkImageProcSet` | Image processing parameter set (groups all filter settings) |

### LUT Management Classes

| Class | Purpose |
|-------|---------|
| `CNkLutChannel` | Single channel LUT (R, G, B, or combined) |
| `CNkLutChannelBase` | Base class for LUT channels |
| `CNkLutEdit` | LUT editing operations (add point, delete, interpolate) |
| `CNkLutGroup` | Group of related LUTs (e.g., master + per-channel curves) |
| `CNkLutViewer` | LUT visualization (for curves dialog) |

LUTs are assembled from multiple sources:
1. User curves adjustments (`CToolDlgCurves*` dialogs)
2. Scanner gamma correction (from MAID param 0x03, SCSI READ DTC 0x03)
3. Auto-levels adjustments (from histogram analysis)
4. `AddCurvesToLutGroup` export (ordinal 3) combines them

### Pipeline Configuration

The Strato pipeline is configured per-scan based on user settings:

```
GetStratoManager() [export ordinal 37, at 0x10047D10]
    │
    ├── IStratoManager::AddFilter(CStratoFilterCMLEngine)  -- if CMS enabled
    │   └── Uses GetCMLEngineSN() for scanner->working space
    │
    ├── IStratoManager::AddFilter(CStratoFilterLut)        -- if curves/gamma set
    │   └── Uses CNkLutGroup from AddCurvesToLutGroup()
    │
    ├── IStratoManager::AddFilter(CUnsharpMaskFilter)      -- if USM enabled
    │   └── Parameters from CToolDlgUnsharpMask
    │
    ├── IStratoManager::AddFilter(CStratoFilterScale)      -- if output size != scan size
    │   └── Parameters from CToolDlgSize
    │
    ├── IStratoManager::AddFilter(CCropFilter)             -- if crop active
    │   └── Parameters from CToolDlgCrop
    │
    ├── IStratoManager::AddFilter(CStratoFilterColorSpace) -- if output != RGB
    │   └── Converts to CMYK/Gray/LCH if requested
    │
    └── IStratoManager::AddFilter(CBGRizeFilter)           -- Windows bitmap output
        └── RGB -> BGR byte reorder
```

Filters are only added when the corresponding feature is enabled. A minimal scan (no processing) would have only the BGRize filter.

---

## 8. Supporting DLLs

### NSSLang4.dll -- UI Language Resources

| Property | Value |
|----------|-------|
| **Size** | 452KB |
| **Exports** | 8 |
| **Purpose** | Localized UI strings, dialogs, bitmaps, menus |

API:
```c
HGLOBAL LoadExtString(id);
HGLOBAL LoadExtDialogTemplate(id);
HGLOBAL LoadExtBitmap(id);
HGLOBAL LoadExtMenu(id);
// + 4 more resource loading functions
```

NikonScan4.ds statically imports NSSLang4.dll for all UI text. This DLL is resource-only -- it contains no algorithmic code.

### Asteroid5.dll -- File I/O (Standalone App Only)

| Property | Value |
|----------|-------|
| **Size** | 784KB |
| **Exports** | 81 |
| **Purpose** | Image file load/save ("Nikon File Utility") |
| **Used by** | `Nikon Scan.exe` ONLY, NOT by NikonScan4.ds |

Key classes:
- `CStratoLoad` (18 methods) -- Load TIFF/JPEG/BMP/PNG files
- `CStratoSave` (16 methods) -- Save to same formats
- `CStratoFileStream` (12 methods) -- File I/O streaming
- `CStratoMemoryStream` (12 methods) -- Memory buffer streaming
- `CStratoTagControl` (14 methods) -- EXIF/TIFF tag management

Supports TIFF (uncompressed, JPEG, PackBits, ZIP), JPEG, BMP, PNG.
Uses Pegasus Imaging codecs (PICN20.dll) for JPEG compression.

Source path: `c:\dev_p4\releases\resco\resco\Release4_Win\shared\imgproc\Asteroid\`

**Important for driver developers**: The TWAIN data source (NikonScan4.ds) does NOT do file I/O. It delivers image data through the TWAIN API to the calling application. File saving is the caller's responsibility. A new driver does not need to replicate Asteroid5.

### Pegasus Imaging Codecs (Standalone App Only)

| DLL | Size | Exports | Purpose |
|-----|------|---------|---------|
| **PICN20.dll** | 41KB | 48 | Dispatcher/plugin manager (Pegasus Imaging Corp., 1995-2002) |
| **picn1020.dll** | 140KB | 1 | `OP_D2S` -- image decompression (Decode Source-to-Destination) |
| **picn1120.dll** | 148KB | 1 | `OP_S2D` -- image compression (encode Source-to-Destination) |

Used only by Asteroid5.dll for JPEG/TIFF compression. Not relevant to scanner communication.

---

## 9. Complete DLL Dependency Map

```
NikonScan4.ds (TWAIN data source -- scan orchestration + image processing)
    ├── DRAGNKL1.dll .............. ROC/GEM (static import, 48 exports)
    ├── Strato3.dll ............... Filter framework (static import, 213 exports)
    ├── StdFilters2.dll ........... Filter implementations (static import, 557 exports)
    │   └── CML4.dll .............. ICC color management (static import, 16 exports)
    ├── NSSLang4.dll .............. UI language resources (static import, 8 exports)
    ├── mscms.dll (Windows) ....... GetColorDirectoryA only (ICC profile path lookup)
    └── MFC70.DLL ................. Microsoft Foundation Classes 7.0

LS5000.md3 (MAID module -- scanner communication + ICE)
    ├── ICEDLL.dll ................ ICE defect correction (dynamic load, 36 exports)
    │   (or ICENKNL1.dll / ICENKNX2.dll depending on scanner model)
    └── NKDUSCAN.dll .............. USB transport (dynamic load, 1 export)
        (or NKDSBP2.dll for IEEE 1394 scanners)

Nikon Scan.exe (standalone application -- UI + file I/O, NOT the TWAIN driver)
    ├── Asteroid5.dll ............. Image file load/save (static import, 81 exports)
    │   └── PICN20.dll ............ Pegasus codec dispatcher (static import, 48 exports)
    │       ├── picn1020.dll ...... JPEG/TIFF decompression (1 export)
    │       └── picn1120.dll ...... JPEG/TIFF compression (1 export)
    ├── Strato3.dll ............... Shared filter framework
    └── StdFilters2.dll ........... Shared filter implementations
```

---

## 10. Data Flow Summary for Driver Developers

### What a New Driver Needs to Replicate

| Stage | Required? | Why |
|-------|-----------|-----|
| **ICE** | Optional | Only needed for dust/scratch removal. Requires 4-channel RGBI scanning. The ICE DLLs use a well-defined API and could potentially be loaded directly, but they are proprietary. Open-source alternatives exist (e.g., negative-film-specific processing). |
| **DRAG ROC** | Optional | Only for faded color correction. Proprietary algorithm. A new driver could skip this or implement basic color correction. |
| **DRAG GEM** | Optional | Only for grain reduction. Proprietary. Many open-source denoising algorithms exist. |
| **Color Management** | Recommended | Use system CMS (Windows ICM, macOS ColorSync, or littlecms on Linux) instead of CML4.dll. ICC profiles from NikonScan can be reused. |
| **LUT Application** | Recommended | Straightforward table lookup. Easy to implement for gamma, curves, levels. |
| **Scaling** | Framework | Standard image scaling. Use any library (e.g., libswscale, Pillow). |
| **Unsharp Mask** | Optional | Standard algorithm. Many implementations available. |
| **BGR Conversion** | Platform-dependent | Only needed if target requires BGR byte order. |

### What is Essential vs. Proprietary

**Essential (must implement for basic scanning)**:
- SCSI command sequences (SET WINDOW, SCAN, READ) -- documented in [pc-software-interface.md](pc-software-interface.md)
- Scan parameter encoding (SET WINDOW descriptor byte layout)
- Data transfer and reassembly from SCSI READ

**Valuable but replaceable**:
- ICC color management (use littlecms/system CMS)
- LUT/curves/gamma (trivial to implement)
- Image scaling and sharpening (many libraries available)

**Proprietary (cannot redistribute)**:
- DRAG ROC/GEM algorithms (Applied Science Fiction/Kodak patents, likely expired by now but DLLs are copyrighted)
- Digital ICE algorithms (same provenance)
- CML4 engine (Nikon proprietary, though functionally equivalent to littlecms)

### ICC Profile Paths (for Reuse)

NikonScan installs scanner-specific ICC profiles. A new driver can use these directly:
- Scanner profiles: found via `GetProfilePath` export or Windows ICC profile directory
- `GetMonitorProfile`, `GetPrinterProfile`, `GetRGBProfile` exports return configured profile paths
- CML4's rendering intent maps: 0=Perceptual, 1=Relative Colorimetric, 2=Saturation, 3=Absolute Colorimetric (standard ICC values)

---

## Cross-References

- [PC Software Interface](pc-software-interface.md) -- TWAIN dispatch, MAID capabilities, SET WINDOW encoding
- [DRAG API Reference](../components/dragnkl1/api.md) -- Full DRAG function signatures
- [DRAG Processing Pipeline](../components/dragnkl1/pipeline.md) -- Algorithm phases, Strato overview
- [ICE Overview](../components/ice/overview.md) -- ICE algorithm variants, DICE API
- [Scan Workflows](../components/nikonscan4-ds/scan-workflows.md) -- How ICE/DRAG fit in scan orchestration
- [Command Queue](../components/nikonscan4-ds/command-queue.md) -- DRAG command execution
- [SET WINDOW Descriptor](../scsi-commands/set-window-descriptor.md) -- ICE/DRAG extension area encoding
- [Software Layers](../architecture/software-layers.md) -- Full system architecture
