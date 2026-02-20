# Phase 4: Firmware -- Device-Side SCSI Handler

## Goal
Understand how the scanner receives and dispatches SCSI commands. Verify host-side findings from Phases 1-3 by analyzing the device-side implementation.

## Completion Criteria
All must be met to mark phase complete:
- [ ] Reset vector startup code (0x100) fully traced: SP init, bus controller setup, peripheral config, jump to main
- [ ] All active interrupt vectors (15 found in recon) mapped to handler functions with purpose identified
- [ ] ISP1581 USB controller interaction code identified: endpoint setup, bulk read/write, status queries
- [ ] SCSI command dispatch mechanism found (switch/table) and all opcode handlers identified
- [ ] At least 5 opcode handlers fully reversed (matching host-side findings from Phase 2)
- [ ] Motor control code identified and GPIO -> physical action mapping documented
- [ ] At least 3 data-driven struct tables identified and decoded (e.g., adapter table, scan param table)
- [ ] Cross-validation: firmware command handlers match host-side CDB formats for all standard commands

## Targets

| Binary | Path | Processor | Size |
|--------|------|-----------|------|
| Firmware | binaries/firmware/Nikon LS-50 MBM29F400B TSOP48.bin | H8/3003 (H8/300H) | 512KB |

## Methodology (Step by Step)

### Step 1: Reset Vector & Startup Code
**What to do**: Analyze the code at the reset vector entry point.
**What to look for**:
- Stack pointer initialization (SP = top of RAM, likely 0x41FFFF or 0x47FFFF)
- Bus State Controller (BSC) register setup -- configures access to external memory regions
- Watchdog timer disable/configure
- Clock frequency setup
- GPIO port direction register configuration
- Jump to main application code
**Where to look**: Reset vector at 0x000 points to entry code, typically at 0x100
**Output**: Annotated startup sequence in `docs/kb/components/firmware/startup.md`

### Step 2: Interrupt Vector Table Mapping
**What to do**: Map all 64 vector table entries to their handler functions.
**What to look for**:
- Active vectors: entries that point to actual handler code (not the default/unused handler)
- Key vectors: Timer interrupts (for motor control timing), external IRQ (USB controller interrupt from ISP1581), SCI (serial), ADC
- Handler patterns: save registers, read peripheral status, clear interrupt flag, process, restore, RTE
**Where to look**: 0x000-0x0FF (64 entries x 4 bytes), follow each non-trivial address
**Output**: Vector table map in `docs/kb/components/firmware/vector-table.md`

### Step 3: ISP1581 USB Controller Interface
**What to do**: Reverse the code that interfaces with the ISP1581 USB controller.
**What to look for**:
- ISP1581 register accesses at 0x600000-0x6000FF
- Key registers: Address (0x00), Mode (0x0C), Interrupt Config (0x10), DcEndpointEnable (0x24)
- Endpoint configuration: Control EP0, Bulk IN/OUT endpoints
- Bulk transfer handling: how firmware reads CDBs from host (bulk-out), sends data to host (bulk-in)
- DMA configuration if used
**Where to look**: All code accessing 0x600000 memory range
**Output**: USB controller interface docs in `docs/kb/components/firmware/isp1581-usb.md`

### Step 4: SCSI Command Dispatch
**What to do**: Find the main SCSI command dispatch mechanism.
**What to look for**:
- After receiving a CDB via USB bulk-out, the firmware parses opcode byte (CDB[0])
- Dispatch table or switch statement: opcode -> handler function
- Handler function pattern: validate CDB parameters, execute operation, prepare response data, set status
- Separate handling for standard SCSI commands vs vendor-specific (0xC0-0xFF)
**Where to look**: Trace from ISP1581 bulk-out receive handler, follow the CDB processing path
**Output**: Command dispatch table in `docs/kb/components/firmware/scsi-handler.md`

### Step 5: Individual Opcode Handler Reversal
**What to do**: Fully reverse at least 5 important opcode handlers.
**What to look for per handler**:
- CDB byte parsing (which bytes control what)
- Data preparation (what response data is assembled)
- Hardware interaction (does this command touch motors, lamp, CCD?)
- Error conditions (what causes CHECK CONDITION / sense data)

**Priority handlers**:
1. `0x12` INQUIRY -- returns device identification string
2. `0x24` SET WINDOW -- configures scan parameters
3. `0x1B` SCAN -- initiates the actual scan operation
4. `0x28` READ -- transfers scan data to host
5. Vendor-specific command(s) -- whichever is most commonly called

**Where to look**: Dispatch table handlers from Step 4
**Output**: Per-handler analysis in `docs/kb/scsi-commands/` (cross-referencing host-side docs from Phase 2)

### Step 6: Motor Control & GPIO
**What to do**: Identify and document motor control code.
**What to look for**:
- GPIO Port B bits 4-7: Film transport motor control
- GPIO Port C bits 3-5: Adapter ID (which film adapter is inserted)
- GPIO Port C bit 6: Door sensor
- GPIO Port C bit 7: Adapter presence detect
- Stepper motor sequencing patterns
- Speed/acceleration profiles
- Position feedback (optical encoder or step counting)
**Where to look**: GPIO port register accesses (H8/3003 I/O registers), timer interrupt handlers
**Output**: Motor control docs in `docs/kb/components/firmware/motor-control.md`

### Step 7: Data-Driven Tables
**What to do**: Identify and decode firmware data tables.
**What to look for**:
- Adapter type table: adapter ID bits -> adapter name/capabilities
- Scan parameter tables: resolution limits, bit depths, color modes per adapter
- Calibration tables: CCD offsets, gain values, dark frame data
- Motor parameter tables: speed, acceleration, step counts for different operations
- String tables: error messages, SCSI INQUIRY strings
**Where to look**: Data regions in flash (non-code areas), pointers from handler functions
**Output**: Table documentation in relevant `docs/kb/components/firmware/` subdocs

### Step 8: Cross-Validation
**What to do**: Verify host-side findings from Phases 1-2 against firmware handlers.
**What to look for**:
- CDB format match: host CDB construction matches firmware CDB parsing
- Data format match: host data buffers match firmware response assembly
- Parameter range match: host parameter limits match firmware validation
- Discrepancies: any mismatch indicates an error in either host or device analysis
**Where to look**: Compare Phase 2 `docs/kb/scsi-commands/` with firmware handler analysis
**Output**: Cross-validation notes in each relevant KB doc (update Confidence to "Verified")

## Prerequisite Knowledge
- `docs/kb/architecture/usb-protocol.md` (Phase 1)
- `docs/kb/scsi-commands/` (Phase 2)
- `docs/kb/reference/memory-map.md` (Phase 0)
- H8/300H instruction set reference
- ISP1581 datasheet

## KB Deliverables
- `docs/kb/components/firmware/startup.md`
- `docs/kb/components/firmware/vector-table.md`
- `docs/kb/components/firmware/isp1581-usb.md`
- `docs/kb/components/firmware/scsi-handler.md`
- `docs/kb/components/firmware/motor-control.md`
- Update `docs/kb/scsi-commands/` with firmware-side verification
- Update confidence levels to "Verified" for cross-validated commands

## Log Files
- Phase log: `docs/log/phases/phase-04-firmware.md`
- Component log: `docs/log/components/firmware-attempts.md`
