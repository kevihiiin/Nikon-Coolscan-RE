# Windows side: install `usbip-win2` and attach the emulator

Tested with `usbip-win2` v0.9.7.7 (released 2026-04-21). Newer versions
should work but the install procedure may differ — check the release
notes if you hit anything unexpected.

## Install `usbip-win2`

1. Download the latest `usbip-win2` installer from
   <https://github.com/vadimgrn/usbip-win2/releases/latest>.
2. Run it as Administrator. The installer creates a system restore
   point automatically.
3. The driver is **attestation-signed** by Microsoft — installation works
   on stock Windows 10 1903+ and Windows 11 without enabling Test
   Signing Mode (no `bcdedit /set testsigning on` needed).
4. If you have a USB 3.0 hub on the Windows machine, expect it to
   restart during installation. This is documented behaviour.

The PowerShell helper `scripts/install_usbip_win2.ps1` automates these
steps if you want a one-command install. Run it from an elevated
PowerShell session.

## Attach the emulator

With the emulator running on the Linux host:

```powershell
PS> usbip list -r 192.168.1.42
Exportable USB devices
======================
 - 192.168.1.42
        1-1: Nikon Corp. : LS-50 ED (04b0:4001)
           : /sys/bus/usbip/1-1
           : (Defined at Interface level) (00/00/00)
           :  0 - Vendor Specific Class / Vendor Specific Subclass / Vendor Specific Protocol (ff/ff/ff)

PS> usbip attach -r 192.168.1.42 -b 1-1
succesfully attached to port 0
```

Replace `192.168.1.42` with your Linux host's IP.

Open Windows Device Manager. You should see a new device appear under
"Nikon" or "Imaging Devices" depending on what NikonScan installed.

## Detach when done

```powershell
PS> usbip port
Imported USB devices
====================
Port 00: <Port in Use> at Hi-Speed (480 Mbps)
       Nikon Corp. : LS-50 ED (04b0:4001)
       0-0  -> usbip://192.168.1.42:3240/1-1
           -> remote bus/dev 001/001

PS> usbip detach -p 0
port 0 is succesfully detached
```

## Use NikonScan

1. Install NikonScan 4.0.3 if not already present. The installer
   provides the driver INF that claims VID 04B0 / PID 4001.
2. Launch Nikon Scan (or any TWAIN host that imports the Coolscan TWAIN
   data source).
3. Choose the Coolscan as the scan source. The emulator log on Linux
   shows the INQUIRY exchange first, followed by mode/calibration and
   eventually scan commands.

## Troubleshooting

See `troubleshooting.md` for detailed debugging steps. Quick checks:

- Device doesn't appear in `usbip list -r` → emulator not running, port
  3240 firewalled, or wrong IP.
- `usbip attach` fails with "Operation not permitted" → run PowerShell
  as Administrator.
- Device appears but Windows shows "Unknown Device" → NikonScan not
  installed; the driver INF is what claims the VID/PID.
- NikonScan opens but says "no scanner found" → INQUIRY response is
  reaching the driver but format may be subtly wrong. Capture USBPcap
  trace and compare against the firmware's INQUIRY template at flash
  offset `0x170CE`.
