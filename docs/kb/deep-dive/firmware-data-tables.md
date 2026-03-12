# Complete Firmware Data Tables Decode — Nikon LS-50

**Status**: Complete
**Last Updated**: 2026-03-12
**Phase**: 4 (Firmware)
**Confidence**: Verified (all tables decoded from binary hex dumps, cross-referenced with disassembly and KB docs)

## Overview

The LS-50 firmware (512KB, H8/3003, big-endian) contains all data tables in two flash regions:
- **0x16000-0x17200**: Shared module data (speed ramp, stepper phases, sense translation, MODE SENSE defaults, USB descriptors)
- **0x45000-0x528BE**: Main data tables region (SCSI dispatch, task table, DTC tables, VPD tables, vendor registers, string tables, numeric/calibration tables, CCD characterization)

This document provides a complete byte-level decode of every table.

---

## 1. SCSI Handler Dispatch Table (0x49834)

**Size**: 21 entries x 10 bytes = 210 bytes + 2 null bytes = 212 bytes (0x49834-0x49907)
**Accessed by**: `FW:0x20B48` (linear opcode search, 10-byte stride)

### Entry Format (10 bytes, big-endian)

| Offset | Size | Field |
|--------|------|-------|
| 0 | 1 | SCSI opcode |
| 1 | 1 | Padding (always 0x00) |
| 2-3 | 2 | Permission flags (16-bit bitmask) |
| 4-7 | 4 | Handler function pointer (24-bit address in 32-bit field) |
| 8 | 1 | Execution mode |
| 9 | 1 | Padding (always 0x00) |

### Execution Mode Values

| Value | Meaning |
|-------|---------|
| 0x00 | Direct call (handler manages own transfer; used by SCAN) |
| 0x01 | USB state setup before handler (calls `0x1374A`) |
| 0x02 | Data-out (host sends data to device) |
| 0x03 | Data-in (device sends data to host) |

### Permission Flag Patterns

| Flags | Binary | Meaning |
|-------|--------|---------|
| 0x07FF | `0000011111111111` | Always allowed (any state) |
| 0x07FC | `0000011111111100` | All states except initial/diagnostic |
| 0x07D4 | `0000011111010100` | Most states except active scan |
| 0x07CC | `0000011111001100` | Restricted (not during scan/transfer) |
| 0x0754 | `0000011101010100` | Limited (status queries during most states) |
| 0x0254 | `0000001001010100` | Limited to specific states |
| 0x0054 | `0000000001010100` | Only during active read operations |
| 0x0016 | `0000000000010110` | Only in diagnostic/service mode |
| 0x0014 | `0000000000010100` | Requires scanner initialized |

### Complete Table Decode (21 entries)

| # | Hex Bytes (10) | Op | Perm | Handler | Exec | SCSI Command |
|---|----------------|-----|------|---------|------|-------------|
| 0 | `00 00 07D4 00 02 15C2 01 00` | 0x00 | 0x07D4 | 0x0215C2 | 0x01 | TEST UNIT READY |
| 1 | `03 00 07FF 00 02 18 66 03 00` | 0x03 | 0x07FF | 0x021866 | 0x03 | REQUEST SENSE |
| 2 | `12 00 07FF 00 02 5E 18 03 00` | 0x12 | 0x07FF | 0x025E18 | 0x03 | INQUIRY |
| 3 | `15 00 00 14 00 02 19 4A 02 00` | 0x15 | 0x0014 | 0x02194A | 0x02 | MODE SELECT(6) |
| 4 | `16 00 07CC 00 02 1E 3E 01 00` | 0x16 | 0x07CC | 0x021E3E | 0x01 | RESERVE(6) |
| 5 | `17 00 07FC 00 02 1E A0 01 00` | 0x17 | 0x07FC | 0x021EA0 | 0x01 | RELEASE(6) |
| 6 | `1A 00 07D4 00 02 1F 1C 03 00` | 0x1A | 0x07D4 | 0x021F1C | 0x03 | MODE SENSE(6) |
| 7 | `1B 00 00 14 00 02 20 B8 00 00` | 0x1B | 0x0014 | 0x0220B8 | 0x00 | SCAN |
| 8 | `1C 00 00 14 00 02 38 56 03 00` | 0x1C | 0x0014 | 0x023856 | 0x03 | RECEIVE DIAGNOSTIC |
| 9 | `1D 00 00 16 00 02 3D 32 02 00` | 0x1D | 0x0016 | 0x023D32 | 0x02 | SEND DIAGNOSTIC |
| 10 | `24 00 00 14 00 02 6E 38 02 00` | 0x24 | 0x0014 | 0x026E38 | 0x02 | SET WINDOW |
| 11 | `25 00 02 54 00 02 72 F6 03 00` | 0x25 | 0x0254 | 0x0272F6 | 0x03 | GET WINDOW |
| 12 | `28 00 00 54 00 02 3F 10 03 00` | 0x28 | 0x0054 | 0x023F10 | 0x03 | READ(10) |
| 13 | `2A 00 00 14 00 02 55 06 02 00` | 0x2A | 0x0014 | 0x025506 | 0x02 | WRITE/SEND(10) |
| 14 | `3B 00 00 14 00 02 83 7C 02 00` | 0x3B | 0x0014 | 0x02837C | 0x02 | WRITE BUFFER |
| 15 | `3C 00 00 14 00 02 88 84 03 00` | 0x3C | 0x0014 | 0x028884 | 0x03 | READ BUFFER |
| 16 | `C0 00 07 54 00 02 8A B4 01 00` | 0xC0 | 0x0754 | 0x028AB4 | 0x01 | Vendor: Status Query |
| 17 | `C1 00 00 14 00 02 8B 08 01 00` | 0xC1 | 0x0014 | 0x028B08 | 0x01 | Vendor: Trigger Action |
| 18 | `D0 00 07FF 00 01 37 48 01 00` | 0xD0 | 0x07FF | 0x013748 | 0x01 | Vendor: Phase Query |
| 19 | `E0 00 00 14 00 02 8E 16 02 00` | 0xE0 | 0x0014 | 0x028E16 | 0x02 | Vendor: Data Out |
| 20 | `E1 00 00 14 00 02 95 EA 03 00` | 0xE1 | 0x0014 | 0x0295EA | 0x03 | Vendor: Data In |
| -- | `00 00 00 00 00 00 00 00 00 00` | — | — | NULL | — | Terminator (0x49906) |

Note: D0 handler (0x013748) is in the shared module (0x10000-0x17FFF); all others are in main firmware (0x20000+).

---

## 2. Internal Task Table (0x49910)

**Size**: 97 entries x 4 bytes = 388 bytes (0x49910-0x49A93)
**Accessed by**: `FW:0x20DBA` (linear search, 4-byte stride, terminated by 0x0000)

### Entry Format (4 bytes, big-endian)

| Offset | Size | Field |
|--------|------|-------|
| 0-1 | 2 | Task code (high byte = subsystem, low byte = variant) |
| 2-3 | 2 | Handler index (used by task execution function at 0x20DD6) |

### Complete Table (97 entries, in binary order)

