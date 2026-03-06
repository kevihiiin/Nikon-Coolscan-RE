// Decompile vendor extension registration functions in LS5000.md3
// These populate the vendor extension list at scanner_state+0x27c
// @category Analysis

import ghidra.app.script.GhidraScript;
import ghidra.app.decompiler.DecompInterface;
import ghidra.app.decompiler.DecompileResults;
import ghidra.program.model.listing.*;
import java.io.*;
import java.util.*;

public class decompile_vendor_ext_reg extends GhidraScript {
    private DecompInterface decomp;
    private PrintWriter out;
    private Set<Long> done = new HashSet<>();

    @Override
    public void run() throws Exception {
        String outputPath = System.getProperty("user.dir") + "/ghidra/exports/ls5000_vendor_ext_reg.txt";
        out = new PrintWriter(new FileWriter(outputPath));
        decomp = new DecompInterface();
        decomp.openProgram(currentProgram);

        out.println("=== VENDOR EXTENSION REGISTRATION ===");
        
        // The initialization cluster at 0x100A2989-0x100A3242
        // These functions LEA edi/esi+0x27c and call registration helpers
        decompAt(0x100a2950L, "FUN_100a2950 - vendor ext registration area start");
        decompAt(0x100a2c00L, "FUN_100a2c00 - vendor ext registration");
        decompAt(0x100a2ca0L, "FUN_100a2ca0 - vendor ext registration");
        decompAt(0x100a2d40L, "FUN_100a2d40 - vendor ext registration");
        decompAt(0x100a2de0L, "FUN_100a2de0 - vendor ext registration");
        decompAt(0x100a2e70L, "FUN_100a2e70 - vendor ext registration");
        decompAt(0x100a2f30L, "FUN_100a2f30 - vendor ext registration");
        decompAt(0x100a2fc0L, "FUN_100a2fc0 - vendor ext registration");
        decompAt(0x100a3060L, "FUN_100a3060 - vendor ext registration");
        decompAt(0x100a3100L, "FUN_100a3100 - vendor ext registration");
        decompAt(0x100a31a0L, "FUN_100a31a0 - vendor ext registration");
        decompAt(0x100a3240L, "FUN_100a3240 - vendor ext registration");
        decompAt(0x100a32d0L, "FUN_100a32d0 - vendor ext registration");
        
        // The list add function (called by all the above)
        decompAt(0x100a0d20L, "FUN_100a0d20 - vendor ext list add function");
        
        // Also decompile the function at 0x100a4020 area for completeness
        decompAt(0x100a4020L, "FUN_100a4020 - possible param init");

        out.println("\n=== DONE ===");
        out.close();
        decomp.dispose();
        println("Output: " + outputPath);
    }

    private void decompAt(long addr, String desc) {
        FunctionManager fm = currentProgram.getFunctionManager();
        Function f = fm.getFunctionAt(toAddr(addr));
        if (f == null) f = fm.getFunctionContaining(toAddr(addr));
        if (f != null && !done.contains(f.getEntryPoint().getOffset())) {
            out.println(String.format("\n// --- %s ---", desc));
            done.add(f.getEntryPoint().getOffset());
            out.println(String.format("// === %s @ 0x%08X (%d bytes) ===",
                f.getName(), f.getEntryPoint().getOffset(), f.getBody().getNumAddresses()));
            try {
                DecompileResults res = decomp.decompileFunction(f, 60, monitor);
                if (res.decompileCompleted()) out.println(res.getDecompiledFunction().getC());
                else out.println("// Decompilation failed\n");
            } catch (Exception e) {
                out.println("// Error: " + e.getMessage() + "\n");
            }
        }
    }
}
