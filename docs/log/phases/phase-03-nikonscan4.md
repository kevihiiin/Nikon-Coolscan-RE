# Phase 3: Scan Workflows (NikonScan4.ds)
<!-- STATUS HEADER - editable -->
**Status**: Complete
**Started**: 2026-02-27  |  **Completed**: 2026-02-27
**Completion**: 6/6 criteria met
---
<!-- ENTRIES BELOW - APPEND ONLY -->

## 2026-02-27 -- Session 3: Phase 3 Start

### Criteria Progress
- [x] TWAIN DS_Entry dispatch logic mapped — table-driven (DAT<<16|MSG) handler dispatch via linked list
- [x] Command queue architecture documented — full class hierarchy, vtables, execution engine, object layouts
- [x] Scan workflows traced — StartScan chain through 8430-byte orchestrator, MAID capability configuration
- [x] SCSI command sequences — ALL 5 scan types mapped: Init(7 cmds), MainScan(3), SimpleScan(7), Focus(5+vendor), Advanced(4)
- [x] UI parameter mapping — SET WINDOW descriptor fully mapped: 20+ MAID param IDs → specific byte offsets
- [x] Definitive scan workflow doc — scan-workflows.md is comprehensive (eject, UI→SCSI mapping, vendor ext discovery)

### Completed
- Full TWAIN dispatch architecture reversed (DS_Entry → 0x10091e60 → 0x10092040 → 0x10090e70)
- Singleton architecture: CNkTwainSource at 0x101656a8, dispatch sub-object at 0x101656ac
- Module loading path (LoadLibraryA + GetProcAddress("MAIDEntryPoint"))
- Exported API (59 exports) grouped by function — all use Fresco SDK pattern
- Handler table structure documented: (DG, key, handler_type, handler_func)
- **Command queue class hierarchy**: CCommandQueue→CStoppableCommandQueue/CQueueAcquireImage/CQueueNotifier
- **CCommandQueueManager::Execute** (680 bytes) fully reversed — main execution engine
- **CProcessCommand** message pump architecture (prevents UI freeze)
- **MAID call chain**: CCommandQueueManager→CFrescoMaidModule::CallMAID→MAIDEntryPoint
- **Core MAID call wrapper** at FUN_1007a1f0: [this+0x74](device, p3..p8)
- **Scan workflow orchestrator** FUN_1003b200 (8430 bytes) traced through
- **MAID capability IDs**: 0x800C=ICE, 0x25=scan direction, 0x8007=multi-sample
- **MFC control ID→scan type map**: 0x46B=final, 0x46E=preview, 0x470=thumb, 0x472=autofocus
- **MAID error codes mapped**: -0x7A=busy, -0x76=timeout, -0x7B=cancelled
- KB docs: twain-dispatch.md, command-queue.md

### Session 4 Progress (continued)

#### SCSI Command Sequences — COMPLETED
- Python E8 scan found all SCSI factory call sites (15 in main scan area)
- Discovered 5-type vtable architecture: Base, Type A-D with Phase A/B factories and handlers
- Decompiled ALL factory and handler functions (3 Ghidra scripts, ~4000 lines output)
- Mapped complete SCSI command sequences per workflow type
- KB written: scan-operation-vtables.md

#### UI Parameter → SCSI Parameter Mapping — COMPLETED
- Decompiled FUN_100b2b30 (SET WINDOW builder, 1268 bytes) — maps 20+ MAID param IDs to window descriptor bytes
- Traced full reading chain: FUN_100aee20 → FUN_100a05d0 → std::map tree lookup
- Scan area uses param 0x123 with 4 vtable accessors for X, Y, width, height
- Multi-sample encoding: param_4 switch at byte 50 (0x20→1, 0x21→2, 0x22→4, etc.)
- Vendor extensions iterate via FUN_100a0370/100a0bc0, ICE/DRAG via FUN_1009fce0/1009fc60
- KB written: set-window-descriptor.md (definitive byte-level reference)

#### Remaining for Phase 3 Completion
- Review scan-workflows.md for completeness (criterion 6: definitive reference doc)
- Consider tracing Eject/FilmAdvance through MAID (minor gap)
- Cross-validate SET WINDOW bytes against firmware-side handling (Phase 4 task)

### Session 5 Progress (continued)

#### Eject Workflow — COMPLETED
- Decompiled FUN_1002e030 (577 bytes) — full eject executor with Ctrl-key dispatch
- Confirmed ALL SCSI commands go through scan operation vtables (zero eject-specific SCSI factory calls outside 0x100af000-0x100b5500)
- Eject: vtable[0x148], Film Advance: vtable[0x14c] (Ctrl key differentiates)

#### Vendor Extension Dynamic Discovery — COMPLETED
- MAJOR finding: Vendor extension params are self-described by the scanner via GET WINDOW response
- FUN_100a2980 (2589 bytes) parses GET WINDOW response, registers vendor ext params dynamically
- Complete catalog: 12 vendor extension param IDs (0x102-0x10d), data sizes from scanner
- Updated set-window-descriptor.md with full architecture

#### Phase 3 Criterion 6 — COMPLETED
- scan-workflows.md updated: eject section expanded, UI→SCSI mapping summary table added
- set-window-descriptor.md updated: vendor extension discovery architecture documented
- All 6 criteria now met

### Next Steps
- Begin Phase 4: Firmware analysis (validate SCSI commands from device side)
- Cross-validate vendor extension param IDs against firmware GET WINDOW handler
