#!/usr/bin/env bash
# Build the post-install ISO consumed by FirstLogonCommands inside Windows.
# Layout:
#   /COOLSCAN_POSTINSTALL.MARKER  — empty file used by postinstall.cmd to find this CDROM
#   /postinstall.cmd              — runs once on first boot
#   /USBip-x64.exe                — usbip-win2 InnoSetup installer
#   /NikonScan403/...             — extracted from binaries/software/NikonScan403.iso

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
SRC_CMD="$REPO_ROOT/emulator/hil/configs/postinstall.cmd"
SRC_NIKON_ISO="$REPO_ROOT/binaries/software/NikonScan403.iso"

VMSTORE="${VMSTORE:-/mnt/vmstore}"
LIBVIRT_IMAGES="$VMSTORE/libvirt-images"
STAGING="${STAGING:-$LIBVIRT_IMAGES/postinstall-staging}"
OUT_ISO="${OUT_ISO:-$LIBVIRT_IMAGES/postinstall.iso}"

[[ -f "$SRC_CMD" ]] || { echo "FATAL: missing $SRC_CMD" >&2; exit 1; }
[[ -f "$SRC_NIKON_ISO" ]] || { echo "FATAL: missing $SRC_NIKON_ISO" >&2; exit 1; }

mkdir -p "$STAGING"
"$REPO_ROOT/emulator/hil/scripts/download_usbip_win2.sh"

WORK=$(mktemp -d /tmp/postinstall-build.XXXXXX)
trap 'rm -rf "$WORK"' EXIT

echo "[build_postinstall_iso] staging at $WORK"

# Marker so postinstall.cmd can find this CD-ROM
: > "$WORK/COOLSCAN_POSTINSTALL.MARKER"

# Post-install batch script + usbip installer
cp "$SRC_CMD" "$WORK/postinstall.cmd"
cp "$STAGING/USBip-x64.exe" "$WORK/USBip-x64.exe"

# Extract the NikonScan installer ISO into a directory so postinstall.cmd
# can run setup.exe directly (Windows can't easily mount nested ISOs).
echo "[build_postinstall_iso] extracting $SRC_NIKON_ISO into staging"
mkdir -p "$WORK/NikonScan403"
7z x -bso0 -bsp0 -y -o"$WORK/NikonScan403" "$SRC_NIKON_ISO" >/dev/null
echo "  NikonScan installer entries:"
ls "$WORK/NikonScan403" | head -10

# Sanity: there must be a setup.exe somewhere in the NikonScan tree.
# (The actual target is .../Nikon Scan 4.0.3/EN/Disk1/setup.exe, ~4 levels deep;
# postinstall.cmd hardcodes that path.)
if ! find "$WORK/NikonScan403" -iname "setup.exe" -print -quit | grep -q .; then
    echo "WARN: no setup.exe found anywhere in NikonScan tree — postinstall will skip silent install" >&2
fi

echo "[build_postinstall_iso] writing $OUT_ISO"
xorriso -as mkisofs \
    -volid POSTINSTALL \
    -iso-level 3 \
    -joliet \
    -joliet-long \
    -rational-rock \
    -o "$OUT_ISO" \
    "$WORK"

chmod 0644 "$OUT_ISO"
ls -lh "$OUT_ISO"
