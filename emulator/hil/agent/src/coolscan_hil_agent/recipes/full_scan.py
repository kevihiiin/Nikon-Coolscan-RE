"""full_scan — drive NikonScan through a complete single-frame scan that
produces a TIFF on disk.

Picks up where `preview_scan` leaves off in concept: launches NikonScan,
connects, but instead of stopping at preview, hits Scan and waits for the
saved file in `C:\\scans\\` (NikonScan's configured output directory, set
during VM provisioning per `vm-setup.md`).

This is the *throughput* recipe — exercises:
- USB bulk-IN sustained transfer (~10-50 MB depending on resolution)
- Firmware-driven CCD → ASIC DMA → ISP1581 EP2 IN pipeline end-to-end
- NikonScan's own image-write pipeline (DRAG/Strato + TIFF encoder)

Like preview_scan, the recipe uses Holo3 grounding rather than committed
click coordinates for resolution/Scan-button clicks. Once a green run
locks in the UI layout, `coolscan-hil record` captures the clicks into
baselines/full_scan/ and they replace the grounding hops.

Resolution is left at NikonScan's default. A first green run at default
DPI proves the pipeline; bumping to 4000 DPI for the throughput stress
test (~50 MB) belongs in a follow-up recipe (`full_scan_4000.py`) once
this one is stable.
"""

from __future__ import annotations

from ..recipe import Recipe

# Single-frame scan budget: emulator CCD is single-threaded; default-DPI
# scan is empirically 1-3 min wall time on dev box. 10 min ceiling
# accommodates retries from grounding fallbacks during the navigation
# hops without bumping into the per-step asyncio.timeout (60 s) — note
# that wait_for_screen has its own poll loop, not the per-step timeout.
SCAN_TIMEOUT_S = 600


def build() -> Recipe:
    return (
        Recipe("full_scan")
        .expect_screen("windows-11-clean-desktop", baseline_hash="ec859a7a913ed829")
        .open_app("Nikon Scan")
        .wait_for_screen("nikonscan-main-window", timeout_s=45)
        .expect_screen("nikonscan-scanner-ready")
        # Hit the Scan (not Preview) button. Grounding identifies it.
        .expect_screen("scan-in-progress")
        # Long timeout: full-frame scan + DRAG processing + TIFF write.
        .wait_for_screen("scan-complete", timeout_s=SCAN_TIMEOUT_S)
        # NikonScan writes timestamped filenames; glob matches any TIFF
        # produced this session. The driver-bound snapshot leaves the
        # scans directory empty, so this is a clean signal.
        .assert_file_exists(r"C:\scans\*.tif")
    )
