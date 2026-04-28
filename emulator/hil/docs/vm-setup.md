# Win LTSC VM setup runbook

End-to-end: from a fresh Linux host with qemu installed to a snapshotted
Win VM that NikonScan + the agent harness can drive against the emulator.

**Estimated time**: ~90 minutes (most of it is the Windows installer GUI).

## What you'll end up with

- libvirt storage pool `vmstore` at `/mnt/vmstore/libvirt-images`
- libvirt domain `win10-ltsc-nikonscan` (4 GB RAM, 4 vCPU, 60 GB sparse qcow2,
  Q35 + UEFI + TPM 2.0, VirtIO disk/net, qemu-guest-agent over virtio-serial)
- A `pristine-install` snapshot — Windows + VirtIO drivers only (cheap to
  re-roll from)
- A `nikonscan-installed` snapshot — Windows + qemu-ga + usbip-win2 +
  NikonScan 4.0.3 (the snapshot recipes revert to between runs)

## ISO acquisition (CHOOSE ONE)

Microsoft retired the **Windows 10 Enterprise LTSC 2021** evaluation
download in late 2025 (eval-center page now redirects to a Win11 migration
blog post). Two paths remain:

### A. Windows 11 IoT Enterprise LTSC 2024 — 90-day Evaluation (recommended; currently downloadable from Microsoft)

1. In a browser, open
   <https://www.microsoft.com/en-us/evalcenter/download-windows-11-iot-enterprise-ltsc-eval>.
   Fill the registration form (any sensible answers — the eval doesn't
   require a product key).
2. Pick **English (en-US)**, **64-bit (x64)**.
3. Microsoft hands you a download URL on
   `software-static.download.prss.microsoft.com/dbazure/<token>/...iso` —
   the token in the URL is opaque and the URL stays valid as long as the
   ISO release does. Save it; it's the same URL across machines. Either:
   - Download via the browser, then `mv ~/Downloads/...iso /mnt/vmstore/libvirt-images/`, or
   - On the dev box: `curl -L -C - -o /mnt/vmstore/libvirt-images/<filename>.iso "<URL>"`
4. Verify integrity:
   ```
   emulator/hil/scripts/verify_iso.sh /mnt/vmstore/libvirt-images/<filename>.iso
   ```
   The script auto-picks the expected SHA-256 from the filename pattern.

Eval ISO filename: `26100.1742.240906-0331.ge_release_svc_refresh_CLIENT_IOT_LTSC_EVAL_x64FRE_en-us.iso`
Eval ISO size: 5,060,020,224 bytes (4.713 GB)
Eval ISO SHA-256: `2cee70bd183df42b92a2e0da08cc2bb7a2a9ce3a3841955a012c0f77aeb3cb29`
osinfo variant: `win11`

(For activated, non-eval Win11 IoT LTSC 2024 from a Microsoft Volume License,
filename `X23-81951_..._CLIENT_ENTERPRISES_OEM_x64FRE_en-us.iso` with
SHA-256 `4f59662a96fc1da48c1b415d6c369d08af55ddd64e8f1c84e0166d9e50405d7a`
is also recognized by `verify_iso.sh`.)

### B. Windows 10 Enterprise LTSC 2021 (only via VLSC / Visual Studio
    Subscriptions)

If you have access to Microsoft's Volume Licensing Service Center or a
Visual Studio subscription:
1. Download the LTSC 2021 ISO from there.
2. Place at `/mnt/vmstore/libvirt-images/win10-ltsc-2021.iso`.
3. Verify:
   ```
   emulator/hil/scripts/verify_iso.sh /mnt/vmstore/libvirt-images/win10-ltsc-2021.iso
   ```

The verify script knows the eval-center filename hash. Volume-licensing
ISOs have different filenames + hashes (Microsoft publishes them to VLSC
subscribers); pass the hash explicitly:
```
verify_iso.sh /mnt/vmstore/libvirt-images/win10-ltsc-2021.iso <sha256-from-VLSC>
```

osinfo variant: `win10`

## One-time host prep

```
emulator/hil/scripts/setup_dev_box.sh
```

This installs qemu/libvirt/virt-manager, adds you to the `libvirt` and
`kvm` groups, brings up the libvirt `default` NAT network, and creates the
`vmstore` storage pool. Idempotent.

After it finishes, **fully log out and back in** (group membership only
takes effect at login). Verify:
```
virsh -c qemu:///system list --all       # no error
virsh -c qemu:///system net-list         # `default` active
virsh -c qemu:///system pool-list        # `vmstore` active
```

## Create the VM

### Option A — Autonomous build (recommended)

One command builds the VM end-to-end (~25-30 min unattended): Windows
installer, OOBE bypass, user creation, VirtIO drivers, qemu-guest-agent,
usbip-win2, system-policy tweaks, optional silent NikonScan, then a
`pristine-install` snapshot:

```
sg libvirt -c 'emulator/hil/scripts/build_vm_autonomously.sh --rebuild'
```

