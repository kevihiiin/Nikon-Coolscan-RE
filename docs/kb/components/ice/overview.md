# Digital ICE DLL Overview

**Status**: Complete
**Last Updated**: 2026-03-05
**Phase**: 6 (DRAG/ICE)
**Confidence**: High (export analysis, compiler path strings, PE version info, DICE API tracing)

## Overview

Digital ICE (Image Correction and Enhancement) is a defect correction technology by Applied Science Fiction, Inc. It uses infrared light to detect surface defects (dust, scratches, fingerprints) on film and automatically removes them from the scanned image.

**Principle**: Film emulsion is transparent to infrared light, but surface defects (dust, scratches) scatter it. By scanning at both visible (RGB) and infrared wavelengths, the scanner produces a 4-channel RGBI image. The IR channel becomes a defect map that the ICE algorithm uses to reconstruct the affected areas in the RGB channels.

## DLL Variants

Three ICE DLLs are shipped with NikonScan 4.03:

| Property | ICEDLL.dll | ICENKNL1.dll | ICENKNX2.dll |
|----------|-----------|-------------|-------------|
| **Location** | `Drivers/` | `Drivers/` | `Drivers/` |
| **Size** | 280KB | 344KB | 432KB |
| **Exports** | 36 | 36 | 36 |
| **Version** | 3.0.0.4012 | 1.0.1.3001 | 1.0.1.3001 |
| **Build** | Willow 2003-04-28 | durer/Cedar 2001-08-17 | durer/Cedar 2001-08-17 |
| **Compiler** | Intel C++ 5.0 | Intel C++ 4.5 | Intel C++ 4.5 |
| **Variants** | L1B + X3A + X3B | L1 only | LSA + LSB |
| **Comment** | "for Nikon X3A,X3B,L1B scanners" | "for the Nikon L1 scanner" | "for the Nikon X2 scanner" |
| **Version String** | `ICE_Willow_030428_GM` | `durer_010817_ICE/Cedar_010817_ICE` | `durer_010817_ICE/Cedar_010817_ICE` |

### ICEDLL.dll (Newest, Universal)

The newest and most comprehensive ICE DLL. Contains three algorithm variants in a single binary:

| Variant | Core Class | Thread Class | SDC Core Algorithm |
|---------|-----------|-------------|-------------------|
| **L1B** | `CDICECoreNikonL1B` | `CDICEThreadNikonL1B` | `CSDCCoreAlgL1B` |
| **X3A** | `CDICECoreNikonX3A` | `CDICEThreadNikonX3A` | `CSDCCoreAlgX3A` |
| **X3B** | `CDICECoreNikonX3B` | `CDICEThreadNikonX3B` | `CSDCCoreAlgX3B` |

