#!/usr/bin/env python3
"""
Find all SCSI sense code writes in the Nikon LS-50 firmware.

The firmware stores the current SCSI sense code at RAM address 0x4007B0 (2 bytes).
This script searches for:
1. All references to address 0x4007B0 in the instruction stream
2. Common H8/300H patterns for loading this address into a register
3. Immediate sense code values near those references
4. Tables of sense data

H8/300H instruction encoding notes (big-endian):
- mov.l #imm32, ERn: 0x7A 0x0n 0xHH 0xHH 0xLL 0xLL (6 bytes)
  where n = register number (0-7)
  The 32-bit immediate follows as HH HH LL LL
  For address 0x004007B0: bytes would be 0x7A 0x0n 0x00 0x40 0x07 0xB0

- mov.w #imm16, Rn: 0x79 0x0n 0xHH 0xLL (4 bytes)

- mov.w Rn, @ERm: 0x69 (8m+n) (2 bytes) - writes Rn word to address in ERm

- mov.w Rn, @(d:16,ERm): 0x6F (8m+n) dd dd (4 bytes) - writes with 16-bit displacement

- mov.b #imm8, Rn: 0xF0+n imm8 (2 bytes)

- mov.w #imm16, @aa:16: absolute address write (various encodings)

The main firmware code is at 0x20000-0x52FFF in the binary.
The shared handler module is at 0x10000-0x17FFF.
"""

import struct
import sys
from pathlib import Path
from collections import defaultdict

FIRMWARE_PATH = Path(__file__).parent.parent.parent / "binaries" / "firmware" / "Nikon LS-50 MBM29F400B TSOP48.bin"

# Known SCSI handler address ranges from the dispatch table
HANDLER_RANGES = {
    "TEST_UNIT_READY (0x00)":    (0x0215C2, 0x021866),
    "REQUEST_SENSE (0x03)":      (0x021866, 0x02194A),
    "MODE_SELECT (0x15)":        (0x02194A, 0x021E3E),
    "RESERVE (0x16)":            (0x021E3E, 0x021EA0),
    "RELEASE (0x17)":            (0x021EA0, 0x021F1C),
    "MODE_SENSE (0x1A)":         (0x021F1C, 0x0220B8),
    "SCAN (0x1B)":               (0x0220B8, 0x023856),
    "RECEIVE_DIAGNOSTIC (0x1C)": (0x023856, 0x023D32),
    "SEND_DIAGNOSTIC (0x1D)":    (0x023D32, 0x023F10),
    "SET_WINDOW (0x24)":         (0x026E38, 0x0272F6),
    "GET_WINDOW (0x25)":         (0x0272F6, 0x02837C),
    "READ (0x28)":               (0x023F10, 0x025506),
    "SEND (0x2A)":               (0x025506, 0x025E18),
    "INQUIRY (0x12)":            (0x025E18, 0x026E38),
    "WRITE_BUFFER (0x3B)":       (0x02837C, 0x028884),
    "READ_BUFFER (0x3C)":        (0x028884, 0x028AB4),
    "VENDOR_C0 (0xC0)":          (0x028AB4, 0x028B08),
    "VENDOR_C1 (0xC1)":          (0x028B08, 0x028E16),
    "VENDOR_E0 (0xE0)":          (0x028E16, 0x0295EA),
    "VENDOR_E1 (0xE1)":          (0x0295EA, 0x02A000),
    "DISPATCH_CORE":             (0x020B00, 0x0215C2),
    "D0_PHASE_QUERY":            (0x013748, 0x014100),
    "SHARED_MODULE":             (0x010000, 0x017FFF),
}

# Target address bytes
SENSE_ADDR = 0x004007B0
SENSE_ADDR_BYTES = bytes([0x00, 0x40, 0x07, 0xB0])
SENSE_ADDR_HI = bytes([0x00, 0x40])  # high 16 bits
SENSE_ADDR_LO = bytes([0x07, 0xB0])  # low 16 bits

# Also search for 0x4007B1 (the second byte of the sense word)
SENSE_ADDR_B1 = bytes([0x00, 0x40, 0x07, 0xB1])

