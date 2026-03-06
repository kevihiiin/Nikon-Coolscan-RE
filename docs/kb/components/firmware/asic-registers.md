# Custom ASIC Register Map — Nikon LS-50

**Status**: Complete
**Last Updated**: 2026-02-28
**Phase**: 4 (Firmware)
**Confidence**: Medium (register addresses confirmed from init table and code references; functional assignments are inferred from context and register grouping)

## Overview

The LS-50 contains a custom ASIC at base address `0x200000` that handles:
- CCD timing and readout
- Analog-to-digital conversion control
- Motor drive signal generation
- DMA channel management
- Scan data buffering and transfer

The ASIC has **172 unique register addresses** across 8 register blocks. It interfaces with three memory regions:
- **ASIC RAM** at `0x800000` (224KB) — CCD line buffer and scan data staging
- **Buffer RAM** at `0xC00000` (64KB) — processed scan data for USB transfer
- **ISP1581** at `0x600000` — USB bulk transfer destination

## Register Block Summary

| Block | Address Range | Registers | Function |
|-------|---------------|-----------|----------|
| 0x00 | `0x200000-0x2000C7` | 26 | System control, status, DAC config |
| 0x01 | `0x200100-0x2001CB` | 65 | DMA channels, motor drive, line timing |
| 0x02 | `0x200200-0x20026D` | 15 | CCD data channel configuration |
| 0x04 | `0x200400-0x200487` | 56 | CCD timing, analog gain, per-channel config |
| 0x09 | `0x200910` | 1 | Unknown |
| 0x0A | `0x200A81-0x200AF2` | 4 | Unknown (possibly test/debug) |
| 0x0C | `0x200C82` | 1 | Unknown |
| 0x0F | `0x200F20-0x200FC0` | 4 | Unknown (possibly calibration) |

## Block 0x00 — System Control (0x200000-0x2000C7)

| Register | Init Value | R/W | Purpose |
|----------|-----------|-----|---------|
| `0x200001` | 0x80 | W | **Master enable/reset** — written during USB bus reset (0x13A20) and system init |
| `0x200002` | — | R | **Status register** — read at 0x035DC8 and DMA handler |
| `0x200003` | — | R/W | Status/control |
| `0x200008` | — | R/W | Interrupt config |
| `0x20000F` | — | R/W | Interrupt mask/status |
| `0x200020` | — | R/W | DMA control |
| `0x200028` | — | R/W | DMA status |
| `0x200041` | — | R/W | **RAM test register** — used during RAM test (0x203BA-0x20460) |
| `0x200042` | — | R/W | **RAM test register** — used during startup validation |
| `0x200044` | 0x00 | W | Cleared at init |
| `0x200045` | 0x00 | W | Cleared at init |
| `0x200046` | 0xFF | W | All bits set at init |
| `0x200053` | — | R/W | Unknown |
| `0x20005A` | — | R/W | Unknown |
| `0x200069` | — | R/W | Unknown |
| `0x20006B` | — | R/W | Unknown |
| `0x20006F` | — | R/W | Unknown |
| `0x20008C-0x20008E` | — | R/W | Unknown triplet |
| `0x2000AD-0x2000AE` | — | R/W | Unknown pair |
| `0x2000C0` | 0x52 | W | **DAC/ADC config** — CCD analog front-end master config |
| `0x2000C1` | 0x04 | W | DAC/ADC control |
| `0x2000C2` | — | R/W | **DAC mode register** — 0x20=init, 0x22=normal scan, 0xA2=calibration (bit 7=cal enable). 16 code refs. |
| `0x2000C4` | — | R/W | ADC control register (ref: `0x293B7`) |
| `0x2000C6` | — | R | ADC readback register (ref: `0x27C67`) |
| `0x2000C7` | — | R/W | **DAC fine control** — 0x08 (LS-50), 0xB4 (LS-5000). Model-specific via flag at `0x404E96`. |

## Block 0x01 — DMA/Channel/Motor Config (0x200100-0x2001CB)

### DMA Channel Configuration (0x200100-0x200117)

| Register | Init | Purpose |
|----------|------|---------|
| `0x200100` | 0x3F | DMA channel 0 source config |
| `0x200101` | 0x3F | DMA channel 0 dest config |
| `0x200102` | 0x04 | **Motor DMA control** (5 write sites in motor code) |
| `0x200103` | 0x01 | DMA channel mode |
| `0x200104` | 0x30 | DMA channel 1 source |
| `0x200105` | 0x32 | DMA channel 1 dest |
| `0x200106` | 0x34 | DMA channel 2 source |
| `0x200107` | 0x36 | DMA channel 2 dest |
| `0x20010C` | 0x20 | DMA channel 3 source |
| `0x20010D` | 0x22 | DMA channel 3 dest |
| `0x20010E` | 0x24 | DMA channel 4 source |
| `0x20010F` | 0x26 | DMA channel 4 dest |
| `0x200114` | 0x00 | DMA channel 5 source |
| `0x200115` | 0x08 | DMA channel 5 dest |
| `0x200116` | 0x10 | DMA channel 6 source |
| `0x200117` | 0x18 | DMA channel 6 dest |

