# LS5000.md3 Analysis Log
<!-- STATUS HEADER - editable -->
**Binary**: binaries/software/NikonScan403_installed/Module_E/LS5000.md3 | **Functions identified**: 22+ CDB builders, 3 exports
---
<!-- ENTRIES BELOW - APPEND ONLY -->

## Attempt 1: Export Analysis — 2026-02-21
**Tool**: radare2 | **Target**: MAIDEntryPoint, NkCtrlEntry, NkMDCtrlEntry
**What I tried**: Analyzed all 3 exports, mapped MAIDEntryPoint 16-case switch table, NkMDCtrlEntry 4-case switch.
**What I found**:
- MAIDEntryPoint at RVA 0x298F0: 16-case switch at 0x10029b30, 10 active cases (0-4, 10-12, 14-15)
- NkCtrlEntry at RVA 0x9BDD0: mangled C++ name, takes 4 shorts + void*
- NkMDCtrlEntry at RVA 0xB120: 4-case switch (FC 1-4)
**Confidence**: High
**KB Updated**: docs/kb/components/ls5000-md3/maid-entrypoint.md

## Attempt 2: Transport Layer Loading — 2026-02-21
**Tool**: radare2 | **Target**: NkDriverEntry function pointer acquisition
**What I tried**: Traced how LS5000.md3 loads the transport DLL and acquires NkDriverEntry.
**What I found**:
- NO static import of NkDriverEntry — loaded via LoadLibraryA/GetProcAddress at runtime
- Transport loader at 0x100a44c0: builds path from own module directory
- "NkDriverEntry" string at 0x100c4a48, "Nkduscan.dll" at 0x100c4abc, "Nkdsbp2.dll" at 0x100c4acc
- Three-layer vtable dispatch: scanner obj → [+0x20] abstract transport (vtable 0x100c4a60) → [+0x20] inner concrete (vtable 0x100c4a9c) → [+4] NkDriverEntry fn ptr
- NkDriverEntry thunk at 0x100a47c0, wrapper at 0x100a48e0
- "1200" protocol version at 0x100c4a58
**Confidence**: High
**KB Updated**: docs/kb/components/ls5000-md3/maid-entrypoint.md

## Attempt 3: INQUIRY Command Flow — 2026-02-21
**Tool**: radare2 | **Target**: INQUIRY CDB construction and execution
**What I tried**: Traced complete INQUIRY command path from factory to execution.
**What I found**:
- INQUIRY CDB builder at 0x100a4870 (Architecture B: inline)
- INQUIRY command factory at 0x100a4de0: checks opcode==0x12, allocates 0x3C bytes, sets vtable 0x100c4ad8
- Full dispatch at 0x100a5030: creates cmd obj → vtable[1] builds CDB → vtable[2] gets params → push params, push 5, call [vtable+0x1c] → NkDriverEntry FC5
- Command class vtable at 0x100c4ad8 has 24 entries with transport interface inherited at offsets 0x24-0x30
**Confidence**: High

## Attempt 4: Systematic SCSI Opcode Search — 2026-02-21
**Tool**: radare2 byte pattern search | **Target**: ALL CDB construction sites
**What I tried**: Exhaustive byte pattern search for `mov byte [ecx+8], XX` (c64108XX) and `mov byte [reg], XX` patterns across all standard (0x00-0x3F) and vendor (0x80-0xFF) SCSI opcodes.
**What I found**:
- **17 unique SCSI opcodes** across **22 CDB builder sites**
- **Two architectures**: (A) vtable-based command objects with CDB at [this+8], (B) inline buffer writes
- **Cluster 1** (0x100aa1d0-0x100aa6d6): 13 builders for 6-byte + window + vendor cmds
- **Cluster 2** (0x100b51b0-0x100b52d0): 5 builders for READ/WRITE/BUFFER group
- **4 inline sites** (0x100a4870, 0x100866d9, 0x10086dfa, 0x1008781a)
- Standard opcodes: 0x00, 0x12, 0x15, 0x16, 0x1A, 0x1B, 0x1D, 0x24, 0x25, 0x28, 0x2A, 0x3B, 0x3C
- Vendor opcodes: 0xC0, 0xC1, 0xE0, 0xE1
- REQUEST SENSE (0x03) NOT present — handled by transport layer
**Confidence**: High
**KB Updated**: docs/kb/components/ls5000-md3/scsi-command-build.md

