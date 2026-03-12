# Multi-Pass Scanning: Firmware Analysis Deep Dive

**Status**: Complete
**Last Updated**: 2026-03-12
**Phase**: 4 + 5 (Firmware + Protocol Spec)
**Confidence**: Verified (cross-validated host-side LS5000.md3 with firmware binary analysis)

## Executive Summary

**Can multi-pass scanning be enabled or modified through firmware changes?**

**Short answer**: The LS-50 firmware **already fully supports multi-pass scanning**. It has 45 scan task codes covering single-pass, multi-pass, and extended multi-sample modes across all adapter types. The multi-sample count (1x through 64x) is a parameter sent from the host via SET WINDOW byte 50, and the firmware has dedicated handlers for all values. There are **no firmware-side artificial limits** that need patching.

The actual limitation, if any, is in the **host software** (NikonScan4.ds / LS5000.md3), which decides what multi-sample options to present to the user based on the scanner's GET WINDOW response. Any custom driver (SANE, VueScan, or a new open-source driver) can send any supported multi-sample count directly.

**Key findings**:
1. The firmware has **12 scan groups** (0x0800-0x08B4), including 3 dedicated multi-pass groups (7/8) and 3 extended multi-sample groups (9/A/B)
2. Multi-pass uses a **3790-byte orchestrator** (F8 at `FW:0x42E2A`) that manages CCD re-exposure, USB interleaving, recalibration, and timing across passes
3. The multi-sample count is stored at RAM `0x400E81` directly from SET WINDOW descriptor byte 50
4. No flash checksum, signature, or integrity verification exists -- firmware patching is trivially possible (but unnecessary for this feature)
5. The LS-50 and LS-5000 share the **identical firmware**, with a model flag at `0x404E96` selecting between them

## How Multi-Sampling Works

### CCD Multi-Sample Architecture

"Multi-sampling" on the Coolscan is **not** multiple physical passes over the film. Instead, it is **multiple CCD integrations at the same physical position**, where:

1. The motor holds the film at a fixed position for one scan line
2. The CCD sensor captures the line N times (where N = multi-sample count)
3. The firmware or ASIC accumulates/averages the N captures
4. The averaged result is sent as a single scan line to the host

This reduces random CCD read noise by a factor of sqrt(N). With 16x multi-sampling, noise is reduced by 4x; with 64x, by 8x.

### Multi-Pass vs Multi-Sample Terminology

In this document, consistent with the firmware's internal naming:
- **Multi-sample** = Multiple CCD integrations per scan line (the CCD reads the same position multiple times)
- **Multi-pass** = The firmware task group designation for scan modes that use multi-sample (groups 7/8/9/A/B)
- **Fine scan** = Standard single-integration scan (groups 3/4/5/6)

The term "multi-pass" in Nikon's context does NOT mean "scan the entire strip multiple times". It means "take multiple samples per line". The motor advances one line at a time, and at each position, N CCD integrations are performed before moving on.

## SET WINDOW: Multi-Sample Count Configuration

### Host-Side: SET WINDOW Byte 50

The host software configures multi-sampling via SET WINDOW descriptor byte 50. The encoding is documented in [SET WINDOW Descriptor](../../scsi-commands/set-window-descriptor.md):

| Host Code (param_4) | SET WINDOW Byte 50 | Multi-Sample Count | Noise Reduction |
|----------------------|--------------------|--------------------|-----------------|
| 0x20 | 1 | 1x (no multi-sample) | 1.0x |
| 0x21 | 2 | 2x | 1.4x |
| 0x22 | 4 | 4x | 2.0x |
| 0x23 | 16 | 16x | 4.0x |
| 0x24 | 32 | 32x | 5.7x |
| 0x25 | 64 | 64x | 8.0x |
| 0x31 | 8 | 8x | 2.8x |

The gap from 4x to 16x (no 8x in the main sequence) and the out-of-sequence 0x31=8x suggest that 8x multi-sample was a late addition.

Source: `LS5000.md3:0x100B2B30` (SET WINDOW builder), offset `+0x44C` in the scan operation object stores the param_4 code.

### Firmware-Side: SET WINDOW Handler

The SET WINDOW handler at `FW:0x026E38` stores multi-sample count byte directly to RAM:

```
FW:0x270B8: mov.l  #0x0000002A, er0   ; Offset 0x2A = byte 42 from desc start
                                        ; (= descriptor byte 50 - 8 byte header)
FW:0x270C0: btst   #0, @er0           ; (test/alignment check)
FW:0x270C4: bne    skip               ; Branch if certain condition
FW:0x270C8: mov.b  r0l, r8l           ; Copy byte value
FW:0x270CA: mov.b  r8l, @0x400E81     ; STORE multi-sample count to RAM
```

**The firmware stores the multi-sample count as-is**. It does not validate, clamp, or reject any value. There is no maximum check on this byte. The firmware accepts whatever value the host sends in SET WINDOW byte 50.

RAM address `0x400E81` is the **sole storage location** for the multi-sample count. It has 5 references in the firmware:

| Address | Context | Operation |
|---------|---------|-----------|
| `0x10F9E` | System init | Write (clear to 0 during startup) |
| `0x22596` | SCAN handler | Read (first check: is multi-sample enabled?) |
| `0x225F2` | SCAN handler | Read (second check: set scan flags) |
| `0x22762` | SCAN handler | Read (third check: select task group) |
| `0x270CE` | SET WINDOW handler | Write (store from descriptor) |

## SCAN Handler: Operation Type and Task Group Selection

### Operation Type Assignment

The SCSI SCAN command (opcode 0x1B, handler at `FW:0x0220B8`) receives a data-out payload containing a scan descriptor. The first byte of this descriptor specifies the operation type:

| Code (er6[0]) | Operation | Description |
|----------------|-----------|-------------|
| 0 | Preview scan | Quick low-resolution preview |
| 1 | Fine scan (single pass) | Full-resolution, single CCD integration |
| **2** | **Fine scan (multi-pass)** | **Full-resolution, multiple CCD integrations** |
| 3 | Calibration scan | CCD/LED calibration |
| 4 | Move to position | Motor positioning only |
| 9 | Eject film | Film transport to eject position |

**The host software (LS5000.md3) decides whether to send operation 1 or 2.** When multi-sampling is enabled (MAID capability 0x8007 is set), the host sends operation type 2 in the SCAN CDB data-out payload.

### Three-Stage Multi-Sample Decision in SCAN Handler

The SCAN handler has three decision points where `0x400E81` (multi-sample count) is checked:

**Stage 1 (FW:0x22590)**:
```
FW:0x22590: mov.b  @0x400E81, r0l   ; Read multi-sample count
FW:0x22596: bne    +0x54            ; IF count != 0 -> multi-sample path
FW:0x22598: mov.b  @0x400D41, r0l   ; (else check another config byte)
```
This is the first gate: if multi-sample count is non-zero, take the multi-sample code path. If zero, take the standard single-pass path.

**Stage 2 (FW:0x225F0)**:
```
FW:0x225F0: mov.b  @0x400E81, r0l   ; Read multi-sample count again
FW:0x225F6: bne    +0x10            ; IF count != 0 -> set additional flags
FW:0x225F8: mov.b  #0x01, ...       ; (else: write flag for single-pass)
```
Sets scan behavior flags based on whether multi-sample is active.

**Stage 3 (FW:0x22760)**:
```
FW:0x22760: mov.b  @0x400E81, r0l   ; Read multi-sample count
FW:0x22766: bne    +0x7E            ; IF count != 0 -> skip to multi-sample finish
                                     ; (0x227E0: store to 0x400D42, end)
FW:0x22768: mov.b  @0x400773, r0l   ; (else: further single-pass logic)
```
Final routing: multi-sample scans skip the single-pass task code selection and go directly to the multi-pass completion path.

### Task Group Selection (Scan Configuration Functions)

After the SCAN handler sets up the scan descriptor, the scan configuration functions at `FW:0x38000-0x3C000` select the specific scan task code (0x08xx). The decision tree:

```
Is scan active? (0x400776 bit 7)
  Yes -> skip (don't start a new scan while one is running)
  No -> continue

Read feature flag 0x404E72:
  == 0 (basic feature set):
    -> Group 3 (0x0830): Fine scan, 8-bit, no ICE

  != 0 (extended features):
    Check ICE flag (0x404E72 bit test):
      ICE off + single-pass -> Group 3 (0x0830) or Group 5 (0x0850)
      ICE on  + single-pass -> Group 4 (0x0840) or Group 6 (0x0860)

    Check multi-sample (0x400E81 via operation type):
      Multi-sample + no ICE  -> Group 7 (0x0870)
      Multi-sample + ICE     -> Group 8 (0x0880)

    Check model flag (0x404E72 extended):
      Extended multi-sample A -> Group 9 (0x0890)
      Extended multi-sample B -> Group A (0x08A0)
      Extended multi-sample C -> Group B (0x08B0)
```