### DMA/Buffer Control (0x200140-0x200153)

| Register | Init | Purpose |
|----------|------|---------|
| `0x200140` | 0x01 | DMA enable register |
| `0x200141` | 0x01 | DMA mode |
| `0x200142` | 0x04 | DMA transfer config (referenced from 0x35C7E) |
| `0x200143` | 0x01 | Buffer control |
| `0x200144` | 0x04 | Buffer mode |
| `0x200147` | 0x00 | Buffer address low (referenced from 0x35D58) |
| `0x200148` | 0x00 | Buffer address mid |
| `0x200149` | 0x00 | Buffer address high |
| `0x20014B` | 0x00 | Transfer count low (referenced from 0x35D92) |
| `0x20014C` | 0x40 | Transfer count mid |
| `0x20014D` | 0x00 | Transfer count high |
| `0x20014E` | 0x00 | DMA status |
| `0x20014F` | 0x04 | DMA control 2 |
| `0x200150` | 0x03 | DMA interrupt enable |
| `0x200152-0x200153` | — | Extended DMA config |

### Motor Drive (0x200181-0x20019B)

| Register | Init | Purpose |
|----------|------|---------|
| `0x200181` | 0x0D | **Motor drive config** — written at 0x03581A, 0x0358F2 |
| `0x200182-0x200189` | — | **Motor drive channels A** — 4 register pairs (high/low), coil drive signals |
| `0x200193` | 0x0E | Motor drive config B |
| `0x200194-0x20019B` | — | **Motor drive channels B** — 4 register pairs (high/low) |
| `0x2001A4-0x2001A6` | — | Motor auxiliary config |

### CCD Line Timing (0x2001C0-0x2001CB)

| Register | Init | Purpose |
|----------|------|---------|
| `0x2001C0` | 0x03 | Line timing mode |
| `0x2001C1` | 0x00 | Line timing control (referenced from 0x3C274) |
| `0x2001C2` | 0x0F | Pixel clock divider |
| `0x2001C3` | 0x98 | Line period low |
| `0x2001C4` | 0x00 | Line period high |
| `0x2001C5` | 0x19 | Integration start |
| `0x2001C6` | 0x0F | Integration config |
| `0x2001C7` | 0x69 | Integration end |
| `0x2001C8` | 0x00 | Readout start |
| `0x2001C9` | 0x18 | Readout config |
| `0x2001CA-0x2001CB` | — | Extended timing |

## Block 0x02 — CCD Data Channels (0x200200-0x20026D)

15 registers. The stride-8 pattern suggests 4 color channels (R, G, B, IR):

| Register | Init | Purpose |
|----------|------|---------|
| `0x200200` | 0x00 | Channel master config |
| `0x200204` | 0x04 | Channel 0 (Red?) config |
| `0x200205` | 0x03 | Channel 0 mode |
| `0x200214-0x200215` | — | Channel 0 pair B |
| `0x20021C-0x20021D` | — | Channel 1 (Green?) config |
| `0x200224-0x200225` | — | Channel 1 pair B |
| `0x20022C-0x20022D` | — | Channel 2 (Blue?) config |
| `0x200255` | — | Channel 2 extended |
| `0x20025D` | — | Channel 3 (IR?) config |
| `0x200265` | — | Channel 3 extended |
| `0x20026D` | — | Channel master extended |

## Block 0x04 — CCD Timing/Gain/Channel Config (0x200400-0x200487)

The largest block with 56 registers. Organized into functional sub-blocks:

### Master CCD Control (0x200400-0x200406)

| Register | Init | Purpose |
|----------|------|---------|
| `0x200400` | 0x20 | CCD master mode |
| `0x200401` | 0x0A | CCD pixel clock config |
| `0x200402` | 0x00 | CCD control |
| `0x200404` | 0x00 | CCD config A |
| `0x200405` | 0xFF | CCD data mask (all bits active) |
| `0x200406` | 0x01 | CCD enable |

### CCD Integration Timing (0x200408-0x200425)

15 register pairs defining CCD integration windows. Groups of 6 registers repeat 3 times, suggesting 3 timing phases per CCD readout cycle:

| Group | Registers | Init Values | Likely Phase |
|-------|-----------|-------------|--------------|
| 1 | `0x408-0x40D` | 01 41, 00 09, 00 19 | Transfer gate timing |
| 2 | `0x40E-0x413` | 01 2B, 00 0D, 00 15 | Integration window |
| 3 | `0x414-0x419` | 01 2B, 00 0D, 00 15 | Second integration (identical to group 2) |
| 4 | `0x41A-0x41F` | 01 29, 00 02, 00 20 | Readout timing |
| 5 | `0x420-0x425` | 01 2F, 00 05, 00 1D | Reset/clamp timing |

