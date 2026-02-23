# WRITE (0x2A)

| Field | Value |
|-------|-------|
| **Status** | Complete |
| **Last Updated** | 2026-02-21 |
| **Phase** | 2 |
| **Confidence** | High |

## Overview

Standard SCSI WRITE(10) command, repurposed for scanner use. Instead of writing disk sectors,
this command sends data to the scanner — typically calibration data, look-up tables (LUTs),
gamma curves, or other configuration data that is too large for a CDB parameter.

The WRITE command mirrors the READ command structure, with the same Data Type Code and
Data Type Qualifier fields, but transfers data in the opposite direction (host to scanner).

## CDB Layout (10 bytes)

| Byte | Field | Value | Notes |
|------|-------|-------|-------|
| 0 | Opcode | `0x2A` | WRITE(10) |
| 1 | Reserved | `0x00` | |
| 2 | Data Type Code | varies | What kind of data to write |
| 3 | Reserved | `0x00` | |
| 4 | Reserved | `0x00` | |
| 5 | Data Type Qualifier | varies | Sub-type or channel selector |
| 6 | Transfer Length [MSB] | varies | Number of bytes to write (big-endian) |
| 7 | Transfer Length | varies | |
| 8 | Transfer Length [LSB] | varies | |
| 9 | Control | `0x00` | Standard control (no vendor flag) |

### Control Byte (Byte 9)

Unlike READ which uses `0x80`, WRITE uses `0x00` for the control byte. This asymmetry
is notable — the vendor flag may only be needed for data-in transfers.

### Data Type Code and Qualifier

Same field positions as READ (bytes 2 and 5). The data type code specifies what kind of
data is being written:

| Value | Meaning | Notes |
|-------|---------|-------|
| TBD | Calibration data | White/dark calibration tables |
| TBD | LUT / gamma curve | Tone correction tables |
| TBD | Configuration data | Scanner operating parameters |

## Data Phase

**Direction:** Data-Out (host -> scanner)

### Calibration Data

The host can upload calibration data to override or supplement the scanner's internal
calibration. This may include:
- **White balance tables** — per-pixel gain correction for CCD non-uniformity
- **Dark frame data** — offset correction for CCD dark current
- **Gamma/LUT curves** — tone mapping applied in scanner hardware before data transfer

### Look-Up Tables (LUTs)

The Coolscan supports hardware LUT application, where tone curves are applied by the
scanner's ASIC before pixel data is transferred to the host. This is more efficient
than software-based tone mapping for large scans.

## Usage Context

- Called during scan setup to upload calibration or correction data
- Called before scanning to set hardware LUTs/gamma curves
- Typical calibration sequence:
  1. `READ` — read scanner's internal calibration data
  2. Process/modify calibration in software
  3. **`WRITE`** — upload modified calibration back to scanner
- Not used for image data (image data flows scanner -> host via READ only)

## Source References

| Source | Location | Notes |
|--------|----------|-------|
| LS5000.md3 | `0x100b51f0` | CDB builder — mirrors READ structure, byte9=0x00 |

## Cross-References

- [READ](read.md) — counterpart that reads data from the scanner
- [READ BUFFER](read-buffer.md) — alternative way to read from scanner buffers
- [WRITE BUFFER](write-buffer.md) — alternative way to write to scanner buffers
- [SCSI Command Build Infrastructure](../components/ls5000-md3/scsi-command-build.md) — CDB builder vtable system
- [NKDUSCAN API](../components/nkduscan/api.md) — USB transport that sends this CDB
- [USB Protocol](../architecture/usb-protocol.md) — transport layer details
