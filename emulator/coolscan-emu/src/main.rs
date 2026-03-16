/// Coolscan V Firmware Emulator — Main Entry Point
///
/// Loads the actual LS-50 firmware binary (512KB) and runs it on an
/// emulated H8/3003 CPU with virtual peripherals.

use std::path::PathBuf;

mod config;
mod orchestrator;

fn main() {
    env_logger::Builder::from_env(env_logger::Env::default().default_filter_or("info"))
        .format_timestamp_millis()
        .init();

    let config = config::Config::from_args();

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

    let mut emu = orchestrator::Emulator::new(&firmware, &config);

    log::info!("Reset vector: 0x{:06X}", emu.reset_vector());
    log::info!("Starting emulation...");

    emu.run(config.max_instructions);
}