| # | Task Code | Handler | Subsystem | Purpose |
|---|-----------|---------|-----------|---------|
| 0 | 0x0920 | 0x0005 | Exposure | Exposure sequence A |
| 1 | 0x0930 | 0x0006 | Exposure | Exposure sequence B |
| 2 | 0x0940 | 0x0077 | Exposure | Exposure sequence C |
| 3 | 0x2000 | 0x000A | Startup | Boot/init task |
| 4 | 0x3000 | 0x0071 | Self-test | Hardware diagnostics |
| 5 | 0x1000 | 0x000B | Power/lamp | Lamp control |
| 6 | 0x8000 | 0x000C | FW reset | Soft restart |
| 7 | 0x4000 | 0x000E | Eject | Media eject |
| 8 | 0x9000 | 0x000F | HW reset | Full hardware reset |
| 9 | 0x7000 | 0x000F | Park/sleep | Low-power mode (shared handler with 0x9000) |
| 10 | 0x0320 | 0x007E | Motor pos | Relative move A |
| 11 | 0x0340 | 0x0082 | Motor pos | Absolute move A |
| 12 | 0x0350 | 0x0083 | Motor pos | Absolute move B |
| 13 | 0x1100 | 0x0078 | Dust detect | Digital ICE support |
| 14 | 0x0600 | 0x0010 | CCD readout | CCD config 0 |
| 15 | 0x0601 | 0x0011 | CCD readout | CCD config 1 |
| 16 | 0x0602 | 0x0012 | CCD readout | CCD config 2 |
| 17 | 0x0603 | 0x0013 | CCD readout | CCD config 3 |
| 18 | 0x0604 | 0x0014 | CCD readout | CCD config 4 |
| 19 | 0x0830 | 0x0015 | Scan | Scan group 3-0 |
| 20 | 0x0831 | 0x0016 | Scan | Scan group 3-1 |
| 21 | 0x0832 | 0x0017 | Scan | Scan group 3-2 |
| 22 | 0x0833 | 0x0018 | Scan | Scan group 3-3 |
| 23 | 0x0834 | 0x0019 | Scan | Scan group 3-4 |
| 24 | 0x0910 | 0x001A | Exposure | Exposure timing 0 |
| 25 | 0x0911 | 0x001B | Exposure | Exposure timing 1 |
| 26 | 0x0912 | 0x001C | Exposure | Exposure timing 2 |
| 27 | 0x0913 | 0x001D | Exposure | Exposure timing 3 |
| 28 | 0x0914 | 0x001E | Exposure | Exposure timing 4 |
| 29 | 0x0F10 | 0x0020 | Error recov | Recovery step 1 |
| 30 | 0x0F20 | 0x0021 | Error recov | Recovery step 2 |
| 31 | 0x0800 | 0x0022 | Scan | Preview scan |
| 32 | 0x0810 | 0x0022 | Scan | Fine scan (shared handler with 0x0800) |
| 33 | 0x0820 | 0x0022 | Scan | Multi-pass scan (shared handler) |
| 34 | 0x0850 | 0x0023 | Scan | Scan variant 5-0 |
| 35 | 0x0851 | 0x0024 | Scan | Scan variant 5-1 |
| 36 | 0x0852 | 0x0025 | Scan | Scan variant 5-2 |
| 37 | 0x0853 | 0x0026 | Scan | Scan variant 5-3 |
| 38 | 0x0854 | 0x0027 | Scan | Scan variant 5-4 |
| 39 | 0x0F30 | 0x0028 | Error recov | Recovery step 3 |
| 40 | 0x0120 | 0x0029 | System init | Init phase A |
| 41 | 0x0121 | 0x002A | System init | Init phase B |
| 42 | 0x0440 | 0x002B | Motor | Motor relative move |
| 43 | 0x0450 | 0x007F | Motor | Motor absolute move |
| 44 | 0x0430 | 0x002C | Motor | Motor home/reference |
| 45 | 0x0F40 | 0x002D | Error recov | Recovery step 4 |
| 46 | 0x0F50 | 0x002E | Error recov | Recovery step 5 |
| 47 | 0x0F60 | 0x002F | Error recov | Recovery step 6 |
| 48 | 0x0400 | 0x0030 | Motor | Motor stop/reset |
| 49 | 0x0300 | 0x0030 | Motor pos | Position stop (shared handler with 0x0400) |
| 50 | 0x0310 | 0x0084 | Motor pos | Position tracking |
| 51 | 0x0502 | 0x0030 | Calibration | Cal shared handler (shared with 0x0400/0x0300) |
| 52 | 0x0500 | 0x0031 | Calibration | Primary calibration |
| 53 | 0x0501 | 0x0032 | Calibration | Secondary calibration |
| 54 | 0x0330 | 0x007B | Motor pos | Position hold |
| 55 | 0x0860 | 0x0033 | Scan | Scan group 6-0 |
| 56 | 0x0861 | 0x0034 | Scan | Scan group 6-1 |
| 57 | 0x0862 | 0x0035 | Scan | Scan group 6-2 |
| 58 | 0x0863 | 0x0036 | Scan | Scan group 6-3 |
| 59 | 0x0864 | 0x0037 | Scan | Scan group 6-4 |
| 60 | 0x0870 | 0x0038 | Scan | Scan group 7-0 |
| 61 | 0x0871 | 0x0039 | Scan | Scan group 7-1 |
| 62 | 0x0872 | 0x003A | Scan | Scan group 7-2 |
| 63 | 0x0873 | 0x003B | Scan | Scan group 7-3 |
| 64 | 0x0874 | 0x003C | Scan | Scan group 7-4 |
| 65 | 0x0610 | 0x003D | CCD readout | Extended CCD config 0 |
| 66 | 0x0611 | 0x003E | CCD readout | Extended CCD config 1 |
| 67 | 0x0612 | 0x003F | CCD readout | Extended CCD config 2 |
| 68 | 0x0613 | 0x0040 | CCD readout | Extended CCD config 3 |
| 69 | 0x0614 | 0x0041 | CCD readout | Extended CCD config 4 |
| 70 | 0x0840 | 0x0042 | Scan | Scan group 4-0 |
| 71 | 0x0841 | 0x0043 | Scan | Scan group 4-1 |
| 72 | 0x0842 | 0x0044 | Scan | Scan group 4-2 |
| 73 | 0x0843 | 0x0045 | Scan | Scan group 4-3 |
| 74 | 0x0844 | 0x0046 | Scan | Scan group 4-4 |
| 75 | 0x0880 | 0x0047 | Scan | Scan group 8-0 |
| 76 | 0x0881 | 0x0048 | Scan | Scan group 8-1 |
| 77 | 0x0882 | 0x0049 | Scan | Scan group 8-2 |
| 78 | 0x0883 | 0x004A | Scan | Scan group 8-3 |
| 79 | 0x0884 | 0x004B | Scan | Scan group 8-4 |
| 80 | 0x0110 | 0x004C | System init | Init phase C |
| 81 | 0x0380 | 0x0073 | Motor pos | Position mode A |
| 82 | 0x0390 | 0x0074 | Motor pos | Position mode B |
| 83 | 0x0200 | 0x0080 | Data mgmt | Data management |
| 84 | 0x0891 | 0x0085 | Scan (ext) | Extended scan 9-1 |
| 85 | 0x0892 | 0x0086 | Scan (ext) | Extended scan 9-2 |
| 86 | 0x0893 | 0x0087 | Scan (ext) | Extended scan 9-3 |
| 87 | 0x0894 | 0x0088 | Scan (ext) | Extended scan 9-4 |
| 88 | 0x08A1 | 0x0089 | Scan (ext) | Extended scan A-1 |
| 89 | 0x08A2 | 0x008A | Scan (ext) | Extended scan A-2 |
| 90 | 0x08A3 | 0x008B | Scan (ext) | Extended scan A-3 |
| 91 | 0x08A4 | 0x008C | Scan (ext) | Extended scan A-4 |
| 92 | 0x08B1 | 0x008D | Scan (ext) | Extended scan B-1 |
| 93 | 0x08B2 | 0x008E | Scan (ext) | Extended scan B-2 |
| 94 | 0x08B3 | 0x008F | Scan (ext) | Extended scan B-3 |
| 95 | 0x08B4 | 0x0090 | Scan (ext) | Extended scan B-4 |
| 96 | 0x1200 | 0x0091 | Extended | Final/extended task |
| -- | 0x0000 | 0x0000 | — | Terminator |

### Subsystem Summary

| Prefix | Count | Subsystem | Handler Range |
|--------|-------|-----------|---------------|
| 0x01xx | 3 | System init | 0x0029-0x004C |
| 0x02xx | 1 | Data mgmt | 0x0080 |
| 0x03xx | 8 | Motor position | 0x0030-0x0084 |
| 0x04xx | 4 | Motor control | 0x002B-0x0030 |
| 0x05xx | 3 | Calibration | 0x0030-0x0032 |
| 0x06xx | 10 | CCD readout | 0x0010-0x0041 |
| 0x08xx | 45 | Scan workflow | 0x0015-0x0090 |
| 0x09xx | 8 | Exposure/timing | 0x0005-0x001E |
| 0x0Fxx | 6 | Error recovery | 0x0020-0x002F |
| 0x10xx | 1 | Power/lamp | 0x000B |
| 0x11xx | 1 | Dust detection | 0x0078 |
| 0x12xx | 1 | Extended | 0x0091 |
| 0x20xx | 1 | Startup | 0x000A |
| 0x30xx | 1 | Self-test | 0x0071 |
| 0x40xx | 1 | Eject | 0x000E |
| 0x70xx | 1 | Park/sleep | 0x000F |
| 0x80xx | 1 | FW reset | 0x000C |
| 0x90xx | 1 | HW reset | 0x000F |

