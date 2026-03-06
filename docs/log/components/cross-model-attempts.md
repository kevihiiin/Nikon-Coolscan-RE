# Cross-Model Module Analysis Log

<!-- STATUS HEADER - editable -->
**Status**: Complete
**Binary**: LS4000.md3, LS5000.md3, LS8000.md3, LS9000.md3
**Ghidra Project**: NikonScan_Modules
---
<!-- ENTRIES BELOW - APPEND ONLY -->

## 2026-03-05 -- Attempt 1: Module Comparison

**Tool**: pefile (Python), strings
**Target**: All 4 .md3 modules
**Goal**: Identify cross-model differences

### Findings

1. **Identical structure**: All 4 modules have same 3 exports (MAIDEntryPoint, NkCtrlEntry, NkMDCtrlEntry), same 7 import DLLs, same RTTI (just exception + type_info)

2. **Module sizes**: LS4000 (824KB) < LS8000 (936KB) < LS5000 (1028KB) < LS9000 (1112KB)

3. **MAID versions**: LS4000/LS8000/LS9000 = MD3.01, LS5000 = MD3.50 (newer protocol)

4. **PE version info**:
   - LS4000: v1.3.0.3006, copyright 1995-2007
   - LS5000: v1.0.0.3014, copyright 2003-2007 (newest design)
   - LS8000: v1.3.0.3003, copyright 1995-2007
   - LS9000: v1.0.0.3009, copyright 1995-2007

5. **ICE integration**: All have identical 18 DICE function references

6. **Transport**: All reference both Nkduscan.dll and Nkdsbp2.dll (transport-agnostic)

7. **Film holders**: All support FH-3, FH-A1, FH-G1. LS8000/LS9000 additionally support Brownie (120/220 medium format) film types.

8. **Film type strings unique to LS8000/LS9000**: "35mm Mount Film", "35mm Strip Film", "Brownie Mount Film", "Brownie Strip Film", "Brownie Strip Film with G"

9. **No unique RTTI classes**: All modules use identical class structure. Model-specific behavior is parameterized, not polymorphic.

**Confidence**: High
