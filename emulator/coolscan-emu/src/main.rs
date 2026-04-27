//! Coolscan V Firmware Emulator — Main Entry Point
//!
//! Loads the actual LS-50 firmware binary (512KB) and runs it on an
//! emulated H8/3003 CPU with virtual peripherals.

use std::sync::Arc;
use std::sync::atomic::{AtomicBool, Ordering};

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
    let usbip_requested = config.usbip_server;
    let tcp_requested = config.tcp_port > 0;
    let mut emu = coolscan_emu::orchestrator::Emulator::new(&firmware, &config);

    // If TCP was requested but bind failed (e.g., port already in use), fail
    // fast so the user notices. Without this, the error scrolls past in boot
    // logs and the emulator appears to start with a silently-dead bridge.
    // Other USB-side transports (gadget, usbip) make TCP a secondary fallback
    // — only enforce when TCP is the only requested transport.
    if tcp_requested && !emu.tcp_bridge_active && !gadget_requested && !usbip_requested {
        log::error!("TCP bridge failed to bind port {} — no transport available", config.tcp_port);
        log::error!("  Either free the port, pass --port <N> with a different port, or use --gadget / --usbip-server");
        std::process::exit(1);
    }

    // Set up USB gadget bridge if requested — wired into emulator's run loop
    let mut gadget_active = false;
    if gadget_requested {
        log::info!("Setting up USB gadget bridge...");
        match emu.setup_gadget() {
            Ok(()) => {
                log::info!("USB gadget ready — connect a USB host to use real USB transport");
                gadget_active = true;
            }
            Err(e) => {
                log::error!("USB gadget setup failed: {e}");
                log::error!("  Requires root + USB gadget kernel support (configfs + functionfs)");
                if emu.tcp_bridge_active {
                    log::warn!("  Continuing with TCP-only bridge on port {}", config.tcp_port);
                }
            }
        }
    }

    // Set up userspace USB/IP server if requested (M14.5).
    // Mutually exclusive with --gadget at the CLI layer; we just need to
    // honor the flag here.
    let mut usbip_active = false;
    if usbip_requested {
        log::info!("Setting up userspace USB/IP server on {}:{}...",
                   config.usbip_bind, config.usbip_port);
        match emu.setup_usbip_server(&config.usbip_bind, config.usbip_port) {
            Ok(()) => {
                log::info!("USB/IP server ready — connect a usbip-win2 client to attach the device");
                usbip_active = true;
            }
            Err(e) => {
                log::error!("USB/IP server setup failed: {e}");
                if emu.tcp_bridge_active {
                    log::warn!("  Continuing with TCP-only bridge on port {}", config.tcp_port);
                }
            }
        }
    }

    // Final transport check: if the user asked for any transport at all, make
    // sure at least one is actually working. Otherwise the emulator runs
    // firmware indefinitely while accepting no commands — exactly the silent
    // failure the M13 fail-fast was meant to prevent.
    if (gadget_requested || usbip_requested || tcp_requested)
        && !gadget_active && !usbip_active && !emu.tcp_bridge_active
    {
        log::error!("No transport available — every requested bridge failed to come up");
        log::error!("  Free port {} (TCP) or {} (USB/IP), or check kernel USB gadget support",
                    config.tcp_port, config.usbip_port);
        std::process::exit(1);
    }

    log::info!("Reset vector: 0x{:06X}", emu.reset_vector());
    log::info!("Model: {:?}, Pattern: {:?}", config.model, config.pattern);

    // Final transport summary, immediately before run starts. This is the
    // last log line a user sees before instruction-level chatter takes over,
    // so it must convey: which transports asked for, which actually came up,
    // and (loudly) which ones the user requested but didn't get.
    let want_tcp = tcp_requested;
    let have_tcp = emu.tcp_bridge_active;
    log::info!(
        "Transports: gadget={} usbip={} tcp={}",
        if gadget_active { "active" } else if gadget_requested { "REQUESTED-BUT-FAILED" } else { "off" },
        if usbip_active { format!("active ({}:{})", config.usbip_bind, config.usbip_port) }
            else if usbip_requested { "REQUESTED-BUT-FAILED".to_string() }
            else { "off".to_string() },
        if have_tcp { format!("active (port {})", config.tcp_port) }
            else if want_tcp { "REQUESTED-BUT-FAILED".to_string() }
            else { "off".to_string() },
    );
    if gadget_requested && !gadget_active {
        log::error!("--gadget was requested but did not come up; continuing without it. See earlier error.");
    }
    if usbip_requested && !usbip_active {
        log::error!("--usbip-server was requested but did not come up; continuing without it. See earlier error.");
    }

    log::info!("Starting emulation...");

    // Install SIGINT/SIGTERM handler so Ctrl+C exits the run loop cleanly.
    // Without this, GadgetBridge::Drop may not fire — leaving FunctionFS
    // mounted, the UDC bound, and configfs entries dangling.
    let shutdown = Arc::new(AtomicBool::new(false));
    {
        let s = shutdown.clone();
        if let Err(e) = ctrlc::set_handler(move || {
            // Multiple signals: log a hint that a second one will hard-kill.
            if s.swap(true, Ordering::Relaxed) {
                log::error!("Second shutdown signal — terminating immediately");
                std::process::exit(130);
            }
            log::warn!("Shutdown signal — finishing current instruction batch");
        }) {
            log::warn!("Could not install signal handler: {e} (Ctrl+C will hard-kill)");
        }
    }

    let start = std::time::Instant::now();
    emu.run_with_shutdown(config.max_instructions, Some(&shutdown));
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