The actual task code includes an adapter variant (0-4) appended to the group base:
```asm
; At FW:0x389FE and similar:
MOV.B   @ER6, R0L          ; Read adapter variant byte (0-3)
EXTU.W  R0                  ; Zero-extend
INC.W   #1, R0              ; Add 1 (variant 0->1, etc.)
OR.W    #0x08G0, R0         ; Set group base code
MOV.W   R0, @0x400778       ; Store as current task code
```

## The 45 Scan Tasks

The complete scan task table (at `FW:0x49910`) has 45 entries for the 0x08xx scan group:

| Group | Code Range | Handler Range | Count | Mode |
|-------|-----------|---------------|-------|------|
| 0 | 0x0800 | 0x0022 | 1 | Preview (low res) |
| 1 | 0x0810 | 0x0022 | 1 | Preview (medium res) |
| 2 | 0x0820 | 0x0022 | 1 | Preview (full res) |
| 3 | 0x0830-0x0834 | 0x0015-0x0019 | 5 | Fine scan, 8-bit, no ICE |
| 4 | 0x0840-0x0844 | 0x0042-0x0046 | 5 | Fine scan, 8-bit, ICE |
| 5 | 0x0850-0x0854 | 0x0023-0x0027 | 5 | Fine scan, 14-bit, no ICE |
| 6 | 0x0860-0x0864 | 0x0033-0x0037 | 5 | Fine scan, 14-bit, ICE |
| **7** | **0x0870-0x0874** | **0x0038-0x003C** | **5** | **Multi-pass scan, no ICE** |
| **8** | **0x0880-0x0884** | **0x0047-0x004B** | **5** | **Multi-pass scan, ICE** |
| **9** | **0x0891-0x0894** | **0x0085-0x0088** | **4** | **Extended multi-sample A** |
| **A** | **0x08A1-0x08A4** | **0x0089-0x008C** | **4** | **Extended multi-sample B** |
| **B** | **0x08B1-0x08B4** | **0x008D-0x0090** | **4** | **Extended multi-sample C** |

### Handler Index Allocation Analysis

The handler indices reveal firmware development history:

| Block | Groups | Handler Range | Development Phase |
|-------|--------|--------------|-------------------|
| 1 | 3 | 0x0015-0x0019 | First implemented (8-bit fine scan) |
| 2 | 0/1/2 + 5 | 0x0022-0x0027 | Second (preview + 14-bit) |
| 3 | 6 + 7 | 0x0033-0x003C | Third (14-bit ICE + multi-pass core) |
| 4 | 4 + 8 | 0x0042-0x004B | Fourth (8-bit ICE + multi-pass ICE) |
| 5 | 9 + A + B | 0x0085-0x0090 | **Late addition** (gap from 0x004B, no base variant) |

Groups 9/A/B were added after initial firmware development. Their handler indices (0x0085-0x0090) have a large gap from block 4 (0x004B), and they lack a variant-0 base case (only variants 1-4), indicating they were added to support additional scan modes in a firmware update.

## Multi-Pass Orchestrator Function (F8)

### Location and Size

**Address**: `FW:0x42E2A` - `FW:0x43CF7`
**Size**: 3790 bytes (the largest function in the scan state machine)
**Entry**: `JSR @0x016458` (standard push_context)
**Exit**: `JSR @0x016436` (pop_context) + RTS

### Function Architecture

F8 is the dedicated multi-pass scan orchestrator. It manages the complex interleaving of:

1. **CCD line capture** (multiple integrations per line)
2. **USB data transfer** (sending averaged data to host between integrations)
3. **Re-calibration** (adjusting analog front-end between passes)
4. **Timing adjustment** (compensating for CCD thermal drift)
5. **Motor control** (holding position during multi-sample, advancing between lines)

### Key Subroutine Calls from F8

