# LS5000.md3 Export Analysis

**Status**: Complete
**Last Updated**: 2026-02-21
**Phase**: 2 (SCSI Commands)
**Confidence**: High (verified from disassembly)

## Overview

LS5000.md3 is a ~1MB PE32 DLL shared by the Coolscan V (LS-50) and Super Coolscan 5000 (LS-5000). It exports 3 functions and dynamically loads the transport DLL (NKDUSCAN.dll or NKDSBP2.dll) at runtime via `LoadLibraryA`/`GetProcAddress`.

## Exports

### 1. MAIDEntryPoint (RVA 0x298F0)

**Signature**: `int __stdcall MAIDEntryPoint(int operation_code, ...)`

The primary MAID (Module Architecture for Imaging Devices) callback entry point. Receives capability IDs and operation codes from the TWAIN data source (NikonScan4.ds).

**Dispatch**: 16-case switch table at `0x10029b30`

| Case | Handler | Notes |
|------|---------|-------|
| 0 | 0x10029905 | |
| 1 | 0x10029933 | |
| 2 | 0x10029961 | |
| 3 | 0x1002998f | |
| 4 | 0x100299bd | |
| 5-9 | 0x100299eb | Default/unimplemented (shared handler) |
| 10 | 0x10029a18 | |
| 11 | 0x10029a46 | |
| 12 | 0x10029a74 | |
| 13 | 0x100299eb | Default/unimplemented |
| 14 | 0x10029aa2 | |
| 15 | 0x10029ad0 | |

Active cases (10 of 16): 0, 1, 2, 3, 4, 10, 11, 12, 14, 15

Each handler forwards parameters to a dedicated function:

| Case | Handler | Likely MAID Operation |
|------|---------|----------------------|
| 0 | `0x10028560` | Open / Initialize module |
| 1 | `0x10029070` | Close / Shutdown module |
| 2 | `0x100287e0` | Enumerate capabilities |
| 3 | `0x100271c0` | Get capability value |
| 4 | `0x10027230` | Set capability value |
| 10 | `0x100275d0` | Start operation (scan, preview, etc.) |
| 11 | `0x10027810` | Get capability default |
| 12 | `0x10027a80` | Capability changed notification |
| 14 | `0x10027cf0` | Abort / Cancel operation |
| 15 | `0x10027f60` | Query status |

MAID capabilities are numeric IDs that map to scanner parameters. Known capability categories (from NikonScan4.ds TWAIN layer):
- **Resolution** → SET WINDOW CDB fields
- **Bit depth** → SET WINDOW CDB fields
- **Scan area** → SET WINDOW CDB fields
- **Film type** → MODE SELECT mode pages
- **Color space** → MODE SELECT mode pages
- **Focus** → Vendor commands (0xE0/0xE1)
- **Exposure** → Vendor commands
- **Gamma/LUT** → WRITE(10) with LUT data
- **Calibration** → SEND DIAGNOSTIC + READ/WRITE
- **Scanner status** → TEST UNIT READY, INQUIRY, vendor 0xC0/0xC1

### MAID Dispatch Architecture

The MAID handlers (cases 3, 4, 10) do NOT directly call SCSI command factories. Instead they dispatch through capability objects with their own vtables:

1. Handler gets capability manager from context structure at `[esi + 0x0c]`
2. Calls vtable[0] on capability manager with a capability ID constant (e.g., `push 0x1007`)
3. Capability handler chains through multiple vtable layers
4. Eventually reaches SCSI command factories at the bottom layer

This multi-layer indirection means individual MAID capability IDs cannot be trivially mapped to single SCSI commands. A full numeric ID mapping requires Phase 3 (NikonScan4.ds TWAIN layer) analysis.

### MAID Operation → SCSI Command Sequences

Instead of individual capability ID mapping, the following maps **operational sequences** — the groups of SCSI commands that execute for each major scanner operation. Verified from callsite cross-references.

#### Scanner Open/Initialize (`fcn.100af200`, 942 bytes)

This function is called during MAID case 0 (Open). It performs the full initialization sequence:

| Step | SCSI Command | Factory | Purpose |
|------|-------------|---------|---------|
| 1 | TEST UNIT READY (0x00) | `0x100aa2a0` | Check scanner is powered on |
| 2 | INQUIRY (0x12) | `0x100aa2e0` | Get scanner model/revision |
| 3 | RESERVE (0x16) | `0x100aa330` | Lock scanner for exclusive use |
| 4 | GET WINDOW (0x25) | `0x100aa3b0` | Read default scan parameters |
| 5 | MODE SELECT (0x15) | `0x100aa440` | Set initial mode pages |
| 6 | SEND DIAGNOSTIC (0x1D) | `0x100aa370` | Self-test/calibration trigger |
| 7 | READ (0x28) | `0x100b5000` | Read calibration/status data |

