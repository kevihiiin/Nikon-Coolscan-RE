//! End-to-end smoke test for the M14.5 userspace USB/IP HIL transport.
//!
//! Spawns the coolscan-emu binary as a subprocess, connects a synchronous
//! USB/IP client to its TCP listener, performs the standard SCSI INQUIRY
//! exchange, and verifies the response identifies the device as a Nikon
//! LS-50.
//!
//! No root, no kernel modules, no Windows VM, no nested virt. The whole
//! HIL stack is exercised on a single machine and `cargo test` is the only
//! command needed.
//!
//! When this passes, the user can be confident that the userspace USB/IP
//! server speaks the protocol correctly and the firmware's IRQ1 → SCSI
//! dispatch path produces the right INQUIRY data through the real USB/IP
//! transport. From there, the M15 work (NikonScan-on-Windows) is a matter
//! of pointing `usbip-win2` at this same TCP port.

use hil::client::Client;
use hil::test_harness::{EmuHandle, pick_free_port, wait_for_port};
use std::path::{Path, PathBuf};
use std::time::Duration;

/// Walk up from this crate's manifest directory looking for the
/// firmware binary. Returns the first match. Tolerates the crate being
/// at any depth under a workspace that has a top-level `binaries/`.
fn find_firmware() -> Option<PathBuf> {
    const RELATIVE: &str = "binaries/firmware/Nikon LS-50 MBM29F400B TSOP48.bin";
    let mut dir = PathBuf::from(env!("CARGO_MANIFEST_DIR"));
    loop {
        let candidate = dir.join(RELATIVE);
        if candidate.exists() {
            return Some(candidate);
        }
        if !dir.pop() {
            return None;
        }
    }
}

const NIKON_VID: u16 = 0x04B0;
const LS50_PID: u16 = 0x4001;

