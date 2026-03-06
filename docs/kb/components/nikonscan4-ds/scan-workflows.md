# NikonScan4.ds Scan Workflows — Definitive Reference

**Status**: Complete
**Last Updated**: 2026-02-27
**Phase**: 3 (Scan Workflows)
**Confidence**: High (decompilation of key functions verified from vtable tracing and RTTI)

## Overview

NikonScan4.ds (2.2MB TWAIN data source) orchestrates all scanner operations. It receives user actions from the MFC GUI, configures scan parameters through the MAID (Module Architecture for Imaging Devices) interface, and delegates hardware control to LS5000.md3. This document traces the complete path from user action to SCSI commands.

## Architecture Layers

```
┌─────────────────────────────────────────────────────────┐
│  User clicks "Scan" / "Preview" / "Eject" in MFC GUI    │
│  MFC Control IDs: 0x46B=final, 0x46E=preview,          │
│                   0x470=thumb, 0x472=autofocus          │
└──────────────────────┬──────────────────────────────────┘
                       ▼
┌─────────────────────────────────────────────────────────┐
│  TWAIN DS_Entry Dispatch (NikonScan4.ds:0x10091e60)     │
│  CNkTwainSource singleton → handler table dispatch      │
│  (DAT<<16|MSG) → linked list lookup → type dispatch     │
└──────────────────────┬──────────────────────────────────┘
                       ▼
┌─────────────────────────────────────────────────────────┐
│  Scan Orchestrator (NikonScan4.ds:0x1003b200, 8430B)    │
│  - Gets scan source list, iterates sources              │
│  - Dynamic casts: CMaidBase → CTwainMaidImage            │
│  - Configures MAID capabilities (ICE, direction, etc.)  │
│  - Sets up ROI/scan area                                │
│  - Creates CStoppableCommandQueue                       │
└──────────────────────┬──────────────────────────────────┘
                       ▼
┌─────────────────────────────────────────────────────────┐
│  CTwainMaidImage vtable call chain                       │
│  Vtable at 0x10145cfc (60 entries)                      │
│  Key: [23]+0x5c = cap set/get thunk (→ inner object)    │
│       [47]+0xbc = cap exists check (red-black tree)     │
└──────────────────────┬──────────────────────────────────┘
                       ▼
┌─────────────────────────────────────────────────────────┐
│  CCommandQueue Execution Engine                          │
│  CCommandQueueManager::Execute @ 0x10014510 (680B)      │
│  Iterates command entries → [cmd_vtable+0x5c]           │
│  CProcessCommand: message pump for UI responsiveness    │
└──────────────────────┬──────────────────────────────────┘
                       ▼
┌─────────────────────────────────────────────────────────┐
│  CFrescoMaidModule::CallMAID @ 0x1007a1f0 (74B)         │
│  [this+0x74](device, opcode, capID, type, data, cb, ctx)│
│  Calls MAIDEntryPoint loaded from LS5000.md3            │
└──────────────────────┬──────────────────────────────────┘
                       ▼
┌─────────────────────────────────────────────────────────┐
│  LS5000.md3 MAIDEntryPoint @ 0x100298F0                 │
│  16-case switch → capability object hierarchy dispatch  │
│  → SCSI command factory → NkDriverEntry FC5             │
└──────────────────────┬──────────────────────────────────┘
                       ▼
┌─────────────────────────────────────────────────────────┐
│  NKDUSCAN.dll → usbscan.sys → USB bulk → scanner HW    │
└─────────────────────────────────────────────────────────┘
```

## MAID Operation Codes

NikonScan4.ds passes operation codes through CTwainMaidImage::vtable[23] (thin thunk at `0x10070500`) which forwards to the inner MAID source object, eventually reaching `MAIDEntryPoint` in LS5000.md3.

