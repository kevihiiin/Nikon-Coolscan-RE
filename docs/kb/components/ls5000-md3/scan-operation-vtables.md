# LS5000.md3 Scan Operation Vtable Architecture

**Status**: Complete
**Last Updated**: 2026-02-27
**Phase**: 3 (Scan Workflows)
**Confidence**: High (decompiled all 5 vtables, verified factory and handler functions)

## Overview

LS5000.md3 uses a vtable-based object hierarchy to implement different scan workflows. Each scan operation type inherits from a base class and overrides specific vtable entries to provide its SCSI command factory and step handler functions.

The vtable is stored at offset 0 of the scan operation object (1152+ bytes). The object is constructed at `FUN_100b29b0` (base) and then specialized by setting the vtable pointer to one of 5 type-specific vtables.

## Vtable Addresses

| Type | Vtable Address | Constructor | Description |
|------|---------------|-------------|-------------|
| Base | `0x100c526c` | `FUN_100b29b0` (120 bytes) | Init-only (used for simple initialization) |
| Type A | `0x100c5290` | `FUN_100b3b10` (44 bytes) | Init + Main Scan |
| Type B | `0x100c5320` | `FUN_100b3ff0` (49 bytes) | Simple Scan (preview, thumbnail) |
| Type C | `0x100c5368` | `FUN_100b45c0` (840 bytes) | Focus/Autofocus operations |
| Type D | `0x100c538c` | `FUN_100b4a40` (81 bytes) | Advanced operations (calibration, diagnostics) |

## Vtable Layout (Key Entries)

Each vtable has at least 18 entries (72 bytes). The critical entries for scan workflow:

| Entry | Offset | Purpose |
|-------|--------|---------|
| [0] | +0x00 | Destructor / cleanup |
| [1] | +0x04 | Add step to queue (`FUN_100b2a80`) |
| [2] | +0x08 | Insert step at position (`FUN_100b2ab0`) |
| [3] | +0x0C | Remove step by index (`FUN_100b2ae0`) |
| [4] | +0x10 | Get queue size (`FUN_100b2b20`) |
| [5] | +0x14 | Advance/consume current step (`FUN_100b2a40`) |
| [6] | +0x18 | Get status code (`FUN_100aec40`) |
| **[7]** | **+0x1C** | **Phase A Command Factory** — creates SCSI command objects |
| **[8]** | **+0x20** | **Phase A Step Handler** — processes results and advances state |
| [9]-[15] | +0x24-0x3C | Various overrides (scan-type-specific) |
| **[16]** | **+0x40** | **Phase B Command Factory** — creates SCSI commands for phase B |
| **[17]** | **+0x44** | **Phase B Step Handler** — processes phase B results |

### Phase Execution Pattern

Each scan operation has two phases (A and B). The sequencer:
1. Calls **Phase A factory** [7] to create SCSI command for current step
2. Executes the command via NkDriverEntry FC5
3. Calls **Phase A handler** [8] with the result status
4. Handler processes result, may insert new steps, advance, or signal completion
5. Repeats until Phase A is done
6. Then executes Phase B with entries [16] and [17] in the same pattern

## Per-Type Vtable Details

### Base Type (0x100c526c) — Init Only

| Entry | Address | Function |
|-------|---------|----------|
| [7] | `0x100AF1F0` | Init factory: TUR, INQUIRY, RESERVE, MODE_SELECT, SEND_DIAG, GET_WINDOW, READ10 |
| [8] | `0x100B3060` | Init handler (983 bytes) — processes INQUIRY results, GET_WINDOW data |
| [16] | `0x100AF1F0` | Same as [7] (init in both phases) |
| [17] | `0x100B3060` | Same as [8] |

### Type A (0x100c5290) — Init + Main Scan

| Entry | Address | Function |
|-------|---------|----------|
| [7] | `0x100AF1F0` | Phase A = Init factory (same as Base) |
| [8] | `0x100B3060` | Phase A = Init handler (same as Base) |
| [16] | `0x100B3B90` | **Phase B = Main Scan factory** (368 bytes) |
| [17] | `0x100AFD00` | **Phase B = Main Scan handler** (314 bytes) |

