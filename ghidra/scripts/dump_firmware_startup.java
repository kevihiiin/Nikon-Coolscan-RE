// Dump disassembly of firmware startup code and interrupt trampolines
// @category Analysis

import ghidra.app.script.GhidraScript;
import ghidra.program.model.listing.*;
import ghidra.program.model.address.*;
import ghidra.program.model.mem.*;

public class dump_firmware_startup extends GhidraScript {

    @Override
    public void run() throws Exception {
        Listing listing = currentProgram.getListing();
        AddressSpace space = currentProgram.getAddressFactory().getDefaultAddressSpace();
        Memory mem = currentProgram.getMemory();

        println("=== FIRMWARE STARTUP ANALYSIS ===");
        println("");

        // Dump vector table (first 256 bytes = 64 vectors)
        println("=== VECTOR TABLE (0x000-0x0FF) ===");
        for (int i = 0; i < 64; i++) {
            Address addr = space.getAddress(i * 4);
            try {
                long vec = (mem.getByte(addr) & 0xFF);
                vec = (vec << 8) | (mem.getByte(addr.add(1)) & 0xFF);
                vec = (vec << 8) | (mem.getByte(addr.add(2)) & 0xFF);
                vec = (vec << 8) | (mem.getByte(addr.add(3)) & 0xFF);
                if (vec != 0x00000186L) {
                    String purpose = getVectorPurpose(i);
                    println(String.format("Vector %2d (0x%03X): 0x%08X  %s", i, i*4, vec, purpose));
                }
            } catch (Exception e) {
                println(String.format("Vector %2d: read error", i));
            }
        }

        println("");
        println("=== STARTUP CODE (0x100-0x18F) ===");
        dumpDisassembly(space, 0x100, 0x190);

        println("");
        println("=== MAIN FIRMWARE ENTRY (0x020334-0x020500) ===");
        dumpDisassembly(space, 0x020334, 0x020500);

        println("");
        println("=== TRAMPOLINE SOURCE DATA (flash) ===");
        println("Bytes at 0x6B0-0x76F:");
        dumpHex(mem, space, 0x6B0, 0x770);

        println("");
        println("=== CODE AROUND 0x020300 ===");
        dumpDisassembly(space, 0x020300, 0x020340);

        // Flash usage map
        println("");
        println("=== FLASH USAGE MAP (4KB blocks) ===");
        for (long block = 0; block < 0x80000; block += 0x1000) {
            Address blockAddr = space.getAddress(block);
            boolean allFF = true;
            boolean allZero = true;
            try {
                for (int j = 0; j < 0x1000; j += 4) {
                    int b = mem.getByte(blockAddr.add(j)) & 0xFF;
                    if (b != 0xFF) allFF = false;
                    if (b != 0x00) allZero = false;
                    if (!allFF && !allZero) break;
                }
                String status = allFF ? "ERASED" : (allZero ? "ZEROED" : "CODE/DATA");
                println(String.format("0x%05X-0x%05X: %s", block, block + 0xFFF, status));
            } catch (Exception e) {
                println(String.format("0x%05X-0x%05X: READ ERROR", block, block + 0xFFF));
            }
        }

        // Search for RTE instructions (end of interrupt handlers)
        println("");
        println("=== RTE INSTRUCTIONS (0x56 0x70) ===");
        int rteCount = 0;
        for (long offset = 0x100; offset < 0x80000 && rteCount < 50; offset += 2) {
            try {
                int b0 = mem.getByte(space.getAddress(offset)) & 0xFF;
                int b1 = mem.getByte(space.getAddress(offset + 1)) & 0xFF;
                if (b0 == 0x56 && b1 == 0x70) {
                    println(String.format("RTE at 0x%06X", offset));
                    rteCount++;
                }
            } catch (Exception e) {}
        }

        // Search for known SCSI strings
        println("");
        println("=== STRING SEARCH ===");
        searchString(mem, space, "INQUIRY");
        searchString(mem, space, "LS-50");
        searchString(mem, space, "LS-5000");
        searchString(mem, space, "NIKON");
        searchString(mem, space, "Nikon");

        // Dump code near INQUIRY strings
        println("");
        println("=== CODE AT 0x020000-0x020040 ===");
        dumpDisassembly(space, 0x020000, 0x020040);

        // Look at the area right after flash base (0x20000)
        println("");
        println("=== CODE AT 0x20100-0x20200 ===");
        dumpDisassembly(space, 0x20100, 0x20200);
    }

