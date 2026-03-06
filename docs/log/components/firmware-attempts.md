# Firmware Analysis Log
<!-- STATUS HEADER - editable -->
**Binary**: binaries/firmware/Nikon LS-50 MBM29F400B TSOP48.bin | **Functions identified**: ~16 ISR handlers
---
<!-- ENTRIES BELOW - APPEND ONLY -->

## Attempt 1 — 2026-02-27 — Vector table and startup decode
**Tool**: Ghidra headless + dump_firmware_startup.java
**Target**: 0x000-0x190 (vector table + startup), flash layout scan
**What I tried**: Parsed all 64 vector entries, decoded startup code at 0x100-0x18A
**What I found**:
- 15 active vectors (confirmed from Session 0), all but NMI point to on-chip RAM trampolines
- Dual-bank boot: address 0x4001 selects main firmware (0x20334) vs backup (0x10334)
- Normal boot path SKIPS trampoline copy loops (branches over them)
- Trampoline source data in flash (0x6B4) is ALL ERASED (0xFF) — copy loops do nothing
- NMI and default handlers are infinite loops
**Confidence**: High

## Attempt 2 — 2026-02-27 — Main firmware entry and I/O init table
**Tool**: Ghidra headless + dump_firmware_startup.java
**Target**: 0x20334-0x20500 (main firmware entry)
**What I tried**: Decoded main firmware initialization sequence
**What I found**:
- Watchdog reset: writes 0x5A00 to 0xFFFFA8
- I/O init table at 0x2001C-0x20334: 132 entries, each 6 bytes (addr:32 + value:16)
- Configures: BSC (ABWCR=0x0B, WCR=0xBA, CSCR=0x30), port DDRs, timer channels
- Custom ASIC at 0x200000 with ~70 register writes (CCD config, timing, motor)
- RAM test with 0x55AA/0xAA55 patterns (0x203BA-0x20460)
- SP relocated from 0xFFFF00 (on-chip) to 0x40F800 (external RAM)
**Confidence**: High

## Attempt 3 — 2026-02-27 — Trampoline installation decode
**Tool**: Ghidra headless + dump_firmware_startup.java
**Target**: 0x204C4-0x205E2 (trampoline installation code)
**What I tried**: Decoded all trampoline write operations
**What I found**:
- Trampolines installed by main firmware (NOT boot code!) using eepmov.b
- 11 trampolines installed with inline JMP instruction data
- Complete mapping: Vec 8→0x10876, Vec 15→0x33444, Vec 16/17→0x14D4A, Vec 32→0x10B76,
  Vec 36→0x2D536, Vec 40→0x10A16, Vec 45→0x2CEF2, Vec 47→0x2E10A, Vec 49→0x2E9F8,
  Vec 60→0x2EDDE, Vec 19→0x2B544
- Vec 13 (IRQ5, likely ISP1581) trampoline NOT found in this sequence — installed elsewhere
**Confidence**: High

## Attempt 4 — 2026-02-27 — Flash layout and string search
**Tool**: Ghidra headless + dump_firmware_startup.java
**Target**: Full 512KB flash
**What I tried**: 4KB block scan for erased/code regions, string search
**What I found**:
- Flash layout: 0x0-0xFFF boot, 0x4000 data, 0x6000 log1, 0x10000-0x17FFF shared handlers,
  0x20000-0x52FFF main firmware, 0x60000-0x63FFF log2, 0x70000-0x7FFFF additional code
- 0x4D000 block is ZEROED (not erased) — possibly calibration data area
- INQUIRY strings: "Nikon   LS-5000" at 0x16674, "Nikon   LS-50 ED        1.02" at 0x170D6 and 0x49E31
- Firmware version "1.02", build ID "DF17811" at 0x20010
- 16 RTE instructions found (interrupt handler boundaries)
**Confidence**: High

## Attempt 5 — 2026-02-27 — ISP1581 register access search
**Tool**: Ghidra headless + dump_firmware_handlers.java
**Target**: 0x10000-0x53000 code regions
**What I tried**: Searched for MOV.L #0x6000xx patterns (ISP1581 register accesses)
**What I found**:
- ISP1581 code concentrated at 0x12200-0x15200
- Key register accesses: Mode(0x0C), Interrupt(0x08), DMA(0x18), Endpoint data(0x20,0x1C), DMA count(0x84)
- 15 ISP1581 register references found
**Confidence**: High

## Attempt 6 — 2026-02-27 — Internal command dispatch analysis
**Tool**: Ghidra headless + dump_scsi_dispatch.java
**Target**: 0x20C00-0x20E00 (command dispatch code)
**What I tried**: Decoded the command dispatch switch/case and command table at 0x49910
**What I found**:
- Dispatch at 0x20CA0 uses INTERNAL command codes (not raw SCSI opcodes)
- Command codes include: 0x10-0x15, 0x20-0x21, 0x40-0x45, 0x81, 0xA0, 0xB0-0xB3,
  0xC0-0xC1, 0xD0-0xD2, 0xF3-0xF4
- Some match SCSI opcodes (0x12=INQUIRY, 0x15=MODE SELECT, 0xC0/C1/D0=vendor)
- Command table at 0x49910: ~93 entries of (cmd_id:16, handler_idx:16)
- Handler dispatch via function pointer: jsr @er6 at 0x20DB2 (loads from [er6+4])
- Permission checking via bit tests on r5h/r5l before dispatch
**Confidence**: Medium (internal command IDs partially overlap with SCSI opcodes)

## Attempt 7 — 2026-02-27 — Adapter string table decode
**Tool**: Ghidra headless + dump_scsi_dispatch.java
**Target**: 0x49E00-0x49F80 (string/data tables)
**What I tried**: Decoded adapter type strings and pointer table
**What I found**:
- INQUIRY response at 0x49E31: "Nikon   LS-50 ED        1.02" (standard SCSI format)
- Adapter type strings: Mount, Strip, 240, Feeder, 6Strip, 36Strip, Test, FH-3, FH-G1, FH-A1
- Debug labels: "SCAN Motor", "AF Motor", "SA_OBJECT", "240_OBJECT", "240_HEAD", "FD_OBJECT"
- Calibration labels: "DA_COARSE", "DA_FINE", "EXP_TIME", "GAIN"
- String pointer table at 0x49EFC (13 pointers to adapter name strings)
**Confidence**: High

