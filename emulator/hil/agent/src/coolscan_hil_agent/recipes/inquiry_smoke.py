"""inquiry_smoke — minimal recipe that opens NikonScan and confirms the
Coolscan LS-50 enumerates as a TWAIN source. Click coordinates are
placeholders to be replaced after recording the first interactive session
against the snapshotted VM.

Maps to "Phase 7 Tier 2 step 6" in the M15 plan: smallest E2E loop that
drives one Holo3 oracle call against a real VM.
"""

from __future__ import annotations

from ..recipe import Recipe


def build() -> Recipe:
    return Recipe("inquiry_smoke").open_app("NikonScan.exe").expect_screen("nikonscan-main-window")
