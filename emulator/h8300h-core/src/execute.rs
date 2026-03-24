//! H8/300H instruction executor.
//!
//! Each instruction modifies CPU registers, memory, and/or CCR flags
//! according to the Hitachi H8/300H Programming Manual.

use crate::cpu::*;
use crate::decode::*;
use crate::memory::MemoryBus;

/// Execute a single decoded instruction. Returns the new PC.
pub fn execute(cpu: &mut Cpu, bus: &mut MemoryBus, insn: &Instruction, insn_pc: u32, insn_len: u32) -> u32 {
    let next_pc = insn_pc + insn_len;

    match insn {
        Instruction::Nop => next_pc,
        Instruction::Sleep => {
            cpu.sleeping = true;
            next_pc
        }

        // --- Data Transfer ---
        Instruction::Mov(size, src, dst) => {
            exec_mov(cpu, bus, *size, src, dst);
            next_pc
        }
        Instruction::Push(src) => {
            let val = read_operand_w(cpu, bus, src);
            let sp = cpu.sp() - 2;
            cpu.set_sp(sp);
            bus.write_word(sp, val);
            next_pc
        }
        Instruction::Pop(dst) => {
            let sp = cpu.sp();
            let val = bus.read_word(sp);
            cpu.set_sp(sp + 2);
            write_operand_w(cpu, bus, dst, val);
            next_pc
        }

        // --- Arithmetic ---
        Instruction::Add(size, src, dst) => {
            exec_add(cpu, bus, *size, src, dst);
            next_pc
        }
        Instruction::Sub(size, src, dst) => {
            exec_sub(cpu, bus, *size, src, dst);
            next_pc
        }
        Instruction::Cmp(size, src, dst) => {
            exec_cmp(cpu, bus, *size, src, dst);
            next_pc
        }
        Instruction::Neg(size, op) => {
            exec_neg(cpu, bus, *size, op);
            next_pc
        }
        Instruction::Inc(size, op, amt) => {
            exec_inc(cpu, *size, op, *amt as u32);
            next_pc
        }
        Instruction::Dec(size, op, amt) => {
            exec_dec(cpu, *size, op, *amt as u32);
            next_pc
        }
        Instruction::Addx(src, dst) => {
            exec_addx(cpu, src, dst);
            next_pc
        }
        Instruction::Subx(src, dst) => {
            exec_subx(cpu, src, dst);
            next_pc
        }
        Instruction::Adds(src, dst) => {
            let val = read_operand_l(cpu, bus, src);
            let rd = read_operand_l(cpu, bus, dst);
            write_operand_l(cpu, bus, dst, rd.wrapping_add(val));
            // No flags affected
            next_pc
        }
        Instruction::Subs(src, dst) => {
            let val = read_operand_l(cpu, bus, src);
            let rd = read_operand_l(cpu, bus, dst);
            write_operand_l(cpu, bus, dst, rd.wrapping_sub(val));
            next_pc
        }
        Instruction::Daa(op) => {
            exec_daa(cpu, op);
            next_pc
        }
        Instruction::Das(op) => {
            exec_das(cpu, op);
            next_pc
        }
        Instruction::MulxuB(src, dst) => {
            let s = read_operand_b(cpu, bus, src) as u16;
            let d = read_operand_w(cpu, bus, dst);
            let dl = d & 0xFF;
            let result = dl * s;
            write_operand_w(cpu, bus, dst, result);
            // No flags affected
            next_pc
        }
        Instruction::MulxuW(src, dst) => {
            let s = read_operand_w(cpu, bus, src) as u32;
            let d = read_operand_l(cpu, bus, dst);
            let dl = d & 0xFFFF;
            let result = dl * s;
            write_operand_l(cpu, bus, dst, result);
            next_pc
        }
        Instruction::DivxuB(src, dst) => {
            let divisor = read_operand_b(cpu, bus, src) as u16;
            let dividend = read_operand_w(cpu, bus, dst);
            if divisor == 0 {
                // Division by zero — result undefined, set Z flag
                cpu.set_flag(CCR_Z, true);
            } else {
                let quotient = dividend / divisor;
                let remainder = dividend % divisor;
                // Result: remainder in upper byte, quotient in lower byte of Rd
                let result = ((remainder & 0xFF) << 8) | (quotient & 0xFF);
                write_operand_w(cpu, bus, dst, result);
                // Flags from truncated 8-bit quotient (not the full u16 quotient)
                let q8 = (quotient & 0xFF) as u8;
                cpu.set_flag(CCR_N, q8 & 0x80 != 0);
                cpu.set_flag(CCR_Z, q8 == 0);
            }
            next_pc
        }
        Instruction::DivxuW(src, dst) => {
            let divisor = read_operand_w(cpu, bus, src) as u32;
            let dividend = read_operand_l(cpu, bus, dst);
            if divisor == 0 {
                cpu.set_flag(CCR_Z, true);
            } else {
                let quotient = dividend / divisor;
                let remainder = dividend % divisor;
                let result = ((remainder & 0xFFFF) << 16) | (quotient & 0xFFFF);
                write_operand_l(cpu, bus, dst, result);
                // Flags from truncated 16-bit quotient
                let q16 = (quotient & 0xFFFF) as u16;
                cpu.set_flag(CCR_N, q16 & 0x8000 != 0);
                cpu.set_flag(CCR_Z, q16 == 0);
            }
            next_pc
        }
        Instruction::Extu(size, op) => {
            match size {
                Size::Word => {
                    let val = read_operand_w(cpu, bus, op);
                    let result = val & 0x00FF; // zero-extend low byte
                    write_operand_w(cpu, bus, op, result);
                    cpu.set_flag(CCR_N, false);
                    cpu.set_flag(CCR_Z, result == 0);
                    cpu.set_flag(CCR_V, false);
                }
                Size::Long => {
                    let val = read_operand_l(cpu, bus, op);
                    let result = val & 0x0000FFFF; // zero-extend low word
                    write_operand_l(cpu, bus, op, result);
                    cpu.set_flag(CCR_N, false);
                    cpu.set_flag(CCR_Z, result == 0);
                    cpu.set_flag(CCR_V, false);
                }
                Size::Byte => {
                    panic!("EXTU.B is invalid per H8/300H manual at PC=0x{:06X}", insn_pc);
                }
            }
            next_pc
        }
        Instruction::Exts(size, op) => {
            match size {
                Size::Word => {
                    let val = read_operand_w(cpu, bus, op);
                    let low = val as u8;
                    let result = low as i8 as i16 as u16;
                    write_operand_w(cpu, bus, op, result);
                    cpu.set_flag(CCR_N, result & 0x8000 != 0);
                    cpu.set_flag(CCR_Z, result == 0);
                    cpu.set_flag(CCR_V, false);
                }
                Size::Long => {
                    let val = read_operand_l(cpu, bus, op);
                    let low = val as u16;
                    let result = low as i16 as i32 as u32;
                    write_operand_l(cpu, bus, op, result);
                    cpu.set_flag(CCR_N, result & 0x8000_0000 != 0);
                    cpu.set_flag(CCR_Z, result == 0);
                    cpu.set_flag(CCR_V, false);
                }
                Size::Byte => {
                    panic!("EXTS.B is invalid per H8/300H manual at PC=0x{:06X}", insn_pc);
                }
            }
            next_pc
        }

        // --- Logic ---
        Instruction::And(size, src, dst) => {
            exec_logic(cpu, bus, *size, src, dst, LogicOp::And);
            next_pc
        }
        Instruction::Or(size, src, dst) => {
            exec_logic(cpu, bus, *size, src, dst, LogicOp::Or);
            next_pc
        }
        Instruction::Xor(size, src, dst) => {
            exec_logic(cpu, bus, *size, src, dst, LogicOp::Xor);
            next_pc
        }
        Instruction::Not(size, op) => {
            let p = size_params(*size);
            let val = read_sized(cpu, bus, *size, op);
            let result = !val & p.mask;
            write_sized(cpu, bus, *size, op, result);
            update_nz(cpu, *size, result);
            cpu.set_flag(CCR_V, false);
            next_pc
        }

        // --- Shift ---
        Instruction::Shal(size, op) => { exec_shift(cpu, bus, *size, op, ShiftOp::Shal); next_pc }
        Instruction::Shar(size, op) => { exec_shift(cpu, bus, *size, op, ShiftOp::Shar); next_pc }
        Instruction::Shll(size, op) => { exec_shift(cpu, bus, *size, op, ShiftOp::Shll); next_pc }
        Instruction::Shlr(size, op) => { exec_shift(cpu, bus, *size, op, ShiftOp::Shlr); next_pc }
        Instruction::Rotl(size, op) => { exec_shift(cpu, bus, *size, op, ShiftOp::Rotl); next_pc }
        Instruction::Rotr(size, op) => { exec_shift(cpu, bus, *size, op, ShiftOp::Rotr); next_pc }
        Instruction::Rotxl(size, op) => { exec_shift(cpu, bus, *size, op, ShiftOp::Rotxl); next_pc }
        Instruction::Rotxr(size, op) => { exec_shift(cpu, bus, *size, op, ShiftOp::Rotxr); next_pc }

        // --- Bit Manipulation ---
        Instruction::Bset(bit, dst) => { exec_bset(cpu, bus, bit, dst); next_pc }
        Instruction::Bclr(bit, dst) => { exec_bclr(cpu, bus, bit, dst); next_pc }
        Instruction::Btst(bit, dst) => { exec_btst(cpu, bus, bit, dst); next_pc }
        Instruction::Bnot(bit, dst) => { exec_bnot(cpu, bus, bit, dst); next_pc }
        Instruction::Bst(bit, dst) => {
            let b = get_bit_num(cpu, bit);
            let val = read_operand_b(cpu, bus, dst);
            let result = if cpu.carry() { val | (1 << b) } else { val & !(1 << b) };
            write_operand_b(cpu, bus, dst, result);
            next_pc
        }
        Instruction::Bist(bit, dst) => {
            let b = get_bit_num(cpu, bit);
            let val = read_operand_b(cpu, bus, dst);
            let result = if !cpu.carry() { val | (1 << b) } else { val & !(1 << b) };
            write_operand_b(cpu, bus, dst, result);
            next_pc
        }
        Instruction::Bld(bit, dst) => {
            let b = get_bit_num(cpu, bit);
            let val = read_operand_b(cpu, bus, dst);
            cpu.set_flag(CCR_C, val & (1 << b) != 0);
            next_pc
        }
        Instruction::Bild(bit, dst) => {
            let b = get_bit_num(cpu, bit);
            let val = read_operand_b(cpu, bus, dst);
            cpu.set_flag(CCR_C, val & (1 << b) == 0);
            next_pc
        }
        Instruction::Band(bit, dst) => {
            let b = get_bit_num(cpu, bit);
            let val = read_operand_b(cpu, bus, dst);
            let bit_set = val & (1 << b) != 0;
            cpu.set_flag(CCR_C, cpu.carry() && bit_set);
            next_pc
        }
        Instruction::Bor(bit, dst) => {
            let b = get_bit_num(cpu, bit);
            let val = read_operand_b(cpu, bus, dst);
            let bit_set = val & (1 << b) != 0;
            cpu.set_flag(CCR_C, cpu.carry() || bit_set);
            next_pc
        }
        Instruction::Bxor(bit, dst) => {
            let b = get_bit_num(cpu, bit);
            let val = read_operand_b(cpu, bus, dst);
            let bit_set = val & (1 << b) != 0;
            cpu.set_flag(CCR_C, cpu.carry() ^ bit_set);
            next_pc
        }
        Instruction::Biand(bit, dst) => {
            let b = get_bit_num(cpu, bit);
            let val = read_operand_b(cpu, bus, dst);
            let bit_set = val & (1 << b) != 0;
            cpu.set_flag(CCR_C, cpu.carry() && !bit_set);
            next_pc
        }
        Instruction::Bior(bit, dst) => {
            let b = get_bit_num(cpu, bit);
            let val = read_operand_b(cpu, bus, dst);
            let bit_set = val & (1 << b) != 0;
            cpu.set_flag(CCR_C, cpu.carry() || !bit_set);
            next_pc
        }
        Instruction::Bixor(bit, dst) => {
            let b = get_bit_num(cpu, bit);
            let val = read_operand_b(cpu, bus, dst);
            let bit_set = val & (1 << b) != 0;
            cpu.set_flag(CCR_C, cpu.carry() ^ !bit_set);
            next_pc
        }

        // --- Branch ---
        Instruction::Bcc(cond, disp) => {
            if eval_condition(cpu, *cond) {
                let target = match disp {
                    Operand::PcRel8(d) => (next_pc as i32 + *d as i32) as u32,
                    Operand::PcRel16(d) => (next_pc as i32 + *d as i32) as u32,
                    _ => next_pc,
                };
                target & 0x00FF_FFFF
            } else {
                next_pc
            }
        }
        Instruction::Jmp(target) => {
            resolve_jump_target(cpu, bus, target)
        }
        Instruction::Bsr(disp) => {
            // Push return address (next_pc), then branch
            let sp = cpu.sp() - 4;
            cpu.set_sp(sp);
            bus.write_long(sp, next_pc);
            let target = match disp {
                Operand::PcRel8(d) => (next_pc as i32 + *d as i32) as u32,
                Operand::PcRel16(d) => (next_pc as i32 + *d as i32) as u32,
                _ => next_pc,
            };
            target & 0x00FF_FFFF
        }
        Instruction::Jsr(target) => {
            let sp = cpu.sp() - 4;
            cpu.set_sp(sp);
            bus.write_long(sp, next_pc);
            resolve_jump_target(cpu, bus, target)
        }

        // --- System ---
        Instruction::Rts => {
            let sp = cpu.sp();
            let addr = bus.read_long(sp);
            cpu.set_sp(sp + 4);
            addr & 0x00FF_FFFF
        }
        Instruction::Rte => {
            // H8/300H Advanced Mode: exception frame is a single longword
            // [CCR:8][PC:24] packed into 4 bytes (see Programming Manual p.159)
            let sp = cpu.sp();
            let frame = bus.read_long(sp);
            cpu.ccr = (frame >> 24) as u8;
            cpu.set_sp(sp + 4);
            frame & 0x00FF_FFFF
        }
        Instruction::Trapa(vec_num) => {
            // H8/300H Advanced Mode: push [CCR:8][PC:24] as single longword
            let frame = ((cpu.ccr as u32) << 24) | (next_pc & 0x00FF_FFFF);
            let sp = cpu.sp() - 4;
            cpu.set_sp(sp);
            bus.write_long(sp, frame);
            // Set I flag to mask interrupts
            cpu.set_flag(CCR_I, true);
            // Load PC from vector table: address = (8 + vec_num) * 4
            // TRAP #0 = vec 8 = addr 0x020, TRAP #1 = vec 9 = addr 0x024, etc.
            let vec_addr = (8 + *vec_num as u32) * 4;
            let target = bus.read_long(vec_addr);
            target & 0x00FF_FFFF
        }
        Instruction::Ldc(src, _) => {
            let val = read_operand_b(cpu, bus, src);
            cpu.ccr = val;
            next_pc
        }
        Instruction::Stc(_, dst) => {
            write_operand_b(cpu, bus, dst, cpu.ccr);
            next_pc
        }
        Instruction::Andc(imm) => {
            let val = read_operand_b(cpu, bus, imm);
            cpu.ccr &= val;
            next_pc
        }
        Instruction::Orc(imm) => {
            let val = read_operand_b(cpu, bus, imm);
            cpu.ccr |= val;
            next_pc
        }
        Instruction::Xorc(imm) => {
            let val = read_operand_b(cpu, bus, imm);
            cpu.ccr ^= val;
            next_pc
        }

        // --- Block Transfer ---
        Instruction::EepmovB => {
            // Copy R4L bytes from @ER5 to @ER6, post-incrementing both
            let mut count = cpu.read_r8(8 + 4); // R4L
            while count > 0 {
                let src_addr = cpu.read_er(5);
                let dst_addr = cpu.read_er(6);
                let byte = bus.read_byte(src_addr);
                bus.write_byte(dst_addr, byte);
                cpu.write_er(5, src_addr + 1);
                cpu.write_er(6, dst_addr + 1);
                count -= 1;
            }
            cpu.write_r8(8 + 4, 0); // R4L = 0 when done
            next_pc
        }

        Instruction::Unknown(w) => {
            panic!("Unknown instruction 0x{:04X} at PC=0x{:06X}", w, insn_pc);
        }
    }
}

