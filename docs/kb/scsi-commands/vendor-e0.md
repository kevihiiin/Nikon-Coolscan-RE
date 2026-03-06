# VENDOR 0xE0 — Nikon Control Write

**Status**: Complete
**Last Updated**: 2026-02-28
**Phase**: 2 + 4
**Confidence**: Verified (cross-validated host ↔ firmware)

## Overview

Vendor-specific command for sending control parameters to the scanner. This is the primary mechanism for focus control, exposure adjustment, and other scanner-specific operations that don't fit into standard SCSI mode pages.

**Direction**: Data-out (host sends control data to scanner)

## CDB Layout (10 bytes)

```
Byte 0: 0xE0 (opcode)
Byte 1: 0x00 (reserved)
Byte 2: Sub-command code (from [obj+0x64])
Byte 3: 0x00
Byte 4: 0x00
Byte 5: 0x00
Byte 6: Transfer length MSB (from [obj+0x50] >> 16)
Byte 7: Transfer length mid (from [obj+0x50] >> 8)
Byte 8: Transfer length LSB (from [obj+0x50])
Byte 9: 0x00 (control)
```

## Key Fields

### Sub-command byte (CDB[2])

The sub-command at byte 2 differentiates what control operation is being performed. Known sub-commands (from NikonScan MAID capability handlers):

| Sub-cmd | Purpose | Max Payload | Notes |
|---------|---------|-------------|-------|
| 0x44 | Motor position | 5 bytes | Focus motor target position |
| 0x45 | Exposure time | 11 bytes | Per-channel exposure time |
| 0x46 | Focus position | 11 bytes | Focus position set |
| 0x47 | Lamp settings | 11 bytes | Lamp intensity / timing |
| 0x80 | Lamp on/off | 0 (trigger) | No payload, immediate action |

Full 23-entry register table with all sub-commands in [Firmware Handler](#firmware-handler-phase-4) section below.

### Transfer length (CDB[6:8])

24-bit big-endian value specifying the number of bytes in the data-out phase. The data payload contains the control parameters specific to the sub-command.

## Architecture

- **Factory**: `0x100aa4c0` — uses full constructor `fcn.100ae770` with direction push 2 (data-out)
- **CDB Builder**: `0x100aa670`
- **Vtable**: `0x100c4f4c` (Group B — with retry on error 9)

## Firmware Handler (Phase 4)

**Handler address**: `FW:0x028E16` | **Size**: ~480 bytes | **Exec mode**: 0x02 (data-out)

### Register Lookup

CDB[2] (sub-command) is matched against the vendor register table at `FW:0x4A134` (23 entries, format `[reg_id:8, max_data_len:8]`):

| Sub-cmd | Max Data Len | Purpose |
|---------|-------------|---------|
| 0x40 | 11 | Scan parameters |
| 0x41 | 11 | Calibration data |
| 0x42 | 11 | Gain values |
| 0x43 | 11 | Offset values |
| 0x44 | 5 | Motor position |
| 0x45 | 11 | Exposure time |
| 0x46 | 11 | Focus position |
| 0x47 | 11 | Lamp settings |
| 0x80 | 0 | Lamp on/off (trigger only, no payload) |
| 0x81 | 0 | Motor init (trigger only) |
| 0x91 | 5 | Motor step (direction + count) |
| 0xA0 | 9 | CCD setup |
| 0xB0 | 0 | State change (trigger only) |
| 0xB1 | 0 | State change (trigger only) |
| 0xB3 | 13 | Config write |
| 0xB4 | 9 | Extended config |
| 0xC0 | 5 | Gain calibration |
| 0xC1 | 5 | Offset calibration |
| 0xD0 | 0 | Diagnostic (trigger only) |
| 0xD1 | 0 | Diagnostic (trigger only) |
| 0xD2 | 5 | Diagnostic data |
| 0xD5 | 5 | Extended diagnostic |
| 0xD6 | 5 | Persistent settings |

### Data Address Calculation

From received data bytes:
- Bytes [1-4]: 32-bit register address (`byte[1]<<24 + byte[2]<<16 + byte[3]<<8 + byte[4]`)
- Bytes [5-8]: 32-bit data length
- Bytes [9-10]: Additional parameters

### Resolution Calculation

For scan-related sub-commands (0x40-0x47):
- Multiplier: 0x6C6 (1734) per resolution unit
- Formula: `(scan_resolution + 2) * 0x6C6`
- Stored at: `@0x400D8E`, `@0x400D9A`, `@0x400D9E`

## Relationship to C1 and E1

0xE0, C1, and E1 form a three-command operational cycle:
1. **0xE0** = write control data TO scanner (sets register values)
2. **0xC1** = trigger the operation (uses same sub-command code from `@0x400D63`)
3. **0xE1** = read sensor data FROM scanner (reads results)

## Cross-References

- [VENDOR 0xE1](vendor-e1.md) — Complementary sensor read command
- [VENDOR 0xC1](vendor-c1.md) — Trigger command (completes the E0→C1→E1 cycle)
- [Firmware SCSI Handler](../components/firmware/scsi-handler.md) — Register table and dispatch details
- [SCSI Command Catalog](../components/ls5000-md3/scsi-command-build.md) — Full command list
- [NkDriverEntry API](../components/nkduscan/api.md) — FC5 executes this command

Source: `LS5000.md3:0x100aa670` (builder), `0x100aa4c0` (factory), `FW:0x028E16` (handler)
