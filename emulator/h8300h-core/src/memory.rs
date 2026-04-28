//! Memory subsystem for the H8/3003.
//!
//! Address decode (from BSC configuration):
//!   0x000000-0x07FFFF  Flash ROM (512KB, read-only)
//!   0x200000-0x200FFF  Custom ASIC (16-bit, memory-mapped I/O)
//!   0x400000-0x41FFFF  External RAM (128KB)
//!   0x600000-0x6000FF  ISP1581 USB controller (16-bit)
//!   0x800000-0x837FFF  ASIC RAM (224KB)
//!   0xC00000-0xC0FFFF  Buffer RAM (64KB)
//!   0xFFFB80-0xFFFEFF  On-chip RAM (896 bytes, includes trampoline area)
//!   0xFFFF00-0xFFFFFF  On-chip I/O registers

/// Trait for memory-mapped I/O peripherals.
pub trait MmioDevice {
    fn read_byte(&mut self, addr: u32) -> u8;
    fn write_byte(&mut self, addr: u32, val: u8);

    fn read_word(&mut self, addr: u32) -> u16 {
        let hi = self.read_byte(addr) as u16;
        let lo = self.read_byte(addr + 1) as u16;
        (hi << 8) | lo
    }

    fn write_word(&mut self, addr: u32, val: u16) {
        self.write_byte(addr, (val >> 8) as u8);
        self.write_byte(addr + 1, val as u8);
    }

    /// Inject host data into the device (for USB EP1 OUT). Returns true if IRQ should fire.
    fn inject_host_data(&mut self, _data: &[u8]) -> bool { false }

    /// Drain device data for host (for USB EP2 IN). Returns bytes available.
    fn drain_device_data(&mut self, _max: usize) -> Vec<u8> { Vec::new() }

    /// Drain host-to-device data (from USB EP1 OUT). Used by SCSI data-out command handlers.
    fn drain_host_data(&mut self, _max: usize) -> Vec<u8> { Vec::new() }

    /// Set a CDB pattern that EP1 OUT reads cycle through when the FIFO
    /// underruns. Default no-op for devices that don't model EP1 OUT.
    /// See `Isp1581::set_ep1_pattern` for the protocol motivation.
    fn set_ep1_pattern(&mut self, _cdb: &[u8]) {}

    /// Check if device has pending interrupt.
    fn has_irq(&self) -> bool { false }

    /// Check if device has data ready for host.
    fn has_data_for_host(&self) -> bool { false }

    /// Push raw bytes into the device's host-bound FIFO (EP2 IN for USB).
    /// Unlike write_word, this adds bytes directly without protocol-level packing.
    fn push_to_host(&mut self, _data: &[u8]) {}

    /// Tick: called once per instruction cycle for time-dependent state transitions.
    fn tick(&mut self) {}
}

/// Memory region identifiers for address decode.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum MemoryRegion {
    Flash,
    Asic,
    Ram,
    Isp1581,
    AsicRam,
    BufferRam,
    OnChipRam,
    OnChipIo,
    Unmapped,
}

/// Decode a 24-bit address to a memory region.
pub fn decode_address(addr: u32) -> MemoryRegion {
    match addr {
        0x000000..=0x07FFFF => MemoryRegion::Flash,
        0x200000..=0x200FFF => MemoryRegion::Asic,
        0x400000..=0x41FFFF => MemoryRegion::Ram,
        0x600000..=0x6000FF => MemoryRegion::Isp1581,
        0x800000..=0x837FFF => MemoryRegion::AsicRam,
        0xC00000..=0xC0FFFF => MemoryRegion::BufferRam,
        0xFFFB80..=0xFFFEFF => MemoryRegion::OnChipRam,
        0xFFFF00..=0xFFFFFF => MemoryRegion::OnChipIo,
        _ => MemoryRegion::Unmapped,
    }
}

