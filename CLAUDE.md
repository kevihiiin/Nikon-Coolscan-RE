# Coolscan RE -- Project Context for Claude

## What This Project Is

Reverse engineering Nikon Coolscan film scanner firmware and Windows drivers to document
the complete SCSI communication protocol. End goal: build modern cross-platform drivers.

**Primary target**: Coolscan V (LS-50, uses LS5000.md3 module). Later: LS-5000, LS-4000, LS-8000, LS-9000.

## Session Bootstrap (READ THESE IN ORDER)

Every new session, follow this chain:

1. **You are here** -- `CLAUDE.md` (this file) gives you project context
2. **Read `docs/log/general.md` header** -- tells you current phase and what to work on next
3. **Read `docs/phases/phase-NN-<name>.md`** for the current phase -- contains:
   - Completion criteria (checklist of what "done" means)
   - Detailed methodology (what to analyze, in what order)
   - Key files and addresses to examine
   - What to look for and where
4. **Read `docs/log/phases/phase-NN-<name>.md`** -- the phase attempt log, tells you what was already tried
5. **Read relevant `docs/log/components/NAME-attempts.md`** -- what was already found for the binary you're working on
6. **Read relevant `docs/kb/` docs** -- existing findings to build upon

Only then begin work.

## Work-Log-Verify Workflow (CRITICAL)

For EVERY unit of work (analyzing a function, tracing a code path, identifying a command), follow this cycle:

### 1. WORK -- Perform the analysis
Do the actual RE work: decompile, trace, pattern match, cross-reference.

### 2. LOG -- Record what you did and found (even failures!)
- **Append** to the relevant component log (`docs/log/components/NAME-attempts.md`)
- Include: date, tool used, target (function/address), what you tried, what you found, confidence level
- **Failed attempts are equally important** -- log what didn't work and why, so we don't repeat it
- Update the phase log (`docs/log/phases/`) with progress

### 3. VERIFY -- Cross-check the finding
- Can this be confirmed from another source? (host-side vs device-side, string xref, etc.)
- Set confidence level (see RE Approach below)

### 4. KB -- Write it up
- **ALL new knowledge MUST go to `docs/kb/`** -- the KB is our final deliverable
- KB docs must be comprehensive enough that a **junior developer** could understand them
- Explain the "why" not just the "what" -- why does this SCSI command exist? What problem does it solve?
- Include hex dumps, decompiled code snippets, diagrams where they help understanding
- Cross-reference related KB docs with links

If a finding is too uncertain (Low confidence), still add it to KB but mark it clearly and list what would be needed to verify it.

## Project Layout

- `CLAUDE.md` -- THIS FILE. Bootstrap for every Claude session
- `ARCHITECTURE.md` -- Call-chain overview, links to detailed KB docs
- `docs/` -- **All model-written documentation**
  - `docs/phases/` -- Phase instruction docs (completion criteria + methodology)
  - `docs/kb/` -- **Knowledge base (ALL findings go here)** -- this is our final output
  - `docs/log/` -- Progress and attempt logs (**APPEND ONLY** - see rules below)
- `binaries/` -- Original firmware + NikonScan 4.03 files (**READ ONLY, never modify**)
- `ghidra/projects/` -- Ghidra project dirs (NikonScan_Drivers, _Modules, _TWAIN, _ICE, CoolscanFirmware)
- `ghidra/scripts/` -- Ghidra Python/Java analysis scripts
- `ghidra/exports/` -- Exported function lists, decompiled code snapshots
- `r2/scripts/` -- radare2 analysis scripts (firmware_init.r2 etc.)
- `scripts/python/` -- PE analysis, RTTI extraction, SCSI pattern matching scripts
- `scripts/shell/` -- bootstrap_ghidra.sh and other shell scripts
- `.claude/skills/` -- RE-specific slash command skills
- `tools/` -- Third-party tools (Ghidra H8/300H SLEIGH module etc.)

## Key Binaries (by RE priority)

Full path prefix: `binaries/software/NikonScan403_installed/`

1. `Drivers/NKDUSCAN.dll` (88KB) -- USB transport layer (LS-40, LS-50, LS-5000)
   - Exports: `NkDriverEntry` (1 export, 9 function codes). 14 RTTI classes.
   - Key classes: CUSB2Command, CUSBSession, CUSBDeviceTable, CUSBDevInfo, CSBP2CommandManager
   - Uses DeviceIoControl -> usbscan.sys, WriteFile/ReadFile on bulk pipes
   - **Ghidra project**: NikonScan_Drivers

2. `Module_E/LS5000.md3` (1MB) -- Scanner model module (shared by LS-50 + LS-5000)
   - Exports: MAIDEntryPoint, NkCtrlEntry, NkMDCtrlEntry
   - Loads transport DLL at runtime (LoadLibraryA/GetProcAddress, NOT static import)
   - Constructs SCSI CDBs, calls NkDriverEntry to send them
   - **Ghidra project**: NikonScan_Modules
   - **Note**: No LS50.md3 exists. LS-50 and LS-5000 share this module.

