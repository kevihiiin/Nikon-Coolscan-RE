# Phase 3: NikonScan4.ds -- TWAIN Source & Scan Workflow

## Goal
Map user operations (preview, scan, autofocus, calibrate) to SCSI command sequences. Understand the complete scan workflow from user action to wire protocol.

## Completion Criteria
All must be met to mark phase complete:
- [ ] TWAIN `DS_Entry` dispatch logic mapped: DG/DAT/MSG triplets -> internal handler functions
- [ ] Command queue architecture documented: class hierarchy, sequencing model, async behavior
- [ ] At least these scan workflows fully traced (MAID calls in order): initialization, preview scan, final scan, autofocus, film advance/eject
- [ ] Each workflow documented as a sequence of SCSI commands (referencing Phase 2 command catalog)
- [ ] UI parameter -> SCSI parameter mapping for: resolution, bit depth, color mode, scan area, film type, gain/offset
- [ ] `docs/kb/components/nikonscan4-ds/scan-workflow.md` is the definitive scan workflow reference

## Targets

| Binary | Path | Ghidra Project | Size |
|--------|------|----------------|------|
| NikonScan4.ds | binaries/software/NikonScan403_installed/Twain_Source/NikonScan4.ds | NikonScan_TWAIN | ~2.3MB |

## Methodology (Step by Step)

### Step 1: TWAIN DS_Entry Dispatch
**What to do**: Find and reverse the `DS_Entry` export (TWAIN data source entry point).
**What to look for**:
- TWAIN triplet dispatch: Data Group (DG), Data Argument Type (DAT), Message (MSG)
- Key triplets: DG_CONTROL/DAT_CAPABILITY/MSG_SET, DG_IMAGE/DAT_IMAGENATIVEXFER/MSG_GET
- Handler function for each supported triplet
- How TWAIN operations map to internal scan operations
**Where to look**: `DS_Entry` export, dispatch table/switch
**Output**: TWAIN triplet mapping table in `docs/kb/components/nikonscan4-ds/twain-dispatch.md`

### Step 2: Command Queue Architecture
**What to do**: Reverse the command queue classes.
**What to look for**:
- `CCommandQueue`: Base command queue -- how commands are enqueued, dequeued, executed
- `CStoppableCommandQueue`: Queue that supports cancellation
- `CProcessCommand`: Individual command in the queue
- Sequencing model: synchronous vs async, threading, command dependencies
- Error propagation: how a failed command affects the queue
**Where to look**: RTTI class names, constructor/destructor chains, virtual methods
**Output**: Class hierarchy and sequencing docs in `docs/kb/components/nikonscan4-ds/command-queue.md`

### Step 3: Scan Workflow Tracing
**What to do**: Trace complete workflows from TWAIN entry to MAID calls.
**What to look for per workflow**:

**Initialization workflow**:
- Device open, INQUIRY, TEST UNIT READY
- Firmware version query, capability negotiation
- Initial calibration if needed

**Preview scan workflow**:
- SET WINDOW (preview parameters: low res, full frame)
- SCAN command
- READ loop (bulk data transfer)
- Image assembly

**Final scan workflow**:
- SET WINDOW (final parameters: user-selected res, crop area)
- Possible pre-scan calibration
- SCAN command
- READ loop (full resolution data)

**Autofocus workflow**:
- Vendor-specific focus commands
- Position feedback loop

**Film advance/eject**:
- Vendor-specific motor control commands

**Where to look**: Trace from TWAIN handlers -> internal methods -> MAIDEntryPoint calls
**Output**: Per-workflow sequence diagrams in `docs/kb/components/nikonscan4-ds/scan-workflow.md`

### Step 4: UI Parameter -> SCSI Mapping
**What to do**: Map user-facing settings to SCSI command parameters.
**What to look for**:
- **Resolution** (DPI) -> SET WINDOW resolution fields
- **Bit depth** (8/14/16 bit) -> SET WINDOW bit depth, data format
- **Color mode** (RGB, grayscale) -> SET WINDOW color mode
- **Scan area** (x, y, width, height) -> SET WINDOW scan area fields
- **Film type** (positive, negative, B&W) -> vendor-specific film type command
- **Gain/offset** (analog gain, exposure) -> vendor-specific calibration commands
- **Multi-sample** (1x, 2x, 4x, 8x, 16x) -> scan count or averaging parameter
**Where to look**: TWAIN capability handlers (MSG_SET), trace to MAID capability set calls
**Output**: Parameter mapping table in `docs/kb/components/nikonscan4-ds/scan-workflow.md`

## Key Addresses / Patterns

### TWAIN Data Groups
- `DG_CONTROL (0x0001)`: Control operations (capability, status, identity)
- `DG_IMAGE (0x0002)`: Image operations (transfer, layout)

### Key TWAIN Triplets
- `DG_CONTROL/DAT_IDENTITY/MSG_OPENDS`: Open data source (init connection)
- `DG_CONTROL/DAT_CAPABILITY/MSG_SET`: Set a capability value
- `DG_IMAGE/DAT_IMAGENATIVEXFER/MSG_GET`: Transfer image data
- `DG_CONTROL/DAT_PENDINGXFERS/MSG_ENDXFER`: End transfer

### String Patterns
- "Preview", "Scan", "AutoFocus", "Calibrat" -- workflow identification
- "Resolution", "BitDepth", "ColorMode" -- capability names
- "MAID" -- MAID interface references

## Prerequisite Knowledge
- Phase 1: `docs/kb/components/nkduscan/api.md` (NkDriverEntry)
- Phase 2: `docs/kb/scsi-commands/` (SCSI command catalog), `docs/kb/components/ls5000-md3/maid-entrypoint.md`
- TWAIN specification basics (DG/DAT/MSG triplet model)

## KB Deliverables
- `docs/kb/components/nikonscan4-ds/twain-dispatch.md`
- `docs/kb/components/nikonscan4-ds/command-queue.md`
- `docs/kb/components/nikonscan4-ds/scan-workflow.md`
- Update `docs/kb/architecture/software-layers.md` with TWAIN layer details

## Log Files
- Phase log: `docs/log/phases/phase-03-nikonscan4.md`
- Component log: `docs/log/components/nikonscan4-attempts.md`
