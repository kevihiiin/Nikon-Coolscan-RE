# Instruction Encoding Decisions

---

## 2026-03-16 — Clean-room from Hitachi Manual

All instruction encoding derived exclusively from Hitachi H8/300H Programming Manual (ADE-602-053A).
No reference to MAME, QEMU, GDB sim, SLEIGH, or any other emulator source.

## 2026-03-16 — Manual Review: Confirmed Behaviors and Key Details

Full review of the 257-page Hitachi H8/300H Programming Manual (ADE-602-053A)
against our emulator implementation. Source: `emulator/reference/H8_300H_Programming_Manual.pdf`.

### Stack Frame Layout (Advanced Mode) — REVISED

From Figure 1-5 (p6) and Table 2-8 bus states (p236).

**NOTE**: The manual describes a 6-byte frame (word CCR + long PC), but empirical
testing of the Coolscan V firmware (Session 5, 2026-03-17) showed the firmware
expects a 4-byte packed frame: `[CCR:8][PC:24]` as a single longword. The 6-byte
layout caused context switch crashes because the firmware's RTE popped 4 bytes,
not 6. The current implementation uses 4-byte packed frames throughout.

**TRAPA / Interrupt exception push:**
```
SP -= 4
[SP+0..SP+3] = [CCR:8 | PC:24] as single 32-bit longword
```
Our implementation: `frame = (ccr << 24) | (pc & 0xFFFFFF); write_long(sp, frame)` — correct.

**RTE pop:**
```
frame = [SP+0..SP+3] (32-bit longword)
CCR = frame >> 24
PC  = frame & 0x00FFFFFF
SP += 4
```
Our implementation: `read_long(sp); ccr = frame >> 24; pc = frame & 0xFFFFFF; sp += 4` — correct.

**JSR/BSR push (Advanced mode):** pushes 32-bit PC (4 bytes), SP -= 4.
**RTS pop (Advanced mode):** pops 32-bit longword, SP += 4.

### CCR Flag Rules — CONFIRMED CORRECT

From Section 1.4.3 (p10-11):

- **H (Half-carry):** Set at bit 3 for .B, bit 11 for .W, bit 27 for .L operations.
  Only affected by: ADD, ADDX, SUB, SUBX, CMP, NEG (byte/word/long).
  Our `half_mask` constants: 0xF / 0xFFF / 0xFFF_FFFF — correct.

- **CCR bit 6 is "U" (User bit)**, also usable as interrupt mask bit per hardware manual.
  We name it "UI" — cosmetic difference only, no behavioral impact.

- **Reset state:** Only I bit set to 1. All other CCR bits undefined. General registers
  NOT initialized (SP must be set by first instruction). Our `cpu.reset()` sets I=1, clears
  everything else — correct.

### INC/DEC #1/#2 Rules — CONFIRMED

From Table 1-3 (p20):
- INC/DEC: Byte operands support #1 only. Word/Long support #1 or #2.
- ADDS/SUBS: Long only, supports #1, #2, or #4.

Our decoder correctly restricts INC.B to #1 and allows INC.W/L #1/#2.

### EEPMOV Behavior — CONFIRMED CORRECT

From Section 2.2.28 (p95-97):
- EEPMOV.B: count in R4L (max 255), source @ER5+, dest @ER6+.
- EEPMOV.W: count in R4 (max 65535), source @ER5+, dest @ER6+.
- After completion: R4L/R4=0, ER5 and ER6 contain **last transfer address + 1**.
- EEPMOV.B: **no interrupts accepted** during execution (including NMI).
- EEPMOV.W: NMI can interrupt (ER5/ER6/R4 contain resumable state).
- All CCR flags unchanged.

Our implementation runs the full copy atomically — correct for EEPMOV.B.
We only implement EEPMOV.B (firmware only uses this variant).

### JMP @@aa:8 (Memory Indirect) — CONFIRMED

From bus states table (p232):
- In advanced mode: reads a **32-bit longword** from the indirect address.
- Branch address is the lower 24 bits of the longword.

Our `MemIndirect` handler: `bus.read_long(vec_addr) & 0x00FF_FFFF` — correct.

### Shift/Rotate V Flag — CONFIRMED

All rotate instructions (ROTL, ROTR, ROTXL, ROTXR): V = 0 always.
All shift instructions (SHAL, SHAR, SHLL, SHLR): per the manual:
- SHAL: V is set if the MSB changes during the shift (our implementation: V = N xor C).
- SHAR/SHLL/SHLR: V = 0.

Fixed: SHAL sets V = N^C (overflow = sign bit changed). SHAR/SHLL/SHLR/all rotates set V=0.
Previously we incorrectly set V = N^C for SHAR too — fixed by matching only ShiftOp::Shal.

### MOV.B @(d:24,ERs),Rd Instruction Fetch Cycles — CONFIRMED

From Table 2-8 (p217): 4 instruction fetch cycles, confirming this is an 8-byte instruction.
Matches our 78-prefix MOV.B decode with len=8.

### No Unexpected Behaviors Found

The manual confirms all our implementations for:
- Register aliasing (ER/E/R/RH/RL) layout (Figure 1-7, p8)
- 16-Mbyte linear address space in advanced mode (Figure 1-6, p7)
- Branch condition encoding (Table 1-3, p24) — all 16 conditions match
- Addressing mode calculations (Table 1-6, p28-33)
- System control instructions (LDC, STC, ANDC, ORC, XORC) behavior
