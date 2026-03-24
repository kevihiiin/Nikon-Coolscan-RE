//! End-to-end integration test: boot firmware, run full SCSI scan sequence.
//!
//! This test loads the real LS-50 firmware binary, boots the emulator to the
//! main loop, then executes the complete NikonScan initialization and scan
//! sequence, validating each SCSI command response.

use coolscan_emu::config::Config;
use coolscan_emu::orchestrator::Emulator;
use std::path::PathBuf;

/// Path to the firmware binary (relative to workspace root).
const FIRMWARE_PATH: &str = "../../binaries/firmware/Nikon LS-50 MBM29F400B TSOP48.bin";

fn load_firmware() -> Vec<u8> {
    let path = PathBuf::from(env!("CARGO_MANIFEST_DIR")).join(FIRMWARE_PATH);
    std::fs::read(&path).unwrap_or_else(|e| {
        panic!("Cannot read firmware at {}: {}", path.display(), e);
    })
}

fn make_config() -> Config {
    Config::test_default()
}

fn boot_emulator() -> Emulator {
    let firmware = load_firmware();
    let config = make_config();
    let mut emu = Emulator::new(&firmware, &config);
    let ok = emu.boot_to_main_loop(5_000_000);
    assert!(ok, "Firmware failed to reach main loop within 5M instructions");
    emu
}

// --- SCSI CDB builders ---

fn cdb_tur() -> Vec<u8> {
    vec![0x00, 0x00, 0x00, 0x00, 0x00, 0x00]
}

fn cdb_inquiry(alloc_len: u8) -> Vec<u8> {
    vec![0x12, 0x00, 0x00, 0x00, alloc_len, 0x00]
}

fn cdb_inquiry_evpd(page: u8, alloc_len: u8) -> Vec<u8> {
    vec![0x12, 0x01, page, 0x00, alloc_len, 0x00]
}

fn cdb_request_sense(alloc_len: u8) -> Vec<u8> {
    vec![0x03, 0x00, 0x00, 0x00, alloc_len, 0x00]
}

fn cdb_reserve() -> Vec<u8> {
    vec![0x16, 0x00, 0x00, 0x00, 0x00, 0x00]
}

fn cdb_release() -> Vec<u8> {
    vec![0x17, 0x00, 0x00, 0x00, 0x00, 0x00]
}

fn cdb_mode_select(param_len: u8) -> Vec<u8> {
    vec![0x15, 0x10, 0x00, 0x00, param_len, 0x00]
}

fn cdb_mode_sense(page: u8, alloc_len: u8) -> Vec<u8> {
    vec![0x1A, 0x18, page, 0x00, alloc_len, 0x00]
}

fn cdb_send_diagnostic() -> Vec<u8> {
    vec![0x1D, 0x04, 0x00, 0x00, 0x00, 0x00]
}

fn cdb_set_window(xfer_len: u32) -> Vec<u8> {
    vec![
        0x24, 0x00, 0x00, 0x00, 0x00, 0x00,
        ((xfer_len >> 16) & 0xFF) as u8,
        ((xfer_len >> 8) & 0xFF) as u8,
        (xfer_len & 0xFF) as u8,
        0x80,
    ]
}

fn cdb_get_window(alloc_len: u32) -> Vec<u8> {
    vec![
        0x25, 0x00, 0x00, 0x00, 0x00, 0x00,
        ((alloc_len >> 16) & 0xFF) as u8,
        ((alloc_len >> 8) & 0xFF) as u8,
        (alloc_len & 0xFF) as u8,
        0x00,
    ]
}

fn cdb_scan(op_type: u8) -> Vec<u8> {
    vec![0x1B, 0x00, 0x00, 0x00, op_type, 0x00]
}

fn cdb_read(dtc: u8, qualifier: u8, xfer_len: u32) -> Vec<u8> {
    vec![
        0x28, 0x00,
        dtc,
        0x00, 0x00,
        qualifier,
        ((xfer_len >> 16) & 0xFF) as u8,
        ((xfer_len >> 8) & 0xFF) as u8,
        (xfer_len & 0xFF) as u8,
        0x80,
    ]
}

