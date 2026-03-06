#!/usr/bin/env python3
"""
Trace exactly which sense code values are written to 0x4007B0 in the LS-50 firmware.

Strategy:
1. Find every mov.l #0x004007B0, ERn instruction
2. At each site, look backward and forward for the value being written
3. Trace the actual mov.w Rm, @ERn or mov.b Rm, @ERn that stores through that register
4. Find what immediate was loaded into Rm before the store

Also decode the custom sense code format by analyzing the REQUEST SENSE handler.
"""

import struct
from pathlib import Path
from collections import defaultdict

FIRMWARE_PATH = Path(__file__).parent.parent.parent / "binaries" / "firmware" / "Nikon LS-50 MBM29F400B TSOP48.bin"

HANDLER_RANGES = {
    "DISPATCH (pre-handler)":    (0x020B00, 0x0215C2),
    "TEST_UNIT_READY (0x00)":    (0x0215C2, 0x021866),
    "REQUEST_SENSE (0x03)":      (0x021866, 0x02194A),
    "MODE_SELECT (0x15)":        (0x02194A, 0x021E3E),
    "RESERVE (0x16)":            (0x021E3E, 0x021EA0),
    "RELEASE (0x17)":            (0x021EA0, 0x021F1C),
    "MODE_SENSE (0x1A)":         (0x021F1C, 0x0220B8),
    "SCAN (0x1B)":               (0x0220B8, 0x023856),
    "RECV_DIAG (0x1C)":          (0x023856, 0x023D32),
    "SEND_DIAG (0x1D)":          (0x023D32, 0x023F10),
    "READ (0x28)":               (0x023F10, 0x025506),
    "SET_WINDOW (0x24)":         (0x026E38, 0x0272F6),
    "GET_WINDOW (0x25)":         (0x0272F6, 0x02837C),
    "SEND (0x2A)":               (0x025506, 0x025E18),
    "INQUIRY (0x12)":            (0x025E18, 0x026E38),
    "WRITE_BUFFER (0x3B)":       (0x02837C, 0x028884),
    "READ_BUFFER (0x3C)":        (0x028884, 0x028AB4),
    "VENDOR_C0 (0xC0)":          (0x028AB4, 0x028B08),
    "VENDOR_C1 (0xC1)":          (0x028B08, 0x028E16),
    "VENDOR_E0 (0xE0)":          (0x028E16, 0x0295EA),
    "VENDOR_E1 (0xE1)":          (0x0295EA, 0x02A000),
    "D0_PHASE_QUERY":            (0x013748, 0x014100),
    "SHARED_MODULE":             (0x010000, 0x017FFF),
}

def addr_to_handler(addr):
    # Check specific handlers first (more precise ranges)
    best = None
    best_size = 0x100000
    for name, (start, end) in HANDLER_RANGES.items():
        if start <= addr < end:
            size = end - start
            if size < best_size:
                best = name
                best_size = size
    return best or f"UNKNOWN@0x{addr:06X}"


def find_all(data, pattern):
    results = []
    start = 0
    while True:
        idx = data.find(pattern, start)
        if idx == -1:
            break
        results.append(idx)
        start = idx + 1
    return results


