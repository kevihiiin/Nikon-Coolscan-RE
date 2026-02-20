#!/usr/bin/env python3
"""Parse H8/300H interrupt vector table from firmware dump.

The H8/300H has 64 interrupt vectors at address 0x000-0x0FF (4 bytes each, big-endian).

Usage: python3 parse_vector_table.py <firmware_path>
Output: formatted vector table to stdout
"""

import sys
import os
import struct
import json

# H8/3003 vector table names (from H8/300H programming manual)
VECTOR_NAMES = {
    0: "Reset (power-on)",
    1: "Reserved",
    2: "Reserved",
    3: "Reserved",
    4: "Reserved",
    5: "Reserved",
    6: "Reserved",
    7: "NMI (non-maskable interrupt)",
    8: "TRAP #0",
    9: "TRAP #1",
    10: "TRAP #2",
    11: "TRAP #3",
    12: "IRQ0 (external)",
    13: "IRQ1 (external)",
    14: "IRQ2 (external)",
    15: "IRQ3 (external)",
    16: "IRQ4 (external)",
    17: "IRQ5 (external)",
    18: "Reserved",
    19: "Reserved",
    20: "WOVI (watchdog overflow)",
    21: "CMI (compare match)",
    22: "Reserved",
    23: "Reserved",
    24: "IMIA0 (ITU ch0 compare A)",
    25: "IMIB0 (ITU ch0 compare B)",
    26: "OVI0 (ITU ch0 overflow)",
    27: "Reserved",
    28: "IMIA1 (ITU ch1 compare A)",
    29: "IMIB1 (ITU ch1 compare B)",
    30: "OVI1 (ITU ch1 overflow)",
    31: "Reserved",
    32: "IMIA2 (ITU ch2 compare A)",
    33: "IMIB2 (ITU ch2 compare B)",
    34: "OVI2 (ITU ch2 overflow)",
    35: "Reserved",
    36: "IMIA3 (ITU ch3 compare A)",
    37: "IMIB3 (ITU ch3 compare B)",
    38: "OVI3 (ITU ch3 overflow)",
    39: "Reserved",
    40: "IMIA4 (ITU ch4 compare A)",
    41: "IMIB4 (ITU ch4 compare B)",
    42: "OVI4 (ITU ch4 overflow)",
    43: "Reserved",
    44: "DEND0A (DMAC ch0A end)",
    45: "DEND0B (DMAC ch0B end)",
    46: "DEND1A (DMAC ch1A end)",
    47: "DEND1B (DMAC ch1B end)",
    48: "Reserved",
    49: "Reserved",
    50: "Reserved",
    51: "Reserved",
    52: "ERI0 (SCI ch0 receive error)",
    53: "RXI0 (SCI ch0 receive)",
    54: "TXI0 (SCI ch0 transmit)",
    55: "TEI0 (SCI ch0 transmit end)",
    56: "ERI1 (SCI ch1 receive error)",
    57: "RXI1 (SCI ch1 receive)",
    58: "TXI1 (SCI ch1 transmit)",
    59: "TEI1 (SCI ch1 transmit end)",
    60: "ADI (A/D conversion end)",
    61: "Reserved",
    62: "Reserved",
    63: "Reserved",
}


def parse_vector_table(fw_path):
    """Parse the 64-entry vector table from firmware."""
    with open(fw_path, 'rb') as f:
        data = f.read(256)  # 64 vectors * 4 bytes

    vectors = []
    default_handler = None
    unique_handlers = set()

    for i in range(64):
        offset = i * 4
        addr = struct.unpack('>I', data[offset:offset+4])[0]
        # Mask to 24-bit address space
        addr_24 = addr & 0xFFFFFF
        name = VECTOR_NAMES.get(i, f"Unknown_{i}")

        vectors.append({
            'index': i,
            'table_offset': f'0x{offset:03X}',
            'target': f'0x{addr_24:06X}',
            'target_raw': f'0x{addr:08X}',
            'name': name,
        })
        unique_handlers.add(addr_24)

    return vectors, unique_handlers


def main():
    if len(sys.argv) != 2:
        print(f"Usage: {sys.argv[0]} <firmware_path>", file=sys.stderr)
        sys.exit(1)

    fw_path = sys.argv[1]
    if not os.path.exists(fw_path):
        print(f"Error: {fw_path} not found", file=sys.stderr)
        sys.exit(1)

    vectors, unique = parse_vector_table(fw_path)

    # Find default handler (most common target address)
    from collections import Counter
    addr_counts = Counter(v['target'] for v in vectors)
    default_addr = addr_counts.most_common(1)[0][0]

    print(f"H8/300H Vector Table -- {os.path.basename(fw_path)}")
    print(f"{'='*80}")
    print(f"Unique handler addresses: {len(unique)}")
    print(f"Default/unused handler: {default_addr}")
    print(f"{'='*80}")
    print()
    print(f"{'Vec':>3} {'Offset':>8} {'Target':>10} {'Name':<45} {'Status'}")
    print(f"{'-'*3} {'-'*8} {'-'*10} {'-'*45} {'-'*10}")

    active_vectors = []
    for v in vectors:
        is_default = v['target'] == default_addr
        status = "default" if is_default else "ACTIVE"
        print(f"{v['index']:>3} {v['table_offset']:>8} {v['target']:>10} {v['name']:<45} {status}")
        if not is_default:
            active_vectors.append(v)

    print()
    print(f"Active (non-default) vectors: {len(active_vectors)}")
    for v in active_vectors:
        print(f"  Vector {v['index']:2d}: {v['target']} -- {v['name']}")

    # Also output JSON for machine consumption
    json_path = fw_path + '.vectors.json'
    with open(json_path, 'w') as f:
        json.dump({
            'firmware': os.path.basename(fw_path),
            'total_vectors': 64,
            'active_count': len(active_vectors),
            'default_handler': default_addr,
            'vectors': vectors,
            'active_vectors': active_vectors,
        }, f, indent=2)
    print(f"\nJSON output: {json_path}", file=sys.stderr)


if __name__ == '__main__':
    main()
