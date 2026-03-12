# Scan Data Pipeline — Nikon LS-50

**Status**: Complete
**Last Updated**: 2026-03-05
**Phase**: 4 (Firmware)
**Confidence**: Verified (pipeline stages confirmed from register/RAM references, vector sources corrected via SLEIGH pspec)

## Overview

The LS-50 scan data pipeline moves pixel data from the CCD sensor through multiple stages to the USB host. The pipeline uses a combination of ASIC-internal DMA, timer-coordinated CPU DMA, and USB bulk transfers, coordinated through a set of RAM-resident state variables.

**Key design insight**: The firmware performs **minimal pixel processing** — only bit extraction from 16-bit CCD words. All calibration correction (dark subtraction, white normalization, gamma, color balance) is performed **host-side** by NikonScan software (DRAG/ICE DLLs).

## Complete Pipeline Diagram

```
CCD Sensor (tri-linear R/G/B + IR)
    |  (analog signal → ASIC ADC → 16-bit digital)
    v
ASIC Analog Front-End (0x200000)
    |  [DAC config: 0x2000C0-C7]
    |  [Integration timing: 0x200408-425]
    |  [Per-channel windows: 0x20046D-487]
    |  [Analog gain: 0x200457-458]
    v
ASIC Internal DMA
    |  [Config: 0x200142-14D]
    |  [Buffer addr: 0x200147/148/149 → 0x800000]
    |  [Transfer count: 0x20014B/14C/14D]
    |  [Trigger: write 0x80 to 0x2001C1]
    |  [Poll: read 0x200002 bit 3 until clear]
    |  [Ack: write 0xC0 to 0x200001]
    v
ASIC RAM (0x800000, 224KB) — CCD Line Buffer
    |  [ITU3 timer ISR (Vec 36, 0x2D536) manages DMA bursts]
    |  [Burst counter: 0x406374 counts down to 0]
    |  [Mode dispatch: 0x4052D6]
    |  [Mode 1 → scan line callback 0x2CEB2]
    |  [Sets scan_status (0x4052EE) = 3 when ready]
    v
Pixel Processing (0x36C90-0x37A8C)
    |  [Read 16-bit pixels from 0x800000+]
    |  [shlr.w for bit-depth extraction]
    |  [Process in 4KB-16KB blocks]
    |  [4 color channels: R/G/B/IR]
    |  [Dual banks: 0x800000 and 0x418000]
    |  [Yield: jsr 0x0109E2 between blocks]
    v
Buffer RAM (0xC00000, 64KB) — USB Staging
    |  [ITU4 system tick (Vec 40, 0x10A16) polls xfer state]
    |  [Checks: 0x400773 == 4 (scan data ready)]
    |  [Checks: 0x4052EE == 3 (buffer full)]
    |  [Transfer mode dispatch: 0x10B3E]
    v
Response Manager (0x1374A)
    |  [Checks USB endpoint busy: 0x40049A]
    |  [ISP1581 DMA setup: 0x13C70]
    |  [Start bulk transfer: 0x13F3A]
    |  [Special fast-path for 0xD0 phase query]
    v
ISP1581 USB Controller (0x600000)
    |  [DMA_REG (0x600018): 0x8000 = host-read]
    |  [DMA config (0x60002C): mode 5 = bulk]
    |  [DMA_CNT (0x60001C): enable transfer]
    |  [DATA_PORT (0x600020): data words]
    v
USB Bulk-In Pipe → Host PC
    (NikonScan reads via NKDUSCAN.dll)
```

## Stage 1: CCD Capture → ASIC RAM

### ASIC DMA Configuration

The ASIC DMA engine transfers digitized CCD data into ASIC RAM. Configuration is done through three register groups:

**Buffer Address** (24-bit, at `0x200147`-`0x200149`):
```
0x200147 = address[23:16]  (e.g., 0x80 for 0x800000)
0x200148 = address[15:8]   (e.g., 0x00)
0x200149 = address[7:0]    (e.g., 0x00)
```

**Transfer Count** (24-bit, at `0x20014B`-`0x20014D`):
```
0x20014B = count[23:16]
0x20014C = count[15:8]     (init: 0x40 = 16384 bytes per block)
0x20014D = count[7:0]
```

**DMA Control**:
- Trigger: Write `0x80` to `0x2001C1`
- Status: Poll `0x200002` bit 3 (1 = busy)
- Acknowledge: Write `0xC0` to `0x200001`

Configuration functions:
- `FW:0x035C7E` — Configure DMA buffer address and transfer config
- `FW:0x035D58` — Read current DMA position, reconfigure
- `FW:0x035D92` — Set transfer count and trigger DMA

## Stage 2: ITU3 Timer — Line Burst Counting

