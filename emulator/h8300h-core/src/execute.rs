/// H8/300H instruction executor.
///
/// Each instruction modifies CPU registers, memory, and/or CCR flags
/// according to the Hitachi H8/300H Programming Manual.

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
        Instruction::Inc(size, op) => {
            exec_inc(cpu, *size, op);
            next_pc
        }
        Instruction::Dec(size, op) => {
            exec_dec(cpu, *size, op);
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
            let dl = (d & 0xFF) as u16;
            let result = dl * s;
            write_operand_w(cpu, bus, dst, result);
            // No flags affected
            next_pc
        }
        Instruction::MulxuW(src, dst) => {
            let s = read_operand_w(cpu, bus, src) as u32;
            let d = read_operand_l(cpu, bus, dst);
            let dl = (d & 0xFFFF) as u32;
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
                cpu.set_flag(CCR_N, quotient & 0x80 != 0);
                cpu.set_flag(CCR_Z, quotient == 0);
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
                cpu.set_flag(CCR_N, quotient & 0x8000 != 0);
                cpu.set_flag(CCR_Z, quotient == 0);
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
                _ => {}
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
                _ => {}
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
            match size {
                Size::Byte => {
                    let val = read_operand_b(cpu, bus, op);
                    let result = !val;
                    write_operand_b(cpu, bus, op, result);
                    cpu.update_nz_b(result);
                    cpu.set_flag(CCR_V, false);
                }
                Size::Word => {
                    let val = read_operand_w(cpu, bus, op);
                    let result = !val;
                    write_operand_w(cpu, bus, op, result);
                    cpu.update_nz_w(result);
                    cpu.set_flag(CCR_V, false);
                }
                Size::Long => {
                    let val = read_operand_l(cpu, bus, op);
                    let result = !val;
                    write_operand_l(cpu, bus, op, result);
                    cpu.update_nz_l(result);
                    cpu.set_flag(CCR_V, false);
                }
            }
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
            let sp = cpu.sp();
            let ccr_val = bus.read_word(sp);
            cpu.ccr = ccr_val as u8;
            let addr = bus.read_long(sp + 2);
            cpu.set_sp(sp + 6);
            addr & 0x00FF_FFFF
        }
        Instruction::Trapa(vec_num) => {
            // Push CCR (as word, zero-extended) and PC onto stack
            let sp = cpu.sp() - 6;
            cpu.set_sp(sp);
            bus.write_word(sp, cpu.ccr as u16);
            bus.write_long(sp + 2, next_pc);
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
            log::error!("Unknown instruction 0x{:04X} at PC=0x{:06X}", w, insn_pc);
            next_pc
        }
    }
}

// --- Helper functions ---

fn exec_mov(cpu: &mut Cpu, bus: &mut MemoryBus, size: Size, src: &Operand, dst: &Operand) {
    match size {
        Size::Byte => {
            let val = read_operand_b(cpu, bus, src);
            write_operand_b(cpu, bus, dst, val);
            cpu.update_nz_b(val);
            cpu.set_flag(CCR_V, false);
        }
        Size::Word => {
            let val = read_operand_w(cpu, bus, src);
            write_operand_w(cpu, bus, dst, val);
            cpu.update_nz_w(val);
            cpu.set_flag(CCR_V, false);
        }
        Size::Long => {
            let val = read_operand_l(cpu, bus, src);
            write_operand_l(cpu, bus, dst, val);
            cpu.update_nz_l(val);
            cpu.set_flag(CCR_V, false);
        }
    }
}

