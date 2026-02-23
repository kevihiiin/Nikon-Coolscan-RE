# LS5000.md3 SCSI Command Catalog

**Status**: Complete
**Last Updated**: 2026-02-21
**Phase**: 2 (SCSI Commands)
**Confidence**: High (verified from disassembly of CDB builders, command factories, and core execute function)

## Overview

LS5000.md3 constructs and sends SCSI commands to the scanner through the NkDriverEntry transport layer ([API reference](../nkduscan/api.md)). This document catalogs every SCSI opcode used by the module.

**17 unique SCSI opcodes** found across **22 CDB builder sites** in two architectural patterns.

## NkDriverEntry Usage

LS5000.md3 calls NkDriverEntry through a three-layer vtable dispatch chain (see [MAIDEntryPoint doc](maid-entrypoint.md) for full architecture). The following function codes are used:

| FC | Purpose | Callsite | Details |
|----|---------|----------|---------|
| FC1 | Init transport | `0x100a45dc` | Passes "1200" version string (from `0x100c4a58`). Called during scanner open. |
| FC2 | Close transport | `0x100a4694` | First-stage close. Passes output buffer. |
| FC3 | Close cleanup | `0x100a472b` | Second-stage close. Zeroed params. |
| FC5 | Execute SCSI cmd | Via core execute `0x100ae3c0` | All 17 SCSI commands go through FC5. Direction encoded in factory. |

FC4 (Release), FC6-FC9 are not called from the command object architecture but may be used elsewhere in the module.

Source: FC1 at `LS5000.md3:0x100a45a0`, FC2/FC3 in transport close functions.

## Command Architecture

### Two CDB Construction Patterns

**Architecture A: Vtable-based CDB builder objects**
- Object layout: vtable at [this+0], CDB buffer at [this+0x08..0x11] (10 bytes max)
- CDB builder is vtable entry [9] (offset 0x24 from vtable start)
- Builder returns CDB length in `eax` (6 or 10)
- Two clusters of builder functions:
  - **Cluster 1**: `0x100aa1d0-0x100aa6d6` (13 builders for standard + vendor commands)
  - **Cluster 2**: `0x100b51b0-0x100b52d0` (5 builders for READ/WRITE group)
- 11-entry vtable per command class (10 shared + CDB builder at entry[9])
- Two base class groups:
  - **Group A**: vtable[4]=0x100ae630, vtable[8]=0x100ae700 — used by MODE SELECT v1, MODE SENSE, SEND DIAGNOSTIC (one variant)
  - **Group B**: vtable[4]=0x100ae8d0, vtable[8]=0x100ae7b0 — used by most commands. Includes retry on error 9 with 50ms delay.

**Architecture B: Inline CDB construction**
- CDB bytes written directly to buffer via register (edx, ebx, eax)
- Used in scan data read paths and INQUIRY initialization
- 4 sites total

### Command Object Layout (Architecture A)

| Offset | Size | Field |
|--------|------|-------|
| +0x00 | 4 | Vtable pointer |
| +0x04 | 4 | Unknown (possibly flags) |
| +0x08 | 1 | CDB[0] — Operation Code |
| +0x09 | 1 | CDB[1] — Misc bits |
| +0x0A | 1 | CDB[2] — Page/sub-command |
| +0x0B | 1 | CDB[3] |
| +0x0C | 1 | CDB[4] |
| +0x0D | 1 | CDB[5] |
| +0x0E | 1 | CDB[6] (10-byte CDBs only) |
| +0x0F | 1 | CDB[7] |
| +0x10 | 1 | CDB[8] |
| +0x11 | 1 | CDB[9] — Control byte |
| +0x14 | 4 | Transport object pointer |
| +0x18 | 4 | Function code (always 5 for SCSI execute) |
| +0x1C | 4 | Data buffer pointer |
| +0x20 | 4 | Data buffer pointer (secondary) |
| +0x24 | 4 | CommandParams buffer pointer |
| +0x2C | 4 | CDB length (set by vtable[9] return value) |
| +0x50 | 4 | Transfer length (DWORD, decomposed to big-endian bytes) |
| +0x54 | 4 | Data direction (1=data-in, 2=data-out) |
| +0x5C | 1 | Page code (6-byte CDB commands) |
| +0x5D | 1 | Sub-page / additional page param |
| +0x63 | 1 | Mode page header byte |
| +0x64 | 1 | LBA high / sub-command (10-byte CDBs) |
| +0x66 | 1 | LBA mid |
| +0x68 | 1 | LBA low |
| +0x6B | 1 | Additional param byte |
| +0x70 | 1 | Parameter page copy |

