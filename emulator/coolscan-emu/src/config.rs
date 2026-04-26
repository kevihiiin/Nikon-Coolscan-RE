//! Emulator configuration.

use std::path::PathBuf;
use peripherals::gpio::AdapterType;

/// Scan test pattern type for synthesized image data.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum ScanPattern {
    /// RGB gradient: R=left-right, G=top-bottom, B=diagonal (default)
    Gradient,
    /// Uniform mid-gray (128) — for calibration testing
    Flat,
    /// 8x8 pixel checkerboard — for resolution/alignment testing
    Checkerboard,
    /// SMPTE-style color bars (8 vertical bars)
    ColorBars,
}

/// Scanner model identity (affects INQUIRY strings).
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum ScannerModel {
    Ls50,
    Ls5000,
}

pub struct Config {
    pub firmware_path: PathBuf,
    pub adapter: AdapterType,
    pub trace: bool,
    pub max_instructions: u64,
    pub tcp_port: u16,
    pub watchdog: bool,
    pub gadget: bool,
    pub pattern: ScanPattern,
    pub model: ScannerModel,
    pub benchmark: bool,
    pub scan_data_path: Option<PathBuf>,
    pub cold_boot: bool,
    pub full_usb_init: bool,
    pub firmware_dispatch: bool,
    /// Force old Rust SCSI emulation path (regression safety net).
    pub emulated_scsi: bool,
}

impl Config {
    /// Default config for tests — no TCP, no gadget, no trace.
    pub fn test_default() -> Self {
        Self {
            firmware_path: PathBuf::from("../../binaries/firmware/Nikon LS-50 MBM29F400B TSOP48.bin"),
            adapter: AdapterType::SaMount,
            trace: false,
            max_instructions: 10_000_000,
            tcp_port: 0,
            watchdog: false,
            gadget: false,
            pattern: ScanPattern::Gradient,
            model: ScannerModel::Ls50,
            benchmark: false,
            scan_data_path: None,
            cold_boot: false,
            full_usb_init: false,
            firmware_dispatch: false,
            emulated_scsi: false,
        }
    }

    pub fn from_args() -> Self {
        let args: Vec<String> = std::env::args().collect();

        let mut firmware_path: Option<PathBuf> = None;
        let mut adapter = AdapterType::SaMount;
        let mut trace = false;
        // Default to unlimited. Real NikonScan sessions run tens of millions
        // of instructions — the old 10M cap silently cut them short. Pass
        // `--max N` to bound a run (e.g., benchmarks, CI); `--max 0` is
        // explicit for "run forever".
        let mut max_instructions: u64 = u64::MAX;
        let mut tcp_port = 6581;
        let mut watchdog = false;
        let mut gadget = false;
        let mut pattern = ScanPattern::Gradient;
        let mut model = ScannerModel::Ls50;
        let mut benchmark = false;
        let mut scan_data_path: Option<PathBuf> = None;
        let mut cold_boot = false;
        let mut full_usb_init = false;
        let mut firmware_dispatch = false;
        let mut emulated_scsi = false;

        let mut i = 1;
        while i < args.len() {
            match args[i].as_str() {
                "--help" | "-h" => {
                    print_usage();
                    std::process::exit(0);
                }
                "--firmware" if i + 1 < args.len() => {
                    firmware_path = Some(PathBuf::from(&args[i + 1]));
                    i += 2;
                }
                "--adapter" if i + 1 < args.len() => {
                    adapter = match args[i + 1].as_str() {
                        "none" => AdapterType::None,
                        "mount" | "sa21" => AdapterType::SaMount,
                        "strip" | "sf210" => AdapterType::SfStrip,
                        "aps" | "ia20" => AdapterType::IaAps,
                        "feeder" | "sa30" => AdapterType::SaFeeder,
                        "test" => AdapterType::TestJig,
                        other => {
                            eprintln!("Warning: unknown adapter '{}', using 'mount'. Valid: none, mount, strip, aps, feeder, test", other);
                            AdapterType::SaMount
                        }
                    };
                    i += 2;
                }
                "--trace" => {
                    trace = true;
                    i += 1;
                }
                "--max" if i + 1 < args.len() => {
                    max_instructions = match args[i + 1].parse::<u64>() {
                        Ok(0) => u64::MAX, // explicit "unlimited"
                        Ok(v) => v,
                        Err(_) => {
                            eprintln!("Warning: invalid --max value '{}', using unlimited", args[i + 1]);
                            u64::MAX
                        }
                    };
                    i += 2;
                }
                "--port" if i + 1 < args.len() => {
                    tcp_port = match args[i + 1].parse() {
                        Ok(v) => v,
                        Err(_) => {
                            eprintln!("Warning: invalid --port value '{}', using 6581", args[i + 1]);
                            6581
                        }
                    };
                    i += 2;
                }
                "--watchdog" => { watchdog = true; i += 1; }
                "--gadget" => { gadget = true; i += 1; }
                "--benchmark" => { benchmark = true; i += 1; }
                "--cold-boot" => { cold_boot = true; i += 1; }
                "--full-usb-init" => { full_usb_init = true; i += 1; }
                "--firmware-dispatch" => { firmware_dispatch = true; i += 1; }
                "--emulated-scsi" => { emulated_scsi = true; i += 1; }
                "--pattern" if i + 1 < args.len() => {
                    pattern = match args[i + 1].as_str() {
                        "gradient" => ScanPattern::Gradient,
                        "flat" => ScanPattern::Flat,
                        "checkerboard" | "checker" => ScanPattern::Checkerboard,
                        "bars" | "colorbars" => ScanPattern::ColorBars,
                        other => {
                            eprintln!("Warning: unknown pattern '{}', using 'gradient'. Valid: gradient, flat, checkerboard, bars", other);
                            ScanPattern::Gradient
                        }
                    };
                    i += 2;
                }
                "--model" if i + 1 < args.len() => {
                    model = match args[i + 1].as_str() {
                        "ls50" | "ls-50" => ScannerModel::Ls50,
                        "ls5000" | "ls-5000" => ScannerModel::Ls5000,
                        other => {
                            eprintln!("Warning: unknown model '{}', using 'ls50'. Valid: ls50, ls5000", other);
                            ScannerModel::Ls50
                        }
                    };
                    i += 2;
                }
                "--scan-data" if i + 1 < args.len() => {
                    scan_data_path = Some(PathBuf::from(&args[i + 1]));
                    i += 2;
                }
                other => {
                    if firmware_path.is_none() && !other.starts_with("--") {
                        firmware_path = Some(PathBuf::from(other));
                    } else {
                        eprintln!("Warning: unknown argument '{}'", other);
                    }
                    i += 1;
                }
            }
        }

        let firmware_path = firmware_path.unwrap_or_else(|| {
            PathBuf::from("../binaries/firmware/Nikon LS-50 MBM29F400B TSOP48.bin")
        });

        Self {
            firmware_path, adapter, trace, max_instructions, tcp_port,
            watchdog, gadget, pattern, model, benchmark,
            scan_data_path, cold_boot, full_usb_init, firmware_dispatch,
            emulated_scsi,
        }
    }
}

