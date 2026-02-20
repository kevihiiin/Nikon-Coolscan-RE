# Coolscan RE -- Project Context for Claude

## What This Project Is

Reverse engineering Nikon Coolscan film scanner firmware and Windows drivers to document
the complete SCSI communication protocol. End goal: build modern cross-platform drivers.

**Primary target**: Coolscan V (LS-50). Later: LS-5000, LS-8000, LS-9000.

## Session Bootstrap (READ THESE IN ORDER)

Every new session, follow this chain:

1. **You are here** -- `CLAUDE.md` (this file) gives you project context
2. **Read `logs/general.md` header** -- tells you current phase and what to work on next
3. **Read `docs/phases/phase-NN-<name>.md`** for the current phase -- contains:
   - Completion criteria (checklist of what "done" means)
   - Detailed methodology (what to analyze, in what order)
   - Key files and addresses to examine
   - What to look for and where
4. **Read `logs/phases/phase-NN-<name>.md`** -- the phase attempt log, tells you what was already tried
5. **Read relevant `logs/components/NAME-attempts.md`** -- what was already found for the binary you're working on
6. **Read relevant `kb/` docs** -- existing findings to build upon

Only then begin work.

## Work-Log-Verify Workflow (CRITICAL)

For EVERY unit of work (analyzing a function, tracing a code path, identifying a command), follow this cycle:

### 1. WORK -- Perform the analysis
Do the actual RE work: decompile, trace, pattern match, cross-reference.

### 2. LOG -- Record what you did and found (even failures!)
- **Append** to the relevant component log (`logs/components/NAME-attempts.md`)
- Include: date, tool used, target (function/address), what you tried, what you found, confidence level
- **Failed attempts are equally important** -- log what didn't work and why, so we don't repeat it
- Update the phase log (`logs/phases/`) with progress

### 3. VERIFY -- Cross-check the finding
- Can this be confirmed from another source? (host-side vs device-side, string xref, etc.)
- Set confidence level: Verified (2+ sources), High (clear evidence), Medium (reasonable), Low (speculative)

### 4. KB -- Write it up
- **ALL new knowledge MUST go to `kb/`** -- the KB is our final deliverable
- KB docs must be comprehensive enough that a **junior developer** could understand them
- Explain the "why" not just the "what" -- why does this SCSI command exist? What problem does it solve?
- Include hex dumps, decompiled code snippets, diagrams where they help understanding
- Cross-reference related KB docs with links

If a finding is too uncertain (Low confidence), still add it to KB but mark it clearly and list what would be needed to verify it.

## Project Layout

- `CLAUDE.md` -- THIS FILE. Bootstrap for every Claude session
- `docs/phases/` -- **Phase instruction docs** (one per phase, contains completion criteria + methodology)
- `binaries/` -- Original firmware + NikonScan 4.03 files (**READ ONLY, never modify**)
- `ghidra/projects/` -- Ghidra project dirs (NikonScan_Drivers, _Modules, _TWAIN, _ICE, CoolscanFirmware)
- `ghidra/scripts/` -- Ghidra Python/Java analysis scripts
- `ghidra/exports/` -- Exported function lists, decompiled code snapshots
- `r2/scripts/` -- radare2 analysis scripts (firmware_init.r2 etc.)
- `scripts/python/` -- PE analysis, RTTI extraction, SCSI pattern matching scripts
- `scripts/shell/` -- bootstrap_ghidra.sh and other shell scripts
- `kb/` -- **Knowledge base (ALL findings go here)** -- this is our final output
- `logs/` -- Progress and attempt logs (**APPEND ONLY** - see rules below)
- `tools/` -- Third-party tools (Ghidra H8/300H SLEIGH module etc.)

## Key Binaries (by RE priority)

Full path prefix: `binaries/software/NikonScan403_installed/`

1. `Drivers/NKDUSCAN.dll` (90KB) -- USB transport layer
   - Exports: `NkDriverEntry`. Classes: CUSB2Command, CUSBSession, CUSBDeviceTable
   - Uses DeviceIoControl -> usbscan.sys to send SCSI over USB
   - **Ghidra project**: NikonScan_Drivers

