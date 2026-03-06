# NikonScan4.ds Analysis Log
<!-- STATUS HEADER - editable -->
**Binary**: binaries/software/NikonScan403_installed/Twain_Source/NikonScan4.ds | **Functions identified**: ~80 key functions | **Classes reversed**: 12 RTTI classes with vtables
---
<!-- ENTRIES BELOW - APPEND ONLY -->

## 2026-02-27 -- Session 3: Phase 3 Start — TWAIN Dispatch Analysis

### Attempt 1: DS_Entry Export Analysis
**Tool**: r2 + Ghidra headless | **Target**: DS_Entry @ 0x10091F50
**What**: Traced DS_Entry dispatch path to find how TWAIN triplets (DG/DAT/MSG) are routed.
**Finding**: DS_Entry is a thin MFC wrapper. Gets singleton from global 0x101656ac, calls vtable[0].
**Confidence**: High (verified from disassembly)

### Attempt 2: Identify Singleton Object Type
**Tool**: RTTI vtable tracing | **Target**: globals 0x101656a8 and 0x101656ac
**What**: Traced RTTI Complete Object Locators to identify vtable ownership.
**Finding**: Two related globals:
- `0x101656a8` = CNkTwainSource singleton (vtable 0x10139a74), created at 0x10091810
- `0x101656ac` = dispatch entry sub-object at offset +4 within CNkTwainSource (vtable 0x10139aa4)
Constructor at 0x10091e40 stores vtable 0x10139aa4 and writes to 0x101656ac.
**Confidence**: High

### Attempt 3: Main TWAIN Dispatch Function
**Tool**: r2 disassembly | **Target**: 0x10091e60 (dispatch entry vtable[0])
**What**: Full reverse of the 239-byte dispatch function.
**Finding**: Dispatch builds combined key `(DAT << 16) | MSG`. Checks identity list (is DS open?).
- If open: calls table-driven handler dispatch (0x10092040)
- If not open: only handles OPENDS (0x30401), STATUS/GET (0x80001), IDENTITY/GET (0x30001)
**Confidence**: High (all constants decode correctly against TWAIN spec)

### Attempt 4: Handler Table Dispatch (0x10092040)
**Tool**: r2 disassembly | **Target**: 0x10092040 (242 bytes)
**What**: Traced the table-driven triplet handler lookup.
**Finding**: Linked list of handler entries, each with DG, (DAT<<16)|MSG key, handler_type, handler_func.
Matched handlers called via 0x10090e70 which has type-based dispatch:
- Type 0: call handler()
- Types 1-10, 258-266: call handler(pData)
- Type 257: call handler() (notification)
**Confidence**: High

### Attempt 5: Module Loading (MAIDEntryPoint)
**Tool**: r2 + xref of "MAIDEntryPoint" string | **Target**: 0x1007a250
**What**: Found how NikonScan4.ds loads .md3 modules.
**Finding**: LoadLibraryA + GetProcAddress("MAIDEntryPoint"). Stores func ptr at [this+0x74], handle at [this+0x78].
**Confidence**: High

### Attempt 6: Ghidra Headless Decompilation
**Tool**: Ghidra analyzeHeadless | **Target**: Full binary
**What**: Wrote and ran decompile_nikonscan4.java script for key functions.
**Finding**: Full analysis took 47 seconds. Decompiled DS_Entry, StartScan, GetSource, CanEject, Eject, module loader, and other key functions. Many vtable targets still show as FUN_ (need manual naming).
**Confidence**: High

### KB Written
- `docs/kb/components/nikonscan4-ds/twain-dispatch.md` — Full TWAIN dispatch architecture

## 2026-02-27 -- Session 3 (continued): Command Queue & Scan Workflow Analysis

### Attempt 7: MAID Call Chain Decompilation
**Tool**: Ghidra headless (decompile_maid_chain.java) | **Target**: CFrescoMaidModule vtable + 0x100B wrappers
**What**: Decompiled all 20 CFrescoMaidModule vtable entries and MAID wrapper functions.
**Finding**: Core MAID call at FUN_1007a1f0 (vtable[23]):
- Checks [this+100] for module loaded
- Gets device handle via [param2_vtable+0x68]()
- Calls [this+0x74](device_handle, p3..p8) — MAIDEntryPoint
- FUN_1007a2e0 (vtable[19]) = module unload (FreeLibrary)
- FUN_10075190 (vtable[0]) = module open/init
**Confidence**: High

