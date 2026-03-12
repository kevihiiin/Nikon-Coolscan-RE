# Firmware Interrupt Vector Table — H8/3003

**Status**: Complete
**Last Updated**: 2026-03-05
**Phase**: 4 (Firmware)
**Confidence**: Verified (binary vector table + SLEIGH pspec + handler register access patterns)

## Overview

The H8/3003 has 64 interrupt vectors (256 bytes at 0x000000-0x0000FF). Each vector is a 32-bit address. Of 64 vectors, 15 are active (point to non-default handlers). All active vectors except NMI point to on-chip RAM trampoline addresses (0xFFFD10-0xFFFD3C), which contain JMP instructions installed at runtime by the main firmware initialization code.

## Active Vectors

**Source**: Binary vector table at 0x000000-0x0000FF, cross-referenced with SLEIGH H8/300H pspec (`tools/ghidra-h8/sleigh-h8/data/languages/h8.pspec`) and verified by checking which peripheral registers each handler accesses.

| Vec# | Vector Addr | Trampoline RAM | Handler Target | H8/3003 Source | Purpose |
|------|-------------|----------------|----------------|----------------|---------|
| 0 | 0x000 | — | 0x000100 | Reset | Power-on entry |
| 7 | 0x01C | — | 0x000182 | NMI | Non-maskable interrupt (tight loop) |
| 8 | 0x020 | 0xFFFD10 | **0x010876** | TRAP #0 | **Context switch — cooperative yield (TRAPA #0 at 0x109E2)** |
| 13 | 0x034 | 0xFFFD3C | **0x014E00** | IRQ1 | **External interrupt — ISP1581 USB (reads 0x60000C)** |
| 15 | 0x03C | 0xFFFD14 | **0x033444** | IRQ3 | **External interrupt — motor encoder pulses** |
| 16 | 0x040 | 0xFFFD18 | **0x014D4A** | IRQ4 | External interrupt (shared handler with IRQ5) |
| 17 | 0x044 | 0xFFFD18 | **0x014D4A** | IRQ5 | External interrupt (shared handler with IRQ4) |
| 19 | 0x04C | 0xFFFD38 | **0x02B544** | **IRQ7** (H8/3003) | Motor step completion / scan segment init (392 bytes; reads I/O 0xFFFF3C, writes 0x400778/0x4052xx) |
| 32 | 0x080 | 0xFFFD1C | **0x010B76** | IMIA2 (ITU2 cmp A) | **Motor mode dispatcher** (reads motor_mode at 0x400774) |
| 36 | 0x090 | 0xFFFD20 | **0x02D536** | IMIA3 (ITU3 cmp A) | Timer 3 compare match A |
| 40 | 0x0A0 | 0xFFFD24 | **0x010A16** | IMIA4 (ITU4 cmp A) | **System tick timer** (increments timestamp at 0x40076E, reads TSR4) |
| 45 | 0x0B4 | 0xFFFD28 | **0x02CEF2** | DEND0B (DMA ch0 B) | DMA channel 0B transfer end (clears DTCR0B bit 3) |
| 47 | 0x0BC | 0xFFFD2C | **0x02E10A** | DEND1B (DMA ch1 B) | DMA channel 1B transfer end |
| 49 | 0x0C4 | 0xFFFD30 | **0x02E9F8** | Timer/CCD (H8/3003) | CCD line readout / DMA coordination (reads I/O 0xFFFF4C, writes ASIC 0x200001+0x2001C1) |
| 60 | 0x0F0 | 0xFFFD34 | **0x02EDDE** | ADI (A/D converter) | A/D conversion complete (tests ADCSR bit 7 at 0xFFFFE8) |

†Vec 19 and 49 fall in gaps of the generic H8/300H pspec. The H8/3003 has 8 external interrupts (IRQ0-IRQ7) vs 6 in basic H8/300H, assigning Vec 18=IRQ6 and Vec 19=**IRQ7**. This pushes all subsequent vectors down by 2 relative to generic H8/300H numbering. Vec 19's handler (0x02B544, 392 bytes) accesses motor/scan state variables (0x4052EA, 0x4052E8, 0x4052EC-ED, 0x4052EE) and I/O register 0xFFFF3C, writing task codes (0x0310) to 0x400778. Vec 49's handler (0x02E9F8) manages CCD line readout timing — it writes ASIC registers 0x200001 (DMA trigger) and 0x2001C1 (CCD timing) while accessing pixel/line data at 0x4052xx, 0x4058FC, 0x4062DC, and 0x406DB6. Vec 52 (SCI0 ERI at 0xD0) is **inactive** — all SCI vectors (52-59) point to the default handler, so serial communication is polled, not interrupt-driven.

