// Decompile key CTwainMaidImage/CMaidBase vtable methods
// Focus on vtable[23] (cap set/get) and vtable[47] (cap exists)
// Also decompile the MAID call wrapper chain
// @category Analysis

import ghidra.app.script.GhidraScript;
import ghidra.app.decompiler.DecompInterface;
import ghidra.app.decompiler.DecompileResults;
import ghidra.program.model.listing.*;
import ghidra.program.model.address.*;
import java.io.*;
import java.util.*;

public class decompile_ctm_methods extends GhidraScript {
    private DecompInterface decomp;
    private PrintWriter out;
    private Set<Long> decompiled = new HashSet<>();

    @Override
    public void run() throws Exception {
        String outputPath = System.getProperty("user.dir") + "/ghidra/exports/nikonscan4_ctm_methods.txt";
        out = new PrintWriter(new FileWriter(outputPath));
        decomp = new DecompInterface();
        decomp.openProgram(currentProgram);
        FunctionManager fm = currentProgram.getFunctionManager();

        out.println("=== CTwainMaidImage VTABLE METHODS ===");
        out.println("Vtable at 0x10145cfc, COL at 0x1014c4d4");
        out.println();

        // Key vtable entries from CTwainMaidImage (0x10145cfc)
        long[][] entries = {
            {0, 0x10075190L}, // [0] destructor/init
            {1, 0x1011c140L}, // [1]
            {2, 0x10075610L}, // [2]
            {7, 0x10070000L}, // [7]
            {8, 0x10074f30L}, // [8]
            {9, 0x10052960L}, // [9] - CTwainMaidImage override (CMaidBase has 0x100707d0)
            {10, 0x100707e0L}, // [10]
            {11, 0x100529f0L}, // [11] - CTwainMaidImage override
            {14, 0x100528e0L}, // [14] - CTwainMaidImage override
            {15, 0x100742d0L}, // [15]
            {17, 0x10070510L}, // [17]
            {18, 0x10073a40L}, // [18]
            {19, 0x100723c0L}, // [19]
            {20, 0x10073980L}, // [20]
            {21, 0x10071700L}, // [21]
            {22, 0x10071750L}, // [22]
            {23, 0x10070500L}, // [23] +0x5c = MAID CAP SET/GET (KEY!)
            {24, 0x10070090L}, // [24]
            {27, 0x10075420L}, // [27] - CTwainMaidImage override (CMaidBase has 0x100700b0)
            {28, 0x10074500L}, // [28]
            {29, 0x10073b40L}, // [29]
            {37, 0x10074d30L}, // [37]
            {44, 0x10075280L}, // [44]
            {45, 0x100752f0L}, // [45]
            {46, 0x100704e0L}, // [46]
            {47, 0x100724e0L}, // [47] +0xbc = CAP EXISTS CHECK (KEY!)
            {48, 0x10072550L}, // [48]
            {49, 0x100725c0L}, // [49]
            {50, 0x10074860L}, // [50]
            {54, 0x10072630L}, // [54]
        };

        for (long[] entry : entries) {
            int idx = (int)entry[0];
            long addr = entry[1];
            Function f = fm.getFunctionAt(toAddr(addr));
            if (f == null) f = fm.getFunctionContaining(toAddr(addr));
            if (f != null && !decompiled.contains(f.getEntryPoint().getOffset())) {
                out.println(String.format("--- vtable[%d] +0x%03X ---", idx, idx*4));
                decompFunc(f);
            }
        }

        // Also decompile the MAID module call wrappers that vtable[23] likely calls
        out.println("\n=== MAID MODULE CALL WRAPPERS ===");
        long[] wrappers = {
            0x1007a1f0L, // CFrescoMaidModule::CallMAID
            0x1007a250L, // Module loader (LoadLibraryA)
            0x1007a2e0L, // Module unload
        };
        for (long addr : wrappers) {
            Function f = fm.getFunctionAt(toAddr(addr));
            if (f == null) f = fm.getFunctionContaining(toAddr(addr));
            if (f != null && !decompiled.contains(f.getEntryPoint().getOffset())) {
                decompFunc(f);
            }
        }

        out.println("\n=== DONE ===");
        out.close();
        decomp.dispose();
        println("Output: " + outputPath);
    }

    private void decompFunc(Function f) {
        if (f == null) return;
        decompiled.add(f.getEntryPoint().getOffset());
        out.println(String.format("\n// === %s @ 0x%08X (%d bytes) ===",
            f.getName(), f.getEntryPoint().getOffset(), f.getBody().getNumAddresses()));
        try {
            DecompileResults res = decomp.decompileFunction(f, 30, monitor);
            if (res.decompileCompleted()) {
                out.println(res.getDecompiledFunction().getC());
            } else {
                out.println("// Decompilation failed");
            }
        } catch (Exception e) {
            out.println("// Error: " + e.getMessage());
        }
    }
}
