# PC Software Interface -- Complete Scanner Communication Reference

**Status**: Complete
**Last Updated**: 2026-03-12
**Phase**: Deep Dive (builds on Phases 1-7)
**Confidence**: High (verified from disassembly of all layers)

## Purpose

This document consolidates everything a driver developer needs to know about how the PC software (NikonScan 4.03) talks to Nikon Coolscan film scanners. It covers the complete path from user action to SCSI command, including all user-facing options, TWAIN capabilities, MAID capability IDs, SET WINDOW parameter encoding, and scan lifecycle management.

---

## 1. Software Architecture (Call Chain)

```
User clicks "Scan" in NikonScan GUI
    |
    v
NikonScan4.ds (2.2MB TWAIN Data Source, 59 exports, 321 RTTI classes)
    | DS_Entry dispatch -> scan orchestrator -> command queue -> MAID call
    v
LS5000.md3 (1MB Model Module, 3 exports, 6 RTTI classes)
    | MAIDEntryPoint -> capability object tree -> SCSI CDB factory
    v
NKDUSCAN.dll (88KB USB Transport, 1 export)
    | NkDriverEntry FC5 -> DeviceIoControl -> usbscan.sys
    v
USB bulk pipes -> Scanner Firmware (H8/3003)
```

---

## 2. TWAIN DS_Entry Dispatch

### Entry Point

`DS_Entry` at `NikonScan4.ds:0x10091F50` (ordinals 1 and 7).

### Dispatch Architecture

The dispatch is **table-driven**, not a giant switch. A linked list of handler entries maps `(DG, DAT<<16|MSG)` tuples to handler functions.

**Pre-open state** (before MSG_OPENDS): Only three triplets accepted:
| Hex Key | Triplet | Handler |
|---------|---------|---------|
| 0x30401 | DAT_IDENTITY / MSG_OPENDS | `0x10091d20` -- opens the data source |
| 0x80001 | DAT_STATUS / MSG_GET | `0x10091040` |
| 0x30001 | DAT_IDENTITY / MSG_GET | `0x10091030` |

**Post-open state**: Full dispatch through `CFrescoTwainSource::DispatchTriplet` at `0x10092040`, which searches the handler linked list. Each handler entry is at least 0x20 bytes:

```
+0x00: DWORD dg             -- Data Group to match
+0x04: DWORD key            -- (DAT << 16) | MSG
+0x06: WORD  handler_type   -- dispatch type (calling convention)
+0x08: WORD  capability_id  -- TWAIN cap ID for MSG_GET/SET matching
+0x0C: DWORD handler_func   -- function pointer
+0x1C: DWORD next           -- next in linked list
```

Handler types (from execute dispatcher at `0x10090e70`):
| Type | Convention | Use |
|------|-----------|-----|
| 0 | `handler()` | No arguments |
| 1-10 | `handler(pData)` | Standard TWAIN data |
| 0x101 | `handler()` | MSG notification |
| 0x102-0x10A | `handler(pData)` | Extended handlers |

Source: `NikonScan4.ds:0x10091E60` (main dispatch), `0x10090E70` (handler execute)

### Key TWAIN Classes

```
CNkTwainSource           -- Singleton at global 0x101656a8
  +0x00: vfptr -> 0x10139a74
  +0x04: dispatch sub-object (vfptr -> 0x10139aa4)
  +0x18: active source pointer (CFrescoTwainSource*)

CFrescoTwainSource       -- Active session, inherits CNkTwainTripletHandler
  Contains handler linked list
  Dispatches matched triplets

TNkTwainNumericEnumeration<D> -- TWAIN enum containers (multiple template instantiations)
TNkTwainNumericEnumeration<E> -- for bytes
TNkTwainNumericEnumeration<F> -- for shorts
TNkTwainNumericEnumeration<G> -- for unsigned shorts
TNkTwainNumericEnumeration<J> -- for longs
TNkTwainNumericEnumeration<K> -- for unsigned longs

VNkTwainArray            -- TWAIN container base classes
VNkTwainContainer
VNkTwainEnumeration
VNkTwainOneValue
VNkTwainRange
CNkTwainFix32Array       -- TW_FIX32 containers
CNkTwainFix32Enumeration
CNkTwainFix32OneValue
CNkTwainFix32Range
CNkTwainIncomingArray    -- For received TWAIN data
CNkTwainIncomingEnumeration
CNkTwainIncomingOneValue
```

---

## 3. Exported Scanner API (59 Exports)

NikonScan4.ds provides a direct (non-TWAIN) API via 59 exports. All follow the pattern: AFX state setup -> get active source via `FUN_10055c20(0x101654f0)` -> `vtable[109]` -> source-specific virtual methods.

### Scan Control
| Export | Ordinal | Address | Purpose |
|--------|---------|---------|---------|
| `StartScan` | 55 | 0x10047C20 | Start scan (triggers full orchestrator) |
| `GetProgress` | 32 | 0x10047F30 | Current scan progress (0-100%) |

