# SCSI Command Sequences -- Complete Protocol Reference

**Status**: Complete
**Last Updated**: 2026-03-12
**Phase**: 5 (Protocol Spec)
**Confidence**: Verified (cross-validated host DLLs, firmware, scan operation vtables, Ghidra decompilations)

## Purpose

This document specifies the **exact SCSI command sequences** for every scanner operation on the Nikon Coolscan V (LS-50) and Super Coolscan 5000 ED (LS-5000). A developer reading this document should be able to implement a working scanner driver from scratch.

All CDB bytes are verified from LS5000.md3 CDB builder functions (Phase 2) and firmware handler dispatch (Phase 4). Sequences are verified from the scan operation vtable architecture (Phase 3).

---

## Table of Contents

1. [USB Transport Layer](#1-usb-transport-layer)
2. [Scanner Initialization](#2-scanner-initialization)
3. [Film Adapter Detection](#3-film-adapter-detection)
4. [Film Loading and Positioning](#4-film-loading-and-positioning)
5. [Autofocus Sequence](#5-autofocus-sequence)
6. [Preview Scan](#6-preview-scan)
7. [Final Scan (Full Resolution)](#7-final-scan-full-resolution)
8. [Multi-Sampling Scan](#8-multi-sampling-scan)
9. [Calibration Sequence](#9-calibration-sequence)
10. [Film Eject](#10-film-eject)
11. [Error Recovery](#11-error-recovery)
12. [Complete CDB Reference](#12-complete-cdb-reference)
13. [Firmware State Machine](#13-firmware-state-machine)

---

## 1. USB Transport Layer

### 1.1 Device Identification

| Field | Value |
|-------|-------|
| VID | `0x04B0` (Nikon Corporation) |
| PID | `0x4001` (LS-50) or `0x4002` (LS-5000) |
| Device Class | `0xFF/0xFF/0xFF` (vendor-specific) |
| Endpoints | EP1 OUT `0x01` Bulk, EP2 IN `0x82` Bulk |
| Max Packet | 64 bytes (USB 1.1), 512 bytes (USB 2.0) |
| Power | Self-powered (`bmAttributes=0xC0`) |

The scanner uses a **custom vendor protocol**, NOT USB Mass Storage (UMS/BOT). There are no CBW/CSW wrappers. CDBs are sent raw on the bulk-out pipe.

Source: Firmware USB descriptors at `FW:0x170FA` (USB 1.1) and `FW:0x1710C` (USB 2.0)

### 1.2 Command Execution Protocol

Every SCSI command follows this exact sequence on the USB bus:

```
Step  Direction  Pipe      Content                Size
----  ---------  --------  ---------------------  ----
 1    Host->Dev  Bulk-OUT  Raw CDB bytes          6 or 10 bytes (padded to 32)
 2    Host->Dev  Bulk-OUT  Phase query opcode      1 byte: 0xD0
 3    Dev->Host  Bulk-IN   Phase response byte     1 byte: 0x01, 0x02, or 0x03
 4a   Dev->Host  Bulk-IN   Data-in payload         N bytes (if phase == 0x03)
 4b   Host->Dev  Bulk-OUT  Data-out payload        N bytes (if phase == 0x02)
 4c   (none)     (none)    (skip data phase)       (if phase == 0x01)
 5    Host->Dev  Bulk-OUT  Sense request opcode    1 byte: 0x06
 6    Dev->Host  Bulk-IN   Sense data              18 bytes (fixed format)
```

Source: `NKDUSCAN.dll:0x10002b50` (CUSB2Command::virtual_12)

### 1.3 Phase Byte Values

| Phase | Meaning | Host Action |
|-------|---------|-------------|
| `0x01` | No data / status only | Skip to sense retrieval |
| `0x02` | Data-out (host -> scanner) | WriteFile on bulk-out pipe |
| `0x03` | Data-in (scanner -> host) | ReadFile on bulk-in pipe |

### 1.4 CDB Padding

All CDBs are sent as 32 bytes on the bulk-out pipe, regardless of actual CDB length (6 or 10). Unused bytes are zero-padded. The firmware reads CDB bytes from RAM at `0x4007DE`.

For 64-byte CDBs (rare), `DeviceIoControl(IOCTL_SEND_USB_REQUEST = 0x80002008)` is used instead of bulk pipe I/O.

### 1.5 Data Transfer Chunking

For data-in transfers (phase `0x03`), the host reads data in chunks:

1. First read: attempt full `transfer_length` bytes
2. If fewer bytes received, use actual count as chunk size for subsequent reads
3. Continue until `transfer_length` total bytes received

This allows the scanner to pace data delivery through its internal buffer.

Source: `NKDUSCAN.dll:0x10002c46-0x10002c98`

### 1.6 Sense Data Format (18 bytes)

Built by firmware subroutine at `FW:0x0111F4` from the sense translation table at `FW:0x16DEE` (148 entries, 5 bytes each):

| Byte | Field | Source |
|------|-------|--------|
| 0 | Response Code | `0x70` (current) or `0xF0` (deferred) |
| 1 | Segment Number | 0 |
| 2 | Sense Key | From table (0x00-0x0B), OR `0x20` if ILI |
| 3-6 | Information | From RAM `0x4007A0` (conditional) |
| 7 | Additional Sense Length | `0x0B` (always 11) |
| 8-11 | Command-Specific Info | 0 |
| 12 | ASC | From table |
| 13 | ASCQ | From table |
| 14-15 | Sense Key Specific | From RAM `0x4007A4` (conditional) |
| 16 | FRU | From table |
| 17 | Reserved | 0 |

Good status: all-zero sense data (sense key = 0x00, ASC = 0x00, ASCQ = 0x00).

### 1.7 Error Codes from Transport Layer

| Code | Meaning |
|------|---------|
| `0x00000000` | Success |
| `0x00011003` | Protocol error (unexpected phase byte) |
| `0x00021008` | Bulk I/O error (ReadFile/WriteFile failed) |

---

## 2. Scanner Initialization

### 2.1 Overview

Scanner initialization is handled by the **Base/Type A Phase A** vtable in LS5000.md3. The factory function at `0x100AF1F0` (958 bytes) creates command objects for each step. The handler at `0x100B3060` (983 bytes) processes results and dynamically inserts additional steps based on scanner state.

### 2.2 SCSI Command Sequence

```
Step  Command          CDB Bytes (hex)                             Dir    Data
----  ---------------  ------------------------------------------  -----  ----
 1    TEST UNIT READY  00 00 00 00 00 00                           None   --
 2    INQUIRY          12 00 00 00 24 80                           In     36+ bytes
 3    RESERVE          16 00 00 00 00 00                           None   --
 4    MODE SELECT      15 10 00 00 14 00                           Out    20 bytes
 5    SEND DIAGNOSTIC  1D 04 00 00 00 00                           None   --
 6    GET WINDOW       25 XX XX XX XX 00 LL LL LL 00               In     ~80+ bytes
 7    READ (cal data)  28 00 88 00 00 QQ LL LL LL 80               In     up to 644 bytes
```

### 2.3 Step-by-Step Detail

#### Step 1: TEST UNIT READY

**Purpose**: Verify scanner is powered on and responsive.

```
CDB: 00 00 00 00 00 00
Direction: None
Data: None
```

The host polls TUR repeatedly until the scanner returns Good status. Typical sense codes during startup:

| Sense | SK/ASC/ASCQ | Meaning | Action |
|-------|-------------|---------|--------|
| 0x07 | 02/04/01 FRU=00 | General startup | Retry after 500ms |
| 0x08 | 02/04/01 FRU=01 | USB/ISP1581 initializing | Retry after 500ms |
| 0x09 | 02/04/01 FRU=02 | Encoder calibrating | Retry after 500ms |
| 0x5C | 06/29/00 | Power-on reset | Clear UA, retry |

The firmware handler at `FW:0x0215C2` checks the scanner state byte at `@0x40077C`:
- `0x00` = idle/ready (returns Good)
- `0xF0` = sensor error
- `0xF1` = motor error
- `0xF3` = motor busy (positioning)
- `0xF4` = calibration in progress

**Timing**: Allow up to 30 seconds for scanner power-up. Poll every 500ms.

#### Step 2: INQUIRY

**Purpose**: Identify scanner model and firmware version.

```
CDB: 12 00 00 00 24 80
     |  |  |  |  |  |
     |  |  |  |  |  +-- Control: 0x80 (Nikon vendor flag)
     |  |  |  |  +----- Allocation length: 36 bytes
     |  |  |  +-------- Reserved
     |  |  +----------- Page code: 0 (standard INQUIRY)
     |  +-------------- EVPD: 0 (standard, not VPD)
     +----------------- Opcode: INQUIRY
Direction: Data-in
Data: 36+ bytes standard INQUIRY response
```

Expected response (36 bytes):

| Offset | Length | Field | Expected Value |
|--------|--------|-------|----------------|
| 0 | 1 | Device Type | `0x06` (scanner) |
| 1 | 1 | RMB | 0 |
| 2 | 1 | Version | 2 (SPC) |
| 3 | 1 | Response Format | 2 |
| 4 | 1 | Additional Length | 31 |
| 8-15 | 8 | Vendor | `"Nikon   "` (space-padded) |
| 16-31 | 16 | Product | `"LS-50 ED        "` or `"LS-5000 ED      "` |
| 32-35 | 4 | Revision | `"1.02"` |

The product string determines which .md3 module the host loads. The `0x80` control byte is a Nikon vendor extension.

Source: Firmware response string at `FW:0x49E31`

#### Step 3: RESERVE

**Purpose**: Claim exclusive scanner access, prevent power-save mode.

```
CDB: 16 00 00 00 00 00
Direction: None
Data: None
```

Sets an internal "session active" flag in the firmware. Permission flags `0x07CC` restrict this command from being called during active scan/data transfer states.

No RELEASE (0x17) is ever sent by NikonScan -- the reservation is implicitly cleared on USB disconnect.

#### Step 4: MODE SELECT

**Purpose**: Configure scanner operating mode (resolution limits, scan area).

```
CDB: 15 10 00 00 14 00
     |  |  |  |  |  |
     |  |  |  |  |  +-- Control: 0
     |  |  |  |  +----- Parameter list length: 20 bytes (0x14)
     |  |  |  +-------- Reserved
     |  |  +----------- Reserved
     |  +-------------- Flags: 0x10 (PF=1, page format)
     +----------------- Opcode: MODE SELECT
Direction: Data-out
Data: 20-byte mode parameter block
```

Data payload structure (20 bytes):

```
Offset  Length  Field
0x00    4       Mode parameter header
0x04    2       Page code (0x03) + page length (6)
0x06    2       Base resolution (big-endian)
0x08    2       Max X dimension (big-endian)
0x0A    2       Max Y dimension (big-endian)
0x0C    8       Reserved/padding
```

Firmware handler at `FW:0x02194A` stores data at `@0x400DAA`.

#### Step 5: SEND DIAGNOSTIC

**Purpose**: Run hardware self-test or state-dependent calibration.

```
CDB: 1D 04 00 00 00 00
     |  |
     |  +-- Flags: 0x04 (SelfTest=1)
     +------- Opcode: SEND DIAGNOSTIC
Direction: None
Data: None
```

**Critical insight**: NikonScan always sends byte[1]=0x04 (SelfTest=1), but the firmware's action depends on the scanner's **current internal state**, not the CDB parameters:

| Scanner State | Firmware Action |
|--------------|-----------------|
| Just initialized | Hardware self-test (lamp, motor, CCD) |
| Pre-scan | Pre-scan calibration |
| Post-scan | Cleanup, lamp-off |
| Ejecting | Motor control for film transport |

The init handler at `FUN_100b3060` dynamically inserts SEND_DIAG steps after processing TUR results if adapter state requires it.

#### Step 6: GET WINDOW

**Purpose**: Read scanner's current window descriptor to discover supported vendor extensions.

```
CDB: 25 XX XX XX XX 00 LL LL LL 00
     |                    |  |  |
     |                    +--+--+-- Transfer length (big-endian, 24-bit)
     +-- Opcode: GET WINDOW
Direction: Data-in
Data: Window parameter header (8 bytes) + window descriptor (variable)
```

**This is the key mechanism for vendor extension discovery.** During initialization, the host:

1. Sends GET WINDOW to read the scanner's default window descriptor
2. Parses feature flags in the response (bit-packed bytes at specific offsets)
3. For each supported feature, registers a vendor extension parameter
4. Data sizes (1, 2, or 4 bytes per param) come from the scanner, not the host

Source: `LS5000.md3:0x100A2980` (init parser, 2589 bytes)

The response includes the standard SCSI-2 Scanner window fields plus up to 12 Nikon vendor extension parameters (IDs 0x102-0x10d) and ICE/DRAG extension data.

#### Step 7: READ -- Calibration Data

**Purpose**: Read per-channel calibration boundary data.

```
CDB: 28 00 88 00 00 QQ LL LL LL 80
     |     |        |  |  |  |  |
     |     |        |  +--+--+-- Transfer length (big-endian)
     |     |        +----------- Qualifier: 0-3 (0=all, 1=R, 2=G, 3=B)
     |     +-------------------- Data Type Code: 0x88 (boundary/cal data)
     +-- Opcode: READ(10)
Direction: Data-in
Data: Up to 644 bytes of calibration boundary data
```

The init handler also reads DTC 0x91 (adapter-specific data) during this phase.

### 2.4 Init Sequence Timing Diagram

```
Host                                    Scanner
  |                                       |
  |--- TUR [00 00 00 00 00 00] -------->|
  |<-- Phase query (D0) + response ------|
  |<-- Sense: 02/04/01 (becoming ready) -|  (scanner still initializing)
  |           ... wait 500ms ...          |
  |--- TUR [00 00 00 00 00 00] -------->|
  |<-- Sense: 00/00/00 (good) ----------|  (scanner ready)
  |                                       |
  |--- INQUIRY [12 00 00 00 24 80] ---->|
  |<-- 36 bytes: "Nikon   LS-50 ED" ----|
  |                                       |
  |--- RESERVE [16 00 00 00 00 00] ---->|
  |<-- Sense: good --------------------- |
  |                                       |
  |--- MODE SELECT [15 10 00 00 14 00] ->|
  |--- Data-out: 20 bytes mode page ---->|
  |<-- Sense: good ----------------------|
  |                                       |
  |--- SEND DIAG [1D 04 00 00 00 00] --->|
  |<-- Sense: good ----------------------|  (self-test passed)
  |                                       |
  |--- GET WINDOW [25 ...] ------------>|
  |<-- 80+ bytes window descriptor ------|
  |                                       |
  |--- READ [28 00 88 00 00 03 ...] ---->|
  |<-- 644 bytes boundary data ----------|
  |                                       |
  |  === INIT COMPLETE ===                |
```

---

## 3. Film Adapter Detection

### 3.1 Overview

Film adapters are detected automatically by the firmware via GPIO Port 7 (`0xFFFF8E`). The scanner supports 8 adapter types (indices 0-7). Detection happens on the firmware side; the host discovers the adapter through INQUIRY VPD pages.

### 3.2 Detection Sequence

```
Step  Command                    CDB Bytes (hex)                     Dir
----  -------------------------  ----------------------------------  -----
 1    TEST UNIT READY            00 00 00 00 00 00                   None
 2    INQUIRY (VPD page 0x00)    12 01 00 00 FF 00                   In
 3    INQUIRY (adapter VPD)      12 01 PP 00 FF 00                   In
```

#### Step 1: TUR -- Check for Unit Attention

After inserting or removing a film adapter, the scanner sets a UNIT ATTENTION condition:

| Sense | SK/ASC/ASCQ | Meaning |
|-------|-------------|---------|
| 0x61 | 06/3F/03 | INQUIRY data has changed (adapter swap detected) |

The host must clear this by issuing any command (typically TUR).

#### Step 2: INQUIRY with EVPD -- Supported Pages

```
CDB: 12 01 00 00 FF 00
     |  |  |  |  |
     |  |  |  |  +-- Allocation length: 255
     |  |  |  +----- Reserved
     |  |  +-------- Page code: 0x00 (supported VPD page list)
     |  +----------- EVPD: 1 (request VPD data)
     +-------------- Opcode: INQUIRY
Direction: Data-in
Data: List of supported VPD page codes
```

The response lists which VPD pages are available. Pages vary by adapter type:

| Adapter | Available VPD Pages |
|---------|-------------------|
| (none/bare mount) | 0xF8, 0xFA, 0xFB, 0xFC |
| SA-21 (Mount) | 0x46 |
| SF-210 (Strip) | 0x43, 0x44, 0xE2 |
| IA-20 (APS/240) | 0x45, 0xF1 |
| SA-30 (Feeder) | 0x46, 0xE2 |
| SF-210 (6Strip mode) | 0x47, 0xE2 |
| SF-210 (36Strip mode) | 0x10 |
| (Test jig -- factory only) | (none) |

#### Step 3: INQUIRY with Adapter-Specific VPD Page

```
CDB: 12 01 PP 00 FF 00
              |
              +-- Page code: adapter-specific (0x43, 0x46, etc.)
Direction: Data-in
Data: Adapter VPD data (film holder type, frame positions, etc.)
```

The firmware dispatches VPD pages through the adapter-specific VPD table at `FW:0x49C74` (8 adapters x 5 entries x 6 bytes). Standard VPD pages (0x00, 0x01, 0x10, 0x40-0x41, 0x50-0x52) are always available at `FW:0x49C20`.

Special case: VPD page 0xC1 is handled before table lookup, returning `[page_code, 0, 2, 0, 0xC1]`.

### 3.3 Adapter-Specific VPD Data

VPD pages return data about the film holder:

| VPD Page | Content | Adapters |
|----------|---------|----------|
| 0x43 | Strip film frame positions | Strip |
| 0x44 | Strip film geometry | Strip |
| 0x45 | 240/APS cartridge parameters | 240 |
| 0x46 | Slide mount dimensions | Mount, Feeder |
| 0x47 | 6-frame strip parameters | 6Strip |
| 0xE2 | Extended adapter capabilities | Strip, Feeder, 6Strip |
| 0xF1 | APS film roll info | 240 |
| 0xF8-0xFC | Scanner base capabilities (no adapter) | (none) |

Film holder strings: `"FH-3"` (standard), `"FH-G1"` (glass), `"FH-A1"` (medical). These appear in the VPD response for the corresponding adapter.

Source: Firmware string table at `FW:0x49E30`-`0x49E88`, VPD dispatch at `FW:0x49C74`

---

## 4. Film Loading and Positioning

### 4.1 Overview

Film positioning is controlled through the SCSI SCAN command (opcode 0x1B) with operation code 4 (move to position) and through vendor commands E0/C1 for motor control.

### 4.2 Motor Positioning via SCAN

```
CDB: 1B 00 00 00 01 00
     |              |
     |              +-- Transfer length: 1 (window ID list size)
     +-- Opcode: SCAN
Direction: Data-out
Data: 1 byte -- window ID specifying target position
```

The SCAN handler at `FW:0x0220B8` supports operation code 4 (move to position), which dispatches motor task `0x0440` (relative move).

### 4.3 Motor Positioning via Vendor Commands

For precise positioning, the host uses the E0/C1 pattern:

```
Step  Command   CDB Bytes                           Sub-cmd  Dir
----  --------  -----------------------------------  -------  -----
 1    E0        E0 00 44 00 00 00 00 00 05 00        0x44     Out
 2    C1        C1 00 00 00 00 00                     --       None
 3    E1        E1 00 44 00 00 00 00 00 05 00        0x44     In
```

#### E0 -- Write Motor Position Target

```
CDB: E0 00 44 00 00 00 00 00 05 00
     |     |              |  |  |
     |     |              +--+--+-- Transfer length: 5 bytes
     |     +-------------------- Sub-command: 0x44 (motor position)
     +-- Opcode: Vendor E0
Direction: Data-out
Data: 5 bytes motor position payload
```

Motor position payload:

| Byte | Field | Values |
|------|-------|--------|
| 0 | Motor selector | 0x01=scan motor, 0x02=AF motor |
| 1 | Operation mode | Step count multiplier |
| 2 | Direction/flags | Bit 0=direction, bits 4-7=speed profile |
| 3-4 | Step count | 16-bit big-endian step count |

#### C1 -- Trigger Motor Movement

```
CDB: C1 00 00 00 00 00
Direction: None
```

The C1 handler at `FW:0x028B08` reads the sub-command from `@0x400D63` (set by E0) and dispatches to the motor subsystem. Sub-command 0x44 triggers motor positioning.

#### E1 -- Read Current Motor Position

```
CDB: E1 00 44 00 00 00 00 00 05 00
Direction: Data-in
Data: 5 bytes -- current motor position readback
```

### 4.4 Complete Film Load Sequence

```
Host                                    Scanner
  |                                       |
  |--- TUR [00 00 00 00 00 00] -------->|
  |<-- Good ----------------------------|
  |                                       |
  |--- E0 [E0 00 91 00 00 00 00 00 05 00]|  (motor step command)
  |--- Data-out: 5 bytes motor params -->|
  |<-- Good ----------------------------|
  |                                       |
  |--- C1 [C1 00 00 00 00 00] --------->|  (trigger motor)
  |<-- Good ----------------------------|
  |                                       |
  |--- TUR [00 00 00 00 00 00] -------->|  (poll until motor done)
  |<-- Sense: 02/04/01 FRU=03 ----------|  (motor busy)
  |           ... wait 200ms ...          |
  |--- TUR [00 00 00 00 00 00] -------->|
  |<-- Good ----------------------------|  (motor done)
  |                                       |
  |--- E1 [E1 00 44 00 00 00 00 00 05 00]|  (read position)
  |<-- 5 bytes: current position --------|
  |                                       |
  |  === FILM IN POSITION ===             |
```

---

## 5. Autofocus Sequence

### 5.1 Overview

Autofocus is **host-driven**. The firmware provides only basic AF motor positioning commands. The contrast-based autofocus algorithm runs entirely in NikonScan -- it reads CCD image data, computes contrast metrics, and sends individual AF motor position commands until optimal focus is achieved. The firmware has no autonomous focus search loop.

This is implemented by the **Type C** scan operation vtable in LS5000.md3.

### 5.2 Phase A -- Focus/Exposure Control (E0/C1/E1 Loop)

Factory: `FUN_100b0380` (617 bytes). Handler: `FUN_100b06f0` (1304 bytes).

```
Step  Command          CDB Bytes (hex)                         Dir    Notes
----  ---------------  -------------------------------------   -----  -----
 1    TUR              00 00 00 00 00 00                       None   Ready check
 2    SEND DIAGNOSTIC  1D 04 00 00 00 00                       None   Pre-focus cal
 3    E0 (write)       E0 00 46 00 00 00 00 00 0B 00           Out    Focus position set
 4    C1 (trigger)     C1 00 00 00 00 00                       None   Execute focus move
 5    E1 (read)        E1 00 46 00 00 00 00 00 0B 00           In     Read focus result
 6    E0 (write)       E0 00 45 00 00 00 00 00 0B 00           Out    Exposure time set
 7    C1 (trigger)     C1 00 00 00 00 00                       None   Execute exposure
 8    E1 (read)        E1 00 45 00 00 00 00 00 0B 00           In     Read exposure result
     [repeat steps 3-8 adjusting focus position until contrast maximum found]
```

### 5.3 Vendor Sub-Commands for Focus

| Sub-cmd | E0 (Write) | C1 (Trigger) | E1 (Read) | Max Data |
|---------|-----------|-------------|-----------|----------|
| 0x44 | Motor target position | Move motor | Current position | 5 bytes |
| 0x45 | Exposure time params | Set exposure | Current exposure | 11 bytes |
| 0x46 | Focus position set | Execute focus | Focus readback | 11 bytes |
| 0xA0 | CCD setup params | Configure CCD | CCD config readback | 9 bytes |

### 5.4 Phase B -- Calibration Data Exchange

Factory: `FUN_100b0c20` (1021 bytes). Handler: `FUN_100b1170` (1376 bytes).

```
Step  Command          CDB Bytes (hex)                         Dir    Notes
----  ---------------  -------------------------------------   -----  -----
 1    TUR              00 00 00 00 00 00                       None   Ready check
 2    SEND DIAGNOSTIC  1D 04 00 00 00 00                       None   Pre-cal
 3    READ (cal)       28 00 84 00 00 QQ LL LL LL 80           In     Read cal data (DTC 0x84)
 4    WRITE (cal)      2A 00 84 00 00 QQ LL LL LL 00           Out    Write modified cal
 5    E0               E0 00 CC 00 00 00 00 00 05 00           Out    Gain/offset cal (0xC0/0xC1)
 6    C1               C1 00 00 00 00 00                       None   Trigger
 7    E1               E1 00 CC 00 00 00 00 00 05 00           In     Read result
     [repeat vendor loop for each calibration parameter]
```

### 5.5 Focus Algorithm (Host-Side)

The host implements a contrast-maximization search:

1. Move AF motor to coarse starting position (E0 sub-cmd 0x46)
2. Take exposure at current position (E0 sub-cmd 0x45, C1 trigger)
3. Read CCD line data (E1 sub-cmd 0x46 or READ DTC 0x8E)
4. Compute contrast metric (high-pass filter on pixel values)
5. Step AF motor to next position
6. Repeat, building a contrast-vs-position curve
7. Move to the position with maximum contrast

The focus handler uses `timeGetTime()` for a **5-second timeout** per focus step.

Source: `LS5000.md3:0x100B06F0`, Type C handler processes E1 vendor response data at sub-cmd 0x42 (focus position stored at object+0x468) and sub-cmd 0xC0 (exposure value stored at object+0x460).

### 5.6 Autofocus Timing Diagram

```
Host                                    Scanner
  |                                       |
  |--- TUR ------------------------------>|
  |<-- Good ------------------------------|
  |                                       |
  |--- SEND DIAG ----------------------->|  (pre-focus calibration)
  |<-- Good ------------------------------|
  |                                       |
  |--- E0 [sub=0x46, pos=START] -------->|  (set AF motor to start)
  |<-- Good ------------------------------|
  |--- C1 ------------------------------>|  (trigger move)
  |<-- Good ------------------------------|
  |--- TUR ------------------------------>|  (wait for motor)
  |<-- Good ------------------------------|
  |                                       |
  |--- E0 [sub=0x45, exposure params] --->|  (set exposure)
  |--- C1 ------------------------------>|  (trigger CCD capture)
  |--- E1 [sub=0x46] ------------------>|  (read focus data)
  |<-- 11 bytes focus/contrast data ------|
  |                                       |
  |  (compute contrast, step AF motor)    |
  |                                       |
  |--- E0 [sub=0x46, pos=NEXT] --------->|  (next AF position)
  |--- C1 ------------------------------>|  (trigger)
  |--- E1 [sub=0x46] ------------------>|  (read)
  |<-- 11 bytes focus data ---------------|
  |                                       |
  |  ... repeat 10-30 times ...           |
  |  (binary search or hill-climbing)     |
  |                                       |
  |--- E0 [sub=0x46, pos=BEST] --------->|  (move to best focus)
  |--- C1 ------------------------------>|
  |<-- Good ------------------------------|
  |                                       |
  |  === AUTOFOCUS COMPLETE ===           |
```

---

## 6. Preview Scan

### 6.1 Overview

Preview scans use the **Type B** (Simple Scan) vtable architecture. A preview typically runs at 300-1000 DPI and produces a quick low-resolution image for the user to frame their scan.

Phase A sends only SET WINDOW. Phase B handles the full scan cycle.

### 6.2 Phase A -- Configure Parameters

Factory: `FUN_100b4040` (194 bytes).

```
Step  Command      CDB Bytes (hex)                                    Dir    Data
----  -----------  ------------------------------------------------   -----  ----
 1    SET WINDOW   24 00 00 00 00 00 LL LL LL 80                      Out    Window descriptor
```

#### SET WINDOW CDB

```
CDB: 24 00 00 00 00 00 LL LL LL 80
     |                 |  |  |  |
     |                 +--+--+-- Transfer length (big-endian, 24-bit)
     |                          = descriptor_size + 8
     +-- Opcode: SET WINDOW     Control: 0x80 (vendor extension bit)
Direction: Data-out
```

#### Window Descriptor for Preview (example: 300 DPI, full frame, RGB 8-bit)

```
Offset  Bytes  Field                    Value (hex)           Notes
------  -----  -----------------------  --------------------  -----
00-05   6      Header (reserved)        00 00 00 00 00 00
06-07   2      Descriptor length        00 XX                 = total_desc - 8
08      1      Window ID                00
09      1      Reserved                 00
10-11   2      X Resolution             01 2C                 300 DPI
12-13   2      Y Resolution             01 2C                 300 DPI
14-17   4      Upper Left X             00 00 00 00           Full frame start
18-21   4      Upper Left Y             00 00 00 00
22-25   4      Width                    00 00 XX XX           Frame width
26-29   4      Height                   00 00 XX XX           Frame height
30      1      Brightness               80                    Default (128)
31      1      Threshold                80
32      1      Contrast                 80
33      1      Image Composition        05                    RGB color
34      1      Bits Per Pixel           08                    8-bit per channel
35      1      Halftone Pattern         00
36-47   12     Reserved                 00 00 ... 00
48      1      Color/Composition        50                    (0x05 << 4 | 0x00)
49      1      Scan Flags               00
50      1      Multi-Sample Count       01                    Single sample (0x20 -> 1)
51      1      Compression Type         00
52      1      Compression Argument     00
53      1      Reserved                 00
54+     var    Vendor extensions         ...                   Dynamic (see 2.3 Step 6)
```

### 6.3 Phase B -- Scan Execution

Factory: `FUN_100b41a0` (898 bytes). Handler: `FUN_100b36e0` (724 bytes).

```
Step  Command          CDB Bytes (hex)                            Dir    Notes
----  ---------------  ----------------------------------------   -----  -----
 1    TUR              00 00 00 00 00 00                           None   Ready check
 2    SCAN             1B 00 00 00 01 00                           Out    Start preview scan
 3    SEND DIAGNOSTIC  1D 04 00 00 00 00                           None   Pre-scan cal
 4    SET WINDOW       24 00 00 00 00 00 LL LL LL 80               Out    Reconfigure if needed
 5    GET WINDOW       25 00 00 00 00 00 LL LL LL 00               In     Verify parameters
 6    READ (params)    28 00 87 00 00 00 00 00 18 80               In     Read scan params (24B)
 7    READ (image)     28 00 00 00 00 QQ LL LL LL 80               In     Transfer image data
      [repeat step 7 until all scan lines received]
 8    WRITE (LUT)      2A 00 03 00 00 QQ LL LL LL 00               Out    Upload gamma LUT
```

#### Step 2: SCAN -- Start Scanning

```
CDB: 1B 00 00 00 01 00
     |              |
     |              +-- Transfer length: 1 byte
     +-- Opcode: SCAN
Direction: Data-out
Data: 1 byte window ID list (typically 0x00)
```

The firmware handler at `FW:0x0220B8` determines the operation type from the scan descriptor:
- Operation 0 = Preview scan
- Sets scan state variables at `0x400D43` (active), `0x400E7A` (state)
- Triggers motor control via internal task dispatch (04xx task codes)

After SCAN completes, the scanner begins physically scanning: moving the film carrier, activating the LED/lamp, and reading the CCD line-by-line into ASIC RAM at `0x800000`.

#### Step 6: READ -- Scan Parameters (DTC 0x87)

```
CDB: 28 00 87 00 00 00 00 00 18 80
     |     |              |  |  |
     |     |              +--+--+-- Transfer length: 24 bytes
     |     +-------------------- DTC: 0x87 (scan parameters/status)
     +-- Opcode: READ(10)
Direction: Data-in
Data: 24 bytes scan parameter status
```

This returns the scanner's current scan status including lines scanned, bytes per line, and completion state.

#### Step 7: READ -- Image Data (DTC 0x00)

```
CDB: 28 00 00 00 00 QQ LL LL LL 80
     |     |        |  |  |  |
     |     |        |  +--+--+-- Transfer length (chunk size)
     |     |        +----------- Qualifier: 0=8-bit, 1=16-bit
     |     +-------------------- DTC: 0x00 (image data)
     +-- Opcode: READ(10)
Direction: Data-in
Data: Raw pixel data (line-by-line, RGB interleaved)
```

Image data format:
- **8-bit**: 1 byte per channel per pixel (R, G, B in order)
- **14/16-bit**: 2 bytes per channel per pixel (big-endian)
- **RGBI**: 4 channels when Digital ICE infrared is enabled
- Layout: line-by-line, pixels left-to-right

The host reads in chunks until all scan lines are transferred. The inline CDB builders at `0x100866d9`, `0x10086dfa`, `0x1008781a` bypass the vtable architecture for performance in this tight loop.

### 6.4 Preview Scan Firmware State Machine

The firmware dispatches preview scans using task codes from the scan task table:

| Task Code | Handler Index | Resolution Band |
|-----------|--------------|-----------------|
| `0x0800` | `0x0022` | Low resolution |
| `0x0810` | `0x0022` | Medium resolution |
| `0x0820` | `0x0022` | Full resolution |

All three share handler index 0x0022 (same scan pipeline, different parameters).

---

## 7. Final Scan (Full Resolution)

### 7.1 Overview

A final scan uses the **Type A** vtable (Init + Main Scan), which runs Phase A (full initialization) followed by Phase B (scan execution). This is then followed by a Simple Scan (Type B) Phase B for the actual data transfer.

### 7.2 Complete Final Scan Sequence

```
=== PHASE A: INITIALIZATION (Type A) ===

Step  Command          CDB Bytes                                Dir    Notes
----  ---------------  ---------------------------------------- -----  -----
 1    TUR              00 00 00 00 00 00                         None   Scanner ready?
 2    INQUIRY          12 00 00 00 24 80                         In     Get identity
 3    RESERVE          16 00 00 00 00 00                         None   Exclusive access
 4    MODE SELECT      15 10 00 00 14 00                         Out    Set mode page 0x03
 5    SEND DIAGNOSTIC  1D 04 00 00 00 00                         None   Self-test/calibration
 6    GET WINDOW       25 XX XX XX XX 00 LL LL LL 00             In     Read window params
 7    READ             28 00 88 00 00 03 LL LL LL 80             In     Read boundary data

=== PHASE B: MAIN SCAN SETUP (Type A) ===

 8    TUR              00 00 00 00 00 00                         None   Ready check
 9    SEND DIAGNOSTIC  1D 04 00 00 00 00                         None   Pre-scan prep
10    SET WINDOW       24 00 00 00 00 00 LL LL LL 80             Out    Full scan descriptor

=== DATA TRANSFER (Type B Phase B) ===

11    TUR              00 00 00 00 00 00                         None   Ready check
12    WRITE (LUT)      2A 00 03 00 00 QQ 00 80 00 00             Out    Upload gamma LUT (32KB)
13    SCAN             1B 00 00 00 01 00                         Out    Start final scan
14    TUR              00 00 00 00 00 00                         None   Poll until scan ready
      [poll TUR until scan buffer has data]
15    READ (status)    28 00 87 00 00 00 00 00 18 80             In     Scan params (24 bytes)
16    READ (image)     28 00 00 00 00 00 LL LL LL 80             In     Image data chunk
      [repeat step 16 until all lines transferred]
17    SEND DIAGNOSTIC  1D 04 00 00 00 00                         None   Post-scan cleanup
```

### 7.3 SET WINDOW for Final Scan (Step 10)

Example: 4000 DPI, 14-bit, RGB, full frame:

```
CDB: 24 00 00 00 00 00 00 00 60 80    (transfer length = 0x60 = 96 bytes)

Descriptor payload (96 bytes):
Offset  Bytes  Value             Field
------  -----  ----------------  -----
00-05   6      00 00 00 00 00 00 Header
06-07   2      00 58             Descriptor length (88 bytes)
08      1      00                Window ID
09      1      00                Reserved
10-11   2      0F A0             X Resolution: 4000 DPI
12-13   2      0F A0             Y Resolution: 4000 DPI
14-17   4      00 00 00 00       Upper Left X
18-21   4      00 00 00 00       Upper Left Y
22-25   4      00 00 XX XX       Width (frame width in scanner units)
26-29   4      00 00 XX XX       Height (frame height in scanner units)
30      1      80                Brightness (default 128)
31      1      80                Threshold
32      1      80                Contrast
33      1      05                Image Composition: RGB color
34      1      0E                Bits Per Pixel: 14
35      1      00                Halftone Pattern
36-47   12     00...             Reserved
48      1      50                Color/Composition
49      1      00                Scan Flags
50      1      01                Multi-Sample: 1 (single)
51-53   3      00 00 00          Compression, reserved
54+     var    ...               Vendor extensions (dynamic from GET WINDOW)
```

### 7.4 WRITE -- Gamma LUT Upload (Step 12)

```
CDB: 2A 00 03 00 00 QQ LL LL LL 00
     |     |        |  |  |  |
     |     |        |  +--+--+-- Transfer length (up to 32768 = 0x8000)
     |     |        +----------- Qualifier: LUT table selector
     |     +-------------------- DTC: 0x03 (gamma function / LUT)
     +-- Opcode: WRITE(10)
Direction: Data-out
Data: Look-up table data (up to 32KB per channel)
```

The scanner applies the LUT in hardware (ASIC) before transferring pixel data. This is more efficient than software gamma for large scans.

### 7.5 Final Scan Firmware State Machine

The firmware routes final scans through the scan task table:

| Condition | Task Group | Task Codes |
|-----------|-----------|------------|
| 8-bit, no ICE | Group 3 | 0x0830-0x0834 |
| 14-bit, no ICE | Group 5 | 0x0850-0x0854 |
| 8-bit, with ICE | Group 4 | 0x0840-0x0844 |
| 14-bit, with ICE | Group 6 | 0x0860-0x0864 |

The low nibble (0-4) selects the adapter variant. Task code formula: `0x08G0 | (adapter_variant_byte + 1)`.

### 7.6 Scan Data Throughput

At 4000 DPI, 14-bit RGB, a single 35mm frame (24x36mm) produces:

```
Pixels: 3780 x 5669 (at 4000 DPI)
Channels: 3 (RGB) or 4 (RGBI with ICE)
Bytes/pixel: 2 (14-bit packed to 16-bit)
Total: 3780 x 5669 x 3 x 2 = ~128 MB (RGB)
Total: 3780 x 5669 x 4 x 2 = ~171 MB (RGBI)
```

USB 2.0 theoretical max: 480 Mbps = 60 MB/s. Practical throughput is limited by scanner CCD speed, not USB bandwidth. A 4000 DPI scan takes 2-4 minutes.

---

## 8. Multi-Sampling Scan

### 8.1 Overview

Multi-sampling scans multiple exposures of the same frame and averages the results to reduce sensor noise. The Coolscan V supports 1x, 2x, 4x, 8x, 16x, 32x, and 64x multi-sampling.

### 8.2 SET WINDOW Multi-Sample Encoding

The multi-sample count is encoded in byte 50 of the window descriptor:

| scan_type (obj+0x44C) | Multi-Sample Count | Byte 50 Value |
|------------------------|-------------------|---------------|
| 0x20 | 1 (single, normal) | 0x01 |
| 0x21 | 2x | 0x02 |
| 0x22 | 4x | 0x04 |
| 0x31 | 8x | 0x08 |
| 0x23 | 16x | 0x10 |
| 0x24 | 32x | 0x20 |
| 0x25 | 64x | 0x40 |

Source: Switch table in `LS5000.md3:0x100B2B30` (SET WINDOW builder)

### 8.3 Multi-Sample Scan Sequence

The sequence is identical to a Final Scan (Section 7.2) except:

1. SET WINDOW byte 50 contains the multi-sample count
2. The firmware uses different scan task groups:

| Condition | Task Group | Task Codes |
|-----------|-----------|------------|
| Multi-pass, no ICE | Group 7 | 0x0870-0x0874 |
| Multi-pass, with ICE | Group 8 | 0x0880-0x0884 |
| Extended multi-sample A | Group 9 | 0x0891-0x0894 |
| Extended multi-sample B | Group A | 0x08A1-0x08A4 |
| Extended multi-sample C | Group B | 0x08B1-0x08B4 |

3. The firmware's F8 (Multi-pass Scan Orchestrator, `FW:0x42E2A`, 3790 bytes) manages the interleaving of multiple CCD exposures per scan line with USB data transfer and re-calibration.

### 8.4 Firmware Multi-Pass Pipeline

```
F8 (Multi-pass Orchestrator) at FW:0x42E2A:
  1. Set up initial calibration (0x39C6C)
  2. For each scan line:
     a. Configure ASIC for exposure N
     b. Trigger CCD capture (DMA via 0x200001)
     c. Wait for DMA complete (poll 0x200002)
     d. Read pixel data from ASIC RAM (0x800000+)
     e. Repeat for N exposures
     f. Average N exposures in firmware
     g. Transfer averaged data to USB buffer (0x12360, 0x12398)
     h. Re-calibrate if needed (0x39E0C, 0x3A00E)
  3. Signal completion
```

The multi-pass orchestrator interleaves scan line capture, USB transfer, and re-calibration across multiple passes. ASIC timing adjustments via `0x3718A` maintain consistent exposure across passes.

---

## 9. Calibration Sequence

### 9.1 Overview

The scanner's calibration subsystem performs dark frame subtraction and white reference normalization. Calibration is triggered by the host before scanning, using a combination of SEND DIAGNOSTIC and the READ/WRITE data type codes for calibration data.

**Key insight**: All pixel-level correction (gamma, LUT, color balance) is performed host-side. The firmware only performs analog front-end calibration (gain/offset) and provides raw CCD data.

### 9.2 Host-Initiated Calibration Sequence

```
Step  Command          CDB Bytes                                Dir    Notes
----  ---------------  ---------------------------------------- -----  -----
 1    SEND DIAGNOSTIC  1D 04 00 00 00 00                         None   Trigger calibration
 2    TUR              00 00 00 00 00 00                         None   Poll until cal done
      [repeat TUR -- sense 0x7A = "calibration in progress"]
 3    READ (cal)       28 00 84 00 00 01 00 00 06 80             In     Read cal data (6B, ch=R)
 4    READ (cal)       28 00 84 00 00 02 00 00 06 80             In     Read cal data (6B, ch=G)
 5    READ (cal)       28 00 84 00 00 03 00 00 06 80             In     Read cal data (6B, ch=B)
 6    [host processes calibration data]
 7    WRITE (cal)      2A 00 84 00 00 01 00 00 06 00             Out    Write cal back (ch=R)
 8    WRITE (cal)      2A 00 84 00 00 02 00 00 06 00             Out    Write cal back (ch=G)
 9    WRITE (cal)      2A 00 84 00 00 03 00 00 06 00             Out    Write cal back (ch=B)
10    E0 (gain cal)    E0 00 C0 00 00 00 00 00 05 00             Out    Gain calibration params
11    C1 (trigger)     C1 00 00 00 00 00                         None   Execute gain cal
12    E1 (read)        E1 00 C0 00 00 00 00 00 05 00             In     Read gain result
13    E0 (offset cal)  E0 00 C1 00 00 00 00 00 05 00             Out    Offset calibration
14    C1 (trigger)     C1 00 00 00 00 00                         None   Execute offset cal
15    E1 (read)        E1 00 C1 00 00 00 00 00 05 00             In     Read offset result
```

### 9.3 READ/WRITE Calibration Data Types

| DTC | Direction | Max Size | Qualifier | Purpose |
|-----|-----------|----------|-----------|---------|
| 0x84 | READ/WRITE | 6 bytes | 0-3 (R/G/B/all) | Standard calibration data |
| 0x85 | WRITE only | varies | single | Extended calibration (no readback) |
| 0x88 | READ/WRITE | 644 bytes | 0-3 (R/G/B/all) | Per-channel boundary calibration |
| 0x8A | READ only | 14 bytes | 0-3 | Exposure/gain parameters |
| 0x8C | READ only | 10 bytes | 0-3 | Offset/dark current |
| 0x90 | READ only | 54 bytes | 0-3 | CCD characterization data |

### 9.4 Firmware Calibration Flow

When the firmware receives SCAN with operation code 3 (calibration scan), or SEND DIAGNOSTIC in calibration state:

1. Set DAC mode register `0x2000C2` = `0xA2` (calibration enable)
2. Read calibration parameters from RAM `0x400F56`-`0x400F9D`
3. Configure ASIC calibration registers (`0x2001CA`/`0x2001CB`, `0x20014E`/`0x200152`/`0x200153`)
4. Perform calibration scan (CCD data via Buffer RAM at `0xC00000`)
5. Compute per-channel min/max from CCD data
6. Update calibration results at `0x400F0A`, `0x400F12`, `0x400F1A`

Four firmware calibration routines:

| Address | Description |
|---------|-------------|
| `FW:0x3D12D` | Calibration routine 1 |
| `FW:0x3DE51` | Calibration routine 2 |
| `FW:0x3EEF9` | Calibration routine 3 |
| `FW:0x3F897` | Calibration routine 4 |

### 9.5 Model-Specific Calibration

The firmware handles LS-50 and LS-5000 differently for analog front-end:

| Parameter | LS-50 | LS-5000 |
|-----------|-------|---------|
| Fine DAC (`0x2000C7`) | `0x08` | `0x00` |
| Coarse gain (`0x200142`) | `0x64` (100) | `0xB4` (180) |

Model flag at RAM `0x404E96`: 0 = LS-50, non-zero = LS-5000.

---

## 10. Film Eject

### 10.1 Overview

Film eject uses the SCSI SCAN command with operation code 9 (eject film), or SEND DIAGNOSTIC for motor control. The eject sequence is managed through the same scan operation vtable machinery.

### 10.2 Eject Sequence

```
Step  Command          CDB Bytes                                Dir    Notes
----  ---------------  ---------------------------------------- -----  -----
 1    TUR              00 00 00 00 00 00                         None   Scanner ready?
 2    SEND DIAGNOSTIC  1D 04 00 00 00 00                         None   Motor control for eject
 3    TUR              00 00 00 00 00 00                         None   Poll until ejected
      [repeat TUR until motor complete]
```

#### Alternative: SCAN with Eject Operation

```
Step  Command  CDB Bytes                Dir    Notes
----  -------  -----------------------  -----  -----
 1    SCAN     1B 00 00 00 01 00        Out    Start eject (operation code 9)
```

The SCAN handler at `FW:0x0220B8` dispatches operation code 9 to motor task `0x0430` (home/eject position).

### 10.3 Eject Firmware Behavior

When scanning state `@0x40077C` = `0x80` (ejecting), the TUR handler returns:
- Sense code 0x0D (SK=2, ASC=05, ASCQ=00) = "LU does not respond to selection" (medium removal request)

The host must poll TUR until the scanner returns Good status (eject complete).

### 10.4 Film Advance vs Eject

NikonScan distinguishes between Film Advance and Eject based on user input:

| Condition | Action | NikonScan Entry |
|-----------|--------|-----------------|
| Film loaded, no Ctrl key | Film Advance (next frame) | `source->vtable[0x14c](queue)` |
| Film loaded, Ctrl held | Full Eject | `source->vtable[0x148](queue)` |
| No film loaded | Eject adapter | `FUN_1002db40` then vtable[0x148] |

Both ultimately send SEND DIAGNOSTIC (0x1D) through the MAID command queue.

Source: `NikonScan4.ds:0x1002E030` (eject executor, 577 bytes)

---

## 11. Error Recovery

### 11.1 Sense Code Reference (Key Codes)

| Sense Index | SK/ASC/ASCQ | FRU | Meaning | Recovery Action |
|-------------|-------------|-----|---------|-----------------|
| 0x00 | 00/00/00 | - | No error | Continue |
| 0x07 | 02/04/01 | 00 | Becoming ready (general) | Retry TUR after 500ms |
| 0x08 | 02/04/01 | 01 | USB controller initializing | Retry TUR after 500ms |
| 0x09 | 02/04/01 | 02 | Encoder calibrating | Retry TUR after 500ms |
| 0x0A | 02/04/02 | 00 | Init command required | Send init sequence |
| 0x0D | 02/05/00 | 00 | Ejecting (medium removal) | Wait for eject complete |
| 0x0E | 02/3A/00 | 00 | No medium (no film) | Prompt user to load film |
| 0x4F | 05/20/00 | - | Invalid command opcode | Bug: unknown command sent |
| 0x50 | 05/24/00 | - | Invalid field in CDB | Fix CDB construction |
| 0x53 | 05/26/00 | - | Invalid parameter | Fix parameter value |
| 0x56 | 05/2C/00 | - | Command sequence error | Re-run init sequence |
| 0x5C | 06/29/00 | - | Power-on/bus reset | Clear UA, re-init |
| 0x61 | 06/3F/03 | - | Inquiry data changed | Adapter swapped, re-init |
| 0x65 | 0B/08/00 | - | LU communication failure | Hardware error, retry |
| 0x71 | 02/04/02 | 00 | Scan timeout | Re-init required |
| 0x79 | 02/04/01 | 03 | Motor busy | Wait and retry |
| 0x7A | 02/04/01 | 04 | Calibration in progress | Wait and retry |

### 11.2 Error Recovery Sequence

```
Error detected (non-zero sense key)
  |
  v
Check sense key:
  |
  |-- SK=0 (NO SENSE): Continue normally
  |
  |-- SK=2 (NOT READY):
  |   |-- ASC=04/01: Scanner becoming ready -> retry TUR every 500ms (up to 30s)
  |   |-- ASC=3A/00: No medium -> prompt user, wait for film insertion
  |   |-- ASC=05/00: Ejecting -> wait for eject complete
  |   +-- ASC=04/02: Timeout -> full re-initialization required
  |
  |-- SK=5 (ILLEGAL REQUEST):
  |   |-- ASC=20/00: Invalid opcode -> firmware bug or wrong scanner model
  |   |-- ASC=24/00: Invalid CDB field -> fix CDB parameters
  |   |-- ASC=26/00: Invalid parameter -> fix data payload
  |   +-- ASC=2C/00: Sequence error -> re-run init, ensure SET WINDOW before SCAN
  |
  |-- SK=6 (UNIT ATTENTION):
  |   |-- ASC=29/00: Power-on reset -> clear UA by issuing any command, then re-init
  |   +-- ASC=3F/03: Adapter changed -> re-detect adapter, re-init
  |
  |-- SK=4 (HARDWARE ERROR):
  |   |-- ASC=60/00: Lamp failure -> FRU identifies channel (1=R, 2=G, 3=B)
  |   |-- ASC=44/00: Internal target failure -> retry once, then report error
  |   +-- ASC=53/00: Media load/eject failed -> motor problem
  |
  |-- SK=3 (MEDIUM ERROR):
  |   +-- ASC=11/00: Unrecovered read error -> FRU identifies CCD channel
  |
  +-- SK=0B (ABORTED COMMAND):
      +-- ASC=08/00: Communication failure -> retry, then re-init
```

### 11.3 Retry Logic (Group B Commands)

Commands using Group B vtable (most commands) include automatic retry on error code 9 with a 50ms delay:

```
Execute command
  |
  v
Check result
  |-- Error 9 -> wait 50ms, retry (up to N times)
  |-- Other error -> report to caller
  +-- Success -> continue
```

Source: `LS5000.md3:0x100ae8d0` (Group B vtable entry[4])

### 11.4 Lamp Failure Sense Codes

The firmware defines **30 lamp failure entries** (the largest single group). FRU encoding:

| FRU High Nibble | Channel |
|-----------------|---------|
| 0 | R (red LED) |
| 1 | G (green LED) |
| 2 | B (blue LED) |
| 3 | IR (infrared) |
| 9 | Multiple channels |

| FRU Low Nibble | Failure Sub-Type |
|----------------|-----------------|
| 0 | Current (immediate detection) |
| 1 | Deferred (detected during scan) |
| 2 | Deferred (no info bytes) |

---

## 12. Complete CDB Reference

### 12.1 All 17 SCSI Opcodes (Host-Side)

| Opcode | Command | CDB Size | Direction | CDB Template |
|--------|---------|----------|-----------|--------------|
| `0x00` | TEST UNIT READY | 6 | None | `00 00 00 00 00 00` |
| `0x12` | INQUIRY | 6 | In | `12 EV PG 00 AL CT` |
| `0x15` | MODE SELECT | 6 | Out | `15 10 00 00 PL 00` |
| `0x16` | RESERVE | 6 | None | `16 00 00 00 00 00` |
| `0x1A` | MODE SENSE | 6 | In | `1A 18 PC 00 AL 00` |
| `0x1B` | SCAN | 6 | Out | `1B 00 00 00 TL 00` |
| `0x1C` | RECEIVE DIAGNOSTIC | 6 | In | `1C 00 PG AL AL 00` |
| `0x1D` | SEND DIAGNOSTIC | 6 | None/Out | `1D 04 00 00 00 00` |
| `0x24` | SET WINDOW | 10 | Out | `24 00 00 00 00 00 TL TL TL 80` |
| `0x25` | GET WINDOW | 10 | In | `25 FL WW WW WW 00 TL TL TL 00` |
| `0x28` | READ(10) | 10 | In | `28 00 DT 00 00 DQ TL TL TL 80` |
| `0x2A` | WRITE(10) | 10 | Out | `2A 00 DT 00 00 DQ TL TL TL 00` |
| `0x3B` | WRITE BUFFER | 10 | Out | `3B MD BI OF OF OF TL TL TL 00` |
| `0x3C` | READ BUFFER | 10 | In | `3C MD BI OF OF OF TL TL TL 00` |
| `0xC0` | Vendor Status | 6 | None | `C0 00 00 00 00 00` |
| `0xC1` | Vendor Trigger | 6 | None | `C1 00 00 00 00 00` |
| `0xE0` | Vendor Write | 10 | Out | `E0 00 SC 00 00 00 TL TL TL 00` |
| `0xE1` | Vendor Read | 10 | In | `E1 00 SC 00 00 00 TL TL TL 00` |

Legend: EV=EVPD, PG=page, AL=alloc length, CT=control, PL=param list length, PC=page control+code, TL=transfer length, FL=flags, WW=window, DT=data type code, DQ=data type qualifier, MD=mode, BI=buffer ID, OF=offset, SC=sub-command

### 12.2 Additional Firmware-Only Opcodes (4 commands)

| Opcode | Command | Handler | Purpose |
|--------|---------|---------|---------|
| `0x03` | REQUEST SENSE | `FW:0x021866` | Sense data retrieval (via 0x06 opcode on USB) |
| `0x17` | RELEASE | `FW:0x021EA0` | Release reservation (not used by NikonScan) |
| `0xD0` | Phase Query | `FW:0x013748` | USB protocol phase query (sent by NKDUSCAN.dll) |
| `0x3B` | WRITE BUFFER | `FW:0x02837C` | Firmware update (used by separate utility) |

### 12.3 READ Data Type Codes (15 total)

From firmware dispatch table at `FW:0x49AD8` (12-byte entries):

| DTC | Name | Max Size | Qualifier | Notes |
|-----|------|----------|-----------|-------|
| 0x00 | Image Data | Variable | 0=8bit, 1=16bit | Main scan data |
| 0x03 | Gamma/LUT | 32768 | LUT select | Hardware tone mapping |
| 0x81 | Film Frame Info | 8 | Single | Scan area dimensions |
| 0x84 | Calibration | 6 | Single | Per-channel cal data |
| 0x87 | Scan Parameters | 24 | None | Scan status/progress |
| 0x88 | Boundary Data | 644 | 0-3 (R/G/B/all) | Per-channel boundaries |
| 0x8A | Exposure/Gain | 14 | 0-3 | Gain parameters |
| 0x8C | Dark Current | 10 | 0-3 | Offset correction |
| 0x8D | Extended Line | Variable | 0/1/3 | Extended scan line |
| 0x8E | Focus Data | Variable | 0 or 1 | Autofocus measurements |
| 0x8F | Histogram | 324 | 0/1/3 (R/G/B) | Profile data |
| 0x90 | CCD Characterization | 54 | 0-3 | CCD sensor data |
| 0x92 | Motor Status | 10 | 0-3 | Position/speed |
| 0x93 | Adapter Info | 12 | Single | Adapter identification |
| 0xE0 | Extended Config | 1030 | 0/1/3 | Configuration data |

### 12.4 WRITE Data Type Codes (7 total)

From firmware dispatch table at `FW:0x49B98` (10-byte entries):

| DTC | Name | Max Size | Qualifier | Notes |
|-----|------|----------|-----------|-------|
| 0x03 | Gamma/LUT | 32768 | LUT select | Upload tone curves |
| 0x84 | Calibration | 6 | Single | Upload cal data |
| 0x85 | Extended Cal | varies | Single | **WRITE-only** (no READ) |
| 0x88 | Boundary Data | 644 | 0-3 | Upload boundaries |
| 0x8F | Histogram | 324 | 0/1/3 | Upload profile |
| 0x92 | Motor Control | 4 | 0-3 | Motor commands |
| 0xE0 | Extended Config | 1024 | 0/1/3 | Upload config |

### 12.5 Vendor E0/C1/E1 Sub-Commands (23 total)

From register table at `FW:0x4A134`:

| Sub-cmd | Max Data | E0 (Write) | C1 (Trigger) | E1 (Read) | Purpose |
|---------|----------|-----------|-------------|-----------|---------|
| 0x40 | 11 | Scan params | Execute scan | Scan status | Scan control |
| 0x41 | 11 | Cal data | Execute cal | Cal results | Calibration |
| 0x42 | 11 | Gain values | Apply gain | Gain readback | Gain |
| 0x43 | 11 | Offset values | Apply offset | Offset readback | Offset |
| 0x44 | 5 | Motor target | Move motor | Motor position | Motor position |
| 0x45 | 11 | Exposure time | Set exposure | Exposure readback | Exposure |
| 0x46 | 11 | Focus position | Execute focus | Focus readback | Autofocus |
| 0x47 | 11 | Lamp settings | Apply lamp | Lamp status | Lamp |
| 0x80 | 0 | (none) | Lamp on/off | (none) | Lamp trigger |
| 0x81 | 0 | (none) | Motor init | (none) | Motor init |
| 0x91 | 5 | Motor step | Step motor | (none) | Motor step |
| 0xA0 | 9 | CCD setup | Apply CCD | CCD readback | CCD config |
| 0xB0 | 0 | (none) | State change | (none) | State A |
| 0xB1 | 0 | (none) | State change | (none) | State B |
| 0xB3 | 13 | Config data | Apply config | (none) | Config write |
| 0xB4 | 9 | Ext config | Apply ext | (none) | Extended config |
| 0xC0 | 5 | Gain cal data | Cal gain | Gain result | Gain cal |
| 0xC1 | 5 | Offset cal data | Cal offset | Offset result | Offset cal |
| 0xD0 | 0 | (none) | Diag trigger | (none) | Diagnostic 1 |
| 0xD1 | 0 | (none) | Diag trigger | (none) | Diagnostic 2 |
| 0xD2 | 5 | Diag data | Apply diag | (none) | Diagnostic 3 |
| 0xD5 | 5 | Ext diag data | Apply ext diag | (none) | Extended diag |
| 0xD6 | 5 | Persist data | Save to flash | (none) | Persistent settings |

---

## 13. Firmware State Machine

### 13.1 Scanner State Byte (`@0x40077C`)

| State | Meaning | TUR Response |
|-------|---------|-------------|
| 0x00 | Idle (ready) | Good |
| 0x01 | Active scan | Check sub-state |
| 0x20-0x2F | Setup phase | Status |
| 0x80 | Ejecting film | Sense 0x0D |
| 0xF0 | Sensor error | Sense 0x0008 |
| 0xF1 | Motor error | Sense 0x0009 |
| 0xF2 | Active scan (variant) | Check sub-state |
| 0xF3 | Motor busy | Sense 0x0079 |
| 0xF4 | Calibration busy | Sense 0x007A |

### 13.2 Scan State Transition Pipeline

```
HOST TRIGGER (SCSI SCAN 0x1B or Vendor C1)
    |
    v
INIT PHASE
    0x0110 -> Scan parameter setup
    0x0120 -> Hardware configuration
    0x0121 -> Final configuration
    |
    v
MOTOR POSITIONING
    0x0300 -> Absolute move (to scan start)
    0x0310 -> Relative move (fine adjust)
    0x0380 -> Slow move (precision)
    0x0390 -> Return to home
    |
    v
FOCUS
    0x0400 -> Focus motor positioning
    0x0450 -> Extended focus (fine)
    |
    v
CALIBRATION
    0x0500 -> Calibration primary
    0x0501 -> Calibration secondary
    0x0502 -> Shared cal/feed/position
    |
    v
EXPOSURE SETUP
    0x0930 -> Exposure computation
    0x0940 -> Exposure timing set
    |
    v
SCAN EXECUTION
    0x08GV -> Scan task (G=group, V=variant)
    Inner loop: CCD line -> ASIC DMA -> pixel process -> USB transfer
    |
    v
COMPLETION
    0x0F20 -> Recovery/cleanup
```

### 13.3 DMA Inner Loop (Pre-function State Machine at `FW:0x40000`)

The inner scan loop (792 bytes, not a standard function) processes each CCD line:

```
1. Read scan descriptor from @0x406E6A
2. Configure next scan line via ASIC function 0x35A9A
3. Check task state @0x400778:
   - 0x0300: Motor positioning, yield and retry
   - 0x0310: Motor relative, yield and retry
   - 0x0320: Motor scan direction set
   - 0x0330: Scan buffer stall (host needs to READ)
4. Check @0x400776 bit 7: scan active flag
5. Trigger ASIC DMA:
   - Write 0x02 to ASIC register 0x200001
   - Poll ASIC register 0x200002 bit 3 (DMA busy)
   - Yield (JSR @0x0109E2) between polls
6. When DMA complete: call F1 (0x40318) for pixel processing
7. Update scan status: @0x4052EF, @0x4052F1
8. Loop back to step 1
```

### 13.4 Cooperative Coroutine Yield

The firmware uses a two-context cooperative coroutine system. The main loop and scan state machine share execution time via `JSR @0x0109E2` (yield). This means:

- The scanner can process USB commands while scanning
- TUR polling works during active scans (returns scan progress)
- Long motor movements yield between steps
- DMA polls yield between checks

---

## Appendix A: Quick Reference -- Minimal Driver Implementation

A minimal driver needs to implement these sequences in order:

### A.1 Connect and Initialize

```
1. Open USB device (VID 0x04B0, PID 0x4001)
2. Poll TUR until Good (up to 30s)
3. INQUIRY -> verify "Nikon" vendor, get product string
4. RESERVE -> claim exclusive access
5. MODE SELECT -> page 0x03, set resolution limits
6. SEND DIAGNOSTIC -> self-test
7. GET WINDOW -> discover vendor extensions
8. READ DTC 0x88 -> calibration boundary data
```

### A.2 Execute a Scan

```
1. SET WINDOW -> resolution, area, depth, multi-sample, ICE
2. WRITE DTC 0x03 -> gamma LUT (if needed)
3. SCAN -> start scanning
4. Poll TUR until scan buffer has data
5. READ DTC 0x87 -> scan parameters (bytes per line, total lines)
6. Loop: READ DTC 0x00 -> image data chunks
7. SEND DIAGNOSTIC -> post-scan cleanup
```

### A.3 Autofocus

```
1. E0 sub=0x46 -> set initial AF motor position
2. C1 -> trigger
3. E0 sub=0x45 -> set exposure
4. C1 -> trigger
5. E1 sub=0x46 -> read focus/contrast data
6. Repeat 1-5 with different positions (contrast maximization)
7. E0 sub=0x46 -> move to best position
8. C1 -> trigger
```

### A.4 Eject Film

```
1. SEND DIAGNOSTIC -> eject command
2. Poll TUR until Good (eject complete)
```

---

## Appendix B: Cross-Reference Index

| Topic | Primary KB Doc |
|-------|---------------|
| USB transport protocol | [usb-protocol.md](../architecture/usb-protocol.md) |
| All SCSI opcodes | [scsi-command-build.md](../components/ls5000-md3/scsi-command-build.md) |
| Scan operation vtables | [scan-operation-vtables.md](../components/ls5000-md3/scan-operation-vtables.md) |
| SET WINDOW descriptor | [set-window-descriptor.md](../scsi-commands/set-window-descriptor.md) |
| Firmware SCSI dispatch | [scsi-handler.md](../components/firmware/scsi-handler.md) |
| Firmware scan state machine | [scan-state-machine.md](../components/firmware/scan-state-machine.md) |
| Firmware calibration | [calibration.md](../components/firmware/calibration.md) |
| Firmware motor control | [motor-control.md](../components/firmware/motor-control.md) |
| Film adapters | [film-adapters.md](../components/firmware/film-adapters.md) |
| Sense code catalog | [sense-codes.md](../scsi-commands/sense-codes.md) |
| NikonScan scan workflows | [scan-workflows.md](../components/nikonscan4-ds/scan-workflows.md) |
| TEST UNIT READY | [test-unit-ready.md](../scsi-commands/test-unit-ready.md) |
| INQUIRY | [inquiry.md](../scsi-commands/inquiry.md) |
| SCAN | [scan.md](../scsi-commands/scan.md) |
| READ | [read.md](../scsi-commands/read.md) |
| WRITE | [write.md](../scsi-commands/write.md) |
| SET WINDOW | [set-window.md](../scsi-commands/set-window.md) |
| GET WINDOW | [get-window.md](../scsi-commands/get-window.md) |
| MODE SELECT | [mode-select.md](../scsi-commands/mode-select.md) |
| MODE SENSE | [mode-sense.md](../scsi-commands/mode-sense.md) |
| SEND DIAGNOSTIC | [send-diagnostic.md](../scsi-commands/send-diagnostic.md) |
| RESERVE | [reserve.md](../scsi-commands/reserve.md) |
| Vendor C0 | [vendor-c0.md](../scsi-commands/vendor-c0.md) |
| Vendor C1 | [vendor-c1.md](../scsi-commands/vendor-c1.md) |
| Vendor E0 | [vendor-e0.md](../scsi-commands/vendor-e0.md) |
| Vendor E1 | [vendor-e1.md](../scsi-commands/vendor-e1.md) |