/// Main memory bus combining all regions.
pub struct MemoryBus {
    /// Flash ROM (512KB, read-only).
    flash: Vec<u8>,
    /// External RAM (128KB).
    ram: Vec<u8>,
    /// ASIC RAM (224KB).
    asic_ram: Vec<u8>,
    /// Buffer RAM (64KB).
    buffer_ram: Vec<u8>,
    /// On-chip RAM (896 bytes at 0xFFFB80-0xFFFEFF — includes trampoline area).
    onchip_ram: Vec<u8>,
    /// On-chip I/O registers (256 bytes at 0xFFFF00).
    pub onchip_io: [u8; 256],

    /// Callback for ASIC reads/writes (0x200000-0x200FFF).
    /// If None, writes are accepted and reads return stored value.
    asic_regs: [u8; 0x1000],

    /// Set when firmware writes to the ASIC region via the memory bus.
    /// Orchestrator's `sync_peripherals()` checks and clears this to forward
    /// level-triggered config registers (DAC mode, DMA addr/count) to the
    /// `Asic` model — avoiding a per-cycle scan of the register array.
    pub asic_dirty: bool,

    /// Edge-triggered CCD line capture write to 0x2001C1. Each firmware write
    /// must produce exactly one line of pixel data, regardless of byte value.
    /// A bare dirty flag + equality gate would drop repeat writes of the same
    /// byte (firmware typically writes 0x80 for every line) and stall scans
    /// after line 1. Consumed (cleared) by `sync_peripherals()`.
    pub ccd_trigger_write: Option<u8>,

    /// ISP1581 register backing (0x600000-0x6000FF).
    isp1581_regs: [u8; 256],

    /// ISP1581 device model for behavioral I/O.
    /// When set, ISP1581 word reads/writes dispatch through this for FIFO side effects.
    pub isp1581_device: Option<Box<dyn MmioDevice>>,

    /// ISP1581 IRQ pending flag — set by the device model, read by the orchestrator.
    /// This avoids needing shared ownership of the ISP1581 model.
    pub isp1581_irq_pending: bool,

    /// USB fast-path code watchpoint (detect writes to 0x4010A0-0x40124E).
    pub usb_code_watchpoint: bool,

    /// Port 7 override value (for adapter detection).
    /// Address 0xFFFF8E is shared between Port 7 GPIO and ITU4 TIER.
    /// This field provides the Port 7 read value without corrupting the timer register.
    pub port7_override: Option<u8>,

    /// Trace callback — if set, called on every memory access.
    pub trace_enabled: bool,

    /// Counters for diagnostics.
    pub unmapped_reads: u64,
    pub unmapped_writes: u64,
}

impl MemoryBus {
    pub fn new() -> Self {
        Self {
            flash: vec![0xFF; 512 * 1024],
            ram: vec![0x00; 128 * 1024],
            asic_ram: vec![0x00; 224 * 1024],
            buffer_ram: vec![0x00; 64 * 1024],
            onchip_ram: vec![0x00; 0xFEFF - 0xFB80 + 1], // 896 bytes
            onchip_io: [0x00; 256],
            asic_regs: [0x00; 0x1000],
            asic_dirty: false,
            ccd_trigger_write: None,
            isp1581_regs: [0x00; 256],
            isp1581_device: None,
            isp1581_irq_pending: false,
            usb_code_watchpoint: false,
            port7_override: None,
            trace_enabled: false,
            unmapped_reads: 0,
            unmapped_writes: 0,
        }
    }

    /// Load firmware binary into flash ROM at address 0x000000.
    pub fn load_firmware(&mut self, data: &[u8]) {
        let len = data.len().min(self.flash.len());
        self.flash[..len].copy_from_slice(&data[..len]);
    }

    /// Read the reset vector (address 0x000000, big-endian u32).
    pub fn read_reset_vector(&self) -> u32 {
        u32::from_be_bytes([
            self.flash[0],
            self.flash[1],
            self.flash[2],
            self.flash[3],
        ])
    }

