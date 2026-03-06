// Decompile specific addresses: vtable[23]=0x10070500 and vtable[47]=0x100724e0
// These are the MAID capability set/get and exists-check methods on CTwainMaidImage
// Also decompile nearby functions that may be called from vtable[23]
// @category Analysis

import ghidra.app.script.GhidraScript;
import ghidra.app.decompiler.DecompInterface;
import ghidra.app.decompiler.DecompileResults;
import ghidra.program.model.listing.*;
import ghidra.program.model.address.*;
import java.io.*;
import java.util.*;

public class decompile_cap_methods extends GhidraScript {
    private DecompInterface decomp;
    private PrintWriter out;
    private Set<Long> decompiled = new HashSet<>();

    @Override
    public void run() throws Exception {
        String outputPath = System.getProperty("user.dir") + "/ghidra/exports/nikonscan4_cap_methods.txt";
        out = new PrintWriter(new FileWriter(outputPath));
        decomp = new DecompInterface();
        decomp.openProgram(currentProgram);
        FunctionManager fm = currentProgram.getFunctionManager();

        // Direct targets
        long[] targets = {
            0x10070500L, // vtable[23] +0x5c = MAID cap set/get
            0x100724e0L, // vtable[47] +0xbc = cap exists check
            0x10070510L, // vtable[17] nearby function
            0x100704e0L, // vtable[46] nearby function
            0x10070490L, // vtable[43]
            0x100703e0L, // vtable[42]
            0x100702d0L, // vtable[41]
            0x10070230L, // vtable[40]
            0x100701b0L, // vtable[39]
            0x10070130L, // vtable[38]
            0x10070100L, // vtable[36]
            0x100700d0L, // vtable[35]
            0x100700c0L, // vtable[34]
            0x10070090L, // vtable[24]
            0x100700a0L, // vtable[25]
            0x10070080L, // vtable[26]
        };

        for (long addr : targets) {
            Function f = fm.getFunctionAt(toAddr(addr));
            if (f == null) f = fm.getFunctionContaining(toAddr(addr));
            if (f != null) {
                out.println(String.format("--- At 0x%08X ---", addr));
                decompFunc(f);
            } else {
                // Try to create a function
                out.println(String.format("--- No function at 0x%08X, trying to create ---", addr));
                try {
                    createFunction(toAddr(addr), null);
                    f = fm.getFunctionAt(toAddr(addr));
                    if (f != null) {
                        decompFunc(f);
                    }
                } catch (Exception e) {
                    out.println("// Could not create function: " + e.getMessage());
                }
            }
        }

        // Also decompile the MAID call path functions
        out.println("\n=== MAID CALL PATH ===");
        long[] maidPath = {
            0x1007a1f0L, // CFrescoMaidModule::CallMAID (vtable[23] on that class)
            0x10072550L, // vtable[48]
            0x100725c0L, // vtable[49]
            0x10072630L, // vtable[54]
            0x100726a0L, // vtable[55]
            0x10072710L, // vtable[56]
            0x10072790L, // vtable[57]
            0x10072800L, // vtable[58]
            0x10072870L, // vtable[59]
        };
        for (long addr : maidPath) {
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
