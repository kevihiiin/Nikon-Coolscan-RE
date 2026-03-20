//! GPIO port models.
//!
//! Active ports:
//!   Port A (0xFFFFA2/A3): Motor stepper phase output
//!   Port 3 (0xFFFF83/84): Motor direction
//!   Port 4 (0xFFFF85): Lamp control (bit 0: BCLR=ON, BSET=OFF)
//!   Port 7 (0xFFFF8E): Adapter detection input (configurable)
//!   Port 9 (0xFFFFC7/C8): Encoder + stepper

/// Adapter types for Port 7.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum AdapterType {
    None,       // 0x01
    SaMount,    // 0x04 (SA-21)
    SfStrip,    // 0x08 (SF-210)
    IaAps,      // 0x20 (IA-20)
    SaFeeder,   // 0x40 (SA-30)
    TestJig,    // Special
}

impl AdapterType {
    pub fn port7_value(&self) -> u8 {
        match self {
            AdapterType::None => 0x01,
            AdapterType::SaMount => 0x04,
            AdapterType::SfStrip => 0x08,
            AdapterType::IaAps => 0x20,
            AdapterType::SaFeeder => 0x40,
            AdapterType::TestJig => 0x00,
        }
    }
}

pub struct GpioPorts {
    /// Port A DDR/DR (motor stepper).
    pub port_a_ddr: u8,
    pub port_a_dr: u8,
    /// Port 3 DDR/DR (motor direction).
    pub port_3_ddr: u8,
    pub port_3_dr: u8,
    /// Port 4 DR (lamp).
    pub port_4_dr: u8,
    /// Port 7 input (adapter detection). Set by configuration.
    pub port_7_input: u8,
    /// Port 9 DDR/DR (encoder + stepper).
    pub port_9_ddr: u8,
    pub port_9_dr: u8,
    /// Lamp state.
    pub lamp_on: bool,
    /// Configured adapter type.
    adapter: AdapterType,
}

impl GpioPorts {
    pub fn new() -> Self {
        Self {
            port_a_ddr: 0,
            port_a_dr: 0,
            port_3_ddr: 0,
            port_3_dr: 0,
            port_4_dr: 0,
            port_7_input: AdapterType::SaMount.port7_value(),
            port_9_ddr: 0,
            port_9_dr: 0,
            lamp_on: false,
            adapter: AdapterType::SaMount,
        }
    }

    /// Set the simulated adapter type.
    pub fn set_adapter(&mut self, adapter: AdapterType) {
        self.adapter = adapter;
        self.port_7_input = adapter.port7_value();
    }

    /// Read an on-chip I/O register.
    pub fn read(&self, offset: u8) -> u8 {
        match offset {
            0x83 => self.port_3_ddr,
            0x84 => self.port_3_dr,
            0x85 => self.port_4_dr,
            0x8E => self.port_7_input, // Input port — returns configured value
            0xA2 => self.port_a_ddr,
            0xA3 => self.port_a_dr,
            0xC7 => self.port_9_ddr,
            0xC8 => self.port_9_dr,
            _ => 0,
        }
    }

    /// Write an on-chip I/O register.
    pub fn write(&mut self, offset: u8, val: u8) {
        match offset {
            0x83 => self.port_3_ddr = val,
            0x84 => self.port_3_dr = val,
            0x85 => {
                self.port_4_dr = val;
                self.lamp_on = val & 0x01 == 0; // BCLR = ON, BSET = OFF
            }
            0x8E => {} // Port 7 is input-only, writes ignored
            0xA2 => self.port_a_ddr = val,
            0xA3 => self.port_a_dr = val,
            0xC7 => self.port_9_ddr = val,
            0xC8 => self.port_9_dr = val,
            _ => {}
        }
    }
}

impl Default for GpioPorts {
    fn default() -> Self {
        Self::new()
    }
}
