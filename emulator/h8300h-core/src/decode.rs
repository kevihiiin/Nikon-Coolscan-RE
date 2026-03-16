/// H8/300H instruction decoder.
///
/// Clean-room implementation from Hitachi H8/300H Programming Manual (ADE-602-053A).
/// Instruction encoding: variable length 2/4/6/8/10 bytes.
/// First byte (or first nibble pair) identifies the instruction group.
///
/// Encoding convention used here:
///   opcode[15:12] = first nibble (bits 15..12 of first word)
///   opcode[11:8]  = second nibble
///   opcode[7:4]   = third nibble
///   opcode[3:0]   = fourth nibble

use crate::memory::MemoryBus;

/// Operand size.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Size {
    Byte,
    Word,
    Long,
}

/// Addressing modes for operands.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Operand {
    /// Register direct (8-bit): R0H..R7H (0-7), R0L..R7L (8-15)
    Reg8(u8),
    /// Register direct (16-bit): R0..R7 (0-7), E0..E7 (8-15)
    Reg16(u8),
    /// Register direct (32-bit): ER0..ER7
    Reg32(u8),
    /// Immediate 8-bit
    Imm8(u8),
    /// Immediate 16-bit
    Imm16(u16),
    /// Immediate 32-bit
    Imm32(u32),
    /// Register indirect @ERn
    RegIndirect(u8),
    /// Register indirect with displacement @(d:16, ERn)
    RegIndirectDisp16(u8, i16),
    /// Register indirect with displacement @(d:24, ERn) — H8/300H extended
    RegIndirectDisp24(u8, u32),
    /// Post-increment @ERn+
    PostInc(u8),
    /// Pre-decrement @-ERn
    PreDec(u8),
    /// Absolute 8-bit (only for MOV.B with @aa:8 — maps to 0xFFxx00+offset)
    Abs8(u8),
    /// Absolute 16-bit
    Abs16(u16),
    /// Absolute 24-bit
    Abs24(u32),
    /// PC-relative 8-bit displacement (signed)
    PcRel8(i8),
    /// PC-relative 16-bit displacement (signed)
    PcRel16(i16),
    /// Memory indirect @@aa:8 (for JMP/JSR)
    MemIndirect(u8),
    /// CCR (for LDC/STC/ANDC/ORC/XORC)
    Ccr,
}

/// Branch condition codes.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Condition {
    Always,  // BRA (true)
    Never,   // BRN (false)
    Hi,      // BHI (C|Z = 0)
    Ls,      // BLS (C|Z = 1)
    Cc,      // BCC/BHS (C = 0)
    Cs,      // BCS/BLO (C = 1)
    Ne,      // BNE (Z = 0)
    Eq,      // BEQ (Z = 1)
    Vc,      // BVC (V = 0)
    Vs,      // BVS (V = 1)
    Pl,      // BPL (N = 0)
    Mi,      // BMI (N = 1)
    Ge,      // BGE (N^V = 0)
    Lt,      // BLT (N^V = 1)
    Gt,      // BGT (Z|(N^V) = 0)
    Le,      // BLE (Z|(N^V) = 1)
}

/// Decoded instruction.
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum Instruction {
    // --- Data Transfer ---
    Mov(Size, Operand, Operand),   // MOV.B/W/L src, dst
    Push(Operand),                  // PUSH (alias for MOV @-SP)
    Pop(Operand),                   // POP (alias for MOV @SP+)

    // --- Arithmetic ---
    Add(Size, Operand, Operand),
    Sub(Size, Operand, Operand),
    Cmp(Size, Operand, Operand),
    Neg(Size, Operand),
    Inc(Size, Operand),             // INC.B/W/L
    Dec(Size, Operand),             // DEC.B/W/L
    Addx(Operand, Operand),         // ADDX (byte only, with carry)
    Subx(Operand, Operand),         // SUBX (byte only, with borrow)
    Adds(Operand, Operand),         // ADDS #1/2/4, ERn (no flags)
    Subs(Operand, Operand),         // SUBS #1/2/4, ERn (no flags)
    Daa(Operand),                   // DAA (decimal adjust add)
    Das(Operand),                   // DAS (decimal adjust sub)
    MulxuB(Operand, Operand),       // MULXU.B Rs, Rd (8x8→16)
    MulxuW(Operand, Operand),       // MULXU.W Rs, ERd (16x16→32)
    DivxuB(Operand, Operand),       // DIVXU.B Rs, Rd (16/8→8:8)
    DivxuW(Operand, Operand),       // DIVXU.W Rs, ERd (32/16→16:16)
    Extu(Size, Operand),            // EXTU.W/L (zero-extend)
    Exts(Size, Operand),            // EXTS.W/L (sign-extend)

    // --- Logic ---
    And(Size, Operand, Operand),
    Or(Size, Operand, Operand),
    Xor(Size, Operand, Operand),
    Not(Size, Operand),

    // --- Shift ---
    Shal(Size, Operand),
    Shar(Size, Operand),
    Shll(Size, Operand),
    Shlr(Size, Operand),
    Rotl(Size, Operand),
    Rotr(Size, Operand),
    Rotxl(Size, Operand),
    Rotxr(Size, Operand),

    // --- Bit Manipulation ---
    Bset(Operand, Operand),   // BSET #imm/Rn, Rd/@ERd/@aa
    Bclr(Operand, Operand),   // BCLR
    Btst(Operand, Operand),   // BTST
    Bnot(Operand, Operand),   // BNOT
    Bst(Operand, Operand),    // BST #imm, Rd
    Bist(Operand, Operand),   // BIST #imm, Rd
    Bld(Operand, Operand),    // BLD #imm, Rd
    Bild(Operand, Operand),   // BILD #imm, Rd
    Band(Operand, Operand),   // BAND #imm, Rd
    Bor(Operand, Operand),    // BOR #imm, Rd
    Bxor(Operand, Operand),   // BXOR #imm, Rd
    Biand(Operand, Operand),  // BIAND #imm, Rd
    Bior(Operand, Operand),   // BIOR #imm, Rd
    Bixor(Operand, Operand),  // BIXOR #imm, Rd

    // --- Branch ---
    Bcc(Condition, Operand),  // Bcc disp (8 or 16 bit)
    Jmp(Operand),             // JMP @ERn / @aa:24 / @@aa:8
    Bsr(Operand),             // BSR disp (8 or 16 bit)
    Jsr(Operand),             // JSR @ERn / @aa:24 / @@aa:8

    // --- System ---
    Rts,
    Rte,
    Trapa(u8),                // TRAPA #imm (0-3)
    Nop,
    Sleep,
    Ldc(Operand, Operand),    // LDC src, CCR
    Stc(Operand, Operand),    // STC CCR, dst
    Andc(Operand),            // ANDC #imm, CCR
    Orc(Operand),             // ORC #imm, CCR
    Xorc(Operand),            // XORC #imm, CCR

    // --- Block Transfer ---
    EepmovB,                  // EEPMOV.B

    /// Unrecognized opcode (for debugging — panics in strict mode).
    Unknown(u16),
}

/// Decode result: instruction + number of bytes consumed.
pub struct Decoded {
    pub insn: Instruction,
    pub len: u32,
}

/// Decode a single instruction at the given PC.
pub fn decode(bus: &mut MemoryBus, pc: u32) -> Decoded {
    let w0 = bus.read_word(pc);
    let op_hi = (w0 >> 12) as u8;
    let op_lo = ((w0 >> 8) & 0xF) as u8;
    let nib2 = ((w0 >> 4) & 0xF) as u8;
    let nib3 = (w0 & 0xF) as u8;

    match op_hi {
        0x0 => decode_group_0(bus, pc, w0, op_lo, nib2, nib3),
        0x1 => decode_group_1(bus, pc, w0, op_lo, nib2, nib3),
        0x2 => {
            // MOV.B @aa:8, Rd — 0 2 abs8 | rd
            // Actually: 2r abs8 where r=dst reg
            let rd = op_lo;
            let abs = (w0 & 0xFF) as u8;
            Decoded {
                insn: Instruction::Mov(Size::Byte, Operand::Abs8(abs), Operand::Reg8(rd)),
                len: 2,
            }
        }
        0x3 => {
            // MOV.B Rs, @aa:8 — 3r abs8 where r=src reg
            let rs = op_lo;
            let abs = (w0 & 0xFF) as u8;
            Decoded {
                insn: Instruction::Mov(Size::Byte, Operand::Reg8(rs), Operand::Abs8(abs)),
                len: 2,
            }
        }
        0x4 => {
            // Bcc d:8 — 4c disp8
            let cond = decode_condition(op_lo);
            let disp = (w0 & 0xFF) as i8;
            Decoded {
                insn: Instruction::Bcc(cond, Operand::PcRel8(disp)),
                len: 2,
            }
        }
        0x5 => decode_group_5(bus, pc, w0, op_lo, nib2, nib3),
        0x6 => decode_group_6(bus, pc, w0, op_lo, nib2, nib3),
        0x7 => decode_group_7(bus, pc, w0, op_lo, nib2, nib3),
        0x8 => {
            // ADD.B #imm8, Rd — 8rd imm8
            let rd = op_lo;
            let imm = (w0 & 0xFF) as u8;
            Decoded {
                insn: Instruction::Add(Size::Byte, Operand::Imm8(imm), Operand::Reg8(rd)),
                len: 2,
            }
        }
        0x9 => {
            // ADDX #imm8, Rd — 9rd imm8
            let rd = op_lo;
            let imm = (w0 & 0xFF) as u8;
            Decoded {
                insn: Instruction::Addx(Operand::Imm8(imm), Operand::Reg8(rd)),
                len: 2,
            }
        }
        0xA => {
            // CMP.B #imm8, Rd — Ard imm8
            let rd = op_lo;
            let imm = (w0 & 0xFF) as u8;
            Decoded {
                insn: Instruction::Cmp(Size::Byte, Operand::Imm8(imm), Operand::Reg8(rd)),
                len: 2,
            }
        }
        0xB => {
            // SUBX #imm8, Rd — Brd imm8
            let rd = op_lo;
            let imm = (w0 & 0xFF) as u8;
            Decoded {
                insn: Instruction::Subx(Operand::Imm8(imm), Operand::Reg8(rd)),
                len: 2,
            }
        }
        0xC => {
            // OR.B #imm8, Rd — Crd imm8
            let rd = op_lo;
            let imm = (w0 & 0xFF) as u8;
            Decoded {
                insn: Instruction::Or(Size::Byte, Operand::Imm8(imm), Operand::Reg8(rd)),
                len: 2,
            }
        }
        0xD => {
            // XOR.B #imm8, Rd — Drd imm8
            let rd = op_lo;
            let imm = (w0 & 0xFF) as u8;
            Decoded {
                insn: Instruction::Xor(Size::Byte, Operand::Imm8(imm), Operand::Reg8(rd)),
                len: 2,
            }
        }
        0xE => {
            // AND.B #imm8, Rd — Erd imm8
            let rd = op_lo;
            let imm = (w0 & 0xFF) as u8;
            Decoded {
                insn: Instruction::And(Size::Byte, Operand::Imm8(imm), Operand::Reg8(rd)),
                len: 2,
            }
        }
        0xF => {
            // MOV.B #imm8, Rd — Frd imm8
            let rd = op_lo;
            let imm = (w0 & 0xFF) as u8;
            Decoded {
                insn: Instruction::Mov(Size::Byte, Operand::Imm8(imm), Operand::Reg8(rd)),
                len: 2,
            }
        }
        _ => unreachable!(),
    }
}

