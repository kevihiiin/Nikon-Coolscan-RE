# Phase 3: USB — Attempt Log

**Status**: COMPLETE — TUR response via TCP verified, USB gadget bridge implemented

---

## 2026-03-17 — USB Init Sequence Analysis (from KB explorer)

**Critical finding**: firmware main loop at 0x0207F2 calls three init functions:
1. JSR @0x010D22 — shared module init (interrupts, timers)
2. JSR @0x01233A — USB configure with timeout (param: 50)
3. JSR @0x0126EE — enable USB endpoints

**Warm-boot flag**: 0x400772 = 0x01 triggers alternate context entry at 0x10C46.

**USB Bus Reset Handler** at 0x013A20:
1. Clears ASIC 0x200001 (value 0x02)
2. Initializes timer at 0x4007D6
3. Clears all USB state (0x407Dxx block)
4. Installs ISP1581 endpoint callback table from flash to RAM at 0x400DC8
5. Calls ISP1581 endpoint config (0x015280)
6. Writes 0x20 to ASIC 0x2000C2

**USB state block**: 0x407D00-0x407DFF must be zeroed for clean start.
**Key state variables**:
- 0x407DC7: USB session state (2=ready)
- 0x407DC3: USB connection state
- 0x400082: cmd_pending
- 0x4007B0: sense code (2 bytes)
- 0x4007DE: CDB buffer (16 bytes)
- 0x40049C: transfer phase
- 0x40049D: command completion counter

**Context switch crash at ~2.78M**: caused by warm-boot context system not
being fully initialized. The firmware at 0x010874 (RTE) pops garbage because
the saved SP in the context save area points to zeroed RAM.

**Root cause**: our warm-boot path skips 0x0207F2 main loop init, so the
firmware never calls USB configure or endpoint enable. The SCSI dispatcher
at 0x020AE2 is part of the main loop that starts AFTER 0x0207F2.

**Solution path**: either (a) let firmware reach 0x0207F2 (requires fixing
context switch to not crash), or (b) pre-initialize all USB state and
jump directly to the polling loop portion of the main loop.

## 2026-03-17 — ISP1581 Peripheral Model Implementation

**Target**: Full ISP1581 register model for firmware USB interaction

**Implemented registers:**
- Mode (0x0C): SOFTCT bit for USB connected signal, CLKAON, GOSUSP, SNDRSU
- IntConfig (0x10): INT level/polarity config
- IntEnable (0x14): Interrupt enable mask
- DcAddress (0x00): USB device address (7 bits)
- DcEndpointIndex (0x22): Endpoint select for config
- DcEndpointType (0x08): Endpoint type and enable
- DcMaxPacketSize (0x04): Endpoint max packet size
- DcBufferStatus (0x1E): FIFO fill state
- DcInterrupt (0x18): IRQ status with write-back-clear semantics
- EP data port (0x20): FIFO read/write access per selected endpoint

**FIFO model:**
- EP1 OUT and EP2 IN each have VecDeque<u8> FIFO
- Write to EP data port enqueues bytes
- Read from EP data port dequeues bytes
- BufferStatus tracks non-empty state per endpoint

**MmioDevice trait**: read_word(offset) / write_word(offset, value) for 16-bit LE bus.
ISP1581 bus at H8/300H address 0x600000; offset = (addr - 0x600000).

**Result**: Firmware can read/write ISP1581 registers. Mode.SOFTCT=1 signals connected.

## 2026-03-17 — TCP Bridge Implementation

**Target**: External SCSI command injection over TCP

**Architecture:**
- Non-blocking TCP server on port 5050
- Frame protocol: [type:1][length:2 big-endian][payload:N]
- Checked every 10,000 instructions in orchestrator main loop

**Frame types:**
| Type | Direction | Payload | Purpose |
|------|-----------|---------|---------|
| 0x01 | client→emu | 6-16 byte CDB | Inject SCSI command |
| 0x02 | client→emu | (empty) | Query transfer phase |
| 0x03 | client→emu | (empty) | Query sense data |
| 0x81 | emu→client | "OK" | CDB inject acknowledgement |
| 0x82 | emu→client | 1 byte phase | Phase response |
| 0x83 | emu→client | 2 bytes sense | Sense response |

**CDB injection (direct RAM):**
- Writes CDB bytes to firmware buffer at 0x4007DE
- Sets cmd_pending flag at 0x400082 = 0x01
- Firmware SCSI dispatcher at 0x020AE2 polls cmd_pending each main loop iteration
- **Bypasses ISP1581 entirely** — no USB transport needed for testing

**Python test client**: emulator/scripts/tcp_test_client.py
- Sends TUR (Test Unit Ready): CDB 00 00 00 00 00 00
- Queries phase and sense after injection
- Frame encoding/decoding helpers

**Result**: Bridge functional — CDB injection confirmed by reading back from RAM.
However, firmware never reaches SCSI dispatcher due to context switch crash.

## 2026-03-17 — USB Fast-Path Bypass

**Problem**: Firmware copies 414 bytes from flash 0x124BA to RAM 0x4010A0 (USB fast-path code).
This code at 0x4011C2 polls bit 7 of @0x063621 (flash address 0x063621 = erased, always 0xFF).
The poll loop never exits.

**Attempts:**
1. JIT copy 414 bytes to RAM before firmware does → FAILED: firmware overwrites during init
2. Memory watchpoint to catch corruption → showed firmware's own init writes to same RAM area
3. NOP the calling JSRs at flash 0x012EC6 and 0x012ECE → SUCCESS

