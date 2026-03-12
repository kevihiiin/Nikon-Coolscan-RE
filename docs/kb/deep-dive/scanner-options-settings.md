# Scanner Options & Settings -- Complete Reference

**Status**: Complete
**Last Updated**: 2026-03-12
**Phase**: Cross-cutting (Phases 1-7)
**Confidence**: High (decompiled from LS5000.md3, NikonScan4.ds, firmware; cross-validated)

## Purpose

This document catalogs EVERY user-configurable option, setting, and configuration in the
Nikon Coolscan NikonScan 4.03 software, from the user-visible UI down to the SCSI byte
encoding sent to the scanner firmware. A driver developer can use this document to
implement a complete scan configuration UI.

---

## Table of Contents

1. [Architecture: How Settings Flow](#1-architecture-how-settings-flow)
2. [Scan Parameters (SET WINDOW)](#2-scan-parameters-set-window)
3. [Resolution](#3-resolution)
4. [Bit Depth](#4-bit-depth)
5. [Color Mode / Image Composition](#5-color-mode--image-composition)
6. [Scan Area / Crop](#6-scan-area--crop)
7. [Film Type](#7-film-type)
8. [Multi-Sample Scanning](#8-multi-sample-scanning)
9. [Analog Gain / Exposure](#9-analog-gain--exposure)
10. [Focus / Autofocus](#10-focus--autofocus)
11. [Scan Direction](#11-scan-direction)
12. [Brightness / Contrast / Threshold](#12-brightness--contrast--threshold)
13. [Digital ICE (Dust/Scratch Removal)](#13-digital-ice-dustscratch-removal)
14. [Digital ROC (Color Restoration)](#14-digital-roc-color-restoration)
15. [Digital GEM (Grain Reduction)](#15-digital-gem-grain-reduction)
16. [Unsharp Mask (USM)](#16-unsharp-mask-usm)
17. [Curves / LUT Editor](#17-curves--lut-editor)
18. [Color Management (CMS)](#18-color-management-cms)
19. [Gamma Correction](#19-gamma-correction)
20. [Batch Scanning](#20-batch-scanning)
21. [Film Adapter / Auto-Feeder](#21-film-adapter--auto-feeder)
22. [Preference Tabs (Persistent Settings)](#22-preference-tabs-persistent-settings)
23. [Settings Save/Load](#23-settings-saveload)
24. [Vendor Extension Parameters](#24-vendor-extension-parameters)
25. [ICE/DRAG Extension Parameters](#25-icedrag-extension-parameters)
26. [Hidden / Internal Settings](#26-hidden--internal-settings)
27. [Model Differences (LS-50 vs LS-5000)](#27-model-differences-ls-50-vs-ls-5000)
28. [Complete MAID Capability ID Table](#28-complete-maid-capability-id-table)
29. [Complete SET WINDOW Byte Map](#29-complete-set-window-byte-map)

---

## 1. Architecture: How Settings Flow

```
User clicks UI control
    |
    v
NikonScan4.ds (CToolDlg* / CPrefTab* dialog classes)
    |  Fresco SDK API (exported functions)
    v
CTwainMaidImage::vtable[23] thunk (0x10070500)
    |  MAID opcode 6 = Set Capability
    v
CFrescoMaidModule::CallMAID (0x1007A1F0)
    |  calls MAIDEntryPoint loaded from LS5000.md3
    v
LS5000.md3 MAIDEntryPoint (0x100298F0)
    |  16-case switch -> capability object tree
    v
Capability Object vtable dispatch
    |  looks up param in std::map<short, ParamObject*>
    v
SET WINDOW builder (0x100B2B30, 1268 bytes)
    |  reads all params, builds 54+ byte descriptor
    v
SCSI CDB 0x24 SET WINDOW via NkDriverEntry FC5
    |
    v
Scanner firmware (H8/3003) receives and applies
```

Three main paths for settings to reach hardware:
- **SET WINDOW** (0x24): Resolution, area, bit depth, color mode, multi-sample, vendor extensions, ICE
- **MODE SELECT** (0x15): Mode page 0x03 (base resolution, max scan area)
- **Vendor E0/C1/E1**: Focus position, exposure time, lamp control

---

## 2. Scan Parameters (SET WINDOW)

The SET WINDOW command (SCSI opcode 0x24) is the primary vehicle for scan configuration.
It sends a Window Descriptor to the scanner containing all parameters for the upcoming scan.

**CDB**: `24 00 00 00 00 00 LL LL LL 80` (LL = 24-bit big-endian transfer length)

The descriptor has three sections:
1. **Standard SCSI fields** (bytes 0-53, fixed)
2. **Vendor extension area** (bytes 54+, dynamic, self-described by scanner)
3. **ICE/DRAG extension area** (after vendor extensions, if scanner supports ICE)

Total size = 54 + vendor_ext_size + ice_drag_size

Source: `LS5000.md3:0x100B2B30` (builder), `LS5000.md3:0x100B3A50` (prepare)

---

## 3. Resolution

| Property | Value |
|----------|-------|
| **UI Location** | Main scan window, resolution dropdown |
| **MAID Param IDs** | 0x121 (X resolution), 0x122 (Y resolution) |
| **SET WINDOW Offset** | Bytes 10-11 (X), 12-13 (Y) |
| **Encoding** | Big-endian 16-bit unsigned, in DPI |
| **Optical Maximum** | 4000 DPI (Coolscan V LS-50) |
| **MODE SENSE Default** | 1200 DPI (flash `FW:0x0168AF`) |
| **Max Scan Area** | 4000 units in both X and Y (from MODE SENSE page 0x03) |
| **Common Values** | 4000, 2700, 2000, 1350, 1000, 675, 500, 338, 250 DPI |
| **Minimum (multi-frame)** | 2000 DPI enforced by scan orchestrator |
| **X and Y independent** | Yes, separate fields, but typically set equal |

**Firmware behavior**: Resolution determines motor speed via formula: `(scan_resolution + 2) * 0x6C6`. Result stored at RAM `@0x400D8E`.

**API**: `GetSampleSize` (ordinal 34) returns current sample size based on resolution.

Source: `LS5000.md3:0x100B2B30` at offset +10, firmware `FW:0x026E38`

---

## 4. Bit Depth

| Property | Value |
|----------|-------|
| **UI Location** | Toolbar / Options menu |
| **MAID Param ID** | 0x126 |
| **SET WINDOW Offset** | Byte 34 |
| **Encoding** | Single byte, direct value |
| **Valid Values** | 8, 14, 16 |

| Value | Meaning | Data Size per Channel |
|-------|---------|-----------------------|
| 8 | 8-bit per channel | 1 byte |
| 14 | 14-bit per channel (native CCD depth) | 2 bytes (padded to 16) |
| 16 | 16-bit per channel | 2 bytes |

**API**:
- `GetBitDepthCount` (ordinal 10): Number of available bit depths
- `GetBitDepthItem` (ordinal 11): Get bit depth value by index
- `SelectBitDepthItem` (ordinal 45): Select a bit depth

**TWAIN types**: Enumeration containers `TNkTwainNumericEnumeration<E,$02>` (unsigned char enum, type 2 = uint8)

Source: `LS5000.md3:0x100B2B30` at offset +0x22

---

## 5. Color Mode / Image Composition

| Property | Value |
|----------|-------|
| **UI Location** | Main window color mode selector |
| **MAID Param IDs** | 0x125 (image composition), 0x128 (color filter) |
| **SET WINDOW Offset** | Byte 33 (composition), Byte 48 high nibble (color filter) |
| **Halftone** | 0x127 at Byte 35 and Byte 48 low nibble |

### Image Composition Values (Byte 33, MAID 0x125)

| Value | Mode |
|-------|------|
| 0 | Line art (binary / B&W) |
| 1 | Halftone (dithered) |
| 2 | Grayscale |
| 5 | Color (RGB) |

### Color Filter / Composition Composite (Byte 48)

Byte 48 is composed: `(param_0x128 << 4) | (param_0x127 & 0xF)`

- **High nibble** (0x128): Color filter mode (0=none, others vendor-specific)
- **Low nibble** (0x127): Halftone pattern code

**API**:
- `GetColorSpaceCount` (ordinal 17): Number of available color spaces
- `GetColorSpaceItem` (ordinal 18): Get color space by index
- `SelectColorSpaceItem` (ordinal 46): Select a color space

**TWAIN types**: Enumeration containers for signed short (type 1), unsigned short (types 3, 5)

Source: `LS5000.md3:0x100B2B30` at offsets +0x21, +0x30

---

## 6. Scan Area / Crop

| Property | Value |
|----------|-------|
| **UI Location** | CToolDlgCrop, preview window drag-select |
| **MAID Param ID** | 0x123 (composite scan area object) |
| **MAID Cap ID** | 0x801B (ROI/scan area bounds, opcode 7 = get) |
| **SET WINDOW Offset** | Bytes 14-29 |
| **Encoding** | 4 x big-endian 32-bit unsigned, in scanner units |
| **Scanner Units** | Typically 1/DPI inches (at current resolution) |

### Byte Layout

| Offset | Size | Field | Area Index | Getter |
|--------|------|-------|------------|--------|
| 14-17 | 4 | Upper Left X | 1 | `FUN_100a09e0` |
| 18-21 | 4 | Upper Left Y | 0 | `FUN_100a0990` |
| 22-25 | 4 | Width | 3 | `FUN_100a0a80` |
| 26-29 | 4 | Height | 2 | `FUN_100a0a30` |

The scan area object at MAID param 0x123 has a vtable with methods for each dimension:
- `[+0x54]` = Y-top, `[+0x58]` = X-left, `[+0x5c]` = height, `[+0x60]` = width

**Maximum scan area** (from MODE SENSE page 0x03): 4000 x 4000 units at default resolution.

**UI class**: `CToolDlgCrop` -- crop rectangle tool dialog

Source: `LS5000.md3:0x100AEEB0`, `LS5000.md3:0x100B2B30` at offsets +0x0E to +0x1D

---

## 7. Film Type

| Property | Value |
|----------|-------|
| **UI Location** | Film type dropdown in main window |
| **MAID Param ID** | 0x103 (vendor extension, dynamically registered) |
| **SET WINDOW Offset** | Vendor extension area (byte 54+), dynamic position |
| **Encoding** | Dynamic size (1, 2, or 4 bytes), big-endian |
| **Registration** | Conditional on scanner GET WINDOW flags_1 bit 3 |

### Known Film Types

The scan orchestrator (`NikonScan4.ds:0x1003B200`) checks `[source+0x1C]` for film type. Value 4 indicates negative film, which triggers an exposure warning dialog.

Film type also affects MODE SELECT parameters (sent via separate SCSI command path, not just SET WINDOW).

**API**:
- `GetFilmTypeCount` (ordinal 21): Number of available film types
- `GetFilmTypeItem` (ordinal 22): Get film type by index
- `SelectFilmTypeItem` (ordinal 47): Select a film type

**Adapter-dependent**: The firmware supports 7 consumer adapter types (Mount, Strip, 240/APS, Feeder, 6Strip, 36Strip, no-adapter) plus a factory test jig. The available film types depend on which adapter is inserted (detected via GPIO Port 7).

Source: `LS5000.md3:0x100A2980` (vendor ext registration), firmware `FW:0x49E30` (adapter table)

---

## 8. Multi-Sample Scanning

| Property | Value |
|----------|-------|
| **UI Location** | Scanner extras / advanced settings |
| **MAID Cap ID** | 0x8007 (multi-sample enable, boolean) |
| **Scanner Type Check** | 0x31C1 in orchestrator disables multi-sample |
| **SET WINDOW Offset** | Byte 50 |
| **Encoding** | Derived from scan type code (see table) |

### Multi-Sample Count Encoding (Byte 50)

The multi-sample count is NOT a direct user value. It is derived from scan operation
type codes stored at object+0x44C:

| Scan Type Code | Byte 50 Value | Samples | Noise Reduction |
|----------------|---------------|---------|-----------------|
| 0x20 | 1 | Single sample (normal) | None |
| 0x21 | 2 | 2x multi-sample | Minimal |
| 0x22 | 4 | 4x multi-sample | Moderate |
| 0x31 | 8 | 8x multi-sample | Good |
| 0x23 | 16 | 16x multi-sample | High |
| 0x24 | 32 | 32x multi-sample | Very high |
| 0x25 | 64 | 64x multi-sample | Maximum |

**How it works**: The scanner scans the same line multiple times and averages the results
to reduce random CCD noise. Higher sample counts give better noise reduction but
proportionally longer scan times.

**MAID hierarchy**: Multi-sample (cap 0x8007, type 0x1016) is a child of Scan Parameters
(0x8005, type 0x1012) in the capability object tree. ICE (0x800C, type 0x1022) is a child
of multi-sample.

Source: `LS5000.md3:0x100B2B30` switch at offset +0x32, `LS5000.md3:0x10028BE0` (tree)

---

## 9. Analog Gain / Exposure

| Property | Value |
|----------|-------|
| **UI Location** | CToolDlgAnalogGain dialog |
| **MAID Param ID** | 0x102 (vendor extension, dynamically registered) |
| **SET WINDOW Offset** | Vendor extension area (byte 54+), dynamic position |
| **Encoding** | Dynamic size from scanner (1, 2, or 4 bytes) |
| **Registration** | Conditional on scanner GET WINDOW flags_1 bit 2 |
| **SCSI Path (fine control)** | Vendor E0 sub-cmd 0x45 (exposure time, 11 bytes) |

### Analog Gain

The analog gain adjusts the CCD amplifier gain before digitization. This is a per-channel
control (R, G, B) that affects the raw signal level.

### Exposure Time

Fine exposure control uses the vendor command path:
1. **E0** (sub-cmd 0x45): Send exposure parameters (11-byte payload, per-channel)
2. **C1**: Trigger the exposure adjustment
3. **E1** (sub-cmd 0xC0): Read back exposure value (stored at object+0x460)

**UI class**: `CToolDlgAnalogGain` -- analog gain adjustment dialog

Source: `LS5000.md3:0x100A2980` (registration), `LS5000.md3:0x100B0400` (vendor cmd)

---

## 10. Focus / Autofocus

| Property | Value |
|----------|-------|
| **UI Location** | Autofocus button (MFC control 0x472), CToolDlgScanner |
| **MFC Control ID** | 0x472 (autofocus) |
| **Operation Code** | 3 (autofocus) |
| **SCSI Path** | Vendor E0/C1/E1 loop |

### Focus Sub-Commands (Vendor E0)

| Sub-cmd | Purpose | Payload | Notes |
|---------|---------|---------|-------|
| 0x44 | Motor position | 5 bytes | Focus motor target position |
| 0x46 | Focus position | 11 bytes | Focus position set |

### Autofocus Sequence

The Type C scan operation vtable handles focus:
1. TUR (0x00) -- check scanner ready
2. SEND DIAGNOSTIC (0x1D) -- prepare
3. E0 (write focus parameters)
4. C1 (trigger focus operation)
5. E1 (read focus result)

**E1 Response parsing**:
- Sub-command 0x42: Focus position result -> stored at object+0x468
- Sub-command 0xC0: Exposure value result -> stored at object+0x460

**Timeout**: 5-second timeout via `timeGetTime()` in the focus handler

### Scan Type Codes for Focus Operations

| Code | Operation |
|------|-----------|
| 0x42 | Focus check |
| 0x80 | Focus with auto-exposure (sets auto-exposure flag) |
| 0x81 | Focus type 2 |
| 0x90 | Autofocus coarse |
| 0x91 | Autofocus fine |
| 0xa0 | Area exposure measurement |
| 0xa1 | Area focus |

Source: `LS5000.md3:0x100B0380` (factory), `LS5000.md3:0x100B06F0` (handler)

---

## 11. Scan Direction

| Property | Value |
|----------|-------|
| **UI Location** | Scanner extras settings |
| **MAID Cap ID** | 0x25 (scan direction, boolean) |
| **Scanner Type Check** | 0x31C2 in orchestrator disables scan direction |
| **Values** | 0 = forward, 1 = reverse |

**Forward scan**: Carriage moves in the normal direction.
**Reverse scan**: Carriage moves in the opposite direction (may reduce banding on some scanners).

The scan orchestrator checks if the scanner supports direction control via
`FUN_10084610(0x31C2)` before attempting to set this capability.

Source: `NikonScan4.ds:0x1003B200` (orchestrator)

---

## 12. Brightness / Contrast / Threshold

| Property | MAID ID | SET WINDOW Offset | Range | Default |
|----------|---------|-------------------|-------|---------|
| Brightness | 0x100 | Byte 30 | 0-255 | From scanner |
| Threshold | 0x124 | Byte 31 | 0-255 | From scanner |
| Contrast | 0x101 | Byte 32 | 0-255 | From scanner |

All three are single-byte values in the standard SCSI window descriptor section.

Registered with range: `min=0, max=0xFF, default=scanner_value`

Source: `LS5000.md3:0x100A0BE0` (registration), `LS5000.md3:0x100B2B30` at +0x1E-0x20

---

## 13. Digital ICE (Dust/Scratch Removal)

| Property | Value |
|----------|-------|
| **UI Location** | Scanner tool palette, ICE checkbox |
| **MAID Cap ID** | 0x800C (ICE enable, boolean) |
| **MAID Object Type** | 0x1022 (kNkMAIDCapType_ICE) |
| **Scanner Type Check** | 0x31C6 enables ICE in orchestrator |
| **SET WINDOW Offset** | ICE/DRAG extension area (after vendor extensions) |
| **Master Enable** | MAID param 0xA20 (1 byte, 0=off, nonzero=on) |

### How ICE Works

Digital ICE requires an infrared scan channel. The scanner performs a normal visible-light
scan plus an infrared scan. Infrared light passes through dust and scratches but is blocked
by the film emulsion, allowing the software to detect and remove surface defects.

### MAID Capability Tree Position

```
0x8005 (Scan Parameters)
  └── 0x8007 (Multi-sample)
      └── 0x800C (ICE)
          └── 0x800E (DRAG)
```

ICE is a child of Multi-sample in the capability hierarchy. The ICE DLL
(ICEDLL.dll, ICENKNL1.dll, or ICENKNX2.dll) is loaded dynamically by LS5000.md3.

### ICE Extension in SET WINDOW

When ICE is supported (`scanner_state+0x84 == 1`):
1. Master enable byte (MAID param 0xA20) is written first
2. Then each ICE/DRAG sub-parameter is written with dynamic size (1, 2, or 4 bytes)
3. Sub-parameter values read via `FUN_1009fc60(scanner, index, param)`

**DLL API**: 36 exports (DICE* functions). Key: `DICENew`, `DICELoad`, `DICEInit`, `DICEBegin`, `DICEProcess`, `DICEEnd`, `DICEComplete`, `DICEDelete`.

Source: `LS5000.md3:0x100B2B30` (ICE area builder), `LS5000.md3:0x1009D730` (ICE check)

---

## 14. Digital ROC (Color Restoration)

| Property | Value |
|----------|-------|
| **UI Location** | Scanner tool palette / image enhancement |
| **MAID Cap ID** | 0x800E (DRAG enable, type 0x1023) |
| **MAID Cap ID** | 0x801D (DRAG post-processing enable, boolean) |
| **DLL** | DRAGNKL1.dll (48 exports, v2.0.0.14) |

### ROC Functionality

Digital ROC corrects color fading in old film. It analyzes the color channels and attempts
to restore the original colors based on known film aging patterns.

**API Functions**:
- `DRAGSetFloatParameter(ctx, id, val)`: Set ROC strength parameter
- `SetROCAdjustment(ctx, ...)`: Adjust ROC color restoration strength (ordinal 46)

**Scan Orchestrator**: Cap 0x801D is set to enable DRAG post-processing. The string ID 0x341E
displays the "Digital ROC/GEM post processing" status. It is enabled when batch scanning
AND DRAG/ICE buffers are valid.

Source: `NikonScan4.ds:0x1003B200` (orchestrator), `NikonScan4.ds:0x10043F60` (string map)

---

## 15. Digital GEM (Grain Reduction)

| Property | Value |
|----------|-------|
| **UI Location** | Scanner tool palette / image enhancement |
| **Shared Cap** | Part of DRAG subsystem (same 0x800E / 0x801D) |
| **DLL** | DRAGNKL1.dll (shared with ROC) |

### GEM Functionality

Digital GEM reduces visible film grain while preserving image detail. It works in
conjunction with ROC.

**API Functions**:
- `SetGrainResidue(ctx, ...)`: Set grain residue threshold (ordinal 39)
- `DRAGSetFloatParameter(ctx, id, val)`: Set GEM parameters

### Revelation Mask

The `CNkRevelation` class in NikonScan4.ds implements "Scanner Revelation Mask" -- a
characterization of consistent scanner artifacts (CCD defects, optical anomalies)
that is fed to DRAG via `SetREV_*` functions. This allows GEM to distinguish between
film grain and scanner-specific artifacts.

**DRAGNKL1.dll unique exports for Revelation**:
- `GetREV_edge_fixup_table` (ordinal 29)
- `SetREV_edge_fixup_table` (ordinal 44)
- `GetREV_gray_level_adjustment` (ordinal 30)
- `SetREV_gray_level_adjustment` (ordinal 45)
- `GetREV_mask_data` (ordinal 32)
- `SetREV_mask_data` (ordinal 43)
- `SetREV_scanner_resolution` (ordinal 47)

Source: `DRAGNKL1.dll` exports, `NikonScan4.ds` CNkRevelation RTTI

---

## 16. Unsharp Mask (USM)

| Property | Value |
|----------|-------|
| **UI Location** | CToolDlgUSM dialog |
| **DLL** | StdFilters2.dll (CUnsharpMaskFilter class) |
| **Pipeline Position** | Post-DRAG, in Strato filter chain |

### USM Parameters

| Parameter | Getter | Setter | Type | Notes |
|-----------|--------|--------|------|-------|
| Radius | `GetRadius()` | `SetRadius(double, bool)` | double | Blur radius in pixels |
| Power/Intensity | `GetPower()` | `SetPower(double, bool)` | double | Sharpening strength |
| Threshold | `GetThreshold()` | `SetThreshold(double, bool)` | double | Edge detection threshold |
| Range | `GetRange()` | `SetRange(double, double, double, double, bool)` | 4 doubles | Min/max shadow/highlight range |
| Mask Method | -- | `SetMaskMethod(long, bool)` | long | Algorithm variant |
| Affect Noise | -- | `SetAffectNoise(bool, bool)` | bool | Whether to apply to noise regions |

**USM is entirely host-side** -- it is applied by NikonScan4.ds after scan data is
retrieved, NOT sent to the scanner firmware.

Source: NikonScan4.ds imports from `StdFilters2.dll`

---

## 17. Curves / LUT Editor

| Property | Value |
|----------|-------|
| **UI Location** | CToolDlgCurves (multiple variants) |
| **DLL** | StdFilters2.dll (CStratoFilterLut, CStratoFilterCML) |
| **SCSI Path** | WRITE(10) with DTC 0x03 (Gamma/LUT data) |

### Curves Dialog Variants

| Class | Color Space |
|-------|-------------|
| CToolDlgCurvesRGB | RGB curves |
| CToolDlgCurvesGray | Grayscale curve |
| CToolDlgCurvesCMYK | CMYK curves |
| CToolDlgCurvesLCH | LCH (Lightness/Chroma/Hue) curves |
| CToolDlgCurvesGeneric | Generic curve editor |

### LUT Data Transfer

LUT (Look-Up Table) data is sent to the scanner via WRITE(10):
- **DTC** 0x03 (Gamma Function / LUT)
- **Max size**: 32768 bytes
- **Qualifier**: Per CDB[5] (identifies which LUT table)

The LUT applies tone mapping in the scanner hardware before data transfer, reducing
the amount of post-processing needed on the host side.

**API**: `AddCurvesToLutGroup` (ordinal 3) -- adds curves to a LUT group for batch application

Source: `LS5000.md3:0x100B50C0` (WRITE factory), firmware DTC table at `FW:0x49B98`

---

## 18. Color Management (CMS)

| Property | Value |
|----------|-------|
| **UI Location** | Preferences -> CMS tabs, CToolDlgColorBalance |
| **DLL** | CML4.dll (Nikon CMS engine), StdFilters2.dll (CStratoFilterColorSpace, CStratoFilterCMLEngine) |
| **API Export** | `UseCMS` (ordinal 58) |

### Color Management Preference Tabs

| Tab Class | Settings |
|-----------|----------|
| CPrefTabCMS | Master CMS enable/disable |
| CPrefTabCMSRGB | RGB input/output profile selection |
| CPrefTabCMSCMYK | CMYK profile selection |
| CPrefTabCMSPreview | Preview color management settings |

### ICC Profiles

NikonScan ships with these ICC profiles (in `Nikon\Profiles\`):

| Profile File | Description |
|-------------|-------------|
| NKsRGB.icm | sRGB color space |
| NKAdobe.icm | Adobe RGB (1998) |
| NKApple.icm | Apple RGB |
| NKApple_CPS.icm | Apple ColorSync |
| NKBruce.icm | Bruce RGB |
| NKCIE.icm | CIE RGB |
| NKCMatch.icm | ColorMatch RGB |
| NKWide.icm | Wide Gamut RGB |
| NKNTSC.icm | NTSC color space |
| NKGrayG18.icm | Grayscale Gamma 1.8 |
| NKGrayG22.icm | Grayscale Gamma 2.2 |
| NKCMYK.icm | Default CMYK profile |
| NKMonitor_Win.icm | Default monitor profile (Windows) |
| Nklch.icm | LCH working space |

### Profile API

| Export | Ordinal | Purpose |
|--------|---------|---------|
| `GetMonitorProfile` | 29 | Current monitor ICC profile |
| `GetPrinterProfile` | 30 | Current printer ICC profile |
| `GetRGBProfile` | 33 | Current RGB working space profile |
| `GetCMYKProfile` | 16 | Current CMYK profile |
| `GetGrayProfile` | 24 | Current grayscale profile |
| `GetLCHProfile` | 26 | Current LCH profile |
| `GetProfilePath` | 31 | Profile directory path |
| `GetMonitorGamma` | 28 | Monitor gamma value |

### CML Engine API

Four CML engine configurations for different input/output combinations:

| Export | Ordinal | Meaning |
|--------|---------|---------|
| `GetCMLEngineNN` | 12 | No input profile, no output profile |
| `GetCMLEngineNS` | 13 | No input profile, scanner output |
| `GetCMLEngineSN` | 14 | Scanner input, no output profile |
| `GetCMLEngineSS` | 15 | Scanner input, scanner output |

### Color Space Output (StdFilters2.dll)

`CStratoFilterColorSpace::SetOutputColorSpace(eOutputColorSpace, eOutputBitDepth, bool)`

The eOutputColorSpace and eOutputBitDepth enums control the final color space conversion.

**CMS is entirely host-side** -- profile conversion happens after scan data retrieval.

Source: NikonScan4.ds exports and imports from StdFilters2.dll, CML4.dll

---

## 19. Gamma Correction

| Property | Value |
|----------|-------|
| **UI Location** | CPrefMonitorGamma preference tab |
| **Preference Help** | SWPrefsGamma.htm |
| **API Export** | `GetMonitorGamma` (ordinal 28) |

Monitor gamma affects how scanned images are displayed. This is a host-side setting
applied during preview and final output. The scanner hardware operates in linear
color space.

---

## 20. Batch Scanning

| Property | Value |
|----------|-------|
| **UI Location** | CDlgBatchSettings dialog |
| **MFC Control IDs** | 0x471 (batch scan start), 0x474 (batch scan complete) |
| **Operation Codes** | 5 (batch scan start), 6 (batch scan complete/status) |
| **Preference Tab** | CPrefTabBatchScan |
| **Help Page** | SWPrefsBatch.htm |

### Batch Scanning Flow

The scan orchestrator handles multi-frame batching:
1. Checks `[param_1+0x60]` for multi-frame source
2. Gets frame count, sets up batching via `[source+0x120]`
3. Dialog 0x42D for batch settings configuration
4. Film strip configuration via `FUN_1001CF30()`
5. Dialog 0x43E for multi-frame confirmation
6. Per-frame: offsets ROI per frame, scales by ratio

### Settings in CDlgBatchSettings

- Output directory
- File naming convention
- Image format
- Batch-specific scan parameters

Source: `NikonScan4.ds:0x1003B200` (orchestrator), `NikonScan4.ds:0x1004D0C0` (status)

---

## 21. Film Adapter / Auto-Feeder

| Property | Value |
|----------|-------|
| **UI Location** | Main window adapter indicator, auto-feeder controls |
| **API Exports** | `CanEject` (4), `CanFeed` (5), `Eject` (8), `SetAutoFeeder` (49) |
| **SCSI Path** | SEND DIAGNOSTIC (0x1D) for motor control |

### Supported Adapters (LS-50/LS-5000)

| Index | Name | Product | Notes |
|-------|------|---------|-------|
| 0 | (none) | Bare mount | No adapter inserted |
| 1 | Mount | SA-21 | Slide mount adapter |
| 2 | Strip | SF-210 | Strip film adapter |
| 3 | 240 | IA-20(s) | APS/IX240 adapter |
| 4 | Feeder | SA-30 | Roll film adapter (auto-feeder) |
| 5 | 6Strip | SF-210 | 6-strip mode |
| 6 | 36Strip | SF-210 | 36-exposure mode |
| 7 | Test | Factory | Manufacturing test jig (not consumer) |

### Film Holders

| Name | Product | Purpose |
|------|---------|---------|
| FH-3 | Nikon FH-3 | Standard 35mm film holder |
| FH-G1 | Nikon FH-G1 | Glass film holder (for curled/warped film) |
| FH-A1 | Nikon FH-A1 | Medical/special slide adapter |

### Eject / Film Advance

The eject executor at `NikonScan4.ds:0x1002E030`:
- **Ctrl key NOT held**: Film Advance (next frame)
- **Ctrl key held**: Eject (remove adapter/film)
- No film loaded: Eject adapter

### Auto-Feeder

`SetAutoFeeder` (ordinal 49) configures automatic feeding behavior for the SA-30
roll film adapter. When enabled, the scanner automatically advances to the next frame
after each scan.

Source: firmware `FW:0x49E30` (adapter table), `NikonScan4.ds:0x1002E030` (eject)

---

## 22. Preference Tabs (Persistent Settings)

NikonScan stores persistent settings through the CPrefTab hierarchy. Each tab corresponds
to a section of the Preferences dialog.

### Preference Tab Classes

| Tab Class | Content | Help Page |
|-----------|---------|-----------|
| CPrefTabDevice | Scanner hardware settings | -- |
| CPrefTabSingleScan | Single scan workflow options | SWPrefsSingle.htm |
| CPrefTabBatchScan | Batch scan options | SWPrefsBatch.htm |
| CPrefTabCalibration | Calibration schedule / options | -- |
| CPrefTabPreview | Preview display settings | SWPrefsPreview.htm |
| CPrefTabGrid | Grid overlay settings | SWPrefsGrid.htm |
| CPrefTabFiles | File save location / format | SWPrefsFile.htm |
| CPrefTabFileSave | File save options (detailed) | -- |
| CPrefTabCMS | Color Management master settings | SWPrefsColorMgmt.htm |
| CPrefTabCMSRGB | RGB profile configuration | SWPrefsColorMgmt.htm |
| CPrefTabCMSCMYK | CMYK profile configuration | SWPrefsColorMgmt.htm |
| CPrefTabCMSPreview | Preview CMS settings | SWPrefsColorMgmt.htm |
| CPrefTabAdColor | Advanced color settings (master) | SWPrefsAdvColor.htm |
| CPrefTabAdColorRGB | Advanced RGB color settings | SWPrefsAdvColor.htm |
| CPrefTabAdColorGray | Advanced grayscale settings | SWPrefsAdvColor.htm |
| CPrefTabAdColorCMYK | Advanced CMYK color settings | SWPrefsAdvColor.htm |
| CPrefTabAutoAction | Auto action / workflow settings | SWPrefsAuto.htm |
| CPrefMonitorGamma | Monitor gamma setting | SWPrefsGamma.htm |

### Grid Settings (StdFilters2.dll)

| Method | Description |
|--------|-------------|
| `SetGridInterval(double, long, long, bool)` | Grid line spacing |
| `SetGridColor(byte, byte, byte, bool)` | Grid line color (R, G, B) |
| `SetAssumedImageSize(long, long, double, bool)` | Image dimensions for grid |

Source: NikonScan4.ds RTTI class names, help page string references

---

## 23. Settings Save/Load

| Property | Value |
|----------|-------|
| **API Exports** | `LoadSettings` (41), `SaveSettings` (44), `ResetToDefaultSettings` (43) |
| **User Settings** | `UserSettings` (59), `IsUserSettingsExist` (40), `UpdateSettingsItem` (57) |
| **Dialog Classes** | CDlgSettingsLoad, CDlgSettingsSave, CDlgSettingsDelete |
| **Resolution-Specific** | CDlgResSettingsLoad, CDlgResSettingsSave, CDlgResSettingsDelete |

### Settings Classes

| Class | Purpose |
|-------|---------|
| CNkSettings | Core settings engine |
| CFrescoSettings | Fresco-specific settings (scan params) |
| CWinSettings | Window layout/position settings |

### Storage

Settings are stored via the Windows registry:
- `SOFTWARE\Nikon\Nikon View` -- cross-application Nikon settings
- Individual scan parameter presets can be saved/loaded by name via the settings dialogs

The `GetDisplaySettingsSection` (ordinal 20) export returns the display settings
registry section name.

Source: NikonScan4.ds exports, RTTI class names, registry path strings

---

## 24. Vendor Extension Parameters

These parameters are dynamically registered based on scanner capabilities reported via
GET WINDOW. The registration happens at `LS5000.md3:0x100A2980` (2589 bytes).

The scanner self-describes which vendor extensions it supports via feature flag bytes
in the GET WINDOW response. For each supported feature, a param ID is registered with
a size (1, 2, or 4 bytes) and min/max range that come from the scanner itself.

### Vendor Extension Parameter Table

| Param ID | Group | Feature Flag Bit | Purpose | State Offset |
|----------|-------|-------------------|---------|-------------|
| 0x102 | 1 | flags_1 bit 2 | Analog gain/offset control | +0x114 |
| 0x103 | 1 | flags_1 bit 3 | Film type / negative-positive | +0x116 |
| 0x104 | 1 | flags_1 bit 4 | Exposure time | +0x118 |
| 0x105 | 1 | flags_1 bit 5 | Color balance | +0x11A |
| 0x106 | 1 | flags_1 bit 6 | Sharpness / edge enhancement | +0x11C |
| 0x107 | 2 | flags_2 bit 0 | Scanner-specific feature A | +0x130 |
| 0x108 | 2 | flags_2 bit 1 | Scanner-specific feature B | +0x132 |
| 0x109 | 2 | flags_2 bit 2 | Scanner-specific feature C | +0x134 |
| 0x10A | 2 | flags_2 bit 3 | Scanner-specific feature D | +0x136 |
| 0x10B | 2 | flags_2 bit 4 | Scanner-specific feature E | +0x138 |
| 0x10C | 2 | flags_2 bit 5 | Scanner-specific feature F | +0x13A |
| 0x10D | 2 | flags_2 bit 6 | Special (triggers 0xF02/0xF03 read) | +0x13C |

### Registration Call Pattern

For each vendor extension (e.g., param 0x102):
```c
// Read size from scanner's GET WINDOW response
size = *(byte*)(window_data + offset);  // 1, 2, or 4 bytes

// Parse min/max from window data
FUN_1009dc30(size, 4, &min_val, window_data + offset + 1);
FUN_1009dc30(size, 4, &max_val, window_data + offset + 1 + size);

// Register with range
vtable[0x24](0x102, 0x7F, size, min_val, max_val, max_val, max_val);

// Add to vendor extension list for SET WINDOW building
FUN_100a2820(this + 0x27C, 0x102, size);
```

### Special Param 0x10D

When param 0x10D is present, the SET WINDOW builder also reads params 0xF02 or 0xF03:
```c
if (param_id == 0x10D) {
    alt_id = (value != 0) ? 0xF03 : 0xF02;
    FUN_100aee20(this, alt_id, ...);
}
```

Params 0xF02 and 0xF03 are registered with range `[0, 0xFFFFFF]` (24-bit).

Source: `LS5000.md3:0x100A2980` (registration), `LS5000.md3:0x100B2B30` (SET WINDOW builder)

---

## 25. ICE/DRAG Extension Parameters

When ICE/DRAG is supported (`scanner_state+0x84 == 1`), additional parameters follow
the vendor extensions in the SET WINDOW descriptor.

### ICE/DRAG Extension Layout

```
Byte N:     Master enable (MAID param 0xA20, 1 byte, range 0-99)
Byte N+1+:  Per-feature parameters (dynamically sized, from scanner)
```

The number and size of ICE/DRAG sub-parameters are determined by iterating a
tree structure at `scanner_state+0x44`. Each tree node contains:
- Param size at `node[4] + 0x48` (short, 1/2/4 bytes)
- Param value via `FUN_100a76d0(node[4], param_id)`

**Total ICE/DRAG size** = sum of all node sizes (computed by `FUN_1009fc20`).

Source: `LS5000.md3:0x100B2B30` (ICE area), `LS5000.md3:0x1009FC20` (size calc)

---

## 26. Hidden / Internal Settings

### Settings NOT Exposed in Main UI

| Setting | How to Access | MAID Cap / ID | Notes |
|---------|--------------|---------------|-------|
| Scan direction | Scanner Extras dialog | 0x25 | Only if scanner supports (0x31C2) |
| Multi-sample count | Scanner Extras dialog | 0x8007 | Only if scanner supports (0x31C1) |
| Padding type | Internal only | 0x129 | SET WINDOW byte 49 bit 0 |
| Bit ordering | Internal only | 0x131 | SET WINDOW byte 49 bit 1 (MSB/LSB first) |
| RIF (Reverse Image) | Internal only | 0x12A | SET WINDOW byte 49 bit 5 |
| Auto background detection | Internal only | 0x12B (299) | SET WINDOW byte 49 bit 6 |
| Reserved flag | Internal only | 0x12C (300) | SET WINDOW byte 49 bit 7 |
| Compression type | Internal only | 0x12D | SET WINDOW byte 51 |
| Compression argument | Internal only | 0x12E | SET WINDOW byte 52 |
| Reserved byte | Internal only | 0x12F | SET WINDOW byte 53 |

### Ctrl+Key Shortcuts (Hidden Behaviors)

- **Ctrl + Eject**: Forces full eject instead of film advance

### Scanner Type Checks

The scan orchestrator uses `FUN_10084610()` to check scanner capabilities at runtime:

| Check Code | Meaning | Effect |
|------------|---------|--------|
| 0x31C1 | Multi-sample support | If missing, multi-sample cap is not set |
| 0x31C2 | Scan direction support | If missing, direction cap is not set |
| 0x31C5 | Additional option | Enables an additional scan option |
| 0x31C6 | ICE support | Enables ICE capability configuration |

### Debug / Diagnostic Capabilities

- Scan type codes 0xB0-0xB4: **Calibration scans** (not exposed to users)
- Scan type codes 0xC0-0xC1: **Vendor command operations** (internal)
- MAID cap 0x800D: Used in capability enumeration (internal book-keeping)
- MAID cap 0x8001: Module ID / marker value (comparison only)

### Factory Test Jig (Adapter Type 7)

The firmware recognizes a factory test adapter (GPIO Port 7 value). It has no VPD pages
and is invisible to NikonScan, but scan operations can still be performed using
low-level SCSI commands.

### Registry Settings

| Registry Path | Purpose |
|--------------|---------|
| `SOFTWARE\Nikon\Nikon View` | Cross-application Nikon settings |
| `Software\Microsoft\Windows\CurrentVersion\App Paths\NikonView.exe` | NikonView integration |
| (Windows TWAIN registry) | TWAIN data source registration |

Source: `NikonScan4.ds:0x1003B200`, `LS5000.md3:0x100A2980`, firmware adapter table

---

## 27. Model Differences (LS-50 vs LS-5000)

Both LS-50 and LS-5000 share the same LS5000.md3 module and the same 17 SCSI opcodes.
There are no model-specific SCSI extensions -- differences are in parameter ranges, not
protocol.

All four .md3 modules (LS4000, LS5000, LS8000, LS9000) have identical SCSI opcode sets.

### LS-50 vs LS-5000

| Feature | LS-50 | LS-5000 |
|---------|-------|---------|
| Optical Resolution | 4000 DPI | 4000 DPI |
| Interface | USB (PID 0x4001) | USB (PID 0x4002) |
| .md3 Module | LS5000.md3 | LS5000.md3 |
| MD3 Version | 3.50 | 3.50 |
| Digital ICE | Yes | Yes |
| Digital ROC/GEM | Yes | Yes |

### LS-8000/LS-9000 Additions

- Additional film types: Brownie (120/220 format)
- FH holder variants for medium format
- Larger scan areas
- LS9000 adds the largest module (1112KB vs 1028KB)

Source: `CLAUDE.md` model table, `docs/kb/scanners/`

---

## 28. Complete MAID Capability ID Table

This table lists every MAID capability ID found in the codebase, with its hierarchy
position, data type, and purpose.

### Capability Object IDs (LS5000.md3 Hierarchy Tree)

| Cap ID | Type Code | MAID Type | Parent | Purpose |
|--------|-----------|-----------|--------|---------|
| 0x8000 | 0x100C | Module | root | Module root |
| 0x8003 | 0x0004 | Source | 0x8000 | Source/Device |
| 0x800B | 0x101F | DataObject | 0x8003 | Data Object |
| 0x8103 | 0x1021 | ImageObject | 0x800B | Image Object A |
| 0x8005 | 0x1012 | ScanParam | 0x8103 | Scan Parameters |
| 0x8007 | 0x1016 | MultiSample | 0x8005 | Multi-sample |
| 0x800C | 0x1022 | ICE | 0x8007 | ICE (infrared dust removal) |
| 0x800E | 0x1023 | DRAG | 0x800C | DRAG (Digital ROC/GEM) |
| 0x8105 | 0x1025 | -- | 0x8103 | Image Object B |
| 0x8101 | 0x101B | ScanAcquire | 0x8105 | Scan Acquire B (secondary) |

### SET WINDOW Internal Parameter IDs

| Param ID | Descriptor Offset | Field Name | Data Size | Range |
|----------|-------------------|------------|-----------|-------|
| 0x100 | Byte 30 | Brightness | 1 byte | 0-255 |
| 0x101 | Byte 32 | Contrast | 1 byte | 0-255 |
| 0x102 | Vendor ext | Analog gain/offset | 1/2/4 (dynamic) | From scanner |
| 0x103 | Vendor ext | Film type | 1/2/4 (dynamic) | From scanner |
| 0x104 | Vendor ext | Exposure time | 1/2/4 (dynamic) | From scanner |
| 0x105 | Vendor ext | Color balance | 1/2/4 (dynamic) | From scanner |
| 0x106 | Vendor ext | Sharpness | 1/2/4 (dynamic) | From scanner |
| 0x107 | Vendor ext | Feature A | 1/2/4 (dynamic) | From scanner |
| 0x108 | Vendor ext | Feature B | 1/2/4 (dynamic) | From scanner |
| 0x109 | Vendor ext | Feature C | 1/2/4 (dynamic) | From scanner |
| 0x10A | Vendor ext | Feature D | 1/2/4 (dynamic) | From scanner |
| 0x10B | Vendor ext | Feature E | 1/2/4 (dynamic) | From scanner |
| 0x10C | Vendor ext | Feature F | 1/2/4 (dynamic) | From scanner |
| 0x10D | Vendor ext | Special trigger | 1/2/4 (dynamic) | From scanner |
| 0x121 | Bytes 10-11 | X Resolution | 2 bytes | 1-4000 DPI |
| 0x122 | Bytes 12-13 | Y Resolution | 2 bytes | 1-4000 DPI |
| 0x123 | Bytes 14-29 | Scan Area (composite) | 4 x 4 bytes | Adapter-dependent |
| 0x124 | Byte 31 | Threshold | 1 byte | 0-255 |
| 0x125 | Byte 33 | Image Composition | 1 byte | 0,1,2,5 |
| 0x126 | Byte 34 | Bits Per Pixel | 1 byte | 8,14,16 |
| 0x127 | Byte 35, 48 low | Halftone Pattern | 1 byte | 0 to max_halftone |
| 0x128 | Byte 48 high | Color filter/mode | 1 byte | 0-15 |
| 0x129 | Byte 49 bit 0 | Padding type | 1 bit | 0-1 |
| 0x12A | Byte 49 bit 5 | RIF (Reverse Image) | 1 bit | 0-1 |
| 0x12B | Byte 49 bit 6 | Auto background | 1 bit | 0-1 |
| 0x12C | Byte 49 bit 7 | Reserved flag | 1 bit | 0-1 |
| 0x12D | Byte 51 | Compression type | 1 byte | 0-255 |
| 0x12E | Byte 52 | Compression argument | 1 byte | 0-255 |
| 0x12F | Byte 53 | Reserved | 1 byte | 0-255 |
| 0x131 | Byte 49 bits 1-4 | Bit ordering | 3 bits | 0-7 |
| 0xA20 | ICE/DRAG area | ICE/DRAG master enable | 1 byte | 0-99 |
| 0xF02 | Vendor ext | Alt value (when 0x10D=0) | variable | 0-0xFFFFFF |
| 0xF03 | Vendor ext | Alt value (when 0x10D!=0) | variable | 0-0xFFFFFF |

### Scan Orchestrator Capability IDs (NikonScan4.ds)

| Cap ID | Opcode | DataType | Direction | Purpose |
|--------|--------|----------|-----------|---------|
| 0x25 | 6 (set) | 1 (bool) | Write | Scan direction (fwd/rev) |
| 0x800C | 6 (set) | 1 (bool) | Write | ICE enable/disable |
| 0x8007 | 6 (set) | 1 (bool) | Write | Multi-sample enable |
| 0x801B | 7 (get) | 10 (rect) | Read | ROI/scan area bounds |
| 0x801D | 6 (set) | 1 (bool) | Write | DRAG post-processing enable |
| 0x801A | 7 (get) | 4 (uint) | Read | Scanner property |
| 0x80A3 | 7 (get) | 4 (uint) | Read | Scanner property |
| 0x80A4 | 7 (get) | 4 (uint) | Read | Scanner property |
| 0x8010 | -- | -- | Read | Progress indicator |
| 0x8001 | -- | -- | Compare | Module ID / marker |

### Close Handler IDs

| Cap ID | Opcode | DataType | Purpose |
|--------|--------|----------|---------|
| 2 | 6 (set) | 0xD | Property before close |
| 3 | 6 (set) | 0xD | Property before close |
| 4 | 6 (set) | 0xD | Property before close |
| 5 | 6 (set) | 0xD | Property before close |
| 8 | 6 (set) | 0xF (range) | Resolution/area bounds |
| 10 | 6 (set) | 0xB (string) | Source/device name |
| 0x34 | 5 (start) | 0 | Start scan operation |

---

## 29. Complete SET WINDOW Byte Map

### Header (Bytes 0-7)

| Offset | Size | Field | Source |
|--------|------|-------|--------|
| 0-5 | 6 | Reserved (zeros) | -- |
| 6-7 | 2 | Window Descriptor Length | `descriptor_length - 8` (big-endian) |

### Standard Descriptor (Bytes 8-53)

| Offset | Size | Field | MAID Param | Encoding |
|--------|------|-------|------------|----------|
| 8 | 1 | Window ID | Factory argument | Window identifier |
| 9 | 1 | Reserved | -- | Zero |
| 10-11 | 2 | X Resolution (DPI) | 0x121 | Big-endian 16-bit |
| 12-13 | 2 | Y Resolution (DPI) | 0x122 | Big-endian 16-bit |
| 14-17 | 4 | Upper Left X | 0x123 [1] | Big-endian 32-bit |
| 18-21 | 4 | Upper Left Y | 0x123 [0] | Big-endian 32-bit |
| 22-25 | 4 | Width | 0x123 [3] | Big-endian 32-bit |
| 26-29 | 4 | Height | 0x123 [2] | Big-endian 32-bit |
| 30 | 1 | Brightness | 0x100 | 0-255 |
| 31 | 1 | Threshold | 0x124 | 0-255 |
| 32 | 1 | Contrast | 0x101 | 0-255 |
| 33 | 1 | Image Composition | 0x125 | 0=lineart, 1=halftone, 2=gray, 5=color |
| 34 | 1 | Bits Per Pixel | 0x126 | 8, 14, or 16 |
| 35 | 1 | Halftone Pattern | 0x127 | Pattern code |
| 36-47 | 12 | Reserved | -- | Zeros (standard padding) |
| 48 | 1 | Color Composite | 0x128, 0x127 | `(0x128 << 4) \| (0x127 & 0xF)` |
| 49 | 1 | Scan Flags | Multiple | Bitfield (see below) |
| 50 | 1 | Multi-Sample Count | scan type code | Encoded (see section 8) |
| 51 | 1 | Compression Type | 0x12D | Direct byte |
| 52 | 1 | Compression Argument | 0x12E | Direct byte |
| 53 | 1 | Reserved | 0x12F | Direct byte |

### Byte 49 -- Scan Flags Bitfield

| Bit | MAID Param | Meaning |
|-----|------------|---------|
| 0 | 0x129 | Padding type |
| 1-3 | 0x131 | Bit ordering (3 bits) |
| 4 | -- | Reserved (zero) |
| 5 | 0x12A | RIF (Reverse Image Format) |
| 6 | 0x12B (299) | Auto background detection |
| 7 | 0x12C (300) | Reserved flag |

### Vendor Extension Area (Bytes 54+)

Variable-length. Each vendor extension param (0x102-0x10D) is written in big-endian
format with its dynamic size (1, 2, or 4 bytes). The order follows the registration
list at `scanner_state+0x27C`.

### ICE/DRAG Extension Area (After Vendor Extensions)

Only present when `scanner_state+0x84 == 1`.

| Offset | Size | Field | MAID Param |
|--------|------|-------|------------|
| N | 1 | ICE/DRAG master enable | 0xA20 |
| N+1+ | varies | Per-feature ICE/DRAG params | Dynamic |

---

## Summary: UI Tool Dialog Classes

| Dialog Class | Purpose | Related Capabilities |
|-------------|---------|---------------------|
| CToolDlgScanner | Main scanner controls | Focus, eject, adapter |
| CToolDlgScannerExtras | Advanced scanner settings | Multi-sample, scan direction |
| CToolDlgAnalogGain | Analog gain/exposure | MAID 0x102, vendor E0 0x45 |
| CToolDlgColorBalance | Color balance adjustment | MAID 0x105 |
| CToolDlgCrop | Scan area selection | MAID 0x123, cap 0x801B |
| CToolDlgCurves | Tone curve editor | LUT via WRITE(10) DTC 0x03 |
| CToolDlgCurvesRGB | RGB curves | Per-channel tone curves |
| CToolDlgCurvesGray | Grayscale curve | Single-channel tone curve |
| CToolDlgCurvesCMYK | CMYK curves | CMYK tone curves |
| CToolDlgCurvesLCH | LCH curves | Lightness/Chroma/Hue curves |
| CToolDlgCurvesGeneric | Generic curve editor | General purpose |
| CToolDlgLutEditor | LUT table editor | Direct LUT editing |
| CToolDlgLCHEditor | LCH color editor | LCH color space adjustment |
| CToolDlgUSM | Unsharp Mask | USM radius, power, threshold |
| CToolDlgImageEnhancement | Digital ICE/ROC/GEM | Cap 0x800C, 0x800E, 0x801D |
| CToolDlgNkEnhancement | Nikon enhancement | Nikon-specific image enhancements |
| CToolDlgInformation | Scan info display | Read-only scan parameters |
| CToolDlgLayout | Page layout | Print/output layout |

---

## Summary: NikonScan4.ds Exported API (59 exports)

| Category | Exports |
|----------|---------|
| **Scan Control** | `StartScan`, `GetProgress` |
| **Film Handling** | `CanEject`, `CanFeed`, `Eject`, `SetAutoFeeder` |
| **Film Type** | `GetFilmTypeCount`, `GetFilmTypeItem`, `SelectFilmTypeItem` |
| **Color Space** | `GetColorSpaceCount`, `GetColorSpaceItem`, `SelectColorSpaceItem` |
| **Bit Depth** | `GetBitDepthCount`, `GetBitDepthItem`, `SelectBitDepthItem`, `GetSampleSize` |
| **CMS/Profiles** | `GetMonitorProfile`, `GetPrinterProfile`, `GetRGBProfile`, `GetCMYKProfile`, `GetGrayProfile`, `GetLCHProfile`, `GetCMLEngineNN/NS/SN/SS`, `UseCMS`, `GetMonitorGamma`, `GetProfilePath` |
| **Settings** | `LoadSettings`, `SaveSettings`, `ResetToDefaultSettings`, `UserSettings`, `IsUserSettingsExist`, `UpdateSettingsItem` |
| **UI** | `ShowPreferences`, `CanShowPreferences`, `ShowAbout`, `ShowHelp`, `ShowPane`, `ActivateScannerWindow`, `IsNormalPaneShown`, `GetFrescoToolPalette`, `SelectToolsItem` |
| **Source** | `GetSource`, `GetAvailableSourceCount`, `GetSelectedItemsCount`, `IsAnyItemExist` |
| **Image** | `TransformItem`, `AddCurvesToLutGroup` |
| **Pipeline** | `GetStratoManager`, `GetGridParameters`, `GetDisplaySettingsSection` |
| **File** | `GetDefaultSaveType`, `GetLastSaveType`, `SetLastSaveType` |
| **Misc** | `PreTranslateMessageDLL`, `DS_Entry` (x2, ordinals 1 and 7) |

---

## Cross-References

- [SET WINDOW Descriptor](../scsi-commands/set-window-descriptor.md) -- Byte-level parameter mapping
- [SET WINDOW](../scsi-commands/set-window.md) -- CDB format and usage
- [MODE SELECT](../scsi-commands/mode-select.md) -- Mode page configuration
- [MODE SENSE](../scsi-commands/mode-sense.md) -- Read scanner configuration
- [READ](../scsi-commands/read.md) -- Data type codes for scan data
- [WRITE](../scsi-commands/write.md) -- LUT/calibration data write
- [Vendor E0](../scsi-commands/vendor-e0.md) -- Focus/exposure control write
- [Vendor E1](../scsi-commands/vendor-e1.md) -- Focus/exposure readback
- [Scan Workflows](../components/nikonscan4-ds/scan-workflows.md) -- End-to-end scan flow
- [MAID Entrypoint](../components/ls5000-md3/maid-entrypoint.md) -- MAID dispatch
- [Scan Operation Vtables](../components/ls5000-md3/scan-operation-vtables.md) -- Scan type codes
- [DRAG API](../components/dragnkl1/api.md) -- Digital ROC/GEM API
- [DRAG/ICE Pipeline](../components/dragnkl1/pipeline.md) -- Image processing pipeline
- [Film Adapters](../components/firmware/film-adapters.md) -- Adapter types and detection
- [Software Layers](../architecture/software-layers.md) -- Architecture overview
