# System Overview -- Nikon Coolscan Film Scanners
**Status**: Complete
**Last Updated**: 2026-02-28  |  **Phase**: 0 + 4  |  **Confidence**: Verified

## Summary

The Nikon Coolscan family are dedicated 35mm/120 film scanners communicating via USB 2.0 (or IEEE 1394 on older models). Internally, SCSI commands are wrapped in USB bulk transfers. The scanner firmware runs on a Hitachi H8/3003 microcontroller.

## Hardware Architecture

### Scanner (Coolscan V / LS-50)

| Component | Details |
|-----------|---------|
| CPU | Hitachi H8/3003 (H8/300H family), clock speed unverified |
| Address Space | 24-bit, big-endian |
| Flash | Fujitsu MBM29F400BC, 512KB NOR, TSOP48 |
| Main RAM | 128KB SRAM at 0x400000 |
| ASIC DSL RAM | 224KB at 0x800000 (range table at FW:0x4A114 ends at 0x837FFF) |
| Buffer RAM | 64KB at 0xC00000 |
| USB Controller | Philips ISP1581, registers at 0x600000 |
| USB | VID 0x04B0 (Nikon), PID 0x4001 |
| SCSI ID | "Nikon   LS-50 ED        1.02" |

### Memory Map

| Address Range | Size | Purpose |
|---------------|------|---------|
| 0x000000-0x07FFFF | 512KB | NOR Flash (firmware) |
| 0x400000-0x41FFFF | 128KB | Main RAM |
| 0x600000-0x6000FF | 256B | ISP1581 USB controller registers |
| 0x800000-0x837FFF | 224KB | ASIC DSL RAM (verified from range table at FW:0x4A114) |
| 0xC00000-0xC0FFFF | 64KB | Buffer RAM |
| 0xFFFD00-0xFFFF3F | ~576B | H8/3003 on-chip I/O registers |
| 0xFFFF40-0xFFFFF3 | ~180B | On-chip RAM (used for vector trampolines) |

### GPIO Usage

Complete GPIO port reference map traced from firmware binary (all MOV.B, BSET, BCLR operations on port registers). The H8/3003 has Ports 1, 3, 5, 7, 8, 9, A, B, C.

| Port | Addr | Refs | Dir | Primary Code Region | Function | Confidence |
|------|------|------|-----|---------------------|----------|------------|
| Port A DR | 0xD3 | 44 | R/W | scan-setup (26), motor (10) | **Stepper motor phase output** (primary motor port) | High |
| Port 1 DDR | 0x80 | 32 | W | param-handling (19), SEND_DIAG (6) | Data direction configuration for Port 1 | High |
| Port 1 DR | 0x82 | 17 | R | recovery (9), motor (4), vendor (3) | Multi-purpose I/O (bus status, motor feedback) | Medium |
| Port C DDR | 0xD2 | 17 | W | diagnostics (8), motor (3) | **Single bit 0 only** — output enable/disable toggle | High |
| Port 7 DR | 0x8E | 16 | R | SCAN handler (14 of 16 refs) | **Adapter/sensor status input** — read during scan cmd | High |
| Port 9 DR | 0xC8 | 12 | R/W | motor (7), scan-setup (5) | Motor encoder input + stepper phase output | High |
| Port 3 DDR | 0x84 | 11 | W | motor-control (all 11) | Motor direction control (bit 0 set/cleared) | High |
| Port 5 DDR | 0x88 | 7 | R/W | READ/WRITE (3), TUR (2) | Peripheral/data bus direction control | Medium |
| Port 3 DR | 0x86 | 6 | R | vendor-cmds (3), recovery (1) | Status input (adapter/sensor readback) | Medium |
| Port 8 DR | 0xC9 | 3 | R | data-tables (2), param (1) | **Lamp state readback** (see lamp-control.md) | High |
| Port B DR | 0xD4 | 3 | R | scan-state-machine (2), recovery (1) | Minimal use — NOT primary motor port | High |
| Port A DDR | 0xD0 | 2 | R/W | USB-data-xfer (1), data-tables (1) | Data direction for Port A | High |
| Port 5 DR | 0x8A | 1 | W | CCD-config (1) | Single CCD config write | Medium |

**Key corrections** (vs. previous unverified assignments):
- Port A (44 refs) is the primary motor port, NOT Port B (only 3 refs)
- Port 7 (16 reads, 14 in SCAN handler) is the adapter/sensor status input, NOT Port C bits 3-7
- Port C DDR only toggles bit 0 (17 ops) — not bits 3-7 as previously speculated
- Port 3 DDR bit 0 controls motor direction (set/clear in motor-control code)
- Port 9 is the motor encoder port (reads in motor area, writes in scan-setup)

### Firmware Flash Layout

| Offset | Size | Purpose |
|--------|------|---------|
| 0x00000 | 0x0190 | Vector table + startup/bootloader code |
| 0x04000 | ~16B | Bootloader flags (2 bytes data, rest erased) |
| 0x06000 | ~80B | Settings/calibration data (structured, rest erased) |
| 0x08000 | 0x8000 | Extended settings (entirely 0xFF in our dump — erased or unused on this unit) |
| 0x10000 | ~28.5KB | Recovery firmware (smaller separate image) |
| 0x20000 | ~202KB | Main firmware (0x20000-0x528C0) |
| 0x60000 | 0x10000 | Log area — newer (structured 32-byte records, 0xAA marker) |
| 0x70000 | 0x10000 | Log area — older (same format, cycled with 0x60000) |

### Interrupt Vectors (Active)

15 active vectors found (out of 64 total). Most point to trampolines in on-chip RAM (0xFFFDxx).

