// Decompile deeper Eject workflow functions in NikonScan4.ds
// @category Analysis

import ghidra.app.script.GhidraScript;
import ghidra.app.decompiler.DecompInterface;
import ghidra.app.decompiler.DecompileResults;
import ghidra.program.model.listing.*;
import java.io.*;
import java.util.*;

public class decompile_eject_deep extends GhidraScript {
    private DecompInterface decomp;
    private PrintWriter out;
    private Set<Long> done = new HashSet<>();

    @Override
    public void run() throws Exception {
        String outputPath = System.getProperty("user.dir") + "/ghidra/exports/nikonscan4_eject_deep.txt";
        out = new PrintWriter(new FileWriter(outputPath));
        decomp = new DecompInterface();
        decomp.openProgram(currentProgram);

        out.println("=== EJECT WORKFLOW (DEEP) ===");
        
        // The actual eject executor called from FUN_100318b0
        decompAt(0x1002e030L, "FUN_1002e030 - actual eject execution");
        
        // Film advance / eject MAID chain
        decompAt(0x1002e100L, "FUN_1002e100 - nearby function (possible eject helper)");
        decompAt(0x1002e1a0L, "FUN_1002e1a0 - nearby function");
        decompAt(0x1002e200L, "FUN_1002e200 - nearby function");
        
        // CanEject export at 0x10008f70
        decompAt(0x10008f70L, "CanEject export");
        // Eject export at 0x10008f50
        decompAt(0x10008f50L, "Eject export");
        
        // GetSource and related
        decompAt(0x10008eb0L, "GetSource export");
        decompAt(0x10008ef0L, "GetScanSource export");
        
        // Film advance functions near eject
        decompAt(0x10031910L, "FUN_10031910 - after execute eject");
        decompAt(0x10031950L, "FUN_10031950 - film strip functions");
        decompAt(0x10031990L, "FUN_10031990 - possible film advance");
        decompAt(0x100319d0L, "FUN_100319d0 - possible rewind");

        // Search for MAID eject capability near known scan workflow
        decompAt(0x10031800L, "FUN_10031800 - before execute eject");
        decompAt(0x10031850L, "FUN_10031850 - possible eject setup");

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