Notable shared handlers: 0x0030 is used by 0x0400, 0x0300, and 0x0502. 0x0022 is used by 0x0800, 0x0810, and 0x0820. 0x000F is shared by 0x7000 and 0x9000.

---

## 3. READ Data Type Code Table (0x49AD8)

**Size**: 15 entries x 12 bytes = 180 bytes + 2 terminator bytes (0x49AD8-0x49B8D)
**Accessed by**: `FW:0x240E2` (READ(10) handler DTC dispatch)

### Entry Format (12 bytes, big-endian)

| Offset | Size | Field | Description |
|--------|------|-------|-------------|
| 0 | 1 | DTC | Data Type Code (CDB byte 2) |
| 1 | 1 | Qualifier category | Controls allowed CDB byte 5 values |
| 2-3 | 2 | Reserved | Always 0x0000 |
| 4-5 | 2 | Max transfer size | 0 = variable/handler-managed |
| 6-9 | 4 | RAM source addr | 0 = handler-specific source |
| 10 | 1 | Sub-handler index | Dispatch group (0x00/0x08/0x0C/0x10/0x20) |
| 11 | 1 | Padding | Always 0x00 |

### Qualifier Category Encoding

| Value | Allowed Qualifiers | Meaning |
|-------|-------------------|---------|
| 0x00 | (ignored) | No qualifier needed |
| 0x01 | Must match entry | Single mode |
| 0x03 | 0, 1, 2, or 3 | Channel select: 0=All, 1=R, 2=G, 3=B |
| 0x10 | 0 or 1 | Two-mode select |
| 0x30 | 0, 1, or 3 | Three-mode select (R/G/B, skipping 2) |

### Complete Table Decode

| # | Raw Hex (12 bytes) | DTC | Qual | MaxSz | RAM Addr | SubIdx |
|---|-------------------|-----|------|-------|----------|--------|
| 0 | `00 10 0000 0000 00000000 00 00` | 0x00 | 0x10 | 0 (var) | — | 0x00 |
| 1 | `03 01 0000 8000 00000000 00 00` | 0x03 | 0x01 | 32768 | — | 0x00 |
| 2 | `81 01 0000 0008 00000000 0C 00` | 0x81 | 0x01 | 8 | — | 0x0C |
| 3 | `84 01 0000 0006 00000000 10 00` | 0x84 | 0x01 | 6 | — | 0x10 |
| 4 | `87 00 0000 0018 00400D45 08 00` | 0x87 | 0x00 | 24 | 0x400D45 | 0x08 |
| 5 | `88 03 0000 0284 00000000 20 00` | 0x88 | 0x03 | 644 | — | 0x20 |
| 6 | `8E 10 0000 0000 00000000 00 00` | 0x8E | 0x10 | 0 (var) | — | 0x00 |
| 7 | `8F 30 0000 0144 00000000 00 00` | 0x8F | 0x30 | 324 | — | 0x00 |
| 8 | `8A 03 0000 000E 00000000 20 00` | 0x8A | 0x03 | 14 | — | 0x20 |
| 9 | `8C 03 0000 000A 00000000 20 00` | 0x8C | 0x03 | 10 | — | 0x20 |
| 10 | `8D 30 0000 0000 00000000 00 00` | 0x8D | 0x30 | 0 (var) | — | 0x00 |
| 11 | `90 03 0000 0036 00000000 00 00` | 0x90 | 0x03 | 54 | — | 0x00 |
| 12 | `92 03 0000 000A 00000000 00 00` | 0x92 | 0x03 | 10 | — | 0x00 |
| 13 | `93 01 0000 000C 00000000 00 00` | 0x93 | 0x01 | 12 | — | 0x00 |
| 14 | `E0 30 0000 0406 00000000 00 00` | 0xE0 | 0x30 | 1030 | — | 0x00 |
| -- | `FF` | — | — | — | — | Terminator |

### Decoded DTC Summary

| DTC | Name | Qual | MaxSize | Sub-handler | Notes |
|-----|------|------|---------|-------------|-------|
| 0x00 | Image Data | two-mode | variable | 0x2413A | Main scan image data |
| 0x03 | Gamma/LUT | single | 32768 | 0x24156 | Gamma correction table |
| 0x81 | Film Frame Info | single | 8 | 0x243DA | Frame boundary data |
| 0x84 | Calibration Data | single | 6 | 0x24266 | Cal readback |
| 0x87 | Scan Parameters | none | 24 | 0x244D2 | RAM copy from 0x400D45 |
| 0x88 | Boundary/Per-Ch Cal | channel | 644 | 0x2452C | Per-channel cal data |
| 0x8A | Exposure/Gain | channel | 14 | 0x24AF0 | Per-channel exposure |
| 0x8C | Offset/Dark Current | channel | 10 | 0x24BB4 | Per-channel dark offset |
| 0x8D | Extended Scan Line | three-mode | variable | 0x24D60 | Extended line data |
| 0x8E | Focus/Measurement | two-mode | variable | 0x24CDE | AF measurement |
| 0x8F | Histogram/Profile | three-mode | 324 | 0x248BC | Histogram data |
| 0x90 | CCD Characterization | channel | 54 | 0x24E84 | CCD sensor data |
| 0x92 | Motor/Positioning | channel | 10 | 0x24F82 | Motor position |
| 0x93 | Adapter/Film Type | single | 12 | 0x24FC4 | Film type info |
| 0xE0 | Extended Config | three-mode | 1030 | 0x25004 | Extended config data |

---

## 4. WRITE Data Type Code Table (0x49B98)

**Size**: 7 entries x 10 bytes = 70 bytes + 2 terminator bytes (0x49B98-0x49BDF)
**Accessed by**: `FW:0x25622` (WRITE/SEND(10) handler DTC dispatch)

### Entry Format (10 bytes, big-endian)

| Offset | Size | Field |
|--------|------|-------|
| 0 | 1 | DTC value |
| 1 | 1 | Qualifier category |
| 2-3 | 2 | Reserved (0x0000) |
| 4-5 | 2 | Max transfer size |
| 6-9 | 4 | Extended parameters (usually 0x00000000) |

### Complete Table Decode

| # | Raw Hex (10 bytes) | DTC | Qual | MaxSize | Extended |
|---|-------------------|-----|------|---------|----------|
| 0 | `03 01 0000 8000 00000000` | 0x03 | 0x01 | 32768 | 0 |
| 1 | `84 01 0000 0000 00000000` | 0x84 | 0x01 | 0 (hdlr) | 0 |
| 2 | `85 01 0000 0000 00000000` | 0x85 | 0x01 | 0 (hdlr) | 0 |
| 3 | `88 03 0000 0284 00000000` | 0x88 | 0x03 | 644 | 0 |
| 4 | `8F 30 0000 0144 00000000` | 0x8F | 0x30 | 324 | 0 |
| 5 | `92 03 0000 0004 00000000` | 0x92 | 0x03 | 4 | 0 |
| 6 | `E0 30 0000 0400 00000000` | 0xE0 | 0x30 | 1024 | 0 |
| -- | `FF` | — | — | — | Terminator |

### Decoded DTC Summary

| DTC | Name | Qual | MaxSize | Sub-handler | Notes |
|-----|------|------|---------|-------------|-------|
| 0x03 | Gamma/LUT | single | 32768 | 0x25650 | Upload gamma table |
| 0x84 | Calibration Upload | single | handler-managed | 0x25722 | 6 bytes internal |
| 0x85 | Extended Cal (WRITE-only) | single | handler-managed | 0x25830 | Not in READ table |
| 0x88 | Boundary/Per-Ch Cal | channel | 644 | 0x258F0 | Per-channel upload |
| 0x8F | Histogram/Profile | three-mode | 324 | 0x2591C | Shared with 0xE0 |
| 0x92 | Motor Control | channel | 4 | 0x25908 | Motor commands |
| 0xE0 | Extended Config | three-mode | 1024 | 0x2591C | Shared handler with 0x8F |

Note: DTC 0x85 exists only in the WRITE table (not READ) -- it is a write-only calibration upload path.

---

## 5. I/O Init Table (0x2001C)