#[test]
fn smoke_inquiry_via_usbip() {
    // 1. Pick an ephemeral port so concurrent test runs don't collide.
    let port = pick_free_port();
    let emu_path = env!("CARGO_BIN_EXE_coolscan-emu");

    // Walk up from CARGO_MANIFEST_DIR looking for a `binaries/` sibling.
    // Robust to workspace restructure: as long as the binary firmware
    // lives somewhere under a `binaries/firmware/` directory above the
    // crate, we'll find it. Hard-coding `../../binaries/...` would
    // silently break the day someone moves the workspace root.
    let firmware_path = find_firmware()
        .expect("could not find binaries/firmware/Nikon LS-50 ... binary above CARGO_MANIFEST_DIR");
    let firmware_path_str = firmware_path
        .to_str()
        .expect("firmware path must be valid UTF-8");

    // 2. Spawn the emulator with --usbip-server bound to localhost.
    //    `--max 30000000` caps the run so a hung test still completes
    //    eventually; the firmware needs ~3M instructions to finish boot
    //    + handle one SCSI command, so 30M is comfortable headroom.
    // Note: deliberately NOT passing --full-usb-init. That flag tells the
    // firmware to do its own USB enumeration (intended for the gadget
    // bridge path on a Pi). Our userspace USB/IP transport handles
    // enumeration in user space; the firmware just needs to be ready to
    // receive CDBs via IRQ1, which the warm-boot path provides.
    // We DO pass --firmware-dispatch so the SCSI handlers run on the real
    // firmware (this is the actual milestone exit criterion: firmware
    // produces an INQUIRY response that arrives over USB/IP).
    let _emu = EmuHandle::spawn(
        Path::new(emu_path),
        &[
            "--firmware",
            firmware_path_str,
            "--usbip-server",
            "--usbip-bind",
            "127.0.0.1",
            "--usbip-port",
            &port.to_string(),
            "--firmware-dispatch",
            // Generous instruction cap so a slow CI machine doesn't time
            // out during emulator boot + INQUIRY handling. Real boots
            // are ~3M instructions; INQUIRY handler is a few hundred K.
            "--max",
            "30000000",
        ],
    )
    .expect("spawn coolscan-emu subprocess");

    // 3. Wait for the USB/IP server to bind. If this times out, the emu
    //    crashed on boot or the port-bind raced.
    assert!(
        wait_for_port(("127.0.0.1", port), Duration::from_secs(10)),
        "emulator did not bind 127.0.0.1:{port} within 10s",
    );

    // 4. Open a USB/IP client. List devices. Expect exactly one Nikon LS-50.
    let mut client = Client::connect(("127.0.0.1", port))
        .expect("client connect to userspace USB/IP server");
    let devices = client.req_devlist().expect("OP_REQ_DEVLIST round-trip");
    assert!(
        !devices.is_empty(),
        "device list is empty — server registered no devices",
    );
    let coolscan = devices
        .iter()
        .find(|d| d.vendor_id == NIKON_VID && d.product_id == LS50_PID)
        .unwrap_or_else(|| {
            panic!(
                "no Nikon LS-50 in device list (got {} devices: {:?})",
                devices.len(),
                devices
                    .iter()
                    .map(|d| format!("{:04x}:{:04x}", d.vendor_id, d.product_id))
                    .collect::<Vec<_>>(),
            )
        });
    let busid = coolscan.busid.clone();

    // 5. Import the device and follow the Nikon USB-wrapped-SCSI protocol
    //    (docs/kb/architecture/usb-protocol.md) to fetch the INQUIRY
    //    response. The wire sequence is:
    //
    //       host → CDB        (bulk-OUT EP1, 6 bytes)
    //       host → 0xD0       (bulk-OUT EP1, 1 byte phase query)
    //       host ← phase byte (bulk-IN  EP2, 1 byte; 0x03 = data-in)
    //       host ← INQUIRY    (bulk-IN  EP2, 36 bytes payload)
    //
    //    Earlier versions of this test took a shortcut by issuing INQUIRY
    //    then a single bulk-IN read for 36 bytes — that was sufficient
    //    against the orchestrator's old behavior of pushing CDB responses
    //    straight to EP2 IN, but the Nikon protocol expects the phase
    //    byte FIRST. The N9 fix (commit TBD) corrected the response
    //    ordering by buffering CDB responses until the matching 0xD0
    //    arrives, so the test now follows the protocol properly.
    let mut session = client.req_import(&busid).expect("OP_REQ_IMPORT");
    let inquiry_cdb = [0x12u8, 0x00, 0x00, 0x00, 0x24, 0x00];
    session
        .bulk_out(0x01, &inquiry_cdb)
        .expect("EP1 OUT bulk submit (INQUIRY)");
    session
        .bulk_out(0x01, &[0xD0u8])
        .expect("EP1 OUT bulk submit (0xD0 phase query)");

    let phase = session
        .bulk_in(0x82, 1, Duration::from_secs(10))
        .expect("EP2 IN bulk submit (phase)");
    assert_eq!(phase.len(), 1, "phase response must be 1 byte");
    assert_eq!(phase[0], 0x03, "phase after INQUIRY (data-in) should be 0x03");

    let response = session
        .bulk_in(0x82, 36, Duration::from_secs(10))
        .expect("EP2 IN bulk submit (INQUIRY data)");

    // Known-good INQUIRY fixture — the exact 36 bytes the firmware's
    // INQUIRY handler produces from its template at flash offset 0x170CE.
    // Cross-checked against M14's `gate_trace_inquiry_isp1581_access`
    // test which compares firmware-dispatch output against Rust-emulation
    // output byte-for-byte. Asserting the full string here (not a lossy
    // `starts_with` substring) catches single-byte regressions anywhere
    // in the response — including past position 5 which `starts_with`
    // would silently allow.
    //
    //   06 80 02 02 1F 00 00 00      header (scanner, removable, ANSI 2)
    //   "Nikon   "                   vendor (8 bytes, space-padded)
    //   "LS-50 ED        "           product (16 bytes, space-padded)
    //   "1.02"                       revision (4 bytes)
    const EXPECTED_INQUIRY: [u8; 36] = [
        0x06, 0x80, 0x02, 0x02, 0x1F, 0x00, 0x00, 0x00,
        b'N', b'i', b'k', b'o', b'n', b' ', b' ', b' ',
        b'L', b'S', b'-', b'5', b'0', b' ', b'E', b'D',
        b' ', b' ', b' ', b' ', b' ', b' ', b' ', b' ',
        b'1', b'.', b'0', b'2',
    ];

    eprintln!("INQUIRY response ({} bytes): {:02X?}", response.len(), response);

    assert_eq!(
        response.as_slice(),
        EXPECTED_INQUIRY.as_slice(),
        "INQUIRY response did not match the known-good fixture byte-for-byte",
    );
}
