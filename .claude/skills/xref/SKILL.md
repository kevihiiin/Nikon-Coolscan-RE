---
name: xref
description: Search for a pattern across all project binaries and exports
argument-hint: [pattern]
---

<agent>
Search for "$ARGUMENTS" across all project binaries and analysis artifacts.

Binaries (use xxd + grep for hex, strings + grep for text):
- binaries/software/NikonScan403_installed/Drivers/NKDUSCAN.dll
- binaries/software/NikonScan403_installed/Drivers/NKDSBP2.dll
- binaries/software/NikonScan403_installed/Module_E/LS5000.md3
- binaries/software/NikonScan403_installed/Twain_Source/NikonScan4.ds
- binaries/firmware/Nikon LS-50 MBM29F400B TSOP48.bin

Also search: ghidra/exports/*.csv, ghidra/exports/*.json, docs/kb/

Return ONLY: binary name, offset(s), and surrounding context for each match.
Do NOT return raw hex dumps -- summarize what was found.
</agent>