**Size**: 132 entries x 6 bytes = 792 bytes (0x2001C-0x20333)
**Processed by**: `FW:0x2035C` (loop: read 32-bit address + 16-bit value, write low byte to address)

### Entry Format (6 bytes)

| Offset | Size | Field |
|--------|------|-------|
| 0-3 | 4 | Target register address (32-bit, big-endian) |
| 4-5 | 2 | Value (only low byte written) |

### Complete Table (132 entries, in order)

#### H8/3003 CPU Registers (entries 0-29)

| # | Address | Register | Value | Purpose |
|---|---------|----------|-------|---------|
| 0 | 0xFFFFF2 | ABWCR | 0x0B | Bus width: areas 0,1,3=8-bit; 2,4-7=16-bit |
| 1 | 0xFFFFF8 | BRCR | 0x00 | Bus release control |
| 2 | 0xFFFFF9 | CSCR | 0x30 | Chip select config |
| 3 | 0xFFFFF5 | WCER | 0x00 | Wait control enable |
| 4 | 0xFFFFF4 | WCR | 0xBA | Wait state control (3+2+3+2 waits per area) |
| 5 | 0xFFFFEC | P1DDR | 0x85 | Port 1 DDR (bits 0,2,7 output) |
| 6 | 0xFFFFED | P2DDR | 0xFF | Port 2 DDR (all outputs) |
| 7 | 0xFFFFEE | P3DDR | 0xF1 | Port 3 DDR (bits 0,4-7 output) |
| 8 | 0xFFFFEF | P4DDR | 0x48 | Port 4 DDR (bits 3,6 output) |
| 9 | 0xFFFFF3 | ASTCR | 0x00 | Access state control |
| 10 | 0xFFFF60 | TSTR | 0xE0 | Timer start: bits 5-7 set (ITU5,6,7 or ITU2,3,4 in H8/3003) |
| 11 | 0xFFFFCB | SCI0_SMR | 0x80 | SCI0 serial mode: async, 8N1 |
| 12 | 0xFFFFC9 | SCI0_BRR | 0x80 | SCI0 baud rate = 128 |
| 13 | 0xFFFFCF | SCI1_SMR | 0xE0 | SCI1 serial mode |
| 14 | 0xFFFFCD | SCI1_BRR | 0xF4 | SCI1 baud rate = 244 |
| 15 | 0xFFFFD2 | P5DDR | 0xC0 | Port 5 DDR (bits 6-7 output) |
| 16 | 0xFFFFD0 | P3DR | 0xC3 | Port 3 data: bits 0-1, 6-7 high |
| 17 | 0xFFFFD3 | P6DDR | 0x3F | Port 6 DDR (bits 0-5 output) |
| 18 | 0xFFFFD1 | P4DR | 0xFF | Port 4 data: all high |
| 19 | 0xFFFFD6 | P9DDR | 0x00 | Port 9 DDR (all inputs) |
| 20 | 0xFFFFD4 | P7DDR | 0xFF | Port 7 DDR (all outputs) |
| 21 | 0xFFFFD7 | PADDR | 0x01 | Port A DDR (bit 0 output) |
| 22 | 0xFFFFD5 | P8DDR | 0x01 | Port 8 DDR (bit 0 output) |
| 23 | 0xFFFF90 | DMAOR | 0xC0 | DMA operation register |
| 24 | 0xFFFF62 | TCR0 | 0x98 | ITU0 timer control |
| 25 | 0xFFFF64 | TIOR0 | 0xA0 | ITU0 timer I/O control |
| 26 | 0xFFFF6E | TCR2 | 0xC1 | ITU2 timer control |
| 27 | 0xFFFF78 | TCR3 | 0xA3 | ITU3 timer control |
| 28 | 0xFFFF82 | TCR4 | 0xA3 | ITU4 timer control |
| 29 | 0xFFFF92 | TOCR | 0xA0 | Timer output control |

#### Custom ASIC Registers (entries 30-131)

| # | Address | Value | Block | Purpose |
|---|---------|-------|-------|---------|
| 30 | 0x200044 | 0x00 | 0x00 | Control reg cleared |
| 31 | 0x200045 | 0x00 | 0x00 | Control reg cleared |
| 32 | 0x200046 | 0xFF | 0x00 | All bits set (mask) |
| 33 | 0x2000C0 | 0x52 | 0x00 | DAC/ADC master config |
| 34 | 0x2000C1 | 0x04 | 0x00 | DAC/ADC control |
| 35 | 0x200102 | 0x04 | 0x01 | Motor DMA control |
| 36 | 0x200100 | 0x3F | 0x01 | DMA ch0 source config |
| 37 | 0x200101 | 0x3F | 0x01 | DMA ch0 dest config |
| 38 | 0x200103 | 0x01 | 0x01 | DMA channel mode |
| 39 | 0x200104 | 0x30 | 0x01 | DMA ch1 source |
| 40 | 0x200105 | 0x32 | 0x01 | DMA ch1 dest |
| 41 | 0x200106 | 0x34 | 0x01 | DMA ch2 source |
| 42 | 0x200107 | 0x36 | 0x01 | DMA ch2 dest |
| 43 | 0x20010C | 0x20 | 0x01 | DMA ch3 source |
| 44 | 0x20010D | 0x22 | 0x01 | DMA ch3 dest |
| 45 | 0x20010E | 0x24 | 0x01 | DMA ch4 source |
| 46 | 0x20010F | 0x26 | 0x01 | DMA ch4 dest |
| 47 | 0x200114 | 0x00 | 0x01 | DMA ch5 source |
| 48 | 0x200115 | 0x08 | 0x01 | DMA ch5 dest |
| 49 | 0x200116 | 0x10 | 0x01 | DMA ch6 source |
| 50 | 0x200117 | 0x18 | 0x01 | DMA ch6 dest |
| 51 | 0x200140 | 0x01 | 0x01 | DMA enable |
| 52 | 0x200141 | 0x01 | 0x01 | DMA mode |
| 53 | 0x200142 | 0x04 | 0x01 | DMA transfer config |
| 54 | 0x200150 | 0x03 | 0x01 | DMA interrupt enable |
| 55 | 0x200147 | 0x00 | 0x01 | Buffer addr low |
| 56 | 0x200148 | 0x00 | 0x01 | Buffer addr mid |
| 57 | 0x200149 | 0x00 | 0x01 | Buffer addr high |
| 58 | 0x20014B | 0x00 | 0x01 | Transfer count low |
| 59 | 0x20014C | 0x40 | 0x01 | Transfer count mid (=16384) |
| 60 | 0x20014D | 0x00 | 0x01 | Transfer count high |
| 61 | 0x200143 | 0x01 | 0x01 | Buffer control |
| 62 | 0x200144 | 0x04 | 0x01 | Buffer mode |
| 63 | 0x20014E | 0x00 | 0x01 | DMA status |
| 64 | 0x20014F | 0x04 | 0x01 | DMA control 2 |
| 65 | 0x200181 | 0x0D | 0x01 | Motor drive config A |
| 66 | 0x200193 | 0x0E | 0x01 | Motor drive config B |
| 67 | 0x2001C0 | 0x03 | 0x01 | Line timing mode |
| 68 | 0x2001C1 | 0x00 | 0x01 | Line timing control |
| 69 | 0x2001C2 | 0x0F | 0x01 | Pixel clock divider |
| 70 | 0x2001C3 | 0x98 | 0x01 | Line period low |
| 71 | 0x2001C4 | 0x00 | 0x01 | Line period high |
| 72 | 0x2001C5 | 0x19 | 0x01 | Integration start |
| 73 | 0x2001C8 | 0x00 | 0x01 | Readout start |
| 74 | 0x2001C9 | 0x18 | 0x01 | Readout config |
| 75 | 0x2001C6 | 0x0F | 0x01 | Integration config |
| 76 | 0x2001C7 | 0x69 | 0x01 | Integration end |
| 77 | 0x200200 | 0x00 | 0x02 | CCD channel master |
| 78 | 0x200204 | 0x04 | 0x02 | CCD ch0 config |
| 79 | 0x200205 | 0x03 | 0x02 | CCD ch0 mode |
| 80 | 0x200400 | 0x20 | 0x04 | CCD master mode |
| 81 | 0x200401 | 0x0A | 0x04 | CCD pixel clock |
| 82 | 0x200402 | 0x00 | 0x04 | CCD control |
| 83 | 0x200404 | 0x00 | 0x04 | CCD config A |
| 84 | 0x200405 | 0xFF | 0x04 | CCD data mask |
| 85 | 0x200406 | 0x01 | 0x04 | CCD enable |
| 86 | 0x200408 | 0x01 | 0x04 | Integration timing grp1-0 |
| 87 | 0x200409 | 0x41 | 0x04 | Integration timing grp1-1 |
| 88 | 0x20040A | 0x00 | 0x04 | Integration timing grp1-2 |
| 89 | 0x20040B | 0x09 | 0x04 | Integration timing grp1-3 |
| 90 | 0x20040C | 0x00 | 0x04 | Integration timing grp1-4 |
| 91 | 0x20040D | 0x19 | 0x04 | Integration timing grp1-5 |
| 92 | 0x20040E | 0x01 | 0x04 | Integration timing grp2-0 |
| 93 | 0x20040F | 0x2B | 0x04 | Integration timing grp2-1 |
| 94 | 0x200410 | 0x00 | 0x04 | Integration timing grp2-2 |
| 95 | 0x200411 | 0x0D | 0x04 | Integration timing grp2-3 |
| 96 | 0x200412 | 0x00 | 0x04 | Integration timing grp2-4 |
| 97 | 0x200413 | 0x15 | 0x04 | Integration timing grp2-5 |
| 98 | 0x200414 | 0x01 | 0x04 | Integration timing grp3-0 |
| 99 | 0x200415 | 0x2B | 0x04 | Integration timing grp3-1 |
| 100 | 0x200416 | 0x00 | 0x04 | Integration timing grp3-2 |
| 101 | 0x200417 | 0x0D | 0x04 | Integration timing grp3-3 |
| 102 | 0x200418 | 0x00 | 0x04 | Integration timing grp3-4 |
| 103 | 0x200419 | 0x15 | 0x04 | Integration timing grp3-5 |
| 104 | 0x20041A | 0x01 | 0x04 | Integration timing grp4-0 |
| 105 | 0x20041B | 0x29 | 0x04 | Integration timing grp4-1 |
| 106 | 0x20041C | 0x00 | 0x04 | Integration timing grp4-2 |
| 107 | 0x20041D | 0x02 | 0x04 | Integration timing grp4-3 |
| 108 | 0x20041E | 0x00 | 0x04 | Integration timing grp4-4 |
| 109 | 0x20041F | 0x20 | 0x04 | Integration timing grp4-5 |
| 110 | 0x200420 | 0x01 | 0x04 | Integration timing grp5-0 |
| 111 | 0x200421 | 0x2F | 0x04 | Integration timing grp5-1 |
| 112 | 0x200422 | 0x00 | 0x04 | Integration timing grp5-2 |
| 113 | 0x200423 | 0x05 | 0x04 | Integration timing grp5-3 |
| 114 | 0x200424 | 0x00 | 0x04 | Integration timing grp5-4 |
| 115 | 0x200425 | 0x1D | 0x04 | Integration timing grp5-5 |
| 116 | 0x200456 | 0x00 | 0x04 | Gain channel select |
| 117 | 0x200457 | 0x63 | 0x04 | Analog gain ch1 (99) |
| 118 | 0x200458 | 0x63 | 0x04 | Analog gain ch2 (99) |
| 119 | 0x20046D | 0x00 | 0x04 | Per-ch0 timing offset |
| 120 | 0x20046E | 0x01 | 0x04 | Per-ch0 timing start |
| 121 | 0x20046F | 0x2B | 0x04 | Per-ch0 timing end |
| 122 | 0x200475 | 0x00 | 0x04 | Per-ch1 timing offset |
| 123 | 0x200476 | 0x01 | 0x04 | Per-ch1 timing start |
| 124 | 0x200477 | 0x2B | 0x04 | Per-ch1 timing end |
| 125 | 0x20047D | 0x00 | 0x04 | Per-ch2 timing offset |
| 126 | 0x20047E | 0x01 | 0x04 | Per-ch2 timing start |
| 127 | 0x20047F | 0x2B | 0x04 | Per-ch2 timing end |
| 128 | 0x200485 | 0x00 | 0x04 | Per-ch3 timing offset |
| 129 | 0x200486 | 0x01 | 0x04 | Per-ch3 timing start |
| 130 | 0x200487 | 0x2B | 0x04 | Per-ch3 timing end |
| 131 | 0x200001 | 0x80 | 0x00 | **ASIC master enable** (last entry) |

