# H8/3003 Memory Map — Nikon LS-50

**Status**: Complete
**Last Updated**: 2026-02-28
**Phase**: 4 (Firmware)
**Confidence**: Verified (I/O init table, BSC config, binary analysis, exhaustive address reference search)

## Overview

The LS-50 uses a Hitachi H8/3003 (H8/300H family) with a 24-bit address bus. The BSC (Bus State Controller) maps external devices into the CPU's address space. This document consolidates the complete memory map from firmware analysis.

## Address Map

```
0x000000-0x07FFFF  Flash ROM (512KB, MBM29F400B TSOP48)
    0x000000-0x0000FF  Interrupt vector table (64 × 4 bytes)
    0x000100-0x003FFF  Boot code + startup
    0x004000-0x005FFF  Settings area (mostly erased 0xFF)
    0x006000-0x007FFF  Extended settings area (identical to 0x4000 block, rest erased)
    0x008000-0x00FFFF  Unused — entirely 0xFF, NO firmware code references
    0x010000-0x017FFF  Shared handler module (ISP1581 USB, response manager)
    0x018000-0x01FFFF  Erased (unused)
    0x020000-0x052FFF  Main firmware (code + data tables)
    0x053000-0x05FFFF  Erased (unused)
    0x060000-0x063FFF  Flash log area 1 (433 records)
    0x064000-0x06FFFF  Erased (unused)
    0x070000-0x07FFFF  Flash log area 2 (2048 records)

0x200000-0x200FFF  Custom ASIC registers (172 unique addresses)
    0x200000-0x2000FF  Block 0x00: System control, status, DAC/ADC
    0x200100-0x2001FF  Block 0x01: DMA, motor drive, CCD line timing
    0x200200-0x2002FF  Block 0x02: CCD data channels (4 × stride-8)
    0x200400-0x2004FF  Block 0x04: CCD timing, analog gain, per-channel config
    0x200900-0x2009FF  Block 0x09: (sparse)
    0x200A00-0x200AFF  Block 0x0A: (sparse)
    0x200C00-0x200CFF  Block 0x0C: (sparse)
    0x200F00-0x200FFF  Block 0x0F: (sparse)

0x400000-0x41FFFF  External RAM (128KB)
    0x400000-0x40FFFF  Main RAM (variables, state, buffers)
        0x400082       USB command pending flag
        0x400764-76E   Context switch save area (coroutine system)
        0x400772       Boot flag (0=cold, 1=warm)
        0x400774       Motor mode selector
        0x400778       Current task code / scan status
        0x4007B0       SCSI sense code
        0x4007B6       Current SCSI opcode
        0x4007DE       CDB receive buffer (16 bytes)
        0x404E96       Model flag (LS-50 vs LS-5000)
        0x405000-4065FF Scan state variables
        0x406E3A       Channel descriptor table A
        0x406E62       Channel descriptor table B
        0x407DC0-407DFF USB session state block
    0x40D000           Context B stack base (USB data handler)
    0x40F800           Initial SP (relocated from on-chip)
    0x410000           Context A stack base (main firmware loop)

0x600000-0x6000FF  ISP1581 USB controller registers
    0x600008           Interrupt register
    0x60000C           Mode register
    0x600018           DMA register
    0x60001C           Endpoint control
    0x600020           Endpoint data
    0x60002C           Bulk mode register
    0x600084           DMA count register

0x800000-0x83FFFF  ASIC RAM (256KB physical, BSC range table at FW:0x207A8)
    Firmware-accessible: 224KB (0x800000-0x837FFF, validation table at FW:0x4A114)
    Last 32KB (0x838000-0x83FFFF): BSC-mapped but not in firmware validation table
    16 DMA banks (4 × 32KB + 12 × 8KB = 224KB):
      Banks 1-4:  0x800000, 0x808000, 0x810000, 0x818000  (32KB spacing)
      Banks 5-16: 0x820000, 0x822000, ..., 0x836000       (8KB spacing)
    Code reference 0x838000 found at FW:0x3E2E4 — used as boundary marker

0xC00000-0xC0FFFF  Buffer RAM (64KB) — USB transfer staging
    0xC00000           Ping-pong bank A (calibration, scan data)
    0xC08000           Ping-pong bank B (calibration)

0xFFFF00-0xFFFFFF  H8/3003 On-chip I/O registers
    0xFFFF60           TSTR (Timer Start Register)
    0xFFFF80-0xFFFF85  Port data registers (P1DR-P8DR)
    0xFFFFA3           Port A DR (motor stepper output)
    0xFFFFA8           Watchdog timer register
    0xFFFFB0-0xFFFFCF  SCI0/SCI1 serial registers

0xFFFD00-0xFFFD3F  On-chip RAM (used for interrupt trampolines)
    0xFFFD10-0xFFFD3C  12 trampoline JMP instructions (4 bytes each)

0xFFFF00             On-chip SP (initial, before relocation to 0x40F800)
```

