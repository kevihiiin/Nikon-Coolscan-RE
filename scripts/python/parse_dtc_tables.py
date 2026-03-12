#!/usr/bin/env python3
"""Parse READ and WRITE Data Type Code dispatch tables from LS-50 firmware.

READ table at 0x49AD8: 15 entries × 12 bytes, 0xFF-terminated
WRITE table at 0x49B98: 7 entries × 10 bytes, 0xFF-terminated

Entry format (READ, 12 bytes):
  Byte 0:    DTC value
  Byte 1:    Qualifier category (0x00=none, 0x01=single, 0x03=channel, 0x10=two-mode, 0x30=three-mode)
  Bytes 2-3: Reserved (always 0x0000)
  Bytes 4-5: Maximum transfer size (u16 big-endian, 0=variable/handler-managed)
  Bytes 6-9: Source RAM address (u32 big-endian, 0=handler-specific)
  Byte 10:   Sub-handler dispatch index
  Byte 11:   Padding (always 0x00)

Entry format (WRITE, 10 bytes):
  Byte 0:    DTC value
  Byte 1:    Qualifier category
  Bytes 2-3: Reserved (always 0x0000)
  Bytes 4-5: Maximum transfer size (u16 big-endian, 0=handler-managed)
  Bytes 6-9: Extended parameters (usually 0)
"""
import struct
import sys

FIRMWARE_PATH = "binaries/firmware/Nikon LS-50 MBM29F400B TSOP48.bin"

DTC_NAMES_READ = {
    0x00: "Image Data",
    0x03: "Gamma/LUT",
    0x81: "Film Frame Info",
    0x84: "Calibration Data",
    0x87: "Scan Parameters",
    0x88: "Boundary/Per-Ch Cal",
    0x8A: "Exposure/Gain Params",
    0x8C: "Offset/Dark Current",
    0x8D: "Extended Scan Line",
    0x8E: "Focus/Measurement",
    0x8F: "Histogram/Profile",
    0x90: "CCD Characterization",
    0x92: "Motor/Positioning",
    0x93: "Adapter/Film Type",
    0xE0: "Extended Configuration",
}

DTC_NAMES_WRITE = {
    0x03: "Gamma/LUT",
    0x84: "Calibration Upload",
    0x85: "Extended Calibration",
    0x88: "Boundary/Per-Ch Cal",
    0x8F: "Histogram/Profile",
    0x92: "Motor Control",
    0xE0: "Extended Configuration",
}

QUAL_CATEGORIES = {
    0x00: "none (ignored)",
    0x01: "single value",
    0x03: "channel (0=all,1=R,2=G,3=B)",
    0x10: "two-mode (0 or 1)",
    0x30: "three-mode (0,1,3 = R/G/B)",
}


def parse_read_table(fw):
    """Parse READ DTC dispatch table at 0x49AD8."""
    entries = []
    offset = 0x49AD8
    while fw[offset] != 0xFF:
        e = fw[offset:offset + 12]
        dtc = e[0]
        qual_cat = e[1]
        reserved = struct.unpack('>H', e[2:4])[0]
        max_size = struct.unpack('>H', e[4:6])[0]
        ram_addr = struct.unpack('>I', e[6:10])[0]
        sub_idx = e[10]
        entries.append({
            'dtc': dtc,
            'qual_cat': qual_cat,
            'max_size': max_size,
            'ram_addr': ram_addr,
            'sub_idx': sub_idx,
            'name': DTC_NAMES_READ.get(dtc, f"Unknown 0x{dtc:02X}"),
        })
        offset += 12
    return entries


def parse_write_table(fw):
    """Parse WRITE DTC dispatch table at 0x49B98."""
    entries = []
    offset = 0x49B98
    while fw[offset] != 0xFF:
        e = fw[offset:offset + 10]
        dtc = e[0]
        qual_cat = e[1]
        reserved = struct.unpack('>H', e[2:4])[0]
        max_size = struct.unpack('>H', e[4:6])[0]
        ext_params = struct.unpack('>I', e[6:10])[0]
        entries.append({
            'dtc': dtc,
            'qual_cat': qual_cat,
            'max_size': max_size,
            'ext_params': ext_params,
            'name': DTC_NAMES_WRITE.get(dtc, f"Unknown 0x{dtc:02X}"),
        })
        offset += 10
    return entries


def main():
    with open(FIRMWARE_PATH, 'rb') as f:
        fw = f.read()

    print("=" * 80)
    print("READ DTC Table (0x49AD8) — 15 entries × 12 bytes")
    print("=" * 80)
    read_entries = parse_read_table(fw)
    print(f"{'DTC':>5} {'Name':<25} {'Qual':>6} {'MaxSz':>6} {'RAM Addr':>10} {'SubIdx':>6}")
    print("-" * 65)
    for e in read_entries:
        qual = QUAL_CATEGORIES.get(e['qual_cat'], f"0x{e['qual_cat']:02X}")
        ram = f"0x{e['ram_addr']:06X}" if e['ram_addr'] else "—"
        print(f"0x{e['dtc']:02X}  {e['name']:<25} {qual[:6]:>6} {e['max_size']:>6} {ram:>10} 0x{e['sub_idx']:02X}")

    print()
    print("=" * 80)
    print("WRITE DTC Table (0x49B98) — 7 entries × 10 bytes")
    print("=" * 80)
    write_entries = parse_write_table(fw)
    print(f"{'DTC':>5} {'Name':<25} {'Qual':>6} {'MaxSz':>6} {'ExtParams':>10}")
    print("-" * 55)
    for e in write_entries:
        qual = QUAL_CATEGORIES.get(e['qual_cat'], f"0x{e['qual_cat']:02X}")
        ext = f"0x{e['ext_params']:08X}" if e['ext_params'] else "—"
        print(f"0x{e['dtc']:02X}  {e['name']:<25} {qual[:6]:>6} {e['max_size']:>6} {ext:>10}")


if __name__ == "__main__":
    main()
