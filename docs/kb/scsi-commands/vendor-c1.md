# VENDOR 0xC1 — Nikon Scanner Control Primitive

**Status**: Complete
**Last Updated**: 2026-02-21
**Phase**: 2 (SCSI Commands)
**Confidence**: High (verified from factory and CDB builder disassembly)

## Overview

Vendor-specific minimal command used as a scanner control trigger. No data phase — this is a fire-and-forget control primitive. Likely used for simple scanner state changes that don't require parameter data.

**Direction**: None (confirmed: uses simple constructor `fcn.100ae720` without direction parameter)

## CDB Layout (6 bytes)

```
Byte 0: 0xC1 (opcode)
Bytes 1-5: 0x00
```

## Key Fields

This is a minimal command — only the opcode byte is set. No parameters, no sub-commands, no data phase.

## Architecture

- **Factory**: `0x100aa580` — uses simple constructor `fcn.100ae720` (3 params, no direction = no data phase)
- **CDB Builder**: `0x100aa5b0` — minimal builder, sets only byte[0]=0xC1, returns 6
- **Vtable**: `0x100c4fc4` (Group B — with retry on error 9)

## Relationship to 0xC0

0xC0 and 0xC1 appear to be a related pair of minimal scanner primitives:
- **0xC0**: Status query (direction unknown, factory not found)
- **0xC1**: Control trigger (no data phase, confirmed)

Both have minimal CDBs (opcode-only, no parameters).

## Cross-References

- [VENDOR 0xC0](vendor-c0.md) — Related status primitive
- [SCSI Command Catalog](../components/ls5000-md3/scsi-command-build.md) — Full command list
- [NkDriverEntry API](../components/nkduscan/api.md) — FC5 executes this command

Source: `LS5000.md3:0x100aa5b0` (builder), `0x100aa580` (factory)
