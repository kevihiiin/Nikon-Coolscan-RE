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
    /// Home sensor state (bit 1 of Port 7, active when motor at position 0).
    pub home_sensor: bool,
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
            home_sensor: true, // Start at home
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
            0x8E => {
                // Port 7: adapter type + home sensor (bit 1)
                let mut val = self.port_7_input;
                if self.home_sensor {
                    val |= 0x02; // Bit 1 = home sensor active
                }
                val
            }
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

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_adapter_port7_values() {
        assert_eq!(AdapterType::None.port7_value(), 0x01);
        assert_eq!(AdapterType::SaMount.port7_value(), 0x04);
        assert_eq!(AdapterType::SfStrip.port7_value(), 0x08);
        assert_eq!(AdapterType::IaAps.port7_value(), 0x20);
        assert_eq!(AdapterType::SaFeeder.port7_value(), 0x40);
        assert_eq!(AdapterType::TestJig.port7_value(), 0x00);
    }

    #[test]
    fn test_set_adapter_updates_port7() {
        let mut gpio = GpioPorts::new();
        gpio.home_sensor = false; // Clear home sensor for clean adapter test
        gpio.set_adapter(AdapterType::SfStrip);
        assert_eq!(gpio.port_7_input, 0x08);
        assert_eq!(gpio.read(0x8E), 0x08);

        gpio.set_adapter(AdapterType::None);
        assert_eq!(gpio.port_7_input, 0x01);
    }

    #[test]
    fn test_port7_write_ignored() {
        let mut gpio = GpioPorts::new();
        gpio.set_adapter(AdapterType::SaMount);
        gpio.write(0x8E, 0xFF); // write to input port
        assert_eq!(gpio.port_7_input, 0x04, "Port 7 unchanged after write");
    }

    #[test]
    fn test_lamp_control() {
        let mut gpio = GpioPorts::new();
        // BCLR → bit 0 = 0 → lamp ON
        gpio.write(0x85, 0x00);
        assert!(gpio.lamp_on);
        // BSET → bit 0 = 1 → lamp OFF
        gpio.write(0x85, 0x01);
        assert!(!gpio.lamp_on);
    }

    #[test]
    fn test_port_a_motor_rw() {
        let mut gpio = GpioPorts::new();
        gpio.write(0xA2, 0xFF); // DDR
        gpio.write(0xA3, 0x42); // DR
        assert_eq!(gpio.read(0xA2), 0xFF);
        assert_eq!(gpio.read(0xA3), 0x42);
    }

    #[test]
    fn test_unknown_offset_returns_zero() {
        let gpio = GpioPorts::new();
        assert_eq!(gpio.read(0x00), 0);
    }
}
