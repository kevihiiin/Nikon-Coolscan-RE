//! Linux USB Gadget bridge using FunctionFS.
//!
//! Presents the emulator as a real USB device (VID 04B0, PID 4001 = Nikon LS-50).
//! Uses configfs to create the gadget and FunctionFS for endpoint I/O.
//!
//! Requires: Linux kernel with USB gadget support (configfs + functionfs).
//! Typically needs root or appropriate permissions.
//!
//! Endpoints:
//!   EP1 OUT (bulk) — host sends CDB / data-out
//!   EP2 IN  (bulk) — device sends phase / data-in / sense

use crate::nikon_ids::{
    BCD_DEVICE, BULK_FS_MAX_PACKET, BULK_HS_MAX_PACKET, EP1_OUT_ADDR, EP2_IN_ADDR,
    MANUFACTURER, PRODUCT, PRODUCT_ID, SERIAL, VENDOR_ID,
};
use crate::traits::UsbBridge;
use std::fs::{self, File, OpenOptions};
use std::io::{Read, Write};
use std::os::unix::io::AsRawFd;
use std::path::{Path, PathBuf};

/// FunctionFS descriptor header magic numbers.
const FUNCTIONFS_DESCRIPTORS_MAGIC_V2: u32 = 3;
const FUNCTIONFS_STRINGS_MAGIC: u32 = 2;
const FUNCTIONFS_HAS_FS_DESC: u32 = 1;
const FUNCTIONFS_HAS_HS_DESC: u32 = 2;

/// `bridge::nikon_ids::BULK_HS_MAX_PACKET` is `u16` because the USB
/// descriptor field is 16-bit. We use it as a `usize` here for slice
/// arithmetic; the cast is a constant fold.
const HS_BULK_MAX_PACKET: usize = BULK_HS_MAX_PACKET as usize;

/// USB gadget bridge state.
pub struct GadgetBridge {
    /// Path to the gadget in configfs (e.g., /sys/kernel/config/usb_gadget/coolscan).
    gadget_path: PathBuf,
    /// Path to the FunctionFS mount point.
    ffs_path: PathBuf,
    /// EP0 control endpoint (FunctionFS).
    ep0: Option<File>,
    /// EP1 OUT bulk endpoint file.
    ep1_out: Option<File>,
    /// EP2 IN bulk endpoint file.
    ep2_in: Option<File>,
    /// Whether the gadget is set up and connected.
    connected: bool,
    /// UDC (USB Device Controller) name.
    udc: Option<String>,
}

impl Default for GadgetBridge {
    fn default() -> Self {
        Self::new()
    }
}

impl GadgetBridge {
    /// Create a new gadget bridge. Does NOT set up the gadget yet — call `setup()`.
    pub fn new() -> Self {
        Self {
            gadget_path: PathBuf::from("/sys/kernel/config/usb_gadget/coolscan"),
            ffs_path: PathBuf::from("/tmp/coolscan-ffs"),
            ep0: None,
            ep1_out: None,
            ep2_in: None,
            connected: false,
            udc: None,
        }
    }

    /// Set up the USB gadget via configfs and mount FunctionFS.
    /// Returns Ok(()) on success. Requires root or appropriate permissions.
    /// On failure, cleans up any partial state created before the error.
    pub fn setup(&mut self) -> Result<(), String> {
        match self.setup_inner() {
            Ok(()) => Ok(()),
            Err(e) => {
                log::error!("Gadget setup failed: {e}. Cleaning up partial state.");
                self.teardown();
                Err(e)
            }
        }
    }

