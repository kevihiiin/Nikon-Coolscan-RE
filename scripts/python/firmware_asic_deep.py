#!/usr/bin/env python3
"""
Deep analysis: trace register-indirect ASIC accesses.
The H8/300H firmware accesses ASIC regs mostly via:
  mov.l #0x20xxxx, ERn   (load base address)
  mov.b @ERn, Rd          (read via register)
  mov.b Rs, @ERn          (write via register)
  mov.b @(disp, ERn), Rd  (read with displacement)
  mov.b Rs, @(disp, ERn)  (write with displacement)

We need to trace base+displacement patterns.
Also need to handle post-increment: mov.b @ERn+, Rd
"""

import struct
from collections import defaultdict

FW_PATH = "/home/ky/projects/Nikon-Coolscan-RE/binaries/firmware/Nikon LS-50 MBM29F400B TSOP48.bin"

with open(FW_PATH, 'rb') as f:
    fw = f.read()

# ===================================================================
# Comprehensive ASIC access finder
# ===================================================================

# Strategy: Find all mov.l #imm32, ERn instructions that load addresses
# in the ranges of interest. Then for each one, scan forward in a small
# window to find register-indirect accesses using that register.

# First, find ALL mov.l #imm32, ERd instructions
# Encoding: 7A 0d xx xx xx xx (6 bytes)
mov_l_imm = []
for i in range(len(fw) - 6):
    if fw[i] == 0x7A and (fw[i+1] & 0xF0) == 0x00:
        reg = fw[i+1] & 0x07
        addr = struct.unpack('>I', fw[i+2:i+6])[0]
        mov_l_imm.append((i, reg, addr))

# Classify by address range
RANGES = {
    'ASIC_REG': (0x200000, 0x20FFFF),
    'EXT_RAM': (0x400000, 0x41FFFF),
    'ISP1581': (0x600000, 0x6000FF),
    'ASIC_RAM': (0x800000, 0x83FFFF),
    'BUF_RAM': (0xC00000, 0xC0FFFF),
    'FLASH_DATA': (0x040000, 0x07FFFF),
    'ON_CHIP': (0xFFFD00, 0xFFFFFF),
}

asic_base_loads = []
for off, reg, addr in mov_l_imm:
    if 0x200000 <= addr <= 0x20FFFF:
        asic_base_loads.append((off, reg, addr))

print(f"Total mov.l #imm32 instructions: {len(mov_l_imm)}")
print(f"ASIC register base loads: {len(asic_base_loads)}")

# For each ASIC base load, look for subsequent register accesses
# This is a simplified static analysis - we look at the next ~200 bytes
# for register-indirect accesses using the same register number

# H8/300H register-indirect addressing:
# mov.b @ERn, Rd    -> 68 (n<<4|d)     (n = base reg pair, d = dest reg)
# mov.b Rd, @ERn    -> 68 (n<<4|d) with bit 7 set: 69 (n<<4|d) .. wait
# Actually:
# mov.b @ERn, Rd    -> 68 (n*16 + d)   where n=0-7, d=0-F (register number)
# mov.b Rs, @ERn    -> 68 (n*16 + s) with different prefix...
# 
# Let me look at actual H8/300H encoding more carefully:
# mov.b @ERs, Rd:   68 sd  where s=ERs number (0-7), d=Rd number (0-F) 
# mov.b Rs, @ERd:   68 sd  (with s having bit 3 set? No...)
# 
# Actually in H8/300H:
# mov.b @ERs, Rd:  prefix 68, byte = (s<<4 | d)  [s = ER reg 0-7 low nibble, d = r reg 0-F]
# Wait, the encoding is:
#   mov.b @ERs, Rd:  68 sd   (s = ERs number, d = Rd number)  -- READ from memory
#   mov.b Rs, @ERd:  68 sd   -- actually 69 sd for WRITE... let me check
#
# H8/300H manual:
# MOV.B @ERs, Rd:  6C sd    (s = source ER, d = dest R) -- with sign extension? No...
#
# Actually from the Ghidra output I have:
# 0x0215F8: [69 E0] mov.w r0, @er6     -- so 69 = mov.w to memory
# 0x021612: [69 50] mov.w @er5, r0     -- 69 = mov.w from memory
# 
# So for H8/300H:
# 68 sd -> mov.b @ERs, Rd (read byte)   where s=0-7 (ER pair), d=0-F (register)
# 68 sd -> when s has bit 3 set (8-F), it's a write: mov.b Rd, @ERs(s-8)
# Wait, that's only 3 bits for ER number...
#
# Let me look at it differently. From the Ghidra output:
# 69 30 -> mov.w @er3, r0   (read word)
# 69 E0 -> mov.w r0, @er6   (write word)
# So 69 XY: if X < 8, it's read: @ER(X), R(Y); if X >= 8, it's write: R(Y), @ER(X-8)
#
# Similarly 68 XY for bytes:
# 68 XY: X < 8 -> read byte @ER(X), R(Y); X >= 8 -> write byte R(Y), @ER(X-8)

