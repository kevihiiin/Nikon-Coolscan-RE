# Firmware Film Adapters & Factory Test Jig

**Status**: Complete
**Last Updated**: 2026-03-06
**Phase**: 4 (Firmware)
**Confidence**: High (string table and VPD table verified from binary; test jig behavior inferred)

## Overview

The LS-50 firmware supports 8 film adapter types (indices 0-7), detected automatically via GPIO Port 7 when inserted. Each adapter reports a unique electrical ID to the scanner, which determines available scan area, film positioning, and which VPD (Vital Product Data) pages are reported to the host.

Adapter type 7 ("Test") is a **factory manufacturing test jig** — not a consumer product. It is recognized by the firmware but has no VPD pages or special host-visible behavior.

## Adapter Type Table

The adapter name strings are at flash `0x49E30`-`0x49E77`, referenced by the pointer table at `0x49EFC`:

| Index | Name | String Addr | VPD Pages | Consumer Product |
|-------|------|-------------|-----------|-----------------|
| 0 | (none) | — | 0xF8, 0xFA, 0xFB, 0xFC | No adapter inserted (bare mount) |
| 1 | Mount | `0x49E4D` | 0x46 | SA-21 Slide Mount Adapter |
| 2 | Strip | `0x49E53` | 0x43, 0x44, 0xE2 | SF-210 Strip Film Adapter |
| 3 | 240 | `0x49E59` | 0x45, 0xF1 | IA-20(s) APS/IX240 Adapter |
| 4 | Feeder | `0x49E5D` | 0x46, 0xE2 | SA-30 Roll Film Adapter |
| 5 | 6Strip | `0x49E64` | 0x47, 0xE2 | SF-210 in 6-strip mode |
| 6 | 36Strip | `0x49E6B` | 0x10 | SF-210 in 36-exposure mode |
| 7 | Test | `0x49E73` | (none) | **Factory test jig** |

### Adapter Detection

The firmware reads GPIO Port 7 (`0xFFFF8E` / short address `0xFF8E`) to determine the currently inserted adapter. This port is read 16 times in the firmware, with 14 of those reads occurring inside the SCAN handler (`FW:0x0220B8`). The Port 7 value maps to an adapter index through a lookup that determines the adapter_type variable.

### VPD Page Dispatch

The adapter-specific VPD table at `FW:0x49C74` contains 5 entries per adapter type (6 bytes each: `page_code:8, field:8, handler:32`). The INQUIRY handler (`FW:0x025E18`) indexes this table by `adapter_type * 30` to find which VPD pages are available.

| VPD Page | Shared Handler | Adapter Types |
|----------|---------------|---------------|
| 0x10 | `0x026178` | 36Strip |
| 0x43 | `0x026178` | Strip |
| 0x44 | `0x026178` | Strip |
| 0x45 | `0x026178` | 240 |
| 0x46 | `0x026178` | Mount, Feeder |
| 0x47 | `0x026178` | 6Strip |
| 0xE2 | `0x026CC6` | Strip, Feeder, 6Strip |
| 0xF1 | `0x026C1C` | 240 |
| 0xF8 | `0x026C70` | none (bare mount) |
| 0xFA | `0x026D86` | none (bare mount) |
| 0xFB | `0x026DD6` | none (bare mount) |
| 0xFC | `0x026DAA` | none (bare mount) |

Most adapter pages share the generic handler at `0x026178`. The "no adapter" state has 4 unique handlers (0xF8, 0xFA, 0xFB, 0xFC) that likely report scanner base capabilities.

## Factory Test Jig (Adapter Type 7)

The "Test" adapter at index 7 has **zero VPD page entries** in the dispatch table. This means:

1. It is detected by GPIO Port 7 like any other adapter
2. The firmware recognizes it and sets `adapter_type = 7`
3. No adapter-specific VPD pages are reported to the host via INQUIRY
4. Scan operations can still be performed (the scan state machine handles adapter type 7)

This is consistent with a **factory test fixture** — a hardware jig that plugs into the film adapter slot during manufacturing. It allows running motor, calibration, CCD, and scan diagnostics without actual film. The lack of VPD pages means the host software (NikonScan) would not recognize it as a valid adapter, but factory diagnostic tools would use low-level SCSI commands directly.

### Pointer Table Anomaly

The pointer table at `0x49EFC` has the adapter names in a non-sequential order:

```
[0] 6Strip   [4] 36Strip   [7] Mount (dup)
[1] 240      [5] Mount
[2] Feeder   [6] Test
[3] 6Strip (dup)
```

Indices 3 and 7 are duplicates (6Strip and Mount respectively). This ordering likely corresponds to the GPIO Port 7 electrical ID encoding, not the logical adapter index used elsewhere in the firmware.

## Film Holder Types

Three film holder strings appear in the string table at `0x49E78`-`0x49E88`:

| Name | Address | Product | Purpose |
|------|---------|---------|---------|
| FH-3 | `0x49E78` | Nikon FH-3 | Standard film holder for 35mm strips |
| FH-G1 | `0x49E7D` | Nikon FH-G1 | Glass film holder for curled/warped film |
| FH-A1 | `0x49E83` | Nikon FH-A1 | Medical/special slide adapter |

These strings are returned in adapter-specific VPD pages to identify the film holder variant. The film holder sits inside the adapter (e.g., FH-3 goes into the SF-210 strip adapter). Different holders may affect scan area geometry or focus behavior.

## Mechanical Positioning Objects

The string table at `0x49E89`-`0x49EDB` contains positioning reference names used by the motor control and calibration subsystems:

| Name | Address | Purpose |
|------|---------|---------|
| SCAN Motor | `0x49E89` | Main carriage stepper motor |
| AF Motor | `0x49E94` | Autofocus stepper motor |
| SA_OBJECT | `0x49E9D` | Strip adapter reference position |
| 240_OBJECT | `0x49EA7` | APS/240 film reference position |
| 240_HEAD | `0x49EB2` | APS/240 head reference position |
| FD_OBJECT | `0x49EBB` | Feeder reference position |
| 6SA_OBJECT | `0x49EC5` | 6-strip adapter reference position |
| 36SA_OBJECT | `0x49ED0` | 36-strip adapter reference position |

These are used during motor homing and film positioning to identify known mechanical reference points. Each adapter type has a corresponding `*_OBJECT` string for its home/reference position.

## Calibration Parameter Names

The string table at `0x49EDC`-`0x49EFB` contains calibration parameter names:

| Name | Address | Purpose |
|------|---------|---------|
| DA_COARSE | `0x49EDC` | Coarse D/A converter adjustment (analog offset) |
| DA_FINE | `0x49EE6` | Fine D/A converter adjustment (precision offset) |
| EXP_TIME | `0x49EEE` | CCD exposure time parameter |
| GAIN | `0x49EF7` | Analog gain (pre-ADC amplification) |

These parameters are used during sensor calibration. The firmware adjusts DA_COARSE and DA_FINE for dark current offset, EXP_TIME for integration time, and GAIN for per-channel amplification. These are written via vendor command E0 and triggered via C1.

## Cross-References

- [INQUIRY](../../scsi-commands/inquiry.md) — VPD page dispatch using adapter type
- [SCSI Handler](scsi-handler.md) — SCSI dispatch table and handler overview
- [Data Tables](data-tables.md) — String pointer table and VPD tables
- [Motor Control](motor-control.md) — Motor positioning using object references
- [Calibration](calibration.md) — Calibration using DA/EXP/GAIN parameters
- [Scan State Machine](scan-state-machine.md) — Per-adapter scan entry points
