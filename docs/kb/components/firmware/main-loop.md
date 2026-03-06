# Firmware Main Loop and Task Dispatch Architecture

**Status**: Complete
**Last Updated**: 2026-02-28
**Phase**: 4 (Firmware)
**Confidence**: High (decoded from raw hex dumps of H8/300H instructions, cross-referenced with known RAM addresses)

## Overview

The LS-50 firmware uses a **two-context cooperative coroutine system** as its core execution model. After hardware initialization completes, the firmware creates two execution contexts with separate stacks and entry points, then uses TRAPA #0 as a cooperative yield mechanism to switch between them. On top of this, a simple polling main loop handles SCSI commands, task dispatch, and hardware state management.

This is NOT a preemptive scheduler. The two contexts cooperate explicitly via TRAPA #0 calls. Hardware interrupts (USB, timers, DMA, serial) run independently in interrupt context and communicate with the main loop via shared RAM flags.

## Initialization Flow (Summary)

```
0x000100: Reset vector entry
  ↓
0x00016E: Bank select (register @0x4001)
  ↓
0x020334: Main firmware entry
  ↓ I/O register init table (132 entries, 0x2001C-0x20334)
  ↓ RAM test (external RAM at 0x400000+)
  ↓ SP relocation to external RAM (0x40F800)
  ↓ Peripheral init (JSR @0x015EAA)
  ↓ Interrupt trampoline installation (12 entries, 0x204C4-0x205F7)
  ↓
0x0205FC: JSR @0x0109FA           ; Clear shared state
0x020600: MOV.B #1, @0x400772     ; Set "initialized" flag
0x020608: ANDC #0x7F, CCR         ; ENABLE INTERRUPTS (first time!)
0x02060A: JSR @0x02A188           ; One-time hardware init with interrupts
0x02060E: ORC #0x80, CCR          ; Disable interrupts again
0x020610: MOV.B #0, @0x400772     ; Clear flag for first-boot descriptor selection
0x020618: JSR @0x0107BC           ; Register Context A entry point
0x02061C: JSR @0x010BCE           ; Initialize ASIC/DMA state
0x020620: JMP @0x0107EC           ; >>> ENTER CONTEXT SYSTEM (never returns)
```

**Key observation**: Interrupts are enabled briefly at 0x20608 for the hardware init call at 0x02A188, then disabled again before entering the context system. The context system itself manages interrupt state.

## Two-Context Cooperative Coroutine System

### Context Initialization (0x107EC)

The context system is set up by `JMP @0x0107EC` at the end of initialization. This function:

1. Reads boot flag at `@0x400772` to select descriptor table
2. Table A (first boot, flag=0) at `0x107CC`: entry points `0x207F2` and `0x29B16`
3. Table B (re-entry, flag=1) at `0x107DC`: entry points `0x10C46` and `0x29B16`
4. For each context: creates a stack frame, pushes entry point as return address, pushes 7 zero-initialized register saves (ER0-ER6)
5. Stores context descriptors in RAM at `0x400766` (8 bytes per context: 4-byte stack pointer save)
6. Loads SP from the first context's saved SP
7. Pops registers and executes RTE to start the first context