// --- Size-parameterized helpers ---
// These eliminate the Byte/Word/Long repetition in arithmetic operations
// by widening all values to u32 and using size-dependent masks.

/// Masks and bit positions for each operand size.
struct SizeParams {
    /// Bitmask for the operand width (0xFF, 0xFFFF, or 0xFFFF_FFFF).
    mask: u32,
    /// MSB position (0x80, 0x8000, or 0x8000_0000).
    msb: u32,
    /// Half-carry mask (0xF, 0xFFF, or 0xFFF_FFFF).
    half_mask: u32,
}

const BYTE_PARAMS: SizeParams = SizeParams { mask: 0xFF, msb: 0x80, half_mask: 0xF };
const WORD_PARAMS: SizeParams = SizeParams { mask: 0xFFFF, msb: 0x8000, half_mask: 0xFFF };
const LONG_PARAMS: SizeParams = SizeParams { mask: 0xFFFF_FFFF, msb: 0x8000_0000, half_mask: 0xFFF_FFFF };

fn size_params(size: Size) -> &'static SizeParams {
    match size {
        Size::Byte => &BYTE_PARAMS,
        Size::Word => &WORD_PARAMS,
        Size::Long => &LONG_PARAMS,
    }
}

/// Read an operand as u32 (widened from the appropriate size).
fn read_sized(cpu: &mut Cpu, bus: &mut MemoryBus, size: Size, op: &Operand) -> u32 {
    match size {
        Size::Byte => read_operand_b(cpu, bus, op) as u32,
        Size::Word => read_operand_w(cpu, bus, op) as u32,
        Size::Long => read_operand_l(cpu, bus, op),
    }
}