### Analog Gain/Offset (0x200456-0x200458)

| Register | Init | Purpose |
|----------|------|---------|
| `0x200456` | 0x00 | Gain channel select or mode |
| `0x200457` | 0x63 | **Analog gain** value (99 decimal — default gain) |
| `0x200458` | 0x63 | **Analog gain** value (second channel or coarse/fine) |

Referenced by calibration routines. Debug string "GAIN" at `FW:0x49EF7` cross-references these registers.

### Per-Channel Config (0x200468-0x200487)

4 identical channel groups at stride 8. Each channel has 3 init registers with identical values (0x00, 0x01, 0x2B):

| Channel | Base | Purpose (inferred) |
|---------|------|-----|
| 0 (Red) | `0x20046D` | Per-channel timing: offset=0x00, start=0x01, end=0x2B |
| 1 (Green) | `0x200475` | Same init values |
| 2 (Blue) | `0x20047D` | Same init values |
| 3 (IR) | `0x200485` | Same init values |

These appear to define per-color-channel CCD readout windows, allowing independent timing for each color. The LS-50 CCD is a tri-linear sensor with separate R/G/B lines plus an IR channel for Digital ICE.

## I/O Init Table (0x2001C)

The I/O init table at `FW:0x2001C` contains 132 entries of 6 bytes each:
- **Bytes 0-3**: 32-bit register address (big-endian)
- **Byte 4**: Always 0x00
- **Byte 5**: Initial value

Breakdown: **30 CPU registers** (0xFFFFxx) + **48 ASIC core registers** (0x2000xx-0x2001xx) + **54 CCD/channel registers** (0x2002xx-0x2004xx)

The table ends with `0x200001 = 0x80` (entry 131), which is the ASIC master enable — the last step of hardware initialization.

## Scan Data Pipeline

```
CCD Sensor (tri-linear R/G/B + IR)
    |
    v
ASIC Analog Front-End (0x2000C0-C7: DAC/ADC config)
    |-- Per-channel gain (0x200457-458)
    |-- Integration timing (0x200408-425)
    |-- Per-channel windows (0x20046D-487)
    |
    v
ASIC Digital Processing
    |-- Line buffer in ASIC RAM (0x800000+, 224KB)
    |-- DMA channels (0x200100-117, 0x200140-153)
    |
    v
Buffer RAM (0xC00000+, 64KB)
    |-- Processed scan lines staged for USB transfer
    |
    v
ISP1581 USB Controller (0x600000)
    |-- Bulk-in DMA transfer to host
    |-- Managed by response manager at 0x01374A
```

## DMA Subsystem

### Timer-Coordinated DMA

Two timer ISRs coordinate DMA operations (not DMA completion interrupts — actual DMA end handlers are DEND0B at Vec 45 → 0x02CEF2 and DEND1B at Vec 47 → 0x02E10A):
- **ITU3** (Vec 36 → `0x02D536`): DMA burst coordinator. Reads state from `0x406374`, checks `0x4052D6` for transfer type, dispatches to ASIC-related DMA
- **ITU4** (Vec 40 → `0x010A16`): System tick / USB poll. Timestamp-based (`0x40076E`), manages multiple transfer modes (checks `0x4062E6`, `0x405302`, `0x4052EE`, `0x400773`)

### ASIC DMA

The ASIC has its own DMA engine (registers 0x200100-0x200117, 0x200140-0x200153) that handles:
- CCD line data → ASIC RAM transfers
- ASIC RAM → Buffer RAM transfers
- Motor DMA (0x200102)

## Key Code Addresses

| Address | Function |
|---------|----------|
| `0x2001C` | I/O init table (132 entries) |
| `0x02D536` | ITU3 ISR (Vec 36) — DMA burst coordinator |
| `0x010A16` | ITU4 ISR (Vec 40) — system tick / USB transfer poll |
| `0x035600` | ASIC motor register configuration |
| `0x035C7E` | ASIC DMA buffer config (refs 0x200142) |
| `0x035D58` | ASIC DMA address config (refs 0x200147) |
| `0x035D92` | ASIC DMA count config (refs 0x20014B) |
| `0x03C274` | CCD line timing config (refs 0x2001C1) |

## Cross-References

- [Startup Code](startup.md) — I/O init table processing
- [Motor Control](motor-control.md) — Motor drive registers (0x200181-0x20019B)
- [ISP1581 USB](isp1581-usb.md) — USB DMA interface
- [SCSI Handler](scsi-handler.md) — SCAN/READ commands that trigger data pipeline
- [Memory Map](../../reference/memory-map.md) — ASIC, buffer, and ISP1581 address regions