| Vector | Address | H8/3003 Source | Trampoline | Purpose |
|--------|---------|----------------|------------|---------|
| 0 | 0x000 | Reset | — | 0x000100 (startup code) |
| 7 | 0x01C | NMI | — | 0x000182 (tight loop) |
| 8 | 0x020 | TRAP #0 | 0xFFFD10 | Context switch (cooperative yield) |
| 13 | 0x034 | IRQ1 | 0xFFFD3C | ISP1581 USB interrupt |
| 15 | 0x03C | IRQ3 | 0xFFFD14 | Motor encoder pulses |
| 16 | 0x040 | IRQ4 | 0xFFFD18 | External interrupt |
| 17 | 0x044 | IRQ5 | 0xFFFD18 | External interrupt (shared with IRQ4) |
| 19 | 0x04C | Reserved† | 0xFFFD38 | Motor position tracking |
| 32 | 0x080 | IMIA2 (ITU2) | 0xFFFD1C | Motor mode dispatcher |
| 36 | 0x090 | IMIA3 (ITU3) | 0xFFFD20 | Timer 3 compare match |
| 40 | 0x0A0 | IMIA4 (ITU4) | 0xFFFD24 | System tick timer |
| 45 | 0x0B4 | DEND0B | 0xFFFD28 | DMA ch0B transfer end |
| 47 | 0x0BC | DEND1B | 0xFFFD2C | DMA ch1B transfer end |
| 49 | 0x0C4 | Reserved† | 0xFFFD30 | H8/3003-specific interrupt |
| 60 | 0x0F0 | ADI | 0xFFFD34 | A/D conversion complete |

†Vec 19 and 49 are in gaps of the generic H8/300H vector table but active in this firmware. All SCI vectors (52-59) are inactive — serial I/O is polled.

**Evidence**: Binary vector table dump, SLEIGH pspec (`h8.pspec`), handler register access verification. See [Vector Table](../components/firmware/vector-table.md) for full analysis.

## Communication Protocol (High Level)

```
Host PC <-- USB 2.0 --> ISP1581 <-- CPU bus --> H8/3003 firmware
                                                    |
                                                 SCSI command processing
                                                    |
                                        Motor / CCD / Lamp control
```

1. Host sends SCSI CDB via USB bulk-out pipe
2. Host queries device phase via vendor command 0xD0 **(verified: NKDUSCAN.dll @ 0x10002b55)**
3. Based on phase (0x01=data-out, 0x02=status, 0x03=data-in): transfer data or complete command
4. Host retrieves sense data via 0x06 on error **(verified: NKDUSCAN.dll @ 0x10002b5a)**

This is a custom USB-SCSI wrapping protocol, NOT standard USB Mass Storage.
**(Verified: no USB Mass Storage CBW/CSW signatures in NKDUSCAN.dll; uses raw WriteFile/ReadFile on usbscan.sys bulk pipes)**

## Scanner Models

**Source**: USB INF (NksUSB.INF), 1394 INF (Nks1394.INF), ICM profiles, .md3 modules.

| Model | Name | Film Format | Interface | USB PID | Module (.md3) |
|-------|------|-------------|-----------|---------|---------------|
| LS-40 | Coolscan IV ED | 35mm | USB only | 0x4000 | LS4000.md3 (shared) |
| LS-50 | Coolscan V ED | 35mm | USB only | 0x4001 | LS5000.md3 (shared) |
| LS-5000 | Super Coolscan 5000 ED | 35mm | USB only | 0x4002 | LS5000.md3 (shared) |
| LS-4000 | Super Coolscan 4000 ED | 35mm | IEEE 1394 only | -- | LS4000.md3 (shared) |
| LS-8000 | Super Coolscan 8000 ED | 35mm + 120/220 | IEEE 1394 only | -- | LS8000.md3 |
| LS-9000 | Super Coolscan 9000 ED | 35mm + 120/220 | IEEE 1394 only | -- | LS9000.md3 |

**Notes**:
- No scanner supports both USB and FireWire. Each model has exactly one bus type.
- LS-40 and LS-4000 share LS4000.md3 and ICM profile "NKLS4000LS40" (same CCD/optics, different bus).
- LS-50 and LS-5000 share LS5000.md3 — there is no separate LS50.md3 file.
- All .md3 modules reference both NKDUSCAN.dll and NKDSBP2.dll (transport-agnostic at module level).
- 1394 scanners share SBP-2 command set ID `CMDSETID104D8`.

## Open Questions (ALL RESOLVED)

- [x] What is the exact startup sequence? — See [Startup & Boot](../components/firmware/startup.md): Reset → 0x100 → boot select → 0x20334 → I/O init → RAM test → trampoline install → SP relocate → coroutine system
- [x] How does the ISP1581 USB interrupt trigger SCSI command processing? — IRQ1 (Vec 13) → ISP1581 ISR → sets flag @0x400082 → Context A polls in main loop → SCSI dispatch. See [Main Loop](../components/firmware/main-loop.md), [ISP1581 USB](../components/firmware/isp1581-usb.md)
- [x] What are the timer interrupts (ITU ch2-4) used for? — Motor step timing and scan line timing. ITU ch2=scan motor stepping, ch3=focus motor, ch4=calibration timing. See [Vector Table](../components/firmware/vector-table.md), [Motor Control](../components/firmware/motor-control.md)
- [x] What do the DMA channels handle? — Ch0: ASIC→RAM (CCD pixel data), Ch1: RAM→USB (scan data to host). See [Scan Pipeline](../components/firmware/scan-pipeline.md)

## Cross-References

- [Software Layers](software-layers.md)
- [USB Protocol](usb-protocol.md) (Phase 1)
- [Firmware Memory Map](../reference/memory-map.md)
