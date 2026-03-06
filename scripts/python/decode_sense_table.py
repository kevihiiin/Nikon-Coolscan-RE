#!/usr/bin/env python3
"""
Decode the sense translation table in the LS-50 firmware.

From the REQUEST SENSE handler analysis:
  0x0111F4: Subroutine builds SCSI sense response
  0x0111FC: mov.w #0x0005, R5     ; table entry stride = 5 bytes
  0x011200: [52 C5]               ; likely mulxu.b R12h, R5 -> R5 = sense_code * 5
  0x011202: add.l #0x00016DEE, ER5  ; ER5 = 0x16DEE + sense_code * 5
  0x011208: mov.b @ER5, R6h       ; Load flags byte from table entry

  The sense code (R1/R12) is an index into a 5-byte-per-entry table at 0x16DEE.

  The REQUEST SENSE handler (0x021866) is called with:
  - When 0x400877 != 0: R1 = 0x0052 (but this seems like an error code, not index)
  - Otherwise: uses the actual CDB buffer contents

  Wait - let me re-read the handler. At 0x0218C6 it loads R1 = 0x0052.
  Then at 0x0111FA: mov.w R1, R12 -> R12 = 0x0052
  Then: mulxu.b R12h, R5 -> R5 = R12h * 5 = 0x00 * 5 = 0
  That gives table base + 0, which is the first entry.

  Actually wait. R12 is a word register. R12h is the HIGH byte.
  0x0052 -> R12h = 0x00, R12l = 0x52

  52 C5: let me look at this more carefully.
  52 is 'mulxu.b Rd, Rs' ... actually no.
  In H8/300H: 50 xx = mulxu.b R0h, Rx... no.
  The H8/300H mulxu encoding:
    mulxu.b Rs, Rd: 50 sd  (multiply unsigned byte Rs * Rd -> Rd as word)
  So 52 C5: This is NOT a standard 2-byte instruction starting with 0x52.

  Actually 0x50 dd = mulxu.b, but 0x52 dd = mulxu.w.
  mulxu.w Rs, ERd: 52 sd
  52 C5 = mulxu.w R12, ER5 -> ER5 = R12 * R5

  So: ER5 = R12 * R5 = sense_code * 5

  Then add.l #0x16DEE, ER5 -> ER5 = sense_code * 5 + 0x16DEE

  THIS IS THE TABLE!

  The sense_code written to 0x4007B0 is used as the R1 parameter when calling 0x0111F4.
  Actually - let me re-read the REQUEST SENSE handler more carefully.

  Looking at the handler:
  0x0218AC: mov.b @0x400877, R4h   ; load additional sense flag
  0x0218B2: beq 0x0218BC           ; if zero, skip
  0x0218B4: mov.b @0x400880, R7h   ; load from 0x400880
  0x0218BA: bra 0x0218C2
  0x0218BC: mov.b @(1, ER4), R7h   ; load CDB[1] (ER4=0x4007B6, so CDB[1]=0x4007B7)
  0x0218C0: and.b #0xE0, R7h       ; mask upper 3 bits
  0x0218C2: cmp R7h, R7h           ; test if zero (actually mov.b R7h, R7h + test)
  0x0218C4: beq 0x0218D2           ; if zero, skip sense response build
  0x0218C6: mov.w #0x0052, R1      ; R1 = 0x0052 (the sense table index!)
  0x0218CA: mov.l ER5, ER0         ; ER0 = stack buffer
  0x0218CC: jsr @0x0111F4          ; Build sense response

  So when called from REQUEST SENSE, R1 = 0x0052.
  Table entry = 0x16DEE + 0x52 * 5 = 0x16DEE + 0x19A = 0x16F88

  But WAIT. The code writes 0x0050, 0x0053, etc. to 0x4007B0.
  The REQUEST SENSE handler doesn't pass the value at 0x4007B0 as R1!
  It hardcodes R1 = 0x0052.

  Let me re-examine... Actually the branch at 0x0218C4 goes to 0x0218D2
  if R7h is zero. 0x0218D2 is the OTHER path that just copies CDB data.

  So the path with R1=0x0052 is taken when @0x400877 or CDB[1]&0xE0 is non-zero.
  This seems like a REQUEST SENSE format indicator, not the error code index.

  Let me look at it from the OTHER direction: when handlers write to 0x4007B0,
  they write values like 0x0050. But 0x4007B0 is the "sense_code" field.
  The REQUEST SENSE handler ALSO has code that reads 0x4007B0 via ER3...

  Actually looking again at the disassembly:
  0x021870: mov.l #0x004007B0, ER3
  ...
  0x0218A2: mov.w #0x0050, R0
  0x0218A6: mov.w R0, @ER3         ; Write 0x0050 to 0x4007B0

  This writes 0x0050 to sense_code when CDB validation fails. It's the error path.

  The NORMAL path (0x0218AC onward) doesn't re-read 0x4007B0.
  Instead it checks 0x400877 and 0x400880.

  So the question is: WHO calls 0x0111F4 with different R1 values?
  And what is the table at 0x16DEE?

  Let's find ALL callers of 0x0111F4 and trace what R1 value they pass.
  Also let's dump the table at 0x16DEE.
"""

