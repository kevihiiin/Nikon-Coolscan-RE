# NkDriverEntry API Reference

**Status**: Complete
**Last Updated**: 2026-02-20
**Phase**: 1 (USB Transport)
**Confidence**: High (verified from disassembly)

## Overview

`NkDriverEntry` is the **sole export** of both NKDUSCAN.dll (USB) and NKDSBP2.dll (FireWire). It serves as the complete public API for the transport layer. The .md3 scanner module (e.g., LS5000.md3) loads the transport DLL at runtime via `LoadLibraryA` / `GetProcAddress` and calls this single entry point for all communication.

## Function Signature

```c
// __stdcall convention (callee cleans stack, ret 0xC = 3 DWORDs)
DWORD __stdcall NkDriverEntry(
    DWORD function_code,    // 1-9, selects operation
    DWORD param1,           // meaning depends on function_code
    DWORD param2            // meaning depends on function_code
);
```

**Address**: RVA 0x3C40 (VA 0x10003C40 with default image base 0x10000000)

**Thread safety**: The entire function is protected by a critical section at 0x10012F68. All 9 operations are serialized.

## Return Values

| Return Code | Meaning |
|------------|---------|
| 0x00000000 | Success |
| 0x00011001 | Invalid function code (not 1-9) |
| 0x00011003 | NULL required parameter / protocol error |
| 0x00011004 | NULL required parameter (first param) |
| 0x00011006 | Version/capability mismatch |
| 0x00021008 | USB I/O error |

Source: `NKDUSCAN.dll:0x10003db5` (default case), various handler functions

## Function Codes

### FC 1: Initialize / Open Session

**Handler**: `fcn.10003e30` (209 bytes)
**Parameters**: `param1` = output structure pointer, `param2` = must be 0
**Returns**: 0 on success, error code on failure

**Behavior**:
1. Validates `param1` is non-NULL (else returns 0x11004)
2. Validates `param2` is 0 (else returns 0x11003)
3. Calls `fcn.10006238(param1, "1200", 4)` — version check: validates the caller passes the string "1200" as a protocol version identifier
4. If version mismatch: returns 0x11006
5. Allocates 12-byte context structure (3 DWORDs, all zeroed)
6. Calls `fcn.10005240` — creates `CUSBDeviceTable` (uses `StiCreateInstanceW` for STI device enumeration)
7. Calls `fcn.100039b0` — scans for connected Nikon USB scanners
8. Opens `ICommandManager` via vtable call (virtual_4)
9. Calls `fcn.10001c30` — opens USB bulk pipe session
10. Opens `ISessionsCollection` via vtable call (virtual_4)
11. Populates output structure at `param1`:
    - `[+0x04]` = 0x8004 (capability flags)
    - `[+0x08]` = 0x20 (32 = standard CDB size)
    - `[+0x0C]` = 0 (error code)
    - `[+0x10]` = pointer to context structure
12. Calls `SetThreadExecutionState(ES_SYSTEM_REQUIRED | ES_CONTINUOUS)` to prevent system sleep during scanning

Source: `NKDUSCAN.dll:0x10003e30-0x10003ef8`

### FC 2: Close Session

**Handler**: `fcn.10004240` (66 bytes + sub-functions)
**Parameters**: `param1` = context struct ptr, `param2` = sub-handle
**Returns**: 0 on success, 0x11005 if magic word mismatch

Two code paths based on context state:
- If `[param1+4]` is 0: jumps to 0x10004150 — validates magic word `[param1]` == 0x8004, then calls `ICommandManager::virtual_20` to shut down command processing, and `ICommandManager::virtual_12` to get result, stores at `[param1+4]`
- If `[param1+8]` is non-zero: jumps to 0x10004190 — iterates over `[param1+4]` sessions, calling `ISessionsCollection::virtual_32` for each session index, storing results in an array at `[param1+8]`

Source: `NKDUSCAN.dll:0x10004240-0x10004281`, sub-functions at 0x10004150 and 0x10004190

### FC 3: Close Command

