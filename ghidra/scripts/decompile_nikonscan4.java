// Ghidra script to decompile key functions from NikonScan4.ds for Phase 3 analysis
// @category Analysis

import ghidra.app.script.GhidraScript;
import ghidra.app.decompiler.DecompInterface;
import ghidra.app.decompiler.DecompileResults;
import ghidra.program.model.listing.Function;
import ghidra.program.model.listing.FunctionManager;
import ghidra.program.model.listing.FunctionIterator;
import ghidra.program.model.address.Address;
import ghidra.program.model.symbol.*;
import java.io.*;
import java.util.*;

public class decompile_nikonscan4 extends GhidraScript {

    private DecompInterface decomp;
    private PrintWriter out;

    @Override
    public void run() throws Exception {
        String outputPath = getScriptArgs().length > 0 ? getScriptArgs()[0] :
            System.getProperty("user.dir") + "/ghidra/exports/nikonscan4_decompiled.txt";
        out = new PrintWriter(new FileWriter(outputPath));
        decomp = new DecompInterface();
        decomp.openProgram(currentProgram);

        FunctionManager fm = currentProgram.getFunctionManager();

        // === Section 1: List all named functions ===
        out.println("=== NAMED FUNCTIONS ===");
        int funcCount = 0;
        FunctionIterator fiter = fm.getFunctions(true);
        while (fiter.hasNext()) {
            Function f = fiter.next();
            String name = f.getName();
            if (!name.startsWith("FUN_")) {
                out.println(String.format("  0x%08X: %s (%d bytes)",
                    f.getEntryPoint().getOffset(), name, f.getBody().getNumAddresses()));
                funcCount++;
            }
        }
        out.println("Total named: " + funcCount);
        out.println();

        // === Section 2: Decompile key functions by address ===
        out.println("=== KEY FUNCTION DECOMPILATIONS ===");
        long[] addrs = {
            0x10091F50L, // DS_Entry
            0x100918b0L, // CNkTwainSource vtable[2]
            0x10091c40L, // CNkTwainSource vtable[8]
            0x10091450L, // CNkTwainSource vtable[9]
            0x100935e0L, // vtable[15]
            0x10091e60L, // vtable[11]
            0x10055c20L, // Object retriever
            0x1007a250L, // MAIDEntryPoint loader
            0x1007a3a0L, // Caller of loader
            0x10047c20L, // StartScan
            0x10048ab0L, // GetSource
            0x100479e0L, // CanEject
            0x10047a40L, // CanFeed
            0x10047aa0L, // Eject
            0x10089c30L, // Called from StartScan
            0x1003d420L, // Called from StartScan
            0x10096ac0L, // vtable function
            0x10095090L, // vtable function
            0x10091fb0L, // vtable function
            0x10090f90L, // vtable[0]
            0x10090fa0L, // vtable[1]
            0x10090fc0L, // vtable[3]
            0x10090fe0L, // vtable[4]
            0x10091010L, // vtable[6]
            0x10091020L, // vtable[7]
            0x10090e50L, // secondary vtable
            0x10090e60L, // secondary vtable
        };

        for (long addr : addrs) {
            Address a = toAddr(addr);
            Function f = fm.getFunctionAt(a);
            if (f == null) {
                f = fm.getFunctionContaining(a);
            }
            if (f != null) {
                decompFunc(f);
            } else {
                out.println(String.format("// No function at 0x%08X", addr));
            }
        }

        // === Section 3: Decompile all functions with interesting names ===
        out.println("\n=== INTERESTING NAMED FUNCTIONS ===");
        String[] patterns = {"Maid", "Command", "Queue", "Scan", "Triplet",
            "Twain", "Fresco", "Source", "Preview", "Focus", "Eject",
            "Feed", "Calibr", "Start", "Acquire"};
        fiter = fm.getFunctions(true);
        Set<String> decompiled = new HashSet<>();
        while (fiter.hasNext()) {
            Function f = fiter.next();
            String name = f.getName();
            if (name.startsWith("FUN_")) continue;
            for (String pat : patterns) {
                if (name.contains(pat) && !decompiled.contains(name)) {
                    // Only decompile functions up to 2000 bytes to avoid huge outputs
                    if (f.getBody().getNumAddresses() < 2000) {
                        decompFunc(f);
                        decompiled.add(name);
                    } else {
                        out.println(String.format("// Skipping large function: %s @ 0x%08X (%d bytes)",
                            name, f.getEntryPoint().getOffset(), f.getBody().getNumAddresses()));
                    }
                    break;
                }
            }
        }

        out.println("\n=== DONE ===");
        out.close();
        decomp.dispose();
        println("Output: " + outputPath);
    }

    private void decompFunc(Function f) {
        out.println(String.format("\n// === %s @ 0x%08X (%d bytes) ===",
            f.getName(), f.getEntryPoint().getOffset(), f.getBody().getNumAddresses()));
        try {
            DecompileResults res = decomp.decompileFunction(f, 30, monitor);
            if (res.decompileCompleted()) {
                out.println(res.getDecompiledFunction().getC());
            } else {
                out.println("// Decompilation failed: " + res.getErrorMessage());
            }
        } catch (Exception e) {
            out.println("// Error: " + e.getMessage());
        }
    }
}