fn decode_condition(code: u8) -> Condition {
    match code {
        0x0 => Condition::Always,
        0x1 => Condition::Never,
        0x2 => Condition::Hi,
        0x3 => Condition::Ls,
        0x4 => Condition::Cc,
        0x5 => Condition::Cs,
        0x6 => Condition::Ne,
        0x7 => Condition::Eq,
        0x8 => Condition::Vc,
        0x9 => Condition::Vs,
        0xA => Condition::Pl,
        0xB => Condition::Mi,
        0xC => Condition::Ge,
        0xD => Condition::Lt,
        0xE => Condition::Gt,
        0xF => Condition::Le,
        _ => unreachable!(),
    }
}

/// Group 0: NOP, SLEEP, STC, LDC, ORC, XORC, ANDC, ADD/MOV/etc register ops
fn decode_group_0(bus: &mut MemoryBus, pc: u32, w0: u16, op_lo: u8, nib2: u8, nib3: u8) -> Decoded {
    match op_lo {
        0x0 => {
            match nib2 {
                0x0 => {
                    // NOP (0x0000)
                    Decoded { insn: Instruction::Nop, len: 2 }
                }
                _ => Decoded { insn: Instruction::Unknown(w0), len: 2 },
            }
        }
        0x1 => {
            // Various prefix opcodes
            match (nib2, nib3) {
                (0x0, 0x0) => {
                    // 0100 prefix — SLEEP, LDC, STC, etc. or prefix for 32-bit ops
                    // Check next word
                    let w1 = bus.read_word(pc + 2);
                    decode_01_prefix(bus, pc, w1)
                }
                (0x4, 0x0) => {
                    // ORC #imm8, CCR  — 0140 imm8 (but nib2=4, nib3=0 gives 0x0140)
                    // Wait — 0x0140 is op_hi=0, op_lo=1, nib2=4, nib3=0
                    let imm = bus.read_byte(pc + 2);
                    // Actually ORC: 04 imm8
                    // No, ORC is 0x04xx. Let me re-check.
                    // 0100 prefix for MOV.L / extended ops
                    let w1 = bus.read_word(pc + 2);
                    decode_0100_mov_l(bus, pc, w1)
                }
                (0x8, 0x0) => {
                    // SLEEP (0x0180)
                    Decoded { insn: Instruction::Sleep, len: 2 }
                }
                (0xC, _) | (0xD, _) => {
                    // 01Cx / 01Dx — prefix for extended addressing
                    let w1 = bus.read_word(pc + 2);
                    decode_01cd_prefix(bus, pc, w0, w1, nib2, nib3)
                }
                (0xF, 0x0) => {
                    // 01F0: prefix for 32-bit @(d:16, ERn) or @(d:24, ERn) or @aa:24
                    let w1 = bus.read_word(pc + 2);
                    decode_01f0_prefix(bus, pc, w1)
                }
                _ => {
                    // 010x prefix for various extended MOV.L / other ops
                    let w1 = bus.read_word(pc + 2);
                    decode_01_extended(bus, pc, w0, w1, nib2, nib3)
                }
            }
        }
        0x2 => {
            // STC CCR, Rd (02 0r)
            Decoded {
                insn: Instruction::Stc(Operand::Ccr, Operand::Reg8(nib3)),
                len: 2,
            }
        }
        0x3 => {
            // LDC Rs, CCR (03 r0)
            Decoded {
                insn: Instruction::Ldc(Operand::Reg8(nib2), Operand::Ccr),
                len: 2,
            }
        }
        0x4 => {
            // ORC #imm8, CCR (04 imm8)
            let imm = (w0 & 0xFF) as u8;
            Decoded {
                insn: Instruction::Orc(Operand::Imm8(imm)),
                len: 2,
            }
        }
        0x5 => {
            // XORC #imm8, CCR (05 imm8)
            let imm = (w0 & 0xFF) as u8;
            Decoded {
                insn: Instruction::Xorc(Operand::Imm8(imm)),
                len: 2,
            }
        }
        0x6 => {
            // ANDC #imm8, CCR (06 imm8)
            let imm = (w0 & 0xFF) as u8;
            Decoded {
                insn: Instruction::Andc(Operand::Imm8(imm)),
                len: 2,
            }
        }
        0x7 => {
            // LDC #imm8, CCR (07 imm8)
            let imm = (w0 & 0xFF) as u8;
            Decoded {
                insn: Instruction::Ldc(Operand::Imm8(imm), Operand::Ccr),
                len: 2,
            }
        }
        0x8 => {
            // ADD.B Rs, Rd (08 sr)
            Decoded {
                insn: Instruction::Add(Size::Byte, Operand::Reg8(nib2), Operand::Reg8(nib3)),
                len: 2,
            }
        }
        0x9 => {
            // ADD.W Rs, Rd (09 sr)
            Decoded {
                insn: Instruction::Add(Size::Word, Operand::Reg16(nib2), Operand::Reg16(nib3)),
                len: 2,
            }
        }
        0xA => {
            // 0A xx: INC.B or ADD.L
            if nib2 & 0x8 != 0 {
                // ADD.L ERs, ERd (0A 1sss 0ddd — bit 3 of nib2 set)
                let rs = nib2 & 0x7;
                Decoded {
                    insn: Instruction::Add(Size::Long, Operand::Reg32(rs), Operand::Reg32(nib3)),
                    len: 2,
                }
            } else {
                // INC.B Rd (0A 0r)
                Decoded {
                    insn: Instruction::Inc(Size::Byte, Operand::Reg8(nib3)),
                    len: 2,
                }
            }
        }
        0xB => {
            // ADDS/INC.W/INC.L
            match nib2 {
                0x0 => {
                    // ADDS #1, ERd (0B 0r)
                    Decoded {
                        insn: Instruction::Adds(Operand::Imm32(1), Operand::Reg32(nib3)),
                        len: 2,
                    }
                }
                0x5 => {
                    // INC.W #1, Rd (0B 5r)
                    Decoded {
                        insn: Instruction::Inc(Size::Word, Operand::Reg16(nib3)),
                        len: 2,
                    }
                }
                0x7 => {
                    // INC.L #1, ERd (0B 7r)
                    Decoded {
                        insn: Instruction::Inc(Size::Long, Operand::Reg32(nib3)),
                        len: 2,
                    }
                }
                0x8 => {
                    // ADDS #2, ERd (0B 8r)
                    Decoded {
                        insn: Instruction::Adds(Operand::Imm32(2), Operand::Reg32(nib3)),
                        len: 2,
                    }
                }
                0x9 => {
                    // ADDS #4, ERd (0B 9r)
                    Decoded {
                        insn: Instruction::Adds(Operand::Imm32(4), Operand::Reg32(nib3)),
                        len: 2,
                    }
                }
                0xD => {
                    // INC.W #2, Rd (0B Dr)
                    // Actually DEC or INC #2
                    Decoded {
                        insn: Instruction::Inc(Size::Word, Operand::Reg16(nib3)),
                        len: 2,
                    }
                }
                0xF => {
                    // INC.L #2, ERd (0B Fr)
                    Decoded {
                        insn: Instruction::Inc(Size::Long, Operand::Reg32(nib3)),
                        len: 2,
                    }
                }
                _ => Decoded { insn: Instruction::Unknown(w0), len: 2 },
            }
        }
        0xC => {
            // MOV.B Rs, Rd (0C sr)
            Decoded {
                insn: Instruction::Mov(Size::Byte, Operand::Reg8(nib2), Operand::Reg8(nib3)),
                len: 2,
            }
        }
        0xD => {
            // MOV.W Rs, Rd (0D sr)
            Decoded {
                insn: Instruction::Mov(Size::Word, Operand::Reg16(nib2), Operand::Reg16(nib3)),
                len: 2,
            }
        }
        0xE => {
            // ADDX Rs, Rd (0E sr)
            Decoded {
                insn: Instruction::Addx(Operand::Reg8(nib2), Operand::Reg8(nib3)),
                len: 2,
            }
        }
        0xF => {
            // DAA / MOV.L ERs, ERd / MULXU etc
            match nib2 {
                0xA => {
                    // DAA Rd (0F Ar)
                    Decoded {
                        insn: Instruction::Daa(Operand::Reg8(nib3)),
                        len: 2,
                    }
                }
                0x8 | 0x9 | 0xB | 0xC | 0xD | 0xE | 0xF => {
                    // MOV.L ERs, ERd (0F 8s_d) — wait, that's not right
                    // H8/300H: 0F sr — MOV.L ERs, ERd where s = nib2 & 7, d = nib3
                    // Actually 0F 8x = MOV.L, where bit 3 of nib2 marks .L
                    if nib2 & 0x8 != 0 {
                        let rs = nib2 & 0x7;
                        Decoded {
                            insn: Instruction::Mov(Size::Long, Operand::Reg32(rs), Operand::Reg32(nib3)),
                            len: 2,
                        }
                    } else {
                        Decoded { insn: Instruction::Unknown(w0), len: 2 }
                    }
                }
                _ => Decoded { insn: Instruction::Unknown(w0), len: 2 },
            }
        }
        _ => Decoded { insn: Instruction::Unknown(w0), len: 2 },
    }
}