/// Write a u32 value truncated to the appropriate size.
fn write_sized(cpu: &mut Cpu, bus: &mut MemoryBus, size: Size, op: &Operand, val: u32) {
    match size {
        Size::Byte => write_operand_b(cpu, bus, op, val as u8),
        Size::Word => write_operand_w(cpu, bus, op, val as u16),
        Size::Long => write_operand_l(cpu, bus, op, val),
    }
}

/// Update N and Z flags for the given size.
fn update_nz(cpu: &mut Cpu, size: Size, result: u32) {
    let p = size_params(size);
    cpu.set_flag(CCR_N, result & p.msb != 0);
    cpu.set_flag(CCR_Z, result & p.mask == 0);
}

// --- Helper functions ---

fn exec_mov(cpu: &mut Cpu, bus: &mut MemoryBus, size: Size, src: &Operand, dst: &Operand) {
    let val = read_sized(cpu, bus, size, src);
    write_sized(cpu, bus, size, dst, val);
    update_nz(cpu, size, val);
    cpu.set_flag(CCR_V, false);
}

fn exec_add(cpu: &mut Cpu, bus: &mut MemoryBus, size: Size, src: &Operand, dst: &Operand) {
    let p = size_params(size);
    let s = read_sized(cpu, bus, size, src);
    let d = read_sized(cpu, bus, size, dst);
    let sum = d.wrapping_add(s) & p.mask;
    let carry = (d & p.mask) > (sum);  // unsigned overflow
    let half = (d & p.half_mask) + (s & p.half_mask) > p.half_mask;
    let overflow = (!(s ^ d) & (s ^ sum)) & p.msb != 0;
    write_sized(cpu, bus, size, dst, sum);
    update_nz(cpu, size, sum);
    cpu.set_flag(CCR_H, half);
    cpu.set_flag(CCR_V, overflow);
    cpu.set_flag(CCR_C, carry);
}

fn exec_sub(cpu: &mut Cpu, bus: &mut MemoryBus, size: Size, src: &Operand, dst: &Operand) {
    sub_internal(cpu, bus, size, src, dst, true);
}

fn exec_cmp(cpu: &mut Cpu, bus: &mut MemoryBus, size: Size, src: &Operand, dst: &Operand) {
    // CMP is SUB without storing the result
    sub_internal(cpu, bus, size, src, dst, false);
}

/// Shared implementation for SUB and CMP (CMP = SUB without writeback).
fn sub_internal(cpu: &mut Cpu, bus: &mut MemoryBus, size: Size, src: &Operand, dst: &Operand, store: bool) {
    let p = size_params(size);
    let s = read_sized(cpu, bus, size, src);
    let d = read_sized(cpu, bus, size, dst);
    let result = d.wrapping_sub(s) & p.mask;
    let borrow = (d & p.mask) < (s & p.mask);
    let half = (d & p.half_mask) < (s & p.half_mask);
    let overflow = ((s ^ d) & !(s ^ result)) & p.msb != 0;
    if store {
        write_sized(cpu, bus, size, dst, result);
    }
    update_nz(cpu, size, result);
    cpu.set_flag(CCR_H, half);
    cpu.set_flag(CCR_V, overflow);
    cpu.set_flag(CCR_C, borrow);
}

fn exec_neg(cpu: &mut Cpu, bus: &mut MemoryBus, size: Size, op: &Operand) {
    let p = size_params(size);
    let val = read_sized(cpu, bus, size, op);
    let result = (0u32).wrapping_sub(val) & p.mask;
    write_sized(cpu, bus, size, op, result);
    update_nz(cpu, size, result);
    cpu.set_flag(CCR_V, val == p.msb);
    cpu.set_flag(CCR_C, val != 0);
    cpu.set_flag(CCR_H, (val & p.half_mask) != 0);
}

fn exec_inc(cpu: &mut Cpu, size: Size, op: &Operand, amount: u32) {
    let p = size_params(size);
    let r = extract_reg(op);
    let val = read_reg_sized(cpu, size, r);
    let result = val.wrapping_add(amount) & p.mask;
    write_reg_sized(cpu, size, r, result);
    update_nz(cpu, size, result);
    // Overflow: sign bit changed from 0→1 (positive became negative)
    // For #1: val == msb-1. For #2: val == msb-1 or msb-2.
    let prev_sign = val & p.msb;
    let new_sign = result & p.msb;
    cpu.set_flag(CCR_V, prev_sign == 0 && new_sign != 0);
}

fn exec_dec(cpu: &mut Cpu, size: Size, op: &Operand, amount: u32) {
    let p = size_params(size);
    let r = extract_reg(op);
    let val = read_reg_sized(cpu, size, r);
    let result = val.wrapping_sub(amount) & p.mask;
    write_reg_sized(cpu, size, r, result);
    update_nz(cpu, size, result);
    // Overflow: sign bit changed from 1→0 (negative became positive)
    let prev_sign = val & p.msb;
    let new_sign = result & p.msb;
    cpu.set_flag(CCR_V, prev_sign != 0 && new_sign == 0);
}

/// Read a register value widened to u32, dispatching by size.
fn read_reg_sized(cpu: &Cpu, size: Size, r: u8) -> u32 {
    match size {
        Size::Byte => cpu.read_r8(r) as u32,
        Size::Word => cpu.read_r16(r) as u32,
        Size::Long => cpu.read_er(r),
    }
}

/// Write a u32 value to a register, truncating by size.
fn write_reg_sized(cpu: &mut Cpu, size: Size, r: u8, val: u32) {
    match size {
        Size::Byte => cpu.write_r8(r, val as u8),
        Size::Word => cpu.write_r16(r, val as u16),
        Size::Long => cpu.write_er(r, val),
    }
}

fn exec_addx(cpu: &mut Cpu, src: &Operand, dst: &Operand) {
    let s = read_operand_b_direct(cpu, src);
    let d = read_operand_b_direct(cpu, dst);
    let c = cpu.carry() as u8;
    let result16 = d as u16 + s as u16 + c as u16;
    let result = result16 as u8;
    write_operand_b_direct(cpu, dst, result);
    let half = (d & 0xF) + (s & 0xF) + c > 0xF;
    let overflow = (!(s ^ d) & (s ^ result)) & 0x80 != 0;
    cpu.set_flag(CCR_N, result & 0x80 != 0);
    // Z is only cleared, never set (for multi-byte arithmetic)
    if result != 0 {
        cpu.set_flag(CCR_Z, false);
    }
    cpu.set_flag(CCR_H, half);
    cpu.set_flag(CCR_V, overflow);
    cpu.set_flag(CCR_C, result16 > 0xFF);
}

fn exec_subx(cpu: &mut Cpu, src: &Operand, dst: &Operand) {
    let s = read_operand_b_direct(cpu, src);
    let d = read_operand_b_direct(cpu, dst);
    let c = cpu.carry() as u8;
    let result = d.wrapping_sub(s).wrapping_sub(c);
    let borrow = (d as u16) < (s as u16 + c as u16);
    write_operand_b_direct(cpu, dst, result);
    let half = (d & 0xF) < (s & 0xF) + c;
    let overflow = ((s ^ d) & !(s ^ result)) & 0x80 != 0;
    cpu.set_flag(CCR_N, result & 0x80 != 0);
    if result != 0 {
        cpu.set_flag(CCR_Z, false);
    }
    cpu.set_flag(CCR_H, half);
    cpu.set_flag(CCR_V, overflow);
    cpu.set_flag(CCR_C, borrow);
}

fn exec_daa(cpu: &mut Cpu, op: &Operand) {
    let r = extract_reg(op);
    let val = cpu.read_r8(r);
    let c = cpu.carry();
    let h = cpu.half_carry();
    let lo = val & 0x0F;
    let hi = val >> 4;

    let mut correction = 0u8;
    let mut new_c = c;

    if h || lo > 9 {
        correction += 0x06;
    }
    if c || hi > 9 || (hi >= 9 && lo > 9) {
        correction += 0x60;
        new_c = true;
    }

    let result = val.wrapping_add(correction);
    cpu.write_r8(r, result);
    cpu.update_nz_b(result);
    cpu.set_flag(CCR_C, new_c);
}

fn exec_das(cpu: &mut Cpu, op: &Operand) {
    let r = extract_reg(op);
    let val = cpu.read_r8(r);
    let c = cpu.carry();
    let h = cpu.half_carry();

    let mut correction = 0u8;
    let mut new_c = c;

    if h {
        correction += 0x06;
    }
    if c {
        correction += 0x60;
        new_c = true;
    }

    let result = val.wrapping_sub(correction);
    cpu.write_r8(r, result);
    cpu.update_nz_b(result);
    cpu.set_flag(CCR_C, new_c);
}

enum LogicOp { And, Or, Xor }

fn exec_logic(cpu: &mut Cpu, bus: &mut MemoryBus, size: Size, src: &Operand, dst: &Operand, op: LogicOp) {
    let s = read_sized(cpu, bus, size, src);
    let d = read_sized(cpu, bus, size, dst);
    let result = match op {
        LogicOp::And => d & s,
        LogicOp::Or => d | s,
        LogicOp::Xor => d ^ s,
    };
    write_sized(cpu, bus, size, dst, result);
    update_nz(cpu, size, result);
    cpu.set_flag(CCR_V, false);
}

