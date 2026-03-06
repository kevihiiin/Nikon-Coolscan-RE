// Dump interrupt handler code and search for SCSI dispatch
// @category Analysis

import ghidra.app.script.GhidraScript;
import ghidra.program.model.listing.*;
import ghidra.program.model.address.*;
import ghidra.program.model.mem.*;

public class dump_firmware_handlers extends GhidraScript {

    @Override
    public void run() throws Exception {
        Listing listing = currentProgram.getListing();
        AddressSpace space = currentProgram.getAddressFactory().getDefaultAddressSpace();
        Memory mem = currentProgram.getMemory();

        // 1. Decode inline trampoline data at 0x204C4+
        println("=== TRAMPOLINE INSTALLATION CODE (0x204C4-0x20620) ===");
        dumpDisassembly(space, 0x204C4, 0x20620);

        // 2. Dump each interrupt handler entry
        // IRQ0 handler jumps to 0x010876
        println("");
        println("=== IRQ0 HANDLER (0x010876) — likely USB/ISP1581 ===");
        dumpDisassembly(space, 0x010800, 0x010900);

        // More handlers based on RTE locations
        println("");
        println("=== HANDLER REGION 0x10800-0x10C00 (all handlers with RTE) ===");
        dumpDisassembly(space, 0x010800, 0x010C00);

        // 3. Search for SCSI opcode comparisons
        // Looking for cmp.b #0x12 (INQUIRY), cmp.b #0x24 (SET WINDOW), etc.
        println("");
        println("=== SCSI OPCODE PATTERN SEARCH ===");
        // Search for CMP.B #imm,R0L where imm is a known SCSI opcode
        // CMP.B #xx,R0L = A8 xx (2 bytes)
        // Known opcodes: 0x00(TUR), 0x03(REQ SENSE), 0x12(INQUIRY), 0x15(MODE SELECT),
        //   0x1A(MODE SENSE), 0x1B(SCAN), 0x24(SET WINDOW), 0x25(GET WINDOW),
        //   0x28(READ), 0x2A(WRITE), 0x3B(WRITE BUFFER), 0x3C(READ BUFFER)
        //   0xC0, 0xC1, 0xD0, 0xE0, 0xE1 (vendor)
        int[] opcodes = {0x00, 0x03, 0x06, 0x12, 0x15, 0x16, 0x1A, 0x1B,
                         0x24, 0x25, 0x28, 0x2A, 0x3B, 0x3C,
                         0xC0, 0xC1, 0xD0, 0xE0, 0xE1};

        for (int opcode : opcodes) {
            // Search for A8 xx (cmp.b #xx, r0l) but also other register variants
            for (long offset = 0x10000; offset < 0x53000; offset += 2) {
                try {
                    int b0 = mem.getByte(space.getAddress(offset)) & 0xFF;
                    int b1 = mem.getByte(space.getAddress(offset + 1)) & 0xFF;
                    // CMP.B #imm,Rn: encoding A0+n imm
                    if (b0 >= 0xA0 && b0 <= 0xAF && b1 == opcode) {
                        // Check if followed by a branch instruction (BEQ/BNE)
                        int b2 = mem.getByte(space.getAddress(offset + 2)) & 0xFF;
                        if (b2 == 0x47 || b2 == 0x46 || // BEQ/BNE short
                            b2 == 0x58) { // Branch with 16-bit displacement
                            String reg = "r" + (b0 & 0x0F) + ((b0 & 0x08) != 0 ? "l" : "h");
                            println(String.format("  CMP.B #0x%02X,%s at 0x%06X (opcode %s) + branch",
                                opcode, reg, offset, getOpcodeName(opcode)));
                        }
                    }
                } catch (Exception e) {}
            }
        }

        // 4. Search for jump tables (common SCSI dispatch pattern)
        // Look for computed jumps: JMP @(disp, ERn) or JMP @ERn
        println("");
        println("=== COMPUTED JUMPS (potential dispatch tables) ===");
        for (long offset = 0x10000; offset < 0x53000; offset += 2) {
            try {
                int b0 = mem.getByte(space.getAddress(offset)) & 0xFF;
                int b1 = mem.getByte(space.getAddress(offset + 1)) & 0xFF;
                // JMP @ERn = 59 n0
                if (b0 == 0x59 && (b1 & 0x0F) == 0) {
                    int reg = (b1 >> 4) & 0x07;
                    println(String.format("  JMP @ER%d at 0x%06X", reg, offset));
                }
            } catch (Exception e) {}
        }

        // 5. Look at code near INQUIRY string references
        println("");
        println("=== CODE NEAR INQUIRY STRINGS ===");
        // INQUIRY string "Nikon" at 0x16674 and 0x170D6
        // Look for code that references these addresses
        // The INQUIRY handler would load a pointer to the string
        // Search for MOV.L #0x016674 or MOV.L #0x0170D6 patterns
        // MOV.L #imm,ERn = 7A 0n + 4 bytes immediate

        // Broader approach: search for the string addresses as 3-byte values in code
        searchAddress(mem, space, 0x016674, "LS-5000 INQUIRY string");
        searchAddress(mem, space, 0x0170D6, "LS-50 ED INQUIRY string");
        searchAddress(mem, space, 0x049E31, "LS-50 ED INQUIRY string (2)");

        // 6. ISP1581 access patterns — search for 0x600000 region references
        println("");
        println("=== ISP1581 USB REGISTER ACCESSES ===");
        // Search for references to 0x600000-0x6000FF
        searchAddress(mem, space, 0x600000, "ISP1581 base");
        // Look for MOV instructions that target 0x6000xx
        for (long offset = 0x10000; offset < 0x53000; offset += 2) {
            try {
                int b0 = mem.getByte(space.getAddress(offset)) & 0xFF;
                int b1 = mem.getByte(space.getAddress(offset + 1)) & 0xFF;
                // MOV.L #imm32, ERn = 7A 0n xx xx xx xx
                if (b0 == 0x7A && (b1 & 0xF0) == 0x00) {
                    long imm = 0;
                    imm = (mem.getByte(space.getAddress(offset + 2)) & 0xFF);
                    imm = (imm << 8) | (mem.getByte(space.getAddress(offset + 3)) & 0xFF);
                    imm = (imm << 8) | (mem.getByte(space.getAddress(offset + 4)) & 0xFF);
                    imm = (imm << 8) | (mem.getByte(space.getAddress(offset + 5)) & 0xFF);
                    if (imm >= 0x600000 && imm <= 0x6000FF) {
                        int reg = b1 & 0x07;
                        println(String.format("  MOV.L #0x%06X,ER%d at 0x%06X", imm, reg, offset));
                    }
                }
                // MOV.B @abs:24, Rn = 6A 2x 00 60 00 xx (read from ISP1581)
                // MOV.B Rn, @abs:24 = 6A Ax 00 60 00 xx (write to ISP1581)
                if (b0 == 0x6A) {
                    int b2 = mem.getByte(space.getAddress(offset + 2)) & 0xFF;
                    int b3 = mem.getByte(space.getAddress(offset + 3)) & 0xFF;
                    int b4 = mem.getByte(space.getAddress(offset + 4)) & 0xFF;
                    if (b2 == 0x00 && b3 == 0x60 && b4 == 0x00) {
                        int b5 = mem.getByte(space.getAddress(offset + 5)) & 0xFF;
                        String dir = (b1 & 0x80) != 0 ? "WRITE" : "READ";
                        println(String.format("  %s ISP1581 reg 0x%02X at 0x%06X", dir, b5, offset));
                    }
                }
            } catch (Exception e) {}
        }

        // 7. Dump the I/O init table entries
        println("");
        println("=== I/O INIT TABLE (0x2001C-0x20334) ===");
        for (long offset = 0x2001C; offset < 0x20334; offset += 6) {
            try {
                long addr = 0;
                addr = (mem.getByte(space.getAddress(offset)) & 0xFF);
                addr = (addr << 8) | (mem.getByte(space.getAddress(offset + 1)) & 0xFF);
                addr = (addr << 8) | (mem.getByte(space.getAddress(offset + 2)) & 0xFF);
                addr = (addr << 8) | (mem.getByte(space.getAddress(offset + 3)) & 0xFF);
                int val = (mem.getByte(space.getAddress(offset + 4)) & 0xFF) << 8;
                val |= (mem.getByte(space.getAddress(offset + 5)) & 0xFF);
                String name = getIORegName(addr);
                println(String.format("  [0x%08X] = 0x%02X  %s", addr, val & 0xFF, name));
            } catch (Exception e) {}
        }

        // 8. Code at 0x10334 (alternate firmware entry)
        println("");
        println("=== ALTERNATE FIRMWARE ENTRY (0x10334) ===");
        dumpDisassembly(space, 0x10000, 0x10060);

        // 9. Look at adapter-related strings
        println("");
        println("=== ADAPTER STRINGS ===");
        searchString(mem, space, "Mount");
        searchString(mem, space, "Strip");
        searchString(mem, space, "Roll");
    }

