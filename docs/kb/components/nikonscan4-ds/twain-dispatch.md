# NikonScan4.ds TWAIN Dispatch Architecture

**Status**: Complete
**Last Updated**: 2026-02-27  |  **Phase**: 3  |  **Confidence**: High (verified from disassembly)

## Overview

NikonScan4.ds implements TWAIN data source functionality via `DS_Entry` (ordinals 1 and 7). The dispatch architecture uses a table-driven approach with a linked list of triplet handlers rather than a giant switch statement.

## Entry Point: DS_Entry (0x10091F50)

**Signature**: `TW_UINT16 __stdcall DS_Entry(TW_IDENTITY* pOrigin, TW_UINT32 DG, TW_UINT16 DAT, TW_UINT16 MSG, TW_MEMREF pData)`

DS_Entry is a thin MFC wrapper:
1. Sets up AFX module state (`FUN_1011e6fb` + `MFC70.DLL Ordinal_261`)
2. Loads the dispatch entry object from global `0x101656ac` (a sub-object at offset +4 within the main CNkTwainSource singleton)
3. If null, returns `TWRC_FAILURE (1)`
4. Calls `vtable[0]` on the dispatch entry object, passing all 5 TWAIN args

Source: `NikonScan4.ds:0x10091F50`

## Object Layout

The CNkTwainSource singleton (stored at global `0x101656a8`) has this layout:

```
Offset 0x00: vfptr → CNkTwainSource vtable at 0x10139a74
Offset 0x04: dispatch entry sub-object (vfptr → 0x10139aa4) — stored in global 0x101656ac
Offset 0x0C: identity list start
Offset 0x10: identity list end
Offset 0x14: identity list capacity
Offset 0x18: current active source pointer (CFrescoTwainSource*)
```

**Constructor**: `0x10091810`
- Sets vfptr to 0x10139a74
- Initializes dispatch entry sub-object (0x10091e40)
- Stores self in global `0x101656a8`

## Main Dispatch: 0x10091e60

This function (vtable[0] of the dispatch entry sub-object at 0x10139aa4) is the central TWAIN triplet router.

**Pseudocode**:
```c
TW_UINT16 TwainDispatch(TW_IDENTITY* pOrigin, TW_UINT32 DG, TW_UINT16 DAT, TW_UINT16 MSG, TW_MEMREF pData)
{
    DWORD combined_key = ((DWORD)DAT << 16) | (DWORD)MSG;

    CNkTwainSource* source = GetSourceSingleton();  // 0x10090f80, reads [0x101656a8]

    // Search for matching identity (is this DS "open" for this caller?)
    int identity_found = source->FindIdentity(pOrigin);  // vtable[9] @ 0x10091450

    if (identity_found) {
        // DS is open — full dispatch through handler table
        CFrescoTwainSource* active = source->GetActiveSource();  // vtable[0] = [this+0x18]
        return active->DispatchTriplet(DG, combined_key, pData);  // 0x10092040
    }

    // DS not open — only handle connection triplets
    if (DG == DG_CONTROL) {  // DG == 1
        if (combined_key == 0x30401)  // DAT_IDENTITY / MSG_OPENDS
            return OpenDS(pOrigin, pData);           // 0x10091d20
        if (combined_key == 0x80001)  // DAT_STATUS / MSG_GET
            return GetStatus(pOrigin, pData);        // 0x10091040
        if (combined_key == 0x30001)  // DAT_IDENTITY / MSG_GET
            return GetIdentity(pOrigin, pData);      // 0x10091030
    }

    // Default error path — unrecognized triplet in pre-open state
    // Sets condition code: 0x0C (non-zero DG) or 0x0B (DG==0) for status reporting
    source->SetState(DG ? 0x0C : 0x0B);  // vtable[4] @ 0x10139a84
    return TWRC_FAILURE;
}
```

Source: `NikonScan4.ds:0x10091E60`

## Handler Table Dispatch: 0x10092040

When the DS is open, triplets are dispatched through a table-driven handler lookup:

```c
TW_UINT16 DispatchTriplet(DWORD DG, DWORD combined_key, TW_MEMREF pData)
{
    // Get handler list head
    HandlerEntry* list = this->GetHandlerList();  // vtable[2]

    // Iterate linked list looking for matching (DG, key) pair
    while (list) {
        HandlerEntry* entry = list;
        while (entry) {
            if (entry->dg == DG && entry->key == combined_key) {
                // Optional: check capability ID match for DG_CONTROL
                if (DAT_part == 1) {
                    // For DG_CONTROL, also match [pData].cap with entry->cap_id
                }
                return ExecuteHandler(entry, pData);  // 0x10090e70
            }
            entry = entry->next;  // [entry + 0x1C]
        }
        list = list->chain;  // [list + 0x00]
    }

    // No handler found
    return TWRC_FAILURE;
}
```

