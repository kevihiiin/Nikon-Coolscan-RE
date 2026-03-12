# Scan State Machine Architecture — Nikon LS-50

**Status**: Complete
**Last Updated**: 2026-02-28
**Phase**: 4 (Firmware)
**Confidence**: High (function boundaries, state transitions, task encoding, handler index pairing, and group structure all confirmed from binary hex analysis)

## Overview

The LS-50 firmware's scan state machine occupies a 20KB region at flash address `0x40000`-`0x45300`. It consists of a state-driven inner loop, 4 adapter-specific entry points, and 12 "giant functions" that collectively implement all scan modes — from preview to multi-pass fine scan, across all adapter types and resolution bands.

The state machine is **not a simple switch-case**. It is a pipeline of cooperative stages, where each stage sets the next task code in RAM variable `@0x400778`, yields to the coroutine scheduler (`JSR @0x0109E2`), and the main loop re-enters the appropriate handler on the next iteration.

**Key architectural insight**: The scan state machine does not use a function pointer table. Instead, the task table at `0x49910` maps 16-bit task codes to handler indices, and the handler index (stored in `@0x4007B0`) controls which execution path runs. The 12 giant functions are called directly through a small set of entry points, not through computed dispatch.

## Memory Layout

```
0x40000-0x40317  Pre-function state machine (inner scan loop, 792 bytes)
0x40318-0x4062F  F1:  Scan step core (792 bytes)
0x40630-0x4065F  Scan entry points (4 adapter types, 48 bytes)
0x40660-0x408FD  F2:  Scan orchestrator (670 bytes)
0x408FE-0x411E7  F3:  Scan configuration + ASIC channel setup (2282 bytes)
0x411E8-0x414E3  F4:  ASIC DMA register programming (764 bytes)
0x414E4-0x41EA5  F5:  CCD pixel transfer (2498 bytes)
0x41EE8-0x4292D  F6:  Resolution/adapter scan setup (2630 bytes)
0x4292E-0x42E29  F7:  Calibration scan routine (1276 bytes)
0x42E2A-0x43CF7  F8:  Multi-pass scan orchestrator (3790 bytes)
0x43D2A-0x43DE1  F9:  Scan parameter computation (184 bytes)
0x43DE2-0x44DCD  F10: Full scan pipeline (4076 bytes)
0x44DCE-0x44E3F  F11: Timing computation (114 bytes)
0x44E40-0x45300  F12: Common scan initialization (1216 bytes)
```

Total: ~20KB across the pre-function loop + 12 functions.

## Function Boundaries

All 12 giant functions are delimited by the H8/300H push/pop context idiom:

- **Entry**: `JSR @0x016458` (push_context: saves ER3-ER6 to stack)
- **Exit**: `JSR @0x016436` (pop_context: restores ER3-ER6) followed by `RTS`

The pre-function state machine (0x40000-0x40317) does NOT use this idiom — it is called as inline code, not as a proper function.

## Scan Entry Points (0x40630-0x4065C)

Four entry points, one per adapter type. Each follows the same three-instruction pattern:

```
entry_X:
    JSR @0x044E40      ; F12: Common scan initialization
    JSR @0x045XXX      ; Mode-specific adapter configuration
    JMP @0x040660      ; F2:  Enter scan orchestrator (tail call)
```

| Entry | Address | Mode Function | Adapter Bit | Adapter Type |
|-------|---------|--------------|-------------|-------------|
| A | `0x40630` | `0x04536E` | `0x08` | Strip film (param 0x12) |
| B | `0x4063C` | `0x045390` | `0x04` | Mount adapter (param 0x13) |
| C | `0x40648` | `0x0453CA` | `0x20` | 240/APS adapter (param 0x14) |
| D | `0x40654` | `0x0453D6` | `0x40` | Feeder adapter (param 0x15) |

The adapter type is determined by reading `@0x400F22` (adapter-type bitmask byte). The dispatch function at `FW:0x3C400` routes to the correct entry point:

```
@0x400F22 == 0x04  ->  Entry B (0x4063C)
@0x400F22 == 0x08  ->  Entry A (0x40630)
@0x400F22 == 0x20  ->  Entry C (0x40648)
@0x400F22 == 0x40  ->  Entry D (0x40654)
@0x400F22 == 0x01  ->  0x3C43C (alternate path, calls 0x3C528)
@0x400F22 == 0x02  ->  0x3C460 (alternate path, calls 0xDB38)
```

