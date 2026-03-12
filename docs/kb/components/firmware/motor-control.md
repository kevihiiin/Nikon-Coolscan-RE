# Firmware Motor Control Subsystem

**Status**: Complete
**Last Updated**: 2026-03-05
**Phase**: 4 (Firmware)
**Confidence**: Verified (decoded from disassembly + binary data tables, timer-to-vector mapping confirmed via SLEIGH pspec + handler register access)

## Overview

The LS-50 scanner has **two stepper motors**:
- **SCAN Motor** — drives the scanning carriage along the film strip
- **AF Motor** — positions the autofocus lens

Both motors are driven by **timer-interrupt-based stepper sequences** using the H8/3003's Integrated Timer Unit (ITU). The firmware implements a complete motion control system with acceleration/deceleration ramp profiles, position encoding, and multi-mode operation.

**Autofocus is host-driven**: The firmware provides only basic motor positioning commands (stop, home, relative move, absolute move). The contrast-based autofocus algorithm runs entirely on the host in NikonScan — it reads CCD image data, computes contrast metrics, and sends individual AF motor position commands to the firmware until optimal focus is achieved. The firmware has no autonomous focus search loop.

Debug strings confirm the two-motor architecture:
- `"SCAN Motor"` at `FW:0x49E89`
- `"AF Motor"` at `FW:0x49E94`

## Architecture

```
SCSI SCAN Command (0x1B) @ 0x0220B8
  |
  v
Internal task dispatch (0x20DBA) -> task code 04xx (motor subsystem)
  |
  v
ITU0 Special handler (0x2B544) -- position tracking, calls motor_setup
  |-- Clears motor state vars (0x4052E8, 0x4052EC, 0x4052ED)
  |-- Calls motor_setup (0x2E158)
  |     |-- Loads ramp config from 0x400CC8
  |     |-- Calculates timer period (jsr 0x163EA, 0x15CCC)
  |     |-- Sets motor_mode in 0x400774 (2, 3, or 6)
  |     |-- Starts ITU2 (BSET #2, TSTR)
  |
  v
ITU2 ISR fires per movement (0x10B76)
  |-- Reads motor_mode from 0x400774
  |-- Dispatches to mode-specific handler
  |
  v
Mode handlers -> Main motor step engine (0x2DEEE)
  |-- Update step position
  |-- Apply ramp table for accel/decel
  |-- Write stepper phase to Port A
  |-- Reload timer compare for next step speed
  |-- Restart ITU2 if more steps needed
  |
  v
Encoder ISR (0x33444) runs independently:
  |-- Counts encoder pulses (position feedback)
  |-- Measures inter-pulse period (speed feedback)
```

## Timer Assignments

| Timer | Vector | Handler | Function |
|-------|--------|---------|----------|
| **ITU2** Compare A | Vec 32 → `0x010B76` | Mode dispatcher | Motor mode interrupt — polls motor_mode, dispatches to mode-specific handlers |
| **ITU4** Compare A | Vec 40 → `0x010A16` | System tick | Global timestamp increment (reads TSR4 at 0xFFFF95) — started once, never stopped |
| **IRQ3** | Vec 15 → `0x033444` | Encoder ISR | Position encoder — counts motor shaft encoder pulses |
| **Reserved** | Vec 19 → `0x02B544` | Position tracker | Integrates encoder data, initiates motor operations |

**Key design**: ITU4 is started **once** at system init (`BSET #4, TSTR` at `0x010A10`) as a system tick counter (not motor-related). ITU2 is the **motor timer**, started/stopped for each motor movement. The motor mode dispatcher (0x010B76) runs on ITU2 compare match events.

**Correction (2026-03-05)**: Previous analysis labeled the motor dispatcher as "ITU4". Binary verification (handler at Vec 32 = IMIA2 per SLEIGH pspec, handler at Vec 40 accesses TSR4) confirms it runs on ITU2. TSTR bit analysis is consistent: BSET #2 (ITU2) has 11 start / 15 stop sites (per-movement), BSET #4 (ITU4) has 1 start / 0 stop (once at init).

### TSTR (Timer Start Register, 0xFFFF60) Usage

| Bit | Timer | Start Sites | Stop Sites | Purpose |
|-----|-------|-------------|------------|---------|
| #0 | ITU0 | 3 | — | Encoder capture |
| #1 | ITU1 | 1 | — | Position feedback |
| #2 | **ITU2** | **11** | **15** | **Motor mode dispatcher** (frequently started/stopped per movement) |
| #3 | ITU3 | 4 | — | Secondary timing |
| #4 | **ITU4** | **1** | **0** | **System tick timer** (started once, never stopped) |

## Motor Mode Dispatcher (ITU2 ISR) — `0x010B76`

The ITU2 Compare A interrupt reads `motor_mode` at RAM `0x400774` and dispatches:

| Mode | Handler | Purpose |
|------|---------|---------|
| 2 | `0x02E268` | Scan motor step |
| 3 | `0x02EDC0` | AF motor step |
| 4 | `0x03337E` | Encoder/special processing |
| 6 | `0x02E276` | Alternative scan motor (possibly reverse direction) |

