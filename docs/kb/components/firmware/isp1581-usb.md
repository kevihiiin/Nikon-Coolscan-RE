# Firmware ISP1581 USB Controller Interface

**Status**: Complete
**Last Updated**: 2026-02-28
**Phase**: 4 (Firmware)
**Confidence**: High (register accesses decoded from disassembly, cross-referenced with ISP1581 datasheet)

## Overview

The LS-50 scanner uses a Philips ISP1581 USB 2.0 High-Speed device controller, memory-mapped at base address 0x600000. The firmware's USB interface code is concentrated in the shared handler module at flash addresses 0x12200-0x15200, with some routines extending to 0x16000.

## ISP1581 Memory Map

The ISP1581 registers are mapped starting at 0x600000 on the H8/3003 address bus:

| ISP1581 Offset | H8 Address | Register Name | Access Pattern |
|---------------|------------|--------------|----------------|
| 0x08 | 0x600008 | Interrupt Status | Read + bit-modify |
| 0x0C | 0x60000C | Mode | Set/clear bit 4 (SOFTCT) |
| 0x18 | 0x600018 | DMA Configuration | Write |
| 0x1C | 0x60001C | Endpoint Index | Write (selects endpoint) |
| 0x20 | 0x600020 | Endpoint Data | Read/Write (bulk transfer) |
| 0x2C | 0x60002C | Endpoint Control | Write |
| 0x84 | 0x600084 | DMA Transfer Count | Write |

## USB Initialization

### Soft Connect/Disconnect

The ISP1581 Mode register at 0x60000C controls the USB soft-connect via bit 4 (SOFTCT):

```asm
; USB Disconnect:
0x0139C0: mov.l  #0x60000C, er6     ; Mode register
0x0139C8: bset   #0x4, r0l          ; Set SOFTCT bit
0x0139CA: mov.w  r0, @er6           ; Write → device disconnected from bus

; USB Reconnect:
0x0139D0: mov.w  @er6, r0
0x0139D2: bclr   #0x4, r0l          ; Clear SOFTCT bit
0x0139D4: mov.w  r0, @er6           ; Write → device visible on bus
```

### USB Reset Handler (0x013A20)

On USB bus reset:
1. Clears ASIC bit at 0x200001 (value 0x02) — resets ASIC-side USB interface
2. Initializes timer at 0x4007D6 for USB timeout monitoring
3. Clears all USB state variables (0x407Dxx block)
4. Installs ISP1581 endpoint callback table from flash to RAM at 0x400DC8
5. Calls ISP1581 endpoint configuration (0x015280)
6. Writes 0x20 to ASIC register 0x2000C2 — re-enables ASIC USB path

## Endpoint Data Transfer Functions

### Read from Endpoint (0x012258)

Reads bulk data from the ISP1581 endpoint data register into a RAM buffer:

```c
// Pseudocode: usb_endpoint_read(uint8_t *dest, uint16_t byte_count)
void usb_endpoint_read(er0=dest, r1=count) {
    uint16_t words = count >> 1;    // e1 = count / 2
    if (count & 1) {                // Odd byte count
        while (words--) {
            uint16_t w = *(uint16_t*)0x600020;  // Read 16-bit from endpoint
            *dest++ = w & 0xFF;                  // Low byte first (little-endian USB data)
            *dest++ = w >> 8;                    // High byte
        }
        uint16_t w = *(uint16_t*)0x600020;      // Read final word
        *dest++ = w & 0xFF;                      // Only low byte used
    } else {
        while (words--) {
            uint16_t w = *(uint16_t*)0x600020;
            *dest++ = w & 0xFF;
            *dest++ = w >> 8;
        }
    }
}
```

**Note**: The ISP1581 data register is 16-bit, but USB data is byte-oriented. The firmware handles byte-swapping (ISP1581 is little-endian, H8/3003 is big-endian).

### Write to Endpoint (0x0122C4)

Writes data from RAM to the ISP1581 endpoint data register:

```c
// Pseudocode: usb_endpoint_write(uint8_t *src, uint16_t byte_count)
void usb_endpoint_write(er0=src, r1=count) {
    *(uint16_t*)0x60001C = count;   // Write byte count to endpoint index register
    uint16_t words = count >> 1;
    if (count & 1) {
        while (words--) {
            uint16_t w = *src++ | (*src++ << 8);  // Pack bytes to word
            *(uint16_t*)0x600020 = w;              // Write to endpoint data
        }
        uint16_t w = *src++;                       // Final odd byte
        *(uint16_t*)0x600020 = w;
    } else {
        while (words--) {
            uint16_t w = *src++ | (*src++ << 8);
            *(uint16_t*)0x600020 = w;
        }
    }
}
```

### Write to Endpoint (0x012304) — Variant

Similar to 0x0122C4 but skips the initial byte count write to 0x60001C. Used when the endpoint index/count was already set by the caller.

## RAM-Resident USB Code

A portion of USB handler code is copied from flash to RAM at runtime:

```asm
; At 0x012486 (called during USB init):
0x012492: mov.l  #0x124BA, er0       ; Source: flash code
0x012498: mov.l  #0x4010A0, er1      ; Destination: external RAM
0x01249E: mov.w  @er0+, r2           ; Copy word by word
0x0124A0: mov.w  r2, @er1
0x0124A2: inc.l  #2, er1
0x0124A4: cmp.l  #0x12658, er0       ; Until end of code block
0x0124AA: bcs    0x01249E
```

This copies 414 bytes (0x12658 - 0x124BA = 0x19E) of USB handler code from flash 0x124BA to RAM at 0x4010A0. Jump tables at 0x01247E and 0x012482 redirect to this RAM code:

```asm
0x01247E: jmp    @0x4010A0           ; Jump to RAM-resident handler
0x012482: jmp    @0x4011A2           ; Jump to RAM-resident handler (alternate entry)
```

**Why RAM-resident code?** During high-speed USB DMA transfers, code execution from flash may conflict with DMA bus accesses. Running critical USB handler code from RAM avoids bus contention.

## USB State Machine

### State Variables (0x407Dxx Block)

| Address | Purpose |
|---------|---------|
| 0x407D2E | USB configuration state (0=unconfigured) |
| 0x407D30 | USB transfer in progress |
| 0x407D32 | USB endpoint state |
| 0x407DC6 | Current command phase |
| 0x407DC7 | USB session state |
| 0x407DC8 | USB retry counter |
| 0x407DD8 | Endpoint stall flags |
| 0x407DD9 | Interrupt mask/priority |
| 0x407DDB | DMA state |
| 0x407DDC | DMA direction |
| 0x407DDD | DMA completion flag |
| 0x407DDE | USB bus reset flag |
| 0x407DE0 | USB connected flag |

### CDB Reception Path

1. ISP1581 interrupt fires when bulk-out data arrives
2. IRQ1 handler (trampoline at 0xFFFD3C) processes the interrupt
3. CDB bytes read from endpoint data register (0x600020) into buffer at 0x4007DE
4. SCSI opcode (byte 0) extracted and stored at 0x4007B6
5. USB state machine signals "command received" to main loop
6. Main dispatch function (0x20B48) looks up opcode in handler table

### Response Sending

The function at 0x1374A manages USB response state:

```asm
; Function 0x1374A - USB response manager
0x01374A: mov.b  r0l, r0h            ; Save command phase
0x01374C: mov.b  @0x40049A, r0l      ; Check if USB transaction active
0x013752: bne    return               ; If already active, abort
0x013754: mov.b  r0h, @0x407DC6      ; Store command phase
0x01375A: jsr    @0x13C70            ; Setup USB DMA for response
; Wait for DMA completion...
0x01376A: jsr    @0x109E2            ; Enable interrupts, wait
0x013770: ; DMA complete
0x01377A: mov.b  #0x1, @0x40049A     ; Mark transaction active
```

### DMA Configuration

USB DMA transfers use ISP1581 DMA registers:

```asm
; DMA setup at 0x013C74:
0x013C42: mov.w  r0, @0x60000C       ; Mode register (configure DMA mode)
0x013C48: mov.b  @0xFFFFF6, r0l      ; Read H8/3003 port register
0x013C4A: and.b  #0xED, r0l          ; Clear bus control bits
0x013C4C: mov.b  r0l, @0xFFFFF6      ; Update port for DMA access
```

## ISP1581 Code Location Summary

| Address Range | Size | Function |
|--------------|------|----------|
| 0x12200-0x12330 | ~300B | Endpoint data read/write primitives |
| 0x12330-0x12400 | ~200B | USB buffer management |
| 0x12400-0x12660 | ~600B | RAM-resident code installer + ROM table |
| 0x12660-0x12800 | ~400B | USB initialization (variables, endpoint setup) |
| 0x13740-0x13800 | ~190B | USB response state machine |
| 0x13920-0x139B8 | ~150B | Timer/timeout setup |
| 0x139B8-0x13A20 | ~100B | USB soft-connect, ISP1581 mode control |
| 0x13A20-0x13AE0 | ~190B | USB bus reset handler |
| 0x13C40-0x13D40 | ~260B | DMA configuration and ISP1581 mode setup |
| 0x13F40-0x14080 | ~320B | DMA transfer management |
| 0x14880-0x14960 | ~224B | ISP1581 interrupt handling |
| 0x14E00-0x15010 | ~530B | Endpoint configuration |
| 0x15100-0x15220 | ~290B | DMA transfer count and completion |

**Total ISP1581 code**: ~3,750 bytes across the shared handler module (0x10000-0x17FFF).

## Interrupt Configuration

The ISP1581 interrupt is connected to the H8/3003 IRQ1 pin (vector 13). The interrupt handler:

1. Reads ISP1581 interrupt status register (0x600008)
2. Checks for endpoint events (bit 3), bus reset, etc.
3. Clears the interrupt by writing back modified status
4. For endpoint events: reads CDB data and signals main loop
5. For bus reset: reinitializes USB state machine

**Note**: The IRQ1 trampoline at 0xFFFD3C is installed by USB initialization code (separate from the main trampoline sequence at 0x204C4-0x205E2). The IRQ1 vector (Vec 13) at the hardware vector table points to the trampoline, which jumps to the ISP1581 ISR. See [Vector Table](vector-table.md) for the complete interrupt map.

## USB Device Descriptors in Flash

The ISP1581 initialization code programs USB descriptors from templates stored in flash:

| Flash Address | Content |
|---------------|---------|
| `0x170D6` | SCSI INQUIRY string: `"Nikon   LS-50 ED        1.02"` + serial `"DF17811"` |
| `0x16674` | LS-5000 variant: `"Nikon   LS-5000-123456  123456"` (template with placeholder serial) |
| `0x170FA` | USB 1.1 Device Descriptor (18 bytes): bcdUSB=0x0110, class=0xFF, VID=0x04B0, PID=0x4001 |
| `0x1710C` | USB 2.0 Device Descriptor (18 bytes): bcdUSB=0x0200, same VID/PID |
| `0x1711E` | USB 1.1 Endpoint templates: EP1 OUT Bulk 64B, EP2 IN Bulk 64B |
| `0x1712E` | USB 2.0 Endpoint templates: EP1 OUT Bulk 512B, EP2 IN Bulk 512B |
| `0x1713E` | USB 1.1 Config Descriptor: 1 interface, self-powered (0xC0), 2 endpoints |
| `0x17148` | USB 2.0 Config Descriptor: same layout, 512B packet size |

The device class is `0xFF/0xFF/0xFF` (vendor-specific) at both device and interface levels. The interface has 2 bulk endpoints.

## Related KB Docs

- [SCSI Handler](./scsi-handler.md) — SCSI dispatch mechanism
- [Vector Table](./vector-table.md) — Interrupt vector mapping
- [USB Protocol](../../architecture/usb-protocol.md) — Host-side USB protocol (includes full descriptor details)
- [NKDUSCAN](../nkduscan/) — Host USB driver analysis
