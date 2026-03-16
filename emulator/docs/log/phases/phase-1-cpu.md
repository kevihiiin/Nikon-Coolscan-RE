# Phase 1: CPU Core — Attempt Log

**Status**: COMPLETE — all instructions decode, firmware boots to 0x020334 and beyond
**Started**: 2026-03-16

---

## Attempt 1 — 2026-03-16 — Register Model

**Target**: H8/300H register set implementation
**Result**: SUCCESS
- ER0-ER7 (32-bit) with E/R/RH/RL aliasing
- PC (24-bit), CCR (8-bit with I/UI/H/U/N/Z/V/C)
- 5 register tests passing
**Confidence**: High

## Attempt 2 — 2026-03-16 — Memory Subsystem

**Target**: Address decoder and memory regions
**Result**: SUCCESS
- Flash (512KB read-only), RAM (128KB), ASIC RAM (224KB), Buffer RAM (64KB)
- On-chip RAM initially 64B, expanded to 896B (0xFFFB80-0xFFFEFF) after firmware wrote to 0xFFFD41
- On-chip I/O (256B), ASIC (4KB), ISP1581 (256B)
- Big-endian word/long access
- 5 memory tests passing
**Confidence**: Verified (matches docs/kb/reference/memory-map.md, expanded per firmware behavior)

## Attempt 3 — 2026-03-16 — Instruction Decoder

**Target**: All H8/300H instruction groups
**Result**: SUCCESS (with minor gaps)
- All major instruction groups working: groups 0-F complete
- Fixed ADD.L/SUB.L register-register (0x0A/0x1A encoding with bit 3 flag)
- Added 0100+78 prefix: MOV.L @(d:24, ERn) — 10-byte instruction (critical for context switch)
- Added 78+6A prefix: bit operations on @(d:24, ERn) — 10-byte instructions
- Unknown 78-prefix bit_op 0x50 at 0x0106EA treated as NOP (4 occurrences in boot, non-critical)
- 13 decoder tests passing
**Confidence**: High (firmware executes 50M+ instructions, only 4 unknown sub-ops)

## Attempt 4 — 2026-03-16 — Instruction Executor

