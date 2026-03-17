# Phase 2: Interrupts — Attempt Log

**Status**: Complete — all interrupt infrastructure working, context switches operational

---

## 2026-03-16 — Timer Interrupt Infrastructure

### I/O routing fix
- On-chip I/O registers (0xFFFF00-0xFFFFFF) stored in flat 256-byte array in bus
- Peripheral models (ITU timers, GPIO) were separate from bus array
- Problem: firmware writes to timer registers went to bus array but timer model never saw them
- Fix: added timer register sync — orchestrator copies bus→model and model→bus each tick

### Timer register sync:
- TSTR (0xFFFF60): timer start/stop bits
- TCR (per-timer): clock source and prescaler
- TIER (per-timer): interrupt enable
- GRA/GRB (per-timer): compare-match values
- TCNT (per-timer): current count
- TSR (per-timer): interrupt flags

### TSR sync direction bug:
- Initial impl: copied model TSR → bus (overwrote firmware's flag-clear writes)
- Fix: sync bus TSR → model (firmware clears flags by writing 0 bits)
- Model generates new flags on compare-match; firmware clears them by writing to bus

### Port 7 / ITU4 TIER conflict at 0xFFFF8E:
- Port 7 GPIO data register and ITU4 TIER both map to 0xFFFF8E
- Fix: Port 7 uses dedicated `port7_override: Option<u8>` field instead of bus array
- GPIO reads check port7_override first, fall back to adapter-type default

### ITU4 pre-configuration (JIT):
- TCR=0xA3 (φ/8 prescaler, compare-match A clear)
- GRA=0x2000 (32K cycles between ticks — reasonable system tick rate)
- TIER=0x01 (compare-match A interrupt enabled)
- TSTR bit 4 set by firmware at 0x010A10 (BSET #4, @0x60:8)

### Result:
- ITU4 system tick interrupts fire at Vec 40 → trampoline 0xFFFD24 → ISR 0x010A16
- Timer-driven cooperative scheduling works
- Both contexts receive regular timer interrupts

## 2026-03-17 — ITU4 Register Base Correction

**Critical bug**: ITU4 register base was 0x8C, should be 0x92.
See phase-3-usb.md for details. Fixed in both itu.rs and orchestrator.rs.

## Completion Status
- [x] Timer compare-match interrupts (ITU2, ITU3, ITU4)
- [x] Context switch via TRAPA #0 (Vec 8)
- [x] IRQ1 USB interrupt routing (Vec 13)
- [x] IRQ3 encoder interrupt routing (Vec 15)
- [x] Trampoline dispatch (on-chip RAM → handler)
- [x] Interrupt priority and masking (CCR.I flag)
- [x] Firmware stable at 50M+ instructions with interrupts enabled