```asm
; Context initialization (0x107EC)
0x107EC: MOV.B @0x400772, R1L     ; Read boot flag
0x107F2: BNE   use_table_B        ; Non-zero = use alternate entry points
0x107F6: MOV.L #0x0107CC, ER0    ; Table A: [0x410000, 0x207F2, 0x40D000, 0x29B16]
0x107FC: BRA   init_contexts
0x10800: MOV.L #0x0107DC, ER0    ; Table B: [0x410000, 0x10C46, 0x40D000, 0x29B16]
0x10806: MOV.L #0x400766, ER1    ; RAM save area
0x1080C: MOV.W #0x0002, R2       ; 2 contexts to initialize
; Loop: for each context
0x10810:   MOV.L @ER0+, ER3      ; Load stack base address
0x10814:   MOV.L @ER0+, ER4      ; Load entry point
0x10818:   PUSH  ER4              ; Push entry point (will be popped as return address)
0x1081C:   SUB.L ER4, ER4        ; ER4 = 0
0x1081E:   PUSH  ER4              ; Push 7 zero registers (ER0-ER6 save)
           PUSH  ER4              ;  (all initialized to zero)
           PUSH  ER4
           PUSH  ER4
           PUSH  ER4
           PUSH  ER4
           PUSH  ER4
0x1083A:   MOV.L ER3, @ER1       ; Save SP to context save area
0x1083E:   DEC.W #1, R1           ; Advance save pointer
           DEC.W #1, R1           ;  (by 4 bytes for next context)
0x10842:   SUB.L ER0, ER2        ; Decrement counter
0x10844:   BNE   loop
; Start first context:
0x10846: SUB.W  R0, R0
0x10848: MOV.W  R0, @0x400764    ; Clear context switch state
0x1084E: MOV.L  #0x400766, ER0
0x10854: MOV.L  @ER0, ER7        ; Load SP from Context A save
0x10858: POP    ER6               ; Restore all registers
         POP    ER5
         POP    ER4
         POP    ER3
         POP    ER2
         POP    ER1
         POP    ER0
0x10874: RTE                      ; "Return" into Context A entry point
```

### Context Descriptors

**Table A** (first boot, `@0x400772` = 0):

| Context | Stack Base | Entry Point | Purpose |
|---------|-----------|------------|---------|
| A | 0x410000 | 0x0207F2 | Main firmware loop |
| B | 0x40D000 | 0x029B16 | USB data transfer handler |

**Table B** (re-entry after warm restart, `@0x400772` = 1):

| Context | Stack Base | Entry Point | Purpose |
|---------|-----------|------------|---------|
| A | 0x410000 | 0x010C46 | Alternate main loop (shared module) |
| B | 0x40D000 | 0x029B16 | USB data transfer handler (same) |

Stack locations:
- Context A stack: `0x410000` (top of 128KB external RAM at 0x400000-0x41FFFF)
- Context B stack: `0x40D000` (middle of external RAM, 52KB below Context A)

### Context Switch Mechanism (TRAPA #0)

The yield operation is a TRAPA #0 instruction (opcode `5700`), accessed via a stub function:

```asm
; Yield stub at 0x109E2:
0x109E2: TRAPA #0                 ; Push CCR+PC, jump to vector 8
0x109E4: RTS                      ; Return after context switch completes
```

The TRAP #0 vector (vector 8, address 0x020) points to trampoline `0xFFFD10`, which jumps to the context switch handler at `0x010876`:

```asm
; Context switch handler at 0x10876:
0x10876: ANDC  #0x7F, CCR         ; Re-enable interrupts
0x10878: PUSH  ER0                ; Save all registers of yielding context
         PUSH  ER1
         PUSH  ER2
         PUSH  ER3
         PUSH  ER4
         PUSH  ER5
         PUSH  ER6
0x10894: MOV.W #0x5A00, R0
0x10898: MOV.W R0, @0xFFA8       ; Reset watchdog timer
0x1089C: MOV.B @0x400772, R0L    ; Read boot flag
0x108A2: MOV.B @0x4001, R0H      ; Read bank select register
         ; [check if context switch should proceed]
         ; If conditions met:
0x108AE: ORC   #0x80, CCR        ; Disable interrupts during SP swap
0x108B0: MOV.W @0x400764, R0     ; Read context switch state
         ; [swap SP between @0x400766 entries]
         ; [update context state @0x400764]
0x108D6: ANDC  #0x7F, CCR        ; Re-enable interrupts
         ; Restore the OTHER context:
0x108D8: POP   ER6               ; Restore all registers of resumed context
         POP   ER5
         POP   ER4
         POP   ER3
         POP   ER2
         POP   ER1
         POP   ER0
0x108F4: RTE                      ; Return to the other context
```

