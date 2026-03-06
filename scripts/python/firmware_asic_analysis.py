#!/usr/bin/env python3
"""
Comprehensive firmware ASIC register analysis for Nikon LS-50 (H8/3003).
Scans entire 512KB firmware binary for:
1. All ASIC register accesses (0x200000-0x20FFFF)
2. I/O init table extraction (0x2001C, 132 entries x 6 bytes)
3. ASIC RAM accesses (0x800000-0x83FFFF)
4. Buffer RAM accesses (0xC00000-0xC0FFFF)
5. ISP1581 accesses (0x600000-0x6000FF)
6. H8/3003 I/O register accesses (0xFFFF20-0xFFFFFF)
7. String references (debug strings)
8. DMA register accesses
"""

import struct
import sys
from collections import defaultdict

FW_PATH = "/home/ky/projects/Nikon-Coolscan-RE/binaries/firmware/Nikon LS-50 MBM29F400B TSOP48.bin"

with open(FW_PATH, 'rb') as f:
    fw = f.read()

print(f"Firmware size: {len(fw)} bytes ({len(fw)//1024}KB)")

# ===================================================================
# TASK 1: Extract I/O Init Table at 0x2001C (132 entries x 6 bytes)
# ===================================================================
print("\n" + "="*80)
print("TASK 1: I/O INIT TABLE (0x2001C - 0x20334, 132 entries x 6 bytes)")
print("="*80)

init_table_start = 0x2001C  # firmware offset
init_table_end = 0x20334

asic_regs_from_init = {}
cpu_regs_from_init = {}
other_regs_from_init = {}

entry_count = 0
for off in range(init_table_start, init_table_end, 6):
    if off + 6 > len(fw):
        break
    # 4-byte address (big-endian), 2-byte value (big-endian), low byte written
    addr = struct.unpack('>I', fw[off:off+4])[0]
    val16 = struct.unpack('>H', fw[off+4:off+6])[0]
    val8 = val16 & 0xFF
    entry_count += 1
    
    if 0x200000 <= addr <= 0x20FFFF:
        asic_regs_from_init[addr] = val8
    elif 0xFFFF00 <= addr <= 0xFFFFFF:
        cpu_regs_from_init[addr] = val8
    else:
        other_regs_from_init[addr] = val8

print(f"\nTotal entries: {entry_count}")
print(f"  ASIC regs (0x200000+): {len(asic_regs_from_init)}")
print(f"  CPU I/O regs (0xFFFF+): {len(cpu_regs_from_init)}")
print(f"  Other: {len(other_regs_from_init)}")

print(f"\n--- ASIC Register Init Values ({len(asic_regs_from_init)} entries) ---")
for addr in sorted(asic_regs_from_init.keys()):
    print(f"  0x{addr:06X} = 0x{asic_regs_from_init[addr]:02X}")

