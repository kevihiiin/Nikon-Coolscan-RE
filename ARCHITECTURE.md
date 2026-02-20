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

## Detailed Documentation

- [System Overview](docs/kb/architecture/system-overview.md)
- [Software Layers](docs/kb/architecture/software-layers.md)
- [SCSI Commands](docs/kb/scsi-commands/) (populated during Phases 2-5)