## Attempt 5: Command Class Vtable Mapping — 2026-02-21
**Tool**: radare2 | **Target**: Map ALL command class vtables
**What I tried**: Found transport interface pattern (0x100a47f0, 0x100a4590, 0x100a47c0, 0x100a47e0) in vtables. Then searched for CDB builder addresses as LE DWORDs to find their vtable locations.
**What I found**:
- Each command class has 10-entry (40-byte) vtable with CDB builder at entry[8] (offset +0x20)
- Two vtable groups: Group A (data-out) and Group B (general), differ in entries [3],[5],[6],[7]
- 14+ vtable blocks in range 0x100c4dc0-0x100c4fef (Cluster 1)
- 5+ vtable blocks in range 0x100c5490-0x100c5570 (Cluster 2)
- Complete vtable→opcode mapping for all 17 commands
- SEND DIAGNOSTIC (0x1D) appears in BOTH Group A and Group B vtables
- MODE SELECT(6) has two variants (v1 in Group A, v2 in Group B)
**Confidence**: High
**KB Updated**: docs/kb/components/ls5000-md3/scsi-command-build.md

## Attempt 6: Cross-Model .md3 Comparison — 2026-02-21
**Tool**: radare2, strings | **Target**: LS4000.md3, LS5000.md3, LS8000.md3, LS9000.md3
**What I tried**: Compared all 4 .md3 modules: exports, sizes, MAID versions, SCSI opcodes, transport DLL refs.
**What I found**:
- ALL 4 modules have IDENTICAL 3 exports with same mangled NkCtrlEntry
- ALL 4 use IDENTICAL 17 SCSI opcodes (18 CDB builders each)
- ALL reference BOTH Nkduscan.dll AND Nkdsbp2.dll — runtime transport selection!
- LS5000.md3 unique: MAID version "MD3.50" (others "MD3.01")
- Sizes: LS4000 824KB, LS5000 1028KB, LS8000 936KB, LS9000 1112KB
- "Plag and Play" typo in ALL 4 modules
**Confidence**: High
**KB Updated**: docs/kb/components/ls5000-md3/scsi-command-build.md

## Attempt 7: Data Direction Analysis & Vtable Correction — 2026-02-21
**Tool**: radare2 | **Target**: Command factories, core execute function, vtable base addresses
**What I tried**: Traced all 16 command factory functions to determine data direction encoding. Analyzed core execute function. Corrected vtable base offset error from Attempt 5.
**What I found**:
- **CRITICAL CORRECTION**: Vtable base was 4 bytes off. Factories set vtable at e.g. 0x100c4e34 (not 0x100c4e38). CDB builder is at vtable entry[9] (offset +0x24), NOT entry[8] (offset +0x20) as documented in Attempt 5.
- **Two constructor types**: `fcn.100ae720` (simple, 3 params) = no data phase, `fcn.100ae770` (full, 6+ params) = direction value pushed before call
- **Direction encoding**: push 1 = data-in (scanner→host), push 2 = data-out (host→scanner), no push = no data phase
- **16 factories mapped** with verified directions:
  - No data: TEST UNIT READY (0x00), RESERVE (0x16), SEND DIAGNOSTIC B (0x1D), VENDOR 0xC1
  - Data-in: INQUIRY (0x12), MODE SENSE (0x1A), GET WINDOW (0x25), READ(10) (0x28), READ BUFFER (0x3C), VENDOR 0xE1
  - Data-out: MODE SELECT v1/v2 (0x15), SCAN (0x1B), SEND DIAGNOSTIC A (0x1D), SET WINDOW (0x24), WRITE(10) (0x2A), WRITE BUFFER (0x3B), VENDOR 0xE0
- **Core execute (0x100ae3c0)**: Builds CommandParams struct from command object fields: data buffer (+0x1C), CDB ptr (+0x08), CDB length (+0x2C), transfer length (+0x50), direction (+0x54), flags (constant 0x20)
- **Group A vs Group B**: NOT about data direction — Group B (0x100ae8d0) adds retry on error 9 with 50ms delay; Group A (0x100ae630) executes directly
- **NkDriverEntry FC usage**: FC1 at 0x100a45dc (init), FC2 at 0x100a4694 (close), FC3 at 0x100a472b (cleanup). All SCSI commands go through FC5 via core execute.
- **0xC0 factory not found** in standard command architecture — may use different execution path
**Confidence**: High
**KB Updated**: docs/kb/components/ls5000-md3/scsi-command-build.md (major rewrite)

