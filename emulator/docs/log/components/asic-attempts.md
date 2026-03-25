# ASIC Development Log

---

## 2026-03-16 — Initial Implementation

**Register model:**
- Master enable: write 0x80 to 0x200001 → ASIC powers on
- Ready flag: 0x200041 bit 1 → set immediately on master enable (warm-boot simulation)
- DMA busy: 0x200002 bit 3 → always 0 (no DMA in progress)
- CCD trigger: 0x2001C1 → accepted, no side effects yet
- ASIC RAM: 224KB at 0x800000-0x837FFF (filled with 0x00)

**Warm-boot decision:**
- Cold boot requires ASIC hardware handshake that has no software-visible exit condition
- Warm boot: set ready flag immediately → firmware skips HW handshake
- This is the correct approach for emulation — real hardware would have ASIC ready after power-on

## 2026-03-17 — USB Bus Reset Handler References

**From KB analysis**: USB bus reset handler at 0x013A20 writes to ASIC:
1. Clears 0x200001 value 0x02 (specific ASIC function TBD)
2. Writes 0x20 to 0x2000C2 (ASIC DMA or buffer config)

These ASIC interactions are not yet modeled — currently accepted as no-op writes.
Should not affect functionality until actual scan operations are attempted.

---

## 2026-03-25 — Phase 9: CCD Data Injection + DMA Completion Rewrite

**Goal**: Model CCD pixel capture and ASIC DMA completion for the scan pipeline.

**Changes**:
- CCD trigger at 0x2001C1 now generates actual pixel data (was just setting a flag)
- Pixel format: 14-bit CCD data in bits [15:2] of 16-bit words, big-endian
- CcdSource enum: Pattern (gradient varying by position+line) or MidGray (fixed 0x2000)
- DAC mode 0xA2 (calibration): produces low-value dark frame data
- DMA busy countdown changed from fixed 50 to transfer-size-based (1 tick per 16 bytes)
- tick() now returns bool indicating DMA completion
- New fields: dma_complete_pending, ccd_source, line_counter, last_line_data
- take_ccd_trigger() and take_dma_complete() for clean interrupt flag handling
- Orchestrator writes pixel data to ASIC RAM on DMA completion

**Tests**: 8 ASIC unit tests (up from 5), covering CCD trigger data generation,
DMA completion pending, line counter, transfer-size-based countdown.

**Result**: SUCCESS. All scan pipeline tests pass. ASIC model now generates realistic
CCD pixel data that can be processed by firmware's pixel processing code at 0x36C90.
