#!/usr/bin/env python3
"""Decode H8/300H instructions at SCSI handler entry points.
Provides full disassembly of each handler from entry to first RTS."""

import struct
import sys

def read_firmware(path="binaries/firmware/Nikon LS-50 MBM29F400B TSOP48.bin"):
    with open(path, 'rb') as f:
        return f.read()

# Known RAM addresses for annotation
RAM_LABELS = {
    0x4007B6: "scsi_opcode",
    0x4007B7: "cdb_flags",
    0x4007B8: "xfer_len",
    0x4007B9: "cmd_state",
    0x4007BA: "exec_mode",
    0x4007BB: "perm_flags",
    0x4007BC: "handler_entry",
    0x4007BD: "response_phase",
    0x4007BE: "data_dir",
    0x4007BF: "cmd_category",
    0x4007B0: "sense_data",
    0x4007B2: "xfer_count",
    0x4007B4: "data_ptr",
    0x4007D6: "usb_timeout_timer",
    0x4007DE: "cdb_buffer",
    0x40077C: "scanner_state",
    0x400776: "abort_flag",
    0x40078C: "asic_busy",
    0x40049A: "usb_active",
    0x40049B: "usb_session",
    0x407DC6: "usb_cmd_phase",
    0x407DC7: "usb_session_state",
    0x4052D7: "scan_busy",
    0x404E96: "buffer_bank",
    0x400773: "adapter_type",
    0x400778: "scan_buffer_size",
    0x40077A: "dma_block_size",
    0x400790: "scan_resolution",
    0x400E92: "color_mode",
    0x400E94: "bit_depth",
    0x405300: "model_flag",
    0x400F08: "timer_flag",
    0x400F5B: "motor_state",
    0x200001: "asic_ctrl",
    0x200002: "asic_status",
    0x2000C2: "asic_usb",
    0x600008: "isp1581_int_status",
    0x60000C: "isp1581_mode",
    0x600018: "isp1581_dma_cfg",
    0x60001C: "isp1581_ep_idx",
    0x600020: "isp1581_ep_data",
    0x60002C: "isp1581_ep_ctrl",
    0x600084: "isp1581_dma_count",
    0xFFFFA8: "watchdog",
    0xFFFFF6: "port_ctrl",
}

def annotate_addr(addr):
    """Return annotation for known address."""
    if addr in RAM_LABELS:
        return f"  ; {RAM_LABELS[addr]}"
    # Check for known function addresses
    fn_labels = {
        0x016458: "push_context",
        0x016436: "pop_context",
        0x0109E2: "wait_irq",
        0x0109EA: "save_irq_mask",
        0x0109F2: "get_irq_state",
        0x0109F6: "restore_irq_mask",
        0x010974: "timer_setup",
        0x01374A: "usb_response_mgr",
        0x013C70: "usb_dma_setup",
        0x015CF2: "dma_alloc",
        0x012258: "usb_ep_read",
        0x0122C4: "usb_ep_write",
        0x012304: "usb_ep_write_alt",
        0x011F4: "sense_setup",
        0x020B48: "scsi_dispatch",
        0x020CA0: "internal_dispatch",
        0x020DB2: "handler_call",
        0x030E6: "flash_write",
        0x029E96: "scan_cleanup",
        0x02D4E2: "scan_init",
        0x02D536: "scan_isr",
        0x02D5E4: "scan_postproc",
        0x036C10: "ccd_setup",
        0x035A9A: "motor_sequence",
    }
    if addr in fn_labels:
        return f"  ; {fn_labels[addr]}"
    return ""

