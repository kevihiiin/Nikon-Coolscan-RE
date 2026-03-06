# NKDUSCAN.dll Overview

**Status**: Complete
**Last Updated**: 2026-02-20
**Phase**: 1 (USB Transport)
**Confidence**: High

## Purpose

NKDUSCAN.dll is the USB transport layer for Nikon Coolscan scanners. It sits between the scanner model module (e.g., LS5000.md3) and the Windows `usbscan.sys` kernel driver, translating SCSI commands into USB bulk pipe operations.

```
LS5000.md3 → NkDriverEntry() → NKDUSCAN.dll → usbscan.sys → USB → scanner
```

## Binary Details

| Property | Value |
|----------|-------|
| File | `binaries/software/NikonScan403_installed/Drivers/NKDUSCAN.dll` |
| Size | 90,112 bytes (88 KB) |
| Type | PE32 DLL (x86, 5 sections) |
| Compiler | MSVC 8.0 (Visual Studio 2005) |
| Build date | 2007-02-16 |
| Exports | 1 (`NkDriverEntry`) |
| RTTI classes | 14 (6 project, 2 shared, 6 stdlib) |
| Ghidra project | NikonScan_Drivers |

## Architecture

### Single Entry Point Design

The entire public API is a single function: `NkDriverEntry(function_code, param1, param2)`. This is a deliberate design choice:

1. The .md3 module discovers transport DLLs by name convention and loads them dynamically (`LoadLibraryA` / `GetProcAddress`)
2. A single entry point means only one `GetProcAddress` call is needed
3. The function code dispatch (1-9) provides all necessary operations
4. The critical section ensures thread safety for all operations

### Session Lifecycle

```
1. FC 1: Initialize
   ├── Version check ("1200")
   ├── STI device enumeration (StiCreateInstanceW)
   ├── Device discovery (scan for \\.\UsbscanN)
   ├── Open USB session (CreateFileA)
   ├── Get pipe configuration (IOCTL_GET_DEVICE_DESCRIPTOR)
   ├── Open command manager
   ├── SetThreadExecutionState (prevent sleep)
   └── Return context handle + capabilities

2. FC 5/8/9: Execute commands
   ├── Build CommandParams struct (done by caller)
   ├── Send CDB via bulk-out
   ├── Phase query (0xD0 → phase byte)
   ├── Data transfer (if needed)
   ├── Sense retrieval (0x06 → sense data)
   └── Return status

3. FC 2/3/4: Close / Release
   ├── Release command resources
   ├── Close USB pipe handle
   └── Free session structures
```

### Transport Abstraction

NKDUSCAN.dll and NKDSBP2.dll share the same `NkDriverEntry` API. The .md3 module doesn't know or care which transport is being used — it calls the same function codes with the same parameter conventions. This is achieved through:

- Shared abstract interfaces: `ICommand`, `ICommandManager`, `ISession`, `ISessionsCollection`
- Transport-specific implementations: `CUSB2Command` vs `CSBP2Command`
- Only the SCSI execution method (vtable slot 3) differs between transports

### Version String "1200"

FC 1 validates that the caller passes the string "1200" as a protocol version. This is compared with `fcn.10006238(param_ptr, "1200", 4)` — a 4-character string comparison. The "1200" likely identifies the NkDriverEntry API version, ensuring the .md3 module and transport DLL are compatible.

## Supported Scanners

Per the USB INF files, NKDUSCAN.dll supports:

| Scanner | USB PID | Module |
|---------|---------|--------|
| Coolscan IV ED (LS-40) | 0x4000 | LS4000.md3 |
| Coolscan V ED (LS-50) | 0x4001 | LS5000.md3 |
| Super Coolscan 5000 ED (LS-5000) | 0x4002 | LS5000.md3 |

All share VID 0x04B0 (Nikon Corporation).

## Peer: NKDSBP2.dll

NKDSBP2.dll is the IEEE 1394 / SBP-2 transport for FireWire scanners:

| Property | NKDSBP2 |
|----------|---------|
| Size | 86,016 bytes (84 KB) |
| Exports | 1 (`NkDriverEntry`) |
| RTTI classes | 13 |
| Supported models | LS-4000, LS-8000, LS-9000 |
| Transport | SBP-2 over IEEE 1394 |

Same function code dispatch (1-9, `ret 0xC`), same critical section pattern.

## Cross-References

- [NkDriverEntry API](api.md) — complete function code reference
- [Class Hierarchy](classes.md) — RTTI, vtables, object layouts
- [USB Transport Details](usb-transport.md) — IOCTLs and pipe operations
- [USB Protocol](../../architecture/usb-protocol.md) — byte-level SCSI wrapping
- [System Overview](../../architecture/system-overview.md)
