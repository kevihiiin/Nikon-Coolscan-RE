# VENDOR 0xC0 — Nikon Scanner Status Primitive

**Status**: Complete
**Last Updated**: 2026-02-28
**Phase**: 2 + 4
**Confidence**: Verified (cross-validated host ↔ firmware)

## Overview

Vendor-specific minimal command. The CDB builder produces an opcode-only command with no additional parameters. Likely used as a scanner status query or ping mechanism.

**Direction**: None (confirmed from firmware exec mode 0x01 — status-only, no data transfer)

## CDB Layout (6 bytes)

```
Byte 0: 0xC0 (opcode)
Bytes 1-5: 0x00
```

## Key Fields

This is a minimal command — only the opcode byte is set. No parameters, no sub-commands.

## Architecture

- **Factory**: Not found in standard command factory architecture. 0xC0 may be executed through a different code path than the vtable-based command objects.
- **CDB Builder**: `0x100b52d0` — minimal builder, sets only byte[0]=0xC0, returns 6
- **Vtable**: Located in Cluster 2 range (0x100c5490-0x100c5570)

## Relationship to 0xC1

0xC0 and 0xC1 appear to be a related pair of minimal scanner primitives:
- **0xC0**: Status query (no data phase — confirmed from firmware)
- **0xC1**: Control trigger (no data phase)

Both have minimal CDBs (opcode-only, no parameters).

## Firmware Handler (Phase 4)

**Handler address**: `FW:0x028AB4` | **Size**: ~80 bytes | **Exec mode**: 0x01 (USB state setup)

The simplest handler. Checks abort/completion state:

1. Validates CDB bytes 2-5 are zero
2. Checks abort flag at `@0x400776` bit 6
3. If set: sets bit 7 (response pending), clears transfer count `@0x4007B2`
4. Returns status only — **no data transfer** (confirmed)

**Direction**: None (confirmed from firmware exec mode 0x01 and handler logic). The handler does not call the USB response manager or data transfer functions.

## Open Questions (RESOLVED)

- ~~What execution path is used for 0xC0?~~ **Exec mode 0x01** — calls USB state setup `0x1374A` before handler.
- ~~Does 0xC0 have a data-in phase?~~ **No** — confirmed from firmware. Status-only response.
- ~~Factory not found in standard architecture?~~ The host-side factory absence is explained: 0xC0 is likely called via a specialized code path (possibly the abort mechanism) rather than the standard command factory architecture.

## Cross-References

- [VENDOR 0xC1](vendor-c1.md) — Related control primitive
- [Firmware SCSI Handler](../components/firmware/scsi-handler.md) — Full dispatch table
- [SCSI Command Catalog](../components/ls5000-md3/scsi-command-build.md) — Full command list
- [NkDriverEntry API](../components/nkduscan/api.md) — FC5 executes this command
- [Driver Guide: Scan Data Transfer](../driver-guide/scan-data-transfer.md) — Complete abort sequence (C0 → TUR poll → USB clear)

Source: `LS5000.md3:0x100b52d0` (builder), `FW:0x028AB4` (handler)
