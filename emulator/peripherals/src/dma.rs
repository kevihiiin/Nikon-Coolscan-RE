//! On-chip DMA controller stub.
//!
//! DMAOR at 0xFFFF90, channel control registers at 0xFFFF20-0xFFFF3F.
//! Firmware uses DMA for ASIC↔RAM and RAM↔ISP1581 transfers.
//! For now: accept register writes, model as instant completion.

pub struct DmaController {
    pub dmaor: u8,
    pub channels: [DmaChannel; 2],
}

pub struct DmaChannel {
    pub dtcr: u8,
}

impl DmaController {
    pub fn new() -> Self {
        Self {
            dmaor: 0,
            channels: [DmaChannel { dtcr: 0 }, DmaChannel { dtcr: 0 }],
        }
    }
}

impl Default for DmaController {
    fn default() -> Self {
        Self::new()
    }
}
