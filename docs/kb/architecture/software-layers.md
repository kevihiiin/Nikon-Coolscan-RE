# Software Layers -- NikonScan to Scanner Communication
**Status**: Complete
**Last Updated**: 2026-02-28  |  **Phase**: 2 + 3  |  **Confidence**: Verified

## Summary

NikonScan 4.03 uses a layered architecture to communicate with Coolscan scanners. Each layer has a well-defined interface, making the system modular across scanner models and transport types.

## Layer Diagram

```
┌──────────────────────────────────────────────────────┐
│                    NikonScan 4.03                     │
│                  (User Application)                   │
└──────────────────────┬───────────────────────────────┘
                       │ TWAIN API (DS_Entry)
┌──────────────────────▼───────────────────────────────┐
│              NikonScan4.ds (2.3MB)                    │
│              TWAIN Data Source                         │
│  - Scan workflow orchestration                        │
│  - UI parameter mapping                               │
│  - Command queue management                           │
│  - 321 RTTI classes (MFC 7.0 based)                    │
│  - Image processing: DRAG/ICE integration             │
└──────────────────────┬───────────────────────────────┘
                       │ MAID API (MAIDEntryPoint)
┌──────────────────────▼───────────────────────────────┐
│        LS5000.md3 / LS4000/8000/9000.md3             │
│        Model-specific MAID Module (~1MB)              │
│  - SCSI CDB construction                             │
│  - Model-specific parameters                          │
│  - Capability ID -> SCSI command mapping              │
│  - 6 RTTI classes (all standard library, none Nikon)   │
│  Exports: MAIDEntryPoint, NkCtrlEntry, NkMDCtrlEntry │
└──────────────────────┬───────────────────────────────┘
                       │ NkDriverEntry API
          ┌────────────┴────────────┐
┌─────────▼──────────┐  ┌──────────▼─────────┐
│  NKDUSCAN.dll      │  │  NKDSBP2.dll       │
│  USB Transport     │  │  IEEE1394/SBP2      │
│  (90KB)            │  │  Transport (86KB)   │
│  14 RTTI classes   │  │  13 RTTI classes    │
│  - CUSB2Command    │  │  - CSBP2Command     │
│  - CUSBSession     │  │  - CSBP2Session     │
│  - CUSBDeviceTable │  │  - CSBP2Device      │
│  Export:           │  │  Export:             │
│    NkDriverEntry   │  │    NkDriverEntry     │
└─────────┬──────────┘  └──────────┬──────────┘
          │ DeviceIoControl         │ DeviceIoControl
┌─────────▼──────────┐  ┌──────────▼──────────┐
│  usbscan.sys       │  │  1394 class driver   │
│  (Windows driver)  │  │  (Windows driver)    │
└─────────┬──────────┘  └──────────┬──────────┘
          │ USB bulk                │ IEEE 1394
          │ pipes                   │ SBP-2 ORBs
┌─────────▼──────────────────────────────────────────┐
│                Scanner Firmware                      │
│            H8/3003 + ISP1581 USB controller          │
│  - SCSI command dispatch                             │
│  - Motor/CCD/Lamp control                            │
│  - Scan data acquisition & transfer                  │
└──────────────────────────────────────────────────────┘
```

## Layer Details

### Layer 1: NikonScan4.ds (TWAIN Data Source)
**Path**: `Twain_Source/NikonScan4.ds` (2.3MB PE32 DLL)
**Interface**: Standard TWAIN `DS_Entry` with DG/DAT/MSG triplets
**Role**: Top-level orchestration of scan operations
**Key classes** (from RTTI, 321 total):
- `CCommandQueue`, `CStoppableCommandQueue`, `CUnstoppableCommandQueue` -- scan operation sequencing
- `CProcessCommand`, `CDRAGProcessCommand`, `CRevProcessCommand` -- individual operations
- `CMaidBase`, `CMaidImageData`, `CMaidModule`, `CMaidSource` -- MAID interface wrappers
- `CNkTwainSource`, `CFrescoTwainSource` -- TWAIN source implementation
- `CDRAGBase`, `CDRAGProcess`, `CDRAGPrepareCommand` -- DRAG image processing
- `CNkRevelation` -- "Scanner Revelation Mask and LUT" processing
- `CToolDlg*` -- Scanner tool dialogs (crop, curves, analog gain, etc.)
- `CPrefTab*` -- Preference tabs (color management, device, calibration, etc.)