| Opcode | MAIDEntryPoint Case | LS5000 Handler | Purpose |
|--------|-------------------|----------------|---------|
| 0 | 0 | `0x10028560` | Open/Initialize module |
| 1 | 1 | `0x10029070` | Close/Shutdown module |
| 2 | 2 | `0x100287e0` | Enumerate capabilities |
| 3 | 3 | `0x100271c0` | Get capability (module-level) |
| 4 | 4 | `0x10027230` | Set capability (module-level, iterates cap tree) |
| **5** | 5 | `0x100273a0` | **Start capability operation** (object-level) |
| **6** | 6 | `0x100273a0` | **Set capability value** (object-level) |
| **7** | 7 | `0x100273a0` | **Get capability info/header** (object-level) |
| 8 | 8 | `0x100273a0` | (reserved, same handler) |
| **9** | 9 | `0x100273a0` | **Get capability data buffer** (object-level) |
| 10 | 10 | `0x100275d0` | Start scan operation |
| 11 | 11 | `0x10027810` | Get capability default |
| 12 | 12 | `0x10027a80` | Capability changed notification |
| 13 | 13 | `0x100273a0` | (reserved, same handler) |
| 14 | 14 | `0x10027cf0` | Abort/Cancel operation |
| 15 | 15 | `0x10027f60` | Query status |

**Key insight**: Opcodes 5-9 and 13 all route to the same handler `FUN_100273a0` (555 bytes) which is the **capability object-level dispatcher**. It looks up the capability object in the hierarchy tree at `[context+0xC]` and forwards the operation to the matched object's vtable. This was previously labeled "unimplemented" in Phase 2 docs — this is incorrect.

Source: `MAIDEntryPoint @ LS5000.md3:0x100298F0`, switch table at `0x10029b30`

## MAID Capability Object Hierarchy (LS5000.md3)

LS5000.md3 creates a tree of capability objects during module open (`FUN_10028be0`, 1164 bytes). Each object is registered with `FUN_10053bc0(capID, capType, &ptr)` and deregistered with `FUN_10053c90(capID)`.

```
0x8000 (type 0x100C) — Module root
└─ 0x8003 (type 0x0004) — Source/Device
   └─ 0x800B (type 0x101F) — Data Object
      └─ 0x8103 (type 0x1021) — Image Object A
         ├─ 0x8005 (type 0x1012) — Scan Parameters
         │  └─ 0x8007 (type 0x1016) — Multi-sample
         │     └─ 0x800C (type 0x1022) — ICE (infrared dust removal)
         │        └─ 0x800E (type 0x1023) — DRAG (Digital ROC/GEM)
         └─ 0x8105 (type 0x1025) — Image Object B
            └─ 0x8101 (type 0x101B) — (unknown)
```

Deregistration order (reverse of creation): 0x8105, 0x800E, 0x800C, 0x8007, 0x8005, 0x8103, 0x800B, 0x8003, 0x8000

Source: `LS5000.md3:0x10028be0` (creation), deregistration at end of close handler

### Capability Type Constants

| Type | Hex | Likely MAID SDK Constant |
|------|-----|-------------------------|
| 4 | 0x0004 | kNkMAIDCapType_Source |
| 0x100C | 0x100C | kNkMAIDCapType_Module |
| 0x1012 | 0x1012 | kNkMAIDCapType_ScanParam |
| 0x1016 | 0x1016 | kNkMAIDCapType_MultiSample |
| 0x101B | 0x101B | kNkMAIDCapType_? |
| 0x101F | 0x101F | kNkMAIDCapType_DataObject |
| 0x1021 | 0x1021 | kNkMAIDCapType_ImageObject |
| 0x1022 | 0x1022 | kNkMAIDCapType_ICE |
| 0x1023 | 0x1023 | kNkMAIDCapType_DRAG |
| 0x1025 | 0x1025 | kNkMAIDCapType_? |

## CTwainMaidImage Object

CTwainMaidImage is the NikonScan4.ds wrapper for a MAID image acquisition target. It inherits from CMaidBase.

### RTTI and Vtable

- **RTTI TypeDescriptor**: `0x10162728`
- **COL**: `0x1014c4d4` (sig=0, offset=0, cdOffset=0)
- **Vtable**: `0x10145cfc` (60 entries)
- **CMaidBase vtable**: `0x1013763c` (60 entries, shares most methods)

### Key Vtable Methods