**Key insight**: The RTE at the end pops both CCR and PC from the new context's stack, atomically resuming the other context with its saved interrupt state.

### Utility Stubs (0x109E0-0x109F8)

A set of tiny utility functions in the shared module:

| Address | Code | Function |
|---------|------|----------|
| 0x109E0 | `RTE` | Return from exception (direct) |
| 0x109E2 | `TRAPA #0; RTS` | **Yield** — context switch to other coroutine |
| 0x109E6 | `TRAPA #0; RTS` | Yield (duplicate entry point) |
| 0x109EA | `ORC #0x80, CCR; RTS` | **Disable interrupts** |
| 0x109EE | `ANDC #0x7F, CCR; RTS` | **Enable interrupts** |
| 0x109F2 | `STC CCR, R0L; RTS` | **Read CCR** (save interrupt state) |
| 0x109F6 | `LDC R0L, CCR; RTS` | **Write CCR** (restore interrupt state) |
| 0x109FA | `SUB.L ER0,ER0; MOV.L ER0,@0x40076E; ...` | **Clear shared state** |

## Main Loop (Context A: 0x207F2)

### Main Loop Structure

```
0x207F2: main_loop:
    JSR  @0x016458           ; push_context (save ER3-ER6 to stack)
    MOV.L #0x40077A, ER3     ; ER3 → scan progress state
    MOV.L #0x400084, ER4     ; ER4 → USB bus reset flag
    MOV.L #0x400085, ER5     ; ER5 → USB re-init flag
    MOV.L #0x400776, ER6     ; ER6 → scanner state flags
    JSR  @0x010D22           ; One-time init (shared module)
    MOV.B R0L, @0x400E80     ; Store init result
    MOV.L #50, ER0
    JSR  @0x01233A           ; USB configuration with timeout
    JSR  @0x0126EE           ; Enable USB endpoints

  .loop_top:                 ; <<<< MAIN POLLING LOOP TOP >>>>
    ; --- Step 1: Check USB connection ---
    MOV.B @0x407DC7, R0L     ; Read USB session state
    CMP.B #0x02, R0L         ; 2 = connected and configured?
    BEQ   .usb_ok
    MOV.W #0x005C, E0        ; Timeout = 92
    MOV.B #0x01, R0L
    JSR  @0x013836           ; Re-establish USB session

  .usb_ok:
    ; --- Step 2: Check scan state ---
    MOV.W @ER3, R0            ; Read scan progress @0x40077A
    MOV.W @0x400778, E0       ; Read scan status
    JSR  @0x0133A4            ; Process scan state changes

    ; --- Step 3: Handle USB bus reset ---
    MOV.B @ER4, R0L           ; Read @0x400084 (USB reset flag)
    BEQ   .no_reset
    JSR  @0x013A20            ; Handle USB bus reset

  .no_reset:
    ; --- Step 4: Run scanner state machine ---
    BSR  scanner_state_machine ; (at 0x208AC)

    ; --- Step 5: Handle USB re-init ---
    MOV.B @ER5, R0L           ; Read @0x400085 (re-init flag)
    BEQ   .no_reinit
    SUB.B R0L, R0L
    MOV.B R0L, @ER5           ; Clear re-init flag
    MOV.B @0x400086, R0L      ; Read error flag
    BEQ   .no_error
    MOV.W #0x0061, R0
    MOV.W R0, @0x4007B0       ; Set sense code 0x0061 (USB comm error)
  .no_error:
    BTST  #6, @ER6            ; Test abort bit in scanner flags
    BEQ   .no_abort
    BSET  #7, @ER6            ; Set response-pending bit
  .no_abort:
    MOV.B @ER4, R0L           ; Check if bus reset also pending
    BNE   .no_reinit
    JSR  @0x013BB4            ; USB soft-reconnect
  .no_reinit:

    ; --- Step 6: Check for SCSI command ---
    JSR  @0x013C70            ; Check if USB command received
    TST.B R0L                 ; R0L = 0 means no command
    BNE   .have_command
    ; No command: YIELD to other context (sleep)
    JSR  @0x0109E2            ; TRAPA #0 → context switch
    BRA  .loop_top            ; After wakeup, re-check everything

  .have_command:
    ; --- Step 7: Process SCSI command ---
    BSR  scanner_state_machine ; Re-check state before dispatch
    JSR  @0x020AE2            ; >>> SCSI DISPATCH FUNCTION <<<

    ; --- Step 8: Check for soft-reset ---
    MOV.B @0x400E5F, R0L      ; Read soft-reset flag
    CMP.B #0x01, R0L
    BNE  .loop_top            ; No reset → go back to loop top

    ; --- Step 9: Soft reset ---
    JSR  @0x012F5A            ; USB disconnect
    JSR  @0x0109EA            ; Disable interrupts
    JSR  @0x000112            ; Jump to warm-restart boot path
    BRA  .loop_top            ; (never reached — boot path reinits everything)
```