    private void dumpDisassembly(AddressSpace space, long start, long end) {
        Listing listing = currentProgram.getListing();
        Memory mem = currentProgram.getMemory();
        Address addr = space.getAddress(start);
        Address endAddr = space.getAddress(end);
        int count = 0;
        while (addr != null && addr.compareTo(endAddr) < 0 && count < 300) {
            Instruction instr = listing.getInstructionAt(addr);
            if (instr != null) {
                String hexBytes = "";
                try { hexBytes = bytesToHex(instr.getBytes()); } catch (Exception ex) {}
                println(String.format("  0x%06X: %-30s  [%s]", addr.getOffset(),
                    instr.toString(), hexBytes));
                addr = instr.getMaxAddress().add(1);
                count++;
            } else {
                Data data = listing.getDataAt(addr);
                if (data != null && data.getLength() > 0) {
                    println(String.format("  0x%06X: [data] %s", addr.getOffset(), data.toString()));
                    addr = data.getMaxAddress().add(1);
                } else {
                    try {
                        int b = mem.getByte(addr) & 0xFF;
                        // Skip printing individual undefined bytes, just note the start
                        if (count == 0 || (count > 0)) {
                            println(String.format("  0x%06X: [undef] 0x%02X", addr.getOffset(), b));
                        }
                    } catch (Exception e) {
                        break; // unmapped
                    }
                    addr = addr.add(1);
                }
                count++;
            }
        }
    }

