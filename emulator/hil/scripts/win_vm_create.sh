#!/usr/bin/env bash
# Create the Win10/Win11 LTSC HIL VM via virt-install.
#
# Defaults match the M15 plan; override via env vars. Idempotent in the
# sense that re-running with the same domain name will refuse to clobber.
#
# Required: ISO present and verified (verify_iso.sh).
# Required: Phase 0/1 done (setup_dev_box.sh).

set -euo pipefail

VMSTORE="${VMSTORE:-/mnt/vmstore}"
POOL="${POOL:-vmstore}"
DOMAIN="${DOMAIN:-win10-ltsc-nikonscan}"
RAM_MIB="${RAM_MIB:-4096}"
VCPUS="${VCPUS:-4}"
DISK_GIB="${DISK_GIB:-60}"
ISO_PATH="${ISO_PATH:?ISO_PATH must point to a verified Win LTSC ISO}"
VIRTIO_ISO="${VIRTIO_ISO:-$VMSTORE/libvirt-images/virtio-win.iso}"

OS_VARIANT="${OS_VARIANT:-win11}"   # `osinfo-query os` for full list (e.g. win10, win11)
VNC_PORT="${VNC_PORT:-5900}"
VNC_PASSWORD="${VNC_PASSWORD:-}"    # blank = no VNC password (loopback only)

# -----------------------------------------------------------------------------
# Sanity
[[ -f "$ISO_PATH" ]] || { echo "ERROR: ISO_PATH=$ISO_PATH not found" >&2; exit 1; }
if [[ ! -f "$VIRTIO_ISO" ]]; then
    echo "WARN: virtio-win.iso not at $VIRTIO_ISO; downloading from Fedora..."
    curl -L -o "$VIRTIO_ISO" \
        "https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/stable-virtio/virtio-win.iso"
fi

# Refuse to clobber an existing domain
if virsh -c qemu:///system list --all --name | grep -qx "$DOMAIN"; then
    echo "ERROR: domain '$DOMAIN' already exists. Use re_roll_vm.sh to rebuild." >&2
    exit 2
fi

# -----------------------------------------------------------------------------
# We delegate disk creation to libvirt via the storage pool. No sudo needed —
# libvirt-qemu owns the pool dir, virt-install creates the volume as that user
# with the right permissions automatically.
echo "Creating VM '$DOMAIN' (disk: ${DISK_GIB} GiB qcow2 in pool '$POOL')"

GRAPHICS_OPT="vnc,listen=127.0.0.1,port=$VNC_PORT"
[[ -n "$VNC_PASSWORD" ]] && GRAPHICS_OPT+=",passwd=$VNC_PASSWORD"

virt-install \
    --connect qemu:///system \
    --name "$DOMAIN" \
    --memory "$RAM_MIB" \
    --vcpus "$VCPUS" \
    --cpu host-passthrough \
    --machine q35 \
    --boot uefi \
    --tpm backend.type=emulator,backend.version=2.0,model=tpm-crb \
    --features smm.state=on \
    --clock offset=localtime \
    --network network=default,model=virtio \
    --controller type=usb,model=qemu-xhci \
    --disk size="$DISK_GIB",pool="$POOL",format=qcow2,bus=virtio,cache=none,discard=unmap \
    --cdrom "$ISO_PATH" \
    --disk path="$VIRTIO_ISO",device=cdrom,bus=sata \
    --channel unix,target.type=virtio,target.name=org.qemu.guest_agent.0 \
    --osinfo "$OS_VARIANT" \
    --graphics "$GRAPHICS_OPT" \
    --console pty,target.type=serial \
    --noautoconsole

cat <<EOF

VM '$DOMAIN' is installing. Connect with:
    virt-viewer --connect qemu:///system $DOMAIN
or:
    vncviewer 127.0.0.1:$VNC_PORT

Follow emulator/hil/docs/vm-setup.md for the manual install steps
(VirtIO drivers, qemu-ga, usbip-win2, NikonScan, snapshots).
EOF