# Address without leading zero (24-bit in some contexts: 0x40, 0x07, 0xB0)
SENSE_ADDR_24 = bytes([0x40, 0x07, 0xB0])


def addr_to_handler(addr):
    """Map a firmware address to its containing SCSI handler."""
    for name, (start, end) in HANDLER_RANGES.items():
        if start <= addr < end:
            return name
    return f"UNKNOWN (0x{addr:06X})"


def find_all_occurrences(data, pattern):
    """Find all occurrences of a byte pattern in data."""
    results = []
    start = 0
    while True:
        idx = data.find(pattern, start)
        if idx == -1:
            break
        results.append(idx)
        start = idx + 1
    return results


def hexdump_context(data, offset, before=8, after=16):
    """Return a hex dump of bytes around an offset."""
    start = max(0, offset - before)
    end = min(len(data), offset + after)

    lines = []
    for i in range(start, end, 16):
        chunk = data[i:min(i+16, end)]
        hex_part = ' '.join(f'{b:02X}' for b in chunk)
        # Mark the target bytes
        ascii_part = ''.join(chr(b) if 32 <= b < 127 else '.' for b in chunk)
        lines.append(f"  0x{i:06X}: {hex_part:<48s} {ascii_part}")
    return '\n'.join(lines)


def analyze_mov_l_context(data, offset):
    """Analyze a mov.l #imm32, ERn instruction at the given offset.

    Format: 7A 0n HH HH LL LL
    Returns (register, imm32) or None if not a valid mov.l instruction.
    """
    if offset < 0 or offset + 6 > len(data):
        return None

    b0, b1 = data[offset], data[offset + 1]
    if b0 == 0x7A and (b1 & 0xF0) == 0x00:
        reg = b1 & 0x0F
        if reg <= 7:
            imm32 = struct.unpack('>I', data[offset+2:offset+6])[0]
            return (reg, imm32)
    return None


def scan_for_address_loads(data):
    """Find all mov.l instructions that load address 0x004007B0 into a register."""
    results = []

    # Pattern 1: mov.l #0x004007B0, ERn  ->  7A 0n 00 40 07 B0
    for n in range(8):
        pattern = bytes([0x7A, 0x00 | n]) + SENSE_ADDR_BYTES
        for offset in find_all_occurrences(data, pattern):
            results.append({
                'offset': offset,
                'flash_addr': offset,
                'type': f'mov.l #0x{SENSE_ADDR:08X}, ER{n}',
                'register': f'ER{n}',
                'instruction_len': 6,
            })

    # Pattern 1b: mov.l #0x004007B1, ERn  ->  7A 0n 00 40 07 B1
    addr_b1 = bytes([0x00, 0x40, 0x07, 0xB1])
    for n in range(8):
        pattern = bytes([0x7A, 0x00 | n]) + addr_b1
        for offset in find_all_occurrences(data, pattern):
            results.append({
                'offset': offset,
                'flash_addr': offset,
                'type': f'mov.l #0x004007B1, ER{n}',
                'register': f'ER{n}',
                'instruction_len': 6,
            })

    # Pattern 2: mov.l #0x004007AE/AF/B2/etc., ERn (nearby addresses)
    # Check for addresses within +/-16 of 0x4007B0
    for delta in range(-32, 33):
        if delta == 0 or delta == 1:  # Already covered above
            continue
        nearby_addr = SENSE_ADDR + delta
        nearby_bytes = struct.pack('>I', nearby_addr)
        for n in range(8):
            pattern = bytes([0x7A, 0x00 | n]) + nearby_bytes
            for offset in find_all_occurrences(data, pattern):
                results.append({
                    'offset': offset,
                    'flash_addr': offset,
                    'type': f'mov.l #0x{nearby_addr:08X}, ER{n} (sense_addr+{delta:+d})',
                    'register': f'ER{n}',
                    'instruction_len': 6,
                })

    return results