### CommandParams Structure (passed to NkDriverEntry FC5)

Built by core execute function at `0x100ae3c0`:

| Offset | Size | Source | Field |
|--------|------|--------|-------|
| +0x00 | 4 | cmd_obj+0x1C | Data buffer pointer |
| +0x04 | 4 | cmd_obj+0x20 | Secondary buffer pointer |
| +0x0C | 4 | 0 | Reserved |
| +0x10 | 4 | 0 | Reserved |
| +0x14 | 4 | cmd_obj+0x2C | CDB length |
| +0x18 | 4 | &cmd_obj+0x08 | CDB buffer pointer |
| +0x1C | 4 | cmd_obj+0x50 | Transfer length |
| +0x20 | 4 | cmd_obj+0x54 | Data direction |
| +0x24 | 4 | 0x20 | Flags/size constant |
| +0x28 | 4 | &cmd_obj+0x30 | Additional params pointer |

Source: `LS5000.md3:0x100ae3c0`

### Execution Flow

1. Caller invokes a **command factory function** with parameters (transport obj, data buffer, transfer length, direction, CDB-specific params)
2. Factory calls base constructor (`0x100ae770` for data commands or `0x100ae720` for no-data commands) with FC=5
3. Factory sets the command-class-specific **vtable pointer** (determines CDB builder)
4. Factory sets CDB-specific parameters (page code, sub-command, etc.) on the object
5. Execution: vtable[8] calls vtable[9] = **CDB builder** (fills CDB bytes at +0x08, returns length)
6. Core execute (`0x100ae3c0`) builds CommandParams struct from object fields
7. NkDriverEntry FC5 called through transport vtable to send CDB + handle data phase

Source: `LS5000.md3:0x100ae770` (factory ctor), `0x100ae7b0` (Group B exec), `0x100ae3c0` (core execute)

### Data Direction Encoding

The command factories pass a direction value to the base constructor:
- **1** = Data-in (scanner → host): scanner sends data to host after CDB
- **2** = Data-out (host → scanner): host sends data to scanner after CDB
- **No direction param** (simple constructor `0x100ae720`): no data phase

This direction is stored at command object offset +0x54 and passed through CommandParams to NkDriverEntry FC5.

Source: Factory functions at `0x100aa2e0` (INQUIRY, push 1), `0x100aa400` (SET WINDOW, push 2), etc.

## Complete SCSI Opcode Catalog

### Standard SCSI Commands (Group 0: 6-byte CDB)

