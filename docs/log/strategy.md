# RE Strategy & Tactical Insights

<!-- CURRENT BEST PRACTICES - editable summary -->
## Active Strategies

- **Use Ghidra (not r2) for H8/300H firmware**: r2 5.5.0 only supports basic H8/300 (16-bit). The carllom/sleigh-h8 SLEIGH module in Ghidra correctly handles H8/300H extended instructions with 32-bit data and 24-bit addressing.
- **Java scripts for Ghidra headless**: Ghidra 12.0.3 doesn't support Python in headless mode without PyGhidra. Use Java `.java` scripts for headless automation.
- **RTTI is the map**: MSVC RTTI class names provide the architectural skeleton. Search `.?AV` in .rdata for type_info names, then match to vtables.
- **Vector trampolines**: Firmware interrupt handlers use on-chip RAM trampolines (0xFFFDxx). These are likely patched at runtime by the main firmware to point to actual handlers in flash. Follow the trampoline setup code to find real handlers.
- **Venv for Python**: Use `.venv/bin/python3` for pefile and other analysis libraries (system pip not available).

---
<!-- INSIGHTS BELOW - APPEND ONLY -->

## 2026-02-20: H8/300H SLEIGH Module Setup

**Context**: Setting up Ghidra for firmware analysis
**Insight**: The carllom/sleigh-h8 module needs manual compilation of h8300h.slaspec using `/opt/ghidra/support/sleigh`. The pre-built h8300.sla only covers basic H8/300. The compiled h8300h.sla must be placed in the extension's data/languages/ directory. Extension goes in `~/.config/ghidra/ghidra_VERSION/Extensions/H8/`.
**Applies to**: Phase 0 setup, Phase 4 firmware analysis

## 2026-02-20: Firmware Vector Table Architecture

**Context**: Parsing firmware interrupt vector table
**Insight**: 15 active vectors, most pointing to 0xFFFDxx (H8/3003 on-chip RAM, not flash). This means the firmware uses a two-stage vector dispatch: hardware vectors in flash point to trampolines in on-chip RAM, which then jump to actual handlers. This allows the main firmware (loaded at 0x20000+) to install its own handlers at runtime without modifying flash. To find the real interrupt handlers, search for code that writes to the 0xFFFD10-0xFFFD3C range.
**Applies to**: Phase 4 firmware analysis -- must trace trampoline setup to find real ISR code

## 2026-02-20: NKDUSCAN.dll Contains Both USB and SBP2 Classes

**Context**: RTTI extraction from NKDUSCAN.dll (USB transport)
**Insight**: NKDUSCAN.dll contains RTTI for both USB classes (CUSB2Command, CUSBSession) AND SBP2 classes (CSBP2CommandManager, CSBP2Command). This suggests a shared base class / interface pattern -- both transports implement the same abstract command interface. This confirms the abstraction boundary: everything above NkDriverEntry is transport-agnostic.
**Applies to**: Phase 1 (NKDUSCAN analysis), Phase 7 (cross-model transport comparison)
