# Emulator Design Gap Analysis

Analysis of the 5 intentional design gaps and how each could be addressed.

## Gap 1: Hybrid SCSI (Emulator Handles Commands, Not Firmware)

**Current**: All 17 SCSI opcodes are handled by Rust code in `orchestrator.rs::handle_scsi_command()`. The firmware's SCSI dispatcher at `0x020AE2` is never invoked. The 26 NOP patches in `apply_flash_nop_patches()` disable the USB response manager (`0x01374A`) and data transfer (`0x014090`) calls inside the firmware's handlers.

**Why it's this way**: The firmware's SCSI handlers call USB I/O functions (`JSR @0x01374A`, `JSR @0x014090`) that interact directly with the ISP1581 hardware for DMA data transfers. These require a fully operational ISP1581 DMA engine, which the emulator's ISP1581 model does not implement (it only models FIFO read/write, not DMA control registers).

**How to implement firmware-dispatched SCSI**:

### Option A: Selective Un-NOP (Medium complexity)

1. Remove the 11 dispatch-level NOP patches (the `JSR @0x01374A` calls at `0x020B22` etc.)
2. Keep the handler-internal patches for now
3. Write the CDB to `FW_CDB_BUFFER` and set `FW_CMD_PENDING = 1`
4. Run the CPU until it reaches the dispatch function at `0x020AE2`
5. The dispatch function will do the table lookup at `0x49834`, validate permissions, and call the handler
6. The handler runs but its USB I/O calls are NOPed, so it just computes the response data and writes it to RAM
7. Read the response from the handler's RAM buffer and push to EP2 IN

**Problem**: Without USB I/O, handlers can't actually transfer data to the host. The response stays in RAM. We'd need to intercept the handler's return and scrape the response from wherever it was placed.

### Option B: ISP1581 DMA Completion (High complexity)

1. Un-NOP ALL patches, including handler-internal USB calls
2. Implement DMA completion signaling in the ISP1581 model:
   - When firmware writes DMA config (0x600018) + DMA count (0x600084), mark transfer as pending
   - When firmware writes EP control (0x60002C), execute the DMA: copy `dma_count` bytes from/to the EP data port
   - Signal completion via DcInterrupt bit
3. The firmware's handler writes data to the ISP1581 data port word-by-word, and the ISP1581 model collects it in EP2 IN FIFO
4. After handler returns, drain EP2 IN FIFO as the response

**Problem**: The firmware uses a complex multi-step DMA setup that interacts with the ASIC's DMA controller (registers at 0x200147-0x20014D). For scan data, the ASIC DMA reads CCD data from buffer RAM and streams it through the ISP1581. This requires modeling the ASIC DMA engine.

### Option C: Handler Hooking (Recommended — Low complexity)

1. Keep all NOP patches (firmware USB I/O stays disabled)
2. Instead of calling `handle_scsi_command()` from Rust, set up the CDB in RAM and call the firmware handler directly by setting PC to the handler address from the dispatch table
3. Run the CPU for N instructions until the handler returns (detected by SP returning to original value or PC reaching a known return address)
4. Read the handler's output from RAM (sense code at `0x4007B0`, response data from the handler's stack/buffer)
5. Push the response to EP2 IN ourselves

**Dispatch table** at `0x49834`: 21 entries, 10 bytes each:
```
[opcode:1][flags:2][reserved:1][handler_addr:4][exec_mode:1][reserved:1]
```

This gives us the exact handler address for each opcode. We call it directly, bypassing the firmware's dispatcher overhead but still exercising the handler's CDB parsing and response generation.

**Benefit**: Validates that firmware handlers correctly parse CDBs and generate responses. Doesn't require ISP1581 DMA.

**Remaining gap**: Handler-internal logic that depends on scanner state (motor position, CCD data, calibration values) would still produce stub results.

---

## Gap 2: No CCD/Motor Hardware

**Current**: Scan data is a synthesized test pattern (gradient/flat/checkerboard/bars). Motor position, CCD sensor data, and calibration are not modeled.

**Why it's this way**: The CCD sensor produces analog signals converted by a 14-bit ADC. The motor subsystem involves stepper control, encoder feedback, and position tracking. These are deeply physical systems.

**How to implement (levels of fidelity)**:

### Level 1: Static Scan Data from File (Easy)
- Add `--scan-data <file>` CLI flag that loads raw pixel data from a file instead of generating patterns
- The file would contain pre-captured scan data (e.g., from a real scanner)
- Useful for: replay testing, comparing emulator output with real hardware

### Level 2: Motor Position State Machine (Medium)
- Track motor position as an integer (steps from home)
- Model the home sensor (Port B GPIO or encoder input)
- SEND DIAGNOSTIC handler sets motor targets; motor "moves" instantly
- Position affects which VPD page (boundary) data is returned
- Useful for: testing multi-frame scans, adapter eject sequences

