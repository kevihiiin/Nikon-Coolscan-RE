//! Motor position model for the LS-50 scanner.
//!
//! Two stepper motors: scan (carriage) and AF (autofocus).
//! Stepper phase cycle on Port A (0xFFFFA3): 01→02→04→08 = 1 step.
//! Direction control on Port 3 DDR (0xFFFF84) bit 0.
//!
//! The firmware drives motors via ITU2 interrupts (Vec 32) which write
//! stepper phases to Port A. We detect phase transitions and track position.

/// Forward stepper phase sequence (from flash 0x16E92).
const FORWARD_PHASES: [u8; 4] = [0x01, 0x02, 0x04, 0x08];
/// Reverse stepper phase sequence (from flash 0x4A8A8).
const REVERSE_PHASES: [u8; 4] = [0x08, 0x04, 0x02, 0x01];

/// State of a single stepper motor.
#[derive(Debug, Clone)]
pub struct MotorState {
    /// Current position in steps (signed for bidirectional movement).
    pub position: i32,
    /// Target position for current movement.
    pub target: i32,
    /// Whether motor is currently moving.
    pub running: bool,
    /// Last stepper phase written to Port A (0x01, 0x02, 0x04, or 0x08).
    pub last_phase: u8,
    /// Steps taken since last movement start.
    pub step_count: u32,
    /// Whether home sensor is triggered (position == 0).
    pub home_sensor: bool,
}

impl MotorState {
    pub fn new() -> Self {
        Self {
            position: 0,
            target: 0,
            running: false,
            last_phase: 0,
            step_count: 0,
            home_sensor: true, // Start at home
        }
    }
}

impl Default for MotorState {
    fn default() -> Self {
        Self::new()
    }
}

/// Motor subsystem containing both scan and AF motors.
pub struct MotorSubsystem {
    pub scan_motor: MotorState,
    pub af_motor: MotorState,
    /// Which motor is active (from motor_mode at 0x400774).
    /// 2,6 = scan motor, 3 = AF motor, 0 = idle.
    pub active_mode: u8,
    /// Instant mode: teleport motor to target immediately.
    pub instant_mode: bool,
    /// Accumulated steps since last encoder feedback (for batched updates).
    pub pending_steps: u32,
}

impl MotorSubsystem {
    pub fn new() -> Self {
        Self {
            scan_motor: MotorState::new(),
            af_motor: MotorState::new(),
            active_mode: 0,
            instant_mode: false,
            pending_steps: 0,
        }
    }

    /// Process a Port A write (stepper phase output).
    /// Returns the number of steps detected.
    pub fn port_a_write(&mut self, new_phase: u8, direction_bit: bool) -> u32 {
        // Only process valid stepper phases (low 4 bits, single bit set)
        let phase = new_phase & 0x0F;
        if phase != 0x01 && phase != 0x02 && phase != 0x04 && phase != 0x08 {
            return 0;
        }

        let motor = self.active_motor_mut();
        let old_phase = motor.last_phase;
        motor.last_phase = phase;

        // Detect phase transition (skip if same phase or first write)
        if old_phase == 0 || old_phase == phase {
            return 0;
        }

        // Detect if this is a valid step (adjacent phase in either direction)
        let is_forward_step = Self::is_next_phase(old_phase, phase, &FORWARD_PHASES);
        let is_reverse_step = Self::is_next_phase(old_phase, phase, &REVERSE_PHASES);

        if !is_forward_step && !is_reverse_step {
            return 0; // Not a valid single-step transition
        }

        // Direction: Port 3 DDR bit 0 controls direction.
        // forward = direction_bit=false, reverse = direction_bit=true
        let step_dir: i32 = if direction_bit { -1 } else { 1 };

        motor.position += step_dir;
        motor.step_count += 1;
        motor.running = true;
        motor.home_sensor = motor.position == 0;
        self.pending_steps += 1;

        1
    }

    /// Check if `new` is the next phase after `old` in the given sequence.
    fn is_next_phase(old: u8, new: u8, seq: &[u8; 4]) -> bool {
        for i in 0..4 {
            if seq[i] == old && seq[(i + 1) % 4] == new {
                return true;
            }
        }
        false
    }

    /// Get mutable reference to the currently active motor.
    fn active_motor_mut(&mut self) -> &mut MotorState {
        match self.active_mode {
            3 => &mut self.af_motor,
            _ => &mut self.scan_motor, // modes 2, 6, or default
        }
    }

