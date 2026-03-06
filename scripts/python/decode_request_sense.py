#!/usr/bin/env python3
"""
Decode the REQUEST SENSE handler (0x021866) and its subroutine (0x0111F4)
to understand how the firmware translates its internal 16-bit sense code
at 0x4007B0 into standard SCSI sense data (SK/ASC/ASCQ).

Also: dump the subroutine at 0x0111F4 which is called by REQUEST SENSE
and likely does the translation. Then trace ALL paths that write sense codes.
"""

import struct
from pathlib import Path

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


def disasm_h8_basic(data, start, end):
    """Basic H8/300H disassembler for the most common instructions.
    This is NOT a full disassembler — just enough to trace sense code logic.
    """
    pos = start
    lines = []
    while pos < end:
        b0 = data[pos]

        # 2-byte instructions
        if pos + 2 <= end:
            b1 = data[pos + 1]
            insn_bytes = f"{b0:02X} {b1:02X}"

            # nop: 00 00
            if b0 == 0x00 and b1 == 0x00:
                lines.append((pos, 2, insn_bytes, "nop"))
                pos += 2; continue

            # rts: 54 70
            if b0 == 0x54 and b1 == 0x70:
                lines.append((pos, 2, insn_bytes, "rts"))
                pos += 2; continue

            # rte: 56 70
            if b0 == 0x56 and b1 == 0x70:
                lines.append((pos, 2, insn_bytes, "rte"))
                pos += 2; continue

            # mov.b Rs, Rd: 0C ss+dd
            if b0 == 0x0C:
                src = (b1 >> 4) & 0xF
                dst = b1 & 0xF
                rs = f"R{src>>1}{'h' if src%2==0 else 'l'}"
                rd = f"R{dst>>1}{'h' if dst%2==0 else 'l'}"
                lines.append((pos, 2, insn_bytes, f"mov.b {rs}, {rd}"))
                pos += 2; continue

            # mov.w Rs, Rd: 0D ss+dd
            if b0 == 0x0D:
                src = (b1 >> 4) & 0xF
                dst = b1 & 0xF
                lines.append((pos, 2, insn_bytes, f"mov.w R{src}, R{dst}"))
                pos += 2; continue

            # mov.l ERs, ERd: 0F ss+dd
            if b0 == 0x0F:
                src = (b1 >> 4) & 0x7
                dst = b1 & 0x7
                lines.append((pos, 2, insn_bytes, f"mov.l ER{src}, ER{dst}"))
                pos += 2; continue

            # add.b Rs, Rd: 08 sd
            if b0 == 0x08:
                src = (b1 >> 4) & 0xF
                dst = b1 & 0xF
                rs = f"R{src>>1}{'h' if src%2==0 else 'l'}"
                rd = f"R{dst>>1}{'h' if dst%2==0 else 'l'}"
                lines.append((pos, 2, insn_bytes, f"add.b {rs}, {rd}"))
                pos += 2; continue

            # addx.b #imm, Rd: 90+d imm
            if (b0 & 0xF0) == 0x90:
                rd = b0 & 0xF
                lines.append((pos, 2, insn_bytes, f"addx.b #0x{b1:02X}, R{rd>>1}{'h' if rd%2==0 else 'l'}"))
                pos += 2; continue

            # sub.w Rs, Rd: 19 sd
            if b0 == 0x19:
                src = (b1 >> 4) & 0xF
                dst = b1 & 0xF
                lines.append((pos, 2, insn_bytes, f"sub.w R{src}, R{dst}"))
                pos += 2; continue

            # cmp.b #imm, Rd: A0+d imm
            if (b0 & 0xF0) == 0xA0:
                rd = b0 & 0xF
                rn = f"R{rd>>1}{'h' if rd%2==0 else 'l'}"
                lines.append((pos, 2, insn_bytes, f"cmp.b #0x{b1:02X}, {rn}"))
                pos += 2; continue

            # mov.b #imm, Rd: F0+d imm
            if (b0 & 0xF0) == 0xF0:
                rd = b0 & 0xF
                rn = f"R{rd>>1}{'h' if rd%2==0 else 'l'}"
                lines.append((pos, 2, insn_bytes, f"mov.b #0x{b1:02X}, {rn}"))
                pos += 2; continue

            # and.b #imm, Rd: E0+d imm
            if (b0 & 0xF0) == 0xE0:
                rd = b0 & 0xF
                rn = f"R{rd>>1}{'h' if rd%2==0 else 'l'}"
                lines.append((pos, 2, insn_bytes, f"and.b #0x{b1:02X}, {rn}"))
                pos += 2; continue

            # or.b #imm, Rd: C0+d imm
            if (b0 & 0xF0) == 0xC0:
                rd = b0 & 0xF
                rn = f"R{rd>>1}{'h' if rd%2==0 else 'l'}"
                lines.append((pos, 2, insn_bytes, f"or.b #0x{b1:02X}, {rn}"))
                pos += 2; continue

            # xor.b Rs, Rd: 15 sd
            if b0 == 0x15:
                src = (b1 >> 4) & 0xF
                dst = b1 & 0xF
                rs = f"R{src>>1}{'h' if src%2==0 else 'l'}"
                rd = f"R{dst>>1}{'h' if dst%2==0 else 'l'}"
                lines.append((pos, 2, insn_bytes, f"xor.b {rs}, {rd}"))
                pos += 2; continue

            # and.w Rs, Rd: 16 sd
            if b0 == 0x16:
                src = (b1 >> 4) & 0xF
                dst = b1 & 0xF
                lines.append((pos, 2, insn_bytes, f"and.w R{src}, R{dst}"))
                pos += 2; continue

            # or.w Rs, Rd: 14 sd (guess)
            # Actually, let me skip less common ones

            # cmp.b Rs, Rd: 1C sd
            if b0 == 0x1C:
                src = (b1 >> 4) & 0xF
                dst = b1 & 0xF
                rs = f"R{src>>1}{'h' if src%2==0 else 'l'}"
                rd = f"R{dst>>1}{'h' if dst%2==0 else 'l'}"
                lines.append((pos, 2, insn_bytes, f"cmp.b {rs}, {rd}"))
                pos += 2; continue

            # cmp.w Rs, Rd: 1D sd
            if b0 == 0x1D:
                src = (b1 >> 4) & 0xF
                dst = b1 & 0xF
                lines.append((pos, 2, insn_bytes, f"cmp.w R{src}, R{dst}"))
                pos += 2; continue

            # mov.b @ERs, Rd: 68 0s+d (load byte from address in ERs)
            if b0 == 0x68:
                if (b1 & 0x80) == 0:  # load
                    src_er = (b1 >> 4) & 0x7
                    dst = b1 & 0xF
                    rd = f"R{dst>>1}{'h' if dst%2==0 else 'l'}"
                    lines.append((pos, 2, insn_bytes, f"mov.b @ER{src_er}, {rd}"))
                else:  # store
                    dst_er = (b1 >> 4) & 0x7
                    src = b1 & 0xF
                    rs = f"R{src>>1}{'h' if src%2==0 else 'l'}"
                    lines.append((pos, 2, insn_bytes, f"mov.b {rs}, @ER{dst_er}"))
                pos += 2; continue

            # mov.w @ERs, Rd: 69 0s+d (load word)
            if b0 == 0x69:
                if (b1 & 0x80) == 0:  # load
                    src_er = (b1 >> 4) & 0x7
                    dst = b1 & 0xF
                    lines.append((pos, 2, insn_bytes, f"mov.w @ER{src_er}, R{dst}"))
                else:  # store
                    dst_er = (b1 >> 4) & 0x7
                    src = b1 & 0xF
                    lines.append((pos, 2, insn_bytes, f"mov.w R{src}, @ER{dst_er}"))
                pos += 2; continue

            # bcc d:8 (branch instructions): 40-4F
            if (b0 & 0xF0) == 0x40:
                cc_names = ["bra","brn","bhi","bls","bcc","bcs","bne","beq",
                           "bvc","bvs","bpl","bmi","bge","blt","bgt","ble"]
                cc = b0 & 0x0F
                disp = struct.unpack('b', bytes([b1]))[0]
                target = pos + 2 + disp
                lines.append((pos, 2, insn_bytes, f"{cc_names[cc]} 0x{target:06X}"))
                pos += 2; continue

            # add.b #imm, Rd: 80+d imm
            if (b0 & 0xF0) == 0x80:
                rd = b0 & 0xF
                rn = f"R{rd>>1}{'h' if rd%2==0 else 'l'}"
                lines.append((pos, 2, insn_bytes, f"add.b #0x{b1:02X}, {rn}"))
                pos += 2; continue

            # not.b Rd: 17 0d
            if b0 == 0x17:
                dst = b1 & 0xF
                src = (b1 >> 4) & 0xF
                if src == 0:
                    rn = f"R{dst>>1}{'h' if dst%2==0 else 'l'}"
                    lines.append((pos, 2, insn_bytes, f"not.b {rn}"))
                else:
                    lines.append((pos, 2, insn_bytes, f"not/extu.w R{dst}  [17 {b1:02X}]"))
                pos += 2; continue

            # btst #imm3, Rd: 73 [imm3]d
            if b0 == 0x73:
                bit = (b1 >> 4) & 0x7
                rd = b1 & 0xF
                rn = f"R{rd>>1}{'h' if rd%2==0 else 'l'}"
                lines.append((pos, 2, insn_bytes, f"btst #{bit}, {rn}"))
                pos += 2; continue

            # bset/bclr: 70-77 range
            if b0 == 0x70:
                bit = (b1 >> 4) & 0x7
                rd = b1 & 0xF
                rn = f"R{rd>>1}{'h' if rd%2==0 else 'l'}"
                lines.append((pos, 2, insn_bytes, f"bset #{bit}, {rn}"))
                pos += 2; continue
            if b0 == 0x72:
                bit = (b1 >> 4) & 0x7
                rd = b1 & 0xF
                rn = f"R{rd>>1}{'h' if rd%2==0 else 'l'}"
                lines.append((pos, 2, insn_bytes, f"bclr #{bit}, {rn}"))
                pos += 2; continue

            # rotl/rotr/shlr/shll: 10-13
            if b0 == 0x10:
                rd = b1 & 0xF
                rn = f"R{rd>>1}{'h' if rd%2==0 else 'l'}"
                lines.append((pos, 2, insn_bytes, f"shll.b {rn}"))
                pos += 2; continue
            if b0 == 0x11:
                rd = b1 & 0xF
                rn = f"R{rd>>1}{'h' if rd%2==0 else 'l'}"
                lines.append((pos, 2, insn_bytes, f"shlr.b {rn}"))
                pos += 2; continue
            if b0 == 0x12:
                rd = b1 & 0xF
                rn = f"R{rd>>1}{'h' if rd%2==0 else 'l'}"
                lines.append((pos, 2, insn_bytes, f"rotxl.b {rn}"))
                pos += 2; continue
            if b0 == 0x13:
                rd = b1 & 0xF
                rn = f"R{rd>>1}{'h' if rd%2==0 else 'l'}"
                lines.append((pos, 2, insn_bytes, f"rotxr.b {rn}"))
                pos += 2; continue

            # sub.b Rs, Rd: 18 sd
            if b0 == 0x18:
                src = (b1 >> 4) & 0xF
                dst = b1 & 0xF
                rs = f"R{src>>1}{'h' if src%2==0 else 'l'}"
                rd = f"R{dst>>1}{'h' if dst%2==0 else 'l'}"
                lines.append((pos, 2, insn_bytes, f"sub.b {rs}, {rd}"))
                pos += 2; continue

            # add.w Rs, Rd: 09 sd
            if b0 == 0x09:
                src = (b1 >> 4) & 0xF
                dst = b1 & 0xF
                lines.append((pos, 2, insn_bytes, f"add.w R{src}, R{dst}"))
                pos += 2; continue

            # 01 00 = prefix for some extended instructions, skip
            if b0 == 0x01 and b1 == 0x00:
                if pos + 4 <= end:
                    b2, b3 = data[pos+2], data[pos+3]
                    extra = f"{b2:02X} {b3:02X}"
                    # 01 00 6B xx = mov.l with 32-bit abs addr
                    if b2 == 0x69:
                        if (b3 & 0x80) == 0:
                            src_er = (b3 >> 4) & 0x7
                            dst = b3 & 0x7
                            lines.append((pos, 4, f"{insn_bytes} {extra}", f"mov.l @ER{src_er}, ER{dst}"))
                        else:
                            dst_er = (b3 >> 4) & 0x7
                            src = b3 & 0x7
                            lines.append((pos, 4, f"{insn_bytes} {extra}", f"mov.l ER{src}, @ER{dst_er}"))
                        pos += 4; continue
                    if b2 == 0x6F:
                        if pos + 6 <= end:
                            d16 = struct.unpack('>h', data[pos+4:pos+6])[0]
                            if (b3 & 0x80) == 0:
                                src_er = (b3 >> 4) & 0x7
                                dst = b3 & 0x7
                                lines.append((pos, 6, f"{insn_bytes} {extra} {data[pos+4]:02X} {data[pos+5]:02X}", f"mov.l @(0x{d16 & 0xFFFF:04X}, ER{src_er}), ER{dst}"))
                            else:
                                dst_er = (b3 >> 4) & 0x7
                                src = b3 & 0x7
                                lines.append((pos, 6, f"{insn_bytes} {extra} {data[pos+4]:02X} {data[pos+5]:02X}", f"mov.l ER{src}, @(0x{d16 & 0xFFFF:04X}, ER{dst_er})"))
                            pos += 6; continue
                    lines.append((pos, 4, f"{insn_bytes} {extra}", f"[prefix] 01 00 {extra}"))
                    pos += 4; continue

            # 0A xx: various (inc, add.l)
            if b0 == 0x0A:
                dst = b1 & 0xF
                src = (b1 >> 4) & 0xF
                if src == 0:
                    rn = f"R{dst>>1}{'h' if dst%2==0 else 'l'}"
                    lines.append((pos, 2, insn_bytes, f"inc.b {rn}"))
                else:
                    lines.append((pos, 2, insn_bytes, f"add.l ER{src}, ER{dst} (or inc) [{b0:02X} {b1:02X}]"))
                pos += 2; continue

            # 1A xx: various (dec, sub.l)
            if b0 == 0x1A:
                dst = b1 & 0xF
                src = (b1 >> 4) & 0xF
                if src == 0:
                    rn = f"R{dst>>1}{'h' if dst%2==0 else 'l'}"
                    lines.append((pos, 2, insn_bytes, f"dec.b {rn}"))
                else:
                    lines.append((pos, 2, insn_bytes, f"sub.l ER{src}, ER{dst} (or dec) [{b0:02X} {b1:02X}]"))
                pos += 2; continue

        # 4-byte instructions
        if pos + 4 <= end:
            b0, b1, b2, b3 = data[pos], data[pos+1], data[pos+2], data[pos+3]

            # jsr @aa:24: 5E aa aa aa
            if b0 == 0x5E:
                addr24 = (b1 << 16) | (b2 << 8) | b3
                insn_bytes = f"{b0:02X} {b1:02X} {b2:02X} {b3:02X}"
                lines.append((pos, 4, insn_bytes, f"jsr @0x{addr24:06X}"))
                pos += 4; continue

            # jmp @aa:24: 5A aa aa aa
            if b0 == 0x5A:
                addr24 = (b1 << 16) | (b2 << 8) | b3
                insn_bytes = f"{b0:02X} {b1:02X} {b2:02X} {b3:02X}"
                lines.append((pos, 4, insn_bytes, f"jmp @0x{addr24:06X}"))
                pos += 4; continue

            # jsr @ERn: 5D n0
            if b0 == 0x5D:
                reg = (b1 >> 4) & 0x7
                insn_bytes = f"{b0:02X} {b1:02X}"
                lines.append((pos, 2, insn_bytes, f"jsr @ER{reg}"))
                pos += 2; continue

            # mov.w #imm16, Rn: 79 0n HH LL
            if b0 == 0x79 and (b1 & 0xF0) == 0x00:
                reg = b1 & 0xF
                imm16 = struct.unpack('>H', data[pos+2:pos+4])[0]
                insn_bytes = f"{b0:02X} {b1:02X} {b2:02X} {b3:02X}"
                lines.append((pos, 4, insn_bytes, f"mov.w #0x{imm16:04X}, R{reg}"))
                pos += 4; continue

            # cmp.w #imm16, Rn: 79 2n HH LL
            if b0 == 0x79 and (b1 & 0xF0) == 0x20:
                reg = b1 & 0xF
                imm16 = struct.unpack('>H', data[pos+2:pos+4])[0]
                insn_bytes = f"{b0:02X} {b1:02X} {b2:02X} {b3:02X}"
                lines.append((pos, 4, insn_bytes, f"cmp.w #0x{imm16:04X}, R{reg}"))
                pos += 4; continue

            # add.l #imm16, ERn: 7A 1n HH LL (actually add.w sign-extended?)
            # Actually: mov.w Rs, @(d:16, ERd): 6F sd dd dd
            if b0 == 0x6F:
                d16 = struct.unpack('>h', data[pos+2:pos+4])[0]
                if (b1 & 0x80) == 0:  # load
                    src_er = (b1 >> 4) & 0x7
                    dst = b1 & 0xF
                    insn_bytes = f"{b0:02X} {b1:02X} {b2:02X} {b3:02X}"
                    lines.append((pos, 4, insn_bytes, f"mov.w @(0x{d16 & 0xFFFF:04X}, ER{src_er}), R{dst}"))
                else:  # store
                    dst_er = (b1 >> 4) & 0x7
                    src = b1 & 0xF
                    insn_bytes = f"{b0:02X} {b1:02X} {b2:02X} {b3:02X}"
                    lines.append((pos, 4, insn_bytes, f"mov.w R{src}, @(0x{d16 & 0xFFFF:04X}, ER{dst_er})"))
                pos += 4; continue

            # mov.b Rs, @(d:16, ERd): 6E sd dd dd
            if b0 == 0x6E:
                d16 = struct.unpack('>h', data[pos+2:pos+4])[0]
                if (b1 & 0x80) == 0:  # load
                    src_er = (b1 >> 4) & 0x7
                    dst = b1 & 0xF
                    rd = f"R{dst>>1}{'h' if dst%2==0 else 'l'}"
                    insn_bytes = f"{b0:02X} {b1:02X} {b2:02X} {b3:02X}"
                    lines.append((pos, 4, insn_bytes, f"mov.b @(0x{d16 & 0xFFFF:04X}, ER{src_er}), {rd}"))
                else:  # store
                    dst_er = (b1 >> 4) & 0x7
                    src = b1 & 0xF
                    rs = f"R{src>>1}{'h' if src%2==0 else 'l'}"
                    insn_bytes = f"{b0:02X} {b1:02X} {b2:02X} {b3:02X}"
                    lines.append((pos, 4, insn_bytes, f"mov.b {rs}, @(0x{d16 & 0xFFFF:04X}, ER{dst_er})"))
                pos += 4; continue

            # mov.b @aa:16, Rd: 6A 0d aa aa  or  mov.b Rd, @aa:16: 6A 8d aa aa
            if b0 == 0x6A:
                if (b1 & 0x80) == 0:  # load
                    dst = b1 & 0xF
                    addr16 = struct.unpack('>H', data[pos+2:pos+4])[0]
                    rd = f"R{dst>>1}{'h' if dst%2==0 else 'l'}"
                    insn_bytes = f"{b0:02X} {b1:02X} {b2:02X} {b3:02X}"
                    lines.append((pos, 4, insn_bytes, f"mov.b @0x{addr16:04X}, {rd}"))
                    # Check for extended 24-bit form: 6A 2d aa aa aa aa
                    if (b1 & 0xF0) == 0x20 and pos + 6 <= end:
                        addr24 = struct.unpack('>I', data[pos+2:pos+6])[0]
                        insn_bytes = ' '.join(f"{data[pos+i]:02X}" for i in range(6))
                        lines[-1] = (pos, 6, insn_bytes, f"mov.b @0x{addr24:08X}, R{dst>>1}{'h' if dst%2==0 else 'l'}")
                        pos += 6; continue
                    if (b1 & 0xF0) == 0x00:
                        pos += 4; continue
                else:  # store
                    dst = b1 & 0xF
                    addr16 = struct.unpack('>H', data[pos+2:pos+4])[0]
                    rs = f"R{dst>>1}{'h' if dst%2==0 else 'l'}"
                    insn_bytes = f"{b0:02X} {b1:02X} {b2:02X} {b3:02X}"
                    if (b1 & 0xF0) == 0xA0 and pos + 6 <= end:
                        addr24 = struct.unpack('>I', data[pos+2:pos+6])[0]
                        src = b1 & 0xF
                        rs = f"R{src>>1}{'h' if src%2==0 else 'l'}"
                        insn_bytes = ' '.join(f"{data[pos+i]:02X}" for i in range(6))
                        lines.append((pos, 6, insn_bytes, f"mov.b {rs}, @0x{addr24:08X}"))
                        pos += 6; continue
                    if (b1 & 0xF0) == 0x80:
                        lines.append((pos, 4, insn_bytes, f"mov.b {rs}, @0x{addr16:04X}"))
                        pos += 4; continue
                lines.append((pos, 4, insn_bytes, f"[6A {b1:02X}] ??"))
                pos += 4; continue

        # 6-byte instructions
        if pos + 6 <= end:
            b0, b1 = data[pos], data[pos + 1]

            # mov.l #imm32, ERn: 7A 0n HH HH LL LL
            if b0 == 0x7A and (b1 & 0xF0) == 0x00:
                reg = b1 & 0x0F
                imm32 = struct.unpack('>I', data[pos+2:pos+6])[0]
                insn_bytes = ' '.join(f"{data[pos+i]:02X}" for i in range(6))
                lines.append((pos, 6, insn_bytes, f"mov.l #0x{imm32:08X}, ER{reg}"))
                pos += 6; continue

            # add.l #imm32, ERn: 7A 1n HH HH LL LL
            if b0 == 0x7A and (b1 & 0xF0) == 0x10:
                reg = b1 & 0x0F
                imm32 = struct.unpack('>I', data[pos+2:pos+6])[0]
                insn_bytes = ' '.join(f"{data[pos+i]:02X}" for i in range(6))
                lines.append((pos, 6, insn_bytes, f"add.l #0x{imm32:08X}, ER{reg}"))
                pos += 6; continue

            # cmp.l #imm32, ERn: 7A 2n HH HH LL LL
            if b0 == 0x7A and (b1 & 0xF0) == 0x20:
                reg = b1 & 0x0F
                imm32 = struct.unpack('>I', data[pos+2:pos+6])[0]
                insn_bytes = ' '.join(f"{data[pos+i]:02X}" for i in range(6))
                lines.append((pos, 6, insn_bytes, f"cmp.l #0x{imm32:08X}, ER{reg}"))
                pos += 6; continue

            # sub.l #imm32, ERn: 7A 3n HH HH LL LL
            if b0 == 0x7A and (b1 & 0xF0) == 0x30:
                reg = b1 & 0x0F
                imm32 = struct.unpack('>I', data[pos+2:pos+6])[0]
                insn_bytes = ' '.join(f"{data[pos+i]:02X}" for i in range(6))
                lines.append((pos, 6, insn_bytes, f"sub.l #0x{imm32:08X}, ER{reg}"))
                pos += 6; continue

        # Fallback: unknown 2-byte
        if pos + 2 <= end:
            b0, b1 = data[pos], data[pos + 1]
            lines.append((pos, 2, f"{b0:02X} {b1:02X}", f"db 0x{b0:02X}, 0x{b1:02X}"))
            pos += 2
        else:
            lines.append((pos, 1, f"{data[pos]:02X}", f"db 0x{data[pos]:02X}"))
            pos += 1

    return lines


