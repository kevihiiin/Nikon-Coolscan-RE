#!/usr/bin/env bash
# End-to-end autonomous Windows VM build for the M15 HIL.
#
# Pipeline:
#   1. Wipe any existing domain (if --rebuild)
#   2. Build the autounattend ISO (Autounattend.xml + windowsPE drivers)
#   3. Build the post-install ISO (postinstall.cmd + usbip-win2 + NikonScan)
#   4. virt-install with all CDROMs attached + virt-install --noautoconsole
#   5. Poll until VM has shut down (signal that postinstall.cmd ran shutdown /s)
#   6. Snapshot as `pristine-install` (or `nikonscan-installed` if NikonScan
#      silent install reported success)
#
# Run via:
#   sg libvirt -c 'emulator/hil/scripts/build_vm_autonomously.sh [--rebuild]'

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
SCRIPTS="$REPO_ROOT/emulator/hil/scripts"

VMSTORE="${VMSTORE:-/mnt/vmstore}"
LIBVIRT_IMAGES="$VMSTORE/libvirt-images"
DOMAIN="${DOMAIN:-win10-ltsc-nikonscan}"
# Use Microsoft's original eval ISO. We tried re-mastering it to remove the
# "Press any key to boot from CD..." prompt (build_no_prompt_iso.sh), but
# OVMF rejects naive single-entry UEFI El Torito catalogs — Microsoft's
# layout has both BIOS and UEFI El Torito entries and OVMF expects that
# structure. Defer the proper re-master; for now bypass the prompt with
# silent virsh send-key spam (see step 5 below).
ORIG_ISO="$LIBVIRT_IMAGES/26100.1742.240906-0331.ge_release_svc_refresh_CLIENT_IOT_LTSC_EVAL_x64FRE_en-us.iso"
WIN_ISO="${WIN_ISO:-$ORIG_ISO}"
VIRTIO_ISO="${VIRTIO_ISO:-$LIBVIRT_IMAGES/virtio-win.iso}"
AUTO_ISO="${AUTO_ISO:-$LIBVIRT_IMAGES/autounattend.iso}"
POST_ISO="${POST_ISO:-$LIBVIRT_IMAGES/postinstall.iso}"
INSTALL_TIMEOUT_S="${INSTALL_TIMEOUT_S:-3600}"  # 1 hour upper bound
RAM_MIB="${RAM_MIB:-4096}"
VCPUS="${VCPUS:-4}"
DISK_GIB="${DISK_GIB:-60}"
POOL="${POOL:-vmstore}"

REBUILD=0
for arg in "$@"; do
    case "$arg" in
        --rebuild) REBUILD=1 ;;
        *) echo "unknown flag: $arg" >&2; exit 2 ;;
    esac
done

step() { echo ""; echo "==[ $* ]=="; }

# Detect VNC listen address: prefer Tailscale IP, fall back to loopback.
# Lets you watch the unattended install over Tailscale without an SSH tunnel.
VNC_LISTEN="${VNC_LISTEN:-}"
if [[ -z "$VNC_LISTEN" ]] && command -v tailscale >/dev/null 2>&1; then
    VNC_LISTEN=$(tailscale ip -4 2>/dev/null | head -1 || true)
fi
VNC_LISTEN="${VNC_LISTEN:-127.0.0.1}"

# -----------------------------------------------------------------------------
# CRITICAL ORDERING: verify ISOs *before* any destructive action below.
# The vol-delete in step 4 cannot un-delete a missing ISO; we'd have to
# re-download GBs of media. Sanity-check first.
step "1. Verify ISOs"
[[ -f "$WIN_ISO" ]] || { echo "FATAL: missing Win ISO at $WIN_ISO" >&2; exit 1; }
"$SCRIPTS/verify_iso.sh" "$WIN_ISO"

# Need virtio-win for both autounattend (driver inject) and post-install (msi).
if [[ ! -f "$VIRTIO_ISO" ]]; then
    step "Fetching virtio-win.iso"
    curl -L -o "$VIRTIO_ISO" \
        "https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/stable-virtio/virtio-win.iso"
fi
[[ -f "$VIRTIO_ISO" ]] || { echo "FATAL: virtio-win.iso missing after fetch attempt" >&2; exit 1; }

# -----------------------------------------------------------------------------
step "2. Build autounattend ISO"
"$SCRIPTS/build_autounattend_iso.sh"