print(f"\n--- CPU I/O Register Init Values ({len(cpu_regs_from_init)} entries) ---")
# H8/3003 register name lookup
h8_regs = {
    0xFFFF60: "TSTR", 0xFFFF61: "TSNC", 0xFFFF62: "TMDR", 0xFFFF63: "TFCR",
    0xFFFF64: "TCR0", 0xFFFF65: "TIOR0", 0xFFFF66: "TIER0", 0xFFFF68: "TSR0",
    0xFFFF6A: "TCNT0_H", 0xFFFF6B: "TCNT0_L",
    0xFFFF6C: "GRA0_H", 0xFFFF6D: "GRA0_L", 0xFFFF6E: "GRB0_H", 0xFFFF6F: "GRB0_L",
    0xFFFF70: "TCR1", 0xFFFF71: "TIOR1", 0xFFFF72: "TIER1", 0xFFFF74: "TSR1",
    0xFFFF76: "TCNT1_H", 0xFFFF77: "TCNT1_L",
    0xFFFF78: "GRA1_H", 0xFFFF79: "GRA1_L", 0xFFFF7A: "GRB1_H", 0xFFFF7B: "GRB1_L",
    0xFFFF7C: "TCR2", 0xFFFF7D: "TIOR2", 0xFFFF7E: "TIER2", 0xFFFF80: "TSR2",
    0xFFFF82: "TCNT2_H", 0xFFFF83: "TCNT2_L",
    0xFFFF84: "GRA2_H", 0xFFFF85: "GRA2_L", 0xFFFF86: "GRB2_H", 0xFFFF87: "GRB2_L",
    0xFFFF88: "TCR3", 0xFFFF89: "TIOR3", 0xFFFF8A: "TIER3", 0xFFFF8C: "TSR3",
    0xFFFF8E: "TCNT3_H", 0xFFFF8F: "TCNT3_L",
    0xFFFF90: "GRA3_H", 0xFFFF91: "GRA3_L", 0xFFFF92: "GRB3_H", 0xFFFF93: "GRB3_L",
    0xFFFF94: "BRA3_H", 0xFFFF95: "BRA3_L", 0xFFFF96: "BRB3_H", 0xFFFF97: "BRB3_L",
    0xFFFF98: "TCR4", 0xFFFF99: "TIOR4", 0xFFFF9A: "TIER4", 0xFFFF9C: "TSR4",
    0xFFFF9E: "TCNT4_H", 0xFFFF9F: "TCNT4_L",
    0xFFFFA0: "GRA4_H", 0xFFFFA1: "GRA4_L", 0xFFFFA2: "GRB4_H", 0xFFFFA3: "GRB4_L",
    0xFFFFA4: "BRA4_H", 0xFFFFA5: "BRA4_L", 0xFFFFA6: "BRB4_H", 0xFFFFA7: "BRB4_L",
    0xFFFFA8: "WDT_TCSR", 0xFFFFA9: "WDT_TCNT",
    0xFFFFAA: "ADCSR", 0xFFFFAC: "ADCR",
    0xFFFFB0: "DTCERA", 0xFFFFB2: "DTCERB", 0xFFFFB4: "DTCERC",
    0xFFFFB6: "DTVECR",
    0xFFFFB8: "BRCR_DMA", 0xFFFFBA: "MAR0A_H",
    0xFFFFC0: "DMACRA0", 0xFFFFC2: "MAR0B_H",
    0xFFFFC8: "DMACRB0", 0xFFFFCA: "MAR1A_H",
    0xFFFFD0: "DMACRA1", 0xFFFFD2: "MAR1B_H",
    0xFFFFD4: "P1DDR", 0xFFFFD5: "P2DDR", 0xFFFFD6: "P3DDR", 0xFFFFD7: "P4DDR",
    0xFFFFD8: "P5DDR", 0xFFFFD9: "P6DDR", 0xFFFFDA: "P7DDR", 0xFFFFDB: "P8DDR",
    0xFFFFDC: "P9DDR", 0xFFFFDD: "PADDR", 0xFFFFDE: "PBDDR",
    0xFFFFE0: "P1DR", 0xFFFFE1: "P2DR", 0xFFFFE2: "P3DR", 0xFFFFE3: "P4DR",
    0xFFFFE4: "P5DR", 0xFFFFE5: "P6DR", 0xFFFFE6: "P7DR", 0xFFFFE7: "P8DR",
    0xFFFFE8: "P9DR", 0xFFFFE9: "PADR", 0xFFFFEA: "PBDR",
    0xFFFFF0: "ASTCR", 0xFFFFF1: "RDNCR",
    0xFFFFF2: "ABWCR", 0xFFFFF3: "WCRH", 0xFFFFF4: "WCR",
    0xFFFFF5: "WCER", 0xFFFFF6: "WCRL",
    0xFFFFF8: "BRCR", 0xFFFFF9: "CSCR",
}
for addr in sorted(cpu_regs_from_init.keys()):
    name = h8_regs.get(addr, "???")
    print(f"  0x{addr:06X} ({name:12s}) = 0x{cpu_regs_from_init[addr]:02X}")

if other_regs_from_init:
    print(f"\n--- Other Register Init Values ({len(other_regs_from_init)} entries) ---")
    for addr in sorted(other_regs_from_init.keys()):
        print(f"  0x{addr:06X} = 0x{other_regs_from_init[addr]:02X}")


# ===================================================================
# TASK 2: Scan for ALL ASIC register accesses in firmware
# ===================================================================
print("\n" + "="*80)
print("TASK 2: ALL ASIC REGISTER ACCESSES (0x200000-0x20FFFF)")
print("="*80)

# H8/300H addressing modes that can encode 24-bit/32-bit addresses:
# 
# mov.b @aa:24, Rd  -> 6A 2d aa aa aa   (read byte from abs24)
# mov.b Rs, @aa:24  -> 6A A{s} aa aa aa  (write byte to abs24)  
# mov.w @aa:24, Rd  -> 6B 2d aa aa aa   (read word from abs24)
# mov.w Rs, @aa:24  -> 6B A{s} aa aa aa  (write word to abs24)
# mov.l #imm32, ERd -> 7A 0d imm32      (load immediate into reg - not a memory access)
# mov.l @aa:24, ERd -> 01 00 6B 2d 00 aa aa aa  (not common, 32-bit access)
#
# We also need to catch indirect access through ER registers loaded with mov.l #imm32:
# mov.l #0x20xxxx, ERd  ->  7A 0d 00 20 xx xx
# mov.b/w @ERd, Rs / Rs, @ERd  -> this uses register indirect, harder to track