### Film Handling
| Export | Ordinal | Address | Purpose |
|--------|---------|---------|---------|
| `CanEject` | 4 | 0x100479E0 | Check if eject is possible |
| `CanFeed` | 5 | 0x10047A40 | Check if film advance is possible |
| `Eject` | 8 | 0x10047AA0 | Eject film (Ctrl+click = eject adapter) |
| `SetAutoFeeder` | 49 | 0x10047B00 | Enable/disable SA-21 auto feeder |

### Film Type Selection
| Export | Ordinal | Address | Purpose |
|--------|---------|---------|---------|
| `GetFilmTypeCount` | 21 | 0x100475E0 | Number of available film types |
| `GetFilmTypeItem` | 22 | 0x10047640 | Get film type by index |
| `SelectFilmTypeItem` | 47 | 0x100476B0 | Select film type |

Film type 4 = negative film (triggers exposure calibration warning dialog in scan orchestrator).

### Color Space Selection
| Export | Ordinal | Address | Purpose |
|--------|---------|---------|---------|
| `GetColorSpaceCount` | 17 | 0x100474B0 | Number of color spaces |
| `GetColorSpaceItem` | 18 | 0x10047510 | Get color space by index |
| `SelectColorSpaceItem` | 46 | 0x10047580 | Select color space |

### Bit Depth Selection
| Export | Ordinal | Address | Purpose |
|--------|---------|---------|---------|
| `GetBitDepthCount` | 10 | 0x100483A0 | Number of bit depths (8/14/16) |
| `GetBitDepthItem` | 11 | 0x10048400 | Get bit depth by index |
| `SelectBitDepthItem` | 45 | 0x10048470 | Select bit depth |
| `GetSampleSize` | 34 | 0x10048360 | Current sample size in bytes |

### Color Management (ICC/CMS)
| Export | Ordinal | Address | Purpose |
|--------|---------|---------|---------|
| `UseCMS` | 58 | 0x10047410 | Enable/disable color management |
| `GetMonitorGamma` | 28 | 0x10047440 | Current monitor gamma value |
| `GetMonitorProfile` | 29 | 0x10048660 | Monitor ICC profile path |
| `GetPrinterProfile` | 30 | 0x100486F0 | Printer ICC profile path |
| `GetRGBProfile` | 33 | 0x10048800 | RGB working space ICC profile |
| `GetCMYKProfile` | 16 | 0x10048750 | CMYK output profile |
| `GetGrayProfile` | 24 | 0x100489C0 | Grayscale output profile |
| `GetLCHProfile` | 26 | 0x10048960 | LCH profile path |
| `GetProfilePath` | 31 | 0x10048A70 | Get ICC profile directory |
| `GetCMLEngineNN` | 12 | 0x100481A0 | CML engine (normal->normal) |
| `GetCMLEngineSN` | 14 | 0x10048280 | CML engine (scanner->normal) |
| `GetCMLEngineNS` | 13 | 0x10048210 | CML engine (normal->scanner) |
| `GetCMLEngineSS` | 15 | 0x100482F0 | CML engine (scanner->scanner) |

### Image Processing
| Export | Ordinal | Address | Purpose |
|--------|---------|---------|---------|
| `TransformItem` | 56 | 0x100484D0 | Apply geometric transform to scan item |
| `AddCurvesToLutGroup` | 3 | 0x10047E20 | Add curves adjustment to LUT group |
| `GetStratoManager` | 37 | 0x10047D10 | Get Strato filter pipeline manager |
| `GetGridParameters` | 25 | 0x10047D70 | Get image grid/tile parameters |
| `SelectToolsItem` | 48 | 0x100485A0 | Select tool (analog gain, curves, etc.) |

### Settings
| Export | Ordinal | Address | Purpose |
|--------|---------|---------|---------|
| `LoadSettings` | 41 | 0x10047710 | Load saved scan settings |
| `SaveSettings` | 44 | 0x10047780 | Save current settings |
| `ResetToDefaultSettings` | 43 | 0x100477F0 | Reset to factory defaults |
| `UserSettings` | 59 | 0x10047850 | Access user settings store |
| `IsUserSettingsExist` | 40 | 0x10047910 | Check if settings file exists |
| `UpdateSettingsItem` | 57 | 0x10047970 | Update one settings value |

### UI
| Export | Ordinal | Address | Purpose |
|--------|---------|---------|---------|
| `ShowPreferences` | 54 | 0x100473B0 | Show preferences dialog |
| `CanShowPreferences` | 6 | 0x10047C80 | Check if prefs can be shown |
| `ShowAbout` | 51 | 0x10047B60 | Show about dialog |
| `ShowHelp` | 52 | 0x10048140 | Launch help |
| `ShowPane` | 53 | 0x10048000 | Show/hide UI pane |
| `ActivateScannerWindow` | 2 | 0x10048540 | Bring scanner window to front |
| `IsNormalPaneShown` | 39 | 0x10047F90 | Check if normal pane visible |
| `GetFrescoToolPalette` | 23 | 0x10047D40 | Get tool palette handle |
| `GetDisplaySettingsSection` | 20 | 0x10047DE0 | Get display settings handle |
| `PreTranslateMessageDLL` | 42 | 0x10048170 | MFC message pre-translation |

