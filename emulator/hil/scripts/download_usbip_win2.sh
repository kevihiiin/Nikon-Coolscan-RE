#!/usr/bin/env bash
# Download the latest usbip-win2 release into the postinstall staging dir.
# Idempotent: skips download if the existing file matches the release size.

set -euo pipefail

OUT_DIR="${OUT_DIR:-/mnt/vmstore/libvirt-images/postinstall-staging}"
OUT_NAME="${OUT_NAME:-USBip-x64.exe}"

mkdir -p "$OUT_DIR"

echo "[download_usbip_win2] querying GitHub for latest release"
URL=$(curl -fsSL https://api.github.com/repos/vadimgrn/usbip-win2/releases/latest |
      grep -oE '"browser_download_url":\s*"[^"]+"' |
      grep -oE 'https://[^"]+x64\.exe' |
      head -1)

if [[ -z "$URL" ]]; then
    echo "[download_usbip_win2] FATAL: couldn't find an x64.exe asset in latest release" >&2
    exit 1
fi

echo "[download_usbip_win2] URL: $URL"
DEST="$OUT_DIR/$OUT_NAME"

# If file exists and is non-trivial, skip
if [[ -f "$DEST" ]] && [[ $(stat -c%s "$DEST") -gt 1000000 ]]; then
    echo "[download_usbip_win2] skip: $DEST already present ($(stat -c%s "$DEST") bytes)"
    exit 0
fi

curl -fL --retry 3 -o "$DEST" "$URL"
ls -lh "$DEST"