| Entry | Offset | Address | Size | Method |
|-------|--------|---------|------|--------|
| 0 | +0x00 | 0x10075190 | 229 | Open/init — calls vtable[23](this,1,...) |
| 9 | +0x24 | 0x10052960 | — | CTwainMaidImage override (CMaidBase has 0x100707d0) |
| 11 | +0x2C | 0x100529f0 | 131 | Source iteration with vtable[0x24](4,this) |
| 14 | +0x38 | 0x100528e0 | — | CTwainMaidImage override |
| 17 | +0x44 | 0x10070510 | 287 | Get cap data — calls vtable[23](this,7,...) then vtable[23](this,9,...) |
| 19 | +0x4C | 0x100723c0 | 280 | Close — sets caps then calls vtable[23](this,2,...) |
| 21 | +0x54 | 0x10071700 | 74 | Lookup child by ID in [this+0x34..0x38] array |
| 22 | +0x58 | 0x10071750 | 40 | Remove all children via vtable[20] |
| **23** | **+0x5C** | **0x10070500** | **12** | **MAID cap set/get thunk** — forwards to inner object |
| 27 | +0x6C | 0x10075420 | — | CTwainMaidImage override (CMaidBase has 0x100700b0) |
| 40 | +0xA0 | 0x10070230 | 154 | Set name — vtable[23](this,6,10,0xb,str,...) |
| 42 | +0xA8 | 0x100703e0 | 162 | Set range — vtable[23](this,6,8,0xf,range,...) |
| 43 | +0xAC | 0x10070490 | 74 | Start op — vtable[23](this,5,0x34,...) |
| **47** | **+0xBC** | **0x100724e0** | **111** | **Cap exists check** — searches red-black tree at [this+0x28] |

### vtable[23] Thunk (FUN_10070500)

```c
// 12 bytes — thin thunk forwarding to inner MAID source object
void __fastcall FUN_10070500(int *param_1) {
    int *inner = (**(code **)(*param_1 + 0x64))(); // vtable[25] = get inner object
    (**(code **)(*inner + 0x5c))();                 // Forward to inner's vtable[23]
}
```

This chains through: CTwainMaidImage → inner MAID source → CFrescoMaidSource → CFrescoMaidModule::CallMAID → MAIDEntryPoint

### vtable[47] Cap Exists Check (FUN_100724e0)

Searches a **red-black tree** (STL std::map) stored at `[this+0x28]`. Each node has the capability ID at `node[3]`. Returns `true` if the ID is found, `false` otherwise. Used by the scan orchestrator to check if optional capabilities (ICE, multi-sample, etc.) are supported before trying to configure them.

## Scan Workflow: StartScan

### Entry Point

`StartScan` export (ordinal 48, `NikonScan4.ds:0x10047C20`, 86 bytes)

```
StartScan → FUN_1003d420 → FUN_1003b200 (8430 bytes, main orchestrator)
```

### Orchestrator Logic (FUN_1003b200)

The 8430-byte scan orchestrator performs these steps:

#### 1. Source Enumeration
- `FUN_10104240()` → get source count
- Allocates source ID array
- `FUN_10104280()` → fill source IDs

#### 2. Film Type Check
- Iterates sources, checks `[source+0x1C]` for film type
- Film type 4 = negative film
- If negative: prompts via `FUN_1001d420(0)` (dialog 0x43A → exposure warning)

#### 3. Exposure Calibration Check
- Checks `FUN_1008c270(0x41A, ...)` for pending exposure calibration
- If needed: shows dialog via `FUN_10040600(0)`

#### 4. Multi-Frame Setup (film strips)
- Checks `[param_1+0x60]` for multi-frame source
- Gets frame count, sets up batching via `[source+0x120]`

#### 5. Film Batch Settings
- Dialog 0x42D for batch settings
- `FUN_1001cf30()` for film strip configuration
- Dialog 0x43E for multi-frame confirmation

#### 6. CStoppableCommandQueue Creation
- Creates queue via `FUN_1004d3e0(context, 0x3422, 1)` with control ID `0x3422`
- `FUN_1006b100(queue, 8, -1, 0)` → configure queue

#### 7. Per-Source MAID Configuration (the core loop)