### Source/Item Management
| Export | Ordinal | Address | Purpose |
|--------|---------|---------|---------|
| `GetSource` | 36 | 0x10048AB0 | Get scanner source handle |
| `GetAvailableSourceCount` | 9 | 0x10047EF0 | Number of connected scanners |
| `GetSelectedItemsCount` | 35 | 0x100478B0 | Number of selected scan items |
| `IsAnyItemExist` | 38 | 0x100485E0 | Check if any scan items exist |

### File Type
| Export | Ordinal | Address | Purpose |
|--------|---------|---------|---------|
| `GetDefaultSaveType` | 19 | 0x10048080 | Default save format |
| `GetLastSaveType` | 27 | 0x100480C0 | Last used save format |
| `SetLastSaveType` | 50 | 0x10048100 | Remember save format |

---

## 4. MAID Interface (LS5000.md3)

### MAIDEntryPoint Dispatch

`MAIDEntryPoint` at `LS5000.md3:0x100298F0`. 16-case switch at `0x10029b30`.

| Opcode | Handler | Purpose |
|--------|---------|---------|
| 0 | `0x10028560` | Open/Initialize module |
| 1 | `0x10029070` | Close/Shutdown module |
| 2 | `0x100287e0` | Enumerate capabilities |
| 3 | `0x100271c0` | Get capability (module-level) |
| 4 | `0x10027230` | Set capability (module-level) |
| 5-9,13 | `0x100273a0` | **Capability object-level dispatcher** (555 bytes) |
| 10 | `0x100275d0` | Start scan operation |
| 11 | `0x10027810` | Get capability default |
| 12 | `0x10027a80` | Capability changed notification |
| 14 | `0x10027cf0` | Abort/Cancel operation |
| 15 | `0x10027f60` | Query status |

**Key insight**: Opcodes 5-9 and 13 route to the **same handler** `FUN_100273a0`, which looks up the target capability object in the hierarchy tree at `[context+0xC]`, then dispatches to the matched object's vtable. This is a general-purpose object-level operation dispatcher.

### MAID Capability Object Hierarchy

Created during module open at `FUN_10028be0` (1164 bytes):

```
0x8000 (type 0x100C) -- Module root
  |
  +-- 0x8003 (type 0x0004) -- Source/Device
       |
       +-- 0x800B (type 0x101F) -- Data Object
            |
            +-- 0x8103 (type 0x1021) -- Image Object A (primary scan path)
            |    |
            |    +-- 0x8005 (type 0x1012) -- Scan Parameters
            |    |    |
            |    |    +-- 0x8007 (type 0x1016) -- Multi-sample control
            |    |         |
            |    |         +-- 0x800C (type 0x1022) -- ICE (Digital ICE)
            |    |              |
            |    |              +-- 0x800E (type 0x1023) -- DRAG (Digital ROC/GEM)
            |    |
            |    +-- 0x8105 (type 0x1025) -- Image Object B
            |         |
            |         +-- 0x8101 (type 0x101B) -- Scan Acquire B (secondary image path)
```

### MAID Capability IDs Used by NikonScan4.ds

These cap IDs are passed through `CTwainMaidImage::vtable[23]` (thunk at `0x10070500`) which chains to `CFrescoMaidModule::CallMAID` at `0x1007a1f0`.

#### Scan Configuration Capabilities

| Cap ID | Opcode | Data Type | Description | Notes |
|--------|--------|-----------|-------------|-------|
| 0x800C | 6 (set) | 1 (bool) | ICE enable/disable | Checked via vtable[47] first |
| 0x25 | 6 (set) | 1 (bool) | Scan direction (0=forward, 1=reverse) | |
| 0x8007 | 6 (set) | 1 (bool) | Multi-sample enable | |
| 0x801B | 7 (get) | 10 (rect) | ROI/scan area bounds | Returns RECT |
| 0x801D | 6 (set) | 1 (bool) | DRAG post-processing enable | True when batch scan + DRAG buffers valid |
| 0x8010 | status | | Progress indicator | MFC string 0x3435 |
| 0x801A | 7 (get) | 4 (uint) | Scanner property (read) | MFC string 0x341C |
| 0x80A3 | 7 (get) | 4 (uint) | Scanner property (read) | MFC string 0x3434 |
| 0x80A4 | 7 (get) | 4 (uint) | Scanner property (read) | |
| 0x8001 | compare | | Module ID / marker value | |

#### Close-Time Capabilities

Set during source close handler at `0x100723c0`:

| Cap ID | Opcode | Data Type | Description |
|--------|--------|-----------|-------------|
| 2 | 6 (set) | 0xD | Property before close |
| 3 | 6 (set) | 0xD | Property before close |
| 4 | 6 (set) | 0xD | Property before close |
| 5 | 6 (set) | 0xD | Property before close |

#### Utility Capabilities

