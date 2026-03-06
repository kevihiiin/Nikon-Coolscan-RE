# Firmware SCSI Command Handler — Dispatch Table and CDB Processing

**Status**: Complete
**Last Updated**: 2026-02-27
**Phase**: 4 (Firmware)
**Confidence**: Verified (all 21 handlers disassembled and analyzed; cross-validated with Phase 2 host-side findings)

## Overview

The LS-50 firmware implements SCSI command handling through a data-driven dispatch table at flash address 0x49834. When a SCSI CDB arrives via USB (bulk-out endpoint), the firmware extracts the opcode byte (CDB[0]), looks it up in this table, performs permission/state checking, and calls the corresponding handler function.

## SCSI Command Dispatch Table (0x49834)

### Table Format

Each entry is 10 bytes, big-endian:

```
Offset  Size  Field
------  ----  -----
  0       1   SCSI opcode
  1       1   Unused (always 0x00)
  2-3     2   Permission flags (bitmask)
  4-7     4   Handler function pointer (32-bit address)
  8       1   Execution mode
  9       1   Unused (always 0x00)
```

The table is terminated by a null entry (all zeros) at 0x49906.

### Complete Handler Mapping (21 entries)

| SCSI Op | Command Name | Handler Addr | Perm Flags | Exec | Data Dir |
|---------|-------------|-------------|-----------|------|----------|
| 0x00 | TEST UNIT READY | 0x0215C2 | 0x07D4 | 0x01 | None |
| 0x03 | REQUEST SENSE | 0x021866 | 0x07FF | 0x03 | In |
| 0x12 | INQUIRY | 0x025E18 | 0x07FF | 0x03 | In |
| 0x15 | MODE SELECT(6) | 0x02194A | 0x0014 | 0x02 | Out |
| 0x16 | RESERVE(6) | 0x021E3E | 0x07CC | 0x01 | None |
| 0x17 | RELEASE(6) | 0x021EA0 | 0x07FC | 0x01 | None |
| 0x1A | MODE SENSE(6) | 0x021F1C | 0x07D4 | 0x03 | In |
| 0x1B | SCAN | 0x0220B8 | 0x0014 | 0x00 | None* |
| 0x1C | RECEIVE DIAGNOSTIC | 0x023856 | 0x0014 | 0x03 | In |
| 0x1D | SEND DIAGNOSTIC | 0x023D32 | 0x0016 | 0x02 | Out |
| 0x24 | SET WINDOW | 0x026E38 | 0x0014 | 0x02 | Out |
| 0x25 | GET WINDOW | 0x0272F6 | 0x0254 | 0x03 | In |
| 0x28 | READ(10) | 0x023F10 | 0x0054 | 0x03 | In |
| 0x2A | SEND(10) | 0x025506 | 0x0014 | 0x02 | Out |
| 0x3B | WRITE BUFFER | 0x02837C | 0x0014 | 0x02 | Out |
| 0x3C | READ BUFFER | 0x028884 | 0x0014 | 0x03 | In |
| 0xC0 | Vendor: Status Query | 0x028AB4 | 0x0754 | 0x01 | None |
| 0xC1 | Vendor: Trigger Action | 0x028B08 | 0x0014 | 0x01 | None |
| 0xD0 | Vendor: Phase Query | 0x013748 | 0x07FF | 0x01 | None |
| 0xE0 | Vendor: Data Out | 0x028E16 | 0x0014 | 0x02 | Out |
| 0xE1 | Vendor: Data In | 0x0295EA | 0x0014 | 0x03 | In |

### Execution Mode Byte

The exec byte at offset +8 controls the handler calling convention:

| Value | Meaning |
|-------|---------|
| 0x00 | Direct call — handler manages its own data transfer. *SCAN uses this mode but does have a data-out phase (window ID list from host); the handler sets up the transfer internally rather than relying on dispatch infrastructure.* |
| 0x01 | Calls 0x1374A (USB state setup) before execution |
| 0x02 | Data-out transfer (host sends data to device) |
| 0x03 | Data-in transfer (device sends data to host) |

### Permission Flags

The 16-bit permission flags at offset +2 control which scanner states allow the command. The dispatch code at 0x20CA0 groups these into categories checked via bit tests on r5h/r5l:

