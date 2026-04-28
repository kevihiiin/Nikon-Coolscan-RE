"""preview_scan — drive NikonScan to render a preview of the loaded slide.

Starts from the same `windows-11-clean-desktop` state that `inquiry_smoke`
baselines. Launches NikonScan, lets it connect to the bound LS-50, hits
Preview, waits for the preview pane to populate.

This recipe deliberately ships *without* hard-coded click coordinates for
NikonScan toolbar/menu items. The vision-oracle + grounding-fallback
pattern (ADR 0001) gives Holo3 up to 3 recovery actions per expect_screen
to advance the UI to the expected state — the runner asks "expected X but
saw Y; emit one Action to recover or Abort". For a known-good NikonScan
build this is enough for the planner to click Preview and similar
single-target buttons without committed coordinates.

Once this recipe runs green a few times, use `coolscan-hil record` to
capture pixel-accurate clicks and promote screen pHashes into
`baselines/preview_scan/`. At that point hard-coded `click_at` calls can
replace the grounding hops for speed and determinism.

NikonScan does NOT save the preview to disk — preview is a window-internal
render only — so this recipe asserts on pixel content of the preview pane
rather than on a file. `full_scan` is the recipe that produces a TIFF.
"""

from __future__ import annotations

from ..recipe import Recipe


def build() -> Recipe:
    return (
        Recipe("preview_scan")
        # Snapshot revert + driver-bound state should land us on the same
        # desktop inquiry_smoke baselined. If pHash drifts, the recipe
        # fails fast on the wrong starting state instead of crashing
        # mid-NikonScan.
        .expect_screen("windows-11-clean-desktop", baseline_hash="ec859a7a913ed829")
        # Launch the app via Win+R. `_open_app` types the exe name and
        # presses Enter; "Nikon Scan" works because installer adds it to
        # PATH via shortcut resolution.
        .open_app("Nikon Scan")
        # NikonScan splash + main window appear over a few seconds.
        .wait_for_screen("nikonscan-main-window", timeout_s=45)
        # Driver is bound (snapshot=`driver-bound`); NikonScan auto-opens
        # the TWAIN data source on launch and shows the scanner-ready
        # workspace. Grounding handles any "select source" dialog if
        # auto-connect didn't fire.
        .expect_screen("nikonscan-scanner-ready")
        # Trigger preview. Grounding identifies and clicks the Preview
        # toolbar button to advance to the rendered state.
        .expect_screen("preview-rendering-started")
        # Preview render is bottlenecked by the emulator's CCD pipeline
        # (single-threaded, ~3000 lines x multi-byte pixels). 3 min ceiling
        # is generous; real wall time has been seen at 30-90 s on dev box.
        .wait_for_screen("preview-pane-shown", timeout_s=180)
        # Sanity: a populated preview pane should have meaningfully more
        # color variation than an empty/grey workspace. 500 unique colors
        # is well above any flat-dialog baseline but well below a real
        # frame's diversity.
        .assert_image_nonblank(min_unique_colors=500)
    )