# Direct absolute 24-bit addressing patterns
asic_accesses = defaultdict(lambda: {'read': 0, 'write': 0, 'sites_r': [], 'sites_w': []})
asic_ram_accesses = defaultdict(lambda: {'read': 0, 'write': 0, 'sites_r': [], 'sites_w': []})
buffer_ram_accesses = defaultdict(lambda: {'read': 0, 'write': 0, 'sites_r': [], 'sites_w': []})
isp1581_accesses = defaultdict(lambda: {'read': 0, 'write': 0, 'sites_r': [], 'sites_w': []})

# Scan for mov.b @aa:24, Rd  (6A 2x aa aa aa) - read byte
# and      mov.b Rs, @aa:24  (6A Ax aa aa aa) - write byte
# and      mov.w @aa:24, Rd  (6B 2x aa aa aa) - read word
# and      mov.w Rs, @aa:24  (6B Ax aa aa aa) - write word

def categorize_access(addr, offset, is_read, accmap):
    """Add an access to the appropriate tracking map."""
    if is_read:
        accmap[addr]['read'] += 1
        accmap[addr]['sites_r'].append(offset)
    else:
        accmap[addr]['write'] += 1
        accmap[addr]['sites_w'].append(offset)

for i in range(len(fw) - 5):
    # mov.b @aa:24, Rd  -> 6A 2x aa aa aa  (read)
    if fw[i] == 0x6A and (fw[i+1] & 0xF0) == 0x20:
        addr = (fw[i+2] << 16) | (fw[i+3] << 8) | fw[i+4]
        if 0x200000 <= addr <= 0x20FFFF:
            categorize_access(addr, i, True, asic_accesses)
        elif 0x800000 <= addr <= 0x83FFFF:
            categorize_access(addr, i, True, asic_ram_accesses)
        elif 0xC00000 <= addr <= 0xC0FFFF:
            categorize_access(addr, i, True, buffer_ram_accesses)
        elif 0x600000 <= addr <= 0x6000FF:
            categorize_access(addr, i, True, isp1581_accesses)
    
    # mov.b Rs, @aa:24  -> 6A Ax aa aa aa  (write)
    if fw[i] == 0x6A and (fw[i+1] & 0xF0) == 0xA0:
        addr = (fw[i+2] << 16) | (fw[i+3] << 8) | fw[i+4]
        if 0x200000 <= addr <= 0x20FFFF:
            categorize_access(addr, i, False, asic_accesses)
        elif 0x800000 <= addr <= 0x83FFFF:
            categorize_access(addr, i, False, asic_ram_accesses)
        elif 0xC00000 <= addr <= 0xC0FFFF:
            categorize_access(addr, i, False, buffer_ram_accesses)
        elif 0x600000 <= addr <= 0x6000FF:
            categorize_access(addr, i, False, isp1581_accesses)
    
    # mov.w @aa:24, Rd  -> 6B 2x aa aa aa  (read word)
    if fw[i] == 0x6B and (fw[i+1] & 0xF0) == 0x20:
        addr = (fw[i+2] << 16) | (fw[i+3] << 8) | fw[i+4]
        if 0x200000 <= addr <= 0x20FFFF:
            categorize_access(addr, i, True, asic_accesses)
        elif 0x800000 <= addr <= 0x83FFFF:
            categorize_access(addr, i, True, asic_ram_accesses)
        elif 0xC00000 <= addr <= 0xC0FFFF:
            categorize_access(addr, i, True, buffer_ram_accesses)
        elif 0x600000 <= addr <= 0x6000FF:
            categorize_access(addr, i, True, isp1581_accesses)
    
    # mov.w Rs, @aa:24  -> 6B Ax aa aa aa  (write word)
    if fw[i] == 0x6B and (fw[i+1] & 0xF0) == 0xA0:
        addr = (fw[i+2] << 16) | (fw[i+3] << 8) | fw[i+4]
        if 0x200000 <= addr <= 0x20FFFF:
            categorize_access(addr, i, False, asic_accesses)
        elif 0x800000 <= addr <= 0x83FFFF:
            categorize_access(addr, i, False, asic_ram_accesses)
        elif 0xC00000 <= addr <= 0xC0FFFF:
            categorize_access(addr, i, False, buffer_ram_accesses)
        elif 0x600000 <= addr <= 0x6000FF:
            categorize_access(addr, i, False, isp1581_accesses)

