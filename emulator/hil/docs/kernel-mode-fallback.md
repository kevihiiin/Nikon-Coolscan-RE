# Kernel-mode HIL via `usbip-vudc` + FunctionFS (advanced)

**Recommendation: don't use this path.** Use `--usbip-server` (described in
the parent `README.md`) instead. This document exists for completeness
and for users with specific needs that the userspace path can't meet.

## Known issues

- **Disconnect after enumeration**: A bug documented in
  <https://github.com/VirtualBox/virtualbox/issues/192> (September 2025)
  causes the kernel `usbip-vudc` server to drop the connection
  immediately after the host completes USB enumeration. The userspace
  path uses different code and avoids this.
- **Requires `sudo`**: every `modprobe`, every configfs write, every
  `usbipd` start needs root.
- **Distro module availability**: `usbip-vudc` is in the standard Ubuntu
  kernel (verified on 24.04). It is *not* shipped with the WSL2 default
  kernel — that path requires a custom kernel build.

## Why you might still want it

- Maximum fidelity: the Linux USB stack sits between the firmware and
  the USB/IP transport, so any quirks introduced by the kernel are
  exercised.
- Compatibility with USB/IP clients that don't speak the userspace
  server's flavour of the protocol — though in practice the wire
  format is identical and `usbip-win2` works with both.
- Pairing with the Linux `vhci-hcd` on the same host for self-loopback
  protocol research.

## Setup procedure

This is a sketch, not an automated script. M14.5 deliberately did not
ship `hil-setup.sh` etc. for this path because the userspace alternative
makes it unnecessary. If you really want the kernel-mode setup, here is
the sequence; adapt to your distro:

```bash
# 1. Verify modules are present.
modinfo usbip-vudc usbip-host vhci-hcd libcomposite usb_f_fs

# 2. Mount configfs and load modules. Needs root.
sudo mount -t configfs none /sys/kernel/config 2>/dev/null || true
sudo modprobe libcomposite usb_f_fs usbip-vudc

# 3. Verify a virtual UDC appeared.
ls /sys/class/udc/                    # expect: usbip-vudc.0

# 4. Run the emulator with --gadget pinned to the virtual UDC.
#    coolscan-emu's GadgetBridge will create the configfs tree and
#    bind to the UDC the same way it does on a Pi.
sudo cargo run --release -- \
    --gadget \
    --firmware-dispatch \
    --full-usb-init

# 5. In another shell, bind for export and start usbipd.
sudo modprobe usbip-host
sudo usbipd -D
busid=$(usbip list -l | awk '/04b0:4001/{getline; print $1}' | tr -d ':')
sudo usbip bind -b "$busid"

# 6. Print the import command for the Windows side.
echo "From Windows: usbip attach -r $(hostname -I | awk '{print $1}') -b $busid"
```

## Cleanup

```bash
sudo usbip unbind -b "$busid"
sudo pkill usbipd
sudo rmmod usbip-vudc
```

## When this path makes sense

If you're researching low-level USB stack behaviour and need every byte
to traverse the real Linux USB layer between the firmware and the wire,
this is the only way. For driver development, scan-pipeline iteration,
and most NikonScan compatibility work, the userspace `--usbip-server`
path is faster, less fragile, and produces equivalent observable
behaviour at the host level.
