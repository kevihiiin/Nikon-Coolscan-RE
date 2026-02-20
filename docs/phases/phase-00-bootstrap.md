# Phase 0: Project Bootstrap & Tooling

## Goal
Set up the complete project infrastructure: git repo, directory structure, Ghidra projects with all binaries imported, H8/300H support installed, analysis scripts written, and initial KB docs.

## Completion Criteria
All must be met to mark phase complete:
- [ ] Git repo initialized with full directory structure committed
- [ ] At least one H8/300H SLEIGH module builds and can disassemble the firmware reset vector (0x100) correctly
- [ ] All 13 PE32 binaries imported into Ghidra projects with auto-analysis complete (no import errors)
- [ ] Firmware imported into Ghidra CoolscanFirmware project with H8/300H processor
- [ ] r2 `firmware_init.r2` script runs without error and labels vector table + known strings
- [ ] PE export extraction script produces CSV for all DLLs
- [ ] RTTI extraction script recovers class names from at least NKDUSCAN.dll
- [ ] `docs/kb/architecture/system-overview.md` and `docs/kb/architecture/software-layers.md` written
- [ ] `docs/log/general.md` and `docs/log/phases/phase-00-setup.md` initialized

## Targets

| Binary | Path | Ghidra Project | Processor |
|--------|------|----------------|-----------|
| NKDUSCAN.dll | Drivers/NKDUSCAN.dll | NikonScan_Drivers | x86:LE:32 |
| NKDSBP2.dll | Drivers/NKDSBP2.dll | NikonScan_Drivers | x86:LE:32 |
| ICEDLL.dll | Drivers/ICEDLL.dll | NikonScan_ICE | x86:LE:32 |
| ICENKNL1.dll | Drivers/ICENKNL1.dll | NikonScan_ICE | x86:LE:32 |
| ICENKNX2.dll | Drivers/ICENKNX2.dll | NikonScan_ICE | x86:LE:32 |
| LS4000.md3 | Module_E/LS4000.md3 | NikonScan_Modules | x86:LE:32 |
| LS5000.md3 | Module_E/LS5000.md3 | NikonScan_Modules | x86:LE:32 |
| LS8000.md3 | Module_E/LS8000.md3 | NikonScan_Modules | x86:LE:32 |
| LS9000.md3 | Module_E/LS9000.md3 | NikonScan_Modules | x86:LE:32 |
| NikonScan4.ds | Twain_Source/NikonScan4.ds | NikonScan_TWAIN | x86:LE:32 |
| DRAGNKL1.dll | Twain_Source/DRAGNKL1.dll | NikonScan_TWAIN | x86:LE:32 |
| DRAGNKX2.dll | Twain_Source/DRAGNKX2.dll | NikonScan_TWAIN | x86:LE:32 |
| Firmware | binaries/firmware/Nikon LS-50 MBM29F400B TSOP48.bin | CoolscanFirmware | H8/300H |

All PE32 binary paths are relative to `binaries/software/NikonScan403_installed/`.

## Methodology (Step by Step)

### Step 1: Git Repository & Directory Structure
**What to do**: `git init`, create all directories per the project structure plan, write `.gitignore`.
**Output**: Clean git repo with all dirs, `.gitkeep` files in empty dirs.

### Step 2: Write CLAUDE.md
**What to do**: Create the bootstrap document at project root per the plan specification.
**Output**: `CLAUDE.md` with full project context, methodology, rules, and quick reference.

### Step 3: Install H8/300H SLEIGH Module
**What to do**: Clone and build a Ghidra SLEIGH module for H8/300H. Two candidates:
- [carllom/sleigh-h8](https://github.com/carllom/sleigh-h8) -- H8/300 + H8/300H, 24-bit
- [shiz/ghidra-h8-300](https://codeberg.org/shiz/ghidra-h8-300) -- actively maintained (Apr 2025)
**What to look for**: Correct 24-bit addressing, big-endian, proper register naming (ER0-ER7, R0-R7, R0H/R0L).
**How to verify**: Import firmware, disassemble at 0x100 (reset vector entry), check instruction decode makes sense.
**Output**: Working H8/300H extension in Ghidra, documented in `tools/README.md`.

### Step 4: Bootstrap Ghidra Projects (Headless Import)
**What to do**: Write `scripts/shell/bootstrap_ghidra.sh` that uses `analyzeHeadless` to:
- Import all 12 PE32 binaries into 4 projects (Drivers, Modules, TWAIN, ICE)
- Import firmware into CoolscanFirmware project with H8/300H processor
- Run auto-analysis on all
**What to look for**: No import errors, successful analysis completion.
**Output**: Populated Ghidra project directories, import log.

### Step 5: Create r2 Firmware Init Script
**What to do**: Write `r2/scripts/firmware_init.r2` that:
- Sets architecture to H8/300H big-endian
- Maps memory regions (flash, RAM, ISP1581, ASIC RAM)
- Labels all 64 vector table entries (0x000-0x0FF)
- Adds flags for known string locations
- Seeks to reset vector entry point
**What to look for**: Vector table at 0x000, reset vector at entry 0 (offset 0x000), entry point at 0x100.
**Output**: Script that bootstraps r2 analysis of the firmware.

### Step 6: Write Python Analysis Scripts
**What to do**: Create three scripts:
1. `scripts/python/extract_pe_exports.py` -- Parse PE export tables, output CSV (name, ordinal, RVA)
2. `scripts/python/extract_rtti.py` -- Find MSVC RTTI structures (`.?AV` prefix), recover class hierarchy
3. `scripts/python/parse_vector_table.py` -- Parse H8/300H vector table from firmware (64 x 4-byte entries)
**What to look for**: pefile library for PE parsing. RTTI: search for `.?AV` strings, follow `RTTICompleteObjectLocator` chains.
**Output**: Scripts + CSV/JSON output in `ghidra/exports/`.

### Step 7: Write Initial KB Docs
**What to do**: Create:
- `docs/kb/architecture/system-overview.md` -- Hardware + software architecture
- `docs/kb/architecture/software-layers.md` -- Call chain from TWAIN to firmware
**Output**: Populated KB architecture docs with Status: Draft.

### Step 8: Initialize Log Files
**What to do**: Create all log files with proper headers:
- `docs/log/general.md` -- with current phase, session template
- `docs/log/strategy.md` -- with active strategies section
- `docs/log/phases/phase-00-setup.md` -- with phase 0 attempt log
**Output**: All log files ready for append.

## Key Addresses / Patterns

### Firmware Vector Table (H8/300H)
- 0x000000-0x0000FF: 64 interrupt vectors (4 bytes each, big-endian addresses)
- Vector 0 (0x000): Reset vector (power-on entry point)
- Vector 7 (0x01C): NMI
- Vector 12-23: External interrupts (IRQ0-IRQ5, WOVI, CMI, ADI, etc.)

### Key Firmware Strings (from prior recon)
- "Nikon   LS-50 ED        1.02" -- SCSI INQUIRY response
- "SCSI" references throughout main firmware region

### PE Binary Patterns
- RTTI: Search for `.?AV` prefix in .rdata sections
- DeviceIoControl: Import from kernel32.dll in NKDUSCAN.dll
- NkDriverEntry: Single export from NKDUSCAN.dll and NKDSBP2.dll

## Prerequisite Knowledge
None -- this is the first phase.

## KB Deliverables
- `docs/kb/architecture/system-overview.md`
- `docs/kb/architecture/software-layers.md`

## Log Files
- Phase log: `docs/log/phases/phase-00-setup.md`
- General log: `docs/log/general.md`
- Strategy log: `docs/log/strategy.md`