**Target**: Execute all decoded instructions with correct flag behavior
**Result**: SUCCESS
- All arithmetic ops set H/N/Z/V/C flags per Hitachi manual
- Post-increment/pre-decrement fixed: @ERn+ now advances register by size (1/2/4 bytes)
- TRAPA pushes CCR+PC (6 bytes), loads vector, sets I flag
- RTE pops CCR+PC, restores all flags
- EEPMOV.B block copy working
- Context switch (TRAPA #0 → trampoline → handler → save regs → swap SP → restore regs → RTE) fully working
- 12 executor tests passing
**Confidence**: High (50M instructions executed without corruption)

## Attempt 5 — 2026-03-16 — Cold Boot HW Handshake

**Target**: Get past firmware cold-boot init
**Result**: RESOLVED (warm-boot simulation)
- Root cause: firmware checks ASIC 0x200041 bit 1 (ASIC ready) at 0x020394
- If bit 1 = 0 (cold boot): enters infinite delay/toggle loop at 0x020790 (toggles BSC register 0xFFFFD7)
- Loop has no software exit condition — relies on hardware interrupt or ASIC becoming ready
- XOR.W E3, E1 with E3=0x0000 → ER1 never changes → same address toggled forever
- **Solution**: Set ASIC 0x200041 bit 1 immediately when 0x200001 (master enable) gets 0x80
- Firmware takes warm-boot path, skipping the HW handshake
**Confidence**: High
**Impact**: Firmware proceeds past init, but warm-boot path has its own challenges (see Attempt 6-7)

## Attempt 6 — 2026-03-16 — Trampoline Installation

**Target**: Ensure TRAPA #0 reaches correct handler
**Result**: RESOLVED (pre-installation)
- Warm-boot path skips trampoline installation code at 0x0204C4-0x0205F7
- Without trampolines, TRAPA #0 jumps to 0xFFFD10 which contains 0x0000 (NOP) → runs off into I/O space
- Traced: PC entered 0xFFFD10 → NOPs through on-chip RAM → entered on-chip I/O (0xFFFF60) → decoded register values as instructions → hit JMP @0x000000 at 0xFFFFA8 → vector table
- **Solution**: Pre-install 12 JMP trampolines in on-chip RAM at emulator startup
- Trampoline targets from KB docs (vector-table.md): TRAP#0→0x010876, IRQ1→0x014E00, etc.
- JMP @aa:24 encoding: 0x5A [addr23:16] [addr15:8] [addr7:0]
**Confidence**: Verified (firmware reaches trampoline install milestone at instruction 1.15M, overwrites our pre-installed ones with identical values)

## Attempt 7 — 2026-03-16 — Context Switch Setup

**Target**: First TRAPA #0 context switch succeeds
**Result**: RESOLVED (JIT context initialization)
- Problem: RAM test (0x400000-0x420000) overwrites pre-initialized context save area at 0x400764-0x40076D
- Context switch handler at 0x010876 reads context index from 0x400764 and loads SP from 0x400766/0x40076A
- With zeroed save area: loaded SP = 0, then register restore popped from address 0 (vector table) → total corruption
- Traced context switch: MOV.W @0x400764:24, R0 → EXTU.L ER0 → MOV.L ER7, @(0x400766, ER0) → ADDS #4 → AND.B #4 → MOV.L @(0x400766, ER0), ER7
- **Solution**: JIT context initialization — detect first TRAPA #0 and set up context B just before it executes
- Context B: fake RTE frame at SP=0x40CFDE with CCR=0x0000 and PC=0x029B16 (Context B entry point) + 7 zeroed register saves
- Context A: index 0x0000, firmware's current SP saved normally by handler
**Confidence**: High (context switch works, both contexts execute)

## Attempt 8 — 2026-03-16 — Extended Execution

**Target**: Firmware runs stably past init
**Result**: SUCCESS
- Firmware executes 50M+ instructions without crashes
- Context switching between A and B works continuously
- SP stays in valid range (Context A: ~0x40F79E, Context B: ~0x40CFDE)
- Trampoline install milestone reached at instruction 1,149,601
- Interrupts enabled (ANDC #0x7F) at instruction 1,149,611
- ITU timer interrupts firing (system tick at Vec 40)
- Only 4 unknown 78-prefix bit_op warnings (treated as NOP)
- Zero unmapped reads, 2 unmapped writes (to BSC area during early init)
**Confidence**: High
**Next**: Check if main loop (0x0207F2) is reached, begin USB bridge work

## Attempt 9 — 2026-03-16 — Timer/I/O Routing Fix

**Target**: Get ITU4 system tick timer interrupts firing
**Result**: SUCCESS
- Root cause: on-chip I/O reads/writes went to flat array, peripheral models never saw them
- Added timer register sync in orchestrator (TSTR, TCR, TIER, GRA, TCNT, TSR)
- Fixed Port 7 / ITU4 TIER address conflict at 0xFFFF8E: Port 7 uses dedicated port7_override
- Fixed TSR sync: firmware flag clears now propagate to model (was overwriting bus with model value)
- Fixed GRA/TCR sync: JIT-configured values now written to bus so sync doesn't overwrite them
- Added OR.L/XOR.L/AND.L decoding (01F0 64/65/66 prefix)
**Confidence**: Verified (ITU4 Vec 40 interrupts fire, ISR at 0x010A16 executes)

## Attempt 10 — 2026-03-16 — 78-Prefix MOV.B Decode

**Target**: Fix unknown bit_op 0x50 at 0x0106EA
**Result**: SUCCESS
- Root cause: 78+6A with mode_lo ≠ 0 is 8-byte MOV.B with 24-bit displacement, not 10-byte bit op
- Format: 78 rr 6A [mode][reg] d23 d15 d7 pad = 8 bytes
- mode_lo = 0: 10-byte bit operation (BSET/BCLR/BTST/etc)
- mode_lo ≠ 0: 8-byte MOV.B (reg is the byte register number)
- All 78-prefix variants now decode correctly
- **Zero unknown instruction warnings** in 1.8M instructions of flash code
**Confidence**: Verified

## Phase 1 COMPLETE — Summary

Phase 1 milestone: "Firmware boots to 0x020334. All instructions decode and execute without panics."

**Achieved**:
- Firmware boots from 0x000100, reaches 0x020334 at instruction 8
- All H8/300H instructions used by the firmware are properly decoded
- Zero unknown instruction warnings through 1.8M instructions of flash code
- Context switching, timer interrupts, trampoline install all working
- 47 unit tests passing, zero compiler warnings

**Remaining issue (Phase 3)**: USB fast-path code at 0x40115C reaches uninitialized RAM at 0x404F62 (instruction ~1.8M). This requires ISP1581 bridge implementation to resolve.