**Handler**: `fcn.10004290` (73 bytes + sub-functions)
**Parameters**: `param1` = context struct ptr, `param2` = sub-handle

Three code paths based on context state:
- If `[param1+4]` is 0: jumps to 0x10004230 — sets `[param1+4]` = 8 (state flag), returns 0
- If `[param1+0xC]` is non-zero: jumps to 0x100041c0 — calls `ICommandManager::virtual_16` to find a command by `[param1]`, then calls `ICommand::virtual_4` passing the handle and context for cleanup
- Always clears `[param1+8]` = 0 before checking `[param1+0xC]`

Source: `NKDUSCAN.dll:0x10004290-0x100042d8`, sub-functions at 0x10004230 and 0x100041c0

### FC 4: Release Resource

**Handler**: `fcn.100042e0` (49 bytes + sub-function)
**Parameters**: `param1` = context struct ptr, `param2` = sub-handle
**Returns**: 0 on success, 0x31012 on specific failure

If `[param1+8]` is non-zero: returns 0x11004 (still in use).
Otherwise jumps to 0x100041f0 which:
1. Gets `ISessionsCollection` from `[param2+4]`
2. Calls `ISessionsCollection::virtual_20` passing `[param1]`, `[param1+0xC]`, `[param1+0x10]`, and `param2`
3. If successful, stores the session object at `[param1+4]`, returns 0
4. On failure returns 0x31012

Source: `NKDUSCAN.dll:0x100042e0-0x1000430a`, sub-function at 0x100041f0

### FC 5: Execute SCSI Command

**Handler**: `fcn.10003fd0` (231 bytes)
**Parameters**: `param1` = CommandParams struct ptr, `param2` = context struct ptr
**Returns**: 0 on success

This is the **primary command execution entry point**. Detailed flow:

1. Validate `param1` non-NULL (else 0x11004)
2. Validate `param2` non-NULL (else 0x11003 + error callback at `[param1+0xC]`)
3. Validate `[param1+0x24] >= 0x20` — command params must be at least 32 bytes (else 0x11004)
4. If `[param1+4]` is non-zero, also check `[param1+0x20]` is non-zero
5. Get ICommandManager from `[param2+4]`, call `virtual_16` (vtable+0x10) passing `[param1]` → returns ICommand object
6. If ICommand is NULL: error callback 0x11004
7. Call `ICommand::virtual_24` (vtable+0x18) → gets transfer size flag
8. Call `fcn.100030a0(out_ptr, transfer_size)` — **allocates command object**:
   - If transfer_size == 0x20000: creates `CUSB2Command` (vtable 0x1000e210) — for USB bulk pipe transfer with standard 32-byte CDBs
   - Otherwise: creates `CSBP2Command` (vtable 0x1000e1e4) — may use IOCTL path for extended CDBs
   - Allocates 0x1C (28) bytes for the command struct
9. Call `ICommand::virtual_4` (vtable+4) with the CommandParams and ICommand — sets up the command
10. Get ISessionsCollection from `[param2+8]`, call `virtual_16` on it
11. If first time and `[param1+0xC]` == 0 (no error callback): call `ISessionsCollection::virtual_40` (vtable+0x28) for completion callback
12. Return result

**Error callback mechanism**: If `[param1+0xC]` contains a function pointer, errors trigger `callback(param1, error_code)` to notify the .md3 module asynchronously.

The actual SCSI-over-USB protocol is implemented in `CUSB2Command::virtual_12`. See [USB Protocol](../../architecture/usb-protocol.md) for the byte-level protocol.

Source: `NKDUSCAN.dll:0x10003fd0-0x100040b6`

### FC 6: Get Command Status

**Handler**: `fcn.10003f90` (59 bytes)
**Parameters**: `param1` = status query context, `param2` = command context
**Returns**: result from ICommand::virtual_8

Flow:
1. Validate `param1` non-NULL (else 0x11004), `param2` non-NULL (else 0x11003)
2. Get ICommandManager from `[param2+4]`
3. Call `ICommandManager::virtual_16` (vtable+0x10) passing `[param1+4]` to look up the command
4. If ICommand is NULL: return 0x11004
5. Tail-call to `ICommand::virtual_8` (vtable+0x08) — returns command execution status