## Execution Flow

```
Host sends SCSI SCAN (0x1B) or C1 trigger
    |
    v
C1 handler (0x28B08) decodes subcode (0x40-0x47)
    |  Reads E0-written parameters from RAM
    |  Stores 32-bit task code to @0x40077E
    v
Main loop reads @0x40077E
    |
    v
Task dispatch (0x20DBA) linear search through table @0x49910
    |  Returns handler_index in R0
    v
Handler index stored to @0x4007B0
    |
    v
Adapter dispatch (0x3C400) selects entry point
    |
    v
Entry point: F12 (common init) -> mode setup -> F2 (orchestrator)
    |
    v
F2 calls F3-F6 subfunctions in sequence
    |
    v
Pre-function state machine (0x40000) processes each scan line
    |  Triggers ASIC DMA (write 0x200001, poll 0x200002)
    |  Calls F1 for pixel processing
    |  Updates scan status flags
    |  Yields between lines (JSR @0x0109E2)
    v
Scan complete -> recovery tasks (0x0F20)
```

## The 12 Giant Functions

### F1: Scan Step Core (0x40318-0x4062F, 792 bytes)

Processes a single scan line. Called from the pre-function state machine at `0x400E2`. Contains the DMA configuration and pixel extraction logic for one CCD line. Uses heavy register arithmetic with the math library functions.

**Key calls**: Math library only (0x16436, 0x16458). All computation is register-level.

### F2: Scan Orchestrator (0x40660-0x408FD, 670 bytes)

The central coordinator. After entry point initialization, this function sequences the scan operation:

1. Calls `0x039C6C` (calibration function) in a loop until stable
2. Reads command state from `@0x400773`:
   - `0x01` = scan data mode -> proceed with scan
   - `0x04` = scan data ready -> proceed with scan
   - `0x05` = calibration data -> proceed with calibration variant
   - Other = branch to `0x407BE` (alternative path)
3. Calls F3 (ASIC config), F4 (DMA setup), F5 (pixel transfer), F6 (resolution setup)
4. Calls scan pipeline functions: `0x2D4E2`, `0x2D598`, `0x2D7AE`
5. Calls motor/ASIC functions: `0x358EC`, `0x37D18`, `0x37338`

**Key calls**: F3 (`0x408FE`), F4 (`0x411E8`), F5 (`0x414E4`), F6 (`0x41EE8`), plus calibration (`0x39C6C`, `0x39C8A`) and scan pipeline (`0x2D4E2`, `0x2D598`, `0x2D7AE`).

### F3: Scan Configuration (0x408FE-0x411E7, 2282 bytes)

The largest configuration function. Sets up ASIC channel parameters, computes timing values, and configures CCD readout modes. Heavy use of the math library for fixed-point arithmetic (multiplication, division, bit manipulation).

Contains yield calls (`0x0109E2`) for long operations. References ASIC function `0x362F4` and scan pipeline function `0x2D5E4`.

**Key calls**: Math library (10 functions), yield, ASIC, scan pipeline.

### F4: DMA Programming (0x411E8-0x414E3, 764 bytes)

Programs the ASIC DMA registers for all 4 color channels (R/G/B/IR). References RAM variables at `0x401078` and `0x400F9E` (scan configuration parameters). Sets up the DMA transfer descriptors that the ITU3 ISR (Vec 36, 0x02D536) uses for DMA coordination.

**Key calls**: Math library only (7 functions).

### F5: CCD Pixel Transfer (0x414E4-0x41EA5, 2498 bytes)

The second-largest function. Handles per-channel pixel readout from ASIC RAM, with multi-bank DMA support. References `0x406E62` (12 times) and `0x406E3A` (11 times) — these are RAM addresses for scan descriptor tables used to track pixel positions across channels.

Includes resolution scaling logic and calls calibration function `0x39C8A`.

**Key calls**: Math library (10 functions), calibration (`0x39C8A`).

### F6: Resolution/Adapter Setup (0x41EE8-0x4292D, 2630 bytes)

