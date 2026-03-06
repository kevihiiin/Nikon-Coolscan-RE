# NikonScan4.ds Command Queue Architecture

**Status**: Complete
**Last Updated**: 2026-02-27
**Phase**: 3 (Scan Workflows)
**Confidence**: High (vtables and key methods decompiled)

## Overview

NikonScan4.ds uses a layered command queue system to orchestrate asynchronous scan operations. Commands flow through a hierarchy of queue classes that manage sequencing, timing, and error handling for MAID (Module Architecture for Imaging Devices) operations.

## Class Hierarchy

```
CCommandQueue (base, vtable 0x101319cc)
├── CStoppableCommandQueue (vtable 0x101353ac) — adds stop/cancel support
│   └── used for long-running scan workflows
├── CQueueAcquireImage (vtable 0x1013ea64) — image acquisition
├── CQueueAcquireDRAGImage (vtable 0x1013eab4) — DRAG (Digital ROC/GEM) acquisition
└── CQueueNotifier (vtable 0x1013eb04) — completion notification

CCommandQueueManager (vtable 0x101319ac) — manages queue lifecycle & execution
CCommandQueuePtrWrapper (vtable 0x101319a4) — ref-counting wrapper

CProcessCommand (vtable 0x1013e7e4) — individual command with message pump
CProcessCommandManager (vtable 0x1013e810) — manages CProcessCommand instances
```

## CCommandQueue Object Layout

Source: `FUN_100148c0` (CopyFrom) at `NikonScan4.ds:0x100148c0`

| Offset | Size | Field | Description |
|--------|------|-------|-------------|
| +0x00 | 4 | vtable_ptr | Points to class vtable |
| +0x04 | 4 | ref_or_flag | Reference/ownership flag |
| +0x08 | 4 | error_code | Error/status code |
| +0x0C | 4 | has_changed | Set to 1 when command changes |
| +0x10 | 4 | reserved | - |
| +0x14 | 4 | state | 0=idle, 1=pending, 2=running, 3=complete |
| +0x18 | 4 | cmd_count | Number of commands added |
| +0x1C | 4 | start_tick | GetTickCount() at queue start |
| +0x20 | 4 | last_cmd_id | ID of last added command |
| +0x24 | 4 | reserved | - |
| +0x28 | 4 | cmd_buf_start | Pointer to command entry buffer |
| +0x2C | 4 | cmd_buf_end | Pointer past last command entry |

### Command Entry Structure (32 bytes, stride 0x20)

Each entry in the command buffer at `[this+0x28]`:

| Offset | Field | Description |
|--------|-------|-------------|
| +0x00 | cmd_obj_ptr | Pointer to MAID object (has vtable with Execute at +0x5c, +0x68) |
| +0x04 | param1 | First parameter (typically MAID operation code) |
| +0x08 | param2 | Second parameter |
| +0x0C | param3 | Third parameter |
| +0x10 | param4 | Fourth parameter |
| +0x14 | entry_state | 0=pending, 1=executing, 2=complete |
| +0x18 | param6 | Sixth parameter |
| +0x1C | param7 | Callback or context |

## CCommandQueue Virtual Methods

| Index | Address | Method | Description |
|-------|---------|--------|-------------|
| 0 | 0x10014890 | Destructor | Scalar deleting destructor |
| 1 | 0x1000FF90 | (pure virtual) | - |
| 2 | 0x10014440 | **AddCommand** | Stores command params in buffer, increments count |
| 3 | 0x100149B0 | **Start** | Records tick, notifies manager, sets state=2 |
| 4 | 0x10012200 | **Stop** | If running/complete, calls StopAll on entries |
| 5 | 0x1000FFA0 | GetState | Returns state field |
| 6 | 0x1000FFB0 | **IsIdle** | Returns `state == 0` |
| 7-10 | 0x1000FFxx | (pure virtual) | Override points for subclasses |
| 11 | 0x100148C0 | **CopyFrom** | Deep-copies queue state from another instance |
| 12-13 | 0x10010000 | (pure virtual) | - |
| 14 | 0x10014030 | **Reset** | Sets state=0, processes pending queue |
| 15 | 0x100144D0 | **Cleanup** | Frees command buffer, self-destructs if flagged |
| 16 | 0x100100C0 | ConditionalCB | Calls vtable[4] unless error code -0x7b |
| 17 | 0x100100D0 | (stub) | 3 bytes, returns |
| 18-19 | - | (pure virtual) | - |

## CCommandQueueManager (0x101319ac)

The manager drives execution of queued commands. Key method is **Execute** (vtable[5]).

