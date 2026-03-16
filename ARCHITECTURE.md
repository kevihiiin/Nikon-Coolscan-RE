# Coolscan RE -- Architecture Overview

## Call Chain

```
NikonScan4.ds  (TWAIN data source -- scan workflow orchestration)
      |
      v
  LS5000.md3   (MAID module -- SCSI command construction)
      |
      v
 NKDUSCAN.dll  (USB transport -- SCSI-over-USB wrapping)
      |
      v
  usbscan.sys  (Windows USB scanner class driver)
      |
      v
   USB bulk     (bulk-out: CDB, bulk-in: data, 0xD0: phase query, 0x06: sense)
      |
      v
  H8/3003 fw   (Firmware -- SCSI command dispatch, motor/CCD/lamp control)
```

## Software Layers

| Layer | Binary | Role |
|-------|--------|------|
| TWAIN | `NikonScan4.ds` | User-facing scan operations, workflow sequencing |
| MAID | `LS5000.md3` (or LS4000/8000/9000) | Model-specific SCSI command building |
| Transport | `NKDUSCAN.dll` (USB) / `NKDSBP2.dll` (1394) | USB or FireWire SCSI transport (never both per model) |
| Kernel | `usbscan.sys` (USB) / `scsiscan.sys` (1394) | OS scanner class driver |
| Firmware | LS-50 flash ROM | Device-side SCSI handler, hardware control |

## Image Processing (Post-Scan)

| DLL | Purpose |
|-----|---------|
| `DRAGNKL1.dll` / `DRAGNKX2.dll` | Digital ROC (color restoration) + GEM (grain reduction) |
| `ICEDLL.dll` / `ICENKNL1.dll` / `ICENKNX2.dll` | Digital ICE (infrared dust/scratch removal) |

## Firmware Architecture (H8/3003, LS-50)

```
Power-on → Reset vector (0x100) → Boot select (0x4001)
    → Main entry (0x20334) → I/O init (132 registers) → RAM test
    → Trampoline install (12 ISRs) → SP relocate
    → JMP @0x107EC: Enter cooperative coroutine system (never returns)

TWO-CONTEXT COOPERATIVE COROUTINE SYSTEM:
    Context A (0x207F2, stack@0x410000): Control plane
        8-step polling loop: USB check → scan state → USB reset
        → state machine → USB reinit → SCSI check → dispatch → reset
        Yield: TRAPA #0 when no SCSI command pending

    Context B (0x29B16, stack@0x40D000): Data plane
        Background processing: DMA management, motor coordination,
        scan progress monitoring, long-running data transfers
        21 yield points throughout

    Context switch: TRAPA #0 → Vec 8 → 0x10876
        Saves ER0-ER6, swaps SP from @0x400766, restores other context

ISP1581 USB IRQ (Vec 13) → CDB received → flag @0x400082
    → Main loop polls → SCSI dispatch (0x20B48)
    → Handler table (0x49834, 20 opcodes) → Permission check → Handler call
    → Action commands store task code → @0x400778

Task system:
    Task dispatch (0x20DBA): linear search in table @0x49910 (97 entries)
    → handler index → budget-based execution (0x20DD6)
    → yields via TRAPA #0 to prevent starvation

SCAN state machine (0x40000-0x45000):
    12 giant functions, 4 adapter entry points
    Pipeline: INIT→MOTOR→FOCUS→CALIB→EXPOSURE→SCAN→RECOVERY
    Task codes: 0x08GV (G=group, V=adapter variant)
    Inner loop: ASIC DMA trigger → poll → F1 pixel process → yield

SCAN data pipeline:
    CCD → ASIC analog front-end (gain/timing)
    → ASIC RAM (0x800000, 224KB, DMA Ch0 ISR)
    → Pixel processing (shlr.w bit extraction only)
    → Buffer RAM (0xC00000, 64KB)
    → ISP1581 USB bulk-in (DMA Ch1 ISR → response manager)

Calibration:
    DAC mode = 0xA2 → CCD read → Per-channel min/max
    → Gain/offset adjustment (LS-50: coarse=100, LS-5000: coarse=180)

Note: ALL image processing (dark subtraction, white normalization,
      gamma, LUT, color balance) is done HOST-SIDE by NikonScan.
      Autofocus is also host-driven (contrast search in NikonScan).
```

## Detailed Documentation

### Architecture
- [System Overview](docs/kb/architecture/system-overview.md)
- [Software Layers](docs/kb/architecture/software-layers.md)