### Main Loop Summary

The main loop is a simple **polling loop** with **cooperative yielding**:

1. Check USB connection state; re-establish if needed
2. Process scan state changes (check motor/DMA progress)
3. Handle USB bus reset events
4. Run scanner state machine (check for pending events)
5. Handle USB re-initialization events
6. **Check for incoming SCSI command** (this is the critical check)
   - If no command: **YIELD** via TRAPA #0 → context switch to USB handler
   - If command available: dispatch it
7. After dispatch, check for soft-reset request
8. Loop back to top

**The yield at step 6 is the only place the main loop voluntarily gives up the CPU.** When no SCSI command is pending, the main loop yields to Context B (USB data handler). When Context B finishes its work (or has nothing to do), it yields back, and the main loop continues polling.

## SCSI Dispatch (0x20AE2 → 0x20B48)

### SCSI Dispatch Entry (0x20AE2)

Called from the main loop when a SCSI command is available:

```asm
0x20AE2: scsi_dispatch:
    PUSH  ER6
    MOV.L #0x40049D, ER6      ; ER6 → command completion counter
    SUB.W R0, R0
    MOV.W R0, @0x4007B0       ; Clear sense code (no error)
    SUB.B R0L, R0L
    MOV.B R0L, @0x400877      ; Clear additional sense

    JSR  @0x013690             ; Check: is USB command ready for processing?
    TST.B R0L
    BEQ  .done                 ; If not ready, exit

    ; Clear execution state
    SUB.B R0L, R0L
    MOV.B R0L, @ER6           ; Clear completion counter @0x40049D
    MOV.B R0L, @0x40049A      ; Clear USB transaction flag
    MOV.B R0L, @0x40049C      ; Clear transfer phase

    ; Check if sense code was already set (from a previous error)
    MOV.W @0x4007B0, R0
    BNE  .already_error        ; If non-zero sense, skip handler lookup

    ; >>> LOOK UP AND CALL SCSI HANDLER <<<
    BSR  scsi_handler_lookup   ; (at 0x20B48)

    MOV.B #0x01, R0L
    JSR  @0x01374A             ; USB response: signal command-complete phase

  .already_error:
    ; Increment completion counter
    MOV.B @ER6, R0L            ; Read @0x40049D
    INC.B R0L
    MOV.B R0L, @ER6            ; Increment
    CMP.B #0x02, R0L           ; If counter reaches 2...
    BNE  .not_second
    MOV.B @0x40049A, R0L       ; Check USB transaction still active
    BNE  .done                 ; If active, don't signal again
  .not_second:
    MOV.B #0x01, R0L
    JSR  @0x01374A             ; Signal USB response phase

  .done:
    JSR  @0x01117A             ; Post-dispatch cleanup
    POP  ER6
    RTS
```

### SCSI Handler Lookup (0x20B48)

