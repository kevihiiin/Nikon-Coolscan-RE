# Emulator Development Log

**Current Phase**: 1 — CPU Core (COMPLETE per milestone) / 2 — Interrupts (IN PROGRESS)
**Status**: Firmware boots, context switches, timer interrupts fire, 2.1M instructions before USB fast-path issue
**Last Updated**: 2026-03-16

---

## Session 1 — 2026-03-16

**Goals**: Bootstrap emulator project, implement CPU core, get firmware booting

**Accomplished**:

### Phase 0 — Project Setup (Complete)
- Created Rust workspace with 4 crates: h8300h-core, peripherals, bridge, coolscan-emu
- Created logging infrastructure: 16 files (session journal, 7 phase logs, 6 component logs, 2 decision docs)
- Updated root CLAUDE.md with emulator sections (clean-room rules, phases, project structure, key constants)

### Phase 1 — CPU Core (Major Progress)

**CPU registers & memory:**
- ER0-ER7 (32-bit) with E/R/RH/RL aliasing, 24-bit PC, 8-bit CCR
- Memory bus with 8 regions: Flash (512KB RO), RAM (128KB), ASIC RAM (224KB), Buffer RAM (64KB), On-chip RAM (896B at 0xFFFB80-0xFFFEFF), On-chip I/O (256B), ASIC (4KB), ISP1581 (256B)
- On-chip RAM expanded from 64B to 896B (firmware writes to 0xFFFD40-0xFFFD41, beyond original 64B range)

**Instruction decoder — all major H8/300H groups:**
- Group 0: NOP, STC, LDC, ORC/XORC/ANDC, ADD.B/W reg, INC.B, ADDS, MOV.B/W/L reg, ADDX, DAA
- Group 1: SHAL/SHAR, SHLL/SHLR, ROTL/ROTR, ROTXL/ROTXR, OR/XOR/AND.B reg, NOT, EXTU/EXTS, NEG, SUB, DEC, SUBS, CMP, SUBX, DAS
- Groups 2-3: MOV.B @aa:8
- Group 4: Bcc d:8 (all 16 conditions)
- Group 5: MULXU, DIVXU, RTS, BSR, RTE, TRAPA, Bcc d:16, JMP, JSR (all addressing modes)
- Group 6: Bit ops reg-reg, OR/XOR/AND.W reg, BST/BIST, MOV.B/W indirect/post-inc/pre-dec/disp16, MOV.B/W abs16/abs24
- Group 7: Bit ops immediate, MOV.W/L #imm, ADD/CMP/SUB/OR/XOR/AND.W/L #imm, EEPMOV.B, bit ops on memory (7C-7F prefix)
- Groups 8-F: ADD/ADDX/CMP/SUBX/OR/XOR/AND/MOV.B #imm
- Extended: ADD.L/SUB.L register-register (0x0A8x/0x1A8x with bit 3 flag)
- 0100 prefix: MOV.L @ERn, @ERn+, @-ERn, @(d:16), @aa:16, @aa:24
- 0100 78xx prefix: MOV.L @(d:24, ERn) — 10-byte instruction for context switch SP save/load
- 78xx 6A prefix: bit operations on @(d:24, ERn) — 10-byte instructions, unknown sub-ops treated as NOP

**Instruction executor:**
- Full CCR flag updates (H, N, Z, V, C) per Hitachi manual for all arithmetic/logic/shift ops
- Post-increment/pre-decrement with correct size-based advancement (+1/+2/+4)
- TRAPA pushes CCR+PC (6 bytes), loads from vector table, sets I flag
- EEPMOV.B block copy (source @ER5, dest @ER6, count R4L)
- RTE pops CCR+PC (6 bytes), restores flags
- All branch conditions (16 variants), JSR/BSR push 4-byte return address

**Interrupt controller:**
- Priority queue with vector number + priority level
- Checks between each instruction when CCR.I=0
- Pushes CCR+PC, loads handler from vector table, sets I=1
- Timer interrupts (ITU2/3/4 compare-match), ISP1581 IRQ, ADC, CCD trigger

**Peripherals:**
- ASIC: master enable (0x200001=0x80) → ready flag (0x200041 bit 1), DMA busy at 0x200002 bit 3, CCD trigger at 0x2001C1
- ISP1581: EP1 OUT/EP2 IN FIFOs, IRQ status with write-back clear, endpoint data port
- GPIO: Port 7 configurable adapter type, Port A motor stepper, Port 4 lamp
- ITU timers 0-4: prescaler, compare-match A/B, interrupt generation, TSTR start/stop
- ADC: instant conversion, fixed 0x200 result
- WDT: accept 0x5A feed, disabled by default

