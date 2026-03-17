# Executor Development Log

---

## 2026-03-16 — Code Review Fixes

**From manual reference review (H8/300H Programming Manual):**

### Fix: DIVXU flags computed from full-width result
- DIVXU.B: quotient in RL, remainder in RH of 16-bit register
- Flags N,Z should be computed from the 8-bit quotient (RL), not the full 16-bit result
- Similarly DIVXU.W: flags from 16-bit quotient, not 32-bit register
- Fix: mask quotient to correct width before flag computation

### Fix: SHAR V flag was N^C (copied from SHAL)
- SHAR: arithmetic shift right — V flag is ALWAYS 0 per manual
- SHAL: arithmetic shift left — V flag = N^C (sign change detection)
- These are different despite sharing the same decode group
- Fix: set V=0 for SHAR, keep V=N^C for SHAL

### Fix: INC/DEC #2 treated as #1
- INC.W #2 and INC.L #2 were incrementing by 1 instead of 2
- Same for DEC.W #2 and DEC.L #2
- The amount (#1 or #2) is encoded in the instruction but was being ignored
- Fix: added `amount: u8` parameter to Instruction::Inc/Dec variants
- Decoder now extracts amount from instruction encoding
- Executor uses amount in add/sub operation

### Fix: INC/DEC overflow detection
- For #1: V = (result sign != prev sign when prev was at boundary)
  - INC: V=1 if result is 0x80..00 (overflowed from 0x7F..FF)
  - DEC: V=1 if result is 0x7F..FF (underflowed from 0x80..00)
- For #2: similar boundary check
- Previously used generic add/sub overflow which was wrong for #1/#2 semantics

### Added: OR.L/XOR.L/AND.L register-register (01F0 prefix)
- Prefix 01F0 followed by 64/65/66 xx = OR.L/XOR.L/AND.L ERs, ERd
- These were decoded as Unknown, causing firmware to halt
- Found during boot at 0x020608: `01F0 6408` = OR.L ER0, ER0

### Note: 78-prefix unknown bit_op 0x50 → NOP
- Changed from Unknown (causes halt) to NOP with warning log
- Only 4 occurrences in entire flash boot sequence
- Later identified as actually being MOV.B @(d:24, ERn) — different format
  (see decoder-attempts.md 78+6A prefix fix)
