# Phase 2: LS5000.md3 -- Scanner Model Module & SCSI Command Catalog

## Goal
Map all SCSI commands the scanner uses. Understand the MAID interface. Produce the definitive SCSI command catalog.

## Completion Criteria
All must be met to mark phase complete:
- [ ] All 3 exports (`MAIDEntryPoint`, `NkCtrlEntry`, `NkMDCtrlEntry`) decompiled with documented signatures
- [ ] Complete list of SCSI opcodes used, with CDB byte layout for each (standard + vendor-specific)
- [ ] Each `NkDriverEntry` callsite annotated with: opcode, CDB bytes, data direction, data format, purpose
- [ ] MAID capability ID -> SCSI command mapping table produced
- [ ] At least 80% of SCSI commands have individual docs in `kb/scsi-commands/`
- [ ] Quick comparison table of LS4000/LS5000/LS8000/LS9000.md3 differences (export count, size, unique strings)
- [ ] `kb/components/ls5000-md3/scsi-command-build.md` contains the definitive SCSI command catalog

## Targets

| Binary | Path | Ghidra Project | Size |
|--------|------|----------------|------|
| LS5000.md3 | binaries/software/NikonScan403_installed/Module_E/LS5000.md3 | NikonScan_Modules | ~1MB |
| LS4000.md3 | Module_E/LS4000.md3 | NikonScan_Modules | reference |
| LS8000.md3 | Module_E/LS8000.md3 | NikonScan_Modules | reference |
| LS9000.md3 | Module_E/LS9000.md3 | NikonScan_Modules | reference |

## Methodology (Step by Step)

### Step 1: Export Analysis
**What to do**: Analyze the 3 exports of LS5000.md3.
**What to look for**:
- `MAIDEntryPoint` -- MAID (Module Architecture for Imaging Devices) callback entry. Likely receives a capability ID and operation code.
- `?NkCtrlEntry@@YGFFFFPAX@Z` (mangled) = `NkCtrlEntry(short, short, short, short, void*)` -- control entry point
- `NkMDCtrlEntry` -- module device control entry
- Import of `NkDriverEntry` from NKDUSCAN.dll -- every call to this is a SCSI command send
**Where to look**: Start at each export address in Ghidra
**Output**: Documented function signatures in `kb/components/ls5000-md3/maid-entrypoint.md`

### Step 2: Find All NkDriverEntry Callsites
**What to do**: Find every location where LS5000.md3 calls `NkDriverEntry` (imported from NKDUSCAN.dll).
**What to look for**:
- The function code passed (from Phase 1 API docs)
- The SCSI CDB being constructed just before the call
- Parameters: CDB buffer, data buffer, data length, direction
- Each callsite represents one SCSI command being sent to the scanner
**Where to look**: Cross-references to the `NkDriverEntry` import in LS5000.md3
**Output**: Annotated callsite list, feeds into SCSI command catalog

### Step 3: SCSI CDB Pattern Extraction
**What to do**: At each NkDriverEntry callsite, extract the CDB being built.
**What to look for**:
- **Standard SCSI opcodes**: 0x00 (TEST UNIT READY), 0x03 (REQUEST SENSE), 0x12 (INQUIRY), 0x15 (MODE SELECT), 0x1A (MODE SENSE), 0x1B (SCAN), 0x24 (SET WINDOW), 0x25 (GET WINDOW), 0x28 (READ), 0x2A (WRITE)
- **Vendor-specific opcodes**: 0xC0-0xFF range -- these are Nikon-proprietary
- CDB structure: opcode byte, LUN bits, parameter bytes, control byte
- Data phase: direction (in/out/none), buffer format, length calculation
**Where to look**: Code immediately before NkDriverEntry calls -- look for buffer fill patterns
**Output**: Per-opcode CDB layout documentation in `kb/scsi-commands/`

### Step 4: MAID Capability Mapping
**What to do**: Map MAID capability IDs to the SCSI commands they trigger.
**What to look for**:
- MAID capability IDs are likely numeric constants (e.g., resolution, bit depth, scan area, exposure)
- `MAIDEntryPoint` dispatch table: capability ID -> handler function -> NkDriverEntry call(s)
- Some capabilities may trigger multiple SCSI commands in sequence
- Group: read-only capabilities (GET queries) vs write capabilities (SET commands)
**Where to look**: `MAIDEntryPoint` dispatch logic, handler functions
**Output**: Capability mapping table in `kb/components/ls5000-md3/maid-entrypoint.md`

### Step 5: Document Individual SCSI Commands
**What to do**: For each SCSI opcode found, create a detailed per-command KB document.
**What to look for per command**:
- Complete CDB byte layout (byte 0 = opcode, bytes 1-N = parameters)
- Data phase: direction, format (struct layout for multi-byte responses), length
- Parameter meaning: what each CDB byte controls
- Context: when is this command used (init, preview, scan, calibrate, etc.)
- Response: what the scanner returns (for data-in commands)
**Output**: Individual docs in `kb/scsi-commands/` (e.g., `inquiry.md`, `set-window.md`, `vendor-specific/nikon-e1.md`)

### Step 6: Cross-Model Comparison (Quick)
**What to do**: Quick comparison of all 4 .md3 modules.
**What to look for**:
- Export count and names (all should have same 3 exports)
- File sizes (indicates complexity difference)
- Unique strings per module (model names, firmware versions, etc.)
- Any unique SCSI opcodes not in LS5000
**Where to look**: Compare string dumps and export lists
**Output**: Comparison table in `kb/components/ls5000-md3/scsi-command-build.md`

## Key Addresses / Patterns

### Standard SCSI Opcodes (Scanner Device Type)
| Opcode | Name | CDB Length |
|--------|------|------------|
| 0x00 | TEST UNIT READY | 6 |
| 0x03 | REQUEST SENSE | 6 |
| 0x12 | INQUIRY | 6 |
| 0x15 | MODE SELECT(6) | 6 |
| 0x1A | MODE SENSE(6) | 6 |
| 0x1B | SCAN | 6 |
| 0x24 | SET WINDOW | 10 |
| 0x25 | GET WINDOW | 10 |
| 0x28 | READ(10) | 10 |
| 0x2A | SEND(10) | 10 |

### NkCtrlEntry Mangled Name
`?NkCtrlEntry@@YGFFFFPAX@Z` decodes to: `short __stdcall NkCtrlEntry(short, short, short, short, void*)`

### CDB Construction Pattern
Look for code like:
```
memset(cdb_buffer, 0, 10);  // or 6, 12, 16
cdb_buffer[0] = OPCODE;
cdb_buffer[1] = LUN << 5;
cdb_buffer[4] = length;     // or cdb_buffer[7..8] for 10-byte CDBs
```

## Prerequisite Knowledge
- Phase 1 `NkDriverEntry` API: `kb/components/nkduscan/api.md`
- Phase 1 USB protocol: `kb/architecture/usb-protocol.md`
- SCSI-2 Scanner device specification (SPC-2, SSC)

## KB Deliverables
- `kb/components/ls5000-md3/maid-entrypoint.md`
- `kb/components/ls5000-md3/scsi-command-build.md`
- `kb/scsi-commands/*.md` (one per opcode)
- Update `kb/architecture/software-layers.md` with MAID details

## Log Files
- Phase log: `logs/phases/phase-02-ls5000.md`
- Component logs: `logs/components/ls5000-attempts.md`
