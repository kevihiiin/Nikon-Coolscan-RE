# Phase 4: SCSI — Attempt Log

**Status**: In Progress — INQUIRY and REQUEST SENSE working, TUR/MODE SENSE blocked

---

## 2026-03-17 — Phase 4 Initial Implementation

### Goal
Get the firmware to handle a full SCSI initialization sequence: TUR → INQUIRY → MODE SENSE → MODE SELECT → SET WINDOW

### TCP Bridge Extensions

Extended the TCP bridge protocol with new message types:
- 0x05: Data-In query (drain ISP1581 EP2 IN FIFO)
- 0x06: Data-Out inject (push to ISP1581 EP1 OUT FIFO)
- 0x07: Completion poll (check cmd_pending + sense + EP2 data)
- 0x08: RAM read (read arbitrary memory for debugging)
- 0x84/0x85/0x86/0x88: New response types

Added `send_tcp_frame()` helper and response data intercept at dispatch return point (0x020DB4).

### Discovery: Command Ready Check Mechanism

**Root cause of SCSI dispatch failure**: The firmware's SCSI dispatcher at 0x020AE2 calls a "command ready" function at 0x013690. This function reads:
1. cmd_pending at 0x400082 (already consumed by main loop before dispatcher runs)
2. ISP1581 DMA Config at 0x600018 (bit 4 = DMA active)
3. RAM word at 0x400088 (must be ≥ 6 for "command ready")

Since cmd_pending is consumed by the main loop before the dispatcher runs, the function relies on 0x400088 as the CDB byte count.

**Fix**: Set 0x400088 = 6 JIT at dispatcher entry (0x020AE2) only when cdb_injected flag is set, clear at opcode lookup (0x020B48).

### Discovery: USB Response Manager Blocking

**Root cause of handler stalling**: SCSI handlers call the USB response manager (JSR @0x01374A) to transfer response data via ISP1581. The response manager:
1. Checks 0x40049A (USB transaction active)
2. Sets cmd_phase at 0x407DC6
3. Calls 0x013C70 (USB DMA setup) which polls ISP1581 registers
4. Calls TRAPA #0 (context switch/yield) when USB isn't ready

Without real USB DMA, the response manager enters a yield-poll loop that blocks Context A permanently, eventually corrupting the context switch save area at 0x400764.

**Fix**: NOP-patch JSR @0x01374A calls within specific SCSI handlers. The handlers still build response data in RAM, and the emulator intercepts it at 0x020DB4 (dispatch return point) by reading from known buffer addresses.

### Handler-Specific Patches Applied

| Handler | Flash Addr | Patch | Purpose |
|---------|-----------|-------|---------|
| Dispatch exec_mode=1 | 0x020D9E | NOP JSR | Prevent yield-poll loop for TUR etc. |
| INQUIRY (0x12) | 0x026042 | NOP JSR | Prevent USB transfer blocking |
| MODE SENSE (0x1A) | 0x02209E | NOP JSR | Prevent USB transfer blocking |
| REQUEST SENSE (0x03) | 0x021932 | NOP JSR | Prevent USB transfer blocking |
| MODE SELECT (0x15) | 0x0219CA | NOP JSR | Prevent USB transfer blocking |
| SET WINDOW (0x24) | 0x026EC6 | NOP JSR | Prevent USB transfer blocking |

### ISP1581 DcInterrupt Fix

Separated ISP1581 register model:
- 0x08 = DcEndpointStatus (per-endpoint events)
- 0x18 = DcInterrupt (global interrupt flags)

After writes to EP data port (0x600020), set dc_interrupt |= 0xFFFF to signal "data accepted". Firmware's polling loops check various bits of this register.

### INQUIRY Response Intercept

At dispatch return (0x020DB4), for data-in commands (exec_mode=0x03):
- INQUIRY (0x12): Read from 0x4008A2 buffer, fill vendor/product/revision from flash strings at 0x170D6
- Response pushed to ISP1581 EP2 IN FIFO for TCP client retrieval

### Results

| Command | Status | Details |
|---------|--------|---------|
| TEST UNIT READY (0x00) | **BLOCKED** | Handler accesses scanner state that corrupts context switch at 0x400764. TUR skipped in init sequence. |
| INQUIRY (0x12) | **WORKING** | Returns correct "Nikon   LS-50 ED        1.02" identification |
| REQUEST SENSE (0x03) | **WORKING** | Via RAM sense read (sense code at 0x4007B0) |
| MODE SENSE (0x1A) | **BLOCKED** | Handler has additional ISP1581 polling beyond the NOPed response manager call |
| MODE SELECT (0x15) | **UNTESTED** | |
| SET WINDOW (0x24) | **UNTESTED** | |

### Key Findings

1. **Context index corruption**: Setting 0x400088 in the main loop causes the firmware's CDB processing to modify USB state structure near 0x400764 (context switch index), changing it from 0x0000/0x0004 to 0x0040 which causes context switch RTE to pop garbage SP.

2. **ISP1581 register map**: Register 0x18 is DcInterrupt (NOT DMA Config as originally labeled). Register 0x08 is DcEndpointStatus. The firmware uses write-back-clear semantics on both.

3. **Response manager pattern**: All data-in handlers follow: `fill buffer on stack/RAM → JSR @0x01374A → transfer loop`. The response manager call must be NOPed per-handler because the dispatch-level response manager call is needed for exec_mode 0x01 but blocks without real USB DMA.

4. **INQUIRY handler builds response at 0x4008A2**: Device type (0x06), vendor/product from flash at 0x170D6. The handler writes all 36 bytes there even with the response manager NOPed.

### Next Steps

- Fix TUR: either NOP the scanner state checks or make the state machine compatible
- Fix MODE SENSE: find and NOP additional ISP1581 polling within the handler
- Add response intercepts for MODE SENSE, MODE SELECT, SET WINDOW
- Test full init sequence end-to-end
