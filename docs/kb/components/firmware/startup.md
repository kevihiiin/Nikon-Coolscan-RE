# Firmware Startup Code — H8/3003 Reset Vector and Initialization

**Status**: Complete
**Last Updated**: 2026-02-27
**Phase**: 4 (Firmware)
**Confidence**: High (decompiled via Ghidra H8/300H SLEIGH)

## Overview

The LS-50 firmware (512KB MBM29F400B flash) boots from the H8/3003 reset vector at address 0x000000. The startup code initializes the stack, disables interrupts, and dispatches to one of two firmware banks based on a hardware register. The main firmware then runs an I/O register initialization table, RAM test, and interrupt trampoline installation before entering the main loop.

## Reset Vector (Address 0x000000)

```
Vector 0 (Reset): 0x00000100 → startup code entry point
```

The H8/3003 reads 4 bytes from address 0x000000, gets 0x00000100, and begins executing at 0x100.

## Boot Code (0x100-0x18A)

### Path A — Normal Boot (Reset Vector Entry)

```asm
0x000100: mov.l  #0xffff00, er7        ; SP → 0x00FFFF00 (top of on-chip RAM)
0x000106: ldc.b  #0xc0, ccr            ; Disable all interrupts (I=1, UI=1)
0x000108: mov.b  #0x0, r0l
0x00010A: mov.b  r0l, @0x00fffd4c      ; Write 0 to state flag (on-chip RAM)
0x00010E: bra    0x0000016e            ; → Skip trampoline copy, go to bank select
```

### Path B — Alternate Entry (0x112)

Not reached from normal reset. Possibly entered from a soft-reset or watchdog:

```asm
0x000112: mov.l  #0xffff00, er7        ; SP init (same)
0x000118: ldc.b  #0xc0, ccr            ; Disable interrupts
0x00011A: mov.b  #0x1, r0l
0x00011C: mov.b  r0l, @0x00fffd4c      ; Write 1 to state flag
0x000120: mov.b  @0x004006b2, r0l      ; Copy flash → on-chip RAM
0x000126: mov.b  r0l, @0x00fffd4d
0x00012A: mov.b  @0x004006b3, r0l
0x000130: mov.b  r0l, @0x00fffd4e
; Three eepmov.b copy loops:
;   Flash 0x4006B4 → RAM 0xFFFD50 (8 bytes)
;   Flash 0x4006BC → RAM 0xFFFD58 (160 bytes)
;   Flash 0x40075C → RAM 0xFFFDF8 (8 bytes)
0x00016A: bra    0x0000016e            ; Fall through to bank select
```

**Note**: The source data at flash offset 0x6B4 is all 0xFF (erased). These copy loops are ineffective in the current flash state. This path may be a legacy boot-from-backup mechanism.

### Bank Select (0x16E)

```asm
0x00016E: mov.b  @0x00004001, r0l      ; Read hardware register at address 0x4001
0x000174: cmp.b  #0x0, r0l
0x000176: bne    0x0000017e            ; If non-zero → alternate bank
0x00017A: jmp    @0x00020334           ; NORMAL: Jump to main firmware at 0x20334
0x00017E: jmp    @0x00010334           ; ALTERNATE: Jump to backup firmware at 0x10334
```

Address 0x4001 is a hardware register (not in flash) that selects the firmware bank. In normal operation it reads 0x00, directing execution to the main firmware at 0x20334.

### Exception Handlers

```asm
0x000182: nop / bra 0x182              ; NMI handler — infinite loop
0x000186: nop / bra 0x186              ; Default handler — infinite loop (all unused vectors)
```

## Main Firmware Entry (0x020334)

### Watchdog and Bank Verification

```asm
0x020334: mov.b  @0x00004001, r0l      ; Re-check bank select register
0x02033A: cmp.b  #0x0, r0l
0x02033C: beq    0x00020344            ; Must be 0 for main firmware
0x020340: jmp    @0x00010334           ; Otherwise redirect to backup

0x020344: mov.b  @0x00004000, r0l      ; Read hardware register at 0x4000
0x02034A: and.b  #0xfe, r0l
0x02034C: beq    0x00020354            ; Must have bit 0 clear
0x020350: jmp    @0x00010334           ; Otherwise redirect to backup

0x020354: mov.w  #0x5a00, r0
0x020358: mov.w  r0, @0x00ffffa8       ; Reset watchdog timer (WDT TCSR = 0x5A00)
```

