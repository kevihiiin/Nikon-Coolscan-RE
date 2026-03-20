//! Emulator configuration.

use std::path::PathBuf;
use peripherals::gpio::AdapterType;

pub struct Config {
    pub firmware_path: PathBuf,
    pub adapter: AdapterType,
    pub trace: bool,
    pub max_instructions: u64,
    pub tcp_port: u16,
    pub watchdog: bool,
    pub gadget: bool,
}

impl Config {
    pub fn from_args() -> Self {
        let args: Vec<String> = std::env::args().collect();

        let mut firmware_path: Option<PathBuf> = None;
        let mut adapter = AdapterType::SaMount;
        let mut trace = false;
        let mut max_instructions = 10_000_000;
        let mut tcp_port = 6581;
        let mut watchdog = false;
        let mut gadget = false;

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
                    max_instructions = match args[i + 1].parse() {
                        Ok(v) => v,
                        Err(_) => {
                            eprintln!("Warning: invalid --max value '{}', using 10000000", args[i + 1]);
                            10_000_000
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
                "--watchdog" => {
                    watchdog = true;
                    i += 1;
                }
                "--gadget" => {
                    gadget = true;
                    i += 1;
                }
                other => {
                    // Treat first positional argument as firmware path (backwards compat)
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
            firmware_path,
            adapter,
            trace,
            max_instructions,
            tcp_port,
            watchdog,
            gadget,
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
    eprintln!("  --max <N>            Max instructions to execute [default: 10000000]");
    eprintln!("  --trace              Enable instruction-level tracing");
    eprintln!("  --watchdog           Enable watchdog timer");
    eprintln!("  --gadget             Enable Linux USB gadget bridge (requires root)");
    eprintln!("  -h, --help           Show this help");
    eprintln!();
    eprintln!("TCP BRIDGE:");
    eprintln!("  The emulator listens on TCP port 6581 for SCSI command injection.");
    eprintln!("  Use emulator/scripts/tcp_test_client.py to interact:");
    eprintln!("    python3 scripts/tcp_test_client.py 6581 scan");
}