# Also scan for mov.l #imm32, ERd -> 7A 0d xx xx xx xx  (load ASIC address into register)
# This is how indirect accesses are set up
asic_addr_loads = defaultdict(list)  # addr -> list of firmware offsets
asic_ram_addr_loads = defaultdict(list)
buffer_ram_addr_loads = defaultdict(list)
isp1581_addr_loads = defaultdict(list)

for i in range(len(fw) - 6):
    if fw[i] == 0x7A and (fw[i+1] & 0xF0) == 0x00:
        addr = struct.unpack('>I', fw[i+2:i+6])[0]
        if 0x200000 <= addr <= 0x20FFFF:
            asic_addr_loads[addr].append(i)
        elif 0x800000 <= addr <= 0x83FFFF:
            asic_ram_addr_loads[addr].append(i)
        elif 0xC00000 <= addr <= 0xC0FFFF:
            buffer_ram_addr_loads[addr].append(i)
        elif 0x600000 <= addr <= 0x6000FF:
            isp1581_addr_loads[addr].append(i)

def print_access_map(name, accmap, addr_loads):
    total_regs = len(set(list(accmap.keys()) + list(addr_loads.keys())))
    print(f"\n--- {name} ({total_regs} unique addresses) ---")
    print(f"{'Address':10s} {'R':>4s} {'W':>4s} {'Load':>5s} {'Total':>6s}  Access Type")
    print("-" * 60)
    all_addrs = sorted(set(list(accmap.keys()) + list(addr_loads.keys())))
    for addr in all_addrs:
        r = accmap[addr]['read'] if addr in accmap else 0
        w = accmap[addr]['write'] if addr in accmap else 0
        l = len(addr_loads.get(addr, []))
        total = r + w + l
        if r > 0 and w > 0:
            atype = "R/W"
        elif r > 0:
            atype = "R"
        elif w > 0:
            atype = "W"
        elif l > 0:
            atype = "Load(indirect)"
        else:
            atype = "?"
        print(f"  0x{addr:06X}  {r:4d}  {w:4d}  {l:5d}  {total:6d}  {atype}")

print_access_map("ASIC Registers (0x200000-0x20FFFF) - Direct Accesses", asic_accesses, asic_addr_loads)
print_access_map("ASIC RAM (0x800000-0x83FFFF)", asic_ram_accesses, asic_ram_addr_loads)
print_access_map("Buffer RAM (0xC00000-0xC0FFFF)", buffer_ram_accesses, buffer_ram_addr_loads)
print_access_map("ISP1581 USB (0x600000-0x6000FF)", isp1581_accesses, isp1581_addr_loads)

# Show detailed access sites for most-accessed ASIC registers
print("\n--- Top ASIC registers by access count (with sites) ---")
asic_all = {}
for addr in sorted(set(list(asic_accesses.keys()) + list(asic_addr_loads.keys()))):
    r = asic_accesses[addr]['read'] if addr in asic_accesses else 0
    w = asic_accesses[addr]['write'] if addr in asic_accesses else 0
    l = len(asic_addr_loads.get(addr, []))
    asic_all[addr] = r + w + l

for addr, count in sorted(asic_all.items(), key=lambda x: -x[1])[:30]:
    r_sites = asic_accesses[addr]['sites_r'] if addr in asic_accesses else []
    w_sites = asic_accesses[addr]['sites_w'] if addr in asic_accesses else []
    l_sites = asic_addr_loads.get(addr, [])
    print(f"\n  0x{addr:06X} (total {count} accesses):")
    if r_sites:
        print(f"    READ  [{len(r_sites)}]: {', '.join(f'0x{s:05X}' for s in r_sites[:10])}")
    if w_sites:
        print(f"    WRITE [{len(w_sites)}]: {', '.join(f'0x{s:05X}' for s in w_sites[:10])}")
    if l_sites:
        print(f"    LOAD  [{len(l_sites)}]: {', '.join(f'0x{s:05X}' for s in l_sites[:10])}")


# ===================================================================
# TASK 3: Debug string references
# ===================================================================
print("\n" + "="*80)
print("TASK 3: DEBUG STRING SEARCH")
print("="*80)

