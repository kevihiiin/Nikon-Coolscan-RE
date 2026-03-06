#!/usr/bin/env python3
"""
Deep analysis of DMA handlers, scan pipeline, calibration, and lamp control.
"""

import struct
from collections import defaultdict

FW_PATH = "/home/ky/projects/Nikon-Coolscan-RE/binaries/firmware/Nikon LS-50 MBM29F400B TSOP48.bin"
with open(FW_PATH, 'rb') as f:
    fw = f.read()

def decode_h8_region(start, end, label=""):
    """Attempt basic H8/300H instruction decode for a region."""
    print(f"\n--- {label} (0x{start:05X} - 0x{end:05X}) ---")
    i = start
    while i < end and i < len(fw) - 1:
        # Try to decode common H8/300H instructions
        b0 = fw[i]
        b1 = fw[i+1] if i+1 < len(fw) else 0
        
        decoded = None
        size = 2  # default instruction size
        
        # NOP
        if b0 == 0x00 and b1 == 0x00:
            decoded = "nop"
        # RTE
        elif b0 == 0x56 and b1 == 0x70:
            decoded = "rte"
        # RTS
        elif b0 == 0x54 and b1 == 0x70:
            decoded = "rts"
        # mov.l ERs, @-SP (push) -> 01 00 6D Fs
        elif b0 == 0x01 and b1 == 0x00 and i+3 < len(fw):
            b2, b3 = fw[i+2], fw[i+3]
            if b2 == 0x6D and (b3 & 0xF0) == 0xF0:
                decoded = f"push.l er{b3 & 0x07}"
                size = 4
            elif b2 == 0x6D and (b3 & 0xF0) == 0x70:
                decoded = f"pop.l er{b3 & 0x07}"
                size = 4
            elif b2 == 0x6B and i+7 < len(fw):
                b4, b5, b6, b7 = fw[i+4], fw[i+5], fw[i+6], fw[i+7]
                if (b3 & 0xF0) == 0x20:
                    addr = (b4 << 24) | (b5 << 16) | (b6 << 8) | b7
                    decoded = f"mov.l @0x{addr:06X}, er{b3 & 0x07}"
                    size = 8
                elif (b3 & 0xF0) == 0xA0:
                    addr = (b4 << 24) | (b5 << 16) | (b6 << 8) | b7
                    decoded = f"mov.l er{b3 & 0x07}, @0x{addr:06X}"
                    size = 8
            elif b2 == 0x69:
                if (b3 & 0xF0) < 0x80:
                    decoded = f"mov.l @er{(b3>>4)&7}, er{b3&7}"
                    size = 4
                else:
                    decoded = f"mov.l er{b3&7}, @er{(b3>>4)&7 - 8}"
                    size = 4
        # mov.l #imm32, ERd -> 7A 0d xx xx xx xx
        elif b0 == 0x7A and (b1 & 0xF0) == 0x00 and i+5 < len(fw):
            imm = struct.unpack('>I', fw[i+2:i+6])[0]
            decoded = f"mov.l #0x{imm:08X}, er{b1 & 0x07}"
            size = 6
        # mov.b @aa:24, Rd -> 6A 2d aa aa aa
        elif b0 == 0x6A and (b1 & 0xF0) == 0x20 and i+4 < len(fw):
            addr = (fw[i+2] << 16) | (fw[i+3] << 8) | fw[i+4]
            decoded = f"mov.b @0x{addr:06X}, r{b1 & 0x0F}{'l' if (b1&0xF)<8 else 'h'}"
            size = 5
        # mov.b Rs, @aa:24 -> 6A Ad aa aa aa
        elif b0 == 0x6A and (b1 & 0xF0) == 0xA0 and i+4 < len(fw):
            addr = (fw[i+2] << 16) | (fw[i+3] << 8) | fw[i+4]
            decoded = f"mov.b r{b1 & 0x0F}{'l' if (b1&0xF)<8 else 'h'}, @0x{addr:06X}"
            size = 5
        # mov.w @aa:24, Rd -> 6B 2d aa aa aa
        elif b0 == 0x6B and (b1 & 0xF0) == 0x20 and i+4 < len(fw):
            addr = (fw[i+2] << 16) | (fw[i+3] << 8) | fw[i+4]
            decoded = f"mov.w @0x{addr:06X}, r{b1 & 0x0F}"
            size = 5
        # mov.w Rs, @aa:24 -> 6B Ad aa aa aa
        elif b0 == 0x6B and (b1 & 0xF0) == 0xA0 and i+4 < len(fw):
            addr = (fw[i+2] << 16) | (fw[i+3] << 8) | fw[i+4]
            decoded = f"mov.w r{b1 & 0x0F}, @0x{addr:06X}"
            size = 5
        # mov.b @ERs, Rd -> 68 xy
        elif b0 == 0x68:
            x = (b1 >> 4) & 0x0F
            y = b1 & 0x0F
            if x < 8:
                decoded = f"mov.b @er{x}, r{y}l"
            else:
                decoded = f"mov.b r{y}l, @er{x-8}"
        # mov.w @ERs, Rd -> 69 xy
        elif b0 == 0x69:
            x = (b1 >> 4) & 0x0F
            y = b1 & 0x0F
            if x < 8:
                decoded = f"mov.w @er{x}, r{y}"
            else:
                decoded = f"mov.w r{y}, @er{x-8}"
        # jsr @aa:24 -> 5E aa aa aa
        elif b0 == 0x5E and i+3 < len(fw):
            addr = (b1 << 16) | (fw[i+2] << 8) | fw[i+3]
            decoded = f"jsr @0x{addr:06X}"
            size = 4
        # jmp @aa:24 -> 5A aa aa aa
        elif b0 == 0x5A and i+3 < len(fw):
            addr = (b1 << 16) | (fw[i+2] << 8) | fw[i+3]
            decoded = f"jmp @0x{addr:06X}"
            size = 4
        # bra d:8 -> 40 dd
        elif b0 == 0x40:
            disp = b1 if b1 < 0x80 else b1 - 256
            decoded = f"bra 0x{i+2+disp:05X}"
        # beq d:8 -> 47 dd
        elif b0 == 0x47:
            disp = b1 if b1 < 0x80 else b1 - 256
            decoded = f"beq 0x{i+2+disp:05X}"
        # bne d:8 -> 46 dd
        elif b0 == 0x46:
            disp = b1 if b1 < 0x80 else b1 - 256
            decoded = f"bne 0x{i+2+disp:05X}"
        # bcc/bcs etc
        elif 0x40 <= b0 <= 0x4F:
            cond = {0x40:'bra',0x41:'brn',0x42:'bhi',0x43:'bls',0x44:'bcc',0x45:'bcs',
                    0x46:'bne',0x47:'beq',0x48:'bvc',0x49:'bvs',0x4A:'bpl',0x4B:'bmi',
                    0x4C:'bge',0x4D:'blt',0x4E:'bgt',0x4F:'ble'}.get(b0, f'b{b0:02X}')
            disp = b1 if b1 < 0x80 else b1 - 256
            decoded = f"{cond} 0x{i+2+disp:05X}"
        # BSET/BCLR via 7F
        elif b0 == 0x7F and i+3 < len(fw):
            ioaddr = 0xFFFF00 + b1
            b2, b3 = fw[i+2], fw[i+3]
            bit = (b3 >> 4) & 0x07
            if b2 == 0x70:
                decoded = f"bset #{bit}, @0x{ioaddr:06X}"
                size = 4
            elif b2 == 0x72:
                decoded = f"bclr #{bit}, @0x{ioaddr:06X}"
                size = 4
        # BSET/BCLR via 7E (BTST)
        elif b0 == 0x7E and i+3 < len(fw):
            ioaddr = 0xFFFF00 + b1
            b2, b3 = fw[i+2], fw[i+3]
            bit = (b3 >> 4) & 0x07
            if b2 == 0x73:
                decoded = f"btst #{bit}, @0x{ioaddr:06X}"
                size = 4
            elif b2 == 0x77:
                decoded = f"bld #{bit}, @0x{ioaddr:06X}"
                size = 4
        # cmp.b #imm, Rd -> A{d} imm
        elif 0xA0 <= b0 <= 0xAF:
            decoded = f"cmp.b #0x{b1:02X}, r{b0 & 0x0F}l"
        # mov.b #imm, Rd -> F{d} imm
        elif 0xF0 <= b0 <= 0xFF:
            decoded = f"mov.b #0x{b1:02X}, r{b0 & 0x0F}l"
        # cmp.w #imm16, Rd -> 79 2d ii ii
        elif b0 == 0x79 and (b1 & 0xF0) == 0x20 and i+3 < len(fw):
            imm = (fw[i+2] << 8) | fw[i+3]
            decoded = f"cmp.w #0x{imm:04X}, r{b1 & 0x0F}"
            size = 4
        # mov.w #imm16, Rd -> 79 0d ii ii
        elif b0 == 0x79 and (b1 & 0xF0) == 0x00 and i+3 < len(fw):
            imm = (fw[i+2] << 8) | fw[i+3]
            decoded = f"mov.w #0x{imm:04X}, r{b1 & 0x0F}"
            size = 4
        # and.b #imm, Rd -> E{d} imm
        elif 0xE0 <= b0 <= 0xEF:
            decoded = f"and.b #0x{b1:02X}, r{b0 & 0x0F}l"
        # or.b #imm, Rd -> C{d} imm
        elif 0xC0 <= b0 <= 0xCF:
            decoded = f"or.b #0x{b1:02X}, r{b0 & 0x0F}l"
        # xor.b #imm, Rd -> D{d} imm
        elif 0xD0 <= b0 <= 0xDF:
            decoded = f"xor.b #0x{b1:02X}, r{b0 & 0x0F}l"
        # sub.w Rd, Rs -> 19 sd
        elif b0 == 0x19:
            decoded = f"sub.w r{(b1>>4)&0xF}, r{b1&0xF}"
        # add.w Rd, Rs -> 09 sd
        elif b0 == 0x09:
            decoded = f"add.w r{(b1>>4)&0xF}, r{b1&0xF}"
        # 78 s0 6A/6B ... displacement access
        elif b0 == 0x78 and (b1 & 0x0F) == 0x00 and i+5 < len(fw):
            src_reg = (b1 >> 4) & 0x07
            b2, b3 = fw[i+2], fw[i+3]
            if b2 == 0x6A:
                disp = struct.unpack('>H', fw[i+4:i+6])[0]
                if disp >= 0x8000: disp -= 0x10000
                if (b3 & 0xF0) < 0x30:
                    decoded = f"mov.b @(0x{disp:04X},er{src_reg}), r{b3&0xF}l"
                else:
                    decoded = f"mov.b r{b3&0xF}l, @(0x{disp:04X},er{src_reg})"
                size = 6
            elif b2 == 0x6B:
                disp = struct.unpack('>H', fw[i+4:i+6])[0]
                if disp >= 0x8000: disp -= 0x10000
                if (b3 & 0xF0) < 0x30:
                    decoded = f"mov.w @(0x{disp:04X},er{src_reg}), r{b3&0xF}"
                else:
                    decoded = f"mov.w r{b3&0xF}, @(0x{disp:04X},er{src_reg})"
                size = 6
        # inc / dec
        elif b0 == 0x0A and (b1 & 0xF0) in [0x00, 0x80]:
            decoded = f"inc.b r{b1 & 0x0F}l"
        elif b0 == 0x1A and (b1 & 0xF0) in [0x00, 0x80]:
            decoded = f"dec.b r{b1 & 0x0F}l"
        elif b0 == 0x0B and (b1 & 0xF0) == 0x50:
            decoded = f"inc.w #1, r{b1 & 0x0F}"
        elif b0 == 0x0B and (b1 & 0xF0) == 0x70:
            decoded = f"inc.l #1, er{b1 & 0x07}"
        
        if decoded:
            hexbytes = ' '.join(f'{fw[i+j]:02X}' for j in range(size))
            print(f"  0x{i:05X}: {hexbytes:<20s}  {decoded}")
        else:
            hexbytes = f'{fw[i]:02X} {fw[i+1]:02X}'
            print(f"  0x{i:05X}: {hexbytes:<20s}  db 0x{fw[i]:02X}, 0x{fw[i+1]:02X}")
        
        i += size
        if decoded and ('rte' in decoded or 'rts' in decoded):
            break  # Stop at return

