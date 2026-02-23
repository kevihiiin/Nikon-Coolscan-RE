# RE Progress Log

<!-- STATUS HEADER - editable -->
**Current Phase**: 2 Complete → Ready for Phase 3 (Scan Workflows — NikonScan4.ds)
**Last Session**: 2026-02-21
**Next Priority**: Phase 3 — NikonScan4.ds TWAIN layer analysis, scan workflow orchestration, MAID numeric capability ID mapping

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

## 2026-02-20 -- Session 3: Phase 1 — NKDUSCAN.dll Full Analysis

### Goals
- Fully reverse engineer NKDUSCAN.dll USB transport layer
- Document NkDriverEntry API (all 9 function codes)
- Decode SCSI-over-USB protocol (0xD0 phase query, 0x06 sense)
- Recover class hierarchy and vtable layouts
- Compare NKDSBP2.dll (FireWire transport)
- Write all Phase 1 KB documents

### Accomplished
- **NkDriverEntry fully decompiled**: 9 function codes, __stdcall(3 params), jump table at 0x10003DC8
- **All 9 FC handlers mapped**: FC1=Init, FC2/3=Close, FC4=Release, FC5=Execute, FC6=Status, FC7=Info, FC8=Query, FC9=Execute+Retrieve
- **CUSB2Command::Execute fully reversed** (612 bytes at 0x10002b50): Complete SCSI-over-USB protocol decoded
- **USB protocol documented**: CDB→bulk-out, 0xD0 phase query, phase byte (0x01/0x02/0x03), data transfer, 0x06 sense
- **5 DeviceIoControl callsites mapped**: 3 unique IOCTLs (0x80002008, 0x80002014, 0x80002018)
- **RTTI hierarchy recovered**: 6 interfaces, 7 concrete classes, vtable layouts documented
- **NKDSBP2.dll compared**: Same 9 FCs, only vtable slot 3 (Execute) differs
- **5 KB docs written**: overview.md, classes.md, api.md, usb-transport.md, usb-protocol.md
- **Phase log and component log updated**: 8 analysis attempts documented
- 7/8 Phase 1 completion criteria met (all KB docs written = criterion 8 now also met)

### Key Findings
1. Protocol is NOT USB Mass Storage — custom vendor protocol with single-byte opcodes
2. Version string "1200" validated during FC1 initialization
3. Only vtable slot 3 differs between USB and SBP-2 transport implementations
4. USB speed detection at session open determines transfer chunk sizes
5. Clean interface design: ICommand/ISession/ICommandManager are transport-agnostic
6. Thread safety via global critical section serializing all NkDriverEntry calls
7. STI (Still Image) architecture used for device enumeration

### What Remains for Phase 1 Deepening
- FC5-FC9 internal mechanics beyond API surface
- Worker thread analysis (CreateThread callsite)
- Full CUSBDeviceTable STI enumeration flow
- Cross-validation with firmware-side USB handling (Phase 4)

### Next Steps
- Deeper analysis of FC5/FC8/FC9 execute paths
- Worker thread and async I/O analysis
- Begin Phase 2: LS5000.md3 SCSI command extraction

## 2026-02-21 -- Session 4: Phase 1 Deep + Phase 2 SCSI Catalog

### Goals
- Complete Phase 1 deep analysis (FC handlers, worker thread, STI)
- Begin Phase 2: LS5000.md3 export analysis and SCSI command extraction

