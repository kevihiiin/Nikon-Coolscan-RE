# NKDUSCAN.dll Analysis Log
<!-- STATUS HEADER - editable -->
**Binary**: binaries/software/NikonScan403_installed/Drivers/NKDUSCAN.dll | **Functions identified**: ~25 key functions
---
<!-- ENTRIES BELOW - APPEND ONLY -->

## 2026-02-20 -- Session 3: Phase 1 Full Analysis

### Attempt 1: NkDriverEntry Dispatch Analysis
**Tool**: radare2 (r2 -q with aaa analysis)
**Target**: NkDriverEntry at VA 0x10003C40
**Method**: Disassembled export function, traced jump table
**Result**: SUCCESS
- `__stdcall` with `ret 0xC` = 3 DWORD params (function_code, param1, param2)
- Critical section at 0x10012F68 protects all operations
- Jump table at 0x10003DC8 with 9 entries (function codes 1-9)
- Default case returns 0x11001 (invalid FC)
- Each case loads param2/param3 from stack, calls handler(param2, param3) [cdecl, add esp,8]
- All cases follow same pattern: handler → save result → LeaveCriticalSection → return

### Attempt 2: Handler Function Mapping
**Tool**: radare2
**Target**: All 9 handler functions
**Result**: SUCCESS — all handlers disassembled and mapped

| FC | Handler | Size | Purpose (determined from analysis) |
|----|---------|------|--------|
| 1 | 0x10003e30 | 209B | Initialize/Open Session |
| 2 | 0x10004240 | 66B | Close Command (type A) |
| 3 | 0x10004290 | 73B | Close Command (type B) |
| 4 | 0x100042e0 | 49B | Release Resource |
| 5 | 0x10003fd0 | 231B | Execute SCSI Command |
| 6 | 0x10003f90 | 59B | Get Command Status |
| 7 | 0x10003f10 | 121B | Get Device Info |
| 8 | 0x100040c0 | 55B | Query via ICommand |
| 9 | 0x10004100 | 70B | Execute and Retrieve |

### Attempt 3: FC1 (Initialize) Deep Analysis
**Tool**: radare2
**Target**: fcn.10003e30
**Result**: SUCCESS
- Validates param1 non-NULL (else 0x11004), param2 == 0 (else 0x11003)
- String comparison with "1200" at 0x1000e29c (version check)
- Allocates 12-byte context struct
- Calls fcn.10005240 (STI init / CUSBDeviceTable construction)
- Calls fcn.100039b0 (device scan)
- Opens ICommandManager and ISessionsCollection via vtable calls
- Populates output: [+4]=0x8004, [+8]=0x20, [+0xC]=0, [+0x10]=context
- Calls SetThreadExecutionState(0x80000001)

### Attempt 4: CUSB2Command::Execute (virtual_12)
**Tool**: radare2
**Target**: 0x10002b50 (612 bytes)
**Result**: SUCCESS — full SCSI-over-USB protocol decoded

Protocol sequence for 32-byte CDB:
1. WriteFile: send raw CDB (32 bytes) via bulk-out
2. WriteFile: send 1 byte 0xD0 (phase query) via bulk-out
3. ReadFile: read 1 byte phase response via bulk-in
4. Phase byte determines action:
   - 0x03 + direction=1: ReadFile data-in (chunked)
   - 0x02 + direction=2: WriteFile data-out
   - 0x01: no data transfer
5. WriteFile: send 1 byte 0x06 (sense request) via bulk-out
6. ReadFile: read sense data via bulk-in

For 64-byte CDB: uses DeviceIoControl(IOCTL_SEND_USB_REQUEST = 0x80002008)

### Attempt 5: RTTI + Interface Analysis
**Tool**: strings, hex dump, radare2 RTTI labels
**Result**: SUCCESS
- 6 abstract interfaces: ICommand, ICommandManager, ISession, ISessionsCollection, IDeviceInfo, IDeviceTable
- CUSB2Command vtable at 0x1000e210 (10 entries, 40 bytes)
- CSBP2Command vtable at 0x1000e1e4 (10 entries, 40 bytes)
- Only vtable slot 3 (Execute) differs between USB and SBP-2
- All other 9 slots are shared code

### Attempt 6: DeviceIoControl IOCTL Mapping
**Tool**: radare2 xrefs
**Target**: All 5 DeviceIoControl callsites
**Result**: SUCCESS
- 0x80002008 (IOCTL_SEND_USB_REQUEST): at 0x10002da0, 0x10003023 — vendor USB control transfer
- 0x80002014 (IOCTL_GET_DEVICE_DESCRIPTOR): at 0x10003bbe — pipe/endpoint config
- 0x80002018 (IOCTL_GET_USB_DESCRIPTOR): at 0x1000323e — device descriptor (VID/PID)
- 5th callsite at 0x100054d6 also uses IOCTL (in CUSBSession pipe query)

