//! Userspace USB/IP server bridge.
//!
//! Presents a virtual Nikon LS-50 over TCP using the jiegec/usbip crate
//! ([crates.io](https://crates.io/crates/usbip)). Pairs with `usbip-win2`
//! on the Windows side. No root, no kernel modules — pure userspace.
//!
//! ## How it fits with the rest of the bridge layer
//!
//! `coolscan-emu` already has two `UsbBridge` implementations:
//! - [`crate::tcp::TcpBridge`] for the in-tree dev test client
//! - [`crate::gadget::GadgetBridge`] (Linux only) for FunctionFS-on-real-UDC
//!
//! `UsbipServerBridge` is the third: it accepts USB/IP TCP connections and
//! translates URBs to/from the same `recv_ep1_out` / `send_ep2_in` interface
//! the orchestrator already polls. The emulator's CPU loop stays synchronous;
//! we own a dedicated `tokio::runtime::Runtime` to drive the TCP accept loop
//! off the main thread.
//!
//! ## Threading
//!
//! - Tokio runtime runs the USB/IP server on a worker thread.
//! - The `UsbInterfaceHandler::handle_urb` callback runs on that thread but
//!   is *synchronous* (per `usbip` crate API), so we just acquire a brief
//!   `std::sync::Mutex` on the shared `BridgeState`.
//! - The orchestrator's polling thread acquires the same mutex via the
//!   `UsbBridge` trait methods.
//! - Mutex critical sections are tiny (deque push/drain), so contention
//!   stays negligible at the protocol's traffic profile.

use crate::nikon_ids::{
    BCD_DEVICE, BULK_HS_MAX_PACKET, EP1_OUT_ADDR, EP2_IN_ADDR, MANUFACTURER, PRODUCT,
    PRODUCT_ID, SERIAL, VENDOR_ID,
};
use crate::traits::UsbBridge;
use std::any::Any;
use std::collections::VecDeque;
use std::sync::{Arc, Mutex};
use tokio::runtime::Runtime;
use usbip::{
    ClassCode, EndpointAttributes, SetupPacket, UsbDevice, UsbEndpoint, UsbInterface,
    UsbInterfaceHandler, UsbIpServer, UsbSpeed,
};

/// Soft cap on bytes buffered in either direction. Beyond this the
/// bridge trips its `fatal_error` flag and drops the host link — silent
/// dropping mid-stream would corrupt the bulk transfer the host has
/// already counted as in-flight.
const MAX_FIFO_BYTES: usize = 4 * 1024 * 1024;

/// USB/IP `bus_id` we expose. The Windows client picks devices by this
/// string; "1-1" is the conventional first-bus-first-port identifier.
const USBIP_BUS_ID: &str = "1-1";

/// Flash patches that the orchestrator must restore once the firmware
/// reaches main loop, when the USB/IP bridge is in use.
///
/// The M14 NOP patch set assumed dispatch-level data transfer is always
/// sufficient. INQUIRY breaks that: its handler builds the 36-byte
/// device descriptor in a separate buffer and ships it via its own
/// response-manager + data-transfer calls (not the dispatcher's). Without
/// these restorations INQUIRY would return sense data instead.
///
/// The list lives here (with the bridge that needs it) rather than on
/// `Emulator` so adding a future bridge that needs different patches
/// doesn't force a change in the orchestrator. Each entry is
/// `(flash_address, original_4_bytes)` matching `restore_flash_patch`'s
/// signature.
pub const POST_BOOT_FLASH_RESTORES: &[(u32, u32)] = &[
    (0x026042, 0x5E01374A), // INQUIRY response manager call
    (0x02604A, 0x5E014090), // INQUIRY data transfer call
];

/// Shared state between the tokio handler thread and the orchestrator's
/// polling thread.
#[derive(Default, Debug)]
struct BridgeState {
    /// Bytes received from the USB host on EP1 OUT (CDB / data-out).
    /// Drained by `recv_ep1_out` into the ISP1581 EP1 OUT FIFO.
    ep1_out: VecDeque<u8>,
    /// Bytes pending for the host on EP2 IN (responses / data-in).
    /// Filled by `send_ep2_in` from the ISP1581 EP2 IN FIFO.
    ep2_in: VecDeque<u8>,
    /// Set by the handler when the first URB arrives — i.e. the host has
    /// not just connected but actually IMPORT'd the device. Used by
    /// `is_connected` so the orchestrator can gate session state.
    connected: bool,
    /// Set when a FIFO over-cap event occurred. Once true, `is_connected`
    /// returns false and both bridge endpoints stop accepting work — the
    /// USB stream is irrecoverable at that point because bytes the SCSI
    /// layer counted as transferred never reached the wire (or vice
    /// versa). Better to drop the host link cleanly than to feed it
    /// truncated data with no STALL signal.
    fatal_error: bool,
}

