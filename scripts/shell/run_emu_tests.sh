#!/bin/bash
# Run emulator test suite with firmware hash validation.
# Usage: ./scripts/shell/run_emu_tests.sh
#
# Exit codes: 0 = all pass, 1 = firmware missing/wrong, 2 = test failure

set -e

FIRMWARE="binaries/firmware/Nikon LS-50 MBM29F400B TSOP48.bin"
EXPECTED_SHA256="n/a"  # Set after first successful run

cd "$(git rev-parse --show-toplevel)"

# --- Firmware validation ---
if [ ! -f "$FIRMWARE" ]; then
    echo "ERROR: Firmware not found: $FIRMWARE"
    echo "  Tests require the proprietary 512KB firmware binary."
    exit 1
fi

SIZE=$(stat -c%s "$FIRMWARE" 2>/dev/null || stat -f%z "$FIRMWARE" 2>/dev/null)
if [ "$SIZE" != "524288" ]; then
    echo "ERROR: Firmware size is $SIZE bytes, expected 524288 (512KB)"
    exit 1
fi

ACTUAL_SHA=$(sha256sum "$FIRMWARE" 2>/dev/null | cut -d' ' -f1 || shasum -a 256 "$FIRMWARE" | cut -d' ' -f1)
echo "Firmware: $FIRMWARE"
echo "SHA-256:  $ACTUAL_SHA"
echo "Size:     $SIZE bytes"

if [ "$EXPECTED_SHA256" != "n/a" ] && [ "$ACTUAL_SHA" != "$EXPECTED_SHA256" ]; then
    echo "WARNING: Firmware hash mismatch!"
    echo "  Expected: $EXPECTED_SHA256"
    echo "  Actual:   $ACTUAL_SHA"
    echo "  Tests may fail if firmware version differs."
fi

echo ""

# --- Run tests ---
echo "Running emulator tests..."
cd emulator
cargo test --release 2>&1
EXIT=$?

if [ $EXIT -eq 0 ]; then
    echo ""
    echo "All emulator tests passed."
else
    echo ""
    echo "FAILED: Some tests did not pass."
    exit 2
fi