/// Decode 0100 prefix — extended to 32-bit MOV.L ops and other 4-byte instructions
fn decode_0100_mov_l(bus: &mut MemoryBus, pc: u32, w1: u16) -> Decoded {
    let w1_hi = (w1 >> 12) as u8;
    let w1_lo = ((w1 >> 8) & 0xF) as u8;
    let w1_n2 = ((w1 >> 4) & 0xF) as u8;
    let w1_n3 = (w1 & 0xF) as u8;

    match w1_hi {
        0x6 => {
            match w1_lo {
                0x9 => {
                    // MOV.L @ERs, ERd (0100 69 s0 d0)
                    // s = w1_n2 >> 0 (top 3 bits), d = w1_n3
                    let rs = w1_n2 & 0x7;
                    let rd = w1_n3;
                    if w1_n2 & 0x8 == 0 {
                        Decoded {
                            insn: Instruction::Mov(Size::Long, Operand::RegIndirect(rs), Operand::Reg32(rd)),
                            len: 4,
                        }
                    } else {
                        // MOV.L ERs, @ERd (0100 69 8s 0d) — bit 3 = direction
                        let rs_mov = w1_n3;
                        let rd_addr = w1_n2 & 0x7;
                        Decoded {
                            insn: Instruction::Mov(Size::Long, Operand::Reg32(rs_mov), Operand::RegIndirect(rd_addr)),
                            len: 4,
                        }
                    }
                }
                0xB => {
                    // MOV.L @ERs+, ERd (0100 6B 0s_d) — post-increment
                    // or MOV.L ERs, @-ERd (0100 6B 8s_d) — pre-decrement
                    if w1_n2 & 0x8 == 0 {
                        // Post-increment read
                        if w1_n2 == 0x0 {
                            // MOV.L @aa:16, ERd (0100 6B 00 0d aa16)
                            let rd = w1_n3;
                            let abs = bus.read_word(pc + 4);
                            Decoded {
                                insn: Instruction::Mov(Size::Long, Operand::Abs16(abs), Operand::Reg32(rd)),
                                len: 6,
                            }
                        } else if w1_n2 == 0x2 {
                            // MOV.L @aa:24, ERd (0100 6B 20 0d aa24)
                            let rd = w1_n3;
                            let abs_hi = bus.read_word(pc + 4) as u32;
                            let abs_lo = bus.read_word(pc + 6) as u32;
                            let abs = (abs_hi << 16) | abs_lo;
                            Decoded {
                                insn: Instruction::Mov(Size::Long, Operand::Abs24(abs), Operand::Reg32(rd)),
                                len: 8,
                            }
                        } else {
                            Decoded { insn: Instruction::Unknown(0x0100), len: 4 }
                        }
                    } else {
                        // Write to memory
                        if w1_n2 == 0x8 {
                            // MOV.L ERs, @aa:16 (0100 6B 80 s0 aa16)
                            let rs = w1_n3;
                            let abs = bus.read_word(pc + 4);
                            Decoded {
                                insn: Instruction::Mov(Size::Long, Operand::Reg32(rs), Operand::Abs16(abs)),
                                len: 6,
                            }
                        } else if w1_n2 == 0xA {
                            // MOV.L ERs, @aa:24 (0100 6B A0 s0 aa24)
                            let rs = w1_n3;
                            let abs_hi = bus.read_word(pc + 4) as u32;
                            let abs_lo = bus.read_word(pc + 6) as u32;
                            let abs = (abs_hi << 16) | abs_lo;
                            Decoded {
                                insn: Instruction::Mov(Size::Long, Operand::Reg32(rs), Operand::Abs24(abs)),
                                len: 8,
                            }
                        } else {
                            Decoded { insn: Instruction::Unknown(0x0100), len: 4 }
                        }
                    }
                }
                0xD => {
                    // MOV.L @ERs+, ERd (0100 6D 7s 0d) — post-inc
                    if w1_n2 & 0x8 == 0 {
                        let rs = w1_n2 & 0x7;
                        let rd = w1_n3;
                        Decoded {
                            insn: Instruction::Mov(Size::Long, Operand::PostInc(rs), Operand::Reg32(rd)),
                            len: 4,
                        }
                    } else {
                        // MOV.L ERs, @-ERd (0100 6D Fs 0d) — pre-dec
                        let rd = w1_n2 & 0x7;
                        let rs = w1_n3;
                        Decoded {
                            insn: Instruction::Mov(Size::Long, Operand::Reg32(rs), Operand::PreDec(rd)),
                            len: 4,
                        }
                    }
                }
                0xF => {
                    // MOV.L @(d:16, ERs), ERd (0100 6F sr disp16)
                    let rs = w1_n2 & 0x7;
                    let rd = w1_n3;
                    let disp = bus.read_word(pc + 4) as i16;
                    if w1_n2 & 0x8 == 0 {
                        Decoded {
                            insn: Instruction::Mov(Size::Long, Operand::RegIndirectDisp16(rs, disp), Operand::Reg32(rd)),
                            len: 6,
                        }
                    } else {
                        // MOV.L ERs, @(d:16, ERd)
                        let rs_val = w1_n3;
                        let rd_addr = w1_n2 & 0x7;
                        Decoded {
                            insn: Instruction::Mov(Size::Long, Operand::Reg32(rs_val), Operand::RegIndirectDisp16(rd_addr, disp)),
                            len: 6,
                        }
                    }
                }
                _ => Decoded { insn: Instruction::Unknown(0x0100), len: 4 },
            }
        }
        _ => Decoded { insn: Instruction::Unknown(0x0100), len: 4 },
    }
}

/// Decode 0100 sub-prefix (for LDC/STC memory modes and MOV.L extended)
fn decode_01_prefix(bus: &mut MemoryBus, pc: u32, w1: u16) -> Decoded {
    let w1_hi = (w1 >> 12) as u8;
    let w1_lo = ((w1 >> 8) & 0xF) as u8;

    match w1_hi {
        0x6 => decode_0100_mov_l(bus, pc, w1),
        0x7 => {
            // 0100 78xx — MOV.L with 24-bit displacement
            // Format: 0100 78 r0 6B [2|A]s 00 dd dd dd (10 bytes total)
            if w1_lo == 0x8 {
                let base_reg = ((w1 >> 4) & 0x7) as u8;
                let w2 = bus.read_word(pc + 4); // 6B [mode]s
                let _pad = bus.read_byte(pc + 6); // 00
                let d_hi = bus.read_byte(pc + 7) as u32;
                let d_mid = bus.read_byte(pc + 8) as u32;
                let d_lo = bus.read_byte(pc + 9) as u32;
                let disp = (d_hi << 16) | (d_mid << 8) | d_lo;

                let w2_hi = (w2 >> 8) as u8;
                let mode = (w2 >> 4) & 0xF;
                let reg = (w2 & 0xF) as u8;

                if w2_hi == 0x6B {
                    if mode & 0x8 == 0 {
                        // Read: MOV.L @(d:24, ERbase), ERdst
                        Decoded {
                            insn: Instruction::Mov(Size::Long,
                                Operand::RegIndirectDisp24(base_reg, disp),
                                Operand::Reg32(reg)),
                            len: 10,
                        }
                    } else {
                        // Write: MOV.L ERsrc, @(d:24, ERbase)
                        Decoded {
                            insn: Instruction::Mov(Size::Long,
                                Operand::Reg32(reg),
                                Operand::RegIndirectDisp24(base_reg, disp)),
                            len: 10,
                        }
                    }
                } else {
                    Decoded { insn: Instruction::Unknown(0x0100), len: 10 }
                }
            } else {
                Decoded { insn: Instruction::Unknown(0x0100), len: 4 }
            }
        }
        _ => Decoded { insn: Instruction::Unknown(0x0100), len: 4 },
    }
}

/// Decode 01C0/01D0 prefix — extended addressing for MOV/bit ops
fn decode_01cd_prefix(_bus: &mut MemoryBus, _pc: u32, w0: u16, _w1: u16, _nib2: u8, _nib3: u8) -> Decoded {
    // These are complex prefix chains for absolute 24-bit bit operations
    // Stub for now — will be refined when firmware hits these paths
    Decoded { insn: Instruction::Unknown(w0), len: 4 }
}

/// Decode 01F0 prefix — 32-bit MOV.L with 24-bit displacement
fn decode_01f0_prefix(bus: &mut MemoryBus, pc: u32, w1: u16) -> Decoded {
    let w1_lo = ((w1 >> 8) & 0xF) as u8;
    let w1_n2 = ((w1 >> 4) & 0xF) as u8;
    let w1_n3 = (w1 & 0xF) as u8;

    match w1_lo {
        0x6 => {
            // MOV.L @(d:24, ERs), ERd (01F0 6B 2s_d disp24)
            if w1_n2 & 0x8 == 0 {
                let rs = w1_n2 & 0x7;
                let rd = w1_n3;
                let disp_hi = bus.read_word(pc + 4) as u32;
                let disp_lo = bus.read_word(pc + 6) as u32;
                let disp = (disp_hi << 16) | disp_lo;
                Decoded {
                    insn: Instruction::Mov(Size::Long, Operand::RegIndirectDisp24(rs, disp), Operand::Reg32(rd)),
                    len: 8,
                }
            } else {
                let rs = w1_n3;
                let rd = w1_n2 & 0x7;
                let disp_hi = bus.read_word(pc + 4) as u32;
                let disp_lo = bus.read_word(pc + 6) as u32;
                let disp = (disp_hi << 16) | disp_lo;
                Decoded {
                    insn: Instruction::Mov(Size::Long, Operand::Reg32(rs), Operand::RegIndirectDisp24(rd, disp)),
                    len: 8,
                }
            }
        }
        _ => Decoded { insn: Instruction::Unknown(0x01F0), len: 4 },
    }
}

/// Decode remaining 01xx prefixes
fn decode_01_extended(_bus: &mut MemoryBus, _pc: u32, w0: u16, _w1: u16, _nib2: u8, _nib3: u8) -> Decoded {
    Decoded { insn: Instruction::Unknown(w0), len: 4 }
}