    fn setup_inner(&mut self) -> Result<(), String> {
        // Step 1: Create gadget directory
        let gp = &self.gadget_path;
        fs::create_dir_all(gp).map_err(|e| format!("create gadget dir: {e}"))?;

        // Step 2: Set USB identifiers
        write_file(&gp.join("idVendor"), &format!("0x{VENDOR_ID:04X}"))?;
        write_file(&gp.join("idProduct"), &format!("0x{PRODUCT_ID:04X}"))?;
        write_file(&gp.join("bcdDevice"), &format!("0x{BCD_DEVICE:04X}"))?;
        write_file(&gp.join("bcdUSB"), "0x0200")?;
        write_file(&gp.join("bDeviceClass"), "0xFF")?;    // Vendor-specific
        write_file(&gp.join("bDeviceSubClass"), "0xFF")?;
        write_file(&gp.join("bDeviceProtocol"), "0xFF")?;

        // Step 3: Set strings
        let strings = gp.join("strings/0x409");
        fs::create_dir_all(&strings).map_err(|e| format!("create strings dir: {e}"))?;
        write_file(&strings.join("manufacturer"), MANUFACTURER)?;
        write_file(&strings.join("product"), PRODUCT)?;
        write_file(&strings.join("serialnumber"), SERIAL)?;

        // Step 4: Create configuration
        let config = gp.join("configs/c.1");
        fs::create_dir_all(&config).map_err(|e| format!("create config dir: {e}"))?;
        write_file(&config.join("MaxPower"), "500")?; // 500mA (self-powered, but declare max)
        let config_strings = config.join("strings/0x409");
        fs::create_dir_all(&config_strings).map_err(|e| format!("create config strings: {e}"))?;
        write_file(&config_strings.join("configuration"), "Coolscan Emulator")?;

        // Step 5: Create FunctionFS function
        let func = gp.join("functions/ffs.coolscan");
        fs::create_dir_all(&func).map_err(|e| format!("create function dir: {e}"))?;

        // Step 6: Link function to configuration
        let link = config.join("ffs.coolscan");
        if !link.exists() {
            std::os::unix::fs::symlink(&func, &link)
                .map_err(|e| format!("symlink function: {e}"))?;
        }

        // Step 7: Mount FunctionFS
        fs::create_dir_all(&self.ffs_path).map_err(|e| format!("create ffs dir: {e}"))?;
        let mount_status = std::process::Command::new("mount")
            .args([
                "-t", "functionfs", "coolscan",
                &self.ffs_path.to_string_lossy(),
            ])
            .status()
            .map_err(|e| format!("mount ffs: {e}"))?;
        if !mount_status.success() {
            return Err("mount functionfs failed".to_string());
        }

        // Step 8: Open EP0 and write descriptors
        let ep0_path = self.ffs_path.join("ep0");
        let mut ep0 = OpenOptions::new()
            .read(true)
            .write(true)
            .open(&ep0_path)
            .map_err(|e| format!("open ep0: {e}"))?;

        // Write FunctionFS descriptors
        let desc = build_ffs_descriptors();
        ep0.write_all(&desc).map_err(|e| format!("write descriptors: {e}"))?;

        // Write FunctionFS strings
        let strings_data = build_ffs_strings();
        ep0.write_all(&strings_data).map_err(|e| format!("write strings: {e}"))?;

        self.ep0 = Some(ep0);

        // Step 9: Open bulk endpoints
        let ep1_path = self.ffs_path.join("ep1");
        let ep2_path = self.ffs_path.join("ep2");

        self.ep1_out = Some(
            OpenOptions::new()
                .read(true)
                .open(&ep1_path)
                .map_err(|e| format!("open ep1: {e}"))?,
        );
        self.ep2_in = Some(
            OpenOptions::new()
                .write(true)
                .open(&ep2_path)
                .map_err(|e| format!("open ep2: {e}"))?,
        );

        // Step 10: Bind to UDC
        let udc = find_udc()?;
        write_file(&gp.join("UDC"), &udc)?;
        self.udc = Some(udc.clone());
        self.connected = true;

        log::info!("USB gadget setup complete: VID={VENDOR_ID:04X} PID={PRODUCT_ID:04X} UDC={udc}");
        Ok(())
    }