Source: `H:\StarTeam\ice_roc\Engineering\Sources\ICE\NikonX3AX3BL1B\`

Special build: "ICE_Willow_030428_GM" / "ICE-KR Alpha for X3B"

### ICENKNL1.dll (Older, Basic)

Single-variant DLL for basic ICE ("Nikon L1" level):

| Component | Source File |
|-----------|------------|
| `CDICECoreNikonL1` | `DICELib\DICELib\NikonL1\CDICECoreNikonL1.cpp` |
| `CDICEThreadNikonL1` | `DICELib\DICELib\NikonL1\CDICEThreadNikonL1.cpp` |
| `CSDCCoreAlg36` | `SDCCoreCPP\CSDCCoreAlg36.cpp` |
| `CSDCCoreAlg37` | `SDCCoreCPP\CSDCCoreAlg37.cpp` |

Source: `H:\StarTeam\ice_roc\Engineering\Sources\ICE\DICELib\` + `DICEStatic\ICENKNL1\`

### ICENKNX2.dll (Older, Advanced)

Two-variant DLL for advanced ICE:

| Variant | Core Class | Thread Class |
|---------|-----------|-------------|
| **LSA** | `CDICECoreNikonLSA` | `CDICEThreadNikonLSA` |
| **LSB** | `CDICECoreNikonLSB` | `CDICEThreadNikonLSB` |

SDC Core algorithms: `CSDCCoreAlg20`, `CSDCCoreAlg30`, `CSDCCoreAlg31`, `CSDCCoreAlg32`, `CSDCCoreAlg33`

Source: `H:\StarTeam\ice_roc\Engineering\Sources\ICE\DICELib\DICELib\NikonLSA\` + `NikonLSB\`

## Algorithm Variant Mapping

| Variant Code | Level | Description | Likely Scanner Mapping |
|-------------|-------|-------------|----------------------|
| L1 / L1B | Basic | Single-pass, fast defect correction | LS-40 (budget scanner, USB PID 4000) |
| X3A | Advanced | Multi-pass, better reconstruction | LS-50 / LS-5000 (mid-range) |
| X3B | Most Advanced | Highest quality, slowest | LS-50 / LS-5000 (when ICE4 Advanced selected) |
| LSA | Large Scanner A | Optimized for higher resolution | LS-8000 / LS-9000 (large format) |
| LSB | Large Scanner B | Alternative for large format | LS-8000 / LS-9000 |

**SDC** = Surface Defect Correction (the underlying technology name)

## DICE API (Identical Across All 3 DLLs)

All three ICE DLLs export exactly 36 functions with identical names. The API uses a C calling convention with opaque context handles and a buffer-queue architecture.

### Lifecycle Functions

| # | Export | Description |
|---|--------|-------------|
| 36 | `DICEVersion()` | Return version string |
| 25 | `DICENew(...)` | Allocate new DICE context (selects algorithm variant) |
| 20 | `DICELoad(...)` | Load algorithm parameters |
| 19 | `DICEInit(...)` | Initialize for processing |
| 2 | `DICEBegin(...)` | Begin processing session |
| 26 | `DICEProcess(...)` | Process next chunk of data |
| 8 | `DICEEnd(...)` | End processing session |
| 4 | `DICEComplete(...)` | Query completion status |
| 34 | `DICEUnload(...)` | Unload algorithm data |
| 5 | `DICEDelete(...)` | Free DICE context |
| 1 | `DICEAbort(...)` | Cancel in-progress operation |

### Buffer Queue Functions

ICE uses a producer-consumer buffer queue model for streaming processing:

| # | Export | Description |
|---|--------|-------------|
| 27 | `DICEQueueInputBuff(ctx, buf)` | Enqueue an input buffer (RGBI row data) |
| 6 | `DICEDequeueInputBuff(ctx)` | Dequeue a consumed input buffer |
| 23 | `DICENeedInputBuff(ctx)` | Check if more input is needed |
| 28 | `DICEQueueOutputBuff(ctx, buf)` | Enqueue an output buffer (for results) |
| 7 | `DICEDequeueOutputBuff(ctx)` | Dequeue a completed output buffer |
| 24 | `DICENeedOutputBuff(ctx)` | Check if output buffer space is needed |
| 18 | `DICEHasOverflowOutputBuff(ctx)` | Check for overflow output |
| 21 | `DICEMakeOverflowOutputBuff(ctx)` | Create overflow output buffer |

### Parameter Functions

| # | Export | Description |
|---|--------|-------------|
| 35 | `DICEUseDefaultParameters(ctx)` | Reset to defaults |
| 30 | `DICESetFloatParameter(ctx, id, val)` | Set float parameter |
| 31 | `DICESetIntParameter(ctx, id, val)` | Set integer parameter |
| 33 | `DICESetPtrParameter(ctx, id, ptr)` | Set pointer parameter |
| 14 | `DICEGetFloatParameter(ctx, id)` | Get float parameter |
| 15 | `DICEGetIntParameter(ctx, id)` | Get integer parameter |
| 17 | `DICEGetPtrParameter(ctx, id)` | Get pointer parameter |

### Progress/Status Functions

| # | Export | Description |
|---|--------|-------------|
| 10 | `DICEGetCurrentInputRow(ctx)` | Current input row being processed |
| 11 | `DICEGetCurrentOutputRow(ctx)` | Current output row produced |
| 12 | `DICEGetDefectPercent(ctx)` | Percentage of image with defects |
| 13 | `DICEGetDuration(ctx)` | Processing duration |

### Multi-Frame Functions

| # | Export | Description |
|---|--------|-------------|
| 3 | `DICEClearAllFrameInfo(ctx)` | Clear all frame data (batch scanning) |
| 16 | `DICEGetMaxFrameCount(ctx)` | Get maximum frames supported |
| 32 | `DICESetMaxFrameCount(ctx, n)` | Set maximum frame count |

### Memory Management Functions

| # | Export | Description |
|---|--------|-------------|
| 22 | `DICEMalloc(ctx, size)` | Allocate memory through ICE allocator |
| 9 | `DICEFree(ctx, ptr)` | Free ICE-allocated memory |
| 29 | `DICERealloc(ctx, ptr, size)` | Reallocate ICE memory |

## LS5000.md3 Integration

LS5000.md3 loads the ICE DLL dynamically and resolves DICE functions via `GetProcAddress`. The DLL filename is **not** stored as a static string in LS5000.md3 -- it is likely determined at runtime from a registry key or MAID capability query.

### DICE Functions Used by LS5000.md3

The following DICE function name strings are present in LS5000.md3 (used for `GetProcAddress` resolution):

```
DICENew, DICELoad, DICEInit, DICEBegin, DICEProcess, DICEEnd,
DICEComplete, DICEUnload, DICEDelete, DICEAbort, DICEVersion,
DICEQueueInputBuff, DICEDequeueInputBuff, DICENeedInputBuff,
DICEQueueOutputBuff, DICEDequeueOutputBuff, DICENeedOutputBuff,
DICEGetDefectPercent
```

18 of the 36 DICE functions are used -- the unused ones are mainly parameter get/set, overflow buffer management, and multi-frame functions.

### MAID Capability Hierarchy

In the MAID object tree (documented in [scan-workflows.md](../nikonscan4-ds/scan-workflows.md)):

```
0x8103 (Image Object A)
└─ 0x8005 (Scan Parameters)
   └─ 0x8007 (Multi-sample)
      └─ 0x800C (ICE)          ◄ ICE enable/disable
         └─ 0x800E (DRAG)      ◄ DRAG enable/disable