/// Group 1: various ops — CMP, MOV, shifts, etc
fn decode_group_1(bus: &mut MemoryBus, pc: u32, w0: u16, op_lo: u8, nib2: u8, nib3: u8) -> Decoded {
    match op_lo {
        0x0 => {
            // SHLL/SHAL/ROTL etc (10 xx)
            match nib2 {
                0x0 => Decoded {
                    insn: Instruction::Shal(Size::Byte, Operand::Reg8(nib3)),
                    len: 2,
                },
                0x1 => Decoded {
                    insn: Instruction::Shal(Size::Word, Operand::Reg16(nib3)),
                    len: 2,
                },
                0x3 => Decoded {
                    insn: Instruction::Shal(Size::Long, Operand::Reg32(nib3)),
                    len: 2,
                },
                0x8 => Decoded {
                    insn: Instruction::Shar(Size::Byte, Operand::Reg8(nib3)),
                    len: 2,
                },
                0x9 => Decoded {
                    insn: Instruction::Shar(Size::Word, Operand::Reg16(nib3)),
                    len: 2,
                },
                0xB => Decoded {
                    insn: Instruction::Shar(Size::Long, Operand::Reg32(nib3)),
                    len: 2,
                },
                _ => Decoded { insn: Instruction::Unknown(w0), len: 2 },
            }
        }
        0x1 => {
            // SHLL/SHLR
            match nib2 {
                0x0 => Decoded {
                    insn: Instruction::Shll(Size::Byte, Operand::Reg8(nib3)),
                    len: 2,
                },
                0x1 => Decoded {
                    insn: Instruction::Shll(Size::Word, Operand::Reg16(nib3)),
                    len: 2,
                },
                0x3 => Decoded {
                    insn: Instruction::Shll(Size::Long, Operand::Reg32(nib3)),
                    len: 2,
                },
                0x8 => Decoded {
                    insn: Instruction::Shlr(Size::Byte, Operand::Reg8(nib3)),
                    len: 2,
                },
                0x9 => Decoded {
                    insn: Instruction::Shlr(Size::Word, Operand::Reg16(nib3)),
                    len: 2,
                },
                0xB => Decoded {
                    insn: Instruction::Shlr(Size::Long, Operand::Reg32(nib3)),
                    len: 2,
                },
                _ => Decoded { insn: Instruction::Unknown(w0), len: 2 },
            }
        }
        0x2 => {
            // ROTL/ROTR
            match nib2 {
                0x0 => Decoded {
                    insn: Instruction::Rotl(Size::Byte, Operand::Reg8(nib3)),
                    len: 2,
                },
                0x1 => Decoded {
                    insn: Instruction::Rotl(Size::Word, Operand::Reg16(nib3)),
                    len: 2,
                },
                0x3 => Decoded {
                    insn: Instruction::Rotl(Size::Long, Operand::Reg32(nib3)),
                    len: 2,
                },
                0x8 => Decoded {
                    insn: Instruction::Rotr(Size::Byte, Operand::Reg8(nib3)),
                    len: 2,
                },
                0x9 => Decoded {
                    insn: Instruction::Rotr(Size::Word, Operand::Reg16(nib3)),
                    len: 2,
                },
                0xB => Decoded {
                    insn: Instruction::Rotr(Size::Long, Operand::Reg32(nib3)),
                    len: 2,
                },
                _ => Decoded { insn: Instruction::Unknown(w0), len: 2 },
            }
        }
        0x3 => {
            // ROTXL/ROTXR
            match nib2 {
                0x0 => Decoded {
                    insn: Instruction::Rotxl(Size::Byte, Operand::Reg8(nib3)),
                    len: 2,
                },
                0x1 => Decoded {
                    insn: Instruction::Rotxl(Size::Word, Operand::Reg16(nib3)),
                    len: 2,
                },
                0x3 => Decoded {
                    insn: Instruction::Rotxl(Size::Long, Operand::Reg32(nib3)),
                    len: 2,
                },
                0x8 => Decoded {
                    insn: Instruction::Rotxr(Size::Byte, Operand::Reg8(nib3)),
                    len: 2,
                },
                0x9 => Decoded {
                    insn: Instruction::Rotxr(Size::Word, Operand::Reg16(nib3)),
                    len: 2,
                },
                0xB => Decoded {
                    insn: Instruction::Rotxr(Size::Long, Operand::Reg32(nib3)),
                    len: 2,
                },
                _ => Decoded { insn: Instruction::Unknown(w0), len: 2 },
            }
        }
        0x4 => {
            // OR.B Rs, Rd (14 sr)
            Decoded {
                insn: Instruction::Or(Size::Byte, Operand::Reg8(nib2), Operand::Reg8(nib3)),
                len: 2,
            }
        }
        0x5 => {
            // XOR.B Rs, Rd (15 sr)
            Decoded {
                insn: Instruction::Xor(Size::Byte, Operand::Reg8(nib2), Operand::Reg8(nib3)),
                len: 2,
            }
        }
        0x6 => {
            // AND.B Rs, Rd (16 sr)
            Decoded {
                insn: Instruction::And(Size::Byte, Operand::Reg8(nib2), Operand::Reg8(nib3)),
                len: 2,
            }
        }
        0x7 => {
            match nib2 {
                0x0 => {
                    // NOT.B Rd (17 0r)
                    Decoded {
                        insn: Instruction::Not(Size::Byte, Operand::Reg8(nib3)),
                        len: 2,
                    }
                }
                0x1 => {
                    // NOT.W Rd (17 1r)
                    Decoded {
                        insn: Instruction::Not(Size::Word, Operand::Reg16(nib3)),
                        len: 2,
                    }
                }
                0x3 => {
                    // NOT.L ERd (17 3r)
                    Decoded {
                        insn: Instruction::Not(Size::Long, Operand::Reg32(nib3)),
                        len: 2,
                    }
                }
                0x5 => {
                    // EXTU.W Rd (17 5r)
                    Decoded {
                        insn: Instruction::Extu(Size::Word, Operand::Reg16(nib3)),
                        len: 2,
                    }
                }
                0x7 => {
                    // EXTU.L ERd (17 7r)
                    Decoded {
                        insn: Instruction::Extu(Size::Long, Operand::Reg32(nib3)),
                        len: 2,
                    }
                }
                0x8 => {
                    // NEG.B Rd (17 8r)
                    Decoded {
                        insn: Instruction::Neg(Size::Byte, Operand::Reg8(nib3)),
                        len: 2,
                    }
                }
                0x9 => {
                    // NEG.W Rd (17 9r)
                    Decoded {
                        insn: Instruction::Neg(Size::Word, Operand::Reg16(nib3)),
                        len: 2,
                    }
                }
                0xB => {
                    // NEG.L ERd (17 Br)
                    Decoded {
                        insn: Instruction::Neg(Size::Long, Operand::Reg32(nib3)),
                        len: 2,
                    }
                }
                0xD => {
                    // EXTS.W Rd (17 Dr)
                    Decoded {
                        insn: Instruction::Exts(Size::Word, Operand::Reg16(nib3)),
                        len: 2,
                    }
                }
                0xF => {
                    // EXTS.L ERd (17 Fr)
                    Decoded {
                        insn: Instruction::Exts(Size::Long, Operand::Reg32(nib3)),
                        len: 2,
                    }
                }
                _ => Decoded { insn: Instruction::Unknown(w0), len: 2 },
            }
        }
        0x8 => {
            // SUB.B Rs, Rd (18 sr)
            Decoded {
                insn: Instruction::Sub(Size::Byte, Operand::Reg8(nib2), Operand::Reg8(nib3)),
                len: 2,
            }
        }
        0x9 => {
            // SUB.W Rs, Rd (19 sr)
            Decoded {
                insn: Instruction::Sub(Size::Word, Operand::Reg16(nib2), Operand::Reg16(nib3)),
                len: 2,
            }
        }
        0xA => {
            // 1A xx: DEC.B or SUB.L
            if nib2 & 0x8 != 0 {
                // SUB.L ERs, ERd (1A 1sss 0ddd)
                let rs = nib2 & 0x7;
                Decoded {
                    insn: Instruction::Sub(Size::Long, Operand::Reg32(rs), Operand::Reg32(nib3)),
                    len: 2,
                }
            } else {
                // DEC.B Rd (1A 0r)
                Decoded {
                    insn: Instruction::Dec(Size::Byte, Operand::Reg8(nib3)),
                    len: 2,
                }
            }
        }
        0xB => {
            // SUBS / DEC.W / DEC.L
            match nib2 {
                0x0 => Decoded {
                    insn: Instruction::Subs(Operand::Imm32(1), Operand::Reg32(nib3)),
                    len: 2,
                },
                0x5 => Decoded {
                    insn: Instruction::Dec(Size::Word, Operand::Reg16(nib3)),
                    len: 2,
                },
                0x7 => Decoded {
                    insn: Instruction::Dec(Size::Long, Operand::Reg32(nib3)),
                    len: 2,
                },
                0x8 => Decoded {
                    insn: Instruction::Subs(Operand::Imm32(2), Operand::Reg32(nib3)),
                    len: 2,
                },
                0x9 => Decoded {
                    insn: Instruction::Subs(Operand::Imm32(4), Operand::Reg32(nib3)),
                    len: 2,
                },
                0xD => Decoded {
                    insn: Instruction::Dec(Size::Word, Operand::Reg16(nib3)),
                    len: 2,
                },
                0xF => Decoded {
                    insn: Instruction::Dec(Size::Long, Operand::Reg32(nib3)),
                    len: 2,
                },
                _ => Decoded { insn: Instruction::Unknown(w0), len: 2 },
            }
        }
        0xC => {
            // CMP.B Rs, Rd (1C sr)
            Decoded {
                insn: Instruction::Cmp(Size::Byte, Operand::Reg8(nib2), Operand::Reg8(nib3)),
                len: 2,
            }
        }
        0xD => {
            // CMP.W Rs, Rd (1D sr)
            Decoded {
                insn: Instruction::Cmp(Size::Word, Operand::Reg16(nib2), Operand::Reg16(nib3)),
                len: 2,
            }
        }
        0xE => {
            // SUBX Rs, Rd (1E sr)
            Decoded {
                insn: Instruction::Subx(Operand::Reg8(nib2), Operand::Reg8(nib3)),
                len: 2,
            }
        }
        0xF => {
            // DAS Rd (1F Ar) or other
            match nib2 {
                0xA => Decoded {
                    insn: Instruction::Das(Operand::Reg8(nib3)),
                    len: 2,
                },
                0x8..=0xF => {
                    // CMP.L ERs, ERd — 1F 8s nib3
                    if nib2 & 0x8 != 0 {
                        let rs = nib2 & 0x7;
                        Decoded {
                            insn: Instruction::Cmp(Size::Long, Operand::Reg32(rs), Operand::Reg32(nib3)),
                            len: 2,
                        }
                    } else {
                        Decoded { insn: Instruction::Unknown(w0), len: 2 }
                    }
                }
                _ => Decoded { insn: Instruction::Unknown(w0), len: 2 },
            }
        }
        _ => Decoded { insn: Instruction::Unknown(w0), len: 2 },
    }
}

