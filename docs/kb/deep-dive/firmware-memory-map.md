# Complete Firmware Memory Map — Nikon LS-50

**Status**: Complete
**Last Updated**: 2026-03-12
**Phase**: 4 (Firmware)
**Confidence**: Verified (all addresses from disassembly, I/O init table, and KB cross-references)

## Overview

This document provides a comprehensive memory map for the Nikon LS-50 firmware running on the Hitachi H8/3003 (H8/300H family, 24-bit address bus, big-endian). Every known RAM variable, hardware register, and memory-mapped I/O address is listed with its size, access pattern, and purpose.

A companion C header file is at [firmware-memory-map.h](firmware-memory-map.h).

---

## 1. Address Space Overview

```
0x000000-0x07FFFF  [512KB]  Flash ROM (MBM29F400B TSOP48)
0x200000-0x200FFF  [ ~4KB]  Custom ASIC Registers (172 unique addresses)
0x400000-0x41FFFF  [128KB]  External SRAM (main working memory)
0x600000-0x6000FF  [ 256B]  ISP1581 USB Controller Registers
0x800000-0x83FFFF  [256KB]  ASIC RAM (224KB firmware-accessible)
0xC00000-0xC0FFFF  [ 64KB]  Buffer RAM (USB staging, ping-pong)
0xFFFD00-0xFFFD3F  [  64B]  On-Chip RAM (interrupt trampolines)
0xFFFF20-0xFFFFFF  [ 224B]  H8/3003 On-Chip I/O Registers
```

---

## 2. Flash ROM (0x000000-0x07FFFF)

| Region | Address Range | Size | Content |
|--------|---------------|------|---------|
| Vector Table | 0x000000-0x0000FF | 256B | 64 x 4-byte interrupt vectors |
| Boot Code | 0x000100-0x00018A | 138B | SP init, bank select, jump to main |
| Default Handlers | 0x000182-0x00018A | 8B | NMI (tight loop), default ISR (tight loop) |
| Settings Area A | 0x004000-0x005FFF | 8KB | Structured data (mostly erased) |
| Settings Area B | 0x006000-0x007FFF | 8KB | Structured data (mostly erased) |
| Unused | 0x008000-0x00FFFF | 32KB | Erased (0xFF), no code references |
| Shared Module | 0x010000-0x017FFF | 32KB | ISP1581 USB, response manager, context switch |
| Unused | 0x018000-0x01FFFF | 32KB | Erased |
| Main Firmware | 0x020000-0x044FFF | 148KB | Code (SCSI handlers, motor, scan, calibration) |
| Data Tables | 0x045000-0x0528BE | ~55KB | All data tables (see firmware-data-tables.md) |
| Unused | 0x053000-0x05FFFF | 52KB | Erased |
| Log Area 1 | 0x060000-0x063FFF | 16KB | Usage telemetry (433 x 32B records) |
| Unused | 0x064000-0x06FFFF | 48KB | Erased |
| Log Area 2 | 0x070000-0x07FFFF | 64KB | Usage telemetry (2048 x 32B records) |

**Total used**: ~314KB (59.9% of 512KB).

---

## 3. External RAM Variables (0x400000-0x41FFFF)

### 3.1 System Core (0x400000-0x4000FF)

| Address | Size | R/W | Name | Description | Used By |
|---------|------|-----|------|-------------|---------|
| 0x400082 | 1 | R/W | cmd_pending | USB command pending flag (1=command waiting) | Main loop, USB ISR |
| 0x400084 | 1 | R/W | usb_bus_reset | USB bus reset detected flag | Main loop |
| 0x400085 | 1 | R/W | usb_reinit | USB re-initialization needed flag | Main loop |
| 0x400086 | 1 | R/W | error_flag | General error flag | Main loop, USB reset |
| 0x400088 | 2 | R/W | usb_state_counter | USB state tracking counter | Main loop |

### 3.2 Task System (0x400490-0x4004BF)

| Address | Size | R/W | Name | Description | Used By |
|---------|------|-----|------|-------------|---------|
| 0x400492 | 1 | R/W | task_complete | Task completion flag | Task executor (0x20DD6) |
| 0x400493 | 1 | R/W | task_active | Task execution in-progress flag | Task executor |
| 0x40049A | 1 | R/W | usb_txn_active | USB transaction in progress | SCSI dispatch, response mgr |
| 0x40049B | 1 | R/W | exec_mode | Current SCSI exec mode (from dispatch table) | SCSI dispatch (0x20D94) |
| 0x40049C | 1 | R/W | xfer_phase | USB transfer phase | SCSI dispatch |
| 0x40049D | 1 | R/W | cmd_complete_ctr | Command completion counter | SCSI dispatch (0x20AE2) |
| 0x40049E | 4 | R/W | task_result | Task result/status (32-bit) | Task executor |
| 0x4004B0 | varies | R/W | write_buffer_area | WRITE BUFFER staging | WRITE BUFFER handler |

### 3.3 Reservation State (0x4006B3)

| Address | Size | R/W | Name | Description | Used By |
|---------|------|-----|------|-------------|---------|
| 0x4006B3 | 1 | R/W | reserve_state | RESERVE/RELEASE state byte | RESERVE (0x21E3E), RELEASE (0x21EA0) |

### 3.4 Context Switch / Coroutine System (0x400760-0x400775)

