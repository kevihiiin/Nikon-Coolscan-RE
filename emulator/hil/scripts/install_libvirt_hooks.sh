#!/usr/bin/env bash
# Install the libvirt qemu hook + per-VM domain list under /etc/libvirt/hooks.
# Idempotent: safe to re-run after editing the source files in this repo.
#
# Usage: sudo ./install_libvirt_hooks.sh

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
SRC_HOOK="$REPO_ROOT/emulator/hil/scripts/libvirt-hook-vnc-tailscale"
SRC_LIST="$REPO_ROOT/emulator/hil/configs/tailscale-vnc-domains.txt"

DST_HOOK="/etc/libvirt/hooks/qemu"
DST_DIR="/etc/libvirt/hooks/coolscan-hil"
DST_LIST="$DST_DIR/tailscale-vnc-domains.txt"

if [[ "$EUID" -ne 0 ]]; then
    echo "Run with sudo: sudo $0" >&2
    exit 2
fi

[[ -f "$SRC_HOOK" ]] || { echo "ERROR: missing $SRC_HOOK" >&2; exit 1; }
[[ -f "$SRC_LIST" ]] || { echo "ERROR: missing $SRC_LIST" >&2; exit 1; }

mkdir -p "$DST_DIR"

# If a qemu hook already exists from another tool, don't blow it away — refuse.
if [[ -e "$DST_HOOK" ]] && ! cmp -s "$SRC_HOOK" "$DST_HOOK"; then
    if ! grep -q 'libvirt-hook-vnc-tailscale' "$DST_HOOK" 2>/dev/null; then
        echo "ERROR: $DST_HOOK exists and is NOT our hook." >&2
        echo "       Inspect it first; merge with our hook if needed." >&2
        exit 3
    fi
fi

install -m 0755 -o root -g root "$SRC_HOOK" "$DST_HOOK"
install -m 0644 -o root -g root "$SRC_LIST" "$DST_LIST"

echo "Installed:"
echo "  $DST_HOOK"
echo "  $DST_LIST"
echo ""

# libvirtd caches the hook list at startup. Reload picks up new/changed
# hooks without dropping running VMs (qemu processes are out-of-process).
echo "Reloading libvirtd to pick up the hook..."
if systemctl is-active --quiet libvirtd.service; then
    systemctl reload libvirtd.service
    echo "  libvirtd reloaded"
elif systemctl is-active --quiet virtqemud.service; then
    # Modular libvirt (Ubuntu 24.04+ default); reload virtqemud instead.
    systemctl reload virtqemud.service
    echo "  virtqemud reloaded"
else
    echo "  WARNING: neither libvirtd nor virtqemud is active. Hook will only" >&2
    echo "  fire after the next libvirt daemon start." >&2
fi

echo ""
echo "Effect: next time any VM listed in tailscale-vnc-domains.txt starts,"
echo "its <graphics type='vnc' listen=...> is rewritten to this host's"
echo "current Tailscale IPv4. Edit $DST_LIST to opt other VMs in/out."
echo ""
echo "If a domain is currently running, restart it for the change to apply:"
echo "  virsh -c qemu:///system destroy <domain>"
echo "  virsh -c qemu:///system start <domain>"
