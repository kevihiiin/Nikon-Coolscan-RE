//! SCI (Serial Communication Interface) stub.
//!
//! SCI0: 0xFFFFB0-B5, SCI1: 0xFFFFC8-CD (overlap with Port 9).
//! Firmware uses polled I/O for adapter communication.
//! Stub: return "no data available" (SSR flags clear).

pub struct Sci {
    pub smr: u8,
    pub brr: u8,
    pub scr: u8,
    pub tdr: u8,
    pub ssr: u8,
    pub rdr: u8,
}

impl Sci {
    pub fn new() -> Self {
        Self {
            smr: 0,
            brr: 0xFF,
            scr: 0,
            tdr: 0xFF,
            ssr: 0x84, // TDRE=1 (transmit ready), RDRF=0 (no data)
            rdr: 0,
        }
    }
}

impl Default for Sci {
    fn default() -> Self {
        Self::new()
    }
}