# Also displacement forms:
# mov.b @(d:16, ERs), Rd:  78 s0 6A 2d dd dd  (6 bytes)
# mov.b Rs, @(d:16, ERd):  78 s0 6A Ad dd dd  (6 bytes)
# mov.w @(d:16, ERs), Rd:  78 s0 6B 2d dd dd  (6 bytes)
# mov.w Rs, @(d:16, ERd):  78 s0 6B Ad dd dd  (6 bytes)

# Post-increment: mov.b @ERn+, Rd -> 6C nd (n < 8 = read, n >= 8 = pre-decrement write)

# Let me collect ALL register-indirect accesses and try to correlate them with base loads

print("\n" + "="*80)
print("ASIC REGISTER ACCESS ANALYSIS (indirect via ERn)")
print("="*80)

# For each ASIC base load, scan forward to find indirect accesses
asic_reg_accesses = defaultdict(lambda: {'read': 0, 'write': 0, 'sites': []})

for base_off, base_reg, base_addr in asic_base_loads:
    # Scan forward up to 300 bytes from the base load
    for j in range(base_off + 6, min(base_off + 300, len(fw) - 6)):
        # Check for mov.b @ERn, Rd / mov.b Rd, @ERn  (68 XY)
        if fw[j] == 0x68:
            x = (fw[j+1] >> 4) & 0x0F
            y = fw[j+1] & 0x0F
            if x < 8 and x == base_reg:
                # Read byte: mov.b @ER(base_reg), Ry
                asic_reg_accesses[base_addr]['read'] += 1
                asic_reg_accesses[base_addr]['sites'].append((j, 'R', 'byte'))
            elif x >= 8 and (x - 8) == base_reg:
                # Write byte: mov.b Ry, @ER(base_reg)
                asic_reg_accesses[base_addr]['write'] += 1
                asic_reg_accesses[base_addr]['sites'].append((j, 'W', 'byte'))
        
        # Check for mov.w @ERn, Rd / mov.w Rd, @ERn  (69 XY)
        if fw[j] == 0x69:
            x = (fw[j+1] >> 4) & 0x0F
            y = fw[j+1] & 0x0F
            if x < 8 and x == base_reg:
                # Read word
                asic_reg_accesses[base_addr]['read'] += 1
                asic_reg_accesses[base_addr]['sites'].append((j, 'R', 'word'))
            elif x >= 8 and (x - 8) == base_reg:
                # Write word
                asic_reg_accesses[base_addr]['write'] += 1
                asic_reg_accesses[base_addr]['sites'].append((j, 'W', 'word'))
        
        # Check for displacement form: 78 n0 6A/6B ...
        if fw[j] == 0x78 and (fw[j+1] & 0x0F) == 0x00:
            src_reg = (fw[j+1] >> 4) & 0x07
            if src_reg == base_reg and j + 6 <= len(fw):
                if fw[j+2] == 0x6A:  # byte with displacement
                    rw = fw[j+3] & 0xF0
                    disp = struct.unpack('>H', fw[j+4:j+6])[0]
                    # Sign extend if needed
                    if disp >= 0x8000:
                        disp -= 0x10000
                    effective_addr = base_addr + disp
                    if rw < 0x30:  # Read
                        asic_reg_accesses[effective_addr]['read'] += 1
                        asic_reg_accesses[effective_addr]['sites'].append((j, 'R', f'byte disp={disp}'))
                    elif rw >= 0xA0:  # Write
                        asic_reg_accesses[effective_addr]['write'] += 1
                        asic_reg_accesses[effective_addr]['sites'].append((j, 'W', f'byte disp={disp}'))
                elif fw[j+2] == 0x6B:  # word with displacement
                    rw = fw[j+3] & 0xF0
                    disp = struct.unpack('>H', fw[j+4:j+6])[0]
                    if disp >= 0x8000:
                        disp -= 0x10000
                    effective_addr = base_addr + disp
                    if rw < 0x30:  # Read
                        asic_reg_accesses[effective_addr]['read'] += 1
                        asic_reg_accesses[effective_addr]['sites'].append((j, 'R', f'word disp={disp}'))
                    elif rw >= 0xA0:  # Write
                        asic_reg_accesses[effective_addr]['write'] += 1
                        asic_reg_accesses[effective_addr]['sites'].append((j, 'W', f'word disp={disp}'))
        
        # If we hit another mov.l into the same register, the base changes
        if fw[j] == 0x7A and (fw[j+1] & 0xF7) == (0x00 | base_reg):
            break  # Base register overwritten, stop tracing

