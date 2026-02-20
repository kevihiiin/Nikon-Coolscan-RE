---
name: verify
description: Cross-validate an RE finding between host-side and device-side sources
argument-hint: [kb-doc-path]
---

<agent>
Cross-validate the finding in `docs/kb/$ARGUMENTS`:

1. Read the KB doc -- identify the claim and evidence source
2. Determine the "other side":
   - Host DLL evidence -> search firmware for matching handler
   - Firmware evidence -> search host DLLs for matching CDB
   - Single DLL -> check other DLLs for consistent usage
3. Search the other source for corroborating evidence
4. Return: what was checked, what was found, new confidence level recommendation
5. If verified, update the KB doc's confidence to "Verified"
</agent>
