//! Idle-stability regression test for the M15 NikonScan workflow.
//!
//! The original `smoke_usbip_e2e` test attaches a USB/IP client within
//! ~100 ms of emulator launch and exits cleanly under 0.5 s — well below
//! the ~0.6 s threshold at which the firmware's SCSI dispatcher idle
//! path used to corrupt the context save area (`mem[0x400764..0x40076D]`)
//! and crash on the next RTE at insn ~2.79 M. Because the existing test
//! returns before that crash, it didn't catch the underlying CPU-decoder
//! bug that the M15 NikonScan workflow tripped over: usbip-win2 inside a
//! Windows VM takes 5–10 s to attach, far past the danger zone.
//!
//! This test exercises the steady-idle scenario directly. It launches
//! the emulator with no client traffic and lets it run for several
//! seconds, expecting the process to stay alive and the listener to stay
//! reachable for sustained idle.
//!
//! Root-cause fix that this test guards against: the H8 decoder for
//! `MOV.B @(d:24, ERn), Rd` (78-prefix, opcode `78 rr 6A 2x`) was reading
//! the displacement from the wrong byte slot. The 24-bit displacement
//! lives at bytes [+5..+7] with padding at [+4]; the previous code
//! treated it as [+4..+6] with padding at [+7], silently dropping the
//! low byte and shifting `disp` by 8 bits. That made the SCSI
//! dispatcher's slot-status read at `0x020BBC` reference the wrong byte,
//! which let the firmware fall into a memmove loop that walked past the
//! queue array into the context save area.

use hil::test_harness::{EmuHandle, pick_free_port, wait_for_port};
use std::net::TcpStream;
use std::path::{Path, PathBuf};
use std::time::{Duration, Instant};

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

#[test]
fn idle_emulator_survives_past_dispatcher_drift_window() {
    let port = pick_free_port();
    let emu_path = env!("CARGO_BIN_EXE_coolscan-emu");
    let firmware_path = find_firmware()
        .expect("missing binaries/firmware/Nikon LS-50 ... binary above CARGO_MANIFEST_DIR");

    let emu = EmuHandle::spawn(
        Path::new(emu_path),
        &[
            "--firmware",
            firmware_path.to_str().expect("firmware path UTF-8"),
            "--usbip-server",
            "--usbip-bind",
            "127.0.0.1",
            "--usbip-port",
            &port.to_string(),
            "--firmware-dispatch",
            // Cap the run so a hang doesn't burn CI time. 80 M instructions
            // is comfortably past the 2.79 M dispatcher-drift halt that the
            // CPU-decoder fix avoids; on a typical dev box this takes ~10 s.
            "--max",
            "80000000",
        ],
    )
    .expect("spawn coolscan-emu subprocess");

    assert!(
        wait_for_port(("127.0.0.1", port), Duration::from_secs(10)),
        "emulator did not bind 127.0.0.1:{port} within 10 s",
    );

    // Burn 6 seconds of wall clock with NO client traffic. The pre-fix
    // emulator halts deterministically at insn 2,795,602 (~0.6 s in). Six
    // seconds is ~10× that headroom and verifies the dispatcher idle path
    // doesn't corrupt the context save area in the absence of CDB traffic.
    let start = Instant::now();
    let target_idle = Duration::from_secs(6);
    while start.elapsed() < target_idle {
        std::thread::sleep(Duration::from_millis(100));
        // Periodically poll the listener to confirm the emulator
        // process is still alive and the USB/IP socket is still
        // accepting connections (it would close on process exit).
        let probe = TcpStream::connect_timeout(
            &format!("127.0.0.1:{port}").parse().expect("loopback addr"),
            Duration::from_millis(500),
        );
        assert!(
            probe.is_ok(),
            "USB/IP listener at 127.0.0.1:{port} stopped accepting connections after {:?} of idle — \
             emulator likely halted on the dispatcher idle-drift path",
            start.elapsed()
        );
        // Drop the probe immediately; we don't want to feed protocol
        // bytes that would advance the firmware out of the idle path
        // and mask a regression.
        drop(probe);
    }

    // Drop the EmuHandle (its Drop kills the child); test passes if we
    // got here without the listener-probe assertion firing.
    drop(emu);
}