# Search for known debug strings
debug_strings = [
    b"DA_COARSE", b"DA_FINE", b"EXP_TIME", b"GAIN",
    b"SCAN Motor", b"AF Motor", b"CCD", b"LAMP", b"LED",
    b"CALIB", b"DARK", b"WHITE", b"SHADING", b"OFFSET",
    b"DMA", b"EXPOSURE", b"FOCUS", b"SENSOR",
    b"GAIN_R", b"GAIN_G", b"GAIN_B",
    b"RED", b"GREEN", b"BLUE",
]

for s in debug_strings:
    idx = 0
    while True:
        idx = fw.find(s, idx)
        if idx == -1:
            break
        # Get context: read surrounding bytes for full string
        start = max(0, idx - 2)
        end = min(len(fw), idx + len(s) + 20)
        context = fw[start:end]
        # Find null terminator
        null_pos = context.find(b'\x00', idx - start)
        if null_pos >= 0:
            full_str = context[idx-start:null_pos]
        else:
            full_str = context[idx-start:idx-start+len(s)+16]
        printable = ''.join(chr(b) if 32 <= b < 127 else '.' for b in full_str)
        print(f"  '{s.decode()}' found at 0x{idx:05X}: \"{printable}\"")
        idx += 1

# Full string dump of the debug area around 0x49E00
print("\n--- All strings in 0x49E00-0x4A000 region ---")
i = 0x49E00
while i < 0x4A000:
    if fw[i] >= 0x20 and fw[i] < 0x7F:
        # Start of a printable string
        end = i
        while end < 0x4A000 and fw[end] >= 0x20 and fw[end] < 0x7F:
            end += 1
        if end - i >= 3:  # At least 3 chars
            s = fw[i:end].decode('ascii', errors='replace')
            print(f"  0x{i:05X}: \"{s}\"")
        i = end + 1
    else:
        i += 1

# Also check 0x49800-0x49E00 for task table and calibration strings
print("\n--- All strings in 0x49800-0x49E00 region ---")
i = 0x49800
while i < 0x49E00:
    if fw[i] >= 0x20 and fw[i] < 0x7F:
        end = i
        while end < 0x49E00 and fw[end] >= 0x20 and fw[end] < 0x7F:
            end += 1
        if end - i >= 3:
            s = fw[i:end].decode('ascii', errors='replace')
            print(f"  0x{i:05X}: \"{s}\"")
        i = end + 1
    else:
        i += 1


# ===================================================================
# TASK 4: Task table at 0x49910
# ===================================================================
print("\n" + "="*80)
print("TASK 4: TASK TABLE AT 0x49910 (calibration 05xx, sensor 06xx, scan 08xx)")
print("="*80)

# The task table likely has fixed-size entries. Let's examine the structure.
# Read and dump the region around 0x49910
print("\n--- Raw hex dump of task table area 0x49910-0x49C00 ---")
for off in range(0x49910, min(0x49C00, len(fw)), 16):
    hexbytes = ' '.join(f'{fw[off+j]:02X}' for j in range(min(16, len(fw)-off)))
    ascii_str = ''.join(chr(fw[off+j]) if 32 <= fw[off+j] < 127 else '.' for j in range(min(16, len(fw)-off)))
    print(f"  0x{off:05X}: {hexbytes:<48s}  {ascii_str}")

# Try to decode task table entries
# Common format: [task_code:16] [handler_index:16] or [task_code:16] [handler_addr:32]
# Let's try 4-byte entries first: [code:16] [index:16]
print("\n--- Attempt: 4-byte task entries (code:16, index:16) ---")
for off in range(0x49910, 0x49C00, 4):
    code = struct.unpack('>H', fw[off:off+2])[0]
    idx = struct.unpack('>H', fw[off+2:off+4])[0]
    if code == 0x0000 and idx == 0x0000:
        continue
    if code == 0xFFFF:
        print(f"  [END MARKER at 0x{off:05X}]")
        break
    if 0x0100 <= code <= 0x0FFF:
        category = {0x01: "INIT", 0x02: "MOTOR_INIT", 0x03: "MEDIA", 0x04: "MOTOR", 
                    0x05: "CALIB", 0x06: "SENSOR", 0x07: "LAMP", 0x08: "SCAN",
                    0x09: "FOCUS", 0x0A: "EJECT", 0x0B: "USB", 0x0C: "DIAG"}.get(code >> 8, "???")
        print(f"  0x{off:05X}: code=0x{code:04X} ({category:12s})  idx=0x{idx:04X}")


# ===================================================================
# TASK 5: DMA register analysis
# ===================================================================
print("\n" + "="*80)
print("TASK 5: H8/3003 DMA REGISTER ACCESSES")
print("="*80)

