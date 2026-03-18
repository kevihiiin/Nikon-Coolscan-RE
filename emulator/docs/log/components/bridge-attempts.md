# Bridge Development Log

---

## 2026-03-17 — TCP Bridge Implementation

**Target**: External interface for SCSI command injection and status query

### Architecture:
- Non-blocking TCP server bound to 127.0.0.1:6581
- Accepts single client connection
- Polled every 1,000 instructions in orchestrator main loop
- Frame protocol: [length:2 BE][type:1][payload:N]

### Frame types:
| Type | Direction | Purpose |
|------|-----------|---------|
| 0x01 | in | CDB inject (6-16 bytes) |
| 0x02 | in | Phase query |
| 0x03 | in | Sense query |
| 0x81 | out | CDB ack |
| 0x82 | out | Phase (1 byte) |
| 0x83 | out | Sense (2 bytes) |

### Direct RAM injection:
- CDB written to firmware buffer at 0x4007DE (16 bytes)
- cmd_pending flag set at 0x400082 = 0x01
- These addresses from KB analysis of firmware SCSI dispatcher at 0x020AE2
- Bypasses ISP1581 USB transport entirely — firmware reads CDB from RAM directly

### Test client (Python):
- emulator/scripts/tcp_test_client.py
- Sends TUR (00 00 00 00 00 00), queries phase and sense
- Confirmed: CDB bytes appear at correct RAM addresses after injection

### Integration:
- Orchestrator polls bridge.check_clients() every 10K instructions
- On CDB inject: writes to bus, sets flag, sends ack frame
- On phase/sense query: reads from bus addresses, sends response frame

### Current limitation:
- CDB injection works at RAM level but firmware never processes them
- Firmware's SCSI dispatcher at 0x020AE2 unreachable due to context switch crash at ~2.78M
- Phase/sense always return initial values (0x00, 0x0000) because no command has been processed

## 2026-03-17 — USB Gadget Bridge (Implemented)

**Implementation** (Session 6): bridge/src/gadget.rs
- Linux FunctionFS implementation via configfs
- USB gadget with Nikon LS-50 identifiers (VID 04B0, PID 4001)
- EP1 OUT bulk + EP2 IN bulk, full-speed (64B) + high-speed (512B)
- Auto-discovers UDC, implements UsbBridge trait
- CLI: --gadget flag, graceful fallback if setup fails
- Requires root + USB gadget kernel support
- Drop implementation for proper teardown

## 2026-03-17 — TCP Protocol Extensions (Session 7)

Added 5 new message types for Phase 4 SCSI testing:

| Type | Direction | Purpose |
|------|-----------|---------|
| 0x05 | in | Data-In query (drain EP2 IN) |
| 0x06 | in | Data-Out inject (push to EP1 OUT) |
| 0x07 | in | Completion poll (check cmd_pending) |
| 0x08 | in | RAM read (addr:4 + len:2) |
| 0x84 | out | Data-In response |
| 0x85 | out | Completion status (4 bytes) |
| 0x86 | out | Data-Out ACK |
| 0x88 | out | RAM read response |

Added `send_tcp_frame()` helper for cleaner response sending.

## 2026-03-17 — Phase 5 TCP Updates (Session 9)

- TCP payload cap increased from 4096 to 65536 bytes for scan data delivery
- ISP1581 drain cap increased to 65536 bytes for image data
- Test client: 7 new SCSI command functions + full scan sequence mode
- `set_nonblocking` failure now aborts TCP bridge instead of creating blocking listener

---

## 2026-03-17 — Phase 5 Completion Fixes

### TCP poll_tcp multi-frame reading
- Changed from single-frame-per-poll to read ALL available frames per cycle
- Prevents data-out frames from being delayed by 1000 instructions
- Uses collect-then-process pattern to avoid borrow checker issues

### Data-out command buffering
- Data-out commands (0x15, 0x24, 0x2A, 0xE0) now buffer in `pending_dataout_opcode`
- Neither `cdb_injected` nor `cmd_pending` set until data-out frame arrives
- Prevents firmware from seeing premature `cmd_pending=1`
- Completion poll fallback: processes buffered command if no data-out received

### Synchronous SCSI processing
- SCSI commands now processed immediately in `handle_tcp_message`
- No firmware interception needed (removed pre-execute hook)
- Completion polls always return done=1 (synchronous processing)
- Much simpler and avoids all firmware execution timing issues

### EP1 OUT drain fix
- Added `drain_host_data()` to MmioDevice trait
- Added `isp1581_drain_host_data()` to MemoryBus
- All data-out handlers (MODE SELECT, SET WINDOW, WRITE, VENDOR E0) corrected
- Previously drained EP2 IN (device→host) instead of EP1 OUT (host→device)