#[derive(Debug)]
struct CoolscanInterfaceHandler {
    state: Arc<Mutex<BridgeState>>,
}

impl UsbInterfaceHandler for CoolscanInterfaceHandler {
    fn get_class_specific_descriptor(&self) -> Vec<u8> {
        // Vendor-specific interface — no class descriptor.
        Vec::new()
    }

    fn handle_urb(
        &mut self,
        _interface: &UsbInterface,
        ep: UsbEndpoint,
        transfer_buffer_length: u32,
        _setup: SetupPacket,
        req: &[u8],
    ) -> std::io::Result<Vec<u8>> {
        let mut state = self.state.lock().expect("BridgeState mutex poisoned");
        // Once the bridge has tripped the fatal flag we refuse all work
        // and surface a fake EBROKENPIPE so the usbip crate tears down
        // the TCP connection. The host then has to detach + re-attach,
        // which gives the firmware a chance to restart cleanly.
        if state.fatal_error {
            return Err(std::io::Error::new(
                std::io::ErrorKind::BrokenPipe,
                "bridge in fatal state (FIFO overflow)",
            ));
        }
        // First URB after IMPORT marks the connection as live for the
        // emulator's session-state gating.
        state.connected = true;

        match ep.address {
            EP1_OUT_ADDR => {
                // Bulk OUT: append host data to EP1 OUT queue. Over-cap
                // means the orchestrator isn't draining (firmware stuck?)
                // — silent drop would corrupt the next CDB the firmware
                // reads. Mark fatal instead.
                if state.ep1_out.len() + req.len() > MAX_FIFO_BYTES {
                    log::error!(
                        "USB/IP: EP1 OUT FIFO overflow ({} buffered + {} new > {} cap) — \
                         dropping host link",
                        state.ep1_out.len(),
                        req.len(),
                        MAX_FIFO_BYTES,
                    );
                    state.fatal_error = true;
                    state.connected = false;
                    return Err(std::io::Error::new(
                        std::io::ErrorKind::BrokenPipe,
                        "EP1 OUT FIFO overflow",
                    ));
                }
                state.ep1_out.extend(req);
                Ok(Vec::new())
            }
            EP2_IN_ADDR => {
                // Bulk IN: drain up to `transfer_buffer_length` from the
                // EP2 IN queue. Returning empty Vec is the correct USB
                // semantic for "no data yet" — the host treats it as a
                // NAK and retries.
                let want = transfer_buffer_length as usize;
                let take = state.ep2_in.len().min(want);
                Ok(state.ep2_in.drain(..take).collect())
            }
            other => {
                log::warn!("USB/IP: URB on unexpected endpoint 0x{other:02X}");
                Ok(Vec::new())
            }
        }
    }

    fn as_any(&mut self) -> &mut dyn Any {
        self
    }
}

/// USB/IP server bridge. Construct via [`UsbipServerBridge::new`]; the
/// returned bridge owns its tokio runtime and shuts it down on `Drop`.
pub struct UsbipServerBridge {
    state: Arc<Mutex<BridgeState>>,
    /// Owned tokio runtime. Held in `Option` so `Drop` can move it out.
    runtime: Option<Runtime>,
}