| Opcode | Command | CDB Len | Direction | Factory | Builder | Purpose |
|--------|---------|---------|-----------|---------|---------|---------|
| 0x00 | TEST UNIT READY | 6 | None | `0x100aa2a0` | `0x100aa2d0` | Check scanner ready status |
| 0x12 | INQUIRY | 6 | Data-in | `0x100aa2e0` | `0x100aa5e0` | Get scanner identification |
| 0x15 | MODE SELECT(6) v1 | 6 | Data-out | (Group A) | `0x100aa1d0` | Set scanner mode pages (Group A, fixed 20-byte param) |
| 0x15 | MODE SELECT(6) v2 | 6 | Data-out | `0x100aa440` | `0x100aa490` | Set scanner mode pages (Group B, variable param) |
| 0x16 | RESERVE(6) | 6 | None | `0x100aa330` | `0x100aa360` | Reserve scanner for exclusive use |
| 0x1A | MODE SENSE(6) | 6 | Data-in | (Group A) | `0x100aa280` | Read current mode page values |
| 0x1B | SCAN | 6 | Data-out | `0x100aa540` | `0x100aa6d0` | Start scan operation (sends window list) |
| 0x1D | SEND DIAGNOSTIC (A) | 6 | Data-out | (Group A) | `0x100aa3a0` | Calibration/diagnostic with data |
| 0x1D | SEND DIAGNOSTIC (B) | 6 | None | `0x100aa370` | `0x100aa3a0` | Self-test trigger (no data) |

### Standard SCSI Commands (Group 1: 10-byte CDB)

| Opcode | Command | CDB Len | Direction | Factory | Builder | Purpose |
|--------|---------|---------|-----------|---------|---------|---------|
| 0x24 | SET WINDOW | 10 | Data-out | `0x100aa400` | `0x100aa650` | Set scan area/resolution/mode |
| 0x25 | GET WINDOW | 10 | Data-in | `0x100aa3b0` | `0x100aa610` | Read current scan parameters |
| 0x28 | READ(10) | 10 | Data-in | `0x100b5000` | `0x100b51b0` | Read scan/diagnostic data |
| 0x2A | WRITE(10) | 10 | Data-out | `0x100b50c0` | `0x100b51f0` | Write LUT/calibration data |
| 0x3B | WRITE BUFFER | 10 | Data-out | `0x100b5160` | `0x100b5270` | Write firmware/buffer data |
| 0x3C | READ BUFFER | 10 | Data-in | `0x100b5110` | `0x100b5230` | Read buffer contents |

### Vendor-Specific Commands (Nikon Proprietary)

| Opcode | CDB Len | Direction | Factory | Builder | Purpose |
|--------|---------|-----------|---------|---------|---------|
| 0xC0 | 6 | Unknown | — | `0x100b52d0` | Scanner status primitive (minimal CDB) |
| 0xC1 | 6 | None | `0x100aa580` | `0x100aa5b0` | Scanner control primitive (minimal CDB) |
| 0xE0 | 10 | Data-out | `0x100aa4c0` | `0x100aa670` | Send control parameters (focus, exposure) |
| 0xE1 | 10 | Data-in | `0x100aa500` | `0x100aa6a0` | Read sensor data (focus position, exposure) |

**Vendor command notes**:
- **0xE0/0xE1** use a sub-command byte at CDB[2] to differentiate operations. 0xE0 sends data TO the scanner, 0xE1 reads data FROM the scanner. This is the primary mechanism for focus control, exposure adjustment, and other scanner-specific operations.
- **0xC0/0xC1** are minimal (opcode-only) commands. 0xC1 confirmed as no-data-phase. 0xC0's factory was not found in the standard command object architecture — it may use a different execution path.

### Inline READ(10) Sites (Architecture B)

These are direct CDB constructions in scan data read paths, bypassing the vtable architecture:

| Address | Context |
|---------|---------|
| `0x100866d9` | Scan data read path |
| `0x10086dfa` | Scan data read path |
| `0x1008781a` | Scan data read path |

## Detailed CDB Layouts

### 0x00 TEST UNIT READY
```
Byte 0: 0x00 (opcode)
Bytes 1-5: 0x00 (reserved)
```
Direction: None | Builder: `0x100aa2d0` — Minimal. Only sets byte[0]=0x00, returns 6.
Called 10+ times during init, scan setup, and status polling.