---

## 6. INQUIRY VPD Tables

### Standard VPD Table (0x49C20)

**Size**: 8 entries x 6 bytes = 48 bytes (but table area extends beyond with more entries)
**Entry format**: `page_code:8, field:8, handler_ptr:32`

| # | Raw Hex (6 bytes) | Page | Field | Handler |
|---|-------------------|------|-------|---------|
| 0 | `00 00 000260BA` | 0x00 | 0x00 | 0x0260BA |
| 1 | `01 00 00026178` | 0x01 | 0x00 | 0x026178 |
| 2 | `10 00 00026178` | 0x10 | 0x00 | 0x026178 |
| 3 | `40 00 00026178` | 0x40 | 0x00 | 0x026178 |
| 4 | `41 00 00026178` | 0x41 | 0x00 | 0x026178 |
| 5 | `50 00 00026178` | 0x50 | 0x00 | 0x026178 |
| 6 | `51 00 00026178` | 0x51 | 0x00 | 0x026178 |
| 7 | `52 00 00026178` | 0x52 | 0x00 | 0x026178 |

### Extended VPD Entries (0x49C50)

Additional VPD dispatch entries follow the standard table:

| Page | Handler | Purpose |
|------|---------|---------|
| 0x60 | 0x026178 | Extended page |
| 0x61 | 0x026178 | Extended page |
| 0xC1 | 0x02625E | Special page (unique handler) |
| 0xD1 | 0x026794 | Diagnostic page |
| 0xE1 | 0x02685C | Extension page |
| 0xF0 | 0x0269F0 | Firmware info page |

### Adapter-Specific VPD Table (0x49C74)

**Size**: 8 adapters x 5 entries x 6 bytes = 240 bytes
**Entry format**: `page_code:8, field:8, handler_ptr:32` (0xFF = unused slot)

| Adapter | Idx | Pages (handler addresses) |
|---------|-----|--------------------------|
| 0 (none) | 0 | F8(0x026C70), FA(0x026D86), FB(0x026DD6), FC(0x026DAA) |
| 1 (Mount) | 1 | 46(0x026178) |
| 2 (Strip) | 2 | 43(0x026178), 44(0x026178), E2(0x026CC6) |
| 3 (240) | 3 | 45(0x026178), F1(0x026C1C) |
| 4 (Feeder) | 4 | 46(0x026178), E2(0x026CC6) |
| 5 (6Strip) | 5 | 47(0x026178), E2(0x026CC6) |
| 6 (36Strip) | 6 | 10(0x026178) |
| 7 (Test) | 7 | (no entries -- factory test jig) |

### VPD Supported Pages List (0x49D44)

Two page list arrays for INQUIRY VPD page 0x00 responses:

**List 1** (no adapter): `00 01 40 41 46 50 51 60 61 C1 D1 E1 F0 F8 FB FC FF`
**List 2** (with adapter): `01 40 41 43 50 51 60 61` (varies by adapter)

---

## 7. Vendor Register Table (0x4A134)

**Size**: 23 entries x 2 bytes + 1 terminator = 47 bytes (0x4A134-0x4A163)
**Accessed by**: E0/E1 handlers at `FW:0x028E16`/`FW:0x0295EA`

### Entry Format (2 bytes)

| Offset | Size | Field |
|--------|------|-------|
| 0 | 1 | Register ID |
| 1 | 1 | Max data length (0 = trigger only) |

### Complete Table Decode