| Address | Size | R/W | Name | Description | Used By |
|---------|------|-----|------|-------------|---------|
| 0x400764 | 2 | R/W | ctx_switch_state | Context switch state word | Context switcher (0x10876) |
| 0x400766 | 4 | R/W | ctx_a_sp_save | Context A saved stack pointer | Context switcher |
| 0x40076A | 4 | R/W | ctx_b_sp_save | Context B saved stack pointer | Context switcher |
| 0x40076E | 4 | R/W | sys_timestamp | Global timestamp (ITU4 increments) | ITU4 ISR (0x10A16), encoder ISR |
| 0x400770 | 2 | R/W | timer_capture | Current timer capture value | Encoder ISR (0x33444) |
| 0x400772 | 1 | R/W | boot_flag | Boot mode (0=cold, 1=warm re-entry) | Init (0x20600), context init |
| 0x400773 | 1 | R/W | cmd_state | Command/pipeline state (4=scan, 5=cal) | ITU4 poll, Context B |
| 0x400774 | 1 | R/W | motor_mode | ITU2 dispatch selector (2/3/4/6) | Motor setup, ITU2 ISR |

### 3.5 Scanner State Machine (0x400776-0x4007AF)

| Address | Size | R/W | Name | Description | Used By |
|---------|------|-----|------|-------------|---------|
| 0x400776 | 2 | R/W | state_flags | Scanner state (bit6=abort, bit7=response, bit14=0x4000 flag) | Main loop, TUR, C0 |
| 0x400778 | 2 | R/W | task_code | Current task code (primary dispatch) | Main loop, Context B, task dispatch |
| 0x40077A | 2 | R/W | scan_progress | Scan progress / DMA state | Main loop, TUR handler |
| 0x40077C | 2 | R/W | scanner_state | Scanner state machine variable (low byte = state) | TUR handler, Context B |
| 0x40077E | 4 | R/W | red_exposure | Red channel exposure timing | Lamp handler (0x28BC4) |
| 0x400782 | 4 | R/W | grn_exposure | Green channel exposure timing | Lamp handler |
| 0x40078C | 4 | R/W | task_remaining | Task remaining work counter (32-bit) | Task executor (0x20DD6) |
| 0x400790 | 1 | R/W | gain_adjust | Gain adjustment factor | Calibration (0x2652A) |
| 0x400791 | 1 | R/W | gpio_shadow | GPIO shadow register (pre-modification state) | Lamp, motor, scan (23 refs) |

### 3.6 SCSI State (0x4007B0-0x4007FF)

| Address | Size | R/W | Name | Description | Used By |
|---------|------|-----|------|-------------|---------|
| 0x4007B0 | 2 | R/W | sense_code | Internal sense code (maps to SK/ASC/ASCQ) | All SCSI handlers |
| 0x4007B2 | 2 | R/W | xfer_count | Transfer byte count | C0 handler, data transfer |
| 0x4007B4 | 2 | R/W | scsi_param_a | SCSI parameter A | RECV/SEND DIAG handlers |
| 0x4007B6 | 1 | R | scsi_opcode | Current SCSI opcode (CDB byte 0) | SCSI dispatch (0x20B48) |
| 0x4007B7 | 1 | R | cdb_byte1 | CDB byte 1 (reserved bits check) | TUR handler (0x2015D8) |
| 0x4007B8 | varies | R | cdb_params | CDB parameter area | E0/WRITE handlers |
| 0x4007BA | 1 | R | scan_exec_mode | SCAN exec mode byte (CDB param) | SCAN handler |
| 0x4007BF | 1 | R | cmd_category | Command category byte | E0 handler |
| 0x4007D6 | 2 | R/W | usb_timeout | USB timeout timer | USB reset handler |
| 0x4007DE | 16 | W | cdb_buffer | CDB receive buffer (written by USB ISR) | ISP1581 ISR -> dispatch |

### 3.7 INQUIRY Response Buffer (0x4008A2)

| Address | Size | R/W | Name | Description | Used By |
|---------|------|-----|------|-------------|---------|
| 0x4008A2 | ~96 | W | inquiry_buf | INQUIRY response build buffer | INQUIRY handler (0x25E18) |
| 0x400877 | 1 | R/W | addl_sense | Additional sense qualifier | SCSI dispatch (0x20AE2) |
| 0x400880 | 1 | R/W | sense_info | Sense information byte | REQUEST SENSE |

### 3.8 Task Budget (0x400896-0x40089F)

| Address | Size | R/W | Name | Description | Used By |
|---------|------|-----|------|-------------|---------|
| 0x400896 | 4 | R/W | task_budget | Task time budget counter (32-bit) | Task executor (0x20DD6) |
| 0x40089A | 4 | R/W | task_budget_init | Saved initial budget for accounting | Task executor |

### 3.9 SET WINDOW / Scan Configuration (0x4009C2-0x400AFF)

| Address | Size | R/W | Name | Description | Used By |
|---------|------|-----|------|-------------|---------|
| 0x4009C2 | varies | R/W | window_desc | SET WINDOW descriptor data | SET WINDOW (0x26E38), GET WINDOW |
| 0x4009EC | varies | R | window_params | Window parameter table | SCAN handler |
| 0x400AAA | varies | R/W | window_buf_a | Window buffer A | GET WINDOW handler |
| 0x400AE4 | varies | R/W | window_buf_b | Window buffer B | GET WINDOW handler |
| 0x400B24 | varies | R/W | buffer_staging | Buffer staging area | READ BUFFER handler |
| 0x400B8A | 2 | W | cal_value_a | Calibration value A | Vec 19 ISR (0x2B544) |
| 0x400B8C | 2 | W | cal_value_b | Calibration value B | Vec 19 ISR |

### 3.10 Motor Speed / Ramp (0x400C0E-0x400CFF)

| Address | Size | R/W | Name | Description | Used By |
|---------|------|-----|------|-------------|---------|
| 0x400C0E | 2 | R/W | motor_speed_param | Current speed parameter | Motor control |
| 0x400CC8 | 2 | R/W | motor_ramp_config | Ramp table selector / speed profile | Motor setup (0x2E158) |

