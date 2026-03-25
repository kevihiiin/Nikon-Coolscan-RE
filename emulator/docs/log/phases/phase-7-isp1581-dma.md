# Phase 7: ISP1581 DMA & Firmware SCSI Handlers — Attempt Log

**Status**: Phase 7.0 complete, Phase 7.1 INQUIRY+REQUEST SENSE working via firmware USB
**Milestone**: Firmware sends SCSI responses through USB path (INQUIRY, REQUEST SENSE, MODE SENSE, GET WINDOW via firmware handlers)

---

## Session 1 — 2026-03-24 (Phase 7.0 GATE: ISP1581 Register Trace)

**Goals**: Resolve 3 unknowns blocking all Phase 7 implementation:
1. Which ISP1581 register offsets does the response manager access?
2. Which DcInterrupt bits does firmware check?
3. Does the response manager call RAM USB code at 0x4010A0?

**Method**: Un-NOPed INQUIRY handler's 2 patches (0x026042 JSR @0x01374A, 0x02604A JSR @0x014090), ran firmware dispatch with ISP1581 trace logging, stuck-PC detector, and RAM USB code PC range monitor.

### Gate Findings

**Answer 1 — ISP1581 Register Access Catalog:**

| Offset | Register | Direction | Value | Purpose |
|--------|----------|-----------|-------|---------|
| 0x18 | DcInterrupt (byte read, high byte) | R | bit 12 checked | Response manager entry check |
| 0x2C | EP Control | W | 0x0002 | Configure endpoint for transfer |
| 0x1C | DcBufferLength | R | expected non-zero | Buffer available check |
| 0x18 | DcInterrupt | W | 0x1000 | Clear bit 12 (write-back) |
| 0x20 | EP Data Port | R | 64 word reads | Data transfer reads CDB from FIFO |
| 0x18 | DcInterrupt | W | 0x8000 | Clear bit 15 (write-back) |
| 0x2C | EP Control | W | 0x0005 | Set DMA mode 5 for data-in |
| 0x28 | ControlFunction | W | 0x0010 | CLBUF (clear buffer) |

**Answer 2 — DcInterrupt Bits Used:**
- **Bit 12 (0x1000)**: "EP TX Ready" — response manager at FW:0x013C8E uses `BTST #4, @ER6` (ER6=0x600018) to check high byte bit 4 = register bit 12. Firmware polls this before proceeding. **Must be always set** in our model (EP2 IN FIFO has unlimited capacity).
- **Bit 15 (0x8000)**: Cleared by data transfer function after EP Data Port reads. Purpose unclear, possibly "host data available" indicator.
- Firmware uses write-back-clear semantics on DcInterrupt.

**Answer 3 — RAM USB Code:**
- **NOT called.** No PC entered 0x4010A0-0x4011A2 range during INQUIRY dispatch. The RAM USB code is likely only used during IRQ1-driven USB transfers, not the response manager's PIO path.

### ISP1581 Register Offset Correction

**design-gaps.md offsets 0x24 and 0x84 were NOT accessed.** The firmware uses:
- 0x18 (DcInterrupt), 0x1C (DcBufferLength), 0x20 (EP Data Port), 0x28 (ControlFunction), 0x2C (EP Control)
- The "DMA config" at 0x24 and "DMA count" at 0x84 from the original isp1581.rs comments are endpoint management registers, NOT ISP1581 DMA engine registers. The firmware does NOT use the ISP1581's DMA engine — it uses PIO (word-by-word writes to EP Data Port).

### Response Manager Flow (0x01374A → 0x013C70)

1. Load ER6 = 0x600018 (DcInterrupt address)
2. Check cmd_pending (0x400082) — if set, clear and return "had pending"
3. BTST #4 on byte at 0x600018 — test DcInterrupt bit 12
4. If not set → check USB session (0x407DC7), yield (TRAPA), loop
5. If set → write EP Control = 0x0002, read DcBufferLength (0x1C)
6. If DcBufferLength == 0 → clear DcInterrupt, CLBUF, return "not ready"
7. If DcBufferLength != 0 → clear DcInterrupt bit 12, continue to return "ready"

