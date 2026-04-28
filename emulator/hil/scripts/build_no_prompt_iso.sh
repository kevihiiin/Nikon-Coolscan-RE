#!/usr/bin/env bash
# Re-master a Microsoft Windows install ISO so UEFI boots straight into
# Setup, bypassing the "Press any key to boot from CD or DVD..." prompt.
#
# Background: UEFI loads whatever EFI image is referenced by the ISO's
# El Torito boot catalog. Microsoft's ISOs point to
#   /efi/microsoft/boot/efisys.bin
# which is a small FAT image whose contents include `cdboot.efi`. cdboot
# shows the 5-second prompt; if no key is pressed it exits, UEFI tries the
# next boot device (empty disk), and falls through to "no bootable
# option found".
#
# The same ISO ALSO ships
#   /EFI/BOOT/BOOTX64.EFI
# which is a copy of `bootmgfw.efi` and boots Windows Setup directly,
# without prompting.
#
# This script repacks the original ISO with `BOOTX64.EFI` as the El Torito
# EFI image. xorriso can't rewrite the boot catalog of Microsoft's
# "hidden" El Torito format in-place (libisofs warns about it), so we do a
# full extract + repack. ~10 GB of temp space, ~3-5 min wall clock; the
# resulting ISO is bit-equivalent in content but boots without the prompt.
#
# Usage:
#   build_no_prompt_iso.sh [<input.iso> [<output.iso>]]

set -euo pipefail

VMSTORE="${VMSTORE:-/mnt/vmstore}"
LIBVIRT_IMAGES="$VMSTORE/libvirt-images"
DEFAULT_IN="$LIBVIRT_IMAGES/26100.1742.240906-0331.ge_release_svc_refresh_CLIENT_IOT_LTSC_EVAL_x64FRE_en-us.iso"
DEFAULT_OUT="$LIBVIRT_IMAGES/win11-ltsc-no-prompt.iso"

IN="${1:-$DEFAULT_IN}"
OUT="${2:-$DEFAULT_OUT}"

[[ -f "$IN" ]] || { echo "FATAL: input ISO not found at $IN" >&2; exit 1; }

if [[ -f "$OUT" ]] && [[ "$OUT" -nt "$IN" ]]; then
    echo "[build_no_prompt_iso] $OUT already up-to-date — skip"
    exit 0
fi

# Read the source ISO's volume id so the rebuild looks identical
VOLID=$(xorriso -indev "$IN" -toc 2>&1 | grep -oE "Volume id\s+:\s+'[^']+'" | head -1 | sed -E "s/.*'(.*)'.*/\1/")
VOLID="${VOLID:-WIN_LTSC}"
echo "[build_no_prompt_iso] source volid: $VOLID"

EXTRACT_DIR="$VMSTORE/win-iso-extract"
echo "[build_no_prompt_iso] extracting $IN to $EXTRACT_DIR (~2 min, ~5 GB)"
rm -rf "$EXTRACT_DIR"
mkdir -p "$EXTRACT_DIR"
7z x -bso0 -bsp0 -y -o"$EXTRACT_DIR" "$IN"

# Sanity: BOOTX64.EFI must exist where we expect
if [[ ! -f "$EXTRACT_DIR/efi/boot/bootx64.efi" ]] && [[ ! -f "$EXTRACT_DIR/EFI/BOOT/BOOTX64.EFI" ]]; then
    echo "FATAL: extracted ISO doesn't have EFI/BOOT/BOOTX64.EFI — wrong ISO type?" >&2
    rm -rf "$EXTRACT_DIR"
    exit 1
fi

# Find bootx64.efi case as it actually exists in the extract (Microsoft ISOs
# vary; mkisofs `-e` takes the path RELATIVE to the source dir, case-sensitive).
BOOTX64=$(find "$EXTRACT_DIR" -ipath '*efi/boot/bootx64.efi' -print -quit | head -1)
[[ -n "$BOOTX64" ]] || { echo "FATAL: bootx64.efi not found in extract" >&2; exit 1; }
BOOTX64_REL="${BOOTX64#$EXTRACT_DIR/}"
echo "[build_no_prompt_iso] EFI boot image: $BOOTX64_REL"

echo "[build_no_prompt_iso] writing $OUT (~2 min, ~5 GB)"
# UEFI-only El Torito catalog. Specify the EFI boot image as the PRIMARY
# boot entry (not alt-boot, which would require a BIOS entry first).
# `-eltorito-platform efi` tells the catalog this entry is for UEFI; OVMF
# uses it directly. `-isohybrid-gpt-basdat` adds a GPT partition table so
# UEFI firmwares that prefer GPT (most do) find the bootable EFI partition.
xorriso -as mkisofs \
    -volid "$VOLID" \
    -iso-level 3 \
    -joliet -joliet-long -rational-rock \
    -eltorito-platform efi \
    -eltorito-boot "$BOOTX64_REL" \
    -no-emul-boot \
    -isohybrid-gpt-basdat \
    -o "$OUT" \
    "$EXTRACT_DIR/"

echo "[build_no_prompt_iso] cleaning up extract dir"
rm -rf "$EXTRACT_DIR"

ls -lh "$OUT"
echo "[build_no_prompt_iso] done. $OUT boots without 'Press any key' prompt."
