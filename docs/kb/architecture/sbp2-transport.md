# SBP-2 / IEEE 1394 Transport (NKDSBP2.dll)

**Status**: Complete
**Last Updated**: 2026-03-05
**Phase**: 7 (Cross-Model)
**Confidence**: High (PE analysis, import/RTTI comparison with NKDUSCAN)

## Overview

NKDSBP2.dll provides the IEEE 1394 (FireWire) transport layer for Nikon Coolscan scanners that use FireWire interfaces: LS-4000, LS-8000, and LS-9000. It implements the same `NkDriverEntry` API as NKDUSCAN.dll, making the transport layer interchangeable from the module's perspective.

**SBP-2** (Serial Bus Protocol 2) is the SCSI-over-1394 standard. Unlike the USB transport (which uses a custom vendor protocol), SBP-2 provides native SCSI command transport -- no custom wrapping protocol is needed.

## Binary Profile

| Property | NKDSBP2.dll | NKDUSCAN.dll (for comparison) |
|----------|------------|-------------------------------|
| **Size** | 84KB | 88KB |
| **Exports** | 1 (`NkDriverEntry`) | 1 (`NkDriverEntry`) |
| **RTTI Classes** | 13 (6 project + 7 stdlib) | 14 (8 project + 6 stdlib) |
| **Imports** | KERNEL32.dll + STI.dll | KERNEL32.dll + STI.dll |
| **KERNEL32 funcs** | 72 | 72 |
| **Key Difference** | No `ReadFile` import | Uses `ReadFile` + `WriteFile` |

## Class Architecture

### NKDSBP2.dll Classes (13 RTTI total, 6 project)

```
ICommand (interface)          IDevice (interface)
    │                             │
CSBP2Command ◄── creates ──  CSBP2Device
                                  │
ICommandManager (interface)   IDeviceManager (interface)
    │                             │
CSBP2CommandManager           CSBP2DeviceManager

ISession (interface)          ISessionsCollection (interface)
    │                             │
CSBP2Session                  CSBP2SessionsCollection
```

The class names reveal an interface-based design with `I`-prefixed interfaces and `CSBP2`-prefixed concrete implementations.

### NKDUSCAN.dll Classes (14 RTTI) — for comparison

```
CSBP2Command          CUSB2Command (USB-specific)
CSBP2CommandManager   CUSBSession
                      CUSBDeviceTable
                      CUSBDevInfo
                      CUSBSessionsCollection
```

**Key observation**: Both DLLs share `CSBP2Command` and `CSBP2CommandManager` class names, suggesting these are base/shared classes for SCSI command construction that both transports inherit from. The "SBP2" in the name refers to the SCSI command block format, not the transport layer.

## Transport Protocol Comparison

### USB Transport (NKDUSCAN.dll) — Custom Vendor Protocol
```
SCSI CDB ──► Wrap in USB vendor control packet
           ──► DeviceIoControl to usbscan.sys
           ──► USB bulk-out pipe (WriteFile)

Phase Query: opcode 0xD0 via DeviceIoControl
Sense Data:  opcode 0x06 via DeviceIoControl
Data In:     ReadFile on bulk-in pipe
Data Out:    WriteFile on bulk-out pipe
```

The USB transport requires a **custom wrapping protocol** because USB does not natively support SCSI. The scanner's ISP1581 USB controller presents vendor-specific endpoints.

### FireWire Transport (NKDSBP2.dll) — Native SBP-2
```
SCSI CDB ──► Embed in SBP-2 ORB (Operation Request Block)
           ──► DeviceIoControl to sbp2port.sys
           ──► IEEE 1394 bus transaction

Phase/Sense: Handled by SBP-2 protocol natively
Data In:     SBP-2 data-in ORB (isochronous or async transfer)
Data Out:    SBP-2 data-out ORB
```

SBP-2 provides **native SCSI transport** over IEEE 1394. The SCSI CDB is placed directly into an ORB without any custom wrapping. Phase management and sense data retrieval are handled by the SBP-2 protocol stack.

### Key Implications for Driver Development

| Aspect | USB (NKDUSCAN) | FireWire (NKDSBP2) |
|--------|---------------|-------------------|
| **CDB transport** | Custom vendor protocol (must be RE'd) | Standard SBP-2 (use OS 1394/SBP-2 stack) |
| **Phase query** | Custom 0xD0 opcode | SBP-2 status block |
| **Sense retrieval** | Custom 0x06 opcode | SBP-2 sense data in status block |
| **Data transfer** | Bulk pipe ReadFile/WriteFile | SBP-2 ORB data buffers |
| **Driver complexity** | High (custom protocol) | Low (standard SBP-2) |
| **Modern OS support** | Needs custom USB driver | Can use generic SBP-2 SCSI initiator |

**For a modern driver**: FireWire models could potentially use the OS's built-in SBP-2/SCSI stack directly, sending standard SCSI CDBs. USB models require implementing the custom wrapping protocol documented in [USB Protocol](usb-protocol.md).

## Device Discovery

Both DLLs import `StiCreateInstanceW` from STI.dll (Still Image Interface). STI provides a unified API for enumerating imaging devices regardless of bus type:

1. STI enumerates devices via SETUPAPI
2. LS*.md3 module receives device information
3. Module checks device interface type (USB vs 1394)
4. Loads appropriate transport DLL (`Nkduscan.dll` or `Nkdsbp2.dll`)
5. Resolves `NkDriverEntry` via `GetProcAddress`

## NkDriverEntry API (Shared Interface)

Both transport DLLs export a single function with the same interface:

```c
// 9 function codes (1-9), dispatched by first parameter
DWORD __stdcall NkDriverEntry(
    DWORD function_code,    // 1-9
    DWORD param1,
    DWORD param2,
    LPVOID data
);
```

Function codes (identical between USB and 1394):

| FC | Purpose |
|----|---------|
| 1 | Initialize / open session |
| 2 | Close session |
| 3 | Close command |
| 4 | Release resource |
| 5 | **Execute SCSI command** (CDB + data transfer) |
| 6 | Get command status |
| 7 | Shutdown / release all |
| 8 | Query command (detailed status) |
| 9 | Execute and retrieve result |

FC5 is the critical function -- it sends a SCSI CDB to the scanner. The CDB format is identical regardless of transport; only the underlying delivery mechanism differs.

## Related Docs

- [USB Protocol](usb-protocol.md) -- USB transport details (NKDUSCAN.dll)
- [NKDUSCAN Overview](../components/nkduscan/overview.md) -- USB transport DLL analysis
- [NKDUSCAN API](../components/nkduscan/api.md) -- NkDriverEntry function codes
- [Model Comparison](../scanners/model-comparison.md) -- which model uses which transport