| Cap ID | Opcode | Data Type | Description |
|--------|--------|-----------|-------------|
| 8 | 6 (set) | 0xF (range) | Resolution/area range bounds |
| 9 | 7 (get) | 0xB (string) | Device name query |
| 10 | 6 (set) | 0xB (string) | Set source/device name |
| 0x34 | 5 (start) | | Start scan operation |
| 7 | get | 0x10 | Cap data retrieval |

---

## 5. SET WINDOW Parameter Encoding (Complete Byte Map)

The SET WINDOW command (opcode 0x24) encodes all scan settings in a single descriptor. Built by `FUN_100b2b30` (1268 bytes) at `LS5000.md3:0x100B2B30`.

### Standard Fields (Bytes 0-53)

| Offset | Size | MAID Param | Field | Values/Encoding |
|--------|------|------------|-------|----------------|
| 0-5 | 6 | -- | Reserved | Zeros |
| 6-7 | 2 | -- | Descriptor length | `total_size - 8`, big-endian |
| 8 | 1 | factory arg | Window ID | Scanner window identifier |
| 9 | 1 | -- | Reserved | Zero |
| 10-11 | 2 | **0x121** | X Resolution (DPI) | Big-endian 16-bit. Range: 150-4000 DPI (LS-50) |
| 12-13 | 2 | **0x122** | Y Resolution (DPI) | Same as X typically |
| 14-17 | 4 | **0x123** area[1] | Upper Left X | Big-endian 32-bit, scanner units |
| 18-21 | 4 | **0x123** area[0] | Upper Left Y | Big-endian 32-bit, scanner units |
| 22-25 | 4 | **0x123** area[3] | Width | Big-endian 32-bit, scanner units |
| 26-29 | 4 | **0x123** area[2] | Height | Big-endian 32-bit, scanner units |
| 30 | 1 | **0x100** | Brightness | 0-255 (128 = neutral) |
| 31 | 1 | **0x124** | Threshold | 0-255 (for line-art mode) |
| 32 | 1 | **0x101** | Contrast | 0-255 (128 = neutral) |
| 33 | 1 | **0x125** | Image Composition | 0=line-art, 1=halftone, 2=grayscale, 5=color |
| 34 | 1 | **0x126** | Bits Per Pixel | 8, 14, or 16 bits per channel |
| 35 | 1 | **0x127** | Halftone Pattern | Dither pattern code |

### Nikon Vendor Fields (Bytes 48-53)

| Offset | Size | MAID Param(s) | Field | Encoding |
|--------|------|---------------|-------|----------|
| 48 | 1 | **0x128** (hi), **0x127** (lo) | Color/Composition | `(0x128 << 4) \| (0x127 & 0xF)` |
| 49 | 1 | multiple | Scan Flags | Bit 0: **0x129** padding; Bit 1: **0x131** bit order; Bit 5: **0x12a** RIF; Bit 6: **0x12b**(299) auto-bg; Bit 7: **0x12c**(300) reserved |
| 50 | 1 | scan type code | Multi-sample count | See encoding table below |
| 51 | 1 | **0x12d** | Compression type | |
| 52 | 1 | **0x12e** | Compression argument | |
| 53 | 1 | **0x12f** | Reserved | |

#### Multi-Sample Encoding (Byte 50)

| Type Code | Sample Count | Use Case |
|-----------|-------------|----------|
| 0x20 | 1 | Normal scan (single pass) |
| 0x21 | 2 | 2x multi-sample (light noise reduction) |
| 0x22 | 4 | 4x multi-sample |
| 0x31 | 8 | 8x multi-sample |
| 0x23 | 16 | 16x multi-sample (heavy noise reduction) |
| 0x24 | 32 | 32x multi-sample |
| 0x25 | 64 | 64x multi-sample (maximum, very slow) |

### Vendor Extension Area (Bytes 54+, Dynamic)

**Architecture**: Extensions are NOT hardcoded. The scanner self-describes its capabilities via GET WINDOW response. During init (`FUN_100a2980`, 2589 bytes), the host reads GET WINDOW, parses feature flags, and registers extension params with `FUN_100a2820(scanner+0x27c, param_id, data_size)`.

Each param's **data size (1, 2, or 4 bytes) comes from the scanner**, not from the host code.

#### Group 1 Vendor Extensions (Conditionally Registered)

| Param ID | Feature Flag | Purpose | Data Size |
|----------|-------------|---------|-----------|
| **0x102** | flags_1 bit 2 | Analog gain/offset control | dynamic |
| **0x103** | flags_1 bit 3 | Film type / negative-positive | dynamic |
| **0x104** | flags_1 bit 4 | Exposure time control | dynamic |
| **0x105** | flags_1 bit 5 | Color balance adjustment | dynamic |
| **0x106** | flags_1 bit 6 | Sharpness / edge enhancement | dynamic |

#### Group 2 Vendor Extensions