For each scan source:
```
a. Get MAID image object:
   local_64 = [source+0x18]->vtable[0x94/4](1, &local_64)

b. Dynamic cast to image type:
   piVar19 = __RTDynamicCast(local_64, 0,
       &CMaidBase::RTTI_Type_Descriptor,
       &CTwainMaidImage::RTTI_Type_Descriptor, 0)

c. Check scanner type via FUN_10084610():
   0x31C1 → disable multi-sample
   0x31C2 → disable scan direction
   0x31C5 → enable additional option
   0x31C6 → enable ICE

d. Configure MAID capabilities:
```

**MAID Capability Configuration in Scan Orchestrator:**

| Cap ID | Opcode | DataType | Value Source | Description |
|--------|--------|----------|-------------|-------------|
| 0x800C | 6 (set) | 1 (bool) | local_30 | ICE enable/disable |
| 0x25 | 6 (set) | 1 (bool) | local_3c | Scan direction (0=forward, 1=reverse) |
| 0x8007 | 6 (set) | 1 (bool) | local_44 | Multi-sample enable |
| 0x801B | 7 (get) | 10 (rect) | &local_278 | Get ROI/scan area bounds |
| 0x801D | 6 (set) | 1 (bool) | local_19 | Unknown boolean (auto-something?) |

These use the pattern:
```c
// Check if capability exists, then set it
if ((*vtable[47])(0x800c) != 0) {
    (*vtable[23])(obj, 6, 0x800c, 1, value, 0, 0);
}
```

#### 8. Resolution and ROI Setup
- Gets resolution via `[source+0xA0]` → double value
- Minimum resolution: 2000.0 DPI (for multi-frame)
- ROI from `piVar6->vtable[0x188/4]()` → RECT structure
- For multi-frame: offsets ROI per frame, scales by ratio

#### 9. Set Window Parameters
- `(*vtable[0x1B0/4])(&local_238)` → sets scan area on MAID object
- Area structure: {left, top, width, height}

#### 10. Scan Execution
- `FUN_10053b30(local_48+0x80)` / `FUN_10053b80(local_48+0x84)` → pre-scan setup
- Calls through MAID to trigger scan (ultimately SCSI SCAN command 0x1B)

### MAID Capability → SCSI Command Mapping

When the scan orchestrator sets capability values through MAID, they flow through to LS5000.md3 where they translate to SCSI commands:

| Cap ID | NikonScan4 Sets | LS5000.md3 Translates To | SCSI Result |
|--------|----------------|------------------------|-------------|
| 0x800C (ICE) | Boolean on/off | Scan parameter object | MODE SELECT mode page or SET WINDOW field |
| 0x25 (direction) | Boolean fwd/rev | Scan parameter object | SET WINDOW scan direction field |
| 0x8007 (multi-sample) | Boolean enable | Multi-sample object | SET WINDOW multi-sample field |
| 0x8005 (scan params) | Resolution, etc. | Scan parameter object | SET WINDOW descriptor (resolution, area, depth) |
| 0x801B (ROI) | RECT structure | Image object property | SET WINDOW scan area fields |
| 0x801D (unknown) | Boolean | Image object property | Unknown (possibly auto-exposure flag) |

### Detailed SCSI Command Sequences per Workflow Type

LS5000.md3 implements scan workflows using a vtable-based object hierarchy. Each scan type has two phases (A and B), each with a command factory and step handler. See [Scan Operation Vtables](../ls5000-md3/scan-operation-vtables.md) for full architecture.

#### Init Sequence (Base/Type A Phase A)
```
TUR (0x00) → INQUIRY (0x12) → RESERVE (0x16) → MODE SELECT (0x15) →
SEND DIAGNOSTIC (0x1D) → GET WINDOW (0x25) → READ10 (0x28, sub=0x88/0x91)
```
Factory: `FUN_100af1f0` (958 bytes). Handler: `FUN_100b3060` (983 bytes).
The handler processes INQUIRY results, stores GET WINDOW data, reads calibration data via READ10, and dynamically inserts SEND_DIAG steps based on scanner state.