/// Group 5: RTS, RTE, BSR, JMP, JSR, TRAPA, EEPMOV etc
fn decode_group_5(bus: &mut MemoryBus, pc: u32, w0: u16, op_lo: u8, nib2: u8, nib3: u8) -> Decoded {
    match op_lo {
        0x0 => {
            // MULXU.B Rs, Rd (50 sr)
            Decoded {
                insn: Instruction::MulxuB(Operand::Reg8(nib2), Operand::Reg16(nib3)),
                len: 2,
            }
        }
        0x1 => {
            // DIVXU.B Rs, Rd (51 sr)
            Decoded {
                insn: Instruction::DivxuB(Operand::Reg8(nib2), Operand::Reg16(nib3)),
                len: 2,
            }
        }
        0x2 => {
            // MULXU.W Rs, ERd (52 sr)
            Decoded {
                insn: Instruction::MulxuW(Operand::Reg16(nib2), Operand::Reg32(nib3)),
                len: 2,
            }
        }
        0x3 => {
            // DIVXU.W Rs, ERd (53 sr)
            Decoded {
                insn: Instruction::DivxuW(Operand::Reg16(nib2), Operand::Reg32(nib3)),
                len: 2,
            }
        }
        0x4 => {
            // RTS (5470)
            Decoded { insn: Instruction::Rts, len: 2 }
        }
        0x5 => {
            // BSR d:8 (55 disp8)
            let disp = (w0 & 0xFF) as i8;
            Decoded {
                insn: Instruction::Bsr(Operand::PcRel8(disp)),
                len: 2,
            }
        }
        0x6 => {
            // RTE (5670)
            Decoded { insn: Instruction::Rte, len: 2 }
        }
        0x7 => {
            // TRAPA #imm (57 i0) where i = nib2 >> 2
            let vec_num = nib2 >> 2;
            Decoded {
                insn: Instruction::Trapa(vec_num),
                len: 2,
            }
        }
        0x8 => {
            // Bcc d:16 (58 c0 disp16)
            let cond = decode_condition(nib2);
            let disp = bus.read_word(pc + 2) as i16;
            Decoded {
                insn: Instruction::Bcc(cond, Operand::PcRel16(disp)),
                len: 4,
            }
        }
        0x9 => {
            // JMP @ERn (5970) or JMP @aa:24 (5A) or JMP @@aa:8 (5B)
            // Wait — 59 = JMP @ERn
            let rn = nib2 & 0x7;
            Decoded {
                insn: Instruction::Jmp(Operand::RegIndirect(rn)),
                len: 2,
            }
        }
        0xA => {
            // JMP @aa:24 (5A aa:24)
            let abs_hi = ((nib2 as u32) << 16) | ((nib3 as u32) << 8) | (bus.read_byte(pc + 2) as u32);
            let abs_lo = bus.read_byte(pc + 3) as u32;
            // Wait, JMP @aa:24 is 4 bytes: 5A xx xx xx
            // The address is in bytes 1-3 of the 4-byte instruction
            let addr = ((nib2 as u32) << 20) | ((nib3 as u32) << 16) | (bus.read_word(pc + 2) as u32);
            Decoded {
                insn: Instruction::Jmp(Operand::Abs24(addr & 0x00FFFFFF)),
                len: 4,
            }
        }
        0xB => {
            // JMP @@aa:8 (5B disp)
            let abs = (w0 & 0xFF) as u8;
            Decoded {
                insn: Instruction::Jmp(Operand::MemIndirect(abs)),
                len: 2,
            }
        }
        0xC => {
            // BSR d:16 (5C 00 disp16)
            let disp = bus.read_word(pc + 2) as i16;
            Decoded {
                insn: Instruction::Bsr(Operand::PcRel16(disp)),
                len: 4,
            }
        }
        0xD => {
            // JSR @ERn (5D n0)
            let rn = nib2 & 0x7;
            Decoded {
                insn: Instruction::Jsr(Operand::RegIndirect(rn)),
                len: 2,
            }
        }
        0xE => {
            // JSR @aa:24 (5E xx xx xx)
            let addr = ((nib2 as u32) << 20) | ((nib3 as u32) << 16) | (bus.read_word(pc + 2) as u32);
            Decoded {
                insn: Instruction::Jsr(Operand::Abs24(addr & 0x00FFFFFF)),
                len: 4,
            }
        }
        0xF => {
            // JSR @@aa:8 (5F disp)
            let abs = (w0 & 0xFF) as u8;
            Decoded {
                insn: Instruction::Jsr(Operand::MemIndirect(abs)),
                len: 2,
            }
        }
        _ => Decoded { insn: Instruction::Unknown(w0), len: 2 },
    }
}

/// Group 6: MOV, AND, OR, XOR with various addressing modes (word/byte memory access)
fn decode_group_6(bus: &mut MemoryBus, pc: u32, w0: u16, op_lo: u8, nib2: u8, nib3: u8) -> Decoded {
    match op_lo {
        0x0 => {
            // BSET Rn, Rd (60 sr) — bit set register to register
            Decoded {
                insn: Instruction::Bset(Operand::Reg8(nib2), Operand::Reg8(nib3)),
                len: 2,
            }
        }
        0x1 => {
            // BNOT Rn, Rd (61 sr)
            Decoded {
                insn: Instruction::Bnot(Operand::Reg8(nib2), Operand::Reg8(nib3)),
                len: 2,
            }
        }
        0x2 => {
            // BCLR Rn, Rd (62 sr)
            Decoded {
                insn: Instruction::Bclr(Operand::Reg8(nib2), Operand::Reg8(nib3)),
                len: 2,
            }
        }
        0x3 => {
            // BTST Rn, Rd (63 sr)
            Decoded {
                insn: Instruction::Btst(Operand::Reg8(nib2), Operand::Reg8(nib3)),
                len: 2,
            }
        }
        0x4 => {
            // OR.W Rs, Rd (64 sr)
            Decoded {
                insn: Instruction::Or(Size::Word, Operand::Reg16(nib2), Operand::Reg16(nib3)),
                len: 2,
            }
        }
        0x5 => {
            // XOR.W Rs, Rd (65 sr)
            Decoded {
                insn: Instruction::Xor(Size::Word, Operand::Reg16(nib2), Operand::Reg16(nib3)),
                len: 2,
            }
        }
        0x6 => {
            // AND.W Rs, Rd (66 sr)
            Decoded {
                insn: Instruction::And(Size::Word, Operand::Reg16(nib2), Operand::Reg16(nib3)),
                len: 2,
            }
        }
        0x7 => {
            // BST/BIST #imm, Rd (67 ir) — bit 7 of nib2 selects BST vs BIST
            if nib2 & 0x8 == 0 {
                Decoded {
                    insn: Instruction::Bst(Operand::Imm8(nib2 & 0x7), Operand::Reg8(nib3)),
                    len: 2,
                }
            } else {
                Decoded {
                    insn: Instruction::Bist(Operand::Imm8(nib2 & 0x7), Operand::Reg8(nib3)),
                    len: 2,
                }
            }
        }
        0x8 => {
            // MOV.B @ERs, Rd (68 sr) — bit 7 of nib2 selects direction
            if nib2 & 0x8 == 0 {
                let rs = nib2 & 0x7;
                Decoded {
                    insn: Instruction::Mov(Size::Byte, Operand::RegIndirect(rs), Operand::Reg8(nib3)),
                    len: 2,
                }
            } else {
                // MOV.B Rs, @ERd (68 8s Rd)
                let rd = nib2 & 0x7;
                Decoded {
                    insn: Instruction::Mov(Size::Byte, Operand::Reg8(nib3), Operand::RegIndirect(rd)),
                    len: 2,
                }
            }
        }
        0x9 => {
            // MOV.W @ERs, Rd (69 sr) / MOV.W Rs, @ERd (69 8s Rd)
            if nib2 & 0x8 == 0 {
                let rs = nib2 & 0x7;
                Decoded {
                    insn: Instruction::Mov(Size::Word, Operand::RegIndirect(rs), Operand::Reg16(nib3)),
                    len: 2,
                }
            } else {
                let rd = nib2 & 0x7;
                Decoded {
                    insn: Instruction::Mov(Size::Word, Operand::Reg16(nib3), Operand::RegIndirect(rd)),
                    len: 2,
                }
            }
        }
        0xA => {
            // MOV.B @(d:16,ERs),Rd (6A 0s disp16) or MOV.B Rd,@(d:16,ERd) (6A 8s disp16)
            // Also: MOV.B @aa:16 (6A 00), MOV.B @aa:24 (6A 20)
            match nib2 {
                0x0 => {
                    // MOV.B @aa:16, Rd
                    let abs = bus.read_word(pc + 2);
                    Decoded {
                        insn: Instruction::Mov(Size::Byte, Operand::Abs16(abs), Operand::Reg8(nib3)),
                        len: 4,
                    }
                }
                0x2 => {
                    // MOV.B @aa:24, Rd
                    let abs_hi = bus.read_word(pc + 2) as u32;
                    let abs_lo = bus.read_word(pc + 4) as u32;
                    let abs = (abs_hi << 16) | abs_lo;
                    Decoded {
                        insn: Instruction::Mov(Size::Byte, Operand::Abs24(abs), Operand::Reg8(nib3)),
                        len: 6,
                    }
                }
                0x8 => {
                    // MOV.B Rs, @aa:16
                    let abs = bus.read_word(pc + 2);
                    Decoded {
                        insn: Instruction::Mov(Size::Byte, Operand::Reg8(nib3), Operand::Abs16(abs)),
                        len: 4,
                    }
                }
                0xA => {
                    // MOV.B Rs, @aa:24
                    let abs_hi = bus.read_word(pc + 2) as u32;
                    let abs_lo = bus.read_word(pc + 4) as u32;
                    let abs = (abs_hi << 16) | abs_lo;
                    Decoded {
                        insn: Instruction::Mov(Size::Byte, Operand::Reg8(nib3), Operand::Abs24(abs)),
                        len: 6,
                    }
                }
                0x1..=0x7 if nib2 & 0x8 == 0 => {
                    // MOV.B @(d:16, ERs), Rd
                    let rs = nib2 & 0x7;
                    let disp = bus.read_word(pc + 2) as i16;
                    Decoded {
                        insn: Instruction::Mov(Size::Byte, Operand::RegIndirectDisp16(rs, disp), Operand::Reg8(nib3)),
                        len: 4,
                    }
                }
                _ => {
                    if nib2 & 0x8 != 0 {
                        // MOV.B Rs, @(d:16, ERd)
                        let rd = nib2 & 0x7;
                        let disp = bus.read_word(pc + 2) as i16;
                        Decoded {
                            insn: Instruction::Mov(Size::Byte, Operand::Reg8(nib3), Operand::RegIndirectDisp16(rd, disp)),
                            len: 4,
                        }
                    } else {
                        Decoded { insn: Instruction::Unknown(w0), len: 2 }
                    }
                }
            }
        }
        0xB => {
            // MOV.W @(d:16,ERs),Rd or MOV.W @aa:16/24,Rd etc
            match nib2 {
                0x0 => {
                    let abs = bus.read_word(pc + 2);
                    Decoded {
                        insn: Instruction::Mov(Size::Word, Operand::Abs16(abs), Operand::Reg16(nib3)),
                        len: 4,
                    }
                }
                0x2 => {
                    let abs_hi = bus.read_word(pc + 2) as u32;
                    let abs_lo = bus.read_word(pc + 4) as u32;
                    let abs = (abs_hi << 16) | abs_lo;
                    Decoded {
                        insn: Instruction::Mov(Size::Word, Operand::Abs24(abs), Operand::Reg16(nib3)),
                        len: 6,
                    }
                }
                0x8 => {
                    let abs = bus.read_word(pc + 2);
                    Decoded {
                        insn: Instruction::Mov(Size::Word, Operand::Reg16(nib3), Operand::Abs16(abs)),
                        len: 4,
                    }
                }
                0xA => {
                    let abs_hi = bus.read_word(pc + 2) as u32;
                    let abs_lo = bus.read_word(pc + 4) as u32;
                    let abs = (abs_hi << 16) | abs_lo;
                    Decoded {
                        insn: Instruction::Mov(Size::Word, Operand::Reg16(nib3), Operand::Abs24(abs)),
                        len: 6,
                    }
                }
                _ => {
                    if nib2 & 0x8 == 0 {
                        let rs = nib2 & 0x7;
                        let disp = bus.read_word(pc + 2) as i16;
                        Decoded {
                            insn: Instruction::Mov(Size::Word, Operand::RegIndirectDisp16(rs, disp), Operand::Reg16(nib3)),
                            len: 4,
                        }
                    } else {
                        let rd = nib2 & 0x7;
                        let disp = bus.read_word(pc + 2) as i16;
                        Decoded {
                            insn: Instruction::Mov(Size::Word, Operand::Reg16(nib3), Operand::RegIndirectDisp16(rd, disp)),
                            len: 4,
                        }
                    }
                }
            }
        }
        0xC => {
            // MOV.B @ERs+, Rd / MOV.B Rs, @-ERd (6C sr) post-inc/pre-dec
            if nib2 & 0x8 == 0 {
                let rs = nib2 & 0x7;
                Decoded {
                    insn: Instruction::Mov(Size::Byte, Operand::PostInc(rs), Operand::Reg8(nib3)),
                    len: 2,
                }
            } else {
                let rd = nib2 & 0x7;
                Decoded {
                    insn: Instruction::Mov(Size::Byte, Operand::Reg8(nib3), Operand::PreDec(rd)),
                    len: 2,
                }
            }
        }
        0xD => {
            // MOV.W @ERs+, Rd / MOV.W Rs, @-ERd (6D sr)
            if nib2 & 0x8 == 0 {
                let rs = nib2 & 0x7;
                Decoded {
                    insn: Instruction::Mov(Size::Word, Operand::PostInc(rs), Operand::Reg16(nib3)),
                    len: 2,
                }
            } else {
                let rd = nib2 & 0x7;
                Decoded {
                    insn: Instruction::Mov(Size::Word, Operand::Reg16(nib3), Operand::PreDec(rd)),
                    len: 2,
                }
            }
        }
        0xE => {
            // MOV.B @(d:16,ERs),Rd / MOV.B Rd,@(d:16,ERd)
            let disp = bus.read_word(pc + 2) as i16;
            if nib2 & 0x8 == 0 {
                let rs = nib2 & 0x7;
                Decoded {
                    insn: Instruction::Mov(Size::Byte, Operand::RegIndirectDisp16(rs, disp), Operand::Reg8(nib3)),
                    len: 4,
                }
            } else {
                let rd = nib2 & 0x7;
                Decoded {
                    insn: Instruction::Mov(Size::Byte, Operand::Reg8(nib3), Operand::RegIndirectDisp16(rd, disp)),
                    len: 4,
                }
            }
        }
        0xF => {
            // MOV.W @(d:16,ERs),Rd / MOV.W Rd,@(d:16,ERd)
            let disp = bus.read_word(pc + 2) as i16;
            if nib2 & 0x8 == 0 {
                let rs = nib2 & 0x7;
                Decoded {
                    insn: Instruction::Mov(Size::Word, Operand::RegIndirectDisp16(rs, disp), Operand::Reg16(nib3)),
                    len: 4,
                }
            } else {
                let rd = nib2 & 0x7;
                Decoded {
                    insn: Instruction::Mov(Size::Word, Operand::Reg16(nib3), Operand::RegIndirectDisp16(rd, disp)),
                    len: 4,
                }
            }
        }
        _ => Decoded { insn: Instruction::Unknown(w0), len: 2 },
    }
}