| Address | Count | Purpose |
|---------|-------|---------|
| `0x012360` | 2 | USB data transfer setup |
| `0x012398` | 2 | USB data transfer execute |
| `0x039C6C` | 2 | Primary calibration routine |
| `0x039E0C` | 1 | Secondary calibration routine |
| `0x03A00E` | 1 | Tertiary calibration routine |
| `0x03718A` | 1 | ASIC timing configuration |
| `0x016458` | 1 | Context save (entry) |
| `0x016436` | 1 | Context restore (exit) |
| `0x0163EA` | 3 | Microsecond timing (multiply) |
| `0x015CF2` | 2 | Division |
| `0x0109E2` | multiple | Yield to coroutine scheduler |

### Multi-Pass Execution Flow

```
F8 Entry (0x42E2A):
  1. Save context (push_context)
  2. Load scan config from 0x400F3A, 0x400F5B, 0x400F34
  3. Read scan operation state from 0x400E7A
     |
     v
  4. Setup ASIC timing via 0x3718A
  5. Configure DMA for multi-channel CCD readout
     |
     v
  6. OUTER LOOP (per scan line):
     a. Check abort flag (0x400D43)
     b. If abort -> exit
     c. Configure CCD integration parameters
     d. INNER LOOP (per sample):
        i.  Trigger CCD integration (ASIC DMA at 0x800000)
        ii. Wait for DMA complete (poll 0x200002)
        iii. Accumulate pixel data in ASIC RAM
        iv. Yield (JSR 0x109E2) between integrations
        v.  Check USB transfer status
     e. Average accumulated data
     f. Transfer averaged line to Buffer RAM (0xC00000)
     g. Trigger USB transfer (0x12360, 0x12398)
     h. Advance motor one step
     i. Re-calibrate if needed (0x39C6C, 0x39E0C)
     |
     v
  7. Scan complete -> cleanup, exit
```

### RAM Variables Used by F8

| Address | Size | Purpose in F8 |
|---------|------|---------------|
| `0x400E7A` | 1 | Scan operation state |
| `0x400D43` | 1 | Scan abort flag |
| `0x400F34` | 1 | Scan parameter flags |
| `0x400F3A` | 2 | Scan config base |
| `0x400F5B` | 1 | Scan config extended |
| `0x400F56` | 1 | Calibration config |
| `0x400F4A` | 2 | DMA config A |
| `0x400F4B` | 2 | DMA config B |
| `0x400F65` | 1 | Channel config (R/G/B/IR selector) |
| `0x400F84` | 2 | Scan area limit |
| `0x400F88` | 2 | Scan line counter |
| `0x400FAE` | 4 | Accumulator base pointer |
| `0x400FEE` | 4 | Secondary accumulator pointer |
| `0x4062F8` | 1 | Feature flags (ICE/extended) |
| `0x404E50` | 1 | Transfer validation flag |
| `0x406E76` | 2 | DMA transfer descriptor |
| `0x400F26` | 2 | Calibration cycle counter |
| `0x400F28` | 2 | Calibration step |
| `0x400F2A` | 2 | Calibration limit |
| `0x400F2C` | 2 | Calibration data A |
| `0x400F2E` | 2 | Calibration data B |
| `0x400F30` | 2 | Calibration data C |
| `0x400F32` | 2 | Position tracking |
| `0x400F33` | 1 | Pass counter |

### Calibration Between Passes

F8 calls three calibration routines during multi-pass scanning:

1. **Primary calibration** (`FW:0x039C6C`): Called at the start of each pass and periodically during the scan. Adjusts DAC mode register (`0x2000C2` = 0xA2 for cal mode) and reads CCD dark reference.

2. **Secondary calibration** (`FW:0x039E0C`): Fine-tuning of per-channel gain after initial calibration.

3. **Tertiary calibration** (`FW:0x03A00E`): Extended calibration for temperature compensation during long multi-sample scans.

The re-calibration addresses thermal drift: during a 64x multi-sample scan at 4000 DPI, the CCD sensor heats up significantly, shifting dark current and gain. Without periodic recalibration, later samples would have different characteristics than earlier ones, defeating the purpose of averaging.

## Motor Control During Multi-Pass

### Film Positioning Architecture

The scan motor is a stepper motor driven by ITU2 timer interrupts (Vec 32 at `FW:0x010B76`). During a multi-pass scan:

1. **Motor holds position** during all N integrations for a given line
2. Motor advances **one step** after the N-sample average is computed
3. The motor step size is determined by the resolution setting:
   - Formula: `motor_speed = (scan_resolution + 2) * 0x6C6` (computed at SET WINDOW time)
   - Stored at `0x400D8E`, `0x400D9A`, `0x400D9E`
4. The encoder ISR (IRQ3 at `FW:0x033444`) tracks actual position via pulse counting at `0x40530E`

### Can the Film Be Repositioned for a Second Pass?

Yes. The motor subsystem supports:
- **Absolute positioning** (task 0x0300): Move to any position
- **Relative positioning** (task 0x0310): Move by a delta
- **Return home** (task 0x0390): Return to reference position

A complete re-scan of the same area would require:
1. First scan completes normally
2. Motor returns to start position (task 0x0300 or 0x0390)
3. Second SCAN command issued with same SET WINDOW parameters
4. Host software averages the two complete scans

This is **host-driven multi-pass** and can be implemented entirely in software without any firmware changes. The firmware has no concept of "scan the same area twice" -- it just executes whatever scan commands the host sends.

## CCD Timing During Multi-Sample

### Integration Timing Registers

The ASIC CCD timing registers at `0x200408-0x200425` control the integration window:

| Register Group | Init Values | Function |
|----------------|-------------|----------|
| 0x408-0x40D | 01 41, 00 09, 00 19 | Transfer gate timing |
| 0x40E-0x413 | 01 2B, 00 0D, 00 15 | Integration window |
| 0x414-0x419 | 01 2B, 00 0D, 00 15 | Second integration |
| 0x41A-0x41F | 01 29, 00 02, 00 20 | Readout timing |
| 0x420-0x425 | 01 2F, 00 05, 00 1D | Reset/clamp timing |

During multi-sample, the integration window registers are programmed once and the ASIC repeats the integration cycle N times before readout. The firmware controls this by:

1. Setting integration timing once
2. Triggering ASIC DMA N times (write 0x80 to `0x2001C1`, poll `0x200002` bit 3)
3. The ASIC accumulates internally
4. One readout at the end

### Timing Computation

The scan handler computes per-pixel timing using:
- `FW:0x0163EA` with parameter `0x000F4240` (1,000,000 microseconds = 1 second)
- `FW:0x015CCC` with parameter `0x00000280` (640 pixels per timing unit)
- Result: pixel clock period in microseconds

For multi-sample, each integration adds approximately `integration_time * line_length` to the per-line time. At 4000 DPI with 64x multi-sampling, a single scan line takes 64x longer than normal.

## Feature Flag: 0x404E72

The RAM byte at `0x404E72` is a **scanner capability flag** that determines which extended scan modes are available. It has 18 references in the firmware and controls:

1. **Standard vs extended scan groups** (at `FW:0x389C8`, `FW:0x38BC0`, `FW:0x38C52`, `FW:0x38CCC`)
2. **ASIC motor DMA configuration** (at `FW:0x357AC`: bit 1 controls motor DMA register 0x200102)
3. **Extended multi-sample groups 9/A/B selection** (at `FW:0x38D38`)

### How 0x404E72 Is Set

The flag is set during scanner initialization from the GET WINDOW response data:

```
FW:0x2A766: mov.b r0l, @0x404E72   ; Write from parsed response data
FW:0x2A7D4: mov.b r4l, @0x404E72   ; Alternative write path
FW:0x2ABB2: mov.b r0l, @0x404E72   ; Write in init sequence
```

These are all in the initialization code region (`0x2A000-0x2B000`) which processes the scanner's self-description response. The LS-50 and LS-5000 share the same firmware but report different capabilities via their hardware-specific GET WINDOW responses, causing different values of `0x404E72`.

### Relationship to 0x404E96 (Model Flag)

A separate flag at `0x404E96` distinguishes LS-50 from LS-5000 at the analog front-end level:

| Parameter | LS-50 (0x404E96 = 0) | LS-5000 (0x404E96 != 0) |
|-----------|----------------------|--------------------------|
| Fine DAC (0x2000C7) | 0x08 | 0x00 |
| Coarse gain (0x200142) | 0x64 (100) | 0xB4 (180) |

The 0x404E72 flag is separate from the model flag and controls software feature enablement, while 0x404E96 controls hardware analog configuration.

## What the Host Software Exposes

