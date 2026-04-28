"""inquiry_smoke — smallest non-trivial recipe that exercises the full runner
pipeline (VNC capture → Holo3 oracle → artifact write) against the live VM.

Asserts the VM is in a clean Windows 11 desktop state — i.e. that the
`driver-bound` snapshot reverted cleanly and no stale dialogs are open.
This is the M15 baseline: every subsequent recipe (preview_scan, full_scan)
should start from the same state, so promoting this frame as the
`windows-11-clean-desktop` baseline gives downstream recipes a stable
launching pad.

Future recipes will add: open_app("Nikon Scan"), wait_for_screen for the
NikonScan main window, click through TWAIN source selection, etc. Held off
in this minimal recipe so we have one single-step success before layering
on click-coordinate guesswork.
"""

from __future__ import annotations

from ..recipe import Recipe


def build() -> Recipe:
    # baseline_hash matches the value committed in
    # baselines/inquiry_smoke/windows-11-clean-desktop.json. The runner re-loads
    # that file at runtime — keeping the literal here is a redundancy guard so
    # a recipe failure points at *whichever* of the two has drifted.
    return Recipe("inquiry_smoke").expect_screen(
        "windows-11-clean-desktop", baseline_hash="ec859a7a913ed829"
    )
