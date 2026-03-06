// Decompile MAID call chain and command queue functions
// @category Analysis

import ghidra.app.script.GhidraScript;
import ghidra.app.decompiler.DecompInterface;
import ghidra.app.decompiler.DecompileResults;
import ghidra.program.model.listing.*;
import ghidra.program.model.address.*;
import java.io.*;
import java.util.*;

public class decompile_maid_chain extends GhidraScript {
    private DecompInterface decomp;
    private PrintWriter out;

    @Override
    public void run() throws Exception {
        String outputPath = System.getProperty("user.dir") + "/ghidra/exports/nikonscan4_maid_chain.txt";
        out = new PrintWriter(new FileWriter(outputPath));
        decomp = new DecompInterface();
        decomp.openProgram(currentProgram);
        FunctionManager fm = currentProgram.getFunctionManager();

        out.println("=== MAID CALL CHAIN DECOMPILATIONS ===\n");

        // Key MAID-related functions
        long[] maidAddrs = {
            0x1007a1f0L, // Contains call [esi+0x74] — direct MAID call
            0x1007a2e0L, // CFrescoMaidModule vtable[19]
            0x10075190L, // CFrescoMaidModule vtable[0]
            0x10054190L, // CFrescoMaidModule vtable[1]
            0x10073720L, // CFrescoMaidModule vtable[2]
            0x10053f70L, // CFrescoMaidModule vtable[3]
            0x10070730L, // CFrescoMaidModule vtable[4]
            0x100706c0L, // CFrescoMaidModule vtable[5]
            0x10070650L, // CFrescoMaidModule vtable[6]
            0x10074f30L, // CFrescoMaidModule vtable[8]
            0x100707f0L, // CFrescoMaidModule vtable[11]
            0x10074050L, // CFrescoMaidModule vtable[16]
            0x10073a40L, // CFrescoMaidModule vtable[18]
            0x10070510L, // CFrescoMaidModule vtable[17]
            0x100742d0L, // CFrescoMaidModule vtable[15]
        };

        for (long addr : maidAddrs) {
            Address a = toAddr(addr);
            Function f = fm.getFunctionAt(a);
            if (f == null) f = fm.getFunctionContaining(a);
            if (f != null) decompFunc(f);
            else out.println("// No function at 0x" + Long.toHexString(addr));
        }

        // MAID wrapper calls in 0x100B2xxx range
        out.println("\n=== MAID WRAPPER FUNCTIONS (0x100B region) ===\n");
        long[] maidWrapAddrs = {
            0x100B2700L, 0x100B278DL, 0x100B28FEL, 0x100B2987L,
            0x100B2AE7L, 0x100B335EL, 0x100B33F9L, 0x100B355EL,
            0x100B35F3L, 0x100B368BL, 0x100B37F2L, 0x100B388AL,
            0x100B39F1L, 0x100B4225L,
        };
        Set<Long> decompiled = new HashSet<>();
        for (long addr : maidWrapAddrs) {
            Address a = toAddr(addr);
            Function f = fm.getFunctionContaining(a);
            if (f != null && !decompiled.contains(f.getEntryPoint().getOffset())) {
                decompFunc(f);
                decompiled.add(f.getEntryPoint().getOffset());
            }
        }

        // Command Queue classes
        out.println("\n=== COMMAND QUEUE DECOMPILATIONS ===\n");
        // CCommandQueue vtable should be near its RTTI
        // Let me find CCommandQueue RTTI and trace to vtable
        // RTTI at 0x10162364 ".?AVCCommandQueue@@"
        // TypeDescriptor at 0x1016235c

        // Instead of RTTI tracing, let me find typical command queue functions
        // by looking at functions in specific address ranges
        // The CProcessCommand and CCommandQueue classes are likely near each other

        // Decompile all functions between 0x10087000-0x1008C000 (typical MFC command range)
        out.println("--- Functions in 0x10087000-0x1008C000 range ---");
        FunctionIterator fiter = fm.getFunctions(toAddr(0x10087000L), true);
        int count = 0;
        while (fiter.hasNext() && count < 40) {
            Function f = fiter.next();
            if (f.getEntryPoint().getOffset() > 0x1008C000L) break;
            if (f.getBody().getNumAddresses() > 20 && f.getBody().getNumAddresses() < 1000) {
                decompFunc(f);
                count++;
            }
        }

        // Also get CQueueAcquireImage functions
        out.println("\n--- CQueueAcquireImage and related ---");
        // Search for functions that call StartScan-like operations
        // The scan workflow likely goes through CQueueAcquireImage

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
                out.println("// Decompilation failed");
            }
        } catch (Exception e) {
            out.println("// Error: " + e.getMessage());
        }
    }
}