| # | Hex | Reg ID | MaxLen | Group | Purpose |
|---|-----|--------|--------|-------|---------|
| 0 | `80 00` | 0x80 | 0 | Control | Lamp on/off (trigger only) |
| 1 | `81 00` | 0x81 | 0 | Control | Lamp status (trigger only) |
| 2 | `91 05` | 0x91 | 5 | Motor | CCD/motor config |
| 3 | `A0 09` | 0xA0 | 9 | Sensor | Exposure/focus params |
| 4 | `B0 00` | 0xB0 | 0 | Motor | State change (trigger only) |
| 5 | `B1 00` | 0xB1 | 0 | Motor | State change (trigger only) |
| 6 | `C0 05` | 0xC0 | 5 | Cal | Gain calibration |
| 7 | `C1 05` | 0xC1 | 5 | Cal | Offset calibration |
| 8 | `D0 00` | 0xD0 | 0 | Status | Status readback (trigger only) |
| 9 | `D1 00` | 0xD1 | 0 | Status | Status readback (trigger only) |
| 10 | `D2 05` | 0xD2 | 5 | Status | Status readback data |
| 11 | `D5 05` | 0xD5 | 5 | Status | Extended diagnostic |
| 12 | `40 0B` | 0x40 | 11 | Scan | Scan control params |
| 13 | `41 0B` | 0x41 | 11 | Scan | Calibration data |
| 14 | `42 0B` | 0x42 | 11 | Scan | Gain values |
| 15 | `46 0B` | 0x46 | 11 | Scan | Focus position |
| 16 | `47 0B` | 0x47 | 11 | Scan | Lamp settings |
| 17 | `43 0B` | 0x43 | 11 | Scan | Offset values |
| 18 | `44 05` | 0x44 | 5 | Scan | Motor position |
| 19 | `45 0B` | 0x45 | 11 | Scan | Exposure time |
| 20 | `B3 0D` | 0xB3 | 13 | Motor | Extended motor control |
| 21 | `B4 09` | 0xB4 | 9 | Motor | Motor position B4 |
| 22 | `D6 05` | 0xD6 | 5 | Config | Persistent settings |
| -- | `FF` | — | — | — | Terminator |

Note: Register IDs are NOT contiguous. Missing IDs: B2, D3, D4.

---

## 8. ASIC RAM Bank Descriptor Table (0x49A94)

**Size**: 18 entries x 4 bytes = 72 bytes (0x49A94-0x49ADB)
**Used for**: DMA target validation

| # | Hex | Bank Address | Spacing |
|---|-----|-------------|---------|
| 0 | `00000000` | 0x000000 | Null sentinel |
| 1 | `00800000` | 0x800000 | — |
| 2 | `00808000` | 0x808000 | 32KB |
| 3 | `00810000` | 0x810000 | 32KB |
| 4 | `00818000` | 0x818000 | 32KB |
| 5 | `00820000` | 0x820000 | 32KB |
| 6 | `00822000` | 0x822000 | 8KB |
| 7 | `00824000` | 0x824000 | 8KB |
| 8 | `00826000` | 0x826000 | 8KB |
| 9 | `00828000` | 0x828000 | 8KB |
| 10 | `0082A000` | 0x82A000 | 8KB |
| 11 | `0082C000` | 0x82C000 | 8KB |
| 12 | `0082E000` | 0x82E000 | 8KB |
| 13 | `00830000` | 0x830000 | 8KB |
| 14 | `00832000` | 0x832000 | 8KB |
| 15 | `00834000` | 0x834000 | 8KB |
| 16 | `00836000` | 0x836000 | 8KB |
| -- | followed by READ DTC table | — | — |

16 banks: 4x32KB (0x800000-0x81FFFF) + 12x8KB (0x820000-0x837FFF) = 224KB.

---

## 9. String Tables

### INQUIRY Response Template (0x49E31)

```
"Nikon   LS-50 ED        1.02"
```
28 bytes: 8-byte vendor ("Nikon   ") + 16-byte product ("LS-50 ED        ") + 4-byte revision ("1.02").

### LS-5000 Variant String (0x16674)

```
"Nikon   LS-5000-123456  123456"
```
Template with placeholder serial "123456". Used when model flag at 0x404E96 is non-zero.

### LS-50 INQUIRY + Serial (0x170D6)

```
"Nikon   LS-50 ED        1.02DF17811"
```
INQUIRY template followed by serial number "DF17811".

### Film Adapter Names (0x49E4D-0x49E77)

| Address | String | Null-terminated |
|---------|--------|----------------|
| 0x49E4D | `Mount` | Yes |
| 0x49E53 | `Strip` | Yes |
| 0x49E59 | `240` | Yes |
| 0x49E5D | `Feeder` | Yes |
| 0x49E64 | `6Strip` | Yes |
| 0x49E6B | `36Strip` | Yes |
| 0x49E73 | `Test` | Yes (factory jig) |

### Film Holder Names (0x49E78-0x49E88)

| Address | String |
|---------|--------|
| 0x49E78 | `FH-3` |
| 0x49E7D | `FH-G1` |
| 0x49E83 | `FH-A1` |

### Motor Subsystem Names (0x49E89-0x49E9B)

| Address | String |
|---------|--------|
| 0x49E89 | `SCAN Motor` |
| 0x49E94 | `AF Motor` |

### Positioning Object Names (0x49E9D-0x49EDB)

| Address | String | Adapter |
|---------|--------|---------|
| 0x49E9D | `SA_OBJECT` | Strip |
| 0x49EA7 | `240_OBJECT` | APS/240 |
| 0x49EB2 | `240_HEAD` | APS/240 head |
| 0x49EBB | `FD_OBJECT` | Feeder |
| 0x49EC5 | `6SA_OBJECT` | 6-Strip |
| 0x49ED0 | `36SA_OBJECT` | 36-Strip |

### Calibration Parameter Names (0x49EDC-0x49EFB)

| Address | String | Purpose |
|---------|--------|---------|
| 0x49EDC | `DA_COARSE` | Coarse DAC adjustment |
| 0x49EE6 | `DA_FINE` | Fine DAC adjustment |
| 0x49EEE | `EXP_TIME` | Exposure time |
| 0x49EF7 | `GAIN` | Analog gain |

### String Pointer Table (0x49EFC)

24 entries x 4 bytes = 96 bytes. Maps indices to string addresses:

| Index | Pointer | Points To |
|-------|---------|-----------|
| 0 | 0x00049E64 | 6Strip |
| 1 | 0x00049E59 | 240 |
| 2 | 0x00049E5D | Feeder |
| 3 | 0x00049E64 | 6Strip (duplicate) |
| 4 | 0x00049E6B | 36Strip |
| 5 | 0x00049E4D | Mount |
| 6 | 0x00049E73 | Test |
| 7 | 0x00049E4D | Mount (duplicate) |
| 8 | 0x00049E78 | FH-3 |
| 9 | 0x00049E7D | FH-G1 |
| 10 | 0x00049E83 | FH-A1 |
| 11 | 0x00049E89 | SCAN Motor |
| 12 | 0x00049E94 | AF Motor |
| 13 | 0x00049E9D | SA_OBJECT |
| 14 | 0x00049EA7 | 240_OBJECT |
| 15 | 0x00049EBB | FD_OBJECT (note: skips 240_HEAD) |
| 16 | 0x00049EC5 | 6SA_OBJECT |
| 17 | 0x00049ED0 | 36SA_OBJECT |
| 18 | 0x00000000 | NULL separator |
| 19 | 0x00049EDC | DA_COARSE |
| 20 | 0x00049EE6 | DA_FINE |
| 21 | 0x00049EEE | EXP_TIME |
| 22 | 0x00049EF7 | GAIN |

Indices 0-7 map GPIO Port 7 values to adapter names (with duplicates at 3 and 7).

---

## 10. USB Descriptors (0x170FA-0x1715D)

### USB 1.1 Device Descriptor (0x170FA, 18 bytes)

```
12 01 10 01 FF FF FF 40 B0 04 01 40 02 01 01 02 03 01
```

| Offset | Value | Field |
|--------|-------|-------|
| 0 | 0x12 | bLength = 18 |
| 1 | 0x01 | bDescriptorType = DEVICE |
| 2-3 | 0x0110 | bcdUSB = 1.10 |
| 4 | 0xFF | bDeviceClass = Vendor-specific |
| 5 | 0xFF | bDeviceSubClass = Vendor-specific |
| 6 | 0xFF | bDeviceProtocol = Vendor-specific |
| 7 | 0x40 | bMaxPacketSize0 = 64 |
| 8-9 | 0x04B0 | idVendor = 0x04B0 (Nikon) |
| 10-11 | 0x4001 | idProduct = 0x4001 (LS-50) |
| 12-13 | 0x0102 | bcdDevice = 1.02 |
| 14 | 0x01 | iManufacturer = string 1 |
| 15 | 0x02 | iProduct = string 2 |
| 16 | 0x03 | iSerialNumber = string 3 |
| 17 | 0x01 | bNumConfigurations = 1 |