#### Main Scan (Type A Phase B)
```
TUR (0x00) → SEND DIAGNOSTIC (0x1D) → SET WINDOW (0x24, with full param builder)
```
Factory: `FUN_100b3b90` (368 bytes). Handler: `FUN_100afd00` (314 bytes).
SET WINDOW calls `FUN_100b3a50`→`FUN_100b2b30` to build the full window descriptor with all scan parameters.

#### Simple Scan — Phase A (Type B)
```
SET WINDOW (0x24)
```
Factory: `FUN_100b4040` (194 bytes). Only sends SET WINDOW to configure scan parameters.

#### Simple Scan — Phase B (Type B)
```
TUR (0x00) → SCAN (0x1B) → SEND DIAGNOSTIC (0x1D) → SET WINDOW (0x24) →
GET WINDOW (0x25) → READ10 (0x28, sub=0x87) → WRITE10 (0x2A)
```
Factory: `FUN_100b41a0` (898 bytes). Handler: `FUN_100b36e0` (724 bytes).
This is the full scan cycle: configure → execute → verify → transfer data. READ10 sub-code 0x87 transfers scan image data. WRITE10 sends LUT/correction data.

#### Focus/Autofocus — Phase A (Type C)
```
TUR (0x00) → SEND DIAGNOSTIC (0x1D) → E0 (vendor write) → C1 (vendor trigger) → E1 (vendor read)
```
Factory: `FUN_100b0380` (617 bytes). Handler: `FUN_100b06f0` (1304 bytes).
Uses the vendor E0→C1→E1 loop for focus/exposure control. E1 response at sub-cmd 0x42 returns focus position, 0xC0 returns exposure value.

#### Focus/Autofocus — Phase B (Type C)
```
TUR (0x00) → SEND DIAGNOSTIC (0x1D) → READ10 (0x28) → WRITE10 (0x2A) →
E0 → C1 → E1 (vendor loop)
```
Factory: `FUN_100b0c20` (1021 bytes). Handler: `FUN_100b1170` (1376 bytes).
Adds READ10/WRITE10 for calibration data exchange alongside the vendor command loop.

#### Advanced Operations (Type D Phase B)
```
TUR (0x00) → INQUIRY (0x12) → SEND DIAGNOSTIC (0x1D) → READ10 (0x28, sub=0x88)
```
Factory: `FUN_100b17e0` (546 bytes). Handler: `FUN_100b1a90` (663 bytes).
Used for diagnostics and calibration. INQUIRY has special readiness check via `FUN_100a03d0`.

#### Complete Final Scan Sequence (Init + Main Scan)
```
Phase A (Init):
  TUR → INQUIRY → RESERVE → MODE_SELECT → SEND_DIAG → GET_WINDOW → READ10

Phase B (Main Scan):
  TUR → SEND_DIAG → SET_WINDOW(full descriptor)
  [then Simple Scan Phase B handles the actual data transfer]:
  TUR → SCAN → SEND_DIAG → SET_WINDOW → GET_WINDOW → READ10 → WRITE10
```

Source: `LS5000.md3` scan phase vtables at 0x100c526c-0x100c538c, decompiled in `ghidra/exports/ls5000_scan_phases.txt`

## Additional Capability IDs Used

From other NikonScan4.ds functions:

| Cap ID | Opcode | DataType | Context | Description |
|--------|--------|----------|---------|-------------|
| 0x801A | 7 (get) | 4 (uint) | Scan config | Scanner property (read) |
| 0x80A3 | 7 (get) | 4 (uint) | Scan config | Scanner property (read) |
| 0x80A4 | 7 (get) | 4 (uint) | Scan config | Scanner property (read) |
| 0x8001 | — | — | Comparison | Module ID / marker value |
| 2 | 6 (set) | 0xD | Close handler | Property before close |
| 3 | 6 (set) | 0xD | Close handler | Property before close |
| 4 | 6 (set) | 0xD | Close handler | Property before close |
| 5 | 6 (set) | 0xD | Close handler | Property before close |
| 8 | 6 (set) | 0xF (range) | Set range | Resolution/area bounds |
| 10 | 6 (set) | 0xB (string) | Set name | Source/device name |
| 0x34 | 5 (start) | 0 | Start op | Start scan operation |

