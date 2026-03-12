# NKDUSCAN.dll Class Hierarchy

**Status**: Complete
**Last Updated**: 2026-02-20
**Phase**: 1 (USB Transport)
**Confidence**: High (RTTI + vtable verified)

## Overview

NKDUSCAN.dll uses a COM-like interface pattern with abstract interfaces (MSVC structs, prefix `I`) and concrete implementations (MSVC classes, prefix `C`). The same interfaces are shared with NKDSBP2.dll (FireWire transport), enabling transport-agnostic code above this layer.

## RTTI Summary

14 RTTI type descriptors found. 6 are project-specific interfaces/classes, 2 are project-specific implementations that also appear in NKDSBP2.dll, and 6 are stdlib/compiler types.

## Interface Hierarchy

### Abstract Interfaces (`.?AU` = struct)

These are pure virtual interfaces shared between USB and SBP-2 transports:

```
ICommand                    — SCSI command abstraction
ICommandManager             — Creates/manages command objects
ISession                    — Communication session with a device
ISessionsCollection         — Collection of active sessions
IDeviceInfo                 — Per-device information (USB only, SBP-2 uses IDevice)
IDeviceTable                — Device enumeration (USB only, SBP-2 uses IDeviceManager)
```

### Concrete USB Classes (`.?AV` = class)

```
CUSB2Command               — ICommand for USB (SCSI-over-USB bulk pipes)
  vtable at 0x1000e210

CUSBSession                — ISession for USB (opens \\.\UsbscanN)
  vtable methods: virtual_4 (Open), virtual_8 (Close), virtual_12 (GetPipeInfo)

CUSBDevInfo                — IDeviceInfo for USB (device descriptor data)
  vtable methods: virtual_4 (ReadDescriptors)

CUSBDeviceTable            — IDeviceTable for USB (STI enumeration)

CUSBSessionsCollection     — ISessionsCollection for USB
  vtable methods: virtual_4 (CreateSession)

CSBP2CommandManager        — ICommandManager
  (NOTE: despite the "SBP2" prefix, this class exists in NKDUSCAN.dll too
   and appears to be shared base code for command management)

CSBP2Command               — ICommand for SBP-2
  vtable at 0x1000e1e4 (in NKDUSCAN.dll, used only when the
   SBP-2 code path is active; shares code with the 1394 DLL)
```

### Standard Library Classes

`std::bad_alloc`, `std::exception`, `std::logic_error`, `std::length_error`, `std::out_of_range`, `std::bad_exception`, `type_info`

## CUSB2Command VTable

The primary class for SCSI command execution over USB.

**VTable address**: 0x1000e210
**RTTI Complete Object Locator**: 0x1000fe2c

| Index | Offset | Address | Method | Notes |
|-------|--------|---------|--------|-------|
| 0 | 0x00 | 0x10002de0 | destructor | Shared with CSBP2Command |
| 1 | 0x04 | 0x10002980 | virtual_4 | Shared |
| 2 | 0x08 | 0x100029c0 | virtual_8 | Shared |
| 3 | 0x0C | **0x10002b50** | **Execute** | **USB-specific SCSI execution** |
| 4 | 0x10 | 0x10003040 | virtual_16 (GetStatus) | Shared |
| 5 | 0x14 | 0x100029e0 | virtual_20 | Shared |
| 6 | 0x18 | 0x10002a40 | virtual_24 | Shared |
| 7 | 0x1C | 0x10002a50 | virtual_28 | Shared |
| 8 | 0x20 | 0x10003540 | virtual_32 | Shared |
| 9 | 0x24 | 0x10002a60 | virtual_36 | Shared |

10 virtual methods total. Only **virtual_12 (Execute)** differs between USB and SBP-2 — all other methods are identical.

## CSBP2Command VTable (for comparison)

**VTable address**: 0x1000e1e4
**RTTI Complete Object Locator**: 0x1000e1e0

| Index | Offset | Address | Method |
|-------|--------|---------|--------|
| 3 | 0x0C | **0x10002e00** | **Execute (SBP-2 version)** |
| (all others) | | (same as CUSB2Command) | |

## CUSB2Command Object Layout