# H8/3003 DMA registers
dma_regs = {
    0xFFFFB0: "DTCERA", 0xFFFFB1: "DTCERB", 0xFFFFB2: "DTCERC", 0xFFFFB3: "DTCERD",
    0xFFFFB6: "DTVECR",
    0xFFFFB8: "DMABCR_H", 0xFFFFB9: "DMABCR_L",
    0xFFFFBA: "MAR0AH", 0xFFFFBB: "MAR0AL", 0xFFFFBC: "ETCR0A_H", 0xFFFFBD: "ETCR0A_L",
    0xFFFFBE: "IOAR0A", 0xFFFFBF: "DTCR0A",
    0xFFFFC0: "MAR0BH", 0xFFFFC1: "MAR0BL", 0xFFFFC2: "ETCR0B_H", 0xFFFFC3: "ETCR0B_L",
    0xFFFFC4: "IOAR0B", 0xFFFFC5: "DTCR0B",
    0xFFFFC6: "MAR1AH", 0xFFFFC7: "MAR1AL", 0xFFFFC8: "ETCR1A_H", 0xFFFFC9: "ETCR1A_L",
    0xFFFFCA: "IOAR1A", 0xFFFFCB: "DTCR1A",
    0xFFFFCC: "MAR1BH", 0xFFFFCD: "MAR1BL", 0xFFFFCE: "ETCR1B_H", 0xFFFFCF: "ETCR1B_L",
    0xFFFFD0: "IOAR1B", 0xFFFFD1: "DTCR1B",
}

# Scan for direct accesses to DMA registers
for i in range(len(fw) - 5):
    # mov.b @aa:24, Rd (read)
    if fw[i] == 0x6A and (fw[i+1] & 0xF0) == 0x20:
        addr = (fw[i+2] << 16) | (fw[i+3] << 8) | fw[i+4]
        if addr in dma_regs:
            print(f"  0x{i:05X}: READ  {dma_regs[addr]:12s} (0x{addr:06X})")
    # mov.b Rs, @aa:24 (write)
    if fw[i] == 0x6A and (fw[i+1] & 0xF0) == 0xA0:
        addr = (fw[i+2] << 16) | (fw[i+3] << 8) | fw[i+4]
        if addr in dma_regs:
            print(f"  0x{i:05X}: WRITE {dma_regs[addr]:12s} (0x{addr:06X})")
    # mov.w @aa:24, Rd (read word)
    if fw[i] == 0x6B and (fw[i+1] & 0xF0) == 0x20:
        addr = (fw[i+2] << 16) | (fw[i+3] << 8) | fw[i+4]
        if addr in dma_regs:
            print(f"  0x{i:05X}: READ  {dma_regs[addr]:12s} (0x{addr:06X}) [word]")
    # mov.w Rs, @aa:24 (write word)
    if fw[i] == 0x6B and (fw[i+1] & 0xF0) == 0xA0:
        addr = (fw[i+2] << 16) | (fw[i+3] << 8) | fw[i+4]
        if addr in dma_regs:
            print(f"  0x{i:05X}: WRITE {dma_regs[addr]:12s} (0x{addr:06X}) [word]")

# Also scan for mov.b @aa:8 short form access to I/O regs
# H8/300H can use 8-bit addressing for 0xFFxxxx:  mov.b @xx:8, Rd -> 20-2F range or special encoding
# Actually for H8/300H, many DMA registers use the short form too.
# mov.b @0xFFFFxx, Rd can be encoded as: 2x yy where xx = 0xFF00+yy offset
# But this is complex. Let's also look for 16-bit absolute addressing of the 0xFFxx area
# mov.b @aa:16, Rd  -> 6A 0x aa aa  (16-bit absolute addressing, sign-extended)
# If aa >= 0xFF00, it maps to 0xFFFF00+xx
print("\n--- DMA register accesses via 16-bit addressing ---")
for i in range(len(fw) - 4):
    # mov.b @aa:16, Rd -> 6A 0x hi lo
    if fw[i] == 0x6A and (fw[i+1] & 0xF0) == 0x00:
        addr16 = (fw[i+2] << 8) | fw[i+3]
        if addr16 >= 0xFF00:
            addr = 0xFFFF00 + (addr16 & 0xFF)
            if addr in dma_regs:
                print(f"  0x{i:05X}: READ  {dma_regs[addr]:12s} (0x{addr:06X}) [16-bit abs]")
    # mov.b Rs, @aa:16 -> 6A 8x hi lo
    if fw[i] == 0x6A and (fw[i+1] & 0xF0) == 0x80:
        addr16 = (fw[i+2] << 8) | fw[i+3]
        if addr16 >= 0xFF00:
            addr = 0xFFFF00 + (addr16 & 0xFF)
            if addr in dma_regs:
                print(f"  0x{i:05X}: WRITE {dma_regs[addr]:12s} (0x{addr:06X}) [16-bit abs]")