# ===================================================================
# DMA Handler Analysis
# ===================================================================
print("="*80)
print("DMA HANDLER ANALYSIS")
print("="*80)

# Vec 45 (DEND0B) -> trampoline at 0xFFFD28
# Vec 47 (DEND1B) -> trampoline at 0xFFFD2C
# The actual handler addresses are installed at boot time into trampolines

# Let's find where the trampoline addresses are written
# The boot code installs JMP instructions at 0xFFFDxx
# Format: JMP @aa:24 = 5A xx xx xx (4 bytes)
# So at 0xFFFD28: should be "5A aa aa aa"

# Let's find the trampoline installation code
print("\n--- Searching for trampoline installation code ---")
# Trampoline install writes 0x5A (JMP opcode) followed by handler address
# to locations 0xFFFD10, 0xFFFD14, etc.

# Search for writes to 0xFFFDxx that look like trampoline setup
# mov.b #0x5A, R -> Fx 5A  followed by mov.b R, @0xFFFDxx
for i in range(len(fw) - 10):
    if fw[i] == 0x6A and (fw[i+1] & 0xF0) == 0xA0:
        addr = (fw[i+2] << 16) | (fw[i+3] << 8) | fw[i+4]
        if 0xFFFD10 <= addr <= 0xFFFD3C:
            # Check context - is this writing a JMP opcode or handler address?
            print(f"  0x{i:05X}: mov.b r{fw[i+1]&0xF}l, @0x{addr:06X}")
            # Show context
            start = max(0, i - 12)
            end = min(len(fw), i + 12)
            ctx = ' '.join(f'{fw[j]:02X}' for j in range(start, end))
            print(f"    ctx: [{ctx}]")

