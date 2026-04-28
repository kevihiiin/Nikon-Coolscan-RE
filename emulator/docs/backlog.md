# Emulator Backlog

**Created**: 2026-03-27
**Updated**: 2026-04-26
**Source**: Full codebase review (4 parallel agents: silent-failure-hunter, design-reviewer, CLI/UX-reviewer, peripheral-correctness), plus gap analysis for NikonScan E2E compatibility
**Scope**: ~12K LOC Rust across 26 source files, 288 tests

Items are ordered by priority within each severity tier. Each item includes the original finding detail so it can be actioned without re-analysis. Cross-references to [`roadmap.md`](roadmap.md) milestones are shown in brackets.

**Resolved in M12** (commits `ffc7dc2`, `ad55b8e`): C1, I4, I5, I6, I7, I10, I13, I15.
**Resolved in M13** (commits `d222a87`, `9d472b0`): I11, I12, M4.
**Resolved in M14**: C2, I2, I3, I17, N3 (STALL), N2 (ZLP). I8 deferred (needs EP-selection modeling first).
**Resolved in M15-N7-fix** (commit TBD): N7 (FIFO underrun phantom TURs under usbscan.sys driving). 318 tests, smoke test still byte-for-byte green. 1 new e2e test, 4 new ISP1581 unit tests.
**Unblocked by M14.5**: NikonScan E2E (M15) is now runnable without hardware via the userspace USB/IP HIL setup at `emulator/hil/`. N4 (throughput benchmarking) becomes testable on the same setup.

The descriptions of resolved items are kept below for historical reference but are tagged with `[RESOLVED]`.

---

## Critical

### C1. ASIC registers not synced from memory bus to ASIC model [M12] [RESOLVED]

**Files**: `h8300h-core/src/memory.rs:218`, `coolscan-emu/src/orchestrator.rs:1368-1376`

The memory bus writes to the ASIC region (0x200000-0x200FFF) go into `MemoryBus::asic_regs[]`. The `Asic` struct has its own separate `regs[]` array. The orchestrator's `sync_peripherals()` only syncs register 0x0001 (master enable) from bus to ASIC model, and writes back 0x0002 (status) and 0x0041 (ready bit). All other behavioral ASIC registers are never forwarded:

- **0x01C1 (CCD line timing trigger)**: Firmware writes via bus → `asic_regs[0x1C1]` but never reaches `Asic::write(0x01C1, ...)`. The CCD trigger logic in `asic.rs:85-97` is dead code when running through the memory bus.
- **0x00C2 (DAC mode)**: Never synced. `generate_line()` reads `self.regs[0x00C2]` which stays at 0, so calibration dark/white frame logic produces wrong pixel levels.
- **0x0147-0x0149, 0x014B-0x014D (DMA address/count)**: Never synced. `dma_address()` and `dma_count()` read stale/zero values.

The emulator works only because SCSI-level intercepts bypass the firmware's hardware access path entirely. If firmware ever directly drives CCD capture without the SCSI intercept layer, the ASIC model would not generate scan line data.

**Fix direction**: Forward all behavioral ASIC registers in `sync_peripherals()`, or route ASIC writes through the model directly from the memory bus.

---

### C2. ISP1581 EP1 OUT FIFO silently returns 0 on underrun [M14] [RESOLVED]

**File**: `peripherals/src/isp1581.rs:176-177`

```rust
let lo = self.ep1_out_fifo.pop_front().unwrap_or(0);
let hi = self.ep1_out_fifo.pop_front().unwrap_or(0);
```

EP Data Port read at offset 0x20 returns fabricated zero bytes when the FIFO is empty, with only a `log::warn!` on line 174. The firmware reads 16-bit words from this port to obtain SCSI CDBs. If the FIFO is underfilled, the firmware silently receives zero-padded data — zeros are indistinguishable from TEST UNIT READY (opcode 0x00). The warn is only emitted when `fifo_len < 2`, so a single missing byte triggers it but two missing bytes in succession get two zeroes silently consumed after the first warning.

**Fix direction**: Return an error or set an underrun flag in DcInterrupt rather than fabricating data.

---

### C3. Unmapped memory reads return 0x00 with globally suppressed warnings [M16]

**File**: `h8300h-core/src/memory.rs:182-196`

After 16 unmapped reads, warnings are suppressed entirely unless `trace_enabled` is set. The counter `unmapped_reads` is a single global counter shared across all addresses. A legitimate bug causing reads from address 0x300000 would be invisible if a USB polling loop already exhausted the warning quota at address 0x063621.

**Fix direction**: Track per-address (or per-region) unmapped access counts instead of a single global counter. Or use a set of seen addresses and warn once per unique address.

---

### C4. Unmapped memory writes silently dropped [M16]

**File**: `h8300h-core/src/memory.rs:226-233`

Same 16-warning global suppression as C3. Writes to unmapped addresses are permanently lost with no programmatic detection. Dangerous for gap regions (0x080000-0x1FFFFF, 0x420000-0x5FFFFF) where a decoder bug could write critical state.

**Fix direction**: Same per-address tracking as C3.

---

### C5. God Object: `Emulator` struct is 2,300 lines with ~50 fields [M16]

**File**: `coolscan-emu/src/orchestrator.rs:69-119`

