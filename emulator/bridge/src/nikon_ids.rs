//! Nikon Coolscan V USB device identifiers — the constants that any bridge
//! impl needs to advertise to make NikonScan recognize the emulator as a
//! real LS-50.
//!
//! Sourced from `binaries/firmware/Nikon LS-50 MBM29F400B TSOP48.bin`'s USB
//! descriptor table at flash offset 0x170FA (USB 1.1) / 0x1710C (USB 2.0).
//! See `docs/kb/components/firmware/usb-descriptors.md` for the full RE.

/// USB Vendor ID for Nikon Corporation.
pub const VENDOR_ID: u16 = 0x04B0;

/// USB Product ID for LS-50 / Coolscan V.
pub const PRODUCT_ID: u16 = 0x4001;

/// `bcdDevice` from the firmware descriptor (firmware version 1.02).
pub const BCD_DEVICE: u16 = 0x0102;

/// `iManufacturer` string.
pub const MANUFACTURER: &str = "NIKON";

/// `iProduct` string. Padded with trailing spaces to match the firmware's
/// fixed-width SCSI INQUIRY product field — preserved here for byte-for-byte
/// equivalence with NikonScan's identification logic.
pub const PRODUCT: &str = "LS-50 ED          ";

/// `iSerialNumber` string from the original device.
pub const SERIAL: &str = "DF17811";

// --- USB endpoint layout (firmware-defined, identical across all bridges) ---
//
// The Coolscan firmware defines two bulk endpoints. Any bridge that
// presents the device to a host (gadget, USB/IP server, future paths)
// must advertise these exact addresses or the firmware's IRQ1 ISR
// won't recognize incoming CDBs and the host won't find the IN pipe.

/// EP1 OUT (bulk): host → device. Receives CDB and data-out phases.
pub const EP1_OUT_ADDR: u8 = 0x01;

/// EP2 IN (bulk): device → host. Sends responses and data-in phases.
pub const EP2_IN_ADDR: u8 = 0x82;

/// USB 2.0 high-speed bulk max-packet-size advertised by the firmware
/// in its USB 2.0 device descriptor (flash offset 0x1710C). Drives both
/// the FunctionFS HS descriptor block and the USB/IP simulated endpoint
/// layout. Also the size used by `bridge::gadget` to decide when a
/// boundary-aligned write needs a ZLP terminator.
pub const BULK_HS_MAX_PACKET: u16 = 512;

/// USB 1.1 full-speed bulk max-packet-size from the firmware's USB 1.1
/// device descriptor (flash offset 0x170FA). Used only by the FunctionFS
/// FS descriptor block; USB/IP transport always negotiates high-speed.
pub const BULK_FS_MAX_PACKET: u16 = 64;