| Flag Pattern | Meaning |
|-------------|---------|
| 0x07FF | Always allowed (any state) |
| 0x07D4 | Allowed in most states except active scan |
| 0x07FC | Allowed in all states except initial |
| 0x07CC | Restricted (not during scan/transfer) |
| 0x0254 | Limited to specific states |
| 0x0054 | Only during active read operations |
| 0x0016 | Only in diagnostic/service mode |
| 0x0014 | Requires scanner to be initialized |

## Cross-Validation with Phase 2 (Host-Side)

### Opcode Match

| Source | Opcode Count | Opcodes |
|--------|-------------|---------|
| LS5000.md3 (Phase 2) | 17 | 00, 12, 15, 16, 17, 1A, 1B, 1C, 1D, 24, 25, 28, 2A, C0, C1, E0, E1 |
| Firmware (Phase 4) | 20 | Same 17 + **0x03, 0x3B, 0x3C** |

*Note*: REQUEST SENSE (0x03) and phase query (0xD0) are transport-layer opcodes handled by NKDUSCAN.dll, not LS5000.md3. D0 is not in the firmware's SCSI dispatch table — it is handled by the ISP1581 USB module.

The firmware supports **3 additional opcodes** beyond what LS5000.md3 builds:
- **0x03 REQUEST SENSE** — Handled by firmware at 0x021866 (sense translation table at 0x16DEE)
- **0x3B WRITE BUFFER** — Standard SCSI command for firmware update (data-out)
- **0x3C READ BUFFER** — Standard SCSI command for reading firmware/diagnostic data (data-in)

0x3B/0x3C are likely used by a separate firmware update utility, not the normal NikonScan scanning workflow.

**All 17 host-side opcodes match exactly.** Confidence: **Verified** (cross-validated between Phase 2 and Phase 4).

### Vendor Command Correlation

| Host-Side Name (Phase 2) | Firmware Handler | Notes |
|--------------------------|-----------------|-------|
| Phase Query (0xD0) | 0x013748 (shared module) | Only handler in shared module (0x10000-0x17FFF) |
| Status Query (0xC0) | 0x028AB4 | Checks scanner state bits |
| Trigger (0xC1) | 0x028B08 | Initiates motor/lamp actions |
| Data Out (0xE0) | 0x028E16 | Sends calibration/config data to scanner |
| Data In (0xE1) | 0x0295EA | Reads calibration/config data from scanner |

## Dispatch Flow

### 1. CDB Reception (ISP1581 → RAM)

The CDB arrives via USB bulk-out endpoint. ISP1581 interrupt handler reads CDB bytes from the endpoint data register (0x600020) and stores them in RAM at 0x4007DE.

### 2. Opcode Lookup (0x020B48)

```asm
0x020B4E: mov.l  #0x49834, er6       ; Table base address
; Loop:
0x020B56: mov.b  @er6, r0l           ; Read opcode from table entry
0x020B58: mov.b  @0x4007B6, r1l      ; Read received SCSI opcode from RAM
0x020B5E: cmp.b  r1l, r0l            ; Compare
0x020B60: beq    0x20B70             ; Match → use this entry
0x020B62: add.l  #0xA, er6           ; Next entry (10-byte stride)
0x020B68: mov.l  @(0x4,er6), er0     ; Read handler pointer
0x020B6E: bne    0x20B56             ; Loop if not null (end-of-table check)
; Match found:
0x020B70: mov.w  @(0x2,er6), r5      ; Load permission flags
```

### 3. Permission Checking (0x020CA0)

The internal state machine determines the current scanner state. The dispatch code at 0x20CA0 checks the internal command category against the permission flags to ensure the command is allowed in the current state.

### 4. Handler Call (0x020DB2)

```asm
0x020D94: mov.b  @(0x8,er6), r0l     ; Read exec mode byte
0x020D98: cmp.b  #0x1, r0l           ; Check if USB state setup needed
0x020D9A: bne    0x20DA2             ; Skip if not
0x020D9C: mov.b  r3l, r0l            ; Pass command phase
0x020D9E: jsr    @0x1374A            ; USB state setup function
; Load and call handler:
0x020DAC: mov.l  @(0x4,er6), er6     ; Load handler function pointer
0x020DB2: jsr    @er6                ; CALL HANDLER
; Cleanup:
0x020DB4: jsr    @0x16436            ; Restore interrupt state
0x020DB8: rts
```

## Internal Task Code Table (0x49910)

A secondary table at 0x49910 maps 16-bit internal task codes to handler indices. This table has 93 entries of 4 bytes each (task_code:16, handler_index:16), terminated by 0x0000.

