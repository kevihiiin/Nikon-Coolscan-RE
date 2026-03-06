// Decompile the Eject workflow functions in NikonScan4.ds
// @category Analysis

import ghidra.app.script.GhidraScript;
import ghidra.app.decompiler.DecompInterface;
import ghidra.app.decompiler.DecompileResults;
import ghidra.program.model.listing.*;
import java.io.*;
import java.util.*;

public class decompile_eject extends GhidraScript {
    private DecompInterface decomp;
    private PrintWriter out;
    private Set<Long> done = new HashSet<>();

    @Override
    public void run() throws Exception {
        String outputPath = System.getProperty("user.dir") + "/ghidra/exports/nikonscan4_eject.txt";
        out = new PrintWriter(new FileWriter(outputPath));
        decomp = new DecompInterface();
        decomp.openProgram(currentProgram);

        out.println("=== EJECT WORKFLOW ===");
        decompAt(0x100318b0L, "FUN_100318b0 - execute eject");
        decompAt(0x1001fdc0L, "FUN_1001fdc0 - can eject check");
        decompAt(0x10089c30L, "FUN_10089c30 - get current source");

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