# Now scan for ALL 16-bit displacement accesses regardless of base load context
# 78 n0 6A 2d dd dd  -> mov.b @(d:16, ERn), Rd  
# 78 n0 6A Ad dd dd  -> mov.b Rd, @(d:16, ERn)
# Also handle 78 n0 6A 0d dd dd patterns (shorter addressing mode)

print(f"\nASIC register accesses found via base+indirect: {len(asic_reg_accesses)} unique addresses")
print(f"\n{'Address':10s} {'R':>4s} {'W':>4s} {'Total':>6s}  Type")
print("-" * 60)
for addr in sorted(asic_reg_accesses.keys()):
    if 0x200000 <= addr <= 0x20FFFF:
        r = asic_reg_accesses[addr]['read']
        w = asic_reg_accesses[addr]['write']
        t = r + w
        rw = "R/W" if r > 0 and w > 0 else ("R" if r > 0 else "W")
        print(f"  0x{addr:06X}  {r:4d}  {w:4d}  {t:6d}  {rw}")
        for site_off, site_rw, site_type in asic_reg_accesses[addr]['sites'][:5]:
            print(f"    @ 0x{site_off:05X} ({site_rw}, {site_type})")


# ===================================================================
# Now scan for ALL absolute addressing access to I/O-like addresses
# using 8-bit addressing mode
# ===================================================================
print("\n" + "="*80)
print("H8/3003 I/O REGISTER ACCESSES (all modes)")
print("="*80)

# For H8/3003, the 8-bit absolute addressing form can access 0xFFFF00-0xFFFFFF:
# mov.b @aa:8, Rd ->  20+d aa   or  28+d aa  (different encoding?)
# Actually in H8/300H:
# mov.b @aa:8, Rd ->  byte at 0xFF00+aa sign-extended to 0xFFFFxx
# The encoding is: 2d aa where d is the register number (0-F), aa is the 8-bit address
# So 20-2F are read, and writes are different...

# Actually in H8/300H instruction set:
# MOV.B @aa:8, Rd  -> 20-2F (Rd in low nibble), followed by aa byte
# MOV.B Rs, @aa:8  -> 30-3F (Rs in low nibble), followed by aa byte

# 8-bit absolute: address = 0xFFFF00 + aa
port_io_accesses = defaultdict(lambda: {'read': 0, 'write': 0})

for i in range(len(fw) - 2):
    # MOV.B @aa:8, Rd (read) -> 2d aa  where d = Rd number
    if 0x20 <= fw[i] <= 0x2F:
        aa = fw[i+1]
        addr = 0xFFFF00 + aa
        # Only count if it's clearly a register access in the I/O range
        if addr >= 0xFFFF20:
            port_io_accesses[addr]['read'] += 1
    
    # MOV.B Rs, @aa:8 (write) -> 3d aa where d = Rs number  
    # Wait, 30-3F might be something else. Let me check.
    # Actually 30-3F might be CMP instructions. Let me be more careful.
    # In H8/300H: 2x yy = MOV.B @yy:8, Rx  and  3x yy = MOV.B Rx, @yy:8
    # But 38-3F could be CMP.B...
    # Actually: 20-2F = MOV.B @aa:8,Rd; 30-37 = MOV.B Rs,@aa:8; 38-3F = ???
    # Hmm, this is getting complex. Let me focus on what we can verify.

# This 8-bit addressing analysis is unreliable because single-byte opcodes
# can have false positives. Let me focus on the more reliable multi-byte forms.

# ===================================================================
# Comprehensive scan of KNOWN handler regions for ASIC accesses
# ===================================================================
print("\n" + "="*80)
print("ASIC ACCESS IN KEY FIRMWARE REGIONS")
print("="*80)