```asm
0x20B48: scsi_handler_lookup:
    JSR  @0x016458             ; push_context
    MOV.B #0x01, R3L           ; R3L = command phase marker
    MOV.L #0x049834, ER6       ; ER6 → SCSI handler table base

    BRA  .check_end
  .scan_loop:
    MOV.B @ER6, R0L            ; Read opcode from table entry
    MOV.B @0x4007B6, R1L       ; Read received SCSI opcode
    CMP.B R1L, R0L             ; Match?
    BEQ  .found                ; Yes → use this entry
    ADD.L #0x0A, ER6           ; No → advance to next entry (10-byte stride)
  .check_end:
    MOV.L @(0x04,ER6), ER0    ; Read handler pointer field
    BNE  .scan_loop            ; If non-null, keep searching
    ; Fall through: opcode not found → error path
    ...

  .found:
    ; Permission checking at 0x20B70-0x20D90
    MOV.W @(0x02,ER6), R5     ; Load permission flags
    ; ... extensive state/permission checking ...

    ; Handler call at 0x20D94:
    MOV.B @(0x08,ER6), R0L    ; Read exec mode byte
    CMP.B #0x01, R0L           ; Mode 1 = needs USB state setup?
    BNE  .no_setup
    MOV.B R3L, R0L             ; Pass command phase
    JSR  @0x01374A             ; USB state setup
  .no_setup:
    MOV.B @(0x08,ER6), R0L    ; Re-read exec mode
    MOV.B R0L, @0x40049B       ; Store exec mode for later reference
    MOV.L @(0x04,ER6), ER6    ; Load handler function pointer
    JSR  @ER6                  ; >>> CALL THE SCSI HANDLER <<<
    JSR  @0x016436             ; pop_context
    RTS
```

## Task Dispatcher (0x20DBA)

The task dispatcher is used by the C1 vendor command handler and possibly other internal callers. It maps a 16-bit task code to a handler index by linear search through the task table at 0x49910.

```asm
0x20DBA: task_dispatch:          ; Input: R0 = task code (16-bit)
    MOV.W R0, E0               ; Save task code in E0
    MOV.L #0x049910, ER1       ; ER1 → task table base
    BRA  .check_null
  .search:
    MOV.W @ER1, R0             ; Read task code from table entry
    CMP.W E0, R0               ; Match with saved code?
    BEQ  .found                ; Yes → return handler index
    ADDS #4, ER1               ; Advance to next 4-byte entry
  .check_null:
    MOV.W @ER1, R0             ; Read task code
    BNE  .search               ; If non-zero, continue searching
  .found:
    MOV.W @(0x02,ER1), R0     ; Load handler index from offset +2
    RTS                        ; Return handler index in R0
```

**Task table format** (97 entries at 0x49910, 4 bytes each):
```
Offset  Size  Field
  0       2   Task code (16-bit, big-endian)
  2       2   Handler index (16-bit)
```

The handler index is NOT a direct function pointer. It is an index used by the calling function (e.g., the task execution function at 0x20DD6) to look up the actual handler via a function pointer table.

### Task Execution Function (0x20DD6)

This function manages task execution with a time-budget system:

```asm
0x20DD6: task_execute:
    JSR  @0x016458             ; push_context
    MOV.L #0x40078C, ER3       ; ER3 → task remaining counter (32-bit)
    MOV.L #0x400896, ER5       ; ER5 → task budget counter (32-bit)
    MOV.L @ER5, ER0
    MOV.L ER0, @0x40089A       ; Save initial budget

    MOV.B #0x01, @0x400493     ; Set "task execution active" flag
    JMP  .check_remaining

  .execute_loop:
    MOV.L @ER3, ER6            ; Read remaining work
    BEQ  .no_work              ; If zero, no work to do
    MOV.L @ER5, ER0            ; Read budget
    ; [compare budget with remaining]
    ; [adjust for USB transfer requirements @0x407DC3/407DCC/407DCE]

    JSR  @0x0140F2             ; Execute one unit of work (DMA transfer/task step)
    MOV.L @ER5, ER0
    SUB.L ER4, ER0
    MOV.L ER0, @ER5            ; Decrease budget by work done
    ; ... update remaining, accounting ...
    BNE  .check_remaining      ; If budget remaining, continue

    MOV.B #0x01, @0x400492     ; Set "task complete" flag
    BRA  .check_remaining

  .no_work:
    MOV.W @0x4007B0, R0        ; Check sense code
    BNE  .error_exit
    MOV.B @0x400085, R0L       ; Check USB re-init flag
    BEQ  .idle
    SUB.B R0L, R0L
    MOV.B R0L, @0x400493       ; Clear "task active" flag
    BRA  .done
  .idle:
    JSR  @0x0109E2             ; YIELD (no work → give up CPU)

  .check_remaining:
    MOV.L @ER5, ER0
    BNE  .execute_loop         ; If budget > 0, keep going

  .error_exit:
    ; Clean up, reconcile accounting
    SUB.B R0L, R0L
    MOV.B R0L, @0x400493       ; Clear "task active" flag
    ; ... final accounting ...

  .done:
    JSR  @0x016436             ; pop_context
    RTS
```

**Key insight**: The task execution function has a **budget system** where each task gets a certain number of execution units. When the budget runs out, or when there's no work to do, the function either exits or yields. This prevents any single long-running task (like a scan) from starving SCSI command processing.

## Connection: USB Interrupt → SCSI Dispatch → Task System

### Complete Data Flow

```
USB Interrupt (Hardware)
  │
  ├─ ISP1581 generates interrupt on IRQ1 pin
  │
  ▼
IRQ1 Handler (0x014E00, interrupt context)
  │
  ├─ Read ISP1581 interrupt status @0x60000C
  ├─ For endpoint events: read CDB from endpoint data register @0x600020
  ├─ Store CDB bytes in RAM buffer @0x4007DE
  ├─ Extract opcode byte → @0x4007B6
  ├─ Set command-pending flag @0x400082 = 1
  ├─ Update USB state variables (@0x407Dxx block)
  └─ RTE (return from interrupt)
       │
       ▼
Context Switch wakes Main Loop
  │  (If main loop was in TRAPA #0 yield, the interrupt wakes the CPU.
  │   The TRAP handler returns to the main loop. On next poll cycle,
  │   the main loop detects the new command.)
  │
  ▼
Main Loop (0x207F2, Context A)
  │
  ├─ Step 6: JSR @0x013C70 (check USB command ready)
  │     └─ Reads @0x400082 (command pending flag)
  │     └─ Returns non-zero in R0L if command available
  │
  ├─ If no command: JSR @0x109E2 (YIELD via TRAPA #0)
  │     └─ Context switch to Context B (USB data handler)
  │     └─ When Context B yields back, resume polling
  │
  ├─ If command available:
  │     └─ BSR scanner_state_machine  (0x208AC)
  │     └─ JSR @0x020AE2  (SCSI dispatch)
  │
  ▼
SCSI Dispatch (0x020AE2)
  │
  ├─ JSR @0x013690 (verify command ready, read CDB)
  ├─ Clear sense/error state
  ├─ BSR @0x020B48 (handler lookup in table @0x49834)
  │     ├─ Linear search: compare CDB[0] with table opcode entries
  │     ├─ Load permission flags, check against scanner state
  │     ├─ Load exec mode byte
  │     └─ JSR @ER6 (call matched handler)
  │
  ├─ For simple commands (INQUIRY, MODE SENSE, etc.):
  │     └─ Handler executes, builds response, returns
  │
  ├─ For action commands (SCAN, C1 trigger):
  │     └─ Handler sets up task parameters in RAM
  │     └─ Sets task code at @0x400778 or @0x40077C
  │     └─ Returns to dispatch
  │
  └─ JSR @0x01374A (signal command completion via USB)
       │
       ▼
Task Execution (next main loop iterations)
  │
  ├─ Main loop Step 2: read scan state @0x400778, @0x40077A
  ├─ State machine at 0x208AC checks for pending tasks
  ├─ Task dispatch function at 0x20DBA:
  │     └─ Linear search task code in table @0x49910 (97 entries)
  │     └─ Returns handler index
  ├─ Task execution function at 0x20DD6:
  │     └─ Executes task with time budget
  │     └─ Yields (TRAPA #0) when no work or budget exhausted
  └─ Task results reported via TEST UNIT READY sense codes
```