### 3.11 MODE SENSE / MODE SELECT (0x400D26-0x400DAF)

| Address | Size | R/W | Name | Description | Used By |
|---------|------|-----|------|-------------|---------|
| 0x400D26 | 4 | R/W | mode_header | Mode page header (length, medium type, dev param) | MODE SENSE (0x21F1C) |
| 0x400D2A | 8 | R/W | mode_current | Current mode page values | MODE SENSE PC=0 |
| 0x400D32 | 8 | R/W | mode_changeable | Changeable mode page values | MODE SENSE PC=1 |
| 0x400D3C | 1 | R/W | max_operations | Max operations for current adapter | SCAN handler |
| 0x400D3D | varies | R | scan_config_ext | Extended scan config | SCAN handler |
| 0x400D43 | 1 | R/W | scan_op_active | Scan operation active flag | SCAN handler |
| 0x400D45 | 24 | R | scan_params_buf | Scan parameters (READ DTC 0x87 source) | READ handler |
| 0x400D63 | 1 | R | c1_subcmd | C1 subcommand code | C1 handler (0x28B08) |
| 0x400D8E | varies | R/W | scan_resolution | Resolution / DMA config | MODE SELECT, E0 handler |
| 0x400D9A | 2 | R/W | resolution_x | Resolution X component | E0 handler |
| 0x400D9E | 2 | R/W | resolution_y | Resolution Y component | E0 handler |
| 0x400DAA | varies | R/W | mode_select_buf | MODE SELECT data buffer | MODE SELECT handler |

### 3.12 Scan State / Control (0x400E5F-0x400EFF)

| Address | Size | R/W | Name | Description | Used By |
|---------|------|-----|------|-------------|---------|
| 0x400E5F | 1 | R/W | soft_reset | Soft-reset request flag | Main loop |
| 0x400E79 | 1 | R | motor_busy_flag | Motor busy indicator | TUR handler |
| 0x400E7A | 1 | R/W | scan_op_state | Scan operation state | SCAN handler |
| 0x400E80 | 1 | W | init_result | Init result storage | Main loop (0x207F2) |
| 0x400E92 | 1 | R | color_mode | Color mode (6=special IR mode) | TUR handler (0x2177E) |
| 0x400E9x | varies | W | scan_config_vars | Scan config vars (set by Vec 19 ISR) | Vec 19 ISR |
| 0x400ED6 | 1 | R | positioning_flag | Motor positioning in progress | TUR handler |

### 3.13 Adapter / Film (0x400F22-0x400FFF)

| Address | Size | R/W | Name | Description | Used By |
|---------|------|-----|------|-------------|---------|
| 0x400F22 | 1 | R/W | adapter_type | Adapter bitmask (0x04/0x08/0x20/0x40) | Context B, INQUIRY |
| 0x400F56 | varies | R/W | cal_params_start | Calibration parameter block start | Calibration routines |
| 0x400F88 | varies | R/W | scan_window_data | Scan window configuration | GET WINDOW handler |
| 0x400F9D | varies | R/W | cal_params_end | Calibration parameter block end | Calibration routines |
| 0x400FAE | varies | R/W | adapter_desc | Adapter descriptor data | GET WINDOW handler |
| 0x400F0A | 2 | W | cal_result_r | Calibration result: Red min/max | Calibration routines |
| 0x400F12 | 2 | W | cal_result_g | Calibration result: Green min/max | Calibration routines |
| 0x400F1A | 2 | W | cal_result_b | Calibration result: Blue min/max | Calibration routines |

### 3.14 USB Code in RAM (0x4010A0-0x40123E)

| Address | Size | R/W | Name | Description | Used By |
|---------|------|-----|------|-------------|---------|
| 0x4010A0 | 414 | X | usb_ram_code | RAM-resident USB handler (copied from flash 0x124BA) | USB DMA fast path |
| 0x4011A2 | — | X | usb_ram_alt | Alternate entry into RAM-resident USB code | USB DMA |

### 3.15 Model Flag (0x404E48-0x404E96)

| Address | Size | R/W | Name | Description | Used By |
|---------|------|-----|------|-------------|---------|
| 0x404E48 | 4 | R/W | model_config_a | Model configuration A | GET WINDOW handler |
| 0x404E4C | 4 | R/W | model_config_b | Model configuration B | GET WINDOW handler |
| 0x404E50 | varies | R/W | model_params | Model parameter array | GET WINDOW handler |
| 0x404E96 | 1 | R | model_flag | LS-50 vs LS-5000 selector (0=LS-50, nonzero=LS-5000) | Calibration, INQUIRY |

### 3.16 Scan Pipeline State (0x405000-0x4065FF)

