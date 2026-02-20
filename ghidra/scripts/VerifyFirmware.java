// Verify firmware disassembly at reset vector
// @category CoolscanRE

import ghidra.app.script.GhidraScript;
import ghidra.program.model.address.*;
import ghidra.program.model.listing.*;
import ghidra.app.cmd.disassemble.DisassembleCommand;

public class VerifyFirmware extends GhidraScript {
    @Override
    public void run() throws Exception {
        AddressSpace space = currentProgram.getAddressFactory().getDefaultAddressSpace();
        Address addr = space.getAddress(0x100);

        println("Reset vector entry point: " + addr);

        // Disassemble at 0x100
        DisassembleCommand cmd = new DisassembleCommand(addr, null, true);
        cmd.applyTo(currentProgram, monitor);

        // Read first 20 instructions
        Listing listing = currentProgram.getListing();
        Instruction instr = listing.getInstructionAt(addr);
        int count = 0;
        while (instr != null && count < 20) {
            println(String.format("  %s: %s", instr.getAddress(), instr));
            instr = instr.getNext();
            count++;
        }

        // Check vector table entries
        println("\nVector table (first 20 entries):");
        var mem = currentProgram.getMemory();
        for (int i = 0; i < 20; i++) {
            Address vecAddr = space.getAddress(i * 4);
            int b0 = mem.getByte(vecAddr) & 0xFF;
            int b1 = mem.getByte(vecAddr.add(1)) & 0xFF;
            int b2 = mem.getByte(vecAddr.add(2)) & 0xFF;
            int b3 = mem.getByte(vecAddr.add(3)) & 0xFF;
            int target = (b0 << 24) | (b1 << 16) | (b2 << 8) | b3;
            println(String.format("  Vector %2d (0x%03X): -> 0x%06X", i, i*4, target));
        }
    }
}
