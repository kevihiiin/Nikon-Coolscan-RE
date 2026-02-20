# Phase 5: Protocol Specification Assembly

## Goal
Combine host-side (Phases 1-3) and device-side (Phase 4) findings into a complete, implementation-ready SCSI protocol specification.

## Completion Criteria
All must be met to mark phase complete:
- [ ] Every SCSI command found in Phase 2 has a complete spec: CDB layout, data phase format, parameter semantics, error responses
- [ ] Host-side and device-side findings cross-validated for every command (no contradictions)
- [ ] Vendor-specific commands documented with same rigor as standard commands
- [ ] Sense code / error response catalog complete
- [ ] USB wrapping protocol spec is implementation-ready (someone could write a driver from it)
- [ ] Complete scan workflow sequences documented with exact SCSI command bytes
- [ ] Protocol spec reviewed for internal consistency

## Methodology (Step by Step)

### Step 1: Command Inventory & Gap Analysis
**What to do**: Create a master list of all SCSI commands found across all phases.
**What to look for**:
- Commands found in Phase 2 (host-side) but not yet verified in Phase 4 (device-side)
- Commands found in Phase 4 but not triggered by any known host-side code path
- Commands with incomplete documentation (missing CDB byte meanings, unknown parameters)
**Output**: Gap analysis document, list of items needing further work

### Step 2: Per-Command Spec Completion
**What to do**: For each SCSI command, produce a complete specification.
**Format for each command doc**:
```
# [Command Name] (Opcode 0xNN)
**Type**: Standard / Vendor-Specific
**CDB Length**: N bytes
**Data Phase**: None / Data-In / Data-Out
**Status**: Verified / High / Medium

## CDB Layout
| Byte | Bits | Field | Description |
|------|------|-------|-------------|
| 0 | 7-0 | Opcode | 0xNN |
| 1 | 7-5 | LUN | Logical Unit Number |
| ... | ... | ... | ... |

## Data Phase
[If data-in]: Response format (struct layout)
[If data-out]: Request format

## Parameters
[Detailed description of each parameter, valid ranges, defaults]

## Usage Context
[When is this command sent? What workflow is it part of?]

## Error Responses
[Sense key / ASC / ASCQ values this command can return]

## Evidence
[Host-side: DLL:offset, Device-side: firmware:offset]
```
**Output**: Updated `docs/kb/scsi-commands/` docs to spec quality

### Step 3: Vendor-Specific Command Deep Dive
**What to do**: Ensure all Nikon vendor-specific commands (0xC0-0xFF) are fully documented.
**What to look for**: These are the most valuable part of the spec -- they're undocumented by any standard.
**Output**: Complete `docs/kb/scsi-commands/vendor-specific/` directory

### Step 4: Sense Code Catalog
**What to do**: Document all sense data / error responses.
**What to look for**:
- Sense Key values used by the scanner
- Additional Sense Code (ASC) / Additional Sense Code Qualifier (ASCQ) pairs
- When each error occurs (from firmware analysis)
- How the host driver handles each error
**Output**: `docs/kb/scsi-commands/sense-codes.md`

### Step 5: USB Protocol Finalization
**What to do**: Finalize the USB wrapping protocol spec from Phase 1.
**What to look for**:
- Complete packet format for each phase (command, data-in, data-out, status)
- Timing requirements or timeouts
- Error recovery procedures
- Endpoint configuration
**Output**: Final `docs/kb/architecture/usb-protocol.md` -- implementation-ready

### Step 6: Workflow Sequences with Hex Bytes
**What to do**: Document complete scan workflows as exact byte sequences.
**What to look for**: For each workflow (init, preview, scan, autofocus, eject), produce:
- Ordered list of SCSI commands with exact CDB hex bytes
- Expected responses (hex bytes)
- Timing between commands (if critical)
**Output**: `docs/kb/components/nikonscan4-ds/scan-workflow.md` updated with hex-level detail

### Step 7: Internal Consistency Review
**What to do**: Review the complete protocol spec for contradictions.
**What to look for**:
- Parameters documented differently in different places
- Missing cross-references
- Contradictions between host and device analysis
- Completeness: can a developer actually build a driver from this?
**Output**: Fix all inconsistencies, mark all docs as "Complete" or "Verified"

## Prerequisite Knowledge
- All Phase 1-4 KB docs

## KB Deliverables
- All `docs/kb/scsi-commands/` docs at spec quality
- `docs/kb/scsi-commands/sense-codes.md`
- Finalized `docs/kb/architecture/usb-protocol.md`
- Updated `docs/kb/components/nikonscan4-ds/scan-workflow.md` with hex-level detail

## Log Files
- Phase log: `docs/log/phases/phase-05-protocol-spec.md`
