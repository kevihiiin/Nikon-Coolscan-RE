#!/usr/bin/env python3
"""
Use radare2 to disassemble all code regions of the LS-50 firmware.
Produces per-region assembly files.
"""
import subprocess
import os

FIRMWARE = "binaries/firmware/Nikon LS-50 MBM29F400B TSOP48.bin"
OUTDIR = "ghidra/exports/firmware_disasm"

# Code regions to disassemble
CODE_REGIONS = [
    (0x00100, 0x001A0, "boot_code"),
    (0x001A0, 0x004000, "early_init"),
    (0x010000, 0x020000, "recovery_firmware"),
    (0x020000, 0x030000, "main_fw_part1"),
    (0x030000, 0x040000, "main_fw_part2"),
    (0x040000, 0x045000, "main_fw_part3"),
    (0x045000, 0x04A000, "data_tables_1"),
    (0x04A000, 0x050000, "data_tables_2"),
    (0x050000, 0x05A000, "late_code"),
]

def r2_disasm(start, end, name):
    """Use r2 to disassemble a region."""
    size = end - start
    outfile = os.path.join(OUTDIR, f"{name}_0x{start:05X}_0x{end:05X}.asm")

    # r2 command: open binary, seek to offset, print disassembly
    r2_cmds = f"""
e asm.arch=h8300
e asm.bits=16
e cfg.bigendian=true
e scr.color=0
e asm.lines=false
s {start}
pd {size // 2}
"""
    try:
        result = subprocess.run(
            ["r2", "-q", "-c", r2_cmds.strip().replace('\n', ';'), FIRMWARE],
            capture_output=True, text=True, timeout=60
        )
        with open(outfile, "w") as f:
            f.write(f"; === {name} (0x{start:06X} - 0x{end:06X}) ===\n")
            f.write(f"; Size: {size} bytes\n")
            f.write(f"; NOTE: r2 h8300 is 16-bit only. 32-bit H8/300H ops may show as invalid.\n")
            f.write(f"; Use Ghidra H8/300H SLEIGH for authoritative disassembly.\n\n")
            f.write(result.stdout)
        print(f"  {name}: {len(result.stdout.splitlines())} lines")
        return True
    except Exception as e:
        print(f"  {name}: ERROR - {e}")
        return False

def main():
    os.makedirs(OUTDIR, exist_ok=True)
    print(f"Disassembling {FIRMWARE} into {OUTDIR}/")

    for start, end, name in CODE_REGIONS:
        r2_disasm(start, end, name)

    print("\nDone. Use Ghidra exports for authoritative H8/300H decompilation.")

if __name__ == "__main__":
    main()