fn print_usage() {
    eprintln!("coolscan-emu — Nikon Coolscan V firmware emulator");
    eprintln!();
    eprintln!("USAGE:");
    eprintln!("  coolscan-emu [OPTIONS] [FIRMWARE_PATH]");
    eprintln!();
    eprintln!("ARGS:");
    eprintln!("  FIRMWARE_PATH  Path to 512KB firmware binary");
    eprintln!("                 [default: ../binaries/firmware/Nikon LS-50 MBM29F400B TSOP48.bin]");
    eprintln!();
    eprintln!("OPTIONS:");
    eprintln!("  --firmware <PATH>    Firmware binary path (alternative to positional arg)");
    eprintln!("  --adapter <TYPE>     Simulated film adapter [default: mount]");
    eprintln!("                       Values: none, mount/sa21, strip/sf210, aps/ia20, feeder/sa30, test");
    eprintln!("  --port <PORT>        TCP bridge port [default: 6581]");
    eprintln!("  --max <N>            Max instructions to execute [default: unlimited]");
    eprintln!("                       Pass 0 for explicit unlimited; positive N caps the run.");
    eprintln!("  --trace              Enable instruction-level tracing");
    eprintln!("  --watchdog           Enable watchdog timer");
    eprintln!("  --gadget             Enable Linux USB gadget bridge (requires root)");
    eprintln!("  --pattern <TYPE>     Scan test pattern [default: gradient]");
    eprintln!("                       Values: gradient, flat, checkerboard, bars");
    eprintln!("  --model <MODEL>      Scanner model identity [default: ls50]");
    eprintln!("                       Values: ls50, ls5000");
    eprintln!("  --scan-data <FILE>   Load raw scan data from file instead of generating pattern");
    eprintln!("  --benchmark          Print performance stats after execution");
    eprintln!("  --cold-boot          Use cold-boot path (skip warm-boot shortcuts)");
    eprintln!("  --full-usb-init      Let firmware run USB initialization (un-NOP USB init patches)");
    eprintln!("  --firmware-dispatch  Route SCSI commands through firmware handlers");
    eprintln!("  --emulated-scsi      Force Rust SCSI emulation (regression safety net)");
    eprintln!("  -h, --help           Show this help");
    eprintln!();
    eprintln!("TCP BRIDGE:");
    eprintln!("  The emulator listens on TCP port 6581 for SCSI command injection.");
    eprintln!("  Use emulator/scripts/tcp_test_client.py to interact:");
    eprintln!("    python3 scripts/tcp_test_client.py 6581 scan");
}
