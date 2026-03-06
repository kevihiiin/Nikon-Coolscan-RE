// Decompile the scan phase vtable methods (command factories and step handlers)
// These are the functions that compose SCSI command sequences
// @category Analysis

import ghidra.app.script.GhidraScript;
import ghidra.app.decompiler.DecompInterface;
import ghidra.app.decompiler.DecompileResults;
import ghidra.program.model.listing.*;
import ghidra.program.model.address.*;
import java.io.*;
import java.util.*;

public class decompile_scan_phases extends GhidraScript {
    private DecompInterface decomp;
    private PrintWriter out;
    private Set<Long> done = new HashSet<>();

    @Override
    public void run() throws Exception {
        String outputPath = System.getProperty("user.dir") + "/ghidra/exports/ls5000_scan_phases.txt";
        out = new PrintWriter(new FileWriter(outputPath));
        decomp = new DecompInterface();
        decomp.openProgram(currentProgram);

        out.println("=== SCAN OPERATION VTABLE METHODS ===");
        out.println("// Vtable structure: [7]=PhaseA factory, [8]=PhaseA handler, [16]=PhaseB factory, [17]=PhaseB handler");
        out.println();

        // Type A: Init + Main Scan
        out.println("// ====== TYPE A: INIT + MAIN SCAN ======");
        decompAt(0x100b3b90L, "Type A [16] PhaseB factory - MAIN SCAN SEQUENCE");
        decompAt(0x100afd00L, "Type A [17] PhaseB handler - scan step handler");
        decompAt(0x100b3060L, "Type A [8] PhaseA handler / Base [8],[17] - init step handler");

        // Type B: Simple Scan
        out.println("\n// ====== TYPE B: SIMPLE SCAN ======");
        decompAt(0x100b4040L, "Type B [7] PhaseA factory - simple scan phase 1");
        decompAt(0x100aff70L, "Type B [8] PhaseA handler");
        decompAt(0x100b41a0L, "Type B [16] PhaseB factory - simple scan phase 2");
        decompAt(0x100b36e0L, "Type B [17] PhaseB handler");

        // Type C: Focus/Autofocus
        out.println("\n// ====== TYPE C: FOCUS/AUTOFOCUS ======");
        // FUN_100b0380 already decompiled (Type C [7])
        decompAt(0x100b06f0L, "Type C [8] PhaseA handler - focus step handler");
        // FUN_100b0c20 already decompiled (Type C [16])
        decompAt(0x100b1170L, "Type C/D [17]/[8] handler - focus phase 2 handler");

        // Type D: Advanced operations
        out.println("\n// ====== TYPE D: ADVANCED OPERATIONS ======");
        decompAt(0x100b17e0L, "Type D [16] PhaseB factory");
        decompAt(0x100b1a90L, "Type D [17] PhaseB handler");

        // Step sequencer functions
        out.println("\n// ====== STEP SEQUENCER ======");
        decompAt(0x100b2a40L, "Shared vtable[5] - step advance?");
        decompAt(0x100b2a80L, "Shared vtable[1] - next step");
        decompAt(0x100b2ab0L, "Shared vtable[2]");
        decompAt(0x100b2ae0L, "Shared vtable[3]");
        decompAt(0x100b2b20L, "Shared vtable[4]");
        decompAt(0x100aec40L, "Shared vtable[6]");

        // Key helper functions
        out.println("\n// ====== HELPER FUNCTIONS ======");
        decompAt(0x100aec50L, "FUN_100aec50 - get next step code");
        decompAt(0x100aec80L, "FUN_100aec80 - get step sub-code");
        decompAt(0x100aecb0L, "FUN_100aecb0 - get step param");
        decompAt(0x100aece0L, "FUN_100aece0 - get step param 2");

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
