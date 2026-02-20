# Phase 6: DRAG/ICE Image Processing (Lower Priority)

## Goal
Understand Digital ICE dust removal and the DRAG image processing pipeline. Document the API contracts and data flow for these post-processing modules.

## Completion Criteria
All must be met to mark phase complete:
- [ ] DRAG API fully documented: DRAGInit/Begin/Process/End signatures, input/output buffer formats
- [ ] "Scanner Revelation Mask and LUT" pipeline understood: what data it takes, what it produces
- [ ] DICE/ICE API documented: how infrared channel data is fed in, dust map is produced
- [ ] SDC Core algorithm variants (L1B, X3A, X3B) differences noted
- [ ] Image processing pipeline from raw scanner data to final output documented end-to-end

## Targets

| Binary | Path | Ghidra Project | Size |
|--------|------|----------------|------|
| DRAGNKL1.dll | binaries/software/NikonScan403_installed/Twain_Source/DRAGNKL1.dll | NikonScan_TWAIN | varies |
| DRAGNKX2.dll | binaries/software/NikonScan403_installed/Twain_Source/DRAGNKX2.dll | NikonScan_TWAIN | varies |
| ICEDLL.dll | binaries/software/NikonScan403_installed/Drivers/ICEDLL.dll | NikonScan_ICE | varies |
| ICENKNL1.dll | binaries/software/NikonScan403_installed/Drivers/ICENKNL1.dll | NikonScan_ICE | varies |
| ICENKNX2.dll | binaries/software/NikonScan403_installed/Drivers/ICENKNX2.dll | NikonScan_ICE | varies |

## Methodology (Step by Step)

### Step 1: DRAG DLL Export Analysis
**What to do**: Analyze exports of DRAGNKL1.dll and DRAGNKX2.dll.
**What to look for**:
- Init/Begin/Process/End lifecycle functions
- "DRAG" = "Digital ROC And GEM" or similar Applied Science Fiction terminology
- L1 suffix = single-pass/lightweight, X2 = extended/two-pass
- Input: raw scanner data (RGB + possibly infrared channel)
- Output: color-corrected / grain-reduced image data
**Output**: `kb/components/dragnkl1/api.md`

### Step 2: DRAG Processing Pipeline
**What to do**: Trace the DRAG image processing pipeline.
**What to look for**:
- "Scanner Revelation Mask" -- likely a mask identifying dust/scratch locations
- "LUT" (Look-Up Table) -- color/tone correction
- ROC = Restoration of Color (faded slide correction)
- GEM = Grain Equalization and Management (grain reduction)
- Buffer formats: pixel layout, bit depth, color channels
**Output**: Pipeline diagram in `kb/components/dragnkl1/pipeline.md`

### Step 3: ICE DLL Analysis
**What to do**: Analyze Digital ICE (Infrared Clean) implementation.
**What to look for**:
- ICEDLL.dll: Core ICE algorithm
- ICENKNL1.dll: Nikon L1 variant (basic ICE)
- ICENKNX2.dll: Nikon X2 variant (ICE4 Advanced)
- Input: infrared channel data from scanner (4th channel beyond RGB)
- Output: dust/scratch map, cleaned image
- "SDC Core" algorithm variants: L1B, X3A, X3B
**Output**: `kb/components/ice/overview.md`

### Step 4: End-to-End Pipeline Documentation
**What to do**: Document the complete pipeline from raw scanner data to final image.
**What to look for**:
- Raw data from scanner: R, G, B, IR channels at CCD resolution
- Pipeline stages: linearization -> white balance -> color correction -> ICE -> DRAG -> gamma -> output
- Which stages happen in hardware (scanner firmware) vs software (DLLs)
- Buffer handoff between stages
**Output**: `kb/components/dragnkl1/pipeline.md` and `kb/components/ice/overview.md`

## Prerequisite Knowledge
- Phase 2-3: How scanner data is transferred (READ command)
- Phase 4: What raw data format the scanner produces

## KB Deliverables
- `kb/components/dragnkl1/api.md`
- `kb/components/dragnkl1/pipeline.md`
- `kb/components/ice/overview.md`

## Log Files
- Phase log: `logs/phases/phase-06-drag-ice.md`
- Component logs: `logs/components/dragnkl1-attempts.md`, `logs/components/ice-attempts.md`