## Attempt 8: MAID Operation → SCSI Command Mapping — 2026-02-21
**Tool**: radare2 | **Target**: Cross-references from SCSI command factory functions to higher-level callers
**What I tried**: Used `axt` to find all callsites for each command factory function. Grouped callsites by containing function address to identify operational sequences. Traced the MAID dispatch architecture.
**What I found**:
- MAID handlers dispatch through capability objects with their own vtables — NOT direct SCSI calls
- Case 10 handler at 0x100275d0 calls vtable[0] with capability ID (e.g., 0x1007), then vtable[5] (offset +0x14)
- Full numeric capability ID mapping requires Phase 3 (TWAIN layer)
- BUT operational sequence mapping was achieved by grouping factory callsites:
  1. **Scanner init** (fcn.100af200, 942 bytes): TUR→INQUIRY→RESERVE→GET WINDOW→MODE SELECT→SEND DIAG→READ
  2. **Focus/exposure** (0x100b0400): TUR→E0(set)→C1(trigger)→E1(readback)→SEND DIAG
  3. **Calibration** (0x100b0d30): READ→WRITE→TUR→E0→C1→E1→SEND DIAG
  4. **Scan operation** (0x100b3c00-0x100b4c00): SET WINDOW×3→SEND DIAG→TUR→SCAN→GET WINDOW→WRITE→READ
  5. **Device query** (0x100b1800-0x100b2800): TUR→INQUIRY→SEND DIAG→READ→INQUIRY
- Confirmed vendor command flow: **E0 sends → C1 triggers → E1 reads back**
- SCAN factory called from exactly 1 site (0x100b42a4)
- TUR called from 10 sites, SEND DIAGNOSTIC from 9 sites — most frequent commands
**Confidence**: High (operational sequences), Medium (capability ID mapping)
**KB Updated**: docs/kb/components/ls5000-md3/maid-entrypoint.md (MAID → SCSI mapping added)

## Attempt 8 — 2026-02-28 — READ/WRITE factory DTC callsite analysis
**Tool**: r2 disassembly (PE-aware loading) + manual stack tracing
**Target**: READ factory at 0x100b5000, WRITE factory at 0x100b50c0, callsites pushing DTC values
**What I tried**: Traced READ/WRITE factory calling convention to identify which stack argument maps to Data Type Code. Analyzed base constructor at 0x100ae770 (ret 0x18) to determine stack cleanup. Scanned all factory callsites for immediate DTC values.
**What I found**:
- Factory signature: `push 1` (READ, direction=data-in) or `push 2` (WRITE, direction=data-out), `ret 0x20` (8 DWORD params)
- Base constructor at 0x100ae770: `ret 0x18` (6 params), stores arg3→[esi+0x64]=DTC, arg4→[esi+0x66], arg5→[esi+0x68]
- arg3 = Data Type Code confirmed via ESP tracing through push/call/ret sequence
- Vtable READ builder at 0x100b51b0 reads DTC from [ecx+0x64] into CDB[2]
- Vtable WRITE builder at 0x100b51f0 mirrors READ structure, opcode 0x2A, control byte 0x00 (not 0x80)
- Factory callsite DTC values found:
  - READ: 0x84 (0x100B0D34), 0x88 (0x100B19E3), 0x8D (0x100B1E46, 0x100B1E9D), 0x87 (0x100B451B)
  - WRITE: 0x84 (0x100B0E06) — other WRITE DTCs passed dynamically from scan operation objects
- Inline READ builders (0x100866d9, 0x10086dfa, 0x1008781a) all hardcode DTC=0x00 (image data)
- Type B Phase B factory (0x100B41A0) dispatches on sub_code == 0x87 for READ
**Confidence**: Verified (cross-validated with firmware DTC tables at 0x49AD8/0x49B98)
**KB Updated**: docs/kb/scsi-commands/read.md, docs/kb/scsi-commands/write.md (both updated with source references)
