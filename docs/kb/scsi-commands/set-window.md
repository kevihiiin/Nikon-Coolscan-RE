# SET WINDOW (0x24)

| Field | Value |
|-------|-------|
| **Status** | Complete |
| **Last Updated** | 2026-02-28 |
| **Phase** | 2 + 4 |
| **Confidence** | Verified (cross-validated host ↔ firmware) |

## Overview

Standard SCSI SET WINDOW command. This is the **most important command for configuring
scans**. It sends a Window Descriptor to the scanner that defines all scan parameters:
resolution, bit depth, scan area coordinates, color mode, and vendor-specific extensions.

Every scan operation must be preceded by a SET WINDOW command. The scanner uses the
window descriptor to configure its CCD readout, motor speed, and data processing pipeline.

## CDB Layout (10 bytes)

| Byte | Field | Value | Notes |
|------|-------|-------|-------|
| 0 | Opcode | `0x24` | SET WINDOW |
| 1 | Reserved | `0x00` | |
| 2 | Reserved | `0x00` | |
| 3 | Reserved | `0x00` | |
| 4 | Reserved | `0x00` | |
| 5 | Reserved | `0x00` | |
| 6 | Transfer Length [MSB] | varies | Length of window descriptor data (big-endian) |
| 7 | Transfer Length | varies | |
| 8 | Transfer Length [LSB] | varies | |
| 9 | Control | `0x80` | Bit 7 set — Nikon vendor control flag |

### Transfer Length (Bytes 6-8)

24-bit big-endian value specifying the total length of the data-out payload (window
parameter header + window descriptor). Standard SCSI window descriptors are typically
40-48 bytes for the header + descriptor, but Nikon likely extends this with vendor-specific
fields.

### Control Byte (Byte 9)

The `0x80` value in the control byte is a Nikon vendor extension. Standard SCSI control
bytes are typically `0x00`. This flag may signal the scanner firmware to expect Nikon-extended
window descriptor fields beyond the standard SCSI scanner specification.

## Data Phase

**Direction:** Data-Out (host -> scanner)

### Window Parameter Data Structure

The data-out payload consists of a Window Parameter Header followed by one or more
Window Descriptors.

#### Window Parameter Header (8 bytes)

| Offset | Length | Field |
|--------|--------|-------|
| 0-5 | 6 | Reserved |
| 6-7 | 2 | Window Descriptor Length (big-endian) |

#### Window Descriptor (standard SCSI fields)

| Offset | Length | Field | Notes |
|--------|--------|-------|-------|
| 0 | 1 | Window Identifier | Usually 0x00 |
| 1 | 1 | Reserved | |
| 2-3 | 2 | X Resolution (dpi) | Big-endian |
| 4-5 | 2 | Y Resolution (dpi) | Big-endian |
| 6-9 | 4 | Upper Left X | Scan area start X (big-endian) |
| 10-13 | 4 | Upper Left Y | Scan area start Y (big-endian) |
| 14-17 | 4 | Width | Scan area width (big-endian) |
| 18-21 | 4 | Height | Scan area height (big-endian) |
| 22 | 1 | Brightness | |
| 23 | 1 | Threshold | |
| 24 | 1 | Contrast | |
| 25 | 1 | Image Composition | 0=BW, 2=grayscale, 5=RGB |
| 26 | 1 | Bits Per Pixel | 8, 14, 16 |
| 27-28 | 2 | Halftone Pattern | |
| 29 | 1 | Padding Type | |
| 30-31 | 2 | Bit Ordering | |
| 32 | 1 | Compression Type | |
| 33+ | varies | Vendor-specific extensions | Nikon-specific parameters |

#### Nikon Vendor Extensions

The Coolscan extends the standard window descriptor with vendor-specific fields. See [SET WINDOW Descriptor](set-window-descriptor.md) for the complete 80-byte descriptor layout including:
- Multi-sample scanning, infrared channel (Digital ICE), analog gain per channel
- Film type selection, focus position, scan speed / quality mode

## Usage Context

- **Required** before every SCAN command
- Sets all scan geometry and quality parameters
- Typical sequence:
  1. **`SET WINDOW`** — configure resolution, depth, area
  2. `SCAN` — start the scan
  3. `READ` — retrieve image data
- May be issued multiple times to reconfigure between preview and final scan
- GET WINDOW can verify the parameters were accepted

## Scanner Resolution Notes

The Coolscan V (LS-50) has a maximum optical resolution of 4000 dpi. Common resolutions:
- 4000 dpi — maximum optical, single-pass
- 2000 dpi — half resolution
- 1000 dpi — quarter resolution (often used for preview)
- Lower resolutions may be interpolated

## Firmware Handler (Phase 4)

**Handler address**: `FW:0x026E38` | **Size**: Large | **Exec mode**: 0x02 (data-out)

Receives window descriptor data from host. Parses standard SCSI window fields plus Nikon vendor extensions. The firmware uses the resolution field to calculate motor speed:
- Multiplier: 0x6C6 (1734) per resolution unit
- Formula: `(scan_resolution + 2) * 0x6C6`
- Result stored at `@0x400D8E`, `@0x400D9A`, `@0x400D9E`

## Source References

| Source | Location | Notes |
|--------|----------|-------|
| LS5000.md3 | `0x100aa650` | CDB builder — sets opcode 0x24, bytes 6-8 transfer length, byte9=0x80 |
| Firmware | `0x026E38` | Handler — window descriptor parser |

## Cross-References

- [GET WINDOW](get-window.md) — reads back the window parameters set by SET WINDOW
- [SCAN](scan.md) — must follow SET WINDOW to initiate scanning
- [READ](read.md) — retrieves scan data after scan completes
- [MODE SELECT](mode-select.md) — sets additional operating parameters
- [Firmware SCSI Handler](../components/firmware/scsi-handler.md) — Full dispatch table
- [Motor Control](../components/firmware/motor-control.md) — Motor speed depends on resolution
- [Driver Guide: Scan Data Transfer](../driver-guide/scan-data-transfer.md) — Vendor extension bytes 54-57 (per-channel exposure time)
- [SCSI Command Build Infrastructure](../components/ls5000-md3/scsi-command-build.md) — CDB builder vtable system
- [NKDUSCAN API](../components/nkduscan/api.md) — USB transport that sends this CDB
- [USB Protocol](../architecture/usb-protocol.md) — transport layer details
