# USB-to-SCSI Wrapping Protocol

**Status**: Complete
**Last Updated**: 2026-02-28
**Phase**: 1 (USB Transport)
**Confidence**: High (verified from NKDUSCAN.dll disassembly)

## Overview

The Nikon Coolscan USB scanners use a **custom vendor-specific** USB protocol to transport SCSI commands. This is **NOT** USB Mass Storage (UMS/BOT). The host driver (NKDUSCAN.dll) communicates with the scanner through the Windows `usbscan.sys` Still Image driver, using USB bulk pipes for command/data transfer and single-byte opcodes for flow control.

## Why Not USB Mass Storage?

Standard USB Mass Storage uses the Bulk-Only Transport (BOT) protocol with 31-byte Command Block Wrappers (CBW) and 13-byte Command Status Wrappers (CSW). The Nikon protocol is simpler and proprietary:

- No CBW/CSW wrappers
- Single-byte phase query (0xD0) instead of CSW status
- Single-byte sense request (0x06) for error retrieval
- CDB sent raw on the bulk-out pipe (no encapsulation)

## Transport Layer

### USB Device

- **VID**: 0x04B0 (Nikon Corporation)
- **PID**: 0x4001 (Coolscan V / LS-50)
- **Interface**: Still Image (usbscan.sys driver)
- **Device path**: `\\.\UsbscanN` (N = device index, discovered via STI enumeration)

### USB Device Descriptors (from firmware)

The firmware contains two USB device descriptors at flash `0x170FA` (USB 1.1) and `0x1710C` (USB 2.0). The ISP1581 selects the appropriate one based on the negotiated bus speed.

| Field | Value | Notes |
|-------|-------|-------|
| bDeviceClass | `0xFF` | Vendor-specific (NOT Mass Storage or Still Image) |
| bDeviceSubClass | `0xFF` | Vendor-specific |
| bDeviceProtocol | `0xFF` | Vendor-specific |
| bMaxPacketSize0 | 64 | Control endpoint max packet size |
| idVendor | `0x04B0` | Nikon Corporation |
| idProduct | `0x4001` | Coolscan V (LS-50) |
| bcdDevice | `0x0102` | Device version 1.02 (matches firmware revision) |
| bmAttributes | `0xC0` | Self-powered |
| bNumConfigurations | 1 | Single configuration |

### Endpoint Configuration

Two bulk endpoints, with max packet size dependent on USB speed:

| Endpoint | Address | Type | USB 1.1 MaxPkt | USB 2.0 MaxPkt | Purpose |
|----------|---------|------|----------------|----------------|---------|
| EP1 OUT | `0x01` | Bulk | 64 bytes | 512 bytes | Host → Scanner (CDB, data-out, opcodes) |
| EP2 IN | `0x82` | Bulk | 64 bytes | 512 bytes | Scanner → Host (phase, data-in, sense) |

Descriptor template locations in flash:
- USB 1.1 endpoints: `FW:0x1711E` (EP1 OUT 64B) and `FW:0x17126` (EP2 IN 64B)
- USB 2.0 endpoints: `FW:0x1712E` (EP1 OUT 512B) and `FW:0x17136` (EP2 IN 512B)
- Configuration descriptors: `FW:0x1713E` (USB 1.1) and `FW:0x17148` (USB 2.0)
- Interface: Class `0xFF/0xFF/0xFF` (vendor-specific), 2 endpoints

### Pipe Configuration

The driver opens the device with `CreateFileA("\\.\UsbscanN", GENERIC_READ | GENERIC_WRITE, ...)` and uses:

- **Bulk-Out pipe** (EP1): `WriteFile()` — sends CDBs, data-out, phase queries, sense requests
- **Bulk-In pipe** (EP2): `ReadFile()` — receives phase responses, data-in, sense data
- **Control pipe**: `DeviceIoControl(IOCTL_SEND_USB_REQUEST = 0x80002008)` — used only for 64-byte extended CDBs

Source: `CUSB2Command::virtual_12` at `NKDUSCAN.dll:0x10002b50`

## SCSI Command Execution Protocol

### Standard Path (CDB size = 32 bytes)

A complete SCSI command exchange follows this sequence:

```
Host (NKDUSCAN.dll)              Scanner (firmware)
       |                                |
  (1)  |--- CDB (bulk-out) ----------->|  Raw SCSI CDB, 32 bytes
       |                                |  Scanner parses & prepares response
  (2)  |--- 0xD0 (bulk-out) ---------->|  Phase query: "what's next?"
  (3)  |<-- phase byte (bulk-in) ------|  Response: 0x01/0x02/0x03
       |                                |
       |  [If phase == 0x03: data-in]   |
  (4a) |<-- data (bulk-in) ------------|  Scanner sends scan data
       |    (chunked reads, up to       |
       |     transfer_length bytes)     |
       |                                |
       |  [If phase == 0x02: data-out]  |
  (4b) |--- data (bulk-out) ---------->|  Host sends parameters/data
       |                                |
       |  [If phase == 0x01: no data]   |
       |    (skip data transfer)        |
       |                                |
  (5)  |--- 0x06 (bulk-out) ---------->|  Sense/status request
  (6)  |<-- sense data (bulk-in) ------|  Error/status information
       |                                |
```