### I/O Register Initialization Table (0x2001C-0x20334)

The firmware uses a data-driven initialization table to configure all hardware registers. Each entry is 6 bytes: `[address:32] [value:16]`, with only the low byte of value written.

**Table size**: (0x20334 - 0x2001C) / 6 = **132 entries**

```asm
0x02035C: mov.l  #0x2001c, er0         ; Source: init table start
0x020362: mov.l  #0x20334, er1         ; End: init table end
; Loop:
0x020368: mov.l  @er0+, er2            ; Load 32-bit target address
0x02036C: mov.w  @er0+, r3             ; Load 16-bit value
0x02036E: mov.b  r3l, @er2             ; Write low byte to target address
0x020370: cmp.l  er1, er0
0x020372: bcs    0x020368              ; Loop until end
```

Key registers initialized:

| Register | Address | Value | Purpose |
|----------|---------|-------|---------|
| ABWCR | 0xFFFFF2 | 0x0B | Bus width: some areas 8-bit, some 16-bit |
| BRCR | 0xFFFFF8 | 0x00 | Bus release control |
| CSCR | 0xFFFFF9 | 0x30 | Chip select control |
| WCER | 0xFFFFF5 | 0x00 | Wait control enable |
| WCR | 0xFFFFF4 | 0xBA | Wait state control |
| P1DDR | 0xFFFFD4 | 0xFF | Port 1 direction: all outputs |
| P2DDR | 0xFFFFD5 | 0x01 | Port 2 direction: bit 0 output |
| P3DDR | 0xFFFFD6 | 0x00 | Port 3 direction: all inputs |
| P4DDR | 0xFFFFD7 | 0x01 | Port 4 direction: bit 0 output |
| TSTR | 0xFFFF60 | 0xE0 | Timer start: enable ITU channels 2,3,4 |
| TCR0 | 0xFFFF64 | 0xA0 | ITU0 control register |
| ASIC regs | 0x200044-0x200204 | various | Custom scanner ASIC initialization |

### ASIC Register Space (0x200000+)

The scanner has a custom ASIC/FPGA at memory address 0x200000. The init table writes ~70 registers in this space, including:
- 0x200044-0x200046: Base control registers
- 0x2000C0-0x2000C1: Configuration
- 0x200100-0x200107: CCD channel mapping (sequential offsets 0x30, 0x32, 0x34, 0x36)
- 0x20010C-0x20010F: Secondary CCD config (0x20, 0x22, 0x24, 0x26)
- 0x200114-0x200117: Timing registers (0x00, 0x08, 0x10, 0x18)
- 0x200140-0x200150: Motor/control config
- 0x2001C0-0x2001C9: Scan parameter registers

### RAM Test (0x203BA-0x020460)

After I/O init, the firmware performs a thorough RAM test:
1. Iterates through a memory region table at 0x207A8 (pairs of start/end addresses)
2. Writes 0x55AA55AA pattern, verifies readback
3. Writes 0xAA55AA55 complementary pattern, verifies readback
4. Resets watchdog between tests
5. Records test results at 0x400778

```asm
0x02049E: mov.l  #0x40f800, er7        ; Relocate SP to external RAM (0x40F800)
```

**Key**: SP is moved from on-chip RAM (0xFFFF00) to external RAM (0x40F800), confirming external RAM at 0x400000.

### Peripheral Initialization (0x204A4)

```asm
0x0204A4: jsr    @0x00015eaa           ; Hardware initialization subroutine
```

### Interrupt Trampoline Installation (0x204C4-0x205E2+)

The interrupt vector table entries point to on-chip RAM addresses (0xFFFD10-0xFFFD3C). The main firmware writes JMP instructions to these RAM locations, allowing runtime modification of interrupt handlers.

See [Vector Table](./vector-table.md) for the complete mapping.

## Flash Layout