    /// Get reference to the currently active motor.
    pub fn active_motor(&self) -> &MotorState {
        match self.active_mode {
            3 => &self.af_motor,
            _ => &self.scan_motor,
        }
    }

    /// Set motor mode from firmware RAM at 0x400774.
    pub fn set_mode(&mut self, mode: u8) {
        self.active_mode = mode;
        if mode != 0 {
            let motor = self.active_motor_mut();
            motor.running = true;
            motor.step_count = 0;
        }
    }

    /// Mark the active motor as stopped (reached target or explicitly stopped).
    pub fn stop(&mut self) {
        let motor = self.active_motor_mut();
        motor.running = false;
        self.active_mode = 0;
    }

    /// Set target position for the active motor.
    pub fn set_target(&mut self, target: i32) {
        let motor = self.active_motor_mut();
        motor.target = target;
    }

    /// Take pending steps count (resets to 0).
    pub fn take_pending_steps(&mut self) -> u32 {
        let steps = self.pending_steps;
        self.pending_steps = 0;
        steps
    }
}

impl Default for MotorSubsystem {
    fn default() -> Self {
        Self::new()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_forward_step_sequence() {
        let mut motor = MotorSubsystem::new();
        motor.set_mode(2); // Scan motor

        // Write forward phase sequence: 01 → 02 → 04 → 08
        assert_eq!(motor.port_a_write(0x01, false), 0); // First phase, no step
        assert_eq!(motor.port_a_write(0x02, false), 1); // Step!
        assert_eq!(motor.port_a_write(0x04, false), 1); // Step!
        assert_eq!(motor.port_a_write(0x08, false), 1); // Step!
        assert_eq!(motor.port_a_write(0x01, false), 1); // Wrap around, step!

        assert_eq!(motor.scan_motor.position, 4);
        assert_eq!(motor.scan_motor.step_count, 4);
    }

    #[test]
    fn test_reverse_step_sequence() {
        let mut motor = MotorSubsystem::new();
        motor.set_mode(2);

        // Write reverse phase sequence: 08 → 04 → 02 → 01
        assert_eq!(motor.port_a_write(0x08, true), 0); // First
        assert_eq!(motor.port_a_write(0x04, true), 1); // Step!
        assert_eq!(motor.port_a_write(0x02, true), 1);
        assert_eq!(motor.port_a_write(0x01, true), 1);

        assert_eq!(motor.scan_motor.position, -3);
    }

    #[test]
    fn test_home_sensor() {
        let mut motor = MotorSubsystem::new();
        motor.set_mode(2);
        motor.scan_motor.position = 2;
        motor.scan_motor.home_sensor = false;

        // Step backward to home
        motor.scan_motor.last_phase = 0x04;
        motor.port_a_write(0x02, true); // pos = 1
        assert!(!motor.scan_motor.home_sensor);
        motor.port_a_write(0x01, true); // pos = 0
        assert!(motor.scan_motor.home_sensor, "Home sensor should trigger at position 0");
    }

    #[test]
    fn test_af_motor_mode() {
        let mut motor = MotorSubsystem::new();
        motor.set_mode(3); // AF motor

        motor.port_a_write(0x01, false);
        motor.port_a_write(0x02, false);
        motor.port_a_write(0x04, false);

        assert_eq!(motor.af_motor.position, 2);
        assert_eq!(motor.scan_motor.position, 0, "Scan motor should be unchanged");
    }

    #[test]
    fn test_pending_steps() {
        let mut motor = MotorSubsystem::new();
        motor.set_mode(2);

        motor.port_a_write(0x01, false);
        motor.port_a_write(0x02, false);
        motor.port_a_write(0x04, false);

        assert_eq!(motor.take_pending_steps(), 2);
        assert_eq!(motor.take_pending_steps(), 0, "Pending should be cleared");
    }

    #[test]
    fn test_invalid_phase_ignored() {
        let mut motor = MotorSubsystem::new();
        motor.set_mode(2);

        motor.port_a_write(0x01, false);
        motor.port_a_write(0x03, false); // Invalid: two bits set
        motor.port_a_write(0x00, false); // Invalid: no bits

        assert_eq!(motor.scan_motor.position, 0, "Invalid phases should not move");
    }

    #[test]
    fn test_stop_motor() {
        let mut motor = MotorSubsystem::new();
        motor.set_mode(2);
        assert!(motor.scan_motor.running);

        motor.stop();
        assert!(!motor.scan_motor.running);
        assert_eq!(motor.active_mode, 0);
    }
}