**Fix applied**: Two 6-byte JSR instructions replaced with 3× NOP each:
```
bus.write_word(0x012EC6, 0x0000); // NOP
bus.write_word(0x012EC8, 0x0000); // NOP
bus.write_word(0x012ECA, 0x0000); // NOP
bus.write_word(0x012ECE, 0x0000); // NOP
bus.write_word(0x012ED0, 0x0000); // NOP
bus.write_word(0x012ED2, 0x0000); // NOP
```

**Result**: Firmware progresses past USB fast-path code. Execution continues to ~2.78M instructions.

## 2026-03-17 — ITU4 Register Base Fix

**Problem**: Timer model had ITU4 at offset 0x8C (immediately after ITU3 at 0x82).
H8/3003 has a gap: ITU3 ends at 0x8B, addresses 0x8C-0x91 are unmapped, ITU4 starts at 0x92.

**Symptom**: Firmware writes to TSR4 at physical 0xFFFF95 (offset 0x95 = ITU4 base 0x92 + 3).
Timer model expected TSR4 at offset 0x8F (wrong base 0x8C + 3). Flag clear never reached model.
Result: compare-match interrupt flag never clears → interrupt fires continuously.

**Fix**: Changed ITU4 base in TWO locations:
1. `peripherals/src/itu.rs` timer_index_and_reg(): `0x8C..=0x95` → `0x92..=0x9B`
2. `coolscan-emu/src/orchestrator.rs` ITU_BASES: `[0x64, 0x6E, 0x78, 0x82, 0x8C]` → `[0x64, 0x6E, 0x78, 0x82, 0x92]`

**Verification**: ITU4 system tick interrupts now fire and clear correctly. Timer-driven
cooperative scheduling resumes working.

## 2026-03-17 — Context Switch Crash (UNRESOLVED)

**Problem**: At instruction ~2,784,650, context switch handler RTE at 0x010874 pops garbage.

**Crash state:**
- SP = 0x00410002 (past Context A stack top of 0x410000)
- All ER0-ER6 = 0x00000000
- CCR = 0x02 (not a valid restored CCR — suggests popping from zeroed RAM)
- PC goes to 0xF20000 (unmapped) → halt

**Analysis:**
- Context switch handler at 0x010876 is structurally correct (verified against KB)
- Frame size: 28 bytes (7 regs) + 6 bytes (CCR+PC from RTE) = 34 bytes per context frame
- Context save area: 0x400764 (index), 0x400766 (A SP), 0x40076A (B SP)

**JIT Context B init:**
- ctx_b_sp = 0x40D000, frame at 0x40CFDE (34 bytes below SP)
- Fake frame: ER0-ER6=0, CCR=0, PC=0x029B16 (Context B entry from KB)
- Saved to 0x40076A

**Root cause hypotheses:**
1. Context B entry (0x029B16) runs into uninitialized state and corrupts context save area
2. An interrupt fires during context switch and double-pushes the stack
3. The warm-boot flag at 0x400772 is not set → firmware takes wrong init branch
4. Stack overflow in one context overwrites the other context's save area

**KB finding**: Main loop at 0x0207F2 calls three init functions before SCSI dispatch.
Without these, USB state and context scheduling are not properly configured.

**Recommended next step**: Add instruction trace at ~2,784,600 to observe the exact
failure mechanism — which context switch goes wrong and what stack data it reads.

## 2026-03-17 — Exception Frame Fix (RESOLVED)

**Root cause**: H8/300H Advanced Mode uses 4-byte packed exception frames,
not 6-byte separate CCR+PC frames.

**H8/300H Programming Manual p.159, section 2.2.51 RTE**:
The Advanced Mode stack diagram shows CCR and PC packed into one longword:
```
[byte 0] CCR (8 bits)
[byte 1] PC bits 23:16
[byte 2] PC bits 15:8
[byte 3] PC bits 7:0
```

**Our bug**: TRAPA pushed 6 bytes (CCR as word, PC as long), RTE popped 6 bytes.
Firmware's context init at 0x0107EC correctly built 32-byte frames (7×4 regs + 4 packed).
Our RTE tried to pop 34 bytes from a 32-byte frame → read 2 bytes past the frame.

**For entry_point 0x000207F2 at stack_top 0x410000**:
- Stored at 0x40FFFC as packed long: 00 02 07 F2
- Our (wrong) RTE read: CCR=0x0002 (word), PC from 0x40FFFE = 0x07F20000
- Masked to 24 bits: PC=0xF20000 → unmapped → crash

**Fix**:
- execute.rs: `TRAPA` pushes `(CCR<<24)|PC` as 4-byte long; `RTE` unpacks
- interrupt.rs: same 4-byte packed frame for hardware interrupts
- orchestrator.rs: JIT Context B frame: 34→32 bytes

**Context init templates found** in firmware flash at 0x0107CC:
| Template | Flag | Context A Entry | Context B Entry |
|----------|------|----------------|----------------|
| 0x0107CC | =0   | 0x0207F2 (main loop) | 0x029B16 |
| 0x0107DC | ≠0   | 0x010C46 (warm entry) | 0x029B16 |

**Result**: firmware reaches 0x0207F2 (Context A main loop) at instruction 2,783,761.
Stable to 5M+ instructions. PC at 5M = 0x0109E4 (scheduler area).