fn cdb_write(dtc: u8, qualifier: u8, xfer_len: u32) -> Vec<u8> {
    vec![
        0x2A, 0x00,
        dtc,
        0x00, 0x00,
        qualifier,
        ((xfer_len >> 16) & 0xFF) as u8,
        ((xfer_len >> 8) & 0xFF) as u8,
        (xfer_len & 0xFF) as u8,
        0x00,
    ]
}

/// Build a window descriptor for 300 DPI, 1x1 inch, 8-bit RGB scan.
fn build_window_descriptor() -> Vec<u8> {
    let mut wd = vec![0u8; 80];
    // Window descriptor length = 72 (at bytes 6-7)
    wd[6] = 0x00; wd[7] = 72;
    // X resolution = 300 DPI (bytes 10-11)
    wd[10] = 0x01; wd[11] = 0x2C;
    // Y resolution = 300 DPI (bytes 12-13)
    wd[12] = 0x01; wd[13] = 0x2C;
    // Width = 1200 (1 inch in 1/1200 units, bytes 22-25)
    wd[22] = 0x00; wd[23] = 0x00; wd[24] = 0x04; wd[25] = 0xB0;
    // Height = 1200 (1 inch, bytes 26-29)
    wd[26] = 0x00; wd[27] = 0x00; wd[28] = 0x04; wd[29] = 0xB0;
    // Image composition = 5 (RGB)
    wd[33] = 5;
    // Bits per pixel = 8
    wd[34] = 8;
    wd
}

// --- Tests ---

#[test]
fn test_firmware_boots() {
    let _ = env_logger::builder().is_test(true).try_init();
    let _emu = boot_emulator();
    // If we get here, firmware booted successfully
}

#[test]
fn test_tur() {
    let _ = env_logger::builder().is_test(true).try_init();
    let mut emu = boot_emulator();
    let result = emu.scsi_command(&cdb_tur());
    assert!(result.is_good(), "TUR should return GOOD, got SK={}", result.sense_key);
}

#[test]
fn test_inquiry_standard() {
    let _ = env_logger::builder().is_test(true).try_init();
    let mut emu = boot_emulator();
    let result = emu.scsi_command(&cdb_inquiry(36));
    assert!(result.is_good(), "INQUIRY should return GOOD");
    assert_eq!(result.data.len(), 36, "INQUIRY should return 36 bytes");

    // Device type = 0x06 (scanner)
    assert_eq!(result.data[0] & 0x1F, 0x06, "Device type should be scanner (0x06)");

    // Vendor string at bytes 8-15 should be "Nikon   "
    let vendor = String::from_utf8_lossy(&result.data[8..16]);
    assert_eq!(vendor.trim(), "Nikon", "Vendor should be 'Nikon'");

    // Product string at bytes 16-31 should contain "LS-50 ED"
    let product = String::from_utf8_lossy(&result.data[16..32]);
    assert!(product.contains("LS-50 ED"), "Product should contain 'LS-50 ED', got '{}'", product);

    // Revision at bytes 32-35
    let revision = String::from_utf8_lossy(&result.data[32..36]);
    assert!(revision.contains("1.02"), "Revision should be '1.02', got '{}'", revision);
}

#[test]
fn test_inquiry_evpd_page_00() {
    let _ = env_logger::builder().is_test(true).try_init();
    let mut emu = boot_emulator();
    let result = emu.scsi_command(&cdb_inquiry_evpd(0x00, 16));
    assert!(result.is_good(), "INQUIRY EVPD page 0x00 should return GOOD");
    assert!(!result.data.is_empty(), "Should return supported VPD page list");
    // Device type byte should be scanner
    assert_eq!(result.data[0] & 0x1F, 0x06);
}

#[test]
fn test_request_sense() {
    let _ = env_logger::builder().is_test(true).try_init();
    let mut emu = boot_emulator();
    let result = emu.scsi_command(&cdb_request_sense(18));
    assert!(result.is_good(), "REQUEST SENSE should return GOOD (and clear sense)");
    assert_eq!(result.data.len(), 18, "Should return 18 bytes");
    // Response code = 0x70 (current errors)
    assert_eq!(result.data[0], 0x70, "Response code should be 0x70");
    // After boot, sense key should be 0 (no error)
    assert_eq!(result.data[2] & 0x0F, 0, "Sense key should be 0 after boot");
}

