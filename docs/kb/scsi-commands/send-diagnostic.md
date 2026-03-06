# SEND DIAGNOSTIC (0x1D)

| Field | Value |
|-------|-------|
| **Status** | Complete |
| **Last Updated** | 2026-03-06 |
| **Phase** | 2 + 4 |
| **Confidence** | Verified (cross-validated host ↔ firmware) |

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

## Firmware Handler (Phase 4)

**Handler address**: `FW:0x023D32` | **Size**: ~478 bytes | **Exec mode**: 0x02 (data-out) | **Perm flags**: 0x0016

The handler supports more than just self-test. Permission flags (0x0016) require the scanner to be initialized; exec mode 0x02 = data-out, so the handler can accept diagnostic parameter data.

### State-Dependent Behavior

NikonScan always sends SelfTest=1 (byte[1]=0x04), but the firmware's action depends on the scanner's **current state**, not just CDB parameters. SEND DIAGNOSTIC appears in nearly every scan workflow phase (init, pre-scan, post-scan, focus, eject) — each time with the same CDB, but the firmware performs a different operation based on internal state:
- During init: runs hardware self-test
- Before scan: performs pre-scan calibration
- After scan: cleanup/lamp-off
- Eject: motor control for film transport

### Diagnostic Page Codes (PF=1 path)

When SelfTest=0 and PF=1, the parameter list data is dispatched by page code:

| Page Code | Direction | Purpose | Notes |
|-----------|-----------|---------|-------|
| 0x05 | SEND + RECEIVE | Standard diagnostic results | SCSI standard page |
| 0x06 | SEND + RECEIVE | Standard diagnostic page | SCSI standard |
| 0x38 | SEND + RECEIVE | Vendor-specific diagnostic | Nikon scanner-specific operations |

The host-side builder always sets SelfTest=1, so these pages may only be accessible via diagnostic tools, not through NikonScan's normal operation.

## RECEIVE DIAGNOSTIC (0x1C) — Companion Command

**Handler address**: `FW:0x023856` | **Size**: ~1244 bytes | **Exec mode**: 0x03 (data-in) | **Perm flags**: 0x0014

### CDB Layout (6 bytes)

| Byte | Field | Value | Notes |
|------|-------|-------|-------|
| 0 | Opcode | `0x1C` | RECEIVE DIAGNOSTIC RESULTS |
| 1 | Reserved | `0x00` | |
| 2 | Page Code | varies | 0x05, 0x06, or 0x38 |
| 3 | Allocation Length [MSB] | varies | Max bytes to return |
| 4 | Allocation Length [LSB] | varies | |
| 5 | Control | `0x00` | |

### Description

The companion handler for reading diagnostic results. Larger than SEND DIAGNOSTIC (1244 vs 478 bytes) because it formats and sends response data back to the host. Supports the same page codes (0x05, 0x06, 0x38).

The handler also checks scanner state values 0x80FB/0x80FC before processing — these correspond to eject and film-advance in-progress states. If the scanner is in one of these states, the handler returns state-specific diagnostic information rather than the standard page content.

### Data Phase

**Direction**: Data-in (scanner -> host). Returns diagnostic page data as requested by the page code in CDB[2].

### Host Usage

LS5000.md3 has a CDB builder for RECEIVE DIAGNOSTIC at `0x100aa320`. NikonScan uses it to read back results after SEND DIAGNOSTIC, particularly during calibration sequences and self-test operations.

### Sense Codes

| Sense Index | ASC/ASCQ | Condition |
|-------------|----------|-----------|
| 0x4E | 1A/00 | Parameter list length error |
| 0x50 | 24/00 | Invalid field in CDB |
| 0x53 | 26/00 | Invalid field in parameter list |

See [Sense Code Catalog](sense-codes.md) for full details.

## Source References

| Source | Location | Notes |
|--------|----------|-------|
| LS5000.md3 | `0x100aa3a0` | CDB builder — sets opcode 0x1D, byte1=0x04 (SelfTest=1) |

## Cross-References

- [TEST UNIT READY](test-unit-ready.md) — simpler readiness check (no self-test)
- [SCSI Command Build Infrastructure](../components/ls5000-md3/scsi-command-build.md) — CDB builder vtable system
- [NKDUSCAN API](../components/nkduscan/api.md) — USB transport that sends this CDB
- [USB Protocol](../architecture/usb-protocol.md) — transport layer details