### Attempt 7: Session/Device Management
**Tool**: radare2
**Target**: CUSBSession, CUSBDevInfo, CUSBDeviceTable
**Result**: SUCCESS
- CUSBSession: opens \\.\UsbscanN via CreateFileA, stores handle at [this+4]
- Session open gets pipe endpoint info via IOCTL_GET_DEVICE_DESCRIPTOR
- Calculates USB 2.0 vs 1.1 max transfer size
- CUSBDevInfo: reads USB descriptors via IOCTL_GET_USB_DESCRIPTOR
- CUSBDeviceTable: uses StiCreateInstanceW for STI enumeration

### Attempt 8: NKDSBP2.dll Comparison
**Tool**: radare2, strings
**Target**: NKDSBP2.dll NkDriverEntry + RTTI
**Result**: SUCCESS
- Identical NkDriverEntry structure: same 9 FCs, same __stdcall(3 params), same critical section pattern
- RTTI classes: CSBP2Command, CSBP2CommandManager, CSBP2Session, CSBP2SessionsCollection, CSBP2Device, CSBP2DeviceManager
- Interface difference: IDevice/IDeviceManager (1394) vs IDeviceInfo/IDeviceTable (USB)
- Command interfaces identical — only Execute method differs (SBP-2 vs USB bulk)

### Attempt 9: FC5/FC6/FC7/FC8/FC9 Deep Analysis
**Tool**: radare2
**Target**: All 5 handler functions + sub-functions
**Result**: SUCCESS — full internal mechanics decoded

**FC5 (Execute SCSI Command, 0x10003fd0)**:
- Validates `[param1+0x24] >= 0x20` (CDB min size)
- Gets ICommandManager from `[param2+4]`, calls `virtual_16` to look up command
- Calls `ICommand::virtual_24` to get transfer size flag
- `fcn.100030a0` allocates command: 0x1C bytes, picks vtable based on transfer_size:
  - If == 0x20000: CUSB2Command vtable (USB bulk)
  - Else: CSBP2Command vtable (IOCTL path)
- Error callback at `[param1+0xC]` → `callback(param1, error_code)` pattern throughout

**FC6 (Get Status, 0x10003f90)**: Looks up ICommand via `ICommandManager::virtual_16`, tail-calls `ICommand::virtual_8`
**FC7 (Shutdown, 0x10003f10)**: Destroys all 3 interface objects at `[param2+0/4/8]`, frees context, calls `SetThreadExecutionState(0x80000000)` to re-enable sleep
**FC8 (Query, 0x100040c0)**: Same as FC6 but tail-calls `ICommand::virtual_16` instead of `virtual_8`
**FC9 (Execute+Retrieve, 0x10004100)**: Finds command via `ICommandManager::virtual_16`, then calls `ISessionsCollection::virtual_44` with it

**FC2/FC3/FC4 Deep Analysis**:
- FC2 sub-function at 0x10004150: validates magic 0x8004, calls `ICommandManager::virtual_20` for shutdown
- FC2 sub-function at 0x10004190: iterates sessions, calls `ISessionsCollection::virtual_32` per session
- FC3 at 0x10004230: simple state flag set `[param1+4] = 8`
- FC3 at 0x100041c0: finds command via `ICommandManager::virtual_16`, calls `ICommand::virtual_4` for cleanup
- FC4 at 0x100041f0: calls `ISessionsCollection::virtual_20`, returns 0x31012 on failure

### Attempt 10: Worker Thread Analysis
**Tool**: radare2
**Target**: CreateThread callsite, thread procedure, CommandManager init
**Result**: SUCCESS

- CreateThread called from `CSBP2CommandManager::virtual_4` at 0x10001000
- 3 events created: `CreateEventA` × 3 (auto-reset, manual-reset, auto-reset)
- 2 critical sections allocated (0x18 bytes each)
- Thread proc at 0x10002880 — command queue processing loop
- CRT _beginthreadex wrapper at 0x1000574b, actual thread proc at 0x100056cb
- Thread priority set to THREAD_PRIORITY_HIGHEST (2)
- Loop: dequeue command → check termination → execute → get status → callback → destroy → signal → repeat
- Exit when `virtual_52` returns 1 (termination flag)
- Thread proc stores thread ID via GetCurrentThreadId
- The "CSBP2" prefix on CommandManager is misleading — it handles both USB and SBP-2 commands

### Attempt 11: STI Enumeration Deep Dive
**Tool**: radare2
**Target**: CUSBDeviceTable::virtual_20 at 0x10003a90
**Result**: SUCCESS — full enumeration flow decoded

- STI device entries are 0x124 (292) bytes each (STI_DEVICE_INFORMATION)
- Device path at offset +0x118 (wide string)
- Substring search for "Usbscan" via `fcn.100061da` (wcsstr equivalent)
- WideCharToMultiByte converts path for CreateFileA
- Opens each matching device, queries IOCTL_GET_DEVICE_DESCRIPTOR (0x80002014)
- **USB speed detection**: max_packet_size from IOCTL result at offset +0x10:
  - 0x40 (64) → USB 1.1 Full Speed, speed_type = 2 (calculated as 0x40-0x3E)
  - 0x200 (512) → USB 2.0 High Speed, speed_type = 3
  - Other → speed_type = 0
- Each valid device: creates CUSBDevInfo via `fcn.10003a50`, adds to linked list at `[this+0xC]`
- Device handle immediately closed after descriptor query (not kept open)
