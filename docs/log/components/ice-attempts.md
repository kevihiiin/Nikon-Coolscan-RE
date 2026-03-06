# ICE DLL Analysis Log

<!-- STATUS HEADER - editable -->
**Status**: Complete
**Binary**: ICEDLL.dll (280KB), ICENKNL1.dll (344KB), ICENKNX2.dll (432KB)
**Ghidra Project**: NikonScan_ICE
---
<!-- ENTRIES BELOW - APPEND ONLY -->

## 2026-03-05 -- Attempt 1: Export and String Analysis

**Tool**: pefile (Python), strings
**Target**: ICEDLL.dll, ICENKNL1.dll, ICENKNX2.dll
**Goal**: Extract exports, version info, algorithm variants, source tree

### Findings

1. **Exports**: All 3 DLLs export exactly 36 identical DICE functions. API is a C interface with opaque context and buffer queues.

2. **Version info**:
   - ICEDLL: v3.0.0.4012, "ICE_Willow_030428_GM", Intel C++ 5.0, "for Nikon X3A,X3B,L1B"
   - ICENKNL1: v1.0.1.3001, "durer_010817_ICE/Cedar_010817_ICE", Intel C++ 4.5, "for Nikon L1"
   - ICENKNX2: v1.0.1.3001, same durer/Cedar build, "for Nikon X2"

3. **Algorithm variants**:
   - ICEDLL: L1B + X3A + X3B (all three in one DLL, newest build)
   - ICENKNL1: L1 only (basic ICE)
   - ICENKNX2: LSA + LSB (Large Scanner variants)

4. **Source tree** from compiler strings:
   ```
   H:\StarTeam\ice_roc\Engineering\Sources\ICE\
   ├── DICELib/DICELib/ (core: CDICECore, CDICEObject, CDICEQueue, CDICEThread, CDICEDataConverter, CDICEBandLimiter, CDICEScaler)
   ├── NikonX3AX3BL1B/ (newest unified build with SDCCore/ and Targets/)
   ├── SDCCoreCPP/ (CSDCCoreAlg20-37, CSDCCoreBase)
   └── DICEStatic/ (DLL entry points)
   ```

5. **SDC Core algorithm mapping**:
   - Alg20, 30-33: ICENKNX2 (LSA/LSB)
   - Alg36-37: ICENKNL1 (L1)
   - AlgL1B, AlgX3A, AlgX3B: ICEDLL (newer named variants)

6. **Sections**: ICE DLLs have 7 sections including .data1 and _DATA -- extra data sections likely hold algorithm coefficients/lookup tables.

7. **Imports**: All three import only KERNEL32.dll. Pure C DLLs, compiled with Intel C++ compiler.

**Confidence**: High (direct binary analysis, compiler paths confirmed)

## 2026-03-05 -- Attempt 2: LS5000.md3 Integration

**Tool**: strings, pefile
**Target**: LS5000.md3 DICE function references
**Goal**: Understand how ICE DLL is loaded and used

### Findings

1. **DICE functions in LS5000.md3**: 18 of 36 DICE function names found as strings (for GetProcAddress resolution). Missing: parameter get/set, overflow buffer, multi-frame, memory management.

2. **DLL loading**: ICE DLL filename is NOT a string constant in LS5000.md3. Likely resolved from registry or MAID capability. The DICE function names are present for GetProcAddress resolution.

3. **MAID cap 0x800C**: ICE is a boolean capability in the MAID object hierarchy, child of Multi-sample (0x8007). NikonScan4.ds checks for and sets this capability during scan orchestration.

4. **Pipeline**: ICE runs at the LS5000.md3 layer (model module), receiving RGBI data from SCSI READ and outputting cleaned RGB. This is host-side processing, not scanner-firmware processing. The scanner just provides the IR channel data.

5. **NikonScan4.ds does NOT import ICE DLLs** -- it only sees ICE through the MAID capability interface. All ICE processing is encapsulated in LS5000.md3.

**Confidence**: High
