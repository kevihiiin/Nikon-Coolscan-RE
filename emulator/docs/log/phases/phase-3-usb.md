# Phase 3: USB — Attempt Log

**Status**: Not Started

---

## 2026-03-17 — USB Init Sequence Analysis (from KB explorer)

**Critical finding**: firmware main loop at 0x0207F2 calls three init functions:
1. JSR @0x010D22 — shared module init (interrupts, timers)
2. JSR @0x01233A — USB configure with timeout (param: 50)
3. JSR @0x0126EE — enable USB endpoints

**Warm-boot flag**: 0x400772 = 0x01 triggers alternate context entry at 0x10C46.

**USB Bus Reset Handler** at 0x013A20:
1. Clears ASIC 0x200001 (value 0x02)
2. Initializes timer at 0x4007D6
3. Clears all USB state (0x407Dxx block)
4. Installs ISP1581 endpoint callback table from flash to RAM at 0x400DC8
5. Calls ISP1581 endpoint config (0x015280)
6. Writes 0x20 to ASIC 0x2000C2

**USB state block**: 0x407D00-0x407DFF must be zeroed for clean start.
**Key state variables**:
- 0x407DC7: USB session state (2=ready)
- 0x407DC3: USB connection state
- 0x400082: cmd_pending
- 0x4007B0: sense code (2 bytes)
- 0x4007DE: CDB buffer (16 bytes)
- 0x40049C: transfer phase
- 0x40049D: command completion counter

**Context switch crash at ~2.78M**: caused by warm-boot context system not
being fully initialized. The firmware at 0x010874 (RTE) pops garbage because
the saved SP in the context save area points to zeroed RAM.

**Root cause**: our warm-boot path skips 0x0207F2 main loop init, so the
firmware never calls USB configure or endpoint enable. The SCSI dispatcher
at 0x020AE2 is part of the main loop that starts AFTER 0x0207F2.

**Solution path**: either (a) let firmware reach 0x0207F2 (requires fixing
context switch to not crash), or (b) pre-initialize all USB state and
jump directly to the polling loop portion of the main loop.