These are **not SCSI opcodes** — they represent the firmware's internal task/event system. The task codes use a hierarchical naming: the high byte is the subsystem, the low byte is the specific task.

### Task Code Groups

| High Byte | Subsystem | Example Codes |
|-----------|-----------|---------------|
| 0x01 | Configuration | 0x0110, 0x0120, 0x0121 |
| 0x02 | Data Management | 0x0200 |
| 0x03 | Control/State | 0x0300, 0x0310, 0x0320, 0x0330, 0x0340, 0x0350, 0x0380, 0x0390 |
| 0x04 | Motor Control | 0x0400, 0x0430, 0x0440, 0x0450 |
| 0x05 | Calibration | 0x0500, 0x0501, 0x0502 |
| 0x06 | Sensor/CCD | 0x0600-0x0614, 0x0610-0x0614 |
| 0x08 | Scan Operations | 0x0800-0x08B4 (largest group, ~40 entries) |
| 0x09 | Status/Query | 0x0910-0x0940 |
| 0x0F | System | 0x0F10, 0x0F20, 0x0F30, 0x0F40, 0x0F50, 0x0F60 |
| 0x10 | Extended | 0x1000, 0x1100, 0x1200 |
| 0x20 | Mode Change | 0x2000 |
| 0x30 | Reset/Init | 0x3000 |
| 0x70 | Debug | 0x7000 |
| 0x80 | Error | 0x8000 |
| 0x90 | Recovery | 0x9000 |

Some entries share the same handler index, indicating common processing paths (e.g., 0x0800, 0x0810, 0x0820 all map to handler 0x0022).

## Key RAM Addresses

| Address | Size | Purpose |
|---------|------|---------|
| 0x4007B6 | 1 | Current SCSI opcode (CDB byte 0) |
| 0x4007DE | 16+ | CDB receive buffer |
| 0x40077C | 2 | Internal command/state code |
| 0x400776 | 1 | Scanner state flags |
| 0x4007B0 | 2 | Command result/status |
| 0x40087B | 1 | Command queue index |
| 0x40049A | 1 | USB transaction in-progress flag |
| 0x40049B | 1 | Current execution mode |
| 0x40049C | 1 | USB transfer phase |
| 0x40049D | 1 | Command completion counter |

## D0 Phase Query Handler (0x013748)

The phase query handler is notable because:
1. It's the ONLY handler located in the shared handler module (0x10000-0x17FFF), not main firmware
2. It has permission flags 0x07FF (always allowed in any state)
3. It's the mechanism by which the host polls for command completion

This matches the Phase 1/2 finding that opcode 0xD0 is used for USB protocol phase queries.

## Handler Function Signatures

All SCSI handlers follow a common pattern:

```asm
; Prologue:
jsr   @0x016458            ; push_context: save er3-er6 to stack
sub.l #N, er7              ; allocate local stack frame (N varies per handler)
; Load common pointers:
mov.l #0x4007B6, er6       ; er6 → CDB buffer (or er4/er5)
mov.l #0x4007B0, erX       ; erX → sense/status result word
; Validate CDB:
mov.b @(0x1, er6), r0l    ; CDB[1] flags
and.b #0x1F, r0l          ; reserved bits must be zero
bne   error                ; → ILLEGAL REQUEST
; ... handler logic ...
; Epilogue:
add.l #N, er7              ; deallocate stack frame
jsr   @0x016436            ; pop_context: restore er3-er6
rts                        ; return to dispatch loop
```

Error is signaled by writing a sense code to `@0x4007B0` (the sense_data word).

### Sense Codes Used by Handlers

Names below describe the *scanner condition*, not the SCSI sense key. See [Sense Code Catalog](../../scsi-commands/sense-codes.md) for actual SK/ASC/ASCQ values.