enum ShiftOp { Shal, Shar, Shll, Shlr, Rotl, Rotr, Rotxl, Rotxr }

fn exec_shift(cpu: &mut Cpu, bus: &mut MemoryBus, size: Size, op: &Operand, shift: ShiftOp) {
    let p = size_params(size);
    let val = read_sized(cpu, bus, size, op);
    let bits = match size { Size::Byte => 8, Size::Word => 16, Size::Long => 32 };
    let (result, carry) = shift_value(val, bits, p.mask, cpu.carry(), &shift);
    write_sized(cpu, bus, size, op, result);
    update_nz(cpu, size, result);
    cpu.set_flag(CCR_C, carry);
    // V: SHAL = overflow (N^C, i.e. sign bit changed), all others = 0
    // Per Hitachi manual: SHAR V=0, SHLL/SHLR V=0, all rotates V=0
    cpu.set_flag(CCR_V, matches!(shift, ShiftOp::Shal) && (cpu.negative() ^ cpu.carry()));
}

/// Size-generic shift/rotate operating on u32, parameterized by bit width and mask.
fn shift_value(val: u32, bits: u32, mask: u32, old_c: bool, op: &ShiftOp) -> (u32, bool) {
    let msb = 1u32 << (bits - 1);
    match op {
        ShiftOp::Shal | ShiftOp::Shll => {
            let carry = val & msb != 0;
            ((val << 1) & mask, carry)
        }
        ShiftOp::Shar => {
            let carry = val & 1 != 0;
            // Arithmetic right shift: sign-extend from the MSB
            let sign = if val & msb != 0 { msb } else { 0 };
            (((val >> 1) | sign) & mask, carry)
        }
        ShiftOp::Shlr => {
            let carry = val & 1 != 0;
            ((val >> 1) & mask, carry)
        }
        ShiftOp::Rotl => {
            let carry = val & msb != 0;
            (((val << 1) | carry as u32) & mask, carry)
        }
        ShiftOp::Rotr => {
            let carry = val & 1 != 0;
            (((val >> 1) | ((carry as u32) << (bits - 1))) & mask, carry)
        }
        ShiftOp::Rotxl => {
            let carry = val & msb != 0;
            (((val << 1) | old_c as u32) & mask, carry)
        }
        ShiftOp::Rotxr => {
            let carry = val & 1 != 0;
            (((val >> 1) | ((old_c as u32) << (bits - 1))) & mask, carry)
        }
    }
}

// --- Bit manipulation helpers ---

fn get_bit_num(cpu: &Cpu, op: &Operand) -> u8 {
    match op {
        Operand::Imm8(n) => *n & 0x7,
        Operand::Reg8(r) => cpu.read_r8(*r) & 0x7,
        _ => panic!("get_bit_num: unexpected operand {:?}, expected Imm8 or Reg8", op),
    }
}

fn exec_bset(cpu: &mut Cpu, bus: &mut MemoryBus, bit: &Operand, dst: &Operand) {
    let b = get_bit_num(cpu, bit);
    let val = read_operand_b(cpu, bus, dst);
    write_operand_b(cpu, bus, dst, val | (1 << b));
}

fn exec_bclr(cpu: &mut Cpu, bus: &mut MemoryBus, bit: &Operand, dst: &Operand) {
    let b = get_bit_num(cpu, bit);
    let val = read_operand_b(cpu, bus, dst);
    write_operand_b(cpu, bus, dst, val & !(1 << b));
}

fn exec_btst(cpu: &mut Cpu, bus: &mut MemoryBus, bit: &Operand, dst: &Operand) {
    let b = get_bit_num(cpu, bit);
    let val = read_operand_b(cpu, bus, dst);
    cpu.set_flag(CCR_Z, val & (1 << b) == 0);
}

fn exec_bnot(cpu: &mut Cpu, bus: &mut MemoryBus, bit: &Operand, dst: &Operand) {
    let b = get_bit_num(cpu, bit);
    let val = read_operand_b(cpu, bus, dst);
    write_operand_b(cpu, bus, dst, val ^ (1 << b));
}

// --- Branch condition evaluation ---

fn eval_condition(cpu: &Cpu, cond: Condition) -> bool {
    match cond {
        Condition::Always => true,
        Condition::Never => false,
        Condition::Hi => !cpu.carry() && !cpu.zero(),
        Condition::Ls => cpu.carry() || cpu.zero(),
        Condition::Cc => !cpu.carry(),
        Condition::Cs => cpu.carry(),
        Condition::Ne => !cpu.zero(),
        Condition::Eq => cpu.zero(),
        Condition::Vc => !cpu.overflow(),
        Condition::Vs => cpu.overflow(),
        Condition::Pl => !cpu.negative(),
        Condition::Mi => cpu.negative(),
        Condition::Ge => cpu.negative() == cpu.overflow(),
        Condition::Lt => cpu.negative() != cpu.overflow(),
        Condition::Gt => !cpu.zero() && (cpu.negative() == cpu.overflow()),
        Condition::Le => cpu.zero() || (cpu.negative() != cpu.overflow()),
    }
}

fn resolve_jump_target(cpu: &Cpu, bus: &mut MemoryBus, target: &Operand) -> u32 {
    match target {
        Operand::RegIndirect(r) => cpu.read_er(*r) & 0x00FF_FFFF,
        Operand::Abs24(addr) => *addr & 0x00FF_FFFF,
        Operand::MemIndirect(abs) => {
            // Memory indirect: read 32-bit address from @@aa:8
            let vec_addr = *abs as u32;
            bus.read_long(vec_addr) & 0x00FF_FFFF
        }
        _ => panic!("resolve_jump_target: unexpected operand {:?}", target),
    }
}

// --- Operand read/write helpers ---

/// Resolve absolute 8-bit address (maps to 0xFFFFxx in H8/300H).
fn abs8_addr(abs: u8) -> u32 {
    0xFFFF00 | abs as u32
}

/// Resolve a memory-mode operand to an effective address.
/// Handles all addressing modes that map to a memory location.
/// For PostInc, advances the register by `size` bytes after computing the address.
/// Returns None for register/immediate operands that don't have a memory address.
fn resolve_read_address(cpu: &mut Cpu, op: &Operand, size: u32) -> Option<u32> {
    match op {
        Operand::RegIndirect(r) => Some(cpu.read_er(*r)),
        Operand::RegIndirectDisp16(r, d) => Some((cpu.read_er(*r) as i32 + *d as i32) as u32),
        Operand::RegIndirectDisp24(r, d) => Some(cpu.read_er(*r).wrapping_add(*d)),
        Operand::PostInc(r) => {
            let addr = cpu.read_er(*r);
            cpu.write_er(*r, addr + size);
            Some(addr)
        }
        Operand::Abs8(a) => Some(abs8_addr(*a)),
        Operand::Abs16(a) => Some(*a as i16 as i32 as u32 & 0x00FF_FFFF),
        Operand::Abs24(a) => Some(*a),
        _ => None,
    }
}

/// Resolve a memory-mode operand for write (PreDec decrements before computing address).
fn resolve_write_address(cpu: &mut Cpu, op: &Operand, size: u32) -> Option<u32> {
    match op {
        Operand::RegIndirect(r) => Some(cpu.read_er(*r)),
        Operand::RegIndirectDisp16(r, d) => Some((cpu.read_er(*r) as i32 + *d as i32) as u32),
        Operand::RegIndirectDisp24(r, d) => Some(cpu.read_er(*r).wrapping_add(*d)),
        Operand::PreDec(r) => {
            let addr = cpu.read_er(*r) - size;
            cpu.write_er(*r, addr);
            Some(addr)
        }
        Operand::Abs8(a) => Some(abs8_addr(*a)),
        Operand::Abs16(a) => Some(*a as i16 as i32 as u32 & 0x00FF_FFFF),
        Operand::Abs24(a) => Some(*a),
        _ => None,
    }
}

pub fn read_operand_b(cpu: &mut Cpu, bus: &mut MemoryBus, op: &Operand) -> u8 {
    match op {
        Operand::Reg8(r) => cpu.read_r8(*r),
        Operand::Imm8(v) => *v,
        Operand::Ccr => cpu.ccr,
        _ => if let Some(addr) = resolve_read_address(cpu, op, 1) {
            bus.read_byte(addr)
        } else {
            panic!("Unhandled byte read operand: {:?}", op);
        }
    }
}

pub fn write_operand_b(cpu: &mut Cpu, bus: &mut MemoryBus, op: &Operand, val: u8) {
    match op {
        Operand::Reg8(r) => cpu.write_r8(*r, val),
        Operand::Ccr => cpu.ccr = val,
        _ => if let Some(addr) = resolve_write_address(cpu, op, 1) {
            bus.write_byte(addr, val);
        } else {
            panic!("Unhandled byte write operand: {:?}", op);
        }
    }
}

pub fn read_operand_w(cpu: &mut Cpu, bus: &mut MemoryBus, op: &Operand) -> u16 {
    match op {
        Operand::Reg16(r) => cpu.read_r16(*r),
        Operand::Imm16(v) => *v,
        _ => if let Some(addr) = resolve_read_address(cpu, op, 2) {
            bus.read_word(addr)
        } else {
            panic!("Unhandled word read operand: {:?}", op);
        }
    }
}

