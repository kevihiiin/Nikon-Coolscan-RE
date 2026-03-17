# Bridge Development Log

---

## 2026-03-17 — TCP Bridge Implementation

**Target**: External interface for SCSI command injection and status query

### Architecture:
- Non-blocking TCP server bound to 127.0.0.1:5050
- Accepts single client connection
- Polled every 10,000 instructions in orchestrator main loop
- Frame protocol: [type:1][length:2 BE][payload:N]

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

## 2026-03-17 — USB Gadget Bridge (Not Started)

**Plan**: Linux FunctionFS (USB gadget) bridge for real USB host connection
- Would present as actual USB device (VID 04B0, PID 4001)
- Forward USB bulk transfers to/from emulated firmware
- Lower priority — TCP bridge sufficient for protocol testing
- Requires Linux kernel USB gadget support (configfs)
