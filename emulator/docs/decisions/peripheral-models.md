# Peripheral Model Decisions

---

## 2026-03-16 — Stub-First Approach

Peripheral models start as stubs returning zero for all reads.
Responses are added incrementally as firmware boot tracing reveals which registers
must return specific values for forward progress.

Priority order (by firmware boot dependency):
1. On-chip I/O (H8/3003 internal registers) — I/O init table target
2. ISP1581 USB controller — first peripheral polled after init
3. ASIC status register — DMA ready flag
4. GPIO ports — adapter detection, motor control
5. ITU timers — interrupt-driven scheduling
6. DMA channels — scan data transfer
7. ADC — analog sensor reads
8. SCI — serial (polled, low priority)

## 2026-03-16 — ASIC Ready Flag (Warm Boot Simulation)

**Decision**: Set ASIC 0x200041 bit 1 immediately when 0x200001 (master enable) receives 0x80.

**Why**: Cold boot path has infinite HW handshake loop at 0x020790 with no software exit.
The loop toggles BSC register 0xFFFFD7 while feeding WDT, waiting for hardware event.
With CCR.I=1, no interrupt can break it. Real hardware presumably has ASIC-to-CPU signaling.

**Alternative considered**: Delayed readiness (set bit after N instructions). Rejected because
the cold boot loop doesn't poll 0x200041 — it has a BRA (always) back to the start.

**Consequence**: Firmware takes warm-boot path, requiring pre-installed trampolines and
JIT context initialization.

## 2026-03-16 — Trampoline Pre-Installation

**Decision**: Pre-install 12 JMP trampolines in on-chip RAM at emulator startup.

**Why**: Warm-boot path skips trampoline installation code at 0x0204C4-0x0205F7.
Without trampolines, TRAPA #0 executes NOPs through on-chip RAM into I/O register space.
Firmware DOES eventually install trampolines (milestone at 1.15M insns), but only after
context switching has already been used.

**Validation**: The firmware's own trampoline install overwrites our pre-installed values
with identical JMP instructions — confirming our addresses are correct.

## 2026-03-16 — JIT Context Initialization

**Decision**: Initialize Context B's stack frame just before the first TRAPA #0 executes.

**Why**: Cannot pre-initialize at startup because RAM test (0x400000-0x420000) overwrites
context save area at 0x400764-0x40076D.

**Implementation**: Detect first TRAPA(0) in decoded instruction stream. Build fake RTE frame
at Context B SP (0x40CFDE) with CCR=0x0000 and PC=0x029B16 (Context B entry from KB).
Write 7 zeroed register saves above the frame. Store SP in 0x40076A, index 0x0000 in 0x400764.
