#!/usr/bin/env python3
"""
Final comprehensive SCSI sense code catalog for the Nikon LS-50 firmware.

This script:
1. Dumps the complete sense translation table at 0x16DEE (147 entries)
2. Cross-references which internal codes are actually written by SCSI handlers
3. Groups by SCSI Sense Key for driver implementors
4. Identifies which SCSI commands can generate each sense code
"""

import struct
from pathlib import Path
from collections import defaultdict

FIRMWARE_PATH = Path(__file__).parent.parent.parent / "binaries" / "firmware" / "Nikon LS-50 MBM29F400B TSOP48.bin"

# Sense translation table base
TABLE_BASE = 0x16DEE
TABLE_ENTRY_SIZE = 5
TABLE_MAX_INDEX = 0x93  # Last valid entry

HANDLER_RANGES = {
    "DISPATCH":                  (0x020B00, 0x0215C2),
    "TEST_UNIT_READY":           (0x0215C2, 0x021866),
    "REQUEST_SENSE":             (0x021866, 0x02194A),
    "MODE_SELECT":               (0x02194A, 0x021E3E),
    "RESERVE":                   (0x021E3E, 0x021EA0),
    "RELEASE":                   (0x021EA0, 0x021F1C),
    "MODE_SENSE":                (0x021F1C, 0x0220B8),
    "SCAN":                      (0x0220B8, 0x023856),
    "RECV_DIAG":                 (0x023856, 0x023D32),
    "SEND_DIAG":                 (0x023D32, 0x023F10),
    "READ":                      (0x023F10, 0x025506),
    "SET_WINDOW":                (0x026E38, 0x0272F6),
    "GET_WINDOW":                (0x0272F6, 0x02837C),
    "SEND":                      (0x025506, 0x025E18),
    "INQUIRY":                   (0x025E18, 0x026E38),
    "WRITE_BUFFER":              (0x02837C, 0x028884),
    "READ_BUFFER":               (0x028884, 0x028AB4),
    "VENDOR_C0":                 (0x028AB4, 0x028B08),
    "VENDOR_C1":                 (0x028B08, 0x028E16),
    "VENDOR_E0":                 (0x028E16, 0x0295EA),
    "VENDOR_E1":                 (0x0295EA, 0x02A000),
    "SHARED_MODULE":             (0x010000, 0x017FFF),
}

SK_NAMES = {
    0x00: "NO SENSE",
    0x01: "RECOVERED ERROR",
    0x02: "NOT READY",
    0x03: "MEDIUM ERROR",
    0x04: "HARDWARE ERROR",
    0x05: "ILLEGAL REQUEST",
    0x06: "UNIT ATTENTION",
    0x07: "DATA PROTECT",
    0x08: "BLANK CHECK",
    0x09: "VENDOR SPECIFIC",
    0x0A: "COPY ABORTED",
    0x0B: "ABORTED COMMAND",
}

