// Force disassembly at known SCSI handler entry points, then dump code
// @category Analysis

import ghidra.app.script.GhidraScript;
import ghidra.program.model.listing.*;
import ghidra.program.model.address.*;
import ghidra.program.model.mem.*;
import ghidra.app.cmd.disassemble.DisassembleCommand;

public class force_disassemble_handlers extends GhidraScript {

    @Override
    public void run() throws Exception {
        AddressSpace space = currentProgram.getAddressFactory().getDefaultAddressSpace();
        Memory mem = currentProgram.getMemory();
        Listing listing = currentProgram.getListing();

        // All SCSI handler entry points
        long[] handlers = {
            0x0215C2, // TEST UNIT READY
            0x021866, // REQUEST SENSE
            0x025E18, // INQUIRY
            0x02194A, // MODE SELECT
            0x021E3E, // RESERVE
            0x021EA0, // RELEASE
            0x021F1C, // MODE SENSE
            0x0220B8, // SCAN
            0x023856, // RECEIVE DIAGNOSTIC
            0x023D32, // SEND DIAGNOSTIC
            0x026E38, // SET WINDOW
            0x0272F6, // GET WINDOW
            0x023F10, // READ(10)
            0x025506, // SEND(10)
            0x02837C, // WRITE BUFFER
            0x028884, // READ BUFFER
            0x028AB4, // Vendor C0
            0x028B08, // Vendor C1
            0x013748, // Vendor D0 (Phase Query)
            0x028E16, // Vendor E0
            0x0295EA, // Vendor E1
            // Motor/timer handlers
            0x010B76, // Timer4 compare
            0x033444, // Timer0 capture B
            0x010876, // IRQ0
            0x014D4A, // Timer0 cap C/D
            0x02B544, // Timer0 special
        };

        String[] names = {
            "TEST_UNIT_READY", "REQUEST_SENSE", "INQUIRY", "MODE_SELECT",
            "RESERVE", "RELEASE", "MODE_SENSE", "SCAN",
            "RECV_DIAG", "SEND_DIAG", "SET_WINDOW", "GET_WINDOW",
            "READ_10", "SEND_10", "WRITE_BUFFER", "READ_BUFFER",
            "VENDOR_C0", "VENDOR_C1", "PHASE_QUERY_D0", "VENDOR_E0", "VENDOR_E1",
            "ITU4_CMP_MOTOR", "ITU0_CAPB_ENCODER", "IRQ0", "ITU0_CAPCD", "ITU0_SPECIAL"
        };

        // Force disassembly at each handler entry point
        println("=== FORCING DISASSEMBLY AT HANDLER ENTRY POINTS ===");
        for (int i = 0; i < handlers.length; i++) {
            Address addr = space.getAddress(handlers[i]);
            Instruction existing = listing.getInstructionAt(addr);
            if (existing == null) {
                DisassembleCommand cmd = new DisassembleCommand(addr, null, true);
                cmd.applyTo(currentProgram, monitor);
                println(String.format("  Disassembled at 0x%06X (%s)", handlers[i], names[i]));
            } else {
                println(String.format("  Already disassembled at 0x%06X (%s)", handlers[i], names[i]));
            }
        }

        // Now dump each handler
        for (int i = 0; i < handlers.length; i++) {
            long start = handlers[i];
            // Find the handler end (RTS instruction or 500 instructions max)
            long end = findHandlerEnd(space, listing, start);
            println(String.format("\n=== %s HANDLER (0x%06X-0x%06X) ===", names[i], start, end));
            dumpDisassembly(space, listing, start, end);
        }
    }

    private long findHandlerEnd(AddressSpace space, Listing listing, long start) {
        Address addr = space.getAddress(start);
        int count = 0;
        int rtsCount = 0;
        while (addr != null && count < 500) {
            Instruction instr = listing.getInstructionAt(addr);
            if (instr != null) {
                String mnemonic = instr.getMnemonicString();
                if (mnemonic != null && mnemonic.equals("rts")) {
                    rtsCount++;
                    // First RTS for simple functions, but allow more for complex ones
                    if (rtsCount >= 1 && count > 5) {
                        return addr.getOffset() + 2; // RTS is 2 bytes
                    }
                }
                addr = instr.getMaxAddress().add(1);
                count++;
            } else {
                // No instruction, try next byte
                addr = addr.add(1);
                count++;
                // If we hit 10 consecutive non-instructions, stop
                boolean hasInstr = false;
                for (int i = 0; i < 10 && addr != null; i++) {
                    if (listing.getInstructionAt(addr.add(i)) != null) {
                        hasInstr = true;
                        break;
                    }
                }
                if (!hasInstr) break;
            }
        }
        return start + Math.min(count * 4, 0x200); // Default: max 512 bytes
    }

    private void dumpDisassembly(AddressSpace space, Listing listing, long start, long end) {
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
                } else {
                    addr = addr.add(1);
                }
                count++;
            }
        }
    }

    private String bytesToHex(byte[] bytes) {
        StringBuilder sb = new StringBuilder();
        for (byte b : bytes) { sb.append(String.format("%02X ", b & 0xFF)); }
        return sb.toString().trim();
    }
}
