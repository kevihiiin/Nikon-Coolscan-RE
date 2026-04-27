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
