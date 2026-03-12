# Lamp/LED Control — Nikon LS-50

**Status**: Complete
**Last Updated**: 2026-02-28
**Phase**: 4 (Firmware)
**Confidence**: High (GPIO port confirmed from multiple write sites; exposure parameters traced from C1 handler)

## Overview

The LS-50 uses a white LED lamp (not fluorescent tube) for illumination during scanning. Lamp control is managed through GPIO bit 0 at address `0xFF85`, with exposure parameters configured through the SCSI Vendor C1 subcommand 0x80.

## Lamp GPIO

**Register at `0xFF85`** (`0xFFFF85` full address) is the lamp control register. Based on H8/3003 port register layout (P1DDR=0x80, P1DR=0x82, P3DDR=0x84, **P4DDR=0x85**, P3DR=0x86 — interleaved pattern confirmed by 11 other port references in the GPIO table), this is **Port 4 Data Direction Register (P4DDR)**. The SLEIGH pspec's "TSR3" mapping is for generic H8/300H, not the H8/3003 specifically.

Lamp control uses DDR toggling (open-drain pattern): BCLR #0 sets P4 bit 0 to input mode, allowing an external pull-up to activate the lamp circuit. BSET #0 sets it to output mode, driving the pin to control lamp off:

| Pin | Function | Direction |
|-----|----------|-----------|
| Bit 0 | **Lamp enable** (BCLR to turn on) | Output |

### Write Sites

All 6 lamp-on write sites in the firmware:

| Address | Instruction | Context |
|---------|------------|---------|
| `0x2C66A` | `BCLR #0, @0xFF85` | Lamp ON in scan init |
| `0x2D2E8` | `BCLR #0, @0xFF85` | Lamp ON in scan setup |
| `0x2D3C2` | `BCLR #0, @0xFF85` | Lamp ON in alt scan path |
| `0x2D4EE` | `BCLR #0, @0xFF85` | Lamp ON in shutdown sequence |
| `0x2D53E` | `BCLR #0, @0xFF85` | Lamp ON in calibration |
| `0x2D670` | `BCLR #0, @0xFF85` | Lamp ON in readout |

### Consistent Pattern

All lamp-on write sites use the same code pattern:

```asm
mov.b   #0xA3, r0l           ; Status value
mov.b   r0l, @(status_reg)   ; Write status
mov.b   @0xFF85, r0l         ; Read current GPIO
mov.b   r0l, @0x400791       ; Save to GPIO shadow register
bclr    #0, @0xFF85           ; LAMP ON (active-low: clear bit 0)
sub.w   r0, r0
mov.w   r0, @0xFF86           ; Clear adjacent port register
```

The RAM address `0x400791` is a general GPIO shadow register (used before bit operations on multiple GPIO ports — 0xFF85, 0xFF67, 0xFF71, 0xFF7B — with 23 total references). It preserves the pre-modification GPIO state.

Lamp-off would use `BSET #0, @0xFF85` (set bit 0 high = inactive), the inverse of the BCLR #0 used for lamp-on.

## Lamp State Machine

The lamp state machine is managed by subroutine `FW:0x13C6E`, called from the C1/0x80 handler:

```asm
0x13C6E:
  test    @0x400082            ; Check lamp state flag
  bne     already_active
  mov.b   #0x01, @0x400082    ; Set lamp state = active
  ; Configure timer control (BSET on 0xFF60 TCSR)
  ; Read device status from 0x407DC7
```

Key state variables:
- `0x400082` — Lamp state (0 = off, 1 = active)
- `0x400E5F` — Lamp active flag (set by C1/0x80 handler)
- `0x400791` — GPIO shadow register (general, not lamp-specific)

## Exposure Control (C1 Subcommand 0x80)

The Vendor C1 subcommand 0x80 at `FW:0x28BC4` controls lamp and per-channel exposure:

```asm
0x28BC4: jsr     @0x13C6E       ; Initialize lamp state machine
0x28BC8: mov.b   #0x01, r0l
0x28BCA: mov.b   r0l, @0x400E5F ; Set lamp active flag
0x28BD0: jmp     @0x28E10       ; Continue to exposure setup
```

### Per-Channel Exposure Parameters

The handler extracts per-channel exposure timing from the SCSI CDB:
- CDB offsets 0x02-0x05: Channel 0 (Red) exposure
- CDB offsets 0x06-0x09: Channel 1 (Green) exposure
- CDB offsets 0x0A-0x0B: Channel identifier

Parameters are assembled into 32-bit values and written to:
- `0x40077E` — R channel exposure timing
- `0x400782` — G channel exposure timing

Processing includes `DIVXU.B` at `0x28BE7` for gain calculation (division for exposure normalization).

## C1 Subcommand Dispatch

The C1 handler at `FW:0x28B08` uses a **linear CMP/BEQ chain** to dispatch 24 subcommands:

| Subcmd | Target | Function |
|--------|--------|----------|
| `0x40`-`0x43` | `0x28BD8` | Scan control (CDB params → RAM) |
| `0x44` | `0x28BF0` | Calibration param write |
| `0x45`-`0x47` | `0x28BD8` | Scan control |
| **`0x80`** | **`0x28BC4`** | **Lamp/exposure control** |
| `0x81` | `0x28DEC` | Lamp status (quick return) |
| `0x91` | `0x28BF0` | CCD configuration |
| `0xA0` | `0x28C2E` | Exposure/focus control params |
| `0xB0`, `0xB1` | `0x28DEC` | Motor (quick return) |
| `0xB3` | `0x28CAC` | Motor position B3 |
| `0xB4` | `0x28D5E` | Motor position B4 |
| `0xC0`, `0xC1` | `0x28BF0` | CCD readout config |
| `0xD0`, `0xD1` | `0x28DEC` | Status read (quick return) |
| `0xD2` | `0x28BF0` | Status D2 |
| `0xD5` | `0x28C2E` | Focus control |
| `0xD6` | `0x28DA6` | Misc D6 |
| default | `0x28DE4` | Error/NOP |

### Two-Level Dispatch

The C1 handler has two dispatch levels:
1. **CDB extraction** at `0x28B08`: Parses CDB parameters, routes by subcommand
2. **Hardware operation** via secondary table at `0x4A134`: Maps subcommands to deeper handler functions

| Subcmd | Secondary Handler | Purpose |
|--------|-------------------|---------|
| `0x80` | `0x2C46E` | Lamp hardware control |
| `0xA0` | `0x4609C` | Exposure/focus hardware |
| `0xC0` | `0x2DB26` | CCD readout hardware |

### Exposure Control Handler (0x4609C)

The 0xA0/0xD5 handler at `FW:0x4609C` performs:
- Motor positioning via `0x037D18`
- CCD line timing setup via `0x035808`
- Math: multiply via `0x0163EA`, divide via `0x015DB4`
- Calibration table lookup via `0x039C8A`, `0x039C6C`
- Reads exposure params from `0x4074DE`, `0x4052A6`, `0x407626`

## Cross-References

- [Vendor C1](../../scsi-commands/vendor-c1.md) — Host-side C1 command documentation
- [Vendor E0](../../scsi-commands/vendor-e0.md) — E0 writes register data including lamp params
- [Calibration](calibration.md) — DAC mode control during calibration
- [ASIC Registers](asic-registers.md) — DAC/ADC registers at 0x2000C0-C7
- [Scan Data Pipeline](scan-pipeline.md) — Lamp must be on during scanning