| Param ID | Feature Flag | Purpose | Data Size |
|----------|-------------|---------|-----------|
| **0x107** | flags_2 bit 0 | Scanner-specific feature | dynamic |
| **0x108** | flags_2 bit 1 | Scanner-specific feature | dynamic |
| **0x109** | flags_2 bit 2 | Scanner-specific feature | dynamic |
| **0x10a** | flags_2 bit 3 | Scanner-specific feature | dynamic |
| **0x10b** | flags_2 bit 4 | Scanner-specific feature | dynamic |
| **0x10c** | flags_2 bit 5 | Scanner-specific feature | dynamic |
| **0x10d** | flags_2 bit 6 | Special (triggers alt 0xf02/0xf03) | dynamic |

#### ICE/DRAG Extension (After Vendor Params)

If `scanner_state+0x84 == 1` (ICE/DRAG supported):

| Param ID | Purpose | Data Size |
|----------|---------|-----------|
| **0xa20** | ICE/DRAG master enable | 1 byte |
| (per-param) | ICE/DRAG sub-parameters | 1/2/4 bytes each |

#### Descriptor Size Calculation

```c
base = 54;  // bytes 0-53 (standard + Nikon vendor)
vendor_ext = FUN_100a0360(scanner_state);  // sum of all registered vendor param sizes
ice_drag = 0;
if (scanner_state[0x84] == 1) {            // ICE/DRAG present?
    ice_drag = FUN_1009fc20(scanner_state); // sum of ICE/DRAG param sizes
}
total = base + vendor_ext + ice_drag;
```

Source: `LS5000.md3:0x100B3A50` (prepare), `0x100B2B30` (builder)

---

## 6. Complete MAID Internal Parameter ID Reference

All MAID param IDs used in the SET WINDOW parameter builder, with their SET WINDOW offsets:

| Param ID | Hex | SET WINDOW Offset | Field | Size |
|----------|-----|-------------------|-------|------|
| 0x100 | 0x100 | 30 | Brightness | 1 |
| 0x101 | 0x101 | 32 | Contrast | 1 |
| 0x102 | 0x102 | vendor 54+ | Analog gain/offset | 1-4 |
| 0x103 | 0x103 | vendor 54+ | Film type | 1-4 |
| 0x104 | 0x104 | vendor 54+ | Exposure | 1-4 |
| 0x105 | 0x105 | vendor 54+ | Color balance | 1-4 |
| 0x106 | 0x106 | vendor 54+ | Sharpness | 1-4 |
| 0x107-0x10d | -- | vendor 54+ | Scanner-specific | 1-4 |
| 0x121 | 0x121 | 10-11 | X Resolution (DPI) | 2 |
| 0x122 | 0x122 | 12-13 | Y Resolution (DPI) | 2 |
| 0x123 | 0x123 | 14-29 | Scan Area (4 coords) | 16 |
| 0x124 | 0x124 | 31 | Threshold | 1 |
| 0x125 | 0x125 | 33 | Image Composition | 1 |
| 0x126 | 0x126 | 34 | Bits Per Pixel | 1 |
| 0x127 | 0x127 | 35, 48 lo | Halftone Pattern | 1 |
| 0x128 | 0x128 | 48 hi | Color filter mode | 1 |
| 0x129 | 0x129 | 49 bit 0 | Padding type | 1 bit |
| 0x12a | 0x12a | 49 bit 5 | RIF (Reverse Image) | 1 bit |
| 0x12b | 299 | 49 bit 6 | Auto background | 1 bit |
| 0x12c | 300 | 49 bit 7 | Reserved flag | 1 bit |
| 0x12d | 0x12d | 51 | Compression type | 1 |
| 0x12e | 0x12e | 52 | Compression arg | 1 |
| 0x12f | 0x12f | 53 | Reserved byte | 1 |
| 0x131 | 0x131 | 49 bit 1 | Bit ordering | 1 bit |
| 0xa20 | 0xa20 | ICE area | ICE/DRAG master enable | 1 |
| 0xf02 | 0xf02 | vendor ext | Alt value (condition false) | varies |
| 0xf03 | 0xf03 | vendor ext | Alt value (condition true) | varies |

---

## 7. Scan Workflow Sequences

### MFC Control ID to Operation Type

| MFC Control ID | Operation Code | Scan Type |
|----------------|---------------|-----------|
| 0x46B | 4 | **Final scan** (full resolution) |
| 0x46E | 1 | **Preview scan** (low resolution) |
| 0x470 | 2 | **Thumbnail scan** |
| 0x471 | 5 | **Batch scan start** |
| 0x472 | 3 | **Autofocus** |
| 0x474 | 6 | **Batch scan complete/status** |

### Scan Orchestrator (FUN_1003b200, 8430 bytes)

The scan orchestrator at `NikonScan4.ds:0x1003B200` performs:

1. **Source enumeration**: `FUN_10104240()` -> count, `FUN_10104280()` -> fill IDs
2. **Film type check**: `[source+0x1C]` -- type 4 = negative -> exposure warning dialog
3. **Exposure calibration**: `FUN_1008c270(0x41A)` -> calibration dialog if needed
4. **Multi-frame setup**: `[param_1+0x60]` -> frame count for film strips
5. **Batch settings**: Dialog 0x42D for batch, 0x43E for multi-frame
6. **Command queue creation**: `FUN_1004d3e0(ctx, 0x3422, 1)` -- CStoppableCommandQueue
7. **Per-source MAID config**: Dynamic cast CMaidBase -> CTwainMaidImage, then:
   ```c
   // Check scanner type via FUN_10084610():
   //   0x31C1 -> disable multi-sample
   //   0x31C2 -> disable scan direction
   //   0x31C5 -> enable additional option
   //   0x31C6 -> enable ICE

   // Configure capabilities:
   if (vtable[47](0x800C)) vtable[23](obj,6,0x800C,1,ice_val,0,0);     // ICE
   if (vtable[47](0x25))   vtable[23](obj,6,0x25,1,dir_val,0,0);       // Direction
   if (vtable[47](0x8007)) vtable[23](obj,6,0x8007,1,ms_val,0,0);      // Multi-sample
   if (vtable[47](0x801B)) vtable[23](obj,7,0x801B,10,&roi,0,0);       // Get ROI
   if (vtable[47](0x801D)) vtable[23](obj,6,0x801D,1,drag_val,0,0);    // DRAG enable
   vtable[0x1B0/4](&area);                                              // Set scan area
   ```
8. **Resolution**: From `[source+0xA0]`, minimum 2000 DPI for multi-frame
9. **Execute**: Queue MAID operations -> CCommandQueueManager::Execute

### SCSI Command Sequences (by Scan Operation Type)

#### Init Sequence (Phase A, all scan types)
```
TUR (0x00) -> INQUIRY (0x12) -> RESERVE (0x16) -> MODE SELECT (0x15) ->
SEND DIAGNOSTIC (0x1D) -> GET WINDOW (0x25) -> READ10 (0x28, sub=0x88/0x91)
```
Factory: `FUN_100af1f0` (958 bytes). Handler: `FUN_100b3060` (983 bytes).

#### Main Scan (Phase B, Type A)
```
TUR (0x00) -> SEND DIAGNOSTIC (0x1D) -> SET WINDOW (0x24, full descriptor)
```
Factory: `FUN_100b3b90` (368 bytes).

#### Data Transfer (Phase B, Type B)
```
TUR (0x00) -> SCAN (0x1B) -> SEND DIAGNOSTIC (0x1D) -> SET WINDOW (0x24) ->
GET WINDOW (0x25) -> READ10 (0x28, sub=0x87) -> WRITE10 (0x2A)
```
Factory: `FUN_100b41a0` (898 bytes). READ10 sub 0x87 = scan image data. WRITE10 = LUT/correction.

#### Focus/Autofocus (Type C)
```
TUR (0x00) -> SEND DIAGNOSTIC (0x1D) -> E0 (vendor write) -> C1 (trigger) -> E1 (vendor read)
```
Factory: `FUN_100b0380` (617 bytes). E1 sub-cmd 0x42 = focus position, 0xC0 = exposure value.

#### Full Final Scan (Combined)
```
Phase A (Init): TUR -> INQUIRY -> RESERVE -> MODE_SELECT -> SEND_DIAG -> GET_WINDOW -> READ10
Phase B (Main): TUR -> SEND_DIAG -> SET_WINDOW
Phase B (Data): TUR -> SCAN -> SEND_DIAG -> SET_WINDOW -> GET_WINDOW -> READ10(data) -> WRITE10
```

### Scan Type Codes (from FUN_100b45c0, LS5000.md3)

| Code | Category | Description |
|------|----------|-------------|
| 0x40-0x45 | Preview | Preview scan variants |
| 0x80-0x81 | Focus | Focus with auto-exposure |
| 0x90-0x91 | Autofocus | Coarse and fine autofocus |
| 0xa0-0xa1 | Area | Area exposure/focus measurement |
| 0xb0-0xb4 | Calibration | Calibration scan passes |
| 0xc0-0xc1 | Vendor | Vendor command operations |
| 0xd0-0xd3, 0xd5-0xd6 | Main scan | Final scan variants |
| 0x800 | Custom | Type from param_1+0x34 |

---

## 8. Command Queue Architecture

### Queue Class Hierarchy

```
CCommandQueue (base, vtable 0x101319cc)
  +-- CStoppableCommandQueue (vtable 0x101353ac) -- for scan operations
  +-- CQueueAcquireImage (vtable 0x1013ea64) -- image acquisition
  +-- CQueueAcquireDRAGImage (vtable 0x1013eab4) -- DRAG acquisition
  +-- CQueueNotifier (vtable 0x1013eb04) -- completion notification

CCommandQueueManager (vtable 0x101319ac) -- queue execution engine
CProcessCommand (vtable 0x1013e7e4) -- individual command with message pump
```

### CCommandQueue Object Layout

| Offset | Field | Description |
|--------|-------|-------------|
| +0x00 | vtable_ptr | Class vtable |
| +0x08 | error_code | Error/status |
| +0x14 | state | 0=idle, 1=pending, 2=running, 3=complete |
| +0x18 | cmd_count | Number of queued commands |
| +0x1C | start_tick | GetTickCount() at queue start |
| +0x28 | cmd_buf_start | Pointer to command entry array |
| +0x2C | cmd_buf_end | Past-end pointer |