This is used to poll asynchronous command progress. The returned value typically indicates whether execution is complete.

Source: `NKDUSCAN.dll:0x10003f90-0x10003fc5`

### FC 7: Shutdown / Release All

**Handler**: `fcn.10003f10` (121 bytes)
**Parameters**: `param1` = unused (but validated non-NULL), `param2` = init context ptr
**Returns**: 0 on success

This is the **full shutdown** counterpart to FC1. It:
1. Validates `param1` non-NULL (else 0x11004), `param2` non-NULL (else 0x11003)
2. For each of the 3 interface objects at `[param2+0]`, `[param2+4]`, `[param2+8]`:
   - If non-NULL: call `virtual_8` (query/finalize), then `virtual_0` (destructor)
3. Call `fcn.10005ac4` (free the init context struct)
4. Call `SetThreadExecutionState(ES_CONTINUOUS = 0x80000000)` — re-allow system sleep
5. Return 0

Source: `NKDUSCAN.dll:0x10003f10-0x10003f83`

### FC 8: Query Command via ICommandManager

**Handler**: `fcn.100040c0` (55 bytes)
**Parameters**: `param1` = query context, `param2` = command context
**Returns**: result from ICommand::virtual_16

Structurally identical to FC6 except the final call:
1. Validate params
2. Get ICommandManager from `[param2+4]`, call `virtual_16` to find ICommand by `[param1+4]`
3. If ICommand is NULL: return 0x11004
4. Tail-call to `ICommand::virtual_16` (vtable+0x10, GetStatus) — different from FC6's `virtual_8`

FC6 and FC8 both look up a command and query it, but through different virtual methods — FC6 uses `virtual_8` (likely basic status), FC8 uses `virtual_16` (likely detailed status/result).

Source: `NKDUSCAN.dll:0x100040c0-0x100040f5`

### FC 9: Execute and Retrieve Result

**Handler**: `fcn.10004100` (70 bytes)
**Parameters**: `param1` = context struct ptr, `param2` = command/result params
**Returns**: 0 on success

Combined operation that:
1. Validate `param1` non-NULL (else 0x11004), `param2` non-NULL (else 0x11003)
2. Get ICommandManager from `[param2+4]`, call `virtual_16` passing `[param1+4]` → get ICommand
3. If ICommand is NULL: return 0x11004
4. Get ISessionsCollection from `[param2+8]`, call `virtual_44` (vtable+0x2C) with ICommand — retrieve command result data
5. Return 0

This appears to be used when the .md3 module wants to fetch results from a previously-submitted asynchronous command in a single call.

Source: `NKDUSCAN.dll:0x10004100-0x10004145`

## Imports

### Key Functional Imports (KERNEL32.dll)

| Function | Count | Purpose |
|----------|-------|---------|
| `CreateFileA` | 3 calls | Open USB device (`\\.\UsbscanN`) |
| `DeviceIoControl` | 5 calls | Send IOCTLs to usbscan.sys |
| `ReadFile` | 1 call site | USB bulk-in pipe read |
| `WriteFile` | 2 call sites | USB bulk-out pipe write |
| `CloseHandle` | multiple | Close device handles |
| `CreateThread` | 1 | Background processing thread |
| `SetThreadExecutionState` | 1 | Prevent sleep during scan |
| `WideCharToMultiByte` | 3 | Convert device path to ANSI |

### STI Import

| Function | Purpose |
|----------|---------|
| `StiCreateInstanceW` (STI.dll) | Create STI interface for device enumeration |

### CRT / Security Imports

Standard MSVC CRT (heap, TLS, exception handling, locale). Stack cookie validation (`__security_check_cookie`).

## Cross-References

- [USB Protocol](../../architecture/usb-protocol.md) — byte-level SCSI wrapping
- [NKDUSCAN Classes](classes.md) — class hierarchy and vtable layout
- [NKDUSCAN Overview](overview.md) — architecture and session lifecycle