2. `Module_E/LS5000.md3` (1MB) -- Scanner model module
   - Exports: MAIDEntryPoint, NkCtrlEntry, NkMDCtrlEntry
   - Constructs SCSI CDBs, calls NkDriverEntry to send them
   - **Ghidra project**: NikonScan_Modules

3. `Twain_Source/NikonScan4.ds` (2.3MB) -- TWAIN data source
   - Full scan workflow: preview, scan, autofocus, calibrate
   - Maps UI settings to MAID capabilities to SCSI commands
   - **Ghidra project**: NikonScan_TWAIN

4. **Firmware**: `binaries/firmware/Nikon LS-50 MBM29F400B TSOP48.bin` (512KB)
   - CPU: Hitachi H8/3003 (H8/300H, 24-bit, big-endian)
   - Handles SCSI commands device-side, controls motors/lamp/CCD
   - **Ghidra project**: CoolscanFirmware (H8/300H processor)
   - **r2 script**: r2/scripts/firmware_init.r2

5. `Drivers/NKDSBP2.dll` (86KB) -- IEEE1394/SBP2 transport
   - Same NkDriverEntry interface as NKDUSCAN but for FireWire
   - **Ghidra project**: NikonScan_Drivers

## Architecture (call chain)

```
NikonScan4.ds (TWAIN) -> LS5000.md3 (MAID) -> NKDUSCAN.dll (USB) -> usbscan.sys -> USB bulk -> scanner firmware (H8/3003)
```

USB wraps SCSI: CDB via bulk-out, phase query opcode 0xD0, sense retrieval opcode 0x06.

## Phases

Each phase has a dedicated instruction doc at `docs/phases/phase-NN-<name>.md` containing
completion criteria, methodology, key targets, and what to look for.

| Phase | Name | Phase Doc | Primary Target |
|-------|------|-----------|----------------|
| 0 | Bootstrap & Tooling | `docs/phases/phase-00-bootstrap.md` | Project setup |
| 1 | USB Transport | `docs/phases/phase-01-nkduscan.md` | NKDUSCAN.dll |
| 2 | SCSI Commands | `docs/phases/phase-02-ls5000.md` | LS5000.md3 |
| 3 | Scan Workflows | `docs/phases/phase-03-nikonscan4.md` | NikonScan4.ds |
| 4 | Firmware | `docs/phases/phase-04-firmware.md` | LS-50 firmware |
| 5 | Protocol Spec | `docs/phases/phase-05-protocol-spec.md` | Cross-validation |
| 6 | DRAG/ICE | `docs/phases/phase-06-drag-ice.md` | Image processing DLLs |
| 7 | Cross-Model | `docs/phases/phase-07-cross-model.md` | Other scanner models |

**Read the current phase doc before starting work.**

## RE Approach

### Two-sided convergence
We RE from both host (Windows DLLs, Phases 1-3) and device (firmware, Phase 4) simultaneously.
A finding is only **"Verified"** when confirmed from both sides.

### Analysis order within any binary
1. Exports/imports -> 2. RTTI/class names -> 3. String xrefs -> 4. Known entry points -> 5. Pattern matching -> 6. Full reversal of key functions

### Confidence levels
- **Verified**: Cross-referenced from 2+ sources (host CDB matches firmware handler)
- **High**: Strong evidence from single source (clear decompilation, unambiguous strings)
- **Medium**: Reasonable inference, not fully confirmed
- **Low**: Speculation -- needs verification. Still log and KB it, but mark clearly

### When stuck
1. Log what was tried and what failed (component attempt log)
2. Mark KB entry with `Confidence: Low` + open questions
3. Move on -- other components often clarify things later
4. Add a "REVISIT" note in the phase log

## Tools

- **Ghidra** at `/opt/ghidra` -- PE32 DLLs (x86:LE:32) and firmware (H8/300H via SLEIGH module)
  - Headless: `/opt/ghidra/support/analyzeHeadless`
  - Projects: `ghidra/projects/`
  - Scripts: `ghidra/scripts/`
- **radare2** -- Firmware analysis (`r2 -e asm.arch=h8300`)
- **Python scripts** in `scripts/python/` -- PE parsing, RTTI extraction, pattern matching
- **binwalk, strings, xxd, objdump, file** -- Standard binary analysis