ASC_MEANINGS = {
    (0x00, 0x00): "No additional sense information",
    (0x00, 0x05): "End of data detected (no ASC/ASCQ)",
    (0x03, 0x00): "Peripheral device write fault",
    (0x04, 0x00): "LU not ready, cause not reportable",
    (0x04, 0x01): "LU in process of becoming ready",
    (0x04, 0x02): "LU not ready, init command required",
    (0x04, 0x03): "LU not ready, manual intervention required",
    (0x05, 0x00): "LU does not respond to selection",
    (0x08, 0x00): "LU communication failure",
    (0x08, 0x01): "LU communication timeout",
    (0x11, 0x00): "Unrecovered read error",
    (0x11, 0x01): "Read retries exhausted",
    (0x15, 0x00): "Random positioning error",
    (0x15, 0x01): "Mechanical positioning error",
    (0x1A, 0x00): "Parameter list length error",
    (0x20, 0x00): "Invalid command operation code",
    (0x24, 0x00): "Invalid field in CDB",
    (0x25, 0x00): "Logical unit not supported",
    (0x26, 0x00): "Invalid field in parameter list",
    (0x26, 0x01): "Parameter not supported",
    (0x26, 0x02): "Parameter value invalid",
    (0x28, 0x00): "Not ready to ready change, medium may have changed",
    (0x29, 0x00): "Power on, reset, or bus device reset",
    (0x2A, 0x00): "Parameters changed",
    (0x2A, 0x01): "Mode parameters changed",
    (0x2C, 0x00): "Command sequence error",
    (0x2C, 0x01): "Too many windows specified",
    (0x2C, 0x02): "Invalid combination of windows specified",
    (0x30, 0x01): "Cannot read medium - unknown format",
    (0x37, 0x00): "Rounded parameter",
    (0x39, 0x00): "Saving parameters not supported",
    (0x3A, 0x00): "Medium not present",
    (0x3D, 0x00): "Invalid bits in identify message",
    (0x3E, 0x00): "LU has not self-configured yet",
    (0x3F, 0x00): "Target operating conditions have changed",
    (0x3F, 0x01): "Microcode has been changed",
    (0x3F, 0x03): "Inquiry data has changed",
    (0x43, 0x00): "Message error",
    (0x44, 0x00): "Internal target failure",
    (0x45, 0x00): "Select or reselect failure",
    (0x47, 0x00): "SCSI parity error",
    (0x48, 0x00): "Initiator detected error message received",
    (0x49, 0x00): "Invalid message error",
    (0x4A, 0x00): "Command phase error",
    (0x4B, 0x00): "Data phase error",
    (0x4C, 0x00): "LU failed self-configuration",
    (0x4E, 0x00): "Overlapped commands attempted",
    (0x53, 0x00): "Media load or eject failed",
    (0x60, 0x00): "Lamp failure",
    (0x61, 0x02): "Out of focus",
    (0x62, 0x00): "Scan head positioning error",
    (0x80, 0x01): "Vendor: general hardware issue",
    (0x80, 0x02): "Vendor: scan data issue",
    (0x80, 0x06): "Vendor: configuration issue",
}


def addr_to_handler(addr):
    best = None
    best_size = 0x100000
    for name, (start, end) in HANDLER_RANGES.items():
        if start <= addr < end:
            size = end - start
            if size < best_size:
                best = name
                best_size = size
    return best or None


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