## Attempt 8 — 2026-02-28 — SCSI command handler table decode
**Tool**: Ghidra headless + dump_isp1581_usb.java + manual binary analysis
**Target**: 0x49834 (SCSI handler table), 0x49910 (internal task table)
**What I tried**: Decoded the command descriptor table structure and all entries
**What I found**:
- SCSI handler table at 0x49834: 20 entries x 10 bytes = primary SCSI dispatch
- Entry format: opcode:8, pad:8, flags:16, handler_ptr:32, exec_mode:8, pad:8
- 20 SCSI opcodes: 00,03,12,15,16,17,1A,1B,1C,1D,24,25,28,2A,3B,3C,C0,C1,D0,E0,E1
- Cross-validation: All 17 Phase 2 (LS5000.md3) opcodes present + 2 extra (0x3B WRITE BUFFER, 0x3C READ BUFFER)
- D0 Phase Query handler at 0x013748 is in shared module (only handler NOT in main firmware)
- Internal task code table at 0x49910: 93 entries of (cmd:16, handler_idx:16), organized by subsystem
- Task codes: 01xx=config, 03xx=control, 04xx=motor, 05xx=calibration, 06xx=sensor, 08xx=scan, 09xx=status
**Confidence**: High (cross-validated with Phase 2)

## Attempt 9 — 2026-02-28 — ISP1581 USB controller interface analysis
**Tool**: Ghidra headless + dump_isp1581_usb.java
**Target**: 0x12200-0x15200 (ISP1581 interface code)
**What I tried**: Decoded USB endpoint read/write functions, init code, DMA setup, state machine
**What I found**:
- Three endpoint I/O functions: read(0x12258), write(0x122C4), write_alt(0x12304)
- ISP1581 registers: Mode(0x60000C), Interrupt(0x600008), DMA(0x600018), Data(0x600020), Endpoint(0x60001C)
- Soft-connect via Mode register bit 4 (SOFTCT)
- RAM-resident USB code: 414 bytes copied from flash 0x124BA to RAM 0x4010A0
- USB state variables at 0x407Dxx (large block: ~30 state bytes)
- CDB reception path: ISP1581 interrupt → read from 0x600020 → buffer at 0x4007DE → opcode to 0x4007B6
- Response manager at 0x1374A: manages USB DMA for sending responses
- 0x40077C referenced from ~57 locations (internal state tracking)
- USB bus reset handler at 0x13A20: resets ASIC (0x200001), reinitializes endpoints
**Confidence**: High

## Attempt 10 — 2026-02-28 — Dispatch flow trace
**Tool**: Ghidra exports analysis
**Target**: SCSI CDB processing chain (0x20B00-0x20DC0)
**What I tried**: Traced full dispatch flow from CDB reception to handler invocation
**What I found**:
- SCSI dispatch entry at 0x20B48: scans handler table at 0x49834 matching CDB opcode
- Opcode at 0x4007B6 compared with table entries (10-byte stride)
- Permission flags loaded from entry offset +2, checked against scanner state
- Internal command state machine at 0x20CA0: categorizes commands, verifies permissions
- Final handler call at 0x20DB2: `jsr @er6` where er6 loaded from entry offset +4
- Exec mode byte at offset +8: 0x00=direct, 0x01=USB setup, 0x02=data-out, 0x03=data-in
- Post-handler cleanup at 0x16436 (restore interrupts)
**Confidence**: High

## Attempt 11 — 2026-02-27 — Force disassembly and individual handler analysis
**Tool**: Ghidra headless (force_disassemble_handlers.java) + Python H8/300H decoder
**Target**: All 21 SCSI handler entry points + 5 interrupt handlers
**What I tried**: Force-disassembled all handlers, decoded raw bytes with custom Python H8 decoder
**What I found**:
- All 21 SCSI handlers + 5 interrupt handlers successfully disassembled (3985 lines Ghidra output)
- Common handler pattern: jsr @0x016458 (push_context), stack frame alloc, handler body, jsr @0x016436 (pop_context), rts
- All handlers validate CDB reserved bits with `and.b #0x1F, r0l; bne error`
- Error signaled by writing sense code to @0x4007B0
- Identified 11 distinct sense codes used across handlers
- TEST UNIT READY is largest handler (~700 bytes), checks extensive state machine with 7+ sub-states
- INQUIRY supports VPD pages via two-level dispatch: standard table (0x49C20, 8 pages) + adapter-specific (0x49C74, per-adapter pages)
- MODE SENSE supports page 0x03 (device-specific) and 0x3F (all), three page control modes (current, changeable, default)
- SCAN handler ~1800 bytes, supports 6 operation types (0-4, 9)
- VENDOR C0 is simplest (~80 bytes, status-only)
- VENDOR C1 dispatches on 23 different subcommand codes via @0x400D63
**Confidence**: High

## Attempt 12 — 2026-02-27 — Vendor register table and data table decode
**Tool**: Python binary analysis
**Target**: Firmware data tables (0x49C20, 0x49C74, 0x4A134, 0x168AF)
**What I tried**: Decoded all data-driven tables referenced by SCSI handlers
**What I found**:
- INQUIRY VPD dispatch table (0x49C20): 8 standard pages (0x00, 0x01, 0x10, 0x40-0x41, 0x50-0x52)
- INQUIRY adapter VPD table (0x49C74): 7 adapters with adapter-specific VPD pages
  - Adapter 0 (none): custom pages 0xF8, 0xFA, 0xFB, 0xFC with unique handlers
  - Adapter 1 (Mount): page 0x46
  - Adapter 2 (Strip): pages 0x43, 0x44, 0xE2
  - Adapter 3 (240): pages 0x45, 0xF1
  - Adapter 4-5 (Feeder/6Strip): pages 0x46/0x47, 0xE2
  - Adapter 6 (36Strip): page 0x10
- Vendor E0/E1 register table (0x4A134): 23 entries mapping reg_id to max_data_len
  - Register IDs (0x40-0xD6) match C1 subcommands and Phase 2 operation codes exactly
  - Max lengths: 0 (trigger-only), 5, 9, 11, or 13 bytes
- MODE SENSE default data (flash 0x168AF): page 0x03, base resolution 1200 DPI, max 4000 units X/Y
- Cross-validation: E0→C1→E1 vendor command flow fully confirmed from firmware side
**Confidence**: Verified (cross-validated with Phase 2)