/// Group 7: bit manipulation instructions, ADD/SUB/CMP with immediates, EEPMOV etc
fn decode_group_7(bus: &mut MemoryBus, pc: u32, w0: u16, op_lo: u8, nib2: u8, nib3: u8) -> Decoded {
    match op_lo {
        0x0 => {
            // BSET #imm, Rd (70 ir) — bit set immediate to register
            Decoded {
                insn: Instruction::Bset(Operand::Imm8(nib2 & 0x7), Operand::Reg8(nib3)),
                len: 2,
            }
        }
        0x1 => {
            // BNOT #imm, Rd (71 ir)
            Decoded {
                insn: Instruction::Bnot(Operand::Imm8(nib2 & 0x7), Operand::Reg8(nib3)),
                len: 2,
            }
        }
        0x2 => {
            // BCLR #imm, Rd (72 ir)
            Decoded {
                insn: Instruction::Bclr(Operand::Imm8(nib2 & 0x7), Operand::Reg8(nib3)),
                len: 2,
            }
        }
        0x3 => {
            // BTST #imm, Rd (73 ir)
            Decoded {
                insn: Instruction::Btst(Operand::Imm8(nib2 & 0x7), Operand::Reg8(nib3)),
                len: 2,
            }
        }
        0x4 => {
            // BOR/BIOR #imm, Rd (74 ir)
            if nib2 & 0x8 == 0 {
                Decoded {
                    insn: Instruction::Bor(Operand::Imm8(nib2 & 0x7), Operand::Reg8(nib3)),
                    len: 2,
                }
            } else {
                Decoded {
                    insn: Instruction::Bior(Operand::Imm8(nib2 & 0x7), Operand::Reg8(nib3)),
                    len: 2,
                }
            }
        }
        0x5 => {
            // BXOR/BIXOR #imm, Rd (75 ir)
            if nib2 & 0x8 == 0 {
                Decoded {
                    insn: Instruction::Bxor(Operand::Imm8(nib2 & 0x7), Operand::Reg8(nib3)),
                    len: 2,
                }
            } else {
                Decoded {
                    insn: Instruction::Bixor(Operand::Imm8(nib2 & 0x7), Operand::Reg8(nib3)),
                    len: 2,
                }
            }
        }
        0x6 => {
            // BAND/BIAND #imm, Rd (76 ir)
            if nib2 & 0x8 == 0 {
                Decoded {
                    insn: Instruction::Band(Operand::Imm8(nib2 & 0x7), Operand::Reg8(nib3)),
                    len: 2,
                }
            } else {
                Decoded {
                    insn: Instruction::Biand(Operand::Imm8(nib2 & 0x7), Operand::Reg8(nib3)),
                    len: 2,
                }
            }
        }
        0x7 => {
            // BLD/BILD #imm, Rd (77 ir)
            if nib2 & 0x8 == 0 {
                Decoded {
                    insn: Instruction::Bld(Operand::Imm8(nib2 & 0x7), Operand::Reg8(nib3)),
                    len: 2,
                }
            } else {
                Decoded {
                    insn: Instruction::Bild(Operand::Imm8(nib2 & 0x7), Operand::Reg8(nib3)),
                    len: 2,
                }
            }
        }
        0x8 => {
            // 78 prefix: bit operations on @(d:24, ERn)
            // Format: 78 rr 6A [mode]0 dd dd dd 00 [bit_op] [bit_nib] 0 = 10 bytes
            // Words: [78rr] [6Amm] [dddd] [dd00] [opbn]
            let base_reg = nib2 & 0x7;
            let w1 = bus.read_word(pc + 2);
            let w1_hi = (w1 >> 8) as u8;

            if w1_hi == 0x6A {
                let mode_byte = (w1 & 0xFF) as u8;
                let mode_hi = (mode_byte >> 4) & 0xF;

                // 78 prefix + 6A: bit operation on @(d:24, ERbase)
                // Format: 78 rr 6A [mode]x dd dd dd pp OP BN = 10 bytes
                // mode = 2 (read) or A (write-back), x = sub-mode (often 0 or 8)
                let w2 = bus.read_word(pc + 4);
                let w3 = bus.read_word(pc + 6);
                let w4 = bus.read_word(pc + 8);

                // Displacement: bytes 4-6 (24-bit)
                let disp = ((w2 as u32) << 8) | ((w3 >> 8) as u32);
                let disp = disp & 0x00FFFFFF;

                let bit_op = (w3 & 0xFF) as u8;
                let bit_nib = (w4 >> 8) as u8;
                let bit_num = bit_nib & 0x7;

                let target = Operand::RegIndirectDisp24(base_reg, disp);
                let bit = Operand::Imm8(bit_num);

                let insn = match bit_op {
                    0x63 | 0x73 => Instruction::Btst(bit, target),
                    0x60 => Instruction::Bset(Operand::Reg8(bit_nib), target),
                    0x70 => Instruction::Bset(bit, target),
                    0x62 => Instruction::Bclr(Operand::Reg8(bit_nib), target),
                    0x72 => Instruction::Bclr(bit, target),
                    0x61 => Instruction::Bnot(Operand::Reg8(bit_nib), target),
                    0x71 => Instruction::Bnot(bit, target),
                    0x67 if bit_nib & 0x8 == 0 => Instruction::Bst(bit, target),
                    0x67 => Instruction::Bist(Operand::Imm8(bit_num), target),
                    0x74 if bit_nib & 0x8 == 0 => Instruction::Bor(bit, target),
                    0x74 => Instruction::Bior(Operand::Imm8(bit_num), target),
                    0x75 if bit_nib & 0x8 == 0 => Instruction::Bxor(bit, target),
                    0x75 => Instruction::Bixor(Operand::Imm8(bit_num), target),
                    0x76 if bit_nib & 0x8 == 0 => Instruction::Band(bit, target),
                    0x76 => Instruction::Biand(Operand::Imm8(bit_num), target),
                    0x77 if bit_nib & 0x8 == 0 => Instruction::Bld(bit, target),
                    0x77 => Instruction::Bild(Operand::Imm8(bit_num), target),
                    _ => {
                        // Unrecognized bit op — treat as NOP to avoid halting
                        log::warn!("78-prefix: unknown bit_op 0x{:02X} at PC=0x{:06X}", bit_op, pc);
                        Instruction::Nop
                    }
                };

                Decoded { insn, len: 10 }
            } else if (w1 >> 8) == 0x6B {
                // 78 rr 6B: MOV.L with 24-bit displacement (same as 0100 78 variant)
                let w2 = bus.read_word(pc + 4);
                let w3 = bus.read_word(pc + 6);
                let mode = ((w1 >> 4) & 0xF) as u8;
                let reg = (w1 & 0xF) as u8;
                let _pad = (w2 >> 8) as u8;
                let d_hi = (w2 & 0xFF) as u32;
                let d_mid = (w3 >> 8) as u32;
                let d_lo = (w3 & 0xFF) as u32;
                let disp = (d_hi << 16) | (d_mid << 8) | d_lo;

                if mode & 0x8 == 0 {
                    Decoded {
                        insn: Instruction::Mov(Size::Long,
                            Operand::RegIndirectDisp24(base_reg, disp),
                            Operand::Reg32(reg)),
                        len: 8,
                    }
                } else {
                    Decoded {
                        insn: Instruction::Mov(Size::Long,
                            Operand::Reg32(reg),
                            Operand::RegIndirectDisp24(base_reg, disp)),
                        len: 8,
                    }
                }
            } else {
                Decoded { insn: Instruction::Unknown(w0), len: 2 }
            }
        }
        0x9 => {
            // MOV.W #imm16, Rd (79 1r imm16) or ADD/CMP/SUB.W #imm16
            match nib2 {
                0x0 => {
                    // MOV.W #imm16, Rd
                    let imm = bus.read_word(pc + 2);
                    Decoded {
                        insn: Instruction::Mov(Size::Word, Operand::Imm16(imm), Operand::Reg16(nib3)),
                        len: 4,
                    }
                }
                0x1 => {
                    // ADD.W #imm16, Rd
                    let imm = bus.read_word(pc + 2);
                    Decoded {
                        insn: Instruction::Add(Size::Word, Operand::Imm16(imm), Operand::Reg16(nib3)),
                        len: 4,
                    }
                }
                0x2 => {
                    // CMP.W #imm16, Rd
                    let imm = bus.read_word(pc + 2);
                    Decoded {
                        insn: Instruction::Cmp(Size::Word, Operand::Imm16(imm), Operand::Reg16(nib3)),
                        len: 4,
                    }
                }
                0x3 => {
                    // SUB.W #imm16, Rd
                    let imm = bus.read_word(pc + 2);
                    Decoded {
                        insn: Instruction::Sub(Size::Word, Operand::Imm16(imm), Operand::Reg16(nib3)),
                        len: 4,
                    }
                }
                0x4 => {
                    // OR.W #imm16, Rd
                    let imm = bus.read_word(pc + 2);
                    Decoded {
                        insn: Instruction::Or(Size::Word, Operand::Imm16(imm), Operand::Reg16(nib3)),
                        len: 4,
                    }
                }
                0x5 => {
                    // XOR.W #imm16, Rd
                    let imm = bus.read_word(pc + 2);
                    Decoded {
                        insn: Instruction::Xor(Size::Word, Operand::Imm16(imm), Operand::Reg16(nib3)),
                        len: 4,
                    }
                }
                0x6 => {
                    // AND.W #imm16, Rd
                    let imm = bus.read_word(pc + 2);
                    Decoded {
                        insn: Instruction::And(Size::Word, Operand::Imm16(imm), Operand::Reg16(nib3)),
                        len: 4,
                    }
                }
                _ => Decoded { insn: Instruction::Unknown(w0), len: 2 },
            }
        }
        0xA => {
            // MOV.L #imm32, ERd (7A 0r imm32) or ADD/CMP/SUB.L #imm32
            match nib2 {
                0x0 => {
                    let imm = bus.read_long(pc + 2);
                    Decoded {
                        insn: Instruction::Mov(Size::Long, Operand::Imm32(imm), Operand::Reg32(nib3)),
                        len: 6,
                    }
                }
                0x1 => {
                    let imm = bus.read_long(pc + 2);
                    Decoded {
                        insn: Instruction::Add(Size::Long, Operand::Imm32(imm), Operand::Reg32(nib3)),
                        len: 6,
                    }
                }
                0x2 => {
                    let imm = bus.read_long(pc + 2);
                    Decoded {
                        insn: Instruction::Cmp(Size::Long, Operand::Imm32(imm), Operand::Reg32(nib3)),
                        len: 6,
                    }
                }
                0x3 => {
                    let imm = bus.read_long(pc + 2);
                    Decoded {
                        insn: Instruction::Sub(Size::Long, Operand::Imm32(imm), Operand::Reg32(nib3)),
                        len: 6,
                    }
                }
                0x4 => {
                    let imm = bus.read_long(pc + 2);
                    Decoded {
                        insn: Instruction::Or(Size::Long, Operand::Imm32(imm), Operand::Reg32(nib3)),
                        len: 6,
                    }
                }
                0x5 => {
                    let imm = bus.read_long(pc + 2);
                    Decoded {
                        insn: Instruction::Xor(Size::Long, Operand::Imm32(imm), Operand::Reg32(nib3)),
                        len: 6,
                    }
                }
                0x6 => {
                    let imm = bus.read_long(pc + 2);
                    Decoded {
                        insn: Instruction::And(Size::Long, Operand::Imm32(imm), Operand::Reg32(nib3)),
                        len: 6,
                    }
                }
                _ => Decoded { insn: Instruction::Unknown(w0), len: 2 },
            }
        }
        0xB => {
            // EEPMOV.B (7B 5C 498F)
            let w1 = bus.read_word(pc + 2);
            if w0 == 0x7B5C && w1 == 0x598F {
                Decoded { insn: Instruction::EepmovB, len: 4 }
            } else {
                Decoded { insn: Instruction::Unknown(w0), len: 4 }
            }
        }
        0xC..=0xF => {
            // Bit operations on memory locations (7C/7D/7E/7F prefix + bit op)
            decode_group_7_bitop_mem(bus, pc, w0, op_lo, nib2, nib3)
        }
        _ => Decoded { insn: Instruction::Unknown(w0), len: 2 },
    }
}