step "3. Build post-install ISO"
"$SCRIPTS/build_postinstall_iso.sh"

# -----------------------------------------------------------------------------
step "4. Wipe existing domain (if --rebuild)"
if [[ "$REBUILD" == "1" ]] && virsh -c qemu:///system list --all --name | grep -qx "$DOMAIN"; then
    virsh -c qemu:///system destroy "$DOMAIN" 2>/dev/null || true
    # Undefine WITHOUT --remove-all-storage: that flag deletes every managed
    # volume in the domain, including ISO CDROMs that we want to keep.
    # Then explicitly delete only the qcow2 disk that belongs to this VM.
    virsh -c qemu:///system undefine --nvram "$DOMAIN"
    virsh -c qemu:///system vol-delete --pool "$POOL" "$DOMAIN.qcow2" 2>/dev/null || true
fi

if virsh -c qemu:///system list --all --name | grep -qx "$DOMAIN"; then
    echo "FATAL: domain '$DOMAIN' already exists. Pass --rebuild to wipe it." >&2
    exit 2
fi

# -----------------------------------------------------------------------------
step "5. virt-install (autonomous; --noautoconsole)"
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
    --cdrom "$WIN_ISO" \
    --disk path="$AUTO_ISO",device=cdrom,bus=sata \
    --disk path="$VIRTIO_ISO",device=cdrom,bus=sata \
    --disk path="$POST_ISO",device=cdrom,bus=sata \
    --channel unix,target.type=virtio,target.name=org.qemu.guest_agent.0 \
    --osinfo win11 \
    --graphics "vnc,listen=$VNC_LISTEN,port=5900" \
    --console pty,target.type=serial \
    --noautoconsole

echo "VM '$DOMAIN' started. The Windows installer is running unattended."
echo "Watch the VNC display: vnc://$VNC_LISTEN:5900"

# Silent background keypress spam to bypass the "Press any key to boot
# from CD..." prompt. cdboot.efi shows the prompt for ~5 s and exits if
# no key is pressed. We send spaces every second for 30 s then stop —
# any presses after Windows Setup loads are harmless (Setup ignores
# spurious keystrokes during file copy).
( for _ in $(seq 1 30); do
      virsh -c qemu:///system send-key "$DOMAIN" KEY_SPACE >/dev/null 2>&1 || true
      sleep 1
  done ) &
KEYSPAM_PID=$!
echo "  (background keypress spam pid=$KEYSPAM_PID, lifespan ~30 s)"

# -----------------------------------------------------------------------------
step "6. Wait for postinstall.cmd to shutdown the VM"
echo "  (timeout: $((INSTALL_TIMEOUT_S / 60)) minutes)"
# False-positive guard: VM may transition through "shut off" briefly during
# `virsh reset` or other reboots. We require:
#   1. qcow2 actual usage > 8 GB (Windows install copied real files)
#   2. THREE consecutive 30 s polls reporting "shut off" (not a transient blip)
DISK_PATH="/mnt/vmstore/libvirt-images/$DOMAIN.qcow2"
MIN_INSTALLED_BYTES=$((8 * 1024 * 1024 * 1024))  # 8 GiB
deadline=$(($(date +%s) + INSTALL_TIMEOUT_S))
shutoff_streak=0
while [[ $(date +%s) -lt $deadline ]]; do
    state=$(virsh -c qemu:///system domstate "$DOMAIN" 2>&1 || true)
    actual_bytes=$(du -B1 --apparent-size=no "$DISK_PATH" 2>/dev/null | awk '{print $1}')
    actual_bytes=${actual_bytes:-0}
    case "$state" in
        "shut off"|"shutdown")
            shutoff_streak=$((shutoff_streak + 1))
            if [[ "$actual_bytes" -lt "$MIN_INSTALLED_BYTES" ]]; then
                printf "  [shutoff #%d, but qcow2 only %dMB — likely transient reset]\n" \
                    "$shutoff_streak" "$((actual_bytes / 1024 / 1024))"
                sleep 30
                continue
            fi
            if [[ "$shutoff_streak" -ge 3 ]]; then
                echo "  VM has shut down (sustained, qcow2 $((actual_bytes / 1024 / 1024 / 1024))GB) — install complete."
                break
            fi
            printf "  [shutoff #%d/3 with qcow2 %dGB — confirming sustained]\n" \
                "$shutoff_streak" "$((actual_bytes / 1024 / 1024 / 1024))"
            sleep 30
            ;;
        "running"|"in shutdown")
            shutoff_streak=0
            sleep 30
            elapsed=$(( $(date +%s) - (deadline - INSTALL_TIMEOUT_S) ))
            printf "  [%dm %ds] %s, qcow2 %dMB\n" \
                $((elapsed / 60)) $((elapsed % 60)) "$state" "$((actual_bytes / 1024 / 1024))"
            ;;
        *)
            echo "  unexpected domstate: $state" >&2
            sleep 30
            ;;
    esac