Type A Phase B factory (`FUN_100b3b90`) handles step codes:
- **0x00**: TUR — creates `FUN_100aa2a0` (Test Unit Ready command)
- **0x1D**: SEND DIAGNOSTIC — creates `FUN_100aa370`
- **0x24**: SET WINDOW — calls `FUN_100b3a50` (param builder) then `FUN_100aa400`

### Type B (0x100c5320) — Simple Scan

| Entry | Address | Function |
|-------|---------|----------|
| [7] | `0x100B4040` | Phase A = SET WINDOW only (194 bytes) |
| [8] | `0x100AFF70` | Phase A handler (182 bytes) |
| [16] | `0x100B41A0` | **Phase B = Full scan factory** (898 bytes) |
| [17] | `0x100B36E0` | **Phase B = Full scan handler** (724 bytes) |

Type B Phase B factory (`FUN_100b41a0`) handles all scan step codes:
- **0x00**: TUR → `FUN_100aa2a0`
- **0x1B**: SCAN → allocates 0x28-byte descriptor via `FUN_100aefe0`
- **0x1D**: SEND DIAGNOSTIC → `FUN_100aa370`
- **0x24**: SET WINDOW → `FUN_100b3a50` + `FUN_100aa400`
- **0x25**: GET WINDOW → `FUN_100aa3b0` (with ICE/DRAG extension size)
- **0x28**: READ(10) → `FUN_100b5000` (sub-code 0x87 = scan data transfer)
- **0x2A**: WRITE(10) → `FUN_100b50c0` (LUT/correction data)

### Type C (0x100c5368) — Focus/Autofocus

| Entry | Address | Function |
|-------|---------|----------|
| [7] | `0x100B0380` | Focus factory (617 bytes) |
| [8] | `0x100B06F0` | Focus handler (1304 bytes) |
| [16] | `0x100B0C20` | Advanced focus factory (1021 bytes) |
| [17] | `0x100B1170` | Focus phase 2 handler (1376 bytes) |

Type C Phase A factory (`FUN_100b0380`) handles:
- **0x00**: TUR
- **0x1D**: SEND DIAGNOSTIC
- **0xC1**: Vendor C1 (trigger/execute)
- **0xE0**: Vendor E0 (write focus/exposure parameters)
- **0xE1**: Vendor E1 (read focus/exposure results)

The focus handler uses `timeGetTime()` for 5-second timeout and processes E1 vendor response data:
- Sub-command 0x42: Focus position → stored at object+0x468
- Sub-command 0xC0: Exposure value → stored at object+0x460

### Type D (0x100c538c) — Advanced Operations

| Entry | Address | Function |
|-------|---------|----------|
| [7] | `0x100B0C20` | Advanced focus factory (shared with Type C [16]) |
| [8] | `0x100B1170` | Focus phase 2 handler (shared with Type C [17]) |
| [16] | `0x100B17E0` | Advanced ops factory (546 bytes) |
| [17] | `0x100B1A90` | Advanced ops handler (663 bytes) |

Type D Phase B factory (`FUN_100b17e0`) handles:
- **0x00**: TUR
- **0x12**: INQUIRY (with special handling: checks `FUN_100a03d0` for readiness)
- **0x1D**: SEND DIAGNOSTIC
- **0x28**: READ(10) (sub-code 0x88 = calibration data transfer)

## Step Queue Architecture

Each scan operation has a step queue at object+0x438 (initialized with capacity 10). Steps are 16-byte descriptors:

```c
struct ScanStep {
    uint32_t step_code;    // +0x00: SCSI opcode (0x00=TUR, 0x12=INQUIRY, 0x24=SET_WINDOW, etc.)
    uint32_t sub_code;     // +0x04: Sub-command or parameter type
    uint32_t param;        // +0x08: Additional parameter
    uint32_t param2;       // +0x0C: Second parameter
};
```

Step queue helpers:
- `FUN_100aec50(this, index, &val)` — get step_code at index
- `FUN_100aec80(this, index, &val)` — get sub_code at index
- `FUN_100aecb0(this, index, &val)` — get param at index
- `FUN_100aece0(this, index, &val)` — get param2 at index
- `FUN_100aed10(this, index, val)` — set step_code at index
- `FUN_100aed40(this, index, val)` — set sub_code at index
- `FUN_100aed70(this, index, val)` — set param at index

