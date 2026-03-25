// Dump disassembly of USB data transfer functions for Phase 7 analysis
// @category Coolscan

import ghidra.app.script.GhidraScript;
import ghidra.program.model.listing.*;
import ghidra.program.model.address.*;

public class dump_usb_transfer extends GhidraScript {

    private void dumpRange(long start, long end, String name) {
        Listing listing = currentProgram.getListing();
        AddressSpace space = currentProgram.getAddressFactory().getDefaultAddressSpace();

        println("=== " + name + " ===");
        Address addr = space.getAddress(start);
        Address endAddr = space.getAddress(end);

        InstructionIterator iter = listing.getInstructions(addr, true);
        while (iter.hasNext()) {
            Instruction insn = iter.next();
            if (insn.getAddress().compareTo(endAddr) >= 0) break;

            StringBuilder sb = new StringBuilder();
            sb.append(String.format("  0x%06X: %-30s [",
                insn.getAddress().getOffset(),
                insn.toString()));
            byte[] bytes = insn.getBytes();
            for (int i = 0; i < bytes.length; i++) {
                if (i > 0) sb.append(" ");
                sb.append(String.format("%02X", bytes[i] & 0xFF));
            }
            sb.append("]");
            println(sb.toString());
        }
        println("");
    }

    @Override
    public void run() throws Exception {
        dumpRange(0x014090, 0x014120, "DATA_TRANSFER_0x014090");
        dumpRange(0x016458, 0x0164A0, "CDB_READ_0x016458");
        dumpRange(0x01232E, 0x012360, "DIVXU_HELPER_0x01232E");
        dumpRange(0x012258, 0x0122C0, "USB_FIFO_RW_0x012258");
        dumpRange(0x013D72, 0x013DC0, "BUFFER_SETUP_0x013D72");
        dumpRange(0x01374A, 0x0137D0, "RESPONSE_MANAGER_0x01374A");
        dumpRange(0x013C70, 0x013D00, "USB_READY_WAIT_0x013C70");
    }
}
