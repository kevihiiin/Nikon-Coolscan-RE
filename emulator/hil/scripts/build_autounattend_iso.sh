#!/usr/bin/env bash
# Build a small ISO that Windows Setup auto-discovers at boot:
#   /Autounattend.xml       — drives the unattended install
#   /$WinPEDriver$/viostor/ — virtio-blk drivers loaded during windowsPE
#                              so Windows sees the virtio system disk

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
SRC_AUTOUNATTEND="$REPO_ROOT/emulator/hil/configs/autounattend.xml"

VMSTORE="${VMSTORE:-/mnt/vmstore}"
LIBVIRT_IMAGES="$VMSTORE/libvirt-images"
VIRTIO_ISO="${VIRTIO_ISO:-$LIBVIRT_IMAGES/virtio-win.iso}"
OUT_ISO="${OUT_ISO:-$LIBVIRT_IMAGES/autounattend.iso}"

[[ -f "$SRC_AUTOUNATTEND" ]] || { echo "FATAL: missing $SRC_AUTOUNATTEND" >&2; exit 1; }
[[ -f "$VIRTIO_ISO" ]] || { echo "FATAL: $VIRTIO_ISO missing — fetch via win_vm_create.sh first" >&2; exit 1; }

WORK=$(mktemp -d /tmp/autounattend-build.XXXXXX)
trap 'rm -rf "$WORK"' EXIT

echo "[build_autounattend_iso] staging at $WORK"

# 1. Autounattend.xml at root (Windows Setup auto-discovers)
cp "$SRC_AUTOUNATTEND" "$WORK/Autounattend.xml"

# 2. $WinPEDriver$ folder triggers automatic driver injection during windowsPE
mkdir -p "$WORK/\$WinPEDriver\$/viostor"
echo "[build_autounattend_iso] extracting viostor (Win11 amd64) from virtio-win.iso"
7z e -bso0 -bsp0 -y -o"$WORK/\$WinPEDriver\$/viostor" "$VIRTIO_ISO" \
    'viostor/w11/amd64/viostor.cat' \
    'viostor/w11/amd64/viostor.inf' \
    'viostor/w11/amd64/viostor.sys'
ls "$WORK/\$WinPEDriver\$/viostor"

# 3. Build the ISO — UDF + ISO9660 + Joliet for max Windows Setup compatibility
echo "[build_autounattend_iso] writing $OUT_ISO"
xorriso -as mkisofs \
    -volid AUTOUNATTEND \
    -iso-level 3 \
    -joliet \
    -joliet-long \
    -rational-rock \
    -o "$OUT_ISO" \
    "$WORK"

# Make readable by libvirt-qemu
chmod 0644 "$OUT_ISO"
ls -lh "$OUT_ISO"
