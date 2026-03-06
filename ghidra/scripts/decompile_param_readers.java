// Decompile the functions that read scanner parameter values by MAID internal ID
// FUN_100a05d0 is called by FUN_100aee20 to get parameter values from state object
// FUN_100a0990/100a09e0/100a0a30/100a0a80 are scan area getters
// @category Analysis

import ghidra.app.script.GhidraScript;
import ghidra.app.decompiler.DecompInterface;
import ghidra.app.decompiler.DecompileResults;
import ghidra.program.model.listing.*;
import java.io.*;
import java.util.*;

public class decompile_param_readers extends GhidraScript {
    private DecompInterface decomp;
    private PrintWriter out;
    private Set<Long> done = new HashSet<>();

    @Override
    public void run() throws Exception {
        String outputPath = System.getProperty("user.dir") + "/ghidra/exports/ls5000_param_readers.txt";
        out = new PrintWriter(new FileWriter(outputPath));
        decomp = new DecompInterface();
        decomp.openProgram(currentProgram);

        out.println("=== MAID PARAMETER VALUE READERS ===");

        // Primary parameter reader (dispatches by param ID)
        decompAt(0x100a05d0L, "FUN_100a05d0 - primary param value reader (param ID dispatch)");

        // Secondary parameter reader (for override path)
        decompAt(0x100aad10L, "FUN_100aad10 - secondary param value reader (override path)");

        // Scan area getters (called by FUN_100aeeb0)
        out.println("\n// ====== SCAN AREA GETTERS ======");
        decompAt(0x100a0990L, "FUN_100a0990 - get scan area Y upper-left (index 0)");
        decompAt(0x100a09e0L, "FUN_100a09e0 - get scan area X upper-left (index 1)");
        decompAt(0x100a0a30L, "FUN_100a0a30 - get scan area height (index 2)");
        decompAt(0x100a0a80L, "FUN_100a0a80 - get scan area width (index 3)");

        // Vendor extension param count/size
        out.println("\n// ====== VENDOR EXTENSION HELPERS ======");
        decompAt(0x100a0360L, "FUN_100a0360 - get vendor extension total size");
        decompAt(0x1009d730L, "FUN_1009d730 - check if ICE/DRAG extensions present");
        decompAt(0x1009fc20L, "FUN_1009fc20 - get ICE/DRAG extension size");
        decompAt(0x1009f730L, "FUN_1009f730 - get vendor extension count");
        decompAt(0x10009ff0L, "FUN_10009ff0 - get ICE/DRAG extension count");

        // Status/condition checking functions
        out.println("\n// ====== CONDITION CHECKERS ======");
        decompAt(0x100ae910L, "FUN_100ae910 - check status bit in state block");
        decompAt(0x1009e660L, "FUN_1009e660 - check condition flag in state block");

        // Scan operation start (MAID opcode 10)
        out.println("\n// ====== SCAN OPERATION START ======");
        decompAt(0x100275d0L, "FUN_100275d0 - MAIDEntryPoint case 10 (start operation)");

        // Capability object factory
        out.println("\n// ====== CAPABILITY MANAGEMENT ======");
        decompAt(0x100273a0L, "FUN_100273a0 - capability object dispatcher (cases 5-9)");

        out.println("\n=== DONE ===");
        out.close();
        decomp.dispose();
        println("Output: " + outputPath);
    }

    private void decompAt(long addr, String desc) {
        FunctionManager fm = currentProgram.getFunctionManager();
        Function f = fm.getFunctionAt(toAddr(addr));
        if (f == null) f = fm.getFunctionContaining(toAddr(addr));
        if (f != null) {
            if (done.contains(f.getEntryPoint().getOffset())) {
                out.println(String.format("\n// Already decompiled: %s @ 0x%08X [%s]",
                    f.getName(), f.getEntryPoint().getOffset(), desc));
                return;
            }
            out.println(String.format("\n// --- %s ---", desc));
            doDecomp(f);
        } else {
            out.println(String.format("\n// --- %s ---", desc));
            out.println(String.format("// No function at 0x%08X, creating...", addr));
            try {
                createFunction(toAddr(addr), null);
                f = fm.getFunctionAt(toAddr(addr));
                if (f != null) doDecomp(f);
                else out.println("// Could not create function");
            } catch (Exception e) {
                out.println("// Error: " + e.getMessage());
            }
        }
    }

    private void doDecomp(Function f) {
        if (f == null) return;
        done.add(f.getEntryPoint().getOffset());
        out.println(String.format("// === %s @ 0x%08X (%d bytes) ===",
            f.getName(), f.getEntryPoint().getOffset(), f.getBody().getNumAddresses()));
        try {
            DecompileResults res = decomp.decompileFunction(f, 60, monitor);
            if (res.decompileCompleted()) {
                out.println(res.getDecompiledFunction().getC());
            } else {
                out.println("// Decompilation failed\n");
            }
        } catch (Exception e) {
            out.println("// Error: " + e.getMessage() + "\n");
        }
    }
}
