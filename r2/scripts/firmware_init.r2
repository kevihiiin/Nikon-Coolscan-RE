# firmware_init.r2 -- radare2 bootstrap script for Nikon LS-50 firmware
# Usage: r2 -i r2/scripts/firmware_init.r2 "binaries/firmware/Nikon LS-50 MBM29F400B TSOP48.bin"
#
# NOTE: r2 5.x h8300 support is limited to basic H8/300 (16-bit).
#       H8/300H extended instructions (32-bit ops) will show as invalid.
#       Use Ghidra with H8/300H SLEIGH module for full disassembly.
#       This script is for quick reference, string search, and hex analysis.

# Architecture setup
e asm.arch=h8300
e asm.bits=16
e cfg.bigendian=true
e anal.arch=h8300

# Memory map labels
# Flash (this file)
f seg.flash 0x80000 0x000000
f seg.vector_table 0x100 0x000000
f seg.startup 0x3f00 0x000100
f seg.bootloader_flags 0x2000 0x004000
f seg.settings 0x2000 0x006000
f seg.ext_settings 0x8000 0x008000
f seg.recovery_fw 0x10000 0x010000
f seg.main_fw 0x40000 0x020000
f seg.logging 0x20000 0x060000

# Vector table entries (active only)
f vec.reset 4 0x000
f vec.nmi 4 0x01C
f vec.trap0 4 0x020
f vec.irq1 4 0x034
f vec.irq3 4 0x03C
f vec.irq4 4 0x040
f vec.irq5 4 0x044
f vec.reserved19 4 0x04C
f vec.imia2 4 0x080
f vec.imia3 4 0x090
f vec.imia4 4 0x0A0
f vec.dend0b 4 0x0B4
f vec.dend1b 4 0x0BC
f vec.reserved49 4 0x0C4
f vec.adi 4 0x0F0

# Entry points (targets of active vectors)
f entry.reset 1 0x000100
f entry.nmi 1 0x000182
f entry.default_handler 1 0x000186

# Known string locations (from prior string analysis)
# SCSI INQUIRY response
f str.scsi_inquiry 28 0x020000
# Main firmware typically has strings in the 0x20000-0x5FFFF range

# Seek to reset vector entry point
s 0x100
