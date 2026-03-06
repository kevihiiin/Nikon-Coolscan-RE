# Phase 5: Protocol Specification
<!-- STATUS HEADER - editable -->
**Status**: Complete
**Started**: 2026-02-28  |  **Completed**: 2026-02-28
**Completion**: 7/7 criteria met
---
<!-- ENTRIES BELOW - APPEND ONLY -->

## 2026-02-28 — Session 9: Phase 5 Start

### Criteria Progress
- [x] **Criterion 1**: Every SCSI command has complete spec — All 18 command docs have CDB layout, data phase, parameter semantics, firmware handler sections, and sense code cross-references
- [x] **Criterion 2**: Host-side and device-side cross-validated — All 4 vendor commands cross-validated (no contradictions). Standard commands verified via dispatch table. Fixed 4 stale vendor-specific/nikon-*.md docs (had wrong E0/E1 direction). Fixed opcode count error in scsi-handler.md.
- [x] **Criterion 3**: Vendor-specific commands documented with same rigor — C0 (status query, abort flag checker), C1 (trigger dispatcher, 23 subcommands), E0 (data-out, 23 registers, resolution calc), E1 (data-in, mirror of E0). All verified from both host and firmware.
- [x] **Criterion 4**: Sense code catalog complete — Created sense-codes.md: 148-entry translation table at FW:0x16DEE, 64 actively-used codes across 8 sense keys, FRU byte encoding scheme, cross-referenced with host-side MAID error handling.
- [x] **Criterion 5**: USB wrapping protocol spec implementation-ready — usb-protocol.md updated to Complete. Covers: CDB transport, phase query (0xD0), sense retrieval (0x06), chunked data transfer, extended CDB path, command parameter structure.
- [x] **Criterion 6**: Complete scan workflow sequences documented — scan-workflows.md has 6 workflow types with SCSI command sequences: Init(7), MainScan(3), SimpleScan(1+7), Focus(5+vendor), Advanced(4), Eject(via SEND_DIAG). Individual command docs provide byte-level CDB layout.
- [x] **Criterion 7**: Protocol spec reviewed for internal consistency — Full systematic review completed. Checked: all 17 handler addresses match between dispatch table and individual docs, all 18 CDB builder addresses consistent, all exec modes consistent, all sense code cross-references verified, broken link in sense-codes.md fixed, handler count corrected (21), C0 direction resolved, RELEASE contradiction fixed, sense naming clarified with actual SK/ASC/ASCQ values, missing sense index 0x71 added to catalog.

### Completed
- Created docs/kb/scsi-commands/sense-codes.md (148 entries, 64 active, comprehensive)
- Cross-validated 4 vendor commands between host and firmware (all consistent)
- Replaced 4 stale vendor-specific/nikon-*.md with redirect stubs
- Fixed opcode count in scsi-handler.md (19 listed as 17 → corrected to actual 17 LS5000.md3 opcodes)
- Updated usb-protocol.md status to Complete
- Added firmware handler sections to 7 SCSI command docs (get-window, send-diagnostic, reserve, write, read-buffer, write-buffer, + sense code xrefs)
- All 18 SCSI command docs now have firmware handler information
- Logged attempt 26 to firmware-attempts.md

## 2026-02-28 — Session 10: READ/WRITE Data Type Code Tables

### Criteria Progress
- [x] **Criterion 1**: Every SCSI command has complete spec — READ and WRITE commands now have COMPLETE Data Type Code tables (15 READ DTCs, 7 WRITE DTCs) extracted from firmware dispatch tables and cross-validated with host-side and SANE. No more TBD values.

### Completed
- **Extracted complete READ DTC table** from firmware dispatch table at 0x49AD8:
  - 15 DTCs: 0x00 (Image), 0x03 (Gamma/LUT), 0x81 (Film Frame), 0x84 (Calibration), 0x87 (Scan Params), 0x88 (Boundary), 0x8A (Exposure), 0x8C (Offset), 0x8D (Extended Line), 0x8E (Focus), 0x8F (Histogram), 0x90 (CCD), 0x92 (Motor), 0x93 (Adapter), 0xE0 (Extended Config)
  - Table structure: 12-byte entries with DTC, category, max size, RAM pointer
- **Extracted complete WRITE DTC table** from firmware dispatch table at 0x49B98:
  - 7 DTCs: 0x03, 0x84, 0x85, 0x88, 0x8F, 0x92, 0xE0
  - DTC 0x85 is WRITE-only (no READ counterpart)
  - Table structure: 10-byte entries