3. `Twain_Source/NikonScan4.ds` (2.2MB) -- TWAIN data source
   - 59 exports (DS_Entry + scanner-specific API: StartScan, GetSource, etc.)
   - 321 RTTI classes (MFC 7.0 based). Full scan workflow orchestration.
   - Model-agnostic: delegates all hardware specifics to .md3 modules
   - **Ghidra project**: NikonScan_TWAIN

4. **Firmware**: `binaries/firmware/Nikon LS-50 MBM29F400B TSOP48.bin` (512KB)
   - CPU: Hitachi H8/3003 (H8/300H, 24-bit, big-endian)
   - Contains INQUIRY strings for both "LS-50 ED" and "LS-5000" (shared lineage)
   - Handles SCSI commands device-side, controls motors/lamp/CCD
   - **Ghidra project**: CoolscanFirmware (H8/300H processor)
   - **r2 script**: r2/scripts/firmware_init.r2

5. `Drivers/NKDSBP2.dll` (84KB) -- IEEE1394/SBP2 transport (LS-4000, LS-8000, LS-9000)
   - Same NkDriverEntry interface as NKDUSCAN but for FireWire (SBP-2 over 1394)
   - 13 RTTI classes: CSBP2CommandManager, CSBP2Command, CSBP2Session, CSBP2Device, etc.
   - **Ghidra project**: NikonScan_Drivers

## Architecture (call chain)

```
NikonScan4.ds (TWAIN) -> LS5000.md3 (MAID) -> NKDUSCAN.dll (USB) -> usbscan.sys -> USB bulk -> scanner firmware (H8/3003)
```

USB wraps SCSI: CDB via bulk-out, phase query opcode 0xD0, sense retrieval opcode 0x06.
(Verified from NKDUSCAN.dll disassembly @ 0x10002b50. NOT USB Mass Storage — custom vendor protocol.)

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
Log the failure, mark KB as Low confidence, add REVISIT to phase log, and move on. Use `/unstuck` for suggestions.

## Tools

- **uv** for Python -- Use `uv run` to execute Python scripts (deps in `pyproject.toml`)
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
- `docs/log/general.md` -- Session journal (date, goals, accomplished, blockers, next steps)
- `docs/log/strategy.md` -- Evolving RE tactics (what works, tool tips, reusable patterns)
- `docs/log/phases/phase-NN-name.md` -- Per-phase attempt log
- `docs/log/components/NAME-attempts.md` -- Per-binary analysis history

## KB Rules (THIS IS OUR FINAL OUTPUT)

The `docs/kb/` directory is the entire point of this project. It must be **comprehensive enough
that a junior developer can understand the Coolscan SCSI protocol** and write a driver from it.

Rules:
- **ALL new knowledge MUST go to `docs/kb/`** -- findings only in logs or conversation are lost
- Every KB doc has: Status, Last Updated, Phase, Confidence level
- Explain "why" not just "what". Cite source: `BINARY:0xADDRESS`. Cross-reference with relative links.
- When in doubt, write MORE detail, not less. Use `/update-kb` skill for proper format.

KB structure:
- `docs/kb/architecture/` -- System overview, software layers, USB protocol, MAID interface
- `docs/kb/scsi-commands/` -- Per-command docs (the crown jewel for driver writers)
- `docs/kb/components/` -- Deep analysis per binary (nkduscan/, ls5000-md3/, firmware/, etc.)
- `docs/kb/scanners/` -- Per-model notes (coolscan-v-ls50, super-coolscan-5000, etc.)
- `docs/kb/reference/` -- CPU reference, chip datasheets, spec summaries

## Skills & Subagents

RE-specific slash commands in `.claude/skills/`. Skills run in main context; subagents fork to keep main context lean.

| Command | Type | Purpose |
|---------|------|---------|
| `/log-finding [component]` | skill | Append finding to component + phase log |
| `/update-kb [path]` | skill | Create/update KB doc with proper format |
| `/unstuck` | subagent | Suggest next steps from logs + KB gaps |
| `/xref [pattern]` | subagent | Search pattern across all binaries |
| `/phase-check [N]` | subagent | Check phase completion |
| `/verify [kb-doc]` | subagent | Cross-validate host vs device side |
| `/ghidra-run [proj] [script]` | background | Run Ghidra headless |
| `/prefetch-refs [N]` | background | Gather reference material |

Auto-launch subagents when: analyzing an opcode (xref other binaries), documenting a CDB (verify against firmware), or running Ghidra scripts.

## Scanner Models (from INF files — ground truth)

USB only (NKDUSCAN.dll): LS-40 (PID 4000), LS-50 (PID 4001), LS-5000 (PID 4002)
FireWire only (NKDSBP2.dll): LS-4000, LS-8000, LS-9000
**No model supports both USB and FireWire.**

Module mapping: LS4000.md3 (LS-40 + LS-4000), LS5000.md3 (LS-50 + LS-5000), LS8000.md3, LS9000.md3

## Quick Hardware Reference

See `docs/kb/reference/memory-map.md` and `docs/kb/reference/` for full details.
- CPU: H8/3003 (H8/300H), 24-bit, big-endian | USB: VID 04B0, PID 4001 (LS-50)
- Main firmware at flash 0x20000 | ISP1581 USB at 0x600000 | RAM at 0x400000