done

state=$(virsh -c qemu:///system domstate "$DOMAIN")
actual_bytes=$(du -B1 --apparent-size=no "$DISK_PATH" 2>/dev/null | awk '{print $1}')
actual_bytes=${actual_bytes:-0}
if [[ "$state" != "shut off" && "$state" != "shutdown" ]]; then
    echo "FATAL: VM did not shut down within ${INSTALL_TIMEOUT_S}s. State: $state" >&2
    echo "       Check VNC for stuck installer / OOBE prompt." >&2
    exit 3
fi
if [[ "$actual_bytes" -lt "$MIN_INSTALLED_BYTES" ]]; then
    echo "FATAL: VM is shutoff but qcow2 only $((actual_bytes / 1024 / 1024))MB — Windows install never ran." >&2
    echo "       Common causes: boot prompt timed out; OOBE blocked; broken Autounattend." >&2
    exit 4
fi

# -----------------------------------------------------------------------------
step "7. Detach install media so the VM boots from disk going forward"
# Eject the install ISO + autounattend so reboots don't loop the installer.
# Keep virtio-win.iso + postinstall.iso attached; they're benign.
for target in sda sdb sdc sdd sde; do
    virsh -c qemu:///system change-media "$DOMAIN" "$target" --eject 2>/dev/null || true
done
# More robust: rewrite the domain XML to drop the install + autounattend cdroms.
TMP_XML=$(mktemp /tmp/win10-xml.XXXXXX.xml)
virsh -c qemu:///system dumpxml --inactive "$DOMAIN" > "$TMP_XML"
# Strip the disk lines for the install + autounattend ISOs (matched by file path).
python3 - "$TMP_XML" "$WIN_ISO" "$AUTO_ISO" <<'PY'
import os, sys, xml.etree.ElementTree as ET
xml_path, *iso_paths = sys.argv[1:]
# Match by basename — libvirt may canonicalize the source path differently
# (symlinks, trailing slashes, ./, etc.) than what we passed to virt-install.
iso_basenames = {os.path.basename(p) for p in iso_paths}
tree = ET.parse(xml_path); root = tree.getroot()
devices = root.find('devices')
to_drop = []
for disk in devices.findall('disk'):
    src = disk.find('source')
    if src is None: continue
    f = src.get('file', '')
    if os.path.basename(f) in iso_basenames:
        to_drop.append(disk)
for d in to_drop:
    devices.remove(d)
tree.write(xml_path, xml_declaration=True, encoding='utf-8')
print(f"  dropped {len(to_drop)} install/autounattend cdrom(s)")
PY
virsh -c qemu:///system define "$TMP_XML"
rm -f "$TMP_XML"

# -----------------------------------------------------------------------------
step "8. Snapshot the freshly-built VM"
SNAP_NAME="pristine-install"
SNAP_DESC="Win11 IoT LTSC 2024 + VirtIO + qemu-ga + usbip-win2 + system policies (autonomous build)"
virsh -c qemu:///system snapshot-create-as "$DOMAIN" "$SNAP_NAME" --description "$SNAP_DESC"
virsh -c qemu:///system snapshot-list "$DOMAIN"

echo ""
echo "Done. VM '$DOMAIN' is shut off with snapshot '$SNAP_NAME'."
echo ""
echo "Inspect post-install log via libguestfs or by booting and reading C:\postinstall.log."
echo "If NikonScan silent install failed, finish manually:"
echo "  virsh -c qemu:///system start $DOMAIN"
echo "  # walk through the NikonScan installer, configure C:\\scans, shutdown, then:"
echo "  virsh -c qemu:///system snapshot-create-as $DOMAIN nikonscan-installed --description '+NikonScan'"