# Let's dump the code around each ASIC base load to understand context
print("\n--- ASIC base address loads with context ---")
for base_off, base_reg, base_addr in asic_base_loads:
    # What function/region is this in?
    region = "unknown"
    if 0x20000 <= base_off <= 0x2FFFF:
        region = "main_firmware"
    elif 0x10000 <= base_off <= 0x17FFF:
        region = "shared_handlers"
    elif 0x30000 <= base_off <= 0x3FFFF:
        region = "extended_code"
    elif 0x40000 <= base_off <= 0x4FFFF:
        region = "data/tables"
    
    # Get a few bytes of context after the load
    context = []
    for j in range(base_off + 6, min(base_off + 40, len(fw) - 2)):
        context.append(f"{fw[j]:02X}")
    
    print(f"\n  0x{base_off:05X}: mov.l #0x{base_addr:06X}, er{base_reg}  [{region}]")
    print(f"    Next bytes: {' '.join(context[:20])}")

# ===================================================================
# Deep dive: Init table ASIC registers grouped by function
# ===================================================================
print("\n" + "="*80)
print("ASIC REGISTER GROUPS (from init table analysis)")
print("="*80)

# Group ASIC registers by address range
groups = {
    'Control (0x200000-0x200046)': [],
    'Config A (0x2000C0-0x2000C1)': [],
    'CCD Channel Map (0x200100-0x200117)': [],
    'Motor/Control (0x200140-0x200150)': [],
    'Motor Drive (0x200181-0x20019B)': [],
    'Scan Timing (0x2001C0-0x2001C9)': [],
    'Status/DMA (0x200200-0x200205)': [],
    'CCD Timing (0x200400-0x200425)': [],
    'CCD Config (0x200456-0x200487)': [],
}

from collections import OrderedDict

for addr, val in sorted(asic_regs_from_init := {}):
    pass

# Re-read the init table
init_table_start = 0x2001C
init_table_end = 0x20334
asic_init = OrderedDict()
for off in range(init_table_start, init_table_end, 6):
    if off + 6 > len(fw):
        break
    addr = struct.unpack('>I', fw[off:off+4])[0]
    val16 = struct.unpack('>H', fw[off+4:off+6])[0]
    val8 = val16 & 0xFF
    if 0x200000 <= addr <= 0x20FFFF:
        asic_init[addr] = val8

# Analyze the register groups with inferred purposes
print("\n--- ASIC Register Classification ---")

for addr, val in sorted(asic_init.items()):
    if addr <= 0x200046:
        group = "CONTROL"
    elif addr <= 0x2000C1:
        group = "CONFIG"
    elif 0x200100 <= addr <= 0x200102:
        group = "CCD_ENABLE"
    elif 0x200103 <= addr <= 0x200117:
        group = "CCD_CHANNEL_MAP"
    elif 0x200140 <= addr <= 0x200150:
        group = "MOTOR_CTRL"
    elif 0x200181 <= addr <= 0x20019B:
        group = "MOTOR_DRIVE"
    elif 0x2001C0 <= addr <= 0x2001C9:
        group = "SCAN_TIMING"
    elif 0x200200 <= addr <= 0x200205:
        group = "STATUS_DMA"
    elif 0x200400 <= addr <= 0x200425:
        group = "CCD_TIMING"
    elif 0x200456 <= addr <= 0x200487:
        group = "CCD_CONFIG"
    else:
        group = "UNKNOWN"
    
    # Try to infer purpose from value and position
    notes = ""
    if addr == 0x200001:
        notes = "Master enable (0x80 = bit 7 set)"
    elif addr == 0x200044:
        notes = "Control reg A"
    elif addr == 0x200046:
        notes = "Control reg C (0xFF = all bits set)"
    elif addr == 0x2000C0:
        notes = "Config word high (0x52)"
    elif addr == 0x2000C1:
        notes = "Config word low (0x04)"
    elif addr == 0x200100:
        notes = "CCD enable A (0x3F = 6 channels?)"
    elif addr == 0x200101:
        notes = "CCD enable B (0x3F)"
    elif addr == 0x200102:
        notes = "CCD/DMA control (0x04)"
    elif addr == 0x200103:
        notes = "CCD gain select (0x01)"
    elif 0x200104 <= addr <= 0x200107:
        notes = f"CCD ch{addr-0x200104} offset ({val:#x}=position {val})"
    elif 0x20010C <= addr <= 0x20010F:
        notes = f"CCD ch{addr-0x20010C} config ({val:#x})"
    elif 0x200114 <= addr <= 0x200117:
        notes = f"CCD timing ch{addr-0x200114} ({val:#x}=delay {val*8}ns?)"
    elif 0x200140 <= addr <= 0x200150:
        notes = f"Motor config"
    elif addr == 0x200181:
        notes = "Motor drive enable (0x0D)"
    elif addr == 0x200193:
        notes = "Motor drive config (0x0E)"
    elif 0x2001C0 <= addr <= 0x2001C9:
        notes = "Scan line timing"
    elif 0x200400 <= addr <= 0x200425:
        notes = "CCD timing chain"
    elif 0x200456 <= addr <= 0x200458:
        notes = "CCD dark reference"
    elif 0x20046D <= addr <= 0x200487:
        notes = "Per-channel CCD config"
    
    print(f"  0x{addr:06X} = 0x{val:02X}  [{group:16s}]  {notes}")