### Cap ID → UI String Mapping (FUN_10043f60)

| Cap ID | MFC String ID | Description |
|--------|---------------|-------------|
| 0x8010 | 0x3435 | Progress indicator |
| 0x801A | 0x341C | Scanner property display |
| 0x801B | 0x341D | ROI/area display |
| 0x801D | 0x341E | Unknown property display |
| 0x80A3 | 0x3434 | Scanner property display |
| 0x8011-0x80A2 | (default) | Fallthrough to generic handler |

Source: `NikonScan4.ds:0x10043F60`

## Scan Workflow: Eject / Film Advance

### Entry Point

`Eject` export (ordinal 8, `NikonScan4.ds:0x10047AA0`, 86 bytes)

```
Eject → FUN_10055c20() [get singleton]
      → vtable[0x1B4/4]() [check state]
      → FUN_10089c30() [get current source]
      → FUN_100318b0() [execute eject]
```

`CanEject` export (ordinal 4, `NikonScan4.ds:0x100479E0`, 93 bytes) follows same pattern but calls `FUN_1001fdc0()` to check if eject is possible.

### Execute Eject (FUN_1002e030, 577 bytes)

The eject executor at `NikonScan4.ds:0x1002E030` performs:

1. **Ready check**: `FUN_10069760()` — verifies scanner is available
2. **Confirmation dialog**: Shows MFC dialog (string 0x401a) via `Ordinal_1014`. If user cancels (returns 2), abort.
3. **Create command queue**: `Ordinal_703(0x34)` allocates 52-byte object, sets vtable to `PTR_FUN_10132d3c`, calls `FUN_10014320(0)` constructor
4. **Film state check**: `scanner_source→vtable[0x11c]()` — checks if film is loaded
5. **Dispatch**:
   - If film loaded AND **Ctrl key NOT held** (`GetKeyState(0x11) >= 0`): calls `vtable[0x14c](queue)` → **Film Advance**
   - If film loaded AND **Ctrl key held**: calls `vtable[0x148](queue)` → **Eject**
   - If no film: calls `FUN_1002db40(source_id)` then `vtable[0x148](queue)` → **Eject** (eject adapter)
6. **Execute loop**: `vtable[0x0c]()` starts, polls `vtable[0x18]()` with message pump `FUN_100148b0()` until complete
7. **Cleanup**: Sets `[param_1+0x71c] = 1` (eject complete flag), updates UI

### SCSI Commands for Eject

All SCSI commands go through the scan operation vtable machinery (confirmed: zero eject-specific SCSI factory calls exist outside the scan operation area 0x100AF000-0x100B5500). The eject command queue triggers a MAID "start operation" which creates a scan operation object. The operation type code determines which SCSI commands are sent through the step queue.

The likely SCSI sequence for eject/film advance is:
```
TUR (0x00) → SEND DIAGNOSTIC (0x1D, with eject/advance page data)
```

SEND DIAGNOSTIC (0x1D) is the general-purpose command used for scanner motor control operations, including film transport.

Source: `NikonScan4.ds:0x1002E030` (eject executor), `NikonScan4.ds:0x100318B0` (wrapper), confirmed by SCSI factory caller analysis

## UI Parameter → SCSI Parameter Mapping Summary

This table maps user-facing settings to their SCSI representation:

| UI Parameter | MAID Param ID | SET WINDOW Offset | SCSI Encoding |
|-------------|---------------|-------------------|---------------|
| **Resolution** (DPI) | 0x121 (X), 0x122 (Y) | Bytes 10-13 | Big-endian 16-bit per axis |
| **Bit depth** (8/14/16) | 0x126 | Byte 34 | Direct value (8, 14, or 16) |
| **Color mode** (RGB/gray/line-art) | 0x125 | Byte 33 | 0=line-art, 1=halftone, 2=gray, 5=color |
| **Scan area** (x, y, w, h) | 0x123 | Bytes 14-29 | Big-endian 32-bit per dimension, scanner units |
| **Film type** (pos/neg/B&W) | 0x103 (likely) | Vendor ext (54+) | Dynamic size from scanner; also orchestrator logic at [source+0x1C] affects MODE SELECT |
| **Gain/offset** (analog) | 0x102 (likely) | Vendor ext (54+) | Dynamic size from scanner; also via vendor E0 command |
| **Multi-sample** (1x-64x) | byte 50 encoding | Byte 50 | 0x20=1, 0x21=2, 0x22=4, 0x23=16, 0x24=32, 0x25=64, 0x31=8 |
| **ICE** (on/off) | 0xa20 | ICE/DRAG area | 1 byte master enable |
| **Brightness** | 0x100 | Byte 30 | 1 byte (0-255) |
| **Contrast** | 0x101 | Byte 32 | 1 byte (0-255) |

