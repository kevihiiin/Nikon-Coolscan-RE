// Dump ISP1581 USB controller interface code and CDB reception path
// @category Analysis

import ghidra.app.script.GhidraScript;
import ghidra.program.model.listing.*;
import ghidra.program.model.address.*;
import ghidra.program.model.mem.*;

public class dump_isp1581_usb extends GhidraScript {

    @Override
    public void run() throws Exception {
        AddressSpace space = currentProgram.getAddressFactory().getDefaultAddressSpace();
        Memory mem = currentProgram.getMemory();

        // 1. ISP1581 initialization - the function called from main init at 0x015EAA
        println("=== ISP1581 INIT FUNCTION (0x015EA0-0x016000) ===");
        dumpDisassembly(space, 0x015EA0, 0x016000);

        // 2. Core ISP1581 register access code - Mode register area
        println("\n=== ISP1581 MODE SETUP (0x0139A0-0x013AE0) ===");
        dumpDisassembly(space, 0x0139A0, 0x013AE0);

        // 3. ISP1581 DMA setup and transfer code
        println("\n=== ISP1581 DMA CODE (0x013C40-0x013D40) ===");
        dumpDisassembly(space, 0x013C40, 0x013D40);

        // 4. ISP1581 DMA continued
        println("\n=== ISP1581 DMA CODE 2 (0x013F40-0x014080) ===");
        dumpDisassembly(space, 0x013F40, 0x014080);

        // 5. ISP1581 endpoint data read/write (0x600020/0x60001C)
        println("\n=== ISP1581 ENDPOINT IO (0x012200-0x012400) ===");
        dumpDisassembly(space, 0x012200, 0x012400);

        // 6. ISP1581 interrupt handler entry (IRQ0 at 0x10876)
        println("\n=== IRQ0 HANDLER (0x010870-0x010900) ===");
        dumpDisassembly(space, 0x010870, 0x010900);

        // 7. The IRQ5 trampoline target is unknown - search for writes to 0xFFFD3C
        // Search for ISP1581 interrupt configuration (0x600008/0x600010)
        println("\n=== ISP1581 INTERRUPT CONFIG (0x014880-0x014980) ===");
        dumpDisassembly(space, 0x014880, 0x014980);

        // 8. Code around 0x14D4A (Timer0 capture C/D handler - may relate to USB timing)
        println("\n=== TIMER0 CAP C/D HANDLER (0x014D40-0x014F00) ===");
        dumpDisassembly(space, 0x014D40, 0x014F00);

        // 9. Key function 0x1374A called from dispatch (permission check?)
        println("\n=== FUNCTION 0x1374A (0x013740-0x013800) ===");
        dumpDisassembly(space, 0x013740, 0x013800);

        // 10. USB endpoint configuration - look for endpoint setup patterns
        println("\n=== ISP1581 ENDPOINT SETUP (0x014E00-0x015000) ===");
        dumpDisassembly(space, 0x014E00, 0x015000);

        // 11. ISP1581 DMA count register area
        println("\n=== ISP1581 DMA COUNT (0x015100-0x015220) ===");
        dumpDisassembly(space, 0x015100, 0x015220);

        // 12. Command descriptor table at 0x49834 (10-byte entries)
        println("\n=== COMMAND DESCRIPTOR TABLE (0x049834-0x049920) ===");
        dumpCommandTable(mem, space, 0x049834, 0x049920);

        // 13. Command lookup table at 0x49910
        println("\n=== COMMAND LOOKUP TABLE (0x049910-0x049A80) ===");
        dumpLookupTable(mem, space, 0x049910, 0x049A80);

        // 14. Search for CDB buffer access patterns
        // The CDB is likely stored in RAM starting at some fixed address
        // Look for code that reads byte[0] of a buffer and dispatches
        println("\n=== SCSI CDB PROCESSING CHAIN (0x020690-0x020800) ===");
        dumpDisassembly(space, 0x020690, 0x020800);

        // 15. Code before the main dispatch entry
        println("\n=== PRE-DISPATCH CODE (0x020800-0x020B00) ===");
        dumpDisassembly(space, 0x020800, 0x020B00);

        // 16. The jsr @0x109E2 function (called before dispatch)
        println("\n=== FUNCTION 0x109E2 (0x0109E2-0x010A18) ===");
        dumpDisassembly(space, 0x0109E2, 0x010A18);

        // 17. Main loop area - what calls the SCSI dispatch?
        println("\n=== MAIN LOOP AREA (0x020600-0x020700) ===");
        dumpDisassembly(space, 0x020600, 0x020700);

        // 18. Search for writes to 0x40077C (where internal cmd code is stored)
        println("\n=== SEARCHING FOR WRITES TO 0x40077C ===");
        searchForWritesTo(mem, space, 0x40077C);

        // 19. Check USB code area more broadly for CDB parsing
        println("\n=== ISP1581 CODE AREA (0x012400-0x012600) ===");
        dumpDisassembly(space, 0x012400, 0x012600);

        // 20. Extended USB code
        println("\n=== ISP1581 EXTENDED (0x012600-0x012800) ===");
        dumpDisassembly(space, 0x012600, 0x012800);
    }

