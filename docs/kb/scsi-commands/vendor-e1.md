# VENDOR 0xE1 — Nikon Sensor Read

**Status**: Complete
**Last Updated**: 2026-02-21
**Phase**: 2 (SCSI Commands)
**Confidence**: High (verified from CDB builder disassembly and factory analysis)

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

| Sub-cmd | Purpose | Notes |
|---------|---------|-------|
| TBD | Focus position read | Current focus motor position |
| TBD | Exposure reading | Per-channel exposure measurements |
| TBD | Sensor status | CCD/LED status readback |

Sub-command values require MAID capability tracing (Phase 2 ongoing) or firmware-side analysis (Phase 4).

### Transfer length (CDB[6:8])

24-bit big-endian value specifying the number of bytes expected in the data-in phase. The response payload contains sensor readings specific to the sub-command.

## Architecture

- **Factory**: `0x100aa500` — uses full constructor `fcn.100ae770` with direction push 1 (data-in)
- **CDB Builder**: `0x100aa6a0`
- **Vtable**: `0x100c4f74` (Group B — with retry on error 9)

## Relationship to 0xE0

0xE0 and 0xE1 are a matched pair:
- **0xE0** = write control data TO scanner (data-out)
- **0xE1** = read sensor data FROM scanner (data-in)

Both use the same CDB structure with sub-command differentiation at CDB[2].

## Cross-References

- [VENDOR 0xE0](vendor-e0.md) — Complementary control write command
- [SCSI Command Catalog](../components/ls5000-md3/scsi-command-build.md) — Full command list
- [NkDriverEntry API](../components/nkduscan/api.md) — FC5 executes this command

Source: `LS5000.md3:0x100aa6a0` (builder), `0x100aa500` (factory)
