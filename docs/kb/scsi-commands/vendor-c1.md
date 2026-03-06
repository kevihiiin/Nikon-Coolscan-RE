# VENDOR 0xC1 — Nikon Scanner Control Primitive

**Status**: Complete
**Last Updated**: 2026-02-28
**Phase**: 2 + 4
**Confidence**: Verified (cross-validated host ↔ firmware)

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
- **0xC0**: Status query (no data phase — confirmed from firmware)
- **0xC1**: Control trigger (no data phase, confirmed)

Both have minimal CDBs (opcode-only, no parameters).

## Firmware Handler (Phase 4)

**Handler address**: `FW:0x028B08` | **Size**: ~730 bytes | **Exec mode**: 0x01 (USB state setup)

Reads subcommand code from `@0x400D63` and dispatches to one of 23 different operations:

### Subcommand Dispatch Table

| Code | Group | Purpose |
|------|-------|---------|
| 0x40-0x43 | Scan/Calibration | Execute scan operation variant |
| 0x44 | Motor | Move to position |
| 0x45-0x47 | Scan/Calibration | Execute calibration variant |
| 0x80 | Control | Lamp on/off control |
| 0x81 | Control | Motor initialization |
| 0x91 | Motor | Step motor command |
| 0xA0 | Sensor | CCD/sensor setup |
| 0xB0-0xB1 | Control | State change |
| 0xB3 | Config | Write configuration data |
| 0xB4 | Config | Write extended config |
| 0xC0-0xC1 | Calibration | Gain/offset calibration |
| 0xD0-0xD2 | Debug | Diagnostic operations |
| 0xD5 | Debug | Extended diagnostic |
| 0xD6 | Config | Write persistent settings |

These subcodes match exactly with the vendor register table at `FW:0x4A134` and the Phase 2 E0/E1 operation identifiers. The E0→C1→E1 flow is: E0 writes register data → C1 triggers operation → E1 reads results.

## Cross-References

- [VENDOR 0xC0](vendor-c0.md) — Related status primitive
- [VENDOR 0xE0](vendor-e0.md) — Data-out counterpart (writes register data before C1 trigger)
- [VENDOR 0xE1](vendor-e1.md) — Data-in counterpart (reads results after C1 trigger)
- [Firmware SCSI Handler](../components/firmware/scsi-handler.md) — Full dispatch table and register table
- [SCSI Command Catalog](../components/ls5000-md3/scsi-command-build.md) — Full command list
- [NkDriverEntry API](../components/nkduscan/api.md) — FC5 executes this command

Source: `LS5000.md3:0x100aa5b0` (builder), `0x100aa580` (factory), `FW:0x028B08` (handler)
