// Trace MAID capability handlers in LS5000.md3
// Focus on Set Capability (case 4) and capability dispatch chain
// Also decompile Get Capability (case 3), Start Operation (case 10), and related
// @category Analysis

import ghidra.app.script.GhidraScript;
import ghidra.app.decompiler.DecompInterface;
import ghidra.app.decompiler.DecompileResults;
import ghidra.program.model.listing.*;
import ghidra.program.model.address.*;
import java.io.*;
import java.util.*;

public class trace_maid_capabilities extends GhidraScript {
    private DecompInterface decomp;
    private PrintWriter out;
    private Set<Long> decompiled = new HashSet<>();

    @Override
    public void run() throws Exception {
        String outputPath = System.getProperty("user.dir") + "/ghidra/exports/ls5000_maid_capabilities.txt";
        out = new PrintWriter(new FileWriter(outputPath));
        decomp = new DecompInterface();
        decomp.openProgram(currentProgram);
        FunctionManager fm = currentProgram.getFunctionManager();

        // === MAIDEntryPoint and dispatch ===
        out.println("=== MAIDEntryPoint DISPATCH ===");
        long[] maidEntry = {
            0x100298F0L, // MAIDEntryPoint export
            0x10029b30L, // Switch table area (within MAIDEntryPoint)
        };
        decompAll(fm, maidEntry);

        // === MAID Case Handlers (the 10 active cases) ===
        out.println("\n=== MAID CASE HANDLERS ===");
        long[] caseHandlers = {
            0x10028560L, // Case 0: Open/Initialize
            0x10029070L, // Case 1: Close/Shutdown
            0x100287e0L, // Case 2: Enumerate capabilities
            0x100271c0L, // Case 3: Get capability value
            0x10027230L, // Case 4: Set capability value (KEY TARGET)
            0x100275d0L, // Case 10: Start operation (scan, preview)
            0x10027810L, // Case 11: Get capability default
            0x10027a80L, // Case 12: Capability changed notification
            0x10027cf0L, // Case 14: Abort/Cancel
            0x10027f60L, // Case 15: Query status
        };
        decompAll(fm, caseHandlers);

        // === Capability dispatch chain ===
        // The set capability handler dispatches through capability objects
        // Need to trace the vtable chain from [esi+0x0c] capability manager
        out.println("\n=== CAPABILITY DISPATCH CHAIN (0x10027-0x10028 range) ===");
        FunctionIterator fiter = fm.getFunctions(toAddr(0x10027000L), true);
        int count = 0;
        while (fiter.hasNext() && count < 80) {
            Function f = fiter.next();
            if (f.getEntryPoint().getOffset() > 0x10029000L) break;
            if (f.getBody().getNumAddresses() > 20 && !decompiled.contains(f.getEntryPoint().getOffset())) {
                decompFunc(f);
                count++;
            }
        }

        // === Capability manager and object area (0x10020-0x10027) ===
        out.println("\n=== CAPABILITY MANAGER AREA (0x10020-0x10027 range) ===");
        fiter = fm.getFunctions(toAddr(0x10020000L), true);
        count = 0;
        while (fiter.hasNext() && count < 80) {
            Function f = fiter.next();
            if (f.getEntryPoint().getOffset() > 0x10027000L) break;
            if (f.getBody().getNumAddresses() > 40 && !decompiled.contains(f.getEntryPoint().getOffset())) {
                decompFunc(f);
                count++;
            }
        }

        // === Scanner init sequence ===
        out.println("\n=== SCANNER INIT SEQUENCE ===");
        long[] initFuncs = {
            0x100af200L, // Scanner open/init (942 bytes)
            0x100a44c0L, // Transport loader
            0x100a45a0L, // Transport init
        };
        decompAll(fm, initFuncs);

        // === Scan operation area (0x100b3-0x100b5) ===
        out.println("\n=== SCAN OPERATION AREA ===");
        long[] scanOps = {
            0x100b3c00L, // Scan operation start area
            0x100b4c00L, // Scan operation area
            0x100b0400L, // Focus/Exposure control
            0x100b0d30L, // Calibration with data
        };
        decompAll(fm, scanOps);

        // Decompile larger functions in the scan operation area
        fiter = fm.getFunctions(toAddr(0x100b3000L), true);
        count = 0;
        while (fiter.hasNext() && count < 40) {
            Function f = fiter.next();
            if (f.getEntryPoint().getOffset() > 0x100b6000L) break;
            if (f.getBody().getNumAddresses() > 60 && !decompiled.contains(f.getEntryPoint().getOffset())) {
                decompFunc(f);
                count++;
            }
        }

        // === Capability object vtable methods (0x10029-0x1002A) ===
        out.println("\n=== CAPABILITY OBJECT METHODS (0x10029-0x1002C range) ===");
        fiter = fm.getFunctions(toAddr(0x10029000L), true);
        count = 0;
        while (fiter.hasNext() && count < 60) {
            Function f = fiter.next();
            if (f.getEntryPoint().getOffset() > 0x1002c000L) break;
            if (f.getBody().getNumAddresses() > 30 && !decompiled.contains(f.getEntryPoint().getOffset())) {
                decompFunc(f);
                count++;
            }
        }

        // === Device query/status area (0x100b18-0x100b28) ===
        out.println("\n=== DEVICE QUERY/STATUS AREA ===");
        fiter = fm.getFunctions(toAddr(0x100b1800L), true);
        count = 0;
        while (fiter.hasNext() && count < 40) {
            Function f = fiter.next();
            if (f.getEntryPoint().getOffset() > 0x100b3000L) break;
            if (f.getBody().getNumAddresses() > 60 && !decompiled.contains(f.getEntryPoint().getOffset())) {
                decompFunc(f);
                count++;
            }
        }

        // === Focus/exposure/calibration area (0x100b04-0x100b18) ===
        out.println("\n=== FOCUS/EXPOSURE/CALIBRATION AREA ===");
        fiter = fm.getFunctions(toAddr(0x100b0400L), true);
        count = 0;
        while (fiter.hasNext() && count < 40) {
            Function f = fiter.next();
            if (f.getEntryPoint().getOffset() > 0x100b1800L) break;
            if (f.getBody().getNumAddresses() > 60 && !decompiled.contains(f.getEntryPoint().getOffset())) {
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