    /// Tear down the USB gadget. Best-effort: logs errors but continues cleanup.
    pub fn teardown(&mut self) {
        // Unbind UDC
        if let Some(ref udc) = self.udc
            && let Err(e) = write_file(&self.gadget_path.join("UDC"), "")
        {
            log::warn!("teardown: failed to unbind UDC {udc}: {e}");
        }
        self.udc = None;

        // Close endpoints (must happen before umount)
        self.ep0 = None;
        self.ep1_out = None;
        self.ep2_in = None;

        // Unmount FunctionFS
        let ffs = self.ffs_path.to_string_lossy().to_string();
        match std::process::Command::new("umount").arg(&ffs).status() {
            Ok(s) if !s.success() => log::warn!("teardown: umount {ffs} exited {s}"),
            Err(e) => log::warn!("teardown: umount {ffs} failed: {e}"),
            _ => {}
        }

        // Remove config link and dirs (best-effort, log failures)
        let removals: &[&str] = &[
            "configs/c.1/ffs.coolscan",
            "configs/c.1/strings/0x409",
            "configs/c.1",
            "strings/0x409",
            "functions/ffs.coolscan",
        ];
        for sub in removals {
            let p = self.gadget_path.join(sub);
            if p.exists() {
                let r = if p.is_dir() { fs::remove_dir_all(&p) } else { fs::remove_file(&p) };
                if let Err(e) = r {
                    log::warn!("teardown: remove {}: {e}", p.display());
                }
            }
        }
        if self.gadget_path.exists() && let Err(e) = fs::remove_dir(&self.gadget_path) {
            log::warn!("teardown: remove gadget dir: {e}");
        }

        self.connected = false;
        log::info!("USB gadget teardown complete");
    }
}

impl UsbBridge for GadgetBridge {
    fn recv_ep1_out(&mut self) -> Option<Vec<u8>> {
        if let Some(ref mut ep1) = self.ep1_out {
            let mut buf = [0u8; 512]; // Max packet size for USB 2.0 bulk
            match ep1.read(&mut buf) {
                Ok(0) => {
                    log::info!("EP1 OUT: EOF (host disconnected)");
                    self.connected = false;
                    None
                }
                Ok(n) => Some(buf[..n].to_vec()),
                Err(ref e) if e.kind() == std::io::ErrorKind::WouldBlock => None,
                Err(e) => {
                    log::warn!("EP1 OUT read error: {e}");
                    None
                }
            }
        } else {
            None
        }
    }

    fn send_ep2_in(&mut self, data: &[u8]) {
        let Some(ref mut ep2) = self.ep2_in else {
            return;
        };
        if let Err(e) = ep2.write_all(data) {
            log::warn!("EP2 IN write error after {} bytes: {e}", data.len());
            self.connected = false;
            return;
        }
        // ZLP termination: if the write's length is a non-zero multiple of
        // the bulk max-packet-size, the host has no in-band signal that the
        // transfer is over.
        //
        // `std::io::Write::write_all(&[])` short-circuits and never issues
        // a syscall, so it does NOT cause FunctionFS to emit a ZLP. We
        // have to call write(2) directly with len=0 to make the kernel
        // queue the empty packet on the EP2 IN ring.
        if !data.is_empty() && data.len().is_multiple_of(HS_BULK_MAX_PACKET) {
            let fd = ep2.as_raw_fd();
            // SAFETY: `fd` is owned by `self.ep2_in` (a File), valid for
            // the duration of this call. Pointer can be null when len=0
            // per POSIX write(2). Single-threaded access — `self` is `&mut`.
            let n = unsafe { libc::write(fd, std::ptr::null(), 0) };
            if n < 0 {
                let err = std::io::Error::last_os_error();
                log::warn!("EP2 IN ZLP write error: {err}");
                self.connected = false;
            }
        }
    }

    fn is_connected(&self) -> bool {
        self.connected
    }
}

impl Drop for GadgetBridge {
    fn drop(&mut self) {
        self.teardown();
    }
}