### USB 2.0 Device Descriptor (0x1710C, 18 bytes)

```
12 01 00 02 FF FF FF 40 B0 04 01 40 02 01 01 02 03 01
```

Identical except bcdUSB = 0x0200 (USB 2.0).

### USB 1.1 Endpoint Descriptors (0x1711E, 2 x 7 bytes)

**EP1 OUT Bulk**:
```
07 05 01 02 40 00 00 00
```
- bEndpointAddress = 0x01 (EP1, OUT)
- bmAttributes = 0x02 (Bulk)
- wMaxPacketSize = 0x0040 (64 bytes)

**EP2 IN Bulk**:
```
07 05 82 02 40 00 00 00
```
- bEndpointAddress = 0x82 (EP2, IN)
- bmAttributes = 0x02 (Bulk)
- wMaxPacketSize = 0x0040 (64 bytes)

### USB 2.0 Endpoint Descriptors (0x1712E, 2 x 7 bytes)

**EP1 OUT Bulk**:
```
07 05 01 02 00 02 00 00
```
- wMaxPacketSize = 0x0200 (512 bytes)

**EP2 IN Bulk**:
```
07 05 82 02 00 02 00 00
```
- wMaxPacketSize = 0x0200 (512 bytes)

### USB 1.1 Configuration Descriptor (0x1713E, 9 bytes)

```
09 02 20 00 01 01 00 C0 01 00
```
- wTotalLength = 0x0020 (32 bytes)
- bNumInterfaces = 1
- bConfigurationValue = 1
- bmAttributes = 0xC0 (Self-powered)
- bMaxPower = 0x01 (2 mA)

### USB 2.0 Configuration Descriptor (0x17148, 9 bytes)

Same layout as USB 1.1 config.

### Interface Descriptors (0x17152+)

```
09 04 00 00 02 FF FF FF 00
```
- bInterfaceNumber = 0
- bNumEndpoints = 2
- bInterfaceClass = 0xFF (Vendor-specific)
- bInterfaceSubClass = 0xFF
- bInterfaceProtocol = 0xFF

---

## 11. Speed Ramp Tables

### Primary Linear Ramp (0x16C38, 33 x 16-bit = 66 bytes)

Timer compare values for stepper motor acceleration/deceleration. Perfectly linear progression:

```
0038 0040 0048 0050 0058 0060 0068 0070  | 56 64 72 80 88 96 104 112
0078 0080 0088 0090 0098 00A0 00A8 00B0  | 120 128 136 144 152 160 168 176
00B8 00C0 00C8 00D0 00D8 00E0 00E8 00F0  | 184 192 200 208 216 224 232 240
00F8 0100 0108 0110 0118 0120 0128 0130  | 248 256 264 272 280 288 296 304
0138                                     | 312
```

Smaller value = shorter interrupt period = faster step rate. Traversed backward for acceleration (312 to 56), forward for deceleration (56 to 312).

### Stepper Phase Tables

**Forward (0x16E92)**: `01 02 04 08` -- unipolar wave drive, A-B-/A-/B
**Reverse (0x4A8A8)**: `08 04 02 01` -- reverse sequence, /B-/A-B-A

### Variant Ramp Tables (0x459D2+)

Multiple resolution/adapter-specific ramp tables. These contain H8/300H code mixed with inline data constants, structured as computed-goto lookup tables for different scan speed profiles. Six major variants start at:

| Address | Start Value | End Value | Use |
|---------|-------------|-----------|-----|
| 0x459D2 | 64 | ~28512 | Resolution A forward |
| 0x45A12 | 64 | ~27562 | Resolution A reverse |
| 0x45C3A | 98 | ~28512 | Resolution B forward |
| 0x45C78 | 98 | ~27562 | Resolution B reverse |
| 0x45EA2 | 132 | ~28512 | Resolution C forward |
| 0x45EE0 | 132 | ~27562 | Resolution C reverse |

---

## 12. Sense Code Translation Table (0x16DEE)

**Size**: ~164 bytes (0x16DEE-0x16E91)
**Accessed by**: REQUEST SENSE handler at `FW:0x021866`

Maps internal 16-bit sense codes (from RAM 0x4007B0) to standard SCSI sense format:

### Entry Format (variable length)

Each entry: `internal_code:16, sense_key:8, ASC:8, ASCQ:8, [FRU:8]`

### Key Entries (decoded from hex)

| Internal Code | SK | ASC | ASCQ | FRU | SCSI Meaning |
|--------------|-----|-----|------|-----|-------------|
| 0x0000 | 0x00 | 0x00 | 0x00 | — | No sense |
| 0x00C0 | 0x00 | 0x00 | 0x00 | — | No sense (alt) |
| 0x0080 | 0x00 | 0x00 | 0x00 | 0x80 | No sense with FRU |
| 0x0007 | 0x02 | 0x04 | 0x01 | — | Not ready, becoming ready |
| 0x0008 | 0x02 | 0x04 | 0x01 | 0x01 | Not ready (USB init) |
| 0x0009 | 0x02 | 0x04 | 0x01 | 0x02 | Not ready (encoder) |
| 0x000A | 0x02 | 0x04 | 0x02 | — | Not ready, init required |
| 0x000D | 0x02 | 0x05 | 0x00 | — | Not ready, LU not respond |
| 0x0050 | 0x05 | 0x24 | 0x00 | — | Illegal request, invalid CDB |
| 0x0053 | 0x05 | 0x26 | 0x00 | — | Illegal request, invalid param |
| 0x0059 | 0x05 | 0x39 | 0x00 | — | Saving params not supported |
| 0x0061 | 0x02 | 0x04 | 0x01 | — | USB communication error |
| 0x0071 | 0x02 | 0x04 | 0x02 | — | Scan timeout, reinit needed |
| 0x0079 | 0x02 | 0x04 | 0x01 | 0x03 | Motor busy (positioning) |
| 0x007A | 0x02 | 0x04 | 0x01 | 0x04 | Calibration in progress |

---

## 13. MODE SENSE Default Data (0x168AF)

**Size**: 8 bytes at 0x168AF
**Used by**: MODE SENSE handler page control = 2 (default values)

```
03 06 0000 04B0 0000
```

| Offset | Value | Field |
|--------|-------|-------|
| 0 | 0x03 | Page code |
| 1 | 0x06 | Page length |
| 2-3 | 0x0000 | Reserved |
| 4-5 | 0x04B0 | Base resolution: 1200 DPI |
| 6-7 | 0x0000 | Pad |

Additional data at 0x168B7:
```
000F A00F A000
```
Max X = 0x0FA0 (4000 units), Max Y = 0x0FA0 (4000 units).

---

## 14. Numeric/Calibration Tables (0x4A200-0x4A8AB)

### Trigonometric Table (0x4A200-0x4A28F, 144 bytes)

Two sections:
- **0x4A200-0x4A20F** (16 bytes): Packed sine/cosine base values in big-endian double-precision fragments
- **0x4A210-0x4A28F** (128 bytes): Interleaved sin/cos lookup, 4-bit packed entries

### Logarithmic Bitmask Lookup (0x4A2A6-0x4A2D7, 50 bytes)

Pattern: 0x40/0xC0 entries forming a bitmask decode table:
```
40 40 40 40 40 40 40 40 40 40 C0 40 40 40 40 40
40 40 40 40 C0 C0 40 40 40 40 40 40 40 40 C0 C0
C0 40 40 40 40 40 40 40 C0 C0 C0 C0 40 40 40 40
40 40
```
Used in calibration math for bit-depth-dependent processing.

### BCD Encoding Table (0x4A394, 16 bytes)

```
30 32 34 36 28 2A 2C 2E 20 22 24 26 00 08 10 18
```
Maps nibble values (0-15) to display encoding for debug/diagnostic output.

### CCD Characterization Pointer Table (0x4A37E, 12 bytes)

| Entry | Pointer | Target |
|-------|---------|--------|
| 0 | 0x0004A8BC | Section 1 |
| 1 | 0x0004A8BC | Section 1 (duplicate) |
| 2 | 0x0004E8BD | Section 2 |

### ASIC Register Address Table (0x4A3A4, 32 bytes)

Pairs of ASIC register addresses for CCD channel configuration:

```
00C00000 00C08000  -- Buffer RAM bank addresses
00200214 0020021C  -- CCD ch0/ch1 data registers
00200224 0020022C  -- CCD ch2/ch3 data registers
00200215 0020021D  -- CCD ch0/ch1 mode registers
00200225 0020022D  -- CCD ch2/ch3 mode registers
00200468 00200470  -- Per-channel timing ch0/ch1
00200478 00200480  -- Per-channel timing ch2/ch3
0020010C 0020010D  -- DMA ch3/ch4 source
0020010E 0020010F  -- DMA ch5/ch6 source
```

### Floating-Point Constants (0x4A430-0x4A51F, 240 bytes)

IEEE 754 double-precision (big-endian) calibration constants:

| Address | Hex (8 bytes) | Value | Purpose |
|---------|--------------|-------|---------|
| 0x4A430 | `00000000 40590000` | 100.0 | Percentage base |
| 0x4A438 | `00000000 406FE000` | 255.0 | 8-bit max |
| 0x4A448 | `00000000 40CFFF80` | 16383.75 | 14-bit max (CCD) |
| 0x4A450 | `00000000 40240000` | 10.0 | Decimal base |
| 0x4A458 | `00000000 40180000` | 6.0 | Channel count |
| 0x4A460 | `00000000 40CCCC00` | ~14745.6 | Cal constant |
| 0x4A468 | `00000000 40AFFE00` | ~4095.75 | 12-bit max |
| 0x4A488 | `00000000 40500000` | 64.0 | USB packet size |
| 0x4A490 | `00000000 40568000` | 90.0 | Angle constant |
| 0x4A498 | `3FECCCCC CCCCCCCD` | 0.9 | 90% threshold |

### CCD Channel Remap Table (0x4A520-0x4A55F, 64 bytes)

8 repetitions of the 6-byte sequence `04 01 02 03 05 00`:

```
04 01 02 03 05 00  (repeat x8)
```

Maps CCD physical channels to logical color channels:
- Physical 0 -> Logical 4 (IR)
- Physical 1 -> Logical 1 (Red)
- Physical 2 -> Logical 2 (Green)
- Physical 3 -> Logical 3 (Blue)
- Physical 4 -> Logical 5 (spare/reference)
- Physical 5 -> Logical 0 (dark reference)

Followed by 8 bytes: `01 01 01 01 01 01 02 02` (channel enable flags).

### Resolution/Geometry Constants (0x4A560-0x4A57F, 32 bytes)

Six 32-bit scan geometry values:

| Address | Value | Decimal | Likely meaning |
|---------|-------|---------|----------------|
| 0x4A560 | 0x000005A0 | 1440 | Pixels per line at 1200 DPI |
| 0x4A564 | 0x00000D36 | 3382 | Scan area (pixels) |
| 0x4A568 | 0x0000042B | 1067 | Margin offset |
| 0x4A56C | 0x00000CB4 | 3252 | Active area end |
| 0x4A570 | 0x000011C6 | 4550 | Total CCD elements |
| 0x4A574 | 0x000011C6 | 4550 | Total CCD elements (duplicate) |

---

## 15. CCD Characterization Map (0x4A8BC-0x528BD)

**Size**: 32,770 bytes (~32KB)
**Purpose**: Factory-programmed per-CCD-element analog correction levels

### Structure

- **Section 1** (0x4A8BC-0x4E8BC, 16,385 bytes): length header 0x3FFF + 4095 groups x 4 bytes
- **Section 2** (0x4E8BD-0x528BD, 16,385 bytes): length header 0x3FFF + 4095 groups x 4 bytes
- **End marker**: 0xFF at 0x528BE

### Properties

- 11 distinct correction levels (0x00 through 0x0B)
- 100% 4-byte grouping (4 identical bytes per group = 4 CCD sub-elements)
- 4095 groups = 2^12 - 1 active CCD elements per section
- Monotonic edge-to-center decay: values 5-6 at edges, 0-1 at center
- Section 2 averages +1 correction level vs Section 1
- Localized hot pixel cluster at Section 2 groups 144-159 (values 10-11)
- Read-only: no runtime flash writes to this region

---

## 16. Scan Mode Dispatch Table (0x4A624)

**Size**: ~330 bytes of scan mode configuration entries
**Format**: 10-byte entries: `mode_id:16, channel_count:16, flags:16, handler_ptr:32`

Representative entries decoded from 0x4A624:

| Mode | Ch | Flags | Handler | Purpose |
|------|-----|-------|---------|---------|
| 0x0100 | 0x0600 | 0x0400 | 0x00037D18 | Mono scan, mode A |
| 0x0200 | 0x0600 | 0x0200 | 0x0004814A | Color scan, mode A |
| 0x0300 | 0x0600 | 0x0600 | 0x0004815C | IR scan, mode A |
| 0x0400 | 0x0600 | 0x0100 | 0x00048178 | Special mode |
| 0x0500 | 0x0600 | 0x0500 | 0x000483CC | Multi-pass mode |
| 0x0600 | 0x0600 | 0x0300 | 0x00048538 | Calibration scan |

---

## 17. RAM Test Region Table (0x207A8)

**Size**: 28 bytes (7 region pairs x 4 bytes each)
**Used by**: RAM test at `FW:0x203BA`

Each pair: `start_addr:16, end_addr:16` (addresses shifted left to form 24-bit values)

| Start | End | Size | Region |
|-------|-----|------|--------|
| 0x400000 | 0x420000 | 128KB | External RAM |
| 0x800000 | 0x820000 | 128KB | ASIC RAM (lower half) |
| 0x820000 | 0x830000 | 64KB | ASIC RAM (mid) |
| 0x830000 | 0x838000 | 32KB | ASIC RAM (upper) |
| 0x838000 | 0x840000 | 32KB | ASIC RAM (top, boundary marker only) |
| 0xC00000 | 0xC08000 | 32KB | Buffer RAM (bank A) |
| 0xC08000 | 0xC10000 | 32KB | Buffer RAM (bank B) |

---

## 18. ASIC RAM Validation Table (0x4A114)

**Size**: 32 bytes (4 range entries x 8 bytes each)
**Format**: `start_addr:32, end_addr:32`

| Start | End | Size | Region |
|-------|-----|------|--------|
| 0x400000 | 0x41FFFF | 128KB | External RAM |
| 0x800000 | 0x837FFF | 224KB | ASIC RAM (firmware-accessible) |
| 0xC00000 | 0xC07FFF | 32KB | Buffer RAM bank A |
| 0xC08000 | 0xC0FFFF | 32KB | Buffer RAM bank B |

---

## 19. Flash Log Record Format (0x60000/0x70000)

**Record size**: 32 bytes, type 0x01 (usage telemetry)
**Area 2** (0x70000): fills first, 2048 records
**Area 1** (0x60000): wraps from Area 2, 433 records

| Offset | Size | Field | Description |
|--------|------|-------|-------------|
| 0 | 1 | Header | 0xAA fixed marker |
| 1 | 1 | Type | 0x01 (usage telemetry, only type observed) |
| 2-3 | 2 | Sequence | Global event counter (big-endian) |
| 4-5 | 2 | Slow counter | Lamp degradation metric |
| 6-7 | 2 | Step counter | Motor position (increments by 256) |
| 8-9 | 2 | Usage counter | Cumulative scan time |
| 10-13 | 4 | Config | Hardware/firmware revision (always 7) |
| 14-17 | 4 | Lamp time | Upper byte = lamp hours, 0xD903 = build ID |
| 18-29 | 12 | Reserved | Usually zero |
| 30 | 1 | Padding | 0x00 |
| 31 | 1 | Footer | 0x55 fixed marker |

Total events on this unit: ~24,500 (sequence range 0x5801-0x61B1).

---

## Cross-References

- [Data Tables (KB)](../components/firmware/data-tables.md) -- Original table documentation
- [SCSI Handler](../components/firmware/scsi-handler.md) -- Handler dispatch analysis
- [Main Loop](../components/firmware/main-loop.md) -- Task dispatch mechanism
- [Motor Control](../components/firmware/motor-control.md) -- Speed ramp usage
- [Calibration](../components/firmware/calibration.md) -- CCD characterization data
- [ISP1581 USB](../components/firmware/isp1581-usb.md) -- USB descriptor details
- [Film Adapters](../components/firmware/film-adapters.md) -- Adapter type table
- [Memory Map](../reference/memory-map.md) -- Address space layout