### Attempt 8: Command Queue RTTI-to-Vtable Tracing
**Tool**: Ghidra headless (trace_command_queues.java) | **Target**: 12 RTTI classes
**What**: Found vtables for CCommandQueue, CCommandQueueManager, CProcessCommand, CQueueAcquireImage, CQueueAcquireDRAGImage, CQueueNotifier, CStoppableCommandQueue, CProcessCommandManager, CFrescoTwainSource, CFrescoMaidModule, CFrescoMaidSource.
**Finding**: Full vtable layouts for all classes. Key relationships:
- CCommandQueue is base class (20 vtable entries)
- CQueueAcquireImage overrides [0,15-18] for image acquisition
- CStoppableCommandQueue overrides [0,14-18] for cancel support
- CCommandQueueManager::Execute (680 bytes, FUN_10014510) is the main execution engine
**Confidence**: High (all vtables match RTTI COL chains)

### Attempt 9: Command Queue Execution Engine Analysis
**Tool**: Ghidra decompilation | **Target**: FUN_10014510 (CCommandQueueManager::Execute)
**What**: Fully reversed the 680-byte execution engine.
**Finding**: Two execution paths:
1. If queue has entries: iterate command buffer, call [cmd_vtable+0x5c](7 args) for actual MAID operations
2. If empty: check secondary source via FUN_100707a0, also process timed commands using GetTickCount delta
Command entry structure is 32 bytes with state machine (0=pending, 1=executing).
**Confidence**: High

### Attempt 10: CProcessCommand Message Pump Analysis
**Tool**: Ghidra decompilation | **Target**: FUN_100c0560 (CProcessCommand::Execute)
**What**: Reversed the 337-byte CProcessCommand execution method.
**Finding**: Two modes:
- Mode 0: Non-blocking loop (Start → poll completion → advance → finalize)
- Mode 1: Blocking with Windows message pump (PeekMessageA + timeGetTime 100ms windows)
This prevents UI freeze during long MAID operations.
**Confidence**: High

### Attempt 11: Scan Workflow Tracing
**Tool**: Ghidra headless (trace_scan_workflows.java) | **Target**: StartScan chain + 0x1003-0x1004 range
**What**: Traced StartScan export → FUN_1003d420 → FUN_1003b200 (8430-byte main scan function).
**Finding**: FUN_1003b200 is the central scan workflow orchestrator:
- Gets scan source list, iterates each source
- Checks film type, exposure, calibration requirements
- Dynamic casts CMaidBase → CTwainMaidImage via __RTDynamicCast
- Configures MAID capabilities: ICE (0x800C), scan direction (0x25), multi-sample (0x8007)
- Sets up ROI via RECT structures
- Creates CStoppableCommandQueue with control ID 0x3422
- CStoppableCommandQueue::StatusHandler maps MFC IDs: 0x46B=final scan, 0x46E=preview, 0x470=thumbnail, 0x472=autofocus
**Confidence**: High

### Attempt 12: CQueueAcquireImage Cleanup Analysis
**Tool**: Ghidra decompilation | **Target**: FUN_100c08a0
**What**: Reversed the 201-byte cleanup/completion handler.
**Finding**: On acquisition completion:
- Checks cancel token at [this+0x34]
- Validates source via [singleton+0x1e8](source_id)
- Notifies callback via [callback+0x0C](ctx, this) for success
- Or reports status via [singleton+0x1ec](source_id, 5, code, error) for failure
**Confidence**: High

### Attempt 13: MAID Error Code Mapping
**Tool**: Decompilation analysis | **Target**: FUN_1004d0c0 (CStoppableCommandQueue::StatusHandler)
**What**: Mapped MAID error codes to UI strings.
**Finding**:
- -0x7A (122): MAID_ERROR_BUSY → string 0x4017
- -0x76 (118): MAID_ERROR_TIMEOUT → string 0x4018
- -0x7B (123): MAID_ERROR_CANCELLED → triggers FUN_1006b1b0
- 0x182 (386): Specific error → string 0x401B
Also mapped capability IDs to UI status strings (FUN_1006aa90):
- 0=completion, 2=0x3420, 0x14=0x3407, 0x1C=0x3406, 0x1E=0x3405
- 0x8010=0x3437, 0x801A=0x3411, 0x801B=0x3412, 0x801D=0x3410, 0x80A3=0x3436
**Confidence**: High

### KB Written
- `docs/kb/components/nikonscan4-ds/command-queue.md` — Full command queue architecture

## 2026-02-27 -- Session 4 (continued): SCSI Sequences, SET WINDOW Mapping, Vtable Architecture

### Attempt 14: Python Binary Search for SCSI Factory Callers
**Tool**: Python script (E8 CALL rel32 scan) | **Target**: All 14 SCSI factory functions
**What**: Searched LS5000.md3 binary for E8 instructions targeting each factory address.
**Finding**: Complete caller map: SET_WINDOW=5 callers, SCAN=1, TUR=10, INQUIRY=5, SEND_DIAG=9, E0/E1/C1=2 each. Main scan area at 0x100b3b10+ has 15 SCSI calls.
**Confidence**: High (verified addresses, cross-referenced with Ghidra)