**Note on film type and gain/offset**: These parameters flow through vendor extension params 0x102-0x10d, which are dynamically registered from the scanner's GET WINDOW response. The exact mapping of param ID to purpose requires firmware analysis (Phase 4) or USB capture data. The assignments above are inferred from SCSI scanner conventions.

Source: `LS5000.md3:0x100B2B30` (SET WINDOW builder), `LS5000.md3:0x100A2980` (vendor ext registration)

## UI Parameter Export API

NikonScan4.ds exports functions for querying available scan parameters:

| Export | Ordinal | Address | Purpose |
|--------|---------|---------|---------|
| `GetColorSpaceCount` | 17 | 0x100474B0 | Number of color spaces |
| `GetColorSpaceItem` | 18 | 0x10047510 | Get color space by index |
| `GetFilmTypeCount` | 21 | 0x100475E0 | Number of film types |
| `GetFilmTypeItem` | 22 | 0x10047640 | Get film type by index |
| `GetBitDepthCount` | 10 | 0x100483A0 | Number of bit depths |
| `GetBitDepthItem` | 11 | 0x10048400 | Get bit depth by index |
| `GetSampleSize` | 34 | 0x10048360 | Current sample size |
| `GetMonitorGamma` | 28 | 0x10047440 | Monitor gamma value |
| `GetProgress` | 32 | 0x10047F30 | Current scan progress |
| `GetSelectedItemsCount` | 35 | 0x100478B0 | Selected scan items |

These exports enumerate scanner capabilities that were discovered through MAID opcode 2 (Enumerate) during scanner initialization.

## MFC Control ID → Operation Type Map

From `CStoppableCommandQueue::StatusHandler` (`NikonScan4.ds:0x1004d0c0`, 573 bytes):

| MFC Control ID | Operation Code | Scan Type |
|----------------|---------------|-----------|
| 0x46B | 4 | Final scan (full resolution) |
| 0x46E | 1 | Preview scan (low resolution) |
| 0x470 | 2 | Thumbnail scan |
| 0x471 | 5 | (unknown operation) |
| 0x472 | 3 | Autofocus |
| 0x474 | 6 | (unknown operation) |

The CStoppableCommandQueue control ID for scan operations is `0x3422`.

Source: `NikonScan4.ds:0x1004d0c0`

## MAID Error Handling

From `CStoppableCommandQueue::StatusHandler`:

| MAID Error | Value | Action |
|------------|-------|--------|
| BUSY | -0x7A (-122) | Shows string 0x4017 ("scanner busy") |
| TIMEOUT | -0x76 (-118) | Shows string 0x4018 ("timeout") |
| CANCELLED | -0x7B (-123) | Calls FUN_10021fa0 + FUN_1006b1b0 |
| SPECIFIC_ERROR | 0x182 (386) | Shows string 0x401B |
| Other | — | Reports via FUN_1006b150 |

### Cap-Level Status Mapping (FUN_1006aa90)

| Progress Code | UI String ID | Meaning |
|---------------|-------------|---------|
| 0 | (completion) | Operation complete |
| 2 | 0x3420 | Status update |
| 0x14 | 0x3407 | Sub-operation status |
| 0x1C | 0x3406 | Sub-operation status |
| 0x1E | 0x3405 | Sub-operation status |
| 0x8010 | 0x3437 | Progress indicator |
| 0x801A | 0x3411 | Parameter status |
| 0x801B | 0x3412 | Area/ROI status |
| 0x801D | 0x3410 | Boolean status |
| 0x80A3 | 0x3436 | Property status |

