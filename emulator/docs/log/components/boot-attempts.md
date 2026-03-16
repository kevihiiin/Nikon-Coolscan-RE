# Boot Sequence Development Log

---

## 2026-03-16 — First Boot Attempt (cold boot)

**Firmware**: Nikon LS-50 MBM29F400B TSOP48.bin (512KB)
**Reset vector**: 0x000100

### Boot sequence traced:
1. [0x000100] Entry: MOV.L #0xFFFF00, ER7 → LDC #0xC0, CCR → JMP 0x020334
2. [0x020334] Main entry: check RAM flags → I/O init table at 0x02035C
3. [0x02035C] I/O init loop: 132 (addr, value) entries from flash 0x0002001C (~678 instructions)
4. [0x020374] Check ASIC 0x200041 bit 1 — cold boot: bit=0, warm boot: bit=1
5. Cold path: RAM test → infinite delay loop at 0x020790 (toggles 0xFFFFD7, no exit)
**Result**: BLOCKED — infinite loop, no software exit condition

## 2026-03-16 — Warm Boot Simulation

**Approach**: Set ASIC 0x200041 bit 1 on master enable → firmware takes warm-boot path

### Problem chain solved:
1. ASIC ready flag → firmware takes BEQ at 0x0203A4 → skips HW handshake
2. But warm path skips trampoline install → TRAPA runs NOPs → PC enters I/O register space
3. Pre-installed 12 JMP trampolines → TRAPA reaches handler correctly
4. But RAM test overwrites context save area → context switch loads SP=0 → total corruption
5. JIT context init before first TRAPA → context B gets valid stack frame

### Final boot sequence (warm boot, working):
1. Reset → 0x000100 → SP=0xFFFF00, CCR=0xC0
2. JMP 0x020334 → I/O init table (678 insns) → ASIC ready detected
3. BEQ → 0x0203B0 → RAM test (128KB × patterns) → ASIC RAM init (0x800000+)
4. TRAPA #0 at 0x0109E2 → trampoline 0xFFFD10 → JMP 0x010876 (context switch)
5. Context switch: save ER0-ER6 → save SP to 0x400766 → load Context B SP from 0x40076A
6. Context B runs from 0x029B16 (JIT-initialized entry point)
7. Multiple context switches → eventually reaches trampoline install (0x0205FC, insn 1.15M)
8. ANDC #0x7F at 0x020608 → interrupts enabled (insn 1.15M)
9. **Stable execution at 50M+ instructions** — both contexts active

### Trampoline table (13 entries, pre-installed):

| On-chip RAM | Handler | Vector | Purpose |
|-------------|---------|--------|---------|
| 0xFFFD10 | 0x010876 | 8 | TRAP#0 context switch |
| 0xFFFD14 | 0x033444 | 15 | IRQ3 encoder |
| 0xFFFD18 | 0x014D4A | 16/17 | IRQ4/5 adapter |
| 0xFFFD1C | 0x010B76 | 32 | IMIA2 motor |
| 0xFFFD20 | 0x02D536 | 36 | IMIA3 DMA burst |
| 0xFFFD24 | 0x010A16 | 40 | IMIA4 system tick |
| 0xFFFD28 | 0x02CEF2 | 45 | DEND0B |
| 0xFFFD2C | 0x02E10A | 47 | DEND1B |
| 0xFFFD30 | 0x02E9F8 | 49 | CCD line |
| 0xFFFD34 | 0x02EDDE | 60 | ADI |
| 0xFFFD38 | 0x02B544 | 19 | IRQ7 motor step |
| 0xFFFD3C | 0x014E00 | 13 | IRQ1 USB |

### Context switch handler trace (0x010876):
- Push 7 registers (ER0-ER6) = 28 bytes
- Feed WDT (0x5A00 → 0xFFA8)
- Check scheduler/boot flags at 0x400772 and 0x400001
- If both zero: swap context (read index from 0x400764, save SP, toggle 0↔4, load SP)
- Pop 7 registers, RTE

### Key finding: context index encoding
- 0x400764 = 0x0000 → Context A (SP at 0x400766)
- 0x400764 = 0x0004 → Context B (SP at 0x40076A)
- Toggle: ADDS #4 then AND.B #0x04 wraps 0→4→0
