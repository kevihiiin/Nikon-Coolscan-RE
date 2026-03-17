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
