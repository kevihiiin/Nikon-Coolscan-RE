//! Process-spawning helpers for the integration test.
//!
//! Lives in this crate so the actual `coolscan-emu/tests/smoke_usbip_e2e.rs`
//! file stays small and focused on the assertions; the noisy subprocess
//! lifecycle / port-picking / timeout management is here.

use std::io::Write;
use std::net::{TcpListener, TcpStream, ToSocketAddrs};
use std::path::Path;
use std::process::{Child, Command, Stdio};
use std::time::{Duration, Instant};

/// Bind to an ephemeral port, capture the assignment, drop the listener,
/// return the port number. There is a brief race between this returning
/// and the caller binding — acceptable for tests.
pub fn pick_free_port() -> u16 {
    let listener = TcpListener::bind("127.0.0.1:0").expect("bind ephemeral port");
    listener
        .local_addr()
        .expect("local_addr after bind")
        .port()
}

/// Poll-connect to `addr` until it's open or `timeout` elapses. Returns
/// `true` on success; `false` if we never connected.
pub fn wait_for_port<A: ToSocketAddrs>(addr: A, timeout: Duration) -> bool {
    let deadline = Instant::now() + timeout;
    let addrs: Vec<_> = match addr.to_socket_addrs() {
        Ok(a) => a.collect(),
        Err(_) => return false,
    };
    while Instant::now() < deadline {
        for a in &addrs {
            if TcpStream::connect_timeout(a, Duration::from_millis(100)).is_ok() {
                return true;
            }
        }
        std::thread::sleep(Duration::from_millis(50));
    }
    false
}

/// RAII wrapper around an emulator subprocess. `Drop` sends SIGTERM with
/// a 5s wait; if the child is still alive after that it gets SIGKILL.
/// This guarantees CI runs don't leak orphan emulators.
pub struct EmuHandle {
    child: Option<Child>,
}

impl EmuHandle {
    /// Spawn `binary` (an absolute path; in tests pass
    /// `env!("CARGO_BIN_EXE_coolscan-emu")`) with `args`. stdout/stderr
    /// are piped to inherit so test output shows the emulator log.
    pub fn spawn(binary: &Path, args: &[&str]) -> std::io::Result<Self> {
        let child = Command::new(binary)
            .args(args)
            .env("RUST_LOG", "info")
            .stdout(Stdio::inherit())
            .stderr(Stdio::inherit())
            .spawn()?;
        Ok(Self { child: Some(child) })
    }

    /// PID of the running emulator, useful for debug logging.
    pub fn pid(&self) -> Option<u32> {
        self.child.as_ref().map(Child::id)
    }
}

impl Drop for EmuHandle {
    fn drop(&mut self) {
        let Some(mut child) = self.child.take() else {
            return;
        };
        // Best-effort SIGTERM. On Unix this is `kill(pid, SIGTERM)`; on
        // Windows `Child::kill` sends an unconditional terminate. We
        // tolerate both because tests just need cleanup, not graceful
        // protocol shutdown (the bridge's own Drop handles that).
        unsafe {
            // SAFETY: we own the child handle exclusively; libc::kill is
            // safe for any pid we own. Use libc only when available; on
            // Windows fall through to Child::kill.
            #[cfg(unix)]
            libc_kill(child.id() as i32, 15 /* SIGTERM */);
        }
        let deadline = Instant::now() + Duration::from_secs(5);
        loop {
            match child.try_wait() {
                Ok(Some(_)) => return,
                Ok(None) => {
                    if Instant::now() >= deadline {
                        let _ = child.kill();
                        let _ = child.wait();
                        let _ = std::io::stderr()
                            .write_all(b"EmuHandle: child did not exit on SIGTERM, sent SIGKILL\n");
                        return;
                    }
                    std::thread::sleep(Duration::from_millis(50));
                }
                Err(_) => {
                    let _ = child.kill();
                    return;
                }
            }
        }
    }
}

/// Tiny libc::kill wrapper so we don't add a libc dep just for SIGTERM.
/// Reaches the syscall directly via the always-present libc.so.
#[cfg(unix)]
unsafe fn libc_kill(pid: i32, sig: i32) {
    unsafe extern "C" {
        fn kill(pid: i32, sig: i32) -> i32;
    }
    unsafe { let _ = kill(pid, sig); }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn pick_free_port_returns_nonzero() {
        let p = pick_free_port();
        assert!(p > 0, "expected a non-zero port, got {p}");
    }

    #[test]
    fn wait_for_port_times_out_when_nothing_listens() {
        // Port that is almost certainly not listening. False return must
        // be observed, not a hang.
        let timeout = Duration::from_millis(500);
        let start = Instant::now();
        let ok = wait_for_port(("127.0.0.1", 1), timeout); // port 1 = TCPMUX, never bound
        assert!(!ok, "should have timed out");
        assert!(
            start.elapsed() < timeout + Duration::from_secs(1),
            "wait_for_port took too long"
        );
    }

    #[test]
    fn wait_for_port_succeeds_when_listener_present() {
        let listener = TcpListener::bind("127.0.0.1:0").unwrap();
        let port = listener.local_addr().unwrap().port();
        std::thread::spawn(move || {
            // Accept once and drop — keeps the listener alive long enough
            // to be polled.
            let _ = listener.accept();
        });
        assert!(
            wait_for_port(("127.0.0.1", port), Duration::from_secs(2)),
            "wait_for_port did not see live listener on {port}"
        );
    }
}
