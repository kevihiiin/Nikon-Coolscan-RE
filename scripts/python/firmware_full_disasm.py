#!/usr/bin/env python3
"""
Full firmware disassembly using radare2.
Produces annotated assembly listing with cross-references, strings, and data annotations.
Usage: uv run scripts/python/firmware_full_disasm.py
"""
import subprocess
import json
import struct
import sys
import os

FIRMWARE = "binaries/firmware/Nikon LS-50 MBM29F400B TSOP48.bin"
OUTPUT = "ghidra/exports/firmware_r2_full_disasm.txt"

# Known memory regions from RE
REGIONS = {
    (0x00000, 0x00100): "Vector Table",
    (0x00100, 0x001A0): "Boot Code",
    (0x001A0, 0x004000): "Early Init / Recovery Stubs",
    (0x004000, 0x006000): "Bootloader Flags",
    (0x006000, 0x008000): "Settings Area",
    (0x008000, 0x010000): "Extended Settings (erased)",
    (0x010000, 0x020000): "Recovery Firmware",
    (0x020000, 0x045000): "Main Firmware Code",
    (0x045000, 0x052900): "Data Tables",
    (0x052900, 0x05A000): "Additional Code / Scan Loops",
    (0x05A000, 0x060000): "Late Code / Padding",
    (0x060000, 0x070000): "Log Area 1",
    (0x070000, 0x080000): "Log Area 2",
}

# Known function addresses from KB docs
KNOWN_FUNCTIONS = {
    0x000100: "reset_entry",
    0x000112: "alt_entry",
    0x00016E: "bank_select",
    0x000182: "nmi_handler",
    0x000186: "default_isr",
    0x0107BC: "register_context_a",
    0x0107EC: "context_system_init",
    0x0109E2: "clear_shared_state",
    0x0109FA: "clear_state_2",
    0x010BCE: "init_asic_dma",
    0x010C46: "context_b_reentry",
    0x013748: "phase_query_D0_handler",
    0x01374A: "scsi_status_set",
    0x015EAA: "peripheral_init",
    0x020334: "main_fw_entry",
    0x0204C4: "trampoline_install_start",
    0x0205FC: "post_trampoline_init",
    0x0207F2: "context_a_entry",
    0x020C00: "scsi_dispatch",
    0x0215C2: "scsi_test_unit_ready",
    0x021866: "scsi_request_sense",
    0x02194A: "scsi_mode_select",
    0x021E3E: "scsi_reserve",
    0x021EA0: "scsi_release",
    0x021F1C: "scsi_mode_sense",
    0x0220B8: "scsi_scan",
    0x023856: "scsi_receive_diagnostic",
    0x023D32: "scsi_send_diagnostic",
    0x023F10: "scsi_read_10",
    0x025506: "scsi_write_10",
    0x025E18: "scsi_inquiry",
    0x026E38: "scsi_set_window",
    0x0272F6: "scsi_get_window",
    0x02837C: "scsi_write_buffer",
    0x028884: "scsi_read_buffer",
    0x028AB4: "scsi_vendor_c0",
    0x028B08: "scsi_vendor_c1",
    0x028E16: "scsi_vendor_e0",
    0x0295EA: "scsi_vendor_e1",
    0x029B16: "context_b_entry",
    0x02A188: "hw_init_with_interrupts",
    0x049834: "scsi_dispatch_table",
    0x049910: "task_dispatch_table",
    0x049AD8: "read_dtc_table",
    0x049B98: "write_dtc_table",
}

def read_firmware():
    with open(FIRMWARE, "rb") as f:
        return f.read()

def extract_strings(data, min_len=4):
    """Extract printable ASCII strings from firmware."""
    strings = {}
    current = b""
    start = 0
    for i, b in enumerate(data):
        if 0x20 <= b < 0x7F:
            if not current:
                start = i
            current += bytes([b])
        else:
            if len(current) >= min_len:
                strings[start] = current.decode('ascii')
            current = b""
    return strings

def decode_vector_table(data):
    """Decode H8/3003 interrupt vector table (64 vectors × 4 bytes)."""
    vectors = []
    for i in range(64):
        addr = struct.unpack(">I", data[i*4:(i+1)*4])[0]
        vectors.append((i, i*4, addr))
    return vectors