#[test]
fn test_reserve_release() {
    let _ = env_logger::builder().is_test(true).try_init();
    let mut emu = boot_emulator();

    let r = emu.scsi_command(&cdb_reserve());
    assert!(r.is_good(), "RESERVE should return GOOD");

    let r = emu.scsi_command(&cdb_release());
    assert!(r.is_good(), "RELEASE should return GOOD");
}

#[test]
fn test_mode_sense() {
    let _ = env_logger::builder().is_test(true).try_init();
    let mut emu = boot_emulator();

    let result = emu.scsi_command(&cdb_mode_sense(0x03, 36));
    assert!(result.is_good(), "MODE SENSE page 0x03 should return GOOD");
    assert!(!result.data.is_empty(), "Should return mode page data");
}

#[test]
fn test_mode_select() {
    let _ = env_logger::builder().is_test(true).try_init();
    let mut emu = boot_emulator();

    let mode_data = vec![0x00, 0x00, 0x00, 0x00];
    let r = emu.scsi_command_out(&cdb_mode_select(4), &mode_data);
    assert!(r.is_good(), "MODE SELECT should return GOOD");
}

#[test]
fn test_send_diagnostic() {
    let _ = env_logger::builder().is_test(true).try_init();
    let mut emu = boot_emulator();

    let r = emu.scsi_command(&cdb_send_diagnostic());
    assert!(r.is_good(), "SEND DIAGNOSTIC should return GOOD");
}

#[test]
fn test_set_get_window() {
    let _ = env_logger::builder().is_test(true).try_init();
    let mut emu = boot_emulator();

    let wd = build_window_descriptor();
    let r = emu.scsi_command_out(&cdb_set_window(80), &wd);
    assert!(r.is_good(), "SET WINDOW should return GOOD");

    let r = emu.scsi_command(&cdb_get_window(88));
    assert!(r.is_good(), "GET WINDOW should return GOOD");
    assert_eq!(r.data.len(), 80, "GET WINDOW should return stored window descriptor");
}

#[test]
fn test_read_scan_params() {
    let _ = env_logger::builder().is_test(true).try_init();
    let mut emu = boot_emulator();

    let r = emu.scsi_command(&cdb_read(0x87, 0, 24));
    assert!(r.is_good(), "READ DTC=0x87 should return GOOD");
    assert_eq!(r.data.len(), 24, "Scan params should be 24 bytes");
}

#[test]
fn test_read_boundary() {
    let _ = env_logger::builder().is_test(true).try_init();
    let mut emu = boot_emulator();

    let r = emu.scsi_command(&cdb_read(0x88, 0, 644));
    assert!(r.is_good(), "READ DTC=0x88 should return GOOD");
    assert_eq!(r.data.len(), 644, "Boundary data should be 644 bytes");
}

#[test]
fn test_write_gamma_lut() {
    let _ = env_logger::builder().is_test(true).try_init();
    let mut emu = boot_emulator();

    // 768 bytes: 3 channels × 256 entries
    let lut: Vec<u8> = (0..=255u8).cycle().take(768).collect();
    let r = emu.scsi_command_out(&cdb_write(0x03, 0, 768), &lut);
    assert!(r.is_good(), "WRITE DTC=0x03 should return GOOD");
}

#[test]
fn test_illegal_opcode() {
    let _ = env_logger::builder().is_test(true).try_init();
    let mut emu = boot_emulator();

    let r = emu.scsi_command(&[0xFF, 0x00, 0x00, 0x00, 0x00, 0x00]);
    assert_eq!(r.sense_key, 5, "Unknown opcode should return ILLEGAL REQUEST (SK=5)");
    assert_eq!(r.asc, 0x24, "ASC should be 0x24");
}