```c
struct CUSB2Command {
    DWORD* vtable;              // +0x00: pointer to vtable at 0x1000e210
    DWORD  status;              // +0x04: execution status (2=success, 3=error)
    DWORD  error_code;          // +0x08: error code (0, 0x11003, 0x21008)
    DWORD  has_callback;        // +0x0C: boolean — 1 if error callback is registered, 0 otherwise
    DWORD  handle;              // +0x10: USB pipe HANDLE (for ReadFile/WriteFile)
    CUSBSession* session;       // +0x14: pointer to CUSBSession object (set during command init)
    CommandParams* params;      // +0x18: pointer to command parameters
};
```

Source: `NKDUSCAN.dll:0x10002dc0` (constructor), `0x10002b50` (Execute method)

## CUSBSession Object Layout

```c
struct CUSBSession {
    DWORD* vtable;              // +0x00: vtable pointer
    HANDLE pipe_handle;         // +0x04: USB pipe handle from CreateFileA
    DWORD  endpoint_in;         // +0x08: bulk-in endpoint info
    DWORD  endpoint_out;        // +0x0C: bulk-out endpoint info
    DWORD  field_10;            // +0x10: state flag
    DWORD  max_transfer_size;   // +0x14: maximum USB transfer size
};
```

**Session lifecycle**:
1. `virtual_4` (Open): `CreateFileA("\\.\UsbscanN")`, then `DeviceIoControl(IOCTL_GET_DEVICE_DESCRIPTOR)` to get pipe info, calculates max transfer size based on USB speed (USB 2.0 vs 1.1)
2. `virtual_8` (Close): `CloseHandle(pipe_handle)`, sets handle to NULL
3. `virtual_12` (GetPipeInfo): queries pipe endpoint configuration

Source: `NKDUSCAN.dll:0x10005310` (Open), `0x10005430` (Close), `0x10005450` (GetPipeInfo)

## CUSBDevInfo

Reads device descriptors via `DeviceIoControl(IOCTL_GET_USB_DESCRIPTOR = 0x80002018)`.

- Opens the device path (converted from wide string at `[this + 0x118]`)
- Sends IOCTL to get 8-byte descriptor data
- Parses VID/PID and device info
- Closes the handle

Source: `NKDUSCAN.dll:0x100031a0`

## CUSBDeviceTable

Uses Windows Still Image Architecture (STI) for device discovery.

**Constructor**: `fcn.10003920` (allocates 0x20 = 32 bytes)
**VTable**: `method.CUSBDeviceTable.virtual_20` at 0x10003a90

### STI Enumeration Flow (`CUSBDeviceTable::virtual_20`)

```
Address: 0x10003a90 (full scan function)
```

1. Get STI interface from `[this+4]`, call `STI::virtual_16` (EnumDevices) to get device list
2. Call `virtual_24` (vtable+0x18) — prepare/filter
3. For each STI device (stride = 0x124 = 292 bytes per STI_DEVICE_INFORMATION):
   a. Read wide string device path at `[device + 0x118]`
   b. Calculate string length (scan for NULL terminator in UTF-16)
   c. If length > 0: call `fcn.100061da("Usbscan", device_path)` — **wcsstr** substring match
   d. If "Usbscan" NOT found: skip device
   e. Zero a 260-byte ANSI buffer
   f. `WideCharToMultiByte` to convert device path to ANSI
   g. `CreateFileA(ansi_path, GENERIC_READ|GENERIC_WRITE, 0, NULL, OPEN_EXISTING, ...)` — open device
   h. If open fails: skip device
   i. Zero a 12-byte buffer, call `DeviceIoControl(IOCTL_GET_DEVICE_DESCRIPTOR = 0x80002014, in=12, out=12)`
   j. `CloseHandle(device_handle)` — immediately close after querying
   k. If IOCTL failed: skip device
   l. **USB speed detection** from max packet size at `[result + 0x10]`:
      - If max_packet_size == **0x40** (64): USB 1.1 Full Speed → speed_type = `0x40 - 0x3E` = **2**
      - If max_packet_size == **0x200** (512): USB 2.0 High Speed → speed_type = **3**
      - Otherwise: speed_type = **0**
   m. Call `fcn.10003a50(speed_type, device_ptr)` — create CUSBDevInfo for this device, add to linked list at `[this+0xC]`
