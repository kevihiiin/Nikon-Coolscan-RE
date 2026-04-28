#!/usr/bin/env bash
# Phase 0/1 dev-box prep for the M15 HIL stack.
#
# Idempotent: safe to re-run. Prints clear status for each step.
# Requires sudo (for apt + group membership + libvirt:///system bootstrap),
# but does NOT require relogin — uses `sg libvirt` to wrap virsh calls so the
# operator can verify the configuration in the same shell.
#
# What it does:
#   1. apt install qemu-kvm + libvirt + virt-manager + virtinst
#   2. add the operator to libvirt + kvm groups (effective after relogin)
#   3. enable + start libvirtd
#   4. ensure /mnt/vmstore is mounted (Phase 0)
#   5. create the libvirt-images dir + `vmstore` storage pool
#   6. define + start the libvirt `default` NAT network
#
# After this, `virsh list --all` should work without sudo (after relogin),
# and the VM build script can be run.

set -euo pipefail

VMSTORE="${VMSTORE:-/mnt/vmstore}"
LIBVIRT_IMAGES="$VMSTORE/libvirt-images"

require_sudo() {
    if ! sudo -n true 2>/dev/null; then
        echo "[setup_dev_box] sudo required; you'll be prompted shortly."
        sudo -v
    fi
}

step() { echo ""; echo "=== $* ==="; }

# -----------------------------------------------------------------------------
step "1. apt install libvirt + qemu + virt-manager"
require_sudo
sudo apt-get update -qq
sudo apt-get install -y --no-install-recommends \
    qemu-kvm libvirt-daemon-system libvirt-clients libvirt-dev \
    virt-manager virtinst bridge-utils virt-viewer \
    swtpm swtpm-tools \
    pkg-config

# -----------------------------------------------------------------------------
step "2. group membership (libvirt + kvm)"
USER_NAME="${SUDO_USER:-$USER}"
if ! id -nG "$USER_NAME" | grep -qw libvirt; then
    sudo usermod -aG libvirt "$USER_NAME"
    echo "added $USER_NAME to libvirt group (effective after relogin)"
else
    echo "$USER_NAME already in libvirt"
fi
if ! id -nG "$USER_NAME" | grep -qw kvm; then
    sudo usermod -aG kvm "$USER_NAME"
    echo "added $USER_NAME to kvm group (effective after relogin)"
else
    echo "$USER_NAME already in kvm"
fi

# -----------------------------------------------------------------------------
step "3. enable + start libvirtd"
sudo systemctl enable --now libvirtd
sudo systemctl is-active --quiet libvirtd
echo "libvirtd running"

# -----------------------------------------------------------------------------
# Reconfigure libvirt's qemu user/group so disk-file chown-on-VM-start
# produces files OWNED BY the operator instead of libvirt-qemu:kvm.
#
# Background: libvirt's `dynamic_ownership` (default on) chowns every disk
# / CDROM file to the qemu run-as user (default libvirt-qemu:kvm) when a
# VM uses it, then tries to restore on undefine — but the restore path is
# unreliable across rebuilds. After a few cycles, ISOs end up libvirt-qemu
# -owned mode 0644 and the operator can't overwrite them.
#
# The naïve fix (`dynamic_ownership = 0`) breaks swtpm (TPM emulator
# refuses to write its state if libvirt didn't relabel the directory).
# Real fix: keep dynamic_ownership on, but tell libvirt to use ky:libvirt
# as the qemu run-as user. That way every chown leaves files writable by
# the operator AND swtpm/qemu still get the relabeling they need.
step "3b. configure libvirt qemu user/group"
QEMU_CONF=/etc/libvirt/qemu.conf
NEED_RESTART=0

# Drop any prior `dynamic_ownership = 0` line (we revert to default behavior)
if sudo grep -qE '^[^#]*dynamic_ownership\s*=\s*0' "$QEMU_CONF" 2>/dev/null; then
    sudo sed -i -E 's|^(dynamic_ownership\s*=\s*0)|#\1|' "$QEMU_CONF"
    NEED_RESTART=1
    echo "  reverted dynamic_ownership = 0 (caused swtpm permission failures)"
fi

