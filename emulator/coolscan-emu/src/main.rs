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

    let gadget_requested = config.gadget;
    let mut emu = coolscan_emu::orchestrator::Emulator::new(&firmware, &config);

    // Set up USB gadget bridge if requested — wired into emulator's run loop
    if gadget_requested {
        log::info!("Setting up USB gadget bridge...");
        match emu.setup_gadget() {
            Ok(()) => {
                log::info!("USB gadget ready — connect a USB host to use real USB transport");
            }
            Err(e) => {
                log::error!("USB gadget setup failed: {e}");
                log::error!("  Requires root + USB gadget kernel support (configfs + functionfs)");
                log::error!("  Falling back to TCP-only bridge");
            }
        }
    }

    log::info!("Reset vector: 0x{:06X}", emu.reset_vector());
    log::info!("Model: {:?}, Pattern: {:?}", config.model, config.pattern);
    log::info!("Starting emulation...");

    let start = std::time::Instant::now();
    emu.run(config.max_instructions);
    let elapsed = start.elapsed();

    if config.benchmark {
        let insns = emu.cpu.cycle_count;
        let secs = elapsed.as_secs_f64();
        let mips = insns as f64 / secs / 1_000_000.0;
        eprintln!();
        eprintln!("=== Benchmark Results ===");
        eprintln!("  Instructions: {}", insns);
        eprintln!("  Wall time:    {:.3}s", secs);
        eprintln!("  Throughput:   {:.2} MIPS", mips);
        eprintln!("  Final PC:     0x{:06X}", emu.cpu.pc);
        eprintln!("  Unmapped R/W: {}/{}", emu.bus.unmapped_reads, emu.bus.unmapped_writes);
    }
}