All 49 inactive vectors point to 0x000186 (default handler = infinite loop).

## Trampoline Architecture

### Why Trampolines?

The vector table is in flash (read-only). To allow the firmware to change interrupt handlers at runtime, each vector points to a fixed location in on-chip RAM. The firmware writes a `JMP @target` instruction (4 bytes: `5A xx xx xx`) to that RAM location during initialization.

### Trampoline Installation (at 0x204C4-0x205F7)

Each trampoline is installed using the `eepmov.b` instruction to copy 4 bytes of inline data to the RAM trampoline address:

```asm
mov.l  #0xfffd10, er6           ; Destination: trampoline RAM address
mov.l  #0x204da, er5            ; Source: inline JMP instruction data
mov.b  #0x4, r4l                ; 4 bytes to copy
eepmov.b                        ; Copy
jmp    @0x204de                 ; Skip over inline data
; Inline data: 5A 01 08 76     → "JMP @0x010876"
```

### Trampoline Data

The inline JMP instruction data is embedded in the firmware code stream:

| Trampoline RAM | Inline Data Addr | JMP Bytes | Target Handler |
|----------------|------------------|-----------|----------------|
| 0xFFFD10 | 0x204DA | 5A 01 08 76 | 0x010876 |
| 0xFFFD14 | 0x204F4 | 5A 03 34 44 | 0x033444 |
| 0xFFFD18 | 0x2050E | 5A 01 4D 4A | 0x014D4A |
| 0xFFFD1C | 0x20528 | 5A 01 0B 76 | 0x010B76 |
| 0xFFFD20 | 0x20542 | 5A 02 D5 36 | 0x02D536 |
| 0xFFFD24 | 0x2055C | 5A 01 0A 16 | 0x010A16 |
| 0xFFFD28 | 0x20576 | 5A 02 CE F2 | 0x02CEF2 |
| 0xFFFD2C | 0x20590 | 5A 02 E1 0A | 0x02E10A |
| 0xFFFD30 | 0x205AA | 5A 02 E9 F8 | 0x02E9F8 |
| 0xFFFD34 | 0x205C4 | 5A 02 ED DE | 0x02EDDE |
| 0xFFFD38 | 0x205DE | 5A 02 B5 44 | 0x02B544 |
| 0xFFFD3C | 0x205F8 | 5A 01 4E 00 | 0x014E00 |

Vector 13 (IRQ1) is the **12th and final entry** at flash 0x205E2-0x205F7. The ISP1581 USB interrupt handler at `0x014E00` reads ISP1581 interrupt register at `0x60000C` and terminates with RTE at `0x014EA4`.

## Handler Purpose Analysis

### Interrupt Handler Locations by Flash Region

Most interrupt handlers reside in two areas:

- **0x10000-0x17FFF** (shared handler module): handlers at 0x10876, 0x10A16, 0x10B76, 0x14D4A, 0x14E00
- **0x20000-0x3FFFF** (main firmware): handlers at 0x2B544, 0x2CEF2, 0x2D536, 0x2E10A, 0x2E9F8, 0x2EDDE, 0x33444

### RTE (Return from Exception) Locations

Found 16 RTE instructions, confirming interrupt handler boundaries:

| Address | Region | Likely Handler |
|---------|--------|---------------|
| 0x010874 | Shared | TRAP #0 handler end |
| 0x0108F4 | Shared | Near context switch area |
| 0x010972 | Shared | |
| 0x0109E0 | Shared | |
| 0x010ABA | Shared | ITU4 system tick handler end |
| 0x010BCC | Shared | ITU2 motor dispatcher handler end |
| 0x012256 | Shared | |
| 0x014DFE | Shared | IRQ4/IRQ5 handler end |
| 0x014EA4 | Shared | IRQ1 (ISP1581 USB) handler end |
| 0x02B6CC | Main | Vec 19 position tracker handler end |
| 0x02D250 | Main | |
| 0x02D596 | Main | ITU3 handler end |
| 0x02E156 | Main | DMA ch1B handler end |
| 0x02ED2C | Main | |
| 0x02EE94 | Main | ADI (A/D converter) handler end |
| 0x033492 | Main | IRQ3 (encoder) handler end |

