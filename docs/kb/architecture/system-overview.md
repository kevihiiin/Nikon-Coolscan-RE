# System Overview -- Nikon Coolscan Film Scanners
**Status**: Draft
**Last Updated**: 2026-02-20  |  **Phase**: 0  |  **Confidence**: High

## Summary

The Nikon Coolscan family are dedicated 35mm/120 film scanners communicating via USB 2.0 (or IEEE 1394 on older models). Internally, SCSI commands are wrapped in USB bulk transfers. The scanner firmware runs on a Hitachi H8/3003 microcontroller.

## Hardware Architecture

### Scanner (Coolscan V / LS-50)

| Component | Details |
|-----------|---------|
| CPU | Hitachi H8/3003 (H8/300H family), 20MHz |
| Address Space | 24-bit, big-endian |
| Flash | Fujitsu MBM29F400BC, 512KB NOR, TSOP48 |
| Main RAM | 128KB SRAM at 0x400000 |
| ASIC DSL RAM | 256KB at 0x800000 |
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
| 0x800000-0x83FFFF | 256KB | ASIC DSL RAM |
| 0xC00000-0xC0FFFF | 64KB | Buffer RAM |
| 0xFFFD00-0xFFFF3F | ~576B | H8/3003 on-chip I/O registers |
| 0xFFFF40-0xFFFFF3 | ~180B | On-chip RAM (used for vector trampolines) |

### GPIO Usage

| Port | Bits | Function |
|------|------|----------|
| Port B | 4-7 | Film transport motor control |
| Port C | 3-5 | Adapter ID (which film adapter is inserted) |
| Port C | 6 | Door sensor |
| Port C | 7 | Adapter presence detect |

### Firmware Flash Layout

| Offset | Size | Purpose |
|--------|------|---------|
| 0x00000 | 0x4000 | Vector table + startup code |
| 0x04000 | 0x2000 | Bootloader flags |
| 0x06000 | 0x2000 | Settings (persistent) |
| 0x08000 | 0x8000 | Extended settings |
| 0x10000 | 0x10000 | Recovery firmware |
| 0x20000 | 0x40000 | Main firmware (256KB) |
| 0x60000 | 0x20000 | Logging area |

### Interrupt Vectors (Active)

15 active vectors found (out of 64 total). Most point to trampolines in on-chip RAM (0xFFFDxx).

| Vector | Address | Name | Target |
|--------|---------|------|--------|
| 0 | 0x000 | Reset | 0x000100 (startup code) |
| 7 | 0x01C | NMI | 0x000182 |
| 8 | 0x020 | TRAP #0 | 0xFFFD10 |
| 13 | 0x034 | IRQ1 | 0xFFFD3C (likely ISP1581 USB interrupt) |
| 15 | 0x03C | IRQ3 | 0xFFFD14 |
| 16 | 0x040 | IRQ4 | 0xFFFD18 |
| 17 | 0x044 | IRQ5 | 0xFFFD18 (shared with IRQ4) |
| 32 | 0x080 | ITU ch2 compare A | 0xFFFD1C (timer - likely motor control) |
| 36 | 0x090 | ITU ch3 compare A | 0xFFFD20 (timer) |
| 40 | 0x0A0 | ITU ch4 compare A | 0xFFFD24 (timer) |
| 45 | 0x0B4 | DMAC ch0B end | 0xFFFD28 (DMA complete) |
| 47 | 0x0BC | DMAC ch1B end | 0xFFFD2C (DMA complete) |
| 49 | 0x0C4 | Reserved | 0xFFFD30 |
| 60 | 0x0F0 | ADI (A/D end) | 0xFFFD34 |

**Evidence**: `parse_vector_table.py` output, Ghidra `VerifyFirmware.java` script confirmed disassembly at 0x100.

## Communication Protocol (High Level)

```
Host PC <-- USB 2.0 --> ISP1581 <-- CPU bus --> H8/3003 firmware
                                                    |
                                                 SCSI command processing
                                                    |
                                        Motor / CCD / Lamp control
```

1. Host sends SCSI CDB via USB bulk-out pipe
2. Host queries device phase via vendor command 0xD0
3. Based on phase: transfer data (bulk read/write) or complete command
4. Host retrieves sense data via 0x06 (REQUEST SENSE) on error

This is a custom USB-SCSI wrapping protocol, NOT standard USB Mass Storage.

## Scanner Models

| Model | Name | Resolution | Film Format | Interface |
|-------|------|-----------|-------------|-----------|
| LS-50 | Coolscan V ED | 4000 DPI | 35mm | USB 2.0 |
| LS-5000 | Super Coolscan 5000 ED | 4000 DPI | 35mm | USB 2.0 |
| LS-4000 | Coolscan 4000 ED | 2900 DPI | 35mm | IEEE 1394 + USB |
| LS-8000 | Super Coolscan 8000 ED | 4000 DPI | 35mm + 120/220 | IEEE 1394 + USB |
| LS-9000 | Super Coolscan 9000 ED | 4000 DPI | 35mm + 120/220 | IEEE 1394 + USB |

## Open Questions

- [ ] What is the exact startup sequence? (Phase 4)
- [ ] How does the ISP1581 USB interrupt (likely IRQ1) trigger SCSI command processing?
- [ ] What are the timer interrupts (ITU ch2-4) used for? Motor step timing?
- [ ] What do the DMA channels handle? Bulk USB data transfer?

## Cross-References

- [Software Layers](software-layers.md)
- [USB Protocol](usb-protocol.md) (Phase 1)
- [Firmware Memory Map](../reference/memory-map.md)
