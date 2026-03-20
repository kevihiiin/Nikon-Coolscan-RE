//! Coolscan V Firmware Emulator — Main Entry Point
//!
//! Loads the actual LS-50 firmware binary (512KB) and runs it on an
//! emulated H8/3003 CPU with virtual peripherals.

fn main() {
    env_logger::Builder::from_env(env_logger::Env::default().default_filter_or("info"))
        .format_timestamp_millis()
        .init();

    let config = coolscan_emu::config::Config::from_args();

    log::info!("Coolscan V Emulator v{}", env!("CARGO_PKG_VERSION"));
    log::info!("Firmware: {}", config.firmware_path.display());
    log::info!("Adapter: {:?}", config.adapter);
    log::info!("Trace: {}", config.trace);

    let firmware = match std::fs::read(&config.firmware_path) {
        Ok(data) => {
            if data.len() != 512 * 1024 {
                log::error!("Firmware must be exactly 512KB, got {} bytes", data.len());
                std::process::exit(1);
            }
            data
        }
        Err(e) => {
            log::error!("Failed to read firmware: {}", e);
            std::process::exit(1);
        }
    };

    // Set up USB gadget bridge if requested
    #[cfg(target_os = "linux")]
    let mut _gadget = if config.gadget {
        log::info!("Setting up USB gadget bridge...");
        let mut g = bridge::gadget::GadgetBridge::new();
        match g.setup() {
            Ok(()) => {
                log::info!("USB gadget ready — connect a USB host to use real USB transport");
                Some(g)
            }
            Err(e) => {
                log::error!("USB gadget setup failed: {e}");
                log::error!("  Requires root + USB gadget kernel support (configfs + functionfs)");
                log::error!("  Falling back to TCP-only bridge");
                None
            }
        }
    } else {
        None
    };

    let mut emu = coolscan_emu::orchestrator::Emulator::new(&firmware, &config);

    log::info!("Reset vector: 0x{:06X}", emu.reset_vector());
    log::info!("Starting emulation...");

    emu.run(config.max_instructions);
}
