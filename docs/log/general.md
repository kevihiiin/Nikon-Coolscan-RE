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

## 2026-02-20 -- Session 2: Documentation Fact-Check

### Goals
- Fact-check all documentation against binary ground truth
- Fix all errors found

### Accomplished
- Comprehensive binary analysis performed: INF files, firmware hex dump, DLL exports/imports/RTTI, strings
- All documentation cross-referenced against ground truth

### Corrections Made
- **Scanner interfaces**: LS-4000/8000/9000 are FireWire ONLY (not "IEEE 1394 + USB"). Confirmed from INF files.
- **LS-40 (Coolscan IV ED)** added: USB PID 0x4000, was missing from all docs
- **LS-4000 name**: Fixed to "Super Coolscan 4000 ED" (per 1394 INF)
- **Module mapping**: Documented that LS-50 uses LS5000.md3, LS-40 uses LS4000.md3 (no separate modules)
- **ASIC RAM**: Corrected 256KB → 224KB (firmware range table: 0x800000-0x837FFF)
- **Flash layout**: Removed phantom "0x8000 extended settings" (entirely 0xFF). Main FW is 202KB not 256KB. Added second log area at 0x70000.
- **NikonScan4.ds RTTI**: Corrected 242 → 321 (recount via `strings | grep .?AV | wc -l`)
- **ICE DLL exports**: Corrected 34 → 36
- **Phase 4 vector count**: Corrected 12 → 15
- **Vector table**: Added missing 15th entry (vector 52 → 0xFFFD38)
- **USB protocol 0xD0/0x06**: Verified from NKDUSCAN.dll disassembly (0x10002b55, 0x10002b5a)
- **NkDriverEntry dispatch**: Found 9 function codes (1-9) at 0x10003c40
- **Firmware USB descriptors**: Found VID=0x04B0, PID=0x4001, dual USB 1.1/2.0 descriptors
- **GPIO/CPU speed**: Marked as unverified (GPIO ports confirmed used, specific bits not)
- **LS5000.md3 RTTI**: Clarified as "6 stdlib classes, no project-specific"
- **NikonScan4.ds exports**: Corrected "DS_Entry + MFC" → "59 exports"
- **DRAGNKL1/X2 exports**: Added actual counts (48/44)
- **Binary sizes**: Updated all to verified values

### Key New Findings
- NkDriverEntry has exactly 9 function codes dispatched via jump table
- Phase bytes in USB protocol: 0x01=data-out, 0x02=status, 0x03=data-in
- Firmware contains dual INQUIRY strings: "LS-50 ED" and "LS-5000-123456" (shared lineage)
- All NKScnUSD.dll copies are byte-identical (6.5KB universal COM shim)
- LS4000.md3 shared by LS-40 (USB) and LS-4000 (1394) — confirmed by shared ICM profile "NKLS4000LS40"
- Firmware flash has dual 64KB log sectors (0x60000 + 0x70000) with structured 32-byte records
- NKDUSCAN compiled 2007-02-16 (MSVC 8.0), NikonScan4.ds compiled 2004-03-22 (MSVC 7.0)

### Post-Review Corrections
- **ASIC RAM**: Reverted to "256KB (unverified)". Two firmware data structures disagree: FW:0x4A114 shows end=0x837FFF (224KB), FW:0x207A8 shows ranges to 0x840000 (256KB). Neither table's purpose has been confirmed by code trace.
- **Flash 0x8000**: Restored as "extended settings (erased in our dump)". All 0xFF means unused on this specific unit, not that the region doesn't serve a purpose — could hold data on other units or firmware versions.