### NikonScan4.ds Multi-Sample Control

From the scan workflow analysis ([Scan Workflows](../../components/nikonscan4-ds/scan-workflows.md)):

1. **MAID Capability 0x8007** = Multi-sample enable (boolean)
2. **MAID Capability 0x1016** = Multi-sample type (kNkMAIDCapType_MultiSample)
3. The scan orchestrator checks for capability 0x8007 before configuring multi-sample
4. If supported, it sets the multi-sample object which maps to SET WINDOW byte 50

The UI presents multi-sample as a quality option in the scan dialog. The available options (1x, 2x, 4x, 8x, 16x) depend on what the scanner's GET WINDOW response advertises.

### SANE Backend (coolscan3)

The open-source SANE coolscan3 backend also supports multi-sampling for the LS-50 and LS-5000. It sends the same SET WINDOW byte 50 values. SANE exposes all supported multi-sample counts without artificial UI limitations.

### Host-Side Limit: What NikonScan Offers vs What Hardware Supports

The NikonScan UI **may not expose all multi-sample counts** for all scanner models. The options shown depend on:

1. The scanner's GET WINDOW feature flags
2. The module's (LS5000.md3) interpretation of those flags
3. NikonScan4.ds's UI logic for the scan dialog

However, the firmware accepts **any value** in SET WINDOW byte 50. A custom driver can send any of the 7 defined multi-sample counts (1, 2, 4, 8, 16, 32, 64) regardless of what NikonScan's UI exposes.

## Extended Multi-Sample Groups (9/A/B)

### What Makes Them Different

Groups 9/A/B (handler indices 0x0085-0x0090) differ from groups 7/8 in several ways:

1. **Late addition**: Handler indices have a gap from 0x004B to 0x0085, indicating they were added in a firmware revision
2. **No base variant**: Only variants 1-4 (no variant 0), suggesting adapter-specific-only behavior
3. **Model-gated**: Selected only when `0x404E72` has specific bits set (at `FW:0x38D38`)
4. **Distinct calibration**: May use different calibration routines or timing parameters

The three extended groups likely correspond to:
- **Group 9 (0x0890)**: Extended multi-sample for one resolution/bit-depth combination
- **Group A (0x08A0)**: Extended multi-sample for another combination (used as alternative to 0x0840 when feature flag is set)
- **Group B (0x08B0)**: Extended multi-sample for a third combination

At `FW:0x38BC0`, the firmware explicitly chooses between group 4 (0x0840, standard ICE scan) and group A (0x08A0, extended multi-sample B) based on `0x404E72`. This means the extended groups are **model-specific optimized scan paths** that may use different CCD timing or averaging algorithms.

## Flash Patchability Assessment

### No Integrity Verification

The LS-50 firmware has **no checksum, CRC, signature, or integrity verification**:

- **Boot code** (0x100-0x18A): Reads bank select register at hardware address 0x4001, then jumps to 0x20334. No flash content verification.
- **Main firmware entry** (0x20334): Re-checks bank select register, then proceeds to I/O init table. No flash verification.
- **No CRC bytes**: Flash header is the vector table (0x00000100 = reset vector). No embedded checksum fields.
- **No signing**: Flash ends with erased bytes (0xFF). No digital signature.

### Flash Write Capability

The firmware includes a flash programming function at `FW:0x3A300` that supports the MBM29F400B chip:
- Active configuration: 0xFFF = 4KB sectors, unlock address 0x1FFF
- Used only for writing to log areas (0x60000, 0x70000)
- The WRITE BUFFER SCSI command (0x3B) at `FW:0x02837C` provides a host-accessible path to flash programming

### What Would Need to Change (If Anything)

**For multi-sample count expansion**: Nothing. The firmware already accepts any value in SET WINDOW byte 50 without validation.

**For true multi-pass HDR scanning** (scan same area at different exposures): This is already achievable entirely from the host side:

1. First pass: SET WINDOW with exposure A, SCAN, READ all data
2. Motor repositions to start (SEND DIAGNOSTIC motor command)
3. Second pass: SET WINDOW with exposure B, SCAN, READ all data
4. Host software combines the two exposures

**For modifying the scan task group selection** (firmware patch):