def scan_for_raw_address_bytes(data):
    """Find raw occurrences of the address bytes (not necessarily in mov.l instructions)."""
    results = []

    # Full 32-bit address
    for offset in find_all_occurrences(data, SENSE_ADDR_BYTES):
        results.append({
            'offset': offset,
            'flash_addr': offset,
            'type': 'raw_32bit',
            'bytes': '00 40 07 B0',
        })

    # 24-bit address (without leading zero)
    for offset in find_all_occurrences(data, SENSE_ADDR_24):
        # Verify it's not already captured as 32-bit
        if offset > 0 and data[offset-1] == 0x00:
            continue  # Already captured as 32-bit
        results.append({
            'offset': offset,
            'flash_addr': offset,
            'type': 'raw_24bit',
            'bytes': '40 07 B0',
        })

    return results


def scan_for_sense_values(data):
    """Find immediate values that look like SCSI sense codes being loaded.

    The firmware writes a 16-bit sense code to 0x4007B0.
    From the existing KB, the format appears to be a custom encoding:
      - 0x0007 = HARDWARE ERROR
      - 0x0008 = COMMUNICATION FAILURE
      - 0x0050 = ILLEGAL REQUEST
      etc.

    Search for mov.w #imm16 instructions with these values.
    """
    results = []

    # Known sense codes from existing KB
    known_codes = {
        0x0007: "HARDWARE ERROR",
        0x0008: "COMMUNICATION FAILURE",
        0x0009: "TRACK FOLLOWING ERROR",
        0x000A: "READ ERROR",
        0x000D: "MEDIUM REMOVAL REQUEST",
        0x0050: "ILLEGAL REQUEST",
        0x0053: "INVALID PARAMETER",
        0x0059: "INVALID MODE PARAMETER",
        0x0071: "SCAN TIMEOUT",
        0x0079: "MOTOR BUSY",
        0x007A: "CALIBRATION BUSY",
    }

    # Standard SCSI sense key values (as 16-bit with high byte = sense key)
    scsi_sense_keys = {
        0x0200: "NOT READY",
        0x0300: "MEDIUM ERROR",
        0x0400: "HARDWARE ERROR",
        0x0500: "ILLEGAL REQUEST",
        0x0600: "UNIT ATTENTION",
        0x0B00: "ABORTED COMMAND",
    }

    # Common ASC/ASCQ pairs
    asc_ascq = {
        0x0400: "NOT READY, CAUSE NOT REPORTABLE",
        0x0401: "NOT READY, IN PROCESS OF BECOMING READY",
        0x0402: "NOT READY, INITIALIZING CMD REQUIRED",
        0x0404: "NOT READY, FORMAT IN PROGRESS",
        0x2000: "INVALID COMMAND OPERATION CODE",
        0x2400: "INVALID FIELD IN CDB",
        0x2500: "LUN NOT SUPPORTED",
        0x2600: "INVALID FIELD IN PARAMETER LIST",
        0x2900: "POWER ON, RESET, OR BUS DEVICE RESET",
        0x2C00: "COMMAND SEQUENCE ERROR",
        0x3A00: "MEDIUM NOT PRESENT",
        0x4400: "INTERNAL TARGET FAILURE",
        0x4700: "SCSI PARITY ERROR",
        0x4900: "INVALID MESSAGE ERROR",
    }

    # Search for mov.w #imm16, Rn: 79 0n HH LL
    # We search in the code regions only (0x10000-0x17FFF and 0x20000-0x52FFF)
    code_regions = [(0x10000, 0x17FFF), (0x20000, 0x52FFF)]

    all_values = {}
    all_values.update(known_codes)
    all_values.update(scsi_sense_keys)
    all_values.update(asc_ascq)

    for value, name in all_values.items():
        hi = (value >> 8) & 0xFF
        lo = value & 0xFF

        for reg in range(8):
            # mov.w #imm16, Rn: 79 0n HH LL
            pattern = bytes([0x79, 0x00 | reg, hi, lo])
            for offset in find_all_occurrences(data, pattern):
                # Check if in code region
                in_code = any(s <= offset <= e for s, e in code_regions)
                if in_code:
                    results.append({
                        'offset': offset,
                        'flash_addr': offset,
                        'type': f'mov.w #0x{value:04X}, R{reg}',
                        'value': value,
                        'name': name,
                        'handler': addr_to_handler(offset),
                    })

        # Also search for mov.w #imm16, Rn with extended encoding:
        # 79 1n HH LL (for En registers - extended)
        # Actually on H8/300H, mov.w #xx:16, Rn uses 79 0n only

    # Search for sub.w Rn,Rn (zeroing) near sense address loads
    # sub.w R0,R0 = 0x1900 (clears sense code = no error)
    # This is how sense_code = 0x0000 (NO SENSE) is typically set

    return results


