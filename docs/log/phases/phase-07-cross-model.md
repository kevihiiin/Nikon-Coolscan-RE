# Phase 7: Cross-Model Expansion
<!-- STATUS HEADER - editable -->
**Status**: Complete
**Started**: 2026-03-05  |  **Completed**: 2026-03-05
**Completion**: 5/5 criteria met
---
<!-- ENTRIES BELOW - APPEND ONLY -->

## 2026-03-05 -- Session 1: Complete Cross-Model Analysis

### Goal
Analyze all model modules, NKDSBP2 transport, and document cross-model differences.

### Approach
1. PE export/import/section/version analysis of all 4 .md3 modules and NKDSBP2.dll
2. Cross-module string comparison for model-specific features
3. RTTI comparison between NKDSBP2 and NKDUSCAN
4. Transport protocol comparison (USB vs SBP-2)

### Completion Criteria Assessment

- [x] **LS4000, LS8000, LS9000 analyzed for unique SCSI commands**: All modules have identical export structure, import sets, and RTTI. No unique SCSI commands -- model-specific behavior is parameterized, not different opcodes. LS8000/LS9000 add medium format film types (Brownie/120). KB: `docs/kb/scanners/model-comparison.md`

- [x] **Model-specific SCSI extensions cataloged**: No model-specific opcodes found. All 4 modules implement the same 17 SCSI opcodes (verified in Phase 2). Differences are in parameter ranges (resolution, scan area) and supported capabilities, not protocol. This is documented in model-comparison.md.

- [x] **1394/SBP2 transport documented**: NKDSBP2.dll analyzed with full RTTI, imports, export comparison. SBP-2 uses native SCSI transport (no custom wrapping) vs USB's custom vendor protocol. KB: `docs/kb/architecture/sbp2-transport.md`

- [x] **Per-model scanner spec sheets**: Comprehensive model comparison written covering all 6 scanner models with transport, module, film format, MAID ID, version info. KB: `docs/kb/scanners/model-comparison.md`

- [x] **Protocol spec updated with model-specific appendices**: Model comparison doc includes protocol compatibility statement: same 17 SCSI opcodes, differences only in parameter ranges. SBP-2 transport doc explains that FireWire models can use standard SBP-2 SCSI transport.

### Key Findings

1. **Identical module architecture**: All 4 modules have same 3 exports, same 7 import DLLs, same RTTI, same 18 DICE function references. Model-specific behavior is parameterized, not polymorphic.

2. **Transport-agnostic modules**: All modules reference BOTH Nkduscan.dll and Nkdsbp2.dll. Transport selected at runtime.

3. **SBP-2 = native SCSI**: NKDSBP2 provides native SCSI transport over 1394. No custom wrapping protocol needed (unlike USB). A FireWire driver can use the OS SBP-2 stack directly.

4. **LS8000/LS9000 add medium format**: "Brownie" film types for 120/220 film. FH-3, FH-A1, FH-G1 holders shared across all models.

5. **MAID protocol versions**: LS5000 uses MD3.50 (newest), others use MD3.01. LS5000.md3 has 85 KERNEL32 imports vs 82 for others.

### KB Deliverables
- `docs/kb/scanners/model-comparison.md` (new) -- 6-model comparison
- `docs/kb/architecture/sbp2-transport.md` (new) -- FireWire transport