| Offset | Size | Content |
|--------|------|---------|
| 0x00000-0x00FFF | 4KB | Boot code (vector table + startup) |
| 0x01000-0x03FFF | 12KB | ERASED |
| 0x04000-0x04FFF | 4KB | Small data block (BSC config?) |
| 0x05000-0x05FFF | 4KB | ERASED |
| 0x06000-0x06FFF | 4KB | Small data block |
| 0x07000-0x07FFF | 4KB | ERASED |
| 0x08000-0x0FFFF | 32KB | ERASED (no "extended settings") |
| 0x10000-0x17FFF | 32KB | Shared handler module (interrupt handlers, USB code) |
| 0x18000-0x1FFFF | 32KB | ERASED |
| 0x20000-0x52FFF | ~200KB | Main firmware code + data |
| 0x53000-0x5FFFF | 52KB | ERASED |
| 0x60000-0x63FFF | 16KB | Log area 1 (433 × 32-byte usage telemetry records) |
| 0x64000-0x6FFFF | 48KB | ERASED |
| 0x70000-0x7FFFF | 64KB | Log area 2 (2048 × 32-byte usage telemetry records) |

**Total used**: ~320KB of 512KB

Source: Flash dump scan via Ghidra script, 4KB block granularity

## Memory Map (Updated)

| Region | Address Range | Size | Purpose |
|--------|---------------|------|---------|
| Flash | 0x000000-0x07FFFF | 512KB | Firmware + data (also mapped as low addresses for boot) |
| ASIC | 0x200000-0x20FFFF | 64KB? | Custom scanner ASIC registers |
| External RAM | 0x400000-0x41FFFF | 128KB | Main working RAM |
| ISP1581 | 0x600000-0x6000FF | 256B | USB controller registers |
| ASIC RAM | 0x800000-0x837FFF | 224KB | Scanner ASIC frame buffer |
| Buffer RAM | 0xC00000-0xC0FFFF | 64KB | Additional buffer |
| On-chip RAM | 0xFFFD00-0xFFFF1F | ~544B | H8/3003 internal RAM |
| I/O Registers | 0xFFFF20-0xFFFFFF | 224B | H8/3003 peripheral registers |

**Note**: Flash appears mapped at BOTH low addresses (for vector table boot) AND at 0x400000+ (for explicit data access in startup code references like `mov.b @0x004006b2, r0l`). The Bus State Controller (ABWCR/CSCR/WCR) configures this dual mapping.

## Transition to Main Loop (0x205FC-0x20620)

After the 12th and final trampoline install (IRQ1/ISP1581 at 0x205E2-0x205F7), the firmware transitions to the main loop:

```asm
0x0205FC: JSR  @0x0109FA         ; Clear shared state (zero @0x40076E)
0x020600: MOV.B #0x01, R0L
0x020602: MOV.B R0L, @0x400772   ; Set "initialized" flag
0x020608: ANDC  #0x7F, CCR       ; >>> ENABLE INTERRUPTS (first time!) <<<
0x02060A: JSR  @0x02A188         ; One-time hardware init (with interrupts enabled)
0x02060E: ORC   #0x80, CCR       ; Disable interrupts again
0x020610: MOV.B #0x00, R0L
0x020612: MOV.B R0L, @0x400772   ; Reset flag for first-boot descriptor selection
0x020618: JSR  @0x0107BC         ; Register main loop entry point
0x02061C: JSR  @0x010BCE         ; Initialize ASIC/DMA state
0x020620: JMP  @0x0107EC         ; >>> ENTER CONTEXT SYSTEM (never returns) <<<
```

The `JMP @0x0107EC` enters the two-context cooperative coroutine system. See [Main Loop](./main-loop.md) for the full architecture.

**Key**: Interrupts are briefly enabled at 0x20608 for the hardware init call, then disabled again. The context system manages its own interrupt state.

## Related KB Docs

- [Main Loop](./main-loop.md) — Main loop and task dispatch architecture
- [Vector Table](./vector-table.md) — All interrupt vector mappings
- [USB Protocol](../../architecture/usb-protocol.md) — Host-side USB protocol