### Phase Byte Values

| Phase | Meaning | Host Action |
|-------|---------|-------------|
| 0x01 | Status only / busy | Skip data transfer, proceed to sense |
| 0x02 | Data-out (host → scanner) | Write data via bulk-out |
| 0x03 | Data-in (scanner → host) | Read data via bulk-in |

Source: `NKDUSCAN.dll:0x10002c28-0x10002d0f`

Phase byte 0x01 was previously documented as "data-out" but actually means "no data transfer needed" — the host skips directly to the sense retrieval step. The command parameter struct's direction field (1=data-in, 2=data-out) must match the scanner's phase byte:

| Direction field | Expected phase | Operation |
|----------------|---------------|-----------|
| 1 | 0x03 | Data-in (read from scanner) |
| 2 | 0x02 | Data-out (write to scanner) |
| other | 0x01 | No data transfer |

### Extended Path (CDB size = 64 bytes)

For 64-byte CDBs, the driver uses `DeviceIoControl` with `IOCTL_SEND_USB_REQUEST (0x80002008)` instead of bulk pipe I/O. This sends the CDB as a USB vendor control transfer, then falls through to the same phase query / sense retrieval path.

Source: `NKDUSCAN.dll:0x10002d75-0x10002da6`

### Data Transfer Chunking

For data-in transfers (phase 0x03), the driver reads data in chunks:

1. First read: attempt full `transfer_length` bytes
2. If first read returns fewer bytes than `transfer_length`, use actual bytes received as new chunk size
3. Continue reading chunks until `transfer_length` total bytes received
4. Track bytes transferred and loop

This handles USB transfer size limitations and allows the scanner to pace data delivery.

Source: `NKDUSCAN.dll:0x10002c46-0x10002c98`

## Command Parameter Structure

The SCSI command is described by a parameter block at `[this + 0x18]` in CUSB2Command:

```c
struct CommandParams {
    DWORD field_00;           // +0x00: unknown
    DWORD direction;          // +0x04: 1=data-in, 2=data-out, other=no-data
    DWORD cdb_size;           // +0x08: CDB size (0x20=standard, 0x40=extended)
    DWORD callback;           // +0x0C: error callback function pointer (or NULL)
    DWORD field_10;           // +0x10: unknown
    DWORD cdb_data;           // +0x14: pointer to CDB bytes
    DWORD field_18;           // +0x18: secondary data / chunk size hint
    DWORD transfer_length;    // +0x1C: total data transfer size in bytes
    DWORD field_20;           // +0x20: unknown
    DWORD data_buffer;        // +0x24: pointer to data buffer
    DWORD sense_buffer_size;  // +0x28: sense data buffer size
};
```

Source: Field offsets from `NKDUSCAN.dll:0x10002b6a-0x10002b99`

## Error Codes

| Code | Meaning | Source |
|------|---------|--------|
| 0x00000000 | Success | All paths |
| 0x00011003 | Protocol error / unexpected phase | 0x10002d1f |
| 0x00021008 | Bulk I/O error (read/write failed) | 0x10002bc2 |

When an error occurs:
- `[this + 0x04]` = status code (2=success, 3=error)
- `[this + 0x08]` = error code (0x21008, 0x11003)
- If `callback` is non-NULL, it's called: `callback(error_code, param_block)`

## IOCTLs Used

| IOCTL Code | Name | Purpose |
|------------|------|---------|
| 0x80002008 | `IOCTL_SEND_USB_REQUEST` | Vendor USB control transfer (64-byte CDBs) |
| 0x80002014 | `IOCTL_GET_DEVICE_DESCRIPTOR` | Get USB device descriptor (pipe info) |
| 0x80002018 | `IOCTL_GET_USB_DESCRIPTOR` | Get USB string/config descriptor |

All IOCTLs go through `DeviceIoControl()` to the `usbscan.sys` kernel driver.

Source: `NKDUSCAN.dll:0x10002da0, 0x1000323e, 0x10003bbe`

## NKDSBP2.dll (FireWire) Comparison

NKDSBP2.dll implements the same `NkDriverEntry` API with identical function codes (1-9) and parameter conventions. The SCSI execution method (`CSBP2Command::virtual_12`) follows the same phase query protocol but uses SBP-2 (Serial Bus Protocol 2) over IEEE 1394 instead of USB bulk pipes.

Key differences:
- Uses 1394 bus driver instead of usbscan.sys
- Device enumeration via 1394 bus instead of STI
- Same `ICommand` interface, only `virtual_12` (Execute) differs

## Cross-References

- [NkDriverEntry API](../components/nkduscan/api.md)
- [CUSB2Command Class](../components/nkduscan/classes.md)
- [System Overview](system-overview.md)
- [Software Layers](software-layers.md)
