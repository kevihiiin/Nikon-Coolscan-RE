# SCAN (0x1B)

| Field | Value |
|-------|-------|
| **Status** | Complete |
| **Last Updated** | 2026-02-21 |
| **Phase** | 2 |
| **Confidence** | High |

## Overview

Standard SCSI SCAN command. Initiates a scanning operation on the scanner. Once this
command is sent, the scanner begins physically scanning the film according to the
parameters previously configured via SET WINDOW and MODE SELECT.

After SCAN completes, the host retrieves the scanned image data using READ commands.

**Note:** The SCSI specification defines opcode 0x1B as both SCAN (for scanner devices)
and START STOP UNIT (for disk devices). For the Coolscan, this is SCAN.

## CDB Layout (6 bytes)

| Byte | Field | Value | Notes |
|------|-------|-------|-------|
| 0 | Opcode | `0x1B` | SCAN |
| 1 | Reserved | `0x00` | |
| 2 | Reserved | `0x00` | |
| 3 | Reserved | `0x00` | |
| 4 | Transfer Length | varies | Meaning depends on scanner implementation |
| 5 | Control | `0x00` | |

### Transfer Length (Byte 4)

The transfer length field in byte 4 may indicate:
- Number of scan passes
- Scan operation sub-type (preview vs. final scan)
- Window identifier

Further analysis of the callers is needed to determine the exact semantics.

## Data Phase

**Direction:** Data-Out (host → scanner)

The SCAN command sends a window identifier list to the scanner specifying which scan
windows to activate. The transfer length in byte 4 indicates the size of this data.
This was verified from the factory function at `0x100aa540` which uses the full
constructor with direction push 2 (data-out).

After the SCAN command completes, the actual scan image data is retrieved via subsequent
READ commands.

## Usage Context

- Called after scan parameters are fully configured
- Typical scan sequence:
  1. `SET WINDOW` — configure resolution, bit depth, scan area
  2. `MODE SELECT` — set operating parameters
  3. **`SCAN`** — initiate the physical scan
  4. `READ` — retrieve scanned image data (possibly multiple reads)
- The scanner hardware begins moving the film carrier, activating the lamp, and reading
  the CCD sensor line by line

## Scanner Behavior

After receiving SCAN, the scanner:
1. Moves the film carrier to the starting position
2. Turns on the LED/lamp
3. Begins CCD line-by-line acquisition
4. Stores data in internal buffer (ASIC RAM at 0x800000)
5. Signals readiness for READ commands

The host must poll for completion or wait for the scanner to signal data availability
before issuing READ commands.

## Source References

| Source | Location | Notes |
|--------|----------|-------|
| LS5000.md3 | `0x100aa6d0` | CDB builder — sets opcode 0x1B, byte4=transfer_length |
| LS5000.md3 | `0x100aa540` | Factory — full constructor, direction=data-out (push 2) |

## Cross-References

- [SET WINDOW](set-window.md) — configures scan parameters before SCAN is issued
- [READ](read.md) — retrieves scan data after SCAN completes
- [MODE SELECT](mode-select.md) — sets operating modes before scanning
- [SCSI Command Build Infrastructure](../components/ls5000-md3/scsi-command-build.md) — CDB builder vtable system
- [NKDUSCAN API](../components/nkduscan/api.md) — USB transport that sends this CDB
- [USB Protocol](../architecture/usb-protocol.md) — transport layer details
