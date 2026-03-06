// Extract all MAID capability IDs used in NikonScan4.ds
// Focus on the scan orchestrator FUN_1003b200 and its callees
// Also trace CFrescoTwainSource capability configuration methods
// @category Analysis

import ghidra.app.script.GhidraScript;
import ghidra.app.decompiler.DecompInterface;
import ghidra.app.decompiler.DecompileResults;
import ghidra.program.model.listing.*;
import ghidra.program.model.address.*;
import java.io.*;
import java.util.*;

public class extract_maid_cap_ids extends GhidraScript {
    private DecompInterface decomp;
    private PrintWriter out;
    private Set<Long> decompiled = new HashSet<>();

    @Override
    public void run() throws Exception {
        String outputPath = System.getProperty("user.dir") + "/ghidra/exports/nikonscan4_maid_cap_ids.txt";
        out = new PrintWriter(new FileWriter(outputPath));
        decomp = new DecompInterface();
        decomp.openProgram(currentProgram);
        FunctionManager fm = currentProgram.getFunctionManager();

        // === Main scan orchestrator and callees ===
        out.println("=== SCAN ORCHESTRATOR (FUN_1003b200, 8430 bytes) ===");
        long[] scanOrch = {
            0x1003b200L, // Main scan orchestrator
        };
        decompAll(fm, scanOrch);

        // === Functions called FROM the scan orchestrator (0x1003-0x1004 range) ===
        out.println("\n=== SCAN ORCHESTRATOR CALLEES ===");
        // Key functions that set MAID capabilities
        long[] orchCallees = {
            0x1003d420L, // StartScan trigger (calls scan orchestrator)
            0x10038c10L, // Area near capability setup
            0x10039000L, // Area near capability setup
            0x10039c00L, // Area near scan param config
            0x1003a000L, // Area near scan param config
            0x1003a800L, // Area near ROI setup
        };
        decompAll(fm, orchCallees);

        // === MAID capability wrapper functions ===
        // These are the functions that call CFrescoMaidModule to set capabilities
        out.println("\n=== MAID CAPABILITY SETTERS (CTwainMaidImage methods) ===");
        // CTwainMaidImage and CMaidBase area
        FunctionIterator fiter = fm.getFunctions(toAddr(0x10098000L), true);
        int count = 0;
        while (fiter.hasNext() && count < 80) {
            Function f = fiter.next();
            if (f.getEntryPoint().getOffset() > 0x100a0000L) break;
            if (f.getBody().getNumAddresses() > 30 && !decompiled.contains(f.getEntryPoint().getOffset())) {
                decompFunc(f);
                count++;
            }
        }

        // === CFrescoMaidSource methods (cap ID routing) ===
        out.println("\n=== CFrescoMaidSource METHODS ===");
        fiter = fm.getFunctions(toAddr(0x10070000L), true);
        count = 0;
        while (fiter.hasNext() && count < 60) {
            Function f = fiter.next();
            if (f.getEntryPoint().getOffset() > 0x10080000L) break;
            if (f.getBody().getNumAddresses() > 50 && !decompiled.contains(f.getEntryPoint().getOffset())) {
                decompFunc(f);
                count++;
            }
        }

        // === Eject, Film Advance, Preview, Autofocus workflows ===
        out.println("\n=== OTHER SCAN WORKFLOWS ===");
        long[] otherWorkflows = {
            0x100479E0L, // CanEject export
            0x10047AA0L, // Eject export
            0x10047C20L, // StartScan export
            0x10047800L, // Preview area
            0x10047900L, // Autofocus area
        };
        decompAll(fm, otherWorkflows);

        // === Functions that reference 0x800C, 0x25, 0x8007 (known cap IDs) ===
        // These are the functions that configure scan parameters
        out.println("\n=== SCAN PARAMETER CONFIGURATION (0x1004-0x1005 range) ===");
        fiter = fm.getFunctions(toAddr(0x10040000L), true);
        count = 0;
        while (fiter.hasNext() && count < 60) {
            Function f = fiter.next();
            if (f.getEntryPoint().getOffset() > 0x10055000L) break;
            if (f.getBody().getNumAddresses() > 80 && !decompiled.contains(f.getEntryPoint().getOffset())) {
                decompFunc(f);
                count++;
            }
        }

        // === Image source list / scan source management ===
        out.println("\n=== SCAN SOURCE MANAGEMENT ===");
        long[] srcMgmt = {
            0x10104240L, // Get scan source list (from scan orch xref)
            0x10104280L, // Get scan source list variant
        };
        decompAll(fm, srcMgmt);

        out.println("\n=== DONE ===");
        out.close();
        decomp.dispose();
        println("Output: " + outputPath);
    }

    private void decompAll(FunctionManager fm, long[] addrs) {
        for (long addr : addrs) {
            Address a = toAddr(addr);
            Function f = fm.getFunctionAt(a);
            if (f == null) f = fm.getFunctionContaining(a);
            if (f != null && !decompiled.contains(f.getEntryPoint().getOffset())) {
                decompFunc(f);
            } else if (f == null) {
                out.println("// No function at 0x" + Long.toHexString(addr));
            }
        }
    }

    private void decompFunc(Function f) {
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