# ===================================================================
# Decode DMA-related handler at Vec 36 (IMIA3 = ITU3 Compare A)
# ===================================================================
print("\n")
decode_h8_region(0x2D536, 0x2D620, "Vec 36 (IMIA3) Handler @ 0x2D536")

# Decode Vec 40 area (IMIA4)
decode_h8_region(0x010A16, 0x010B20, "Vec 40 (IMIA4 area) @ 0x010A16")

# ===================================================================
# Decode DEND0B and DEND1B handlers
# ===================================================================
# Find the actual DMA end handlers from trampoline setup
# The trampoline setup is in the main firmware init (around 0x204C4)
print("\n")
decode_h8_region(0x204C4, 0x20600, "Interrupt Trampoline Installation @ 0x204C4")

# ===================================================================
# SCAN command handler (0x0220B8) - look at CCD/DMA setup
# ===================================================================
print("\n")
decode_h8_region(0x220B8, 0x22200, "SCAN Handler (opcode 0x1B) @ 0x220B8")

# ===================================================================  
# Calibration handlers (task 05xx)
# ===================================================================
# From task table: 0x0502 -> idx 0x30, 0x0500 -> idx 0x31, 0x0501 -> idx 0x32
# We need to find the handler function table that maps indices to addresses

# Search for a function pointer table
# Task indices range from 0x00 to ~0x92, each would be a 4-byte pointer
# Let's look for a table of function pointers that starts with valid code addresses