Steps can be dynamically inserted during handler execution. For example, the init handler (`FUN_100b3060`) inserts a SEND_DIAG step after processing TUR results:
```c
FUN_100aed10(this, 0, 0x1d);  // set step_code = SEND_DIAG
FUN_100aed40(this, 0, 0);      // set sub_code = 0
FUN_100aed70(this, 0, 4);      // set param = 4
```

## Scan Type Codes

The scan type code (stored at object+0x450) determines the specific operation:

| Code | Vtable | Operation |
|------|--------|-----------|
| 0x40 | Type C | Preview scan (basic) |
| 0x41 | Type C | Preview with processing |
| 0x42 | Type C | Focus check |
| 0x43-0x45 | Type C | Other preview variants |
| 0x80 | Type C | Focus with auto-exposure (sets [+0x44e]=1) |
| 0x81 | Type C | Focus type 2 |
| 0x90 | Type C | Autofocus coarse |
| 0x91 | Type C | Autofocus fine |
| 0xa0 | Type C | Area exposure measurement |
| 0xa1 | Type C | Area focus |
| 0xb0-0xb4 | Type C | Calibration scans |
| 0xc0-0xc1 | Type C | Vendor command operations |
| 0xd0 | Type C | Main scan (copies 0x76 dwords from param+0x88) |
| 0xd1-0xd3 | Type C | Main scan variants |
| 0xd5-0xd6 | Type C | Main scan with extras |
| 0x800 | Type C | Custom (type from param_1+0x34) |

Source: `FUN_100b45c0` at `LS5000.md3:0x100B45C0`

## Scan Object Memory Layout

| Offset | Size | Field |
|--------|------|-------|
| +0x000 | 4 | Vtable pointer |
| +0x008 | 0x400 | Data buffer (SCSI response data stored here) |
| +0x408 | 4 | Transfer size |
| +0x40C | 4 | NkDriverEntry function code (from param_1+4) |
| +0x410 | 4 | Transport param 1 (from param_2+0x70) |
| +0x414 | 4 | Transport param 2 (from param_2+0x74) |
| +0x418 | 4 | Scan config param 1 (from param_1+0x14) |
| +0x41C | 4 | Scan config param 2 (from param_1+0x1c) |
| +0x420 | 4 | Scan config param 3 (from param_1+0x24) |
| +0x424 | 4 | Scan mode flag (from param_1+0x18, non-zero = scan active) |
| +0x42C | 4 | Scanner state object pointer (param_2) |
| +0x430 | 4 | Override parameter source (param_3, may be NULL) |
| +0x438 | 20 | Step queue header (linked list) |
| +0x440 | 4 | Step queue status |
| +0x44C | 2 | Multi-sample type code (for SET WINDOW byte 50) |
| +0x44D | 1 | Main scan flag (set for type 0xd0 special case) |
| +0x44E | 1 | Auto-exposure flag (set for type 0x80) |
| +0x44F | 1 | Focus retry flag |
| +0x450 | 2 | Scan type code (0x40-0xd6) |
| +0x454 | 4 | Reserved |
| +0x458 | 4 | Scan config pointer |
| +0x45C | 28 | Status/result block |
| +0x460 | 4 | E1 vendor response: exposure value (sub-cmd 0xC0) |
| +0x468 | 4 | E1 vendor response: focus position (sub-cmd 0x42) |
| +0x484 | 4 | Step queue misc state |
| +0x488 | 2 | Current vendor sub-command |

## Related KB Docs

- [SCSI Command Catalog](scsi-command-build.md) — All 17 SCSI opcodes and their factories
- [SET WINDOW Descriptor](../../scsi-commands/set-window-descriptor.md) — Byte-level parameter mapping
- [Scan Workflows](../nikonscan4-ds/scan-workflows.md) — NikonScan4.ds orchestration
- [MAID Entry Point](maid-entrypoint.md) — MAIDEntryPoint dispatch and transport