| Address | Size | R/W | Name | Description | Used By |
|---------|------|-----|------|-------------|---------|
| 0x405284 | varies | R | pixel_desc_a | Pixel descriptor A | Vec 49 ISR |
| 0x405288 | varies | R | pixel_desc_b | Pixel descriptor B | Vec 49 ISR |
| 0x405300 | 1 | R/W | encoder_enable | Encoder subsystem enable | Vec 19 ISR |
| 0x405301 | 1 | R/W | recv_diag_state | RECEIVE DIAGNOSTIC state | RECV DIAG handler |
| 0x405302 | 1 | R/W | scan_complete | Scan complete flag | ITU4 poll |
| 0x405306 | 1 | R/W | encoder_mode | Encoder operating mode | Encoder system |
| 0x40530A | 1 | R/W | encoder_state | Encoder state (0xD1=special mode) | Encoder ISR (0x33444) |
| 0x40530E | 2 | R/W | encoder_count | Encoder pulse count | Encoder ISR |
| 0x405314 | 2 | R/W | encoder_delta | Inter-pulse time delta (speed) | Encoder ISR |
| 0x405318 | 4 | R/W | encoder_timestamp | Timestamp of last encoder event | Encoder ISR |
| 0x40531A | 2 | R/W | encoder_last_capture | Previous timer capture value | Encoder ISR |
| 0x405342 | varies | R/W | chan_descriptors | Per-channel pixel descriptors (4 ch) | Scan pipeline |
| 0x4052D6 | 1 | R/W | dma_mode | ITU3 ISR dispatch mode (1/2/3/4/6) | ITU3 ISR (0x2D536) |
| 0x4052E2 | 2 | R/W | motor_step_count | Current step position | Motor control |
| 0x4052E4 | 2 | R/W | motor_target_pos | Target position for move | Motor, Vec 19 ISR |
| 0x4052E6 | 2 | R/W | motor_current_speed | Current timer period (speed) | Motor step engine |
| 0x4052E8 | 2 | R/W | motor_accel_index | Index into acceleration ramp table | Motor step engine |
| 0x4052EA | 1 | R/W | motor_enable | Motor enabled flag | Motor setup (0x2E158) |
| 0x4052EB | 1 | R/W | motor_running | Motor currently running flag | Motor, Vec 19 ISR |
| 0x4052EC | 1 | R/W | motor_state | Motor state machine variable | Motor, Vec 19 ISR |
| 0x4052ED | 1 | R/W | motor_direction | Motor direction (secondary) | Motor, Vec 19 ISR |
| 0x4052EE | 1 | R/W | scan_status | Buffer status (3=full, ready for USB) | ITU3/ITU4, Context B |
| 0x4052F0 | 1 | R/W | scan_status_ext | Extended scan status | Vec 49 ISR |
| 0x4052F1 | 1 | R/W | scan_active | Scan active flag | Vec 49 ISR |
| 0x4052F2 | 1 | R/W | scan_phase | Scan phase indicator | Vec 49 ISR |
| 0x4058FC | 2 | R/W | line_counter_isr | Line counter (ISR side) | Vec 49 ISR |
| 0x4062DA | varies | R/W | motor_coord_data | Motor coordination state | Context B (0x29B16) |
| 0x4062DC | 2 | R/W | channel_data_a | Channel data register A | Vec 49 ISR |
| 0x4062DD | 1 | R/W | channel_data_b | Channel data register B | Vec 49 ISR |
| 0x4062E6 | 1 | R/W | xfer_active | USB transfer in progress | ITU4 poll |
| 0x4062FC | 2 | R/W | diag_val_0 | Diagnostic value 0 | RECV DIAG handler |
| 0x4062FE | 2 | R/W | diag_val_1 | Diagnostic value 1 | RECV DIAG handler |
| 0x406300 | 2 | R/W | diag_val_2 | Diagnostic value 2 | RECV DIAG handler |
| 0x406304 | 2 | R/W | diag_val_3 | Diagnostic value 3 | RECV DIAG handler |
| 0x406306 | 2 | R/W | diag_val_4 | Diagnostic value 4 | RECV DIAG handler |
| 0x406308 | 2 | R/W | diag_val_5 | Diagnostic value 5 | RECV DIAG handler |
| 0x40630C | 2 | R/W | diag_val_6 | Diagnostic value 6 | RECV DIAG handler |
| 0x40630E | 2 | R/W | diag_val_7 | Diagnostic value 7 | RECV DIAG handler |
| 0x406310 | 2 | R/W | diag_val_8 | Diagnostic value 8 | RECV DIAG handler |
| 0x406314 | 2 | R/W | diag_val_9 | Diagnostic value 9 | RECV DIAG handler |
| 0x406316 | 2 | R/W | diag_val_10 | Diagnostic value 10 | RECV DIAG handler |
| 0x406318 | 2 | R/W | diag_val_11 | Diagnostic value 11 | RECV DIAG handler |
| 0x40631C | 2 | R/W | diag_val_12 | Diagnostic value 12 | RECV DIAG handler |
| 0x40631E | 2 | R/W | diag_val_13 | Diagnostic value 13 | RECV DIAG handler |
| 0x406320 | 2 | R/W | diag_val_14 | Diagnostic value 14 | RECV DIAG handler |
| 0x406324 | 2 | R/W | diag_val_15 | Diagnostic value 15 | RECV DIAG handler |
| 0x406326 | 2 | R/W | diag_val_16 | Diagnostic value 16 | RECV DIAG handler |
| 0x406328 | 2 | R/W | diag_val_17 | Diagnostic value 17 | RECV DIAG handler |
| 0x40632F | 1 | R | adapter_state | Adapter state indicator | Context B |
| 0x406338 | varies | R/W | dma_state_vars | DMA state variables | DEND0B ISR |
| 0x406370 | 4 | R/W | scan_desc_ptr | Scan descriptor pointer | ITU3 callback |
| 0x406374 | 2 | R/W | dma_burst_counter | DMA burst countdown counter | ITU3 ISR (0x2D536) |
| 0x4064E6 | 2 | R/W | lines_remaining | Remaining scan lines | Scan pipeline |
| 0x4064E8 | varies | R/W | dma_line_state | DMA per-line state | DEND0B ISR |
| 0x406DB6 | varies | R/W | channel_state | CCD channel state data | Vec 49 ISR |

### 3.17 Channel Descriptor Tables (0x406E3A-0x406E89)

| Address | Size | R/W | Name | Description | Used By |
|---------|------|-----|------|-------------|---------|
| 0x406E3A | 40 | R/W | chan_desc_a | Channel descriptor table A | Scan pipeline |
| 0x406E62 | 40 | R/W | chan_desc_b | Channel descriptor table B | Scan pipeline |

### 3.18 Exposure Parameters (0x407400-0x407699)