# ===================================================================
# TASK 6: Look at DMA handler regions
# ===================================================================
print("\n" + "="*80)
print("TASK 6: DMA HANDLER REGION ANALYSIS")
print("="*80)

# Vec 45 (DEND0B) -> 0xFFFD28 trampoline
# Vec 47 (DEND1B) -> 0xFFFD2C trampoline
# The actual handler addresses need to be found from the trampoline setup code
# Let's look at the trampoline setup near 0x204C4

# Dump the code around the mentioned DMA vectors
# Vec 36 -> IMIA3 (not DMA), mentioned as 0x2D536
# Vec 40 -> IMIA4 (not DMA), mentioned as 0x010A16
# Let me dump those areas
print("\n--- Code at 0x2D536 (Vec 36 = IMIA3 handler) ---")
for off in range(0x2D536, min(0x2D600, len(fw)), 2):
    print(f"  0x{off:05X}: {fw[off]:02X} {fw[off+1]:02X}")

print("\n--- Code at 0x010A16 (Vec 40 = IMIA4 handler?) ---")
for off in range(0x010A16, min(0x010B00, len(fw)), 2):
    print(f"  0x{off:05X}: {fw[off]:02X} {fw[off+1]:02X}")


# ===================================================================
# TASK 7: ASIC register address loads (indirect via mov.l)
# ===================================================================
print("\n" + "="*80)
print("TASK 7: ASIC ADDRESS LOADS (indirect access setup)")  
print("="*80)
print("Addresses loaded into ER registers that point to ASIC space:")
for addr in sorted(asic_addr_loads.keys()):
    sites = asic_addr_loads[addr]
    print(f"  0x{addr:06X}: {len(sites)} loads at {', '.join(f'0x{s:05X}' for s in sites[:8])}")

print("\nASIC RAM address loads:")
for addr in sorted(asic_ram_addr_loads.keys()):
    sites = asic_ram_addr_loads[addr]
    print(f"  0x{addr:06X}: {len(sites)} loads at {', '.join(f'0x{s:05X}' for s in sites[:8])}")

print("\nBuffer RAM address loads:")
for addr in sorted(buffer_ram_addr_loads.keys()):
    sites = buffer_ram_addr_loads[addr]
    print(f"  0x{addr:06X}: {len(sites)} loads at {', '.join(f'0x{s:05X}' for s in sites[:8])}")

print("\nISP1581 address loads:")
for addr in sorted(isp1581_addr_loads.keys()):
    sites = isp1581_addr_loads[addr]
    print(f"  0x{addr:06X}: {len(sites)} loads at {', '.join(f'0x{s:05X}' for s in sites[:8])}")


# ===================================================================
# TASK 8: Calibration data area (0x4D000 region)
# ===================================================================
print("\n" + "="*80)
print("TASK 8: POTENTIAL CALIBRATION DATA AREAS")
print("="*80)

# Check if 0x4D000 is zeroed
zero_runs = []
run_start = None
for i in range(0x4D000, min(0x50000, len(fw))):
    if fw[i] == 0x00:
        if run_start is None:
            run_start = i
    else:
        if run_start is not None:
            if i - run_start >= 64:
                zero_runs.append((run_start, i - run_start))
            run_start = None

print("Large zero runs in 0x4D000-0x50000:")
for start, length in zero_runs:
    print(f"  0x{start:05X} - 0x{start+length-1:05X}: {length} bytes zeroed")

# Look for references to 0x4D000 area
print("\nFirmware references to 0x4D0xx area:")
for i in range(len(fw) - 6):
    if fw[i] == 0x7A and (fw[i+1] & 0xF0) == 0x00:
        addr = struct.unpack('>I', fw[i+2:i+6])[0]
        if 0x4D000 <= addr <= 0x4DFFF:
            print(f"  0x{i:05X}: mov.l #0x{addr:06X}, er{fw[i+1] & 0x07}")


# ===================================================================
# TASK 9: Lamp/LED control search
# ===================================================================
print("\n" + "="*80)
print("TASK 9: LAMP/LED CONTROL SEARCH")
print("="*80)