- **Decoded qualifier category system**: 5 categories (0x00, 0x01, 0x03, 0x10, 0x30) controlling CDB[5] validation
- **Cross-validated** with 3 independent sources:
  - Firmware dispatch tables (ground truth)
  - LS5000.md3 factory callsites (host-side)
  - SANE coolscan3 backend (independent implementation)
- **Updated read.md**: replaced TBD Data Type Code section with complete 15-entry table
- **Updated write.md**: replaced TBD section with 7-entry table, added dispatch chain, DTC-specific data phase docs, key differences from READ
- **Logged**: firmware-attempts.md (attempt 27), ls5000-md3-attempts.md (attempt 8)

## 2026-02-28 — Session 11: Internal Consistency Review (Criterion 7)

### Systematic Review Results

Performed comprehensive cross-validation of all 49 KB docs:

**Handler Addresses**: All 17 firmware handler addresses match perfectly between scsi-handler.md dispatch table and individual command docs. No discrepancies.

**CDB Builder Addresses**: All 18 builder addresses (plus 2 factory addresses) match perfectly between scsi-command-build.md catalog and individual command docs.

**Exec Modes**: All 17 exec mode values consistent between dispatch table and individual docs. Clarified SCAN's exec mode 0x00 (direct call with internal data-out handling).

**Cross-Reference Links**: All links validated. Fixed 1 broken link in sense-codes.md (`scsi-dispatch.md` → `scsi-handler.md`).

### Discrepancies Found and Fixed

1. **Broken link**: sense-codes.md linked to non-existent `scsi-dispatch.md` → fixed to `scsi-handler.md`
2. **Handler count**: scsi-handler.md said "20 entries" but table has 21 → fixed to 21
3. **RELEASE contradiction**: reserve.md said "LS5000.md3 also has a builder for RELEASE" but binary search confirmed NO such builder exists → fixed reserve.md
4. **C0 direction**: vendor-c0.md overview said "Unknown" despite firmware section saying "None" → fixed to "None (confirmed)"
5. **C0 references in vendor-c1.md and scsi-command-build.md**: still said "direction unknown" → fixed
6. **Sense naming mismatch**: scsi-handler.md used conceptual names (HARDWARE ERROR, COMMUNICATION FAILURE) that didn't match actual SK/ASC/ASCQ → replaced with actual sense data + scanner condition descriptions
7. **Missing sense index**: 0x71 (scan timeout, SK=2 04/02) was used by TUR but missing from sense-codes.md → added
8. **Sense count**: Updated from 64→65 actively used entries
9. **SCAN data direction**: Dispatch table "None" was misleading → added asterisk and clarified in exec mode table
10. **E0/E1 summary TBDs**: Replaced generic TBD labels with actual sub-command values from firmware register table
11. **Open Questions**: Updated system-overview.md (all 4 questions now RESOLVED with cross-refs to firmware docs), software-layers.md (3 of 4 resolved), mode-select.md (all resolved)
12. **system-overview.md status**: Updated from Draft → Complete, ASIC RAM from "unverified 256KB" → verified 224KB

### Post-Review State

- **Zero TBDs** remaining across all KB docs
- **Zero Draft** KB docs remaining
- **Zero In Progress** KB docs remaining
- All Open Questions sections marked as RESOLVED (except 1 low-priority NikonScan "Revelation" question)
- All cross-reference links valid
- All handler addresses, builder addresses, exec modes, and sense codes internally consistent

## 2026-03-06 — Session 12: Protocol Spec Documentation Improvements

### Updates
Following a comprehensive firmware audit, several SCSI command KB docs were expanded:

1. **RECEIVE DIAGNOSTIC (0x1C)**: Elevated from brief mention in send-diagnostic.md to a full section with CDB layout, data phase, handler details, and host usage notes.
2. **RELEASE (0x17)**: Elevated from brief mention in reserve.md to a full section with CDB layout, permission analysis, and driver implementation note.
3. **INQUIRY VPD table**: Expanded from 7 to 8 adapter entries with handler addresses. Added "Test" factory adapter (zero VPD pages).
4. **Film Adapters KB doc**: Created docs/kb/components/firmware/film-adapters.md documenting all 8 adapter types, VPD handler dispatch, film holders, positioning objects, and calibration parameter names.

No new criteria — Phase 5 was already 7/7 complete. These are documentation quality improvements.
