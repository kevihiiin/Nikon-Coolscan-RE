# NKDSBP2.dll Analysis Log
<!-- STATUS HEADER - editable -->
**Status**: Complete
**Binary**: NKDSBP2.dll (84KB)
**Ghidra Project**: NikonScan_Drivers
---
<!-- ENTRIES BELOW - APPEND ONLY -->

## 2026-03-05 -- Attempt 1: Export/Import/RTTI Analysis

**Tool**: pefile (Python), strings
**Target**: NKDSBP2.dll
**Goal**: Compare SBP-2 transport with USB transport (NKDUSCAN.dll)

### Findings

1. **Single export**: NkDriverEntry (same as NKDUSCAN)
2. **7 RTTI classes**: CSBP2Command, CSBP2CommandManager, CSBP2Device, CSBP2DeviceManager, CSBP2Session, CSBP2SessionsCollection + type_info. Plus interface RTTI: ICommand, ICommandManager, IDevice, IDeviceManager, ISession, ISessionsCollection
3. **Imports**: KERNEL32.dll (72 funcs) + STI.dll (StiCreateInstanceW). Key: NO ReadFile import (unlike NKDUSCAN which uses ReadFile for bulk-in pipe). Uses DeviceIoControl for all I/O (SBP-2 ORBs via sbp2port.sys)
4. **Transport**: SBP-2 (Serial Bus Protocol 2) over IEEE 1394. Native SCSI transport -- no custom wrapping protocol needed. CDBs placed directly in SBP-2 ORBs
5. **Shared classes**: CSBP2Command and CSBP2CommandManager appear in BOTH NKDUSCAN and NKDSBP2 -- likely base class for SCSI command block construction

**Confidence**: High

## 2026-03-05 -- Attempt 2: Cross-Module Transport Analysis

**Tool**: strings comparison
**Target**: All 4 .md3 modules transport references
**Goal**: Verify transport-agnostic module architecture

### Findings

1. All 4 modules reference BOTH Nkduscan.dll and Nkdsbp2.dll as strings
2. Transport selection happens at runtime based on device enumeration
3. Both transport DLLs import STI.dll (StiCreateInstanceW) for device discovery
4. The module architecture is fully transport-agnostic -- same NkDriverEntry API regardless of bus

**Confidence**: High