### Handler Entry Structure (at least 0x20 bytes)
```
Offset 0x00: DWORD dg              — Data Group to match
Offset 0x04: DWORD key             — (DAT << 16) | MSG to match
Offset 0x06: WORD  handler_type    — dispatch type (determines calling convention)
Offset 0x08: WORD  capability_id   — TWAIN capability ID (for MSG_GET/SET matching)
Offset 0x0C: DWORD handler_func    — function pointer to call
Offset 0x1C: DWORD next            — next entry in linked list
```

### Handler Types (0x10090e70 switch logic)
| Type Range | Calling Convention | Description |
|-----------|-------------------|-------------|
| 0 | `handler()` | No arguments |
| 1-10 | `handler(pData)` | With TW_MEMREF |
| 0x101 (257) | `handler()` | MSG notification handler (no args) |
| 0x102-0x10A (258-266) | `handler(pData)` | Extended handlers with pData |
| >= 0x8000 | skip | Reserved/invalid |

Source: `NikonScan4.ds:0x10090E70`

## TWAIN Constants Decoded

| Hex Key | DAT | MSG | Meaning |
|---------|-----|-----|---------|
| 0x30401 | DAT_IDENTITY (3) | MSG_OPENDS (0x401) | Open Data Source |
| 0x80001 | DAT_STATUS (8) | MSG_GET (1) | Get Status |
| 0x30001 | DAT_IDENTITY (3) | MSG_GET (1) | Get Identity |

## Class Hierarchy (from RTTI)

```
CNkTwainSource          — Main singleton, holds identity list and active source
  ├─ vtable at 0x10139a74
  └─ contains dispatch entry sub-object at offset +4
       └─ vtable at 0x10139aa4 (dispatch function 0x10091e60)

CFrescoTwainSource      — Active source for an open session
  ├─ Inherits from CNkTwainTripletHandler (vtable at 0x10139a5c)
  ├─ Contains handler table (linked list of TripletHandler entries)
  └─ Dispatches matched triplets via 0x10090e70

CNkTwainTripletHandler  — Base handler interface
  ├─ vtable[0] = 0x10090e50 (getter: return [this+4] as WORD)
  ├─ vtable[1] = 0x10090e60 (getter)
  └─ vtable[2] = 0x10090e30 (getter/destructor)
```

## Exported API (Fresco SDK)

The 59 exports bypass TWAIN dispatch entirely. All follow the same pattern:
1. AFX state setup
2. Get active source via `FUN_10055c20(0x101654f0)` → `vtable[109]` (offset 0x1B4)
3. Call source-specific virtual methods

This is the NikonScan-specific API for direct integration (not TWAIN).

Key exports grouped by function:
- **Scan**: `StartScan`, `GetProgress`
- **Film handling**: `CanEject`, `CanFeed`, `Eject`, `SetAutoFeeder`
- **Film type**: `GetFilmTypeCount/Item`, `SelectFilmTypeItem`
- **Color**: `GetColorSpaceCount/Item`, `SelectColorSpaceItem`
- **Bit depth**: `GetBitDepthCount/Item`, `SelectBitDepthItem`, `GetSampleSize`
- **Profiles/CMS**: `GetMonitorProfile`, `GetPrinterProfile`, `GetRGBProfile`, `GetCMYKProfile`, `GetGrayProfile`, `GetLCHProfile`, `GetCMLEngine*`, `UseCMS`, `GetMonitorGamma`
- **Settings**: `LoadSettings`, `SaveSettings`, `ResetToDefaultSettings`, `UserSettings`, `IsUserSettingsExist`, `UpdateSettingsItem`
- **UI**: `ShowPreferences`, `ShowAbout`, `ShowHelp`, `ShowPane`, `ActivateScannerWindow`, `IsNormalPaneShown`
- **Source**: `GetSource`, `GetAvailableSourceCount`, `GetSelectedItemsCount`, `IsAnyItemExist`
- **Image**: `TransformItem`, `AddCurvesToLutGroup`, `SelectToolsItem`
- **Misc**: `GetFrescoToolPalette`, `GetStratoManager`, `GetGridParameters`, `GetDisplaySettingsSection`, `GetProfilePath`, `PreTranslateMessageDLL`, `GetDefaultSaveType`, `GetLastSaveType`, `SetLastSaveType`

## Module Loading

The MAID module (.md3) is loaded dynamically at `0x1007a250`:
```c
HMODULE hModule = LoadLibraryA(modulePath);  // e.g., "LS5000.md3"
this->maidEntryPoint = GetProcAddress(hModule, "MAIDEntryPoint");
this->moduleHandle = hModule;
```

Object fields:
- `[this + 0x74]` = MAIDEntryPoint function pointer
- `[this + 0x78]` = Module HMODULE

Source: `NikonScan4.ds:0x1007A250`

## Cross-References

- [Software Layers](../../architecture/software-layers.md)
- [LS5000 MAID Entrypoint](../ls5000-md3/maid-entrypoint.md)
- [Command Queue Architecture](command-queue.md)
- [Scan Workflows](scan-workflows.md)