# ===================================================================
# Extended ASIC register space analysis
# ===================================================================
print("\n" + "="*80)
print("CCD TIMING REGISTER ANALYSIS (0x200400+)")
print("="*80)

# The 0x200400 range has many registers initialized - this is likely CCD timing
# Let's analyze the pattern
print("\n--- CCD Timing registers with value analysis ---")
ccd_timing_regs = {a: v for a, v in sorted(asic_init.items()) if 0x200400 <= a <= 0x200500}
for addr, val in sorted(ccd_timing_regs.items()):
    offset = addr - 0x200400
    print(f"  0x{addr:06X} (offset +0x{offset:02X}) = 0x{val:02X} ({val:3d})")

# Group by what looks like paired registers (address/data or high/low)
print("\n--- Grouped as register pairs ---")
addrs = sorted(ccd_timing_regs.keys())
i = 0
while i < len(addrs):
    addr = addrs[i]
    val = ccd_timing_regs[addr]
    offset = addr - 0x200400
    
    # Check if next address is consecutive
    if i + 1 < len(addrs) and addrs[i+1] == addr + 1:
        val2 = ccd_timing_regs[addrs[i+1]]
        combined = (val << 8) | val2
        print(f"  0x{addr:06X}-0x{addr+1:06X} (+0x{offset:02X}): 0x{combined:04X} ({combined:5d})")
        i += 2
    else:
        print(f"  0x{addr:06X} (+0x{offset:02X}):           0x{val:02X}   ({val:3d})")
        i += 1

# ===================================================================
# Look at code that references the debug strings
# ===================================================================
print("\n" + "="*80)
print("CODE REFERENCING CALIBRATION DEBUG STRINGS")
print("="*80)

# The strings are at 0x49EDC-0x49EFB
# Find mov.l #0x49Exx references
calib_string_addrs = {
    0x49EDC: "DA_COARSE",
    0x49EE6: "DA_FINE", 
    0x49EEE: "EXP_TIME",
    0x49EF7: "GAIN",
    0x49E9D: "SA_OBJECT",
    0x49EA7: "240_OBJECT",
    0x49EB2: "240_HEAD",
    0x49EBB: "FD_OBJECT",
    0x49EC5: "6SA_OBJECT",
    0x49ED0: "36SA_OBJECT",
}

for str_addr, name in sorted(calib_string_addrs.items()):
    # Search for mov.l #str_addr in firmware
    target = struct.pack('>I', str_addr)
    for i in range(len(fw) - 6):
        if fw[i] == 0x7A and (fw[i+1] & 0xF0) == 0x00:
            if fw[i+2:i+6] == target:
                reg = fw[i+1] & 0x07
                print(f"  0x{i:05X}: mov.l #0x{str_addr:05X} (\"{name}\"), er{reg}")
                # Show surrounding context
                start = max(0, i - 12)
                end = min(len(fw), i + 30)
                ctx_bytes = ' '.join(f'{fw[j]:02X}' for j in range(start, end))
                print(f"    context: [{ctx_bytes}]")

# ===================================================================  
# Find all string pointer tables
# ===================================================================
print("\n" + "="*80)
print("STRING POINTER TABLE SEARCH (adapter/film type names)")
print("="*80)

# The strings at 0x49E31+ look like adapter names used for mode selection
adapter_strings = {
    0x49E31: "Nikon   LS-50 ED        1.02Mount",
    0x49E53: "Strip",
    0x49E59: "240",
    0x49E5D: "Feeder",
    0x49E64: "6Strip",
    0x49E6B: "36Strip",
    0x49E73: "Test",
    0x49E78: "FH-3",
    0x49E7D: "FH-G1",
    0x49E83: "FH-A1",
}

# Look for pointer tables that reference these strings
for str_addr in sorted(adapter_strings.keys()):
    packed = struct.pack('>I', str_addr)
    for i in range(len(fw) - 4):
        if fw[i:i+4] == packed:
            # This could be a pointer table entry
            if i != str_addr:  # Don't match the string itself
                print(f"  0x{i:05X}: pointer to 0x{str_addr:05X} (\"{adapter_strings[str_addr][:20]}...\")")