Source: `LS5000.md3:0x100af200`

#### Focus/Exposure Control (`0x100b0400` area)

Executed when MAID set capability triggers focus or exposure changes:

| Step | SCSI Command | Factory | Purpose |
|------|-------------|---------|---------|
| 1 | TEST UNIT READY (0x00) | `0x100aa2a0` | Ready check |
| 2 | VENDOR 0xE0 | `0x100aa4c0` | Send focus/exposure parameters |
| 3 | VENDOR 0xC1 | `0x100aa580` | Trigger the control action |
| 4 | VENDOR 0xE1 | `0x100aa500` | Read sensor response |
| 5 | SEND DIAGNOSTIC (0x1D) | `0x100aa370` | Finalize |

Source: `LS5000.md3:0x100b0400`

This confirms the vendor command relationship: **0xE0 sends → 0xC1 triggers → 0xE1 reads back**.

#### Calibration with Data (`0x100b0d30` area)

Extended calibration sequence involving data read/write plus vendor commands:

| Step | SCSI Command | Factory | Purpose |
|------|-------------|---------|---------|
| 1 | READ (0x28) | `0x100b5000` | Read current calibration data |
| 2 | WRITE (0x2A) | `0x100b50c0` | Write updated calibration/LUT |
| 3 | TEST UNIT READY (0x00) | `0x100aa2a0` | Ready check |
| 4 | VENDOR 0xE0 | `0x100aa4c0` | Send control parameters |
| 5 | VENDOR 0xC1 | `0x100aa580` | Trigger |
| 6 | VENDOR 0xE1 | `0x100aa500` | Read response |
| 7 | SEND DIAGNOSTIC (0x1D) | `0x100aa370` | Finalize |

Source: `LS5000.md3:0x100b0d30`

#### Scan Operation (`0x100b3c00-0x100b4c00` area)

The main scan workflow, triggered by MAID case 10 (Start operation):

| Step | SCSI Command | Factory | Purpose |
|------|-------------|---------|---------|
| 1 | SET WINDOW (0x24) | `0x100aa400` | Configure scan parameters |
| 2 | SEND DIAGNOSTIC (0x1D) | `0x100aa370` | Pre-scan calibration |
| 3 | TEST UNIT READY (0x00) | `0x100aa2a0` | Wait for ready |
| 4 | TEST UNIT READY (0x00) | `0x100aa2a0` | Poll ready |
| 5 | SET WINDOW (0x24) | `0x100aa400` | Reconfigure after calibration |
| 6 | SEND DIAGNOSTIC (0x1D) | `0x100aa370` | Second diagnostic pass |
| 7 | GET WINDOW (0x25) | `0x100aa3b0` | Verify accepted parameters |
| 8 | SET WINDOW (0x24) | `0x100aa400` | Final scan configuration |
| 9 | TEST UNIT READY (0x00) | `0x100aa2a0` | Final ready check |
| 10 | **SCAN (0x1B)** | `0x100aa540` | **START SCAN** |
| 11 | SET WINDOW (0x24) | `0x100aa400` | Post-scan reconfigure |
| 12 | GET WINDOW (0x25) | `0x100aa3b0` | Verify parameters |
| 13 | SEND DIAGNOSTIC (0x1D) | `0x100aa370` | Post-scan diagnostic |
| 14 | WRITE (0x2A) | `0x100b50c0` | Write LUT/correction data |
| 15 | READ (0x28) | `0x100b5000` | **Read scan image data** |

Source: `LS5000.md3:0x100b3c00-0x100b4c00`

#### Device Query/Status (`0x100b1800-0x100b2800` area)

Device identification and status queries, used by MAID cases 2, 3, 11, 15:

| Step | SCSI Command | Factory | Purpose |
|------|-------------|---------|---------|
| 1 | TEST UNIT READY (0x00) | `0x100aa2a0` | Ready check |
| 2 | INQUIRY (0x12) | `0x100aa2e0` | Device identification |
| 3 | SEND DIAGNOSTIC (0x1D) | `0x100aa370` | Diagnostic query |
| 4 | READ (0x28) | `0x100b5000` | Read diagnostic data |
| 5 | INQUIRY (0x12) | `0x100aa2e0` | Additional EVPD pages |

Source: `LS5000.md3:0x100b1800-0x100b2800`

### Capability Category → SCSI Command Summary