**ITU3 compare match ISR at `FW:0x02D536`** (Vector 36 = IMIA3) manages CCD line DMA completion. This is a timer interrupt that coordinates DMA transfers, not a DMA completion interrupt itself. Actual DMA completion interrupts are DEND0B (Vec 45 → 0x02CEF2) and DEND1B (Vec 47 → 0x02E10A).

```asm
; Entry: clear DMA interrupt flag
bclr    #0, @DTCR           ; Clear DMA Ch0 interrupt
mov.l   #0x406374, er0      ; Load burst counter address
mov.b   @er0, r9l           ; Read counter
dec     r9l                  ; Decrement
mov.b   r9l, @er0           ; Store
bne     return               ; If not zero, return (more bursts)

; Counter == 0: full CCD line transfer complete
mov.b   @0x4052D6, r8l      ; Read DMA mode
; Dispatch:
;   Mode 1 → call 0x2CEB2 (scan line callback)
;   Mode 2 → set state 3, trigger next DMA
;   Mode 6 → call 0x2D4B2 (cleanup)
```

**Two-level dispatch**: First a countdown counter (counts DMA bursts per scan line), then a mode byte selects the handler. The counter at `0x406374` is initialized per-line based on the configured transfer size and burst granularity.

### Scan Line Callback (0x2CEB2)

Called when a complete CCD line has been DMA'd into ASIC RAM:
1. Reads scan descriptor from `0x406370`
2. Updates operation type at `0x400791`
3. Clears/resets DMA status
4. Re-triggers ASIC DMA for next line (`bset #0, @er6`)
5. Sets `0x4052EE = 3` when buffer is full

## Stage 3: Pixel Processing (0x36C90)

The pixel processing code reads from ASIC RAM and writes to Buffer RAM. Processing is minimal:

1. **Bit extraction**: `shlr.w` (shift right word) extracts significant bits from 16-bit CCD data. The CCD produces 14-bit data packed in 16-bit words.

2. **Block processing**: Data is processed in fixed-size blocks:
   - 4KB, 8KB, 12KB, ~16KB (16321 bytes), 16KB
   - `jsr 0x0109E2` (yield) between blocks allows ITU4 system tick to service USB transfers

3. **Multi-channel**: Handles 4 color channels (R/G/B/IR) with per-channel buffer geometry:
   - Channel descriptors at `0x405342`-`0x40535A`
   - Values: 757 (0x02F5) and 665 (0x0299) — pixel counts/offsets for CCD line geometry

4. **Dual ASIC RAM banks**: Code references both `0x800000` (primary) and `0x418000` (secondary), likely for color channel separation within ASIC RAM.

**No firmware-side image processing**: No LUT lookups, no multiplication/division for gain, no dark frame subtraction, no gamma correction. The firmware sends raw CCD data. All image processing is performed by NikonScan host software.

## Stage 4: ITU4 System Tick — Periodic USB Transfer Polling

**ITU4 system tick ISR at `FW:0x010A16`** (Vector 40 = IMIA4) is a periodic timer interrupt. Started once at init, it continuously polls for scan data ready to transfer via USB:

```asm
; Entry: clear interrupt, update timestamp at 0x40076E
; Transfer mode dispatch:
mov.b   @0x4062E6, r0l       ; Read transfer state
bne     active_transfer       ; If active: continue transfer
; Check for new data:
mov.b   @0x400773, r0l       ; Read command state
cmp.b   #0x04, r0l           ; State 4 = scan data ready?
bne     check_cal
cmp.b   #0x05, r0l           ; State 5 = calibration data?
; ...
mov.b   @0x4052EE, r0l       ; Check scan status
cmp.b   #0x03, r0l           ; Status 3 = buffer full?
beq     push_to_usb
; ...
push_to_usb:
jsr     @0x10B3E             ; Transfer data subroutine
```

This is a **pull model** — the timer ISR periodically checks if scan data is ready and initiates USB transfer.

### Transfer Mode Dispatch (0x10B3E)

| Mode | Handler | Purpose |
|------|---------|---------|
| 2 | `0x02E268` | Block transfer |
| 3 | `0x02EDC0` | Streaming transfer |
| 4 | `0x3337E` | Scan line transfer (pixel processing) |
| 6 | `0x02E276` | Calibration transfer |

## Stage 5: USB Bulk Transfer

### Response Manager (0x1374A)

Manages USB bulk-in transfers:

1. Check endpoint busy flag at `0x40049A`
2. If free, store response type at `0x407DC6`
3. Call `0x13C70` for ISP1581 DMA setup
4. Call `0x13F3A` to start bulk transfer
5. Increment transfer counter at `0x40049D`

Special fast-path: If opcode is `0xD0` (phase query), returns immediately without data transfer.

### ISP1581 DMA Setup (0x13C70)