The `Emulator` struct conflates 6+ responsibilities: CPU execution loop, SCSI command emulation, TCP bridge protocol handling, USB gadget polling, firmware NOP patching, and scan image generation. It has 30+ fields covering unrelated concerns. `handle_tcp_message` at line 1657 directly calls `handle_scsi_command` which directly manipulates `self.bus`, `self.motor`, `self.scan_data`, and `self.peripherals` all in one call chain.

Additionally, duplicated boot logic exists between `run()` (lines 238-340), `boot_to_main_loop()` (lines 1897-1946), `step_one()` (lines 2319-2343), and `decode_execute_one()` (lines 1869-1891). Bug fixes must be applied to all copies, and tests using `step_one()` exercise subtly different behavior than the real `run()` loop.

**Fix direction**: Extract `ScsiEmulator`, `TcpBridge`, `ScanEngine` as separate types. Unify the instruction fetch/decode/execute loop into a single implementation.

---

## Important

### I1. Peripheral dual-state sync fragility [M16]

**File**: `coolscan-emu/src/orchestrator.rs:1287-1403`

The emulator maintains dual state: `bus.onchip_io[256]` (ground truth written by CPU) and peripheral behavioral models (`peripherals.timers`, `peripherals.gpio`, `peripherals.dma`, `motor`, `asic`). `sync_peripherals()` runs every instruction cycle and manually copies ~30 register fields between the two representations. A missed sync creates silent bugs.

Lines 1381-1382 clone `self.asic.last_line_data` (a `Vec<u8>` up to several KB) every cycle DMA completes. Lines 1392-1402 read and compare 15 individual I/O register bytes per cycle.

**Fix direction**: Unify state ownership — either peripheral models own registers and the bus dispatches to them, or the bus owns registers and models read from the bus.

---

### I2. ISP1581 `write_byte` on write-back-clear registers causes data loss [M14] [RESOLVED]

**File**: `peripherals/src/isp1581.rs:349-355`

`write_byte` calls `read_word()` to reconstruct current word value before merging. For DcInterrupt (0x18), `read_word` returns `self.dc_interrupt | IRQ_EP_TX_READY` (line 156), so the synthetic TX_READY bit gets included. When `write_word` then performs `self.dc_interrupt &= !val` (line 222), it incorrectly clears bits based on the synthetic value. Firmware uses word writes exclusively (per comment at line 323/341), so this path is not currently triggered, but it is a correctness hazard.

**Fix direction**: Guard write-back-clear registers in `write_byte` the same way EP Data Port is guarded, or skip the read-modify-write for known write-back-clear registers.

---

### I3. ISP1581 unmodeled register reads/writes invisible at default log level [M14] [RESOLVED]

**Files**: `peripherals/src/isp1581.rs:192-195` (reads), `peripherals/src/isp1581.rs:256-258` (writes)

Unmodeled ISP1581 registers return 0 (reads) or are dropped (writes) with only `log::trace!` — invisible at default `info` level. If firmware reads a register that was not modeled (DMA status, test registers, OTG status), it silently gets 0.

**Fix direction**: Promote to `log::debug!` or `log::warn!` (at least once per unique offset).

---

### I4. ITU timer: no overflow flag (OVF) or overflow interrupt [M12] [RESOLVED]

**File**: `peripherals/src/itu.rs:67`

When TCNT overflows from 0xFFFF to 0x0000, the H8/3003 sets TSR bit 2 (OVF) and can generate an overflow interrupt if OVIE (TIER bit 2) is enabled. The emulator does not check for this transition and never sets OVF. If firmware relies on overflow interrupts or polls OVF, it will hang.

---

### I5. ITU timer: compare-match B never generates interrupt [M12] [RESOLVED]

**File**: `peripherals/src/itu.rs:83-90`

`tick()` sets IMFB flag in TSR on GRB match but never returns `true` for GRB match interrupts. The `IMIA_VECTORS` table (line 103) only has IMIA vectors; there is no IMIB vector table. If firmware enables IMIEB for any timer, that interrupt will never fire.

---

### I6. ITU timer: GRA==GRB conflict on same tick [M12] [RESOLVED]

**File**: `peripherals/src/itu.rs:70-90`

When GRA == GRB: code first matches GRA (line 70), potentially clearing TCNT to 0 (line 75). Then it checks GRB (line 84) against the now-cleared TCNT (0) — GRB match is lost. On real hardware, both would trigger simultaneously before clearing.

**Fix direction**: Check both GRA and GRB against the pre-clear TCNT value before applying any clearing.

---

### I7. Watchdog `tick()` never called from orchestrator [M12] [RESOLVED]

**File**: `coolscan-emu/src/orchestrator.rs` (missing call), `peripherals/src/wdt.rs:35`

The watchdog model has `tick()` but it is never called. The counter never advances, so even with `enabled = true`, the watchdog can never fire. The `--watchdog` CLI flag is non-functional.

**Fix direction**: Call `self.peripherals.watchdog.tick()` in the main instruction loop or in `sync_peripherals()`.

---

### I8. DcBufferLength always returns 64, ignoring actual FIFO state [M14] [DEFERRED]

