//! Hardware-in-the-Loop (HIL) helpers for the Coolscan emulator.
//!
//! - [`client`]: synchronous USB/IP client used by integration tests
//! - [`test_harness`]: subprocess + port helpers for spawning the emulator

pub mod client;
pub mod test_harness;
