// Find CTwainMaidImage and CMaidBase vtables from their RTTI TypeDescriptors
// Then decompile vtable entries at offsets 0x5c (cap set/get) and 0xbc (cap exists check)
// @category Analysis

import ghidra.app.script.GhidraScript;
import ghidra.app.decompiler.DecompInterface;
import ghidra.app.decompiler.DecompileResults;
import ghidra.program.model.listing.*;
import ghidra.program.model.address.*;
import ghidra.program.model.mem.Memory;
import java.io.*;
import java.util.*;

public class find_ctm_vtable extends GhidraScript {
    private DecompInterface decomp;
    private PrintWriter out;
    private Set<Long> decompiled = new HashSet<>();
    private Memory mem;

    @Override
    public void run() throws Exception {
        String outputPath = System.getProperty("user.dir") + "/ghidra/exports/nikonscan4_ctm_vtable.txt";
        out = new PrintWriter(new FileWriter(outputPath));
        decomp = new DecompInterface();
        decomp.openProgram(currentProgram);
        mem = currentProgram.getMemory();
        FunctionManager fm = currentProgram.getFunctionManager();

        // TypeDescriptor addresses for our target classes
        long[] typeDescs = {
            0x10162718L, // CMaidBase
            0x10162730L, // CTwainMaidImage
        };
        String[] names = {"CMaidBase", "CTwainMaidImage"};

        for (int i = 0; i < typeDescs.length; i++) {
            out.println("=== Tracing " + names[i] + " (TypeDescriptor @ 0x" +
                Long.toHexString(typeDescs[i]) + ") ===");

            // Search for references to this TypeDescriptor in .rdata section
            // COL has TypeDescriptor ptr at offset +12
            long tdAddr = typeDescs[i];
            long searchStart = 0x10130000L;
            long searchEnd = 0x10170000L;

            List<Long> colAddrs = new ArrayList<>();
            for (long addr = searchStart; addr < searchEnd; addr += 4) {
                try {
                    int val = mem.getInt(toAddr(addr));
                    if (val == (int)tdAddr) {
                        // Check if this is at offset +12 of a COL
                        // COL structure: [signature(4), offset(4), cdOffset(4), typeDesc(4), classHier(4)]
                        long colStart = addr - 12;
                        int sig = mem.getInt(toAddr(colStart));
                        if (sig == 0) { // COL signature is 0 for non-virtual inheritance
                            colAddrs.add(colStart);
                            out.println("  Found COL at 0x" + Long.toHexString(colStart));
                        }
                    }
                } catch (Exception e) {}
            }

            // For each COL, find the vtable that references it
            // Vtable[-1] = COL pointer, so search for COL address references
            for (long colAddr : colAddrs) {
                for (long addr = searchStart; addr < searchEnd; addr += 4) {
                    try {
                        int val = mem.getInt(toAddr(addr));
                        if (val == (int)colAddr) {
                            long vtableStart = addr + 4; // vtable starts right after COL ptr
                            out.println("  Found vtable at 0x" + Long.toHexString(vtableStart) +
                                " (COL ptr at 0x" + Long.toHexString(addr) + ")");

                            // Read and dump vtable entries
                            int maxEntries = 60; // CTwainMaidImage could have many entries
                            for (int e = 0; e < maxEntries; e++) {
                                long entryAddr = vtableStart + e * 4;
                                int funcAddr = mem.getInt(toAddr(entryAddr));
                                // Stop if we hit a non-code address
                                if (funcAddr < 0x10001000 || funcAddr > 0x10130000) break;
                                Function f = fm.getFunctionContaining(toAddr(funcAddr));
                                String fname = (f != null) ? f.getName() : "???";
                                int fsize = (f != null) ? (int)f.getBody().getNumAddresses() : 0;
                                out.println(String.format("    [%d] +0x%03X = 0x%08X (%s, %d bytes)",
                                    e, e*4, funcAddr, fname, fsize));
                            }

                            // Decompile key vtable entries
                            // Entry 23 (offset 0x5c) = cap set/get call
                            // Entry 47 (offset 0xbc) = cap exists check
                            int[] keyEntries = {0, 1, 2, 3, 4, 5, 10, 15, 20, 23, 30, 35, 40, 47, 50};
                            for (int ke : keyEntries) {
                                long eAddr = vtableStart + ke * 4;
                                try {
                                    int funcAddrI = mem.getInt(toAddr(eAddr));
                                    if (funcAddrI >= 0x10001000 && funcAddrI <= 0x10130000) {
                                        Function f = fm.getFunctionAt(toAddr(funcAddrI));
                                        if (f == null) f = fm.getFunctionContaining(toAddr(funcAddrI));
                                        if (f != null && !decompiled.contains(f.getEntryPoint().getOffset())) {
                                            out.println(String.format(
                                                "\n--- Decompiling vtable[%d] (offset 0x%03X) ---", ke, ke*4));
                                            decompFunc(f);
                                        }
                                    }
                                } catch (Exception e2) {}
                            }
                        }
                    } catch (Exception e) {}
                }
            }
            out.println();
        }

        // Also decompile the MAID call wrapper FUN_1007a1f0 for reference
        out.println("\n=== CFrescoMaidModule::CallMAID (FUN_1007a1f0) ===");
        decompFunc(fm.getFunctionAt(toAddr(0x1007a1f0L)));

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