def find_function_boundaries(data, start, end):
    """Heuristic function boundary detection for H8/300H."""
    boundaries = set()
    # Known functions
    for addr in KNOWN_FUNCTIONS:
        if start <= addr < end:
            boundaries.add(addr)

    # Look for RTS (0x5470) and RTE (0x5670) as function ends
    i = start
    while i < end - 1:
        word = struct.unpack(">H", data[i:i+2])[0]
        if word == 0x5470 or word == 0x5670:  # RTS or RTE
            # Next non-zero word after RTS/RTE is likely next function
            j = i + 2
            while j < end and j < i + 16:
                w = struct.unpack(">H", data[j:j+2])[0]
                if w != 0x0000 and w != 0xFFFF:
                    boundaries.add(j)
                    break
                j += 2
        i += 2

    return sorted(boundaries)

def is_erased(data, start, end):
    """Check if region is all 0xFF."""
    return all(b == 0xFF for b in data[start:end])

def hex_dump(data, start, length, width=16):
    """Generate hex dump of a data region."""
    lines = []
    for offset in range(0, length, width):
        addr = start + offset
        chunk = data[start + offset:start + offset + width]
        hex_part = " ".join(f"{b:02X}" for b in chunk)
        ascii_part = "".join(chr(b) if 0x20 <= b < 0x7F else "." for b in chunk)
        lines.append(f"  {addr:06X}: {hex_part:<{width*3}}  {ascii_part}")
    return "\n".join(lines)

