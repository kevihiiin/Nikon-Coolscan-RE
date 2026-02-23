# VENDOR 0xC0 — Nikon Scanner Status Primitive

**Status**: Complete
**Last Updated**: 2026-02-21
**Phase**: 2 (SCSI Commands)
**Confidence**: Medium (CDB builder confirmed, but factory not found in standard architecture)

## Overview

Vendor-specific minimal command. The CDB builder produces an opcode-only command with no additional parameters. Likely used as a scanner status query or ping mechanism.

**Direction**: Unknown (factory not found in standard command object architecture — may use a different execution path)

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
- **0xC0**: Status query (direction unknown)
- **0xC1**: Control trigger (no data phase)

Both have minimal CDBs (opcode-only, no parameters).

## Open Questions

- What execution path is used for 0xC0? It has a CDB builder in Cluster 2 but no standard factory function was found.
- Does 0xC0 have a data-in phase (status response)? The lack of a factory makes this hard to determine from host-side analysis alone.
- Firmware-side analysis (Phase 4) should reveal the handler and response format.

## Cross-References

- [VENDOR 0xC1](vendor-c1.md) — Related control primitive
- [SCSI Command Catalog](../components/ls5000-md3/scsi-command-build.md) — Full command list
- [NkDriverEntry API](../components/nkduscan/api.md) — FC5 executes this command

Source: `LS5000.md3:0x100b52d0` (builder)