### 0x12 INQUIRY
```
Byte 0: 0x12 (opcode)
Byte 1: EVPD flag (1 if [obj+0x0C]==1, else 0)
Byte 2: Page code (from [obj+0x04] or [obj+0x5C])
Byte 3: 0x00
Byte 4: Allocation length (from [obj+0x08])
Byte 5: Control (0x80 if [obj+0x0D]!=1, else 0x00)
```
Direction: Data-in (36+ bytes standard response) | Architecture A builder: `0x100aa5e0` | Architecture B builder: `0x100a4870`

### 0x15 MODE SELECT(6)
```
Byte 0: 0x15 (opcode)
Byte 1: 0x10 (PF=1, SP=0)
Byte 2: 0x00
Byte 3: 0x00
Byte 4: 0x14 (parameter list length = 20 bytes) [v1] or varies [v2]
Byte 5: 0x00
```
Direction: Data-out |
Two variants:
- **v1** (`0x100aa1d0`, Group A): Writes mode page header at +0x63=8, +0x6B=1, +0x6C=3, copies page/subpage from +0x5C/+0x5D. Fixed 20-byte parameter list.
- **v2** (`0x100aa490`, Group B): Different parameter page layout (+0x6B/+0x73 offsets). Variable-length.

### 0x16 RESERVE(6)
```
Byte 0: 0x16 (opcode)
Bytes 1-5: 0x00
```
Direction: None | Builder: `0x100aa360` — Minimal. Only sets byte[0]=0x16, returns 6.

### 0x1A MODE SENSE(6)
```
Byte 0: 0x1A (opcode)
Byte 1: 0x18 (DBD=1, reserved bits)
Byte 2: Page code (from [obj+0x5C])
Byte 3: 0x00
Byte 4: Allocation length (from [obj+0x50] low byte)
Byte 5: 0x00
```
Direction: Data-in | Builder: `0x100aa280`

### 0x1B SCAN
```
Byte 0: 0x1B (opcode)
Bytes 1-3: 0x00
Byte 4: Transfer length (from [obj+0x50] low byte)
Byte 5: 0x00
```
Direction: Data-out (sends window identifier list) | Builder: `0x100aa6d0`

### 0x1D SEND DIAGNOSTIC
```
Byte 0: 0x1D (opcode)
Byte 1: 0x04 (SelfTest=1)
Bytes 2-5: 0x00
```
Direction: None (Group B, self-test trigger) or Data-out (Group A, diagnostic with parameters) |
Builder: `0x100aa3a0` — Used in both Group A and Group B vtables.

### 0x24 SET WINDOW
```
Byte 0: 0x24 (opcode)
Bytes 1-5: 0x00
Byte 6: Transfer length MSB (from [obj+0x50] >> 16)
Byte 7: Transfer length mid (from [obj+0x50] >> 8)
Byte 8: Transfer length LSB (from [obj+0x50])
Byte 9: 0x80 (control byte, vendor bit set)
```
Direction: Data-out (sends scan window descriptor) | Builder: `0x100aa650`
Control byte 0x80 indicates Nikon vendor extension in the window descriptor.

### 0x25 GET WINDOW
```
Byte 0: 0x25 (opcode)
Byte 1: Single flag (conditional)
Byte 2-4: Reserved/window ID fields
Byte 5: 0x00
Byte 6: Transfer length MSB
Byte 7: Transfer length mid
Byte 8: Transfer length LSB
Byte 9: 0x00
```
Direction: Data-in (returns current scan window descriptor) | Builder: `0x100aa610`

### 0x28 READ(10)
```
Byte 0: 0x28 (opcode)
Byte 1: 0x00
Byte 2: Data type code (from [obj+0x64])
Byte 3: Reserved
Byte 4: Data type qualifier (from [obj+0x66])
Byte 5: Data type qualifier low (from [obj+0x68])
Byte 6: Transfer length MSB (from [obj+0x50] >> 16)
Byte 7: Transfer length mid (from [obj+0x50] >> 8)
Byte 8: Transfer length LSB (from [obj+0x50])
Byte 9: 0x80 (control byte, vendor bit set)
```
Direction: Data-in (scan image data, diagnostic data, calibration data) | Builder: `0x100b51b0`
Two factories exist (`0x100b5000` and `0x100b5060`) for different parameter contexts.