Configures resolution-specific and adapter-specific scan parameters. This is where different scan modes diverge — the pixel geometry, scan area, and motor step parameters are set based on the current resolution and adapter type.

References `0x406E3A` and `0x406E62` extensively (scan descriptor tables). Calls many math functions including `0x1640A` (used only by F5 and F6).

**Key calls**: Math library (11 functions including unique 0x1640A).

### F7: Calibration Scan (0x4292E-0x42E29, 1276 bytes)

Performs factory calibration scans. Uses timing measurement via `0x0163EA` (microsecond timing function). Does not call other giant functions — it's a self-contained calibration routine.

**Key calls**: Math library (timing `0x163EA`).

### F8: Multi-pass Scan Orchestrator (0x42E2A-0x43CF7, 3790 bytes)

The largest function. Orchestrates multi-pass scanning (multiple CCD exposures per line for improved dynamic range). Includes USB data transfer integration (`0x12360`, `0x12398`), calibration (`0x39C6C`, `0x39E0C`, `0x3A00E`), and ASIC timing (`0x3718A`).

This function manages the complex interleaving of: scan line capture, USB transfer, re-calibration, and timing adjustment across multiple passes.

**Key calls**: USB transfer (`0x12360`, `0x12398`), calibration (3 functions), ASIC timing, math library (9 functions).

### F9: Parameter Computation (0x43D2A-0x43DE1, 184 bytes)

Small utility function that computes scan parameters from the current configuration. Likely converts resolution/area settings into DMA transfer counts and motor step values.

**Key calls**: Math library only.

### F10: Full Scan Pipeline (0x43DE2-0x44DCD, 4076 bytes)

The second-largest function and effectively a complete scan pipeline for certain modes. Includes ASIC initialization (`0x3718A`), CCD configuration, pixel processing, USB transfer (`0x12360`, `0x12398`), and calibration (`0x39542`).

This appears to be a "direct mode" scan that bypasses the F2 orchestrator for simpler scan operations (perhaps preview scans).

**Key calls**: ASIC timing, USB transfer, calibration, math library (12 functions).

### F11: Timing Computation (0x44DCE-0x44E3F, 114 bytes)

Small function that computes pixel clock timing from the resolution setting. Uses the microsecond timing function (`0x0163EA`) and division (`0x015CF2`). The result is used by F12 and the scan orchestrator to set CCD integration time.

**Key calls**: Timing `0x163EA`, division `0x15CF2`.

### F12: Common Scan Initialization (0x44E40-0x45300, 1216 bytes)

Called by all 4 entry points as the first step. Performs:
- Adapter detection and configuration
- ASIC base configuration
- Timing setup (calls F11 internally for timing computation)
- Scan area parameter initialization
- References `@0x400F30`-`0x400F34` (scan config area)
- USB data transfer setup (`0x12360`)

## Pre-function State Machine (0x40000-0x40317)

This 792-byte block is the **inner scan loop** — called repeatedly during an active scan to process each CCD line. It is NOT a standard function (no push_context/pop_context frame).

### State Variables Read

| Address | Read Count | Purpose |
|---------|-----------|---------|
| `0x400778` | 14x | **Current task code** (primary dispatch variable) |
| `0x400776` | 4x | Scanner state flags (bit 7 = scan active) |
| `0x40078C` | 2x | Saved scan descriptor |
| `0x400896` | 3x | Counter/flag |
| `0x406E6A` | 2x | Scan line descriptor |

### State Values Checked

The pre-function state machine dispatches on `@0x400778` values:

| State | Meaning | Action |
|-------|---------|--------|
| `0x0300` | Motor: absolute positioning | Wait for motor, yield |
| `0x0310` | Motor: relative positioning | Wait for motor, yield |
| `0x0320` | Motor: scan direction set | Update scan direction |
| `0x0330` | Motor: scan buffer stall | Wait for buffer, yield |

### Inner Loop Operation