pub fn write_operand_w(cpu: &mut Cpu, bus: &mut MemoryBus, op: &Operand, val: u16) {
    match op {
        Operand::Reg16(r) => cpu.write_r16(*r, val),
        _ => if let Some(addr) = resolve_write_address(cpu, op, 2) {
            bus.write_word(addr, val);
        } else {
            panic!("Unhandled word write operand: {:?}", op);
        }
    }
}

pub fn read_operand_l(cpu: &mut Cpu, bus: &mut MemoryBus, op: &Operand) -> u32 {
    match op {
        Operand::Reg32(r) => cpu.read_er(*r),
        Operand::Imm32(v) => *v,
        _ => if let Some(addr) = resolve_read_address(cpu, op, 4) {
            bus.read_long(addr)
        } else {
            panic!("Unhandled long read operand: {:?}", op);
        }
    }
}

pub fn write_operand_l(cpu: &mut Cpu, bus: &mut MemoryBus, op: &Operand, val: u32) {
    match op {
        Operand::Reg32(r) => cpu.write_er(*r, val),
        _ => if let Some(addr) = resolve_write_address(cpu, op, 4) {
            bus.write_long(addr, val);
        } else {
            panic!("Unhandled long write operand: {:?}", op);
        }
    }
}

/// Read byte from register-only operand (for ADDX/SUBX which only use registers/immediates).
fn read_operand_b_direct(cpu: &Cpu, op: &Operand) -> u8 {
    match op {
        Operand::Reg8(r) => cpu.read_r8(*r),
        Operand::Imm8(v) => *v,
        _ => panic!("read_operand_b_direct: unexpected operand {:?}, expected Reg8 or Imm8", op),
    }
}

fn write_operand_b_direct(cpu: &mut Cpu, op: &Operand, val: u8) {
    if let Operand::Reg8(r) = op {
        cpu.write_r8(*r, val);
    } else {
        panic!("write_operand_b_direct: unexpected operand {:?}, expected Reg8", op);
    }
}