print("\n" + "="*80)
print("TASK HANDLER DISPATCH ANALYSIS")
print("="*80)

# The task dispatch at 0x20DBA was mentioned in the motor control doc
# Let's decode it
decode_h8_region(0x20DBA, 0x20E40, "Task Dispatch @ 0x20DBA")

# ===================================================================
# P9DR analysis - LED/lamp control
# ===================================================================
print("\n" + "="*80)
print("PORT 9 (P9DR) BIT ANALYSIS - LAMP/LED CONTROL")
print("="*80)

# From the BSET/BCLR analysis:
# P9DR bit 5 and bit 7 are frequently manipulated
# bit 5: 15 BCLR sites, 2 BSET sites
# bit 7: 14 BCLR sites, 0 BSET sites
# bit 6: 1 BCLR site, 1 BSET site

# Let's look at code regions around P9DR accesses
p9dr_sites = []
for i in range(len(fw) - 4):
    if fw[i] == 0x7F and fw[i+1] == 0xE8:  # 0xFFFFE8 = P9DR
        b2, b3 = fw[i+2], fw[i+3]
        bit = (b3 >> 4) & 0x07
        if b2 == 0x70:  # BSET
            p9dr_sites.append((i, 'SET', bit))
        elif b2 == 0x72:  # BCLR
            p9dr_sites.append((i, 'CLR', bit))