**Update 2026-04-26 (M14)**: Attempted to make DcBufferLength reflect EP1 OUT FIFO length. This broke `gate_trace_inquiry_isp1581_access` because the firmware's response manager at FW:0x013D7E reads DcBufferLength after writing EP Control to confirm the IN endpoint has buffer space — a non-zero return is required or the manager loops forever. Per-EP accuracy needs the EP-selection register modeled first. Reverted to the constant 64 with an updated comment explaining why. The actionable correctness piece (silent zero on underrun) is covered by the new `ep1_underrun` flag (C2 fix below).


**File**: `peripherals/src/isp1581.rs:158-165`

DcBufferLength at offset 0x1C always returns 64 regardless of EP1 OUT FIFO contents. `ep1_last_inject_size` (line 76/281) is set but never used — dead code. If firmware checks DcBufferLength to decide how many bytes to read, it could read beyond available data (causing FIFO underrun C2) or stop too early.

**Fix direction**: Return `self.ep1_out_fifo.len()` or `self.ep1_last_inject_size` instead of hardcoded 64.

---

### I9. GPIO/DMA/ADC/ITU catch-all returns 0 with no logging [M16]

**Files**:
- `peripherals/src/gpio.rs:102` (read) and `:120` (write)
- `peripherals/src/dma.rs:69` (read)
- `peripherals/src/adc.rs:28` (read)
- `peripherals/src/itu.rs:174-177` (read) and `:194-197` (write)

Unmodeled ports/registers silently return 0 or drop writes with zero logging. The H8/3003 has many GPIO ports (Port 1, 2, 5, 6, 8, B) not modeled. Per CLAUDE.md: "4 GPIO ports remain Medium (hardware-only)".

**Fix direction**: Add `log::debug!` or `log::trace!` to catch-all arms for peripheral reads/writes.

---

### I10. SCI module defined but never integrated into bus routing [M12] [RESOLVED]

**File**: `peripherals/src/sci.rs` (not routed in `bus.rs` or orchestrator)

SCI struct exists with `ssr = 0x84` (TDRE=1) but is never instantiated in `PeripheralBus` or routed in the orchestrator. SCI0 at 0xFFFFB0-0xB5 reads/writes go to raw `onchip_io[]`. SSR reads as 0x00 (TDRE=0) instead of model's 0x84 (TDRE=1). If firmware polls TDRE before transmitting, it would spin forever.

**Fix direction**: Route SCI0 registers through the SCI model in `sync_peripherals()`, at minimum syncing SSR.

---

### I11. TCP `read_exact` on non-blocking socket loses partial reads [M13] [RESOLVED]

**File**: `coolscan-emu/src/orchestrator.rs:1593-1623`

`poll_tcp()` calls `stream.read_exact(&mut header)` on a non-blocking socket. If a TCP segment splits the 3-byte header, `read_exact` returns `WouldBlock` after partial read, but the partially-read byte is lost (no read buffer). Same issue for payload at line 1606.

**Fix direction**: Add a per-connection read buffer that accumulates partial reads across `poll_tcp()` calls.

---

### I12. TCP bind failure logged but emulator continues silently [M13] [RESOLVED]

**File**: `coolscan-emu/src/orchestrator.rs:182-194`

If port 6581 is in use, the error scrolls past among many info-level boot messages. The emulator appears to start successfully but the TCP bridge (primary use case) is non-functional.

**Fix direction**: Either exit with error when TCP bind fails (unless `--gadget` is the primary bridge), or print a prominent warning at the end of startup.

---

### I13. Motor direction reads Port 3 DR (0x84) but comment says DDR (0x83) [M12] [RESOLVED]

**Files**: `coolscan-emu/src/orchestrator.rs:1338`, `peripherals/src/motor.rs:5`

The motor.rs comment says "Direction control on Port 3 DDR (0xFFFF84) bit 0" but 0x84 is Port 3 DR, not DDR (DDR is 0x83). The code reads `self.bus.onchip_io[0x84]`. One of them is wrong — need to verify against firmware disassembly.

**Fix direction**: Check firmware's motor direction writes to determine if DR or DDR is correct, fix the wrong one.

---

### I14. Executor `Bcc`/`Bsr` silently fall through on unexpected operand types [M16]

**Files**: `h8300h-core/src/execute.rs:312` (Bcc), `:330` (Bsr)

If the decoder ever produces a `Bcc` or `Bsr` with an unexpected operand type (not `PcRel8`/`PcRel16`), the branch target is silently ignored and execution continues sequentially. For BSR, the return address is pushed to the stack (corrupting it), then execution falls through — the corresponding RTS never pops the spurious return address.

**Fix direction**: Replace catch-all `_ => next_pc` with `unreachable!()` or at minimum a `log::error!`.

---

### I15. ASIC DMA completion may double-fire Vec 49 interrupt [M12] [RESOLVED]

**File**: `coolscan-emu/src/orchestrator.rs:1377-1441`

Both `tick()` return value (line 1377, used for data write at 1380) and `take_dma_complete()` (line 1441, used for interrupt) report the same DMA completion event. `take_ccd_trigger()` (line 1436) and `take_dma_complete()` (line 1441) independently fire Vec 49 for what is logically one CCD line capture event.

**Fix direction**: Ensure Vec 49 fires exactly once per CCD line capture, not once for trigger and once for DMA complete.

---

### I16. Default log volume overwhelming for end users [M16]

**File**: `coolscan-emu/src/main.rs:7`

