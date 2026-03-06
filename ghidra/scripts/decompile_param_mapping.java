// Decompile MAID parameter mapping functions in LS5000.md3
// FUN_100aee20 reads capability values by internal param ID
// FUN_100aeeb0 reads scan area values
// FUN_100b3a50 builds SET WINDOW parameters
// FUN_100b45c0 scan operation constructor (maps scan type codes to params)
// @category Analysis

import ghidra.app.script.GhidraScript;
import ghidra.app.decompiler.DecompInterface;
import ghidra.app.decompiler.DecompileResults;
import ghidra.program.model.listing.*;
import ghidra.program.model.address.*;
import java.io.*;
import java.util.*;

public class decompile_param_mapping extends GhidraScript {
    private DecompInterface decomp;
    private PrintWriter out;
    private Set<Long> done = new HashSet<>();

    @Override
    public void run() throws Exception {
        String outputPath = System.getProperty("user.dir") + "/ghidra/exports/ls5000_param_mapping.txt";
        out = new PrintWriter(new FileWriter(outputPath));
        decomp = new DecompInterface();
        decomp.openProgram(currentProgram);

        out.println("=== MAID PARAMETER MAPPING FUNCTIONS ===");

        // Core param readers used in SET WINDOW builder
        out.println("\n// ====== PARAM VALUE READERS ======");
        decompAt(0x100aee20L, "FUN_100aee20 - read MAID capability value by param ID");
        decompAt(0x100aeeb0L, "FUN_100aeeb0 - read scan area value by index");
        decompAt(0x100aee00L, "FUN_100aee00 - check/get status value");
        decompAt(0x100aeda0L, "FUN_100aeda0 - check condition/flag");
        decompAt(0x100aedc0L, "FUN_100aedc0 - check condition with param");

        // SET WINDOW parameter builders
        out.println("\n// ====== SET WINDOW BUILDERS ======");
        decompAt(0x100b3a50L, "FUN_100b3a50 - prepare SET WINDOW params (called before factory)");
        decompAt(0x100b2b30L, "FUN_100b2b30 - SET WINDOW parameter builder (1268 bytes)");

        // Scan operation constructor (maps scan type codes)
        out.println("\n// ====== SCAN OPERATION SETUP ======");
        decompAt(0x100b45c0L, "FUN_100b45c0 - scan operation constructor (type codes 0x40-0xD6)");
        decompAt(0x100b3ff0L, "FUN_100b3ff0 - scan type setup");
        decompAt(0x100b29b0L, "FUN_100b29b0 - base scan object constructor");

        // Step insert/modify helpers
        out.println("\n// ====== STEP MANAGEMENT ======");
        decompAt(0x100aed10L, "FUN_100aed10 - insert step (step code)");
        decompAt(0x100aed40L, "FUN_100aed40 - insert step (sub-code)");
        decompAt(0x100aed70L, "FUN_100aed70 - insert step (param)");
        decompAt(0x100aebf0L, "FUN_100aebf0 - init step queue");
        decompAt(0x100aec10L, "FUN_100aec10 - get step at index");

        // Vendor extension builders for SET WINDOW
        out.println("\n// ====== VENDOR EXTENSION BUILDERS ======");
        decompAt(0x100a0370L, "FUN_100a0370 - vendor extension iterator (SET WINDOW)");
        decompAt(0x100a0bc0L, "FUN_100a0bc0 - vendor extension data writer");
        decompAt(0x1009fc60L, "FUN_1009fc60 - ICE/DRAG extension iterator");
        decompAt(0x1009fce0L, "FUN_1009fce0 - ICE/DRAG extension data writer");

        // Status/progress reporting
        out.println("\n// ====== STATUS HELPERS ======");
        decompAt(0x100ae940L, "FUN_100ae940 - get scan mode flag");
        decompAt(0x1009ea60L, "FUN_1009ea60 - report status/progress");
        decompAt(0x100aeb80L, "FUN_100aeb80 - process E1 vendor response");
        decompAt(0x100aea30L, "FUN_100aea30 - process E1 readback data");

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
