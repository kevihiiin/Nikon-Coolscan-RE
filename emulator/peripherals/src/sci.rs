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

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_default_ssr_flags() {
        let sci = Sci::new();
        // TDRE=1 (bit 7), RDRF=0 (bit 6) → 0x84
        assert_eq!(sci.ssr, 0x84);
        assert_eq!(sci.ssr & 0x80, 0x80, "TDRE should be set (transmit ready)");
        assert_eq!(sci.ssr & 0x40, 0x00, "RDRF should be clear (no data)");
    }

    #[test]
    fn test_default_register_values() {
        let sci = Sci::new();
        assert_eq!(sci.smr, 0);
        assert_eq!(sci.brr, 0xFF);
        assert_eq!(sci.scr, 0);
        assert_eq!(sci.tdr, 0xFF);
        assert_eq!(sci.rdr, 0);
    }
}