def scan_for_sense_byte_writes(data):
    """Search for mov.b #imm8 patterns that write sense key bytes.

    mov.b #imm8, Rn: F0+n imm8

    If a register points to 0x4007B0, a mov.b #SK, Rnh would write the sense key.
    """
    results = []

    # Sense key values as byte immediates
    sense_keys = {
        0x00: "NO SENSE",
        0x02: "NOT READY",
        0x03: "MEDIUM ERROR",
        0x04: "HARDWARE ERROR",
        0x05: "ILLEGAL REQUEST",
        0x06: "UNIT ATTENTION",
        0x0B: "ABORTED COMMAND",
    }

    code_regions = [(0x10000, 0x17FFF), (0x20000, 0x52FFF)]

    for value, name in sense_keys.items():
        if value == 0x00:
            continue  # Too common, skip zero
        for reg in range(16):  # r0h-r7h, r0l-r7l
            # mov.b #imm8, Rn: F(reg) val
            pattern = bytes([0xF0 | reg, value])
            for offset in find_all_occurrences(data, pattern):
                in_code = any(s <= offset <= e for s, e in code_regions)
                if in_code:
                    # Check if near a sense address load (within 32 bytes)
                    near_sense = False
                    for delta in range(-48, 49):
                        check = offset + delta
                        if 0 <= check + 4 <= len(data):
                            if data[check:check+4] == SENSE_ADDR_BYTES[0:4]:
                                near_sense = True
                                break
                    results.append({
                        'offset': offset,
                        'flash_addr': offset,
                        'type': f'mov.b #0x{value:02X}, R{reg >> 3}{"h" if reg < 8 else "l"}{"" if reg < 8 else ""}',
                        'value': value,
                        'name': name,
                        'near_sense_addr': near_sense,
                        'handler': addr_to_handler(offset),
                    })

    return results


def scan_for_word_writes_to_absolute(data):
    """Search for mov.w patterns that write to absolute addresses near 0x4007B0.

    H8/300H absolute address write:
    mov.w Rn, @aa:16 — 6B 8n aa aa  (16-bit abs, but only 0x0000-0xFFFF)
    mov.w Rn, @aa:24 — 6B An xx xx xx  (24-bit abs)

    Since 0x4007B0 > 0xFFFF, we need the 24-bit form:
    6B A(n) 00 40 07 B0
    But actually in H8/300H the encoding for @aa:32 (or @aa:24 in 24-bit mode) is:
    6B 2n 00 00 (mod reg) followed by address bytes

    Let me search for the address bytes more broadly.
    """
    results = []

    code_regions = [(0x10000, 0x17FFF), (0x20000, 0x52FFF)]

    # Pattern: any instruction followed by 0x004007B0 or 0x4007B0 address
    # H8/300H mov.w Rn, @(d:32, ERm): complex encoding
    # Let's just find all occurrences of the address bytes in code regions

    for start, end in code_regions:
        for offset in range(start, min(end, len(data) - 4)):
            # Check for 3-byte address: 40 07 B0
            if data[offset] == 0x40 and data[offset+1] == 0x07 and data[offset+2] == 0xB0:
                # Avoid duplicates with 4-byte pattern
                if offset > 0 and data[offset-1] == 0x00:
                    pass  # Will be found by 4-byte search
                else:
                    results.append({
                        'offset': offset,
                        'flash_addr': offset,
                        'type': 'addr_3byte_in_code',
                    })

    return results


