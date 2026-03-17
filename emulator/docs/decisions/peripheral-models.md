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

## 2026-03-17 — USB Fast-Path NOP Bypass

**Decision**: NOP the two JSR instructions at flash 0x012EC6 and 0x012ECE that call the
USB fast-path code in RAM at 0x4011C2.

**Why**: The USB fast-path code polls bit 7 of @0x063621 (ISP1581 internal register offset
0x3621). In real hardware, this register indicates USB bus ready. In our emulation,
unmapped ISP1581 reads return 0x0000 → bit 7 never set → infinite poll loop.

**Alternatives considered**:
1. Copy fast-path code to RAM via JIT → FAILED: firmware init overwrites the RAM area
2. Return specific value for ISP1581 @0x3621 → risky: unknown what else reads that register
3. NOP the callers → CHOSEN: cleanest approach, allows firmware to skip USB fast-path entirely

**Consequence**: Firmware does not execute USB bus initialization via fast-path. This is
acceptable because we're using direct RAM CDB injection for testing, not real USB transport.
When USB gadget bridge is implemented, this decision may need revisiting.

## 2026-03-17 — ITU4 Register Base Correction

**Decision**: Change ITU4 register base from 0x8C to 0x92 in both itu.rs and orchestrator.rs.

**Why**: H8/3003 I/O register map has a 6-byte gap between ITU3 (0x82-0x8B) and ITU4 (0x92-0x9B).
Addresses 0x8C-0x91 are unmapped/reserved. Our initial implementation assumed contiguous
assignment (ITU0=0x64, ITU1=0x6E, ITU2=0x78, ITU3=0x82, ITU4=0x8C). The correct bases are
(0x64, 0x6E, 0x78, 0x82, 0x92), confirmed from H8/3003 hardware manual register map.

**Impact**: Without this fix, firmware writes to TSR4 at 0xFFFF95 went to unmapped space.
The timer model never saw flag clears → compare-match interrupt re-fired continuously →
interrupt storm instead of periodic system tick.

## 2026-03-17 — TCP Bridge with Direct RAM CDB Injection

**Decision**: Use TCP socket with custom frame protocol for external SCSI command injection,
bypassing ISP1581 USB controller entirely.

**Why**: Getting the firmware to its SCSI dispatcher (0x020AE2) requires either solving the
context switch crash or pre-initializing enough state. Direct RAM injection allows testing
the TCP bridge infrastructure independently of firmware boot completion.

**Implementation**:
- Non-blocking TCP server on port 5050
- Frame protocol: [type:1][length:2 BE][payload:N]
- CDB written directly to firmware buffer at 0x4007DE
- cmd_pending flag set at 0x400082
- Phase/sense read from 0x40049C and 0x4007B0

**Trade-off**: This bypasses the ISP1581 transport layer. A future ISP1581 transport path
(inject CDB into EP1 OUT FIFO → firmware reads via ISP1581 registers → parses CDB)
will be needed for full fidelity. The TCP bridge will remain as a testing convenience.