| Capability Category | SCSI Commands Used |
|---------------------|-------------------|
| Scanner open/init | TUR → INQUIRY → RESERVE → GET WINDOW → MODE SELECT → SEND DIAG → READ |
| Resolution/area/depth | SET WINDOW (parameters encoded in window descriptor) |
| Film type/color space | MODE SELECT (mode pages) |
| Focus control | TUR → E0 (set) → C1 (trigger) → E1 (readback) → SEND DIAG |
| Exposure control | TUR → E0 (set) → C1 (trigger) → E1 (readback) → SEND DIAG |
| Gamma/LUT tables | WRITE (LUT data to scanner) |
| Calibration | READ + WRITE + E0 + C1 + E1 + SEND DIAG |
| Start scan | SET WINDOW × 3 → SEND DIAG → TUR → SCAN → READ |
| Scanner status | TUR, INQUIRY, C0/C1 |

Source: `LS5000.md3:0x100298F0` (entry), `0x10029b30` (switch table), factory cross-references

### 2. NkCtrlEntry (RVA 0x9BDD0)

**Mangled name**: `?NkCtrlEntry@@YGFFFFPAX@Z`
**Demangled**: `short __stdcall NkCtrlEntry(short, short, short, short, void*)`

Control entry point for scanner operations. Takes 4 short parameters and a void pointer.

Source: `LS5000.md3:0x1009BDD0`

### 3. NkMDCtrlEntry (RVA 0xB120)

**Signature**: `int __stdcall NkMDCtrlEntry(int function_code, ...)`

Module device control entry. 4-case switch (function codes 1-4).

| FC | Purpose |
|----|---------|
| 1 | Initialize module |
| 2 | Query/get info |
| 3 | Control operation |
| 4 | Shutdown/cleanup |

Source: `LS5000.md3:0x1000B120`

## Transport Layer Loading

LS5000.md3 does **NOT** statically import `NkDriverEntry`. Instead, it loads the transport DLL dynamically.

### Transport Loader (0x100a44c0)

1. `GetModuleFileNameA(hModule, buf, MAX_PATH)` — gets own DLL path
2. Finds last `\` in path, truncates to directory
3. Appends transport DLL name ("Nkduscan.dll" at `0x100c4abc` or "Nkdsbp2.dll" at `0x100c4acc`)
4. `LoadLibraryA(full_path)` — loads transport DLL
5. `GetProcAddress(hDll, "NkDriverEntry")` — gets function pointer
6. Stores function pointer at `[this + 4]`, DLL handle at `[this + 8]`

Source: `LS5000.md3:0x100a44c0`

### Transport Object Architecture

Three-layer vtable dispatch for calling NkDriverEntry:

```
Scanner control object
  └─ [+0x20] Abstract transport base (vtable 0x100c4a60, 15 entries)
       └─ [+0x20] Inner concrete transport (vtable 0x100c4a9c, 8 entries)
            └─ [+0x04] NkDriverEntry function pointer
            └─ [+0x08] DLL module handle
```

**Abstract base vtable (0x100c4a60)**:
| Offset | Entry | Function |
|--------|-------|----------|
| +0x00 to +0x10 | [0]-[4] | purecall (0x1008e7fa) |
| +0x14 | [5] | 0x100a47f0 — Get transport context |
| +0x18 | [6] | 0x100a4590 — Get this pointer |
| +0x1C | [7] | 0x100a47c0 — **NkDriverEntry thunk** |
| +0x20 | [8] | 0x100a47e0 — Set transport config thunk |
| +0x24 to +0x30 | [9]-[12] | purecall |
| +0x34 | [13] | 0x100a48c0 — Destructor |
| +0x38 | [14] | purecall |

**NkDriverEntry thunk (0x100a47c0)**:
```asm
mov ecx, [ecx + 0x20]   ; get inner transport object
mov eax, [ecx]           ; get its vtable
jmp [eax + 0x10]         ; forward to inner vtable[4] = NkDriverEntry wrapper
```

**NkDriverEntry wrapper (0x100a48e0)**:
- Reads NkDriverEntry function pointer from `[edi + 4]`
- Receives function code and params from stack (stdcall)
- Special handling for FC5: copies `[edi + 0x14]` into `[param1 + 8]`
- Calls NkDriverEntry via `call dword [esp + 0x1c]`

Source: Thunk at `0x100a47c0`, wrapper at `0x100a48e0`

### "1200" Protocol Version

At FC1 (Initialize), the caller passes the string "1200" (stored at `0x100c4a58` as DWORD `0x30303231`) as a protocol version identifier. The transport validates this in `fcn.10006238`.

Init function at `0x100a45a0` copies "1200" to the params structure, then calls FC1 through the transport vtable thunk.

## Cross-References

- [NkDriverEntry API](../nkduscan/api.md) — Transport layer API
- [SCSI Command Catalog](scsi-command-build.md) — All SCSI commands sent through this module
- [USB Protocol](../../architecture/usb-protocol.md) — USB-level protocol details