### Attempt 15: Scan Operation Vtable Discovery
**Tool**: Python binary reader | **Target**: 5 vtable addresses (0x100c526c, 0x100c5290, 0x100c5320, 0x100c5368, 0x100c538c)
**What**: Read 72 bytes at each vtable, decoded as 18 DWORD pointers. Mapped entries [7], [8], [16], [17] to factories/handlers.
**Finding**: 5 scan operation types:
- Base (0x100c526c): Init-only (both phases use same factory)
- Type A (0x100c5290): Init + Main Scan (Phase B adds TUR/SEND_DIAG/SET_WINDOW)
- Type B (0x100c5320): Simple Scan (Phase B = full scan: TUR→SCAN→SET_WINDOW→GET_WINDOW→READ10→WRITE10)
- Type C (0x100c5368): Focus/Autofocus (E0→C1→E1 vendor loop)
- Type D (0x100c538c): Advanced Operations (INQUIRY + READ10 calibration)
**Confidence**: High (all vtable entries resolved to valid functions)

### Attempt 16: Decompile Scan Controller Functions
**Tool**: Ghidra headless (decompile_scan_controller.java) | **Target**: 12 key scan functions
**What**: Decompiled init factory (FUN_100af1f0), focus factory (FUN_100b0380), advanced focus (FUN_100b0c20), I/O factory (FUN_100adec0).
**Finding**: Each factory has a switch on step_code (SCSI opcode) that creates the appropriate command object:
- Init: 0x00=TUR, 0x12=INQUIRY, 0x15=MODE_SELECT, 0x16=RESERVE, 0x1D=SEND_DIAG, 0x25=GET_WINDOW, 0x28=READ10
- Focus: 0x00=TUR, 0x1D=SEND_DIAG, 0xC1=VENDOR_C1, 0xE0=VENDOR_E0, 0xE1=VENDOR_E1
**Confidence**: High (clean decompilation, 824 lines output)

### Attempt 17: Decompile All Scan Phase Vtable Methods
**Tool**: Ghidra headless (decompile_scan_phases.java) | **Target**: All factory and handler functions from 5 vtables
**What**: Decompiled Type A PhaseB factory, Type A handler, init handler, Type B factories/handlers, Type C handlers, Type D operations, step sequencer.
**Finding**: 1607 lines of decompiled code. Key discoveries:
- Init handler (FUN_100b3060, 983 bytes) dynamically inserts SEND_DIAG steps via FUN_100aed10
- Type B PhaseB factory handles 7 SCSI opcodes including SCAN (0x1B) with 0x28-byte descriptor
- Focus handler uses timeGetTime() with 5-second timeout for E0→C1→E1 loop convergence
- Step queue is a linked list at object+0x438 with 16-byte step descriptors
**Confidence**: High

### Attempt 18: SET WINDOW Parameter Builder Analysis
**Tool**: Ghidra decompilation | **Target**: FUN_100b2b30 (1268 bytes)
**What**: Fully analyzed the SET WINDOW parameter builder byte-by-byte.
**Finding**: Complete mapping of ~20 MAID param IDs to specific SET WINDOW descriptor bytes:
- 0x121/0x122 → bytes 10-13 (resolution)
- 0x100/0x101/0x124 → bytes 30-32 (brightness/contrast/threshold)
- 0x125/0x126/0x127 → bytes 33-35 (composition/bit-depth/halftone)
- 0x128/0x129/0x12a/0x131 → bytes 48-49 (vendor flags)
- param_4 switch → byte 50 (multi-sample: 0x20→1, 0x21→2, 0x22→4, 0x23→16, 0x24→32, 0x25→64, 0x31→8)
- Vendor extensions at 0x36+ via FUN_100a0370/100a0bc0 iterator
- ICE/DRAG extensions after vendor area with 0xa20 master enable
**Confidence**: High (every byte traced from decompilation)

### Attempt 19: Parameter Reader Chain Decompilation
**Tool**: Ghidra headless (decompile_param_mapping.java + decompile_param_readers.java) | **Target**: FUN_100aee20, FUN_100aeeb0, FUN_100a05d0, scan area getters, status checkers
**What**: Traced the full parameter value reading chain from SET WINDOW builder to the scanner state object.
**Finding**:
- FUN_100aee20 (30 bytes): Thin dispatcher — if [this+0x430] set, reads overrides; else reads from scanner state via FUN_100a05d0
- FUN_100a05d0 (113 bytes): Looks up param_id in std::map at scanner_state+0x1c, calls parameter object's vtable getter
- FUN_100aeeb0 (263 bytes): Scan area reader — all 4 dimensions use param_id 0x123, different vtable methods per dimension
- FUN_100ae910/1009e660: Status checkers compare packed condition codes against state block at +0x260
- MAIDEntryPoint case 10 (FUN_100275d0): Uses FUN_1001b490(0x8005, 0x1012) to find scan parameter capability
**Confidence**: High

