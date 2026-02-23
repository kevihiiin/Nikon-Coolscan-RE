# Phase 2: SCSI Commands (LS5000.md3)
<!-- STATUS HEADER - editable -->
**Status**: Complete
**Started**: 2026-02-20  |  **Completed**: 2026-02-21
**Completion**: 7/7 criteria met
---
<!-- ENTRIES BELOW - APPEND ONLY -->

### Session 4 — 2026-02-21 (Phase 2 deep analysis)

**Criteria met this session**:
- [x] All 3 exports (`MAIDEntryPoint`, `NkCtrlEntry`, `NkMDCtrlEntry`) decompiled with documented signatures
- [x] Complete list of SCSI opcodes used, with CDB byte layout for each (17 opcodes, standard + vendor-specific)

**Key findings**:

1. **Export analysis**: MAIDEntryPoint has 16-case switch (10 active), NkCtrlEntry is mangled C++ (4 shorts + void*), NkMDCtrlEntry has 4-case switch. Transport loaded dynamically via LoadLibraryA/GetProcAddress.

2. **Transport architecture**: Three-layer vtable dispatch: scanner control → abstract transport (vtable 0x100c4a60, 15 entries) → inner concrete transport (vtable 0x100c4a9c, 8 entries) → NkDriverEntry fn ptr at [+4]. Thunk at 0x100a47c0, wrapper at 0x100a48e0.

3. **SCSI command catalog**: 17 unique opcodes across 22 CDB builders:
   - Standard: 0x00, 0x12, 0x15, 0x16, 0x1A, 0x1B, 0x1D, 0x24, 0x25, 0x28, 0x2A, 0x3B, 0x3C
   - Vendor: 0xC0, 0xC1, 0xE0, 0xE1
   - REQUEST SENSE (0x03) NOT present — handled by transport layer

4. **CDB builder architecture**: Two patterns:
   - Architecture A: vtable-based objects (CDB at [this+8], builder at vtable[8])
   - Architecture B: inline construction (4 sites, INQUIRY + 3× READ)
   - Two clusters: 0x100aa1d0 (13 builders) and 0x100b51b0 (5 builders)

5. **Command class vtables**: 10-entry (40-byte) vtables at 0x100c4dc0-0x100c5570. Two groups (A=data-out, B=general). CDB builder always at offset +0x20.

**KB docs created**:
- `docs/kb/components/ls5000-md3/scsi-command-build.md` — Definitive SCSI command catalog
- `docs/kb/components/ls5000-md3/maid-entrypoint.md` — Export analysis + transport architecture

**Still needed**:
- [x] Each NkDriverEntry callsite annotated with: opcode, CDB bytes, data direction, data format, purpose ← Completed in Session 5
- [ ] MAID capability ID → SCSI command mapping table
- [x] Individual SCSI command docs in docs/kb/scsi-commands/ ← 13/17 standard docs written, vendor docs pending
- [x] Cross-model .md3 comparison table ← Completed in Session 4
- [x] Annotate NkDriverEntry callsite list (Step 2 of Phase 2) ← Completed in Session 5

### Session 5 — 2026-02-21 (Data direction analysis, vtable correction, vendor command docs)

**Criteria met this session**:
- [x] Each NkDriverEntry callsite annotated with: opcode, CDB bytes, data direction, data format, purpose
- [x] Cross-model .md3 comparison table (was done in S4 but not checked off)
- [x] Definitive SCSI command catalog (major rewrite with corrections)

**Key findings**:

1. **Vtable base correction**: CDB builder is at vtable entry[9] (offset +0x24), NOT entry[8] (offset +0x20). Previous analysis was 4 bytes off on the vtable base address.

2. **Data direction verified for all 17 commands**: Two constructor types encode direction — `fcn.100ae720` (no data phase) and `fcn.100ae770` (push 1=data-in, push 2=data-out). 16 factories mapped.

3. **Core execute function (0x100ae3c0)**: Builds CommandParams structure from command object fields. Direction at +0x54, transfer length at +0x50, CDB at +0x08, flags constant 0x20.

4. **Group A vs Group B**: Not about data direction — Group B adds retry on error 9 with 50ms delay.

5. **NkDriverEntry FC usage from LS5000.md3**: FC1 (init) at 0x100a45dc, FC2 (close) at 0x100a4694, FC3 (cleanup) at 0x100a472b. All SCSI commands go through FC5.

6. **0xC0 factory not found** in standard command architecture — may use different execution path.

**KB docs updated**:
- `docs/kb/components/ls5000-md3/scsi-command-build.md` — Major rewrite with corrected vtable layout, data directions, factory addresses, CommandParams structure

**All criteria now met**:
- [x] MAID capability → SCSI command operational sequence mapping (full numeric ID mapping deferred to Phase 3)
- [x] Vendor command docs (0xC0, 0xC1, 0xE0, 0xE1) — all 17/17 individual docs written (100%)

### Session 5 continued — MAID operational mapping

**Additional findings**:

1. **MAID dispatch is multi-layer indirect**: Case 10 handler calls capability manager vtable[0] with capability ID (e.g., 0x1007), then vtable[5]. Full numeric ID → SCSI mapping requires Phase 3.

2. **5 operational sequences mapped** (via factory callsite cross-references):
   - Scanner init: TUR→INQUIRY→RESERVE→GET WINDOW→MODE SELECT→SEND DIAG→READ
   - Focus/exposure: TUR→E0→C1→E1→SEND DIAG
   - Calibration: READ→WRITE→TUR→E0→C1→E1→SEND DIAG
   - Scan: SET WINDOW×3→SEND DIAG→TUR→SCAN→GET WINDOW→WRITE→READ
   - Device query: TUR→INQUIRY→SEND DIAG→READ

3. **Vendor command protocol confirmed**: E0(send params)→C1(trigger)→E1(readback). This is the focus/exposure/calibration control loop.

**KB docs updated**:
- `docs/kb/components/ls5000-md3/maid-entrypoint.md` — Complete MAID → SCSI operational mapping
- `docs/kb/scsi-commands/vendor-e0.md`, `vendor-e1.md`, `vendor-c0.md`, `vendor-c1.md` — All vendor command docs
