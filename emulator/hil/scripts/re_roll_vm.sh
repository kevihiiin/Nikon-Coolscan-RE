#!/usr/bin/env bash
# Re-roll the HIL VM from scratch. Use when:
#   - the 90-day Win11 LTSC eval expires
#   - the snapshot has rotted (e.g., kernel changes broke virtio drivers)
#   - someone messed up the VM and we want a clean build
#
# Steps:
#   1. virsh destroy + undefine the existing domain
#   2. delete the qcow2 disk
#   3. re-run win_vm_create.sh
#   4. operator does the manual install (vm-setup.md)
#   5. operator re-snapshots as 'nikonscan-installed'

set -euo pipefail

DOMAIN="${DOMAIN:-win10-ltsc-nikonscan}"

echo "This will DESTROY VM '$DOMAIN' and all of its storage volumes."
read -r -p "Type 'rebuild' to confirm: " confirm
[[ "$confirm" == "rebuild" ]] || { echo "aborted"; exit 1; }

# Undefine WITHOUT --remove-all-storage: that flag deletes every managed
# volume in the domain, including ISO CDROMs that should be kept across
# rebuilds. Delete only the VM's qcow2 disk explicitly.
if virsh -c qemu:///system list --all --name | grep -qx "$DOMAIN"; then
    virsh -c qemu:///system destroy "$DOMAIN" 2>/dev/null || true
    virsh -c qemu:///system undefine --nvram "$DOMAIN"
    virsh -c qemu:///system vol-delete --pool vmstore "$DOMAIN.qcow2" 2>/dev/null || true
fi

echo "VM cleared. Re-running win_vm_create.sh..."
exec "$(dirname "$0")/win_vm_create.sh" "$@"
