# Phase 7: ISP1581 DMA & Firmware SCSI Handlers — Attempt Log

**Status**: In progress (7.0 gate complete)
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

