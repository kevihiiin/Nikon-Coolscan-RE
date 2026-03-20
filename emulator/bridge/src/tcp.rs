//! TCP bridge protocol definition.
//!
//! The TCP bridge is implemented directly in `coolscan-emu::orchestrator::poll_tcp()`.
//! This module documents the wire protocol.
//!
//! Frame format: `[length:2 BE] [type:1] [payload:N]`
//!
//! Host → Emulator:
//!   - `0x01` CDB inject (6-16 bytes)
//!   - `0x02` Phase query
//!   - `0x04` Sense query
//!   - `0x05` Data-In query (drain EP2 IN)
//!   - `0x06` Data-Out inject (push to EP1 OUT)
//!   - `0x07` Completion poll
//!   - `0x08` RAM read (addr:4 + len:2)
//!
//! Emulator → Host:
//!   - `0x81` Phase byte (1 byte)
//!   - `0x82` Data-In auto-push (variable)
//!   - `0x83` Sense data (18 bytes)
//!   - `0x84` Data-In response (variable)
//!   - `0x85` Completion status (4 bytes: done, sk, asc, has_data)
//!   - `0x86` Data-Out ACK (1 byte)
//!   - `0x88` RAM read response (variable)