| Index | Address | Size | Method |
|-------|---------|------|--------|
| 0 | 0x10014050 | 27 | Destructor |
| 1 | 0x10014940 | 100 | **NotifyManager** — checks status, queues PtrWrapper if ready |
| 2 | 0x10013980 | 154 | **ProcessQueue** — iterates & dispatches |
| 3 | 0x100117F0 | - | (pure virtual) |
| 4 | 0x10011790 | 95 | **StopAll** — aborts pending commands |
| 5 | 0x10014510 | 680 | **Execute** — main execution engine |
| 6 | 0x100118A0 | - | (pure virtual) |

### Execute Logic (FUN_10014510, 680 bytes)

The main execution engine at `NikonScan4.ds:0x10014510`:

1. **If queue has entries** (`[this+0x08] != 0`):
   - Records start tick via `GetTickCount()`
   - Gets last command entry from `[this+0x0C]-4`
   - Iterates command entries in buffer
   - For each pending entry (state=0):
     - Stores command params for tracking
     - Calls `[cmd_vtable+0x48](cmd_obj, param1)` — pre-execute notification
     - Sets queue state to 3 (executing)
     - Records execution tick
     - **Calls `[cmd_vtable+0x5c](cmd_obj, p1, p2, p3, p4, callback, queue)`** — the actual MAID operation
     - Checks if the current queue was removed during execution
     - Returns 1 (executed something)
   - For executing entry (state=1):
     - Calls `[cmd_vtable+0x5c](cmd_obj, 0, 0, 0)` — poll/continue
     - Returns 1

2. **If queue is empty**, checks secondary source:
   - Calls `FUN_100707a0()` for pending MAID module operations
   - Iterates, calling `[entry_vtable+0x74]()` — direct MAID EntryPoint call
   - Also checks timed command list (DAT_10165374):
     - Uses `GetTickCount()` delta to decide if timed command is due
     - Calls `[cmd_vtable+0x5c](cmd, 0, 0, 0)` when time expires

### StopAll Logic (FUN_10011790, 95 bytes)

Iterates all command entries:
- **state=0** (pending): Calls `[cmd_vtable+0x68](p1, p2, p3, p4, queue, -0x7b)` — cancel with error
- **state=1** (executing): Calls `[cmd_vtable+0x5c](cmd, 0xb, 0, 0, 0, 0, 0)` — abort command

## CQueueAcquireImage (0x1013ea64)

Extends CCommandQueue for image acquisition. Overrides vtable entries [15-18]:

| Index | Base | Override | Method |
|-------|------|----------|--------|
| 15 | 0x100144D0 | **0x100C08A0** | Cleanup — signals acquisition complete |
| 16 | - | 0x100C0970 | (small override) |
| 17 | - | 0x100C0A80 | (small override) |
| 18 | - | 0x100C0A40 | (small override) |

### CQueueAcquireImage Object Layout (extends base)

| Offset | Field | Description |
|--------|-------|-------------|
| +0x34 | cancel_token | Checked by `FUN_1011d400` for cancellation |
| +0x38 | source_id | Scanner source identifier |
| +0x3C | callback_obj | Pointer to callback interface |
| +0x40 | callback_ctx | Context passed to callback |
| +0x44 | completed_flag | Set to 1 after notification sent |

### Cleanup Override (FUN_100c08a0)

1. If acquisition succeeded (param2 != 0):
   - Check cancellation token at `[this+0x34]`
   - If not cancelled: call `[singleton+0x1e8](source_id)` — validate source
   - If valid and callback exists: call `[callback+0x0C](ctx, this)` — notify completion
2. If not yet notified (`[this+0x44] == 0`):
   - Call `[singleton+0x1ec](source_id, 5, code, error)` — report status
   - Set completed flag
   - If callback exists: call `[callback+0x10](ctx, source_id, 5, 2, error, this)`

## CStoppableCommandQueue (0x101353ac)

Extends CCommandQueue with cancellation and UI error reporting. Overrides [14-18] and adds extra methods.

| Index | Override | Method |
|-------|----------|--------|
| 14 | 0x1004CD70 | **Reset** — calls base Reset + `FUN_10020100` |
| 15 | 0x1004CD90 | (override) |
| 16 | 0x1004D0C0 | **StatusHandler** (573 bytes) — handles errors/progress |
| 17 | 0x1004CDF0 | (override) |
| 18 | 0x1004CDC0 | **FinishHandler** — cleans up after completion |

### StatusHandler (FUN_1004d0c0)