## Attempt 13 — 2026-02-28 — Motor control subsystem deep analysis
**Tool**: Ghidra exports + Python binary analysis + hex dump
**Target**: Timer ISRs (0x010B76, 0x033444, 0x02B544), GPIO ports, motor data tables
**What I tried**: Traced full motor control architecture from timer interrupts through stepper drive
**What I found**:
- Two motors confirmed: "SCAN Motor" (carriage) and "AF Motor" (autofocus) — debug strings at 0x49E89/0x49E94
- Timer architecture: ITU4 (0x010B76) is master dispatcher polling motor_mode (0x400774), ITU2 is step timer (start/stop per move)
- ITU4 started ONCE at init (0x010A10, BSET #4 TSTR) and never stopped — continuously dispatches
- Four motor modes: 2=scan, 3=AF, 4=encoder, 6=alt scan
- Motor setup function at 0x02E158: configures ramp, direction, starts ITU2
- Main step engine at 0x02DEEE: updates position, applies ramp, reloads timer
- Stepper drive: unipolar 4-phase wave drive (01,02,04,08 at FW:0x16E92, reverse 08,04,02,01 at 0x4A8A8)
- Port A DR (0xFFFFA3) is primary motor output — 9 write sites all from motor code
- Linear speed ramp at 0x16C38: 33 entries, 56-312 step 8 (timer compare values)
- Multiple variant ramp tables at 0x0459D2+ for different resolutions/adapters
- Encoder ISR (0x033444): counts pulses at 0x40530E, measures speed delta at 0x405314
- ASIC motor registers at 0x200102, 0x200182-0x20019B for motor DMA and drive channels
- 20+ motor RAM state variables mapped (0x400774, 0x4052E2-0x4052EE, 0x405300-0x40531A)
- Task table motor entries: 0x0440=relative move, 0x0450=absolute move, 0x0430=home, 0x0400=stop
**Confidence**: High

## Attempt 14 — 2026-02-28 — Cross-validation: SCSI command KB docs updated
**Tool**: Manual cross-referencing Phase 2 ↔ Phase 4 findings
**Target**: All 17 SCSI command KB docs in docs/kb/scsi-commands/
**What I tried**: Updated all SCSI command KB docs with firmware handler addresses, CDB validation logic, and firmware-specific behavior
**What I found**:
- All 17 host-side opcodes have confirmed firmware handlers with matching exec modes and data directions
- TUR handler reveals complete scanner state machine (7+ states with distinct sense codes)
- INQUIRY VPD page system matches two-level dispatch (standard + adapter-specific)
- MODE SENSE: only page 0x03 (device-specific) supported; saved pages (PC=3) not supported
- SCAN: 6 operation types decoded (preview, fine, multi-pass, calibration, move, eject)
- Vendor E0/C1/E1: all 23 register IDs match between firmware table (0x4A134) and host-side operations
- C0 confirmed as no-data-phase abort/status check (resolves host-side "factory not found" mystery)
- All 17 KB docs updated to Confidence: Verified, Phase: 2+4
**Confidence**: Verified

## Attempt 15 — 2026-02-28 — ASIC register map (172 registers, 8 blocks)
**Tool**: Ghidra headless scripts + Python binary analysis + hex dump
**Target**: All ASIC register accesses (0x200000-0x200FFF), I/O init table at 0x2001C
**What I tried**: Dumped all MOV instructions referencing 0x200xxx addresses, parsed I/O init table, mapped register blocks
**What I found**:
- 172 unique ASIC register addresses across 8 blocks (0x00, 0x01, 0x02, 0x04, 0x09, 0x0A, 0x0C, 0x0F)
- I/O init table (0x2001C, 132 entries × 6 bytes): 30 CPU registers + 48 ASIC core + 54 CCD/channel
- Block 0x00 (26 regs): System control, status, DAC/ADC config (0x2000C0-C7)
- Block 0x01 (65 regs): DMA channels (7 pairs), motor drive (2 groups × 4 coils), CCD line timing (12 regs)
- Block 0x02 (15 regs): CCD data channels with stride-8 pattern (4 channels: R/G/B/IR)
- Block 0x04 (56 regs): CCD timing (5 integration timing groups), analog gain (0x200457-458, default 99), per-channel config (4 × stride-8)
- DMA Ch0 ISR at 0x2D536: reads state from 0x406374, dispatches ASIC DMA
- DMA Ch1 ISR at 0x010A16: timestamp-based, multiple transfer modes
- ASIC RAM (224KB @ 0x800000): 85 reference groups for CCD line buffer
- Buffer RAM (64KB @ 0xC00000): 23 reference groups for USB transfer staging
- Scan data pipeline: CCD → ASIC AFE (gain/timing) → ASIC RAM (line buffer) → Buffer RAM → ISP1581 USB DMA
- KB doc created: docs/kb/components/firmware/asic-registers.md
**Confidence**: High (register addresses confirmed from init table; functional assignments inferred from context)

## Attempt 16 — 2026-02-28 — Flash layout and log record decode
**Tool**: Python binary analysis + hex dump
**Target**: Full 512KB flash layout, log record format
**What I tried**: Scanned all 128 × 4KB blocks, decoded log record structure
**What I found**:
- Complete flash layout mapped:
  - 0x0000-0x3FFF: Vector table + boot code (code)
  - 0x4000-0x5FFF: Settings/data (mostly erased 0xFF)
  - 0x6000-0xBFFF: Log area 1 + more data/code
  - 0x10000-0x17FFF: Shared handler module (code)
  - 0x18000-0x1FFFF: Erased (0xFF)
  - 0x20000-0x52FFF: Main firmware (code + data tables)
  - 0x53000-0x5FFFF: Erased (0xFF)
  - 0x60000-0x63FFF: Log area 1 (433 records)
  - 0x64000-0x6FFFF: Erased (0xFF)
  - 0x70000-0x7FFFF: Log area 2 (512+ records)
- Flash log record format: 32 bytes each
  - Byte 0: 0xAA (header marker)
  - Byte 1: Record type
  - Bytes 2-3: Counter/sequence number
  - Bytes 4-29: Type-specific data
  - Byte 30-31: 0x55 (footer marker)
- Calibration data at 0x4C000-0x4EFFF: per-pixel offset correction, 16-bit values
- 0x4D000 block is ZEROED (not erased) — intentional calibration area
**Confidence**: High

## Attempt 17 — 2026-02-28 — Calibration subsystem deep analysis
**Tool**: Ghidra headless (dump_calibration.java) + hex analysis
**Target**: Task codes 05xx, DAC registers, flash write routines, calibration data
**What I tried**: Extracted all calibration task codes, traced DAC register accesses, analyzed flash programming, decoded calibration data structure
**What I found**:
- 3 calibration task codes: 0x0500 (handler 0x31), 0x0501 (0x32), 0x0502 (0x30 shared with FEED/POSITION)
- DAC mode register 0x2000C2 is the calibration gate: 0x20=init, 0x22=scan, 0xA2=calibration (bit 7 enables cal mode)
- Four calibration routines (0x3D12D, 0x3DE51, 0x3EEF9, 0x3F897) ALL set 0xA2 before CCD reads
- LS-50 vs LS-5000 analog config: model flag at 0x404E96 selects fine DAC (0x08 vs 0x00) and coarse gain (100 vs 180)
- Flash 0x4C000-0x4EFFF: per-pixel binary map (0x00/0x01 only), ~5152 pixels, factory-programmed
- ZERO code references to 0x4C000/4D000/4E000 — calibration data NEVER modified at runtime
- Flash programming at 0x3A300 supports 4 flash types; active chip uses 0x1FFF unlock (4KB sector mode)
- Gain registers 0x200457/458 are init-only — dynamic gain uses 0x200142/152 path
- Calibration scan uses ping-pong buffering: 0xC00000 (bank A) and 0xC08000 (bank B)
- KB doc created: docs/kb/components/firmware/calibration.md
**Confidence**: High

## Attempt 18 — 2026-02-28 — Lamp/LED control and CCD signal chain
**Tool**: Hex dump analysis + Ghidra
**Target**: Lamp GPIO, C1 subcommand dispatch, CCD readout, exposure control
**What I tried**: Decoded lamp control subroutine at 0x28BC4, mapped all GPIO port writes for lamp, traced CCD readout path
**What I found**:
- Lamp GPIO: Port 8 bit 2 (P8DR at 0xFF85) — 6 BSET write sites all in motor/scan code (0x2C66A-0x2D670)
- Consistent lamp-on pattern: read P8DR → save shadow to 0x400791 → BSET #2 → clear 0xFF86
- Lamp state machine at 0x13C6E: sets 0x400082=1 (active), configures timer control
- C1 subcommand 0x80 handler at 0x28BC4: calls 0x13C6E → sets 0x400E5F=1 → extracts per-channel exposure params from CDB
- Per-channel exposure: CDB offsets 0x02-0x05 (R), 0x06-0x09 (G), 0x0A-0x0B (channel ID) → written to 0x40077E/0x400782
- DIVXU.B at 0x28BE7 for exposure gain calculation
- C1 dispatch is linear CMP/BEQ chain (NOT indirect table): 24 subcommands with target addresses decoded
- Two-level dispatch: 0x28B08 (CDB extraction) → 0x4A134 secondary table (hardware operations)
- No BCLR for Port 8 found — lamp-off likely uses byte write (0x00 to P8DR)
- CCD readout in SCAN handler: pixel clock timing computed as 1,000,000 / 640 μs/pixel
- KB doc created: docs/kb/components/firmware/lamp-control.md
**Confidence**: High

## Attempt 19 — 2026-02-28 — Scan data pipeline complete trace
**Tool**: Hex dump analysis + Ghidra
**Target**: DMA Ch0/Ch1 ISRs, response manager, ASIC DMA config, pixel processing, SCAN handler
**What I tried**: Traced complete scan data pipeline from CCD capture to USB transfer
**What I found**:
- DMA Ch0 ISR (0x2D536): two-level dispatch — burst counter at 0x406374 counts down, then mode at 0x4052D6 selects handler
- Mode 1 → scan line callback (0x2CEB2): reads scan descriptor from 0x406370, re-triggers ASIC DMA
- DMA Ch1 ISR (0x10A16): periodic timer interrupt, polls for data readiness (pull model)
- Checks 0x400773==4 (scan data) and 0x4052EE==3 (buffer full) before initiating USB transfer
- Transfer mode dispatch at 0x10B3E: mode 2=block, 3=stream, 4=scan line, 6=calibration
- Response manager (0x1374A): checks USB busy (0x40049A), sets up ISP1581 DMA (0x13C70), starts transfer (0x13F3A)
- ISP1581 DMA: write 0x8000 to 0x600018 (host-read direction), mode 5 bulk at 0x60002C, enable at 0x60001C
- ASIC DMA registers: trigger=0x80→0x2001C1, poll=0x200002 bit 3, ack=0xC0→0x200001
- Pixel processing (0x36C90): minimal — shlr.w for bit extraction, NO LUT/gamma/dark subtraction
- All image processing done host-side by NikonScan (DRAG/ICE DLLs)
- Dual ASIC RAM banks: 0x800000 (primary) and 0x418000 (secondary)
- Channel descriptors at 0x405342-40535A: 757/665 pixel values per channel
- 12 pipeline state variables mapped (0x406374, 0x4052D6, 0x4052EE, 0x4052F1, 0x405302, etc.)
- KB doc created: docs/kb/components/firmware/scan-pipeline.md
**Confidence**: High

## Attempt 20 — 2026-02-28 — Vec 13 trampoline resolution
**Tool**: Hex dump + binary analysis
**Target**: Vec 13 (IRQ5/ISP1581) trampoline installation
**What I tried**: Searched for Vec 13 trampoline installation outside the known 0x204C4-0x205E2 range
**What I found**:
- RESOLVED: Vec 13 IS in the main sequence — it's the 12th and FINAL entry at 0x205E2-0x205F7
- The original range "0x204C4-0x205E2" excluded the last entry (0x205E2 was the start, not the end)
- Trampoline: RAM 0xFFFD3C ← flash 0x205F8 = JMP @0x014E00
- ISP1581 interrupt handler at 0x014E00: reads ISP1581 interrupt register at 0x60000C, RTE at 0x014EA4
- All 12 trampolines use identical pattern: MOV.L dest, MOV.L src, MOV.B #4, EEPMOV.W, BVS (safety), JMP (skip)
- Complete vector table: all 15 active vectors now have confirmed handler targets
- Updated vector-table.md with Vec 13 handler and corrected installation range
**Confidence**: Verified

## Attempt 21 — 2026-02-28 — Complete firmware gap analysis
**Tool**: Hex dump + strings + binary analysis
**Target**: All unanalyzed code regions in 0x10000-0x52FFF
**What I tried**: Classified all code gaps by content type, decoded remaining data tables, extracted full task table
**What I found**:
- 11 unanalyzed code regions totaling ~110KB identified and classified:
  - 0x40000-0x45000 (20KB): Main scan state machine (16 giant functions)
  - 0x45000-0x49834 (18KB): MAID parameter/config handling (76 functions)
  - 0x2F400-0x33000 (15KB): Scan acquisition/image data path (29 functions)
  - 0x29600-0x2C400 (12KB): ASIC/CCD init + focus control (40 functions)
  - 0x37B00-0x3A300 (10KB): CCD pixel readout with unrolled loops (18 functions)
  - 0x33500-0x35600 (8.4KB): Stepper motor between-line logic (54 functions)
  - 0x3A400-0x3C200 (7.7KB): CCD timing/exposure management (23 functions)
  - Plus 4 smaller regions (2-6KB each)
- Task table has 94 entries (not 93): 17 task code prefixes including dust detection (0x11xx), self-test (0x30xx), park/sleep (0x70xx)
- ASIC RAM bank descriptor table at 0x49A94: 17 × 8KB banks = 136KB mapped for DMA
- Data tables region 0x4A200-0x528BE contains:
  - Sine/cosine table, BCD encoding, logarithmic bitmask lookup
  - IEEE 754 double-precision calibration coefficients (100.0, 250.0, etc.)
  - CCD channel remap table: {04,01,02,03,05,00} × 8 = 48 entries
  - 32KB CCD defect map (16384 × 16-bit entries, pixel quality classification)
- KB doc created: docs/kb/components/firmware/data-tables.md
**Confidence**: High

## Attempt 22 — 2026-02-28 — Serial ports, flash log records, focus tasks
**Tool**: Hex dump + binary analysis + Python scripts
**Target**: SCI0/SCI1 handlers, flash log records, focus task codes
**What I tried**: Dumped SCI0 RX handler (0x2CEF2), SCI0 TX handler (0x2E10A), SCI1 RX handler (0x2E9F8). Analyzed flash log records from Area 1 (0x60000) and Area 2 (0x70000). Extracted focus/lens task codes from task table.
**What I found**:
- Serial ports (SCI0/SCI1) are for film adapter communication (SA-21, MA-21, etc.), not debugging
- SCI handlers manipulate scan state variables (0x4052D6, 0x4064E8, 0x406338, 0x4052E4-EB, 0x400778, 0x4052FE, 0x405298) rather than directly accessing SCI data registers
- SCI register accesses (SMR, BRR, SSR, RDR, TDR) are sparse (2-3 sites each), via 8-bit addressing
- No baud rate (BRR) config in I/O init table — serial ports configured dynamically at runtime when adapter detected
- Flash log records: ALL type 0x01 (usage telemetry), 32 bytes each, 2481 records total
- Area 2 (0x70000) fills first (2048 records), then wraps to Area 1 (0x60000, 433 records)
- Record format decoded: header 0xAA, sequence counter, lamp degradation, motor position, cumulative scan time, hardware revision (always 7), lamp hours, footer 0x55
- Sequence counter range 0x5801-0x61B1 = ~24,500 total events since manufacture
- Focus/lens task codes: 0x0400, 0x0430, 0x0440, 0x0450 (4 entries in task table)
- CCD readout task codes: 0x0600-0x0609 (10 entries, 5 basic + 5 extended)
- Updated data-tables.md with detailed log record format, vector-table.md with serial port purpose
**Confidence**: High

## Attempt 23 — 2026-02-28 — Main loop and cooperative coroutine system
**Tool**: Raw hex dump + manual H8/300H disassembly
**Target**: Main loop at 0x207F2, context system at 0x107EC, task dispatcher at 0x20DBA
**What I tried**: Traced firmware from end of initialization (0x205FC) through context system init (0x107EC) into main loop (0x207F2). Decoded task dispatcher and execution functions.
**What I found**:
- MAJOR FINDING: Firmware uses a **two-context cooperative coroutine system**, NOT a simple polling loop
- Context A: main firmware loop at 0x207F2 (stack @ 0x410000) — SCSI dispatch, motor, scan control
- Context B: USB data transfer handler at 0x29B16 (stack @ 0x40D000) — large USB data transfers
- Context switch via TRAPA #0 (stub at 0x109E2 → vector 8 → trampoline 0xFFFD10 → handler 0x10876)
- Handler saves all ER0-ER6, resets watchdog, swaps SP from save area @0x400766, restores other context, RTE
- Descriptor tables in flash: Table A (cold boot) at 0x107CC, Table B (warm restart) at 0x107DC
- Main loop is 8-step polling: USB check → scan state → USB reset → state machine → USB reinit → SCSI check → dispatch → reset check
- Single yield point at step 6 (no SCSI command) — only place Context A gives up CPU
- Task dispatcher at 0x20DBA: linear search through 97-entry table at 0x49910, returns handler index
- Task execution at 0x20DD6: budget-based system prevents task starvation of SCSI processing
- Complete USB→SCSI→task chain traced: IRQ5 sets flag → main loop polls → dispatch → handler → task code in RAM → subsequent iterations process
- Utility stubs at 0x109E0-0x109FA: yield, enable/disable interrupts, read/write CCR, clear state
- KB doc created: docs/kb/components/firmware/main-loop.md
**Confidence**: High

## Attempt 24 — 2026-02-28 — Scan state machine (0x40000-0x45000)
**Tool**: Raw hex dump + manual H8/300H disassembly
**Target**: 20KB scan state machine region, 45 scan task codes
**What I tried**: Mapped all function boundaries using push_context/pop_context patterns. Decoded scan entry points and task code construction. Analyzed inner scan loop and state transitions.
**What I found**:
- 12 giant functions (F1-F12) identified with clear boundaries
- Pre-function inner loop (0x40000-0x40317, 792 bytes): processes each CCD line, triggers ASIC DMA, yields between lines
- F2 (0x40660): scan orchestrator — central coordinator calling F3-F6 in sequence
- F8 (0x42E2A): multi-pass scan orchestrator — largest function (3790 bytes)
- F10 (0x43DE2): full scan pipeline — "direct mode" bypassing orchestrator for simple scans
- 4 adapter entry points at 0x40630-0x4065C: each calls F12 (common init) → adapter config → F2 (orchestrator)
- Adapter dispatch at 0x3C400 reads @0x400F22 bitmask byte (0x04=mount, 0x08=strip, 0x20=240, 0x40=feeder)
- Task code format: 0x08GV where G=scan group (0-B), V=variant (0-4)
- Task codes computed at runtime: task_code = 0x08G0 | (adapter_variant_byte + 1)
- Group pairs from handler index adjacency: (3+5), (6+7), (4+8)
- Groups 9/A/B (handlers 0x85-0x90) added in later firmware revision
- State transition pipeline: INIT→MOTOR→FOCUS→CALIB→EXPOSURE→SCAN→RECOVERY
- Key discovery: handler_index does NOT map to function pointer table — stored in @0x4007B0, adapter dispatch selects entry point directly
- KB doc created: docs/kb/components/firmware/scan-state-machine.md
**Confidence**: High (function boundaries, state transitions, task encoding verified; some group semantics Medium)

## Attempt 25 — 2026-02-28 — Context B, focus motor, parameter region survey
**Tool**: Raw hex dump + Python analysis
**Target**: Context B (0x29B16), AF motor handler (0x2EDC0), parameter handling region (0x45000-0x49834)
**What I tried**: Traced Context B entry point structure. Counted yield points and function boundaries. Analyzed AF motor handler and compared with scan motor handler. Surveyed parameter handling region.
**What I found**:
- Context B (0x29B16) is a background processing loop with 21 yield points and 16 functions across 12KB
- Context B monitors task codes (0x0010, 0x0110-0x0121, 0x2000, 0x3000) and manages DMA/motor state
- Context B is the DATA PLANE (DMA management, motor coordination, scan progress) vs Context A CONTROL PLANE (SCSI dispatch, command handling)
- Both contexts share RAM state vars (0x400778, 0x40077A, 0x400776) and cooperate via TRAPA #0
- AF motor handler at 0x2EDC0: same architecture as scan motor — stops ITU2 (BCLR #2, @TSTR), has own stepping logic
- Motor mode 3 is set at 0x2ED90 (MOV.B #3 → @0x400774) for AF motor operations
- AF motor uses same ITU4 dispatcher and stepper infrastructure as scan motor (mode 3 vs mode 2)
- Focus task codes (0x0400/0x0430/0x0440/0x0450) are simple position commands — no autonomous autofocus
- Autofocus algorithm runs HOST-SIDE in NikonScan (firmware just executes individual motor moves)
- Parameter handling region (0x45000-0x49834): 17 functions, 76 RTS, includes adapter config functions
  - 0x4536E/0x45390/0x453CA/0x453D6: adapter mode config functions (strip/mount/240/feeder)
  - 0x4609C: focus motor handler function
  - Remaining functions handle vendor register parameter parsing
- Updated main-loop.md with Context B details
- Updated motor-control.md with host-driven autofocus note
- Updated ARCHITECTURE.md with coroutine system diagram and 12 KB doc links
**Confidence**: High

## Attempt 26 — 2026-02-28 — Sense code catalog + cross-validation + cleanup
**Tool**: Python hex analysis scripts, manual KB review
**Target**: Sense translation table at 0x16DEE, cross-validation of vendor commands
**What I tried**:
- Extracted full sense translation table from firmware flash at 0x16DEE (148 entries × 5 bytes)
- Decoded all 64 actively-used sense codes grouped by Sense Key (SK 0-B)
- Traced sense response builder subroutine at 0x0111F4
- Cross-validated vendor commands C0, C1, E0, E1 between host-side (LS5000.md3) and firmware
**What I found**:
- Two-level sense system: internal index (word at 0x4007B0) → 5-byte table entry [Flags, SK, ASC, ASCQ, FRU]
- 148 total entries, 64 actively used. Largest group: 30 lamp failure entries with FRU encoding channel+subtype
- REQUEST SENSE handler at 0x021866 calls 0x0111F4 to build 18-byte fixed-format response
- FRU byte encodes CCD channel (high nibble: 0=R, 1=G, 2=B, 3=IR, 9=multi) and failure type (low nibble)
- Vendor command cross-validation: ALL 4 vendor commands (C0, C1, E0, E1) are CONSISTENT between host and firmware
- Stale vendor-specific/nikon-*.md docs had WRONG E0/E1 direction speculation — superseded by verified root docs
- Fixed opcode count error in scsi-handler.md (listed 19, labeled 17 — clarified transport-layer vs application-layer)
**Created**: docs/kb/scsi-commands/sense-codes.md (complete, 64 entries with meaning and context)
**Fixed**: 4 stale vendor-specific/nikon-*.md → redirect stubs
**Fixed**: scsi-handler.md opcode count + REQUEST SENSE handler address
**Fixed**: usb-protocol.md status → Complete
**Confidence**: Verified (firmware table decoded + cross-validated with host error handling)

## Attempt 27 — 2026-02-28 — READ/WRITE Data Type Code dispatch tables
**Tool**: Hex dump + Ghidra exports + r2 disassembly + SANE coolscan3 cross-reference
**Target**: READ handler DTC dispatch at 0x0240E2, WRITE handler DTC dispatch at 0x025622, firmware tables at 0x49AD8 (READ) and 0x49B98 (WRITE)
**What I tried**: Extracted all Data Type Code values from both READ and WRITE firmware handlers. Decoded the firmware dispatch tables (12-byte entries for READ, 10-byte entries for WRITE, both 0xFF-terminated). Traced DTC qualifier validation logic at 0x024024-0x0240AC. Cross-validated with LS5000.md3 host-side factory callsites and SANE coolscan3 open-source backend.
**What I found**:
- READ dispatch table at flash 0x49AD8: **15 DTC entries** × 12 bytes each
  - DTC values: 0x00, 0x03, 0x81, 0x84, 0x87, 0x88, 0x8A, 0x8C, 0x8D, 0x8E, 0x8F, 0x90, 0x92, 0x93, 0xE0
  - Each entry: DTC byte, category byte, max_size (16-bit), RAM ptr (32-bit), extra bytes
  - Category byte controls qualifier validation: 0x00=none, 0x01=single, 0x03=channel(0-3), 0x10=two-mode(0/1), 0x30=three-mode(0/1/3)
- WRITE dispatch table at flash 0x49B98: **7 DTC entries** × 10 bytes each
  - DTC values: 0x03, 0x84, 0x85, 0x88, 0x8F, 0x92, 0xE0
  - DTC 0x85 is WRITE-only (no READ counterpart) — Extended Calibration
- Dispatch chain at 0x0240E2-0x024136 uses linear cmp.b/beq sequence (15 comparisons + default jmp)
- WRITE dispatch at 0x025622-0x02564C: 7 comparisons
- Host-side cross-validation: LS5000.md3 factory callsites push DTC as arg3 to READ/WRITE factories
  - Confirmed: 0x84 at 0x100B0D34 (READ) and 0x100B0E06 (WRITE), 0x88 at 0x100B19E3, 0x8D at 0x100B1E46, 0x87 at 0x100B451B
  - Inline READ builders at 0x100866d9/0x10086dfa/0x1008781a all hardcode DTC=0x00 (image data)
- SANE coolscan3 cross-validation: cs3_send_lut() uses DTC=0x03, cs3_set_boundary() uses DTC=0x88, sane_read() uses DTC=0x00
- DTC 0x87 entry has RAM pointer 0x400D45 (scan configuration area) confirming "scan parameters readback"
**KB Updated**: docs/kb/scsi-commands/read.md (replaced TBD DTC table with 15-entry verified table), docs/kb/scsi-commands/write.md (replaced TBD with 7-entry table, added dispatch chain, DTC-specific data phase sections)
**Confidence**: Verified (cross-validated firmware ↔ host ↔ SANE)

## Attempt 28: SEND/RECEIVE DIAGNOSTIC Handler Analysis
**Date**: 2026-03-05
**Tool**: Python binary analysis (xxd-style dumps + pattern matching)
**Target**: SEND DIAGNOSTIC handler at 0x023D32, RECEIVE DIAGNOSTIC handler at 0x023856
**Goal**: Discover diagnostic sub-commands and dispatch structure

### Method
- Dumped handler bytes and searched for `cmp.b #imm` dispatch patterns (A0-AF prefix)
- Traced CDB byte reads (`mov.b @(disp, er4)`) to identify which CDB fields are checked
- Measured handler sizes from dispatch table address boundaries
- Searched LS5000.md3 for all CDB builders setting opcode 0x1D (found exactly 1)

### Findings
1. **Handler size correction**: SEND DIAGNOSTIC is ~478 bytes (0x023D32-0x023F0A), NOT ~1800 as previously stated. RECEIVE DIAGNOSTIC is ~1244 bytes (0x023856-0x023D32).
2. **SEND DIAGNOSTIC dispatch**:
   - First check: CDB[1] bit 2 (SelfTest) and bit 4 (DevOfl) — both branch to same target
   - SelfTest=1 path: state-dependent operation (action depends on scanner state, not CDB)
   - SelfTest=0 + PF=1 path: parameter data dispatches on page codes 0x04, 0x05, 0x06, 0x38
3. **RECEIVE DIAGNOSTIC dispatch**:
   - Checks scanner state values 0x80FB, 0x80FC (eject/advance in-progress?)
   - Dispatches on diagnostic page codes: 0x05, 0x06, 0x38
4. **Host-side**: Only ONE CDB builder exists in LS5000.md3 (at 0x100aa3a0), always sets SelfTest=1
5. **State-dependent behavior**: SEND DIAGNOSTIC appears in init, pre-scan, post-scan, focus, and eject workflows — all with identical SelfTest=1 CDB. The firmware decides what to do based on internal state registers.
6. **No RELEASE builder**: Confirmed via binary search — zero instances of `C6 41 08 17` (mov byte ptr [ecx+8], 0x17) in LS5000.md3

**KB Updated**: docs/kb/scsi-commands/send-diagnostic.md (corrected handler size, added state-dependent behavior docs, diagnostic page codes, RECEIVE DIAGNOSTIC info)
**Confidence**: High (firmware analysis, no host-side verification of diagnostic pages since NikonScan always uses SelfTest=1)

## Attempt 29 — 2026-03-05 — Complete GPIO Port Reference Map
**Tool**: Python binary analysis (H8/300H instruction pattern matching)
**Target**: All 13 GPIO port registers (P1-P9, PA-PC DDR/DR)
**What I tried**: Scanned entire 512KB firmware for MOV.B @port,Rn / MOV.B Rn,@port / BSET #n,@port / BCLR #n,@port patterns on all 13 GPIO register addresses (0x80-0xD5)
**What I found**:
1. Port A DR (0xD3): 44 refs — PRIMARY motor output (not Port B as previously assumed)
2. Port 7 DR (0x8E): 16 refs, ALL reads, 14 in SCAN handler — adapter/sensor status input
3. Port B DR (0xD4): only 3 refs — NOT motor control (correction)
4. Port C DDR (0xD2): 17 refs, only bit 0 toggled — NOT adapter ID bits 3-7 (correction)
5. Port 3 DDR (0x84): 11 refs, bit 0 set/cleared — motor direction control
6. Port 9 DR (0xC8): 12 refs — motor encoder input + stepper output
7. Port 1 DDR/DR: 49 refs — data bus direction and multi-purpose I/O
**KB Updated**: system-overview.md (complete GPIO table), motor-control.md (supporting ports)
**Confidence**: High (exhaustive pattern search over full firmware binary)

## Attempt 30 — 2026-03-05 — ASIC Unknown Registers Investigation
**Tool**: Python binary analysis (absolute address pattern matching)
**Target**: 11 "Unknown" ASIC registers (0x200053, 0x20005A, 0x200069, etc.)
**What I tried**: Searched for MOV.B @aa:32 patterns (6A 28/A8 + addr) for each unknown register
**What I found**: ZERO direct absolute-address references for any of the 11 unknown registers. All are accessed via indexed addressing (ERn+displacement) from the init table. Without hardware documentation, their function cannot be determined.
**Result**: Confirmed these unknowns are genuinely unreachable via binary analysis alone
**Confidence**: High (exhaustive search, negative result confirmed)

## Attempt 31 — 2026-03-05 — H8/3003 Interrupt Vector Source Correction
**Tool**: Python binary analysis + SLEIGH pspec cross-reference + handler register access verification
**Target**: All 15 active interrupt vectors in firmware
**What I tried**:
1. Parsed all 64 vector table entries from firmware binary (4 bytes each at 0x000-0x0FF)
2. Cross-referenced against SLEIGH H8/300H pspec (`h8.pspec`) for interrupt source names
3. For disputed vectors, dumped handler code and checked which peripheral registers are accessed

**What I found**:
Vector-table.md had **10 of 13 active vectors with wrong interrupt source names**. The errors were systematic — as if the assignments were shifted from a different H8 variant. Confirmed correct assignments by checking handler register access:
- Vec 45 handler reads DTCR0B (0xFFFF2F) → DMA ch0B, not SCI0 receive
- Vec 60 handler tests ADCSR bit 7 (0xFFFFE8) → A/D converter, not Refresh timer
- Vec 40 handler reads TSR4 (0xFFFF95) → ITU4 compare match, not DMA ch1
- Vec 32 handler reads motor_mode (RAM) → ITU2 (motor dispatcher), not ITU4
- Vec 8 is TRAP #0 target (context switch via TRAPA #0 instruction)

**Key discovery**: Motor mode dispatcher runs on **ITU2** (Vec 32 = IMIA2), not ITU4 as previously documented. ITU4 (Vec 40 = IMIA4) is a system tick timer that increments a global timestamp. TSTR bit analysis (bit 2 = 11 start/15 stop, bit 4 = 1 start/0 stop) is consistent.

**Also found**: Vec 52 (0xD0) is INACTIVE (points to default handler 0x186) — system-overview.md had a spurious entry. Vec 19 (0x4C) was missing from system-overview.md but IS active. All SCI vectors (52-59) are inactive — serial I/O is polled.

**KB Updated**: vector-table.md (complete rewrite of source names + functional groups), system-overview.md (vector table corrected), motor-control.md (ITU2/ITU4 swap), isp1581-usb.md (IRQ5→IRQ1), main-loop.md (IRQ5→IRQ1), startup.md (IRQ5→IRQ1), memory-map.md (ITU4→ITU2)
**Confidence**: Verified (binary + pspec + handler register access, three independent confirmations)

## Attempt 32 — 2026-03-05 — USB Device Descriptor Extraction
**Tool**: Python binary analysis (struct.unpack for USB descriptors)
**Target**: USB descriptor templates in shared module flash (0x170FA-0x17170)
**What I tried**: Parsed USB device descriptors, endpoint descriptors, and configuration descriptors from firmware flash. Searched for USB string descriptors.
**What I found**:
1. **Two USB device descriptors** in flash:
   - USB 1.1 at 0x170FA: bcdUSB=0x0110, class=0xFF/0xFF/0xFF, VID=0x04B0, PID=0x4001, bcdDevice=0x0102
   - USB 2.0 at 0x1710C: bcdUSB=0x0200, same class/VID/PID
2. **Four endpoint templates** at 0x1711E-0x1713D:
   - EP1 OUT Bulk 64B (USB 1.1), EP2 IN Bulk 64B (USB 1.1)
   - EP1 OUT Bulk 512B (USB 2.0), EP2 IN Bulk 512B (USB 2.0)
3. **Two configuration descriptors** at 0x1713E and 0x17148: 1 interface, self-powered (0xC0), 2 endpoints
4. **Interface descriptor**: Class 0xFF/0xFF/0xFF (vendor-specific), confirming NOT USB Mass Storage
5. **INQUIRY/serial strings** in shared module:
   - 0x170D6: "Nikon   LS-50 ED        1.02DF17811" (LS-50 + serial number)
   - 0x16674: "Nikon   LS-5000-123456  123456" (LS-5000 template with placeholder serials)
6. No real USB string descriptors found — likely constructed dynamically by ISP1581 init code
**KB Updated**: usb-protocol.md (added USB Device Descriptors and Endpoint Configuration sections), isp1581-usb.md (added USB Device Descriptors in Flash section)
**Confidence**: High (direct binary extraction, cross-validated with known VID/PID)

## Attempt 33 — 2026-03-06 — Comprehensive Firmware Audit & Gap Analysis

**Tool**: Python binary analysis, parallel subagent research, hex dump, strings
**Target**: Complete firmware binary — looking for undocumented features, missing KB coverage, unknown regions

**What I tried**:
1. Mapped all 512KB of flash into usage categories (code, data, log, erased) by 4KB block
2. Counted all functions (660 by RTS, 304 unique call targets, ~270 documented in KB)
3. Extracted and analyzed the complete SCSI opcode dispatch at 0x020CA0 — 30 comparison values
4. Searched firmware strings for debug/test/factory/secret keywords
5. Analyzed the firmware string table at 0x49E30-0x49EFB in detail
6. Dumped the adapter-specific VPD table at 0x49C74 for all 8 adapter types
7. Examined data regions at 0x4B000-0x52000 (motor microstep tables, CCD correction LUTs)
8. Analyzed flash log record format at 0x60000/0x70000

**What I found**:
1. **"Test" adapter type (index 7)** — exists in string table at 0x49E73. VPD table at 0x49C74 confirms: adapter 7 has ZERO VPD page entries. This is a factory manufacturing test jig detected via GPIO Port 7.
2. **Film holder names** — FH-3 (standard), FH-G1 (glass), FH-A1 (medical/special) at 0x49E78-0x49E88. Returned in adapter-specific VPD pages.
3. **Mechanical positioning objects** — SA_OBJECT, 240_OBJECT, 240_HEAD, FD_OBJECT, 6SA_OBJECT, 36SA_OBJECT at 0x49E89-0x49EDB. Used for motor homing per adapter type.
4. **Calibration parameter names** — DA_COARSE, DA_FINE, EXP_TIME, GAIN at 0x49EDC-0x49EFB.
5. **Internal dispatch at 0x020CA0 contains 30 state codes, NOT SCSI opcodes** — these are the scan state machine dispatch, including extended codes 0xF3/0xF4.
6. **No hidden SCSI commands** — all 21 entries in the dispatch table at 0x49834 are documented in KB.
7. **No debug backdoors, easter eggs, or undocumented modes** — firmware is clean and straightforward.
8. **Binary coverage**: 314KB used / 210KB erased. ~89% of unique call targets documented. 100% of SCSI handlers, interrupt vectors, and task codes documented.
9. **~110KB of scan implementation code** has function boundaries mapped but not line-by-line decoded — diminishing returns, all implementation detail.

**KB Created**: `docs/kb/components/firmware/film-adapters.md` — Film adapters, factory test jig, film holders, positioning objects, calibration params
**KB Updated**: data-tables.md (string table expanded), inquiry.md (VPD table expanded to 8 adapters with handlers), send-diagnostic.md (RECEIVE DIAGNOSTIC section expanded), reserve.md (RELEASE section added)
**Confidence**: High (direct binary verification, VPD table confirmed empty for Test adapter)