    /// Read a byte from the memory bus.
    pub fn read_byte(&mut self, addr: u32) -> u8 {
        let addr = addr & 0x00FF_FFFF; // 24-bit address space
        match decode_address(addr) {
            MemoryRegion::Flash => self.flash[addr as usize],
            MemoryRegion::Ram => self.ram[(addr - 0x400000) as usize],
            MemoryRegion::AsicRam => self.asic_ram[(addr - 0x800000) as usize],
            MemoryRegion::BufferRam => self.buffer_ram[(addr - 0xC00000) as usize],
            MemoryRegion::OnChipRam => self.onchip_ram[(addr - 0xFFFB80) as usize],
            MemoryRegion::OnChipIo => self.read_onchip_io(addr),
            MemoryRegion::Asic => self.asic_regs[(addr - 0x200000) as usize],
            MemoryRegion::Isp1581 => {
                if let Some(ref mut dev) = self.isp1581_device {
                    dev.read_byte(addr - 0x600000)
                } else {
                    self.isp1581_regs[(addr - 0x600000) as usize]
                }
            }
            MemoryRegion::Unmapped => {
                self.unmapped_reads += 1;
                // Log first 16 unique unmapped reads unconditionally, then only when tracing
                if self.unmapped_reads <= 16 || self.trace_enabled {
                    log::warn!("Unmapped read: 0x{:06X} (#{}){}",
                        addr, self.unmapped_reads,
                        if self.unmapped_reads == 16 { " — suppressing further warnings" } else { "" });
                }
                // Return 0x00 for unmapped regions (not 0xFF).
                // The firmware's USB fast-path code polls bit 7 of an ISP1581
                // register via register indirect. If the address falls in an
                // unmapped region (e.g., 0x063621), returning 0x00 lets the
                // polling loop exit (bit 7 clear = "ready").
                0x00
            }
        }
    }

    /// Write a byte to the memory bus.
    pub fn write_byte(&mut self, addr: u32, val: u8) {
        let addr = addr & 0x00FF_FFFF;
        match decode_address(addr) {
            MemoryRegion::Flash => {
                // Allow writes to firmware log areas (0x60000-0x7FFFF).
                // The firmware writes operational logs here during normal use.
                if (0x60000..0x80000).contains(&addr) {
                    self.flash[addr as usize] = val;
                } else {
                    log::warn!("Write to read-only flash: 0x{:06X} = 0x{:02X}", addr, val);
                }
            }
            MemoryRegion::Ram => self.ram[(addr - 0x400000) as usize] = val,
            MemoryRegion::AsicRam => self.asic_ram[(addr - 0x800000) as usize] = val,
            MemoryRegion::BufferRam => self.buffer_ram[(addr - 0xC00000) as usize] = val,
            MemoryRegion::OnChipRam => self.onchip_ram[(addr - 0xFFFB80) as usize] = val,
            MemoryRegion::OnChipIo => self.write_onchip_io(addr, val),
            MemoryRegion::Asic => {
                let offset = (addr - 0x200000) as usize;
                self.asic_regs[offset] = val;
                self.asic_dirty = true;
                // 0x2001C1 is edge-triggered (every write fires a CCD line).
                // Tracked separately so repeat writes of the same byte aren't
                // coalesced by the level-triggered forwarding path.
                if offset == 0x01C1 {
                    self.ccd_trigger_write = Some(val);
                }
            }
            MemoryRegion::Isp1581 => {
                if let Some(ref mut dev) = self.isp1581_device {
                    dev.write_byte(addr - 0x600000, val);
                } else {
                    self.isp1581_regs[(addr - 0x600000) as usize] = val;
                }
            }
            MemoryRegion::Unmapped => {
                self.unmapped_writes += 1;
                if self.unmapped_writes <= 16 || self.trace_enabled {
                    log::warn!("Unmapped write: 0x{:06X} = 0x{:02X} (#{}){}",
                        addr, val, self.unmapped_writes,
                        if self.unmapped_writes == 16 { " — suppressing further warnings" } else { "" });
                }
            }
        }
    }

