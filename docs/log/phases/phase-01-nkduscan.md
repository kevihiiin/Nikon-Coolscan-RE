# Phase 1: USB Transport (NKDUSCAN.dll)
<!-- STATUS HEADER - editable -->
**Status**: Complete
**Started**: 2026-02-20  |  **Completed**: 2026-02-20
**Completion**: 8/8 criteria met
---
<!-- ENTRIES BELOW - APPEND ONLY -->

## 2026-02-20 -- Session 3: Comprehensive NKDUSCAN.dll Analysis

### Criteria Checklist Progress
- [x] NkDriverEntry fully decompiled: 9 function codes, __stdcall(3 params), all handlers mapped
- [x] RTTI class hierarchy recovered: 6 interfaces, 7 concrete classes, vtable layout documented
- [x] DeviceIoControl callsites identified: 5 calls, 3 unique IOCTLs (0x80002008, 0x80002014, 0x80002018)
- [x] CUSB2Command class reversed: Execute method (0x10002b50), 0xD0 phase query, 0x06 sense, chunked data transfer
- [x] USB-to-SCSI wrapping protocol documented: docs/kb/architecture/usb-protocol.md
- [x] NkDriverEntry API documented: docs/kb/components/nkduscan/api.md (all 9 FCs with params/returns)
- [x] NKDSBP2.dll compared: same API, same 9 FCs, only Execute method differs
- [x] All KB docs written with status >= "In Progress" — 5 KB docs written + usb-protocol.md, .gitkeep removed

### Key Findings
1. **Protocol is NOT USB Mass Storage** — uses single-byte opcodes (0xD0 phase query, 0x06 sense) on raw bulk pipes
2. **Version string "1200"** — FC1 validates this during initialization, likely API version identifier
3. **Only vtable slot 3 (Execute) differs** between USB and SBP-2 — all other 9 virtual methods are shared
4. **USB speed detection** — session open queries pipe info to determine USB 2.0 vs 1.1 transfer sizes
5. **Clean interface design** — ICommand/ISession/ICommandManager interfaces are transport-agnostic
6. **Thread safety** — global critical section serializes all NkDriverEntry operations
7. **Error reporting** — status codes (0x11001-0x11006, 0x21008), callback support for async errors

### Tools Used
- radare2 (r2 -q with aaa auto-analysis) — primary disassembly tool
- strings (with -el for wide strings) — string extraction
- Previous Phase 0 exports (all_exports_imports.csv, rtti_classes.json)

### What Remains
- Cross-validation with firmware-side USB handling (Phase 4)

## 2026-02-20 -- Session 3 (continued): Deep Analysis

### Additional Criteria Met
- FC5-FC9 internal mechanics fully decoded (command allocation, error callbacks, vtable dispatch)
- FC2-FC4 close/release sub-functions analyzed (magic 0x8004 validation, session iteration, state flags)
- Worker thread fully analyzed: CSBP2CommandManager::virtual_4 creates thread, sets THREAD_PRIORITY_HIGHEST
- Thread proc at 0x10002880: command queue loop with dequeue/execute/callback/destroy cycle
- STI enumeration deep dive: 0x124-byte device entries, wcsstr "Usbscan" filter
- USB speed detection decoded: max_packet_size 0x40→USB1.1(type 2), 0x200→USB2.0(type 3)
- Command object allocation in fcn.100030a0: 0x1C bytes, vtable selection based on transfer_size flag (0x20000 = USB bulk)
- All KB docs updated with detailed findings
- Phase 1 now 8/8 criteria — COMPLETE

### Key New Findings
1. FC5 command allocation selects CUSB2Command vs CSBP2Command based on transfer_size == 0x20000
2. Error callback mechanism: `[params+0xC]` stores callback fn, called as `callback(params, error_code)`
3. FC7 is full shutdown (not just "get info"): destroys all 3 interface objects, re-enables system sleep
4. Worker thread uses THREAD_PRIORITY_HIGHEST for time-critical scanning
5. 3 events + 2 critical sections for thread synchronization
6. STI device entry size = 0x124 (292 bytes), device path at +0x118
7. USB 1.1 Full Speed: max_packet = 64, USB 2.0 High Speed: max_packet = 512