fn exec_add(cpu: &mut Cpu, bus: &mut MemoryBus, size: Size, src: &Operand, dst: &Operand) {
    match size {
        Size::Byte => {
            let s = read_operand_b(cpu, bus, src);
            let d = read_operand_b(cpu, bus, dst);
            let (result, carry) = d.overflowing_add(s);
            let half = (d & 0xF) + (s & 0xF) > 0xF;
            let overflow = (!(s ^ d) & (s ^ result)) & 0x80 != 0;
            write_operand_b(cpu, bus, dst, result);
            cpu.update_nz_b(result);
            cpu.set_flag(CCR_H, half);
            cpu.set_flag(CCR_V, overflow);
            cpu.set_flag(CCR_C, carry);
        }
        Size::Word => {
            let s = read_operand_w(cpu, bus, src);
            let d = read_operand_w(cpu, bus, dst);
            let (result, carry) = d.overflowing_add(s);
            let half = (d & 0xFFF) + (s & 0xFFF) > 0xFFF;
            let overflow = (!(s ^ d) & (s ^ result)) & 0x8000 != 0;
            write_operand_w(cpu, bus, dst, result);
            cpu.update_nz_w(result);
            cpu.set_flag(CCR_H, half);
            cpu.set_flag(CCR_V, overflow);
            cpu.set_flag(CCR_C, carry);
        }
        Size::Long => {
            let s = read_operand_l(cpu, bus, src);
            let d = read_operand_l(cpu, bus, dst);
            let (result, carry) = d.overflowing_add(s);
            let half = (d & 0xFFF_FFFF) + (s & 0xFFF_FFFF) > 0xFFF_FFFF;
            let overflow = (!(s ^ d) & (s ^ result)) & 0x8000_0000 != 0;
            write_operand_l(cpu, bus, dst, result);
            cpu.update_nz_l(result);
            cpu.set_flag(CCR_H, half);
            cpu.set_flag(CCR_V, overflow);
            cpu.set_flag(CCR_C, carry);
        }
    }
}

fn exec_sub(cpu: &mut Cpu, bus: &mut MemoryBus, size: Size, src: &Operand, dst: &Operand) {
    match size {
        Size::Byte => {
            let s = read_operand_b(cpu, bus, src);
            let d = read_operand_b(cpu, bus, dst);
            let (result, borrow) = d.overflowing_sub(s);
            let half = (d & 0xF) < (s & 0xF);
            let overflow = ((s ^ d) & !(s ^ result)) & 0x80 != 0;
            write_operand_b(cpu, bus, dst, result);
            cpu.update_nz_b(result);
            cpu.set_flag(CCR_H, half);
            cpu.set_flag(CCR_V, overflow);
            cpu.set_flag(CCR_C, borrow);
        }
        Size::Word => {
            let s = read_operand_w(cpu, bus, src);
            let d = read_operand_w(cpu, bus, dst);
            let (result, borrow) = d.overflowing_sub(s);
            let half = (d & 0xFFF) < (s & 0xFFF);
            let overflow = ((s ^ d) & !(s ^ result)) & 0x8000 != 0;
            write_operand_w(cpu, bus, dst, result);
            cpu.update_nz_w(result);
            cpu.set_flag(CCR_H, half);
            cpu.set_flag(CCR_V, overflow);
            cpu.set_flag(CCR_C, borrow);
        }
        Size::Long => {
            let s = read_operand_l(cpu, bus, src);
            let d = read_operand_l(cpu, bus, dst);
            let (result, borrow) = d.overflowing_sub(s);
            let half = (d & 0xFFF_FFFF) < (s & 0xFFF_FFFF);
            let overflow = ((s ^ d) & !(s ^ result)) & 0x8000_0000 != 0;
            write_operand_l(cpu, bus, dst, result);
            cpu.update_nz_l(result);
            cpu.set_flag(CCR_H, half);
            cpu.set_flag(CCR_V, overflow);
            cpu.set_flag(CCR_C, borrow);
        }
    }
}