### 0x2A WRITE(10)
```
Byte 0: 0x2A (opcode)
Structure mirrors READ(10) except:
Byte 9: 0x00 (no vendor control bit)
```
Direction: Data-out (LUT tables, calibration data) | Builder: `0x100b51f0`

### 0x3B WRITE BUFFER
```
Byte 0: 0x3B (opcode)
Byte 1: Mode (from [obj+0x64])
Byte 2: Buffer ID (from [obj+0x66])
Byte 3-5: Buffer offset (24-bit, big-endian from [obj+0x68] decomposed)
Byte 6: Parameter list length MSB (from [obj+0x50] >> 16)
Byte 7: Parameter list length mid (from [obj+0x50] >> 8)
Byte 8: Parameter list length LSB (from [obj+0x50])
Byte 9: 0x00
```
Direction: Data-out (firmware update, calibration storage) | Builder: `0x100b5270`

### 0x3C READ BUFFER
```
Structure mirrors WRITE BUFFER.
Byte 0: 0x3C (opcode)
```
Direction: Data-in (buffer readback) | Builder: `0x100b5230`

### 0xC0 VENDOR (Nikon)
```
Byte 0: 0xC0 (opcode)
Bytes 1-5: 0x00
```
Direction: Unknown (factory not found in standard architecture) | Builder: `0x100b52d0` — Minimal.

### 0xC1 VENDOR (Nikon)
```
Byte 0: 0xC1 (opcode)
Bytes 1-5: 0x00
```
Direction: None (confirmed: uses simple constructor without direction) | Builder: `0x100aa5b0` — Minimal.

### 0xE0 VENDOR (Nikon) — Control Write
```
Byte 0: 0xE0 (opcode)
Byte 1: 0x00
Byte 2: Sub-command code (from [obj+0x64])
Bytes 3-5: 0x00
Byte 6: Transfer length MSB (from [obj+0x50] >> 16)
Byte 7: Transfer length mid (from [obj+0x50] >> 8)
Byte 8: Transfer length LSB (from [obj+0x50])
Byte 9: 0x00
```
Direction: **Data-out** (host sends control data to scanner) | Builder: `0x100aa670`
Sub-command at CDB[2] differentiates operations (focus, exposure, etc.).

### 0xE1 VENDOR (Nikon) — Sensor Read
```
Structure mirrors 0xE0.
Byte 0: 0xE1 (opcode)
```
Direction: **Data-in** (scanner sends sensor/status data to host) | Builder: `0x100aa6a0`
Sub-command at CDB[2] differentiates what data is read.

## Commands NOT Present

- **0x03 REQUEST SENSE** — Handled by NKDUSCAN.dll transport layer via custom USB sense opcode 0x06 ([USB Protocol](../../architecture/usb-protocol.md))
- **0x17 RELEASE(6)** — Not used, despite RESERVE(6) being present
- **0x2B SEEK(10)** — Not used
- No opcodes in 0xD0-0xDF or 0xE2-0xFF range

## Vtable Layout

Each command class has a vtable. The factory function sets the vtable pointer (e.g., `mov dword [esi], vtable_addr`). The vtable entry at offset +0x24 is the CDB builder unique to each command.

