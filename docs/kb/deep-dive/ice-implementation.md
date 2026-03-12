# Digital ICE / DRAG Implementation Deep-Dive

**Status**: Complete
**Last Updated**: 2026-03-12
**Phase**: 6 (DRAG/ICE) -- extended analysis
**Confidence**: High (binary analysis of 5 DLLs, firmware trace, cross-validated with SCSI protocol docs)

## Table of Contents

1. [Overview and Physical Principles](#1-overview-and-physical-principles)
2. [Hardware: The Infrared Channel](#2-hardware-the-infrared-channel)
3. [Firmware: IR Scan Execution](#3-firmware-ir-scan-execution)
4. [SCSI Protocol: Requesting IR Data](#4-scsi-protocol-requesting-ir-data)
5. [Host Pipeline: Data Flow from Scanner to Output](#5-host-pipeline-data-flow-from-scanner-to-output)
6. [ICE DLL Architecture](#6-ice-dll-architecture)
7. [DICE API Reference](#7-dice-api-reference)
8. [ICE Algorithm Deep-Dive](#8-ice-algorithm-deep-dive)
9. [SDC Core Algorithms](#9-sdc-core-algorithms)
10. [DRAG Algorithm Deep-Dive (ROC + GEM)](#10-drag-algorithm-deep-dive-roc--gem)
11. [DLL-to-Scanner Mapping](#11-dll-to-scanner-mapping)
12. [LS5000.md3 ICE Integration](#12-ls5000md3-ice-integration)
13. [NikonScan4.ds DRAG Integration](#13-nikonscan4ds-drag-integration)
14. [Algorithm Parameter Tables](#14-algorithm-parameter-tables)
15. [Implementation Notes for Driver Developers](#15-implementation-notes-for-driver-developers)

---

## 1. Overview and Physical Principles

### What is Digital ICE?

Digital ICE (Image Correction and Enhancement) is a technology developed by Applied Science Fiction, Inc. (later acquired by Kodak) for automatically detecting and removing surface defects -- dust particles, scratches, fingerprints, and other physical blemishes -- from scanned film images.

### The Core Physical Principle

Film emulsion layers (which contain the image) are **transparent to infrared light**. When the scanner shines visible light through the film, the emulsion absorbs and transmits specific wavelengths to produce the image. But when the scanner shines **infrared light** (typically ~940nm), the emulsion is essentially transparent -- the IR passes straight through.

However, **surface defects scatter infrared light**. A dust particle sitting on the film surface blocks or scatters both visible and infrared light equally. A scratch on the film surface does the same.

This difference is the key insight:

```
                  Visible Light          Infrared Light
                  ────────────           ────────────
Film emulsion:    Absorbed (image)       Transparent (no signal)
Surface defect:   Blocked (artifact)     Blocked (defect signal!)
                                         ^^^^^^^^^^^^^^^^^^^^^^^^
                                         This is the defect map
```

By scanning at both visible (RGB) and infrared wavelengths, the scanner produces a 4-channel **RGBI** image. The IR channel contains ONLY the defect information -- anywhere the IR channel shows low transmission, there is a surface defect. The ICE algorithm then uses this defect map to reconstruct the affected areas in the RGB channels by interpolating from surrounding clean pixels.

### Technology Layers

```
Applied Science Fiction (ASF) Technologies:
├── Digital ICE  -- Infrared defect detection and removal
│   └── SDC (Surface Defect Correction) -- the core algorithm engine
├── Digital ROC  -- Restoration of Color (faded film correction)
├── Digital GEM  -- Grain Equalization and Management
└── Digital SHO  -- Shadow and Highlight Optimizer (not in NikonScan)

Nikon Implementation:
├── ICE DLLs    -- ICEDLL.dll, ICENKNL1.dll, ICENKNX2.dll
│   └── Called by LS5000.md3 (scanner model module)
├── DRAG DLL    -- DRAGNKL1.dll (ROC + GEM combined)
│   └── Called by NikonScan4.ds (TWAIN data source)
└── Firmware     -- IR LED control, RGBI CCD readout
```

---

## 2. Hardware: The Infrared Channel

### CCD Sensor Architecture

The LS-50/LS-5000 uses a **tri-linear CCD** with an additional infrared sensing line. The CCD has four sensing lines arranged in parallel:

```
Film travel direction →
┌────────────────────────────────────────────┐
│  ████████████████████████████████████ Red   │  CCD line 0
│                                            │
│  ████████████████████████████████████ Green │  CCD line 1
│                                            │
│  ████████████████████████████████████ Blue  │  CCD line 2
│                                            │
│  ████████████████████████████████████ IR    │  CCD line 3
└────────────────────────────────────────────┘
                    ↑
              ~4095 active CCD elements per line
              (from firmware CCD characterization data at FW:0x4A8BC)
```

Source: Firmware scan pipeline at `FW:0x36C90` processes 4 color channels. Per-channel descriptors at `FW:0x405342-0x40535A` define channel geometry:
- 757 (0x02F5) pixels: full CCD line width including margins
- 665 (0x0299) pixels: active pixel count per line

### Illumination Sources

The scanner contains two light sources, selectable electronically:

| Source | Wavelength | Purpose | Control |
|--------|-----------|---------|---------|
| White LED | ~400-700nm (broadband visible) | RGB image capture | GPIO `0xFF85` bit 0 (BCLR = on) |
| Infrared LED | ~940nm (near-IR) | Defect detection for ICE | Same GPIO control, different DAC mode |

Source: Lamp control at `FW:0x2C66A` (6 write sites). DAC mode register `0x2000C2`:
- `0x22` = normal visible-light scan mode
- `0xA2` = calibration mode (bit 7 set)

The IR LED is part of the same illumination assembly. The firmware switches between visible and IR illumination by changing the ASIC DAC configuration and the LED drive circuit. The CCD's silicon photodiode is naturally sensitive to near-IR light, so the IR CCD line uses a filter that passes only IR while the RGB lines use colored filters.

### Scan Modes with IR

The firmware has separate scan task groups for IR-enabled and non-IR scans (from task table at `FW:0x49910`):

| Group | Task Codes | Handler Range | Mode |
|-------|-----------|--------------|------|
| 3 | 0x0830-0x0834 | 0x0015-0x0019 | Fine 8-bit, **no ICE** |
| **4** | **0x0840-0x0844** | **0x0042-0x0046** | **Fine 8-bit, with ICE/IR** |
| 5 | 0x0850-0x0854 | 0x0023-0x0027 | Fine 14-bit, **no ICE** |
| **6** | **0x0860-0x0864** | **0x0033-0x0037** | **Fine 14-bit, with ICE/IR** |
| 7 | 0x0870-0x0874 | 0x0038-0x003C | Multi-pass, **no ICE** |
| **8** | **0x0880-0x0884** | **0x0047-0x004B** | **Multi-pass, with ICE/IR** |

ICE groups (4, 6, 8) have **different handler indices** from their non-ICE counterparts (3, 5, 7), confirming that ICE requires a different firmware code path that additionally captures the IR channel.

### IR Scan Timing

For an ICE-enabled scan, the scanner performs **each scan line twice** or reads all four CCD lines simultaneously:

1. **Simultaneous 4-channel readout**: The CCD captures R, G, B, and IR lines in a single pass. Because the CCD lines are physically offset on the chip, the firmware compensates for the line delay between channels using ASIC DMA programming (function F4 at `FW:0x411E8`, 764 bytes, which programs DMA for all 4 color channels).

2. **Separate IR pass**: An alternative approach where the scanner makes one pass with visible light (RGB) and a second pass with only the IR LED active. This method is used for some scan modes where higher IR quality is needed.

The scan pipeline at `FW:0x36C90` explicitly handles 4 channels, with channel 3 being IR. The pixel processing block reads 16-bit CCD values from all four channels and applies `shlr.w` (shift right word) for bit-depth extraction from the 14-bit CCD data packed in 16-bit words.

---

## 3. Firmware: IR Scan Execution

### How the Firmware Handles an ICE Scan

When the host sends a SCAN command (0x1B) with ICE enabled, the firmware executes the ICE-specific task group. The sequence:

```
1. Host: SET WINDOW (0x24) with ICE/DRAG extension area enabled
   └── Window descriptor byte at ICE offset: 0xa20 master enable = 1
   └── Byte 50: multi-sample count
   └── Vendor extension includes ICE parameters

2. Host: SCAN (0x1B) -- initiates physical scan
   └── Firmware dispatches ICE task group (0x084x / 0x086x / 0x088x)
   └── Task dispatch: FW:0x20DBA → table at 0x49910

3. Firmware scan execution:
   a. F12 (0x44E40): Common scan init -- adapter detection, ASIC base config
   b. Entry point (0x40630-0x40654): Adapter-specific configuration
   c. F2 (0x40660): Scan orchestrator
      ├── F3 (0x408FE): ASIC channel setup for 4 channels (R/G/B/IR)
      ├── F4 (0x411E8): DMA programming for all 4 channels
      ├── F5 (0x414E4): CCD pixel transfer (multi-channel)
      └── F6 (0x41EE8): Resolution/adapter setup

4. Per-line processing:
   a. Inner state machine (0x40000): Triggers ASIC DMA per line
   b. F1 (0x40318): Processes scan line from ASIC RAM
   c. 4-channel pixel data → Buffer RAM (0xC00000)
   d. ISP1581 USB DMA → bulk transfer to host

5. Host: READ (0x28) DTC=0x00 -- retrieves RGBI pixel data
   └── Transfer includes all 4 channels interleaved
```

### CCD Channel Geometry

The firmware defines per-channel descriptors at RAM `0x405342-0x40535A`:

| Channel | Index | Start/End | Active Pixels | Assignment |
|---------|-------|-----------|---------------|------------|
| 0 | 0 | 0x02F5 / 0x0299 | 665 | Red |
| 1 | 1 | 0x02F5 / 0x0299 | 665 | Green |
| 2 | 2 | 0x02F5 / 0x0299 | 665 | Blue |
| **3** | **3** | **0x02F5 / 0x0299** | **665** | **Infrared** |

All four channels have identical pixel geometry -- the same CCD element count and the same active window. This means the IR channel has the same spatial resolution as the RGB channels (no downsampling).

### CCD Characterization Data

Factory-calibrated per-CCD-element correction data at `FW:0x4A8BC-0x528BD` (~32KB):
- 4095 groups per section (matching the CCD element count)
- 4 bytes per group (one per CCD sub-element: R, G, B, IR)
- Values 0-11: analog correction levels (NOT binary defect map)
- Edge-to-center vignetting decay pattern
- Accessed via pointer table at `FW:0x4A37E`

This correction data is applied during the analog-to-digital conversion phase to normalize CCD response across all channels including IR.

---

## 4. SCSI Protocol: Requesting IR Data

### SET WINDOW with ICE

The SET WINDOW command (0x24) configures the scanner for ICE operation. LS5000.md3 builds the window descriptor at `FUN_100b2b30` (1268 bytes).

```
Standard Window Descriptor (54 bytes):
  Bytes 0-7:   Header
  Bytes 8-9:   Window ID
  Bytes 10-13: Resolution (X, Y DPI)
  Bytes 14-29: Scan area (UL X/Y, Width, Height)
  Bytes 30-35: Image params (brightness, threshold, contrast, composition, BPP, halftone)
  Bytes 36-47: Reserved
  Bytes 48-53: Nikon vendor fields (color mode, scan flags, multi-sample, compression)

Vendor Extension Area (byte 54+):
  Dynamic list of vendor params (0x102-0x10d, 1/2/4 bytes each)
  Auto-discovered via GET WINDOW during init

ICE/DRAG Extension Area (at end):
  If FUN_1009d730() returns true (scanner_state+0x84 == 1):
    Byte: ICE/DRAG master enable (MAID param 0xa20)
    Then: Per-ICE parameter list (dynamic size from FUN_1009fc20)
```

The ICE enable flag is MAID capability ID `0x800C`, which maps to the ICE object (type `0x1022`) in the MAID hierarchy:

```
0x8103 (Image Object A)
└── 0x8005 (Scan Parameters)
    └── 0x8007 (Multi-sample)
        └── 0x800C (ICE)          <-- ICE enable/disable
            └── 0x800E (DRAG)     <-- DRAG enable/disable
```

### READ Command for RGBI Data

When ICE is enabled, the READ command (0x28) with DTC=0x00 returns 4-channel RGBI data instead of 3-channel RGB:

```
READ CDB:
  Byte 0: 0x28 (READ opcode)
  Byte 2: 0x00 (DTC = Image Data)
  Byte 5: 0x00 (8-bit) or 0x01 (16-bit) qualifier
  Bytes 6-8: Transfer length (big-endian, 24-bit)
  Byte 9: 0x80 (vendor flag)

RGBI Data Format:
  Per scan line, interleaved by pixel:
    [R0 G0 B0 I0] [R1 G1 B1 I1] [R2 G2 B2 I2] ...

  8-bit mode:  4 bytes per pixel  (4 channels x 1 byte)
  14-bit mode: 8 bytes per pixel  (4 channels x 2 bytes, big-endian, upper 2 bits zero)
  16-bit mode: 8 bytes per pixel  (4 channels x 2 bytes, big-endian)
```

The firmware READ handler at `FW:0x023F10` transfers RGBI data from ASIC buffer RAM (`0x800000+`) through buffer RAM (`0xC00000+`) via ISP1581 USB DMA.

---

## 5. Host Pipeline: Data Flow from Scanner to Output

### Complete End-to-End Pipeline

```
Scanner Hardware
    │
    │  CCD captures RGBI (4 channels)
    │  Firmware DMA: CCD → ASIC RAM → Buffer RAM → USB
    │
    ▼
NKDUSCAN.dll (USB Transport)
    │  NkDriverEntry FC5 (Execute Command)
    │  Bulk pipe read → RGBI raw data
    │
    ▼
LS5000.md3 (Scanner Model Module)
    │  ┌────────────────────────────────────────┐
    │  │ DICE Processing (ICE)                   │
    │  │                                         │
    │  │ Input:  RGBI (4-channel, raw from CCD)  │
    │  │                                         │
    │  │ 1. DICENew(variant_code)                │
    │  │ 2. DICELoad(ctx, ...)                   │
    │  │ 3. DICEInit(ctx, width, height, ...)    │
    │  │ 4. DICEBegin(ctx)                       │
    │  │ 5. Loop per row:                        │
    │  │    a. DICEQueueInputBuff(ctx, RGBI_row) │
    │  │    b. DICEProcess(ctx)                  │
    │  │    c. DICEDequeueOutputBuff(ctx)→RGB_row│
    │  │    d. DICENeedInputBuff/OutputBuff()     │
    │  │ 6. DICEEnd(ctx)                         │
    │  │ 7. DICEComplete(ctx) → defect percent   │
    │  │                                         │
    │  │ Output: RGB (3-channel, defects removed) │
    │  └────────────────────────────────────────┘
    │
    ▼
NikonScan4.ds (TWAIN Data Source)
    │  ┌────────────────────────────────────────┐
    │  │ DRAG Processing (ROC + GEM)             │
    │  │                                         │
    │  │ Input:  RGB (cleaned by ICE)             │
    │  │                                         │
    │  │ 1. DRAGNew() → DRAGLoad() → DRAGInit() │
    │  │ 2. Statistics gathering pass             │
    │  │ 3. DRAGBegin() → DRAGProcess() loop     │
    │  │ 4. Phases: acquire, normalize, grain     │
    │  │    analysis, fade correction, ROC, GEM   │
    │  │ 5. DRAGEnd() → DRAGComplete()           │
    │  │                                         │
    │  │ Output: RGB (color restored, grain       │
    │  │         reduced)                         │
    │  └────────────────────────────────────────┘
    │
    ▼
Strato Pipeline (Standard Image Filters)
    │  Strato3.dll + StdFilters2.dll
    │  Color space conversion (CML4.dll / ICC profiles)
    │  LUT application, scaling, unsharp mask
    │  Cropping, histogram operations
    │
    ▼
Final Output Image (via TWAIN API)
```

### Key Architectural Observations

1. **ICE runs in LS5000.md3** (the scanner model module), NOT in NikonScan4.ds. This is because ICE needs the 4-channel RGBI data directly from the scanner.

2. **DRAG runs in NikonScan4.ds** (the TWAIN source). It receives already-cleaned 3-channel RGB data.

3. **ICE always runs before DRAG**. ICE must remove defects first because DRAG's grain/color analysis would be corrupted by dust artifacts.

4. **ICE is scanner-specific** (loaded dynamically by LS5000.md3), while DRAG is scanner-agnostic (statically linked into NikonScan4.ds).

5. **The firmware performs NO image processing** -- all calibration, defect correction, color restoration, and grain reduction happen host-side.

---

## 6. ICE DLL Architecture

### Three ICE DLL Variants

NikonScan ships three ICE DLLs. All export the identical 36-function DICE API but contain different algorithm implementations:

| Property | ICEDLL.dll | ICENKNL1.dll | ICENKNX2.dll |
|----------|-----------|-------------|-------------|
| **Size** | 280KB | 344KB | 432KB |
| **Version** | 3.0.0.4012 | 1.0.1.3001 | 1.0.1.3001 |
| **Build** | ICE_Willow_030428_GM | durer_010817_ICE/Cedar_010817_ICE | durer_010817_ICE/Cedar_010817_ICE |
| **Date** | April 30, 2003 | August 16, 2001 | August 16, 2001 |
| **Compiler** | Intel C++ 5.0.1120 | Intel C++ 4.5.15 | Intel C++ 4.5.15 |
| **Variants** | L1B + X3A + X3B | L1 only | LSA + LSB |
| **Comment** | "for Nikon X3A,X3B,L1B scanners" | "for the Nikon L1 scanner" | "for the Nikon X2 scanner" |
| **Imports** | KERNEL32 only | KERNEL32 only | KERNEL32 only |
| **DICENew alloc** | ~600KB context | ~600KB context | ~600KB context |

### Class Hierarchy (from RTTI and compiler paths)

```
CDICEObject (base)
├── CDICECore (abstract core engine)
│   ├── CDICECoreNikonL1    (ICENKNL1.dll)
│   ├── CDICECoreNikonL1B   (ICEDLL.dll)
│   ├── CDICECoreNikonX3A   (ICEDLL.dll)
│   ├── CDICECoreNikonX3B   (ICEDLL.dll)
│   ├── CDICECoreNikonLSA   (ICENKNX2.dll)
│   └── CDICECoreNikonLSB   (ICENKNX2.dll)
├── CDICEThread (abstract processing thread)
│   ├── CDICEThreadNikonL1   (ICENKNL1.dll)
│   ├── CDICEThreadNikonL1B  (ICEDLL.dll)
│   ├── CDICEThreadNikonX3A  (ICEDLL.dll)
│   ├── CDICEThreadNikonX3B  (ICEDLL.dll)
│   ├── CDICEThreadNikonLSA  (ICENKNX2.dll)
│   └── CDICEThreadNikonLSB  (ICENKNX2.dll)
├── CDICEQueue (buffer queue management)
├── CDICEDataConverter (pixel format conversion)
├── CDICEScaler (image scaling for multi-resolution analysis)
└── CDICEBandLimiter (frequency band limiting)

CSDCCoreBase (abstract SDC algorithm base)
├── CSDCCoreAlg20   (ICENKNX2.dll -- LSA/LSB)
├── CSDCCoreAlg30   (ICENKNX2.dll -- LSA/LSB)
├── CSDCCoreAlg31   (ICENKNX2.dll -- LSA/LSB)
├── CSDCCoreAlg32   (ICENKNX2.dll -- LSA/LSB)
├── CSDCCoreAlg33   (ICENKNX2.dll -- LSA/LSB)
├── CSDCCoreAlg36   (ICENKNL1.dll -- L1)
├── CSDCCoreAlg37   (ICENKNL1.dll -- L1)
├── CSDCCoreAlgL1B  (ICEDLL.dll)
├── CSDCCoreAlgX3A  (ICEDLL.dll)
└── CSDCCoreAlgX3B  (ICEDLL.dll)
```

### Source Tree (from compiler path strings)

```
H:\StarTeam\ice_roc\Engineering\Sources\ICE\
├── DICELib/
│   └── DICELib/
│       ├── CDICECore.cpp          -- Core engine (abstract base)
│       ├── CDICEObject.cpp        -- Base object lifecycle
│       ├── CDICEQueue.cpp         -- Producer-consumer buffer queue
│       ├── CDICEThread.cpp        -- Worker thread management
│       ├── CDICEDataConverter.cpp -- 8/16-bit ↔ float conversion
│       ├── CDICEBandLimiter.cpp   -- Frequency band limiting for multi-scale
│       ├── CDICEScaler.cpp        -- Image scaling (downsample/upsample)
│       ├── DICE.cpp               -- C API entry points (DICENew, etc.)
│       ├── DICEWin32Utils.cpp     -- Win32 platform helpers
│       ├── NikonL1/               -- L1 variant target (oldest)
│       ├── NikonLSA/              -- LSA variant target (large scanner A)
│       └── NikonLSB/              -- LSB variant target (large scanner B)
├── NikonX3AX3BL1B/                -- Unified build (ICEDLL.dll)
│   ├── DICELib/                   -- Same core files
│   ├── SDCCore/
│   │   ├── CSDCCoreAlgL1B.cpp    -- L1B algorithm
│   │   ├── CSDCCoreAlgX3A.cpp    -- X3A algorithm
│   │   ├── CSDCCoreAlgX3B.cpp    -- X3B algorithm
│   │   └── CSDCCoreBase.cpp      -- SDC algorithm base class
│   └── Targets/
│       ├── CDICECoreNikonL1B.cpp
│       ├── CDICECoreNikonX3A.cpp
│       ├── CDICECoreNikonX3B.cpp
│       ├── CDICEThread*.cpp       -- Per-variant thread classes
│       └── ICENIKON.cpp           -- DLL entry point
├── SDCCoreCPP/                    -- Shared SDC algorithm implementations
│   ├── CSDCCoreBase.cpp
│   ├── CSDCCoreAlg20-37.cpp      -- Numbered algorithm variants
│   └── (algorithms 20-37 span both older DLLs)
└── DICEStatic/                    -- Per-DLL static link wrappers
    ├── ICENKNL1/ICENKNL1.cpp
    └── ICENKNX2/ICENKNX2.cpp
```

### Compiler Flags (from embedded strings)

All source files compiled with:
- `-D KR_EXPECTED_VALUE`: Enables "Kodak Research expected value" code paths (algorithm tuning parameter selection)
- `-D USE_OBJECT_SDCCORE`: Uses object-oriented SDC core (vs. plain C implementation)
- `-D NDEBUG`: Release build (no debug assertions)
- `-O2`: Full optimization
- `-MT`: Multi-threaded static CRT

---

## 7. DICE API Reference

### Complete Export Table (36 functions, identical across all 3 DLLs)

All functions use C calling convention (`__cdecl`). The `ctx` parameter is an opaque pointer to a ~600KB context object allocated by `DICENew`.

#### Lifecycle (strict calling order)

| Ord | Function | Signature | Description |
|-----|----------|-----------|-------------|
| 25 | `DICENew` | `ctx = DICENew(int variant)` | Allocate context, select algorithm. Allocates ~600KB. |
| 20 | `DICELoad` | `int DICELoad(ctx, ...)` | Load algorithm parameters and calibration data |
| 19 | `DICEInit` | `int DICEInit(ctx, ...)` | Initialize for processing (set image dimensions, bit depth) |
| 2 | `DICEBegin` | `int DICEBegin(ctx)` | Begin processing session |
| 26 | `DICEProcess` | `int DICEProcess(ctx)` | Process available buffered data (call repeatedly) |
| 8 | `DICEEnd` | `int DICEEnd(ctx)` | End processing session |
| 4 | `DICEComplete` | `int DICEComplete(ctx)` | Query completion status, get final statistics |
| 34 | `DICEUnload` | `int DICEUnload(ctx)` | Unload algorithm data, free internal buffers |
| 5 | `DICEDelete` | `void DICEDelete(ctx)` | Free context (~600KB) |
| 1 | `DICEAbort` | `int DICEAbort(ctx)` | Cancel in-progress operation |

#### Buffer Queue I/O

| Ord | Function | Description |
|-----|----------|-------------|
| 27 | `DICEQueueInputBuff(ctx, buf)` | Submit an RGBI input row for processing |
| 6 | `DICEDequeueInputBuff(ctx)` | Retrieve a consumed input buffer (for reuse) |
| 23 | `DICENeedInputBuff(ctx)` | Returns true if algorithm needs more input |
| 28 | `DICEQueueOutputBuff(ctx, buf)` | Submit an empty output buffer for results |
| 7 | `DICEDequeueOutputBuff(ctx)` | Retrieve a completed output row (cleaned RGB) |
| 24 | `DICENeedOutputBuff(ctx)` | Returns true if algorithm needs output buffer space |
| 18 | `DICEHasOverflowOutputBuff(ctx)` | Check for overflow (more output than expected) |
| 21 | `DICEMakeOverflowOutputBuff(ctx)` | Allocate overflow buffer |

#### Parameters

| Ord | Function | Description |
|-----|----------|-------------|
| 35 | `DICEUseDefaultParameters(ctx)` | Reset all parameters to defaults |
| 30 | `DICESetFloatParameter(ctx, id, val)` | Set float parameter by ID |
| 31 | `DICESetIntParameter(ctx, id, val)` | Set integer parameter by ID |
| 33 | `DICESetPtrParameter(ctx, id, ptr)` | Set pointer parameter by ID |
| 14 | `DICEGetFloatParameter(ctx, id)` | Get float parameter value |
| 15 | `DICEGetIntParameter(ctx, id)` | Get integer parameter value |
| 17 | `DICEGetPtrParameter(ctx, id)` | Get pointer parameter value |

#### Progress / Status

| Ord | Function | Description |
|-----|----------|-------------|
| 10 | `DICEGetCurrentInputRow(ctx)` | Row currently being consumed |
| 11 | `DICEGetCurrentOutputRow(ctx)` | Row most recently produced |
| 12 | `DICEGetDefectPercent(ctx)` | Percentage of image area with detected defects |
| 13 | `DICEGetDuration(ctx)` | Processing time elapsed |

#### Multi-Frame (batch scanning)

| Ord | Function | Description |
|-----|----------|-------------|
| 3 | `DICEClearAllFrameInfo(ctx)` | Reset frame data for new batch |
| 16 | `DICEGetMaxFrameCount(ctx)` | Maximum frames supported |
| 32 | `DICESetMaxFrameCount(ctx, n)` | Set maximum frame count |

#### Memory Management

| Ord | Function | Description |
|-----|----------|-------------|
| 22 | `DICEMalloc(ctx, size)` | Allocate through ICE allocator |
| 9 | `DICEFree(ctx, ptr)` | Free ICE-allocated memory |
| 29 | `DICERealloc(ctx, ptr, size)` | Reallocate ICE memory |

#### Version

| Ord | Function | Description |
|-----|----------|-------------|
| 36 | `DICEVersion()` | Returns version string |

Version strings returned:
- ICEDLL.dll: `"ICE_Willow_030428_GM"` + `"Digital ICE 3.3.0.4012"`
- ICENKNL1.dll: `"durer_010817_ICE/Cedar_010817_ICE"` + `"Digital ICE 1.0.0.3005"`
- ICENKNX2.dll: `"durer_010817_ICE/Cedar_010817_ICE"` + `"Digital ICE 1.0.0.3005"`

### DICENew Variant Selection (from ICEDLL.dll disassembly at RVA 0x300E0)

```c
// Pseudocode from disassembly of DICENew in ICEDLL.dll
void* DICENew(int variant) {
    void* ctx = NULL;
    switch (variant) {
        case 7:  // L1B variant
            ctx = malloc(0x928E0);     // ~600KB context object
            CDICECoreNikonL1B_ctor(ctx);
            break;
        case 8:  // X3A variant
            ctx = malloc(0x928E0);
            CDICECoreNikonX3A_ctor(ctx);
            break;
        case 9:  // X3B variant
            ctx = malloc(0x928E0);
            CDICECoreNikonX3B_ctor(ctx);
            break;
        default:
            return NULL;  // Invalid variant
    }
    return ctx;
}
```

The context object is ~600,288 bytes (0x928E0). All three variants use the same allocation size, meaning they share the same base context layout but have different vtable pointers that dispatch to variant-specific algorithm code.

**ICENKNL1.dll** has a single variant (L1, likely code 1 or similar).
**ICENKNX2.dll** has two variants (LSA, LSB, likely codes 4 and 5).

---

## 8. ICE Algorithm Deep-Dive

### Core Processing Model

The DICE engine uses a **streaming row-based architecture** with lookahead:

```
Input Buffers (RGBI rows)          Output Buffers (RGB rows)
┌────────────────────┐             ┌────────────────────┐
│ Row N-K  (oldest)  │             │ Row M    (oldest)  │
│ Row N-K+1          │             │ Row M+1            │
│ ...                │   DICE      │ ...                │
│ Row N-1            │ ──Engine──> │ Row M+P-1          │
│ Row N   (newest)   │             │ Row M+P  (newest)  │
└────────────────────┘             └────────────────────┘
    Input queue                        Output queue
    (producer-consumer)                (producer-consumer)
```

The algorithm requires a **window of K input rows** before it can produce output for a given row. This is because defect detection and repair need spatial context in both horizontal and vertical directions. The exact window size depends on the algorithm variant:

- **L1/L1B**: Smaller window (faster, simpler repair)
- **X3A**: Medium window (better quality)
- **X3B**: Largest window (best quality, slowest)

### Algorithm Pipeline (Inferred from Class Architecture)

```
RGBI Input Row
    │
    ▼
CDICEDataConverter
    │  Convert 8/16-bit integer pixels to normalized floats [0.0, 1.0]
    │  Supported conversions from .data1 constants:
    │    255.0   → 8-bit  (0-255 range)
    │    1023.0  → 10-bit (0-1023 range)
    │    4095.0  → 12-bit (0-4095 range)
    │    65535.0 → 16-bit (0-65535 range)
    │
    ▼
CDICEBandLimiter
    │  Frequency band limiting / multi-resolution decomposition
    │  Separates image into frequency bands:
    │    - Low frequency: large-scale structure (film grain, image)
    │    - High frequency: fine detail + defects
    │  This helps isolate defects from image content
    │
    ▼
CDICEScaler
    │  Create scaled versions of the image for multi-scale analysis
    │  Used for detecting defects at multiple scales:
    │    - Full resolution: fine scratches
    │    - Downsampled: large dust particles, fingerprints
    │
    ▼
CSDCCoreAlg (variant-specific)
    │  The actual Surface Defect Correction algorithm
    │  Input: RGBI at all scales
    │  Steps:
    │
    │  1. DEFECT MAP CREATION from IR channel:
    │     ┌──────────────────────────────────────────────┐
    │     │ For each pixel (x, y):                       │
    │     │   ir_value = IR_channel[x, y]                │
    │     │   threshold = adaptive_threshold(x, y)       │
    │     │                                              │
    │     │   if ir_value < threshold:                   │
    │     │     defect_map[x, y] = 1   // defect!       │
    │     │     defect_strength[x, y] =                  │
    │     │       (threshold - ir_value) / threshold     │
    │     │   else:                                      │
    │     │     defect_map[x, y] = 0   // clean pixel   │
    │     └──────────────────────────────────────────────┘
    │     The IR channel shows LOW values where defects are
    │     (because dust/scratches block/scatter IR light).
    │     The threshold is adaptive to handle:
    │       - Film density variations (dense negatives vs thin positives)
    │       - Optical vignetting (edge falloff)
    │       - CCD response non-uniformity
    │
    │  2. DEFECT MAP REFINEMENT:
    │     - Morphological operations to connect nearby defect pixels
    │     - Small isolated defect pixels may be noise → remove
    │     - Scratch detection: linear features in the defect map
    │     - Edge detection: avoid marking film grain as defects
    │
    │  3. DEFECT REPAIR (inpainting):
    │     ┌──────────────────────────────────────────────┐
    │     │ For each defect pixel in each RGB channel:   │
    │     │   - Identify surrounding clean pixels        │
    │     │   - Interpolate from clean neighbors         │
    │     │   - Weight by distance and direction         │
    │     │   - Special handling for scratches (linear   │
    │     │     features: interpolate perpendicular to   │
    │     │     scratch direction)                       │
    │     │   - Blend repaired value with original based │
    │     │     on defect_strength (soft transition)     │
    │     └──────────────────────────────────────────────┘
    │
    │  Algorithms differ in repair quality:
    │    L1/L1B: Simple bilinear interpolation from 4 neighbors
    │    X3A:    Weighted directional interpolation (8+ neighbors)
    │    X3B:    Full inpainting with texture synthesis
    │    LSA/LSB: Optimized for higher resolution (8000/9000 DPI)
    │
    ▼
CDICEDataConverter (reverse)
    │  Convert normalized floats back to 8/16-bit integers
    │
    ▼
RGB Output Row (IR channel removed, defects repaired)
```

### The Defect Detection Algorithm (Detail)

The IR-based defect detection is the critical step. From the algorithm parameters embedded in ICEDLL.dll's `.data1` section:

**Threshold Parameters** (from floating-point constants at file offset 0x39034-0x39174):
- `2.5`, `2.75`, `3.0`: Defect detection sensitivity multipliers
- `1.875`: Default threshold factor
- `0.707107` (1/sqrt(2)): Diagonal distance normalization
- `0.3`, `0.425`: Blend weights for soft transitions
- `30.0`: Maximum defect size parameter
- `99999.0`: Sentinel for "infinite" threshold (disable detection)

**Multi-Scale Detection**:
The `CDICEScaler` creates downsampled versions of both the image and the IR channel. Defects are detected at each scale independently:
- Full resolution: catches fine scratches (1-2 pixel wide)
- 2x downsampled: catches medium dust particles
- 4x or more: catches large smudges and fingerprints

Detections at different scales are combined into a unified defect map.

**Adaptive Thresholding**:
The threshold for defect detection adapts to local image density. Dense negative film transmits less IR overall, so the absolute IR values are lower everywhere. The algorithm computes a local average IR value and sets the threshold relative to that average, preventing false positives in dense areas and false negatives in thin areas.

### Buffer Flow Model

```
Caller (LS5000.md3):

    while (scan_rows_remaining) {
        // Read RGBI row from scanner via SCSI READ
        scsi_read(DTC=0x00, rgbi_row, row_size);

        // Feed to ICE
        while (DICENeedInputBuff(ctx)) {
            DICEQueueInputBuff(ctx, rgbi_row);
        }

        // Process
        DICEProcess(ctx);

        // Retrieve cleaned output
        while (!DICENeedOutputBuff(ctx)) {
            rgb_row = DICEDequeueOutputBuff(ctx);
            // Send cleaned RGB to NikonScan4.ds
            deliver_to_host(rgb_row);
        }

        // Recycle consumed input buffers
        consumed = DICEDequeueInputBuff(ctx);
        if (consumed) reuse_buffer(consumed);
    }
```

---

## 9. SDC Core Algorithms

### Algorithm Variant Naming Convention

The "SDC" (Surface Defect Correction) algorithms are numbered and lettered:

| Algorithm | DLL | Variants | Era | Likely Approach |
|-----------|-----|----------|-----|-----------------|
| Alg20 | ICENKNX2 | LSA/LSB | 2001 | First-generation, large-format optimized |
| Alg30 | ICENKNX2 | LSA/LSB | 2001 | Second-generation (v3.0 = "30"?) |
| Alg31 | ICENKNX2 | LSA/LSB | 2001 | Variant of Alg30 |
| Alg32 | ICENKNX2 | LSA/LSB | 2001 | Variant of Alg30 |
| Alg33 | ICENKNX2 | LSA/LSB | 2001 | Variant of Alg30 |
| Alg36 | ICENKNL1 | L1 | 2001 | Basic single-pass, compact scanner |
| Alg37 | ICENKNL1 | L1 | 2001 | Variant of Alg36 |
| AlgL1B | ICEDLL | L1B | 2003 | Updated L1 ("B" revision) |
| AlgX3A | ICEDLL | X3A | 2003 | Advanced multi-pass, mid-range scanner |
| AlgX3B | ICEDLL | X3B | 2003 | Most advanced, "ICE-KR Alpha for X3B" |

### Algorithm Families

**L1 family** (L1, L1B): Single-pass algorithms optimized for speed. Simple interpolation for defect repair. The "B" revision in ICEDLL.dll likely adds improved edge handling.

**X3 family** (X3A, X3B): Multi-pass algorithms for maximum quality. X3A does directional interpolation from 8+ neighbors. X3B adds texture synthesis ("KR" = Kodak Research). The X3B variant has a build tag "ICE-KR Alpha for X3B", suggesting it was a Kodak Research prototype that was productized.

**LS family** (LSA, LSB): Optimized for the LS-8000/LS-9000 large-format scanners which produce much higher resolution scans. LSA may be for 35mm adapter at 8000 DPI, LSB for medium format.

### Multi-Algorithm Selection in ICENKNX2.dll

ICENKNX2.dll has **five** SDC algorithm implementations (Alg20, 30, 31, 32, 33) but only **two** variant codes (LSA, LSB). The CDICECoreNikonLSA and CDICECoreNikonLSB classes likely select different combinations of the five algorithms based on scan parameters (resolution, bit depth, film type):

```
CDICECoreNikonLSA → CSDCCoreAlg30 (default) or CSDCCoreAlg31 (fallback)
CDICECoreNikonLSB → CSDCCoreAlg32 (default) or CSDCCoreAlg33 (fallback)
CSDCCoreAlg20    → Legacy/compatibility mode for both LSA and LSB
```

---

## 10. DRAG Algorithm Deep-Dive (ROC + GEM)

### DRAGNKL1.dll Architecture

DRAGNKL1.dll (484KB, 48 exports, v2.0.0.14, 2003) implements both Digital ROC and Digital GEM in a single DLL. It embeds the ASF "tVec" vectorized math library for high-performance pixel operations.

Source tree: `C:\StarTeam\DFP\Software\vectorlibs\SRC\tVec\tVecLib\`

### ROC Algorithm (Restoration of Color)

ROC corrects color fading in old photographic film. Fading occurs because the dye layers in film degrade at different rates -- typically cyan dye fades fastest, followed by magenta, then yellow. This causes predictable color shifts.

**Processing Phases** (from embedded phase description strings):

```
Phase 1: Channel Acquisition
    "Acquire RED channel"
    "Acquire GREEN channel"
    "Acquire BLUE channel"
    → Receives per-channel image data, normalizes using statistics

Phase 2: Downsized Analysis
    "Create normalized, downsized, median filtered image"
    → Creates small version with median filtering to remove noise
    → Used for overall color/density analysis

Phase 3: Fade Analysis
    "Determine Fade Correction Color Leakage values"
    → Measures inter-channel dye cross-talk from fading
    → Quantifies how much each dye layer has degraded
    → Computes correction matrix

Phase 4: ROC Application
    "Apply ROC then Build and Apply Localcolor and Hist leveling LUTs"
    → Applies global color correction from fade analysis
    → Builds spatially-varying (local) color correction LUTs
    → Applies histogram leveling to restore dynamic range
    → Strength controlled by SetROCAdjustment()
```

**ROC Algorithm Pseudocode**:

```python
def roc_process(image_rgb, roc_strength):
    # 1. Normalize image (per-channel mean/variance)
    stats = gather_statistics(image_rgb)
    normalized = normalize(image_rgb, stats)

    # 2. Create downsampled analysis image
    downsized = median_filter(downsample(normalized), kernel=5)

    # 3. Measure fade (color leakage between channels)
    # Faded film has channel cross-contamination:
    #   observed_R = true_R + leak_GR * true_G + leak_BR * true_B
    #   observed_G = leak_RG * true_R + true_G + leak_BG * true_B
    #   observed_B = leak_RB * true_R + leak_GB * true_G + true_B
    leakage_matrix = measure_color_leakage(downsized)

    # 4. Apply correction
    fade_corrected = apply_inverse_matrix(normalized, leakage_matrix)

    # 5. Build local color correction LUTs
    local_luts = build_spatially_varying_luts(fade_corrected, downsized)

    # 6. Apply local correction + histogram leveling
    result = apply_luts(fade_corrected, local_luts)
    result = histogram_level(result)

    # 7. Blend with original based on strength
    output = blend(image_rgb, result, roc_strength)
    return unnormalize(output, stats)
```

### GEM Algorithm (Grain Equalization and Management)

GEM reduces visible film grain while preserving image detail. Film grain is a random pattern caused by silver halide crystals in the emulsion. It is visible in high-resolution scans, especially in shadow areas where grain is coarser.

**Processing Phases**:

```
Phase 3 (Grain Analysis):
    "Measure Grain Strength vs Density"
    → Maps grain amplitude as function of image density
    → Grain is typically stronger in mid-tones, weaker in highlights

    "Measure 3x3 Freq vs. Mag"
    "Track Max 3x3 Freq vs. Mag"
    → 2D FFT analysis of image blocks
    → Characterizes grain's spatial frequency spectrum
    → Grain has a characteristic frequency signature

    "Measure 3x3 Freq vs. Mag weighted by Grain Strength"
    "Track Max 3x3 Freq vs. Mag weighted by Grain Strength"
    → Weighted analysis: prioritizes grain-heavy regions
    → Builds a density-dependent grain model

Phase 8 (Combined ROC+GEM):
    "Apply grain reduction, ROC, Local Color"
    → Applies grain reduction SIMULTANEOUSLY with ROC
    → Prevents ROC from amplifying grain

Phase 9 (GEM-only):
    "Apply grain reduction only. Unnormalize the result."
    → For GEM-only mode (no ROC)
    → Controlled by SetGrainResidue()
```

**GEM Algorithm Pseudocode**:

```python
def gem_process(image_rgb, gem_strength):
    # 1. FFT-based grain model
    for block in image_blocks(size=32):
        fft = fft_2d(block)
        density = mean_density(block)
        grain_spectrum[density] += magnitude(fft)
        grain_count[density] += 1

    # 2. Average grain spectrum per density
    grain_model = grain_spectrum / grain_count

    # 3. For each block, subtract estimated grain
    for block in image_blocks(size=32):
        fft = fft_2d(block)
        density = mean_density(block)
        estimated_grain = grain_model[density] * gem_strength
        cleaned_fft = fft - estimated_grain  # spectral subtraction
        cleaned_block = ifft_2d(cleaned_fft)
        output_block = blend(block, cleaned_block, gem_strength)

    # 4. Edge fixup (prevent block boundary artifacts)
    fixup_edges(output)
    return output
```

### FFT Functions (exported for external use)

| Function | Purpose |
|----------|---------|
| `Exported_Complex_2D_FLPT_FFT()` | Forward 2D FFT on image block |
| `Exported_Complex_2D_FLPT_FFT_New()` | Newer FFT variant (L1 only) |
| `Exported_Complex_2D_FLPT_IFFT()` | Inverse 2D FFT for reconstruction |
| `Exported_ArrangeForFFT()` | Prepare pixel data layout for FFT input |
| `Exported_ArrangeForDRAG()` | Rearrange FFT output for DRAG processing |

### Scanner Revelation Mask (L1-only feature)

The "Revelation" system is a scanner-specific correction that uses a pre-computed mask:

```
SetREVPreview()          -- Fast approximate mode for preview
SetREV_DH_Adjustment()   -- Dark-Highlight correction strength
SetREV_GT_Adjustment()   -- Gray-Tone correction
SetREV_SB_Adjustment()   -- Shadow-Brightness correction
```

Phase descriptions:
- `"Create downsized sandblasted mask"` -- "Sandblasting" creates a spatially-varying defect map that identifies systematic artifacts (consistent CCD defects, optical anomalies)
- `"Apply Scanner Revelation Mask and LUT"` -- Applies scanner-specific correction data
- `"Apply DSC/UNK Revelation Mask and LUT"` -- Applies generic digital scanner correction

NikonScan4.ds wraps this in the `CNkRevelation` RTTI class and `CREVProcess` / `CRevProcessCommand` command objects.

### tVec Vector Library (embedded in DRAGNKL1.dll)

A comprehensive SIMD-optimized math library for pixel processing. Key function categories:

| Category | Functions | Purpose |
|----------|-----------|---------|
| **Conversion** | tVecUCtoNF, tVecUStoNF, tVecNFtoUC, tVecNFtoUS | 8/16-bit ↔ normalized float |
| **Interleave** | tVecInterleaveNRGBUC/US, tVecUCInterleaveRGB | Planar ↔ interleaved conversion |
| **Convolution** | tVec2DConv3x3, tVecConv1x7/1x9/1x19, tVecConvnx1/19x1xN | Spatial filtering (separable and non-separable) |
| **Decimation** | tVecDecimateByN/UC/US, tVec2DDecimate, tVecDownsample | Multi-scale pyramid creation |
| **Undecimation** | tVec2DUndecimate, tVecUpsample | Image reconstruction from pyramid |
| **Median** | tVecMed3x3/5x5, tVecMedian, tVecCenterWeightedMed5x5 | Noise reduction |
| **Min/Max** | tVec2DMax17x17/19x19, tVec2DMin17x17/19x19 | Large-kernel morphological operations |
| **FFT** | (via Exported_ functions) | Frequency-domain grain analysis |
| **Statistics** | tVecHist, tVecHistN, tVecIntegrate2D, tVecSigma, tVecMean | Image statistics |
| **Math** | tVecScMult, tVecVcAdd/Sub/Mult/Div, tVecPow, tVecLog | Pixel arithmetic |
| **Blending** | tVecMaskedBlend, tVecMaskedBlendClip, tVecWeightedSumOf2/3/4Vc | Compositing |
| **Threshold** | tVecThresholdHigh/Low, tVecVcCompare, tVecVcSelectGT | Binary masking |
| **Lookup** | tVecLookUp | LUT application |
| **Scale** | tVecScaleBicubInt, tVecScaleImage, tVecResampleH/V | Resampling |
| **Warp** | tVecWarpRow | Geometric transformation |
| **Rotation** | tVecRotateCCW90/CW90 (UC/US/float variants) | Image rotation |

---

## 11. DLL-to-Scanner Mapping

### Which DLL is Used for Which Scanner

LS5000.md3 dynamically loads the ICE DLL. The DLL filename is NOT stored as a static string in LS5000.md3. Instead, it is determined at runtime by:

1. Reading the Windows registry key `Software\Microsoft\Windows\CurrentVersion` → `CommonFilesDir`
2. Appending `\Nikon` to get the common files path
3. Selecting the DLL based on scanner model capabilities

From the DLL internal comments and scanner model analysis:

| Scanner | Module | ICE DLL | Variant Code | Algorithm |
|---------|--------|---------|-------------|-----------|
| **LS-40** (PID 4000) | LS4000.md3 | ICENKNL1.dll | L1 | CSDCCoreAlg36/37 |
| **LS-50** (PID 4001) | LS5000.md3 | ICEDLL.dll | 7 (L1B) or 8 (X3A) or 9 (X3B) | CSDCCoreAlgL1B/X3A/X3B |
| **LS-5000** (PID 4002) | LS5000.md3 | ICEDLL.dll | 8 (X3A) or 9 (X3B) | CSDCCoreAlgX3A/X3B |
| **LS-4000** (1394) | LS4000.md3 | ICENKNL1.dll | L1 | CSDCCoreAlg36/37 |
| **LS-8000** (1394) | LS8000.md3 | ICENKNX2.dll | LSA or LSB | CSDCCoreAlg30-33 |
| **LS-9000** (1394) | LS9000.md3 | ICENKNX2.dll | LSA or LSB | CSDCCoreAlg30-33 |

**Variant selection logic** (inferred from NikonScan4.ds UI and DICENew analysis):

- **Normal ICE**: X3A (variant 8) -- standard quality, reasonable speed
- **Fine ICE**: X3B (variant 9) -- highest quality, slower
- **Basic ICE** (LS-40): L1 (variant from ICENKNL1.dll) -- fastest, basic quality

The LS-50 and LS-5000 share the same module (LS5000.md3) and the same ICE DLL (ICEDLL.dll), but the LS-5000 may default to X3B while the LS-50 defaults to X3A or L1B.

### DLL Loading Mechanism

From LS5000.md3 binary analysis:
1. `GetModuleFileNameA` -- get the module's own path
2. Registry lookup: `Software\Microsoft\Windows\CurrentVersion` → `CommonFilesDir`
3. Path construction: `<CommonFilesDir>\Nikon\<ICE_DLL_name>`
4. `LoadLibraryA` -- load the ICE DLL
5. `GetProcAddress` for each of the 18 DICE functions used:
   ```
   DICENew, DICELoad, DICEInit, DICEBegin, DICEProcess, DICEEnd,
   DICEComplete, DICEUnload, DICEDelete, DICEAbort, DICEVersion,
   DICEQueueInputBuff, DICEDequeueInputBuff, DICENeedInputBuff,
   DICEQueueOutputBuff, DICEDequeueOutputBuff, DICENeedOutputBuff,
   DICEGetDefectPercent
   ```

Note: Only 18 of the 36 DICE exports are used by LS5000.md3. The unused ones are:
- Parameter get/set functions (DICESet/GetFloatParameter, IntParameter, PtrParameter)
- Overflow buffer management
- Multi-frame functions
- Memory management functions (DICEMalloc, DICEFree, DICERealloc)
- DICEUseDefaultParameters

This means LS5000.md3 uses **only default parameters** -- it never customizes the ICE algorithm parameters. The algorithm variant selection via DICENew is the only configuration point.

---

## 12. LS5000.md3 ICE Integration

### MAID Capability Flow

```
NikonScan4.ds UI: User enables "Digital ICE"
    │
    ▼
NikonScan4.ds: Set MAID cap 0x800C = true
    │  via vtable[23](obj, 6, 0x800C, 1, true, 0, 0)
    │  (opcode 6 = set capability, type 1 = boolean)
    │
    ▼
LS5000.md3: Cap 0x800C handler in capability tree
    │  Object type 0x1022 (kNkMAIDCapType_ICE)
    │  Stores ICE enable flag in scanner state
    │
    ▼
LS5000.md3: SET WINDOW builder (FUN_100b2b30)
    │  Checks scanner_state+0x84 == 1 (ICE present)
    │  Writes ICE/DRAG extension area:
    │    - Master enable byte (MAID param 0xa20)
    │    - Per-ICE parameter list
    │
    ▼
LS5000.md3: SCAN command issued
    │  Firmware selects ICE task group (0x084x/086x/088x)
    │  instead of non-ICE group (0x083x/085x/087x)
    │
    ▼
LS5000.md3: READ loop receives RGBI data
    │  4 channels instead of 3
    │
    ▼
LS5000.md3: DICE processing
    │  Feeds RGBI → gets cleaned RGB
    │
    ▼
NikonScan4.ds: Receives cleaned RGB for DRAG/Strato
```

### ICE Processing Integration Code Path

```
LS5000.md3 scan data read loop (inline CDB builders at
    0x100866d9, 0x10086dfa, 0x1008781a):

    1. SCSI READ (DTC=0x00) → RGBI row data from scanner

    2. If ICE enabled (scanner_state+0x84 == 1):
       a. Load ICE DLL if not already loaded
          - LoadLibraryA("<CommonFilesDir>\Nikon\<ICE_DLL>")
          - GetProcAddress for 18 functions
       b. DICENew(variant_code) -- variant from scanner model config
       c. DICELoad(ctx, ...) -- load default algorithm parameters
       d. DICEInit(ctx, width, height, bpp, channels)
       e. DICEBegin(ctx)
       f. For each scan line:
          - DICEQueueInputBuff(ctx, rgbi_row)
          - DICEProcess(ctx)
          - If DICENeedOutputBuff(ctx) == false:
              rgb_row = DICEDequeueOutputBuff(ctx)
              → pass to output
          - recycled = DICEDequeueInputBuff(ctx)
       g. DICEEnd(ctx)
       h. defect_pct = DICEGetDefectPercent(ctx)
       i. DICEComplete(ctx)
       j. DICEUnload(ctx)
       k. DICEDelete(ctx)
       l. FreeLibrary(hDll)

    3. If ICE NOT enabled:
       - Pass RGB data (3 channels) directly to output
```

---

## 13. NikonScan4.ds DRAG Integration

### DRAG Command Queue System

NikonScan4.ds wraps DRAG processing in an MFC command queue:

```
RTTI Classes:
    CDRAGBase              -- Holds DRAG context handle
    CDRAGProcess           -- Main coordinator
    CDRAGPrepareCommand    -- DRAGNew → DRAGLoad → DRAGInit
    CDRAGProcessCommand    -- DRAGBegin → DRAGProcess loop → DRAGEnd
    CDRAGProcessCommandQueue -- Sequence manager
    CQueueAcquireDRAGImage -- Combines scan + DRAG processing

    CREVProcess            -- Revelation mask processing
    CRevProcessCommand     -- Revelation command
    CNkRevelation          -- Revelation data manager
```

Import thunks at `NikonScan4.ds:0x1011DA26-0x1011DA68` (11 DRAG functions as 6-byte jmp thunks).

### DRAG Processing Flow in NikonScan4.ds

```
CQueueAcquireDRAGImage execution:
    │
    ├── CDRAGPrepareCommand
    │   └── DRAGNew() → DRAGLoad() → DRAGInit()
    │       DRAGSetStatisticsImageInfo()
    │
    ├── CDRAGProcessCommand
    │   └── DRAGBegin()
    │       Loop:
    │         DRAGSetAvailableInputRow(ctx, row_number)
    │         DRAGProcess(ctx)
    │         DRAGGetCurrentInputRow(ctx)
    │         DRAGGetCurrentOutputRow(ctx)
    │       DRAGEnd()
    │
    ├── CRevProcessCommand (optional, L1 scanner only)
    │   └── REV mask application
    │       SetREVPreview(), SetREV_DH_Adjustment(),
    │       SetREV_GT_Adjustment(), SetREV_SB_Adjustment()
    │
    └── DRAGComplete() → DRAGUnload() → DRAGDelete()
```

The `CProcessCommandManager` coordinates command execution with the MFC message pump (`FUN_100148b0`) to keep the NikonScan UI responsive during processing.

### DRAG Data Format

| Parameter | Value |
|-----------|-------|
| **Input** | RGB, interleaved or planar, 8-bit or 16-bit per channel |
| **Output** | Same dimensions and format as input |
| **Processing** | Row-by-row with vertical lookahead/lookbehind for spatial analysis |
| **ROC strength** | `SetROCAdjustment()` -- 0.0 to 1.0 |
| **GEM strength** | `SetGrainResidue()` -- 0.0 to 1.0 |

---

## 14. Algorithm Parameter Tables

### ICEDLL.dll Internal Parameter Tables

From the `.data1` section of ICEDLL.dll, the algorithm constants are organized as parameter blocks. Each block corresponds to a set of tuning parameters for a specific algorithm aspect:

**Bit Depth Configuration** (offset 0x134-0x144):
| Float Value | Integer | Meaning |
|-------------|---------|---------|
| 255.0 | 0x437F0000 | 8-bit pixel max value |
| 1023.0 | 0x447FC000 | 10-bit pixel max value |
| 4095.0 | 0x4587F800 | 12-bit pixel max value |
| 65535.0 | 0x477FFF00 | 16-bit pixel max value |

**Defect Detection Parameters** (offset 0x034-0x0DC):
| Value | Likely Purpose |
|-------|---------------|
| 2.500 | Threshold multiplier (standard sensitivity) |
| 2.750 | Threshold multiplier (high sensitivity) |
| 3.000 | Threshold multiplier (low sensitivity / fewer false positives) |
| 1.875 | Default threshold factor |
| -0.500 | Negative offset for threshold calculation |
| -0.667 | Two-thirds negative ratio |
| 0.500 | Half-weight blend factor |
| 0.170 | Fine-detail sensitivity weight |
| 0.140 | Fine-detail secondary weight |
| 0.707 | 1/sqrt(2): diagonal normalization |
| 0.300 | Soft blend transition width |
| 0.425 | Repair blend weight |
| -0.125 | Negative correction offset |

**Defect Repair Parameters** (offset 0x108-0x174):
| Value | Likely Purpose |
|-------|---------------|
| 30.0 | Maximum defect diameter (pixels) |
| 99999.0 | Sentinel: disable detection |
| 1.375 | Interpolation weight A |
| 1.625 | Interpolation weight B |
| 30.0 | Maximum repair radius |

**Vtable Pointers** (offset 0x180-0x1A8):
10 function pointers for the selected algorithm variant's methods:
- `0x100047C0`: Method 0 (likely: initialize core)
- `0x10003040`: Method 1 (likely: process_line)
- `0x10003070`: Method 2 (likely: detect_defects)
- `0x10003210`: Method 3 (likely: repair_defects)
- `0x10004780`: Method 4 (likely: finalize)
- `0x10003250`: Method 5 (likely: scale_up)
- `0x10003690`: Method 6 (likely: blend_output)
- `0x10003640`: Method 7 (likely: compute_threshold)
- `0x100036F0`: Method 8 (likely: morphological_ops)
- `0x10004610`: Method 9 (likely: statistics)

### DRAGNKL1.dll Processing Phase Strings

Complete list of phase description strings (used internally for debug/progress reporting):

| Phase | String | Algorithm Step |
|-------|--------|----------------|
| 1a | "Acquire RED channel" | Load R channel |
| 1b | "Acquire GREEN channel" | Load G channel |
| 1c | "Acquire BLUE channel" | Load B channel |
| 2 | "Create normalized, downsized, median filtered image" | Analysis image creation |
| 3a | "Measure Grain Strength vs Density" | GEM: grain-density relationship |
| 3b | "Measure 3x3 Freq vs. Mag" | GEM: FFT grain spectrum |
| 3c | "Measure 3x3 Freq vs. Mag weighted by Grain Strength" | GEM: weighted FFT |
| 3d | "Track Max 3x3 Freq vs. Mag" | GEM: peak tracking |
| 3e | "Track Max 3x3 Freq vs. Mag weighted by Grain Strength" | GEM: weighted peak tracking |
| 4 | "Create downsized sandblasted mask" | REV: defect/anomaly mask |
| 5a | "Apply Scanner Revelation Mask and LUT" | REV: scanner-specific correction |
| 5b | "Apply DSC/UNK Revelation Mask and LUT" | REV: generic DSC correction |
| 6 | "Determine Fade Correction Color Leakage values" | ROC: fade analysis |
| 7 | "Apply ROC then Build and Apply Localcolor and Hist leveling LUTs" | ROC: correction application |
| 8 | "Apply grain reduction, ROC, Local Color" | Combined ROC+GEM |
| 9a | "Apply Localcolor and Hist leveling LUTs" | ROC: LUT-only application |
| 9b | "Apply grain reduction only. Unnormalize the result." | GEM: grain-only mode |
| 10 | "Apply various corrections" | Final cleanup pass |

Additional internal strings:
| String | Purpose |
|--------|---------|
| "NRA Process RED/GREEN/BLUE channel" | Normalization/Restoration/Adjustment per channel |
| "Histogram" | Histogram computation step |
| "applyMaskMono" | Apply binary mask to monochrome data |
| "createMaskPyramid" | Build multi-resolution mask pyramid |
| "Bad value passed in for gray level" | Error: invalid parameter |
| "@Zero value in mask" | Warning: division-by-zero protection |

---

## 15. Implementation Notes for Driver Developers

### Minimal ICE Implementation (for an open-source driver)

To implement basic Digital ICE functionality without the proprietary DICE library:

```python
def simple_ice(rgbi_image):
    """
    Minimal ICE implementation.
    Input: RGBI image (H x W x 4), uint16
    Output: RGB image (H x W x 3), uint16
    """
    R, G, B, IR = rgbi_image[:,:,0], rgbi_image[:,:,1], \
                   rgbi_image[:,:,2], rgbi_image[:,:,3]

    # 1. Normalize IR channel
    ir_float = IR.astype(float) / IR.max()

    # 2. Compute adaptive threshold
    #    Use local mean of IR as baseline
    from scipy.ndimage import uniform_filter
    ir_local_mean = uniform_filter(ir_float, size=31)
    threshold = ir_local_mean * 0.7  # 70% of local mean

    # 3. Create defect map
    defect_map = ir_float < threshold
    defect_strength = np.clip(
        (threshold - ir_float) / (threshold + 1e-6), 0, 1
    )
    defect_strength[~defect_map] = 0

    # 4. Dilate defect map slightly (connect nearby pixels)
    from scipy.ndimage import binary_dilation
    defect_map = binary_dilation(defect_map, iterations=1)

    # 5. Repair defects by inpainting
    #    For each defect pixel, interpolate from nearest clean neighbors
    output = np.stack([R, G, B], axis=-1).astype(float)

    from scipy.ndimage import generic_filter
    for ch in range(3):
        # Simple: replace defect pixels with local median of clean pixels
        channel = output[:,:,ch].copy()
        clean_channel = channel.copy()
        clean_channel[defect_map] = np.nan

        # Use NaN-aware median filter
        repaired = nan_median_filter(clean_channel, size=5)
        # Blend: smooth transition at defect boundaries
        output[:,:,ch] = (
            channel * (1 - defect_strength) +
            repaired * defect_strength
        )

    return output.astype(np.uint16)
```

### Key SCSI Commands for ICE

| Step | Command | Parameters |
|------|---------|------------|
| 1. Enable ICE | SET WINDOW (0x24) | ICE/DRAG extension area, master enable=1 |
| 2. Start scan | SCAN (0x1B) | Firmware selects ICE task group automatically |
| 3. Read data | READ (0x28) | DTC=0x00, returns RGBI (4 channels) |
| 4. Process | Host-side | DICE library or custom algorithm |

### Data Format Details

| Parameter | Value |
|-----------|-------|
| CCD elements | 4095 active per line (from characterization data) |
| Active pixels | 665 (0x0299) per channel after margins |
| Bit depth | 14-bit CCD data in 16-bit words (MSB-aligned) |
| Channels | 4 (RGBI), interleaved per-pixel in transfer |
| Byte order | Big-endian (SCSI/Motorola convention) |
| IR wavelength | ~940nm (near-IR, silicon CCD sensitive range) |

### Alternative: Skip ICE, Export RGBI

For an open-source driver, the simplest approach is to:
1. Configure the scanner for 4-channel RGBI scan
2. Read raw RGBI data via SCSI READ
3. Save the IR channel as a separate file
4. Let users process with their preferred tool (Photoshop, GIMP, etc.)

This preserves maximum flexibility and avoids reimplementing proprietary algorithms.

### Common Pitfalls

1. **Do NOT assume the IR channel is a binary mask.** It is a grayscale image. Defects cause reduced transmission, but the degree varies. Use the IR channel as a continuous defect strength map.

2. **Film density affects IR transmission.** Dense negatives transmit less IR overall. The threshold must be adaptive to local density, not a fixed value.

3. **Some film types block IR completely.** Kodachrome is notably opaque to infrared due to its unique dye chemistry. ICE does not work with Kodachrome. The scanner reports film type via VPD pages and the adapter detection system.

4. **The IR CCD line is physically offset** from the RGB lines on the chip. The firmware compensates for this offset during DMA programming (F4 at `FW:0x411E8`), but if you are implementing a custom firmware or bypassing the standard pipeline, you must account for this line delay.

5. **ICE processing roughly doubles scan time** because the scanner must capture 4 channels instead of 3, and the host must run the defect correction algorithm.

---

## Related KB Documents

- [ICE Overview](../components/ice/overview.md) -- DLL variant comparison and DICE API summary
- [DRAG API Reference](../components/dragnkl1/api.md) -- All 48 DRAG exports with signatures
- [DRAG Processing Pipeline](../components/dragnkl1/pipeline.md) -- Phase-by-phase DRAG algorithm flow
- [Scan Data Pipeline](../components/firmware/scan-pipeline.md) -- CCD → ASIC → USB firmware pipeline
- [Scan State Machine](../components/firmware/scan-state-machine.md) -- Task groups including ICE variants
- [Lamp/LED Control](../components/firmware/lamp-control.md) -- IR LED and visible LED control
- [Calibration](../components/firmware/calibration.md) -- CCD calibration including IR channel
- [SET WINDOW Descriptor](../scsi-commands/set-window-descriptor.md) -- ICE/DRAG extension area in SET WINDOW
- [READ Command](../scsi-commands/read.md) -- DTC=0x00 for RGBI image data
- [SCAN Command](../scsi-commands/scan.md) -- Scan operation types and ICE task groups
- [Scan Workflows](../components/nikonscan4-ds/scan-workflows.md) -- MAID capability 0x800C for ICE enable
- [Film Adapters](../components/firmware/film-adapters.md) -- Adapter-specific ICE behavior
