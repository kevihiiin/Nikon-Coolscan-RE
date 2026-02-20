# RE Progress Log

<!-- STATUS HEADER - editable -->
**Current Phase**: 0 (Bootstrap & Tooling)
**Last Session**: 2026-02-20
**Next Priority**: Complete Phase 0 criteria, then begin Phase 1 (NKDUSCAN.dll)

---
<!-- ENTRIES BELOW - APPEND ONLY -->

## 2026-02-20 -- Session 1: Project Bootstrap

### Goals
- Initialize full project structure per master plan
- Install H8/300H SLEIGH module for Ghidra
- Import all binaries into Ghidra projects
- Create analysis scripts and run initial extraction
- Write initial KB documents

### Accomplished
- Git repo initialized with full directory structure
- CLAUDE.md written at project root (session bootstrap document)
- All 8 phase instruction docs written (`docs/phases/phase-00` through `phase-07`)
- H8/300H SLEIGH module installed (carllom/sleigh-h8, compiled for Ghidra 12.0.3)
  - Verified: disassembly at reset vector 0x100 produces correct H8/300H instructions
  - `mov.l #0xffff00,er7` (SP init), `ldc.b #0xc0,ccr` (disable interrupts), etc.
- Firmware imported into Ghidra CoolscanFirmware project
- PE32 binary imports into Ghidra projects (NikonScan_Drivers, _ICE, _Modules, _TWAIN) -- in progress
- Python analysis scripts written and executed:
  - `extract_pe_exports.py` -- all 12 binaries processed, exports/imports extracted
  - `extract_rtti.py` -- 309 RTTI entries found across 12 binaries
  - `parse_vector_table.py` -- 15 active interrupt vectors identified
- r2 `firmware_init.r2` script created and verified
- KB docs written: `system-overview.md`, `software-layers.md`
- Log files initialized

### Key Findings
- NKDUSCAN.dll has 14 RTTI classes: CUSB2Command, CUSBSession, CUSBDeviceTable, CUSBDevInfo, CUSBSessionsCollection, CSBP2CommandManager, CSBP2Command
- NikonScan4.ds has 242 RTTI classes (MFC-based application)
- Firmware has 15 active interrupt vectors (not 12 as initially estimated)
- Most active vectors point to on-chip RAM trampolines (0xFFFDxx), suggesting relocatable handlers
- IRQ1 (vector 13) is likely the ISP1581 USB interrupt
- Three ITU timer compare-match interrupts active (ch2, ch3, ch4) -- likely motor step timing
- Two DMA end interrupts active -- likely USB bulk data transfer
- r2 h8300 support is 16-bit only; H8/300H extended instructions require Ghidra

### Blockers
- Ghidra 12.0.3 requires PyGhidra for Python scripts; Java scripts work fine
- r2 doesn't fully support H8/300H (only basic H8/300, 16-bit mode)

### Next Steps
- Verify all Ghidra PE imports completed successfully
- Begin Phase 1: NKDUSCAN.dll analysis (USB transport layer)
- First Phase 1 target: `NkDriverEntry` export -- understand API contract