# Search for lamp-related strings
lamp_strings = [b"LAMP", b"lamp", b"LED", b"led", b"LIGHT", b"light", 
                b"RED", b"GREEN", b"BLUE", b"IR", b"ILLUM"]
for s in lamp_strings:
    idx = 0
    while True:
        idx = fw.find(s, idx)
        if idx == -1:
            break
        # Context
        start = max(0, idx - 4)
        end = min(len(fw), idx + 40)
        context = fw[start:end]
        null_pos = context.find(b'\x00', idx - start)
        if null_pos > 0:
            full = context[idx-start:null_pos]
        else:
            full = context[idx-start:idx-start+len(s)+16]
        printable = ''.join(chr(b) if 32 <= b < 127 else '.' for b in full)
        print(f"  '{s.decode()}' at 0x{idx:05X}: \"{printable}\"")
        idx += 1

# Look for port writes that might control LEDs
# Port 1-9, A, B data registers
port_writes = defaultdict(list)
for i in range(len(fw) - 5):
    if fw[i] == 0x6A and (fw[i+1] & 0xF0) == 0xA0:
        addr = (fw[i+2] << 16) | (fw[i+3] << 8) | fw[i+4]
        if 0xFFFFE0 <= addr <= 0xFFFFEA:
            port_writes[addr].append(i)
    # Also check 16-bit addressing
    if fw[i] == 0x6A and (fw[i+1] & 0xF0) == 0x80:
        addr16 = (fw[i+2] << 8) | fw[i+3]
        if addr16 >= 0xFFE0 and addr16 <= 0xFFEA:
            full_addr = 0xFFFF00 + (addr16 & 0xFF)
            port_writes[full_addr].append(i)

port_names = {
    0xFFFFE0: "P1DR", 0xFFFFE1: "P2DR", 0xFFFFE2: "P3DR", 0xFFFFE3: "P4DR",
    0xFFFFE4: "P5DR", 0xFFFFE5: "P6DR", 0xFFFFE6: "P7DR", 0xFFFFE7: "P8DR",
    0xFFFFE8: "P9DR", 0xFFFFE9: "PADR", 0xFFFFEA: "PBDR",
}
print("\n--- Port data register writes (potential LED/lamp control) ---")
for addr in sorted(port_writes.keys()):
    name = port_names.get(addr, "???")
    sites = port_writes[addr]
    print(f"  {name} (0x{addr:06X}): {len(sites)} write sites")
    for s in sites[:15]:
        print(f"    0x{s:05X}")

# Also check BSET/BCLR instructions on ports (bit manipulation)
# BSET #imm, @aa:8 -> 7F xx 70 bb  (set bit bb at address 0xFFxx00+xx)
# BCLR #imm, @aa:8 -> 7F xx 72 bb  (clear bit bb at address 0xFFxx00+xx)
print("\n--- BSET/BCLR on port/control registers ---")
for i in range(len(fw) - 4):
    if fw[i] == 0x7F:
        ioaddr = 0xFFFF00 + fw[i+1]
        if fw[i+2] == 0x70:  # BSET
            bit = (fw[i+3] >> 4) & 0x07
            name = port_names.get(ioaddr, h8_regs.get(ioaddr, f"0x{ioaddr:06X}"))
            if ioaddr in port_names or ioaddr in [0xFFFF60]:  # ports and TSTR
                print(f"  0x{i:05X}: BSET #{bit}, {name}")
        elif fw[i+2] == 0x72:  # BCLR
            bit = (fw[i+3] >> 4) & 0x07
            name = port_names.get(ioaddr, h8_regs.get(ioaddr, f"0x{ioaddr:06X}"))
            if ioaddr in port_names or ioaddr in [0xFFFF60]:
                print(f"  0x{i:05X}: BCLR #{bit}, {name}")


# Summary statistics
print("\n" + "="*80)
print("SUMMARY STATISTICS")
print("="*80)
print(f"ASIC registers (direct access):     {len(asic_accesses)} unique addresses")
print(f"ASIC registers (indirect via load):  {len(asic_addr_loads)} unique addresses")
print(f"ASIC RAM addresses:                  {len(asic_ram_accesses) + len(asic_ram_addr_loads)} unique addresses")
print(f"Buffer RAM addresses:                {len(buffer_ram_accesses) + len(buffer_ram_addr_loads)} unique addresses")
print(f"ISP1581 addresses:                   {len(isp1581_accesses) + len(isp1581_addr_loads)} unique addresses")
print(f"I/O init table entries:              {entry_count}")