Maps MFC control IDs to scan operation types:
- `0x46B` → operation 4 (final scan)
- `0x46E` → operation 1 (preview)
- `0x470` → operation 2 (thumbnail)
- `0x471` → operation 5 (?)
- `0x472` → operation 3 (autofocus)
- `0x474` → operation 6 (?)

Error handling by MAID error code:
- `-0x7A` (=-122, MAID_ERROR_BUSY): Shows string 0x4017 ("scanner busy")
- `0x182` (=386, specific error): Shows string 0x401B
- `-0x76` (=-118, MAID_ERROR_TIMEOUT): Shows string 0x4018 ("timeout")
- `-0x7B` (=-123, MAID_ERROR_CANCELLED): Calls `FUN_10021fa0` + `FUN_1006b1b0`
- Other errors: Reports via `FUN_1006b150`

## CProcessCommand (0x1013e7e4)

A command that wraps a synchronous MAID operation with a Windows message pump, preventing the UI from freezing during long operations.

### Execute (FUN_100c0560, 337 bytes)

Two execution modes based on param2:

**Mode 0 (non-blocking)**:
1. Call `[this+0x1C]()` — Start operation
2. Loop: call `[this+0x20]()` — check completion
3. If not done: call `[this+0x24]()` — advance/poll
4. Call `[this+0x14]()` — finalize
5. Check `[this+0x10]()` for error → return success/fail

**Mode 1 (blocking with message pump)**:
1. Call `[this+0x1C]()` — Start operation
2. Set up `FUN_100c04c0` (progress callback)
3. Loop until done or error:
   - `timeGetTime()` + 100ms window
   - `PeekMessageA()` — process Windows messages
   - Call `[thread+0x64]()` — process MFC idle
   - Call `[thread+0x68](count++)` — pump messages
   - Check `[this+0x20]()` — completion
   - Check `[this+0x10]()` — error
4. Call `[this+0x14]()` — finalize

## MAID Call Flow

The MAID call chain from NikonScan4.ds to LS5000.md3:

```
CCommandQueueManager::Execute
  → iterates command entries
  → calls [cmd_vtable+0x5c](obj, opcode, capID, dataType, data, callback, context)
     ↓
CFrescoMaidModule::CallMAID  (vtable[23], FUN_1007a1f0)
  → checks [this+100] (module loaded?)
  → gets device handle via [param2_vtable+0x68]()
  → calls [this+0x74](device_handle, opcode, capID, dataType, data, callback, context)
     ↓
MAIDEntryPoint (loaded from LS5000.md3 via LoadLibraryA/GetProcAddress)
  → LS5000.md3 processes the MAID command
  → eventually calls NkDriverEntry to send SCSI CDBs
```

## MAID Operation Codes (from scan workflow)

Observed in the scan workflow function `FUN_1003b200`:

| Code | Hex | Description |
|------|-----|-------------|
| 0x25 | 0x25 | Scan direction/orientation |
| 0x8007 | 0x8007 | Multi-sample mode |
| 0x800C | 0x800C | ICE (infrared dust removal) enable/disable |

These are MAID capability IDs passed to `[obj+0x5c]` with opcode 6 (Set capability):
```c
(*vtable_0x5c)(obj, 6, capID, dataType, value, 0, 0)
```

## Key Globals

| Address | Type | Description |
|---------|------|-------------|
| 0x10165364 | DWORD | Last Execute start tick |
| 0x10165368 | DWORD | Current tick for timed commands |
| 0x10165374 | ptr | Timed command list start |
| 0x10165378 | ptr | Timed command list end |

## Relationship to Scan Workflows

The scan workflow in `FUN_1003b200` (8430 bytes, the `StartScan` handler):

1. Gets list of scan sources via `FUN_10104240`/`FUN_10104280`
2. For each source, checks film type (4=negative), exposure settings
3. Creates dialog prompts for user confirmation (calibration, exposure warnings)
4. Dynamic-casts MAID objects: `__RTDynamicCast(CMaidBase → CTwainMaidImage)`
5. Configures scan parameters on the MAID image object:
   - ICE enable (0x800C)
   - Scan direction (0x25)
   - Multi-sample (0x8007)
6. Sets up ROI (Region of Interest) via RECT structures
7. Creates `CStoppableCommandQueue` with control ID `0x3422`
8. Queues scan operations through the command system
9. Handles multi-frame batching for film strips

## Related KB Docs

- [TWAIN Dispatch Architecture](twain-dispatch.md) — how TWAIN operations reach the queue system
- [LS5000.md3 SCSI Commands](../ls5000-md3/) — what MAID calls translate to at the SCSI level
