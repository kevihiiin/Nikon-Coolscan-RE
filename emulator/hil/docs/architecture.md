# HIL Architecture

## Design goals

1. **No `sudo`** on the Linux side. The agent driving the emulator
   should be able to bring up HIL with `cargo run` only.
2. **No kernel modules**. Avoids distro-specific module availability and
   the known `usbip-vudc` "disconnect after enumeration" bug.
3. **No nested virtualisation**. The user runs Windows as a single VM
   on this Linux host; HIL must work when the Linux side IS the host.
4. **Agent-runnable verification**. `cargo test --test smoke_usbip_e2e`
   exercises the complete pipeline locally without involving Windows.
5. **NikonScan compatibility**. The Windows host must see a device that
   matches the real Nikon LS-50's USB descriptors byte-for-byte, so the
   stock `NKDUSCAN.dll` driver claims it via INF match.

## The pipeline

```
┌──────────────────────────────────────┐        ┌──────────────────────────┐
│  Linux host                          │        │   Windows VM             │
│                                      │        │                          │
│  ┌────────────────────────────────┐  │        │  ┌────────────────────┐  │
│  │ coolscan-emu                   │  │        │  │   NikonScan 4.0.3  │  │
│  │   ↓                            │  │        │  │           ↓        │  │
│  │ orchestrator::poll_usbip       │  │        │  │  NKDUSCAN.dll      │  │
│  │   ↓                            │  │        │  │           ↑        │  │
│  │ scsi_command (firmware path)   │  │        │  │  usbip-win2        │  │
│  │   ↓                            │  │        │  │  vhci driver       │  │
│  │ ISP1581 EP1/EP2 FIFOs          │  │        │  │           ↑        │  │
│  │   ↓                            │  │        │  │  usbip.exe attach  │  │
│  │ bridge::usbip_server           │  │        │  │           ↑        │  │
│  │   ↓ tokio runtime              │  │        │  │           │        │  │
│  │ TcpListener :3240              │ ◄────────►│           │        │  │
│  └────────────────────────────────┘  │   TCP  │  └────────────────────┘  │
└──────────────────────────────────────┘        └──────────────────────────┘
```

## How a single SCSI command flows

1. Windows USB stack issues a bulk-OUT URB containing the SCSI CDB.
2. `vhci-hcd` driver in `usbip-win2` wraps it in a `USBIP_CMD_SUBMIT`
   message and sends it over TCP :3240.
3. On Linux, the `usbip` crate's TCP accept loop hands the URB to our
   `CoolscanInterfaceHandler::handle_urb` callback (synchronous).
4. The callback appends the CDB bytes to a shared `BridgeState::ep1_out`
   `VecDeque` and returns an empty `Vec<u8>` (no IN data).
5. On the next 1000-instruction tick of the emulator's run loop,
   `Emulator::poll_usbip` drains `state.ep1_out`, then calls
   `scsi_command(cdb)` synchronously.
6. `scsi_command` pads the CDB to 384 bytes, injects it into the
   ISP1581 EP1 OUT FIFO, runs the firmware mini-loop until the SCSI
   handler returns to the sentinel, and drains the response from the
   ISP1581 EP2 IN FIFO.
7. `poll_usbip` pushes that response into `BridgeState::ep2_in`.
8. The host's bulk-IN URB triggers `handle_urb` again (this time on
   EP2 IN address `0x82`), which drains up to `transfer_buffer_length`
   bytes from `state.ep2_in` and returns them.
9. The `usbip` crate wraps the bytes in `USBIP_RET_SUBMIT` and ships
   them back over TCP. `vhci-hcd` delivers them as the URB completion.
10. NikonScan parses the response.

## Why `scsi_command` and not the autonomous IRQ1 path

The earlier M11/M14 work added an "autonomous IRQ1" path
(`Emulator::inject_cdb_irq1`): inject CDB into EP1 OUT FIFO, IRQ1 fires,
firmware ISR reads the CDB and dispatches. This path is what `--gadget`
uses on a real Pi.

It does not work for `--usbip-server` because the firmware's SCSI
dispatcher reads from the EP1 OUT FIFO **multiple times** per command
(CDB read, dispatch init copy, data transfer setup). A 6-byte CDB
injection depletes after the first read; subsequent reads see zeros and
the response goes wrong.

`scsi_command` already handles this: it pads the CDB to 384 bytes
before injecting, then actively drives the dispatcher via
`firmware_dispatch_scsi`. M14.5's `poll_usbip` reuses this same path,
so commands arriving via USB/IP get the same treatment as commands sent
via the in-process `scsi_command` API used by tests.

This is also why `poll_usbip` waits for the firmware to reach main loop
(milestone `0xDEAD0001`) before processing CDBs — `scsi_command` needs
firmware state initialised.

## INQUIRY-specific patch restoration

The M14 NOP patch set assumed dispatch-level data transfer is always
sufficient. INQUIRY breaks this assumption: its handler builds a 36-byte
response in a separate buffer and sends it via its own response-manager
+ data-transfer calls, which are NOPed.

`setup_usbip_server` sets a flag (`usbip_inquiry_patches_pending`) that
is cleared on the first `poll_usbip` after main loop is reached. At that
point we restore the two flash patches at `0x026042` and `0x02604A` to
re-enable INQUIRY's handler-internal transfer path.

The same restoration is performed by `gate_trace_inquiry_isp1581_access`
in `e2e_scan.rs` and is documented in the M14 phase notes.

Other SCSI commands may need similar selective restoration. M14.5 covers
the INQUIRY case; M15 (NikonScan E2E) will surface the rest.

## Threading

- The emulator's CPU loop is fully synchronous and runs in `main()`.
- `bridge::UsbipServerBridge::new` builds a single-threaded tokio
  runtime in a dedicated OS thread. The runtime owns the TCP accept
  loop and the per-connection task that dispatches URBs to our handler.
- The handler grabs a `std::sync::Mutex` on the shared `BridgeState`,
  appends/drains a `VecDeque`, and releases. Critical sections are
  microseconds.
- The emulator's `poll_usbip` (called every 1000 instructions on the
  main thread) acquires the same mutex, drains/appends, and releases.
- Contention is therefore between two threads each holding the mutex
  for under a microsecond. Negligible in practice.

## Why `usbip` crate (jiegec) instead of hand-rolling

- Server: the crate's `UsbIpServer` + `UsbInterfaceHandler` covers the
  entire USB/IP server side. Hand-rolling would be ~500 LOC of
  serialization that's been written and tested several times in this
  ecosystem already.
- The crate's request encoders (`UsbIpCommand::to_bytes`) are public,
  so even our hand-rolled client reuses them. Only response *parsing*
  is hand-rolled (the crate doesn't expose decoders).
- Cost: pulls `tokio`, `nusb`, `rusb` (which needs libusb on the host).
  We accept the libusb build dependency in exchange for the ~500 LOC
  saving on the server side.

## When `--usbip-server` is the wrong answer

- **Maximum protocol fidelity** — the kernel `usbip-vudc` path puts the
  full Linux USB stack between the firmware and the host. Useful for
  research into low-level USB behaviour. Documented in
  `kernel-mode-fallback.md`.
- **Production deployment** — `--gadget` on a Pi remains the natural
  fit for a "drop-in scanner replacement" appliance.
- **Performance benchmarking** — TCP loopback + USB/IP framing adds
  measurable latency vs raw USB. Acceptable for protocol testing,
  borderline for full-resolution scans (50MB).
