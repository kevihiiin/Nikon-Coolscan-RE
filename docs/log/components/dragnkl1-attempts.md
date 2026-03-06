# DRAGNKL1/DRAGNKX2 Analysis Log

<!-- STATUS HEADER - editable -->
**Status**: Complete
**Binary**: DRAGNKL1.dll (484KB), DRAGNKX2.dll (176KB)
**Ghidra Project**: NikonScan_TWAIN
---
<!-- ENTRIES BELOW - APPEND ONLY -->

## 2026-03-05 -- Attempt 1: Export and String Analysis

**Tool**: pefile (Python), strings
**Target**: DRAGNKL1.dll, DRAGNKX2.dll
**Goal**: Extract exports, imports, version info, processing phase strings

### Findings

1. **Exports**: DRAGNKL1 has 48 exports, DRAGNKX2 has 44. Both share 44 common DRAG API functions. L1 has 4 extra: FixupTopAndLeftEdges, SetGrayLevelAdjustment, SetREVPreview, SetREV_DH/GT/SB_Adjustment, GetVerbosity/SetVerbosity.

2. **Version info**:
   - DRAGNKL1: v2.0.0.14, built 2003-07-14, copyright 1996-2003 ASF Inc.
   - DRAGNKX2: v1.0.0.0, built 2000-10-05, copyright 1996-2000 ASF Inc.
   - Both: "Digital ROC and Digital GEM are trademarks of Applied Science Fiction, Inc."

3. **Imports**: Both import only KERNEL32.dll (63 and 42 funcs respectively). Pure C DLLs, no C++ runtime, no RTTI.

4. **Processing phases** (from embedded debug strings in DRAGNKL1):
   - Acquire R/G/B channels
   - Create normalized downsized median filtered image
   - Measure grain strength, 3x3 freq-mag analysis
   - Create sandblasted mask (L1 only)
   - Apply Scanner Revelation Mask and LUT (L1 only)
   - Determine fade correction color leakage
   - Apply ROC + local color + histogram LUTs
   - Apply grain reduction
   - Unnormalize result

5. **Source tree**: `C:\StarTeam\DFP\Software\vectorlibs\SRC\tVec\tVecLib\` embedded in DRAGNKL1. Contains convolution, conversion, and mathematical vector operations. DFP = Digital Film Processing (ASF product line).

6. **FFT**: Both DLLs export FFT functions for 2D floating-point transforms. Used for grain frequency analysis. L1 has newer FFT variant, X2 has Intel-optimized variant.

7. **Usage**: NikonScan4.ds statically imports DRAGNKL1.dll (11 functions). DRAGNKX2.dll is NOT referenced by any NikonScan binary -- appears unused/legacy.

**Confidence**: High (direct binary analysis, strings verified against exports)

## 2026-03-05 -- Attempt 2: NikonScan4.ds Integration

**Tool**: pefile, strings, Ghidra export search
**Target**: NikonScan4.ds DRAG-related RTTI and command queues
**Goal**: Understand how DRAG is orchestrated in the scan workflow

### Findings

1. **RTTI classes** (from NikonScan4.ds):
   - CDRAGBase, CDRAGProcess, CDRAGPrepareCommand, CDRAGProcessCommand
   - CDRAGProcessCommandQueue, CQueueAcquireDRAGImage
   - CREVProcess, CRevProcessCommand (Revelation mask processing)
   - CNkImageProcSet, CProcessCommand, CProcessCommandManager

2. **Import thunks** at 0x1011DA26-0x1011DA68 (11 DRAG functions, 6-byte jmp thunks)

3. **MAID hierarchy**: ICE at cap 0x800C, DRAG at cap 0x800E. DRAG is child of ICE in the capability tree, confirming dependency order.

4. **Pipeline position**: Scanner → LS5000.md3 (ICE) → NikonScan4.ds (DRAG) → Strato filters → output

**Confidence**: High