Default log level is `info`. ~100+ `log::info!` calls in the orchestrator produce hundreds of lines per run. No quiet mode documented in `--help`. Users would need to know to set `RUST_LOG=warn`.

**Fix direction**: Reduce default to `warn`, or add `--verbose`/`--quiet` flags, and document `RUST_LOG` in `--help`.

---

### I17. No signal handling for graceful shutdown [M14] [RESOLVED]

**File**: `coolscan-emu/src/main.rs` (missing)

No `SIGINT`/`SIGTERM` handler. Ctrl+C during `--gadget` mode may skip USB gadget teardown (`GadgetBridge::Drop` depends on Rust runtime behavior for signal-killed processes).

**Fix direction**: Install a signal handler that sets an atomic flag checked in the main loop, allowing graceful `Drop`-based cleanup.

---

### I18. Halt/panic messages opaque to non-developers [M16]

**Files**: `h8300h-core/src/execute.rs:167,193,414`, `coolscan-emu/src/orchestrator.rs:265-271`

`EXTU.B`/`EXTS.B` panics include PC but no guidance. Unknown instruction halts show raw hex dumps with no suggestion. 11 "Unhandled operand" panics in the executor show internal enum variants. A user sees a Rust backtrace with no actionable information.

**Fix direction**: Add context to panic messages ("This may indicate an unsupported firmware version") or convert panics to graceful error returns with state dumps.

---

### I19. Flash writes outside log area silently fail [M16]

**File**: `h8300h-core/src/memory.rs:204-211`

Writes to flash addresses below 0x60000 are `log::warn!` but silently discarded. The CPU has no way to know the write failed. If firmware ever attempts flash programming outside the log area, the operation appears to succeed but data is not stored.

---

## Minor

### M1. CLI args missing value produce misleading "unknown argument" warning [M16]

**File**: `coolscan-emu/src/config.rs:93,97,116,126,143,156,167`

When `--firmware`, `--adapter`, etc. is the last argument (no value follows), the `if i + 1 < args.len()` guard fails silently and the argument falls through to the `other` branch at line 171. Prints `Warning: unknown argument '--firmware'` instead of `"--firmware requires a value"`.

---

### M2. Default firmware path is relative and context-dependent [M16]

**File**: `coolscan-emu/src/config.rs:182-184`

Default path `../binaries/firmware/Nikon LS-50 MBM29F400B TSOP48.bin` only works from the `emulator/` directory. The test at line 49 uses a different relative path, confirming the inconsistency.

---

### M3. `--max 0` accepted without warning [M16]

**File**: `coolscan-emu/src/config.rs:120`

A value of 0 runs zero instructions and exits immediately, which could confuse users.

---

### M4. Default `max_instructions=10M` is a hard stop with no warning [M13] [RESOLVED]

**File**: `coolscan-emu/src/config.rs:73`

For interactive TCP use, the emulator silently stops after 10M instructions with a state dump. No approaching-limit warning. `--help` doesn't clarify this is a hard stop.

---

### M5. Zero-patch mode flags undocumented in `--help` [M16]

**File**: `coolscan-emu/src/config.rs:221-223`

`--cold-boot`, `--full-usb-init`, `--firmware-dispatch`, `--emulated-scsi` are expert flags with minimal help text. The zero-patch mode (`--full-usb-init --firmware-dispatch` without `--emulated-scsi`) is documented only in a code comment at `orchestrator.rs:459-461`.

---

### M6. `PeripheralBus` is an empty shell with no encapsulation [M16]

**File**: `peripherals/src/bus.rs:13-42`

`PeripheralBus` holds 5 peripheral models with no methods beyond `new()`. Comment explains routing was removed due to address overlap bugs. The type adds indirection without behavioral value.

---

### M7. `InterruptController::assert_interrupt` sorts entire vec on every insertion [M16]

**File**: `h8300h-core/src/interrupt.rs:40-47`

Appends then sorts on every assert. Called from `check_peripherals()` every instruction cycle. With ~1-3 pending interrupts, a `BinaryHeap` or insertion-sort would be more appropriate for this hot path.

---

### M8. `MemoryBus` public fields enable I/O register bypass [M16]

**File**: `h8300h-core/src/memory.rs:82-125`

`onchip_io: [u8; 256]` being public allows 45+ direct writes in `sync_peripherals()` without going through `write_onchip_io()`, bypassing any future side-effect handling (watchpoints, logging).

---

### M9. ASIC `generate_line` noise is deterministic, not pseudo-random [M16]

**File**: `peripherals/src/asic.rs:143`

Uses `(i as u16).wrapping_mul(31).wrapping_add(self.line_counter as u16 * 17)) & 0x3F` — purely deterministic with strong periodic structure. If calibration algorithms detect structured patterns, this could cause false test failures.

---

### M10. Watchdog only handles 0x5A feed; ignores all other register writes [M16]

**File**: `peripherals/src/wdt.rs:29-32`

The real H8/3003 watchdog has TCSR, TCNT with write-protect sequences. Only the feed pattern (0x5A) is handled. Also, `fed` flag is cleared unconditionally on every `tick()` (line 44), making it redundant — the counter check dominates.

---

### M11. ADC only implements channel A; ADST not auto-cleared [M16]

**File**: `peripherals/src/adc.rs:23-38`

