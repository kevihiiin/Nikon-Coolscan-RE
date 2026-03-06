# VENDOR 0xE1 — Nikon Sensor Read

**Status**: Complete
**Last Updated**: 2026-02-28
**Phase**: 2 + 4
**Confidence**: Verified (cross-validated host ↔ firmware)

## Overview

Vendor-specific command for reading sensor data and status information from the scanner. This is the complementary read command to 0xE0, used for reading focus position, exposure readings, and other scanner-specific sensor data.

**Direction**: Data-in (scanner sends sensor/status data to host)

## CDB Layout (10 bytes)

```
Byte 0: 0xE1 (opcode)
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

The sub-command at byte 2 differentiates what sensor data is being read. Known sub-commands (from NikonScan MAID capability handlers):

| Sub-cmd | Purpose | Max Payload | Notes |
|---------|---------|-------------|-------|
| 0x44 | Motor position | 5 bytes | Current motor position readback |
| 0x45 | Exposure time | 11 bytes | Current exposure readings |
| 0x46 | Focus position | 11 bytes | Current focus position readback |
| 0x47 | Lamp settings | 11 bytes | Current lamp status |
| 0xA0 | CCD setup | 9 bytes | CCD sensor configuration readback |

Full 23-entry register table (same IDs as E0) in [Vendor E0 Firmware Handler](vendor-e0.md#firmware-handler-phase-4).

### Transfer length (CDB[6:8])

24-bit big-endian value specifying the number of bytes expected in the data-in phase. The response payload contains sensor readings specific to the sub-command.

## Architecture

- **Factory**: `0x100aa500` — uses full constructor `fcn.100ae770` with direction push 1 (data-in)
- **CDB Builder**: `0x100aa6a0`
- **Vtable**: `0x100c4f74` (Group B — with retry on error 9)

## Firmware Handler (Phase 4)

**Handler address**: `FW:0x0295EA` | **Size**: ~430 bytes | **Exec mode**: 0x03 (data-in)

Mirror of E0 handler. Uses the same vendor register table at `FW:0x4A134` for sub-command lookup. Reads register data and sends to host via USB response manager (`jsr @0x01374A` then `@0x014090`).

## Relationship to E0 and C1

0xE0, C1, and E1 form a three-command operational cycle:
1. **0xE0** = write control data TO scanner (sets register values)
2. **0xC1** = trigger the operation
3. **0xE1** = read sensor data FROM scanner (reads results)

Both E0 and E1 use the same CDB structure with sub-command differentiation at CDB[2], and the same register table at `FW:0x4A134`.

## Cross-References

- [VENDOR 0xE0](vendor-e0.md) — Complementary control write command (with complete register table)
- [VENDOR 0xC1](vendor-c1.md) — Trigger command (completes the E0→C1→E1 cycle)
- [Firmware SCSI Handler](../components/firmware/scsi-handler.md) — Register table and dispatch details
- [SCSI Command Catalog](../components/ls5000-md3/scsi-command-build.md) — Full command list
- [NkDriverEntry API](../components/nkduscan/api.md) — FC5 executes this command

Source: `LS5000.md3:0x100aa6a0` (builder), `0x100aa500` (factory), `FW:0x0295EA` (handler)