```asm
mov.l   #0x600018, er6       ; ISP1581 DMA register
; Check endpoint status, clear state
; Configure DMA direction and mode
bsr     0x13D68               ; Setup transfer parameters
```

### ISP1581 Bulk Transfer Start (0x13F3A)

```asm
mov.w   #0x8000, r0           ; DMA direction = host-read
mov.w   r0, @0x600018         ; Write to ISP1581 DMA_REG
mov.w   #0x0005, r0           ; DMA mode = bulk endpoint
mov.w   r0, @0x60002C         ; Write to ISP1581 DMA config
mov.w   #0x0001, r0           ; Enable
mov.w   r0, @0x60001C         ; Write to ISP1581 DMA_CNT
; Write first data word to DATA_PORT (0x600020)
```

### ISP1581 Register Usage

| Register | Address | Purpose |
|----------|---------|---------|
| DATA_PORT | `0x600020` | Bulk data read/write (5 code refs) |
| DMA_REG | `0x600018` | DMA control/direction (4 code refs) |
| DMA_CNT | `0x60001C` | DMA transfer count (2 code refs) |
| DMA_CONFIG | `0x60002C` | DMA mode configuration |
| INT_CONFIG | `0x60000C` | Interrupt config (2 code refs) |
| EP_CONFIG | `0x600008` | Endpoint setup (1 ref) |
| CHIP_ID | `0x600084` | Initialization check (1 ref) |

## Pipeline State Variables

| Address | Variable | Values | Role |
|---------|----------|--------|------|
| `0x406374` | `dma_burst_counter` | N→0 | ITU3 ISR counts down per DMA burst |
| `0x4052D6` | `dma_mode` | 1/2/3/4/6 | ITU3 ISR state machine |
| `0x4052EE` | `scan_status` | 0-7 | 3 = buffer full, ready for USB |
| `0x4052F1` | `scan_active` | 0/1 | Scan in progress flag |
| `0x405302` | `scan_complete` | 0/1 | All lines scanned |
| `0x400773` | `cmd_state` | 4/5 | 4=scan-data, 5=cal-data |
| `0x4062E6` | `xfer_state` | 0/1+ | USB transfer in progress |
| `0x40049A` | `usb_busy` | 0/1 | USB endpoint busy flag |
| `0x40076E` | `timestamp` | 32-bit | ITU4 system tick timestamp counter |
| `0x406370` | `scan_desc_ptr` | 32-bit | Scan descriptor pointer |
| `0x400791` | `gpio_shadow` | byte | Current operation type |
| `0x4064E6` | `line_counter` | word | Remaining scan lines |

## SCAN Handler (0x2EC00)

The SCAN handler is a ~2KB state machine managing the entire scan operation:

### Operation Flow

1. **Setup** (0x2EC00-0x2EC90): Read operation type from `0x40530A`, configure DMA descriptors
2. **Motor control** (0x2EC90-0x2ED30): Position stepper, set scan direction, configure CCD timing
3. **DMA setup** (0x2ED2E):
   ```
   BSET #2, @0xFF7A   ; Timer/port setup
   BSET #2, @0xFF7B   ; Timer/port setup
   BSET #2, @0xFF60   ; Timer start
   BSET #2, @0xFF47   ; Additional timer
   ```
4. **Scan loop** (0x2EE00-0x2F200): Process each line via DMA interrupts
5. **Completion** (0x2F200-0x2F400): Clean up DMA, signal complete

### Per-Channel Descriptors

Four color channels configured at `0x405342`-`0x40535A`:

| Channel | Start/End Offset | Size | Color |
|---------|-----------------|------|-------|
| 0 | `0x02F5` / `0x02F5` | `0x0299` (665) | Red |
| 1 | `0x02F5` / `0x02F5` | `0x0299` (665) | Green |
| 2 | `0x02F5` / `0x02F5` | `0x0299` (665) | Blue |
| 3 | `0x02F5` / `0x02F5` | `0x0299` (665) | IR (Digital ICE) |

Values 757 and 665 represent pixel counts within the CCD line geometry (active area minus margins).

### Timing Computation

The handler computes microsecond-per-pixel timing:
- `jsr @0x0163EA` with parameter `0x000F4240` (1,000,000)
- `jsr @0x015CCC` with parameter `0x00000280` (640)
- Result: pixel clock period in microseconds

## Cross-References

- [ASIC Registers](asic-registers.md) — DMA and CCD register details
- [Motor Control](motor-control.md) — Motor positioning during scan
- [Calibration](calibration.md) — Calibration scan pipeline variant
- [ISP1581 USB](isp1581-usb.md) — USB controller interface
- [SCSI SCAN Command](../../scsi-commands/scan.md) — Host-side SCAN command
- [SCSI READ Command](../../scsi-commands/read.md) — Host reads scan data
- [Memory Map](../../reference/memory-map.md) — ASIC RAM, Buffer RAM addresses