```
1. Read scan descriptor from @0x406E6A
2. Call ASIC function 0x35A9A (configure next scan line)
3. Check task state @0x400778:
   - If 0x0300/0x0310: motor positioning, yield and retry
   - If 0x0320/0x0330: scan buffer management
4. Check @0x400776 bit 7: scan active flag
5. Trigger ASIC DMA:
   - Write 0x02 to ASIC register 0x200001
   - Poll ASIC register 0x200002 bit 3 (DMA busy)
   - Yield (0x109E2) between polls
6. When DMA complete: call F1 (0x40318) for pixel processing
7. Update scan status flags:
   - @0x4052EF: scan status byte
   - @0x4052F1: scan active flag
8. Loop back to step 1
```

## Task Table Organization (45 Scan Tasks)

The 45 scan tasks in the 0x08xx group of the task table at `0x49910` are organized by a two-dimensional encoding:

### Task Code Format: `0x08GV`

- **G** = scan Group (0-B): determines the type of scan operation
- **V** = Variant (0-4): determines adapter-specific or resolution-specific configuration

### Task Code Construction

Task codes are computed dynamically at runtime:

```asm
; At FW:0x389FE and similar locations:
MOV.B   @ER6, R0L          ; Read adapter variant byte (0-3)
EXTU.W  R0                  ; Zero-extend to 16-bit
INC.W   #1, R0              ; Add 1 (variant 0 -> 1, etc.)
OR.W    #0x08G0, R0         ; Set group base code
MOV.W   R0, @0x400778       ; Store as current task code
```

So: `task_code = 0x08G0 | (adapter_variant_byte + 1)`

Variant 0 (`0x08G0`) is handled as a special base/default case, separate from the computed variants 1-4.

### Scan Groups

| Group | Task Codes | Handler Indices | Entries | Mode |
|-------|-----------|----------------|---------|------|
| 0 | 0x0800 | 0x0022 (shared) | 1 | Preview — low resolution |
| 1 | 0x0810 | 0x0022 (shared) | 1 | Preview — medium resolution |
| 2 | 0x0820 | 0x0022 (shared) | 1 | Preview — full resolution |
| 3 | 0x0830-0x0834 | 0x0015-0x0019 | 5 | Fine scan, 8-bit, no ICE |
| 4 | 0x0840-0x0844 | 0x0042-0x0046 | 5 | Fine scan, 8-bit, with ICE/IR |
| 5 | 0x0850-0x0854 | 0x0023-0x0027 | 5 | Fine scan, 14-bit, no ICE |
| 6 | 0x0860-0x0864 | 0x0033-0x0037 | 5 | Fine scan, 14-bit, with ICE/IR |
| 7 | 0x0870-0x0874 | 0x0038-0x003C | 5 | Multi-pass scan, no ICE |
| 8 | 0x0880-0x0884 | 0x0047-0x004B | 5 | Multi-pass scan, with ICE/IR |
| 9 | 0x0891-0x0894 | 0x0085-0x0088 | 4 | Extended multi-sample A (no base) |
| A | 0x08A1-0x08A4 | 0x0089-0x008C | 4 | Extended multi-sample B (no base) |
| B | 0x08B1-0x08B4 | 0x008D-0x0090 | 4 | Extended multi-sample C (no base) |

### Group Pairing (from handler index contiguity analysis)

Handler indices cluster into 5 allocation blocks, revealing the firmware development timeline and functional relationships:

| Block | Groups | Handler Range | Scan Mode | Evidence |
|-------|--------|--------------|-----------|----------|
| 1 | 3 | 0x0015-0x0019 | Fine 8-bit, no ICE | Lowest indices = first scan mode implemented |
| 2 | 0/1/2 + 5 | 0x0022-0x0027 | Preview + Fine 14-bit | Shares infrastructure with preview |
| 3 | 6 + 7 | 0x0033-0x003C | 14-bit ICE + Multi-pass | Adjacent indices = closely related pipelines |
| 4 | 4 + 8 | 0x0042-0x004B | 8-bit ICE + Multi-pass ICE | Adjacent indices = ICE variants |
| 5 | 9 + A + B | 0x0085-0x0090 | Extended multi-sample | High indices + no variant 0 = late additions |

**Key structural observations:**
- All 5-entry groups (3-8) have contiguous handler indices with constant diff=1 per variant
- Groups within the same block (e.g., 6+7) use immediately adjacent index ranges, confirming they share core scan logic with minimal parametric differences
- The 8-bit/14-bit distinction is the primary axis: (3=8-bit, 5=14-bit), (4=8-bit+ICE, 6=14-bit+ICE)
- ICE (infrared channel for Digital ICE dust removal) is the secondary axis
- Multi-pass (multiple CCD exposures per line) is the tertiary axis
- Groups 9-B (handler indices 0x0085-0x0090) were added in a later firmware revision — evidenced by the large gap from 0x004B to 0x0085 and the lack of variant 0 (no base/default case)