4. Loop until all STI devices processed

Source: `NKDUSCAN.dll:0x10003a90-0x10003c37`

## CSBP2CommandManager Object Layout

Despite the "SBP2" prefix, this class exists in NKDUSCAN.dll and manages the **command queue worker thread** for both transports.

```c
struct CSBP2CommandManager {
    DWORD*         vtable;              // +0x00
    HANDLE         thread_handle;       // +0x04: worker thread handle
    DWORD          field_08;            // +0x08
    DWORD          field_0C;            // +0x0C
    HANDLE         event_auto_reset;    // +0x10: auto-reset event (command ready)
    DWORD          field_14;            // +0x14
    HANDLE         event_manual_reset;  // +0x18: manual-reset event
    HANDLE         event_completion;    // +0x1C: auto-reset event (completion)
    // ...more fields...
    CRITICAL_SECTION* cs1;             // +0x38: critical section 1
    CRITICAL_SECTION* cs2;             // +0x3C: critical section 2
};
```

### Initialization (`CSBP2CommandManager::virtual_4` at 0x10001000)

1. Create 3 events via `CreateEventA`:
   - `[this+0x10]`: auto-reset, non-signaled — command ready signal
   - `[this+0x18]`: manual-reset, non-signaled — state flag
   - `[this+0x1C]`: auto-reset, non-signaled — completion notification
2. Allocate and initialize 2 critical sections at `[this+0x38]` and `[this+0x3C]`
3. Create worker thread with `_beginthreadex` wrapper (CRT at 0x1000574b):
   - Thread procedure: `0x10002880`
   - Parameter: `this` (the CommandManager object)
4. Set thread priority to `THREAD_PRIORITY_HIGHEST` (2)

### Worker Thread (`0x10002880`)

The worker thread runs a **command processing loop**:

```
loop:
  1. call virtual_36 (vtable+0x24) to dequeue next command
     → also reports pending count via output param
  2. if command found AND first iteration AND count==0:
       call virtual_48 (vtable+0x30) — begin processing notification
       call virtual_20 (vtable+0x14) — prepare/reset state
  3. call virtual_52 (vtable+0x34) — check termination flag
     → if returns 1: exit thread
  4. call virtual_56 (vtable+0x38) — wait/timing (may subtract elapsed time)
     → if returns 1 with time delta: loop back (adjust command index)
  5. for dequeued command:
     a. call virtual_12 (vtable+0x0C) — Execute the SCSI command
        if success, verify iteration count
     b. call virtual_20 (vtable+0x14) — prepare next command
     c. call virtual_16 (vtable+0x10, GetStatus) — get result
     d. if first completion (edi==1):
          call virtual_60 (vtable+0x3C) — completion callback
     e. call virtual_0 (destructor) — destroy processed command
     f. call virtual_24 (vtable+0x18) — signal completion
  goto loop
```

The thread exits (returns 0) only when `virtual_52` returns 1 (termination signal).

Source: `NKDUSCAN.dll:0x10001000-0x1000109a` (init), `0x10002880-0x10002965` (thread proc)

## Interface Comparison: USB vs FireWire

| Interface | USB (NKDUSCAN) | FireWire (NKDSBP2) |
|-----------|---------------|-------------------|
| ICommand | CUSB2Command | CSBP2Command |
| ICommandManager | CSBP2CommandManager | CSBP2CommandManager |
| ISession | CUSBSession | CSBP2Session |
| ISessionsCollection | CUSBSessionsCollection | CSBP2SessionsCollection |
| Device info | **IDeviceInfo → CUSBDevInfo** | **IDevice → CSBP2Device** |
| Device enum | **IDeviceTable → CUSBDeviceTable** | **IDeviceManager → CSBP2DeviceManager** |

Note: The command and session interfaces are identical. The device enumeration interfaces differ because USB uses STI while FireWire uses the 1394 bus driver.

## Cross-References

- [NkDriverEntry API](api.md) — how these classes are used via function codes
- [USB Protocol](../../architecture/usb-protocol.md) — CUSB2Command::Execute protocol details
- [NKDUSCAN Overview](overview.md) — architecture context
