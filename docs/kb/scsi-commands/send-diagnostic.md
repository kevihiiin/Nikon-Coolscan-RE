# SEND DIAGNOSTIC (0x1D)

| Field | Value |
|-------|-------|
| **Status** | Complete |
| **Last Updated** | 2026-02-21 |
| **Phase** | 2 |
| **Confidence** | High |

## Overview

Standard SCSI SEND DIAGNOSTIC command. Requests the scanner to perform a self-test
diagnostic. The CDB sets the SelfTest bit (byte 1 bit 2), telling the scanner to run
its internal diagnostic routine and report pass/fail via the returned status.

Self-test on a scanner typically verifies:
- CCD sensor functionality
- Lamp/LED operation
- Motor movement
- Internal memory integrity
- Communication path health

## CDB Layout (6 bytes)

| Byte | Field | Value | Notes |
|------|-------|-------|-------|
| 0 | Opcode | `0x1D` | SEND DIAGNOSTIC |
| 1 | Flags | `0x04` | SelfTest=1 (bit 2) |
| 2 | Reserved | `0x00` | |
| 3 | Parameter List Length [MSB] | `0x00` | No additional parameter data |
| 4 | Parameter List Length [LSB] | `0x00` | |
| 5 | Control | `0x00` | |

### Flag Byte (Byte 1) Detail

| Bit | Name | Value | Meaning |
|-----|------|-------|---------|
| 7 | PF | 0 | Page Format — not used when SelfTest=1 |
| 4 | DevOfL | 0 | Device Offline — 0 = don't allow offline tests |
| 3 | UnitOfL | 0 | Unit Offline — 0 = don't allow unit offline tests |
| 2 | SelfTest | 1 | **Self Test: run internal diagnostics** |
| 1-0 | Self Test Code | 00 | Default self-test |

When SelfTest=1 and Self Test Code=00, the device performs its default self-test
and returns Good status on success, or Check Condition on failure.

## Data Phase

**None** when SelfTest=1 with no parameter list. The scanner performs the self-test
internally and reports the result via status.

If the self-test fails, the host should issue REQUEST SENSE to get detailed failure
information.

## Response Interpretation

| Status | Meaning |
|--------|---------|
| Good (0x00) | Self-test passed — scanner hardware is functional |
| Check Condition (0x02) | Self-test failed — issue REQUEST SENSE for details |

## Usage Context

- Called during scanner initialization to verify hardware health
- May be called on user request (e.g., "diagnose scanner" in NikonScan UI)
- Useful for detecting hardware failures before attempting a scan
- May take several seconds to complete as the scanner exercises its subsystems
- Possible initialization sequence:
  `TEST UNIT READY` -> `INQUIRY` -> **`SEND DIAGNOSTIC`** -> `MODE SENSE` -> (begin)

## Open Questions

- How long does the self-test take on the Coolscan V?
- What subsystems are tested (lamp, motor, CCD, memory)?
- What sense data is returned on failure?
- Is RECEIVE DIAGNOSTIC RESULTS (0x1C) used to get detailed results?

## Source References

| Source | Location | Notes |
|--------|----------|-------|
| LS5000.md3 | `0x100aa3a0` | CDB builder — sets opcode 0x1D, byte1=0x04 (SelfTest=1) |

## Cross-References

- [TEST UNIT READY](test-unit-ready.md) — simpler readiness check (no self-test)
- [SCSI Command Build Infrastructure](../components/ls5000-md3/scsi-command-build.md) — CDB builder vtable system
- [NKDUSCAN API](../components/nkduscan/api.md) — USB transport that sends this CDB
- [USB Protocol](../architecture/usb-protocol.md) — transport layer details
