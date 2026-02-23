# READ (0x28)

| Field | Value |
|-------|-------|
| **Status** | Complete |
| **Last Updated** | 2026-02-21 |
| **Phase** | 2 |
| **Confidence** | High |

## Overview

Standard SCSI READ(10) command, repurposed for scanner use. Instead of reading disk sectors,
this command reads scan data, calibration data, or other scanner data from the device.
This is the primary command for retrieving scanned image data after a SCAN operation.

Multiple code paths build READ CDBs in LS5000.md3:
1. **Vtable-based builder** at `0x100b51b0` — general-purpose READ via CDB builder hierarchy
2. **Inline site 1** at `0x100866d9` — scan data read path
3. **Inline site 2** at `0x10086dfa` — scan data read path
4. **Inline site 3** at `0x1008781a` — scan data read path

The three inline sites are all in scan data retrieval code paths, suggesting they are
performance-critical hot loops that bypass the vtable builder for efficiency.

## CDB Layout (10 bytes)

| Byte | Field | Value | Notes |
|------|-------|-------|-------|
| 0 | Opcode | `0x28` | READ(10) |
| 1 | Reserved | `0x00` | |
| 2 | Data Type Code | varies | What kind of data to read |
| 3 | Reserved | `0x00` | |
| 4 | Reserved | `0x00` | |
| 5 | Data Type Qualifier | varies | Sub-type or channel selector |
| 6 | Transfer Length [MSB] | varies | Number of bytes to read (big-endian) |
| 7 | Transfer Length | varies | |
| 8 | Transfer Length [LSB] | varies | |
| 9 | Control | `0x80` | Nikon vendor control flag |

### Data Type Code (Byte 2)

Specifies what category of data to read. Known/suspected values:

| Value | Meaning | Notes |
|-------|---------|-------|
| TBD | Image data | Main scan data (RGB pixels) |
| TBD | Calibration data | CCD calibration / dark frame |
| TBD | Status/info | Scanner status or diagnostic data |

Further analysis needed to enumerate all data type codes.

### Data Type Qualifier (Byte 5)

Provides additional qualification of the data type. For image data, this may select:
- Color channel (R, G, B, IR)
- Data format variant
- Buffer region

### Transfer Length (Bytes 6-8)

24-bit big-endian value specifying the number of bytes to read from the scanner.
For image data, this corresponds to scan lines or pixel blocks.

### Control Byte (Byte 9)

The `0x80` value is a Nikon vendor extension flag, same as in SET WINDOW.

## Data Phase

**Direction:** Data-In (scanner -> host)

The data format depends on the Data Type Code:

### Image Data

Raw pixel data in the format specified by the preceding SET WINDOW command:
- Bit depth: 8-bit or 14/16-bit per channel
- Channels: grayscale (1), RGB (3), or RGBI (4, with infrared for Digital ICE)
- Byte order: big-endian for multi-byte pixel values
- Layout: line-by-line, with pixels in the order specified by the window descriptor

### Calibration Data

Internal calibration values — format is scanner-specific and requires firmware analysis
to fully document.

## Usage Context

- Called after SCAN to retrieve scanned image data
- May require multiple READ commands to transfer a full image (chunked transfer)
- Also used to read non-image data (calibration, diagnostics)
- The inline builders in scan data paths suggest the driver reads data in a tight loop:
  ```
  SET WINDOW -> SCAN -> READ (repeat) -> READ (repeat) -> ... -> done
  ```

## Performance Considerations

The three inline CDB builder sites (rather than using the vtable-based builder) suggest
that scan data reads are performance-critical. USB 2.0 bulk transfers at 480 Mbps are
the bottleneck for 4000 dpi 14-bit scans which produce large data volumes.

## Source References

| Source | Location | Notes |
|--------|----------|-------|
| LS5000.md3 | `0x100b51b0` | Vtable-based CDB builder |
| LS5000.md3 | `0x100866d9` | Inline builder — scan data read path 1 |
| LS5000.md3 | `0x10086dfa` | Inline builder — scan data read path 2 |
| LS5000.md3 | `0x1008781a` | Inline builder — scan data read path 3 |

## Cross-References

- [WRITE](write.md) — counterpart that sends data to the scanner
- [SCAN](scan.md) — triggers the scan whose data is retrieved by READ
- [SET WINDOW](set-window.md) — defines the data format that READ will return
- [READ BUFFER](read-buffer.md) — alternative way to read from scanner buffers
- [SCSI Command Build Infrastructure](../components/ls5000-md3/scsi-command-build.md) — CDB builder vtable system
- [NKDUSCAN API](../components/nkduscan/api.md) — USB transport that sends this CDB
- [USB Protocol](../architecture/usb-protocol.md) — transport layer details