#[test]
fn test_full_scan_sequence() {
    let _ = env_logger::builder().is_test(true).try_init();
    let mut emu = boot_emulator();

    // 1. TUR
    let r = emu.scsi_command(&cdb_tur());
    assert!(r.is_good(), "TUR failed");

    // 2. INQUIRY
    let r = emu.scsi_command(&cdb_inquiry(36));
    assert!(r.is_good(), "INQUIRY failed");
    assert_eq!(r.data.len(), 36);

    // 3. REQUEST SENSE (clear any pending)
    let r = emu.scsi_command(&cdb_request_sense(18));
    assert!(r.is_good(), "REQUEST SENSE failed");

    // 4. RESERVE
    let r = emu.scsi_command(&cdb_reserve());
    assert!(r.is_good(), "RESERVE failed");

    // 5. MODE SELECT
    let r = emu.scsi_command_out(&cdb_mode_select(4), &[0, 0, 0, 0]);
    assert!(r.is_good(), "MODE SELECT failed");

    // 6. SEND DIAGNOSTIC
    let r = emu.scsi_command(&cdb_send_diagnostic());
    assert!(r.is_good(), "SEND DIAGNOSTIC failed");

    // 7. SET WINDOW (300 DPI, 1x1 inch, 8-bit RGB)
    let wd = build_window_descriptor();
    let r = emu.scsi_command_out(&cdb_set_window(80), &wd);
    assert!(r.is_good(), "SET WINDOW failed");

    // 8. GET WINDOW (verify)
    let r = emu.scsi_command(&cdb_get_window(88));
    assert!(r.is_good(), "GET WINDOW failed");
    assert_eq!(r.data.len(), 80);

    // 9. READ scan parameters
    let r = emu.scsi_command(&cdb_read(0x87, 0, 24));
    assert!(r.is_good(), "READ scan params failed");
    // Parse width/height from scan params
    let width = ((r.data[0] as u32) << 8) | r.data[1] as u32;
    let height = ((r.data[2] as u32) << 8) | r.data[3] as u32;
    assert_eq!(width, 300, "Scan width should be 300 pixels");
    assert_eq!(height, 300, "Scan height should be 300 pixels");

    // 10. READ boundary data
    let r = emu.scsi_command(&cdb_read(0x88, 0, 644));
    assert!(r.is_good(), "READ boundary failed");

    // 11. WRITE gamma LUT
    let lut: Vec<u8> = (0..=255u8).cycle().take(768).collect();
    let r = emu.scsi_command_out(&cdb_write(0x03, 0, 768), &lut);
    assert!(r.is_good(), "WRITE gamma LUT failed");

    // 12. SCAN (initiate)
    let r = emu.scsi_command(&cdb_scan(0));
    assert!(r.is_good(), "SCAN failed");
    assert!(emu.is_scan_active(), "Scan should be active after SCAN command");

    // 13. READ image data in chunks
    // 300x300 pixels × 3 channels × 1 byte = 270,000 bytes
    let expected_size = 300 * 300 * 3;
    let mut total_bytes = 0;
    let mut chunk_count = 0;
    loop {
        let r = emu.scsi_command(&cdb_read(0x00, 0, 4096));
        assert!(r.is_good(), "READ image data chunk {} failed", chunk_count);
        if r.data.is_empty() {
            break;
        }
        total_bytes += r.data.len();
        chunk_count += 1;
        if r.data.len() < 4096 {
            break; // Last chunk
        }
    }

    assert_eq!(total_bytes, expected_size,
        "Total image data should be {} bytes (300x300x3), got {} in {} chunks",
        expected_size, total_bytes, chunk_count);
    assert!(!emu.is_scan_active(), "Scan should be complete after reading all data");

    // 14. Final REQUEST SENSE — should be GOOD
    let r = emu.scsi_command(&cdb_request_sense(18));
    assert!(r.is_good(), "Final REQUEST SENSE failed");

    // 15. RELEASE
    let r = emu.scsi_command(&cdb_release());
    assert!(r.is_good(), "RELEASE failed");
}