| Code | Scanner Condition | SK/ASC/ASCQ | Used By |
|------|------------------|-------------|---------|
| 0x0007 | Becoming ready (general) | 02/04/01 | TEST UNIT READY (startup) |
| 0x0008 | Becoming ready (USB) | 02/04/01 FRU=01 | TEST UNIT READY (ISP1581 init) |
| 0x0009 | Becoming ready (encoder) | 02/04/01 FRU=02 | TEST UNIT READY (encoder init) |
| 0x000A | Init command required | 02/04/02 | TEST UNIT READY (not initialized) |
| 0x000D | Ejecting (LU not responding) | 02/05/00 | TEST UNIT READY (ejecting state 0x80) |
| 0x0050 | Invalid CDB field | 05/24/00 | All handlers (bad opcode/param) |
| 0x0053 | Invalid parameter value | 05/26/00 | SCAN, MODE SELECT |
| 0x0059 | Saving parameters unsupported | 05/39/00 | MODE SENSE (PC=3 not supported) |
| 0x0071 | Scan timeout (reinit needed) | 02/04/02 | TEST UNIT READY |
| 0x0079 | Motor busy (positioning) | 02/04/01 FRU=03 | TEST UNIT READY |
| 0x007A | Calibration in progress | 02/04/01 FRU=04 | TEST UNIT READY |

### Response Sending

Handlers that return data to the host (exec mode 0x03) follow this pattern:
1. Fill response buffer on stack (er5 typically points to it)
2. Call `jsr @0x01374A` — USB response manager, passes command phase in r0l
3. Call `jsr @0x014090` — USB data transfer function, with:
   - er0 = pointer to response buffer
   - r1 = byte count to send
4. The response manager handles ISP1581 DMA and USB bulk-in transfer

## Individual Handler Analysis

### TEST UNIT READY (0x00) — Handler 0x0215C2

**Size**: ~700 bytes (0x0215C2-0x021860)
**Stack frame**: None (uses pointers to RAM)

The largest handler. Reports scanner readiness through sense codes. Checks an extensive state machine:

1. **CDB Validation**: CDB bytes 2-5 must be zero
2. **Scanner State Check** (@0x40077C low byte):
   - 0x00: Idle — checks scan buffer state (@0x400778) for pending errors
   - 0x80: Ejecting — returns sense 0x000D (MEDIUM REMOVAL REQUEST)
   - 0x01 or 0xF2: Active scan — checks DMA/motor state for errors
   - 0x20-0x2F: Setup phase — returns status
   - 0xF0: Sensor error → sense 0x0008
   - 0xF1: Motor error → sense 0x0009
   - 0xF3: Motor busy → sense 0x0079
   - 0xF4: Calibration busy → sense 0x007A
3. **Active Scan State**: When scanner_state=0x01/0xF2:
   - Checks DMA state (@0x40077A) against scan progress
   - State 0x0330: scan buffer full (stalled)
   - State 0x0340/0x0320: scan complete conditions
   - State 0x3000: resolution-dependent handling (checks color_mode @0x400E92)
   - State 0x2000: checks sub-states 0x0110, 0x0120, 0x0121

### REQUEST SENSE (0x03) — Handler 0x021866

**Size**: ~230 bytes
**Stack frame**: 0x108 bytes

Returns sense data describing the last error. Standard SCSI sense format:
- CDB[4] = allocation length (max bytes to return)
- Reads sense key from @0x4007B0
- Builds 18-byte sense data response on stack
- Includes additional sense code from @0x400877/0x400880

### INQUIRY (0x12) — Handler 0x025E18

**Size**: ~580 bytes (0x025E18-0x026058)
**Stack frame**: 0x0C bytes

Supports standard INQUIRY and VPD (Vital Product Data) pages:

1. **CDB Parsing**:
   - CDB[1] & 0x1E: reserved bits, must be zero
   - CDB[1] bit 0: EVPD flag (enables VPD page lookup)
   - CDB[2]: page code (VPD page number)
   - CDB[5] bit 7: CMDDT flag (command support data)
   - CDB[5] & 0x3F: allocation length low bits

2. **Standard INQUIRY** (EVPD=0, page=0):
   - Calls subroutine at 0x02605A to build standard INQUIRY response
   - Response built at buffer @0x4008A2
   - Device type: 0x06 (Scanner) — or 0x7F if peripheral qualifier set
   - Sends response via USB (jsr @0x01374A then @0x014090)

3. **VPD Page Lookup**: Uses two-level dispatch:
   - **Standard VPD table** at 0x49C20 (8 entries, 6 bytes each):
     - `[page_code:8, field:8, handler:32]`
     - Pages: 0x00 (supported pages), 0x01, 0x10, 0x40, 0x41, 0x50, 0x51, 0x52
   - **Adapter-specific VPD table** at 0x49C74 (indexed by adapter_type * 30):
     - 5 entries per adapter, same 6-byte format
     - Adapter 0 (none): pages 0xF8, 0xFA, 0xFB, 0xFC
     - Adapter 1 (Mount): page 0x46
     - Adapter 2 (Strip): pages 0x43, 0x44, 0xE2
     - Adapter 3 (240): pages 0x45, 0xF1
     - Adapter 4 (Feeder): pages 0x46, 0xE2
     - Adapter 5 (6Strip): pages 0x47, 0xE2
     - Adapter 6 (36Strip): page 0x10