H8/3003 ADC has 4 result registers (ADDRA-ADDRD). Only ADDRA implemented; ADDRB/C/D return 0. ADCSR channel select bits stored but ignored. ADST (bit 5) not auto-cleared after conversion in single mode.

---

### M12. ISP1581 offset 0x1C write maps to `ep_index` (mismapping) [M16]

**File**: `peripherals/src/isp1581.rs:227`

Offset 0x1C is DcBufferLength (read-only per ISP1581 datasheet). The write handler stores the value in `ep_index`, but EndpointIndex is at a different offset.

---

### M13. ASIC `generate_line` wrong byte count for odd `dma_count` [M16]

**File**: `peripherals/src/asic.rs:124-126`

`word_count = byte_count / 2` uses integer division. If `dma_count` is odd, the last byte stays 0. Unlikely since CCD data is word-aligned, but no assertion guards this.

---

### M14. Gadget setup failure exits with code 0 [M14]

**File**: `coolscan-emu/src/main.rs:42-47`

When `--gadget` setup fails, the emulator falls back to TCP-only mode with exit code 0. User may not notice the error in log output.

---

### M15. Unknown CLI arguments silently accepted [M16]

**File**: `coolscan-emu/src/config.rs:175`

A typo like `--gadgett` produces a warning but is otherwise ignored. The user doesn't get the gadget bridge they expected.

---

### M16. Motor `port_a_write` can detect spurious step on motor mode transition [M16]

**File**: `peripherals/src/motor.rs:84-86`

`active_motor_mut()` returns motor based on `active_mode`, but `port_a_write` is called every sync cycle regardless of whether mode just changed. If mode changes mid-cycle, old motor's `last_phase` is stale but `active_motor_mut()` now points to the new motor — could cause spurious step detection.

---

### M17. ISP1581 `take_irq` is non-destructive despite `take_` naming [M16]

**File**: `peripherals/src/isp1581.rs:310-312`

`take_irq` only reads `irq_pending` without clearing it. The `take_*` convention implies consuming. This is functionally correct for ISP1581 (IRQ stays asserted until firmware clears it), but the naming is misleading.

---

### M18. Benchmark output uses `eprintln!` while everything else uses `log::*` [M16]

**File**: `coolscan-emu/src/main.rs:62-68`

Inconsistent formatting — benchmark output has no timestamps or level prefixes.

---

### M19. `wait_response()` returns empty Vec on timeout indistinguishably from zero-length response [M16]

**File**: `coolscan-emu/src/orchestrator.rs:1863`

Caller cannot distinguish "timeout" from "command produced zero-length response".

---

## Positive Observations

These strengths should be preserved:

1. **Zero `unwrap()`/`expect()` in production code** — excellent discipline
2. **No `unsafe` code anywhere** in the codebase
3. **CPU core (decode/execute) is clean and well-tested** — faithful to H8/300H manual
4. **PC range validation after every instruction** catches wild jumps
5. **Flash NOP patches validated** before application (expected vs actual bytes checked)
6. **Context switch monitoring** with save area corruption detection
7. **Firmware dispatch has multiple escape hatches** (timeout, stuck-PC, SLEEP, unknown instruction)
8. **Gadget bridge has proper `Drop`-based cleanup**
9. **269 tests with 0 clippy warnings**
10. **Clean crate-level separation** (h8300h-core, peripherals, bridge, coolscan-emu)

---

## Recommended Priority Order

Organized by milestone (see [`roadmap.md`](roadmap.md) for milestone descriptions and exit criteria).

### Milestone 12 — Firmware-Path Correctness (do first)

1. **C1** — ASIC register sync: entire CCD/DMA path broken via bus; only SCSI intercepts mask this
2. **I10** — SCI routing: TDRE polling hang risk in firmware dispatch
3. **I4/I5** — ITU timer completeness: OVF + IMIB interrupts missing
4. **I6** — ITU GRA==GRB conflict: both should trigger before clearing
5. **I13** — Motor direction register: DDR vs DR, one is wrong
6. **I15** — ASIC DMA double-fire: could corrupt scan timing
7. **I7** — Watchdog tick: quick fix, enables `--watchdog`

### Milestone 13 — TCP Bridge Hardening

8. **I11** — TCP partial read buffer: latent data corruption under network latency
9. **I12** — TCP bind failure: emulator appears to start but TCP is non-functional
10. **M4** — Remove 10M instruction hard stop for interactive sessions

### Milestone 14 — USB Gadget Ready

11. **C2/I8** — FIFO underrun + DcBufferLength: linked issues, fix together
12. **I2** — ISP1581 write-back-clear: correctness hazard for byte writes
13. **I3** — ISP1581 unmodeled register logging: invisible gaps
14. **I17** — Signal handling: gadget teardown on Ctrl+C
15. **M14** — Gadget setup failure exit code

### Milestone 15 — NikonScan E2E (no backlog items — integration testing)

### Milestone 16 — Polish & Robustness

16. **C3/C4** — Per-address unmapped tracking: global counter hides real bugs
17. **C5/I1** — God object + dual-state sync: largest architectural improvement
18. **I9** — GPIO/DMA/ADC/ITU catch-all logging
19. **I14** — Executor Bcc/Bsr fallthrough: replace with `unreachable!()`
20. **I19** — Flash write protection
21. Everything else in severity order (I16, I18, M1-M19)

---

## New Items (2026-04-05 gap analysis)

