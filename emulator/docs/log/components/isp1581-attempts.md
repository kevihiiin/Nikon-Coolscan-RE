# ISP1581 Development Log

---

## 2026-03-17 — Initial Implementation

**Target**: Model ISP1581 USB controller at H8/300H address 0x600000

### Register map implemented:
| Offset | Register | Bits/Notes |
|--------|----------|------------|
| 0x00 | DcAddress | 7-bit USB address |
| 0x04 | DcMaxPacketSize | Per-endpoint max packet |
| 0x08 | DcEndpointType | Type + enable per EP |
| 0x0C | Mode | SOFTCT, CLKAON, GOSUSP, SNDRSU |
| 0x10 | IntConfig | Level/polarity |
| 0x14 | IntEnable | Interrupt mask |
| 0x18 | DcInterrupt | Status, write-1-to-clear |
| 0x1E | DcBufferStatus | FIFO state per EP |
| 0x20 | DcData (EP data port) | FIFO R/W |
| 0x22 | DcEndpointIndex | Select EP for config |

### FIFO model:
- EP1 OUT: host→device (CDB + data-out), VecDeque<u8>
- EP2 IN: device→host (sense/data-in/phase), VecDeque<u8>
- Data port reads dequeue from selected EP, writes enqueue
- BufferStatus tracks non-empty state

### MmioDevice trait:
- `read_word(offset) -> u16`: register read, FIFO side effects on data port
- `write_word(offset, value)`: register write, write-1-clear on interrupt status
- ISP1581 uses 16-bit LE bus (H8/300H is 16-bit BE — byte swap handled in bus layer)

### Mode register init:
- SOFTCT=1 (bit 8 of Mode register) set at init → firmware sees USB as connected
- This prevents firmware from entering USB disconnect polling loops

### IRQ integration:
- `has_irq()` method checks DcInterrupt & IntEnable for active unmasked interrupts
- Orchestrator checks `isp1581.has_irq()` and queues Vec 13 (IRQ1) when active
- Firmware handler at 0x014E00 (trampoline 0xFFFD3C) services USB interrupts

### Convenience methods on bus:
- `isp1581_inject(data: &[u8])` — push bytes into EP1 OUT FIFO
- `isp1581_drain(max: usize) -> Vec<u8>` — pull bytes from EP2 IN FIFO
- `isp1581_has_response() -> bool` — check EP2 IN non-empty
- `isp1581_has_irq() -> bool` — check for pending interrupt

### Known limitation:
- Only EP1 OUT and EP2 IN modeled (the two endpoints used by Coolscan protocol)
- No USB state machine (enumeration, suspend, reset) — firmware handles via register polling
- No SOF counter or frame timing

## 2026-03-17 — Erased Flash Polling Bug

**Problem**: Firmware USB code at 0x4011C2 reads @0x063621 and tests bit 7.
Address 0x063621 is in the ISP1581 region (0x600000+) but offset 0x3621 is way
beyond the ISP1581 register space. In the real hardware this would be an ISP1581
internal register; in our model unmapped reads return 0x0000.

However, the code was FIRST copied from flash (0x124BA → 0x4010A0), and the
instruction uses absolute address 0x063621 which maps differently depending on
context. The actual problem is the firmware polls a register that would indicate
USB bus ready — we bypass the entire fast-path instead.

**Resolution**: NOP the calling JSRs rather than trying to model the register.