def analyze_sense_write_site(data, addr_load_offset, target_reg):
    """Given a 'mov.l #0x4007B0, ERn' at addr_load_offset,
    find what values are written through ERn to the sense address.

    Returns list of (store_offset, value_loaded, source_description)
    """
    results = []
    ern = target_reg

    # Scan forward from the mov.l instruction
    # Look for:
    # 1. mov.w Rm, @ERn  -> 69 (0x80 | (ern << 4) | rm_word)
    #    Actually: mov.w Rs, @ERd -> 69 (Sd) where S = source reg hi nibble, d = dest_er reg
    #    Wait - H8 encoding: mov.w Rs, @ERd
    #    Opcode: 69 SD where S = source word reg (R0-R7), D = 0x80 | dest ER reg
    #    So mov.w R0, @ER5 = 69 (0 << 4 | 0x80 | 5) = 69 85
    #    Actually the encoding is: 69 XY where X = 8+dest_er, Y = source_reg
    #    No wait. Let me be precise:
    #    mov.w Rs, @ERd: 0x69, (0x80 | (d << 4) | s)  - NO
    #
    # H8/300H encoding for mov.w Rs, @ERd:
    #   Byte 0: 0x69
    #   Byte 1: (dest_er << 4) | source_reg, with bit 7 set for store direction
    #   So: 0x69, 0x80 | (dest_er << 4) | source_reg
    #   Example: mov.w R0, @ER5 = 0x69, 0x80 | 0x50 | 0x00 = 0x69, 0xD0
    #   Hmm that doesn't look right either.
    #
    # Let me check the actual H8/300H manual encoding:
    # mov.w Rs, @ERd:  0110 1001 1ddd ssss  where ddd=ERd, ssss=Rs
    # = 0x69, (0x80 | (d << 4 >> 1)...
    # Binary: 0110 1001  1 ddd ssss
    # Byte 1 = 1dddssss
    # For mov.w R0, @ER3: 0x69, 0b1_011_0000 = 0x69, 0xB0
    # For mov.w R0, @ER4: 0x69, 0b1_100_0000 = 0x69, 0xC0
    # For mov.w R0, @ER5: 0x69, 0b1_101_0000 = 0x69, 0xD0
    # For mov.w R0, @ER6: 0x69, 0b1_110_0000 = 0x69, 0xE0
    #
    # So the store byte = 0x80 | (dest_er << 4) | source_word_reg
    # But dest_er is 3 bits (0-7) packed into bits 6:4, source is 4 bits in 3:0
    # Wait: 1_ddd_ssss: d is 3 bits (bit6-4), s is 4 bits (bit3-0)
    # Hmm s should be 0-7 for R0-R7.

    # I'll use a more empirical approach: look at the bytes in context

    # From the hex dump we saw patterns like:
    # "6E 48 00 01" after loading ER4 with 0x4007B6 and ER5 with 0x4007B0
    # 6E = mov.b/mov.w with displacement?
    # 6E Rs, @(d:16, ERd): byte/word with 16-bit displacement
    #
    # Actually from my hex dump analysis:
    # At 0x011346: 6E 48 00 01 -> this is mov.b R4h, @(0x0001, ER4)
    # Wait no. 6E = mov.b with displacement. 6F = mov.w with displacement.
    #
    # Let me take a different approach and look for sub.w/mov.w patterns that are
    # followed by stores.

    # H8/300H key instruction encodings:
    # mov.w Rs, @ERd:         69 [1dddssss]  (2 bytes)
    # mov.w Rs, @(d:16,ERd):  6F [1dddssss] [disp16]  (4 bytes)
    # mov.b Rs, @ERd:         68 [1dddssss]  (2 bytes)
    # mov.b Rs, @(d:16,ERd):  6E [1dddssss] [disp16]  (4 bytes)

    # So for our target ER register:
    store_w_prefix = 0x80 | (ern << 4)  # 1ddd0000 base for word store to @ERn
    store_b_prefix = 0x80 | (ern << 4)  # same for byte

    for delta in range(6, 200, 2):
        pos = addr_load_offset + delta
        if pos + 4 > len(data):
            break

        b0, b1 = data[pos], data[pos + 1]

        # Check for mov.w Rs, @ERn (direct)
        if b0 == 0x69 and (b1 & 0xF0) == store_w_prefix and (b1 & 0x80):
            src_reg = b1 & 0x0F
            if src_reg <= 7:
                # Now trace back to find what was loaded into Rs
                val = trace_register_value(data, pos, src_reg, addr_load_offset)
                results.append({
                    'store_offset': pos,
                    'store_type': f'mov.w R{src_reg}, @ER{ern}',
                    'value': val,
                })

        # Check for mov.w Rs, @(d:16, ERn)
        if b0 == 0x6F and (b1 & 0xF0) == store_w_prefix and (b1 & 0x80):
            src_reg = b1 & 0x0F
            if src_reg <= 7 and pos + 4 <= len(data):
                disp = struct.unpack('>h', data[pos+2:pos+4])[0]
                if disp == 0:  # Same as @ERn essentially
                    val = trace_register_value(data, pos, src_reg, addr_load_offset)
                    results.append({
                        'store_offset': pos,
                        'store_type': f'mov.w R{src_reg}, @(0x{disp & 0xFFFF:04X}, ER{ern})',
                        'value': val,
                    })

        # Check for mov.b Rs, @ERn
        if b0 == 0x68 and (b1 & 0xF0) == store_w_prefix and (b1 & 0x80):
            src_reg_4bit = b1 & 0x0F
            val = trace_register_value_byte(data, pos, src_reg_4bit, addr_load_offset)
            reg_name = f'R{src_reg_4bit >> 1}{"h" if (src_reg_4bit & 1) == 0 else "l"}'
            results.append({
                'store_offset': pos,
                'store_type': f'mov.b {reg_name}, @ER{ern}',
                'value': val,
            })

        # Stop at function epilogue
        if b0 == 0x54 and b1 == 0x70:  # rts
            break
        # Stop at another mov.l that changes our register
        if b0 == 0x7A and (b1 & 0x0F) == ern:
            break

    return results


