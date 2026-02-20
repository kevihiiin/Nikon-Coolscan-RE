# Phase 7: Cross-Model Expansion

## Goal
Extend protocol documentation from LS-50/LS-5000 to cover LS-4000, LS-8000, and LS-9000 scanners. Document 1394/SBP-2 transport differences.

## Completion Criteria
All must be met to mark phase complete:
- [ ] LS4000.md3, LS8000.md3, LS9000.md3 each analyzed for unique SCSI commands not in LS5000
- [ ] Model-specific SCSI extensions cataloged (extra opcodes, different parameter ranges, etc.)
- [ ] 1394/SBP2 transport differences documented (NKDSBP2.dll vs NKDUSCAN.dll)
- [ ] Per-model scanner spec sheets written in `kb/scanners/`
- [ ] Protocol spec updated with model-specific appendices

## Targets

| Binary | Path | Ghidra Project | Purpose |
|--------|------|----------------|---------|
| LS4000.md3 | Module_E/LS4000.md3 | NikonScan_Modules | LS-4000 ED model module |
| LS8000.md3 | Module_E/LS8000.md3 | NikonScan_Modules | Super Coolscan 8000 ED |
| LS9000.md3 | Module_E/LS9000.md3 | NikonScan_Modules | Super Coolscan 9000 ED |
| NKDSBP2.dll | Drivers/NKDSBP2.dll | NikonScan_Drivers | IEEE1394/SBP-2 transport |

All PE32 paths relative to `binaries/software/NikonScan403_installed/`.

## Methodology (Step by Step)

### Step 1: Module Comparison (BinDiff / Manual)
**What to do**: Compare LS4000, LS8000, LS9000 modules against LS5000 baseline.
**What to look for**:
- Same export structure? (MAIDEntryPoint, NkCtrlEntry, NkMDCtrlEntry)
- New/different SCSI opcodes (search CDB construction patterns)
- Different parameter ranges (resolution, bit depth, scan area limits)
- Model-specific strings
- Size differences indicating additional functionality
**Output**: Per-model comparison notes

### Step 2: Model-Specific SCSI Commands
**What to do**: For each model, identify SCSI commands unique to that model.
**What to look for**:
- LS-4000: Early USB model, may have simpler command set
- LS-8000: Medium format (120 film) -- different scan area, possibly extra frame positioning commands
- LS-9000: Most advanced -- maximum resolution, possibly additional calibration/processing commands
- Vendor-specific opcodes that appear in one module but not LS5000
**Output**: Model-specific command appendices in `kb/scsi-commands/`

### Step 3: Scanner Capability Differences
**What to do**: Document hardware capability differences per model.
**What to look for**:
- Maximum optical resolution (2900/4000 DPI)
- Film formats supported (35mm, APS, 120/220)
- Bit depth (12-bit vs 14-bit vs 16-bit)
- Multi-sample scanning support
- ICE/ROC/GEM/DEE support levels
- Interface: USB 1.1 vs 2.0, FireWire 400
**Output**: `kb/scanners/` per-model spec sheets

### Step 4: NKDSBP2.dll (IEEE 1394 / SBP-2 Transport)
**What to do**: Full analysis of the FireWire transport layer.
**What to look for**:
- Same `NkDriverEntry` API as NKDUSCAN.dll
- Class hierarchy: CSBP2Command, CSBP2Session (vs CUSB2Command, CUSBSession)
- SBP-2 (Serial Bus Protocol 2) command ORB construction
- How SCSI CDBs are wrapped in SBP-2 ORBs
- Login/logout sequence
- Key difference: SBP-2 has native SCSI transport vs USB which needs custom wrapping
**Output**: `kb/architecture/sbp2-transport.md`

### Step 5: Protocol Spec Model Appendices
**What to do**: Update the main protocol specification with per-model differences.
**Output**: Model-specific sections in `kb/scsi-commands/`, updated `kb/scanners/` docs

## Key Model Information

| Model | Name | Resolution | Film | Interface | USB PID |
|-------|------|-----------|------|-----------|---------|
| LS-40 | Coolscan IV | 2900 DPI | 35mm | USB 1.1 | ? |
| LS-50 | Coolscan V | 4000 DPI | 35mm | USB 2.0 | 0x4001 |
| LS-4000 | Coolscan 4000 | 2900 DPI | 35mm | 1394 + USB | ? |
| LS-5000 | Coolscan 5000 | 4000 DPI | 35mm | USB 2.0 | 0x4002 |
| LS-8000 | Super Coolscan 8000 | 4000 DPI | 35mm+120 | 1394 + USB | ? |
| LS-9000 | Super Coolscan 9000 | 4000 DPI | 35mm+120 | 1394 + USB | ? |

## Prerequisite Knowledge
- All Phase 1-5 KB docs (complete LS-50/LS-5000 protocol)
- Phase 1: NKDUSCAN.dll analysis (for NKDSBP2 comparison)

## KB Deliverables
- `kb/scanners/coolscan-v-ls50.md`
- `kb/scanners/super-coolscan-5000.md`
- `kb/scanners/coolscan-4000.md`
- `kb/scanners/super-coolscan-8000.md`
- `kb/scanners/super-coolscan-9000.md`
- `kb/architecture/sbp2-transport.md`
- Model-specific appendices in `kb/scsi-commands/`

## Log Files
- Phase log: `logs/phases/phase-07-cross-model.md`
- Component logs: `logs/components/ls4000-attempts.md`, `logs/components/ls8000-attempts.md`, `logs/components/ls9000-attempts.md`, `logs/components/nkdsbp2-attempts.md`