What it orchestrates (all idempotent, all in-repo):

1. `verify_iso.sh` — confirms the Win ISO matches Microsoft's published SHA-256
2. `download_usbip_win2.sh` — fetches the latest `USBip-x64.exe` release from `vadimgrn/usbip-win2`
3. `build_autounattend_iso.sh` — packs `Autounattend.xml` + `$WinPEDriver$/viostor` (extracted from `virtio-win.iso`) into a small CDROM Windows Setup auto-discovers at boot
4. `build_postinstall_iso.sh` — bundles `postinstall.cmd` + the usbip installer + the extracted NikonScan installer tree into a second CDROM
5. `virt-install` with all CDROMs attached and the `vmstore`-pool qcow2; VM boots from the Win ISO, autounattend takes over from the language picker onward
6. `FirstLogonCommands` runs `postinstall.cmd` from the post-install CDROM. Logs to `C:\postinstall.log`
7. After `shutdown /s` from inside the VM, the host detects power-off, detaches install media from the persistent XML, snapshots as `pristine-install`

Watch progress via VNC at the host's Tailscale IP (script binds the VM's
graphics there automatically; falls back to `127.0.0.1` if Tailscale isn't
running).

The NikonScan silent install is best-effort. The 2003 InstallShield
honors `/S` on some builds but not all. If it fails, the rest of the
build still completes; finish manually:

```
sg libvirt -c 'virsh -c qemu:///system start win10-ltsc-nikonscan'
# VNC in, walk the NikonScan installer interactively, configure C:\\scans\\,
# then shutdown the VM and:
sg libvirt -c '
  virsh -c qemu:///system snapshot-create-as win10-ltsc-nikonscan nikonscan-installed \
    --description "+NikonScan 4.0.3 manually"
'
```

Re-roll path (when the eval expires after 90 days, or if the snapshot rots):

```
sg libvirt -c 'emulator/hil/scripts/re_roll_vm.sh'
sg libvirt -c 'emulator/hil/scripts/build_vm_autonomously.sh --rebuild'
```

### Option B — Manual build (fallback if autounattend trips)

If the autonomous build hangs at an OOBE prompt that Win11's current
build interprets differently (Microsoft tightens MS-account screens
periodically), `win_vm_create.sh` is the manual path:

```
ISO_PATH=/mnt/vmstore/libvirt-images/26100.1742.240906-0331.ge_release_svc_refresh_CLIENT_IOT_LTSC_EVAL_x64FRE_en-us.iso \
DOMAIN=win10-ltsc-nikonscan \
OS_VARIANT=win11 \
emulator/hil/scripts/win_vm_create.sh
```

(Domain name stays `win10-ltsc-nikonscan` regardless of OS — every
existing reference in the agent harness uses it.)

`virt-install` defines the domain and starts the installer. Connect with
either of:
```
virt-viewer --connect qemu:///system win10-ltsc-nikonscan
vncviewer 127.0.0.1:5900
```

## Manual installer steps (~30 min)

This is the only un-automated part. The Windows installer is graphical
and asks for a few clicks/answers.

1. **Boot from the LTSC ISO** (auto).
2. **Language**: English (United States).
3. **Install now → I don't have a product key** (eval doesn't need one).
4. **Edition**: pick the LTSC variant. **Custom: Install Windows only**.
5. **Drive selection**: when no disks appear (VirtIO is unsupported by the
   Windows installer out of the box), click **Load driver** → browse to
   the `virtio-win` CD-ROM → `viostor\<edition>\amd64` → install. Drive
   appears, select it, **Next**.
6. **Wait for the install** (~10 min on NVMe).
7. **Out-of-box experience**: choose **Domain join instead** (Windows 11
   asks for a Microsoft account by default; this bypasses it). Local
   user: name `coolscan`, blank password.
8. **First boot to desktop**.

### Inside the running VM

Open `cmd.exe` as Admin (Win+R → `cmd` → Ctrl+Shift+Enter) and run:

```cmd
:: 9. Install all VirtIO drivers (one click)
D:\virtio-win-gt-x64.msi  /quiet

:: 10. Install qemu-guest-agent
D:\guest-agent\qemu-ga-x86_64.msi  /quiet

:: 11. Disable Windows Update (LTSC; gpedit also works)
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" /v NoAutoUpdate /t REG_DWORD /d 1 /f

:: 12. Disable screen lock + standby (recipes need a constant display)
powercfg /change monitor-timeout-ac 0
powercfg /change standby-timeout-ac 0
powercfg /change hibernate-timeout-ac 0

:: 13. Disable Windows Defender real-time scan
:: (Win11 requires tamper-protection off first via Settings > Privacy & security)
powershell -Command "Set-MpPreference -DisableRealtimeMonitoring $true"

:: 14. Sync clock with NTP
w32tm /config /manualpeerlist:"time.windows.com,0x9" /syncfromflags:manual /reliable:YES /update
net stop w32time && net start w32time
w32tm /resync

:: 15. Create the scan-output directory recipes will assert against
mkdir C:\scans
```

