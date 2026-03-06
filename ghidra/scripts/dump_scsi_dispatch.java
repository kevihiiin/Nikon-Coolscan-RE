// Dump SCSI command dispatch code and INQUIRY handler
// @category Analysis

import ghidra.app.script.GhidraScript;
import ghidra.program.model.listing.*;
import ghidra.program.model.address.*;
import ghidra.program.model.mem.*;

public class dump_scsi_dispatch extends GhidraScript {

    @Override
    public void run() throws Exception {
        AddressSpace space = currentProgram.getAddressFactory().getDefaultAddressSpace();
        Memory mem = currentProgram.getMemory();

        // 1. SCSI dispatch area
        println("=== SCSI DISPATCH (0x020C00-0x020E00) ===");
        dumpDisassembly(space, 0x020C00, 0x020E00);

        // 2. Wider context — what calls the dispatch?
        println("");
        println("=== DISPATCH CONTEXT (0x020B00-0x020C00) ===");
        dumpDisassembly(space, 0x020B00, 0x020C00);

        // 3. INQUIRY handler area (near string refs)
        // Strings at 0x16674 (LS-5000) and 0x170D6 (LS-50 ED)
        println("");
        println("=== INQUIRY STRING AREA (0x16640-0x16720) ===");
        dumpHex(mem, space, 0x16640, 0x16720);

        println("");
        println("=== INQUIRY STRING AREA 2 (0x170C0-0x17150) ===");
        dumpHex(mem, space, 0x170C0, 0x17150);

        // 4. Adapter type table at 0x049E31
        println("");
        println("=== ADAPTER/STRING TABLE (0x049E00-0x049F80) ===");
        dumpHex(mem, space, 0x049E00, 0x049F80);

        // 5. ISP1581 USB code — main area is at 0x12200-0x15200
        println("");
        println("=== ISP1581 INIT CODE (0x0139C0-0x013A40) ===");
        dumpDisassembly(space, 0x0139C0, 0x013A40);

        // 6. The function at 0x015EAA (called from main init)
        println("");
        println("=== CALLED FROM MAIN INIT (0x015EA0-0x015F60) ===");
        dumpDisassembly(space, 0x015EA0, 0x015F60);

        // 7. Dump the complete trampoline mapping
        println("");
        println("=== TRAMPOLINE TARGET MAP ===");
        // Read inline data from 0x204DA, 0x204F4, 0x2050E, etc.
        long[] trampolineDataAddrs = {0x204DA, 0x204F4, 0x2050E, 0x20528, 0x20542,
                                       0x2055C, 0x20576, 0x20590, 0x205AA, 0x205C4, 0x205DE};
        long[] trampolineRAMAddrs = {0xFFFD10, 0xFFFD14, 0xFFFD18, 0xFFFD1C, 0xFFFD20,
                                      0xFFFD24, 0xFFFD28, 0xFFFD2C, 0xFFFD30, 0xFFFD34, 0xFFFD38};
        int[] vectorNums = {8, 15, 16, 32, 36, 40, 45, 47, 49, 60, 19};

        for (int i = 0; i < trampolineDataAddrs.length; i++) {
            long src = trampolineDataAddrs[i];
            try {
                int b0 = mem.getByte(space.getAddress(src)) & 0xFF;
                int b1 = mem.getByte(space.getAddress(src + 1)) & 0xFF;
                int b2 = mem.getByte(space.getAddress(src + 2)) & 0xFF;
                int b3 = mem.getByte(space.getAddress(src + 3)) & 0xFF;
                long target = (b1 << 16) | (b2 << 8) | b3;
                String instr = String.format("JMP @0x%06X", target);
                if (b0 != 0x5A) instr = String.format("?? [%02X %02X %02X %02X]", b0, b1, b2, b3);
                String purpose = getVectorPurpose(vectorNums[i]);
                println(String.format("  Vec %2d → RAM 0x%06X → %s  %s",
                    vectorNums[i], trampolineRAMAddrs[i], instr, purpose));
            } catch (Exception e) {
                println(String.format("  Vec %2d → RAM 0x%06X → READ ERROR", vectorNums[i], trampolineRAMAddrs[i]));
            }
        }

        // Check if there are more trampolines (for 0xFFFD3C)
        // Vector 13 (IRQ5) → 0xFFFD3C
        println("");
        println("=== TRAMPOLINE CONTINUATION (0x205E0-0x20640) ===");
        dumpDisassembly(space, 0x205E0, 0x20640);

        // 8. Second dispatch at 0x2ECE8 area
        println("");
        println("=== SECONDARY SCSI DISPATCH (0x2EC00-0x2ED40) ===");
        dumpDisassembly(space, 0x2EC00, 0x2ED40);

        // 9. Third cluster 0x2F000-0x2F400
        println("");
        println("=== THIRD SCSI CLUSTER (0x2F000-0x2F400) ===");
        dumpDisassembly(space, 0x2F000, 0x2F400);
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
                    addr = data.getMaxAddress().add(1);
                    count++;
                } else {
                    addr = addr.add(1);
                    count++;
                }
            }
        }
    }

    private void dumpHex(Memory mem, AddressSpace space, long start, long end) {
        for (long i = start; i < end; i += 16) {
            StringBuilder hex = new StringBuilder();
            StringBuilder ascii = new StringBuilder();
            hex.append(String.format("  0x%06X: ", i));
            for (int j = 0; j < 16 && (i + j) < end; j++) {
                try {
                    int b = mem.getByte(space.getAddress(i + j)) & 0xFF;
                    hex.append(String.format("%02X ", b));
                    ascii.append(b >= 0x20 && b < 0x7F ? (char)b : '.');
                } catch (Exception e) { hex.append("?? "); ascii.append('?'); }
            }
            println(hex.toString() + " " + ascii.toString());
        }
    }

    private String bytesToHex(byte[] bytes) {
        StringBuilder sb = new StringBuilder();
        for (byte b : bytes) { sb.append(String.format("%02X ", b & 0xFF)); }
        return sb.toString().trim();
    }

    private String getVectorPurpose(int vecNum) {
        switch (vecNum) {
            case 8: return "IRQ0 (external)";
            case 13: return "IRQ5";
            case 15: return "ICIB (ITU0 capture B)";
            case 16: return "ICIC/D (ITU0 cap C/D)";
            case 17: return "OCID (ITU0 overflow)";
            case 19: return "Reserved ITU0";
            case 32: return "IMIA4 (ITU4 compare A)";
            case 36: return "DEND0A (DMA ch0 end)";
            case 40: return "DEND1A? / Reserved";
            case 45: return "RXI0 (SCI0 receive)";
            case 47: return "TXI0 (SCI0 transmit)";
            case 49: return "RXI1 (SCI1 receive)";
            case 60: return "Refresh compare match";
            default: return "";
        }
    }
}