def trace_register_value(data, store_offset, word_reg, search_start):
    """Trace backward from store_offset to find what immediate value was loaded into word_reg (R0-R7).

    Returns the immediate value or a description string.
    """
    # Search backward for:
    # mov.w #imm16, Rn: 79 0n HH LL
    # sub.w Rn, Rn: 19 nn (zeroing)
    # mov.w Rm, Rn: 0D nm (register copy)

    for delta in range(2, 64, 2):
        pos = store_offset - delta
        if pos < search_start:
            break

        b0, b1 = data[pos], data[pos + 1]

        # mov.w #imm16, Rn
        if b0 == 0x79 and b1 == (0x00 | word_reg) and pos + 4 <= len(data):
            imm16 = struct.unpack('>H', data[pos+2:pos+4])[0]
            return imm16

        # sub.w Rn, Rn (zeroing)
        if b0 == 0x19:
            src = (b1 >> 4) & 0x0F
            dst = b1 & 0x0F
            if src == dst == word_reg:
                return 0x0000

        # xor.w Rn, Rn (zeroing)
        if b0 == 0x65:
            src = (b1 >> 4) & 0x0F
            dst = b1 & 0x0F
            if src == dst == word_reg:
                return 0x0000

    return "??"


def trace_register_value_byte(data, store_offset, reg_4bit, search_start):
    """Trace backward from store_offset to find what immediate value was loaded into byte reg."""
    # mov.b #imm8, Rn: Fn imm8
    for delta in range(2, 48, 2):
        pos = store_offset - delta
        if pos < search_start:
            break

        b0, b1 = data[pos], data[pos + 1]

        # mov.b #imm8, Rn: 0xF0|reg imm8
        if (b0 & 0xF0) == 0xF0 and (b0 & 0x0F) == reg_4bit:
            return b1

        # xor.b Rn, Rn
        if b0 == 0x15:
            src = (b1 >> 4) & 0x0F
            dst = b1 & 0x0F
            if src == dst == reg_4bit:
                return 0x00

    return "??"


