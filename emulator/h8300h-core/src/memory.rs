/// Memory subsystem for the H8/3003.
///
/// Address decode (from BSC configuration):
///   0x000000-0x07FFFF  Flash ROM (512KB, read-only)
///   0x200000-0x200FFF  Custom ASIC (16-bit, memory-mapped I/O)
///   0x400000-0x41FFFF  External RAM (128KB)
///   0x600000-0x6000FF  ISP1581 USB controller (16-bit)
///   0x800000-0x837FFF  ASIC RAM (224KB)
///   0xC00000-0xC0FFFF  Buffer RAM (64KB)
///   0xFFFD00-0xFFFD3F  On-chip RAM (64 bytes, for trampolines)
///   0xFFFF00-0xFFFFFF  On-chip I/O registers

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

    /// ISP1581 register backing (0x600000-0x6000FF).
    isp1581_regs: [u8; 256],

    /// USB fast-path code watchpoint (detect writes to 0x4010A0-0x40124E).
    pub usb_code_watchpoint: bool,

    /// Port 7 override value (for adapter detection).
    /// Address 0xFFFF8E is shared between Port 7 GPIO and ITU4 TIER.
    /// This field provides the Port 7 read value without corrupting the timer register.
    pub port7_override: u8,

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
            isp1581_regs: [0x00; 256],
            usb_code_watchpoint: false,
            port7_override: 0,
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
            MemoryRegion::Isp1581 => self.isp1581_regs[(addr - 0x600000) as usize],
            MemoryRegion::Unmapped => {
                self.unmapped_reads += 1;
                if self.trace_enabled {
                    log::warn!("Unmapped read: 0x{:06X}", addr);
                }
                0xFF
            }
        }
    }

    /// Write a byte to the memory bus.
    pub fn write_byte(&mut self, addr: u32, val: u8) {
        let addr = addr & 0x00FF_FFFF;
        match decode_address(addr) {
            MemoryRegion::Flash => {
                if self.trace_enabled {
                    log::warn!("Write to read-only flash: 0x{:06X} = 0x{:02X}", addr, val);
                }
            }
            MemoryRegion::Ram => self.ram[(addr - 0x400000) as usize] = val,
            MemoryRegion::AsicRam => self.asic_ram[(addr - 0x800000) as usize] = val,
            MemoryRegion::BufferRam => self.buffer_ram[(addr - 0xC00000) as usize] = val,
            MemoryRegion::OnChipRam => self.onchip_ram[(addr - 0xFFFB80) as usize] = val,
            MemoryRegion::OnChipIo => self.write_onchip_io(addr, val),
            MemoryRegion::Asic => self.asic_regs[(addr - 0x200000) as usize] = val,
            MemoryRegion::Isp1581 => self.isp1581_regs[(addr - 0x600000) as usize] = val,
            MemoryRegion::Unmapped => {
                self.unmapped_writes += 1;
                if self.trace_enabled {
                    log::warn!("Unmapped write: 0x{:06X} = 0x{:02X}", addr, val);
                }
            }
        }
    }

    /// Read a 16-bit word (big-endian) from the bus.
    pub fn read_word(&mut self, addr: u32) -> u16 {
        let hi = self.read_byte(addr) as u16;
        let lo = self.read_byte(addr + 1) as u16;
        (hi << 8) | lo
    }

    /// Write a 16-bit word (big-endian) to the bus.
    pub fn write_word(&mut self, addr: u32, val: u16) {
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
        self.flash[a] = (val >> 24) as u8;
        self.flash[a + 1] = (val >> 16) as u8;
        self.flash[a + 2] = (val >> 8) as u8;
        self.flash[a + 3] = val as u8;
    }

    /// Direct access to RAM for testing/inspection.
    pub fn ram_slice(&self, offset: usize, len: usize) -> &[u8] {
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

    /// Read on-chip I/O register (0xFFFF00-0xFFFFFF).
    fn read_onchip_io(&self, addr: u32) -> u8 {
        let offset = (addr - 0xFFFF00) as usize;
        // Port 7 (0xFFFF8E) shares address with ITU4 TIER.
        // Port 7 value is stored in port7_override; return it for reads.
        if offset == 0x8E && self.port7_override != 0 {
            return self.port7_override;
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
}