### Level 3: CCD Data Synthesis with Calibration (Hard)
- Model the CCD as a 1D array of pixel values (e.g., 4000 pixels for the LS-50's sensor)
- Generate per-line data with configurable offset/gain per channel
- Apply the firmware's calibration tables to produce corrected output
- Useful for: testing ICE (infrared) channel, calibration sequences

**Recommendation**: Level 1 is straightforward and immediately useful. Level 2 adds value for driver developers testing positioning. Level 3 is diminishing returns unless testing the full image pipeline.

---

## Gap 3: Warm-Boot Only

**Current**: `Emulator::new()` sets ASIC ready bit (`0x200041 |= 0x02`) immediately. The firmware sees "ASIC ready" on first check and takes the warm-boot path, skipping cold-boot hardware initialization.

**Why it's this way**: Cold boot requires the ASIC to complete a hardware initialization sequence (master enable → wait → ready). The real hardware takes ~100ms. The firmware polls the ready bit in a tight loop. Without setting it, the firmware hangs.

**How to implement cold boot**:

1. Remove the immediate ready-bit set in `Asic::write()` for offset `0x0001`
2. Instead, set `ready_countdown = N` (e.g., 50,000 instructions ≈ ~2ms at 25MHz)
3. `Asic::tick()` already decrements `ready_countdown` and sets the bit when it reaches 0
4. The firmware's polling loop runs for N iterations, then continues

**Benefit**: Tests the firmware's cold-boot path, which includes:
- Trampoline installation (currently pre-installed by emulator)
- RAM test (already runs in warm boot too)
- Full timer initialization (partially handled by JIT context init)

**Risk**: The cold-boot path may access hardware we haven't modeled (flash programming, VPD reads from flash log areas at 0x60000/0x70000).

**Recommendation**: Add `--cold-boot` flag. Default stays warm boot. Cold boot would be experimental.

---

## Gap 4: USB Fast-Path NOPed

**Current**: Two NOP patches at `0x012EC6` and `0x012ECE` disable USB bus initialization in the timer ISR path. Three more patches at `0x02080E`, `0x020820`, `0x020824` disable main-loop USB configure calls.

**Why it's this way**: The firmware's USB initialization sequence interacts with ISP1581 control registers (Mode, Address, Endpoint Configuration) that require multi-step handshakes. The emulator's ISP1581 model doesn't implement these configuration registers — it only models the data path (EP1 OUT/EP2 IN FIFOs) and interrupt flags.

**How to implement**:

### ISP1581 Configuration Registers
The firmware writes to these ISP1581 registers during USB init:
- `0x60000C` Mode: SOFTCT (bit 4), GLINTENA (bit 3)
- `0x600028` Address: device address assignment
- `0x600014` Endpoint configuration

Implementation:
1. Add `address`, `endpoint_config` fields to `Isp1581`
2. Handle writes to configuration registers (accept and store)
3. Make SOFTCT reflect connection state
4. Un-NOP the USB init patches
5. The firmware's init sequence should complete because all register writes are accepted

**Benefit**: The firmware would go through its real USB enumeration sequence, validating the ISP1581 interaction protocol documented in `docs/kb/components/firmware/isp1581-usb.md`.

**Risk**: Low — the init sequence is mostly register writes. If a step reads back a config register expecting a specific value, we'd need to return the correct default.

---

## Gap 5: SCI (Serial I/O) — Polled Stub Only

**Current**: `peripherals/src/sci.rs` is a 33-line stub. It provides DDR/DR register storage but no FIFO, no baud rate generation, no interrupt-driven receive/transmit. SCI vectors 52-59 are all inactive in the firmware.

**Why it's this way**: The firmware doesn't use serial I/O for normal operation. SCI may be used for factory debug/programming, but all operational communication is via USB.

**How to implement**:
1. Add TX/RX FIFOs to the SCI model
2. Implement TDRE (transmit data register empty) and RDRF (receive data register full) flags
3. Connect to a host-side PTY or TCP socket for debug console access
4. Fire TXI/RXI interrupts when enabled

**Benefit**: Minimal for normal emulation. Useful only if reverse-engineering the factory debug interface.

**Recommendation**: Keep as stub. Not worth implementing unless factory debug protocol becomes relevant.

---

## Priority Ranking

| Gap | Effort | Value | Recommendation |
|-----|--------|-------|----------------|
| 1 (Firmware SCSI) | Medium | High | Option C: Handler hooking |
| 2 (CCD/Motor) | Easy-Hard | Medium | Level 1: File-based scan data |
| 3 (Warm boot) | Easy | Low | Add --cold-boot flag |
| 4 (USB fast-path) | Medium | Medium | ISP1581 config registers |
| 5 (SCI serial) | Low | Minimal | Keep as stub |