| Address | Size | R/W | Name | Description | Used By |
|---------|------|-----|------|-------------|---------|
| 0x4074DE | varies | R | exposure_param_a | Exposure parameter A | Exposure handler (0x4609C) |
| 0x4052A6 | varies | R | exposure_param_b | Exposure parameter B | Exposure handler |
| 0x407626 | varies | R | exposure_param_c | Exposure parameter C | Exposure handler |

### 3.19 USB Session State Block (0x407D00-0x407DFF)

| Address | Size | R/W | Name | Description | Used By |
|---------|------|-----|------|-------------|---------|
| 0x407D2E | 1 | R/W | usb_config_state | USB configuration (0=unconfigured) | USB state machine |
| 0x407D30 | 1 | R/W | usb_xfer_progress | USB transfer in progress | USB state machine |
| 0x407D32 | 1 | R/W | usb_ep_state | USB endpoint state | USB state machine |
| 0x407DC3 | 1 | R | usb_connection | USB connection state | Main loop |
| 0x407DC6 | 1 | R/W | cmd_phase | Current command phase | Response manager (0x1374A) |
| 0x407DC7 | 1 | R | usb_session | USB session state (2=connected+configured) | Main loop (0x207F2) |
| 0x407DC8 | 1 | R/W | usb_retry_counter | USB retry counter | USB state machine |
| 0x407DCC | varies | R/W | usb_xfer_req | USB transfer requirements | Task executor |
| 0x407DCE | varies | R/W | usb_xfer_config | USB transfer config | Task executor |
| 0x407DD2 | varies | R/W | scan_usb_state | Scan USB state block | SCAN handler |
| 0x407DD8 | 1 | R/W | ep_stall_flags | Endpoint stall flags | USB state machine |
| 0x407DD9 | 1 | R/W | int_mask_priority | Interrupt mask/priority | USB state machine |
| 0x407DDB | 1 | R/W | dma_state | USB DMA state | USB DMA |
| 0x407DDC | 1 | R/W | dma_direction | USB DMA direction | USB DMA |
| 0x407DDD | 1 | R/W | dma_complete | USB DMA completion flag | USB DMA |
| 0x407DDE | 1 | R/W | usb_reset_flag | USB bus reset flag | USB ISR |
| 0x407DE0 | 1 | R/W | usb_connected | USB connected flag | USB ISR |

### 3.20 Stack Areas

| Address | Size | Purpose |
|---------|------|---------|
| 0x40D000 | (grows down) | Context B stack base (USB data handler) |
| 0x40F800 | (grows down) | Initial SP after relocation from on-chip |
| 0x410000 | (grows down) | Context A stack base (main firmware loop) |

---

## 4. Custom ASIC Registers (0x200000-0x200FFF)

172 unique register addresses across 8 blocks. "Init" = written by I/O init table. "Runtime" = written by code at runtime. "Init-only" = set once during init, never modified.

### 4.1 Block 0x00 -- System Control (0x200000-0x2000C7)

| Address | Init Val | R/W | Purpose | Code Refs | Notes |
|---------|----------|-----|---------|-----------|-------|
| 0x200001 | 0x80 | W | Master enable/reset | USB reset, system init | Final init table entry |
| 0x200002 | — | R | Status register | DMA handler, 0x035DC8 | Bit 3 = DMA busy |
| 0x200003 | — | R/W | Status/control | Runtime | |
| 0x200008 | — | R/W | Interrupt config | Runtime | |
| 0x20000F | — | R/W | Interrupt mask/status | Runtime | |
| 0x200020 | — | R/W | DMA control | Runtime | |
| 0x200028 | — | R/W | DMA status | Runtime | |
| 0x200041 | — | R/W | RAM test reg A | RAM test (0x203BA) | |
| 0x200042 | — | R/W | RAM test reg B | RAM test | |
| 0x200044 | 0x00 | W | Control A | Init-only | |
| 0x200045 | 0x00 | W | Control B | Init-only | |
| 0x200046 | 0xFF | W | Mask register | Init-only | |
| 0x200053 | — | W | Static config | Init-only | Zero runtime refs |
| 0x20005A | — | W | Static config | Init-only | Zero runtime refs |
| 0x200069 | — | W | Static config | Init-only | Zero runtime refs |
| 0x20006B | — | W | Static config | Init-only | Zero runtime refs |
| 0x20006F | — | W | Static config | Init-only | Zero runtime refs |
| 0x20008C | — | W | Static config (triplet) | Init-only | Zero runtime refs |
| 0x20008D | — | W | Static config (triplet) | Init-only | Zero runtime refs |
| 0x20008E | — | W | Static config (triplet) | Init-only | Zero runtime refs |
| 0x2000AD | — | W | Static config (pair) | Init-only | Zero runtime refs |
| 0x2000AE | — | W | Static config (pair) | Init-only | Zero runtime refs |
| 0x2000C0 | 0x52 | W | DAC/ADC master config | Init + calibration | CCD AFE master |
| 0x2000C1 | 0x04 | W | DAC/ADC control | Init + calibration | |
| 0x2000C2 | — | R/W | **DAC mode** | 16 code refs | 0x20=init, 0x22=scan, 0xA2=cal |
| 0x2000C4 | — | R/W | ADC control | 0x293B7 | |
| 0x2000C6 | — | R | ADC readback | 0x27C67 | |
| 0x2000C7 | — | R/W | DAC fine control | Calibration | 0x08 (LS-50), 0x00 (LS-5000) |

### 4.2 Block 0x01 -- DMA/Motor/Timing (0x200100-0x2001CB)