def main():
    data = FIRMWARE_PATH.read_bytes()

    # ========================================================================
    # 1. Read the complete sense translation table
    # ========================================================================
    table_entries = {}
    for idx in range(TABLE_MAX_INDEX + 1):
        addr = TABLE_BASE + idx * TABLE_ENTRY_SIZE
        if addr + TABLE_ENTRY_SIZE > len(data):
            break
        flags = data[addr]
        sk = data[addr + 1]
        asc = data[addr + 2]
        ascq = data[addr + 3]
        fru = data[addr + 4]
        table_entries[idx] = {
            'flags': flags,
            'sk': sk,
            'asc': asc,
            'ascq': ascq,
            'fru': fru,
            'addr': addr,
        }

    # ========================================================================
    # 2. Find all sense code writes in handler code
    # ========================================================================
    # Search for mov.w #imm16, Rn (79 0n HH LL) in handler regions
    # where the value is a valid table index

    code_writes = defaultdict(set)  # code -> set of handler names

    code_regions = [(0x010000, 0x017FFF), (0x020000, 0x052FFF)]

    for start, end in code_regions:
        for pos in range(start, min(end, len(data) - 4), 2):
            b0, b1 = data[pos], data[pos + 1]

            # mov.w #imm16, Rn: 79 0n HH LL
            if b0 == 0x79 and (b1 & 0xF0) == 0x00:
                reg = b1 & 0x0F
                if reg <= 7:
                    imm16 = struct.unpack('>H', data[pos+2:pos+4])[0]
                    if imm16 <= TABLE_MAX_INDEX and imm16 in table_entries:
                        handler = addr_to_handler(pos)
                        if handler:
                            code_writes[imm16].add(handler)

            # sub.w Rn, Rn -> code 0x0000
            if b0 == 0x19 and ((b1 >> 4) == (b1 & 0x0F)):
                handler = addr_to_handler(pos)
                if handler:
                    # Only count as sense write if near a sense address load
                    for delta in range(-48, 49):
                        check = pos + delta
                        if 0 <= check + 6 <= len(data):
                            if (data[check] == 0x7A and
                                (data[check+1] & 0xF0) == 0x00 and
                                data[check+2:check+6] == b'\x00\x40\x07\xB0'):
                                code_writes[0x0000].add(handler)
                                break

    # ========================================================================
    # 3. Output: Complete table
    # ========================================================================
    print("=" * 120)
    print("COMPLETE SCSI SENSE CODE CATALOG — Nikon LS-50 Firmware")
    print("=" * 120)
    print(f"""
Sense Translation Table: 0x{TABLE_BASE:06X} in flash
Entry format: 5 bytes [Flags, SK, ASC, ASCQ, FRU]
Table indices 0x00 through 0x{TABLE_MAX_INDEX:02X} ({TABLE_MAX_INDEX + 1} entries)
Internal code at RAM 0x4007B0 indexes directly into this table.

The subroutine at 0x0111F4 builds a standard 18-byte SCSI fixed-format sense
response from the table entry:
  Byte 0: 0x70 (current) or 0xF0 (deferred, if flags bit 7 set)
  Byte 1: 0x00
  Byte 2: Sense Key (from table byte 1), OR'd with 0x20 if flags bit 4 set
  Bytes 3-6: Command-specific info (from RAM 0x4007A0, if flags bit 5 set)
  Byte 7: 0x0B (additional sense length = 11)
  Bytes 8-9: 0x00
  Bytes 10-11: 0x00
  Byte 12: ASC (from table byte 2)
  Byte 13: ASCQ (from table byte 3)
  Bytes 14-15: Field-replaceable unit / sense key specific (from RAM 0x4007A4, if flags bit 3 set)
  Byte 16: Copy of table entry byte 4 (FRU-like)
  Bytes 17+: zeroed
""")

    # Print ALL valid entries
    print(f"{'Idx':<6s} {'Flg':<6s} {'SK':<20s} {'ASC/ASCQ':<12s} {'FRU':<6s} {'Meaning':<45s} {'Written By'}")
    print("-" * 140)

    for idx in sorted(table_entries.keys()):
        e = table_entries[idx]
        if e['sk'] > 0x0B and idx > 0x92:
            continue  # Skip clearly invalid entries

        sk_name = SK_NAMES.get(e['sk'], f"0x{e['sk']:02X}")
        asc_meaning = ASC_MEANINGS.get((e['asc'], e['ascq']), "")
        handlers = sorted(code_writes.get(idx, set()))
        handler_str = ", ".join(handlers[:3])
        if len(handlers) > 3:
            handler_str += f" (+{len(handlers)-3})"
        if not handlers:
            handler_str = "-"

        # Mark entries that are actually used
        used = "*" if handlers and handlers != ["-"] else " "

        print(f"0x{idx:02X}{used}  0x{e['flags']:02X}   {sk_name:<20s} {e['asc']:02X}/{e['ascq']:02X}       0x{e['fru']:02X}   {asc_meaning:<45s} {handler_str}")

    # ========================================================================
    # 4. Summary grouped by Sense Key
    # ========================================================================
    print("\n\n" + "=" * 120)
    print("SUMMARY BY SCSI SENSE KEY (used codes only)")
    print("=" * 120)

    by_sk = defaultdict(list)
    for idx in sorted(table_entries.keys()):
        if idx in code_writes:
            e = table_entries[idx]
            by_sk[e['sk']].append(idx)

    for sk in sorted(by_sk.keys()):
        indices = by_sk[sk]
        sk_name = SK_NAMES.get(sk, f"0x{sk:02X}")
        print(f"\n--- SK={sk:X} ({sk_name}) --- {len(indices)} codes ---")
        for idx in indices:
            e = table_entries[idx]
            asc_meaning = ASC_MEANINGS.get((e['asc'], e['ascq']), "")
            handlers = sorted(code_writes.get(idx, set()))
            handler_str = ", ".join(handlers)
            print(f"  0x{idx:02X}: ASC={e['asc']:02X}h ASCQ={e['ascq']:02X}h FRU={e['fru']:02X}h  {asc_meaning:<40s}  [{handler_str}]")

    # ========================================================================
    # 5. Cross-reference: SCSI command -> possible sense codes
    # ========================================================================
    print("\n\n" + "=" * 120)
    print("CROSS-REFERENCE: SCSI Command -> Possible Sense Codes")
    print("=" * 120)

    cmd_to_codes = defaultdict(set)
    for idx, handlers in code_writes.items():
        for h in handlers:
            cmd_to_codes[h].add(idx)

    for handler in sorted(cmd_to_codes.keys()):
        codes = sorted(cmd_to_codes[handler])
        print(f"\n  {handler}:")
        for idx in codes:
            e = table_entries.get(idx, {})
            sk = e.get('sk', 0)
            asc = e.get('asc', 0)
            ascq = e.get('ascq', 0)
            sk_name = SK_NAMES.get(sk, "?")
            asc_meaning = ASC_MEANINGS.get((asc, ascq), "")
            print(f"    0x{idx:02X}: {sk_name:<20s} ASC/ASCQ={asc:02X}h/{ascq:02X}h  {asc_meaning}")

    # ========================================================================
    # 6. For driver writers: sense codes to expect per workflow stage
    # ========================================================================
    print("\n\n" + "=" * 120)
    print("DRIVER IMPLEMENTOR GUIDE: Key Sense Codes by Category")
    print("=" * 120)

    categories = {
        "Scanner Busy / Not Ready": [0x07, 0x08, 0x09, 0x0A, 0x0B, 0x0C, 0x0E, 0x0F, 0x71, 0x78, 0x79, 0x7A, 0x7B, 0x7C, 0x80, 0x82, 0x91],
        "Invalid Command / CDB": [0x4E, 0x4F, 0x50, 0x51, 0x52, 0x53, 0x54, 0x55],
        "Scan Workflow Errors": [0x56, 0x57, 0x58, 0x59, 0x64, 0x92],
        "Hardware Faults": [0x1F, 0x20, 0x21, 0x28, 0x29, 0x2A, 0x2B, 0x2C, 0x2D, 0x2E, 0x2F, 0x72, 0x73, 0x74, 0x81],
        "Lamp Faults": list(range(0x33, 0x4C)) + list(range(0x85, 0x91)),
        "Medium Errors (Film)": list(range(0x10, 0x1F)) + [0x83],
        "Unit Attention": [0x5B, 0x5C, 0x5D, 0x5E, 0x5F, 0x60, 0x61, 0x75],
        "Communication/Bus Errors": [0x65, 0x66, 0x67, 0x68, 0x69, 0x6A, 0x6B, 0x6C, 0x6D, 0x6E, 0x6F, 0x70],
        "Vendor-Specific": [0x62, 0x63, 0x64, 0x76, 0x7D, 0x81, 0x92, 0x93],
    }

    for cat_name, indices in categories.items():
        valid = [i for i in indices if i in table_entries and table_entries[i]['sk'] <= 0x0B]
        if not valid:
            continue
        print(f"\n  --- {cat_name} ({len(valid)} codes) ---")
        for idx in valid:
            e = table_entries[idx]
            sk_name = SK_NAMES.get(e['sk'], "?")
            asc_meaning = ASC_MEANINGS.get((e['asc'], e['ascq']), "")
            used = "*" if idx in code_writes else " "
            print(f"    0x{idx:02X}{used}: {sk_name:<20s} ASC/ASCQ={e['asc']:02X}h/{e['ascq']:02X}h FRU={e['fru']:02X}h  {asc_meaning}")


if __name__ == "__main__":
    main()
