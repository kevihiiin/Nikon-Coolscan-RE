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

        let firmware_path = if args.len() > 1 {
            PathBuf::from(&args[1])
        } else {
            // Default path relative to repo root
            PathBuf::from("../binaries/firmware/Nikon LS-50 MBM29F400B TSOP48.bin")
        };

        let mut adapter = AdapterType::SaMount;
        let mut trace = false;
        let mut max_instructions = 10_000_000;
        let mut tcp_port = 6581;
        let mut watchdog = false;
        let mut gadget = false;

        let mut i = 2;
        while i < args.len() {
            match args[i].as_str() {
                "--adapter" if i + 1 < args.len() => {
                    adapter = match args[i + 1].as_str() {
                        "none" => AdapterType::None,
                        "mount" | "sa21" => AdapterType::SaMount,
                        "strip" | "sf210" => AdapterType::SfStrip,
                        "aps" | "ia20" => AdapterType::IaAps,
                        "feeder" | "sa30" => AdapterType::SaFeeder,
                        "test" => AdapterType::TestJig,
                        _ => AdapterType::SaMount,
                    };
                    i += 2;
                }
                "--trace" => {
                    trace = true;
                    i += 1;
                }
                "--max" if i + 1 < args.len() => {
                    max_instructions = args[i + 1].parse().unwrap_or(10_000_000);
                    i += 2;
                }
                "--port" if i + 1 < args.len() => {
                    tcp_port = args[i + 1].parse().unwrap_or(6581);
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
                _ => i += 1,
            }
        }

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