| # | Offset | Purpose |
|---|--------|---------|
| 0 | +0x00 | Destructor (Group B: 0x100aa5c0, Group A: 0x100aa260) |
| 1 | +0x04 | Base method (0x100ae3a0) — shared |
| 2 | +0x08 | Base method (0x100ae4b0) — shared |
| 3 | +0x0C | Base method (0x100ae3b0) — shared |
| 4 | +0x10 | Group selector (A: 0x100ae630, B: 0x100ae8d0) |
| 5 | +0x14 | Setter (0x100aa240) — shared |
| 6 | +0x18 | Group selector (A: 0x100b2a30, B: 0x100ae7e0) |
| 7 | +0x1C | Group selector (A: 0x100aa250, B: 0x100ae4e0) |
| 8 | +0x20 | Execution method (A: 0x100ae700, B: 0x100ae7b0) — calls entry[9], then core execute |
| 9 | +0x24 | **CDB Builder** (unique per command — returns CDB length in eax) |

**Note**: Vtable pointers in the factories point to the destructor entry (offset +0x00), not to the base methods. Earlier analysis incorrectly documented CDB builder at entry[8]/offset+0x20 — this was due to a 4-byte vtable base offset error.

### Vtable Addresses (Corrected)

| Opcode | Command | Factory Vtable Ptr | CDB Builder (at +0x24) |
|--------|---------|-------------------|----------------------|
| 0x00 | TEST UNIT READY | `0x100c4e34` | `0x100aa2d0` |
| 0x12 | INQUIRY | `0x100c4e5c` | `0x100aa5e0` |
| 0x15 v1 | MODE SELECT (Group A) | `0x100c4de4` | `0x100aa1d0` |
| 0x15 v2 | MODE SELECT (Group B) | `0x100c4f24` | `0x100aa490` |
| 0x16 | RESERVE(6) | `0x100c4e84` | `0x100aa360` |
| 0x1A | MODE SENSE | `0x100c4e0c` | `0x100aa280` |
| 0x1B | SCAN | `0x100c4f9c` | `0x100aa6d0` |
| 0x1D | SEND DIAGNOSTIC (B) | `0x100c4eac` | `0x100aa3a0` |
| 0x24 | SET WINDOW | `0x100c4efc` | `0x100aa650` |
| 0x25 | GET WINDOW | `0x100c4ed4` | `0x100aa610` |
| 0x28 | READ(10) | `0x100c548c` | `0x100b51b0` |
| 0x2A | WRITE(10) | `0x100c54b4` | `0x100b51f0` |
| 0x3B | WRITE BUFFER | `0x100c5504` | `0x100b5270` |
| 0x3C | READ BUFFER | `0x100c54dc` | `0x100b5230` |
| 0xC1 | VENDOR | `0x100c4fc4` | `0x100aa5b0` |
| 0xE0 | VENDOR | `0x100c4f4c` | `0x100aa670` |
| 0xE1 | VENDOR | `0x100c4f74` | `0x100aa6a0` |

## Cross-Model .md3 Comparison

All 4 scanner model modules share the **identical SCSI command set** (17 opcodes, 18 builders per module).

| Property | LS4000.md3 | LS5000.md3 | LS8000.md3 | LS9000.md3 |
|----------|-----------|-----------|-----------|-----------|
| **File size** | 824 KB | 1,028 KB | 936 KB | 1,112 KB |
| **Exports** | 3 (same) | 3 (same) | 3 (same) | 3 (same) |
| **Export names** | MAIDEntryPoint, NkCtrlEntry, NkMDCtrlEntry | (identical) | (identical) | (identical) |
| **NkCtrlEntry mangled** | `?NkCtrlEntry@@YGFFFFPAX@Z` | (identical) | (identical) | (identical) |
| **MAID version** | MD3.01 | **MD3.50** | MD3.01 | MD3.01 |
| **SCSI opcodes** | 17 (identical) | 17 (identical) | 17 (identical) | 17 (identical) |
| **CDB builders** | 18 | 18 | 18 | 18 |
| **Transport refs** | Nkduscan.dll + Nkdsbp2.dll | (identical) | (identical) | (identical) |
| **Model string** | "Nikon LS-4000" | "Nikon LS-5000" | "Nikon LS-8000" | "Nikon LS-9000" |
| **PnP string** | "Nikon LS-4000 Plag and Play" | "Nikon LS-5000 Plag and Play" | "Nikon LS-8000 Plag and Play" | "Nikon LS-9000 Plag and Play" |
| **Scanner types** | LS-40 (USB) + LS-4000 (1394) | LS-50 (USB) + LS-5000 (USB) | LS-8000 (1394) | LS-9000 (1394) |