```
010B76: push er1, er0
010B7E: mov.b @0x400774, r0l    ; motor_mode
010B84: cmp.b #2, r0l           ; mode 2?
010B88: beq -> jsr @0x02E268    ; Scan motor
010B8C: cmp.b #3, r0l           ; mode 3?
010B90: beq -> jsr @0x02EDC0    ; AF motor
010B94: cmp.b #4, r0l           ; mode 4?
010B98: beq -> jsr @0x03337E    ; Encoder
010B9C: cmp.b #6, r0l           ; mode 6?
010BA0: beq -> jsr @0x02E276    ; Alt scan motor
010BA4: jmp -> pop, rte         ; Default: no-op
```

## Motor Setup Function — `0x02E158`

Configures ITU2 and starts a motor movement:

1. Sets `motor_enable_flag` at `0x4052EA`
2. Clears GRA1 compare register
3. Stops ITU1
4. Loads ramp configuration from `0x400CC8`
5. Calculates initial timer period (`jsr @0x0163EA`, `jsr @0x015CCC`)
6. Loads counter into TCNT3
7. Sets motor direction at `0x400791`
8. Configures GRB2 compare register
9. Sets motor_mode (2, 3, 4, or 6) at `0x400774`
10. Configures TIER3 interrupt enable
11. **Starts ITU2** (`BSET #2, TSTR`)

## Stepper Motor Drive

### Phase Tables

**Forward direction** at `FW:0x16E92`:
```
01 02 04 08    (wave drive: one coil at a time)
```

**Reverse direction** at `FW:0x4A8A8`:
```
08 04 02 01    (reverse sequence)
```

This is **unipolar 4-phase wave drive** (single-phase excitation):
| Step | Binary | Active Coil |
|------|--------|-------------|
| 0 | 0001 | Phase A |
| 1 | 0010 | Phase B |
| 2 | 0100 | Phase /A |
| 3 | 1000 | Phase /B |

Wave drive trades torque for simplicity — each step activates only one coil. The 4-step cycle gives the minimum step resolution (full-step mode).

### Motor Output

**Port A DR** (`0xFFFFA3`) is the primary motor output port. Stepper phase values (01, 02, 04, 08) are written here. Port A has 44 firmware references (22R/22W), concentrated in scan-setup (26) and motor-control (10) code regions. Port A bit 0 is used via BSET/BCLR (4 ops) for motor enable/disable.

**Supporting GPIO ports**:
- **Port 3 DDR** (`0xFFFF84`): Motor direction control — bit 0 toggled via BSET/BCLR (11 refs, all in motor-control code)
- **Port 9 DR** (`0xFFFFC8`): Motor encoder input (7 reads in motor-control) and stepper phase output (5 writes in scan-setup)
- **Port 7 DR** (`0xFFFF8E`): Adapter/sensor status input (16 reads total, 14 in SCAN command handler at 0x22000-0x22600)

## Speed Ramp Tables

### Linear Ramp — `FW:0x16C38`

33 entries, perfectly linear from 56 to 312 in steps of 8:
```
56, 64, 72, 80, 88, 96, 104, 112, 120, 128,
136, 144, 152, 160, 168, 176, 184, 192, 200, 208,
216, 224, 232, 240, 248, 256, 264, 272, 280, 288,
296, 304, 312
```

These are timer compare values — **smaller values = faster stepping** (shorter interval between step interrupts). This table is used for deceleration (traversed forward) or acceleration (traversed backward).

### Multi-Variant Ramp Tables — `FW:0x0459D2+`

Multiple ramp tables for different scan speeds/adapter types:

| Address | Starting Value | Ending Value | Likely Use |
|---------|---------------|-------------|------------|
| `0x0459D2` | 64 | 28512 | Decel ramp, mode A |
| `0x045A10` | 64 | 27562 | Decel ramp, mode B |
| `0x045C3A` | 98 | 28512 | Decel ramp, adapter A |
| `0x045C78` | 98 | 27562 | Decel ramp, adapter B |
| `0x045EA2` | 132 | 28512 | Decel ramp, adapter C |
| `0x045EE0` | 132 | 27562 | Decel ramp, adapter D |

The starting values (64, 98, 132) correspond to different scan resolutions or adapter types — faster resolutions can afford shorter initial timing values.

## Encoder Subsystem — `0x033444`

The optical encoder provides position and speed feedback:

```
033444: push er1, er0
03344C: mov.l #0x40530E, er0    ; encoder_count address
033452: mov.w @er0, r1          ; Read current count
033454: inc.w #1, r1            ; Increment
033456: mov.w r1, @er0          ; Store updated count
033458: mov.w @0x400770, r0     ; Current timer capture value
03345E: mov.w @0x40531A, r1     ; Previous capture value
033464: sub.w r1, r0            ; Delta = time between pulses
033466: mov.w r0, @0x405314     ; Store delta (speed measurement)
03346C: mov.l @0x40076E, er0    ; System timestamp
033474: mov.l er0, @0x405318    ; Store timestamp
03347C: mov.b @0x40530A, r0l    ; Encoder state
033482: cmp.b #0xD1, r0l        ; Special mode?
033486: bsr 0x033A0C            ; Handle special processing
03348A: pop, rte
```

