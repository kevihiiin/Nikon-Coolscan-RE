# READ BUFFER (0x3C)

| Field | Value |
|-------|-------|
| **Status** | Complete |
| **Last Updated** | 2026-02-21 |
| **Phase** | 2 |
| **Confidence** | High |

## Overview

Standard SCSI READ BUFFER command. Reads data from a specific buffer within the scanner,
identified by a buffer ID and byte offset. Unlike READ (0x28) which uses abstract data
type codes, READ BUFFER provides direct addressed access to scanner memory buffers.

This command may be used for:
- Reading diagnostic data from specific scanner memory regions
- Accessing firmware version or configuration data stored in named buffers
- Low-level debugging and diagnostics
- Reading back data previously written via WRITE BUFFER

## CDB Layout (10 bytes)

| Byte | Field | Value | Notes |
|------|-------|-------|-------|
| 0 | Opcode | `0x3C` | READ BUFFER |
| 1 | Mode | varies | Buffer access mode |
| 2 | Buffer ID | varies | Which buffer to read from |
| 3 | Buffer Offset [MSB] | varies | 24-bit offset into buffer (big-endian) |
| 4 | Buffer Offset | varies | |
| 5 | Buffer Offset [LSB] | varies | |
| 6 | Parameter List Length [MSB] | varies | Number of bytes to read (big-endian) |
| 7 | Parameter List Length | varies | |
| 8 | Parameter List Length [LSB] | varies | |
| 9 | Control | `0x00` | |

### Mode (Byte 1)

Standard SCSI READ BUFFER modes:

| Value | Mode | Description |
|-------|------|-------------|
| 0x00 | Combined header and data | Returns header + buffer data |
| 0x02 | Data | Returns buffer data only |
| 0x03 | Descriptor | Returns buffer descriptor (capacity info) |
| 0x0A | Echo buffer | Reads echo buffer (written by WRITE BUFFER) |

The Nikon scanner may only support a subset of these modes, or may use vendor-specific
mode values.

### Buffer ID (Byte 2)

Identifies which internal buffer to access. The available buffer IDs and their contents
are scanner-specific. Possible buffers:
- Firmware version/info buffer
- Diagnostic data buffer
- Calibration data buffers
- Scan data buffers (if direct access is supported)

### Buffer Offset (Bytes 3-5)

24-bit big-endian offset within the selected buffer. Allows random access to large
buffers by reading in chunks starting at different offsets.

### Parameter List Length (Bytes 6-8)

24-bit big-endian value specifying how many bytes to read.

## Data Phase

**Direction:** Data-In (scanner -> host)

The returned data format depends on the mode and buffer ID. In mode 0x02 (data), the
raw buffer contents are returned. In mode 0x00 (combined), a 4-byte header precedes
the data.

## Usage Context

- Used for low-level buffer access, diagnostics, and firmware queries
- Less commonly used than READ (0x28) for normal scan operations
- May be used during firmware update processes to verify written data
- Complements WRITE BUFFER (0x3B) for bidirectional buffer access

## Source References

| Source | Location | Notes |
|--------|----------|-------|
| LS5000.md3 | `0x100b5230` | CDB builder — byte1=mode, byte2=buffer_id, bytes3-5=offset, bytes6-8=length |

## Cross-References

- [WRITE BUFFER](write-buffer.md) — writes data to scanner buffers
- [READ](read.md) — higher-level data read using data type codes
- [WRITE](write.md) — higher-level data write using data type codes
- [SCSI Command Build Infrastructure](../components/ls5000-md3/scsi-command-build.md) — CDB builder vtable system
- [NKDUSCAN API](../components/nkduscan/api.md) — USB transport that sends this CDB
- [USB Protocol](../architecture/usb-protocol.md) — transport layer details
