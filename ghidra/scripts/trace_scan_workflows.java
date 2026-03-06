// Trace scan workflow functions: StartScan, Preview, Autofocus, Eject, Film Advance
// Also trace from CStoppableCommandQueue and CFrescoTwainSource
// @category Analysis

import ghidra.app.script.GhidraScript;
import ghidra.app.decompiler.DecompInterface;
import ghidra.app.decompiler.DecompileResults;
import ghidra.program.model.listing.*;
import ghidra.program.model.address.*;
import java.io.*;
import java.util.*;

public class trace_scan_workflows extends GhidraScript {
    private DecompInterface decomp;
    private PrintWriter out;
    private Set<Long> decompiled = new HashSet<>();

    @Override
    public void run() throws Exception {
        String outputPath = System.getProperty("user.dir") + "/ghidra/exports/nikonscan4_scan_workflows.txt";
        out = new PrintWriter(new FileWriter(outputPath));
        decomp = new DecompInterface();
        decomp.openProgram(currentProgram);
        FunctionManager fm = currentProgram.getFunctionManager();

        // === StartScan chain ===
        out.println("=== STARTSCAN WORKFLOW CHAIN ===");
        long[] startScanChain = {
            0x10047C20L, // StartScan (export)
            0x10055c20L, // Get singleton scanner obj
            0x10089c30L, // Find current scanner source
            0x1003d420L, // StartScan trigger
            0x1003b200L, // Actual scan start
        };
        decompAll(fm, startScanChain);

        // === Eject / CanEject ===
        out.println("\n=== EJECT WORKFLOW ===");
        long[] ejectChain = {
            0x100479E0L, // CanEject
            0x10047AA0L, // Eject
        };
        decompAll(fm, ejectChain);

        // === CFrescoTwainSource key functions ===
        out.println("\n=== CFrescoTwainSource KEY METHODS ===");
        // vtable entries that are large (>100 bytes) = likely important
        long[] frescoTwain = {
            0x1005fc40L, // vtable[4] - 1597 bytes (module discovery/loading)
            0x1005ca40L, // vtable[6] - 1032 bytes
            0x1005cf60L, // vtable[7] - 899 bytes
            0x10060EB0L, // vtable[14]
            0x10059E80L, // vtable[15]
            0x10093B40L, // vtable[20]
            0x10093290L, // vtable[21]
            0x100921f0L, // vtable[22] - 124 bytes
            0x10059F70L, // vtable[24]
            0x10063100L, // vtable[27]
            0x10063580L, // vtable[29]
        };
        decompAll(fm, frescoTwain);

        // === CStoppableCommandQueue::Execute (573 bytes) and related ===
        out.println("\n=== CStoppableCommandQueue METHODS ===");
        long[] stoppableQueue = {
            0x1004d0c0L, // vtable[16] - Execute, 573 bytes (already have, but re-decompile)
            0x1004cd70L, // vtable[14] - Reset override
            0x1004cdc0L, // vtable[18]
            0x1004CDF0L, // vtable[17]
            0x1004CD90L, // vtable[15]
        };
        decompAll(fm, stoppableQueue);

        // === Functions referencing scan workflow (0x1003xxxx range) ===
        out.println("\n=== SCAN TRIGGER FUNCTIONS (0x1003-0x1004 range) ===");
        // Decompile large functions in the scan trigger area
        FunctionIterator fiter = fm.getFunctions(toAddr(0x10038000L), true);
        int count = 0;
        while (fiter.hasNext() && count < 60) {
            Function f = fiter.next();
            if (f.getEntryPoint().getOffset() > 0x10050000L) break;
            if (f.getBody().getNumAddresses() > 80 && !decompiled.contains(f.getEntryPoint().getOffset())) {
                decompFunc(f);
                count++;
            }
        }

        // === Functions in 0x1006xxxx range (MAID/scan operations) ===
        out.println("\n=== MAID OPERATION FUNCTIONS (0x1006 range) ===");
        long[] maidOps = {
            0x1006b1b0L, // Referenced by CStoppableCommandQueue (scan error handler)
            0x1006b150L, // Referenced by CStoppableCommandQueue
            0x100696e0L, // Referenced by CStoppableCommandQueue
            0x1006aa90L, // Referenced by CStoppableCommandQueue
            0x1006fed0L, // Get MAID module (referenced frequently)
        };
        decompAll(fm, maidOps);

        // === CQueueAcquireImage overridden methods ===
        out.println("\n=== CQueueAcquireImage SPECIFIC METHODS ===");
        long[] acquireImage = {
            0x100C08A0L, // vtable[15] - Cleanup override (201 bytes)
            0x100C0970L, // vtable[16]
            0x100C0A80L, // vtable[17]
            0x100C0A40L, // vtable[18]
            0x100C0820L, // Destructor inner
        };
        decompAll(fm, acquireImage);

        // === 0x100B wrapper functions (MAID call wrappers) ===
        out.println("\n=== MAID CALL WRAPPERS (0x100B region) ===");
        fiter = fm.getFunctions(toAddr(0x100B2000L), true);
        count = 0;
        while (fiter.hasNext() && count < 50) {
            Function f = fiter.next();
            if (f.getEntryPoint().getOffset() > 0x100BF000L) break;
            if (f.getBody().getNumAddresses() > 30 && !decompiled.contains(f.getEntryPoint().getOffset())) {
                decompFunc(f);
                count++;
            }
        }

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