| Address | Init Val | R/W | Purpose | Code Refs |
|---------|----------|-----|---------|-----------|
| 0x200100 | 0x3F | W | DMA ch0 source config | Init |
| 0x200101 | 0x3F | W | DMA ch0 dest config | Init |
| 0x200102 | 0x04 | W | **Motor DMA control** | 5 write sites in motor code |
| 0x200103 | 0x01 | W | DMA channel mode | Init |
| 0x200104 | 0x30 | W | DMA ch1 source | Init |
| 0x200105 | 0x32 | W | DMA ch1 dest | Init |
| 0x200106 | 0x34 | W | DMA ch2 source | Init |
| 0x200107 | 0x36 | W | DMA ch2 dest | Init |
| 0x20010C | 0x20 | W | DMA ch3 source | Init + runtime |
| 0x20010D | 0x22 | W | DMA ch3 dest | Init + runtime |
| 0x20010E | 0x24 | W | DMA ch4 source | Init + runtime |
| 0x20010F | 0x26 | W | DMA ch4 dest | Init + runtime |
| 0x200114 | 0x00 | W | DMA ch5 source | Init |
| 0x200115 | 0x08 | W | DMA ch5 dest | Init |
| 0x200116 | 0x10 | W | DMA ch6 source | Init |
| 0x200117 | 0x18 | W | DMA ch6 dest | Init |
| 0x200140 | 0x01 | W | DMA enable | Init |
| 0x200141 | 0x01 | W | DMA mode | Init |
| 0x200142 | 0x04 | W | DMA transfer config | Runtime (0x35C7E) |
| 0x200143 | 0x01 | W | Buffer control | Init |
| 0x200144 | 0x04 | W | Buffer mode | Init |
| 0x200147 | 0x00 | W | Buffer addr byte 0 | Runtime (0x35D58) |
| 0x200148 | 0x00 | W | Buffer addr byte 1 | Runtime |
| 0x200149 | 0x00 | W | Buffer addr byte 2 | Runtime |
| 0x20014B | 0x00 | W | Transfer count byte 0 | Runtime (0x35D92) |
| 0x20014C | 0x40 | W | Transfer count byte 1 | Runtime |
| 0x20014D | 0x00 | W | Transfer count byte 2 | Runtime |
| 0x20014E | 0x00 | W | DMA status | Runtime |
| 0x20014F | 0x04 | W | DMA control 2 | Init |
| 0x200150 | 0x03 | W | DMA interrupt enable | Init |
| 0x200152 | — | W | Ch2 coarse gain | Calibration |
| 0x200153 | — | W | Ch2 fine gain | Calibration |
| 0x200181 | 0x0D | W | **Motor drive config A** | 0x03581A, 0x0358F2 |
| 0x200182-189 | — | W | Motor drive channels A (4 pairs) | Motor code |
| 0x200193 | 0x0E | W | Motor drive config B | Init |
| 0x200194-19B | — | W | Motor drive channels B (4 pairs) | Motor code |
| 0x2001A4-A6 | — | W | Motor auxiliary config | Motor code |
| 0x2001C0 | 0x03 | W | Line timing mode | Init |
| 0x2001C1 | 0x00 | W | Line timing control | Runtime (0x3C274), Vec 49 ISR |
| 0x2001C2 | 0x0F | W | Pixel clock divider | Init |
| 0x2001C3 | 0x98 | W | Line period low | Init |
| 0x2001C4 | 0x00 | W | Line period high | Init |
| 0x2001C5 | 0x19 | W | Integration start | Init |
| 0x2001C6 | 0x0F | W | Integration config | Init |
| 0x2001C7 | 0x69 | W | Integration end | Init |
| 0x2001C8 | 0x00 | W | Readout start | Init |
| 0x2001C9 | 0x18 | W | Readout config | Init |
| 0x2001CA | — | W | Cal config 1 | Calibration routines |
| 0x2001CB | — | W | Cal config 2 | Calibration routines |

### 4.3 Block 0x02 -- CCD Data Channels (0x200200-0x20026D)

| Address | Init Val | Purpose |
|---------|----------|---------|
| 0x200200 | 0x00 | Channel master config |
| 0x200204 | 0x04 | Ch0 (Red) config |
| 0x200205 | 0x03 | Ch0 mode |
| 0x200214-215 | — | Ch0 pair B |
| 0x20021C-21D | — | Ch1 (Green) config |
| 0x200224-225 | — | Ch1 pair B |
| 0x20022C-22D | — | Ch2 (Blue) config |
| 0x200255 | — | Ch2 extended |
| 0x20025D | — | Ch3 (IR) config |
| 0x200265 | — | Ch3 extended |
| 0x20026D | — | Channel master extended |

### 4.4 Block 0x04 -- CCD Timing/Gain (0x200400-0x200487)

| Address | Init Val | Purpose |
|---------|----------|---------|
| 0x200400 | 0x20 | CCD master mode |
| 0x200401 | 0x0A | CCD pixel clock config |
| 0x200402 | 0x00 | CCD control |
| 0x200404 | 0x00 | CCD config A |
| 0x200405 | 0xFF | CCD data mask (all bits active) |
| 0x200406 | 0x01 | CCD enable |
| 0x200408-40D | grp1 | Integration timing group 1 (transfer gate) |
| 0x20040E-413 | grp2 | Integration timing group 2 (integration window) |
| 0x200414-419 | grp3 | Integration timing group 3 (second integration) |
| 0x20041A-41F | grp4 | Integration timing group 4 (readout timing) |
| 0x200420-425 | grp5 | Integration timing group 5 (reset/clamp timing) |
| 0x200456 | 0x00 | Gain channel select |
| 0x200457 | 0x63 | **Analog gain ch1** (99 decimal) -- init-only |
| 0x200458 | 0x63 | **Analog gain ch2** (99 decimal) -- init-only |
| 0x20046D-46F | 00/01/2B | Per-ch0 (Red) timing |
| 0x200475-477 | 00/01/2B | Per-ch1 (Green) timing |
| 0x20047D-47F | 00/01/2B | Per-ch2 (Blue) timing |
| 0x200485-487 | 00/01/2B | Per-ch3 (IR) timing |