Source: `NikonScan4.ds:0x1006aa90`

## Complete Scan Data Flow (StartScan)

```
1. User clicks "Scan" button (MFC control ID 0x46B)
   │
2. DS_Entry dispatch → TWAIN MSG_XFERREADY
   │
3. StartScan export → FUN_1003d420 → FUN_1003b200
   │
4. Scan orchestrator:
   ├─ Enumerate sources via FUN_10104240/10104280
   ├─ Check film type, exposure, calibration
   ├─ __RTDynamicCast(CMaidBase → CTwainMaidImage)
   │
5. Configure MAID capabilities:
   ├─ vtable[47](0x800C) → check ICE support
   ├─ vtable[23](obj,6,0x800C,1,ice_val,0,0) → set ICE
   ├─ vtable[23](obj,6,0x25,1,dir_val,0,0) → set direction
   ├─ vtable[23](obj,6,0x8007,1,ms_val,0,0) → set multi-sample
   ├─ vtable[47](0x801B) → check ROI support
   ├─ vtable[23](obj,7,0x801B,10,&roi,0,0) → get ROI bounds
   ├─ vtable[0x1B0/4](&area) → set scan area
   └─ vtable[47](0x801D) → check/set additional param
   │
6. Create CStoppableCommandQueue (control ID 0x3422)
   │
7. Queue MAID operations → CCommandQueueManager::Execute
   │
8. CFrescoMaidModule::CallMAID → [this+0x74](device, ...)
   │
9. MAIDEntryPoint @ LS5000.md3:
   ├─ Opcode 6 → FUN_100273a0 (cap object dispatcher)
   │  └─ Looks up cap object in tree → calls setter
   ├─ Opcode 10 → FUN_100275d0 (start operation)
   │  └─ Triggers SCSI scan sequence
   └─ Opcode 7 → FUN_100273a0 (cap object getter)
   │
10. LS5000.md3 SCSI command sequence (Type A vtable → Type B vtable):
    Phase A (Init):
    ├─ TUR (0x00) — check scanner ready
    ├─ INQUIRY (0x12) — get scanner identity/capabilities
    ├─ RESERVE (0x16) — lock scanner for exclusive use
    ├─ MODE SELECT (0x15) — configure operating mode
    ├─ SEND DIAGNOSTIC (0x1D) — pre-scan calibration
    ├─ GET WINDOW (0x25) — read current window params
    └─ READ10 (0x28) — read calibration data
    Phase B (Main Scan):
    ├─ TUR (0x00) — ready check
    ├─ SEND DIAGNOSTIC (0x1D) — prepare for scan
    └─ SET WINDOW (0x24) — full window descriptor (see set-window-descriptor.md)
    Then Simple Scan Phase B:
    ├─ TUR (0x00) — ready check
    ├─ SCAN (0x1B) — START SCAN
    ├─ SEND DIAGNOSTIC (0x1D) — post-scan
    ├─ SET WINDOW (0x24) — reconfigure
    ├─ GET WINDOW (0x25) — verify parameters
    ├─ READ10 (0x28, sub=0x87) — transfer scan image data
    └─ WRITE10 (0x2A) — send LUT/correction data
    │
11. NKDUSCAN.dll wraps CDBs for USB bulk transfer
    │
12. Scanner firmware (H8/3003) executes commands
```

## Related KB Docs

- [TWAIN Dispatch Architecture](twain-dispatch.md) — DS_Entry → handler table
- [Command Queue Architecture](command-queue.md) — Queue execution engine
- [LS5000.md3 MAID Entry Point](../ls5000-md3/maid-entrypoint.md) — MAID → SCSI mapping
- [LS5000.md3 SCSI Command Catalog](../ls5000-md3/scsi-command-build.md) — All 17 SCSI opcodes
- [LS5000.md3 Scan Operation Vtables](../ls5000-md3/scan-operation-vtables.md) — 5 vtable types, step queues
- [SET WINDOW Descriptor](../../scsi-commands/set-window-descriptor.md) — Byte-level parameter mapping
- [USB Protocol](../../architecture/usb-protocol.md) — USB-level CDB transport