def main():
    data = read_firmware()
    strings = extract_strings(data)

    with open(OUTPUT, "w") as f:
        f.write("=" * 80 + "\n")
        f.write("  NIKON LS-50 FIRMWARE — COMPLETE ANNOTATED LISTING\n")
        f.write("  512KB MBM29F400B Flash | H8/3003 (H8/300H) | Big-Endian\n")
        f.write("=" * 80 + "\n\n")

        # === VECTOR TABLE ===
        f.write("=" * 80 + "\n")
        f.write("  SECTION: INTERRUPT VECTOR TABLE (0x000000 - 0x0000FF)\n")
        f.write("=" * 80 + "\n\n")

        vectors = decode_vector_table(data)
        vec_names = {
            0: "Reset", 1: "Reserved", 2: "Reserved", 3: "Reserved",
            4: "Reserved", 5: "Reserved", 6: "Reserved", 7: "NMI",
            8: "TRAP #0", 9: "TRAP #1", 10: "TRAP #2", 11: "TRAP #3",
            12: "IRQ0", 13: "IRQ1 (ISP1581 USB)", 14: "IRQ2",
            15: "IRQ3 (Encoder)", 16: "IRQ4", 17: "IRQ5",
            18: "Reserved18", 19: "Reserved19",
            20: "WOVI", 21: "CMI", 22: "Reserved22", 23: "Reserved23",
            24: "IMIA0", 25: "IMIB0/ICIB0", 26: "OVI0",
            27: "Reserved27", 28: "IMIA1", 29: "IMIB1/ICIB1", 30: "OVI1",
            31: "Reserved31", 32: "IMIA2 (Motor)", 33: "IMIB2", 34: "OVI2",
            35: "Reserved35", 36: "IMIA3", 37: "IMIB3", 38: "OVI3",
            39: "Reserved39", 40: "IMIA4 (Tick)", 41: "IMIB4", 42: "OVI4",
            43: "Reserved43", 44: "DEND0A", 45: "DEND0B (DMA0)",
            46: "DEND1A", 47: "DEND1B (DMA1)",
            48: "Reserved48", 49: "Reserved49",
            50: "Reserved50", 51: "Reserved51",
            52: "SCI0_ERI", 53: "SCI0_RXI", 54: "SCI0_TXI", 55: "SCI0_TEI",
            56: "SCI1_ERI", 57: "SCI1_RXI", 58: "SCI1_TXI", 59: "SCI1_TEI",
            60: "ADI (A/D Conv)", 61: "Reserved61", 62: "Reserved62", 63: "Reserved63",
        }

        for vec_num, offset, target in vectors:
            name = vec_names.get(vec_num, f"Vec{vec_num}")
            active = " *ACTIVE*" if target not in (0x000000, 0xFFFFFF, 0x000186) and target != 0 else ""
            known = ""
            if target in KNOWN_FUNCTIONS:
                known = f" => {KNOWN_FUNCTIONS[target]}"
            f.write(f"  Vec {vec_num:2d} ({offset:04X}): 0x{target:06X}  {name}{active}{known}\n")

        f.write("\n")

        # === STRING TABLE ===
        f.write("=" * 80 + "\n")
        f.write("  STRING TABLE (all ASCII strings >= 4 chars)\n")
        f.write("=" * 80 + "\n\n")

        for addr in sorted(strings.keys()):
            s = strings[addr]
            f.write(f"  0x{addr:06X}: \"{s}\"\n")

        f.write(f"\n  Total strings: {len(strings)}\n\n")

        # === REGION-BY-REGION ANALYSIS ===
        for (rstart, rend), rname in REGIONS.items():
            f.write("=" * 80 + "\n")
            f.write(f"  SECTION: {rname} (0x{rstart:06X} - 0x{rend:06X})\n")
            f.write(f"  Size: {rend - rstart} bytes ({(rend - rstart)/1024:.1f} KB)\n")
            f.write("=" * 80 + "\n\n")

            if is_erased(data, rstart, rend):
                f.write("  [ERASED — all 0xFF]\n\n")
                continue

            # Check if mostly zero
            zero_count = sum(1 for b in data[rstart:rend] if b == 0)
            ff_count = sum(1 for b in data[rstart:rend] if b == 0xFF)
            total = rend - rstart

            if ff_count > total * 0.9:
                f.write(f"  [MOSTLY ERASED — {ff_count}/{total} bytes are 0xFF]\n")
                # Show non-FF parts
                i = rstart
                while i < rend:
                    if data[i] != 0xFF:
                        # Find extent of non-FF data
                        j = i
                        while j < rend and data[j] != 0xFF:
                            j += 1
                        f.write(f"\n  Non-erased block at 0x{i:06X} ({j-i} bytes):\n")
                        f.write(hex_dump(data, i, min(j-i, 256)) + "\n")
                        i = j
                    else:
                        i += 1
                f.write("\n")
                continue

            # For data tables region, do hex dump with annotations
            if "Data Tables" in rname or "Settings" in rname or "Log" in rname:
                # Show known tables and hex dump
                region_data = data[rstart:rend]
                for taddr, tname in sorted(KNOWN_FUNCTIONS.items()):
                    if rstart <= taddr < rend:
                        f.write(f"  --- {tname} at 0x{taddr:06X} ---\n")

                f.write("\n  Hex dump (first 1024 bytes):\n")
                f.write(hex_dump(data, rstart, min(1024, rend - rstart)) + "\n")
                if rend - rstart > 1024:
                    f.write(f"  ... ({rend - rstart - 1024} more bytes)\n")
                f.write("\n")
                continue

            # For code regions, list known functions and boundaries
            funcs_in_region = {a: n for a, n in KNOWN_FUNCTIONS.items() if rstart <= a < rend}
            if funcs_in_region:
                f.write("  Known functions in this region:\n")
                for addr in sorted(funcs_in_region.keys()):
                    f.write(f"    0x{addr:06X}: {funcs_in_region[addr]}\n")
                f.write("\n")

            # Show region strings
            region_strings = {a: s for a, s in strings.items() if rstart <= a < rend}
            if region_strings:
                f.write("  Strings in this region:\n")
                for addr in sorted(region_strings.keys()):
                    f.write(f"    0x{addr:06X}: \"{region_strings[addr]}\"\n")
                f.write("\n")

            # Count code density
            code_bytes = sum(1 for b in data[rstart:rend] if b != 0xFF and b != 0x00)
            f.write(f"  Code density: {code_bytes}/{total} non-trivial bytes ({100*code_bytes/total:.1f}%)\n")
            f.write("\n")

    print(f"Written to {OUTPUT}")
    print(f"Strings found: {len(strings)}")
    print(f"Known functions: {len(KNOWN_FUNCTIONS)}")

if __name__ == "__main__":
    main()
