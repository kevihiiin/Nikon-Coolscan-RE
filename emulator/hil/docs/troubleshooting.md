# HIL troubleshooting

## "Bind failed: Address already in use" on `--usbip-server`

The default port 3240 is taken. Either:

- Stop whatever is using it: `sudo ss -lntp | grep 3240`
- Pass a different port: `--usbip-port 13240`

The integration test always uses an ephemeral port to avoid this.

## "device 1-1 not found" on `usbip attach`

The emulator is running but its USB/IP server is not reachable from the
Windows VM. Check in this order:

1. `nc -zv <linux-host-ip> 3240` from any other machine.
2. `sudo ufw status` on Linux — port 3240 may be blocked by the firewall.
3. Hypervisor network mode — `host-only` networks may not route between
   the host and a Windows guest depending on settings.
4. `--usbip-bind 0.0.0.0` rather than `127.0.0.1`. The default in
   `Config::test_default` is `127.0.0.1` for safety; the CLI default is
   `0.0.0.0` for HIL use.

## INQUIRY succeeds but NikonScan still doesn't see the scanner

The driver claimed the device (visible in Device Manager) but NikonScan
doesn't enumerate it. Most likely cause:

- NikonScan is filtering by INQUIRY contents. Compare the response in
  the emulator log against the expected `"Nikon   LS-50 ED        1.02"`.
- The INQUIRY-specific patch restoration in `poll_usbip` only covers
  INQUIRY itself. Subsequent commands (MODE SENSE, REQUEST SENSE,
  vendor-specific 0xC1/0xE0/0xE1) may need similar restorations. This is
  M15 territory — capture a USBPcap trace on the Windows side and report
  what command fails.

## "EP1 OUT FIFO underrun" warnings

A single-CDB injection depletes after the first firmware read; subsequent
reads see zeros. M14.5's `poll_usbip` works around this by routing
through `scsi_command` which pads to 384 bytes. If you see this warning
*outside* the dispatcher (e.g. during boot), it's likely a different
firmware code path reading EP1 OUT spuriously — log the PC and report.

## `cargo build` fails with libusb errors

The `usbip` crate depends on `nusb` + `rusb` which need libusb headers
on the build host:

```bash
sudo apt install libusb-1.0-0-dev          # Debian / Ubuntu
sudo dnf install libusbx-devel              # Fedora / RHEL
brew install libusb                         # macOS
```

## "Driver signature failed" on Windows

You may have downloaded an unsigned development build. Make sure you
grabbed the official release from
<https://github.com/vadimgrn/usbip-win2/releases/latest>; releases are
attestation-signed and install without enabling Test Signing Mode on
modern Windows.

If you genuinely need to use a test-signed build, enable Test Signing
Mode:

```powershell
PS> bcdedit /set testsigning on
PS> shutdown /r /t 0
```

Disable when done:

```powershell
PS> bcdedit /set testsigning off
```

## Smoke test hangs or times out

`cargo test --test smoke_usbip_e2e` should complete in 5-10 seconds. If
it times out:

- The emulator subprocess never bound the port → check that
  `cargo build --release --bin coolscan-emu` finished successfully and
  produced the binary at `target/release/coolscan-emu`.
- The firmware never reached main loop within the 30M instruction cap
  → bump `--max` in the test or run on a faster machine.

## "Write to read-only flash" warnings during boot

Cosmetic. The firmware writes to RAM-shadowed regions during early init
and the emulator's memory bus warns about it. The behaviour is harmless
and pre-existing (not introduced by M14.5). If you find it noisy, set
`RUST_LOG=warn,h8300h_core::memory=error` to silence specifically those
warnings.

## "Device disconnects immediately after enumeration"

This is the documented `usbip-vudc` kernel bug from September 2025. If
you're seeing it on the userspace path (i.e. with `--usbip-server`),
that's a new issue — please file with the captured USBPcap trace. The
userspace path uses entirely different code from `usbip-vudc` and
shouldn't exhibit this.