    private void dumpDisassembly(AddressSpace space, long start, long end) {
        Listing listing = currentProgram.getListing();
        Memory mem = currentProgram.getMemory();
        Address addr = space.getAddress(start);
        Address endAddr = space.getAddress(end);
        int count = 0;
        while (addr != null && addr.compareTo(endAddr) < 0 && count < 200) {
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
                    println(String.format("  0x%06X: [data] %s (len=%d)", addr.getOffset(),
                        data.toString(), data.getLength()));
                    addr = data.getMaxAddress().add(1);
                } else {
                    try {
                        int b = mem.getByte(addr) & 0xFF;
                        println(String.format("  0x%06X: [undef] 0x%02X", addr.getOffset(), b));
                    } catch (Exception e) {
                        println(String.format("  0x%06X: [unmapped]", addr.getOffset()));
                    }
                    addr = addr.add(1);
                }
                count++;
            }
        }
    }

    private void dumpHex(Memory mem, AddressSpace space, long start, long end) {
        StringBuilder sb = new StringBuilder();
        for (long i = start; i < end; i += 16) {
            sb.setLength(0);
            sb.append(String.format("  0x%06X: ", i));
            StringBuilder ascii = new StringBuilder();
            for (int j = 0; j < 16 && (i + j) < end; j++) {
                try {
                    int b = mem.getByte(space.getAddress(i + j)) & 0xFF;
                    sb.append(String.format("%02X ", b));
                    ascii.append(b >= 0x20 && b < 0x7F ? (char)b : '.');
                } catch (Exception e) {
                    sb.append("?? ");
                    ascii.append('?');
                }
            }
            sb.append(" ").append(ascii.toString());
            println(sb.toString());
        }
    }

    private void searchString(Memory mem, AddressSpace space, String target) {
        byte[] bytes = target.getBytes();
        for (long offset = 0; offset < 0x80000 - bytes.length; offset++) {
            boolean match = true;
            try {
                for (int j = 0; j < bytes.length; j++) {
                    int b = mem.getByte(space.getAddress(offset + j)) & 0xFF;
                    if (b != (bytes[j] & 0xFF)) {
                        match = false;
                        break;
                    }
                }
                if (match) {
                    // Read surrounding context
                    StringBuilder ctx = new StringBuilder();
                    int ctxStart = (int)Math.max(0, offset - 2);
                    int ctxEnd = (int)Math.min(0x80000, offset + bytes.length + 32);
                    for (int j = ctxStart; j < ctxEnd; j++) {
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
        for (byte b : bytes) {
            sb.append(String.format("%02X ", b & 0xFF));
        }
        return sb.toString().trim();
    }

    private String getVectorPurpose(int vecNum) {
        switch (vecNum) {
            case 0: return "Reset";
            case 7: return "NMI";
            case 8: return "IRQ0";
            case 13: return "IRQ5";
            case 14: return "ICIA (ITU0 capture A)";
            case 15: return "ICIB (ITU0 capture B)";
            case 16: return "ICIC/D (ITU0 cap C/D)";
            case 20: return "IMIA1 (ITU1 compare A)";
            case 24: return "IMIA2 (ITU2 compare A)";
            case 25: return "IMIB2 (ITU2 compare B)";
            case 28: return "IMIA3 (ITU3 compare A)";
            case 29: return "IMIB3 (ITU3 compare B)";
            case 32: return "IMIA4 (ITU4 compare A)";
            case 36: return "DEND0A (DMA ch0 A)";
            case 37: return "DEND0B (DMA ch0 B)";
            case 44: return "ERI0 (SCI0 rx error)";
            case 45: return "RXI0 (SCI0 receive)";
            case 46: return "TXI0 (SCI0 transmit)";
            case 60: return "Refresh compare match";
            default: return "";
        }
    }
}