/// Extract register number from a register operand.
fn extract_reg(op: &Operand) -> u8 {
    match op {
        Operand::Reg8(r) | Operand::Reg16(r) | Operand::Reg32(r) => *r,
        _ => panic!("extract_reg: unexpected operand {:?}, expected register", op),
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn make_cpu_bus() -> (Cpu, MemoryBus) {
        (Cpu::new(), MemoryBus::new())
    }

    #[test]
    fn test_mov_b_imm() {
        let (mut cpu, mut bus) = make_cpu_bus();
        let insn = Instruction::Mov(Size::Byte, Operand::Imm8(0x42), Operand::Reg8(8)); // R0L
        execute(&mut cpu, &mut bus, &insn, 0, 2);
        assert_eq!(cpu.read_r8(8), 0x42);
    }

    #[test]
    fn test_mov_l_imm() {
        let (mut cpu, mut bus) = make_cpu_bus();
        let insn = Instruction::Mov(Size::Long, Operand::Imm32(0x00410000), Operand::Reg32(7));
        execute(&mut cpu, &mut bus, &insn, 0, 6);
        assert_eq!(cpu.sp(), 0x00410000);
    }

    #[test]
    fn test_add_b_flags() {
        let (mut cpu, mut bus) = make_cpu_bus();
        cpu.write_r8(8, 0x7F); // R0L = 0x7F
        let insn = Instruction::Add(Size::Byte, Operand::Imm8(0x01), Operand::Reg8(8));
        execute(&mut cpu, &mut bus, &insn, 0, 2);
        assert_eq!(cpu.read_r8(8), 0x80);
        assert!(cpu.negative());
        assert!(!cpu.zero());
        assert!(cpu.overflow()); // 0x7F + 0x01 overflows (positive + positive = negative)
        assert!(cpu.half_carry()); // 0xF + 0x1 = 0x10
    }

    #[test]
    fn test_cmp_b() {
        let (mut cpu, mut bus) = make_cpu_bus();
        cpu.write_r8(8, 0x42); // R0L
        cpu.write_r8(9, 0x42); // R1L
        let insn = Instruction::Cmp(Size::Byte, Operand::Reg8(9), Operand::Reg8(8));
        execute(&mut cpu, &mut bus, &insn, 0, 2);
        assert!(cpu.zero());
        assert!(!cpu.carry());
    }

    #[test]
    fn test_bra() {
        let (mut cpu, mut bus) = make_cpu_bus();
        let insn = Instruction::Bcc(Condition::Always, Operand::PcRel8(10));
        let new_pc = execute(&mut cpu, &mut bus, &insn, 0x1000, 2);
        assert_eq!(new_pc, 0x100C); // 0x1002 + 10
    }

    #[test]
    fn test_beq_taken() {
        let (mut cpu, mut bus) = make_cpu_bus();
        cpu.set_flag(CCR_Z, true);
        let insn = Instruction::Bcc(Condition::Eq, Operand::PcRel8(4));
        let new_pc = execute(&mut cpu, &mut bus, &insn, 0x1000, 2);
        assert_eq!(new_pc, 0x1006); // 0x1002 + 4
    }

    #[test]
    fn test_beq_not_taken() {
        let (mut cpu, mut bus) = make_cpu_bus();
        cpu.set_flag(CCR_Z, false);
        let insn = Instruction::Bcc(Condition::Eq, Operand::PcRel8(4));
        let new_pc = execute(&mut cpu, &mut bus, &insn, 0x1000, 2);
        assert_eq!(new_pc, 0x1002); // falls through
    }

    #[test]
    fn test_jsr_rts() {
        let (mut cpu, mut bus) = make_cpu_bus();
        cpu.set_sp(0x410000);
        let insn = Instruction::Jsr(Operand::Abs24(0x020334));
        let new_pc = execute(&mut cpu, &mut bus, &insn, 0x1000, 4);
        assert_eq!(new_pc, 0x020334);
        assert_eq!(cpu.sp(), 0x410000 - 4); // return address pushed

        // RTS should pop it back
        let rts = Instruction::Rts;
        let ret_pc = execute(&mut cpu, &mut bus, &rts, 0x020334, 2);
        assert_eq!(ret_pc, 0x1004); // return to instruction after JSR
        assert_eq!(cpu.sp(), 0x410000);
    }

    #[test]
    fn test_trapa() {
        let (mut cpu, mut bus) = make_cpu_bus();
        cpu.set_sp(0x410000);
        // Set up vector table: TRAP #0 = vec 8, addr 0x020
        bus.flash_write_long(0x020, 0x00FFFD10); // Trampoline address

        let insn = Instruction::Trapa(0);
        let new_pc = execute(&mut cpu, &mut bus, &insn, 0x1000, 2);
        assert_eq!(new_pc, 0x00FFFD10);
        assert!(cpu.interrupt_masked());
        assert_eq!(cpu.sp(), 0x410000 - 4);
    }

    #[test]
    fn test_shll_b() {
        let (mut cpu, mut bus) = make_cpu_bus();
        cpu.write_r8(8, 0x81); // R0L = 0b10000001
        let insn = Instruction::Shll(Size::Byte, Operand::Reg8(8));
        execute(&mut cpu, &mut bus, &insn, 0, 2);
        assert_eq!(cpu.read_r8(8), 0x02);
        assert!(cpu.carry()); // MSB shifted out
    }

    #[test]
    fn test_eepmov_b() {
        let (mut cpu, mut bus) = make_cpu_bus();
        // Set up: copy 4 bytes from 0x400100 to 0x400200
        cpu.write_er(5, 0x400100); // Source
        cpu.write_er(6, 0x400200); // Dest
        cpu.write_r8(8 + 4, 4);   // R4L = count = 4
        bus.write_byte(0x400100, 0x5A);
        bus.write_byte(0x400101, 0x00);
        bus.write_byte(0x400102, 0x02);
        bus.write_byte(0x400103, 0x03);

        let insn = Instruction::EepmovB;
        execute(&mut cpu, &mut bus, &insn, 0, 4);

        assert_eq!(bus.read_byte(0x400200), 0x5A);
        assert_eq!(bus.read_byte(0x400201), 0x00);
        assert_eq!(bus.read_byte(0x400202), 0x02);
        assert_eq!(bus.read_byte(0x400203), 0x03);
        assert_eq!(cpu.read_r8(8 + 4), 0); // Count exhausted
    }

    #[test]
    fn test_orc_andc() {
        let (mut cpu, mut bus) = make_cpu_bus();
        cpu.ccr = 0x00;
        let orc = Instruction::Orc(Operand::Imm8(0x80));
        execute(&mut cpu, &mut bus, &orc, 0, 2);
        assert_eq!(cpu.ccr, 0x80);
        assert!(cpu.interrupt_masked());

        let andc = Instruction::Andc(Operand::Imm8(0x7F));
        execute(&mut cpu, &mut bus, &andc, 0, 2);
        assert_eq!(cpu.ccr, 0x00);
        assert!(!cpu.interrupt_masked());
    }

    #[test]
    fn test_bset_bclr_btst() {
        let (mut cpu, mut bus) = make_cpu_bus();
        cpu.write_r8(8, 0x00); // R0L = 0
        let bset = Instruction::Bset(Operand::Imm8(3), Operand::Reg8(8));
        execute(&mut cpu, &mut bus, &bset, 0, 2);
        assert_eq!(cpu.read_r8(8), 0x08);

        let btst = Instruction::Btst(Operand::Imm8(3), Operand::Reg8(8));
        execute(&mut cpu, &mut bus, &btst, 0, 2);
        assert!(!cpu.zero()); // Bit 3 is set

        let bclr = Instruction::Bclr(Operand::Imm8(3), Operand::Reg8(8));
        execute(&mut cpu, &mut bus, &bclr, 0, 2);
        assert_eq!(cpu.read_r8(8), 0x00);
    }

    // --- SUB flag tests ---

    #[test]
    fn test_sub_b_borrow() {
        let (mut cpu, mut bus) = make_cpu_bus();
        cpu.write_r8(8, 0x00); // R0L = 0
        cpu.write_r8(9, 0x01); // R1L = 1
        let insn = Instruction::Sub(Size::Byte, Operand::Reg8(9), Operand::Reg8(8));
        execute(&mut cpu, &mut bus, &insn, 0, 2);
        assert_eq!(cpu.read_r8(8), 0xFF);
        assert!(cpu.carry(), "borrow on 0 - 1");
        assert!(cpu.negative());
        assert!(!cpu.zero());
    }

    #[test]
    fn test_sub_b_overflow() {
        let (mut cpu, mut bus) = make_cpu_bus();
        cpu.write_r8(8, 0x80); // R0L = -128
        cpu.write_r8(9, 0x01); // R1L = 1
        let insn = Instruction::Sub(Size::Byte, Operand::Reg8(9), Operand::Reg8(8));
        execute(&mut cpu, &mut bus, &insn, 0, 2);
        assert_eq!(cpu.read_r8(8), 0x7F); // -128 - 1 = 127 (overflow)
        assert!(cpu.overflow(), "signed overflow: negative became positive");
        assert!(!cpu.negative());
    }

    #[test]
    fn test_sub_w_zero() {
        let (mut cpu, mut bus) = make_cpu_bus();
        cpu.write_r16(0, 0x1234);
        cpu.write_r16(1, 0x1234);
        let insn = Instruction::Sub(Size::Word, Operand::Reg16(1), Operand::Reg16(0));
        execute(&mut cpu, &mut bus, &insn, 0, 2);
        assert_eq!(cpu.read_r16(0), 0x0000);
        assert!(cpu.zero());
        assert!(!cpu.carry());
    }

    // --- NEG flag tests ---

    #[test]
    fn test_neg_b_msb_overflow() {
        let (mut cpu, mut bus) = make_cpu_bus();
        cpu.write_r8(8, 0x80); // R0L = -128
        let insn = Instruction::Neg(Size::Byte, Operand::Reg8(8));
        execute(&mut cpu, &mut bus, &insn, 0, 2);
        assert_eq!(cpu.read_r8(8), 0x80); // NEG(0x80) = 0x80
        assert!(cpu.overflow(), "V set when input == MSB");
        assert!(cpu.carry(), "C set when input != 0");
    }

    #[test]
    fn test_neg_b_zero() {
        let (mut cpu, mut bus) = make_cpu_bus();
        cpu.write_r8(8, 0x00);
        let insn = Instruction::Neg(Size::Byte, Operand::Reg8(8));
        execute(&mut cpu, &mut bus, &insn, 0, 2);
        assert_eq!(cpu.read_r8(8), 0x00);
        assert!(!cpu.carry(), "C clear when input == 0");
        assert!(cpu.zero());
        assert!(!cpu.overflow());
    }

    #[test]
    fn test_neg_b_normal() {
        let (mut cpu, mut bus) = make_cpu_bus();
        cpu.write_r8(8, 0x42);
        let insn = Instruction::Neg(Size::Byte, Operand::Reg8(8));
        execute(&mut cpu, &mut bus, &insn, 0, 2);
        assert_eq!(cpu.read_r8(8), 0xBE); // -0x42 = 0xBE
        assert!(cpu.carry(), "C set when input != 0");
        assert!(!cpu.overflow());
        assert!(cpu.negative());
    }

    // --- INC/DEC overflow tests ---

    #[test]
    fn test_inc_b_overflow() {
        let (mut cpu, mut bus) = make_cpu_bus();
        cpu.write_r8(8, 0x7F); // R0L = 127
        let insn = Instruction::Inc(Size::Byte, Operand::Reg8(8), 1);
        execute(&mut cpu, &mut bus, &insn, 0, 2);
        assert_eq!(cpu.read_r8(8), 0x80);
        assert!(cpu.overflow(), "V on 0x7F → 0x80 (positive → negative)");
        assert!(cpu.negative());
    }

    #[test]
    fn test_inc_b_no_overflow() {
        let (mut cpu, mut bus) = make_cpu_bus();
        cpu.write_r8(8, 0xFF);
        let insn = Instruction::Inc(Size::Byte, Operand::Reg8(8), 1);
        execute(&mut cpu, &mut bus, &insn, 0, 2);
        assert_eq!(cpu.read_r8(8), 0x00);
        assert!(!cpu.overflow(), "no V on 0xFF → 0x00");
        assert!(cpu.zero());
    }

    #[test]
    fn test_dec_b_overflow() {
        let (mut cpu, mut bus) = make_cpu_bus();
        cpu.write_r8(8, 0x80); // -128
        let insn = Instruction::Dec(Size::Byte, Operand::Reg8(8), 1);
        execute(&mut cpu, &mut bus, &insn, 0, 2);
        assert_eq!(cpu.read_r8(8), 0x7F);
        assert!(cpu.overflow(), "V on 0x80 → 0x7F (negative → positive)");
        assert!(!cpu.negative());
    }

    // --- ADDX/SUBX carry chain tests ---

    #[test]
    fn test_addx_z_flag_only_clears() {
        let (mut cpu, mut bus) = make_cpu_bus();
        cpu.set_flag(CCR_Z, true);
        cpu.set_flag(CCR_C, false);
        cpu.write_r8(8, 0x00);
        let insn = Instruction::Addx(Operand::Imm8(0), Operand::Reg8(8));
        execute(&mut cpu, &mut bus, &insn, 0, 2);
        assert_eq!(cpu.read_r8(8), 0x00);
        // ADDX only clears Z, never sets it -- Z stays true because result == 0
        assert!(cpu.zero(), "Z preserved (not cleared) when result is 0");
    }

    #[test]
    fn test_addx_z_flag_clears_on_nonzero() {
        let (mut cpu, mut bus) = make_cpu_bus();
        cpu.set_flag(CCR_Z, true);
        cpu.set_flag(CCR_C, false);
        cpu.write_r8(8, 0x01);
        let insn = Instruction::Addx(Operand::Imm8(0), Operand::Reg8(8));
        execute(&mut cpu, &mut bus, &insn, 0, 2);
        assert_eq!(cpu.read_r8(8), 0x01);
        assert!(!cpu.zero(), "Z cleared when result is non-zero");
    }

    #[test]
    fn test_addx_carry_chain() {
        let (mut cpu, mut bus) = make_cpu_bus();
        cpu.set_flag(CCR_C, true);
        cpu.write_r8(8, 0xFF);
        let insn = Instruction::Addx(Operand::Imm8(0x00), Operand::Reg8(8));
        execute(&mut cpu, &mut bus, &insn, 0, 2);
        assert_eq!(cpu.read_r8(8), 0x00); // 0xFF + 0 + C(1) = 0x100 → 0x00
        assert!(cpu.carry(), "carry out from 0xFF + 1");
    }

    #[test]
    fn test_subx_borrow_chain() {
        let (mut cpu, mut bus) = make_cpu_bus();
        cpu.set_flag(CCR_C, true); // borrow-in
        cpu.write_r8(8, 0x00);
        let insn = Instruction::Subx(Operand::Imm8(0x00), Operand::Reg8(8));
        execute(&mut cpu, &mut bus, &insn, 0, 2);
        assert_eq!(cpu.read_r8(8), 0xFF); // 0 - 0 - C(1) = -1
        assert!(cpu.carry(), "borrow out");
        assert!(cpu.negative());
    }

    // --- DIVXU edge cases ---

    #[test]
    fn test_divxu_b_by_zero() {
        let (mut cpu, mut bus) = make_cpu_bus();
        cpu.write_r16(0, 0x1234);
        cpu.write_r8(9, 0x00); // divisor = 0
        let insn = Instruction::DivxuB(Operand::Reg8(9), Operand::Reg16(0));
        execute(&mut cpu, &mut bus, &insn, 0, 2);
        assert!(cpu.zero(), "Z set on division by zero");
        assert_eq!(cpu.read_r16(0), 0x1234, "result unchanged on div-by-zero");
    }

    #[test]
    fn test_divxu_b_normal() {
        let (mut cpu, mut bus) = make_cpu_bus();
        cpu.write_r16(0, 0x000A); // dividend = 10
        cpu.write_r8(9, 0x03);    // divisor = 3
        let insn = Instruction::DivxuB(Operand::Reg8(9), Operand::Reg16(0));
        execute(&mut cpu, &mut bus, &insn, 0, 2);
        let result = cpu.read_r16(0);
        assert_eq!(result & 0xFF, 0x03, "quotient = 10/3 = 3");
        assert_eq!((result >> 8) & 0xFF, 0x01, "remainder = 10%3 = 1");
    }

    // --- Shift/rotate tests ---

    #[test]
    fn test_shar_b_preserves_sign() {
        let (mut cpu, mut bus) = make_cpu_bus();
        cpu.write_r8(8, 0x80); // -128
        let insn = Instruction::Shar(Size::Byte, Operand::Reg8(8));
        execute(&mut cpu, &mut bus, &insn, 0, 2);
        assert_eq!(cpu.read_r8(8), 0xC0); // sign-extended: 1100_0000
        assert!(!cpu.carry(), "LSB was 0");
        assert!(cpu.negative());
    }

    #[test]
    fn test_shar_b_carry() {
        let (mut cpu, mut bus) = make_cpu_bus();
        cpu.write_r8(8, 0x81); // 1000_0001
        let insn = Instruction::Shar(Size::Byte, Operand::Reg8(8));
        execute(&mut cpu, &mut bus, &insn, 0, 2);
        assert_eq!(cpu.read_r8(8), 0xC0); // 1100_0000
        assert!(cpu.carry(), "LSB was 1");
    }

    #[test]
    fn test_shlr_b() {
        let (mut cpu, mut bus) = make_cpu_bus();
        cpu.write_r8(8, 0x81);
        let insn = Instruction::Shlr(Size::Byte, Operand::Reg8(8));
        execute(&mut cpu, &mut bus, &insn, 0, 2);
        assert_eq!(cpu.read_r8(8), 0x40); // logical: no sign extension
        assert!(cpu.carry());
        assert!(!cpu.negative());
    }

    #[test]
    fn test_rotxl_b_through_carry() {
        let (mut cpu, mut bus) = make_cpu_bus();
        cpu.write_r8(8, 0x00);
        cpu.set_flag(CCR_C, true); // old carry = 1
        let insn = Instruction::Rotxl(Size::Byte, Operand::Reg8(8));
        execute(&mut cpu, &mut bus, &insn, 0, 2);
        assert_eq!(cpu.read_r8(8), 0x01); // old carry rotated into bit 0
        assert!(!cpu.carry(), "MSB was 0");
    }

    #[test]
    fn test_rotxr_b_through_carry() {
        let (mut cpu, mut bus) = make_cpu_bus();
        cpu.write_r8(8, 0x00);
        cpu.set_flag(CCR_C, true);
        let insn = Instruction::Rotxr(Size::Byte, Operand::Reg8(8));
        execute(&mut cpu, &mut bus, &insn, 0, 2);
        assert_eq!(cpu.read_r8(8), 0x80); // old carry rotated into bit 7
        assert!(!cpu.carry(), "LSB was 0");
    }

    #[test]
    fn test_rotl_b() {
        let (mut cpu, mut bus) = make_cpu_bus();
        cpu.write_r8(8, 0x81); // 1000_0001
        let insn = Instruction::Rotl(Size::Byte, Operand::Reg8(8));
        execute(&mut cpu, &mut bus, &insn, 0, 2);
        assert_eq!(cpu.read_r8(8), 0x03); // MSB wraps to bit 0: 0000_0011
        assert!(cpu.carry(), "old MSB was 1");
    }

    #[test]
    fn test_rotr_b() {
        let (mut cpu, mut bus) = make_cpu_bus();
        cpu.write_r8(8, 0x81); // 1000_0001
        let insn = Instruction::Rotr(Size::Byte, Operand::Reg8(8));
        execute(&mut cpu, &mut bus, &insn, 0, 2);
        assert_eq!(cpu.read_r8(8), 0xC0); // LSB wraps to bit 7: 1100_0000
        assert!(cpu.carry(), "old LSB was 1");
    }

    #[test]
    fn test_shal_b_overflow() {
        let (mut cpu, mut bus) = make_cpu_bus();
        cpu.write_r8(8, 0x40); // 0100_0000
        let insn = Instruction::Shal(Size::Byte, Operand::Reg8(8));
        execute(&mut cpu, &mut bus, &insn, 0, 2);
        assert_eq!(cpu.read_r8(8), 0x80);
        assert!(!cpu.carry(), "old MSB was 0");
        assert!(cpu.overflow(), "V = N xor C (sign bit changed: 0→1)");
    }

    // --- Branch condition evaluation ---

    /// Execute a Bcc with PcRel8(4) at PC=0x1000, len=2. Returns the resulting PC.
    /// Taken = 0x1006, not taken = 0x1002.
    fn run_branch(flags: &[(u8, bool)], cond: Condition) -> u32 {
        let (mut cpu, mut bus) = make_cpu_bus();
        for &(flag, val) in flags {
            cpu.set_flag(flag, val);
        }
        let insn = Instruction::Bcc(cond, Operand::PcRel8(4));
        execute(&mut cpu, &mut bus, &insn, 0x1000, 2)
    }

    const TAKEN: u32 = 0x1006;
    const NOT_TAKEN: u32 = 0x1002;

    #[test]
    fn test_bhi_taken() {
        assert_eq!(run_branch(&[(CCR_C, false), (CCR_Z, false)], Condition::Hi), TAKEN);
    }

    #[test]
    fn test_bhi_not_taken_c() {
        assert_eq!(run_branch(&[(CCR_C, true), (CCR_Z, false)], Condition::Hi), NOT_TAKEN);
    }

    #[test]
    fn test_bgt_taken() {
        assert_eq!(run_branch(&[(CCR_Z, false), (CCR_N, false), (CCR_V, false)], Condition::Gt), TAKEN);
    }

    #[test]
    fn test_bgt_not_taken_z() {
        assert_eq!(run_branch(&[(CCR_Z, true), (CCR_N, false), (CCR_V, false)], Condition::Gt), NOT_TAKEN);
    }

    #[test]
    fn test_ble_taken() {
        assert_eq!(run_branch(&[(CCR_Z, false), (CCR_N, true), (CCR_V, false)], Condition::Le), TAKEN);
    }

    #[test]
    fn test_bge_taken() {
        assert_eq!(run_branch(&[(CCR_N, true), (CCR_V, true)], Condition::Ge), TAKEN);
    }

    #[test]
    fn test_blt_taken() {
        assert_eq!(run_branch(&[(CCR_N, true), (CCR_V, false)], Condition::Lt), TAKEN);
    }

    #[test]
    fn test_bls_taken() {
        assert_eq!(run_branch(&[(CCR_C, false), (CCR_Z, true)], Condition::Ls), TAKEN);
    }

    #[test]
    fn test_backward_branch() {
        let (mut cpu, mut bus) = make_cpu_bus();
        let insn = Instruction::Bcc(Condition::Always, Operand::PcRel8(-4));
        let new_pc = execute(&mut cpu, &mut bus, &insn, 0x1000, 2);
        assert_eq!(new_pc, 0x0FFE); // 0x1002 + (-4)
    }

    // --- Memory addressing in execute ---

    #[test]
    fn test_mov_b_through_memory() {
        let (mut cpu, mut bus) = make_cpu_bus();
        cpu.write_er(0, 0x400100);
        bus.write_byte(0x400100, 0x42);
        let insn = Instruction::Mov(Size::Byte, Operand::RegIndirect(0), Operand::Reg8(9));
        execute(&mut cpu, &mut bus, &insn, 0, 2);
        assert_eq!(cpu.read_r8(9), 0x42);
    }

    #[test]
    fn test_mov_b_post_inc() {
        let (mut cpu, mut bus) = make_cpu_bus();
        // Use ER1 as source to avoid aliasing with R0L destination
        cpu.write_er(1, 0x400100);
        bus.write_byte(0x400100, 0xAA);
        let insn = Instruction::Mov(Size::Byte, Operand::PostInc(1), Operand::Reg8(8));
        execute(&mut cpu, &mut bus, &insn, 0, 2);
        assert_eq!(cpu.read_r8(8), 0xAA);
        assert_eq!(cpu.read_er(1), 0x400101, "ER1 incremented by 1 (byte)");
    }

    #[test]
    fn test_mov_b_pre_dec() {
        let (mut cpu, mut bus) = make_cpu_bus();
        cpu.write_er(7, 0x410000);
        cpu.write_r8(8, 0x55);
        let insn = Instruction::Mov(Size::Byte, Operand::Reg8(8), Operand::PreDec(7));
        execute(&mut cpu, &mut bus, &insn, 0, 2);
        assert_eq!(cpu.sp(), 0x40FFFF, "SP decremented by 1 (byte)");
        assert_eq!(bus.read_byte(0x40FFFF), 0x55);
    }

    #[test]
    fn test_mov_w_post_inc() {
        let (mut cpu, mut bus) = make_cpu_bus();
        cpu.write_er(0, 0x400100);
        bus.write_word(0x400100, 0x1234);
        let insn = Instruction::Mov(Size::Word, Operand::PostInc(0), Operand::Reg16(1));
        execute(&mut cpu, &mut bus, &insn, 0, 2);
        assert_eq!(cpu.read_r16(1), 0x1234);
        assert_eq!(cpu.read_er(0), 0x400102, "ER0 incremented by 2 (word)");
    }

    #[test]
    fn test_mov_l_pre_dec() {
        let (mut cpu, mut bus) = make_cpu_bus();
        cpu.write_er(7, 0x410000);
        cpu.write_er(0, 0xDEADBEEF);
        let insn = Instruction::Mov(Size::Long, Operand::Reg32(0), Operand::PreDec(7));
        execute(&mut cpu, &mut bus, &insn, 0, 2);
        assert_eq!(cpu.sp(), 0x40FFFC, "SP decremented by 4 (long)");
        assert_eq!(bus.read_long(0x40FFFC), 0xDEADBEEF);
    }

    #[test]
    fn test_mov_b_disp16() {
        let (mut cpu, mut bus) = make_cpu_bus();
        cpu.write_er(0, 0x400000);
        bus.write_byte(0x400010, 0xBB);
        let insn = Instruction::Mov(Size::Byte, Operand::RegIndirectDisp16(0, 0x0010), Operand::Reg8(8));
        execute(&mut cpu, &mut bus, &insn, 0, 4);
        assert_eq!(cpu.read_r8(8), 0xBB);
    }

    #[test]
    fn test_mov_b_abs8() {
        let (mut cpu, mut bus) = make_cpu_bus();
        bus.write_byte(0xFFFF85, 0x42); // Port 4 DR
        let insn = Instruction::Mov(Size::Byte, Operand::Abs8(0x85), Operand::Reg8(8));
        execute(&mut cpu, &mut bus, &insn, 0, 2);
        assert_eq!(cpu.read_r8(8), 0x42);
    }

    // --- ADD.W/ADD.L flag tests ---

    #[test]
    fn test_add_w_overflow() {
        let (mut cpu, mut bus) = make_cpu_bus();
        cpu.write_r16(0, 0x7FFF);
        let insn = Instruction::Add(Size::Word, Operand::Imm16(0x0001), Operand::Reg16(0));
        execute(&mut cpu, &mut bus, &insn, 0, 4);
        assert_eq!(cpu.read_r16(0), 0x8000);
        assert!(cpu.overflow(), "0x7FFF + 1 overflows (positive → negative)");
        assert!(cpu.negative());
        assert!(!cpu.carry());
    }

    #[test]
    fn test_add_l_carry() {
        let (mut cpu, mut bus) = make_cpu_bus();
        cpu.write_er(0, 0xFFFF_FFFF);
        let insn = Instruction::Add(Size::Long, Operand::Imm32(0x0000_0001), Operand::Reg32(0));
        execute(&mut cpu, &mut bus, &insn, 0, 6);
        assert_eq!(cpu.read_er(0), 0x0000_0000);
        assert!(cpu.carry(), "unsigned carry on 0xFFFFFFFF + 1");
        assert!(cpu.zero());
    }

    // --- EXTU/EXTS tests ---

    #[test]
    fn test_extu_w() {
        let (mut cpu, mut bus) = make_cpu_bus();
        cpu.write_r16(0, 0xFF42); // R0 = 0xFF42
        let insn = Instruction::Extu(Size::Word, Operand::Reg16(0));
        execute(&mut cpu, &mut bus, &insn, 0, 2);
        assert_eq!(cpu.read_r16(0), 0x0042); // zero-extend low byte
        assert!(!cpu.negative());
        assert!(!cpu.zero());
        assert!(!cpu.overflow());
    }

    #[test]
    fn test_exts_w() {
        let (mut cpu, mut bus) = make_cpu_bus();
        cpu.write_r16(0, 0x0080); // R0 low byte = 0x80 (negative)
        let insn = Instruction::Exts(Size::Word, Operand::Reg16(0));
        execute(&mut cpu, &mut bus, &insn, 0, 2);
        assert_eq!(cpu.read_r16(0), 0xFF80); // sign-extend 0x80
        assert!(cpu.negative());
        assert!(!cpu.zero());
    }

    // --- Bit-on-memory tests ---

    #[test]
    fn test_bset_bclr_memory() {
        let (mut cpu, mut bus) = make_cpu_bus();
        bus.write_byte(0xFFFF85, 0x00); // Port 4 DR = 0
        let bset = Instruction::Bset(Operand::Imm8(0), Operand::Abs8(0x85));
        execute(&mut cpu, &mut bus, &bset, 0, 4);
        assert_eq!(bus.read_byte(0xFFFF85), 0x01);

        let bclr = Instruction::Bclr(Operand::Imm8(0), Operand::Abs8(0x85));
        execute(&mut cpu, &mut bus, &bclr, 0, 4);
        assert_eq!(bus.read_byte(0xFFFF85), 0x00);
    }

    #[test]
    fn test_btst_memory() {
        let (mut cpu, mut bus) = make_cpu_bus();
        bus.write_byte(0xFFFF8E, 0x04); // Port 7
        let btst = Instruction::Btst(Operand::Imm8(2), Operand::Abs8(0x8E));
        execute(&mut cpu, &mut bus, &btst, 0, 4);
        assert!(!cpu.zero(), "bit 2 is set");

        let btst2 = Instruction::Btst(Operand::Imm8(0), Operand::Abs8(0x8E));
        execute(&mut cpu, &mut bus, &btst2, 0, 4);
        assert!(cpu.zero(), "bit 0 is clear");
    }

    // --- DIVXU.W ---

    #[test]
    fn test_divxu_w_normal() {
        let (mut cpu, mut bus) = make_cpu_bus();
        cpu.write_er(0, 0x0000000A); // dividend = 10
        cpu.write_r16(1, 0x0003);     // divisor = 3
        let insn = Instruction::DivxuW(Operand::Reg16(1), Operand::Reg32(0));
        execute(&mut cpu, &mut bus, &insn, 0, 2);
        let result = cpu.read_er(0);
        assert_eq!(result & 0xFFFF, 0x0003, "quotient = 10/3 = 3");
        assert_eq!((result >> 16) & 0xFFFF, 0x0001, "remainder = 10%3 = 1");
    }

    #[test]
    fn test_divxu_w_by_zero() {
        let (mut cpu, mut bus) = make_cpu_bus();
        cpu.write_er(0, 0x12345678);
        cpu.write_r16(1, 0x0000);
        let insn = Instruction::DivxuW(Operand::Reg16(1), Operand::Reg32(0));
        execute(&mut cpu, &mut bus, &insn, 0, 2);
        assert!(cpu.zero());
        assert_eq!(cpu.read_er(0), 0x12345678, "result unchanged on div-by-zero");
    }

    // --- EXTU.L / EXTS.L ---

    #[test]
    fn test_extu_l() {
        let (mut cpu, mut bus) = make_cpu_bus();
        cpu.write_er(0, 0xFFFF8042);
        let insn = Instruction::Extu(Size::Long, Operand::Reg32(0));
        execute(&mut cpu, &mut bus, &insn, 0, 2);
        assert_eq!(cpu.read_er(0), 0x00008042); // zero-extend low word
        assert!(!cpu.negative());
        assert!(!cpu.zero());
    }

    #[test]
    fn test_exts_l() {
        let (mut cpu, mut bus) = make_cpu_bus();
        cpu.write_er(0, 0x00008000); // low word = 0x8000 (negative)
        let insn = Instruction::Exts(Size::Long, Operand::Reg32(0));
        execute(&mut cpu, &mut bus, &insn, 0, 2);
        assert_eq!(cpu.read_er(0), 0xFFFF8000); // sign-extend 0x8000
        assert!(cpu.negative());
    }

    // --- Word-size shift ---

    #[test]
    fn test_shar_w() {
        let (mut cpu, mut bus) = make_cpu_bus();
        cpu.write_r16(0, 0x8001);
        let insn = Instruction::Shar(Size::Word, Operand::Reg16(0));
        execute(&mut cpu, &mut bus, &insn, 0, 2);
        assert_eq!(cpu.read_r16(0), 0xC000); // sign-extended right shift, bit 0 → carry
        assert!(cpu.carry());
        assert!(cpu.negative());
    }

    // --- MOV sets N/Z and clears V ---

    #[test]
    fn test_mov_flags() {
        let (mut cpu, mut bus) = make_cpu_bus();
        cpu.set_flag(CCR_V, true); // pre-set V
        cpu.write_r8(8, 0x80);
        let insn = Instruction::Mov(Size::Byte, Operand::Reg8(8), Operand::Reg8(9));
        execute(&mut cpu, &mut bus, &insn, 0, 2);
        assert_eq!(cpu.read_r8(9), 0x80);
        assert!(cpu.negative(), "N set for 0x80");
        assert!(!cpu.zero());
        assert!(!cpu.overflow(), "V cleared by MOV");
    }

    #[test]
    fn test_mov_zero_flag() {
        let (mut cpu, mut bus) = make_cpu_bus();
        cpu.write_r8(8, 0x00);
        let insn = Instruction::Mov(Size::Byte, Operand::Reg8(8), Operand::Reg8(9));
        execute(&mut cpu, &mut bus, &insn, 0, 2);
        assert!(cpu.zero());
        assert!(!cpu.negative());
    }
}