4. **VPD C1 Page** (special case, checked before table lookup):
   - Builds direct response: [page_code, 0, 2, 0, 0xC1]
   - Length: 6 bytes

### MODE SELECT (0x15) — Handler 0x02194A

**Size**: ~500 bytes
**Stack frame**: 0x10A bytes

Receives mode parameter data from host to configure scanner settings. CDB validation checks reserved bits, then reads mode page data from USB bulk-out. Buffer stored at @0x400DAA with header at @0x400D8E.

### MODE SENSE (0x1A) — Handler 0x021F1C

**Size**: ~420 bytes (0x021F1C-0x0220B6)
**Stack frame**: 0x100 bytes

Returns scanner mode pages:

1. **CDB Parsing**:
   - CDB[1] bit 4: DBD (Disable Block Descriptors)
   - CDB[1] & 0x07: reserved, must be zero
   - CDB[2]: page code + page control field
   - CDB[3]: must be zero
   - CDB[4]: allocation length (0 → default 256)
   - CDB[5]: must be zero

2. **Mode Page Header** (3 bytes from @0x400D26):
   - Byte 0: mode data length
   - Byte 1: medium type
   - Byte 2: device-specific parameter

3. **Page Control (CDB[2] bits 6-7)**:
   - 0: Current values — data from @0x400D2A (8 bytes per page)
   - 1: Changeable values — 8 bytes from @0x400D32
   - 2: Default values — 8 bytes from flash @0x0168AF
   - 3: Saved values — not supported (sense 0x0059)

4. **Supported Page Codes**:
   - 0x03: Format/device-specific (resolution, max scan area)
   - 0x3F: All pages (returns all supported pages concatenated)

5. **Flash Page Data** (0x0168AF) — Default device parameters:
   - Page code 0x03, length 6
   - Base resolution: 1200 DPI
   - Max X: 4000 units, Max Y: 4000 units

### SCAN (0x1B) — Handler 0x0220B8

**Size**: ~1800 bytes (0x0220B8-0x022874+)
**Stack frame**: 0x3C bytes

Initiates a scan operation. The most complex standard command:

1. **CDB Validation**: CDB bytes 2-5 must be zero; CDB[0x4007BA] (exec_mode byte) must be ≤ 4
2. **Scan Parameter Buffer**: Builds scan descriptor at er6 (stack-relative), up to 10 bytes
3. **Scan Phases** (er6[0] value = operation code):
   - 0: Preview scan
   - 1: Fine scan (single pass)
   - 2: Fine scan (multi-pass)
   - 3: Calibration scan
   - 4: Move to position
   - 9: Eject film
4. **Operation Execution**:
   - Calls USB response manager (0x1374A) with exec mode 2
   - Calls data transfer setup (0x13E20)
   - Validates operation code against max allowed (checks busy conflicts)
   - Error 0x0053 if invalid operation code
5. **Scan State Variables**:
   - 0x400D43: scan operation active flag
   - 0x400E7A: scan operation state
   - 0x400D3C: max operations for current adapter

### VENDOR C0 (0xC0) — Handler 0x028AB4

**Size**: ~80 bytes
**Stack frame**: None

Simple status query. Returns scanner abort/completion state:
1. Validates CDB bytes 2-5 are zero
2. Checks abort flag at @0x400776 bit 6
3. If set: sets bit 7 (response pending), clears transfer count @0x4007B2
4. Returns status only — no data transfer

### VENDOR C1 (0xC1) — Handler 0x028B08

**Size**: ~730 bytes (0x028B08-0x028DEC)
**Stack frame**: None

Trigger/action dispatcher. Reads subcommand code from @0x400D63 and dispatches:

**Subcommand codes** (matched against @0x400D63):