fn exec_cmp(cpu: &mut Cpu, bus: &mut MemoryBus, size: Size, src: &Operand, dst: &Operand) {
    // CMP is SUB without storing the result
    match size {
        Size::Byte => {
            let s = read_operand_b(cpu, bus, src);
            let d = read_operand_b(cpu, bus, dst);
            let (result, borrow) = d.overflowing_sub(s);
            let half = (d & 0xF) < (s & 0xF);
            let overflow = ((s ^ d) & !(s ^ result)) & 0x80 != 0;
            cpu.update_nz_b(result);
            cpu.set_flag(CCR_H, half);
            cpu.set_flag(CCR_V, overflow);
            cpu.set_flag(CCR_C, borrow);
        }
        Size::Word => {
            let s = read_operand_w(cpu, bus, src);
            let d = read_operand_w(cpu, bus, dst);
            let (result, borrow) = d.overflowing_sub(s);
            let half = (d & 0xFFF) < (s & 0xFFF);
            let overflow = ((s ^ d) & !(s ^ result)) & 0x8000 != 0;
            cpu.update_nz_w(result);
            cpu.set_flag(CCR_H, half);
            cpu.set_flag(CCR_V, overflow);
            cpu.set_flag(CCR_C, borrow);
        }
        Size::Long => {
            let s = read_operand_l(cpu, bus, src);
            let d = read_operand_l(cpu, bus, dst);
            let (result, borrow) = d.overflowing_sub(s);
            let half = (d & 0xFFF_FFFF) < (s & 0xFFF_FFFF);
            let overflow = ((s ^ d) & !(s ^ result)) & 0x8000_0000 != 0;
            cpu.update_nz_l(result);
            cpu.set_flag(CCR_H, half);
            cpu.set_flag(CCR_V, overflow);
            cpu.set_flag(CCR_C, borrow);
        }
    }
}

fn exec_neg(cpu: &mut Cpu, bus: &mut MemoryBus, size: Size, op: &Operand) {
    match size {
        Size::Byte => {
            let val = read_operand_b(cpu, bus, op);
            let result = (0u8).wrapping_sub(val);
            write_operand_b(cpu, bus, op, result);
            cpu.update_nz_b(result);
            cpu.set_flag(CCR_V, val == 0x80);
            cpu.set_flag(CCR_C, val != 0);
            cpu.set_flag(CCR_H, (val & 0xF) != 0);
        }
        Size::Word => {
            let val = read_operand_w(cpu, bus, op);
            let result = (0u16).wrapping_sub(val);
            write_operand_w(cpu, bus, op, result);
            cpu.update_nz_w(result);
            cpu.set_flag(CCR_V, val == 0x8000);
            cpu.set_flag(CCR_C, val != 0);
            cpu.set_flag(CCR_H, (val & 0xFFF) != 0);
        }
        Size::Long => {
            let val = read_operand_l(cpu, bus, op);
            let result = (0u32).wrapping_sub(val);
            write_operand_l(cpu, bus, op, result);
            cpu.update_nz_l(result);
            cpu.set_flag(CCR_V, val == 0x8000_0000);
            cpu.set_flag(CCR_C, val != 0);
            cpu.set_flag(CCR_H, (val & 0xFFF_FFFF) != 0);
        }
    }
}

fn exec_inc(cpu: &mut Cpu, size: Size, op: &Operand) {
    match size {
        Size::Byte => {
            let val = cpu.read_r8(extract_reg(op));
            let result = val.wrapping_add(1);
            cpu.write_r8(extract_reg(op), result);
            cpu.update_nz_b(result);
            cpu.set_flag(CCR_V, val == 0x7F);
        }
        Size::Word => {
            let r = extract_reg(op);
            let val = cpu.read_r16(r);
            let result = val.wrapping_add(1);
            cpu.write_r16(r, result);
            cpu.update_nz_w(result);
            cpu.set_flag(CCR_V, val == 0x7FFF);
        }
        Size::Long => {
            let r = extract_reg(op);
            let val = cpu.read_er(r);
            let result = val.wrapping_add(1);
            cpu.write_er(r, result);
            cpu.update_nz_l(result);
            cpu.set_flag(CCR_V, val == 0x7FFF_FFFF);
        }
    }
}