/// Group 7C-7F: bit operations on memory (@ERd or @aa:8)
fn decode_group_7_bitop_mem(bus: &mut MemoryBus, pc: u32, w0: u16, op_lo: u8, nib2: u8, nib3: u8) -> Decoded {
    let w1 = bus.read_word(pc + 2);
    let bit_op = (w1 >> 8) as u8;
    let bit_num = ((w1 >> 4) & 0xF) as u8;
    let _reg_or_zero = (w1 & 0xF) as u8;

    let target = match op_lo {
        0xC => {
            // 7C r0 xxxx — @ERd (bit ops via register indirect)
            Operand::RegIndirect(nib2 & 0x7)
        }
        0xD => {
            // 7D r0 xxxx — @ERd (bit ops via register indirect, write variant)
            Operand::RegIndirect(nib2 & 0x7)
        }
        0xE => {
            // 7E aa xxxx — @aa:8
            let abs = ((nib2 as u8) << 4) | nib3;
            Operand::Abs8(abs)
        }
        0xF => {
            // 7F aa xxxx — @aa:8 (write variant)
            let abs = ((nib2 as u8) << 4) | nib3;
            Operand::Abs8(abs)
        }
        _ => unreachable!(),
    };

    let bit = Operand::Imm8(bit_num & 0x7);

    let insn = match bit_op {
        0x63 => Instruction::Btst(bit, target),
        0x73 => Instruction::Btst(bit, target),
        0x60 => Instruction::Bset(Operand::Reg8(bit_num), target),
        0x70 => Instruction::Bset(bit, target),
        0x61 => Instruction::Bnot(Operand::Reg8(bit_num), target),
        0x71 => Instruction::Bnot(bit, target),
        0x62 => Instruction::Bclr(Operand::Reg8(bit_num), target),
        0x72 => Instruction::Bclr(bit, target),
        0x67 if bit_num & 0x8 == 0 => Instruction::Bst(bit, target),
        0x67 => Instruction::Bist(Operand::Imm8(bit_num & 0x7), target),
        0x74 if bit_num & 0x8 == 0 => Instruction::Bor(bit, target),
        0x74 => Instruction::Bior(Operand::Imm8(bit_num & 0x7), target),
        0x75 if bit_num & 0x8 == 0 => Instruction::Bxor(bit, target),
        0x75 => Instruction::Bixor(Operand::Imm8(bit_num & 0x7), target),
        0x76 if bit_num & 0x8 == 0 => Instruction::Band(bit, target),
        0x76 => Instruction::Biand(Operand::Imm8(bit_num & 0x7), target),
        0x77 if bit_num & 0x8 == 0 => Instruction::Bld(bit, target),
        0x77 => Instruction::Bild(Operand::Imm8(bit_num & 0x7), target),
        _ => Instruction::Unknown(w0),
    };

    Decoded { insn, len: 4 }
}