impl UsbipServerBridge {
    /// Bind to `bind_addr:port` and start serving USB/IP requests for the
    /// virtual Nikon LS-50.
    pub fn new(bind_addr: &str, port: u16) -> Result<Self, String> {
        let state = Arc::new(Mutex::new(BridgeState::default()));

        let handler_box: Box<dyn UsbInterfaceHandler + Send> =
            Box::new(CoolscanInterfaceHandler { state: state.clone() });
        let handler = Arc::new(Mutex::new(handler_box));

        // Build the simulated UsbDevice. Most fields are public — set
        // them directly; strings go through the `set_*_name` helpers
        // because the crate's string-pool indexing is internal.
        let mut device = UsbDevice::new(0);
        device.path = format!("/sys/bus/usbip/{USBIP_BUS_ID}");
        device.bus_id = USBIP_BUS_ID.to_string();
        device.bus_num = 1;
        device.dev_num = 1;
        device.speed = UsbSpeed::High as u32;
        device.vendor_id = VENDOR_ID;
        device.product_id = PRODUCT_ID;
        device.device_bcd = BCD_DEVICE.into();
        device.device_class = ClassCode::VendorSpecific as u8;
        device.device_subclass = 0xFF;
        device.device_protocol = 0xFF;
        device.set_manufacturer_name(MANUFACTURER);
        device.set_product_name(PRODUCT);
        device.set_serial_number(SERIAL);

        let endpoints = vec![
            UsbEndpoint {
                address: EP1_OUT_ADDR,
                attributes: EndpointAttributes::Bulk as u8,
                max_packet_size: BULK_HS_MAX_PACKET,
                interval: 0,
            },
            UsbEndpoint {
                address: EP2_IN_ADDR,
                attributes: EndpointAttributes::Bulk as u8,
                max_packet_size: BULK_HS_MAX_PACKET,
                interval: 0,
            },
        ];

        let device = device.with_interface(
            ClassCode::VendorSpecific as u8,
            0xFF,
            0xFF,
            Some("Coolscan"),
            endpoints,
            handler,
        );

        let server = Arc::new(UsbIpServer::new_simulated(vec![device]));

        let runtime = tokio::runtime::Builder::new_multi_thread()
            .worker_threads(1)
            .enable_io()
            .enable_time()
            .thread_name("usbip-server")
            .build()
            .map_err(|e| format!("tokio runtime: {e}"))?;

        let addr = format!("{bind_addr}:{port}")
            .parse()
            .map_err(|e| format!("invalid bind address {bind_addr}:{port}: {e}"))?;

        let server_clone = server.clone();
        runtime.spawn(async move {
            usbip::server(addr, server_clone).await;
        });

        log::info!("USB/IP server listening on {bind_addr}:{port} (bus_id={USBIP_BUS_ID})");
        Ok(Self {
            state,
            runtime: Some(runtime),
        })
    }
}

impl Drop for UsbipServerBridge {
    fn drop(&mut self) {
        if let Some(rt) = self.runtime.take() {
            // Give in-flight URBs 1s to complete, then cancel everything.
            // Necessary so SIGINT-driven shutdown does not block on a
            // hung TCP read.
            rt.shutdown_timeout(std::time::Duration::from_secs(1));
        }
        log::info!("USB/IP server shut down");
    }
}

impl UsbBridge for UsbipServerBridge {
    fn recv_ep1_out(&mut self) -> Option<Vec<u8>> {
        // A poisoned mutex here means another thread panicked while
        // holding bridge state — the program is already broken. Per
        // CLAUDE.md "no over-defensive checks", surface the panic
        // rather than silently dropping CDB bytes which would leave the
        // emulator running but deaf to the host.
        let mut s = self.state.lock().expect("BridgeState mutex poisoned");
        if s.ep1_out.is_empty() {
            None
        } else {
            Some(s.ep1_out.drain(..).collect())
        }
    }

    fn send_ep2_in(&mut self, data: &[u8]) {
        let mut s = self.state.lock().expect("BridgeState mutex poisoned");
        if s.ep2_in.len() + data.len() > MAX_FIFO_BYTES {
            // Over-cap means the host isn't draining (stalled? slow?).
            // Silently dropping bytes here would feed the host a
            // truncated bulk-IN payload with no STALL/short-packet
            // signal — it would hang waiting for the missing tail. Mark
            // fatal so subsequent URBs get EBROKENPIPE and the host
            // tears down cleanly.
            log::error!(
                "USB/IP: EP2 IN FIFO overflow ({} buffered + {} new > {} cap) — \
                 dropping host link",
                s.ep2_in.len(),
                data.len(),
                MAX_FIFO_BYTES,
            );
            s.fatal_error = true;
            s.connected = false;
            return;
        }
        s.ep2_in.extend(data);
    }

