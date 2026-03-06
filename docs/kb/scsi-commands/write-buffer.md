# WRITE BUFFER (0x3B)

| Field | Value |
|-------|-------|
| **Status** | Complete |
| **Last Updated** | 2026-02-28 |
| **Phase** | 2 + 4 |
| **Confidence** | Verified (cross-validated host ↔ firmware) |

## Overview

Standard SCSI WRITE BUFFER command. Writes data to a specific buffer within the scanner,
identified by a buffer ID and byte offset. This is the write-side counterpart to READ
BUFFER, providing direct addressed access to scanner memory buffers.

This command is commonly used in SCSI devices for **firmware updates** — the new firmware
image is written to a designated buffer, and the device flashes it to non-volatile storage.
For the Coolscan, this may also be used for uploading calibration data or configuration
to specific memory regions.

## CDB Layout (10 bytes)

| Byte | Field | Value | Notes |
|------|-------|-------|-------|
| 0 | Opcode | `0x3B` | WRITE BUFFER |
| 1 | Mode | varies | Buffer access mode |
| 2 | Buffer ID | varies | Which buffer to write to |
| 3 | Buffer Offset [MSB] | varies | 24-bit offset into buffer (big-endian) |
| 4 | Buffer Offset | varies | |
| 5 | Buffer Offset [LSB] | varies | |
| 6 | Parameter List Length [MSB] | varies | Number of bytes to write (big-endian) |
| 7 | Parameter List Length | varies | |
| 8 | Parameter List Length [LSB] | varies | |
| 9 | Control | `0x00` | |

### Mode (Byte 1)

Standard SCSI WRITE BUFFER modes:

| Value | Mode | Description |
|-------|------|-------------|
| 0x00 | Combined header and data | Header + data |
| 0x02 | Data | Raw data to buffer |
| 0x04 | Download microcode | Firmware update |
| 0x05 | Download microcode and save | Firmware update + flash |
| 0x0A | Echo buffer | Write to echo buffer (read back via READ BUFFER) |

**Firmware update modes (0x04/0x05) are particularly relevant** — the Coolscan firmware
is stored in flash (MBM29F400B) and could theoretically be updated over USB using this
command.

### Buffer ID (Byte 2)

Identifies the target buffer. For firmware updates, this is typically 0x00.

### Buffer Offset (Bytes 3-5)

24-bit big-endian offset within the selected buffer.

### Parameter List Length (Bytes 6-8)

24-bit big-endian value specifying how many bytes to write.

## Data Phase

**Direction:** Data-Out (host -> scanner)

The data format depends on the mode:
- Mode 0x02: raw data written directly to the buffer at the specified offset
- Mode 0x04/0x05: firmware image data (possibly with device-specific header)

## Usage Context

- **Firmware updates**: Writing new firmware to the scanner's flash memory
- **Calibration upload**: Writing calibration data to specific scanner buffers
- **Diagnostics**: Writing test patterns or configuration data
- May be used by NikonScan's firmware update feature

## Caution

Writing to scanner buffers can potentially brick the device if:
- Firmware update is interrupted
- Invalid data is written to critical configuration buffers
- Flash write operations corrupt the boot sector

This command should be used with extreme care in any custom driver implementation.

## Firmware Handler (Phase 4)

**Handler address**: `FW:0x02837C` | **Exec mode**: 0x02 (data-out) | **Perm flags**: 0x0014

The firmware handler accepts buffer data from the host and writes it to the designated internal buffer. This command is used for firmware updates, not for normal scanning. The handler at 0x02837C is distinct from the SEND(10)/WRITE(10) handler at 0x025506 — WRITE BUFFER provides raw addressed access to internal buffers while WRITE(10) uses abstract data type codes.

Permission flags 0x0014 require the scanner to be initialized. **Caution**: Flash write operations (mode 0x04/0x05) could brick the scanner if interrupted.

## Source References

| Source | Location | Notes |
|--------|----------|-------|
| LS5000.md3 | `0x100b5270` | CDB builder — same field layout as READ BUFFER |

## Cross-References

- [READ BUFFER](read-buffer.md) — reads data from scanner buffers
- [READ](read.md) — higher-level data read using data type codes
- [WRITE](write.md) — higher-level data write using data type codes
- [SCSI Command Build Infrastructure](../components/ls5000-md3/scsi-command-build.md) — CDB builder vtable system
- [NKDUSCAN API](../components/nkduscan/api.md) — USB transport that sends this CDB
- [USB Protocol](../architecture/usb-protocol.md) — transport layer details