/// Disassemble an instruction to a human-readable string.
pub fn disassemble(insn: &Instruction) -> String {
    match insn {
        Instruction::Nop => "NOP".to_string(),
        Instruction::Sleep => "SLEEP".to_string(),
        Instruction::Rts => "RTS".to_string(),
        Instruction::Rte => "RTE".to_string(),
        Instruction::Trapa(n) => format!("TRAPA #{}", n),
        Instruction::EepmovB => "EEPMOV.B".to_string(),

        Instruction::Mov(size, src, dst) => format!("MOV.{} {}, {}", size_str(size), operand_str(src), operand_str(dst)),
        Instruction::Add(size, src, dst) => format!("ADD.{} {}, {}", size_str(size), operand_str(src), operand_str(dst)),
        Instruction::Sub(size, src, dst) => format!("SUB.{} {}, {}", size_str(size), operand_str(src), operand_str(dst)),
        Instruction::Cmp(size, src, dst) => format!("CMP.{} {}, {}", size_str(size), operand_str(src), operand_str(dst)),
        Instruction::And(size, src, dst) => format!("AND.{} {}, {}", size_str(size), operand_str(src), operand_str(dst)),
        Instruction::Or(size, src, dst) => format!("OR.{} {}, {}", size_str(size), operand_str(src), operand_str(dst)),
        Instruction::Xor(size, src, dst) => format!("XOR.{} {}, {}", size_str(size), operand_str(src), operand_str(dst)),

        Instruction::Neg(size, op) => format!("NEG.{} {}", size_str(size), operand_str(op)),
        Instruction::Not(size, op) => format!("NOT.{} {}", size_str(size), operand_str(op)),
        Instruction::Inc(size, op) => format!("INC.{} {}", size_str(size), operand_str(op)),
        Instruction::Dec(size, op) => format!("DEC.{} {}", size_str(size), operand_str(op)),

        Instruction::Addx(src, dst) => format!("ADDX {}, {}", operand_str(src), operand_str(dst)),
        Instruction::Subx(src, dst) => format!("SUBX {}, {}", operand_str(src), operand_str(dst)),
        Instruction::Adds(src, dst) => format!("ADDS {}, {}", operand_str(src), operand_str(dst)),
        Instruction::Subs(src, dst) => format!("SUBS {}, {}", operand_str(src), operand_str(dst)),

        Instruction::Shal(size, op) => format!("SHAL.{} {}", size_str(size), operand_str(op)),
        Instruction::Shar(size, op) => format!("SHAR.{} {}", size_str(size), operand_str(op)),
        Instruction::Shll(size, op) => format!("SHLL.{} {}", size_str(size), operand_str(op)),
        Instruction::Shlr(size, op) => format!("SHLR.{} {}", size_str(size), operand_str(op)),
        Instruction::Rotl(size, op) => format!("ROTL.{} {}", size_str(size), operand_str(op)),
        Instruction::Rotr(size, op) => format!("ROTR.{} {}", size_str(size), operand_str(op)),
        Instruction::Rotxl(size, op) => format!("ROTXL.{} {}", size_str(size), operand_str(op)),
        Instruction::Rotxr(size, op) => format!("ROTXR.{} {}", size_str(size), operand_str(op)),

        Instruction::Bset(bit, dst) => format!("BSET {}, {}", operand_str(bit), operand_str(dst)),
        Instruction::Bclr(bit, dst) => format!("BCLR {}, {}", operand_str(bit), operand_str(dst)),
        Instruction::Btst(bit, dst) => format!("BTST {}, {}", operand_str(bit), operand_str(dst)),
        Instruction::Bnot(bit, dst) => format!("BNOT {}, {}", operand_str(bit), operand_str(dst)),
        Instruction::Bst(bit, dst) => format!("BST {}, {}", operand_str(bit), operand_str(dst)),
        Instruction::Bist(bit, dst) => format!("BIST {}, {}", operand_str(bit), operand_str(dst)),
        Instruction::Bld(bit, dst) => format!("BLD {}, {}", operand_str(bit), operand_str(dst)),
        Instruction::Bild(bit, dst) => format!("BILD {}, {}", operand_str(bit), operand_str(dst)),
        Instruction::Band(bit, dst) => format!("BAND {}, {}", operand_str(bit), operand_str(dst)),
        Instruction::Bor(bit, dst) => format!("BOR {}, {}", operand_str(bit), operand_str(dst)),
        Instruction::Bxor(bit, dst) => format!("BXOR {}, {}", operand_str(bit), operand_str(dst)),
        Instruction::Biand(bit, dst) => format!("BIAND {}, {}", operand_str(bit), operand_str(dst)),
        Instruction::Bior(bit, dst) => format!("BIOR {}, {}", operand_str(bit), operand_str(dst)),
        Instruction::Bixor(bit, dst) => format!("BIXOR {}, {}", operand_str(bit), operand_str(dst)),

        Instruction::Bcc(cond, disp) => format!("B{} {}", cond_str(cond), operand_str(disp)),
        Instruction::Jmp(target) => format!("JMP {}", operand_str(target)),
        Instruction::Bsr(disp) => format!("BSR {}", operand_str(disp)),
        Instruction::Jsr(target) => format!("JSR {}", operand_str(target)),

        Instruction::Ldc(src, _) => format!("LDC {}, CCR", operand_str(src)),
        Instruction::Stc(_, dst) => format!("STC CCR, {}", operand_str(dst)),
        Instruction::Andc(imm) => format!("ANDC {}, CCR", operand_str(imm)),
        Instruction::Orc(imm) => format!("ORC {}, CCR", operand_str(imm)),
        Instruction::Xorc(imm) => format!("XORC {}, CCR", operand_str(imm)),

        Instruction::Daa(op) => format!("DAA {}", operand_str(op)),
        Instruction::Das(op) => format!("DAS {}", operand_str(op)),
        Instruction::MulxuB(src, dst) => format!("MULXU.B {}, {}", operand_str(src), operand_str(dst)),
        Instruction::MulxuW(src, dst) => format!("MULXU.W {}, {}", operand_str(src), operand_str(dst)),
        Instruction::DivxuB(src, dst) => format!("DIVXU.B {}, {}", operand_str(src), operand_str(dst)),
        Instruction::DivxuW(src, dst) => format!("DIVXU.W {}, {}", operand_str(src), operand_str(dst)),
        Instruction::Extu(size, op) => format!("EXTU.{} {}", size_str(size), operand_str(op)),
        Instruction::Exts(size, op) => format!("EXTS.{} {}", size_str(size), operand_str(op)),

        Instruction::Push(op) => format!("PUSH {}", operand_str(op)),
        Instruction::Pop(op) => format!("POP {}", operand_str(op)),

        Instruction::Unknown(w) => format!("??? (0x{:04X})", w),
    }
}

fn size_str(s: &Size) -> &'static str {
    match s {
        Size::Byte => "B",
        Size::Word => "W",
        Size::Long => "L",
    }
}

fn cond_str(c: &Condition) -> &'static str {
    match c {
        Condition::Always => "RA",
        Condition::Never => "RN",
        Condition::Hi => "HI",
        Condition::Ls => "LS",
        Condition::Cc => "CC",
        Condition::Cs => "CS",
        Condition::Ne => "NE",
        Condition::Eq => "EQ",
        Condition::Vc => "VC",
        Condition::Vs => "VS",
        Condition::Pl => "PL",
        Condition::Mi => "MI",
        Condition::Ge => "GE",
        Condition::Lt => "LT",
        Condition::Gt => "GT",
        Condition::Le => "LE",
    }
}

fn operand_str(op: &Operand) -> String {
    match op {
        Operand::Reg8(n) => {
            if *n < 8 {
                format!("R{}H", n)
            } else {
                format!("R{}L", n - 8)
            }
        }
        Operand::Reg16(n) => {
            if *n < 8 {
                format!("R{}", n)
            } else {
                format!("E{}", n - 8)
            }
        }
        Operand::Reg32(n) => format!("ER{}", n),
        Operand::Imm8(v) => format!("#0x{:02X}", v),
        Operand::Imm16(v) => format!("#0x{:04X}", v),
        Operand::Imm32(v) => format!("#0x{:08X}", v),
        Operand::RegIndirect(n) => format!("@ER{}", n),
        Operand::RegIndirectDisp16(n, d) => format!("@(0x{:04X},ER{})", *d as u16, n),
        Operand::RegIndirectDisp24(n, d) => format!("@(0x{:06X},ER{})", d, n),
        Operand::PostInc(n) => format!("@ER{}+", n),
        Operand::PreDec(n) => format!("@-ER{}", n),
        Operand::Abs8(a) => format!("@0x{:02X}:8", a),
        Operand::Abs16(a) => format!("@0x{:04X}:16", a),
        Operand::Abs24(a) => format!("@0x{:06X}:24", a),
        Operand::PcRel8(d) => format!(".{:+}", d),
        Operand::PcRel16(d) => format!(".{:+}", d),
        Operand::MemIndirect(a) => format!("@@0x{:02X}", a),
        Operand::Ccr => "CCR".to_string(),
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn decode_bytes(bytes: &[u8]) -> Decoded {
        let mut bus = MemoryBus::new();
        for (i, &b) in bytes.iter().enumerate() {
            bus.write_byte(0x400000 + i as u32, b);
        }
        // Read from RAM at 0x400000
        decode(&mut bus, 0x400000)
    }

    #[test]
    fn test_decode_nop() {
        let d = decode_bytes(&[0x00, 0x00]);
        assert_eq!(d.insn, Instruction::Nop);
        assert_eq!(d.len, 2);
    }

    #[test]
    fn test_decode_rts() {
        let d = decode_bytes(&[0x54, 0x70]);
        assert_eq!(d.insn, Instruction::Rts);
    }

    #[test]
    fn test_decode_rte() {
        let d = decode_bytes(&[0x56, 0x70]);
        assert_eq!(d.insn, Instruction::Rte);
    }

    #[test]
    fn test_decode_trapa() {
        // TRAPA #0 = 0x5700
        let d = decode_bytes(&[0x57, 0x00]);
        assert_eq!(d.insn, Instruction::Trapa(0));

        // TRAPA #1 = 0x5740
        let d = decode_bytes(&[0x57, 0x40]);
        assert_eq!(d.insn, Instruction::Trapa(1));
    }

    #[test]
    fn test_decode_mov_b_imm() {
        // MOV.B #0x42, R0L = F8 42
        let d = decode_bytes(&[0xF8, 0x42]);
        assert_eq!(d.insn, Instruction::Mov(Size::Byte, Operand::Imm8(0x42), Operand::Reg8(8)));
        assert_eq!(d.len, 2);
    }

    #[test]
    fn test_decode_mov_w_imm() {
        // MOV.W #0x1234, R0 = 79 00 12 34
        let d = decode_bytes(&[0x79, 0x00, 0x12, 0x34]);
        assert_eq!(d.insn, Instruction::Mov(Size::Word, Operand::Imm16(0x1234), Operand::Reg16(0)));
        assert_eq!(d.len, 4);
    }

    #[test]
    fn test_decode_mov_l_imm() {
        // MOV.L #0x00410000, ER7 = 7A 07 00 41 00 00
        let d = decode_bytes(&[0x7A, 0x07, 0x00, 0x41, 0x00, 0x00]);
        assert_eq!(d.insn, Instruction::Mov(Size::Long, Operand::Imm32(0x00410000), Operand::Reg32(7)));
        assert_eq!(d.len, 6);
    }

    #[test]
    fn test_decode_bra() {
        // BRA .+4 = 40 02 (PC-relative, disp is from PC+2)
        let d = decode_bytes(&[0x40, 0x02]);
        assert_eq!(d.insn, Instruction::Bcc(Condition::Always, Operand::PcRel8(2)));
    }

    #[test]
    fn test_decode_beq() {
        // BEQ .-2 = 47 FC
        let d = decode_bytes(&[0x47, 0xFC]);
        assert_eq!(d.insn, Instruction::Bcc(Condition::Eq, Operand::PcRel8(-4)));
    }

    #[test]
    fn test_decode_jsr_abs24() {
        // JSR @0x020334 = 5E 02 03 34
        let d = decode_bytes(&[0x5E, 0x02, 0x03, 0x34]);
        assert_eq!(d.insn, Instruction::Jsr(Operand::Abs24(0x020334)));
    }

    #[test]
    fn test_decode_add_b_reg() {
        // ADD.B R0H, R1L = 08 09
        let d = decode_bytes(&[0x08, 0x09]);
        assert_eq!(d.insn, Instruction::Add(Size::Byte, Operand::Reg8(0), Operand::Reg8(9)));
    }

    #[test]
    fn test_decode_orc() {
        // ORC #0x80, CCR = 04 80
        let d = decode_bytes(&[0x04, 0x80]);
        assert_eq!(d.insn, Instruction::Orc(Operand::Imm8(0x80)));
    }

    #[test]
    fn test_decode_andc() {
        // ANDC #0x7F, CCR = 06 7F
        let d = decode_bytes(&[0x06, 0x7F]);
        assert_eq!(d.insn, Instruction::Andc(Operand::Imm8(0x7F)));
    }

    #[test]
    fn test_decode_shll_b() {
        // SHLL.B R0L = 11 08
        let d = decode_bytes(&[0x11, 0x08]);
        assert_eq!(d.insn, Instruction::Shll(Size::Byte, Operand::Reg8(8)));
    }

    #[test]
    fn test_decode_mov_b_reg_indirect() {
        // MOV.B @ER0, R1L = 68 09
        let d = decode_bytes(&[0x68, 0x09]);
        assert_eq!(d.insn, Instruction::Mov(Size::Byte, Operand::RegIndirect(0), Operand::Reg8(9)));
    }

    #[test]
    fn test_decode_bset_imm() {
        // BSET #3, R0L = 70 38
        let d = decode_bytes(&[0x70, 0x38]);
        assert_eq!(d.insn, Instruction::Bset(Operand::Imm8(3), Operand::Reg8(8)));
    }
}