# Set user = "<operator>" and group = "libvirt"
USER_NAME="${SUDO_USER:-$USER}"
for kv in "user=$USER_NAME" "group=libvirt"; do
    key="${kv%%=*}"
    val="${kv##*=}"
    if sudo grep -qE "^${key}\s*=\s*\"${val}\"" "$QEMU_CONF" 2>/dev/null; then
        echo "  $key = \"$val\" already set"
        continue
    fi
    if sudo grep -qE "^\s*#?\s*${key}\s*=" "$QEMU_CONF" 2>/dev/null; then
        sudo sed -i -E "s|^\\s*#?\\s*(${key}\\s*=).*|\\1 \"${val}\"|" "$QEMU_CONF"
    else
        echo "${key} = \"${val}\"" | sudo tee -a "$QEMU_CONF" >/dev/null
    fi
    echo "  set $key = \"$val\""
    NEED_RESTART=1
done

if [[ "$NEED_RESTART" == "1" ]]; then
    echo "  restarting libvirtd to apply"
    sudo systemctl restart libvirtd
fi

# -----------------------------------------------------------------------------
step "4. /mnt/vmstore mount check"
if ! mountpoint -q "$VMSTORE"; then
    echo "ERROR: $VMSTORE is not a mounted filesystem." >&2
    echo "Mount your dedicated VM disk at $VMSTORE before running this script." >&2
    exit 1
fi
df -h "$VMSTORE" | tail -1

# -----------------------------------------------------------------------------
step "5. libvirt-images dir + vmstore pool"
sudo mkdir -p "$LIBVIRT_IMAGES"
# libvirt-qemu user owns the images (may differ on non-Debian distros)
LIBVIRT_QEMU_UID=$(id -u libvirt-qemu 2>/dev/null || id -u qemu 2>/dev/null || echo "0")
LIBVIRT_GID=$(getent group libvirt | cut -d: -f3)
if [[ "$LIBVIRT_QEMU_UID" != "0" ]]; then
    sudo chown "$LIBVIRT_QEMU_UID:$LIBVIRT_GID" "$LIBVIRT_IMAGES"
fi
sudo chmod 0775 "$LIBVIRT_IMAGES"

# Check if the pool already exists. Use pool-info for a more robust check
# than `pool-list --all --name | grep` (which can produce false negatives
# in edge cases like daemon-just-restarted).
if sudo virsh -c qemu:///system pool-info vmstore >/dev/null 2>&1; then
    echo "pool 'vmstore' already defined"
    sudo virsh -c qemu:///system pool-autostart vmstore >/dev/null 2>&1 || true
    sudo virsh -c qemu:///system pool-start vmstore 2>/dev/null || true
else
    sudo virsh -c qemu:///system pool-define-as vmstore dir --target "$LIBVIRT_IMAGES"
    sudo virsh -c qemu:///system pool-autostart vmstore
    sudo virsh -c qemu:///system pool-start vmstore
    echo "pool 'vmstore' created and started"
fi
sudo virsh -c qemu:///system pool-info vmstore

# -----------------------------------------------------------------------------
step "6. libvirt 'default' NAT network"
if sudo virsh -c qemu:///system net-list --all --name | grep -qx default; then
    echo "network 'default' already defined"
else
    DEFAULT_NET_XML="/usr/share/libvirt/networks/default.xml"
    if [[ ! -f "$DEFAULT_NET_XML" ]]; then
        echo "ERROR: $DEFAULT_NET_XML missing — libvirt-daemon-system not fully installed?" >&2
        exit 1
    fi
    sudo virsh -c qemu:///system net-define "$DEFAULT_NET_XML"
    echo "network 'default' defined"
fi
sudo virsh -c qemu:///system net-autostart default >/dev/null
sudo virsh -c qemu:///system net-start default 2>/dev/null || true
sudo virsh -c qemu:///system net-info default

# -----------------------------------------------------------------------------
step "summary"
echo "Phase 0/1 setup complete."
echo ""
echo "Verify in a NEW LOGIN SESSION (group membership is per-login):"
echo "  virsh -c qemu:///system list --all"
echo "  virsh -c qemu:///system net-list"
echo "  virsh -c qemu:///system pool-list"
echo ""
echo "Next: source the Win10/Win11 LTSC ISO and run win_vm_create.sh."
echo "      See emulator/hil/docs/vm-setup.md for the full runbook."
