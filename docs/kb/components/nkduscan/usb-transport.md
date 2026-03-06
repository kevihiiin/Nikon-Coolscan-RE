# NKDUSCAN.dll USB Transport Details

**Status**: Complete
**Last Updated**: 2026-02-20
**Phase**: 1 (USB Transport)
**Confidence**: High

## USB Stack

```
NKDUSCAN.dll (user mode)
    │
    ├── CreateFileA("\\.\UsbscanN")     → open device
    ├── WriteFile(handle, ...)           → bulk-out pipe
    ├── ReadFile(handle, ...)            → bulk-in pipe
    ├── DeviceIoControl(handle, ...)     → control pipe / device query
    └── CloseHandle(handle)             → close device
    │
usbscan.sys (kernel mode, Windows Still Image driver)
    │
USB Host Controller → USB bus → Scanner
```

## Device Discovery (STI Enumeration)

NKDUSCAN.dll uses Windows Still Image Architecture (STI) to find connected scanners:

1. `StiCreateInstanceW(STI_VERSION, &pSti)` — get STI interface
2. Enumerate still image devices via STI API
3. Filter for devices with "Usbscan" in their device path
4. For each matching device:
   - Extract device path (wide string stored at object offset +0x118)
   - Convert to ANSI: `WideCharToMultiByte()`
   - Open device: `CreateFileA(path, GENERIC_READ|GENERIC_WRITE, 0, NULL, OPEN_EXISTING, 0, NULL)`
   - Query descriptor: `DeviceIoControl(IOCTL_GET_USB_DESCRIPTOR = 0x80002018, in=8, out=8)`
   - Close device
   - Store VID/PID and device info

Source: `fcn.10005240` (STI init), `fcn.100039b0` (scan), `fcn.100031a0` (per-device query)

## Device Path Format

Device paths follow the Windows STI convention:

```
\\.\Usbscan0    — first USB still image device
\\.\Usbscan1    — second device
...
```

The wide string "Usbscan" is stored at `NKDUSCAN.dll:0x1000e28c` (UTF-16LE) and is used for path matching during enumeration.

## Session Open (Pipe Setup)

When a session is opened (`CUSBSession::virtual_4`):

1. Convert device path from wide to ANSI
2. `CreateFileA(path, GENERIC_READ | GENERIC_WRITE, 0, NULL, OPEN_EXISTING, 0, NULL)`
   - Access: 0xC0000000 = GENERIC_READ | GENERIC_WRITE
   - Disposition: 3 = OPEN_EXISTING
3. If CreateFileA succeeds, query pipe configuration:
   - Call `IDeviceInfo::virtual_16` (vtable offset 0x10) to get endpoint info
   - Read word at offset +2 of result: USB speed indicator
   - Calculate max transfer size based on USB speed:
     - If max packet size == 0x40 (64 bytes): USB 1.1 Full Speed → speed_type = 2
     - If max packet size == 0x200 (512 bytes): USB 2.0 High Speed → speed_type = 3
     - Otherwise: speed_type = 0
   - Store: `[session + 0x14]` = max transfer size (derived from speed type)

Source: `NKDUSCAN.dll:0x10005310-0x1000541e` (CUSBSession::virtual_4)

## Session Close

`CUSBSession::virtual_8` at 0x10005430:

1. Check if `[session + 4]` (pipe handle) is non-NULL
2. If so: `CloseHandle(pipe_handle)`
3. Set `[session + 4] = NULL`
4. Return 0

## IOCTLs Used

### IOCTL_SEND_USB_REQUEST (0x80002008)

**Purpose**: Send USB vendor control transfer (for 64-byte extended CDBs)
**Call sites**: 0x10002da0 (CUSB2Command), 0x10003023 (CSBP2Command)
**Parameters**:
```c
DeviceIoControl(
    handle,                 // USB device handle
    0x80002008,            // IOCTL code
    NULL,                  // input buffer (not used)
    0,                     // input size
    data_buffer,           // output buffer (CDB data)
    data_size,             // CDB size (64 bytes)
    &bytes_returned,       // bytes actually transferred
    NULL                   // no overlapped I/O
);
```

### IOCTL_GET_DEVICE_DESCRIPTOR (0x80002014)

**Purpose**: Get USB device/pipe descriptor information
**Call site**: 0x10003bbe
**Parameters**:
```c
// Input: 12-byte zeroed buffer (pipe query params)
// Output: 12-byte pipe descriptor
DeviceIoControl(
    handle,
    0x80002014,
    pipe_query,            // 12 bytes, all zero
    0,                     // input size = 0 (using inout buffer)
    pipe_result,           // 12 bytes output
    0x0C,                  // output size = 12
    &bytes_returned,
    NULL
);
```

Returns pipe endpoint information: bulk-in endpoint, bulk-out endpoint, interrupt endpoint.

### IOCTL_GET_USB_DESCRIPTOR (0x80002018)

**Purpose**: Get USB string/configuration descriptor
**Call site**: 0x1000323e
**Parameters**:
```c
// Input: 8-byte buffer (descriptor request)
// Output: 8-byte buffer (descriptor data)
DeviceIoControl(
    handle,
    0x80002018,
    descriptor_request,    // 8 bytes (descriptor type + index)
    8,                     // input size
    descriptor_data,       // 8 bytes output
    8,                     // output size
    &bytes_returned,
    NULL
);
```

Used during device enumeration to read VID, PID, and device type.

## Bulk Pipe I/O

### WriteFile Wrapper (Bulk-Out)

**Function**: `fcn.10002b20` at 0x10002b20
**Convention**: thiscall + 3 cdecl params, `ret 0xC`
**Prototype**: `BOOL WriteOut(BYTE* buffer, DWORD size, LPOVERLAPPED overlapped)`

```c
// Simplified:
BOOL WriteOut(CUSB2Command* this, BYTE* buf, DWORD size, LPOVERLAPPED ovl) {
    DWORD written = 0;
    return WriteFile(this->pipe_handle, buf, size, &written, ovl);
}
```

Uses `[this + 0x10]` as the pipe handle.

### ReadFile Wrapper (Bulk-In)

**Function**: `fcn.10002ae0` at 0x10002ae0
**Convention**: thiscall + 3 cdecl params, `ret 0xC`
**Prototype**: `BOOL ReadIn(BYTE* buffer, DWORD* size_ptr, LPOVERLAPPED overlapped)`

```c
// Simplified:
BOOL ReadIn(CUSB2Command* this, BYTE* buf, DWORD* pSize, LPOVERLAPPED ovl) {
    DWORD toRead = *pSize;
    memset(buf, 0, toRead);  // fcn.10005fc0 pre-clears buffer
    return ReadFile(this->pipe_handle, buf, toRead, pSize, ovl);
}
```

Note: The read buffer is pre-cleared before each read. The size parameter is a pointer — the actual value is dereferenced before calling ReadFile, and the bytes-read count overwrites it.

## Thread Management

- `CreateThread` — used to create a background worker thread for asynchronous operations
- `SetThreadPriority` — adjusts thread priority for scan operations
- `SetThreadExecutionState(ES_SYSTEM_REQUIRED | ES_CONTINUOUS = 0x80000001)` — prevents system sleep during active scan sessions
- `WaitForSingleObject` / event objects — synchronization between main and worker threads

## Cross-References

- [USB Protocol](../../architecture/usb-protocol.md) — SCSI-over-USB byte-level protocol
- [NkDriverEntry API](api.md) — how transport operations are invoked
- [Class Hierarchy](classes.md) — CUSBSession, CUSBDevInfo details