### Attempt 20: Scan Operation Constructor Analysis
**Tool**: Ghidra decompilation (in param_mapping output) | **Target**: FUN_100b45c0 (840 bytes)
**What**: Reversed the scan operation constructor that maps type codes to vtable/flags.
**Finding**: 25+ scan type codes (0x40-0xD6 and 0x800) all map to Type C vtable (0x100c5368). The type code stored at +0x450 controls behavior within handlers. Type 0x80 sets auto-exposure flag, 0xd0 copies scan parameters. Type 0x800 reads custom type from config.
**Confidence**: High

### KB Written
- `docs/kb/scsi-commands/set-window-descriptor.md` — Definitive byte-level SET WINDOW mapping (crown jewel)
- `docs/kb/components/ls5000-md3/scan-operation-vtables.md` — Complete vtable architecture with memory layout
- Updated `docs/kb/components/nikonscan4-ds/scan-workflows.md` — Added per-workflow SCSI sequences, vtable references

## 2026-02-27 -- Session 5 (continued): Eject Workflow, Vendor Extensions, Phase 3 Finalization

### Attempt 21: Eject Workflow Decompilation (NikonScan4.ds)
**Tool**: Ghidra headless (decompile_eject.java + decompile_eject_deep.java) | **Target**: FUN_100318b0, FUN_1002e030, FUN_1001fdc0, FUN_10089c30
**What**: Decompiled the eject workflow chain from NikonScan4.ds export through to MAID dispatch.
**Finding**: FUN_1002e030 (577 bytes) is the eject executor:
- Shows confirmation dialog (MFC Ordinal_1014, string 0x401a)
- Creates 52-byte command queue (vtable PTR_FUN_10132d3c)
- Ctrl key check: NOT held → vtable[0x14c] (film advance), held → vtable[0x148] (eject)
- Execution loop: vtable[0x0c] start, poll vtable[0x18], message pump FUN_100148b0
- Sets [param_1+0x71c] = 1 on completion
**Confidence**: High

### Attempt 22: Eject SCSI Path Verification
**Tool**: Python E8 call scan | **Target**: All 17 SCSI factory addresses, outside scan operation area
**What**: Searched for SCSI factory callers OUTSIDE the scan operation area (0x100af000-0x100b5500).
**Finding**: Only 2 callers exist outside scan operations: INQUIRY at 0x1009EC5B (initial connect) and VENDOR_E1 at 0x100AA5C3 (vendor chain). Zero eject-specific SCSI calls. Confirms eject goes through the scan operation vtable machinery.
**Confidence**: High

### Attempt 23: Vendor Extension Dynamic Registration Discovery
**Tool**: Ghidra headless (decompile_vendor_ext_reg.java) + Python binary analysis | **Target**: FUN_100a2980 (2589 bytes), FUN_100a2820, scanner_state+0x27c
**What**: Traced how the vendor extension list at scanner_state+0x27c is populated.
**Finding**: MAJOR ARCHITECTURAL DISCOVERY — Vendor extension parameters are dynamically self-described by the scanner:
1. During init, host sends GET WINDOW (0x25) to read scanner capabilities
2. FUN_100a2980 parses the response, checking feature flag bits
3. For each supported feature, registers a vendor ext param via FUN_100a2820(+0x27c, param_id, data_size)
4. Data sizes (1/2/4 bytes) come from the scanner response, not hardcoded

Complete vendor extension param ID catalog:
- Group 1 (flags_1 bits): 0x102, 0x103, 0x104, 0x105, 0x106
- Group 2 (flags_2 bits): 0x107, 0x108, 0x109, 0x10a, 0x10b, 0x10c, 0x10d

Each also registered with min/max ranges via vtable+0x24.
**Confidence**: High (all param IDs extracted from decompilation, registration pattern confirmed)

### Attempt 24: FUN_100aee20 Caller Analysis
**Tool**: Python E8 scan | **Target**: All 21 callers of param reader FUN_100aee20
**What**: Extracted param IDs from all callers to build complete MAID internal param catalog.
**Finding**: 19 of 21 callers have statically extractable param IDs (0x100, 0x101, 0x121-0x131, 0xa20, 0x130). 2 callers are in the vendor extension iteration loop where param IDs come from runtime list. Complete static param catalog matched existing documentation.
**Confidence**: High

### KB Updated
- Updated `docs/kb/scsi-commands/set-window-descriptor.md` — Added vendor extension discovery architecture, complete param ID list (0x102-0x10d)
- Updated `docs/kb/components/nikonscan4-ds/scan-workflows.md` — Expanded eject section with deep analysis, added UI→SCSI parameter mapping summary table