### Accomplished
- **Phase 1 completed (8/8 criteria)**: Deep analysis of FC2-FC9 internals, worker thread (CSBP2CommandManager), STI enumeration, command allocation. See Session 3 (continued) in phase-01-nkduscan.md.
- **Phase 2 export analysis**: All 3 LS5000.md3 exports documented. MAIDEntryPoint 16-case switch, NkCtrlEntry mangled C++ signature, NkMDCtrlEntry 4-case switch.
- **Transport architecture decoded**: Three-layer vtable dispatch (scanner → abstract transport → inner concrete → NkDriverEntry fn ptr). Thunk at 0x100a47c0, wrapper at 0x100a48e0. "1200" protocol version.
- **INQUIRY command flow fully traced**: Factory at 0x100a4de0, dispatch at 0x100a5030, CDB builder at 0x100a4870/0x100aa5e0.
- **DEFINITIVE SCSI CATALOG**: 17 unique opcodes found across 22 CDB builder sites:
  - Standard (13): 0x00 TEST UNIT READY, 0x12 INQUIRY, 0x15 MODE SELECT, 0x16 RESERVE, 0x1A MODE SENSE, 0x1B SCAN, 0x1D SEND DIAGNOSTIC, 0x24 SET WINDOW, 0x25 GET WINDOW, 0x28 READ, 0x2A WRITE, 0x3B WRITE BUFFER, 0x3C READ BUFFER
  - Vendor (4): 0xC0, 0xC1, 0xE0, 0xE1
  - REQUEST SENSE (0x03) NOT present — handled by transport layer
- **Command class architecture**: Two builder patterns (vtable-based objects + inline), 10-entry vtables (40 bytes each), two base class groups (A=data-out, B=general).
- **2 KB docs created**: scsi-command-build.md (definitive catalog), maid-entrypoint.md (exports + transport)
- **Phase 2 progress**: 2/7 criteria met

### Key Findings
1. LS5000.md3 dynamically loads transport DLL — NOT a static import
2. CDB builders are clustered: 0x100aa1d0 (13 builders) and 0x100b51b0 (5 builders)
3. Each command class has its own vtable with CDB builder at entry[8] (offset +0x20)
4. Vendor opcodes 0xE0/0xE1 use sub-command byte at CDB[2] for differentiation
5. 0xC0/0xC1 are minimal (opcode-only) — likely scanner status/control primitives
6. READ(10)/SET WINDOW use control byte 0x80 (vendor bit), WRITE does not

### Next Steps
- Annotate each NkDriverEntry callsite with purpose/data direction
- Map MAID capability IDs to SCSI commands (MAIDEntryPoint dispatch → handler → SCSI call)
- Write individual SCSI command docs in docs/kb/scsi-commands/
- Cross-model .md3 comparison (LS4000/LS5000/LS8000/LS9000)

## 2026-02-21 -- Session 5: Phase 2 — Data Direction Analysis & Vendor Commands

### Goals
- Annotate all NkDriverEntry callsites with data direction
- Complete individual SCSI command docs
- Progress toward Phase 2 completion

### Accomplished
- **Vtable base correction**: CDB builder at vtable[9] (+0x24), NOT vtable[8] (+0x20). Previous analysis was 4 bytes off.
- **All 16 command factories traced**: Direction encoding verified — push 1=data-in, push 2=data-out, no push=no data phase
- **Core execute function (0x100ae3c0)**: CommandParams structure fully documented
- **NkDriverEntry FC usage**: FC1 at 0x100a45dc, FC2 at 0x100a4694, FC3 at 0x100a472b. All SCSI commands use FC5.
- **Group A vs B**: NOT about data direction — Group B adds retry on error 9 with 50ms delay
- **SCSI command catalog major rewrite**: scsi-command-build.md updated with corrected vtable layout, directions, factories, CommandParams
- **Vendor command docs written**: 0xE0, 0xE1, 0xC0, 0xC1 — all 4 vendor command KB docs created
- **Phase 2 COMPLETE**: 7/7 criteria met

### Key Findings
1. Two constructor types cleanly encode data direction at factory level
2. 0xE0 is data-OUT (focus, exposure control), 0xE1 is data-IN (sensor readback)
3. 0xC1 confirmed no-data-phase, 0xC0 factory not found in standard architecture
4. All 17 commands now have verified direction and purpose

### Next Steps
- Begin Phase 3: NikonScan4.ds TWAIN layer analysis
- Full MAID numeric capability ID mapping (deferred from Phase 2 to Phase 3)
- Scan workflow orchestration documentation