**Firmware boot progress (milestones with instruction counts):**
1. Reset vector 0x000100 → instruction 0
2. Main entry point 0x020334 → instruction 8
3. I/O init table (132 entries) → instruction 678
4. ASIC ready flag set (warm-boot path) → instruction ~680
5. RAM test (128KB × 3 patterns) → instructions 680-164K
6. ASIC RAM init → instructions 164K-356K
7. First TRAPA #0 (JIT context init) → instruction ~356K
8. Context switch handler at 0x010876 → working
9. Trampoline install milestone (0x0205FC) → instruction 1,149,601
10. **Interrupts enabled** (ANDC #0x7F at 0x020608) → instruction 1,149,611
11. **Stable execution at 50M+ instructions** — no crashes, proper stack, context switching

**Bugs fixed during session:**
1. Post-increment not implemented in read_operand_b/w/l — @ERn+ didn't advance register
2. ADD.L/SUB.L register-register (0x0A/0x1A) not decoded — bit 3 of nib2 distinguishes from INC/DEC
3. On-chip RAM too small (64B) — firmware writes to 0xFFFD40+, expanded to 896B (0xFFFB80-0xFFFEFF)
4. ASIC cold-boot path has infinite HW handshake loop — solved by setting ASIC ready flag (warm-boot simulation)
5. Warm-boot path skips trampoline install — pre-installed 12 JMP trampolines in on-chip RAM
6. RAM test overwrites pre-initialized context data — JIT context init right before first TRAPA
7. 0100+78 prefix (MOV.L 24-bit displacement) not decoded — added 10-byte instruction handler
8. 78+6A bit operations: displacement extraction fixed, unknown sub-ops treated as NOP instead of halt

**Key architectural decisions:**
- Warm-boot simulation: ASIC 0x200041 bit 1 set immediately on master enable, bypassing cold-boot HW handshake
- 12 trampolines pre-installed from known handler addresses (KB docs)
- JIT context B setup: fake RTE frame at 0x40CFDE pointing to Context B entry 0x029B16
- Context A SP = 0x40F800 (from firmware init analysis)
- 78-prefix unknown bit_op codes treated as NOP with warning (only 4 occurrences in boot)

**Blockers**:
- Context A main loop (0x0207F2) not yet reached — firmware still in late init at 50M instructions
- 78-prefix bit_op 0x50 at 0x0106EA decoded as NOP — may need proper implementation
- Timer interrupt timing may need tuning (ITU4 system tick drives firmware's cooperative scheduling)

**Next Steps**:
- Fix USB fast-path RAM corruption (code at 0x4010A0 gets overwritten after JIT copy)
- Investigate why JMP at 0x401136 has wrong bytes (should be F955, got 5A6BFF40)
- Begin ISP1581 EP data exchange for SCSI command reception
- Profile instruction execution rate and optimize if needed

---

## Session 2 — 2026-03-16 (continued)

**Goals**: Fix timer interrupts, get firmware past init to main loop

**Accomplished**:
- Fixed critical I/O routing: on-chip I/O registers were stored in flat array, peripheral models never saw writes
- Added timer register sync: TSTR, TCR, TIER, GRA, TCNT, TSR all sync between bus and timer model
- Fixed Port 7 / ITU4 TIER address conflict at 0xFFFF8E: Port 7 now uses dedicated `port7_override` field
- Fixed timer TSR sync direction: firmware flag clears now propagate to model (was overwriting bus with model)
- Added OR.L/XOR.L/AND.L register-register decoding (01F0 64/65/66 prefix)
- Pre-configured ITU4 system tick timer in JIT init (TCR=0xA3, GRA=0x2000, TIER=0x01)
- Pre-copied 414-byte USB fast-path code from flash 0x124BA to RAM 0x4010A0
- Improved PC range validation: only Flash, RAM, On-chip RAM regions allowed
- Added register index bounds masking (n & 7) to prevent panics from corrupt state

**Firmware progress (new milestones):**
- ITU4 system tick interrupts firing (Vec 40 → trampoline 0xFFFD24 → ISR 0x010A16)
- Trampoline install at instruction 1,149,757
- Interrupts enabled at instruction 1,149,767
- USB fast-path code called at instruction ~2.1M (JMP to 0x40115C)
- Crash at instruction 2,136,900: JMP @0x6BFF40 from RAM 0x401136 (RAM code corrupted)

**Key findings:**
- Address 0xFFFF8E is shared between Port 7 GPIO and ITU4 TIER register — must handle separately
- Timer prescaler sync was overwriting JIT-configured values with I/O init table defaults (TCR=0x00)
- TSR sync was writing model flags back to bus, undoing firmware's flag clear writes
- Timer GRA=0x0100 was too fast (1K insns/tick) causing interrupt storm; 0x2000 (32K/tick) is better
- Firmware at 0x010A10 does BSET #4, @0x60:8 to start ITU4 — reached during warm-boot init
- USB fast-path code at 0x4010A0 gets corrupted between JIT copy and actual use (~1.8M instructions later)

**Blockers**:
- USB fast-path RAM code corruption at 0x401136 (bytes changed from F955 to 5A6BFF40)
- Root cause likely: firmware init writes to the same RAM area after our JIT copy

**Next Steps**:
- Add memory watchpoint on 0x4010A0-0x40123E to catch who overwrites the USB code
- Or: defer USB code copy to just before it's first accessed
- Continue with Phase 2: verify all 15 interrupt vectors work correctly