#[test]
fn test_vendor_commands() {
    let _ = env_logger::builder().is_test(true).try_init();
    let mut emu = boot_emulator();

    // Vendor C0 (trigger)
    let r = emu.scsi_command(&[0xC0, 0x00, 0x00, 0x00, 0x00, 0x00]);
    assert!(r.is_good(), "VENDOR C0 should return GOOD");

    // Vendor C1 (trigger)
    let r = emu.scsi_command(&[0xC1, 0x00, 0x00, 0x00, 0x00, 0x00]);
    assert!(r.is_good(), "VENDOR C1 should return GOOD");

    // Vendor E0 (data-out, 6 bytes)
    let r = emu.scsi_command_out(
        &[0xE0, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x06, 0x00],
        &[0x01, 0x02, 0x03, 0x04, 0x05, 0x06],
    );
    assert!(r.is_good(), "VENDOR E0 should return GOOD");

    // Vendor E1 (data-in, 6 bytes)
    let r = emu.scsi_command(&[0xE1, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x06, 0x00]);
    assert!(r.is_good(), "VENDOR E1 should return GOOD");
    assert_eq!(r.data.len(), 6, "VENDOR E1 should return 6 bytes");
}

// --- Nice-to-have feature tests ---

fn make_config_with(pattern: coolscan_emu::config::ScanPattern, model: coolscan_emu::config::ScannerModel) -> Config {
    let mut c = Config::test_default();
    c.pattern = pattern;
    c.model = model;
    c
}

fn boot_with_config(config: &Config) -> Emulator {
    let firmware = load_firmware();
    let mut emu = Emulator::new(&firmware, config);
    let ok = emu.boot_to_main_loop(5_000_000);
    assert!(ok, "Firmware failed to reach main loop");
    emu
}

#[test]
fn test_flat_pattern() {
    let _ = env_logger::builder().is_test(true).try_init();
    let config = make_config_with(
        coolscan_emu::config::ScanPattern::Flat,
        coolscan_emu::config::ScannerModel::Ls50,
    );
    let mut emu = boot_with_config(&config);

    emu.scsi_command(&cdb_reserve());
    let wd = build_window_descriptor();
    emu.scsi_command_out(&cdb_set_window(wd.len() as u32), &wd);
    emu.scsi_command(&cdb_scan(0));

    let r = emu.scsi_command(&cdb_read(0x00, 0x00, 4096));
    assert!(r.is_good());
    assert!(r.data.iter().all(|&b| b == 128), "flat pattern should be uniform 128");
}

#[test]
fn test_checkerboard_pattern() {
    let _ = env_logger::builder().is_test(true).try_init();
    let config = make_config_with(
        coolscan_emu::config::ScanPattern::Checkerboard,
        coolscan_emu::config::ScannerModel::Ls50,
    );
    let mut emu = boot_with_config(&config);

    emu.scsi_command(&cdb_reserve());
    let wd = build_window_descriptor();
    emu.scsi_command_out(&cdb_set_window(wd.len() as u32), &wd);
    emu.scsi_command(&cdb_scan(0));

    let r = emu.scsi_command(&cdb_read(0x00, 0x00, 4096));
    assert!(r.is_good());
    // Checkerboard: first pixel (0,0) is in block (0,0) -> white (255)
    assert_eq!(r.data[0], 255, "checkerboard (0,0) R should be 255");
    assert_eq!(r.data[1], 255, "checkerboard (0,0) G should be 255");
    assert_eq!(r.data[2], 255, "checkerboard (0,0) B should be 255");
}

#[test]
fn test_colorbars_pattern() {
    let _ = env_logger::builder().is_test(true).try_init();
    let config = make_config_with(
        coolscan_emu::config::ScanPattern::ColorBars,
        coolscan_emu::config::ScannerModel::Ls50,
    );
    let mut emu = boot_with_config(&config);

    emu.scsi_command(&cdb_reserve());
    let wd = build_window_descriptor();
    emu.scsi_command_out(&cdb_set_window(wd.len() as u32), &wd);
    emu.scsi_command(&cdb_scan(0));

    let r = emu.scsi_command(&cdb_read(0x00, 0x00, 4096));
    assert!(r.is_good());
    // First bar (leftmost) = White (255, 255, 255)
    assert_eq!(r.data[0], 255, "colorbars bar 0 R = 255 (white)");
    assert_eq!(r.data[1], 255, "colorbars bar 0 G = 255 (white)");
    assert_eq!(r.data[2], 255, "colorbars bar 0 B = 255 (white)");
}