Items identified during NikonScan E2E compatibility analysis that aren't covered by the original audit.

### N1. No USB SET_ADDRESS / GET_DESCRIPTOR handling in ISP1581 model [M14] [INVESTIGATED]

**Update 2026-04-26 (M14)**: Traced `--full-usb-init --firmware-dispatch` for 5M instructions. Firmware only touches modeled offsets (0x0C, 0x18, 0x1C, 0x20, 0x2C). Without a USB host driving enumeration the firmware's USB init code stalls at SOFTCT toggle — there are no missing registers to add for the no-host case. Future surprises will be caught by I3's warn-once mechanism. Real enumeration registers can only be characterized in M15 against NikonScan.


**File**: `peripherals/src/isp1581.rs`

NikonScan (via Windows USB stack) sends standard USB control transfers during enumeration: SET_ADDRESS, GET_DESCRIPTOR (device, config, string), SET_CONFIGURATION. The ISP1581 model doesn't handle USB control transfers at all — the FunctionFS gadget layer handles enumeration in `--gadget` mode, but in firmware-dispatch mode with `--full-usb-init`, the firmware's own USB init code handles these. Need to verify that the ISP1581 model provides the right register responses during firmware-driven USB enumeration.

**Action**: Trace `--full-usb-init` boot and catalog which ISP1581 registers are read/written during USB init. Add any missing registers.

### N2. No USB bulk transfer chunking / short-packet handling [M14] [RESOLVED]

**File**: `peripherals/src/isp1581.rs`, `bridge/src/gadget.rs`

Real USB bulk transfers are chunked into max-packet-size (512B for USB 2.0). The ISP1581 EP2 IN FIFO is drained in one go (`isp1581_drain(65536)`). NikonScan may expect standard USB bulk transfer semantics: short packet = end of transfer. The gadget bridge's `send_ep2_in` writes all data in one `write_all` — FunctionFS may or may not handle chunking.

**Action**: Test with a large INQUIRY EVPD response and verify FunctionFS handles chunking, or implement explicit max-packet-size chunking in the gadget bridge.

### N3. No USB STALL / NAK handling [M14] [RESOLVED]

**File**: `peripherals/src/isp1581.rs`

When firmware encounters an unsupported USB request, real hardware STALLs the endpoint. The ISP1581 model has no STALL mechanism. NikonScan may send control requests the firmware doesn't understand — without STALL, the host hangs.

**Action**: Implement EP STALL flag in ISP1581 model. In gadget mode, FunctionFS handles this natively.

### N4. Scan data throughput unknown for real USB [M15]

A full 4000 DPI scan of a 35mm frame is ~50MB of image data. At USB 2.0 bulk speeds (480 Mbps theoretical, ~35 MB/s practical), this takes ~1.5s. But the emulator's CPU loop is the bottleneck — it must generate and push data through the ISP1581 FIFO fast enough. Need benchmarking.

**Action**: Run `--benchmark` with a large scan and measure MIPS + data throughput. If too slow, consider batched DMA transfers or instruction caching.

### N5. No USB reset / disconnect handling [M15]

**File**: `coolscan-emu/src/orchestrator.rs`, `bridge/src/gadget.rs`

If NikonScan closes and reopens the scanner (or the user unplugs/replugs), the emulator has no mechanism to reset state. `GadgetBridge::recv_ep1_out` detects EOF and sets `connected = false`, but the emulator doesn't reset firmware state or re-enumerate.

**Action**: On gadget disconnect, either reset the emulator state or re-run the boot sequence.

### N6. Motor timing not modeled (instant teleport) [M15]

**Files**: `peripherals/src/motor.rs`, `coolscan-emu/src/orchestrator.rs`

Motors teleport instantly (`instant_mode`). NikonScan may poll SEND DIAGNOSTIC status or wait for motor completion flags at specific timing. If NikonScan assumes motor movement takes N milliseconds and checks too early, it could see stale state.

**Action**: Add configurable motor speed (steps/sec) with optional `--instant-motors` override for testing. Default to realistic timing for USB gadget mode.

### N7. usbip server → ISP1581 EP1 OUT FIFO race produces phantom TURs under usbscan.sys driving [RESOLVED commit TBD]

**Resolution (2026-04-28, 318 tests)**: Three-part fix in `peripherals/src/isp1581.rs` + `coolscan-emu/src/orchestrator.rs`:

1. **CDB pattern fallback in ISP1581**: new `Isp1581::set_ep1_pattern(cdb)` API with `ep1_pattern: Option<Vec<u8>>` + cycling cursor. When EP1 OUT FIFO underruns, reads now cycle a 16-byte zero-padded CDB instead of fabricating zeros. `host_send_ep1` clears the pattern when real host data arrives. Wired through `MmioDevice::set_ep1_pattern` trait method + `MemoryBus::isp1581_set_ep1_pattern`. New unit tests: `test_ep1_pattern_serves_underrun_reads_without_warning`, `test_ep1_pattern_cleared_by_real_host_send`, `test_ep1_pattern_falls_back_after_fifo_drained`, `test_ep1_set_pattern_with_empty_clears_pattern`.