    /// Read a 16-bit word (big-endian) from the bus.
    pub fn read_word(&mut self, addr: u32) -> u16 {
        let addr = addr & 0x00FF_FFFF;
        // ISP1581 region: dispatch as word read (EP Data FIFO pops on word access)
        if let MemoryRegion::Isp1581 = decode_address(addr)
            && let Some(ref mut dev) = self.isp1581_device
        {
            return dev.read_word(addr - 0x600000);
        }
        let hi = self.read_byte(addr) as u16;
        let lo = self.read_byte(addr + 1) as u16;
        (hi << 8) | lo
    }

    /// Write a 16-bit word (big-endian) to the bus.
    pub fn write_word(&mut self, addr: u32, val: u16) {
        let addr_masked = addr & 0x00FF_FFFF;
        // ISP1581 region: dispatch as word write
        if let MemoryRegion::Isp1581 = decode_address(addr_masked)
            && let Some(ref mut dev) = self.isp1581_device
        {
            dev.write_word(addr_masked - 0x600000, val);
            return;
        }
        self.write_byte(addr, (val >> 8) as u8);
        self.write_byte(addr + 1, val as u8);
    }

    /// Read a 32-bit long (big-endian) from the bus.
    pub fn read_long(&mut self, addr: u32) -> u32 {
        let b0 = self.read_byte(addr) as u32;
        let b1 = self.read_byte(addr + 1) as u32;
        let b2 = self.read_byte(addr + 2) as u32;
        let b3 = self.read_byte(addr + 3) as u32;
        (b0 << 24) | (b1 << 16) | (b2 << 8) | b3
    }

    /// Write a 32-bit long (big-endian) to the bus.
    pub fn write_long(&mut self, addr: u32, val: u32) {
        self.write_byte(addr, (val >> 24) as u8);
        self.write_byte(addr + 1, (val >> 16) as u8);
        self.write_byte(addr + 2, (val >> 8) as u8);
        self.write_byte(addr + 3, val as u8);
    }

    /// Write directly to flash (for test setup only — bypasses read-only protection).
    pub fn flash_write_long(&mut self, addr: u32, val: u32) {
        let a = addr as usize;
        assert!(a + 3 < self.flash.len(), "flash_write_long: address 0x{:06X} out of range", addr);
        self.flash[a] = (val >> 24) as u8;
        self.flash[a + 1] = (val >> 16) as u8;
        self.flash[a + 2] = (val >> 8) as u8;
        self.flash[a + 3] = val as u8;
    }

    /// Direct access to RAM for testing/inspection.
    pub fn ram_slice(&self, offset: usize, len: usize) -> &[u8] {
        assert!(offset + len <= self.ram.len(),
            "ram_slice: offset 0x{:X} + len 0x{:X} exceeds RAM size 0x{:X}", offset, len, self.ram.len());
        &self.ram[offset..offset + len]
    }

    /// Direct access to ASIC registers for peripheral models.
    pub fn asic_reg(&self, offset: usize) -> u8 {
        self.asic_regs[offset]
    }

    pub fn set_asic_reg(&mut self, offset: usize, val: u8) {
        self.asic_regs[offset] = val;
    }

    /// Direct access to ISP1581 registers for the USB bridge.
    pub fn isp1581_reg(&self, offset: usize) -> u8 {
        self.isp1581_regs[offset]
    }

    pub fn set_isp1581_reg(&mut self, offset: usize, val: u8) {
        self.isp1581_regs[offset] = val;
    }

