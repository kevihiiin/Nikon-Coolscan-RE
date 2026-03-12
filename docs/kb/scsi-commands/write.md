# WRITE (0x2A)

| Field | Value |
|-------|-------|
| **Status** | Complete |
| **Last Updated** | 2026-02-28 |
| **Phase** | 2 + 4 |
| **Confidence** | Verified (cross-validated host ↔ firmware) |

## Overview

Standard SCSI WRITE(10) command, repurposed for scanner use. Instead of writing disk sectors,
this command sends data to the scanner — typically calibration data, look-up tables (LUTs),
gamma curves, or other configuration data that is too large for a CDB parameter.

The WRITE command mirrors the READ command structure, with the same Data Type Code and
Data Type Qualifier fields, but transfers data in the opposite direction (host to scanner).

## CDB Layout (10 bytes)

| Byte | Field | Value | Notes |
|------|-------|-------|-------|
| 0 | Opcode | `0x2A` | WRITE(10) |
| 1 | Reserved | `0x00` | |
| 2 | Data Type Code | varies | What kind of data to write |
| 3 | Reserved | `0x00` | |
| 4 | Reserved | `0x00` | |
| 5 | Data Type Qualifier | varies | Sub-type or channel selector |
| 6 | Transfer Length [MSB] | varies | Number of bytes to write (big-endian) |
| 7 | Transfer Length | varies | |
| 8 | Transfer Length [LSB] | varies | |
| 9 | Control | `0x00` | Standard control (no vendor flag) |

### Control Byte (Byte 9)

Unlike READ which uses `0x80`, WRITE uses `0x00` for the control byte. This asymmetry
is notable — the vendor flag may only be needed for data-in transfers.

### Data Type Code (Byte 2)

Specifies what category of data to write to the scanner. The firmware validates this against a dispatch table at flash `0x49B98` (10-byte entries, 0xFF-terminated). The WRITE command supports a subset of the READ DTCs — only those data types that accept host-to-device uploads.

| Value | Name | Max Size | Qualifier | Confidence |
|-------|------|----------|-----------|------------|
| `0x03` | Gamma Function / LUT | 32768 | Per CDB[5] (LUT select) | Verified |
| `0x84` | Calibration Data Upload | 6 | Single value | Verified |
| `0x85` | Extended Calibration | varies | Single value | High |
| `0x88` | Boundary / Per-Channel Cal | 644 | 0-3 (R/G/B/all) | Verified |
| `0x8F` | Histogram / Profile | 324 | 0/1/3 (R/G/B) | High |
| `0x92` | Motor / Positioning Control | 4 | 0-3 (sub-type) | High |
| `0xE0` | Extended Configuration | 1024 | 0/1/3 (modes) | High |

The firmware handler (at `0x025622`) dispatches each DTC to a dedicated sub-routine. Any value not in this table returns sense code 0x0050 (ILLEGAL REQUEST / Invalid Field in CDB).

**Key differences from READ:**
- WRITE supports only 7 DTCs vs READ's 15. Image data (0x00) is never written — image flow is device-to-host only.
- DTC `0x85` (Extended Calibration) is **WRITE-only** — it has no READ counterpart. This suggests the scanner accepts calibration uploads that it does not expose for readback.
- DTCs `0x81`, `0x87`, `0x8A`, `0x8C`, `0x8D`, `0x8E`, `0x90`, `0x93` are **READ-only** (status/measurement readback that cannot be overwritten by the host).

### Data Type Qualifier (Byte 5)

Same qualifier system as READ. The allowed qualifier values depend on the DTC's category byte (second byte in the firmware table entry):

| Category | Allowed Qualifiers | Meaning |
|----------|-------------------|---------|
| `0x00` | (ignored) | No qualifier needed |
| `0x01` | Must match table | Single mode |
| `0x03` | 0, 1, 2, or 3 | Channel select: 0=composite/all, 1=R, 2=G, 3=B |
| `0x30` | 0, 1, or 3 | Three-mode select (R/G/B channels, skipping 2) |

For gamma/LUT (DTC=0x03): qualifier identifies which LUT table to write.
For per-channel data (DTC=0x88): qualifier selects the color channel.
For motor control (DTC=0x92): qualifier selects the motor sub-type.

## Data Phase

**Direction:** Data-Out (host -> scanner)

The data format depends on the Data Type Code:

### Gamma / LUT Data (DTC=0x03)

Look-up table data for hardware tone mapping. The Coolscan supports hardware LUT application where tone curves are applied by the scanner's ASIC before pixel data is transferred to the host. This is more efficient than software-based tone mapping for large scans. Max payload: 32768 bytes (32KB). The qualifier selects which LUT slot to write.

The SANE coolscan3 backend confirms this usage: `cs3_send_lut()` builds CDB `2a 00 03 00 ...` to upload gamma curves.

### Calibration Data (DTC=0x84, 0x85)

Upload calibration values to override or supplement the scanner's internal calibration:
- **DTC 0x84** — Standard calibration upload (6 bytes max). The host reads calibration with READ DTC=0x84, processes/modifies in software, then writes modified values back.
- **DTC 0x85** — Extended calibration (**WRITE-only**, no READ counterpart). This may include per-pixel gain/offset correction data that the scanner applies internally.

### Boundary / Per-Channel Calibration (DTC=0x88)