2. **scsi_command zero-pads firmware CDB buffers**: `0x4007DE` and `0x40008A` now get `[cdb..., 0, 0, ..., 0]` to a full 16 bytes per call, instead of just the first `cdb.len()` bytes leaving prior-command stale args in positions 1..15. Without this, a 1-byte 0xD0 inheriting `[0x12 0x00 0x00 0x00 0x24 0x00]` from a prior INQUIRY made the firmware decode 0xD0 as "phase query with alloc_len=36" and emit a metadata-laden response.

3. **Transport opcodes (0xD0, 0x06) bypass firmware dispatch**: even with `--firmware-dispatch`, `scsi_command` now routes 0xD0 (phase query) and 0x06 (sense fetch) through the Rust emulation path, which returns the wire-format expected by `NKDUSCAN.dll` (1-byte phase / proper sense buffer). The firmware's dispatcher handlers for these opcodes write 24+ bytes of internal state where the host expects single bytes; surplus bytes accumulated in the `bridge::usbip_server` `state.ep2_in` queue and corrupted the next bulk-IN read. New regression test `post_phase_query_after_inquiry_returns_1_byte_firmware_dispatch`.

Live emulator log post-fix shows clean traffic: `received 6 bytes (0x12) → sending 36`, `received 1 byte (0xD0) → SCSI EMU: PHASE QUERY → phase=0x00 → sending 1 byte`. Smoke test (`smoke_inquiry_via_usbip`) still byte-for-byte matches the 36-byte INQUIRY fixture. **Phantom TURs no longer fire under usbscan.sys driving.**

**Live preview_scan still blocks on a separate, post-N7 NikonScan-side rejection** — see N9 for the new issue.

**Discovered**: 2026-04-28 during the first live `preview_scan` recipe run against `usbip-win2 + usbscan.sys` in Win11 LTSC.
**Files**: `coolscan-emu/src/orchestrator.rs::poll_usbip`, `peripherals/src/isp1581.rs:174-177`

The smoke test `smoke_usbip_e2e` works because the test harness pushes one INQUIRY CDB and reads one response in lockstep. Under Windows `usbscan.sys` driving the same VID/PID, the timing is different:

1. usbip-win2 attaches → PnP transitions to OK, usbscan service Running.
2. NikonScan launches, opens a usbscan handle, and issues an INQUIRY (or a sequence of CDBs) via the bulk-out endpoint.
3. The kernel-mode driver's URB submission and the firmware's IRQ1 handler reading 2 bytes from EP1 OUT race. The firmware reads first, finds the FIFO empty, and the C2 fix only emits a one-time warn — the read still **fabricates two zero bytes** which the firmware decodes as opcode `0x00` = TEST UNIT READY.
4. Firmware happily processes the phantom TUR (handler returns success). No actual INQUIRY reaches the firmware.
5. NikonScan: "Nikon Scan was unable to find any active devices." Status bar shows "Ready." but TWAIN data source enumeration failed.

Emulator log evidence (run `c0901a108b3948f9a775dea55fa7adeb`):
```
WARN  peripherals::isp1581] ISP1581: EP1 OUT FIFO underrun (0 bytes available, 2 needed) — fabricated zeros may be misread as TUR opcode
INFO  coolscan_emu::orchestrator] FW DISPATCH: handler returned after 5188 instructions
WARN  peripherals::isp1581] ISP1581: EP1 OUT FIFO underrun ...
INFO  coolscan_emu::orchestrator] FW DISPATCH: handler returned after 1547 instructions
```

The single `usbip] Got connection from 192.168.122.115:49685` event confirms one (and only one — see also: usbip server only accepts one attach per emulator instance) successful TCP attachment, but no `MILESTONE: SCSI: INQUIRY handler` lines fire after that point. Just phantom TURs.

**M14 closed C2 with a warn-once flag, but the underlying fabrication is still happening.** That was sufficient for `--gadget` and the smoke test (where pushers pre-populate the FIFO before reads), but insufficient for live usbscan-driven traffic.

**Fix direction (sketch)**:
- Make EP1 OUT FIFO reads block (or NAK at the USB level) when underrun rather than fabricate zeros.
- Modeling: when firmware tries to read 2 bytes from an empty FIFO during IRQ1 dispatch, defer the read until the orchestrator's `poll_usbip` has actually pushed CDB bytes into the FIFO. Could use a "pending read" state in ISP1581 + an interrupt-pending hold.
- Alternatively (simpler but heavier): in `poll_usbip`, atomically push a complete CDB (full 12 or 16 bytes) into EP1 OUT FIFO and set the IRQ1-pending flag in one transaction, so the firmware only sees a transition from "empty" to "complete CDB ready" — never half-filled.
- Verify with a *new* HIL test: drive usbip-win2 from Linux (`vhci-hcd` + `usbip attach`) with rapid sequential INQUIRY/MODE SENSE/READ CAPACITY CDBs, assert the firmware sees those exact opcodes in the dispatcher milestones, not 0x00.

**Why this blocks M15**: `preview_scan` and `full_scan` both need NikonScan to enumerate the device. Until N7 is fixed, recipes can't get past the "scanner-ready" expect.

**Backlog item I8** (DcBufferLength accuracy, M14-deferred) is adjacent — fixing N7 may also unstick I8 since "did the host fully fill EP1 OUT" becomes meaningful.

### N9. NikonScan TWAIN data source rejects emulator device after clean INQUIRY+0xD0 exchange [M15-blocking]