### Layer 2: LS5000.md3 (MAID Module)
**Path**: `Module_E/LS5000.md3` (~1MB PE32 DLL)
**Interface**: `MAIDEntryPoint` (MAID callback), `NkCtrlEntry`, `NkMDCtrlEntry`
**Role**: Translate MAID capability requests into SCSI commands
**Imports**: Transport DLLs loaded at runtime via `LoadLibraryA`/`GetProcAddress` (not static import). Also imports from SETUPAPI.dll (device enumeration), KERNEL32, USER32, GDI32, ADVAPI32, WINMM.
**Key info**:
- MAID = "Module Architecture for Imaging Devices" (Nikon's internal framework)
- Four .md3 modules: LS4000 (shared by LS-40 + LS-4000), LS5000 (shared by LS-50 + LS-5000), LS8000, LS9000
- Module constructs SCSI CDBs and calls NkDriverEntry to send them
- LS5000.md3 is MD3 version 3.50; all others are MD3 version 3.01
- `NkCtrlEntry` mangled: `?NkCtrlEntry@@YGFFFFPAX@Z` = `short __stdcall NkCtrlEntry(short, short, short, short, void*)`
- MAIDEntryPoint has 16-case switch (10 active): Open, Close, Enumerate, Get, Set, Start, GetDefault, Changed, Abort, QueryStatus
- Uses 17 SCSI opcodes via 22 CDB builders — standard (0x00-0x3C) + vendor (0xC0/C1/E0/E1)
- Vendor command protocol: 0xE0 (data-out) → 0xC1 (trigger) → 0xE1 (data-in) for focus/exposure control
- Full SCSI catalog and MAID→SCSI mapping: [SCSI Command Catalog](../components/ls5000-md3/scsi-command-build.md), [MAID Entrypoint](../components/ls5000-md3/maid-entrypoint.md)

### Layer 3: NKDUSCAN.dll (USB Transport)
**Path**: `Drivers/NKDUSCAN.dll` (90KB PE32 DLL)
**Interface**: `NkDriverEntry` (single export)
**Role**: Wrap SCSI commands in USB bulk transfers
**Key classes** (from RTTI):
- `CUSB2Command` -- SCSI command execution over USB
- `CUSBSession` -- Communication session with a scanner
- `CUSBDevInfo` -- Per-device information
- `CUSBDeviceTable` -- Device enumeration
- `CUSBSessionsCollection` -- Session management
- `CSBP2CommandManager`, `CSBP2Command` -- SBP2 classes (also present in USB DLL, interesting)
**Uses**: `DeviceIoControl` to communicate with `usbscan.sys` Windows driver

### Layer 3 (alternate): NKDSBP2.dll (IEEE 1394 Transport)
**Path**: `Drivers/NKDSBP2.dll` (86KB PE32 DLL)
**Interface**: Same `NkDriverEntry` export
**Role**: Wrap SCSI commands in SBP-2 ORBs over IEEE 1394
**Key classes** (from RTTI):
- `CSBP2CommandManager`, `CSBP2Command`, `CSBP2Session`, `CSBP2Device`, `CSBP2DeviceManager`, `CSBP2SessionsCollection`

### Side-loaded: Image Processing DLLs
- `DRAGNKL1.dll`, `DRAGNKX2.dll` -- DRAG (Digital ROC And GEM) image processing
- `ICEDLL.dll`, `ICENKNL1.dll`, `ICENKNX2.dll` -- Digital ICE dust/scratch removal
- These are Applied Science Fiction (now Kodak) technology
- Called by NikonScan4.ds after raw scan data is acquired

## USB-SCSI Protocol (Preview)

The USB transport wraps SCSI commands in a custom protocol (not USB Mass Storage):
1. **CDB send**: SCSI CDB sent via USB bulk-out endpoint
2. **Phase query**: Vendor command `0xD0` queries scanner's current phase
3. **Data transfer**: Based on phase, data transferred via bulk read/write
4. **Sense retrieval**: `0x06` (REQUEST SENSE) for error information

Full protocol documentation: [USB Protocol](usb-protocol.md) (Phase 1)

## Binary Summary Table

| Binary | Size | Exports | RTTI Classes | Ghidra Project |
|--------|------|---------|-------------|----------------|
| NikonScan4.ds | 2.2MB | 59 (DS_Entry + scanner API) | 321 | NikonScan_TWAIN |
| LS5000.md3 | 1.0MB | 3 (MAID+Ctrl) | 6 (stdlib only) | NikonScan_Modules |
| LS4000.md3 | 824KB | 3 (MAID+Ctrl) | -- | NikonScan_Modules |
| LS8000.md3 | 936KB | 3 (MAID+Ctrl) | -- | NikonScan_Modules |
| LS9000.md3 | 1.1MB | 3 (MAID+Ctrl) | -- | NikonScan_Modules |
| NKDUSCAN.dll | 88KB | 1 (NkDriverEntry) | 14 | NikonScan_Drivers |
| NKDSBP2.dll | 84KB | 1 (NkDriverEntry) | 13 | NikonScan_Drivers |
| ICEDLL.dll | 280KB | 36 (DICE API) | 0 | NikonScan_ICE |
| ICENKNL1.dll | 344KB | 36 (DICE API) | 0 | NikonScan_ICE |
| ICENKNX2.dll | 432KB | 36 (DICE API) | 0 | NikonScan_ICE |
| DRAGNKL1.dll | 484KB | 48 (DRAG API) | 0 | NikonScan_TWAIN |
| DRAGNKX2.dll | 176KB | 44 (DRAG API) | 0 | NikonScan_TWAIN |

## Open Questions (ALL RESOLVED)

- [x] What are all the NkDriverEntry function codes? (Phase 1) — 9 FCs (1-9), fully documented in [NkDriverEntry API](../components/nkduscan/api.md)
- [x] What MAID capability IDs exist? (Phase 2) — Operational sequence mapping complete in [MAID Entrypoint](../components/ls5000-md3/maid-entrypoint.md). Numeric ID mapping deferred to Phase 3.
- [x] How does the command queue handle async scan operations? (Phase 3) — Documented in [Command Queue](../components/nikonscan4-ds/command-queue.md): three-tier system (immediate/queued/async) with CriticalSection-guarded queue, scan commands go via async tier with worker thread.
- [x] What is "Revelation" processing? (Phase 6) — `CNkRevelation` in NikonScan4.ds wraps DRAG's "Scanner Revelation Mask" — systematic scanner artifact knowledge (consistent CCD defects, optical anomalies) fed to `SetREV_*` functions. See [DRAG API](../components/dragnkl1/api.md).

## Cross-References

- [System Overview](system-overview.md)
- [USB Protocol](usb-protocol.md) (Phase 1)
- [NKDUSCAN Analysis](../components/nkduscan/overview.md) (Phase 1)
- [LS5000 Analysis](../components/ls5000-md3/maid-entrypoint.md) (Phase 2)