### Data Transfer Flow (0x014090)

1. Read 64 words (128 bytes) from EP Data Port (0x20) — this is the CDB that was in EP1 OUT FIFO
2. Clear DcInterrupt bit 15 (write 0x8000)
3. Write EP Control = 0x0005 (DMA mode 5 — data-in transfer direction)
4. Then writes INQUIRY response data word-by-word to EP Data Port (0x20)

**Key insight**: The data transfer function reads 128 bytes from EP1 OUT FIFO FIRST (the original CDB from the host), THEN writes response data to EP2 IN. Our current flow writes CDB directly to RAM, so EP1 OUT is empty when the data transfer function tries to read it.

### Implementation Changes Made

1. **ISP1581 DcInterrupt bit 12 always set** (`isp1581.rs`): Added `IRQ_EP_TX_READY = 1 << 12`, always OR'd into DcInterrupt reads. The response manager's BTST check now passes.
2. **DcBufferLength at offset 0x1C** (`isp1581.rs`): Returns 64 (full-speed max packet size) instead of 0. Response manager's non-zero check passes.
3. **Stuck-PC detector** (`orchestrator.rs`): Break if PC unchanged for 1000 iterations.
4. **RAM USB code PC monitor** (`orchestrator.rs`): Log if PC enters 0x4010A0-0x4011A2.
5. **TRAPA logging demoted** to trace level (was warn, too spammy).

### Result

Handler completed in 1313 instructions, sense_key=0 (GOOD), 0 bytes data output. The missing output is because EP1 OUT FIFO was empty — the data transfer function read 128 bytes of zeros (no CDB) and produced no INQUIRY data. **Fix for Phase 7.1**: inject the CDB into EP1 OUT FIFO before firmware dispatch so the data transfer function can read it.

### Next Steps (Phase 7.1)

1. In `scsi_command()`, when `firmware_dispatch` is true, inject CDB into EP1 OUT FIFO (padded to 128 bytes) via `bus.isp1581_inject()` BEFORE calling `firmware_dispatch_scsi()`.
2. After handler returns, drain EP2 IN FIFO for the response data.
3. This should produce INQUIRY data from the firmware handler.
4. The ISP1581 DMA state machine from the plan is NOT needed for the initial implementation — firmware uses PIO (word writes to EP Data Port), not ISP1581's DMA engine.

**All 194 tests pass.** (28 e2e + 133 core + 33 peripherals)

## Session 2 — 2026-03-25 (Phase 7.1: Firmware USB Data Path + Dispatcher Routing)

**Goals**: Get firmware SCSI handlers to produce actual response data through the ISP1581 USB path.

### CDB FIFO Injection
- `scsi_command()` now injects CDB into EP1 OUT FIFO (384 bytes, CDB repeated every 128 bytes)
- Firmware reads CDB from FIFO at multiple points: dispatcher init, response manager buffer setup, data transfer
- Data transfer function at FW:0x014090 reads CDB via JSR @0x016458, then calls write function at FW:0x012304

### USB State Dependencies Found
| Variable | Address | Purpose | Fix Applied |
|----------|---------|---------|-------------|
| cmd_pending | 0x400082 | Response manager exit signal | Set on TRAPA when return addr = 0x01376E |
| usb_event_flag | 0x400085 | Data transfer abort condition | Cleared at PC=0x014090 |
| usb_packet_size | 0x407DCA | DIVXU divisor for word count | Pre-set to 2 (word size) |
| adapter_type | 0x400773 | INQUIRY string selection | Pre-set to 1 (SA-Mount) |
| scanner_init | 0x400877 | REQUEST SENSE build path | Pre-set to 1 |
| sense_type | 0x400880 | Sense response format | Pre-set to 0x04 |

### ISP1581 DcInterrupt Bits
- Bit 12 (0x1000): IRQ_EP_TX_READY — always set, response manager entry check
- Bit 15 (0x8000): IRQ_EP_TX_COMPLETE — set on EP Data Port writes, state update check at FW:0x014014