    private void searchAddress(Memory mem, AddressSpace space, long targetAddr, String desc) {
        // Search for MOV.L #targetAddr, ERn (7A 0n + big-endian addr)
        byte b0 = (byte)((targetAddr >> 24) & 0xFF);
        byte b1 = (byte)((targetAddr >> 16) & 0xFF);
        byte b2 = (byte)((targetAddr >> 8) & 0xFF);
        byte b3 = (byte)(targetAddr & 0xFF);

        for (long offset = 0x10000; offset < 0x53000; offset += 2) {
            try {
                // Check for MOV.L #imm, ERn
                int i0 = mem.getByte(space.getAddress(offset)) & 0xFF;
                int i1 = mem.getByte(space.getAddress(offset + 1)) & 0xFF;
                if (i0 == 0x7A && (i1 & 0xF0) == 0x00) {
                    int i2 = mem.getByte(space.getAddress(offset + 2)) & 0xFF;
                    int i3 = mem.getByte(space.getAddress(offset + 3)) & 0xFF;
                    int i4 = mem.getByte(space.getAddress(offset + 4)) & 0xFF;
                    int i5 = mem.getByte(space.getAddress(offset + 5)) & 0xFF;
                    long imm = ((long)i2 << 24) | (i3 << 16) | (i4 << 8) | i5;
                    if (imm == targetAddr) {
                        println(String.format("  REF to 0x%06X (%s) at 0x%06X", targetAddr, desc, offset));
                    }
                }
            } catch (Exception e) {}
        }
    }