**Discovered**: 2026-04-28 during the post-N7-fix `preview_scan` re-run. Filed separately because the N7 fix DOES land — phantom TURs are gone — but NikonScan still shows "Nikon Scan was unable to find any active devices" on launch.

**Files**: bridge / Windows-side investigation needed; emulator `coolscan-emu/src/orchestrator.rs::poll_usbip` and `bridge/src/usbip_server.rs` may need response-format tweaks.

**Live emulator log shows mechanically-correct exchange**:
```
USBIP: received 6 bytes from host (CDB[0]=0x12)
FW DISPATCH: opcode 0x12 → handler returned after 5188 instructions
USBIP: sending 36 bytes to host (sense_key=0x0, asc=0x0)        # INQUIRY OK, vendor "Nikon", product "LS-50 ED"
USBIP: received 1 bytes from host (CDB[0]=0xD0)
SCSI EMU: PHASE QUERY → phase=0x00
USBIP: sending 1 bytes to host (sense_key=0x0, asc=0x0)         # phase=0x00 idle, single byte (post-N7-fix)
USBIP: received 6 bytes from host (CDB[0]=0x12)                  # NikonScan retries INQUIRY
USBIP: sending 36 bytes to host                                  # same response
USBIP: received 1 bytes from host (CDB[0]=0xD0)
USBIP: sending 1 bytes to host                                   # same response
[no further commands; NikonScan gives up and shows "no active devices" dialog]
```

Confirmed via qemu-ga on the Windows side at the failure point: device PnP is `Status=OK / CM_PROB_NONE / Service=usbscan`, `usbip port` shows attached at 480 Mbps, `usbscan` service is `Running`. Nothing wrong on the Windows kernel side.

So: NikonScan retries INQUIRY twice, gets correct responses both times, then gives up. INQUIRY response is byte-for-byte identical to the smoke-test fixture (which the M14.5 `smoke_usbip_e2e` test asserts byte-equal). NkDUSCAN.dll's STI device enumeration (per `docs/kb/components/nkduscan/classes.md`) uses `IOCTL_GET_DEVICE_DESCRIPTOR` not SCSI INQUIRY for device discovery — that's a kernel-level USB descriptor query that the `bridge::usbip_server` already advertises correctly (VID 04B0, PID 4001, max_packet_size 0x200 = USB 2.0 HS).

**Hypotheses ranked by likelihood**:

1. **NikonScan's TWAIN data source needs a TUR / MODE SENSE / RESERVE handshake before declaring the device acceptable**, and we never see those because NikonScan gives up first. Diagnostic: walk through NikonScan4.ds DS_Entry initialization in Ghidra and find where it short-circuits on a missing prerequisite. (Requires RE on NikonScan4.ds; phase log suggests it's already documented.)
2. **NkDUSCAN's `CUSBDeviceTable::virtual_20`** at 0x10003a90 enumerates STI devices but we appear in the list correctly per qemu-ga. Maybe `CUSBDevInfo::virtual_8` (probe) is failing because of some descriptor field mismatch beyond the `IOCTL_GET_DEVICE_DESCRIPTOR` we already provide.
3. **Timing race**: NikonScan launches via `Lifecycle.usbip_reattach`'s 5s settle hook, but the kernel-side WIA enumeration may not have re-published the device handle to NkDUSCAN's STI interface yet. Increasing the post-attach settle to 10-15s might unstick this.
4. **Bridge response not closing properly**: NikonScan may expect a zero-length packet (ZLP) on EP2 IN after the 36-byte response to signal end-of-transfer. The gadget bridge's `send_ep2_in` already does this for HS-aligned writes (see N2 RESOLVED in M14); the USB/IP server may not.

**Action (in priority order)**:
- a) Try a 15-30 s post-attach settle in `Lifecycle.usbip_reattach` — cheapest and rules out hypothesis 3.
- b) Enable `usbmon` or USB/IP packet capture on the host side to compare against a real-LS-50 trace if anyone has one, to identify what URBs NikonScan actually sends and how it short-circuits.
- c) RE NikonScan4.ds DS_Entry to find the device-acceptance check.
- d) Walk through `bridge::usbip_server::handle_urb` against the smoke-test path to see what differs between "smoke test sends 1 INQUIRY → gets 36 bytes back" and "live host sends 2 INQUIRYs in rapid succession" — possibly a state-cleanup gap between commands.

**Why this is M15-blocking**: `preview_scan` and `full_scan` both need NikonScan to enumerate the device. Until N9 is resolved, recipes can't get past `expect_screen("nikonscan-scanner-ready")`.

### N8. usbip server only accepts ONE attach per emulator instance [M16-prereq]

**Discovered**: 2026-04-28 same session.
**File**: `bridge/src/usbip_server.rs`

After the first usbip TCP connection and disconnect, subsequent `usbip attach -r ... -b 1-1` calls fail with `error: Device not available.` The server logs `Remote closed the connection` + `Handler ended with Ok(())` but doesn't re-export the device. Manual recovery: kill and restart the emulator.

This is awkward for live recipe runs because every snapshot revert + reattach burns the one available session. Workable for now (one emulator per recipe run), but it makes the orchestrator's "long-running emulator + many short recipes" model from M14.5 not actually achievable in practice.

**Fix direction**: Make the USB/IP server idempotent — after a client disconnects, re-register the device into the server's exported-list and accept new connections.
