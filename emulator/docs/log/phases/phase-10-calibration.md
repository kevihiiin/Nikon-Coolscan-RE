# Phase 10: Calibration & Full Fidelity — Attempt Log

**Status**: COMPLETE (230 tests)
**Milestone**: Dark frame, white reference, calibration tasks, model config
**Depends**: Phase 8 (motor), Phase 9 (CCD pipeline)

---

## Session 1 — 2026-03-25 (Phase 10 Implementation)

### 10.1 DAC Mode Gating
- Dark frame (0xA2, lamp off): 0x0020 + noise | White ref (0xA2, lamp on): 0x3F00 + noise
- Per-pixel PRNG for CCD non-uniformity. Lamp synced from GPIO.

### 10.2 CCD Characterization Data
- Flash 0x4A8BC-0x528BD verified readable and non-trivial.

### 10.3 Calibration Task Codes
- 0x0500-0x0502 via SEND DIAGNOSTIC → writes min/mid/max to 0x400F0A/12/1A.

### 10.4 Calibration RAM Defaults
- 0x400F56-0x400F9D pre-populated with 0x2000 mid-range defaults.

### 10.5 Model Config
- 0x404E96 model flag set from --model CLI (LS-5000 = 1).

### Completion: 5/5 criteria DONE ✓. 6 new tests. 230 total. Clippy clean.
