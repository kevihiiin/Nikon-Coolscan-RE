#!/usr/bin/env bash
# Verify the SHA-256 of a downloaded Windows LTSC ISO against a known value.
#
# Usage:
#   verify_iso.sh <iso-path> [expected-sha256]
#
# If [expected-sha256] is omitted, the script picks the right hash by
# inspecting the filename. Hashes embedded below are sourced from
# Microsoft's published `WindowsXxEnterpriseHashValues.pdf` (or community
# threads where Microsoft engineers have quoted them in answers).

set -euo pipefail

ISO_PATH="${1:?usage: verify_iso.sh <iso-path> [expected-sha256]}"
EXPECTED="${2:-}"

if [[ ! -f "$ISO_PATH" ]]; then
    echo "ERROR: $ISO_PATH not found." >&2
    exit 1
fi

# --- Known-good hashes (extend as new official ISOs are released) ----------
# Format: filename-substring  →  SHA-256
declare -A HASHES=(
    # Win 10 Enterprise LTSC 2021 — eval (90-day; Microsoft retired the host)
    ["19044.1288.211006-0501.21h2_release_svc_refresh_CLIENT_LTSC_EVAL"]="e4ab2e3535be5748252a8d5d57539a6e59be8d6726345ee10e7afd2cb89fefb5"

    # Win 11 IoT Enterprise LTSC 2024 (en-US, x64) — direct OEM ISO
    # SHA-256 from https://archive.org/details/Windows11LTSC mirror manifest;
    # cross-verify against Microsoft's Windows11EnterpriseHashValues.pdf if
    # you can fetch it.
    ["X23-81951_26100.1742.240906-0331.ge_release_svc_refresh_CLIENT_ENTERPRISES_OEM_x64FRE_en-us"]="4f59662a96fc1da48c1b415d6c369d08af55ddd64e8f1c84e0166d9e50405d7a"

    # Win 11 IoT Enterprise LTSC 2024 (en-US, x64) — 90-day Evaluation ISO,
    # served from software-static.download.prss.microsoft.com.
    # Cross-confirmed by: Ventoy GitHub issue 3194, Microsoft Q&A, rg-adguard
    # file DB, ComputerBase forum. Size 4.713 GB / 5,060,020,224 bytes.
    ["26100.1742.240906-0331.ge_release_svc_refresh_CLIENT_IOT_LTSC_EVAL_x64FRE_en-us"]="2cee70bd183df42b92a2e0da08cc2bb7a2a9ce3a3841955a012c0f77aeb3cb29"
)

base="$(basename "$ISO_PATH")"

# Try to auto-pick the expected hash if caller didn't pass one.
if [[ -z "$EXPECTED" ]]; then
    for substr in "${!HASHES[@]}"; do
        if [[ "$base" == *"$substr"* ]]; then
            EXPECTED="${HASHES[$substr]}"
            echo "matched filename pattern: $substr"
            break
        fi
    done
fi

if [[ -z "$EXPECTED" ]]; then
    echo "ERROR: no expected hash matched filename '$base'." >&2
    echo "       pass the SHA-256 explicitly:" >&2
    echo "       verify_iso.sh '$ISO_PATH' <sha256>" >&2
    exit 2
fi

echo "ISO:      $ISO_PATH"
echo "Expected: $EXPECTED"
echo "computing SHA-256 (this is fast on NVMe, ~30s on spinning disk)..."

ACTUAL=$(sha256sum "$ISO_PATH" | awk '{print $1}')
echo "Actual:   $ACTUAL"

if [[ "$ACTUAL" == "$EXPECTED" ]]; then
    echo "OK: SHA-256 matches."
    exit 0
fi

echo "FAIL: SHA-256 mismatch — the ISO is corrupted, modified, or a different release." >&2
exit 1
