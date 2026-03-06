# Phase 6: DRAG/ICE Image Processing
<!-- STATUS HEADER - editable -->
**Status**: Complete
**Started**: 2026-03-05  |  **Completed**: 2026-03-05
**Completion**: 5/5 criteria met
---
<!-- ENTRIES BELOW - APPEND ONLY -->

## 2026-03-05 -- Session 1: Complete DRAG/ICE Analysis

### Goal
Analyze all 5 DRAG/ICE DLLs, document APIs, processing pipeline, and integration.

### Approach
1. PE export/import/section/version analysis of all 5 DLLs using pefile
2. String extraction for processing phase descriptions, source paths, version info
3. RTTI extraction from NikonScan4.ds and LS5000.md3 for integration classes
4. Cross-reference with existing scan workflow KB docs
5. Supporting DLL analysis (Strato3.dll, StdFilters2.dll)

### Completion Criteria Assessment

- [x] **DRAG API fully documented**: 48 exports (L1) / 44 exports (X2) documented with lifecycle, row I/O, configuration, FFT, normalization functions. KB: `docs/kb/components/dragnkl1/api.md`

- [x] **Scanner Revelation Mask and LUT pipeline**: Documented in pipeline.md Phase 5. L1-only feature using SetREV_* functions for scanner-specific defect knowledge. The mask guides ROC/GEM processing by identifying systematic scanner artifacts.

- [x] **DICE/ICE API documented**: 36 DICE exports (identical across 3 DLLs) with lifecycle, buffer queues, parameters, progress, multi-frame, memory management. KB: `docs/kb/components/ice/overview.md`

- [x] **SDC Core algorithm variants documented**:
  - ICEDLL.dll: L1B, X3A, X3B (Willow build, newest)
  - ICENKNL1.dll: L1/Alg36/Alg37 (durer/Cedar build)
  - ICENKNX2.dll: LSA/LSB/Alg20-33 (durer/Cedar build)
  Full source tree architecture from compiler paths.

- [x] **End-to-end image pipeline documented**: Scanner RGBI → ICE (LS5000.md3, DICE API) → DRAG (NikonScan4.ds, DRAG API: ROC+GEM) → Strato filters (StdFilters2.dll: color space, LUT, scale, unsharp mask, CMS) → final output. KB: `docs/kb/components/dragnkl1/pipeline.md`

### Key Findings

1. **DRAG architecture**: NikonScan4.ds statically imports DRAGNKL1.dll (only L1, not X2). Uses CDRAGBase/CDRAGProcess/CDRAGProcessCommand class hierarchy with CQueueAcquireDRAGImage command queue. DRAG is purely host-side post-processing.

2. **ICE architecture**: LS5000.md3 dynamically loads ICE DLL (name from registry/MAID, not hardcoded). Uses 18 of 36 DICE functions via GetProcAddress. ICE runs at model module layer, close to hardware data.

3. **Pipeline position**: ICE before DRAG. ICE uses IR channel for defect correction at the .md3 level. DRAG does color/grain processing at the .ds level. Both are host-side CPU operations.

4. **Applied Science Fiction**: Both DRAG and ICE are from ASF Inc. DRAG from the "DFP" (Digital Film Processing) team using the tVec vectorized math library. ICE from the "ice_roc" team using SDC Core algorithms. Both were acquired by Kodak.

5. **Supporting pipeline**: After DRAG, NikonScan4.ds applies Strato framework filters (Strato3.dll = framework, StdFilters2.dll = 557 standard filter exports including color space, LUT, scale, unsharp mask, CMS/ICC profiles).

### KB Deliverables
- `docs/kb/components/dragnkl1/api.md` -- DRAG API reference (48/44 exports)
- `docs/kb/components/dragnkl1/pipeline.md` -- End-to-end processing pipeline
- `docs/kb/components/ice/overview.md` -- ICE overview (3 DLLs, variants, DICE API)

## 2026-03-05 -- Session 2: Supporting DLL Analysis & Dependency Map

### Goal
Analyze remaining supporting DLLs and complete the full NikonScan DLL dependency map.

### Approach
1. PE analysis (pefile) of Asteroid5.dll, CML4.dll, PICN20/1020/1120.dll, NSSLang4.dll
2. Cross-reference string/import analysis to determine usage relationships
3. Trace which DLLs are used by NikonScan4.ds vs Nikon Scan.exe

### Findings

1. **CML4.dll** (116KB, 16 exports): Nikon Color Management Library v4
   - API: NKCMCreate → SetInputProfile/SetOutputProfile → SetIntent → ProcessInterleavedData → Destroy
   - Used by StdFilters2.dll's CStratoFilterCML, NOT directly by NikonScan4.ds
   - Self-contained (no external CMS dependency)

2. **NSSLang4.dll** (452KB, 8 exports): UI language resource DLL
   - Statically imported by NikonScan4.ds for LoadExtString, LoadExtDialogTemplate, etc.
   - Resource-heavy (452KB) -- mostly localized strings, dialogs, bitmaps

3. **Asteroid5.dll** (784KB, 81 exports): "Nikon File Utility"
   - Image file I/O using Strato framework (CStratoLoad, CStratoSave, CStratoFileStream, CStratoMemoryStream)
   - Supports TIFF (uncompressed/JPEG/PackBits/ZIP), JPEG, BMP, PNG
   - Used by Nikon Scan.exe (standalone app), NOT by NikonScan4.ds (TWAIN source)
   - TWAIN source delivers data to calling app via TWAIN API -- file saving is caller's responsibility

4. **Pegasus Imaging** (3 DLLs): Third-party image codecs
   - PICN20.dll (41KB, 48 exports): Dispatcher/plugin manager
   - picn1020.dll (140KB): OP_D2S (decompression)
   - picn1120.dll (148KB): OP_S2D (compression)
   - Used by Asteroid5.dll, NOT by NikonScan4.ds

5. **Key architectural insight**: NikonScan4.ds (TWAIN) and Nikon Scan.exe (standalone) have distinct DLL trees. The TWAIN source handles scanning and image processing but NOT file I/O. File I/O (Asteroid5 + Pegasus) only exists in the standalone app path.

### KB Updates
- Updated `docs/kb/components/dragnkl1/pipeline.md` with CML4, NSSLang4, Asteroid5, Pegasus docs + full DLL dependency map
- Updated `ARCHITECTURE.md` link for pipeline doc