Per-channel boundary and calibration data (up to 644 bytes). The qualifier selects channel: 0=all, 1=R, 2=G, 3=B. The SANE coolscan3 backend confirms: `cs3_set_boundary()` builds CDB `2a 00 88 00 00 03 ...` (qualifier=3) to upload boundary data.

### Histogram / Profile (DTC=0x8F)

Upload histogram or profile data (324 bytes max). Qualifier selects R/G/B channel (0, 1, or 3).

### Motor / Positioning Control (DTC=0x92)

Write motor control parameters (4 bytes). Qualifier selects the sub-type. Sub-handler at `FW:0x25908`:

1. Validates transfer size == 4 bytes (sense 0x0050 if mismatch)
2. Validates qualifier against allowed range (sense 0x0050 if invalid)
3. Checks exec_mode at `0x40049B` via `FW:0x1374A`
4. Reads 4 payload bytes from USB data transfer via `FW:0x13E20`
5. Validates byte[0] (motor ID) and byte[2] (direction/mode): sense 0x0053 if invalid
6. Unpacks payload:
   - Byte 0: Motor selector (0x01=scan motor, 0x02=focus motor)
   - Byte 1: Operation mode (step count multiplier)
   - Byte 2: Direction/flags (bit 0=direction, bits 4-7=speed profile)
   - Byte 3: Step count parameter
7. Writes motor command to `0x400790` (motor_state) and dispatches via `FW:0x25B6A`
8. Calls motor subroutines at `FW:0x25BF6` (3 call sites for different motor operations)

### Extended Configuration (DTC=0xE0)

Upload extended scanner configuration (up to 1024 bytes). Qualifier selects the mode (0, 1, or 3). This likely includes advanced operating parameters not covered by SET WINDOW.

## Usage Context

- Called during scan setup to upload calibration or correction data
- Called before scanning to set hardware LUTs/gamma curves
- Typical calibration sequence:
  1. `READ` — read scanner's internal calibration data
  2. Process/modify calibration in software
  3. **`WRITE`** — upload modified calibration back to scanner
- Not used for image data (image data flows scanner -> host via READ only)

## Firmware Handler (Phase 4)

**Handler address**: `FW:0x025506` | **Exec mode**: 0x02 (data-out) | **Perm flags**: 0x0014

The handler address is labeled SEND(10) in the SCSI-2 scanner standard (opcode 0x2A = SEND, used for sending data TO the scanner). Permission flags 0x0014 require the scanner to be initialized.

The handler accepts data payloads from the host and routes them based on the Data Type Code (CDB byte 2) and Data Type Qualifier (CDB byte 5) to the appropriate internal storage — calibration tables, LUT data, or configuration parameters.

The dispatch chain at `0x025622`-`0x02564C` compares CDB[2] (loaded into `r8l`) against each supported DTC:

```
0x025624: cmp.b #0x03, r8l  -> beq 0x025650   (gamma/LUT)
0x025628: cmp.b #0x84, r8l  -> beq 0x025722   (calibration)
0x02562E: cmp.b #0x85, r8l  -> beq 0x025830   (extended calibration)
0x025634: cmp.b #0x88, r8l  -> beq 0x0258F0   (boundary data)
0x02563A: cmp.b #0x8F, r8l  -> beq 0x02591C   (histogram/profile)
0x025640: cmp.b #0x92, r8l  -> beq 0x025908   (motor control)
0x025646: cmp.b #0xE0, r8l  -> beq 0x02591C   (extended config)
```

The dispatch table at flash `0x49B98` contains 7 entries of 10 bytes each, terminated by 0xFF. Each entry encodes: DTC value, qualifier category, max transfer size, and handler-internal parameters.

### Sense Codes

| Sense Index | ASC/ASCQ | Condition |
|-------------|----------|-----------|
| 0x50 | 24/00 | Invalid field in CDB (unknown data type code) |
| 0x53 | 26/00 | Invalid field in parameter list (bad data content) |
| 0x65 | 08/00 | LU communication failure (DMA/transfer error) |

See [Sense Code Catalog](sense-codes.md) for full details.

## Source References

| Source | Location | Notes |
|--------|----------|-------|
| LS5000.md3 | `0x100b51f0` | CDB builder — mirrors READ structure, byte9=0x00 |
| LS5000.md3 | `0x100b50c0` | WRITE factory — `push 2` (direction=data-out), `ret 0x20` |
| LS5000.md3 | `0x100B0E06` | Callsite — `push 0x84` (calibration upload) |
| Firmware | `0x025506` | Handler entry — SEND(10) dispatcher |
| Firmware | `0x025622` | DTC dispatch chain start |
| Firmware | `0x049B98` | DTC dispatch table (7 entries x 10 bytes) |

## Cross-References

- [READ](read.md) — counterpart that reads data from the scanner (15 DTCs vs WRITE's 7)
- [READ BUFFER](read-buffer.md) — alternative way to read from scanner buffers
- [WRITE BUFFER](write-buffer.md) — alternative way to write to scanner buffers
- [Firmware SCSI Handler](../components/firmware/scsi-handler.md) — Full dispatch table
- [ISP1581 USB](../components/firmware/isp1581-usb.md) — USB DMA for data transfer
- [SCSI Command Build Infrastructure](../components/ls5000-md3/scsi-command-build.md) — CDB builder vtable system
- [NKDUSCAN API](../components/nkduscan/api.md) — USB transport that sends this CDB
- [USB Protocol](../architecture/usb-protocol.md) — transport layer details