### Command Entry (32 bytes, stride 0x20)

| Offset | Field | Description |
|--------|-------|-------------|
| +0x00 | cmd_obj_ptr | MAID object (vtable with Execute at +0x5c) |
| +0x04 | param1 | MAID operation code |
| +0x08-0x10 | params 2-4 | Additional parameters |
| +0x14 | entry_state | 0=pending, 1=executing, 2=complete |
| +0x1C | callback | Completion callback |

### Execution Engine (FUN_10014510, 680 bytes)

1. Records start tick via `GetTickCount()`
2. Iterates command entries
3. For pending entries: calls `[cmd_vtable+0x5c](obj, p1, p2, p3, p4, callback, queue)` -- the actual MAID operation
4. For executing entries: calls `[cmd_vtable+0x5c](obj, 0, 0, 0)` -- poll/continue
5. Also checks timed command list at `0x10165374` using `GetTickCount()` deltas

---

## 9. MAID Error Handling

| MAID Error | Value | Action |
|------------|-------|--------|
| BUSY | -0x7A (-122) | Shows "scanner busy" string |
| TIMEOUT | -0x76 (-118) | Shows "timeout" string |
| CANCELLED | -0x7B (-123) | Calls cleanup functions |
| SPECIFIC_ERROR | 0x182 (386) | Shows specific error string |
| NOT_LOADED | 0xFFFFFFF8 (-8) | Module not loaded |
| NOT_FOUND | 0xFFFFFF05 (-251) | Capability not found |
| OUT_OF_MEMORY | 0xFFFFFF04 (-252) | Memory allocation failed |
| ALREADY_OPEN | 0xFFFFFF06 (-250) | Already in use |

---

## 10. RTTI Class Functional Map (321 Classes in NikonScan4.ds)

### Scan Orchestration (core workflow)
- `CCommandQueue`, `CStoppableCommandQueue` -- scan operation sequencing
- `CCommandQueueManager`, `CCommandQueuePtrWrapper` -- queue lifecycle
- `CProcessCommand`, `CProcessCommandManager` -- individual ops with UI pump

### MAID Interface (scanner communication)
- `CMaidBase`, `CMaidBaseData`, `CMaidBasePtrWrapper` -- MAID object wrappers
- `CMaidImageData`, `CMaidItem`, `CMaidModule`, `CMaidSource`, `CMaidThumbnailData`
- `CFrescoMaidImage`, `CFrescoMaidItem`, `CFrescoMaidModule`, `CFrescoMaidSource`
- `CFrescoMaidThumbnail`, `CFrescoPreviewMaidImage`

### TWAIN Interface
- `CNkTwainSource`, `CFrescoTwainSource` -- source implementation
- `VNkTwainArray/Container/Enumeration/OneValue/Range` -- TWAIN containers
- `TNkTwainNumericEnumeration<T>` (6 instantiations) -- typed enumerations
- `CNkTwainFix32Array/Enumeration/OneValue/Range` -- TW_FIX32 containers
- `CNkTwainIncomingArray/Enumeration/OneValue` -- received data containers

### DRAG/ICE Processing
- `CDRAGBase`, `CDRAGProcess`, `CDRAGPrepareCommand`, `CDRAGProcessCommand`, `CDRAGProcessCommandQueue`
- `CREVProcess`, `CRevProcessCommand` -- Scanner Revelation processing
- `CQueueAcquireImage`, `CQueueAcquireDRAGImage`, `CQueueNotifier`

### Image Processing (Strato integration)
- `IStratoDataDestination`, `IStratoDataSource`, `IStratoImage` -- pipeline I/O
- `CNkImageProcSet` -- image processing parameter set
- `CNkLutChannel`, `CNkLutChannelBase`, `CNkLutEdit`, `CNkLutGroup`, `CNkLutViewer` -- LUT editing

### Preferences Dialogs (22 CPrefTab* classes)
- `CPrefTab` (base), `CPrefTabAdColor`, `CPrefTabAdColorCMYK/Gray/RGB`
- `CPrefTabAutoAction`, `CPrefTabBatchScan`, `CPrefTabCalibration`
- `CPrefTabCMS`, `CPrefTabCMSCMYK/Gray/LCH/RGB` -- per-space CMS settings
- `CPrefTabDevice`, `CPrefTabPreview`, `CPrefTabSingleScan`
- `CPrefMonitorGamma` -- monitor gamma calibration

### Tool Dialogs (19 CToolDlg* classes)
- `CToolDlg` (base), `CToolDlgAnalogGain` -- per-channel analog gain
- `CToolDlgColorBalance` -- color balance adjustment
- `CToolDlgCrop` -- crop region selection
- `CToolDlgCurves` (base), `CToolDlgCurvesCMYK/Generic/Gray/LCH/RGB` -- tone curves
- `CToolDlgLutEditor` -- raw LUT editing
- `CToolDlgScan` -- scan operation dialog
- `CToolDlgSize`, `CToolDlgUnsharpMask` -- resize and sharpening