import struct
from pathlib import Path
from collections import defaultdict

FIRMWARE_PATH = Path(__file__).parent.parent.parent / "binaries" / "firmware" / "Nikon LS-50 MBM29F400B TSOP48.bin"

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
    # 1. Dump the sense translation table at 0x16DEE
    # ========================================================================
    print("=" * 90)
    print("SENSE TRANSLATION TABLE at 0x16DEE")
    print("=" * 90)
    print("""
Table entry format (5 bytes each):
  Byte 0: Flags (bit 7=deferred, bit 5=?, bit 4=?, bit 3=cmd_specific, bit 2=?, bit 1=?)
  Byte 1: Sense Key (standard SCSI SK 0x00-0x0B)
  Byte 2: ASC (Additional Sense Code)
  Byte 3: ASCQ (Additional Sense Code Qualifier)
  Byte 4: ??? (additional data, possibly FRU)

The index into this table is the internal sense code value written to 0x4007B0.
Table address = 0x16DEE + index * 5
""")

    base = 0x16DEE

    # Known internal sense codes from our earlier analysis
    known_codes = {
        0x0000: "NO SENSE / Good",
        0x0007: "HARDWARE ERROR",
        0x0008: "COMMUNICATION FAILURE",
        0x0009: "TRACK FOLLOWING ERROR",
        0x000A: "READ ERROR",
        0x000D: "MEDIUM REMOVAL REQUEST",
        0x0020: "DATA TRANSFER TIMEOUT",
        0x004E: "OVERLAPPED COMMANDS",
        0x004F: "VENDOR SPECIFIC (init)",
        0x0050: "ILLEGAL REQUEST",
        0x0051: "CMD NOT SUPPORTED",
        0x0052: "REQ SENSE OVERFLOW",
        0x0053: "INVALID PARAMETER",
        0x0055: "SCAN SEQUENCE ERROR",
        0x0056: "INVALID PERMISSION",
        0x0058: "SCAN OPERATION CONFLICT",
        0x0059: "INVALID MODE PAGE",
        0x0064: "SCAN OVERFLOW",
        0x0065: "SEND DATA FORMAT ERROR",
        0x0066: "DISPATCH RESERVATION",
        0x0068: "DISPATCH STATE ERROR",
        0x006F: "INTERNAL PROCESSING",
        0x0071: "SCAN TIMEOUT",
        0x0072: "DATA TRANSFER ERROR",
        0x0079: "MOTOR BUSY",
        0x007A: "CALIBRATION IN PROGRESS",
        0x0081: "MOTOR CONTROL ERROR",
        0x0092: "SCAN PARAMETER ERROR",
    }

    # Standard SCSI sense key names
    sk_names = {
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

    # Standard SCSI ASC/ASCQ meanings
    asc_meanings = {
        (0x00, 0x00): "No additional sense information",
        (0x04, 0x00): "Logical unit not ready, cause not reportable",
        (0x04, 0x01): "Logical unit is in process of becoming ready",
        (0x04, 0x02): "Logical unit not ready, initializing cmd required",
        (0x04, 0x04): "Logical unit not ready, format in progress",
        (0x15, 0x01): "Mechanical positioning error",
        (0x15, 0x02): "Positioning error detected by read of medium",
        (0x20, 0x00): "Invalid command operation code",
        (0x24, 0x00): "Invalid field in CDB",
        (0x25, 0x00): "Logical unit not supported",
        (0x26, 0x00): "Invalid field in parameter list",
        (0x26, 0x01): "Parameter not supported",
        (0x26, 0x02): "Parameter value invalid",
        (0x28, 0x00): "Not ready to ready change, medium may have changed",
        (0x29, 0x00): "Power on, reset, or bus device reset occurred",
        (0x2C, 0x00): "Command sequence error",
        (0x2C, 0x01): "Too many windows specified",
        (0x2C, 0x02): "Invalid combination of windows specified",
        (0x3A, 0x00): "Medium not present",
        (0x3D, 0x00): "Invalid bits in identify message",
        (0x43, 0x00): "Message error",
        (0x44, 0x00): "Internal target failure",
        (0x45, 0x00): "Select or reselect failure",
        (0x47, 0x00): "SCSI parity error",
        (0x48, 0x00): "Initiator detected error message received",
        (0x49, 0x00): "Invalid message error",
        (0x4E, 0x00): "Overlapped commands attempted",
        (0x60, 0x00): "Lamp failure",
        (0x62, 0x00): "Scan head positioning error",
        (0x80, 0x00): "Vendor specific",
    }

    print(f"{'Index':<8s} {'Flags':<8s} {'SK':<20s} {'ASC':<6s} {'ASCQ':<6s} {'FRU':<6s} {'ASC/ASCQ Meaning':<40s} {'Internal Name'}")
    print("-" * 160)

    # Dump entries for all indices from 0 to 0x9F
    max_idx = 0xA0
    for idx in range(max_idx):
        entry_addr = base + idx * 5
        if entry_addr + 5 > len(data):
            break

        flags = data[entry_addr]
        sk = data[entry_addr + 1]
        asc = data[entry_addr + 2]
        ascq = data[entry_addr + 3]
        fru = data[entry_addr + 4]

        # Skip all-zero entries (unless it's index 0)
        if flags == 0 and sk == 0 and asc == 0 and ascq == 0 and fru == 0 and idx > 0:
            continue

        sk_name = sk_names.get(sk, f"0x{sk:02X}")
        asc_meaning = asc_meanings.get((asc, ascq), "")
        internal_name = known_codes.get(idx, "")

        # Only print if the entry looks valid (SK <= 0x0B or has known flags)
        is_valid = sk <= 0x0B or idx in known_codes
        marker = "" if is_valid else " [?]"

        print(f"0x{idx:04X}   0x{flags:02X}     {sk_name:<20s} 0x{asc:02X}   0x{ascq:02X}   0x{fru:02X}   {asc_meaning:<40s} {internal_name}{marker}")

    # ========================================================================
    # 2. Now verify: dump raw hex of the table
    # ========================================================================
    print("\n\n" + "=" * 90)
    print("RAW TABLE HEX DUMP (0x16DEE - 0x170F0)")
    print("=" * 90)

    for i in range(0, min(0x300, len(data) - base), 16):
        addr = base + i
        chunk = data[addr:addr+16]
        # Mark every 5-byte boundary
        hex_parts = []
        for j, b in enumerate(chunk):
            entry_offset = (i + j) % 5
            if entry_offset == 0 and j > 0:
                hex_parts.append('|')
            hex_parts.append(f'{b:02X}')
        hex_str = ' '.join(hex_parts)
        ascii_part = ''.join(chr(b) if 32 <= b < 127 else '.' for b in chunk)
        print(f"  0x{addr:06X}: {hex_str:<60s} {ascii_part}")

    # ========================================================================
    # 3. Find ALL callers of 0x0111F4 and what R1 value they pass
    # ========================================================================
    print("\n\n" + "=" * 90)
    print("ALL CALLERS of 0x0111F4 (sense response builder)")
    print("=" * 90)

    # Search for jsr @0x0111F4 -> 5E 01 11 F4
    pattern = bytes([0x5E, 0x01, 0x11, 0xF4])
    for offset in find_all(data, pattern):
        # Look backward for mov.w #imm16, R1 (79 01 HH LL)
        r1_val = None
        for delta in range(4, 48, 2):
            check = offset - delta
            if check < 0:
                break
            if data[check] == 0x79 and data[check+1] == 0x01:
                r1_val = struct.unpack('>H', data[check+2:check+4])[0]
                break
            # Also check for mov.w Rn, R1 (0D n1)
            if data[check] == 0x0D and (data[check+1] & 0x0F) == 0x01:
                src = (data[check+1] >> 4) & 0xF
                r1_val = f"R{src} (dynamic)"
                break

        r1_str = f"0x{r1_val:04X}" if isinstance(r1_val, int) else str(r1_val) if r1_val else "unknown"

        # If R1 is an integer, look up the table entry
        entry_info = ""
        if isinstance(r1_val, int) and r1_val < max_idx:
            entry_addr = base + r1_val * 5
            if entry_addr + 5 <= len(data):
                sk = data[entry_addr + 1]
                asc = data[entry_addr + 2]
                ascq = data[entry_addr + 3]
                sk_name = sk_names.get(sk, f"0x{sk:02X}")
                entry_info = f" -> SK={sk_name}, ASC=0x{asc:02X}, ASCQ=0x{ascq:02X}"

        print(f"  0x{offset:06X}: jsr @0x0111F4, R1={r1_str}{entry_info}")

    # ========================================================================
    # 4. Now find ALL callers of ANOTHER key subroutine that may set sense
    # Look for the subroutine that writes to @0x400877 (the sense flag address)
    # ========================================================================
    print("\n\n" + "=" * 90)
    print("Writes to 0x400877 (additional sense code flag)")
    print("=" * 90)

    # Search for the address bytes 00 40 08 77
    addr877 = bytes([0x00, 0x40, 0x08, 0x77])
    for reg in range(8):
        pattern = bytes([0x7A, 0x00 | reg]) + addr877
        for offset in find_all(data, pattern):
            print(f"  0x{offset:06X}: mov.l #0x00400877, ER{reg}")

    # Also search for mov.b to absolute 0x400877
    # 6A 8x 00 40 08 77
    for r in range(16):
        # 6A A0+r 00 40 08 77 (24-bit abs write)
        pattern = bytes([0x6A, 0xA0 | r]) + addr877
        for offset in find_all(data, pattern):
            rn = f"R{r>>1}{'h' if r%2==0 else 'l'}"
            print(f"  0x{offset:06X}: mov.b {rn}, @0x00400877")

    # ========================================================================
    # 5. Writes to 0x400880
    # ========================================================================
    print("\n\n" + "=" * 90)
    print("Writes to 0x400880 (sense byte)")
    print("=" * 90)

    addr880 = bytes([0x00, 0x40, 0x08, 0x80])
    for reg in range(8):
        pattern = bytes([0x7A, 0x00 | reg]) + addr880
        for offset in find_all(data, pattern):
            print(f"  0x{offset:06X}: mov.l #0x00400880, ER{reg}")

    for r in range(16):
        pattern = bytes([0x6A, 0xA0 | r]) + addr880
        for offset in find_all(data, pattern):
            rn = f"R{r>>1}{'h' if r%2==0 else 'l'}"
            print(f"  0x{offset:06X}: mov.b {rn}, @0x00400880")

    # ========================================================================
    # 6. Most importantly - which internal codes are ACTUALLY written to 0x4007B0?
    #    For each handler, what values does it write?
    # ========================================================================
    print("\n\n" + "=" * 90)
    print("COMPLETE CATALOG: Internal sense codes written to 0x4007B0")
    print("=" * 90)
    print("""
For each known sense code value, look up its translation table entry.
This gives us the final SCSI sense data that the host receives.
""")

    # Collect all confirmed sense code values from our first script
    confirmed_codes = [
        0x0000, 0x0007, 0x0008, 0x0009, 0x000A, 0x000D,
        0x0020, 0x004E, 0x004F, 0x0050, 0x0051, 0x0052, 0x0053,
        0x0055, 0x0056, 0x0058, 0x0059,
        0x0064, 0x0065, 0x0066, 0x0068, 0x006F,
        0x0071, 0x0072, 0x0079, 0x007A, 0x0081, 0x0092,
    ]

    print(f"\n{'IntCode':<10s} {'SK':<6s} {'ASC':<6s} {'ASCQ':<6s} {'Flags':<8s} {'FRU':<6s} {'Sense Key Name':<20s} {'ASC/ASCQ Meaning':<40s} {'Internal Name'}")
    print("-" * 170)

    for code in confirmed_codes:
        if code < max_idx:
            entry_addr = base + code * 5
            if entry_addr + 5 <= len(data):
                flags = data[entry_addr]
                sk = data[entry_addr + 1]
                asc = data[entry_addr + 2]
                ascq = data[entry_addr + 3]
                fru = data[entry_addr + 4]

                sk_name = sk_names.get(sk, f"0x{sk:02X}")
                asc_meaning = asc_meanings.get((asc, ascq), f"Vendor: 0x{asc:02X}/0x{ascq:02X}")
                int_name = known_codes.get(code, "")

                print(f"0x{code:04X}     0x{sk:02X}   0x{asc:02X}   0x{ascq:02X}   0x{flags:02X}     0x{fru:02X}   {sk_name:<20s} {asc_meaning:<40s} {int_name}")
            else:
                print(f"0x{code:04X}     (out of table range)")
        else:
            print(f"0x{code:04X}     (index too large for table)")


if __name__ == "__main__":
    main()
