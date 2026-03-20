# Decoder Development Log

---

## 2026-03-16 — Initial Implementation

**Groups implemented**: 0x0-0xF (all major groups)

### Group 0 (0x0x): NOP, STC, LDC, ORC, XORC, ANDC, ADD.B reg, MOV.B reg, INC.B, ADDS, MOV.L reg
- 0x00 = NOP
- 0x02 = STC CCR, Rd; 0x03 = LDC Rs, CCR
- 0x04-0x07 = ORC/XORC/ANDC/LDC #imm, CCR
- 0x08-0x09 = ADD.B/W reg-reg
- 0x0A = INC.B / ADD.L reg-reg (fixed: bit 3 of nib2 distinguishes)
- 0x0B = ADDS/INC.W/INC.L
- 0x0C-0x0D = MOV.B/W reg-reg
- 0x0E = ADDX reg
- 0x0F = DAA / MOV.L reg-reg

### Group 1 (0x1x): Shifts, rotates, logic reg, NOT, EXTU/EXTS, NEG, SUB, DEC, SUBS, CMP, SUBX, DAS
- 0x10 = SHAL/SHAR (B/W/L)
- 0x11 = SHLL/SHLR (B/W/L)
- 0x12 = ROTL/ROTR; 0x13 = ROTXL/ROTXR
- 0x14-0x16 = OR/XOR/AND.B reg
- 0x17 = NOT/EXTU/EXTS/NEG (B/W/L)
- 0x18-0x19 = SUB.B/W
- 0x1A = DEC.B / SUB.L reg-reg (fixed: bit 3)
- 0x1B = SUBS/DEC.W/DEC.L
- 0x1C-0x1D = CMP.B/W; 0x1E = SUBX; 0x1F = DAS/CMP.L

### Groups 2-3: MOV.B @aa:8
### Group 4: Bcc d:8 (all 16 conditions)
### Group 5: MULXU, DIVXU, RTS, BSR, RTE, TRAPA, Bcc d:16, JMP, JSR
### Group 6: Bit ops reg, OR/XOR/AND.W reg, BST/BIST, MOV.B/W indirect/post-inc/pre-dec/disp16
### Group 7: Bit ops imm, MOV.W/L #imm, ADD/CMP/SUB/OR/XOR/AND.W/L #imm, EEPMOV, bit ops @memory

**Known gaps**: 01xx prefix chains (LDC/STC memory), 01F0 24-bit displacement for non-MOV.L

## 2026-03-16 — Extended Instruction Fixes

### Fix: ADD.L/SUB.L register-register (0x0A8x/0x1A8x)
- 0x0A with nib2 bit 3 set = ADD.L ERs, ERd (was returning Unknown)
- 0x1A with nib2 bit 3 set = SUB.L ERs, ERd (was returning Unknown)
- Discovered when firmware hit 0x0AB0 at 0x0203F8 (RAM test loop counter)

### Fix: 0100+78 prefix — MOV.L @(d:24, ERn) (10-byte instruction)
- Format: 0100 78 [r]0 6B [2|A]s 00 [d23:16] [d15:8] [d7:0]
- Read: MOV.L @(d:24, ERbase), ERdst
- Write: MOV.L ERsrc, @(d:24, ERbase)
- Critical for context switch: saves/loads SP from 0x400766+index
- Discovered at 0x0108B8: `0100 7880 6BA7 0040 0766` = MOV.L ER7, @(0x400766, ER0)
- byte 3 = 0x80: bits 6-4 → base_reg = 0 (ER0). Bit 7 purpose unclear.

### Added: 78+6A prefix — two formats distinguished by mode byte low nibble

**Format 1: mode_lo = 0 → 10-byte bit operation on @(d:24, ERn)**
- 78 [r]0 6A [2|A]0 d23 d15_hi d15_lo pad bitop bitnib = 10 bytes
- Displacement: bytes 4-6, bit_op: byte 7, bit_nib: byte 8
- Handles: BTST, BSET, BCLR, BNOT, BST, BIST, BLD, BILD, BAND, BOR, BXOR, BIAND, BIOR, BIXOR
- Example: 78 00 6A 20 00 40 10 67 A8 08 = BIST #0, @(0x004010, ER0)

**Format 2: mode_lo ≠ 0 → 8-byte MOV.B with 24-bit displacement**
- 78 [r]0 6A [2|A][reg] d23 d15 d7 pad = 8 bytes
- mode_hi 2 = read (MOV.B @(d:24, ERn), Rn), A = write (MOV.B Rn, @(d:24, ERn))
- reg = byte register number (8 = R0L, etc.)
- Example: 78 50 6A A8 00 40 4E 50 = MOV.B R0L, @(0x00404E, ER5)
- Previously mistakenly decoded as 10-byte bit op, giving unknown bit_op 0x50

**Key insight**: mode_lo distinguishes the two formats. This resolved the last unknown instruction in flash code.

### Added: 78+6B prefix — MOV.L @(d:24, ERn) without 0100 prefix (8-byte instruction)
- Format: 78 [r]0 6B [2|A]s [pad] [d23:16] [d15:8] [d7:0]
- Same as 0100+78 variant but for standalone 78 prefix context

## 2026-03-19 — Bug Fix: MOV.L ERs, ERd decoder regression

**Problem**: Commit 3bf52c9 (code review) incorrectly marked opcodes 0F 9x/Bx-Fx as Unknown.
These are valid MOV.L ERs, ERd (32-bit register move) instructions.

**Encoding**: `0F (8+s)(d)` — nib2 bit 3 is set, s = nib2 & 0x7, d = nib3.
- 0F 80 = MOV.L ER0, ER0
- 0F 91 = MOV.L ER1, ER1
- 0F E0 = MOV.L ER6, ER0 ← the instruction that triggered discovery

**Impact**: Firmware halted at 0x0203FE (during RAM test pattern setup) because
MOV.L ER6, ER0 was decoded as Unknown. Both `run()` and `boot_to_main_loop()` affected.

**Fix**: Changed match from `nib2 == 0x8` to `nib2 & 0x8 != 0`, with DAA (nib2=0xA)
handled first as a special case. All MOV.L ERs, ERd variants (ER0-ER7 as source) now
decode correctly.

**Confidence**: Verified — firmware boots to main loop (instruction 2,783,761) and all
63 tests pass.
