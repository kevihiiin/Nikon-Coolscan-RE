# READ (0x28)

| Field | Value |
|-------|-------|
| **Status** | Complete |
| **Last Updated** | 2026-02-28 |
| **Phase** | 2 + 4 |
| **Confidence** | Verified (cross-validated host ↔ firmware) |

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

Specifies what category of data to read. The firmware validates this against a dispatch table at flash `0x49AD8` (12-byte entries, 0xFF-terminated). SCSI-2 defines 0x00-0x03 as standard; 0x80-0xFF are Nikon vendor-specific.

| Value | Name | Max Size | Qualifier | Confidence |
|-------|------|----------|-----------|------------|
| `0x00` | Image Data | Variable | 0=8-bit, 1=16-bit | Verified |
| `0x03` | Gamma Function / LUT | 32768 | Per CDB[5] | Verified |
| `0x81` | Scan Area / Film Frame Info | 8 | Single value | High |
| `0x84` | Calibration Data | 6 | Single value | Verified |
| `0x87` | Scan Parameters / Status | 24 | None (ignored) | Verified |
| `0x88` | Boundary / Per-Channel Cal | 644 | 0-3 (R/G/B/all) | Verified |
| `0x8A` | Exposure / Gain Parameters | 14 | 0-3 (R/G/B/all) | High |
| `0x8C` | Offset / Dark Current | 10 | 0-3 (R/G/B/all) | High |
| `0x8D` | Extended Scan Line Data | Variable | 0/1/3 (modes) | High |
| `0x8E` | Focus / Measurement Data | Variable | 0 or 1 | High |
| `0x8F` | Histogram / Profile | 324 | 0/1/3 (R/G/B) | High |
| `0x90` | CCD Characterization | 54 | 0-3 (R/G/B/all) | High |
| `0x92` | Motor / Positioning Status | 10 | 0-3 (sub-type) | High |
| `0x93` | Adapter / Film Type Info | 12 | Single value | High |
| `0xE0` | Extended Configuration | 1030 | 0/1/3 (modes) | High |

The firmware handler (at `0x0240E2`) dispatches each DTC to a dedicated sub-routine. Any value not in this table returns sense code 0x0050 (ILLEGAL REQUEST / Invalid Field in CDB).

### Data Type Qualifier (Byte 5)

Provides additional qualification within a Data Type Code. The allowed qualifier values depend on the DTC's category byte (second byte in the firmware table entry):

| Category | Allowed Qualifiers | Meaning |
|----------|-------------------|---------|
| `0x00` | (ignored) | No qualifier needed |
| `0x01` | Must match table | Single mode |
| `0x03` | 0, 1, 2, or 3 | Channel select: 0=composite/all, 1=R, 2=G, 3=B |
| `0x10` | 0 or 1 | Two-mode select |
| `0x30` | 0, 1, or 3 | Three-mode select (R/G/B channels, skipping 2) |

For image data (DTC=0x00): qualifier 0 selects 8-bit pixel output, qualifier 1 selects 16-bit.
For per-channel data (DTCs 0x88, 0x8A, 0x8C, 0x90): qualifier selects the color channel.
For gamma/LUT (DTC=0x03): qualifier identifies the specific LUT table.

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

Internal calibration values with scanner-specific formats.

### DTC Sub-handler Details (from firmware dispatch at FW:0x240E2)

Each DTC branches to a dedicated sub-handler in the READ dispatch chain. Sub-handler addresses and key behaviors for the previously Medium-confidence DTCs:

**DTC 0x8C — Offset/Dark Current** (sub-handler at `FW:0x24BB4`, 10 bytes):
Reads per-channel calibration data from RAM at `0x40107C` (word) and `0x40108C` (word), with qualifier selecting the channel. Uses shared per-channel reader at `FW:0x24C9C`. Response is 10 bytes of offset/dark current measurements used for CCD black-level correction.

**DTC 0x8E — Focus/Measurement** (sub-handler at `FW:0x24CDE`, variable size):
Reads focus measurement data from `0x405282` (word). For qualifier=0, reads 3 iterations of 9 bytes each; for qualifier=1, reads variable-length measurement. Calls `FW:0x24EE2` for extended processing. Data represents autofocus sensor readings.

**DTC 0x90 — CCD Characterization** (sub-handler at `FW:0x24E84`, 54 bytes):
Validates command state (`0x400773` must be 0x06 or 0x07). For active scans (state 0x01), checks multiple scan config flags (`0x400E99`, `0x400E96`, `0x400EA1`, `0x400EA0`, `0x400EA4`, `0x4052D6`). Returns 54 bytes (0x36) of CCD characterization data via shared response builder at `FW:0x25060`.

**DTC 0x92 — Motor/Positioning Status** (sub-handler at `FW:0x24F82`, 10 bytes):
Copies 10 bytes from RAM at `0x400B20` (motor state block) via `FW:0x25120`. Transfer size validated as ≤ 0x0A. Yields (calls 0x109E2) if scanner is in active scan state (0x01). Response contains motor position, speed, and direction data.

**DTC 0x93 — Adapter/Film Type Info** (sub-handler at `FW:0x24FC4`, 12 bytes):
Copies 12 bytes starting at RAM address `0x6042` (via mov.l #0x60042). Transfer validated as ≤ 0x0C. Response contains adapter identification (type, holder, film format) — the hardware counterpart to the string table at `0x49E30`.

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

## Firmware Handler (Phase 4)

**Handler address**: `FW:0x023F10` | **Exec mode**: 0x03 (data-in) | **Permission**: 0x0054 (only during active read)

The READ handler has restrictive permission flags (0x0054) — it can only be called when the scanner is in an active scan/read state. The handler transfers scan data from ASIC buffer RAM (`0x800000+`) or buffer RAM (`0xC00000+`) to the host via the ISP1581 USB controller's DMA engine.

## Source References

| Source | Location | Notes |
|--------|----------|-------|
| LS5000.md3 | `0x100b51b0` | Vtable-based CDB builder |
| LS5000.md3 | `0x100866d9` | Inline builder — scan data read path 1 |
| LS5000.md3 | `0x10086dfa` | Inline builder — scan data read path 2 |
| LS5000.md3 | `0x1008781a` | Inline builder — scan data read path 3 |
| Firmware | `0x023F10` | Handler — scan data transfer |

## Cross-References

- [WRITE](write.md) — counterpart that sends data to the scanner
- [SCAN](scan.md) — triggers the scan whose data is retrieved by READ
- [SET WINDOW](set-window.md) — defines the data format that READ will return
- [READ BUFFER](read-buffer.md) — alternative way to read from scanner buffers
- [Firmware SCSI Handler](../components/firmware/scsi-handler.md) — Full dispatch table
- [ISP1581 USB](../components/firmware/isp1581-usb.md) — USB DMA for data transfer
- [SCSI Command Build Infrastructure](../components/ls5000-md3/scsi-command-build.md) — CDB builder vtable system
- [NKDUSCAN API](../components/nkduscan/api.md) — USB transport that sends this CDB
- [USB Protocol](../architecture/usb-protocol.md) — transport layer details