### Timing Considerations

- **USB interrupts** (IRQ1) fire asynchronously and can wake the CPU from SLEEP
- **Timer interrupts** (ITU2/3/4) fire during motor stepping operations
- **DMA interrupts** fire when USB bulk transfers complete
- **The main loop polls** on each iteration; no interrupt directly calls SCSI dispatch
- **Yield points**: only at 0x109E2 calls (TRAPA #0) in the main loop and task execution

The firmware's response latency to a new SCSI command depends on:
1. Whether Context A is currently yielded (needs context switch back from B)
2. Whether a long-running task (scan, motor move) is executing (needs budget expiry)
3. Whether the main loop is in a JSR call that doesn't yield

## RAM Layout for Task System

| Address | Size | Purpose |
|---------|------|---------|
| 0x400082 | 1 | USB command pending flag |
| 0x400084 | 1 | USB bus reset flag |
| 0x400085 | 1 | USB re-init needed flag |
| 0x400086 | 1 | Error flag |
| 0x400088 | 2 | USB state counter |
| 0x400492 | 1 | Task completion flag |
| 0x400493 | 1 | Task execution in-progress flag |
| 0x40049A | 1 | USB transaction active flag |
| 0x40049B | 1 | Current exec mode (from SCSI table) |
| 0x40049C | 1 | USB transfer phase |
| 0x40049D | 1 | Command completion counter |
| 0x40049E | 4 | Task result/status |
| 0x400764 | 2 | Context switch state word |
| 0x400766 | 8 | Stack pointer save area (2 contexts x 4 bytes) |
| 0x400772 | 1 | Boot flag (0=cold, 1=warm re-entry) |
| 0x400776 | 1 | Scanner state flags (bit 6=abort, bit 7=response) |
| 0x400778 | 2 | Current task code / scan status |
| 0x40077A | 2 | Scan progress / DMA state |
| 0x40077C | 2 | Scanner state machine variable |
| 0x40078C | 4 | Task remaining work counter |
| 0x400896 | 4 | Task time budget counter |
| 0x40089A | 4 | Saved initial budget (for accounting) |
| 0x4007B0 | 2 | SCSI sense code |
| 0x4007B6 | 1 | Current SCSI opcode |
| 0x4007DE | 16 | CDB receive buffer |
| 0x400E5F | 1 | Soft-reset request flag |
| 0x400E80 | 1 | Init result |
| 0x407DC3 | 1 | USB connection state |
| 0x407DC7 | 1 | USB session state (2=ready) |

## Context A Stack Usage

Context A (main loop) stack at 0x410000 (grows downward):
- Top: 0x410000 (initial SP)
- push_context saves ER3-ER6 (16 bytes)
- Local variables for each function call
- When yielded: full register save (ER0-ER6 = 28 bytes + CCR+PC = 6 bytes = 34 bytes)

Context B (USB data handler) stack at 0x40D000:
- Separate 52KB below Context A
- Used for large USB data transfer state

## Context B: Background Processing Loop (0x29B16)

Context B is the secondary coroutine handling background processing. It runs at 0x29B16 with a stack at 0x40D000.

### Structure

```
0x29B16: push_context
         MOV.L #0x40077A, ER3     ; scan progress pointer
         MOV.L #0x400776, ER5     ; scanner state flags pointer
         MOV.L #0x40077C, ER6     ; state machine var pointer

  .loop:
    ; Check task code for init/scan state transitions
    ; Monitor @0x400778 for various task codes:
    ;   0x0010 → set scan progress to 0x2000, call handler, yield
    ;   0x0110/0x0120/0x0121 → init sequence monitoring
    ;   0x2000/0x3000 → scan/recovery monitoring
    ;
    ; Check ASIC DMA status and manage data flow
    ; Check adapter state (@0x400F22, @0x40632F)
    ; Check USB busy (@0x400773) and cmd_state values (1-7)
    ;
    ; When idle: JSR @0x0109E2 (yield to Context A)
    ; BRA .loop
```

### Yield Points

Context B has **21 yield calls** across the 0x29B16-0x2C400 region, yielding frequently to ensure Context A (SCSI command processing) remains responsive. The yield points are distributed across:

- Task code polling loops (yield when waiting for state changes)
- DMA completion polling (yield between DMA status checks)
- Motor position waiting (yield while motor moves)
- USB transfer completion (yield while data transfers)

### Functions in Context B Region (0x29600-0x2C400)

16 functions in the 12KB region, organized by subsystem:

| Function | Address | Size | Purpose |
|----------|---------|------|---------|
| Pre-B support | 0x29600-0x29B02 | 1.3KB | Support functions for Context B |
| **Context B entry** | 0x29B16-0x29E92 | 892B | Main background loop |
| Init handler | 0x29E96-0x29F2C | 150B | Initialization state processing |
| State machine | 0x29F56-0x2A182 | 556B | Secondary state machine |
| HW init | 0x2A188-0x2A68A | 1.3KB | One-time hardware init (with interrupts) |
| Motor coord | 0x2A690-0x2A80C | 380B | Motor coordination |
| ASIC/DMA mgr | 0x2A812-0x2ADDE | 1.5KB | ASIC DMA management |
| Data path | 0x2ADE4-0x2AED6 | 242B | Data path control |
| Task monitor | 0x2AF1A-0x2AFA8 | 142B | Task code monitoring |
| ISR support | 0x2AFAE-0x2B53E | 1.4KB | ISR support functions |
| ITU0 handler | 0x2B544-0x2B6C8 | 388B | ITU0 special event ISR |
| Encoder supp | 0x2B6CE-0x2B980 | 690B | Encoder processing support |
| Motor step | 0x2B986-0x2BAC0 | 314B | Motor stepping support |
| Recovery | 0x2BCAE-0x2BDEE | 320B | Error recovery |
| Focus coord | 0x2BDF4-0x2C06E | 634B | Focus motor coordination |
| Scan coord | 0x2C074-0x2C1D2 | 350B | Scan coordination |

### Key Architectural Role

Context B handles the **data plane** while Context A handles the **control plane**:

- **Context A** (0x207F2): Receives SCSI commands, dispatches handlers, manages state transitions, sends USB responses
- **Context B** (0x29B16): Monitors task progress, manages DMA transfers, coordinates motor/CCD timing, handles long-running data flows

The two contexts share RAM state variables (0x400778 task code, 0x40077A progress, 0x400776 flags) and cooperate via TRAPA #0 yield. Neither context can preempt the other — only hardware interrupts (timers, DMA, USB) can interrupt either context.

## Related KB Docs

- [Startup Code](./startup.md) -- Reset vector and initialization
- [SCSI Handler](./scsi-handler.md) -- SCSI dispatch table and handler analysis
- [Vector Table](./vector-table.md) -- Interrupt vector mapping
- [ISP1581 USB](./isp1581-usb.md) -- USB controller interface
- [Data Tables](./data-tables.md) -- Task table at 0x49910
- [Motor Control](./motor-control.md) -- Motor tasks driven by task system
- [Scan Pipeline](./scan-pipeline.md) -- Scan tasks driven by task system