Triggered by IRQ3 (external interrupt from encoder output pin). Measures time between encoder pulses using software timer reads, providing both:
- **Position**: pulse count at `0x40530E`
- **Speed**: inter-pulse delta at `0x405314`

## Task Table Motor Entries (04xx codes)

From the internal task table at `0x49910`:

| Code | Handler Idx | Purpose |
|------|------------|---------|
| 0x0440 | 0x002B | Motor move (relative) |
| 0x0450 | 0x007F | Motor move (absolute) |
| 0x0430 | 0x002C | Motor home/reference |
| 0x0400 | 0x0030 | Motor stop/reset |
| 0x0406 | 0x0000 | Motor status query |

## ASIC Motor Registers

The custom ASIC at `0x200000` has motor-related registers:

| Address | Purpose |
|---------|---------|
| `0x200001` | Master enable/control |
| `0x200002` | Status (read) |
| `0x200102` | Motor DMA control (5 write sites in motor code) |
| `0x200181` | Motor config |
| `0x200182-0x200189` | Motor drive channels A (4 register pairs) |
| `0x200194-0x20019B` | Motor drive channels B (4 register pairs) |
| `0x2001A4-0x2001A6` | Motor auxiliary config |
| `0x2001C0-0x2001C9` | Motor timing / CCD line timing config |

The ASIC acts as an intermediary between the CPU's timer-driven step sequences and the actual motor driver hardware, likely providing current limiting, microstepping translation, or CCD-synchronized motor timing.

## RAM State Variables

| Address | Size | Name | Description |
|---------|------|------|-------------|
| `0x400774` | 1 | motor_mode | Mode selector for ITU2 dispatch (2/3/4/6) |
| `0x400791` | 1 | gpio_shadow | GPIO shadow register (general, 23 refs) |
| `0x400CC8` | 2 | motor_ramp_config | Ramp table selector / speed profile |
| `0x400C0E` | 2 | motor_speed_param | Current speed parameter |
| `0x4052E2` | 2 | motor_step_count | Current step position |
| `0x4052E4` | 2 | motor_target_pos | Target position for move |
| `0x4052E6` | 2 | motor_current_speed | Current timer period |
| `0x4052E8` | 2 | motor_accel_index | Index into acceleration ramp table |
| `0x4052EA` | 1 | motor_enable_flag | Motor enabled |
| `0x4052EB` | 1 | motor_running_flag | Motor currently running |
| `0x4052EC` | 1 | motor_state | State machine variable |
| `0x4052ED` | 1 | motor_direction2 | Direction (secondary) |
| `0x4052EE` | 1 | motor_error_flag | Error condition |
| `0x405300` | 1 | encoder_enable | Encoder subsystem enable |
| `0x405306` | 1 | encoder_mode | Encoder operating mode |
| `0x40530A` | 1 | encoder_state | Encoder state (0xD1 = special mode) |
| `0x40530E` | 2 | encoder_count | Encoder pulse count |
| `0x405314` | 2 | encoder_delta | Time between last two encoder pulses |
| `0x405318` | 4 | encoder_timestamp | Timestamp of last encoder event |
| `0x40531A` | 2 | encoder_last_capture | Previous capture value |

## Key Code Addresses

| Address | Type | Description |
|---------|------|-------------|
| `0x010A10` | Code | `BSET #4, TSTR` — ITU4 start (system tick, once) |
| `0x010A16` | ISR | ITU4 Compare A (Vec 40) — system tick timer |
| `0x010B76` | ISR | ITU2 Compare A (Vec 32) — motor mode dispatcher |
| `0x02B544` | ISR | Vec 19 — position tracking |
| `0x02DEEE` | Code | Main motor step engine |
| `0x02E158` | Code | Motor timer setup/start |
| `0x02E268` | Code | Mode 2 handler (scan motor) |
| `0x02E276` | Code | Mode 6 handler (alt scan motor) |
| `0x02EDC0` | Code | Mode 3 handler (AF motor) |
| `0x033444` | ISR | IRQ3 (Vec 15) — encoder pulse ISR |
| `0x03337E` | Code | Mode 4 handler (encoder special) |
| `0x035600` | Code | ASIC motor register configuration |

## Data Table Addresses

| Address | Type | Description |
|---------|------|-------------|
| `0x16C38` | Data | Linear speed ramp (33 entries, 56-312, step 8) |
| `0x16E92` | Data | Stepper phase table: `01 02 04 08` (forward) |
| `0x0459D2+` | Data | Multi-variant speed ramp tables |
| `0x4A8A8` | Data | Reverse stepper phase table: `08 04 02 01` |

## Cross-References

- [Vector Table](vector-table.md) — Interrupt vector assignments for motor timers
- [SCSI Handler](scsi-handler.md) — SCAN command (0x1B) triggers motor operations
- [Startup](startup.md) — I/O init table configures timer registers
- [Memory Map](../../reference/memory-map.md) — ASIC and RAM regions
- [SCAN Command](../../scsi-commands/scan.md) — Host-side scan operation flow