### Preview/Thumbnail
- `CDlgPreview`, `CPreviewContainer`, `CPreviewCtrlTab`, `CPreviewWndWrapper`
- `CNkDrawingPreview`, `CNkPreviewCtrl`
- `CThumbnailTab`, `CThumbnailWnd`, `CNkThumbnailListBox/Item/Scroll`

### UI Controls
- `CNkButton`, `CNkButtonBase`, `CNkBitmapButton`, `CNkArrowButton`, `CNkPushButton`
- `CNkCheckBox`, `CNkComboBox`, `CNkListBox`, `CNkListItem`
- `CNkSlider`, `CNkScrollerBar`
- `CNkCoordCtrl`, `CRectCtrl` -- coordinate entry
- `CCascadeFrame/Group/Pane` -- cascade layout

### Settings/Profiles
- `CFrescoSettings`, `CWinSettings`, `CNkSettings` -- settings storage
- `CProfileFileDialog`, `CProfileLookup` -- ICC profile management

---

## 11. Transport Layer Interface

### NkDriverEntry Function Codes

| FC | Purpose | Used By |
|----|---------|---------|
| 1 | Init transport | `LS5000.md3:0x100a45dc`, passes "1200" version string |
| 2 | Close transport (stage 1) | `LS5000.md3:0x100a4694` |
| 3 | Close cleanup (stage 2) | `LS5000.md3:0x100a472b` |
| 5 | **Execute SCSI command** | All SCSI ops via `0x100ae3c0` |

### CommandParams Structure (FC5 Input)

Built by core execute at `LS5000.md3:0x100ae3c0`:

| Offset | Size | Field |
|--------|------|-------|
| +0x00 | 4 | Data buffer pointer |
| +0x04 | 4 | Secondary buffer pointer |
| +0x14 | 4 | CDB length (6 or 10) |
| +0x18 | 4 | CDB buffer pointer |
| +0x1C | 4 | Transfer length |
| +0x20 | 4 | Data direction (1=in, 2=out) |
| +0x24 | 4 | Flags (always 0x20) |

### Transport Loading

LS5000.md3 dynamically loads the transport at `0x100a44c0`:
1. `GetModuleFileNameA()` -- own path
2. Truncates to directory
3. Appends "Nkduscan.dll" or "Nkdsbp2.dll"
4. `LoadLibraryA()` + `GetProcAddress("NkDriverEntry")`
5. Stores at `[this+4]` (function), `[this+8]` (HMODULE)

---

## 12. User-Facing Options Summary (for Driver Developers)

A new driver should expose these user-controllable parameters:

| Option | MAID Path | SCSI Encoding | Range |
|--------|-----------|---------------|-------|
| **Resolution** | 0x121/0x122 | SET WINDOW bytes 10-13 | 150-4000 DPI (LS-50) |
| **Bit Depth** | 0x126 | SET WINDOW byte 34 | 8, 14, or 16 bits/channel |
| **Color Mode** | 0x125 | SET WINDOW byte 33 | 0=line-art, 2=gray, 5=color |
| **Scan Area** | 0x123 (4-part) | SET WINDOW bytes 14-29 | Model-dependent |
| **Film Type** | 0x103 (vendor ext) | SET WINDOW byte 54+ | From GET WINDOW |
| **Multi-Sample** | Scan type code | SET WINDOW byte 50 | 1,2,4,8,16,32,64x |
| **ICE Enable** | 0x800C (MAID cap) -> 0xa20 | SET WINDOW ICE area | Boolean |
| **Scan Direction** | 0x25 (MAID cap) | SET WINDOW vendor | 0=fwd, 1=rev |
| **Analog Gain** | 0x102 (vendor ext) | SET WINDOW byte 54+ | From GET WINDOW |
| **Exposure** | 0x104 (vendor ext) | SET WINDOW byte 54+ | From GET WINDOW |
| **Brightness** | 0x100 | SET WINDOW byte 30 | 0-255 |
| **Contrast** | 0x101 | SET WINDOW byte 32 | 0-255 |
| **Focus Position** | Via E0/C1/E1 vendor cmds | Not in SET WINDOW | E1 sub 0x42 |
| **DRAG (ROC/GEM)** | 0x801D (MAID cap) | Host-side processing | Boolean |

---

## Cross-References

- [TWAIN Dispatch](../components/nikonscan4-ds/twain-dispatch.md)
- [Scan Workflows](../components/nikonscan4-ds/scan-workflows.md)
- [Command Queue](../components/nikonscan4-ds/command-queue.md)
- [MAID Entry Point](../components/ls5000-md3/maid-entrypoint.md)
- [SCSI Command Catalog](../components/ls5000-md3/scsi-command-build.md)
- [Scan Operation Vtables](../components/ls5000-md3/scan-operation-vtables.md)
- [SET WINDOW Descriptor](../scsi-commands/set-window-descriptor.md)
- [USB Protocol](../architecture/usb-protocol.md)
- [Image Processing Pipeline](image-processing-pipeline.md)