### SCSI Protocol
- [USB Protocol](docs/kb/architecture/usb-protocol.md) — SCSI-over-USB transport (CDB, phase query, sense retrieval)
- [SCSI Commands](docs/kb/scsi-commands/) — All 17 opcodes + 4 vendor commands, Verified confidence
- [SET WINDOW Descriptor](docs/kb/scsi-commands/set-window-descriptor.md) — Byte-level parameter mapping (54+ bytes)
- [Sense Code Catalog](docs/kb/scsi-commands/sense-codes.md) — 148 entries, 64 active, full error response reference

### Firmware (LS-50 H8/3003)
- [Main Loop & Coroutines](docs/kb/components/firmware/main-loop.md) — Two-context cooperative system, task dispatch
- [Scan State Machine](docs/kb/components/firmware/scan-state-machine.md) — 12 giant functions, task encoding
- [Startup & Boot](docs/kb/components/firmware/startup.md) — Boot sequence, I/O init table
- [Vector Table](docs/kb/components/firmware/vector-table.md) — All 15 active interrupt vectors
- [SCSI Handler](docs/kb/components/firmware/scsi-handler.md) — Dispatch chain, 21 handlers
- [ISP1581 USB](docs/kb/components/firmware/isp1581-usb.md) — USB controller interface
- [Motor Control](docs/kb/components/firmware/motor-control.md) — Stepper motors, encoder, speed ramps
- [ASIC Registers](docs/kb/components/firmware/asic-registers.md) — 172 registers, 8 blocks
- [Scan Data Pipeline](docs/kb/components/firmware/scan-pipeline.md) — CCD→ASIC→RAM→USB
- [Calibration](docs/kb/components/firmware/calibration.md) — DAC modes, factory data
- [Lamp Control](docs/kb/components/firmware/lamp-control.md) — GPIO, exposure control
- [Data Tables](docs/kb/components/firmware/data-tables.md) — Task table, VPD, ramp tables

### Host Software
- [NKDUSCAN.dll](docs/kb/components/nkduscan/) — USB transport layer (NkDriverEntry, 9 function codes)
- [NKDSBP2.dll / SBP-2 Transport](docs/kb/architecture/sbp2-transport.md) — FireWire transport (native SCSI over 1394)
- [LS5000.md3](docs/kb/components/ls5000-md3/) — Scanner model module (MAID→SCSI, 17 opcodes)
- [NikonScan4.ds](docs/kb/components/nikonscan4-ds/) — TWAIN data source (scan workflows, command queue)
- [Memory Map](docs/kb/reference/memory-map.md) — H8/3003 address space

### Image Processing (Post-Scan)
- [Digital ICE](docs/kb/components/ice/overview.md) — Infrared defect correction (3 DLLs, DICE API, SDC Core variants)
- [Digital ROC/GEM (DRAG)](docs/kb/components/dragnkl1/api.md) — Color restoration + grain reduction (ASF/Kodak)
- [DRAG Pipeline](docs/kb/components/dragnkl1/pipeline.md) — End-to-end image processing pipeline, DLL dependency map, supporting DLLs

### Cross-Model
- [Model Comparison](docs/kb/scanners/model-comparison.md) — All 6 scanner models, transport/module mapping

### Driver Development Guide
- [Scan Data Transfer Q&A](docs/kb/driver-guide/scan-data-transfer.md) — Image byte count calculation, end-of-scan behavior, abort sequence, buffer architecture, vendor extension bytes

### Deep Dive References
- [SCSI Command Sequences](docs/kb/deep-dive/scsi-command-sequences.md) — Complete CDB sequences for every scanner operation (Verified)
- [Firmware Data Tables](docs/kb/deep-dive/firmware-data-tables.md) — Byte-level decode of all flash data tables (Verified)
- [Firmware Memory Map](docs/kb/deep-dive/firmware-memory-map.md) — Complete address space reference
- [Scanner Options & Settings](docs/kb/deep-dive/scanner-options-settings.md) — All configurable parameters
- [Multi-Pass Scanning](docs/kb/deep-dive/multi-pass-scanning.md) — Multi-pass firmware analysis
- [PC Software Interface](docs/kb/deep-dive/pc-software-interface.md) — Host-to-scanner communication reference
- [ICE Implementation](docs/kb/deep-dive/ice-implementation.md) — Full Digital ICE/ROC/GEM algorithm analysis
- [Image Processing Pipeline](docs/kb/deep-dive/image-processing-pipeline.md) — Complete post-scan processing pipeline
- Firmware C Pseudocode: [Main System](docs/kb/deep-dive/firmware-main-system.c), [Scan Engine](docs/kb/deep-dive/firmware-scan-engine.c), [Hardware Control](docs/kb/deep-dive/firmware-hardware-control.c), [SCSI Handlers](docs/kb/deep-dive/firmware-scsi-handlers.c), [Memory Map Header](docs/kb/deep-dive/firmware-memory-map.h)
