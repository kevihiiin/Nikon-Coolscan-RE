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
use std::path::Path;
use std::time::Duration;

const NIKON_VID: u16 = 0x04B0;
const LS50_PID: u16 = 0x4001;

#[test]
fn smoke_inquiry_via_usbip() {
    // 1. Pick an ephemeral port so concurrent test runs don't collide.
    let port = pick_free_port();
    let emu_path = env!("CARGO_BIN_EXE_coolscan-emu");

    // Resolve the firmware path. Cargo doesn't set CARGO_MANIFEST_DIR
    // for tests of the binary's own crate to a sane relative root, so
    // we anchor on the binary location and walk up to the workspace.
    let manifest_dir = env!("CARGO_MANIFEST_DIR");
    let firmware_path = std::path::PathBuf::from(manifest_dir)
        .join("../../binaries/firmware/Nikon LS-50 MBM29F400B TSOP48.bin");
    assert!(
        firmware_path.exists(),
        "firmware binary not found at {firmware_path:?}",
    );
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

    // 5. Import the device and submit an INQUIRY CDB on EP1 OUT, then
    //    drain EP2 IN for the response.
    let mut session = client.req_import(&busid).expect("OP_REQ_IMPORT");
    let inquiry_cdb = [0x12u8, 0x00, 0x00, 0x00, 0x24, 0x00];
    session
        .bulk_out(0x01, &inquiry_cdb)
        .expect("EP1 OUT bulk submit");

    let response = session
        .bulk_in(0x82, 36, Duration::from_secs(10))
        .expect("EP2 IN bulk submit");

    assert!(
        response.len() >= 36,
        "short INQUIRY response: got {} bytes, want ≥36; data={:02X?}",
        response.len(),
        response,
    );

    // INQUIRY response layout: bytes 0..8 are header (peripheral type,
    // EVPD bit, response data format, etc.); bytes 8..16 vendor;
    // 16..32 product; 32..36 revision.
    let vendor = String::from_utf8_lossy(&response[8..16]);
    let product = String::from_utf8_lossy(&response[16..32]);
    let revision = String::from_utf8_lossy(&response[32..36]);

    eprintln!("INQUIRY response (raw {} bytes):", response.len());
    eprintln!("  hex:      {:02X?}", response);
    eprintln!("  vendor   = {:?}", vendor.trim());
    eprintln!("  product  = {:?}", product.trim());
    eprintln!("  revision = {:?}", revision.trim());

    assert!(
        vendor.starts_with("Nikon"),
        "expected vendor to start with \"Nikon\", got {vendor:?}",
    );
    assert!(
        product.starts_with("LS-50"),
        "expected product to start with \"LS-50\", got {product:?}",
    );
}
