# Driver Implementation Q&A — Scan Data Transfer Protocol

**Status**: Complete
**Last Updated**: 2026-03-16
**Phase**: 5 (Protocol Spec) + all phases
**Confidence**: Verified (cross-validated firmware disassembly, host DLL decompilation, 5 parallel research agents)

## Overview

This document answers nine critical questions from the driver development team about the scan data transfer protocol. Each answer is traced through the full stack: NikonScan4.ds → LS5000.md3 → NKDUSCAN.dll → USB → firmware.

The central problem being solved: when the host stops reading image data mid-transfer, stale bytes remain in the host USB controller's buffer, corrupting all subsequent communication. NikonScan avoids this by reading exactly the right number of bytes. This document explains how.

---

## Q1: How Does NikonScan Calculate the Exact Image Byte Count?

**Answer: READ DTC 0x87 returns the firmware-computed total byte count at response bytes [2..5] (32-bit big-endian). NikonScan does NOT calculate it locally from SET WINDOW parameters.**

### Protocol Sequence

```
SET WINDOW → E0/C1/E1 cal → SET WINDOW → SCAN → READ DTC 0x87 → poll TUR → loop: READ DTC 0x00 → SEND DIAGNOSTIC
```

**Critical ordering**: READ DTC 0x87 must be issued IMMEDIATELY after SCAN returns Good, BEFORE TUR polling. See [Q7](#q7-the-dtc-0x87-timing-problem) for why.

After SCAN starts, the firmware computes the actual scan geometry (accounting for CCD alignment, resolution rounding, area clipping) and stores a 24-byte scan parameters block at RAM `0x400D45`. Five code paths write to this buffer (`FW:0x23376`, `0x23440`, `0x2351C`, `0x2359E`, `0x23660`).

### DTC 0x87 Response Layout (24 bytes)

| Offset | Size | Endian | Field |
|--------|------|--------|-------|
| 0-1 | 2 | BE | Status/flags |
| **2-5** | **4** | **BE** | **Total image byte count** |
| 6 | 1 | -- | Channel count/mode (1=mono, 2=dual, 6=RGB, 7=RGBI) |
| 7-18 | 12 | BE | Per-channel line geometry (bytes_per_line, line_count) |
| 19-23 | 5 | -- | Additional params |

### Host-Side Parsing

The Type B Phase B handler at `LS5000.md3:0x100B36E0` parses the response:

```c
// Extract total byte count from bytes [2..5]
total_bytes = (response[2] << 24) | (response[3] << 16) |
              (response[4] << 8)  |  response[5];
// Store at scan object +0x408 (offset 0x102 in DWORD terms)
```

Channel dispatcher `FUN_1009F2D0` (at `LS5000.md3:0x1009F2D0`) uses byte [6] to route to per-channel geometry parsers:

| Byte [6] Value | Channels | Parser Address |
|----------------|----------|----------------|
| 1 | Mono | `0x1009E300` |
| 2 | Dual | `0x1009E380` |
| 6 | RGB | `0x1009E400` |
| 7 | RGBI | `0x1009E4D0` |

Each parser extracts `bytes_per_line` and `total_lines` from bytes [7..18] into a 20-byte struct at `scanner+0x28C`.

### Chunked Read Loop

The scan read controller constructor at `LS5000.md3:0x10087030` initializes:
- `chunk_lines` (+0x24): normal lines per READ request
- `bytes_per_line` (+0x28): bytes per scan line
- `total_iterations` (+0x34): total number of line-reads
- `lines_done` (+0x38): accumulator, starts at 0

The per-chunk CDB builder at `LS5000.md3:0x100865C0` (the hot loop):

```c
lines_this_chunk = chunk_lines;
if (total_lines < lines_this_chunk + lines_done)
    lines_this_chunk = total_lines - lines_done;  // LAST CHUNK: smaller!
transfer_length = bytes_per_line * lines_this_chunk;
// Write to CDB bytes [6..8] as 24-bit big-endian
lines_done += lines_this_chunk;
```

This is why NikonScan's last READ DTC 0x00 has a smaller transfer length -- it's `(total_lines - lines_done) * bytes_per_line`.

### Firmware Side

The DTC 0x87 sub-handler at `FW:0x244D2` simply copies the 24-byte buffer from RAM `0x400D45` to the USB response. This is the only DTC whose handler is a direct RAM copy (all other DTCs compose their response dynamically).

The firmware populates `0x400D45` during SET WINDOW processing and scan initialization. The values reflect the **actual** scan parameters after any rounding or adjustment.

### Why This Design

The firmware is authoritative because it may adjust SET WINDOW parameters (rounding resolution to supported CCD pixel boundaries, clipping scan area to physical limits, adjusting for CCD tri-linear alignment). The host cannot reliably predict these adjustments. The firmware reports the exact resulting byte count, eliminating any calculation mismatch.

### Implementation

```
CDB: 28 00 87 00 00 00 00 00 18 80
     |     |              |     |
     |     DTC 0x87       |     Control (vendor bit)
     READ(10)         24 bytes

Response: 24 bytes
  [0..1]  = status flags
  [2..5]  = total_image_bytes (32-bit BE) ← USE THIS
  [6]     = channel_mode
  [7..18] = per-channel geometry
```

---

## Q2: What Does the Scanner Do After All Image Data Is Sent?

**Answer: The firmware returns a SCSI sense error. No STALL, no NAK, no zero-length packet. The D0 phase query protocol handles this gracefully.**

### Firmware State Transition on Scan Completion

When the line counter at `0x4064E6` reaches 0 (`firmware-scan-engine.c:644`):
- `scan_active` (`0x4052F1`) cleared to 0
- `scan_complete` (`0x405302`) set to 1
- Scanner state low byte at `0x40077C` cleared (`and.w #0xFF00` at `FW:0x29F86`)
- Recovery task `0x0F20` runs cleanup

### If Host Sends Another READ DTC 0x00

**Case A -- Scanner returned to idle (most common):**

The SCSI dispatch code at `FW:0x020C6A` rejects the command before the READ handler even runs. The READ handler has permission flags `0x0054` which require the scanner to be in active scan/read state. Once the scan completes and the state changes, the permission check fails.

Returns **sense 0x66**: SK=0B (ABORTED COMMAND), ASC=3E/00 "LU has not self-configured yet"

**Case B -- Scanner still partially active but data-ready bit cleared:**

The READ handler runs but the response builder at `FW:0x0250B4` checks `scanner_state & 0x0020` (bit 5 of low byte). During active data transfer, bit 5 is set (by `bset #5, r0l` at `FW:0x3D366`). After scan completion, the low byte is cleared. With bit 5 clear:

Returns **sense 0x56**: SK=5 (ILLEGAL REQUEST), ASC=2C/00 "Command Sequence Error"

### ISP1581 State After Last Image Byte

- DMA engine returns to idle (no active transfer)
- EP2 (bulk-in) is in normal ready state -- **not STALLed**
- EP1 (bulk-out) continues accepting CDBs normally
- No STALL register writes found in any transfer completion code path

### USB-Level Behavior

The D0 phase query protocol handles this cleanly:
1. Host sends CDB via bulk-out (EP1)
2. Host sends 0xD0 phase query via bulk-out
3. Scanner responds with phase byte **0x01** (no data) via bulk-in (EP2)
4. Host sends 0x06 sense request
5. Scanner returns sense data with the appropriate error

The host never gets stale image data -- it gets a sense error instead.

### Key Insight for Driver Writers

The corruption problem is NOT caused by the scanner sending extra data after scan completion. It's caused by the host **stopping mid-transfer** -- leaving partially-read image data in the host USB controller's receive buffer. Every subsequent USB read gets those leftover bytes instead of command responses.

---

## Q3: Is There a SCSI Command to Abort an In-Progress Scan?

**Answer: VENDOR C0 (0xC0) is the abort command. It uses a cooperative flag mechanism -- not an immediate kill.**

### Complete Abort Chain

```
User Cancel
  → NikonScan4.ds CStoppableCommandQueue::StopAll (0x10011790)
  → CFrescoMaidModule::CallMAID with opcode=14
  → MAIDEntryPoint case 14 at LS5000.md3:0x10027cf0 (609 bytes)
  → Capability lookup for ID 0x1009 (scan state object)
  → Sends VENDOR C0 [C0 00 00 00 00 00] via NkDriverEntry FC5
  → Firmware sets abort flag at 0x400776 bit 7
  → Scan engine detects flag, exits cleanly
  → Recovery task 0x0F10 runs
  → Host polls TUR until Good
```

### MAID Abort Handler (`LS5000.md3:0x10027cf0`)

1. Gets capability manager from context `[param_1 + 0x0C]`
2. If NULL: returns error `0xFFFFFF8B` (MAID not initialized)
3. Checks if an operation is actually in progress
4. If no operation active: returns `0xFFFFFF89` (nothing to abort)
5. Acquires abort-level lock via vtable
6. Looks up capability object `0x1009` via vtable -- this is the scan state/abort capability
7. Calls through the capability object's vtable → sends VENDOR C0

The constant `0x1009` is a MAID capability type ID used specifically by the abort handler. This is why C0's factory was "not found" in the normal scan vtable architecture -- it's invoked through a separate capability lookup path.

### Firmware C0 Handler (`FW:0x028AB4`, ~80 bytes)

```c
void handler_vendor_c0(void) {
    // Validate CDB bytes 1-5 are zero
    uint16_t flags = *(uint16_t *)0x400776;
    if (flags & 0x0040) {                         // bit 6 = operation active
        *(uint16_t *)0x400776 = flags | 0x0080;   // set bit 7 = abort requested
        *(uint16_t *)0x4007B2 = 0;                // clear transfer count
    }
    // No data phase -- status only
}
```

The flag word at `0x400776` encodes: high byte = flags (bit 6 = active, bit 7 = abort), low byte = operation subcode. Bit 6 is set by SCAN/DIAG/READ handlers when they start an asynchronous operation.

### Scan Engine Response

The inner scan loop checks bit 7 periodically:

```c
// At FW:0x40252 and other yield points:
if (*(volatile uint16_t *)0x400776 & 0x80) {  // abort requested
    goto scan_done;  // exit cleanly
}
```

After exit, recovery task `0x0F10` ("scan abort") cleans up motor position, DMA state, and CCD timing.

### Post-Abort Host Behavior

The host polls TEST UNIT READY until the scanner reports Good status:
- During cleanup: sense 0x0007 (SK=2, ASC=04/01 "Becoming ready")
- When ready: no sense (Good status)

### Implementation -- Abort + Buffer Recovery

```
1. Send VENDOR C0:  CDB [C0 00 00 00 00 00]
   → D0 phase query → phase 0x01 → read sense
2. Poll TUR (0x00) until Good status
   Expect sense 0x0007 (BECOMING READY) during cleanup
3. Clear host-side USB buffer:
   → usb_clear_halt() on EP2 IN
   → Or USB device reset (forces ISP1581 reset at FW:0x013A20)
4. After reset: re-initialize with TUR → INQUIRY → RESERVE
```

**Critical**: C0 only signals the scanner firmware. It does NOT clear stale data from the host-side USB controller buffer. You need `usb_clear_halt()` or a device reset for that.

---

## Q4: What Is the Firmware's Internal Scan Data Buffer Architecture?

**Answer: A 3-stage pipeline with per-line flow control. The motor physically pauses when the host stops reading. No data loss occurs. Overflow is architecturally impossible.**

### Pipeline Architecture

```
CCD Sensor (tri-linear R/G/B + IR)
    ↓  ASIC internal DMA (triggered per line: write 0x02 to 0x200001)
    ↓  Poll 0x200002 bit 3 for completion, yield() between polls
ASIC RAM (224KB @ 0x800000-0x837FFF)
    ↓  16 DMA banks: 4×32KB (0x800000, 0x808000, 0x810000, 0x818000)
    ↓                12×8KB  (0x820000 through 0x836000)
    ↓  CPU pixel extraction at FW:0x36C90 (yield between 4-16KB blocks)
Buffer RAM (64KB @ 0xC00000-0xC0FFFF)
    ↓  Ping-pong: Bank A (0xC00000, 32KB) + Bank B (0xC08000, 32KB)
    ↓  ITU4 system tick (FW:0x10A8C) polls buffer_status==3
ISP1581 USB Controller (0x600000)
    ↓  DMA direction 0x8000 = host-read, mode 5 = bulk
USB Bulk-In (EP2) → Host
```

Effective pipeline capacity: one ASIC RAM bank (8-32KB) + one Buffer RAM bank (32KB) = 40-64KB in-flight.

### Per-Line Flow Control

The pipeline is explicitly gated per scan line. Overflow is impossible:

1. CCD DMA is triggered per line by writing `0x02` to `@0x200001` (at `FW:0x400B0`)
2. Firmware polls `@0x200002` bit 3 for completion, calling `yield()` between polls
3. Next line's DMA is **not triggered** until the current line has been:
   - DMA'd from CCD to ASIC RAM (ITU3 burst countdown at `0x406374` reaches 0)
   - Pixel-processed and copied to Buffer RAM (CPU code at `FW:0x36C90`)
   - Buffer RAM drained via USB (`buffer_status` at `0x4052EE` cleared from 3 to 0)

### Buffer Status Variable (`0x4052EE`)

| Value | Meaning | Set By |
|-------|---------|--------|
| 0 | Empty/cleared | USB transfer completion |
| 1 | Initializing | Scan setup |
| 3 | **Buffer full, ready for USB** | Scan line callback (`FW:0x2CEB2`) |
| 6 | DMA active | DMA setup |
| 7 | Scan complete | Completion handler |

27 read sites and 16 write sites across the firmware confirm this is the central flow control variable.

### When the Host Stops Reading

1. ISP1581 endpoint fills up → `usb_busy` (`0x40049A`) stays 1
2. ITU4 system tick calls `push_to_usb` (`0x10B3E`) → finds busy → returns
3. `buffer_status` stays at 3 → no new CCD DMA triggered
4. Task code transitions to **`0x0330`** ("scan buffer stall")
5. Inner scan loop at `FW:0x40252` checks for 0x0330 → enters wait state

### Motor Behavior During Stall

The motor uses a **single-step cooperative model**:

1. Motor setup (`FW:0x2E158`) configures ITU2 compare register, starts ITU2
2. ITU2 fires → ISR at `FW:0x10B76` dispatches to mode handler
3. Mode handler immediately stops ITU2 (`BCLR #2, @TSTR`)
4. Step engine (`FW:0x2DEEE`) executes one step, sets `motor_enable_flag` (`0x4052EA`) = 3
5. **ITU2 stays stopped** -- no automatic restart
6. Scan state machine must explicitly call motor_setup for the next step

During a buffer stall, the scan state machine stops calling motor_setup. The motor stops naturally because no new ITU2 timer is started. **The scan head does not complete its travel independently.**

### When the Host Resumes Reading

1. USB data drains → `buffer_status` clears to 0
2. Scan state machine detects buffer available → resumes
3. Motor stepping resumes → scanning continues from the paused position
4. No data is lost

### TEST UNIT READY During Stall

Reports state `0x0330` via `@0x40077A`:
- Returns sense 0x0079: SK=2, ASC=04/01, FRU=03 "Motor busy (positioning)"
- Host should respond by issuing READ DTC 0x00 commands to drain the buffer

---

## Q5: What Determines the Actual Bytes Sent for a READ DTC 0x00?

**Answer: The firmware sends what's available. If the scan completes mid-transfer, it sends a short transfer with ILI sense and residual count in the sense Information field.**

### Normal Case (data available >= requested)

The data transfer function at `FW:0x020DD6` implements a producer-consumer loop:

1. **Budget** (`@0x400896`): initialized to CDB transfer length (bytes 6-8, 24-bit BE)
2. **Available** (`@0x40078C`): updated dynamically by scan engine producing CCD data
3. **Loop**: transfer `min(available, budget)` bytes via ISP1581 DMA (`FW:0x0140F2`), each burst up to 4,094 bytes (0x0FFE)
4. Between bursts: `yield()` (H8/300H SLEEP at `FW:0x0109E2`) -- CPU halts until interrupt
5. Transfer completes when budget reaches 0

The scanner sends **exactly** the requested bytes. The host's `ReadFile()` may return in chunks (NKDUSCAN handles this at `0x10002c46` with a retry loop).

### Edge Case (scan completes mid-transfer)

If 131,072 bytes requested but only 90,000 remain:

1. Firmware sends 90,000 bytes via USB
2. Scan engine signals completion, `available` stays at 0
3. Transfer loop exits with 41,072 bytes unsent
4. Post-loop residual check at `FW:0x020E96`:

```c
residual = requested - sent;  // = 41,072
*(uint32_t *)0x4007A0 = residual;  // sense Information field
*(uint16_t *)0x4007B0 = 0x006F;    // sense code
```

### Sense 0x6F Details

From translation table at `FW:0x17019` (entry 0x6F):

| Field | Value | Meaning |
|-------|-------|---------|
| Flags | 0x36 | INFO (bit 5) + ILI (bit 4) |
| SK | 0x0B | ABORTED COMMAND |
| ASC | 0x4B | Data Phase Error |
| ASCQ | 0x00 | -- |
| Response byte 2 | 0x2B | SK=0B with ILI bit set |
| Sense bytes 3-6 | residual | Number of bytes NOT transferred |

### What the Firmware Does NOT Do

- Does NOT block indefinitely waiting for more scan data
- Does NOT zero-pad to fill the requested transfer length
- Does NOT NAK USB IN tokens (the ISP1581 just stops sending)
- Does NOT STALL the endpoint

### Implementation Guidance

**Best practice**: Always calculate exact total from DTC 0x87, never request more than remaining:

```c
remaining = total_bytes - bytes_read;
chunk = min(preferred_chunk_size, remaining);
// CDB bytes 6-8 = chunk (24-bit BE)
```

**If you do over-request**: Parse the sense response. If SK=0B and ILI bit is set, bytes 3-6 contain the residual count. Actual bytes received = requested - residual.

---

## Q6: What Are the 4 Vendor Extension Bytes in SET WINDOW (Bytes 54-57)?

**Answer: A single 32-bit big-endian per-channel CCD integration time value, registered as MAID vendor extension parameter 0x102.**

### Firmware Verification

The SET WINDOW handler at `FW:0x026E38` validates a maximum transfer of **0x42 (66 bytes)** at `FW:0x026EB2`. With the 8-byte header and 54 bytes of standard+Nikon fields (bytes 8-53 of the descriptor), exactly 4 bytes remain at offsets 54-57 for the first vendor extension.

At `FW:0x027166-0x0271AE`, the firmware reads and stores these bytes:

```c
// Read 4 bytes from descriptor offset 0x2E (= byte 54) as 32-bit BE
uint32_t value = read_be32(window_store + 0x2E);  // FUN_12360

if (value == 0)
    goto skip;  // ZERO → keep previous value, do NOT overwrite!

// Store per-channel at RAM 0x400FAE + (channel_id * 4)
*(uint32_t *)(0x400FAE + (channel_id << 2)) = value;
```

### Per-Channel Storage (RAM `0x400FAE`)

| Window | Channel | RAM Address | Capture 001 | Capture 002 |
|--------|---------|-------------|-------------|-------------|
| win1 | Red | `0x400FAE` | `00 01 08 04` (67,588) | `00 01 11 E4` (70,116) |
| win2 | Green | `0x400FB2` | `00 00 D6 6A` (54,890) | `00 01 F7 9F` (128,927) |
| win3 | Blue | `0x400FB6` | `00 00 A6 2D` (42,541) | `00 01 FA A0` (129,696) |
| win9 | IR | special | `00 04 D2 6E` (316,014) | -- |

### Why These Values Are Exposure Time

- **R > G > B**: Color negative film base is orange, transmitting more blue; blue channel needs less integration time
- **IR >> visible**: Infrared source is weaker, requiring 5-6x longer integration
- **Preview > thumbnail**: Larger scan area or higher quality mode uses longer exposure
- Values are in hardware clock cycles (20 MHz CPU = 50 ns/cycle)
- The firmware reads these values ~20 times across scan and calibration routines at `FW:0x039542`, `FW:0x042xxx`

### Dynamic Registration Mechanism

These vendor extensions are NOT hardcoded. During initialization (`LS5000.md3:0x100A2980`):

1. Host sends GET WINDOW (0x25) to read scanner's current window descriptor
2. Parses feature flags in the response
3. For each supported feature, registers a vendor extension:
   ```c
   FUN_100a2820(scanner + 0x27C, param_id, data_size_from_scanner);
   ```
4. The data size (1, 2, or 4 bytes) comes from the scanner, not the host

Param 0x102 is registered first (if `flags_1 bit 2` is set) with size=4 bytes.

### What Happens with All Zeros

The firmware **silently skips the store** (branches on `beq` at `FW:0x027186`). RAM at `0x400FAE` retains the last-configured value from initialization or a previous SET WINDOW. This means:

- **Zeros don't crash** the scanner
- **Zeros don't produce a sense error**
- **Zeros produce unpredictable exposure** -- the scanner uses whatever was left in RAM
- On a fresh power-on, the default may be reasonable (from calibration init)
- After a previous scan with different parameters, the leftover values will be wrong

### How to Get Correct Values

Run the auto-exposure calibration sequence before scanning:

```
1. E0 sub=0x45 → write initial exposure parameters
2. C1           → trigger measurement
3. E1 sub=0xC0 → read exposure result
4. Repeat 1-3, adjusting until target brightness converged
5. READ DTC 0x8A → read final per-channel exposure/gain (14 bytes)
6. Use calibrated values in SET WINDOW bytes 54-57
```

Or capture per-channel values from a known-good NikonScan USB trace for your specific scan parameters.

---

## Q7: The DTC 0x87 Timing Problem — When Exactly Can It Be Read?

**Answer: DTC 0x87 must be read IMMEDIATELY after SCAN returns Good status, before TUR polling begins. The auto-exposure calibration loop (E0/C1/E1) before SCAN is required to guarantee a safe timing window.**

### The Root Problem

The firmware's `push_to_usb` function at `FW:0x10B3E` runs autonomously on the ITU4 system tick timer (`FW:0x10A8C`). Once the scan pipeline produces its first complete scan line into Buffer RAM and `buffer_status` (`0x4052EE`) becomes 3, the system tick pushes that data to EP2's FIFO — **without waiting for a READ DTC 0x00 CDB from the host**.

Once scan data is in EP2's FIFO, all subsequent bulk-in reads return that data instead of command responses (D0 phase bytes, sense data, or DTC 0x87 responses). This is why every approach the driver team tried either hits USB overflow or permission failures.

### Why Each Approach Fails

| Approach | Failure Mechanism |
|----------|-------------------|
| DTC 0x87 after SCAN succeeds (no cal) | Scan pipeline skips calibration → reaches SCAN EXEC (0x08xx) quickly → data in EP2 FIFO before host can complete READ DTC 0x87 exchange |
| DTC 0x87 after TUR OK | TUR OK means scanner exited active scan state → READ permission `0x0054` rejects → sense 0x66 (SK=0B, ASC=3E/00) |
| DTC 0x87 during SCAN "retries" | **Works!** Scanner is in active state (perm OK) AND pipeline is in calibration phase (no data on EP2) |
| GET WINDOW after TUR OK | Permission `0x0254` is state-dependent — passes for some scanner states but not others (see Q9) |
| Config estimate | Firmware rounds geometry for CCD alignment — host can't predict the rounding |
| Read until timeout | No end-of-data signal on USB; firmware just stops producing, last read hangs |

### The Scan Pipeline Timeline

After SCAN returns Good, the firmware's scan state machine progresses through:

```
SCAN Good → INIT (0x0110-0x0121) → MOTOR (0x0300) → FOCUS (0x0400)
         → CALIBRATION (0x0501) → EXPOSURE (0x0930-0x0940) → SCAN EXEC (0x08xx)
                                                                    ↓
                                                              First scan line → Buffer RAM
                                                                    ↓
                                                              push_to_usb → EP2 FIFO ← DEADLINE
```

**DTC 0x87 must complete before the DEADLINE.** The window size:

| Scenario | Window | Reliable? |
|----------|--------|-----------|
| With calibration (E0/C1/E1 ran) | 500ms — 5s | Yes |
| Motor needs repositioning only | 10 — 500ms | Usually |
| Everything cached (same params, repeat scan) | 1 — 20ms | **Dangerous** |

### The Solution: Force Calibration via E0/C1/E1

NikonScan runs the auto-exposure calibration loop before every SCAN:

```
 1. E0 sub=0x45 → write initial exposure parameters to scanner RAM
 2. C1           → trigger exposure measurement
 3. E1 sub=0xC0 → read measured exposure result
 4. Repeat 1-3 adjusting until target brightness converges (typically 2-4 iterations)
 5. Store final per-channel exposure values
```

This updates the per-channel exposure times at RAM `0x400FAE` (see Q6). When SCAN triggers the pipeline, the firmware sees that exposure parameters changed since the last calibration and **must recalibrate**. This creates a guaranteed window of 500ms+ where:

- Scanner is in active scan state (permission `0x0054` passes for READ DTC 0x87)
- Pipeline is in CALIBRATION phase (no scan data has reached EP2)
- DTC 0x87 buffer at `0x400D45` is already populated from SET WINDOW processing

**This is not a hack. It is the correct protocol.** The E0/C1/E1 loop also produces correct exposure values for SET WINDOW bytes 54-57. Omitting it produces incorrectly-exposed images regardless of the DTC 0x87 timing issue.

### Correct Sequence

```
 1. SET WINDOW (0x24)       — initial scan params (exposure bytes can be zero)
 2. E0/C1/E1 loop           — auto-exposure calibration
 3. SET WINDOW (0x24)       — re-send with calibrated exposure in bytes 54-57
 4. SCAN (0x1B)             — start scan pipeline (returns Good)
 5. READ DTC 0x87           — IMMEDIATELY! Parse bytes [2..5] = total_bytes
 6. Poll TUR (0x00)         — wait for data ready
 7. READ DTC 0x00 loop      — transfer exactly total_bytes
 8. SEND DIAGNOSTIC         — cleanup
```

Step 5 MUST come before step 6. The E0/C1/E1 loop in step 2 guarantees the pipeline will enter calibration, giving you hundreds of milliseconds to complete step 5 before any scan data reaches EP2.

---

## Q8: What Controls Whether SCAN Triggers Calibration (Creating the DTC 0x87 Window)?

**Answer: The firmware recalibrates when scan parameters differ from the last calibration state. The auto-exposure loop (E0/C1/E1) is the primary trigger because it always updates exposure RAM.**

### Calibration Trigger Conditions

| Condition | Triggers Recalibration? | Why |
|-----------|------------------------|-----|
| E0/C1/E1 exposure loop ran | **Always yes** | Updates `0x400FAE` (per-channel exposure), firmware detects parameter change |
| Resolution changed | Yes | Different CCD binning mode requires new calibration data |
| Bit depth changed (8→14 or vice versa) | Yes | Different analog gain/offset configuration |
| Scan area changed | Sometimes | Only if area crosses CCD readout boundary |
| Same params, repeat scan | **No** — calibration skipped | Firmware reuses cached calibration data |
| First scan of session | Yes | No cached calibration exists |

### Firmware Calibration Decision

The scan orchestrator F2 at `FW:0x40660` calls the calibration function `0x039C6C` in a loop until stable. The calibration function checks:

1. DAC mode register (`0x2000C2`): sets to `0xA2` (bit 7 = calibration enable) during calibration
2. CCD analog correction levels from table at `0x4A8BC` (values 0-11)
3. Per-channel exposure RAM at `0x400FAE` vs last-used values
4. All 4 calibration routines (`0x3D12D`, `0x3DE51`, `0x3EEF9`, `0x3F897`) use ping-pong buffering: ASIC RAM `0x800000` → Buffer RAM `0xC00000`

If the firmware determines calibration data is still valid (same parameters, recent calibration), it skips `0x039C6C` entirely and proceeds directly to exposure setup (0x0930) → scan execution (0x08xx). **This is why repeat scans with identical parameters sometimes produce no retry window.**

### TUR Sense During Calibration

While calibration runs, TEST UNIT READY returns:

| State | Sense Index | SK/ASC/ASCQ/FRU | Meaning |
|-------|-------------|------------------|---------|
| Motor positioning | 0x79 | 02/04/01/03 | Motor busy |
| Calibration active | 0x7A | 02/04/01/04 | Calibration in progress |
| General init | 0x07 | 02/04/01/00 | Becoming ready |

All of these indicate the scanner is still in active scan state — permission `0x0054` passes, DTC 0x87 is readable.

### What SET WINDOW Byte 48 (Multi-Sample) Does

Toggling SET WINDOW byte 48 changes the scan group in the task code (e.g., group 3 → group 7 for multi-pass), which selects a different scan task code at `0x08Gx`. Different task codes MAY require different calibration data. However, this is an **indirect** trigger — the firmware doesn't recalibrate because byte 48 changed, it recalibrates because the resulting scan mode requires different CCD timing. This is unreliable as a deliberate calibration trigger. **Use E0/C1/E1 instead.**

### Forcing Calibration Without Full E0/C1/E1

If you need a minimal approach (not recommended for production):

```
 1. E0 sub=0x45, data=[any non-zero exposure value different from last scan]
 2. C1           → trigger (firmware processes the new exposure)
 3. Skip E1 read (not strictly required for calibration trigger)
```

Writing any different exposure value to `0x400FAE` via E0 is sufficient to force recalibration. But skipping the full convergence loop means your exposure values will be wrong, producing a poorly-exposed image. Only useful for protocol testing.

---

## Q9: Can DTC 0x87 Be Read Before SCAN, or Via GET WINDOW?

**Answer: Neither works. READ DTC 0x87 before SCAN is blocked by permissions. GET WINDOW does not contain the total byte count field.**

### DTC 0x87 Before SCAN — Permission Block

READ(10) has permission flags `0x0054` in the SCSI dispatch table at `FW:0x49834`:

```
0x49834 + (READ entry): opcode=0x28, perm=0x0054, handler=0x023F10, exec=0x03
```

Permission `0x0054` = "only during active read operations." Before SCAN, the scanner is in initialized-idle state. The permission check at `FW:0x020CA0` rejects the command before the READ handler even runs.

**Result**: Sense 0x66 — SK=0B (ABORTED COMMAND), ASC=3E/00 "LU has not self-configured yet"

The DTC 0x87 buffer at RAM `0x400D45` IS partially populated by SET WINDOW processing — the five write paths (`FW:0x23376`, `0x23440`, `0x2351C`, `0x2359E`, `0x23660`) include SET WINDOW code paths. The geometry fields (bytes_per_line, line_count) are likely valid after SET WINDOW. But the permission check prevents reading them, and the total byte count at bytes [2..5] may not be finalized until scan initialization applies CCD alignment rounding.

No alternative command can access this buffer:
- READ BUFFER (0x3C): permission `0x0014`, but reads firmware/diagnostic data, not DTC buffers
- RECEIVE DIAGNOSTIC (0x1C): permission `0x0014`, different handler, different data
- MODE SENSE (0x1A): returns mode pages, not scan parameters

### GET WINDOW — Wrong Data, Unreliable Permissions

GET WINDOW (opcode 0x25) returns a mirror of the SET WINDOW descriptor. It contains resolution, scan area, bit depth, and channel configuration — but **NOT the computed total byte count**. The total byte count is only available from DTC 0x87's 24-byte block at RAM `0x400D45`.

Even if you tried to compute the byte count from GET WINDOW fields, you would need to replicate the firmware's CCD alignment rounding, which is implemented across multiple functions in the 20KB scan state machine region (`0x40000`-`0x45300`). The rounding depends on:

- CCD effective pixel count (5782 for LS-50 at 4000 DPI)
- Binning mode (1:1, 2:1, 4:1 based on resolution)
- Tri-linear R/G/B sensor alignment offsets
- Adapter-specific scan area limits
- Motor step resolution at the given speed

### Why GET WINDOW Fails at 4000 DPI

GET WINDOW has permission flags `0x0254`:

```
0x0254 = 0000 0010 0101 0100 (binary)
0x0054 = 0000 0000 0101 0100 (READ for comparison)
```

Permission `0x0254` has bit 9 set (`0x0200`) that `0x0054` doesn't, making it allowed in some additional states. But it's still state-dependent — the dispatch code at `FW:0x020CA0` checks the scanner's internal state machine against these bits.

At 300 DPI, the scanner's post-scan state happens to match the `0x0254` permission bits. At 4000 DPI with ICE/multi-sample, the scanner enters a different internal state after scan completion that **doesn't match** `0x0254`. The ASC=0x24 ("Invalid field in CDB") error is generated by the permission check failing, not by the GET WINDOW handler itself.

This makes GET WINDOW unreliable as a byte count source even if you could extract the count from it.

### Bottom Line

There is no alternative to reading DTC 0x87 during the active scan window. The solution is to guarantee that window exists by running the E0/C1/E1 exposure calibration loop before SCAN (see Q7).

---

## Complete Recommended Scan Sequence

```
=== INITIALIZATION (once per session) ===

 1. Open USB device (VID 0x04B0, PID 0x4001)
 2. Poll TUR until Good (up to 30s, expect sense 04/01 during startup)
 3. INQUIRY → verify "Nikon" vendor, get product string
 4. RESERVE → claim exclusive access
 5. GET WINDOW → discover vendor extension params (sizes, feature flags)
 6. MODE SELECT → page 0x03, set resolution limits
 7. SEND DIAGNOSTIC → self-test/calibration trigger
 8. READ DTC 0x88 → calibration boundary data


=== PRE-SCAN CALIBRATION (per scan) ===

 9. SET WINDOW → initial scan params (exposure bytes can be zero first time)
10. Auto-exposure: E0/C1/E1 loop → per-channel exposure calibration
    This ALSO forces firmware recalibration during SCAN (see Q7/Q8)
11. WRITE DTC 0x03 → gamma LUT (if custom gamma needed)


=== SCAN EXECUTION ===

12. SET WINDOW → re-send with calibrated exposure in bytes 54-57!
13. SCAN (0x1B) → start physical scanning
14. READ DTC 0x87 → IMMEDIATELY after SCAN! Parse bytes [2..5] = total_bytes
    CDB: 28 00 87 00 00 00 00 00 18 80
    *** MUST come BEFORE TUR polling — see Q7 for why ***
15. Poll TUR → wait for scan data to be ready
    Expect sense 04/01 FRU=04 (calibrating) or 04/01 FRU=03 (motor busy)
16. Loop: READ DTC 0x00
    transfer_length = min(chunk_size, total_bytes - bytes_read)
    Stop when bytes_read == total_bytes
17. SEND DIAGNOSTIC → post-scan cleanup


=== ABORT (if needed) ===

18. VENDOR C0 [C0 00 00 00 00 00] → signal abort to firmware
19. Poll TUR until Good (firmware cleanup in progress)
20. usb_clear_halt(EP2_IN) → clear host-side stale data
21. If USB is corrupted: USB device reset → re-do steps 2-8
```

### The Fix for Your Buffer Corruption Problem

The corruption occurs because your driver stops reading mid-transfer, leaving image bytes in the host USB controller's receive buffer. Every subsequent `ReadFile()` gets those leftover bytes instead of command responses.

**Two fixes are required together:**

1. **Step 10 (E0/C1/E1)**: The auto-exposure loop forces the firmware to recalibrate during SCAN, creating a safe window where DTC 0x87 can be read without scan data colliding on EP2.

2. **Step 14 (READ DTC 0x87 immediately after SCAN)**: Issue READ DTC 0x87 as the very first command after SCAN returns Good — before any TUR polling. Parse the total byte count from response bytes [2..5], and ensure your read loop transfers exactly that many bytes. The last READ should request exactly `total_bytes - bytes_already_read`.

If you need to abort mid-scan, use the abort sequence (steps 18-21). The `usb_clear_halt()` call is essential to flush the host-side buffer.

---

## Source References

| Topic | Primary Source | Address |
|-------|---------------|---------|
| DTC 0x87 response layout | Firmware RAM buffer | `0x400D45` (24 bytes) |
| DTC 0x87 handler | Firmware | `FW:0x244D2` |
| Scan params parsing | LS5000.md3 | `0x100B36E0` (Phase B handler) |
| Channel dispatcher | LS5000.md3 | `0x1009F2D0` |
| Chunked read constructor | LS5000.md3 | `0x10087030` |
| Per-chunk CDB builder | LS5000.md3 | `0x100865C0` |
| READ handler + permissions | Firmware | `FW:0x023F10` (perm 0x0054) |
| Permission dispatch | Firmware | `FW:0x020C6A` |
| Data transfer loop | Firmware | `FW:0x020DD6` |
| Residual check | Firmware | `FW:0x020E96` |
| MAID abort handler | LS5000.md3 | `0x10027cf0` (case 14, 609 bytes) |
| C0 firmware handler | Firmware | `FW:0x028AB4` (~80 bytes) |
| Abort flag | Firmware RAM | `0x400776` (bit 6=active, bit 7=abort) |
| Buffer status | Firmware RAM | `0x4052EE` (0=empty, 3=full, 7=done) |
| Motor enable flag | Firmware RAM | `0x4052EA` |
| Scan stall task code | Firmware | `0x0330` in task table at `0x49910` |
| SET WINDOW max transfer | Firmware | `FW:0x026EB2` (max 0x42 = 66 bytes) |
| Vendor ext read+store | Firmware | `FW:0x027166-0x0271AE` |
| Per-channel exposure RAM | Firmware RAM | `0x400FAE` + channel*4 |
| Sense translation table | Firmware | `FW:0x16DEE` (148 entries x 5 bytes) |
| Sense 0x6F (ILI) | Firmware | `FW:0x17019` |
| ISP1581 USB reset | Firmware | `FW:0x013A20` |
| push_to_usb (auto EP2 push) | Firmware | `FW:0x10B3E` (called from ITU4 tick `0x10A8C`) |
| Scan orchestrator (cal decision) | Firmware | `FW:0x40660` (F2, calls `0x039C6C` for cal) |
| Calibration routines (4) | Firmware | `FW:0x3D12D`, `0x3DE51`, `0x3EEF9`, `0x3F897` |
| DAC calibration mode | Firmware register | `0x2000C2` (set `0xA2` = cal enable) |
| CCD correction levels | Firmware table | `0x4A8BC` (analog levels 0-11) |
| GET WINDOW permission | Firmware dispatch | `FW:0x0272F6` (perm `0x0254`) |
| SCAN pipeline stages | Firmware | Task codes: `0x0110`→`0x0300`→`0x0400`→`0x0501`→`0x0930`→`0x08xx` |
| Scan state machine | Firmware flash | `0x40000-0x45300` (20KB, 12 giant functions) |

## Cross-References

- [READ Command](../scsi-commands/read.md) -- DTC dispatch and CDB layout
- [SCAN Command](../scsi-commands/scan.md) -- Scan initiation
- [SET WINDOW Descriptor](../scsi-commands/set-window-descriptor.md) -- Byte-level descriptor mapping
- [GET WINDOW](../scsi-commands/get-window.md) -- Vendor extension discovery
- [VENDOR C0](../scsi-commands/vendor-c0.md) -- Abort primitive
- [Sense Code Catalog](../scsi-commands/sense-codes.md) -- All sense codes referenced
- [USB Protocol](../architecture/usb-protocol.md) -- D0 phase query, chunked transfers
- [Scan Pipeline](../components/firmware/scan-pipeline.md) -- CCD → ASIC → Buffer → USB
- [Scan State Machine](../components/firmware/scan-state-machine.md) -- Task codes and state transitions
- [ISP1581 USB](../components/firmware/isp1581-usb.md) -- USB controller interface
- [Scan Workflows](../components/nikonscan4-ds/scan-workflows.md) -- NikonScan orchestration
- [SCSI Command Sequences](../deep-dive/scsi-command-sequences.md) -- Full protocol walkthrough
- [Firmware Scan Engine](../deep-dive/firmware-scan-engine.c) -- Pseudocode for scan pipeline
- [Firmware SCSI Handlers](../deep-dive/firmware-scsi-handlers.c) -- Handler pseudocode
- [Memory Map](../reference/memory-map.md) -- RAM variable addresses
- [Calibration](../components/firmware/calibration.md) -- Calibration routines and DAC modes
- [SCSI Handler Dispatch](../components/firmware/scsi-handler.md) -- Permission flags and dispatch table