### Dispatcher Routing (Major Architecture Change)
- Changed from direct handler call to routing through firmware dispatcher at 0x020AE2
- Dispatcher sets up correct stack frame via JSR @0x016458 (CDB read/stack relay)
- Dispatch-level response manager calls (11 NOP patches) remain NOPed
- Handler-internal USB calls un-NOPed for testing (0x021932/0x02193A for REQUEST SENSE)
- Handlers receive correct byte count (R5=0x24 for INQUIRY, R5=0xFEBC stack ptr for REQUEST SENSE)

### INQUIRY Handler Results
- Handler runs through full USB data path (write function 0x012304 called 18 times)
- Buffer at 0x4008A2 has device type 0x06 but vendor/product strings are zeros
- Handler's string copy depends on firmware init state not fully set in our emulation
- 176 bytes written to EP2 IN FIFO (correct mechanism, wrong content)

### REQUEST SENSE Handler Results — BREAKTHROUGH
- With 0x400877=1 and 0x400880=0x04, handler calls sense build function at FW:0x0111F4
- Build function produces correct SCSI sense response: [0x70, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x0B, ...]
- Data appears at offset 80 in 104-byte output (offset issue in stack buffer layout)
- Dispatcher init at FW:0x013E0A copies FIFO data to 0x4007DE, overwriting sense template
- Sense rebuild at FW:0x011222 runs AFTER handler reads (too late)
- The 0x70 response byte is the first firmware-generated SCSI content to flow through the USB path

### Write Function Traced (FW:0x012304)
- Writes R1 bytes to DcBufferLength register (0x60001C)
- Then writes R1/2 words to EP Data Port (0x600020) in a loop
- Reads data from RAM buffer at ER0, writes word-by-word to ISP1581
- Called by data transfer at 0x0140C0 for full packets, 0x0140E4 (via 0x0122C4) for remainder

### Remaining Issues
1. Data offset: sense data at byte 80 instead of byte 0 (byte count parameter from stack relay)
2. INQUIRY content: vendor/product strings zeros (need more firmware init state)
3. Both traced to stack frame parameter passing — the stack relay 0x016458 reads byte count from caller's stack frame, which depends on how the dispatcher sets up parameters

### Next Steps
- Fix byte count parameter to get correct data size
- Investigate INQUIRY init state dependencies
- All 196 tests pass (30 e2e + 133 core + 33 peripherals)

### Session 2 Addendum — 2026-03-25 (Phase 7.1 Completion)

**Final Results**:
- REQUEST SENSE: firmware produces [70, 00, 00, 00, 00, 00, 00, 0B] at offset 0 ✓
  - Dispatch-level data path via FW:0x01117A → 0x0111F4 (sense build) → 0x013FB2 → 0x012304 (write)
  - 8-byte compact sense summary header stripped from output
  - Response code (0x70) and sense key match Rust emulation
- INQUIRY: firmware produces "Nikon   LS-50 ED        1.02" ✓
  - Handler-internal data path via un-NOPed 0x026042/0x02604A
  - INQUIRY buffer at 0x4008A2 pre-populated from flash template at 0x170CE
  - Header: [06, 80, 02, 02, 1F, 00, 00, 00] (scanner, SCSI-2, format 2)
- NOP patch added: 0x011186 (post-handler response manager in FW:0x01117A)
- Total NOP patches: 27 (was 26: 5 USB init + 11 dispatch + 10 handler + 1 post-handler)

**Architecture Findings**:
- Two different data transfer architectures in firmware:
  1. Dispatch-level: post-handler at 0x01117A sends compact sense via 0x013FB2
  2. Handler-internal: individual handlers send their own response via 0x014090
- Dispatch-level always sends 8-byte compact summary + actual response data
- REQUEST SENSE uses dispatch-level (handler-internal NOPed)
- INQUIRY uses handler-internal (dispatch-level sends wrong data for INQUIRY)

**Tests**: 196 passing (30 e2e + 133 core + 33 peripherals)

