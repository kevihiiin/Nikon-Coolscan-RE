# Phase 0: Bootstrap & Tooling

<!-- STATUS HEADER - editable -->
**Status**: Complete
**Started**: 2026-02-20  |  **Completed**: 2026-02-20
**Completion**: 9/9 criteria met

### Criteria Status
- [x] Git repo initialized with full directory structure committed
- [x] H8/300H SLEIGH module builds and disassembles firmware reset vector correctly
- [x] All 13 PE32 binaries imported into Ghidra projects with auto-analysis complete
- [x] Firmware imported into Ghidra CoolscanFirmware project with H8/300H processor
- [x] r2 `firmware_init.r2` script runs without error and labels vector table + known strings
- [x] PE export extraction script produces CSV for all DLLs
- [x] RTTI extraction script recovers class names from at least NKDUSCAN.dll
- [x] `kb/architecture/system-overview.md` and `kb/architecture/software-layers.md` written
- [x] `logs/general.md` and `logs/phases/phase-00-setup.md` initialized

---
<!-- ENTRIES BELOW - APPEND ONLY -->

### 2026-02-20: Git Init & Directory Structure
**Tool**: git, mkdir
**What was tried**: Created full directory tree per master plan, git init, .gitignore
**Result**: Success -- all directories created with .gitkeep files
**Artifacts**: `.gitignore`, directory structure

### 2026-02-20: H8/300H SLEIGH Module Installation
**Tool**: git clone, Ghidra SLEIGH compiler
**What was tried**: Cloned carllom/sleigh-h8, compiled h8300h.slaspec with /opt/ghidra/support/sleigh
**Result**: Success -- compiled with warnings only (no errors). Installed as Ghidra extension at ~/.config/ghidra/ghidra_12.0.3_PUBLIC/Extensions/H8/
**Insight**: The .slaspec files needed to be compiled; only h8300.sla (basic) was pre-built
**Artifacts**: `tools/ghidra-h8/sleigh-h8/`

### 2026-02-20: Firmware Import & Disassembly Verification
**Tool**: Ghidra headless (analyzeHeadless), VerifyFirmware.java script
**What was tried**: Imported firmware as raw binary with H8:BE:32:H8300 processor, ran disassembly at 0x100
**Result**: Success -- clean H8/300H disassembly:
  - 0x100: `mov.l #0xffff00,er7` (SP = top of on-chip RAM)
  - 0x106: `ldc.b #0xc0,ccr` (disable interrupts)
  - 0x108: `mov.b #0x0,r0l` + store to 0xfffd4c
  - 0x10e: `bra 0x16e` (jump to main init)
**Confidence**: High
**Artifacts**: `ghidra/projects/CoolscanFirmware/`, `ghidra/scripts/VerifyFirmware.java`

### 2026-02-20: Python Script Execution
**Tool**: Python 3.12 + pefile (in .venv)
**What was tried**: Ran extract_pe_exports.py, extract_rtti.py, parse_vector_table.py on all binaries
**Result**: All successful:
  - Exports: All 12 PE32 binaries processed (NKDUSCAN=1 export, ICEDLL=34 exports, etc.)
  - RTTI: 309 entries total (NKDUSCAN=14 classes, NikonScan4.ds=242 classes)
  - Vectors: 15 active interrupt vectors identified
**Confidence**: High
**Artifacts**: `ghidra/exports/all_exports_imports.csv`, `ghidra/exports/rtti_classes.json`, `ghidra/exports/firmware_vectors.json`

### 2026-02-20: Ghidra PE32 Import (Background)
**Tool**: Ghidra headless (analyzeHeadless)
**What was tried**: Importing all 12 PE32 binaries into 4 Ghidra projects with auto-analysis
**Result**: Success -- all 12 PE32 binaries imported and auto-analyzed:
  - NikonScan_Drivers: NKDUSCAN.dll, NKDSBP2.dll (both analyzed)
  - NikonScan_ICE: ICEDLL.dll, ICENKNL1.dll, ICENKNX2.dll (all analyzed)
  - NikonScan_Modules: LS4000.md3, LS5000.md3, LS8000.md3, LS9000.md3 (all analyzed)
  - NikonScan_TWAIN: NikonScan4.ds, DRAGNKL1.dll, DRAGNKX2.dll (all analyzed)
  - CoolscanFirmware: firmware auto-analysis also completed
**Confidence**: High
**Artifacts**: `ghidra/projects/NikonScan_Drivers/`, `NikonScan_ICE/`, `NikonScan_Modules/`, `NikonScan_TWAIN/`
