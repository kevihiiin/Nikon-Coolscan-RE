//! USB bridge trait — connects the ISP1581 model to the outside world.
//!
//! Implementations: TCP socket bridge, Linux USB gadget bridge.

pub trait UsbBridge {
    /// Receive data from host on EP1 OUT (CDB / data-out / phase query).
    /// Returns None if no data available (non-blocking).
    fn recv_ep1_out(&mut self) -> Option<Vec<u8>>;

    /// Send data to host on EP2 IN (phase byte / data-in / sense).
    fn send_ep2_in(&mut self, data: &[u8]);

    /// Check if a host is connected.
    fn is_connected(&self) -> bool;
}