### Key Observations

1. **Identical SCSI command set**: All models use the same 17 opcodes. No model has unique commands. Model differences are in parameter values (resolution limits, CCD characteristics), not protocol.

2. **Dual transport support**: ALL modules reference BOTH Nkduscan.dll (USB) and Nkdsbp2.dll (FireWire). The module selects transport at runtime based on the connected device. This means the code supports USB and FireWire transparently.

3. **LS5000.md3 is special**: Only module with MAID version MD3.50 (others are MD3.01). This is the newest design (LS-50/LS-5000 are the latest scanner generation). The larger file size reflects additional features.

4. **"Plag and Play" typo**: Present in ALL 4 modules — consistent bug in Nikon's build process.

5. **CDB builder architecture identical**: Same vtable-based command object pattern with CDB builders at vtable entry[9] (offset +0x24). Same two cluster layout. Only addresses differ.

### CDB Builder Address Comparison

| Opcode | LS4000.md3 | LS5000.md3 | LS8000.md3 | LS9000.md3 |
|--------|-----------|-----------|-----------|-----------|
| 0x00 | 0x1008cf10 | 0x100aa2d0 | 0x1009feb0 | 0x100a9170 |
| 0x12 | 0x1008d225 | 0x100aa5e0 | 0x100a01a5 | 0x100a9465 |
| 0x15 v1 | 0x1008ce0e | 0x100aa1d0 | 0x1009fdbe | 0x100a907e |
| 0x15 v2 | 0x1008d0de | 0x100aa490 | 0x100a007e | 0x100a933e |
| 0x16 | 0x1008cfa0 | 0x100aa360 | 0x1009ff40 | 0x100a9200 |
| 0x1A | 0x1008cec9 | 0x100aa280 | 0x1009fe69 | 0x100a9129 |
| 0x1B | 0x1008d316 | 0x100aa6d0 | 0x100a0296 | 0x100a9586 |
| 0x1D | 0x1008cfe0 | 0x100aa3a0 | 0x1009ff80 | 0x100a9240 |
| 0x24 | 0x1008d29e | 0x100aa650 | 0x100a021e | 0x100a94de |
| 0x25 | 0x1008d268 | 0x100aa610 | 0x100a01e8 | 0x100a94a8 |
| 0x28 | 0x10097a30 | 0x100b51b0 | 0x100aad20 | 0x100b2080 |
| 0x2A | 0x10097a80 | 0x100b51f0 | 0x100aad70 | 0x100b20c0 |
| 0x3B | 0x10097afc | 0x100b5270 | 0x100aadec | 0x100b213c |
| 0x3C | 0x10097abc | 0x100b5230 | 0x100aadac | 0x100b20fc |
| 0xC0 | 0x10097b30 | 0x100b52d0 | 0x100aae20 | 0x100b2170 |
| 0xC1 | 0x1008d1f0 | 0x100aa5b0 | 0x100a0190 | 0x100a9450 |
| 0xE0 | 0x1008d2c4 | 0x100aa670 | 0x100a0244 | 0x100a9524 |
| 0xE1 | 0x1008d2f4 | 0x100aa6a0 | 0x100a0274 | 0x100a9564 |

## Cross-References

- [NkDriverEntry API](../nkduscan/api.md) — FC5 executes these commands
- [USB Protocol](../../architecture/usb-protocol.md) — How CDBs are wrapped for USB
- [MAIDEntryPoint](maid-entrypoint.md) — How MAID capabilities map to these commands
- Individual command docs: `docs/kb/scsi-commands/`
