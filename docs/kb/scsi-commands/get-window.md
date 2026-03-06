# GET WINDOW (0x25)

| Field | Value |
|-------|-------|
| **Status** | Complete |
| **Last Updated** | 2026-02-28 |
| **Phase** | 2 + 4 |
| **Confidence** | Verified (cross-validated host ↔ firmware) |

## Overview

Standard SCSI GET WINDOW command. Reads back the current scan window parameters from the
scanner. This is the read-side counterpart to SET WINDOW — the host uses it to verify that
the scanner accepted the requested scan parameters, or to read the scanner's default/current
window configuration.

The response data format mirrors the SET WINDOW data structure.

## CDB Layout (10 bytes)

| Byte | Field | Value | Notes |
|------|-------|-------|-------|
| 0 | Opcode | `0x25` | GET WINDOW |
| 1 | Reserved | `0x00` | |
| 2 | Reserved | `0x00` | |
| 3 | Reserved | `0x00` | |
| 4 | Reserved | `0x00` | |
| 5 | Reserved | `0x00` | |
| 6 | Transfer Length [MSB] | varies | Maximum data host can accept (big-endian) |
| 7 | Transfer Length | varies | |
| 8 | Transfer Length [LSB] | varies | |
| 9 | Control | `0x00` | |

### Transfer Length (Bytes 6-8)

24-bit big-endian allocation length. The host specifies the maximum number of bytes it
can accept. The scanner returns up to this many bytes of window parameter data.

## Data Phase

**Direction:** Data-In (scanner -> host)

The response format is identical to the SET WINDOW data-out structure:
- Window Parameter Header (8 bytes)
- Window Descriptor (variable length, includes Nikon vendor extensions)

See [SET WINDOW](set-window.md) for the detailed data structure layout.

## Usage Context

- Called after SET WINDOW to verify the scanner accepted the parameters
- The scanner may adjust requested parameters to supported values (e.g., rounding
  resolution to nearest supported value, clipping scan area to physical limits)
- Comparing GET WINDOW response to SET WINDOW request reveals any parameter adjustments
- May also be called standalone to read the scanner's default window configuration

## Firmware Handler (Phase 4)

**Handler address**: `FW:0x0272F6` | **Exec mode**: 0x03 (data-in) | **Perm flags**: 0x0254

The firmware handler reads the current window descriptor from internal state (built during SET WINDOW processing) and sends it back to the host. The relatively restrictive permission flags (0x0254) limit this command to specific scanner states.

The response includes both standard SCSI-2 Scanner window fields and Nikon vendor extension fields — the host uses this response during initialization (`LS5000.md3:0x100A2980`) to discover which vendor extensions the scanner supports and their data sizes. This is the key mechanism for the dynamic vendor extension discovery documented in [SET WINDOW Descriptor](set-window-descriptor.md).

### Sense Codes

| Sense Index | ASC/ASCQ | Condition |
|-------------|----------|-----------|
| 0x01 | 00/00 | No error (deferred+ILI — returned data may be truncated) |
| 0x04 | 37/00 | Rounded parameter (scanner adjusted a requested value) |
| 0x50 | 24/00 | Invalid field in CDB |

See [Sense Code Catalog](sense-codes.md) for full details.

## Source References

| Source | Location | Notes |
|--------|----------|-------|
| LS5000.md3 | `0x100aa610` | CDB builder — sets opcode 0x25, bytes 6-8 transfer length |

## Cross-References

- [SET WINDOW](set-window.md) — writes the window parameters that GET WINDOW reads back
- [SCAN](scan.md) — follows SET WINDOW / GET WINDOW in scan sequence
- [SCSI Command Build Infrastructure](../components/ls5000-md3/scsi-command-build.md) — CDB builder vtable system
- [NKDUSCAN API](../components/nkduscan/api.md) — USB transport that sends this CDB
- [USB Protocol](../architecture/usb-protocol.md) — transport layer details
