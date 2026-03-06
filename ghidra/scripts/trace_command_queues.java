// Trace CCommandQueue, CProcessCommand, CQueueAcquireImage vtables from RTTI
// @category Analysis

import ghidra.app.script.GhidraScript;
import ghidra.app.decompiler.DecompInterface;
import ghidra.app.decompiler.DecompileResults;
import ghidra.program.model.listing.*;
import ghidra.program.model.address.*;
import ghidra.program.model.mem.*;
import java.io.*;
import java.util.*;

public class trace_command_queues extends GhidraScript {
    private DecompInterface decomp;
    private PrintWriter out;
    private Memory mem;
    private FunctionManager fm;

    @Override
    public void run() throws Exception {
        String outputPath = System.getProperty("user.dir") + "/ghidra/exports/nikonscan4_command_queues.txt";
        out = new PrintWriter(new FileWriter(outputPath));
        decomp = new DecompInterface();
        decomp.openProgram(currentProgram);
        mem = currentProgram.getMemory();
        fm = currentProgram.getFunctionManager();

        Address dataStart = toAddr(0x10130000L);
        Address dataEnd = toAddr(0x10170000L);

        // Classes to trace
        String[] classes = {
            ".?AVCCommandQueue@@",
            ".?AVCCommandQueueManager@@",
            ".?AVCCommandQueuePtrWrapper@@",
            ".?AVCProcessCommand@@",
            ".?AVCProcessCommandManager@@",
            ".?AVCQueueAcquireImage@@",
            ".?AVCQueueAcquireDRAGImage@@",
            ".?AVCQueueNotifier@@",
            ".?AVCStoppableCommandQueue@@",
            ".?AVCFrescoTwainSource@@",
            ".?AVCFrescoMaidModule@@",
            ".?AVCFrescoMaidSource@@",
        };

        for (String className : classes) {
            out.println("\n====== " + className + " ======");
            traceClassVtable(className, dataStart, dataEnd);
        }

        // Also look for StartScan and scan workflow functions
        out.println("\n====== SCAN WORKFLOW FUNCTIONS ======");
        // Search for "StartScan" string references
        Address strAddr = mem.findBytes(toAddr(0x10130000L), toAddr(0x10170000L), "StartScan".getBytes(), null, true, monitor);
        if (strAddr != null) {
            out.println("\"StartScan\" string at: 0x" + Long.toHexString(strAddr.getOffset()));
        }
        strAddr = mem.findBytes(toAddr(0x10130000L), toAddr(0x10170000L), "Preview".getBytes(), null, true, monitor);
        if (strAddr != null) {
            out.println("\"Preview\" string at: 0x" + Long.toHexString(strAddr.getOffset()));
        }
        strAddr = mem.findBytes(toAddr(0x10130000L), toAddr(0x10170000L), "Eject".getBytes(), null, true, monitor);
        if (strAddr != null) {
            out.println("\"Eject\" string at: 0x" + Long.toHexString(strAddr.getOffset()));
        }
        strAddr = mem.findBytes(toAddr(0x10130000L), toAddr(0x10170000L), "AutoFocus".getBytes(), null, true, monitor);
        if (strAddr != null) {
            out.println("\"AutoFocus\" string at: 0x" + Long.toHexString(strAddr.getOffset()));
        }

        // Decompile the exported StartScan, CanEject, Eject, GetSource functions
        out.println("\n====== KEY EXPORTED FUNCTIONS ======");
        long[] exportAddrs = {
            0x1008c940L, // StartScan (from earlier export analysis)
            0x1008cbe0L, // GetSource
            0x1008c900L, // CanEject
            0x1008c910L, // Eject
        };
        for (long addr : exportAddrs) {
            Address a = toAddr(addr);
            Function f = fm.getFunctionAt(a);
            if (f == null) f = fm.getFunctionContaining(a);
            if (f != null) decompFunc(f);
        }

        // Find and decompile functions referencing CQueueAcquireImage constructor
        // Also look for large functions in the 0x100A0000-0x100B0000 range (scan workflow area)
        out.println("\n====== SCAN WORKFLOW AREA (0x100A-0x100B) ======");
        FunctionIterator fiter = fm.getFunctions(toAddr(0x100A0000L), true);
        int count = 0;
        while (fiter.hasNext() && count < 80) {
            Function f = fiter.next();
            if (f.getEntryPoint().getOffset() > 0x100B5000L) break;
            if (f.getBody().getNumAddresses() > 100) {
                decompFunc(f);
                count++;
            }
        }

        out.println("\n=== DONE ===");
        out.close();
        decomp.dispose();
        println("Output: " + outputPath);
    }

