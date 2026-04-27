# HIL — Hardware-in-the-Loop testing for the Coolscan emulator

This crate stands the emulator up as a USB device that NikonScan (running
in a Windows VM) can talk to, with **no Raspberry Pi, no kernel modules,
and no `sudo`**. It also provides the test harness used by the M14.5 smoke
test (`coolscan-emu/tests/smoke_usbip_e2e.rs`).

## What this gets you

- A running `coolscan-emu` exposes itself on TCP :3240 as a USB/IP
  server. Anything that speaks the USB/IP protocol can attach to it and
  see a fully simulated Nikon LS-50 (VID 04B0, PID 4001).
- On Windows, `usbip-win2` (a free attestation-signed driver) attaches
  the device into Windows Device Manager. NikonScan 4.0.3 then uses it
  exactly like a physical scanner plugged in via USB.
- The whole pipeline can be exercised end-to-end on one Linux box via
  `cargo test --test smoke_usbip_e2e` — no Windows needed for the
  protocol-level smoke test.

## Two-machine quickstart

### Linux side (this machine, no `sudo`)

```bash
cargo run --release -- \
    --usbip-server \
    --usbip-bind 0.0.0.0 \
    --usbip-port 3240 \
    --firmware-dispatch
```

Last log line before instruction-level chatter:

    Transports: gadget=off usbip=active (0.0.0.0:3240) tcp=active (port 6581)

### Windows side (one-time setup)

1. Install `usbip-win2` (vadimgrn fork) on the Windows VM from
   <https://github.com/vadimgrn/usbip-win2/releases/latest>.
   Drivers are attestation-signed — no Test Signing Mode needed on
   Windows 10 1903+ or Windows 11.
2. Allow TCP port 3240 through any firewall between the Linux host and
   the Windows VM.

### Attach + scan

```powershell
PS> usbip list -r <linux-host-ip>
   1-1: Nikon Corp. : LS-50 ED          (04b0:4001)

PS> usbip attach -r <linux-host-ip> -b 1-1
```

Device Manager shows "Nikon LS-50". Open NikonScan; INQUIRY traffic
appears in the emulator log.

To detach:

```powershell
PS> usbip detach -p <port>
```

## Why this is the recommended HIL path

| | Userspace USB/IP (this) | Kernel `usbip-vudc` | Raspberry Pi `dwc2` |
|---|---|---|---|
| Root needed | No | Yes (modprobe + configfs) | Yes |
| Kernel modules | None | usbip-vudc, vhci-hcd | None on Pi side |
| Linux VM needed | No (host is fine) | Yes if not bare metal | No (Pi is the host) |
| Hardware purchase | None | None | ~$60 |
| Cross-platform server | Yes (in principle) | Linux only | Linux only |
| Known disconnect-after-enum bug | No | Yes (Sept 2025) | No |
| Agent-runnable end-to-end | Yes (`cargo test`) | Partial (sudo bootstrap) | Partial |

See `docs/architecture.md` for the design notes and `docs/kernel-mode-fallback.md`
if you want the kernel-module path anyway.

## Build prerequisites

The `usbip` Rust crate depends on `nusb` and `rusb` which need libusb
development headers on the build host:

```bash
sudo apt install libusb-1.0-0-dev          # Debian / Ubuntu
sudo dnf install libusbx-devel              # Fedora / RHEL
brew install libusb                         # macOS
```

## Folder contents

- `src/client.rs` — synchronous USB/IP client (~250 LOC). Used by the
  smoke test; speaks USB/IP wire protocol on top of `std::net::TcpStream`,
  no async runtime needed.
- `src/test_harness.rs` — subprocess + port helpers. Spawns the
  `coolscan-emu` binary and tears it down via SIGTERM on `Drop`.
- `docs/architecture.md` — detailed design and trade-off discussion.
- `docs/windows-setup.md` — exact steps for the Windows side.
- `docs/troubleshooting.md` — common failure modes and fixes.
- `docs/kernel-mode-fallback.md` — the alternative path for users who
  want the kernel `usbip-vudc` route (with prominent caveats).
- `scripts/install_usbip_win2.ps1` — optional PowerShell installer for
  the Windows side.

## Verification checklist

You should be able to run, end-to-end, on the Linux side alone:

```bash
cargo test --release --test smoke_usbip_e2e
```

This spawns the emulator, connects a USB/IP client to localhost, sends an
INQUIRY CDB, and asserts the response identifies the device as a Nikon
LS-50. **If this passes, the M14.5 milestone exit criterion is met.**

When you also run the Windows side and NikonScan recognises the scanner,
you have started M15 (NikonScan E2E validation).
