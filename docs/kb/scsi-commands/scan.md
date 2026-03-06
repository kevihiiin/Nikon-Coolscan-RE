# SCAN (0x1B)

| Field | Value |
|-------|-------|
| **Status** | Complete |
| **Last Updated** | 2026-02-28 |
| **Phase** | 2 + 4 |
| **Confidence** | Verified (cross-validated host ↔ firmware) |

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

## Firmware Handler (Phase 4)

**Handler address**: `FW:0x0220B8` | **Size**: ~1800 bytes | **Exec mode**: 0x00 (direct)

The most complex standard SCSI handler. Supports 6 operation types via a scan descriptor built at er6 (stack-relative):

### Scan Operation Types

| Code (er6[0]) | Operation | Description |
|----------------|-----------|-------------|
| 0 | Preview scan | Quick low-resolution preview |
| 1 | Fine scan (single pass) | Full-resolution single exposure |
| 2 | Fine scan (multi-pass) | Multi-sample averaging scan |
| 3 | Calibration scan | CCD/LED calibration |
| 4 | Move to position | Motor positioning only (no CCD) |
| 9 | Eject film | Film transport to eject position |

### CDB Validation (Firmware)

- CDB bytes 2-5 must be zero
- `CDB[0x4007BA]` (exec_mode byte) must be ≤ 4
- Invalid operation code → sense 0x0053 (Invalid Parameter)

### Scan Execution Flow

1. Calls USB response manager `0x1374A` with exec mode 2
2. Calls data transfer setup `0x13E20`
3. Validates operation code against max allowed for current adapter
4. Sets scan state variables:
   - `0x400D43`: scan operation active flag
   - `0x400E7A`: scan operation state
   - `0x400D3C`: max operations for current adapter
5. Triggers motor control via internal task dispatch (04xx task codes)

### Motor Integration

The SCAN handler interfaces with the motor subsystem (documented in [Motor Control](../components/firmware/motor-control.md)):
- Operation 4 (move) dispatches motor task 0x0440 (relative move)
- Operation 9 (eject) dispatches motor task 0x0430 (home)
- Scan operations configure motor speed based on resolution (ramp tables at `FW:0x16C38`)

## Source References

| Source | Location | Notes |
|--------|----------|-------|
| LS5000.md3 | `0x100aa6d0` | CDB builder — sets opcode 0x1B, byte4=transfer_length |
| LS5000.md3 | `0x100aa540` | Factory — full constructor, direction=data-out (push 2) |
| Firmware | `0x0220B8` | Handler — 6 operation types, ~1800 bytes |
| Firmware | `0x400D43` | Scan operation active flag (RAM) |

## Cross-References

- [SET WINDOW](set-window.md) — configures scan parameters before SCAN is issued
- [READ](read.md) — retrieves scan data after SCAN completes
- [MODE SELECT](mode-select.md) — sets operating modes before scanning
- [Motor Control](../components/firmware/motor-control.md) — Motor subsystem triggered by SCAN
- [Firmware SCSI Handler](../components/firmware/scsi-handler.md) — Full dispatch table
- [SCSI Command Build Infrastructure](../components/ls5000-md3/scsi-command-build.md) — CDB builder vtable system
- [NKDUSCAN API](../components/nkduscan/api.md) — USB transport that sends this CDB
- [USB Protocol](../architecture/usb-protocol.md) — transport layer details
