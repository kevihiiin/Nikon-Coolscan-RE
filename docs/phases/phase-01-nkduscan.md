# Phase 1: NKDUSCAN.dll -- USB Transport Layer

## Goal
Fully document the USB-to-SCSI wrapping protocol and the `NkDriverEntry` API exposed by NKDUSCAN.dll.

## Completion Criteria
All must be met to mark phase complete:
- [ ] `NkDriverEntry` fully decompiled: function signature, dispatch logic, all function codes documented
- [ ] RTTI class hierarchy recovered and diagrammed: all vtables labeled, inheritance mapped
- [ ] Every `DeviceIoControl` callsite identified with IOCTL code and purpose
- [ ] `CUSB2Command` class fully reversed: CDB construction, USB bulk send, phase query (0xD0), data transfer, sense retrieval (0x06)
- [ ] USB-to-SCSI wrapping protocol documented byte-by-byte in `kb/architecture/usb-protocol.md`
- [ ] `NkDriverEntry` API documented well enough to write a caller (param types, function codes, return values)
- [ ] NKDSBP2.dll briefly compared: confirm same `ICommand`/`ISession` interface, note transport differences
- [ ] All KB docs in `kb/components/nkduscan/` written with status >= "In Progress"

## Targets

| Binary | Path | Ghidra Project | Size |
|--------|------|----------------|------|
| NKDUSCAN.dll | binaries/software/NikonScan403_installed/Drivers/NKDUSCAN.dll | NikonScan_Drivers | ~90KB |
| NKDSBP2.dll | binaries/software/NikonScan403_installed/Drivers/NKDSBP2.dll | NikonScan_Drivers | ~86KB |

## Methodology (Step by Step)

### Step 1: Export & Import Analysis
**What to do**: List all exports and imports of NKDUSCAN.dll.
**What to look for**:
- Single export: `NkDriverEntry` -- this is the entire public API
- Imports from kernel32.dll: `DeviceIoControl`, `CreateFileA/W`, memory allocation
- Imports from usbscan.sys IOCTLs via DeviceIoControl
**Where to look**: PE export/import tables (use Phase 0 extraction script output)
**Output**: `kb/components/nkduscan/api.md` with export/import list

### Step 2: RTTI Class Hierarchy Recovery
**What to do**: Find all RTTI type descriptors (`.?AV` strings), reconstruct class hierarchy.
**What to look for**:
- Known classes from prior recon: `CUSB2Command`, `CUSBSession`, `CUSBDevInfo`, `CUSBDeviceTable`, `CUSBSessionsCollection`
- Base class pointers in `RTTICompleteObjectLocator` structures
- VTable addresses associated with each class
**Where to look**: `.rdata` section for RTTI structures, `.text` for vtable references
**Output**: Class hierarchy diagram, vtable mapping in `kb/components/nkduscan/classes.md`

### Step 3: NkDriverEntry Dispatch Logic
**What to do**: Fully decompile `NkDriverEntry` export function.
**What to look for**:
- Function code parameter (likely first or second arg after calling convention)
- Switch/dispatch table on the function code
- Each case creates or uses a different class/operation
- Common function codes might include: open device, close device, send command, get status
**Where to look**: Start at the single export address
**Output**: Complete function code table in `kb/components/nkduscan/api.md`

### Step 4: CUSB2Command -- SCSI-over-USB Protocol
**What to do**: Reverse the `CUSB2Command` class completely.
**What to look for**:
- **CDB construction**: How a SCSI Command Descriptor Block is built (opcode, LUN, parameters)
- **USB bulk-out**: CDB sent via USB bulk write
- **Phase query**: Opcode `0xD0` sent to query device phase (data-in, data-out, status, etc.)
- **Data transfer**: Bulk read/write based on phase
- **Sense retrieval**: Opcode `0x06` (REQUEST SENSE) to get error information
- **Status handling**: How command completion/error is determined
**Where to look**: `CUSB2Command` vtable methods, especially send/execute methods. Cross-reference DeviceIoControl calls.
**Output**: Byte-level protocol documentation in `kb/architecture/usb-protocol.md`

### Step 5: DeviceIoControl IOCTL Mapping
**What to do**: Find every `DeviceIoControl` call in NKDUSCAN.dll.
**What to look for**:
- IOCTL codes (constants passed as `dwIoControlCode` parameter)
- These map to `usbscan.sys` driver IOCTLs
- Common ones: `IOCTL_SEND_USB_REQUEST`, `IOCTL_READ_REGISTERS`, `IOCTL_WRITE_REGISTERS`
- The buffer layouts for each IOCTL
**Where to look**: Cross-references to `DeviceIoControl` import
**Output**: IOCTL mapping table in `kb/components/nkduscan/usb-transport.md`

### Step 6: CUSBSession & Device Management
**What to do**: Reverse session/device management classes.
**What to look for**:
- `CUSBSession`: How a communication session is opened/closed with a scanner
- `CUSBDeviceTable`: How available scanners are enumerated
- `CUSBDevInfo`: Per-device information storage
- Device open path (likely `\\.\UsbscanN` or similar)
**Where to look**: Constructor/destructor of each class, `NkDriverEntry` open/close function codes
**Output**: Session lifecycle documentation in `kb/components/nkduscan/overview.md`

### Step 7: NKDSBP2.dll Comparison
**What to do**: Brief analysis of NKDSBP2.dll to confirm interface equivalence.
**What to look for**:
- Same `NkDriverEntry` export signature
- Equivalent class hierarchy (CSBP2Command vs CUSB2Command)
- Different transport (1394 SBP-2 protocol vs USB bulk)
- Confirms the abstraction boundary -- everything above this layer is transport-agnostic
**Where to look**: NKDSBP2.dll exports, RTTI classes, string references
**Output**: Comparison notes in `kb/components/nkduscan/overview.md`

## Key Addresses / Patterns

### IOCTL Codes for usbscan.sys
- `0x80002004`: IOCTL_SEND_USB_REQUEST (vendor request)
- `0x80002014`: IOCTL_GET_PIPE_CONFIGURATION
- `0x80002024`: IOCTL_RESET_PIPE
- `0x80002018`: IOCTL_GET_VERSION
- Look for constants in `0x8000XXXX` range

### USB-SCSI Protocol Opcodes (from prior recon)
- `0xD0`: Phase query (vendor-specific USB command to ask scanner's current phase)
- `0x06`: REQUEST SENSE (standard SCSI, but wrapped in USB)
- `0x12`: INQUIRY
- `0x00`: TEST UNIT READY

### RTTI Search Pattern
- String `.?AV` in .rdata section marks MSVC `type_info::name`
- Follow pointer chain: type_info -> RTTIClassHierarchyDescriptor -> base class array

## Prerequisite Knowledge
- `kb/architecture/system-overview.md` (Phase 0)
- `kb/architecture/software-layers.md` (Phase 0)
- Windows `usbscan.sys` IOCTL interface (research during analysis)

## KB Deliverables
- `kb/components/nkduscan/overview.md`
- `kb/components/nkduscan/classes.md`
- `kb/components/nkduscan/api.md`
- `kb/components/nkduscan/usb-transport.md`
- `kb/architecture/usb-protocol.md`

## Log Files
- Phase log: `logs/phases/phase-01-nkduscan.md`
- Component logs: `logs/components/nkduscan-attempts.md`, `logs/components/nkdsbp2-attempts.md`