/// Build FunctionFS v2 descriptor block for EP1 OUT + EP2 IN (bulk).
fn build_ffs_descriptors() -> Vec<u8> {
    let mut buf = Vec::new();

    // Header
    buf.extend_from_slice(&FUNCTIONFS_DESCRIPTORS_MAGIC_V2.to_le_bytes());
    // Length placeholder — filled in at the end
    let len_pos = buf.len();
    buf.extend_from_slice(&0u32.to_le_bytes());
    // Flags: full-speed + high-speed descriptors
    buf.extend_from_slice(&(FUNCTIONFS_HAS_FS_DESC | FUNCTIONFS_HAS_HS_DESC).to_le_bytes());

    // Full-speed descriptor count
    buf.extend_from_slice(&3u32.to_le_bytes()); // 1 interface + 2 endpoints

    // High-speed descriptor count
    buf.extend_from_slice(&3u32.to_le_bytes());

    // FS + HS descriptor blocks have identical layout: 1 interface + 2
    // bulk endpoints, only the wMaxPacketSize differs.
    for max_packet in [BULK_FS_MAX_PACKET, BULK_HS_MAX_PACKET] {
        // Interface descriptor (vendor-specific class)
        buf.extend_from_slice(&[
            9,    // bLength
            4,    // bDescriptorType = INTERFACE
            0,    // bInterfaceNumber
            0,    // bAlternateSetting
            2,    // bNumEndpoints
            0xFF, // bInterfaceClass = vendor-specific
            0xFF, // bInterfaceSubClass
            0xFF, // bInterfaceProtocol
            1,    // iInterface (string index)
        ]);
        let mp = max_packet.to_le_bytes();
        for ep_addr in [EP1_OUT_ADDR, EP2_IN_ADDR] {
            buf.extend_from_slice(&[
                7,        // bLength
                5,        // bDescriptorType = ENDPOINT
                ep_addr,
                0x02,     // bmAttributes = Bulk
                mp[0], mp[1],
                0,        // bInterval
            ]);
        }
    }

    // Fill in total length
    let total_len = buf.len() as u32;
    buf[len_pos..len_pos + 4].copy_from_slice(&total_len.to_le_bytes());

    buf
}

/// Build FunctionFS strings block.
fn build_ffs_strings() -> Vec<u8> {
    let mut buf = Vec::new();
    buf.extend_from_slice(&FUNCTIONFS_STRINGS_MAGIC.to_le_bytes());
    let len_pos = buf.len();
    buf.extend_from_slice(&0u32.to_le_bytes()); // length placeholder
    buf.extend_from_slice(&1u32.to_le_bytes()); // str_count
    buf.extend_from_slice(&1u32.to_le_bytes()); // lang_count

    // Language 0x0409 (English)
    buf.extend_from_slice(&0x0409u16.to_le_bytes());
    // String 1: interface name
    buf.extend_from_slice(b"Coolscan Scanner\0");

    let total_len = buf.len() as u32;
    buf[len_pos..len_pos + 4].copy_from_slice(&total_len.to_le_bytes());

    buf
}

/// Find the first available USB Device Controller name.
fn find_udc() -> Result<String, String> {
    let udc_dir = Path::new("/sys/class/udc");
    if !udc_dir.exists() {
        return Err("No /sys/class/udc — USB gadget support not available".to_string());
    }
    for entry in fs::read_dir(udc_dir).map_err(|e| format!("read /sys/class/udc: {e}"))?.flatten() {
        let name = entry.file_name().to_string_lossy().to_string();
        if !name.is_empty() {
            return Ok(name);
        }
    }
    Err("No UDC found in /sys/class/udc".to_string())
}