fn exec_dec(cpu: &mut Cpu, size: Size, op: &Operand) {
    match size {
        Size::Byte => {
            let r = extract_reg(op);
            let val = cpu.read_r8(r);
            let result = val.wrapping_sub(1);
            cpu.write_r8(r, result);
            cpu.update_nz_b(result);
            cpu.set_flag(CCR_V, val == 0x80);
        }
        Size::Word => {
            let r = extract_reg(op);
            let val = cpu.read_r16(r);
            let result = val.wrapping_sub(1);
            cpu.write_r16(r, result);
            cpu.update_nz_w(result);
            cpu.set_flag(CCR_V, val == 0x8000);
        }
        Size::Long => {
            let r = extract_reg(op);
            let val = cpu.read_er(r);
            let result = val.wrapping_sub(1);
            cpu.write_er(r, result);
            cpu.update_nz_l(result);
            cpu.set_flag(CCR_V, val == 0x8000_0000);
        }
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
    match size {
        Size::Byte => {
            let s = read_operand_b(cpu, bus, src);
            let d = read_operand_b(cpu, bus, dst);
            let result = match op {
                LogicOp::And => d & s,
                LogicOp::Or => d | s,
                LogicOp::Xor => d ^ s,
            };
            write_operand_b(cpu, bus, dst, result);
            cpu.update_nz_b(result);
            cpu.set_flag(CCR_V, false);
        }
        Size::Word => {
            let s = read_operand_w(cpu, bus, src);
            let d = read_operand_w(cpu, bus, dst);
            let result = match op {
                LogicOp::And => d & s,
                LogicOp::Or => d | s,
                LogicOp::Xor => d ^ s,
            };
            write_operand_w(cpu, bus, dst, result);
            cpu.update_nz_w(result);
            cpu.set_flag(CCR_V, false);
        }
        Size::Long => {
            let s = read_operand_l(cpu, bus, src);
            let d = read_operand_l(cpu, bus, dst);
            let result = match op {
                LogicOp::And => d & s,
                LogicOp::Or => d | s,
                LogicOp::Xor => d ^ s,
            };
            write_operand_l(cpu, bus, dst, result);
            cpu.update_nz_l(result);
            cpu.set_flag(CCR_V, false);
        }
    }
}

enum ShiftOp { Shal, Shar, Shll, Shlr, Rotl, Rotr, Rotxl, Rotxr }

fn exec_shift(cpu: &mut Cpu, bus: &mut MemoryBus, size: Size, op: &Operand, shift: ShiftOp) {
    match size {
        Size::Byte => {
            let val = read_operand_b(cpu, bus, op);
            let (result, carry) = shift_byte(val, cpu.carry(), &shift);
            write_operand_b(cpu, bus, op, result);
            cpu.update_nz_b(result);
            cpu.set_flag(CCR_C, carry);
            // V = N xor C for arithmetic shifts
            match shift {
                ShiftOp::Shal | ShiftOp::Shar => {
                    cpu.set_flag(CCR_V, cpu.negative() ^ cpu.carry());
                }
                _ => cpu.set_flag(CCR_V, false),
            }
        }
        Size::Word => {
            let val = read_operand_w(cpu, bus, op);
            let (result, carry) = shift_word(val, cpu.carry(), &shift);
            write_operand_w(cpu, bus, op, result);
            cpu.update_nz_w(result);
            cpu.set_flag(CCR_C, carry);
            match shift {
                ShiftOp::Shal | ShiftOp::Shar => {
                    cpu.set_flag(CCR_V, cpu.negative() ^ cpu.carry());
                }
                _ => cpu.set_flag(CCR_V, false),
            }
        }
        Size::Long => {
            let val = read_operand_l(cpu, bus, op);
            let (result, carry) = shift_long(val, cpu.carry(), &shift);
            write_operand_l(cpu, bus, op, result);
            cpu.update_nz_l(result);
            cpu.set_flag(CCR_C, carry);
            match shift {
                ShiftOp::Shal | ShiftOp::Shar => {
                    cpu.set_flag(CCR_V, cpu.negative() ^ cpu.carry());
                }
                _ => cpu.set_flag(CCR_V, false),
            }
        }
    }
}

fn shift_byte(val: u8, old_c: bool, op: &ShiftOp) -> (u8, bool) {
    match op {
        ShiftOp::Shal | ShiftOp::Shll => {
            let carry = val & 0x80 != 0;
            (val << 1, carry)
        }
        ShiftOp::Shar => {
            let carry = val & 0x01 != 0;
            ((val as i8 >> 1) as u8, carry) // arithmetic: sign-extend
        }
        ShiftOp::Shlr => {
            let carry = val & 0x01 != 0;
            (val >> 1, carry)
        }
        ShiftOp::Rotl => {
            let carry = val & 0x80 != 0;
            let result = (val << 1) | (carry as u8);
            (result, carry)
        }
        ShiftOp::Rotr => {
            let carry = val & 0x01 != 0;
            let result = (val >> 1) | ((carry as u8) << 7);
            (result, carry)
        }
        ShiftOp::Rotxl => {
            let carry = val & 0x80 != 0;
            let result = (val << 1) | (old_c as u8);
            (result, carry)
        }
        ShiftOp::Rotxr => {
            let carry = val & 0x01 != 0;
            let result = (val >> 1) | ((old_c as u8) << 7);
            (result, carry)
        }
    }
}

fn shift_word(val: u16, old_c: bool, op: &ShiftOp) -> (u16, bool) {
    match op {
        ShiftOp::Shal | ShiftOp::Shll => {
            let carry = val & 0x8000 != 0;
            (val << 1, carry)
        }
        ShiftOp::Shar => {
            let carry = val & 0x0001 != 0;
            ((val as i16 >> 1) as u16, carry)
        }
        ShiftOp::Shlr => {
            let carry = val & 0x0001 != 0;
            (val >> 1, carry)
        }
        ShiftOp::Rotl => {
            let carry = val & 0x8000 != 0;
            ((val << 1) | (carry as u16), carry)
        }
        ShiftOp::Rotr => {
            let carry = val & 0x0001 != 0;
            ((val >> 1) | ((carry as u16) << 15), carry)
        }
        ShiftOp::Rotxl => {
            let carry = val & 0x8000 != 0;
            ((val << 1) | (old_c as u16), carry)
        }
        ShiftOp::Rotxr => {
            let carry = val & 0x0001 != 0;
            ((val >> 1) | ((old_c as u16) << 15), carry)
        }
    }
}

fn shift_long(val: u32, old_c: bool, op: &ShiftOp) -> (u32, bool) {
    match op {
        ShiftOp::Shal | ShiftOp::Shll => {
            let carry = val & 0x8000_0000 != 0;
            (val << 1, carry)
        }
        ShiftOp::Shar => {
            let carry = val & 0x0000_0001 != 0;
            ((val as i32 >> 1) as u32, carry)
        }
        ShiftOp::Shlr => {
            let carry = val & 0x0000_0001 != 0;
            (val >> 1, carry)
        }
        ShiftOp::Rotl => {
            let carry = val & 0x8000_0000 != 0;
            ((val << 1) | (carry as u32), carry)
        }
        ShiftOp::Rotr => {
            let carry = val & 0x0000_0001 != 0;
            ((val >> 1) | ((carry as u32) << 31), carry)
        }
        ShiftOp::Rotxl => {
            let carry = val & 0x8000_0000 != 0;
            ((val << 1) | (old_c as u32), carry)
        }
        ShiftOp::Rotxr => {
            let carry = val & 0x0000_0001 != 0;
            ((val >> 1) | ((old_c as u32) << 31), carry)
        }
    }
}

// --- Bit manipulation helpers ---

fn get_bit_num(cpu: &Cpu, op: &Operand) -> u8 {
    match op {
        Operand::Imm8(n) => *n & 0x7,
        Operand::Reg8(r) => cpu.read_r8(*r) & 0x7,
        _ => 0,
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
        _ => 0,
    }
}

// --- Operand read/write helpers ---

/// Resolve absolute 8-bit address (maps to 0xFFFFxx in H8/300H).
fn abs8_addr(abs: u8) -> u32 {
    0xFFFF00 | abs as u32
}

pub fn read_operand_b(cpu: &mut Cpu, bus: &mut MemoryBus, op: &Operand) -> u8 {
    match op {
        Operand::Reg8(r) => cpu.read_r8(*r),
        Operand::Imm8(v) => *v,
        Operand::RegIndirect(r) => bus.read_byte(cpu.read_er(*r)),
        Operand::RegIndirectDisp16(r, d) => {
            let addr = (cpu.read_er(*r) as i32 + *d as i32) as u32;
            bus.read_byte(addr)
        }
        Operand::RegIndirectDisp24(r, d) => {
            let addr = cpu.read_er(*r).wrapping_add(*d);
            bus.read_byte(addr)
        }
        Operand::PostInc(r) => {
            let addr = cpu.read_er(*r);
            let val = bus.read_byte(addr);
            cpu.write_er(*r, addr + 1); // Post-increment by 1 for byte
            val
        }
        Operand::Abs8(a) => bus.read_byte(abs8_addr(*a)),
        Operand::Abs16(a) => {
            let addr = *a as i16 as i32 as u32 & 0x00FF_FFFF;
            bus.read_byte(addr)
        }
        Operand::Abs24(a) => bus.read_byte(*a),
        Operand::Ccr => cpu.ccr,
        _ => {
            log::warn!("Unhandled byte read operand: {:?}", op);
            0
        }
    }
}

pub fn write_operand_b(cpu: &mut Cpu, bus: &mut MemoryBus, op: &Operand, val: u8) {
    match op {
        Operand::Reg8(r) => cpu.write_r8(*r, val),
        Operand::RegIndirect(r) => bus.write_byte(cpu.read_er(*r), val),
        Operand::RegIndirectDisp16(r, d) => {
            let addr = (cpu.read_er(*r) as i32 + *d as i32) as u32;
            bus.write_byte(addr, val);
        }
        Operand::RegIndirectDisp24(r, d) => {
            let addr = cpu.read_er(*r).wrapping_add(*d);
            bus.write_byte(addr, val);
        }
        Operand::PreDec(r) => {
            let addr = cpu.read_er(*r) - 1;
            cpu.write_er(*r, addr);
            bus.write_byte(addr, val);
        }
        Operand::Abs8(a) => bus.write_byte(abs8_addr(*a), val),
        Operand::Abs16(a) => {
            let addr = *a as i16 as i32 as u32 & 0x00FF_FFFF;
            bus.write_byte(addr, val);
        }
        Operand::Abs24(a) => bus.write_byte(*a, val),
        Operand::Ccr => cpu.ccr = val,
        _ => log::warn!("Unhandled byte write operand: {:?}", op),
    }
}

pub fn read_operand_w(cpu: &mut Cpu, bus: &mut MemoryBus, op: &Operand) -> u16 {
    match op {
        Operand::Reg16(r) => cpu.read_r16(*r),
        Operand::Imm16(v) => *v,
        Operand::RegIndirect(r) => bus.read_word(cpu.read_er(*r)),
        Operand::RegIndirectDisp16(r, d) => {
            let addr = (cpu.read_er(*r) as i32 + *d as i32) as u32;
            bus.read_word(addr)
        }
        Operand::RegIndirectDisp24(r, d) => {
            let addr = cpu.read_er(*r).wrapping_add(*d);
            bus.read_word(addr)
        }
        Operand::PostInc(r) => {
            let addr = cpu.read_er(*r);
            let val = bus.read_word(addr);
            cpu.write_er(*r, addr + 2); // Post-increment by 2 for word
            val
        }
        Operand::Abs16(a) => {
            let addr = *a as i16 as i32 as u32 & 0x00FF_FFFF;
            bus.read_word(addr)
        }
        Operand::Abs24(a) => bus.read_word(*a),
        _ => {
            log::warn!("Unhandled word read operand: {:?}", op);
            0
        }
    }
}

pub fn write_operand_w(cpu: &mut Cpu, bus: &mut MemoryBus, op: &Operand, val: u16) {
    match op {
        Operand::Reg16(r) => cpu.write_r16(*r, val),
        Operand::RegIndirect(r) => bus.write_word(cpu.read_er(*r), val),
        Operand::RegIndirectDisp16(r, d) => {
            let addr = (cpu.read_er(*r) as i32 + *d as i32) as u32;
            bus.write_word(addr, val);
        }
        Operand::RegIndirectDisp24(r, d) => {
            let addr = cpu.read_er(*r).wrapping_add(*d);
            bus.write_word(addr, val);
        }
        Operand::PreDec(r) => {
            let addr = cpu.read_er(*r) - 2;
            cpu.write_er(*r, addr);
            bus.write_word(addr, val);
        }
        Operand::Abs16(a) => {
            let addr = *a as i16 as i32 as u32 & 0x00FF_FFFF;
            bus.write_word(addr, val);
        }
        Operand::Abs24(a) => bus.write_word(*a, val),
        _ => log::warn!("Unhandled word write operand: {:?}", op),
    }
}

pub fn read_operand_l(cpu: &mut Cpu, bus: &mut MemoryBus, op: &Operand) -> u32 {
    match op {
        Operand::Reg32(r) => cpu.read_er(*r),
        Operand::Imm32(v) => *v,
        Operand::RegIndirect(r) => bus.read_long(cpu.read_er(*r)),
        Operand::RegIndirectDisp16(r, d) => {
            let addr = (cpu.read_er(*r) as i32 + *d as i32) as u32;
            bus.read_long(addr)
        }
        Operand::RegIndirectDisp24(r, d) => {
            let addr = cpu.read_er(*r).wrapping_add(*d);
            bus.read_long(addr)
        }
        Operand::PostInc(r) => {
            let addr = cpu.read_er(*r);
            let val = bus.read_long(addr);
            cpu.write_er(*r, addr + 4); // Post-increment by 4 for long
            val
        }
        Operand::Abs16(a) => {
            let addr = *a as i16 as i32 as u32 & 0x00FF_FFFF;
            bus.read_long(addr)
        }
        Operand::Abs24(a) => bus.read_long(*a),
        _ => {
            log::warn!("Unhandled long read operand: {:?}", op);
            0
        }
    }
}

pub fn write_operand_l(cpu: &mut Cpu, bus: &mut MemoryBus, op: &Operand, val: u32) {
    match op {
        Operand::Reg32(r) => cpu.write_er(*r, val),
        Operand::RegIndirect(r) => bus.write_long(cpu.read_er(*r), val),
        Operand::RegIndirectDisp16(r, d) => {
            let addr = (cpu.read_er(*r) as i32 + *d as i32) as u32;
            bus.write_long(addr, val);
        }
        Operand::RegIndirectDisp24(r, d) => {
            let addr = cpu.read_er(*r).wrapping_add(*d);
            bus.write_long(addr, val);
        }
        Operand::PreDec(r) => {
            let addr = cpu.read_er(*r) - 4;
            cpu.write_er(*r, addr);
            bus.write_long(addr, val);
        }
        Operand::Abs16(a) => {
            let addr = *a as i16 as i32 as u32 & 0x00FF_FFFF;
            bus.write_long(addr, val);
        }
        Operand::Abs24(a) => bus.write_long(*a, val),
        _ => log::warn!("Unhandled long write operand: {:?}", op),
    }
}

/// Read byte from register-only operand (for ADDX/SUBX which only use registers/immediates).
fn read_operand_b_direct(cpu: &Cpu, op: &Operand) -> u8 {
    match op {
        Operand::Reg8(r) => cpu.read_r8(*r),
        Operand::Imm8(v) => *v,
        _ => 0,
    }
}

fn write_operand_b_direct(cpu: &mut Cpu, op: &Operand, val: u8) {
    if let Operand::Reg8(r) = op {
        cpu.write_r8(*r, val);
    }
}

/// Extract register number from a register operand.
fn extract_reg(op: &Operand) -> u8 {
    match op {
        Operand::Reg8(r) | Operand::Reg16(r) | Operand::Reg32(r) => *r,
        _ => 0,
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
        assert_eq!(cpu.sp(), 0x410000 - 6);
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
}
