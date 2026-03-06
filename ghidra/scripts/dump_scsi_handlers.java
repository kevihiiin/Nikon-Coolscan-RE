// Dump specific SCSI command handler code for analysis
// @category Analysis

import ghidra.app.script.GhidraScript;
import ghidra.program.model.listing.*;
import ghidra.program.model.address.*;
import ghidra.program.model.mem.*;

public class dump_scsi_handlers extends GhidraScript {

    @Override
    public void run() throws Exception {
        AddressSpace space = currentProgram.getAddressFactory().getDefaultAddressSpace();
        Memory mem = currentProgram.getMemory();

        // 1. INQUIRY handler (0x025E18) - Phase 2 says this returns device identification
        println("=== INQUIRY HANDLER (0x025E18) - opcode 0x12 ===");
        dumpDisassembly(space, 0x025E18, 0x026000);

        // 2. TEST UNIT READY handler (0x0215C2)
        println("\n=== TEST UNIT READY HANDLER (0x0215C2) - opcode 0x00 ===");
        dumpDisassembly(space, 0x0215C2, 0x021700);

        // 3. REQUEST SENSE handler (0x021866)
        println("\n=== REQUEST SENSE HANDLER (0x021866) - opcode 0x03 ===");
        dumpDisassembly(space, 0x021866, 0x021950);

        // 4. D0 Phase Query handler (0x013748) — in shared module
        println("\n=== PHASE QUERY HANDLER (0x013748) - opcode 0xD0 ===");
        dumpDisassembly(space, 0x013748, 0x01374A);
        // The handler at 0x13748 is very short, look at related functions
        println("\n=== PHASE QUERY RELATED (0x013700-0x013750) ===");
        dumpDisassembly(space, 0x013700, 0x013750);

        // 5. MODE SENSE handler (0x021F1C)
        println("\n=== MODE SENSE HANDLER (0x021F1C) - opcode 0x1A ===");
        dumpDisassembly(space, 0x021F1C, 0x022100);

        // 6. SCAN handler (0x0220B8) - initiates scanning
        println("\n=== SCAN HANDLER (0x0220B8) - opcode 0x1B ===");
        dumpDisassembly(space, 0x0220B8, 0x022300);

        // 7. SET WINDOW handler (0x026E38) - configures scan parameters
        println("\n=== SET WINDOW HANDLER (0x026E38) - opcode 0x24 ===");
        dumpDisassembly(space, 0x026E38, 0x027300);

        // 8. READ(10) handler (0x023F10) - transfers scan data
        println("\n=== READ HANDLER (0x023F10) - opcode 0x28 ===");
        dumpDisassembly(space, 0x023F10, 0x024100);

        // 9. Vendor C0 Status handler (0x028AB4)
        println("\n=== VENDOR C0 STATUS HANDLER (0x028AB4) ===");
        dumpDisassembly(space, 0x028AB4, 0x028B10);

        // 10. Vendor C1 Trigger handler (0x028B08)
        println("\n=== VENDOR C1 TRIGGER HANDLER (0x028B08) ===");
        dumpDisassembly(space, 0x028B08, 0x028C00);

        // 11. Vendor E0 Data Out handler (0x028E16)
        println("\n=== VENDOR E0 DATA OUT HANDLER (0x028E16) ===");
        dumpDisassembly(space, 0x028E16, 0x029000);

        // 12. Vendor E1 Data In handler (0x0295EA)
        println("\n=== VENDOR E1 DATA IN HANDLER (0x0295EA) ===");
        dumpDisassembly(space, 0x0295EA, 0x029800);

        // 13. SEND(10) handler (0x025506) - host sends data to device
        println("\n=== SEND HANDLER (0x025506) - opcode 0x2A ===");
        dumpDisassembly(space, 0x025506, 0x025700);

        // 14. CDB buffer structure - dump 0x4007D6 context references
        println("\n=== CDB BUFFER SETUP FUNCTION (0x0137C4) ===");
        dumpDisassembly(space, 0x0137C4, 0x013840);

        // 15. INQUIRY response data (near 0x49E31)
        println("\n=== INQUIRY RESPONSE STRINGS ===");
        dumpHex(mem, space, 0x049E20, 0x049E60);

        // 16. MODE SELECT handler (0x02194A)
        println("\n=== MODE SELECT HANDLER (0x02194A) - opcode 0x15 ===");
        dumpDisassembly(space, 0x02194A, 0x021B00);

        // 17. RECEIVE DIAGNOSTIC handler (0x023856)
        println("\n=== RECEIVE DIAGNOSTIC HANDLER (0x023856) - opcode 0x1C ===");
        dumpDisassembly(space, 0x023856, 0x023A00);

        // 18. Motor control - timer4 compare handler (0x10B76)
        println("\n=== TIMER4 COMPARE HANDLER / MOTOR STEP (0x010B76) ===");
        dumpDisassembly(space, 0x010B76, 0x010C00);

        // 19. Timer0 capture B handler (0x33444) - encoder feedback
        println("\n=== TIMER0 CAPTURE B / ENCODER (0x033444) ===");
        dumpDisassembly(space, 0x033444, 0x033500);

        // 20. Search for GPIO port B/C writes (motor control and adapter detect)
        println("\n=== GPIO PORT WRITES SEARCH ===");
        searchGPIOAccess(mem, space);
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

    private void searchGPIOAccess(Memory mem, AddressSpace space) {
        // Search for port B data register writes (0xFFFFD9)
        // Pattern: mov.b rXl, @0xFFFFD9  → 38 D9 (short form) or 6A Ax 00 FF FF D9
        // Also port C (0xFFFFDA)
        String[] portNames = {"Port B (0xD9)", "Port C (0xDA)", "Port 1 DDR (0xD4)",
                              "Port 4 DDR (0xD7)", "Port 5 (0xDB)"};
        int[] portAddrs = {0xD9, 0xDA, 0xD4, 0xD7, 0xDB};

        long[][] regions = {{0x10000, 0x18000}, {0x20000, 0x53000}, {0x70000, 0x80000}};

        for (int p = 0; p < portAddrs.length; p++) {
            println(String.format("\n  --- %s ---", portNames[p]));
            int portAddr = portAddrs[p];
            int foundCount = 0;

            for (long[] region : regions) {
                for (long addr = region[0]; addr < region[1] - 2; addr++) {
                    try {
                        int b0 = mem.getByte(space.getAddress(addr)) & 0xFF;
                        int b1 = mem.getByte(space.getAddress(addr + 1)) & 0xFF;

                        // Short form: 38 xx (mov.b r0l, @0xFFFFxx) or 28 xx (mov.b @0xFFFFxx, r0l)
                        if ((b0 == 0x38 || b0 == 0x28 || b0 == 0x30 || b0 == 0x20) && b1 == portAddr) {
                            String op = (b0 & 0x10) != 0 ? "WRITE" : "READ";
                            println(String.format("    %s at 0x%06X [%02X %02X]", op, addr, b0, b1));
                            foundCount++;
                            if (foundCount > 30) break;
                        }
                    } catch (Exception e) {}
                }
                if (foundCount > 30) break;
            }
        }
    }

    private String bytesToHex(byte[] bytes) {
        StringBuilder sb = new StringBuilder();
        for (byte b : bytes) { sb.append(String.format("%02X ", b & 0xFF)); }
        return sb.toString().trim();
    }
}