## BSC Configuration (from I/O init table)

| Register | Value | Meaning |
|----------|-------|---------|
| ABWCR | 0x0B | Areas 0,1,3 = 8-bit bus; Areas 2,4-7 = 16-bit |
| WCR | 0xBA | Wait state configuration per area |
| CSCR | 0x30 | Chip select configuration |

## Flash Layout Detail

| Region | Address | Size | Content |
|--------|---------|------|---------|
| Vector table | 0x0000-0x00FF | 256B | 64 interrupt vectors |
| Boot code | 0x0100-0x018A | 138B | SP init, bank select, jump to main |
| Default handler | 0x0182-0x018A | 8B | NMI (0x0182), default infinite loop (0x0186) |
| Boot trampoline data | 0x06B4 | 48B | Erased (0xFF) — trampolines installed by main FW |
| Settings | 0x4000-0x7FFF | 16KB | Mostly erased (structured data at 0x4000, 0x6000) |
| Unused | 0x8000-0xFFFF | 32KB | Entirely 0xFF — no firmware references |
| Shared module | 0x10000-0x17FFF | 32KB | ISP1581, response manager, context switch, utility stubs |
| Main firmware | 0x20000-0x52FFF | ~204KB | SCSI handlers, motor, scan, calibration, data tables |
| Data tables | 0x45000-0x528BE | ~55KB | Task table, VPD, ramp, CCD characterization map |
| Log area 1 | 0x60000-0x63FFF | 16KB | Usage telemetry (wraps from area 2) |
| Log area 2 | 0x70000-0x7FFFF | 64KB | Usage telemetry (fills first) |

## Key RAM Variable Map

| Address | Size | Name | Description |
|---------|------|------|-------------|
| 0x400082 | 1 | cmd_pending | USB command pending flag |
| 0x400084 | 1 | usb_reset | USB bus reset flag |
| 0x400085 | 1 | usb_reinit | USB re-init needed |
| 0x400492 | 1 | task_complete | Task completion flag |
| 0x400493 | 1 | task_active | Task execution in-progress |
| 0x40049A | 1 | usb_txn_active | USB transaction active |
| 0x40049B | 1 | exec_mode | Current exec mode (SCSI table) |
| 0x400764 | 2 | ctx_switch_state | Context switch state word |
| 0x400766 | 8 | ctx_sp_save | SP save area (2 contexts × 4B) |
| 0x400772 | 1 | boot_flag | 0=cold boot, 1=warm restart |
| 0x400774 | 1 | motor_mode | ITU2 dispatch: 2=scan, 3=AF, 4=enc, 6=alt |
| 0x400776 | 1 | state_flags | Scanner state (bit6=abort, bit7=response) |
| 0x400778 | 2 | task_code | Current task code (primary dispatch) |
| 0x40077A | 2 | scan_progress | Scan progress / DMA state |
| 0x40078C | 4 | task_remaining | Task remaining work counter |
| 0x400791 | 1 | gpio_shadow | GPIO shadow register (general, 23 refs across multiple ports) |
| 0x400896 | 4 | task_budget | Task time budget counter |
| 0x4007B0 | 2 | sense_code | SCSI sense code |
| 0x4007B6 | 1 | scsi_opcode | Current SCSI opcode |
| 0x4007DE | 16 | cdb_buffer | CDB receive buffer |
| 0x400CC8 | 2 | ramp_config | Motor ramp table selector |
| 0x400E5F | 1 | soft_reset | Soft-reset request flag |
| 0x400F22 | 1 | adapter_type | Adapter bitmask (0x04/0x08/0x20/0x40) |
| 0x404E96 | 1 | model_flag | LS-50 vs LS-5000 selector |
| 0x4052D6 | 1 | scan_mode | ITU3 ISR dispatch mode byte |
| 0x4052EA | 1 | motor_enable | Motor enabled flag |
| 0x4052EE | 1 | buffer_status | Buffer ready flag (3=full) |
| 0x4052F1 | 1 | scan_active | Scan active flag |
| 0x405342 | varies | chan_desc | Per-channel pixel descriptors |
| 0x406374 | 2 | dma_burst_cnt | DMA burst counter |
| 0x407DC7 | 1 | usb_session | USB session state (2=ready) |

## Cross-References

- [ASIC Registers](../components/firmware/asic-registers.md) — 172 ASIC register details
- [Vector Table](../components/firmware/vector-table.md) — Interrupt vectors at 0x000-0x0FF
- [Startup](../components/firmware/startup.md) — BSC configuration and I/O init
- [Main Loop](../components/firmware/main-loop.md) — Context A/B stack layout
- [Data Tables](../components/firmware/data-tables.md) — Flash data table addresses
- [ISP1581 USB](../components/firmware/isp1581-usb.md) — USB register map
- [Scan Pipeline](../components/firmware/scan-pipeline.md) — ASIC RAM and buffer RAM usage