| Code | Group | Purpose |
|------|-------|---------|
| 0x40-0x43 | Scan/Calibration | Execute scan operation variant |
| 0x44 | Motor | Move to position |
| 0x45-0x47 | Scan/Calibration | Execute calibration variant |
| 0x80 | Control | Lamp on/off control |
| 0x81 | Control | Motor initialization |
| 0x91 | Motor | Step motor command |
| 0xA0 | Sensor | CCD/sensor setup |
| 0xB0-0xB1 | Control | State change |
| 0xB3 | Config | Write configuration data |
| 0xB4 | Config | Write extended config |
| 0xC0-0xC1 | Calibration | Gain/offset calibration |
| 0xD0-0xD2 | Debug | Diagnostic operations |
| 0xD5 | Debug | Extended diagnostic |
| 0xD6 | Config | Write persistent settings |

These subcodes match the internal task table codes (0x49910) and correspond directly to Phase 2 vendor command operations.

### VENDOR E0 (0xE0) — Handler 0x028E16

**Size**: ~480 bytes
**Stack frame**: 0x18 bytes

Data-out handler for writing configuration registers. Uses the vendor register table at 0x4A134:

1. **CDB Validation**: CDB bytes 3-5 must be zero; CDB[0x4007BF] (cmd_category) must be zero
2. **Register Lookup**: CDB[0x4007B8] matched against table at 0x4A134
   - Table format: [reg_id:8, max_data_len:8] × 23 entries
   - Terminates with 0xFF marker
3. **Data Address Calculation** from CDB bytes:
   - Bytes [1-4] of received data: 32-bit register address (byte[1]<<24 + byte[2]<<16 + byte[3]<<8 + byte[4])
   - Bytes [5-8]: 32-bit data length (byte[5]<<24 + byte[6]<<16 + byte[7]<<8 + byte[8])
   - Byte [9-10]: additional parameters (9=high, 10=low)
4. **Resolution Calculation** (for 1200 DPI base):
   - Multiplier: 0x6C6 (1734) for each resolution unit
   - Formula: `(scan_resolution + 2) * 0x6C6` stored at @0x400D8E, 0x400D9A, 0x400D9E

### VENDOR E1 (0xE1) — Handler 0x0295EA

**Size**: ~430 bytes
**Stack frame**: 0x20 bytes

Data-in handler for reading configuration registers. Mirror of E0:
1. Same CDB validation pattern
2. Same register table lookup at 0x4A134
3. Reads register data and sends to host via USB response manager

### Vendor Register Table (0x4A134)

23 entries mapping register IDs to maximum data lengths:

| Reg ID | Max Len | Purpose (from Phase 2 cross-ref) |
|--------|---------|--------------------------------|
| 0x40 | 11 | Scan parameters (R/W) |
| 0x41 | 11 | Calibration data (R/W) |
| 0x42 | 11 | Gain values (R/W) |
| 0x43 | 11 | Offset values (R/W) |
| 0x44 | 5 | Motor position (R/W) |
| 0x45 | 11 | Exposure time (R/W) |
| 0x46 | 11 | Focus position (R/W) |
| 0x47 | 11 | Lamp settings (R/W) |
| 0x80 | 0 | Lamp on/off (trigger only) |
| 0x81 | 0 | Motor init (trigger only) |
| 0x91 | 5 | Motor step (5 bytes: direction + count) |
| 0xA0 | 9 | CCD setup (9 bytes) |
| 0xB0 | 0 | State change (trigger only) |
| 0xB1 | 0 | State change (trigger only) |
| 0xB3 | 13 | Config write (13 bytes) |
| 0xB4 | 9 | Extended config (9 bytes) |
| 0xC0 | 5 | Gain calibration data |
| 0xC1 | 5 | Offset calibration data |
| 0xD0 | 0 | Diagnostic (trigger only) |
| 0xD1 | 0 | Diagnostic (trigger only) |
| 0xD2 | 5 | Diagnostic data |
| 0xD5 | 5 | Extended diagnostic |
| 0xD6 | 5 | Persistent settings |

**Cross-validation**: These register IDs match the C1 subcommand codes and the Phase 2 E0/E1 operation identifiers. The E0→C1→E1 flow is confirmed: E0 writes register data, C1 triggers the operation, E1 reads results.

## Related KB Docs

- [Vector Table](./vector-table.md) — Interrupt handler mapping
- [Startup Code](./startup.md) — Initialization and dispatch setup
- [ISP1581 USB](./isp1581-usb.md) — USB controller interface
- [USB Protocol](../../architecture/usb-protocol.md) — Host-side USB protocol analysis
- [SCSI Commands](../../scsi-commands/) — Per-command host-side documentation
