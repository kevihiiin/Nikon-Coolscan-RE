/// Emulator configuration.

use std::path::PathBuf;
use peripherals::gpio::AdapterType;

pub struct Config {
    pub firmware_path: PathBuf,
    pub adapter: AdapterType,
    pub trace: bool,
    pub max_instructions: u64,
    pub _tcp_port: u16,
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
            _tcp_port: tcp_port,
            watchdog,
            gadget,
        }
    }
}