    /// Access ISP1581 device model mutably, returning default if not installed.
    fn with_isp1581_mut<F, R>(&mut self, default: R, f: F) -> R
    where F: FnOnce(&mut dyn MmioDevice) -> R {
        if let Some(ref mut dev) = self.isp1581_device {
            f(dev.as_mut())
        } else {
            default
        }
    }

    /// Inject host data into ISP1581 EP1 OUT FIFO. Returns true if IRQ should fire.
    pub fn isp1581_inject(&mut self, data: &[u8]) -> bool {
        let fire_irq = self.with_isp1581_mut(false, |dev| dev.inject_host_data(data));
        if fire_irq { self.isp1581_irq_pending = true; }
        fire_irq
    }

    /// Set the CDB pattern that the EP1 OUT read path falls back to when
    /// the FIFO is empty. See `Isp1581::set_ep1_pattern` for the rationale.
    pub fn isp1581_set_ep1_pattern(&mut self, cdb: &[u8]) {
        self.with_isp1581_mut((), |dev| dev.set_ep1_pattern(cdb));
    }

    /// Drain ISP1581 EP2 IN FIFO (host reads device responses).
    pub fn isp1581_drain(&mut self, max: usize) -> Vec<u8> {
        self.with_isp1581_mut(Vec::new(), |dev| dev.drain_device_data(max))
    }

    /// Drain ISP1581 EP1 OUT FIFO (device reads host data-out).
    pub fn isp1581_drain_host_data(&mut self, max: usize) -> Vec<u8> {
        self.with_isp1581_mut(Vec::new(), |dev| dev.drain_host_data(max))
    }

    /// Check if ISP1581 has data ready for host.
    pub fn isp1581_has_response(&self) -> bool {
        self.isp1581_device.as_ref().is_some_and(|dev| dev.has_data_for_host())
    }

    /// Push raw bytes to ISP1581 EP2 IN FIFO (intercepted data transfers).
    pub fn isp1581_push_to_host(&mut self, data: &[u8]) {
        self.with_isp1581_mut((), |dev| dev.push_to_host(data));
    }

    /// Check if ISP1581 has pending IRQ.
    pub fn isp1581_has_irq(&self) -> bool {
        self.isp1581_device.as_ref().map_or(self.isp1581_irq_pending, |dev| dev.has_irq())
    }

    /// Tick ISP1581 for time-dependent state transitions (bus reset, etc.).
    pub fn isp1581_tick(&mut self) {
        self.with_isp1581_mut((), |dev| dev.tick());
    }

    /// Read on-chip I/O register (0xFFFF00-0xFFFFFF).
    fn read_onchip_io(&self, addr: u32) -> u8 {
        let offset = (addr - 0xFFFF00) as usize;
        // Port 7 (0xFFFF8E) shares address with ITU4 TIER.
        // Port 7 value is stored in port7_override; return it for reads.
        if offset == 0x8E
            && let Some(val) = self.port7_override
        {
            return val;
        }
        self.onchip_io[offset]
    }

    /// Write on-chip I/O register.
    fn write_onchip_io(&mut self, addr: u32, val: u8) {
        let offset = (addr - 0xFFFF00) as usize;
        self.onchip_io[offset] = val;
    }

    /// Direct access to on-chip I/O for peripheral models.
    pub fn io_reg(&self, addr: u32) -> u8 {
        let offset = (addr - 0xFFFF00) as usize;
        self.onchip_io[offset]
    }

    pub fn set_io_reg(&mut self, addr: u32, val: u8) {
        let offset = (addr - 0xFFFF00) as usize;
        self.onchip_io[offset] = val;
    }
}