### 4.5 Blocks 0x09-0x0F -- Static Config (init-only, zero runtime refs)

| Address | Block | Purpose |
|---------|-------|---------|
| 0x200910 | 0x09 | Static ASIC config |
| 0x200A81 | 0x0A | Static ASIC config |
| 0x200A8C | 0x0A | Static ASIC config |
| 0x200AE0 | 0x0A | Static ASIC config |
| 0x200AF2 | 0x0A | Static ASIC config |
| 0x200C82 | 0x0C | Static ASIC config |
| 0x200F20 | 0x0F | Static ASIC config |
| 0x200F60 | 0x0F | Static ASIC config |
| 0x200FA0 | 0x0F | Static ASIC config |
| 0x200FC0 | 0x0F | Static ASIC config |

---

## 5. ISP1581 USB Controller (0x600000-0x6000FF)

| H8 Address | ISP1581 Offset | Register Name | R/W | Purpose | Code Refs |
|-----------|----------------|--------------|-----|---------|-----------|
| 0x600008 | 0x08 | Interrupt Status | R/W | Read + bit-modify for interrupt handling | 0x148E8 |
| 0x60000C | 0x0C | Mode Register | R/W | Bit 4 (SOFTCT): USB soft-connect | 0x139C0, 0x14E1A |
| 0x600018 | 0x18 | DMA Configuration | W | DMA direction/mode setup | 0x13C74, 0x13F72, 0x14004, 0x14F00 |
| 0x60001C | 0x1C | Endpoint Index/Count | W | Select endpoint, set byte count | 0x122CC, 0x1230C |
| 0x600020 | 0x20 | Endpoint Data Port | R/W | Bulk data read/write (16-bit) | 0x12260, 0x122A4, 0x122D4, 0x12314, 0x1500C |
| 0x60002C | 0x2C | DMA Mode Config | W | DMA mode selection (mode 5 = bulk) | USB DMA setup |
| 0x600084 | 0x84 | DMA Transfer Count | W | Transfer byte count | 0x15170 |

ISP1581 is little-endian; H8/3003 is big-endian. The firmware performs byte-swapping in read/write endpoint functions (0x12258/0x122C4).

---

## 6. ASIC RAM (0x800000-0x83FFFF)

224KB accessible via firmware validation table. Used for CCD line buffers and scan data staging.

| Bank | Address | Size | Purpose |
|------|---------|------|---------|
| 1 | 0x800000 | 32KB | CCD line buffer, DMA target |
| 2 | 0x808000 | 32KB | CCD line buffer |
| 3 | 0x810000 | 32KB | CCD line buffer |
| 4 | 0x818000 | 32KB | Pixel processing secondary |
| 5-16 | 0x820000-0x837FFF | 12x8KB | Per-channel/per-line buffers |
| — | 0x838000-0x83FFFF | 32KB | BSC-mapped, boundary marker only |

Code reference 0x838000 at `FW:0x3E2E4` -- used as boundary marker, not data storage.

---

## 7. Buffer RAM (0xC00000-0xC0FFFF)

64KB, used for USB transfer staging with ping-pong buffering.

| Bank | Address | Size | Purpose |
|------|---------|------|---------|
| A | 0xC00000 | 32KB | Active scan data / calibration data |
| B | 0xC08000 | 32KB | Secondary calibration / ping-pong alternate |

Referenced by calibration routines (0x3E265, 0x3F631, 0x3FFDF) and scan pipeline.

---

## 8. H8/3003 On-Chip I/O Registers (0xFFFF20-0xFFFFFF)

### 8.1 Integrated Timer Unit (ITU)

| Address | Name | Init | Purpose |
|---------|------|------|---------|
| 0xFFFF60 | TSTR | 0xE0 | Timer start (bit 0=ITU0, 1=ITU1, 2=ITU2, 3=ITU3, 4=ITU4) |
| 0xFFFF62 | TCR0 | 0x98 | ITU0 timer control |
| 0xFFFF64 | TIOR0 | 0xA0 | ITU0 timer I/O control |
| 0xFFFF6E | TCR2 | 0xC1 | ITU2 timer control (motor timer) |
| 0xFFFF78 | TCR3 | 0xA3 | ITU3 timer control (DMA coordination) |
| 0xFFFF82 | TCR4 | 0xA3 | ITU4 timer control (system tick) |
| 0xFFFF92 | TOCR | 0xA0 | Timer output control |
| 0xFFFF95 | TSR4 | — | ITU4 timer status (read by system tick ISR) |

### 8.2 GPIO Ports

| Address | Name | Init | Direction | Purpose | Refs |
|---------|------|------|-----------|---------|------|
| 0xFFFF80 | P1DR | — | Mixed | General I/O | — |
| 0xFFFF82 | P3DDR | — | — | Port 3 direction | — |
| 0xFFFF84 | P3DR | — | — | Motor direction (bit 0) | 11 refs (motor code) |
| 0xFFFF85 | P4DDR | — | — | **Lamp control** (bit 0: BCLR=ON, BSET=OFF) | 6 refs (lamp code) |
| 0xFFFF86 | P4DR | — | — | Cleared after lamp ops | Lamp pattern |
| 0xFFFF8E | P7DR | — | Input | **Adapter detection** (16 reads, 14 in SCAN handler) | Adapter ID |
| 0xFFFFA3 | PADR | — | Output | **Motor stepper output** (phase values 01/02/04/08) | 44 refs (22R/22W) |
| 0xFFFFC8 | P9DR | — | Mixed | Motor encoder input (7R) + stepper phase (5W) | Motor/scan |