def scan_for_mov_w_to_register_indirect(data, sense_addr_offsets):
    """Near sense address loads, find mov.w instructions that write through the register.

    After "mov.l #0x4007B0, ERn", look for:
    - mov.w Rm, @ERn  (69 8n+m) — write through register
    - mov.w #imm16, @ERn (no direct encoding — H8 uses register load then write)

    Also look for what immediate values are loaded into registers nearby.
    """
    results = []

    for addr_info in sense_addr_offsets:
        offset = addr_info['offset']
        reg_str = addr_info.get('register', '')
        if not reg_str.startswith('ER'):
            continue
        ern = int(reg_str[2])

        # Scan forward up to 64 bytes for writes through this register
        for delta in range(6, 128, 2):  # Start after the mov.l instruction
            pos = offset + delta
            if pos + 2 > len(data):
                break

            b0, b1 = data[pos], data[pos + 1]

            # mov.w Rm, @ERn: 69 (8n | m)  where n=base reg, m=source reg (0-7)
            if b0 == 0x69 and (b1 >> 4) == (0x8 | ern):
                src_reg = b1 & 0x07
                results.append({
                    'offset': pos,
                    'flash_addr': pos,
                    'type': f'mov.w R{src_reg}, @ER{ern}',
                    'via_addr_load_at': offset,
                    'handler': addr_to_handler(pos),
                })

            # mov.w Rm, @(d:16, ERn): 6F (8n | m) dd dd
            if b0 == 0x6F and (b1 >> 4) == (0x8 | ern):
                src_reg = b1 & 0x07
                if pos + 4 <= len(data):
                    disp = struct.unpack('>h', data[pos+2:pos+4])[0]  # signed 16-bit
                    target_addr = 0x4007B0 + disp
                    results.append({
                        'offset': pos,
                        'flash_addr': pos,
                        'type': f'mov.w R{src_reg}, @(0x{disp & 0xFFFF:04X}, ER{ern}) -> 0x{target_addr:06X}',
                        'via_addr_load_at': offset,
                        'handler': addr_to_handler(pos),
                        'target_addr': target_addr,
                    })

            # mov.b Rm, @ERn: 68 (8n | m)
            if b0 == 0x68 and (b1 >> 4) == (0x8 | ern):
                src_reg = b1 & 0x0F
                reg_name = f'R{src_reg >> 1}{"h" if (src_reg & 1) == 0 else "l"}'
                results.append({
                    'offset': pos,
                    'flash_addr': pos,
                    'type': f'mov.b {reg_name}, @ER{ern}',
                    'via_addr_load_at': offset,
                    'handler': addr_to_handler(pos),
                })

            # Stop scanning if we hit rts (0x5470) or jmp/jsr
            if b0 == 0x54 and b1 == 0x70:  # rts
                break

    return results


def scan_for_immediate_loads_near_sense(data, sense_addr_offsets):
    """Find mov.w #imm16, Rn instructions near sense address loads.

    These are likely the sense code values being prepared for writing.
    """
    results = []

    for addr_info in sense_addr_offsets:
        offset = addr_info['offset']

        # Scan in a window around the address load
        for delta in range(-32, 128, 2):
            pos = offset + delta
            if pos < 0 or pos + 4 > len(data):
                continue

            b0, b1 = data[pos], data[pos + 1]

            # mov.w #imm16, Rn: 79 0n HH LL
            if b0 == 0x79 and (b1 & 0xF0) == 0x00:
                reg = b1 & 0x0F
                if reg <= 7:
                    imm16 = struct.unpack('>H', data[pos+2:pos+4])[0]
                    # Only report non-trivial values
                    if imm16 != 0x0000 and imm16 < 0x1000:  # Likely sense codes are small
                        results.append({
                            'offset': pos,
                            'flash_addr': pos,
                            'type': f'mov.w #0x{imm16:04X}, R{reg}',
                            'value': imm16,
                            'near_addr_load': offset,
                            'handler': addr_to_handler(pos),
                        })

            # sub.w Rn, Rn (zeroing a register): 19 nn (where both nibbles = same reg)
            if b0 == 0x19 and ((b1 >> 4) == (b1 & 0x0F)):
                reg = b1 & 0x0F
                results.append({
                    'offset': pos,
                    'flash_addr': pos,
                    'type': f'sub.w R{reg}, R{reg} (=0x0000, NO SENSE)',
                    'value': 0x0000,
                    'near_addr_load': offset,
                    'handler': addr_to_handler(pos),
                })

    return results