impl Default for MemoryBus {
    fn default() -> Self {
        Self::new()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_address_decode() {
        assert_eq!(decode_address(0x000000), MemoryRegion::Flash);
        assert_eq!(decode_address(0x07FFFF), MemoryRegion::Flash);
        assert_eq!(decode_address(0x200000), MemoryRegion::Asic);
        assert_eq!(decode_address(0x400000), MemoryRegion::Ram);
        assert_eq!(decode_address(0x600000), MemoryRegion::Isp1581);
        assert_eq!(decode_address(0x800000), MemoryRegion::AsicRam);
        assert_eq!(decode_address(0xC00000), MemoryRegion::BufferRam);
        assert_eq!(decode_address(0xFFFD00), MemoryRegion::OnChipRam);
        assert_eq!(decode_address(0xFFFF00), MemoryRegion::OnChipIo);
        assert_eq!(decode_address(0x100000), MemoryRegion::Unmapped);
    }

    #[test]
    fn test_flash_readonly() {
        let mut bus = MemoryBus::new();
        bus.flash[0] = 0x42;
        assert_eq!(bus.read_byte(0x000000), 0x42);
        bus.write_byte(0x000000, 0xFF); // Should be ignored
        assert_eq!(bus.read_byte(0x000000), 0x42);
    }

    #[test]
    fn test_ram_readwrite() {
        let mut bus = MemoryBus::new();
        bus.write_byte(0x400000, 0x42);
        assert_eq!(bus.read_byte(0x400000), 0x42);
        bus.write_word(0x400010, 0xABCD);
        assert_eq!(bus.read_word(0x400010), 0xABCD);
        bus.write_long(0x400020, 0x12345678);
        assert_eq!(bus.read_long(0x400020), 0x12345678);
    }

    #[test]
    fn test_onchip_ram() {
        let mut bus = MemoryBus::new();
        bus.write_byte(0xFFFD10, 0x5A);
        assert_eq!(bus.read_byte(0xFFFD10), 0x5A);
    }

    #[test]
    fn test_firmware_load() {
        let mut bus = MemoryBus::new();
        let firmware = vec![0x00, 0x00, 0x01, 0x00]; // Reset vector = 0x000100
        bus.load_firmware(&firmware);
        assert_eq!(bus.read_reset_vector(), 0x000100);
    }

    #[test]
    fn test_big_endian_word() {
        let mut bus = MemoryBus::new();
        bus.write_byte(0x400000, 0xAB);
        bus.write_byte(0x400001, 0xCD);
        assert_eq!(bus.read_word(0x400000), 0xABCD);
    }

    #[test]
    fn test_port7_override() {
        let mut bus = MemoryBus::new();
        bus.onchip_io[0x8E] = 0xFF; // ITU4 TIER value
        bus.port7_override = Some(0x04); // SA-21 mount adapter
        assert_eq!(bus.read_byte(0xFFFF8E), 0x04, "port7_override takes precedence");

        bus.port7_override = None;
        assert_eq!(bus.read_byte(0xFFFF8E), 0xFF, "falls back to onchip_io when no override");
    }

    #[test]
    fn test_24bit_address_mask() {
        let mut bus = MemoryBus::new();
        bus.write_byte(0x400000, 0x42);
        // Address 0x01400000 should mask to 0x400000 (24-bit)
        assert_eq!(bus.read_byte(0x01400000), 0x42);
    }

    #[test]
    fn test_unmapped_read_returns_zero() {
        let mut bus = MemoryBus::new();
        assert_eq!(bus.read_byte(0x100000), 0x00);
        assert_eq!(bus.unmapped_reads, 1);
    }

    #[test]
    fn test_asic_ram_rw() {
        let mut bus = MemoryBus::new();
        bus.write_byte(0x800000, 0xAA);
        bus.write_byte(0x837FFF, 0xBB);
        assert_eq!(bus.read_byte(0x800000), 0xAA);
        assert_eq!(bus.read_byte(0x837FFF), 0xBB);
    }

    #[test]
    fn test_buffer_ram_rw() {
        let mut bus = MemoryBus::new();
        bus.write_byte(0xC00000, 0x11);
        bus.write_byte(0xC0FFFF, 0x22);
        assert_eq!(bus.read_byte(0xC00000), 0x11);
        assert_eq!(bus.read_byte(0xC0FFFF), 0x22);
    }

    #[test]
    fn test_long_rw() {
        let mut bus = MemoryBus::new();
        bus.write_long(0x400000, 0xDEADBEEF);
        assert_eq!(bus.read_long(0x400000), 0xDEADBEEF);
        // Verify big-endian byte order
        assert_eq!(bus.read_byte(0x400000), 0xDE);
        assert_eq!(bus.read_byte(0x400001), 0xAD);
        assert_eq!(bus.read_byte(0x400002), 0xBE);
        assert_eq!(bus.read_byte(0x400003), 0xEF);
    }

    #[test]
    fn test_flash_log_area_writable() {
        let mut bus = MemoryBus::new();
        // Log area 1 (0x60000) should be writable
        bus.write_byte(0x60000, 0xAB);
        assert_eq!(bus.read_byte(0x60000), 0xAB);
        // Log area 2 (0x70000) should be writable
        bus.write_byte(0x70000, 0xCD);
        assert_eq!(bus.read_byte(0x70000), 0xCD);
        // Just below log area should be read-only
        bus.flash[0x5FFFF] = 0x42;
        bus.write_byte(0x5FFFF, 0xFF);
        assert_eq!(bus.read_byte(0x5FFFF), 0x42, "Below log area should be read-only");
    }

    #[test]
    fn test_isp1581_no_device_fallback() {
        let mut bus = MemoryBus::new();
        // Without device model installed, ISP1581 uses raw register backing
        assert!(bus.isp1581_device.is_none());
        bus.write_byte(0x600010, 0x42);
        assert_eq!(bus.read_byte(0x600010), 0x42);
        // Bridge methods should return defaults
        assert!(!bus.isp1581_has_irq());
        assert!(!bus.isp1581_has_response());
        assert!(bus.isp1581_drain(100).is_empty());
        assert!(bus.isp1581_drain_host_data(100).is_empty());
    }

    #[test]
    fn test_unmapped_write_counter() {
        let mut bus = MemoryBus::new();
        assert_eq!(bus.unmapped_writes, 0);
        bus.write_byte(0x100000, 0xFF);
        assert_eq!(bus.unmapped_writes, 1);
        bus.write_byte(0x100001, 0xFE);
        assert_eq!(bus.unmapped_writes, 2);
    }

    #[test]
    fn test_region_boundary_rw() {
        let mut bus = MemoryBus::new();
        // Last byte of RAM
        bus.write_byte(0x41FFFF, 0xAA);
        assert_eq!(bus.read_byte(0x41FFFF), 0xAA);
        // Last byte of ASIC RAM
        bus.write_byte(0x837FFF, 0xBB);
        assert_eq!(bus.read_byte(0x837FFF), 0xBB);
        // Last byte of on-chip RAM
        bus.write_byte(0xFFFEFF, 0xCC);
        assert_eq!(bus.read_byte(0xFFFEFF), 0xCC);
        // First byte of on-chip RAM
        bus.write_byte(0xFFFB80, 0xDD);
        assert_eq!(bus.read_byte(0xFFFB80), 0xDD);
    }

    #[test]
    fn test_onchip_io_rw() {
        let mut bus = MemoryBus::new();
        // Write/read at various I/O offsets
        bus.write_byte(0xFFFF00, 0x11);
        assert_eq!(bus.read_byte(0xFFFF00), 0x11);
        bus.write_byte(0xFFFFFF, 0x22);
        assert_eq!(bus.read_byte(0xFFFFFF), 0x22);
    }

    #[test]
    fn test_flash_write_long_bypass() {
        let mut bus = MemoryBus::new();
        bus.flash_write_long(0x000100, 0xDEADC0DE);
        assert_eq!(bus.read_long(0x000100), 0xDEADC0DE);
    }
}