/// Helper: write a string to a file.
fn write_file(path: &Path, content: &str) -> Result<(), String> {
    fs::write(path, content).map_err(|e| format!("write {}: {e}", path.display()))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_ffs_descriptors_structure() {
        let desc = build_ffs_descriptors();
        // Magic number (LE u32) = 3 (FUNCTIONFS_DESCRIPTORS_MAGIC_V2)
        assert_eq!(u32::from_le_bytes(desc[0..4].try_into().unwrap()), 3);
        // Length field at bytes 4-7 should match actual length
        let len = u32::from_le_bytes(desc[4..8].try_into().unwrap());
        assert_eq!(len as usize, desc.len());
        // Flags at bytes 8-11: HAS_FS_DESC | HAS_HS_DESC = 3
        let flags = u32::from_le_bytes(desc[8..12].try_into().unwrap());
        assert_eq!(flags, 3);
        // FS descriptor count at bytes 12-15: 3 (1 interface + 2 endpoints)
        let fs_count = u32::from_le_bytes(desc[12..16].try_into().unwrap());
        assert_eq!(fs_count, 3);
        // HS descriptor count at bytes 16-19: 3
        let hs_count = u32::from_le_bytes(desc[16..20].try_into().unwrap());
        assert_eq!(hs_count, 3);
        // FS interface descriptor starts at byte 20, bLength=9, bDescriptorType=4
        assert_eq!(desc[20], 9);
        assert_eq!(desc[21], 4);
        // FS EP1 OUT: bEndpointAddress=0x01, bmAttributes=0x02 (bulk)
        assert_eq!(desc[29 + 2], 0x01);
        assert_eq!(desc[29 + 3], 0x02);
        // FS EP2 IN: bEndpointAddress=0x82, bmAttributes=0x02 (bulk)
        assert_eq!(desc[36 + 2], 0x82);
        assert_eq!(desc[36 + 3], 0x02);
    }

    #[test]
    fn test_ffs_descriptors_hs_packet_size() {
        let desc = build_ffs_descriptors();
        // High-speed descriptors start after FS: 20 (header) + 9+7+7 = 43
        let hs_start = 20 + 9 + 7 + 7; // = 43
        // HS interface descriptor
        assert_eq!(desc[hs_start], 9);
        assert_eq!(desc[hs_start + 1], 4);
        // HS EP1 OUT: wMaxPacketSize = 512 (0x0200 LE)
        let ep1_start = hs_start + 9;
        assert_eq!(desc[ep1_start + 4], 0x00); // low byte
        assert_eq!(desc[ep1_start + 5], 0x02); // high byte = 512
        // HS EP2 IN: wMaxPacketSize = 512
        let ep2_start = ep1_start + 7;
        assert_eq!(desc[ep2_start + 4], 0x00);
        assert_eq!(desc[ep2_start + 5], 0x02);
    }

    #[test]
    fn test_ffs_strings_structure() {
        let strings = build_ffs_strings();
        // Magic = 2 (FUNCTIONFS_STRINGS_MAGIC)
        assert_eq!(u32::from_le_bytes(strings[0..4].try_into().unwrap()), 2);
        // Length field matches actual length
        let len = u32::from_le_bytes(strings[4..8].try_into().unwrap());
        assert_eq!(len as usize, strings.len());
        // str_count = 1
        assert_eq!(u32::from_le_bytes(strings[8..12].try_into().unwrap()), 1);
        // lang_count = 1
        assert_eq!(u32::from_le_bytes(strings[12..16].try_into().unwrap()), 1);
        // Language ID = 0x0409 (English)
        assert_eq!(u16::from_le_bytes(strings[16..18].try_into().unwrap()), 0x0409);
        // String 1 should be null-terminated "Coolscan Scanner"
        let str_bytes = &strings[18..];
        assert!(str_bytes.ends_with(&[0]));
        let s = std::str::from_utf8(&str_bytes[..str_bytes.len() - 1]).unwrap();
        assert_eq!(s, "Coolscan Scanner");
    }

    #[test]
    fn test_gadget_bridge_default() {
        let bridge = GadgetBridge::new();
        assert!(!bridge.connected);
        assert!(bridge.ep0.is_none());
        assert!(bridge.ep1_out.is_none());
        assert!(bridge.ep2_in.is_none());
        assert!(bridge.udc.is_none());
        assert!(!bridge.is_connected());
    }
}