    fn is_connected(&self) -> bool {
        let s = self.state.lock().expect("BridgeState mutex poisoned");
        s.connected && !s.fatal_error
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn bridge_starts_and_binds_random_port() {
        // Bind to port 0 → kernel assigns ephemeral; verifies the whole
        // construct path (tokio runtime + UsbDevice build + listener
        // bind) without depending on any specific port being free.
        let bridge = UsbipServerBridge::new("127.0.0.1", 0)
            .expect("bridge should construct");
        // Drop immediately — exercises the Drop impl too.
        drop(bridge);
    }

    #[test]
    fn recv_ep1_out_drains_state() {
        let bridge = UsbipServerBridge::new("127.0.0.1", 0).unwrap();
        // Inject directly into shared state (simulating what a real URB
        // would do via handle_urb).
        bridge.state.lock().unwrap().ep1_out.extend([0x12, 0x00, 0x00, 0x00, 0x24, 0x00]);
        let mut bridge = bridge;
        let drained = bridge.recv_ep1_out().expect("FIFO had data");
        assert_eq!(drained, vec![0x12, 0x00, 0x00, 0x00, 0x24, 0x00]);
        assert!(bridge.recv_ep1_out().is_none(), "FIFO drained");
    }

    #[test]
    fn send_ep2_in_appends_to_state() {
        let mut bridge = UsbipServerBridge::new("127.0.0.1", 0).unwrap();
        bridge.send_ep2_in(&[0x70, 0x00, 0x05]);
        bridge.send_ep2_in(&[0x00, 0x00]);
        let queued: Vec<u8> = bridge.state.lock().unwrap().ep2_in.iter().copied().collect();
        assert_eq!(queued, vec![0x70, 0x00, 0x05, 0x00, 0x00]);
    }

    #[test]
    fn ep2_in_over_cap_trips_fatal_and_disconnects() {
        // Regression for B3: over-cap writes must NOT silently drop the
        // payload (which would corrupt the host-visible bulk-IN stream).
        // They trip the fatal flag, drop the write, and force is_connected
        // to false so the orchestrator stops issuing commands.
        let mut bridge = UsbipServerBridge::new("127.0.0.1", 0).unwrap();
        bridge.state.lock().unwrap().connected = true;
        bridge
            .state
            .lock()
            .unwrap()
            .ep2_in
            .extend(std::iter::repeat_n(0u8, MAX_FIFO_BYTES - 10));
        assert!(bridge.is_connected(), "pre-overflow: connected");

        bridge.send_ep2_in(&[0xAA; 100]);

        let s = bridge.state.lock().unwrap();
        assert_eq!(s.ep2_in.len(), MAX_FIFO_BYTES - 10, "over-cap write dropped");
        assert!(s.fatal_error, "fatal_error set");
        assert!(!s.connected, "connected cleared");
        drop(s);
        assert!(!bridge.is_connected(), "is_connected now false");
    }

    #[test]
    fn ep1_out_over_cap_in_handler_returns_brokenpipe() {
        // Regression for B3 on the EP1 OUT side: handler must return an
        // error so the usbip crate tears down the TCP connection. Silent
        // drop here would corrupt the next CDB the firmware reads.
        let state = Arc::new(Mutex::new(BridgeState::default()));
        state
            .lock()
            .unwrap()
            .ep1_out
            .extend(std::iter::repeat_n(0u8, MAX_FIFO_BYTES - 10));

        let mut handler = CoolscanInterfaceHandler { state: state.clone() };
        let interface = UsbInterface {
            interface_class: 0xFF,
            interface_subclass: 0xFF,
            interface_protocol: 0xFF,
            endpoints: vec![],
            string_interface: 0,
            class_specific_descriptor: vec![],
            handler: Arc::new(Mutex::new(
                Box::new(CoolscanInterfaceHandler { state: state.clone() }) as Box<_>,
            )),
        };
        let ep = UsbEndpoint {
            address: EP1_OUT_ADDR,
            attributes: EndpointAttributes::Bulk as u8,
            max_packet_size: BULK_HS_MAX_PACKET,
            interval: 0,
        };

        let result = handler.handle_urb(&interface, ep, 0, SetupPacket::default(), &[0xAA; 100]);
        assert!(result.is_err(), "expected error on EP1 OUT overflow");
        assert_eq!(
            result.unwrap_err().kind(),
            std::io::ErrorKind::BrokenPipe,
            "expected BrokenPipe so usbip tears down the TCP connection"
        );
        let s = state.lock().unwrap();
        assert!(s.fatal_error);
        assert!(!s.connected);
    }

    #[test]
    fn fatal_state_rejects_subsequent_urbs() {
        // Once tripped, every URB returns BrokenPipe — no leakage of late
        // data into the host stream.
        let state = Arc::new(Mutex::new(BridgeState {
            fatal_error: true,
            connected: true, // pre-trip value, should not matter
            ..Default::default()
        }));
        let mut handler = CoolscanInterfaceHandler { state: state.clone() };
        let interface = UsbInterface {
            interface_class: 0xFF,
            interface_subclass: 0xFF,
            interface_protocol: 0xFF,
            endpoints: vec![],
            string_interface: 0,
            class_specific_descriptor: vec![],
            handler: Arc::new(Mutex::new(
                Box::new(CoolscanInterfaceHandler { state: state.clone() }) as Box<_>,
            )),
        };
        // Both EP1 OUT and EP2 IN URBs must be refused.
        for ep_addr in [EP1_OUT_ADDR, EP2_IN_ADDR] {
            let ep = UsbEndpoint {
                address: ep_addr,
                attributes: EndpointAttributes::Bulk as u8,
                max_packet_size: BULK_HS_MAX_PACKET,
                interval: 0,
            };
            let r = handler.handle_urb(&interface, ep, 64, SetupPacket::default(), &[]);
            assert!(r.is_err(), "EP 0x{ep_addr:02X}: should be rejected");
            assert_eq!(r.unwrap_err().kind(), std::io::ErrorKind::BrokenPipe);
        }
    }

    #[test]
    fn handler_marks_connected_on_first_urb() {
        let state = Arc::new(Mutex::new(BridgeState::default()));
        let mut handler = CoolscanInterfaceHandler { state: state.clone() };
        assert!(!state.lock().unwrap().connected);

        // Synthesize a minimal URB on EP1 OUT.
        let interface = UsbInterface {
            interface_class: 0xFF,
            interface_subclass: 0xFF,
            interface_protocol: 0xFF,
            endpoints: vec![],
            string_interface: 0,
            class_specific_descriptor: vec![],
            handler: Arc::new(Mutex::new(
                Box::new(CoolscanInterfaceHandler { state: state.clone() }) as Box<_>,
            )),
        };
        let ep = UsbEndpoint {
            address: EP1_OUT_ADDR,
            attributes: EndpointAttributes::Bulk as u8,
            max_packet_size: BULK_HS_MAX_PACKET,
            interval: 0,
        };
        let setup = SetupPacket::default();

        let result = handler
            .handle_urb(&interface, ep, 0, setup, &[0xAB, 0xCD])
            .expect("URB succeeds");
        assert_eq!(result, Vec::<u8>::new(), "OUT URB returns empty");
        assert!(state.lock().unwrap().connected, "first URB sets connected");
        assert_eq!(
            state.lock().unwrap().ep1_out.iter().copied().collect::<Vec<_>>(),
            vec![0xAB, 0xCD],
        );
    }

    #[test]
    fn handler_bulk_in_drains_up_to_transfer_buffer_length() {
        let state = Arc::new(Mutex::new(BridgeState::default()));
        state.lock().unwrap().ep2_in.extend([1, 2, 3, 4, 5, 6, 7, 8]);

        let mut handler = CoolscanInterfaceHandler { state: state.clone() };
        let interface = UsbInterface {
            interface_class: 0xFF,
            interface_subclass: 0xFF,
            interface_protocol: 0xFF,
            endpoints: vec![],
            string_interface: 0,
            class_specific_descriptor: vec![],
            handler: Arc::new(Mutex::new(
                Box::new(CoolscanInterfaceHandler { state: state.clone() }) as Box<_>,
            )),
        };
        let ep = UsbEndpoint {
            address: EP2_IN_ADDR,
            attributes: EndpointAttributes::Bulk as u8,
            max_packet_size: BULK_HS_MAX_PACKET,
            interval: 0,
        };
        let setup = SetupPacket::default();

        let out = handler.handle_urb(&interface, ep, 5, setup, &[]).unwrap();
        assert_eq!(out, vec![1, 2, 3, 4, 5], "drains only requested count");
        let remaining: Vec<u8> = state.lock().unwrap().ep2_in.iter().copied().collect();
        assert_eq!(remaining, vec![6, 7, 8]);
    }

    #[test]
    fn handler_bulk_in_empty_returns_empty_vec() {
        let state = Arc::new(Mutex::new(BridgeState::default()));
        let mut handler = CoolscanInterfaceHandler { state: state.clone() };
        let interface = UsbInterface {
            interface_class: 0xFF,
            interface_subclass: 0xFF,
            interface_protocol: 0xFF,
            endpoints: vec![],
            string_interface: 0,
            class_specific_descriptor: vec![],
            handler: Arc::new(Mutex::new(
                Box::new(CoolscanInterfaceHandler { state: state.clone() }) as Box<_>,
            )),
        };
        let ep = UsbEndpoint {
            address: EP2_IN_ADDR,
            attributes: EndpointAttributes::Bulk as u8,
            max_packet_size: BULK_HS_MAX_PACKET,
            interval: 0,
        };
        let out = handler
            .handle_urb(&interface, ep, 64, SetupPacket::default(), &[])
            .unwrap();
        assert_eq!(out, Vec::<u8>::new(), "empty FIFO → NAK-style empty Vec");
    }
}