def decode_h8(data, offset, max_instr=300):
    """Decode H8/300H instructions starting at offset.
    Returns list of (addr, bytes_hex, mnemonic, operands, annotation)."""

    results = []
    pos = offset
    rts_count = 0

    for _ in range(max_instr):
        if pos >= len(data) - 1:
            break

        b0 = data[pos]
        b1 = data[pos+1] if pos+1 < len(data) else 0

        instr_len = 2  # default
        mnemonic = ""
        operands = ""
        annotation = ""

        # === 2-byte instructions ===

        # NOP
        if b0 == 0x00 and b1 == 0x00:
            mnemonic = "nop"

        # MOV.B Rn, Rm  (0C xx)
        elif b0 == 0x0C:
            rs = (b1 >> 4) & 0xF
            rd = b1 & 0xF
            mnemonic = "mov.b"
            operands = f"r{rs}l, r{rd}l"

        # MOV.W Rn, Rm  (0D xx)
        elif b0 == 0x0D:
            rs = (b1 >> 4) & 0xF
            rd = b1 & 0xF
            mnemonic = "mov.w"
            operands = f"{'e' if rs>=8 else 'r'}{rs&7}, {'e' if rd>=8 else 'r'}{rd&7}"

        # ADD.B #xx, Rd  (8x xx)
        elif (b0 >> 4) == 0x8:
            rd = b0 & 0xF
            mnemonic = "add.b"
            operands = f"#0x{b1:02X}, r{rd}l"

        # CMP.B #xx, Rd  (Ax xx)
        elif (b0 >> 4) == 0xA:
            rd = b0 & 0xF
            mnemonic = "cmp.b"
            operands = f"#0x{b1:02X}, r{rd}l"

        # AND.B #xx, Rd (Ex xx)
        elif (b0 >> 4) == 0xE:
            rd = b0 & 0xF
            mnemonic = "and.b"
            operands = f"#0x{b1:02X}, r{rd}l"

        # MOV.B #xx, Rd (Fx xx)
        elif (b0 >> 4) == 0xF:
            rd = b0 & 0xF
            mnemonic = "mov.b"
            operands = f"#0x{b1:02X}, r{rd}l"

        # OR.B #xx, Rd (Cx xx)
        elif (b0 >> 4) == 0xC:
            rd = b0 & 0xF
            mnemonic = "or.b"
            operands = f"#0x{b1:02X}, r{rd}l"

        # SUB.B Rs, Rd (18 xx)
        elif b0 == 0x18:
            rs = (b1 >> 4) & 0xF
            rd = b1 & 0xF
            mnemonic = "sub.b"
            operands = f"r{rs}l, r{rd}l"

        # ADD.B Rs, Rd (08 xx)
        elif b0 == 0x08:
            rs = (b1 >> 4) & 0xF
            rd = b1 & 0xF
            mnemonic = "add.b"
            operands = f"r{rs}l, r{rd}l"

        # SUB.W Rs, Rd (19 xx)
        elif b0 == 0x19:
            rs = (b1 >> 4) & 0xF
            rd = b1 & 0xF
            mnemonic = "sub.w"
            operands = f"r{rs}, r{rd}"

        # ADD.W Rs, Rd (09 xx)
        elif b0 == 0x09:
            rs = (b1 >> 4) & 0xF
            rd = b1 & 0xF
            mnemonic = "add.w"
            operands = f"r{rs}, r{rd}"

        # INC.B Rd (0A 0x)
        elif b0 == 0x0A and (b1 & 0xF0) == 0x00:
            rd = b1 & 0xF
            mnemonic = "inc.b"
            operands = f"r{rd}l"

        # DEC.B Rd (1A 0x)
        elif b0 == 0x1A and (b1 & 0xF0) == 0x00:
            rd = b1 & 0xF
            mnemonic = "dec.b"
            operands = f"r{rd}l"

        # ADD.L ERs, ERd (0A 8x)
        elif b0 == 0x0A and (b1 & 0xF0) == 0x80:
            rs = (b1 >> 0) & 0x7
            mnemonic = "add.l"
            operands = f"er{(b1>>4)&7}, er{b1&7}"

        # SUB.L ERs, ERd (1A 8x/9x)
        elif b0 == 0x1A and (b1 & 0xF0) >= 0x80:
            rs = (b1 >> 4) & 0x7
            rd = b1 & 0x7
            mnemonic = "sub.l"
            operands = f"er{rs}, er{rd}"

        # CMP.L ERs, ERd (1F 8x)
        elif b0 == 0x1F and (b1 & 0xF0) == 0x80:
            rs = (b1 >> 4) & 0x7
            rd = b1 & 0x7
            mnemonic = "cmp.l"
            operands = f"er{rs}, er{rd}"

        # NOT.B Rd (17 0x)
        elif b0 == 0x17 and (b1 & 0xF0) == 0x00:
            rd = b1 & 0xF
            mnemonic = "not.b"
            operands = f"r{rd}l"

        # EXTU.W Rn (17 5x)
        elif b0 == 0x17 and (b1 & 0xF0) == 0x50:
            rd = b1 & 0xF
            mnemonic = "extu.w"
            operands = f"r{rd}"

        # EXTU.L ERn (17 7x)
        elif b0 == 0x17 and (b1 & 0xF0) == 0x70:
            rd = b1 & 0xF
            mnemonic = "extu.l"
            operands = f"er{rd}"

        # EXTS.W Rn (17 Dx)
        elif b0 == 0x17 and (b1 & 0xF0) == 0xD0:
            rd = b1 & 0xF
            mnemonic = "exts.w"
            operands = f"r{rd}"

        # SHLL.L ERn (10 3x)
        elif b0 == 0x10 and (b1 & 0xF0) == 0x30:
            rd = b1 & 0x7
            mnemonic = "shll.l"
            operands = f"er{rd}"

        # SHLR.L ERn (11 3x)
        elif b0 == 0x11 and (b1 & 0xF0) == 0x30:
            rd = b1 & 0x7
            mnemonic = "shlr.l"
            operands = f"er{rd}"

        # ROTL.B Rd (12 8x)
        elif b0 == 0x12 and (b1 & 0xF0) == 0x80:
            rd = b1 & 0xF
            mnemonic = "rotl.b"
            operands = f"r{rd}l"

        # SHAL.B Rd (10 8x)
        elif b0 == 0x10 and (b1 & 0xF0) == 0x80:
            rd = b1 & 0xF
            mnemonic = "shal.b"
            operands = f"r{rd}l"

        # SHLR.B Rd (11 0x)
        elif b0 == 0x11 and (b1 & 0xF0) == 0x00:
            rd = b1 & 0xF
            mnemonic = "shlr.b"
            operands = f"r{rd}l"

        # SHLL.B Rd (10 0x)
        elif b0 == 0x10 and (b1 & 0xF0) == 0x00:
            rd = b1 & 0xF
            mnemonic = "shll.b"
            operands = f"r{rd}l"

        # MOV.W @ERs, Rd (69 xx)
        elif b0 == 0x69:
            if (b1 & 0x80) == 0:
                rs = (b1 >> 4) & 0x7
                rd = b1 & 0xF
                mnemonic = "mov.w"
                operands = f"@er{rs}, r{rd}"
            else:
                rs = (b1 >> 4) & 0x7
                rd = b1 & 0xF
                mnemonic = "mov.w"
                operands = f"r{rd & 7}, @er{rs}"

        # MOV.B @ERs, Rd (68 xx)
        elif b0 == 0x68:
            if (b1 & 0x80) == 0:
                rs = (b1 >> 4) & 0x7
                rd = b1 & 0xF
                mnemonic = "mov.b"
                operands = f"@er{rs}, r{rd}l"
            else:
                rs = (b1 >> 4) & 0x7
                rd = b1 & 0xF
                mnemonic = "mov.b"
                operands = f"r{rd&7}l, @er{rs}"

        # INC.W #1, Rd (0B 5x)
        elif b0 == 0x0B and (b1 & 0xF0) == 0x50:
            rd = b1 & 0xF
            mnemonic = "inc.w"
            operands = f"#1, r{rd}"

        # DEC.W #1, Rd (1B 5x)
        elif b0 == 0x1B and (b1 & 0xF0) == 0x50:
            rd = b1 & 0xF
            mnemonic = "dec.w"
            operands = f"#1, r{rd}"

        # INC.L #1, ERd (0B 7x)
        elif b0 == 0x0B and (b1 & 0xF0) == 0x70:
            rd = b1 & 0x7
            mnemonic = "inc.l"
            operands = f"#1, er{rd}"

        # INC.L #2, ERd (0B Fx)
        elif b0 == 0x0B and (b1 & 0xF0) == 0xF0:
            rd = b1 & 0x7
            mnemonic = "inc.l"
            operands = f"#2, er{rd}"

        # DEC.L #1, ERd (1B 7x)
        elif b0 == 0x1B and (b1 & 0xF0) == 0x70:
            rd = b1 & 0x7
            mnemonic = "dec.l"
            operands = f"#1, er{rd}"

        # BTST #n, Rd (73 xx)
        elif b0 == 0x73:
            bit = (b1 >> 4) & 0x7
            rd = b1 & 0xF
            mnemonic = "btst"
            operands = f"#{bit}, r{rd}l"

        # BSET #n, Rd (70 xx)
        elif b0 == 0x70:
            bit = (b1 >> 4) & 0x7
            rd = b1 & 0xF
            mnemonic = "bset"
            operands = f"#{bit}, r{rd}l"

        # BCLR #n, Rd (72 xx)
        elif b0 == 0x72:
            bit = (b1 >> 4) & 0x7
            rd = b1 & 0xF
            mnemonic = "bclr"
            operands = f"#{bit}, r{rd}l"

        # BLD #n, Rd (77 xx)
        elif b0 == 0x77:
            bit = (b1 >> 4) & 0x7
            rd = b1 & 0xF
            mnemonic = "bld"
            operands = f"#{bit}, r{rd}l"

        # BST #n, Rd (67 xx)
        elif b0 == 0x67:
            bit = (b1 >> 4) & 0x7
            rd = b1 & 0xF
            mnemonic = "bst"
            operands = f"#{bit}, r{rd}h"

        # Branch instructions (4x xx)
        elif (b0 & 0xF0) == 0x40:
            cond_map = {0: "bra", 1: "brn", 2: "bhi", 3: "bls", 4: "bcc", 5: "bcs",
                       6: "bne", 7: "beq", 8: "bvc", 9: "bvs", 0xA: "bpl", 0xB: "bmi",
                       0xC: "bge", 0xD: "blt", 0xE: "bgt", 0xF: "ble"}
            cond = b0 & 0xF
            mnemonic = cond_map.get(cond, f"b{cond:X}")
            disp = b1 if b1 < 128 else b1 - 256
            target = pos + 2 + disp
            operands = f"0x{target:06X}"
            annotation = annotate_addr(target)

        # RTS (54 70)
        elif b0 == 0x54 and b1 == 0x70:
            mnemonic = "rts"
            rts_count += 1

        # RTE (56 70)
        elif b0 == 0x56 and b1 == 0x70:
            mnemonic = "rte"
            rts_count += 1

        # SLEEP (01 80)
        elif b0 == 0x01 and b1 == 0x80:
            mnemonic = "sleep"

        # === 4-byte instructions ===

        # JSR @aa:24 (5E xx xx xx)
        elif b0 == 0x5E and pos + 3 < len(data):
            instr_len = 4
            addr24 = (b1 << 16) | (data[pos+2] << 8) | data[pos+3]
            mnemonic = "jsr"
            operands = f"@0x{addr24:06X}"
            annotation = annotate_addr(addr24)

        # BSR disp:16 (5C 00 xx xx)
        elif b0 == 0x5C and b1 == 0x00 and pos + 3 < len(data):
            instr_len = 4
            disp = struct.unpack('>h', data[pos+2:pos+4])[0]
            target = pos + 4 + disp
            mnemonic = "bsr"
            operands = f"0x{target:06X}"
            annotation = annotate_addr(target)

        # JMP @aa:24 (5A xx xx xx)
        elif b0 == 0x5A and pos + 3 < len(data):
            instr_len = 4
            addr24 = (b1 << 16) | (data[pos+2] << 8) | data[pos+3]
            mnemonic = "jmp"
            operands = f"@0x{addr24:06X}"
            annotation = annotate_addr(addr24)

        # Branch 16-bit displacement (58 xC xx xx or 58 x0 xx xx)
        elif b0 == 0x58 and pos + 3 < len(data):
            instr_len = 4
            cond_map = {0: "bra", 1: "brn", 2: "bhi", 3: "bls", 4: "bcc", 5: "bcs",
                       6: "bne", 7: "beq", 8: "bvc", 9: "bvs", 0xA: "bpl", 0xB: "bmi",
                       0xC: "bge", 0xD: "blt", 0xE: "bgt", 0xF: "ble"}
            cond = (b1 >> 4) & 0xF
            disp = struct.unpack('>h', data[pos+2:pos+4])[0]
            target = pos + 4 + disp
            mnemonic = cond_map.get(cond, f"b{cond:X}")
            operands = f"0x{target:06X}"
            annotation = annotate_addr(target)

        # MOV.W #xx, Rd (79 0x xx xx)
        elif b0 == 0x79 and pos + 3 < len(data):
            instr_len = 4
            sub = (b1 >> 4) & 0xF
            rd = b1 & 0xF
            imm16 = (data[pos+2] << 8) | data[pos+3]
            if sub == 0:
                mnemonic = "mov.w"
                operands = f"#0x{imm16:04X}, r{rd}"
            elif sub == 1:
                mnemonic = "add.w"
                operands = f"#0x{imm16:04X}, r{rd}"
            elif sub == 2:
                mnemonic = "cmp.w"
                operands = f"#0x{imm16:04X}, r{rd}"
            elif sub == 4:
                mnemonic = "or.w"
                operands = f"#0x{imm16:04X}, r{rd}"
            elif sub == 5:
                mnemonic = "xor.w"
                operands = f"#0x{imm16:04X}, r{rd}"
            elif sub == 6:
                mnemonic = "and.w"
                operands = f"#0x{imm16:04X}, r{rd}"
            elif sub == 8:
                mnemonic = "mov.w"
                operands = f"#0x{imm16:04X}, e{rd}"
            else:
                mnemonic = f"?79.{sub:X}"
                operands = f"#0x{imm16:04X}, r{rd}"

        # MOV.B @(d:16, ERs), Rd or MOV.B Rd, @(d:16, ERs) (6E xx xx xx)
        elif b0 == 0x6E and pos + 3 < len(data):
            instr_len = 4
            if (b1 & 0x80) == 0:
                rs = (b1 >> 4) & 0x7
                rd = b1 & 0xF
                disp = struct.unpack('>h', data[pos+2:pos+4])[0]
                mnemonic = "mov.b"
                operands = f"@(0x{disp & 0xFFFF:04X}, er{rs}), r{rd}l"
            else:
                rs = (b1 >> 4) & 0x7
                rd = b1 & 0x7
                disp = struct.unpack('>h', data[pos+2:pos+4])[0]
                mnemonic = "mov.b"
                operands = f"r{rd}l, @(0x{disp & 0xFFFF:04X}, er{rs})"

        # MOV.W @(d:16, ERs), Rd (6F xx xx xx)
        elif b0 == 0x6F and pos + 3 < len(data):
            instr_len = 4
            if (b1 & 0x80) == 0:
                rs = (b1 >> 4) & 0x7
                rd = b1 & 0xF
                disp = struct.unpack('>h', data[pos+2:pos+4])[0]
                mnemonic = "mov.w"
                operands = f"@(0x{disp & 0xFFFF:04X}, er{rs}), r{rd}"
            else:
                rs = (b1 >> 4) & 0x7
                rd = b1 & 0x7
                disp = struct.unpack('>h', data[pos+2:pos+4])[0]
                mnemonic = "mov.w"
                operands = f"r{rd}, @(0x{disp & 0xFFFF:04X}, er{rs})"

        # MOV.W @aa:16, Rd (6B 2x xx xx)
        elif b0 == 0x6B and pos + 3 < len(data):
            instr_len = 4
            rd = b1 & 0xF
            if (b1 & 0xF0) == 0x20:
                addr16 = (data[pos+2] << 8) | data[pos+3]
                # Sign extend for IO addresses
                if addr16 >= 0xFF00:
                    full_addr = 0xFFFF00 | (addr16 & 0xFF)
                else:
                    full_addr = addr16
                mnemonic = "mov.w"
                operands = f"@0x{addr16:04X}, r{rd}"
                annotation = annotate_addr(full_addr)
            elif (b1 & 0xF0) == 0x80 or (b1 & 0xF0) == 0xA0:
                addr16 = (data[pos+2] << 8) | data[pos+3]
                if addr16 >= 0xFF00:
                    full_addr = 0xFFFF00 | (addr16 & 0xFF)
                else:
                    full_addr = addr16
                mnemonic = "mov.w"
                operands = f"r{rd&7}, @0x{addr16:04X}"
                annotation = annotate_addr(full_addr)
            else:
                mnemonic = f"?6B.{b1:02X}"
                operands = f"0x{data[pos+2]:02X}{data[pos+3]:02X}"

        # BTST/BSET/BCLR #n, @ERd (7C/7D xx 7x xx)
        elif (b0 == 0x7C or b0 == 0x7D) and pos + 3 < len(data):
            instr_len = 4
            rd = (b1 >> 4) & 0x7
            b2 = data[pos+2]
            b3 = data[pos+3]
            bit = (b3 >> 4) & 0x7
            if b2 == 0x73:
                mnemonic = "btst"
                operands = f"#{bit}, @er{rd}"
            elif b2 == 0x70:
                if b0 == 0x7D:
                    mnemonic = "bset"
                else:
                    mnemonic = "bset"
                operands = f"#{bit}, @er{rd}"
            elif b2 == 0x72:
                mnemonic = "bclr"
                operands = f"#{bit}, @er{rd}"
            else:
                mnemonic = f"?{b0:02X}"
                operands = f"@er{rd}, {b2:02X} {b3:02X}"

        # MULXU.B Rs, Rd (50 xx)
        elif b0 == 0x50:
            rs = (b1 >> 4) & 0xF
            rd = b1 & 0xF
            mnemonic = "mulxu.b"
            operands = f"r{rs}l, r{rd}"

        # DIVXU.B Rs, Rd (51 xx)
        elif b0 == 0x51:
            rs = (b1 >> 4) & 0xF
            rd = b1 & 0xF
            mnemonic = "divxu.b"
            operands = f"r{rs}l, r{rd}"

        # MOV.W @ERs+, Rd (6D xx)
        elif b0 == 0x6D:
            if (b1 & 0x80) == 0:
                rs = (b1 >> 4) & 0x7
                rd = b1 & 0xF
                mnemonic = "pop.w" if rs == 7 else "mov.w"
                operands = f"r{rd}" if rs == 7 else f"@er{rs}+, r{rd}"
            else:
                rs = (b1 >> 4) & 0x7
                rd = b1 & 0x7
                mnemonic = "push.w" if rs == 7 else "mov.w"
                operands = f"r{rd}" if rs == 7 else f"r{rd}, @-er{rs}"

        # === 4-byte instructions (EEPMOV) ===
        elif b0 == 0x7B and b1 == 0x5C and pos + 3 < len(data):
            instr_len = 4
            mnemonic = "eepmov.b"
            operands = ""

        # === 6-byte instructions ===

        # MOV.B @aa:24, Rd (6A 2x xx xx xx xx) or MOV.B Rd, @aa:24 (6A Ax xx xx xx xx)
        elif b0 == 0x6A and pos + 5 < len(data):
            instr_len = 6
            rd = b1 & 0xF
            addr24 = (data[pos+2] << 16) | (data[pos+3] << 8) | data[pos+4]
            if (b1 & 0xF0) == 0x20 or (b1 & 0xF0) == 0x00:
                mnemonic = "mov.b"
                operands = f"@0x{addr24:06X}, r{rd}l"
                annotation = annotate_addr(addr24)
            elif (b1 & 0xF0) == 0xA0 or (b1 & 0xF0) == 0x80:
                mnemonic = "mov.b"
                operands = f"r{rd&7}l, @0x{addr24:06X}"
                annotation = annotate_addr(addr24)
            else:
                mnemonic = f"?6A.{b1:02X}"
                operands = f"0x{addr24:06X}"

        # MOV.L #imm32, ERd (7A 0x xx xx xx xx)
        elif b0 == 0x7A and pos + 5 < len(data):
            instr_len = 6
            sub = (b1 >> 4) & 0xF
            rd = b1 & 0x7
            imm32 = (data[pos+2] << 24) | (data[pos+3] << 16) | (data[pos+4] << 8) | data[pos+5]
            if sub == 0:
                mnemonic = "mov.l"
                operands = f"#0x{imm32:08X}, er{rd}"
                annotation = annotate_addr(imm32)
            elif sub == 1:
                mnemonic = "add.l"
                operands = f"#0x{imm32:08X}, er{rd}"
            elif sub == 2:
                mnemonic = "cmp.l"
                operands = f"#0x{imm32:08X}, er{rd}"
            elif sub == 3:
                mnemonic = "sub.l"
                operands = f"#0x{imm32:08X}, er{rd}"
            elif sub == 4:
                mnemonic = "or.l"
                operands = f"#0x{imm32:08X}, er{rd}"
            elif sub == 5:
                mnemonic = "xor.l"
                operands = f"#0x{imm32:08X}, er{rd}"
            elif sub == 6:
                mnemonic = "and.l"
                operands = f"#0x{imm32:08X}, er{rd}"
            elif sub == 7:
                mnemonic = "sub.l"
                operands = f"#0x{imm32:08X}, er{rd}"
            else:
                mnemonic = f"?7A.{sub:X}"
                operands = f"#0x{imm32:08X}, er{rd}"

        # MOV.B @(d:16, ERs), Rd or MOV.B Rd, @(d:16, ERs) (6E xx xx xx)
        # Already handled above

        # === 8-byte instructions ===

        # MOV.L @ERs, ERd (01 00 69 xx) or variants
        elif b0 == 0x01 and b1 == 0x00 and pos + 3 < len(data):
            b2 = data[pos+2]
            b3 = data[pos+3]

            if b2 == 0x69:
                instr_len = 4
                if (b3 & 0x80) == 0:
                    rs = (b3 >> 4) & 0x7
                    rd = b3 & 0x7
                    mnemonic = "mov.l"
                    operands = f"@er{rs}, er{rd}"
                else:
                    rs = (b3 >> 4) & 0x7
                    rd = b3 & 0x7
                    mnemonic = "mov.l"
                    operands = f"er{rd}, @er{rs}"
            elif b2 == 0x6D:
                instr_len = 4
                if (b3 & 0x80) == 0:
                    rd = b3 & 0x7
                    mnemonic = "pop.l"
                    operands = f"er{rd}"
                else:
                    rd = b3 & 0x7
                    mnemonic = "push.l"
                    operands = f"er{rd}"
            elif b2 == 0x6F and pos + 5 < len(data):
                instr_len = 6
                rs = (b3 >> 4) & 0x7
                rd = b3 & 0x7
                disp = struct.unpack('>h', data[pos+4:pos+6])[0]
                if (b3 & 0x80) == 0:
                    mnemonic = "mov.l"
                    operands = f"@(0x{disp & 0xFFFF:04X}, er{rs}), er{rd}"
                else:
                    mnemonic = "mov.l"
                    operands = f"er{rd}, @(0x{disp & 0xFFFF:04X}, er{rs})"
            elif b2 == 0x6B and pos + 7 < len(data):
                instr_len = 8
                rd = b3 & 0x7
                addr32 = struct.unpack('>I', data[pos+4:pos+8])[0]
                if (b3 & 0xF0) == 0x20:
                    mnemonic = "mov.l"
                    operands = f"@0x{addr32:08X}, er{rd}"
                    annotation = annotate_addr(addr32)
                elif (b3 & 0xF0) == 0xA0 or (b3 & 0xF0) == 0x80:
                    mnemonic = "mov.l"
                    operands = f"er{rd&7}, @0x{addr32:08X}"
                    annotation = annotate_addr(addr32)
                else:
                    mnemonic = f"?0100.6B.{b3:02X}"
                    operands = f"0x{addr32:08X}"
            else:
                mnemonic = f"?0100.{b2:02X}.{b3:02X}"
                operands = ""

        # MULXU.W Rs, ERd (01 C0 52 xx)
        elif b0 == 0x01 and b1 == 0xC0 and pos + 3 < len(data):
            instr_len = 4
            b2 = data[pos+2]
            b3 = data[pos+3]
            if b2 == 0x52:
                rs = (b3 >> 4) & 0xF
                rd = b3 & 0x7
                mnemonic = "mulxu.w"
                operands = f"r{rs}, er{rd}"
            else:
                mnemonic = f"?01C0.{b2:02X}{b3:02X}"

        # DIVXU.W Rs, ERd (01 D0 53 xx)
        elif b0 == 0x01 and b1 == 0xD0 and pos + 3 < len(data):
            instr_len = 4
            b2 = data[pos+2]
            b3 = data[pos+3]
            if b2 == 0x53:
                rs = (b3 >> 4) & 0xF
                rd = b3 & 0x7
                mnemonic = "divxu.w"
                operands = f"r{rs}, er{rd}"
            else:
                mnemonic = f"?01D0.{b2:02X}{b3:02X}"

        # Short MOV.B @aa:8, R0L (28 xx) or MOV.B R0L, @aa:8 (38 xx)
        elif (b0 & 0xF0) == 0x20:
            reg = b0 & 0x0F
            addr = 0xFFFF00 | b1
            mnemonic = "mov.b"
            operands = f"@0x{addr:06X}, r{reg}l"
            annotation = annotate_addr(addr)
        elif (b0 & 0xF0) == 0x30:
            reg = b0 & 0x0F
            addr = 0xFFFF00 | b1
            mnemonic = "mov.b"
            operands = f"r{reg}l, @0x{addr:06X}"
            annotation = annotate_addr(addr)

        # ORC/ANDC/XORC to CCR (04/06/05 xx)
        elif b0 == 0x04:
            mnemonic = "orc"
            operands = f"#0x{b1:02X}, ccr"
        elif b0 == 0x06:
            mnemonic = "andc"
            operands = f"#0x{b1:02X}, ccr"
        elif b0 == 0x05:
            mnemonic = "xorc"
            operands = f"#0x{b1:02X}, ccr"

        # LDC #xx, CCR (07 xx)
        elif b0 == 0x07:
            mnemonic = "ldc"
            operands = f"#0x{b1:02X}, ccr"

        # OR.B Rs, Rd (14 xx)
        elif b0 == 0x14:
            rs = (b1 >> 4) & 0xF
            rd = b1 & 0xF
            mnemonic = "or.b"
            operands = f"r{rs}l, r{rd}l"

        # AND.B Rs, Rd (16 xx)
        elif b0 == 0x16:
            rs = (b1 >> 4) & 0xF
            rd = b1 & 0xF
            mnemonic = "and.b"
            operands = f"r{rs}l, r{rd}l"

        # XOR.B Rs, Rd (15 xx)
        elif b0 == 0x15:
            rs = (b1 >> 4) & 0xF
            rd = b1 & 0xF
            mnemonic = "xor.b"
            operands = f"r{rs}l, r{rd}l"

        # CMP.B Rs, Rd (1C xx)
        elif b0 == 0x1C:
            rs = (b1 >> 4) & 0xF
            rd = b1 & 0xF
            mnemonic = "cmp.b"
            operands = f"r{rs}l, r{rd}l"

        # CMP.W Rs, Rd (1D xx)
        elif b0 == 0x1D:
            rs = (b1 >> 4) & 0xF
            rd = b1 & 0xF
            mnemonic = "cmp.w"
            operands = f"r{rs}, r{rd}"

        # ADDX Rs, Rd (0E xx)
        elif b0 == 0x0E:
            rs = (b1 >> 4) & 0xF
            rd = b1 & 0xF
            mnemonic = "addx"
            operands = f"r{rs}l, r{rd}l"

        # XOR.L Rs, Rd (01 F0 65 xx)
        elif b0 == 0x01 and b1 == 0xF0 and pos + 3 < len(data):
            instr_len = 4
            b2 = data[pos+2]
            b3 = data[pos+3]
            mnemonic = f"xor.l/01F0"
            operands = f"{b2:02X}{b3:02X}"

        # MOV.W @aa:24, Rd or MOV.W Rd, @aa:24 (6B 2x 00 xx xx xx or 6B Ax 00 xx xx xx)
        # 6-byte variant already handled above via 4-byte

        # NOP or unrecognized
        else:
            mnemonic = f"db"
            operands = f"0x{b0:02X}, 0x{b1:02X}"

        # Format hex bytes
        hex_bytes = ' '.join(f'{data[pos+i]:02X}' for i in range(instr_len))

        results.append((pos, hex_bytes, mnemonic, operands, annotation))
        pos += instr_len

        # Stop at RTS/RTE (but allow first few instructions)
        if rts_count >= 1 and len(results) > 5:
            break

    return results