### 8.3 DMA Controller

| Address | Name | Purpose |
|---------|------|---------|
| 0xFFFF90 | DMAOR | DMA operation register (init: 0xC0) |
| 0xFFFF2F | DTCR0B | DMA ch0 transfer control (bit 3 cleared by DEND0B ISR) |

### 8.4 Serial Communication Interface (SCI)

| Address | Name | Init | Purpose |
|---------|------|------|---------|
| 0xFFFFC9 | SCI0_BRR | 0x80 | SCI0 baud rate |
| 0xFFFFCB | SCI0_SMR | 0x80 | SCI0 serial mode (async 8N1) |
| 0xFFFFCD | SCI1_BRR | 0xF4 | SCI1 baud rate |
| 0xFFFFCF | SCI1_SMR | 0xE0 | SCI1 serial mode |

SCI is polled, not interrupt-driven (all SCI vectors inactive).

### 8.5 Bus State Controller (BSC)

| Address | Name | Init | Purpose |
|---------|------|------|---------|
| 0xFFFFF2 | ABWCR | 0x0B | Bus width per area (8/16-bit) |
| 0xFFFFF3 | ASTCR | 0x00 | Access state control |
| 0xFFFFF4 | WCR | 0xBA | Wait state configuration |
| 0xFFFFF5 | WCER | 0x00 | Wait control enable |
| 0xFFFFF6 | BRDR | — | Bus release data (modified for USB DMA) |
| 0xFFFFF8 | BRCR | 0x00 | Bus release control |
| 0xFFFFF9 | CSCR | 0x30 | Chip select control |

### 8.6 Port Direction Registers (DDR)

| Address | Name | Init | Purpose |
|---------|------|------|---------|
| 0xFFFFD0 | P3DR | 0xC3 | Port 3 initial data |
| 0xFFFFD1 | P4DR | 0xFF | Port 4 initial data |
| 0xFFFFD2 | P5DDR | 0xC0 | Port 5 direction |
| 0xFFFFD3 | P6DDR | 0x3F | Port 6 direction |
| 0xFFFFD4 | P7DDR | 0xFF | Port 7 direction (all outputs for bus address) |
| 0xFFFFD5 | P8DDR | 0x01 | Port 8 direction (bit 0 output) |
| 0xFFFFD6 | P9DDR | 0x00 | Port 9 direction (all inputs) |
| 0xFFFFD7 | PADDR | 0x01 | Port A direction (bit 0 output for motor enable) |
| 0xFFFFEC | P1DDR | 0x85 | Port 1 direction |
| 0xFFFFED | P2DDR | 0xFF | Port 2 direction (all outputs) |
| 0xFFFFEE | P3DDR | 0xF1 | Port 3 direction |
| 0xFFFFEF | P4DDR | 0x48 | Port 4 direction |

### 8.7 Watchdog Timer

| Address | Name | Purpose |
|---------|------|---------|
| 0xFFFFA8 | WDT_TCSR | Watchdog timer (write 0x5A00 to reset) |

### 8.8 A/D Converter

| Address | Name | Purpose |
|---------|------|---------|
| 0xFFFFE8 | ADCSR | A/D control/status (bit 7 = ADF flag, tested by ADI ISR) |

---

## 9. On-Chip RAM (0xFFFD00-0xFFFD4F)

Used for interrupt trampolines and boot state.

| Address | Size | Purpose |
|---------|------|---------|
| 0xFFFD10 | 4 | Trampoline: TRAP #0 -> JMP 0x010876 |
| 0xFFFD14 | 4 | Trampoline: IRQ3 -> JMP 0x033444 |
| 0xFFFD18 | 4 | Trampoline: IRQ4/5 -> JMP 0x014D4A |
| 0xFFFD1C | 4 | Trampoline: ITU2 CmpA -> JMP 0x010B76 |
| 0xFFFD20 | 4 | Trampoline: ITU3 CmpA -> JMP 0x02D536 |
| 0xFFFD24 | 4 | Trampoline: ITU4 CmpA -> JMP 0x010A16 |
| 0xFFFD28 | 4 | Trampoline: DEND0B -> JMP 0x02CEF2 |
| 0xFFFD2C | 4 | Trampoline: DEND1B -> JMP 0x02E10A |
| 0xFFFD30 | 4 | Trampoline: Vec49 -> JMP 0x02E9F8 |
| 0xFFFD34 | 4 | Trampoline: ADI -> JMP 0x02EDDE |
| 0xFFFD38 | 4 | Trampoline: IRQ7 -> JMP 0x02B544 |
| 0xFFFD3C | 4 | Trampoline: IRQ1 -> JMP 0x014E00 |
| 0xFFFD4C | 1 | Boot state flag (0=normal, 1=warm restart) |
| 0xFFFD4D | 1 | Saved state byte (from 0x4006B2) |
| 0xFFFD4E | 1 | Saved state byte (from 0x4006B3) |
| 0xFFFD50 | 8 | Saved state block (from 0x4006B4, erased in current flash) |

---

## Cross-References

- [firmware-data-tables.md](firmware-data-tables.md) -- All data table decodes
- [firmware-memory-map.h](firmware-memory-map.h) -- C header with all #defines
- [Memory Map (KB)](../reference/memory-map.md) -- Original KB memory map
- [ASIC Registers (KB)](../components/firmware/asic-registers.md) -- ASIC register details
- [ISP1581 USB (KB)](../components/firmware/isp1581-usb.md) -- USB register details
- [Main Loop (KB)](../components/firmware/main-loop.md) -- RAM variable usage
- [Motor Control (KB)](../components/firmware/motor-control.md) -- Motor RAM variables
- [Scan Pipeline (KB)](../components/firmware/scan-pipeline.md) -- Pipeline state variables