```

ICE (cap ID `0x800C`) is controlled as a boolean capability through the MAID interface. When NikonScan4.ds sets cap `0x800C = true`, LS5000.md3 enables infrared scanning and ICE processing.

### Processing Flow in LS5000.md3

```
1. Scan orchestrator sets MAID cap 0x800C = true (ICE enabled)
2. LS5000.md3 configures scanner for 4-channel RGBI scan
   (SET WINDOW descriptor includes IR channel parameters)
3. Scanner performs scan with visible light + IR LED
4. SCSI READ transfers RGBI data to host
5. LS5000.md3 feeds data to DICE:
   a. DICENew() → DICELoad() → DICEInit() → DICEBegin()
   b. Loop:
      - DICEQueueInputBuff(RGBI_row)
      - DICEProcess()
      - DICEDequeueOutputBuff() → cleaned RGB row
      - DICENeedInputBuff() / DICENeedOutputBuff() → flow control
   c. DICEEnd() → DICEComplete()
6. Cleaned RGB data passed to NikonScan4.ds for DRAG/Strato processing
```

## Source Code Architecture (from compiler strings)

The ICE SDK has a layered architecture revealed by embedded compiler paths:

```
H:\StarTeam\ice_roc\Engineering\Sources\ICE\
├── DICELib/
│   └── DICELib/
│       ├── CDICECore.cpp          -- Core DICE engine
│       ├── CDICEObject.cpp        -- Base object
│       ├── CDICEQueue.cpp         -- Buffer queue management
│       ├── CDICEThread.cpp        -- Threading support
│       ├── CDICEDataConverter.cpp -- Pixel format conversion
│       ├── CDICEBandLimiter.cpp   -- Frequency band limiting
│       ├── CDICEScaler.cpp        -- Image scaling for analysis
│       ├── DICE.cpp               -- C API entry points
│       ├── DICEWin32Utils.cpp     -- Windows platform utilities
│       ├── NikonL1/
│       │   ├── CDICECoreNikonL1.cpp
│       │   └── CDICEThreadNikonL1.cpp
│       ├── NikonLSA/
│       │   ├── CDICECoreNikonLSA.cpp
│       │   └── CDICEThreadNikonLSA.cpp
│       └── NikonLSB/
│           ├── CDICECoreNikonLSB.cpp
│           └── CDICEThreadNikonLSB.cpp
├── NikonX3AX3BL1B/              (newer unified build)
│   ├── DICELib/                  (same core files)
│   ├── SDCCore/
│   │   ├── CSDCCoreAlgL1B.cpp
│   │   ├── CSDCCoreAlgX3A.cpp
│   │   ├── CSDCCoreAlgX3B.cpp
│   │   └── CSDCCoreBase.cpp
│   └── Targets/
│       ├── CDICECoreNikonL1B.cpp
│       ├── CDICECoreNikonX3A.cpp
│       ├── CDICECoreNikonX3B.cpp
│       ├── CDICEThreadNikonL1B.cpp
│       ├── CDICEThreadNikonX3A.cpp
│       ├── CDICEThreadNikonX3B.cpp
│       └── ICENIKON.cpp
├── SDCCoreCPP/
│   ├── CSDCCoreBase.cpp
│   ├── CSDCCoreAlg20.cpp  -- (ICENKNX2)
│   ├── CSDCCoreAlg30.cpp  -- (ICENKNX2)
│   ├── CSDCCoreAlg31.cpp  -- (ICENKNX2)
│   ├── CSDCCoreAlg32.cpp  -- (ICENKNX2)
│   ├── CSDCCoreAlg33.cpp  -- (ICENKNX2)
│   ├── CSDCCoreAlg36.cpp  -- (ICENKNL1)
│   └── CSDCCoreAlg37.cpp  -- (ICENKNL1)
└── DICEStatic/
    ├── ICENKNL1/ICENKNL1.cpp
    └── ICENKNX2/ICENKNX2.cpp
```

## Related Docs

- [DRAG API Reference](../dragnkl1/api.md) -- DRAG (ROC/GEM) processing (runs after ICE)
- [DRAG Pipeline](../dragnkl1/pipeline.md) -- end-to-end image processing pipeline
- [Scan Workflows](../nikonscan4-ds/scan-workflows.md) -- ICE in the MAID capability hierarchy
- [SET WINDOW Descriptor](../../scsi-commands/set-window-descriptor.md) -- scanner IR channel configuration