print(f"P9DR bit manipulation sites: {len(p9dr_sites)}")
for off, op, bit in p9dr_sites:
    # Determine which function this is in
    region = "unknown"
    if 0x10000 <= off < 0x18000:
        region = "shared_handlers"
    elif 0x2C000 <= off < 0x2F000:
        region = "motor/timing"
    elif 0x2E000 <= off < 0x30000:
        region = "motor_step"
    elif 0x31000 <= off < 0x34000:
        region = "encoder/scan"
    elif 0x3C000 <= off < 0x40000:
        region = "scan_config"
    print(f"  0x{off:05X}: B{op} #{bit}, P9DR  [{region}]")

# ===================================================================
# Look at scan configuration code (0x3C000-0x3E000)
# This area has ASIC register writes including 0x2001C1 and 0x200001
# ===================================================================
print("\n" + "="*80)
print("SCAN CONFIGURATION CODE (where ASIC regs are written)")
print("="*80)

# Decode the region around the 0x2001C1 access at 0x3C274
decode_h8_region(0x3C260, 0x3C310, "Scan Config (ASIC 0x2001C1 write) @ 0x3C260")

# Decode region around 0x200001 and 0x200002 accesses
decode_h8_region(0x3E520, 0x3E610, "ASIC Enable/Status @ 0x3E520")

# ===================================================================
# Calibration region analysis
# ===================================================================
print("\n" + "="*80)
print("CALIBRATION CODE ANALYSIS")
print("="*80)

# Look for the function handler table
# The task table entries have an index (0x00-0x92). 
# We need to find where these indices map to function addresses.
# Search for a table of 32-bit pointers to code addresses

# Typical code addresses are in range 0x020000-0x07FFFF
# A function pointer table would be consecutive 32-bit values in this range
# Let's search around common data areas

# Try to find a handler dispatch table by looking for consecutive valid code pointers
print("\n--- Searching for handler function table ---")
for scan_start in [0x49A90, 0x49A94, 0x49A98, 0x49AA0, 0x40000, 0x45000, 0x46000, 0x47000]:
    valid_count = 0
    for j in range(scan_start, min(scan_start + 400, len(fw) - 4), 4):
        val = struct.unpack('>I', fw[j:j+4])[0]
        if 0x010000 <= val <= 0x07FFFF:
            valid_count += 1
        elif val == 0:
            valid_count += 1  # NULL entries allowed
        else:
            break
    if valid_count >= 10:
        print(f"  Candidate table at 0x{scan_start:05X}: {valid_count} consecutive valid entries")
        for j in range(scan_start, min(scan_start + valid_count * 4, len(fw) - 4), 4):
            val = struct.unpack('>I', fw[j:j+4])[0]
            idx = (j - scan_start) // 4
            print(f"    [{idx:3d}] 0x{val:08X}")

# Also look at the memory right after the task table (0x49A90+)
print("\n--- Data after task table (0x49A90-0x49B00) ---")
for off in range(0x49A90, 0x49B00, 4):
    val = struct.unpack('>I', fw[off:off+4])[0]
    print(f"  0x{off:05X}: 0x{val:08X}")