# Handler table
HANDLERS = [
    (0x0215C2, "TEST_UNIT_READY", "0x00"),
    (0x021866, "REQUEST_SENSE", "0x03"),
    (0x025E18, "INQUIRY", "0x12"),
    (0x02194A, "MODE_SELECT", "0x15"),
    (0x021E3E, "RESERVE", "0x16"),
    (0x021EA0, "RELEASE", "0x17"),
    (0x021F1C, "MODE_SENSE", "0x1A"),
    (0x0220B8, "SCAN", "0x1B"),
    (0x023856, "RECV_DIAG", "0x1C"),
    (0x023D32, "SEND_DIAG", "0x1D"),
    (0x026E38, "SET_WINDOW", "0x24"),
    (0x0272F6, "GET_WINDOW", "0x25"),
    (0x023F10, "READ_10", "0x28"),
    (0x025506, "SEND_10", "0x2A"),
    (0x02837C, "WRITE_BUFFER", "0x3B"),
    (0x028884, "READ_BUFFER", "0x3C"),
    (0x028AB4, "VENDOR_C0", "0xC0"),
    (0x028B08, "VENDOR_C1", "0xC1"),
    (0x013748, "PHASE_QUERY_D0", "0xD0"),
    (0x028E16, "VENDOR_E0", "0xE0"),
    (0x0295EA, "VENDOR_E1", "0xE1"),
]


def main():
    data = read_firmware()

    for addr, name, opcode in HANDLERS:
        print(f"\n{'='*80}")
        print(f"=== {name} HANDLER (opcode {opcode}) @ 0x{addr:06X} ===")
        print(f"{'='*80}")

        instrs = decode_h8(data, addr, max_instr=200)
        for iaddr, hexb, mnemonic, operands, annot in instrs:
            op_str = f"{mnemonic:<12} {operands}" if operands else mnemonic
            print(f"  0x{iaddr:06X}: [{hexb:<24}] {op_str:<45}{annot}")

        print(f"  --- {len(instrs)} instructions ---")


if __name__ == "__main__":
    main()