def main():
    data = FIRMWARE_PATH.read_bytes()

    print("=" * 90)
    print("REQUEST SENSE Handler Disassembly (0x021866)")
    print("=" * 90)

    lines = disasm_h8_basic(data, 0x021866, 0x02194A)
    for addr, size, bytez, text in lines:
        print(f"  0x{addr:06X}: {bytez:<24s}  {text}")

    print("\n\n" + "=" * 90)
    print("Subroutine 0x0111F4 (called by REQUEST SENSE)")
    print("=" * 90)
    print("This likely does the sense code -> response translation.")

    # Find the end of this subroutine (first rts after start)
    end_0111f4 = 0x0111F4
    for i in range(0x0111F4, min(0x0111F4 + 512, len(data)), 2):
        if data[i] == 0x54 and data[i+1] == 0x70:
            end_0111f4 = i + 2
            break

    lines = disasm_h8_basic(data, 0x0111F4, end_0111f4)
    for addr, size, bytez, text in lines:
        print(f"  0x{addr:06X}: {bytez:<24s}  {text}")

    # Now let's examine any subroutines called from 0x0111F4
    print("\n\n" + "=" * 90)
    print("Subroutine 0x016458 (push_context) and 0x016436 (pop_context)")
    print("=" * 90)

    for sub_addr in [0x016458, 0x016436]:
        sub_end = sub_addr
        for i in range(sub_addr, min(sub_addr + 64, len(data)), 2):
            if data[i] == 0x54 and data[i+1] == 0x70:
                sub_end = i + 2
                break
        print(f"\n  --- 0x{sub_addr:06X} ---")
        lines = disasm_h8_basic(data, sub_addr, sub_end)
        for addr, size, bytez, text in lines:
            print(f"  0x{addr:06X}: {bytez:<24s}  {text}")

    # ========================================================================
    # Now let's look for a SENSE DATA TABLE
    # The REQUEST SENSE handler calls 0x0111F4 which should build the response
    # Let's also dump the area at 0x4007B0 context - maybe there's a lookup
    # mechanism via additional RAM fields
    # ========================================================================

    print("\n\n" + "=" * 90)
    print("Comprehensive sense code cross-reference")
    print("=" * 90)

    # Let me look at all mov.w instructions that write to 0x4007B0 register
    # AND the subsequent code that reads them in REQUEST SENSE

    # The KEY observation from the REQUEST SENSE handler hex is:
    # 0x021870: mov.l #0x004007B0, ER3  -- loads sense addr into ER3
    # 0x021876: mov.l #0x004007B6, ER4  -- loads CDB addr into ER4
    # Then it reads from ER4 (CDB) and ER3 (sense code)
    # 0x0218A6: 69 B0 -> mov.w R0, @ER3  -- writes sense code (0x0050)
    # 0x0218CC: jsr @0x0111F4  -- calls the translation subroutine

    # So 0x0111F4 is the key. Let's also look at what it accesses
    # The handler sets up ER3 = 0x4007B0, and 0x0111F4 probably uses it

    # Let's also check the dispatch's common sense-writing pattern
    # We know from the first script that MANY handlers call a common path
    # that loads 0x4007B0 and writes to it. Let's find that pattern.

    print("\n\nAll handlers writing to sense address, with traced values:")
    print("=" * 90)

    # Find all mov.l #0x4007B0, ERn and trace forward to the write
    for reg in range(8):
        pattern = bytes([0x7A, 0x00 | reg]) + bytes([0x00, 0x40, 0x07, 0xB0])
        for offset in find_all(data, pattern):
            # Only in code regions
            if not (0x010000 <= offset <= 0x017FFF or 0x020000 <= offset <= 0x052FFF):
                continue

            # Disassemble from this point forward to find the write pattern
            mini_end = min(offset + 48, len(data))
            mini_lines = disasm_h8_basic(data, offset, mini_end)

            # Find writes through ERn
            for addr, size, bytez, text in mini_lines:
                if f"@ER{reg}" in text and ("mov.w" in text or "mov.b" in text) and "," in text:
                    # This is a write to the sense address
                    # Now look for the value source
                    pass

    # ========================================================================
    # MOST IMPORTANT: Look at subroutine 0x0111F4 more carefully
    # This appears to be the sense response builder
    # ========================================================================
    print("\n" + "=" * 90)
    print("EXTENDED: Subroutine 0x0111F4 and callees (sense response builder)")
    print("=" * 90)

    # Disassemble 0x0111F4 to its end
    # First find all rts instructions to know the function boundary
    # May have branches/loops so just disassemble a big chunk
    print("\n  --- 0x0111F4 extended disassembly ---")
    lines = disasm_h8_basic(data, 0x0111F4, 0x011300)
    for addr, size, bytez, text in lines:
        print(f"  0x{addr:06X}: {bytez:<24s}  {text}")

    # Let's also look at the function at 0x011304 which might be related
    # (from the pattern of shared module sense functions)
    print("\n  --- 0x011304 (potential sense helper) ---")
    sub_end = 0x011304
    for i in range(0x011304, min(0x011304 + 256, len(data)), 2):
        if data[i] == 0x54 and data[i+1] == 0x70:
            sub_end = i + 2
            break
    lines = disasm_h8_basic(data, 0x011304, sub_end)
    for addr, size, bytez, text in lines:
        print(f"  0x{addr:06X}: {bytez:<24s}  {text}")

    # ========================================================================
    # LOOK FOR SENSE DATA TABLES referenced by the subroutine
    # ========================================================================
    print("\n" + "=" * 90)
    print("Data tables referenced by sense handler subroutines")
    print("=" * 90)

    # Find all mov.l instructions in 0x0111F4-0x011300 that load data addresses
    for pos in range(0x0111F4, 0x011300 - 6, 2):
        if data[pos] == 0x7A and (data[pos+1] & 0xF0) == 0x00:
            reg = data[pos+1] & 0x0F
            addr = struct.unpack('>I', data[pos+2:pos+6])[0]
            if 0x020000 <= addr < 0x053000:
                print(f"\n  0x{pos:06X}: mov.l #0x{addr:08X}, ER{reg}")
                print(f"    Data at 0x{addr:06X}:")
                if addr < len(data):
                    for j in range(0, min(64, len(data) - addr), 16):
                        chunk = data[addr+j:addr+j+16]
                        hex_part = ' '.join(f'{b:02X}' for b in chunk)
                        ascii_part = ''.join(chr(b) if 32 <= b < 127 else '.' for b in chunk)
                        print(f"      0x{addr+j:06X}: {hex_part:<48s} {ascii_part}")


if __name__ == "__main__":
    main()