#[test]
fn test_ls5000_model_inquiry() {
    let _ = env_logger::builder().is_test(true).try_init();
    let config = make_config_with(
        coolscan_emu::config::ScanPattern::Gradient,
        coolscan_emu::config::ScannerModel::Ls5000,
    );
    let mut emu = boot_with_config(&config);

    let r = emu.scsi_command(&cdb_inquiry(36));
    assert!(r.is_good());
    assert_eq!(r.data.len(), 36);
    let product = std::str::from_utf8(&r.data[16..32]).unwrap().trim();
    assert_eq!(product, "LS-5000 ED", "model override should produce LS-5000 in INQUIRY");
}

// --- Design gap feature tests ---

#[test]
fn test_firmware_dispatch_tur() {
    let _ = env_logger::builder().is_test(true).try_init();
    let mut config = Config::test_default();
    config.firmware_dispatch = true;
    let mut emu = boot_with_config(&config);

    let r = emu.scsi_command(&cdb_tur());
    assert!(r.is_good(), "FW dispatch: TUR should return GOOD, got SK={}", r.sense_key);
}

#[test]
fn test_firmware_dispatch_inquiry() {
    let _ = env_logger::builder().is_test(true).try_init();
    let mut config = Config::test_default();
    config.firmware_dispatch = true;
    let mut emu = boot_with_config(&config);

    let r = emu.scsi_command(&cdb_inquiry(36));
    // Handler runs but USB data transfer calls are NOPed, so INQUIRY
    // completes without error but may not produce data output.
    assert_eq!(r.sense_key, 0, "FW dispatch INQUIRY should return GOOD, got SK={}", r.sense_key);
}

#[test]
fn test_scan_data_from_file() {
    let _ = env_logger::builder().is_test(true).try_init();

    // Create a temp file with known data
    let dir = std::env::temp_dir();
    let path = dir.join("coolscan_test_scan_data.raw");
    // 300*300*3 = 270000 bytes of value 0x42
    let data = vec![0x42u8; 270_000];
    std::fs::write(&path, &data).expect("write temp scan data");

    let mut config = Config::test_default();
    config.scan_data_path = Some(path.clone());
    let mut emu = boot_with_config(&config);

    emu.scsi_command(&cdb_reserve());
    let wd = build_window_descriptor();
    emu.scsi_command_out(&cdb_set_window(wd.len() as u32), &wd);
    emu.scsi_command(&cdb_scan(0));

    let r = emu.scsi_command(&cdb_read(0x00, 0x00, 4096));
    assert!(r.is_good());
    assert!(r.data.iter().all(|&b| b == 0x42), "scan data from file should all be 0x42");

    std::fs::remove_file(&path).ok();
}

#[test]
fn test_isp1581_config_registers() {
    // Verify ISP1581 config registers accept writes and return correct values
    let mut isp = peripherals::isp1581::Isp1581::new();

    // Address register (offset 0x00)
    isp.write_word(0x00, 0x0042);
    assert_eq!(isp.read_word(0x00), 0x0042);

    // Interrupt Configuration (offset 0x10)
    isp.write_word(0x10, 0x00FF);
    assert_eq!(isp.read_word(0x10), 0x00FF);

    // Interrupt Enable (offset 0x14)
    isp.write_word(0x14, 0x1234);
    assert_eq!(isp.read_word(0x14), 0x1234);

    // Control Function (offset 0x28)
    isp.write_word(0x28, 0x0007);
    assert_eq!(isp.read_word(0x28), 0x0007);

    // Chip ID (read-only, ISP1581 datasheet Table 60: CHIPID[15:0] = 0x1581)
    assert_eq!(isp.read_word(0x70), 0x1581);
}

