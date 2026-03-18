/// TCP socket bridge.
///
/// Listens on a configurable port (default 6581).
/// Frame protocol: [2B length BE] [1B type] [payload]
///
/// Types (host → emulator):
///   0x01 = CDB (32 bytes)
///   0x02 = Phase Query (0 bytes payload)
///   0x03 = Data Out (variable)
///   0x04 = Sense Query (0 bytes payload)
///
/// Types (emulator → host):
///   0x81 = Phase Byte (1 byte)
///   0x82 = Data In (variable)
///   0x83 = Sense Data (18 bytes)

use crate::traits::UsbBridge;

/// TCP bridge stub — UNUSED. TCP is implemented directly in orchestrator::poll_tcp().
/// Kept for potential future refactoring where TCP logic moves out of the orchestrator.
#[allow(dead_code)]
pub struct TcpBridge {
    port: u16,
    connected: bool,
}

impl TcpBridge {
    pub fn new(port: u16) -> Self {
        Self {
            port,
            connected: false,
        }
    }

    pub fn port(&self) -> u16 {
        self.port
    }
}

impl UsbBridge for TcpBridge {
    fn recv_ep1_out(&mut self) -> Option<Vec<u8>> {
        None // Stub — no data until TCP server is implemented
    }

    fn send_ep2_in(&mut self, _data: &[u8]) {
        // Stub
    }

    fn is_connected(&self) -> bool {
        self.connected
    }
}