## Logging Rules (CRITICAL)

**All log files are APPEND ONLY.** Never delete or edit past entries.

The ONLY editable part is the status header at the top (above the `---` separator).
Everything below the separator is an immutable chronological record.

**Log EVERY attempt, including failures.** A failed attempt is valuable -- it prevents
repeating the same dead end and may provide clues for a different approach.

Log locations:
- `logs/general.md` -- Session journal (date, goals, accomplished, blockers, next steps)
- `logs/strategy.md` -- Evolving RE tactics (what works, tool tips, reusable patterns)
- `logs/phases/phase-NN-name.md` -- Per-phase attempt log
- `logs/components/NAME-attempts.md` -- Per-binary analysis history

## KB Rules (THIS IS OUR FINAL OUTPUT)

The `kb/` directory is the entire point of this project. It must be **comprehensive enough
that a junior developer can understand the Coolscan SCSI protocol** and write a driver from it.

Rules:
- **ALL new knowledge MUST go to `kb/`** -- findings that only exist in logs or conversation are lost
- Every KB doc has: Status, Last Updated, Phase, Confidence level
- Explain the "why" not just the "what" -- context matters for driver writers
- Include hex dumps, decompiled snippets, diagrams where they help understanding
- Evidence must cite source: `NKDUSCAN.dll:0x1234` or `firmware:0x20100`
- Cross-reference with relative links: `[USB Protocol](../architecture/usb-protocol.md)`
- When in doubt, write MORE detail, not less

KB structure:
- `kb/architecture/` -- System overview, software layers, USB protocol, MAID interface
- `kb/scsi-commands/` -- Per-command docs (the crown jewel for driver writers)
- `kb/components/` -- Deep analysis per binary (nkduscan/, ls5000-md3/, firmware/, etc.)
- `kb/scanners/` -- Per-model notes (coolscan-v-ls50, super-coolscan-5000, etc.)
- `kb/reference/` -- CPU reference, chip datasheets, spec summaries

## Subagent Usage

Use subagents to parallelize:
- `general-purpose` -- Multi-binary search, web research, correlation
- `Bash` -- Ghidra headless, r2 batch, Python scripts (use run_in_background for long jobs)
- `feature-dev:code-explorer` -- Trace decompiled code paths, map class hierarchies

Rules:
- Always give subagents specific file paths and targets
- Subagent results MUST be written to KB files (not just reported in conversation)
- Subagent work MUST be logged in the appropriate component/phase log

## Hardware Quick Reference

- CPU: Hitachi H8/3003 (H8/300H family), 24-bit address, big-endian
- Flash: MBM29F400BC, 512KB NOR, TSOP48
- USB controller: Philips ISP1581, mapped at 0x600000
- RAM: 128KB at 0x400000, 256KB ASIC DSL RAM at 0x800000, 64KB buffer at 0xC00000
- GPIO: PB4-7=film motor, PC3-5=adapter ID, PC6=door sensor, PC7=adapter detect
- USB: VID 04B0, PID 4001 (LS-50), 4002 (LS-5000)
- SCSI INQUIRY: "Nikon   LS-50 ED        1.02"

## Firmware Flash Layout

| Offset | Size | Purpose |
|--------|------|---------|
| 0x00000 | 0x4000 | Vector table + startup |
| 0x04000 | 0x2000 | Bootloader flags |
| 0x06000 | 0x2000 | Settings |
| 0x08000 | 0x8000 | Extended settings |
| 0x10000 | 0x10000 | Recovery firmware |
| 0x20000 | 0x40000 | Main firmware |
| 0x60000 | 0x20000 | Logging |

## Naming Conventions for Reversed Symbols

- Prefix with component: `usb_`, `scsi_`, `maid_`, `fw_`, `ice_`
- Descriptive: `usb_send_scsi_command`, `scsi_build_set_window_cdb`
- Unknown: `usb_unk_0x1234` (component + address) until purpose is clear
- Data tables: `tbl_scsi_dispatch`, `tbl_adapter_ids`, `tbl_motor_params`