#[test]
fn test_asic_cold_boot_mode() {
    let mut asic = peripherals::asic::Asic::new();
    asic.cold_boot_mode = true;

    // Master enable should NOT set ready immediately
    asic.write(0x0001, 0x80);
    assert_eq!(asic.read(0x0041) & 0x02, 0x00, "ready bit NOT set immediately in cold boot");

    // After 49999 ticks, still not ready
    for _ in 0..49_999 {
        asic.tick();
    }
    assert_eq!(asic.read(0x0041) & 0x02, 0x00, "ready bit NOT set after 49999 ticks");

    // One more tick completes the countdown
    asic.tick();
    assert_eq!(asic.read(0x0041) & 0x02, 0x02, "ready bit set after 50000 ticks");
}

#[test]
fn test_firmware_dispatch_illegal_opcode() {
    let _ = env_logger::builder().is_test(true).try_init();
    let mut config = Config::test_default();
    config.firmware_dispatch = true;
    let mut emu = boot_with_config(&config);

    // 0xFF is not in the firmware dispatch table — should get ILLEGAL REQUEST
    let r = emu.scsi_command(&[0xFF, 0x00, 0x00, 0x00, 0x00, 0x00]);
    assert_eq!(r.sense_key, 5, "unknown opcode via FW dispatch should return ILLEGAL REQUEST");
}

#[test]
fn test_scan_data_file_missing() {
    let _ = env_logger::builder().is_test(true).try_init();
    let mut config = Config::test_default();
    config.scan_data_path = Some(std::path::PathBuf::from("/tmp/nonexistent_coolscan_test_data.raw"));
    let mut emu = boot_with_config(&config);

    emu.scsi_command(&cdb_reserve());
    let wd = build_window_descriptor();
    emu.scsi_command_out(&cdb_set_window(wd.len() as u32), &wd);

    let r = emu.scsi_command(&cdb_scan(0));
    assert_ne!(r.sense_key, 0, "SCAN with missing file should fail, not silently succeed");
}

// --- Phase 7 Gate: ISP1581 Register Access Trace ---

/// Phase 7.0 GATE: Trace ISP1581 register accesses during INQUIRY firmware dispatch.
///
/// This test un-NOPs the INQUIRY handler's 2 USB call patches, then runs INQUIRY
/// via firmware dispatch. The ISP1581 trace logs (RUST_LOG=trace) reveal:
/// 1. Which ISP1581 register offsets the response manager (0x01374A) accesses
/// 2. Which DcInterrupt bits the firmware checks for completion
/// 3. Whether execution enters RAM USB code at 0x4010A0-0x4011A2
///
/// Run with: RUST_LOG=info,peripherals::isp1581=trace cargo test gate_trace_inquiry -- --nocapture
#[test]
fn gate_trace_inquiry_isp1581_access() {
    let _ = env_logger::builder().is_test(true).try_init();
    let mut config = Config::test_default();
    config.firmware_dispatch = true;
    let mut emu = boot_with_config(&config);

    // Restore INQUIRY handler's 2 NOPed calls to their original JSR instructions:
    //   0x026042: JSR @0x01374A (response manager)
    //   0x02604A: JSR @0x014090 (data transfer)
    emu.restore_flash_patch(0x026042, 0x5E01374A);
    emu.restore_flash_patch(0x02604A, 0x5E014090);

    // Run INQUIRY via firmware dispatch with USB calls un-NOPed.
    // CDB is injected into EP1 OUT FIFO by scsi_command().
    let r = emu.scsi_command(&cdb_inquiry(36));

    // Handler completes GOOD. USB data transfer doesn't produce output yet
    // because 0x407DCA (transfer unit size) isn't set by the response manager's
    // incomplete USB handshake. The data send function at 0x01232E does
    // DIVXU.W R1,ER0 where R1=@0x407DCA; if R1=0, it returns without writing.
    //
    // Phase 7.0 Gate verified:
    // - DcInterrupt bit 12 (0x1000) = EP TX Ready check
    // - DcBufferLength (0x1C) must return non-zero
    // - Firmware uses PIO to EP Data Port, not ISP1581 DMA engine
    // - No RAM USB code (0x4010A0) involvement
    // - Register catalog: 0x18, 0x1C, 0x20, 0x28, 0x2C
    // - Data path requires 0x407DCA set by response manager handshake
    assert_eq!(r.sense_key, 0, "FW INQUIRY should complete GOOD");
}