### Preview Group (Group 0)

The three preview tasks share a single handler (index 0x0022):

| Task | Code | Purpose |
|------|------|---------|
| Base preview | 0x0800 | Low-resolution preview |
| Fine preview | 0x0810 | Medium-resolution preview |
| Extended preview | 0x0820 | Full-resolution preview |

These are set directly via `MOV.W #0x0810, R0` / `MOV.W #0x0820, R0` at `FW:0x38514` and `FW:0x385F8`, unlike the computed codes for other groups.

## State Transition Pipeline

The scan state machine progresses through a well-defined pipeline of task codes stored in `@0x400778`. Each stage completes its work and sets the next task code:

```
HOST TRIGGER (SCSI SCAN 0x1B or Vendor C1)
    |
    v
INIT PHASE
    0x0110 -> Init sequence (scan parameter setup)
    0x0120 -> Init step 2 (hardware config)
    0x0121 -> Init step 3 (final config)
    |
    v
MOTOR POSITIONING
    0x0300 -> Absolute move (move to scan start position)
    0x0310 -> Relative move (fine positioning adjustment)
    0x0380 -> Slow move (precision positioning)
    0x0390 -> Return to home/reference position
    |
    v
FOCUS
    0x0400 -> Focus motor positioning (most common transition)
    0x0450 -> Extended focus (fine focus adjustment)
    |
    v
CALIBRATION
    0x0501 -> Calibration data acquisition
    |
    v
EXPOSURE SETUP
    0x0930 -> Exposure parameter computation
    0x0940 -> Exposure timing set
    |
    v
SCAN EXECUTION
    0x08xx -> Scan task (group + variant determines exact mode)
    Inner loop processes each CCD line
    |
    v
COMPLETION / ERROR
    0x0F20 -> Recovery/cleanup (on error or completion)
```

## Key RAM Variables

| Address | Size | Name | Purpose |
|---------|------|------|---------|
| `0x400773` | byte | `cmd_state` | Command state (4=scan, 5=cal) |
| `0x400776` | word | `state_flags` | Scanner state (bit 7 = scan active) |
| `0x400778` | word | `task_code` | Current task code (primary dispatch) |
| `0x40078C` | long | `saved_desc` | Saved scan descriptor |
| `0x400790` | ptr | `motor_state` | Motor state pointer |
| `0x400896` | long | `counter` | DMA/line counter |
| `0x4007B0` | word | `sense_code` | SCSI sense code (consistent with memory-map.md) |
| `0x40049E` | long | `handler_ptr` | Active handler function pointer |
| `0x400B24` | ptr | `asic_base` | ASIC configuration base address |
| `0x400F22` | byte | `adapter_type` | Adapter bitmask (0x01-0x40) |
| `0x400F26` | ptr | `scan_config` | Scan configuration pointer |
| `0x400F34` | byte | `scan_params` | Scan parameter flags |
| `0x400F55` | byte | `adapter_cfg` | Adapter config byte (5 refs) |
| `0x406E3A` | table | `chan_desc_a` | Channel descriptor table A (11 refs) |
| `0x406E62` | table | `chan_desc_b` | Channel descriptor table B (12 refs) |
| `0x4052EF` | byte | `scan_status` | Scan status byte |
| `0x4052F1` | byte | `scan_active` | Scan active flag |

## Cross-References

- [Scan Data Pipeline](scan-pipeline.md) — DMA and USB data flow stages
- [SCSI Handler](scsi-handler.md) — SCSI SCAN (0x1B) and C1 trigger handlers
- [Data Tables](data-tables.md) — Task table structure at 0x49910
- [Motor Control](motor-control.md) — Motor positioning during scan
- [Calibration](calibration.md) — Calibration scan variant
- [Main Loop](main-loop.md) — Coroutine scheduler and task dispatch
- [ASIC Registers](asic-registers.md) — ASIC DMA configuration registers