    private void searchString(Memory mem, AddressSpace space, String target) {
        byte[] bytes = target.getBytes();
        for (long offset = 0; offset < 0x80000 - bytes.length; offset++) {
            boolean match = true;
            try {
                for (int j = 0; j < bytes.length; j++) {
                    int b = mem.getByte(space.getAddress(offset + j)) & 0xFF;
                    if (b != (bytes[j] & 0xFF)) { match = false; break; }
                }
                if (match) {
                    StringBuilder ctx = new StringBuilder();
                    int ctxEnd = (int)Math.min(0x80000, offset + bytes.length + 40);
                    for (int j = (int)offset; j < ctxEnd; j++) {
                        int b = mem.getByte(space.getAddress(j)) & 0xFF;
                        ctx.append(b >= 0x20 && b < 0x7F ? (char)b : '.');
                    }
                    println(String.format("  \"%s\" at 0x%06X: %s", target, offset, ctx.toString()));
                }
            } catch (Exception e) {}
        }
    }

    private String bytesToHex(byte[] bytes) {
        StringBuilder sb = new StringBuilder();
        for (byte b : bytes) { sb.append(String.format("%02X ", b & 0xFF)); }
        return sb.toString().trim();
    }

    private String getOpcodeName(int opcode) {
        switch (opcode) {
            case 0x00: return "TEST UNIT READY";
            case 0x03: return "REQUEST SENSE";
            case 0x06: return "VENDOR 06";
            case 0x12: return "INQUIRY";
            case 0x15: return "MODE SELECT";
            case 0x16: return "RESERVE";
            case 0x1A: return "MODE SENSE";
            case 0x1B: return "SCAN";
            case 0x24: return "SET WINDOW";
            case 0x25: return "GET WINDOW";
            case 0x28: return "READ";
            case 0x2A: return "WRITE";
            case 0x3B: return "WRITE BUFFER";
            case 0x3C: return "READ BUFFER";
            case 0xC0: return "VENDOR C0";
            case 0xC1: return "VENDOR C1";
            case 0xD0: return "VENDOR D0";
            case 0xE0: return "VENDOR E0";
            case 0xE1: return "VENDOR E1";
            default: return String.format("OPCODE 0x%02X", opcode);
        }
    }

    private String getIORegName(long addr) {
        // H8/3003 I/O registers (0xFFFF00-0xFFFFFF)
        if (addr >= 0xFFFF00) {
            int reg = (int)(addr & 0xFF);
            switch (reg) {
                // Timer (ITU)
                case 0x60: return "TSTR (Timer Start)";
                case 0x61: return "TSNC (Timer Sync)";
                case 0x62: return "TMDR (Timer Mode)";
                case 0x63: return "TFCR (Timer Function Control)";
                case 0x64: return "TCR0 (ITU0 Control)";
                case 0x65: return "TIOR0 (ITU0 I/O)";
                case 0x66: return "TIER0 (ITU0 Interrupt Enable)";
                case 0x67: return "TSR0 (ITU0 Status)";
                case 0x68: return "TCNT0H (ITU0 Counter High)";
                case 0x69: return "TCNT0L (ITU0 Counter Low)";
                // Port B
                case 0xD4: return "P1DDR (Port 1 DDR)";
                case 0xD5: return "P2DDR (Port 2 DDR)";
                case 0xD6: return "P3DDR (Port 3 DDR)";
                case 0xD7: return "P4DDR (Port 4 DDR)";
                case 0xD8: return "P5DDR (Port 5 DDR)";
                case 0xD9: return "P6DDR (Port 6 DDR)";
                // BSC
                case 0xEC: return "P8DDR (Port 8 DDR)";
                case 0xF2: return "ABWCR (Area Bus Width Control)";
                case 0xF3: return "ASTCR (Access State Control)";
                case 0xF4: return "WCR (Wait Control)";
                case 0xF5: return "WCER (Wait Control Enable)";
                case 0xF8: return "BRCR (Bus Release Control)";
                case 0xF9: return "CSCR (Chip Select Control)";
                case 0xA8: return "TCSR_WDT (Watchdog)";
                case 0xA9: return "TCNT_WDT (Watchdog Counter)";
                default: return "";
            }
        }
        if (addr >= 0x200000 && addr < 0x210000) {
            return "ASIC register";
        }
        if (addr >= 0xFFFD00 && addr < 0xFFFF00) {
            return "On-chip RAM";
        }
        return "";
    }
}