    private void dumpDisassembly(AddressSpace space, long start, long end) {
        Listing listing = currentProgram.getListing();
        Address addr = space.getAddress(start);
        Address endAddr = space.getAddress(end);
        int count = 0;
        while (addr != null && addr.compareTo(endAddr) < 0 && count < 500) {
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

    private void dumpCommandTable(Memory mem, AddressSpace space, long start, long end) {
        // Command descriptor table: 10-byte entries
        // [0] = byte (SCSI opcode?), [1-2] = word (flags?), [3] = byte, [4-7] = dword (handler ptr), [8-9] = word
        for (long addr = start; addr < end; addr += 10) {
            try {
                int b0 = mem.getByte(space.getAddress(addr)) & 0xFF;
                int w1 = ((mem.getByte(space.getAddress(addr + 1)) & 0xFF) << 8) |
                          (mem.getByte(space.getAddress(addr + 2)) & 0xFF);
                int b3 = mem.getByte(space.getAddress(addr + 3)) & 0xFF;
                long ptr = ((long)(mem.getByte(space.getAddress(addr + 4)) & 0xFF) << 24) |
                           ((long)(mem.getByte(space.getAddress(addr + 5)) & 0xFF) << 16) |
                           ((long)(mem.getByte(space.getAddress(addr + 6)) & 0xFF) << 8) |
                           (mem.getByte(space.getAddress(addr + 7)) & 0xFF);
                int w8 = ((mem.getByte(space.getAddress(addr + 8)) & 0xFF) << 8) |
                          (mem.getByte(space.getAddress(addr + 9)) & 0xFF);
                if (ptr == 0) {
                    println(String.format("  0x%06X: END (null ptr)", addr));
                    break;
                }
                println(String.format("  0x%06X: opcode=0x%02X flags=0x%04X b3=0x%02X handler=0x%06X w8=0x%04X",
                    addr, b0, w1, b3, ptr, w8));
            } catch (Exception e) {
                println(String.format("  0x%06X: READ ERROR", addr));
            }
        }
    }

    private void dumpLookupTable(Memory mem, AddressSpace space, long start, long end) {
        // Lookup table: 4-byte entries (cmd_id:16, handler_idx:16)
        for (long addr = start; addr < end; addr += 4) {
            try {
                int cmdId = ((mem.getByte(space.getAddress(addr)) & 0xFF) << 8) |
                             (mem.getByte(space.getAddress(addr + 1)) & 0xFF);
                int handlerIdx = ((mem.getByte(space.getAddress(addr + 2)) & 0xFF) << 8) |
                                  (mem.getByte(space.getAddress(addr + 3)) & 0xFF);
                if (cmdId == 0 && handlerIdx == 0) {
                    println(String.format("  0x%06X: END (0x0000, 0x0000)", addr));
                    break;
                }
                println(String.format("  0x%06X: cmd=0x%04X -> handler_idx=0x%04X",
                    addr, cmdId, handlerIdx));
            } catch (Exception e) {
                println(String.format("  0x%06X: READ ERROR", addr));
            }
        }
    }

    private void searchForWritesTo(Memory mem, AddressSpace space, long targetAddr) {
        // Search for mov.w/mov.b instructions writing to 0x40077C
        // Pattern: mov.w r0, @0x0040077C → 6B 80 00 40 07 7C
        // Pattern: mov.b r0l, @0x0040077C → 6A 88 00 40 07 7C
        byte[] pattern1 = {(byte)0x6B, (byte)0x80, 0x00, 0x40, 0x07, 0x7C};
        byte[] pattern2 = {(byte)0x6A, (byte)0x88, 0x00, 0x40, 0x07, 0x7C};

        // Search in code areas
        long[][] regions = {{0x10000, 0x18000}, {0x20000, 0x53000}, {0x70000, 0x80000}};
        for (long[] region : regions) {
            for (long addr = region[0]; addr < region[1] - 6; addr++) {
                try {
                    boolean match1 = true, match2 = true;
                    for (int i = 0; i < 6; i++) {
                        byte b = mem.getByte(space.getAddress(addr + i));
                        if (b != pattern1[i]) match1 = false;
                        if (b != pattern2[i]) match2 = false;
                    }
                    if (match1) {
                        // Also check other register variants: 6B 8x for different source registers
                        println(String.format("  FOUND mov.w write to 0x%06X at 0x%06X", targetAddr, addr));
                        // Dump context
                        dumpDisassembly(space, addr - 16, addr + 16);
                    }
                    if (match2) {
                        println(String.format("  FOUND mov.b write to 0x%06X at 0x%06X", targetAddr, addr));
                        dumpDisassembly(space, addr - 16, addr + 16);
                    }
                } catch (Exception e) {}
            }
        }

        // Also search for any mov instruction with 0x40077C in operand (more general)
        // Pattern: xx xx 00 40 07 7C (6 bytes with 00 40 07 7C at end)
        byte[] addrBytes = {0x00, 0x40, 0x07, 0x7C};
        for (long[] region : regions) {
            for (long addr = region[0]; addr < region[1] - 6; addr++) {
                try {
                    boolean match = true;
                    for (int i = 0; i < 4; i++) {
                        if (mem.getByte(space.getAddress(addr + 2 + i)) != addrBytes[i]) {
                            match = false;
                            break;
                        }
                    }
                    if (match) {
                        int opcode = mem.getByte(space.getAddress(addr)) & 0xFF;
                        int opcode2 = mem.getByte(space.getAddress(addr + 1)) & 0xFF;
                        // Filter to actual mov instructions (6A, 6B, or 78 prefixed)
                        if (opcode == 0x6A || opcode == 0x6B || opcode == 0x78) {
                            println(String.format("  REFERENCE to 0x40077C at 0x%06X [%02X %02X ...]",
                                addr, opcode, opcode2));
                        }
                    }
                } catch (Exception e) {}
            }
        }
    }

    private String bytesToHex(byte[] bytes) {
        StringBuilder sb = new StringBuilder();
        for (byte b : bytes) { sb.append(String.format("%02X ", b & 0xFF)); }
        return sb.toString().trim();
    }
}