### Pristine snapshot

Power down cleanly: **Start → Power → Shut down**. Then on the host:
```
virsh -c qemu:///system snapshot-create-as win10-ltsc-nikonscan pristine-install \
    --description "Win + VirtIO + qemu-ga + power/clock policies"
```

(If anything goes wrong with the next steps, revert here and try again.)

### Install usbip-win2 + NikonScan

Boot the VM (`virsh start`).

1. Copy `emulator/hil/scripts/install_usbip_win2.ps1` into the guest (drag
   into the VNC window, or via virtio-serial / shared folder if configured).
2. In an elevated PowerShell:
   ```powershell
   Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
   .\install_usbip_win2.ps1
   ```
   This downloads + installs the latest `usbip-win2` release from
   `github.com/vadimgrn/usbip-win2/releases/latest`. The driver is
   attestation-signed; no Test Signing Mode required.
3. Mount the NikonScan installer ISO (the host has it at
   `binaries/software/NikonScan403.iso`). Drag-drop into the VM, or attach
   via libvirt:
   ```
   virsh -c qemu:///system attach-disk win10-ltsc-nikonscan \
       /home/ky/projects/Nikon-Coolscan-RE/binaries/software/NikonScan403.iso \
       sdc --type cdrom --mode readonly --persistent
   ```
4. In the VM, run the NikonScan installer. Accept defaults; finish the
   first-run wizard (EULA, language, registration nag — bake these out now).
5. Open NikonScan once. **Edit → Preferences → Save Folder** → `C:\scans\`.
6. Quit NikonScan cleanly.
7. Detach the NikonScan ISO:
   ```
   virsh -c qemu:///system detach-disk win10-ltsc-nikonscan sdc --persistent
   ```

### Snapshot `nikonscan-installed`

Power down cleanly. Then:
```
virsh -c qemu:///system snapshot-create-as win10-ltsc-nikonscan nikonscan-installed \
    --description "Pristine + usbip-win2 + NikonScan 4.0.3 + scans/ folder configured"
```

## Verify the VM end-to-end

In one terminal, start the emulator's USB/IP server:
```
cd emulator
cargo run --release -- --usbip-server --usbip-bind 127.0.0.1 --firmware-dispatch
```

In another, bring up the VM and attach the scanner:
```
virsh -c qemu:///system snapshot-revert win10-ltsc-nikonscan nikonscan-installed
virsh -c qemu:///system start win10-ltsc-nikonscan
# Wait ~30 s for boot; qemu-ga becomes responsive after that.
cd emulator/hil/agent
uv run coolscan-hil vm status      # should report state=running, qemu_ga_responsive=true
```

In the VM (PowerShell, elevated):
```
usbip list -r 192.168.122.1
# Should show:  1-1: Nikon Corp. : LS-50 ED          (04b0:4001)
usbip attach -r 192.168.122.1 -b 1-1
# Device Manager should now show "Nikon LS-50".
```

Open NikonScan, pick the Coolscan as the TWAIN source. INQUIRY traffic
should appear in the host emulator's stdout. **This is M15's
manual-operator exit criterion.**

## Re-rolling

Win11 LTSC 2024 evaluation runs for 90 days, then nags + hourly shutdowns.
Win10 LTSC 2021 from VLSC is permanently activated against your VL key —
no re-roll needed.

When the eval expires (or the snapshot rots after a host kernel/libvirt
upgrade):
```
emulator/hil/scripts/re_roll_vm.sh
# Then re-do the manual install steps above.
```

The cached ISO at `/mnt/vmstore/libvirt-images/<...>.iso` is reused —
re-roll is roughly 30 min, not the original 90.

## Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `virsh` says `Permission denied on /var/run/libvirt/libvirt-sock` | not in libvirt group, or no relogin | `sudo usermod -aG libvirt $USER` then **fully log out** |
| `virt-install` errors about TPM | Win11 LTSC needs TPM 2.0; libvirt's `swtpm` is the right backend | `apt install swtpm swtpm-tools` (already in setup_dev_box.sh) |
| Windows installer can't find drives | VirtIO disk driver not loaded | from the installer's "Where do you want to install Windows" screen, **Load driver** → `viostor` |
| Win11 installer demands MS account | "Domain join instead" trick | from the OOBE network screen, hit Shift+F10, run `OOBE\BYPASSNRO` (or for newer Win11 builds, `start ms-cxh:localonly`) |
| `usbip list -r 192.168.122.1` says "Connection refused" | emulator not listening on host's libvirt-default-bridge IP | start the emulator with `--usbip-bind 192.168.122.1` instead of `127.0.0.1`, OR adjust the libvirt network to forward 3240 |
| Device shows in Device Manager as "Unknown Device" | NikonScan driver not installed yet | NikonScan supplies the INF; ensure it's installed inside the VM |
| Eval expires 90 days from install | inevitable | `re_roll_vm.sh` |