### Functional Groups

**Context Switch:**
- TRAP #0 (0x010876) — Cooperative yield via `TRAPA #0` instruction. See [Main Loop](./main-loop.md).

**USB/Communication:**
- IRQ1 (0x014E00) — ISP1581 USB controller interrupt (reads ISP1581 mode register at 0x60000C)
- IRQ4/IRQ5 (0x014D4A) — Shared external interrupt handler (likely adapter-related or hardware status)

**Motor Control:**
- ITU2 compare A (0x010B76) — Motor mode dispatcher. Reads motor_mode (0x400774), dispatches to scan/AF/encoder handlers. Started/stopped per motor movement via BSET/BCLR #2, TSTR.
- IRQ3 (0x033444) — Encoder pulse ISR. Counts pulses, measures inter-pulse timing for position/speed feedback.
- Vec 19 / IRQ7 (0x02B544) — **Motor step completion / scan segment initialization**. Fires on external interrupt (limit switch or auxiliary encoder). Reads motor state (0x4052EA), sets task_code 0x0310 for motor positioning, initializes scan config variables (0x400E9x range), sets calibration values (0x400B8A/B8C). Also accesses I/O register 0xFFFF3C (likely 8-bit timer counter). 392 bytes.

**DMA (Scan Data Transfer):**
- ITU3 compare A (0x02D536) — Timer-based DMA coordination
- DEND0B (0x02CEF2) — DMA channel 0B transfer end. Clears DTCR0B bit 3 (0xFFFF2F). Accesses scan state at `0x4052D6`, `0x4064E8`, `0x406338`.
- DEND1B (0x02E10A) — DMA channel 1B transfer end. Accesses motor/scan state at `0x4052E4`-`0x4052EB`.

**System:**
- ITU4 compare A (0x010A16) — System tick timer. Started once at init (`BSET #4, TSTR` at 0x010A10), never stopped. Increments global timestamp at 0x40076E.
- ADI (0x02EDDE) — A/D conversion complete. Tests ADCSR bit 7 (ADF flag at 0xFFFFE8). Used for analog measurements (lamp intensity, CCD temperature, or similar).
- Vec 49 (0x02E9F8) — **CCD line readout / DMA coordination**. H8/3003-specific timer interrupt for scan line timing. Reads I/O 0xFFFF4C (8-bit timer register), writes ASIC 0x200001 (DMA trigger) and 0x2001C1 (CCD line timing). Manages pixel transfer state: reads 0x4052F1 (scan_active), 0x4052F0/F2 (scan status), 0x405284/5288 (pixel descriptors), 0x4058FC (line counter), 0x4062DC/DD (channel data). Controls DMA-to-USB pipeline during active scanning.

**Note on Serial Communication:** All SCI interrupt vectors (52-59) are **inactive** in this firmware — serial communication with film adapters (SA-21, MA-21) is handled via **polled I/O**, not interrupts. SCI register accesses (SMR, BRR, SSR, RDR, TDR) are sparse (2-3 sites each) at scattered locations: SCI0 at `0x1686A`, `0x33F6A`, `0x137FE`; SCI1 at `0x33828`, `0x2F89A`, `0x385E6`. No BRR configuration in the I/O init table — ports are configured dynamically when an adapter is detected.

## ISP1581 Code Region

USB controller (ISP1581) interaction code is concentrated at 0x12200-0x15200 based on register access patterns:

| ISP1581 Register | Address | Code Locations |
|-----------------|---------|----------------|
| Mode (0x0C) | 0x60000C | 0x0139C0, 0x014E1A |
| Interrupt (0x08) | 0x600008 | 0x0148E8 |
| DMA (0x18) | 0x600018 | 0x013C74, 0x013F72, 0x014004, 0x014F00 |
| Endpoint data (0x20) | 0x600020 | 0x012260, 0x0122A4, 0x0122D4, 0x012314, 0x01500C |
| Endpoint 7 (0x1C) | 0x60001C | 0x0122CC, 0x01230C |
| DMA count (0x84) | 0x600084 | 0x015170 |

Source: Binary pattern search for MOV.L #0x6000xx instructions in 0x10000-0x53000

## Related KB Docs

- [Startup Code](./startup.md) — Reset vector and initialization sequence
- [USB Protocol](../../architecture/usb-protocol.md) — Host-side USB protocol analysis