    private void traceClassVtable(String rttiName, Address dataStart, Address dataEnd) {
        try {
            Address rttiAddr = mem.findBytes(dataStart, dataEnd, rttiName.getBytes(), null, true, monitor);
            if (rttiAddr == null) {
                out.println("  RTTI not found: " + rttiName);
                return;
            }
            out.println("  RTTI string at: 0x" + Long.toHexString(rttiAddr.getOffset()));

            // TypeDescriptor is at rttiAddr - 8 (vfptr + spare)
            Address typeDesc = rttiAddr.subtract(8);
            out.println("  TypeDescriptor at: 0x" + Long.toHexString(typeDesc.getOffset()));

            // Find COL referencing this TypeDescriptor (at COL+12)
            byte[] tdBytes = intToBytes((int)typeDesc.getOffset());
            Address colRef = mem.findBytes(dataStart, dataEnd, tdBytes, null, true, monitor);
            while (colRef != null) {
                Address colStart = colRef.subtract(12);
                try {
                    int sig = mem.getInt(colStart);
                    int offset = mem.getInt(colStart.add(4));
                    if (sig == 0) {
                        out.println("  COL at: 0x" + Long.toHexString(colStart.getOffset()) + " (offset=" + offset + ")");
                        // Find vtable[-1] pointing to this COL
                        byte[] colBytes = intToBytes((int)colStart.getOffset());
                        Address vtRef = mem.findBytes(dataStart, dataEnd, colBytes, null, true, monitor);
                        while (vtRef != null) {
                            // Vtable starts right after the COL pointer
                            Address vtableStart = vtRef.add(4);
                            // Verify first entry is in code range
                            int firstEntry = mem.getInt(vtableStart);
                            if (firstEntry >= 0x10001000 && firstEntry < 0x1012F000) {
                                out.println("  Vtable at: 0x" + Long.toHexString(vtableStart.getOffset()) + " (COL ref at 0x" + Long.toHexString(vtRef.getOffset()) + ")");
                                // Read vtable entries
                                int numEntries = 0;
                                for (int i = 0; i < 30; i++) {
                                    int entry = mem.getInt(vtableStart.add(i * 4));
                                    if (entry < 0x10001000 || entry >= 0x1012F000) {
                                        break;
                                    }
                                    Function f = fm.getFunctionAt(toAddr(entry));
                                    String name = f != null ? f.getName() : "???";
                                    long size = f != null ? f.getBody().getNumAddresses() : 0;
                                    out.println(String.format("    vtable[%d] = 0x%08X (%s, %d bytes)", i, entry, name, size));
                                    numEntries++;
                                }
                                // Decompile the vtable functions
                                out.println("  --- Decompiling vtable methods ---");
                                Set<Long> decompiled = new HashSet<>();
                                for (int i = 0; i < numEntries && i < 30; i++) {
                                    int entry = mem.getInt(vtableStart.add(i * 4));
                                    Function f = fm.getFunctionAt(toAddr(entry));
                                    if (f != null && !decompiled.contains(f.getEntryPoint().getOffset())) {
                                        if (f.getBody().getNumAddresses() > 10) {
                                            decompFunc(f);
                                            decompiled.add(f.getEntryPoint().getOffset());
                                        }
                                    }
                                }
                            }
                            vtRef = mem.findBytes(vtRef.add(1), dataEnd, colBytes, null, true, monitor);
                        }
                    }
                } catch (Exception e) {}
                colRef = mem.findBytes(colRef.add(1), dataEnd, tdBytes, null, true, monitor);
            }
        } catch (Exception e) {
            out.println("  Error: " + e.getMessage());
        }
    }

    private byte[] intToBytes(int val) {
        return new byte[] {
            (byte)(val & 0xFF),
            (byte)((val >> 8) & 0xFF),
            (byte)((val >> 16) & 0xFF),
            (byte)((val >> 24) & 0xFF)
        };
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