| Target | Address | Current Value | Change To | Effect |
|--------|---------|---------------|-----------|--------|
| Enable extended multi-sample | `0x404E72` (RAM) | Set by GET WINDOW response | Force non-zero via init code | Enable groups 9/A/B |
| Force multi-pass mode | `0x400E81` (RAM) | Set by SET WINDOW byte 50 | Set directly via vendor E0 command | Force multi-pass pipeline |

However, these RAM modifications don't require flash changes -- they can be achieved by sending appropriate SCSI commands.

### Flash Layout (Writeable Regions)

| Region | Address | Size | Content | Writeable? |
|--------|---------|------|---------|------------|
| Boot code | 0x0000-0x3FFF | 16KB | Vectors + boot | Dangerous (would brick) |
| Settings | 0x4000-0x5FFF | 8KB | Erased (0xFF) | Available but unused |
| Main firmware | 0x20000-0x52FFF | 204KB | Code + data | Patchable |
| Log area 1 | 0x60000-0x63FFF | 16KB | Usage logs | Already written to |
| Log area 2 | 0x70000-0x7FFFF | 64KB | Usage logs | Already written to |

## Practical Conclusions

### For Driver Developers

1. **Multi-sampling is fully supported** at all documented levels (1x-64x) by sending the appropriate value in SET WINDOW byte 50
2. **Operation type 2** in the SCAN data-out payload activates multi-pass firmware logic
3. The firmware selects between 45 different scan task codes based on: resolution, bit depth, ICE enable, multi-sample enable, adapter type, and model feature flags
4. **No firmware modification is needed** to use any supported multi-sample count

### For HDR/Multi-Exposure Scanning

True multi-exposure HDR scanning (different exposure levels for shadows vs highlights) can be implemented entirely from the host:

1. Configure exposure A via vendor E0 commands (registers 0x40-0x47)
2. Execute complete scan (SET WINDOW + SCAN + READ)
3. Reposition motor to start (SEND DIAGNOSTIC or vendor C1 subcommand 0x44)
4. Configure exposure B via vendor E0 commands
5. Execute second complete scan
6. Merge in software (tone mapping, HDR blending)

The firmware's motor control system fully supports repositioning to any absolute position, making this workflow feasible. The main challenge is scan-to-scan alignment (the encoder provides position feedback at `0x40530E`, but mechanical backlash in the stepper motor may introduce slight misalignment).

### For Maximum Quality Scanning

The optimal strategy for maximum quality:
1. **64x multi-sampling** (SET WINDOW byte 50 = 64): 8x noise reduction
2. **14-bit depth** (SET WINDOW byte 34 = 14): Maximum dynamic range
3. **4000 DPI** (SET WINDOW bytes 10-13): Maximum optical resolution
4. **ICE enabled** (SET WINDOW ICE/DRAG area): Dust/scratch removal
5. **Per-channel calibration** (WRITE DTC 0x88): Custom calibration before scan

This will use firmware task group 8 (0x0880-0x0884) for the scan operation, activating the full multi-pass orchestrator (F8 at `FW:0x42E2A`) with ICE data collection.

Estimated scan time for a full 35mm frame at these settings: approximately 30-45 minutes (64 CCD integrations per line * ~7000 lines * CCD integration time + recalibration pauses).

## Cross-References

- [SCAN Command](../../scsi-commands/scan.md) -- SCSI SCAN opcode 0x1B and operation types
- [SET WINDOW](../../scsi-commands/set-window.md) -- SCSI SET WINDOW opcode 0x24
- [SET WINDOW Descriptor](../../scsi-commands/set-window-descriptor.md) -- Byte 50 multi-sample encoding
- [Scan State Machine](../../components/firmware/scan-state-machine.md) -- 45 scan task codes
- [Scan Data Pipeline](../../components/firmware/scan-pipeline.md) -- CCD to USB data flow
- [Motor Control](../../components/firmware/motor-control.md) -- Stepper motor during scanning
- [Calibration](../../components/firmware/calibration.md) -- DAC modes and CCD calibration
- [ASIC Registers](../../components/firmware/asic-registers.md) -- CCD timing registers
- [Lamp Control](../../components/firmware/lamp-control.md) -- LED illumination during scanning
- [Scan Workflows](../../components/nikonscan4-ds/scan-workflows.md) -- Host-side scan orchestration
- [Model Comparison](../../scanners/model-comparison.md) -- LS-50 vs LS-5000 differences
