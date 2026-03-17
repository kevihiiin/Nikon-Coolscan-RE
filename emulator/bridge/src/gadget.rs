/// Linux USB Gadget bridge using FunctionFS.
///
/// Presents the emulator as a real USB device (VID 04B0, PID 4001 = Nikon LS-50).
/// Uses configfs to create the gadget and FunctionFS for endpoint I/O.
///
/// Requires: Linux kernel with USB gadget support (configfs + functionfs).
/// Typically needs root or appropriate permissions.
///
/// Endpoints:
///   EP1 OUT (bulk) — host sends CDB / data-out
///   EP2 IN  (bulk) — device sends phase / data-in / sense

use crate::traits::UsbBridge;
use std::fs::{self, File, OpenOptions};
use std::io::{Read, Write};
use std::path::{Path, PathBuf};

/// Nikon Coolscan V USB identifiers.
const VENDOR_ID: u16 = 0x04B0;   // Nikon
const PRODUCT_ID: u16 = 0x4001;  // LS-50
const BCD_DEVICE: u16 = 0x0102;
const MANUFACTURER: &str = "NIKON";
const PRODUCT: &str = "LS-50 ED          ";
const SERIAL: &str = "DF17811";

/// FunctionFS descriptor header magic numbers.
const FUNCTIONFS_DESCRIPTORS_MAGIC_V2: u32 = 3;
const FUNCTIONFS_STRINGS_MAGIC: u32 = 2;
const FUNCTIONFS_HAS_FS_DESC: u32 = 1;
const FUNCTIONFS_HAS_HS_DESC: u32 = 2;

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
    pub fn setup(&mut self) -> Result<(), String> {
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
                self.ffs_path.to_str().unwrap(),
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

    /// Tear down the USB gadget.
    pub fn teardown(&mut self) {
        // Unbind UDC
        if let Some(ref udc) = self.udc {
            let _ = write_file(&self.gadget_path.join("UDC"), "");
            log::info!("Unbound UDC {udc}");
        }

        // Close endpoints
        self.ep0 = None;
        self.ep1_out = None;
        self.ep2_in = None;

        // Unmount FunctionFS
        let _ = std::process::Command::new("umount")
            .arg(self.ffs_path.to_str().unwrap())
            .status();

        // Remove config link
        let link = self.gadget_path.join("configs/c.1/ffs.coolscan");
        let _ = fs::remove_file(&link);

        // Remove gadget dirs (in reverse order)
        let _ = fs::remove_dir_all(self.gadget_path.join("configs/c.1/strings/0x409"));
        let _ = fs::remove_dir(self.gadget_path.join("configs/c.1"));
        let _ = fs::remove_dir_all(self.gadget_path.join("strings/0x409"));
        let _ = fs::remove_dir(self.gadget_path.join("functions/ffs.coolscan"));
        let _ = fs::remove_dir(&self.gadget_path);

        self.connected = false;
        log::info!("USB gadget torn down");
    }
}

impl UsbBridge for GadgetBridge {
    fn recv_ep1_out(&mut self) -> Option<Vec<u8>> {
        if let Some(ref mut ep1) = self.ep1_out {
            let mut buf = [0u8; 512]; // Max packet size for USB 2.0 bulk
            match ep1.read(&mut buf) {
                Ok(n) if n > 0 => Some(buf[..n].to_vec()),
                _ => None,
            }
        } else {
            None
        }
    }

    fn send_ep2_in(&mut self, data: &[u8]) {
        if let Some(ref mut ep2) = self.ep2_in {
            if let Err(e) = ep2.write_all(data) {
                log::warn!("EP2 IN write error: {e}");
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

    // --- Full-speed descriptors ---
    // Interface descriptor
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
    // EP1 OUT bulk
    buf.extend_from_slice(&[
        7,    // bLength
        5,    // bDescriptorType = ENDPOINT
        0x01, // bEndpointAddress = EP1 OUT
        0x02, // bmAttributes = Bulk
        64, 0, // wMaxPacketSize = 64 (full-speed)
        0,    // bInterval
    ]);
    // EP2 IN bulk
    buf.extend_from_slice(&[
        7,    // bLength
        5,    // bDescriptorType = ENDPOINT
        0x82, // bEndpointAddress = EP2 IN
        0x02, // bmAttributes = Bulk
        64, 0, // wMaxPacketSize = 64 (full-speed)
        0,    // bInterval
    ]);

    // --- High-speed descriptors ---
    // Interface descriptor (same as full-speed)
    buf.extend_from_slice(&[9, 4, 0, 0, 2, 0xFF, 0xFF, 0xFF, 1]);
    // EP1 OUT bulk (512 byte packets for high-speed)
    buf.extend_from_slice(&[7, 5, 0x01, 0x02, 0, 2, 0]); // wMaxPacketSize = 512
    // EP2 IN bulk
    buf.extend_from_slice(&[7, 5, 0x82, 0x02, 0, 2, 0]); // wMaxPacketSize = 512

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
    for entry in fs::read_dir(udc_dir).map_err(|e| format!("read /sys/class/udc: {e}"))? {
        if let Ok(entry) = entry {
            let name = entry.file_name().to_string_lossy().to_string();
            if !name.is_empty() {
                return Ok(name);
            }
        }
    }
    Err("No UDC found in /sys/class/udc".to_string())
}

/// Helper: write a string to a file.
fn write_file(path: &Path, content: &str) -> Result<(), String> {
    fs::write(path, content).map_err(|e| format!("write {}: {e}", path.display()))
}