def main():
    print("=" * 80)
    print("Nikon LS-50 Firmware SCSI Sense Code Analysis")
    print("=" * 80)

    data = FIRMWARE_PATH.read_bytes()
    print(f"\nFirmware size: {len(data)} bytes ({len(data) / 1024:.0f} KB)")
    print(f"Target address: 0x{SENSE_ADDR:08X} (SCSI sense code, 2 bytes)")

    # ========================================================================
    # PHASE 1: Find all references to address 0x4007B0
    # ========================================================================
    print("\n" + "=" * 80)
    print("PHASE 1: Address Load Instructions (mov.l #0x004007B0, ERn)")
    print("=" * 80)

    addr_loads = scan_for_address_loads(data)

    # Group by exact address
    exact_loads = [r for r in addr_loads if '004007B' in r['type']]
    nearby_loads = [r for r in addr_loads if '+' in r['type'] or '-' in r['type']]

    print(f"\nFound {len(exact_loads)} direct loads of sense address:")
    for r in sorted(exact_loads, key=lambda x: x['offset']):
        handler = addr_to_handler(r['offset'])
        print(f"  0x{r['offset']:06X}: {r['type']}")
        print(f"           Handler: {handler}")
        print(f"           Context:")
        print(hexdump_context(data, r['offset'], before=4, after=24))
        print()

    if nearby_loads:
        print(f"\nFound {len(nearby_loads)} loads of nearby addresses:")
        for r in sorted(nearby_loads, key=lambda x: x['offset']):
            handler = addr_to_handler(r['offset'])
            print(f"  0x{r['offset']:06X}: {r['type']}")
            print(f"           Handler: {handler}")

    # ========================================================================
    # PHASE 2: Raw address bytes in code regions
    # ========================================================================
    print("\n" + "=" * 80)
    print("PHASE 2: Raw Address Byte Occurrences (00 40 07 B0)")
    print("=" * 80)

    raw_refs = find_all_occurrences(data, SENSE_ADDR_BYTES)
    print(f"\nFound {len(raw_refs)} occurrences of bytes 00 40 07 B0:")
    for offset in raw_refs:
        handler = addr_to_handler(offset)
        # Check if this is part of a mov.l instruction
        is_movl = False
        if offset >= 2:
            if data[offset-2] == 0x7A and (data[offset-1] & 0xF0) == 0x00:
                is_movl = True

        marker = " [mov.l]" if is_movl else ""
        print(f"  0x{offset:06X}: {handler}{marker}")

    # Also search for 0x4007B1
    raw_refs_b1 = find_all_occurrences(data, SENSE_ADDR_B1)
    if raw_refs_b1:
        print(f"\nFound {len(raw_refs_b1)} occurrences of bytes 00 40 07 B1:")
        for offset in raw_refs_b1:
            handler = addr_to_handler(offset)
            print(f"  0x{offset:06X}: {handler}")

    # ========================================================================
    # PHASE 3: Writes through sense address register
    # ========================================================================
    print("\n" + "=" * 80)
    print("PHASE 3: Write Instructions Near Sense Address Loads")
    print("=" * 80)

    write_refs = scan_for_mov_w_to_register_indirect(data, exact_loads)
    print(f"\nFound {len(write_refs)} write-through-register instructions:")
    for r in sorted(write_refs, key=lambda x: x['offset']):
        print(f"  0x{r['offset']:06X}: {r['type']}")
        print(f"           Handler: {r['handler']}")
        print(f"           (addr loaded at 0x{r['via_addr_load_at']:06X})")

    # ========================================================================
    # PHASE 4: Immediate values near sense address loads
    # ========================================================================
    print("\n" + "=" * 80)
    print("PHASE 4: Immediate Values Near Sense Address Loads (likely sense codes)")
    print("=" * 80)

    imm_near = scan_for_immediate_loads_near_sense(data, exact_loads)

    # Deduplicate
    seen = set()
    unique_imm = []
    for r in imm_near:
        key = (r['offset'], r['value'])
        if key not in seen:
            seen.add(key)
            unique_imm.append(r)

    # Sort by value then offset
    unique_imm.sort(key=lambda x: (x['value'], x['offset']))

    # Group by value
    by_value = defaultdict(list)
    for r in unique_imm:
        by_value[r['value']].append(r)

    print(f"\nFound {len(unique_imm)} immediate value loads near sense address loads:")
    print(f"Unique values: {len(by_value)}")

    for value in sorted(by_value.keys()):
        refs = by_value[value]
        known_name = ""
        known_codes = {
            0x0000: "NO SENSE (clear)",
            0x0007: "HARDWARE ERROR",
            0x0008: "COMMUNICATION FAILURE",
            0x0009: "TRACK FOLLOWING ERROR",
            0x000A: "READ ERROR",
            0x000D: "MEDIUM REMOVAL REQUEST",
            0x0050: "ILLEGAL REQUEST",
            0x0053: "INVALID PARAMETER",
            0x0059: "INVALID MODE PARAMETER",
            0x0071: "SCAN TIMEOUT",
            0x0079: "MOTOR BUSY",
            0x007A: "CALIBRATION BUSY",
        }
        if value in known_codes:
            known_name = f" [{known_codes[value]}]"

        print(f"\n  Value 0x{value:04X}{known_name}:")
        for r in refs:
            print(f"    0x{r['offset']:06X}: {r['type']} -- {r['handler']}")

    # ========================================================================
    # PHASE 5: Known SCSI sense code patterns
    # ========================================================================
    print("\n" + "=" * 80)
    print("PHASE 5: Known SCSI Sense Code Immediate Values in Code")
    print("=" * 80)

    sense_vals = scan_for_sense_values(data)

    # Group by value
    by_value2 = defaultdict(list)
    for r in sense_vals:
        by_value2[r['value']].append(r)

    print(f"\nFound {len(sense_vals)} known sense code immediates in code regions:")
    for value in sorted(by_value2.keys()):
        refs = by_value2[value]
        print(f"\n  0x{value:04X} ({refs[0]['name']}):")
        for r in refs:
            print(f"    0x{r['offset']:06X}: {r['type']} -- {r['handler']}")

    # ========================================================================
    # PHASE 6: Scan for sense code table patterns
    # ========================================================================
    print("\n" + "=" * 80)
    print("PHASE 6: Search for Sense Code Tables")
    print("=" * 80)

    # Look for sequences of sense-like values in the data tables region (0x45000-0x528BE)
    table_region = data[0x45000:0x52900]

    print("\nSearching data tables (0x45000-0x528FF) for sense-like value sequences...")

    for i in range(0, len(table_region) - 4, 2):
        w1 = struct.unpack('>H', table_region[i:i+2])[0]
        w2 = struct.unpack('>H', table_region[i+2:i+4])[0]

        # Look for pairs of values that both look like sense codes
        def is_sense_like(v):
            return 0 < v < 0x0100 or v in (0x0050, 0x0053, 0x0059, 0x0071, 0x0079, 0x007A)

        if is_sense_like(w1) and is_sense_like(w2):
            addr = 0x45000 + i
            # Check context - are there more?
            count = 0
            for j in range(0, min(20, len(table_region) - i), 2):
                wj = struct.unpack('>H', table_region[i+j:i+j+2])[0]
                if is_sense_like(wj):
                    count += 1
                else:
                    break
            if count >= 3:
                print(f"  Possible sense table at 0x{addr:06X} ({count} entries):")
                for j in range(count):
                    wj = struct.unpack('>H', table_region[i+j*2:i+j*2+2])[0]
                    print(f"    0x{addr+j*2:06X}: 0x{wj:04X}")
                print()

    # ========================================================================
    # PHASE 7: Deep analysis of REQUEST SENSE handler
    # ========================================================================
    print("\n" + "=" * 80)
    print("PHASE 7: REQUEST SENSE Handler (0x021866) — Sense Data Format")
    print("=" * 80)

    # The REQUEST SENSE handler reads from 0x4007B0 and builds the response
    rs_start = 0x021866
    rs_end = min(0x02194A, len(data))
    if rs_start < len(data):
        print(f"\nREQUEST SENSE handler hex dump (0x{rs_start:06X}-0x{rs_end:06X}):")
        for i in range(rs_start, rs_end, 16):
            chunk = data[i:min(i+16, rs_end)]
            hex_part = ' '.join(f'{b:02X}' for b in chunk)
            ascii_part = ''.join(chr(b) if 32 <= b < 127 else '.' for b in chunk)
            print(f"  0x{i:06X}: {hex_part:<48s} {ascii_part}")

    # ========================================================================
    # PHASE 8: Comprehensive sense code value analysis
    # ========================================================================
    print("\n" + "=" * 80)
    print("PHASE 8: Comprehensive — All mov.w #imm16 in sense-writing functions")
    print("=" * 80)

    # For each handler that loads the sense address, find ALL mov.w #imm16 instructions
    # within that handler's address range

    handlers_with_sense = set()
    for r in exact_loads:
        handler = addr_to_handler(r['offset'])
        if handler != "UNKNOWN":
            handlers_with_sense.add(handler)

    print(f"\nHandlers that reference sense address: {len(handlers_with_sense)}")
    for h in sorted(handlers_with_sense):
        print(f"  - {h}")

    # For each handler, scan for all mov.w #imm16 instructions
    for handler_name in sorted(handlers_with_sense):
        if handler_name not in HANDLER_RANGES:
            continue
        start, end = HANDLER_RANGES[handler_name]
        if start >= len(data) or end > len(data):
            continue

        print(f"\n  --- {handler_name} (0x{start:06X}-0x{end:06X}) ---")

        for pos in range(start, end - 4, 2):
            b0, b1 = data[pos], data[pos + 1]

            # mov.w #imm16, Rn: 79 0n HH LL
            if b0 == 0x79 and (b1 & 0xF0) == 0x00:
                reg = b1 & 0x0F
                if reg <= 7:
                    imm16 = struct.unpack('>H', data[pos+2:pos+4])[0]
                    if imm16 != 0 and imm16 < 0x0200:  # Likely sense code range
                        print(f"    0x{pos:06X}: mov.w #0x{imm16:04X}, R{reg}")

    # ========================================================================
    # SUMMARY
    # ========================================================================
    print("\n" + "=" * 80)
    print("SUMMARY: All Discovered Sense Codes")
    print("=" * 80)

    # Collect all unique sense code values
    all_codes = set()

    for r in unique_imm:
        all_codes.add(r['value'])

    for r in sense_vals:
        all_codes.add(r['value'])

    known_codes_full = {
        0x0000: "NO SENSE (clear error state)",
        0x0007: "HARDWARE ERROR",
        0x0008: "COMMUNICATION FAILURE",
        0x0009: "TRACK FOLLOWING ERROR",
        0x000A: "READ ERROR",
        0x000D: "MEDIUM REMOVAL REQUEST",
        0x0050: "ILLEGAL REQUEST (invalid CDB field)",
        0x0053: "INVALID PARAMETER",
        0x0059: "INVALID MODE PARAMETER",
        0x0071: "SCAN TIMEOUT",
        0x0079: "MOTOR BUSY",
        0x007A: "CALIBRATION BUSY",
    }

    print(f"\nTotal unique sense code values found: {len(all_codes)}")
    print("\n{:<8s} {:<40s} {:<s}".format("Code", "Name", "Locations"))
    print("-" * 80)

    for code in sorted(all_codes):
        name = known_codes_full.get(code, "???")

        # Find all locations
        locations = set()
        for r in unique_imm:
            if r['value'] == code:
                locations.add(r['handler'])
        for r in sense_vals:
            if r['value'] == code:
                locations.add(r['handler'])

        loc_str = ", ".join(sorted(locations)[:3])
        if len(locations) > 3:
            loc_str += f" (+{len(locations)-3} more)"

        print(f"0x{code:04X}   {name:<40s} {loc_str}")


if __name__ == "__main__":
    main()