def main():
    data = FIRMWARE_PATH.read_bytes()

    print("=" * 90)
    print("SCSI Sense Code Write Tracing — Nikon LS-50 Firmware")
    print("=" * 90)

    # Find all mov.l #0x004007B0, ERn instructions
    addr_load_sites = []
    sense_bytes = bytes([0x00, 0x40, 0x07, 0xB0])

    for reg in range(8):
        pattern = bytes([0x7A, 0x00 | reg]) + sense_bytes
        for offset in find_all(data, pattern):
            addr_load_sites.append((offset, reg))

    addr_load_sites.sort()

    print(f"\nFound {len(addr_load_sites)} loads of 0x4007B0 address")

    # For each site, trace the actual writes
    all_sense_writes = []  # (handler, store_addr, value, store_type)

    for load_offset, reg in addr_load_sites:
        handler = addr_to_handler(load_offset)
        writes = analyze_sense_write_site(data, load_offset, reg)

        for w in writes:
            val = w['value']
            val_str = f"0x{val:04X}" if isinstance(val, int) else str(val)
            all_sense_writes.append((handler, w['store_offset'], val, w['store_type']))

    # Print grouped by handler
    by_handler = defaultdict(list)
    for handler, store_addr, value, store_type in all_sense_writes:
        by_handler[handler].append((store_addr, value, store_type))

    print("\n" + "=" * 90)
    print("SENSE CODE WRITES BY HANDLER")
    print("=" * 90)

    for handler in sorted(by_handler.keys()):
        writes = sorted(by_handler[handler])
        print(f"\n--- {handler} ---")
        for store_addr, value, store_type in writes:
            val_str = f"0x{value:04X}" if isinstance(value, int) else str(value)
            print(f"  0x{store_addr:06X}: {store_type} = {val_str}")

    # Now collect unique sense code values
    print("\n" + "=" * 90)
    print("UNIQUE SENSE CODE VALUES (confirmed writes to 0x4007B0)")
    print("=" * 90)

    by_value = defaultdict(list)
    for handler, store_addr, value, store_type in all_sense_writes:
        if isinstance(value, int):
            by_value[value].append((handler, store_addr))

    # Known mappings
    known = {
        0x0000: "NO SENSE / Good",
        0x0007: "HARDWARE ERROR (motor/mechanical)",
        0x0008: "COMMUNICATION FAILURE (ISP1581/USB)",
        0x0009: "TRACK FOLLOWING ERROR (encoder)",
        0x000A: "READ ERROR (CCD)",
        0x000D: "MEDIUM REMOVAL REQUEST (ejecting)",
        0x0020: "DATA TRANSFER TIMEOUT",
        0x004E: "OVERLAPPED COMMANDS ATTEMPTED",
        0x004F: "VENDOR SPECIFIC (init error)",
        0x0050: "ILLEGAL REQUEST (invalid CDB field)",
        0x0051: "COMMAND NOT SUPPORTED IN STATE",
        0x0052: "REQUEST SENSE OVERFLOW",
        0x0053: "INVALID PARAMETER VALUE",
        0x0055: "SCAN SEQUENCE ERROR",
        0x0056: "INVALID PERMISSION/STATE",
        0x0058: "SCAN OPERATION CONFLICT",
        0x0059: "INVALID MODE PAGE",
        0x0064: "SCAN OVERFLOW",
        0x0065: "SEND DATA FORMAT ERROR",
        0x0066: "DISPATCH RESERVATION ERROR",
        0x0068: "DISPATCH STATE ERROR",
        0x006F: "INTERNAL PROCESSING ERROR",
        0x0071: "SCAN TIMEOUT",
        0x0072: "DATA TRANSFER ERROR",
        0x0079: "MOTOR BUSY (positioning)",
        0x007A: "CALIBRATION IN PROGRESS",
        0x0081: "MOTOR CONTROL ERROR",
        0x0092: "SCAN PARAMETER ERROR",
    }

    print(f"\n{'Code':<8s} {'Name':<45s} {'Handlers'}")
    print("-" * 110)

    for value in sorted(by_value.keys()):
        locations = by_value[value]
        handlers = sorted(set(h for h, _ in locations))
        name = known.get(value, "???")
        handler_str = ", ".join(handlers[:4])
        if len(handlers) > 4:
            handler_str += f" (+{len(handlers)-4})"
        print(f"0x{value:04X}   {name:<45s} {handler_str}")

    # ========================================================================
    # Now decode the REQUEST SENSE handler to understand the format
    # ========================================================================
    print("\n" + "=" * 90)
    print("REQUEST SENSE HANDLER ANALYSIS (0x021866)")
    print("=" * 90)
    print("""
The REQUEST SENSE handler (0x021866) reads the 2-byte sense_code from 0x4007B0
and builds a standard 18-byte SCSI sense data response.

Key question: How does the firmware map its internal 16-bit code to the
standard SCSI Sense Key / ASC / ASCQ format?

Let's dump the handler and trace the mapping logic.
""")

    # Hex dump with instruction analysis
    start = 0x021866
    end = 0x02194A
    print(f"Handler bytes (0x{start:06X}-0x{end:06X}):")
    for i in range(start, end, 16):
        chunk = data[i:min(i+16, end)]
        hex_part = ' '.join(f'{b:02X}' for b in chunk)
        ascii_part = ''.join(chr(b) if 32 <= b < 127 else '.' for b in chunk)
        print(f"  0x{i:06X}: {hex_part:<48s} {ascii_part}")

    # Look for sense mapping tables
    # The handler likely has a table that maps internal code -> (SK, ASC, ASCQ)
    # Search for sequences of bytes that look like sense key mappings

    print("\n\nSearching for sense mapping table...")

    # Look for a table in the vicinity of the REQUEST SENSE handler
    # A mapping table would have entries like: [internal_code, sense_key, ASC, ASCQ]
    # Or the handler might use a switch/case

    # Search the code region near REQUEST SENSE for address references
    # that point to data tables
    for pos in range(start, end - 6, 2):
        if data[pos] == 0x7A and (data[pos+1] & 0xF0) == 0x00:
            reg = data[pos+1] & 0x0F
            addr = struct.unpack('>I', data[pos+2:pos+6])[0]
            if 0x020000 <= addr < 0x053000:
                print(f"  0x{pos:06X}: mov.l #0x{addr:08X}, ER{reg}")

    # Also search for sense key mapping logic
    # Look for: cmp.b / cmp.w instructions comparing the sense code
    print("\n\nCompare instructions in REQUEST SENSE handler:")
    for pos in range(start, end - 2, 2):
        b0, b1 = data[pos], data[pos+1]

        # cmp.b #imm8, Rd: A0+d imm8
        if (b0 & 0xF0) == 0xA0:
            reg = b0 & 0x0F
            imm = b1
            if imm > 0:
                print(f"  0x{pos:06X}: cmp.b #0x{imm:02X}, R{reg >> 1}{'h' if (reg & 1) == 0 else 'l'}")

        # cmp.w #imm16, Rd: 79 2d HH LL
        if b0 == 0x79 and (b1 & 0xF0) == 0x20 and pos + 4 <= len(data):
            reg = b1 & 0x0F
            imm16 = struct.unpack('>H', data[pos+2:pos+4])[0]
            print(f"  0x{pos:06X}: cmp.w #0x{imm16:04X}, R{reg}")

    # ========================================================================
    # Look for the sense data translation table
    # ========================================================================
    print("\n" + "=" * 90)
    print("SENSE DATA TRANSLATION TABLE SEARCH")
    print("=" * 90)

    # The firmware must have a table mapping its internal codes to SCSI sense format.
    # Search for patterns that look like: [code_byte, sense_key, ASC, ASCQ]

    # From the data tables region, look for byte sequences where:
    # - byte 0 matches known internal codes
    # - byte 1 is a valid sense key (0x00-0x0B)
    # - bytes 2-3 are valid ASC/ASCQ

    # Known internal codes from our analysis
    internal_codes = [0x07, 0x08, 0x09, 0x0A, 0x0D, 0x50, 0x51, 0x53, 0x55, 0x56, 0x59]

    # Search for sequences that start with a known code followed by sense-key-like bytes
    print("\nSearching 0x20000-0x52FFF for potential sense translation tables...")

    for base in range(0x20000, 0x52F00 - 8):
        matches = 0
        for j in range(0, 20, 4):  # Check 5 consecutive 4-byte entries
            if base + j + 4 > len(data):
                break
            code = data[base + j]
            sk = data[base + j + 1]
            asc = data[base + j + 2]
            ascq = data[base + j + 3]

            if code in internal_codes and 0 <= sk <= 0x0B and asc > 0 and asc < 0x80:
                matches += 1
        if matches >= 3:
            print(f"\n  Possible table at 0x{base:06X}:")
            for j in range(0, 40, 4):
                if base + j + 4 > len(data):
                    break
                code = data[base + j]
                sk = data[base + j + 1]
                asc = data[base + j + 2]
                ascq = data[base + j + 3]
                print(f"    0x{base+j:06X}: [{code:02X}] SK={sk:02X} ASC={asc:02X} ASCQ={ascq:02X}")
                if code == 0x00 and sk == 0x00 and asc == 0x00 and ascq == 0x00:
                    break

    # Alternative: search for 2-byte entries (internal_code -> index into another table)
    # or the firmware might use a computed jump

    # Search for what looks like a REQUEST SENSE response template
    # Standard fixed-format sense data starts with 0x70 (or 0xF0 for deferred)
    print("\n\nSearching for 0x70 (SCSI sense response code) in data tables...")
    for offset in find_all(data[0x020000:0x053000], b'\x70'):
        addr = 0x020000 + offset
        # Check if this could be start of a sense response template
        # 0x70 xx SK xx xx xx xx AL ASC ASCQ ...
        if addr + 18 <= len(data):
            sense_resp = data[addr:addr+18]
            if sense_resp[0] == 0x70 and (sense_resp[2] & 0xF0) == 0x00 and sense_resp[2] <= 0x0B:
                sk = sense_resp[2]
                al = sense_resp[7]
                asc = sense_resp[12] if len(sense_resp) > 12 else 0
                ascq = sense_resp[13] if len(sense_resp) > 13 else 0
                print(f"  0x{addr:06X}: 0x70 response template? SK={sk:X} AL={al:02X} ASC={asc:02X} ASCQ={ascq:02X}")
                print(f"    Full: {' '.join(f'{b:02X}' for b in sense_resp)}")

    # ========================================================================
    # SEARCH FOR SENSE KEY / ASC TABLE REFS IN REQUEST SENSE
    # ========================================================================
    print("\n" + "=" * 90)
    print("DEEP: Searching for sense translation table address references")
    print("=" * 90)

    # In the REQUEST SENSE handler and nearby code, find all 32-bit addresses loaded
    for pos in range(0x021866, 0x02194A - 6, 2):
        if data[pos] == 0x7A and (data[pos+1] & 0xF0) == 0x00:
            reg = data[pos+1] & 0x0F
            addr = struct.unpack('>I', data[pos+2:pos+6])[0]
            print(f"  0x{pos:06X}: mov.l #0x{addr:08X}, ER{reg}")
            if 0x020000 <= addr < 0x053000 or 0x400000 <= addr < 0x420000:
                # Dump some bytes at the target address
                if addr < len(data):
                    target_bytes = data[addr:addr+32]
                    print(f"    -> data: {' '.join(f'{b:02X}' for b in target_bytes)}")

    # Also check addresses referenced from 0x400877/0x400880 (mentioned in KB as sense storage)
    print("\n\nSearching for references to 0x400877 and 0x400880 (additional sense areas):")
    for target in [0x400877, 0x400880, 0x4008A2]:
        target_bytes = struct.pack('>I', target)
        for reg in range(8):
            pattern = bytes([0x7A, 0x00 | reg]) + target_bytes
            for offset in find_all(data, pattern):
                handler = addr_to_handler(offset)
                print(f"  0x{offset:06X}: mov.l #0x{target:08X}, ER{reg} -- {handler}")

    # ========================================================================
    # ANALYZE: How does the firmware convert internal code to sense key?
    # ========================================================================
    print("\n" + "=" * 90)
    print("ANALYSIS: Internal Code -> SCSI Sense Key Mapping Logic")
    print("=" * 90)

    # The SCSI-handler KB says the REQUEST SENSE handler reads sense key from @0x4007B0
    # But the handler likely does MORE than just copy it.
    # Let's look at what the REQUEST SENSE handler writes to the response buffer.

    # First, let's look for a table/subroutine that the handler calls
    # jsr instructions in REQUEST SENSE handler:
    print("\nJSR (subroutine call) instructions in REQUEST SENSE handler:")
    for pos in range(0x021866, 0x02194A - 4, 2):
        b0, b1 = data[pos], data[pos+1]

        # jsr @aa:24 -> 5E followed by 3 bytes
        if b0 == 0x5E:
            if pos + 4 <= len(data):
                addr24 = (data[pos+1] << 16) | (data[pos+2] << 8) | data[pos+3]
                print(f"  0x{pos:06X}: jsr @0x{addr24:06X}")

        # jsr @ERn -> 5D [reg]
        if b0 == 0x5D:
            reg = (b1 >> 4) & 0x07
            print(f"  0x{pos:06X}: jsr @ER{reg}")

    # ========================================================================
    # Look for the actual sense byte lookup table
    # ========================================================================
    print("\n" + "=" * 90)
    print("SEARCHING FOR SENSE LOOKUP TABLE (internal code -> SK+ASC+ASCQ)")
    print("=" * 90)

    # Strategy: The REQUEST SENSE handler must have a way to turn its 16-bit
    # internal code into SK/ASC/ASCQ. Common approaches:
    # 1. A lookup table
    # 2. A series of compare-and-branch
    # 3. Arithmetic transformation

    # Let me search for a table where:
    # - entries are sorted by the low byte of our internal codes
    # - each entry contains a standard SCSI sense key byte

    # From our internal codes, the low byte values are:
    # 0x07, 0x08, 0x09, 0x0A, 0x0D, 0x4E, 0x4F, 0x50, 0x51, 0x52, 0x53,
    # 0x55, 0x56, 0x58, 0x59, 0x64, 0x65, 0x66, 0x68, 0x6F, 0x71, 0x72,
    # 0x79, 0x7A, 0x81, 0x92

    # Let's look for a 3-byte table: [internal_code_lo, ASC, ASCQ]
    # Or a 4-byte table: [internal_code_lo, SK, ASC, ASCQ]

    # Search for two adjacent known codes
    for base in range(0x020000, 0x053000 - 40):
        # Look for a sequence that starts with 0x50 (ILLEGAL REQUEST) -> SK=0x05, ASC=0x24 or 0x20
        found = 0
        entries = []
        pos = base
        while pos < min(base + 200, 0x053000):
            code = data[pos]
            if code in internal_codes:
                found += 1
                entries.append(pos - base)
            elif code == 0x00 and found >= 3:
                break
            elif code == 0xFF and found >= 3:
                break
            pos += 4  # try 4-byte stride

        if found >= 4:
            print(f"\n  Potential 4-byte table at 0x{base:06X} ({found} known codes):")
            for i in range(min(found + 2, 20)):
                off = base + i * 4
                if off + 4 > len(data):
                    break
                b = data[off:off+4]
                marker = " <--" if b[0] in internal_codes else ""
                print(f"    0x{off:06X}: [{b[0]:02X}] {b[1]:02X} {b[2]:02X} {b[3]:02X}{marker}")

    # Try 3-byte stride
    for base in range(0x020000, 0x053000 - 30):
        found = 0
        pos = base
        while pos < min(base + 150, 0x053000):
            code = data[pos]
            if code in internal_codes:
                found += 1
            pos += 3

        if found >= 5:
            print(f"\n  Potential 3-byte table at 0x{base:06X} ({found} known codes with stride 3):")
            for i in range(min(15, 20)):
                off = base + i * 3
                if off + 3 > len(data):
                    break
                b = data[off:off+3]
                marker = " <--" if b[0] in internal_codes else ""
                print(f"    0x{off:06X}: [{b[0]:02X}] {b[1]:02X} {b[2]:02X}{marker}")

    # Try 2-byte stride (code -> single mapping byte)
    for base in range(0x020000, 0x053000 - 20):
        found = 0
        pos = base
        while pos < min(base + 100, 0x053000):
            code = data[pos]
            if code in internal_codes:
                found += 1
            pos += 2

        if found >= 6:
            print(f"\n  Potential 2-byte table at 0x{base:06X} ({found} known codes with stride 2):")
            for i in range(min(15, 20)):
                off = base + i * 2
                if off + 2 > len(data):
                    break
                b = data[off:off+2]
                marker = " <--" if b[0] in internal_codes else ""
                print(f"    0x{off:06X}: [{b[0]:02X}] {b[1]:02X}{marker}")


if __name__ == "__main__":
    main()
