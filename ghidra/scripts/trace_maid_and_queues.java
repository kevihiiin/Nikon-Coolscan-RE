// Ghidra script: Find MAID call chain and command queue classes in NikonScan4.ds
// @category Analysis

import ghidra.app.script.GhidraScript;
import ghidra.app.decompiler.DecompInterface;
import ghidra.app.decompiler.DecompileResults;
import ghidra.program.model.listing.*;
import ghidra.program.model.address.*;
import ghidra.program.model.symbol.*;
import ghidra.program.model.data.*;
import ghidra.program.model.mem.*;
import java.io.*;
import java.util.*;

public class trace_maid_and_queues extends GhidraScript {
    private DecompInterface decomp;
    private PrintWriter out;

    @Override
    public void run() throws Exception {
        String outputPath = System.getProperty("user.dir") + "/ghidra/exports/nikonscan4_maid_queues.txt";
        out = new PrintWriter(new FileWriter(outputPath));
        decomp = new DecompInterface();
        decomp.openProgram(currentProgram);
        FunctionManager fm = currentProgram.getFunctionManager();

        // === Section 1: Find all functions that reference the MAID function pointer ===
        // The MAIDEntryPoint ptr is at [object + 0x74]
        // Search for "call dword [reg + 0x74]" pattern
        out.println("=== FUNCTIONS CALLING THROUGH OFFSET 0x74 (MAID) ===");
        Memory mem = currentProgram.getMemory();
        Address textStart = toAddr(0x10001000L);
        Address textEnd = toAddr(0x1012F000L);

        // Search for ff 51 74 (call [ecx+0x74]) and ff 52 74 (call [edx+0x74])
        byte[][] patterns = {
            {(byte)0xff, (byte)0x51, (byte)0x74},  // call [ecx+0x74]
            {(byte)0xff, (byte)0x52, (byte)0x74},  // call [edx+0x74]
            {(byte)0xff, (byte)0x53, (byte)0x74},  // call [ebx+0x74]
            {(byte)0xff, (byte)0x56, (byte)0x74},  // call [esi+0x74]
            {(byte)0xff, (byte)0x57, (byte)0x74},  // call [edi+0x74]
            {(byte)0xff, (byte)0x90, (byte)0x74, (byte)0x00, (byte)0x00, (byte)0x00},  // call [eax+0x74]
        };
        // Also search for call [reg+0x74] with SIB: ff 54 .. 74
        // And indirect: mov reg, [obj+0x74]; call reg

        // Simple approach: search for the byte pattern FF xx 74 in .text
        Address searchAddr = textStart;
        while (searchAddr != null && searchAddr.compareTo(textEnd) < 0) {
            searchAddr = mem.findBytes(searchAddr, textEnd, new byte[]{(byte)0xff}, null, true, monitor);
            if (searchAddr == null) break;
            try {
                byte nextByte = mem.getByte(searchAddr.add(1));
                byte offsetByte = mem.getByte(searchAddr.add(2));
                if (offsetByte == 0x74 && (nextByte >= 0x50 && nextByte <= 0x57)) {
                    Function f = fm.getFunctionContaining(searchAddr);
                    String fname = f != null ? f.getName() + " @ " + f.getEntryPoint() : "unknown";
                    out.println(String.format("  0x%08X: call [reg+0x74] in %s", searchAddr.getOffset(), fname));
                }
            } catch (Exception e) {}
            searchAddr = searchAddr.add(1);
        }

        // === Section 2: Decompile functions that contain "Command" or "Queue" RTTI ===
        out.println("\n=== COMMAND QUEUE RELATED FUNCTIONS ===");
        // Find all functions with size 50-500 bytes in the 0x10088000 - 0x1009C000 range
        // (typical area for these classes based on vtable analysis)

        // First, let's find the RTTI strings and their vtables
        out.println("\n--- RTTI Classes with 'Command' or 'Queue' ---");
        String[] rttiPatterns = {"Command", "Queue", "Process", "Acquire", "Maid"};
        Address dataStart = toAddr(0x10130000L);
        Address dataEnd = toAddr(0x10166000L);

        for (String pat : rttiPatterns) {
            searchAddr = dataStart;
            byte[] patBytes = (".?AVC" + pat).getBytes();
            while (searchAddr != null && searchAddr.compareTo(dataEnd) < 0) {
                searchAddr = mem.findBytes(searchAddr, dataEnd, patBytes, null, true, monitor);
                if (searchAddr == null) break;
                // Read the full RTTI name
                StringBuilder sb = new StringBuilder();
                Address strAddr = searchAddr;
                while (true) {
                    byte b = mem.getByte(strAddr);
                    if (b == 0) break;
                    sb.append((char)b);
                    strAddr = strAddr.add(1);
                }
                out.println(String.format("  RTTI: %s at 0x%08X", sb.toString(), searchAddr.getOffset()));
                searchAddr = searchAddr.add(1);
            }
        }

        // === Section 3: Decompile the CFrescoMaidModule and CFrescoMaidSource classes ===
        out.println("\n=== MAID MODULE/SOURCE VTABLE FUNCTIONS ===");

        // Find CFrescoMaidModule RTTI
        Address fmmRtti = mem.findBytes(dataStart, dataEnd, ".?AVCFrescoMaidModule@@".getBytes(), null, true, monitor);
        if (fmmRtti != null) {
            out.println("CFrescoMaidModule RTTI at: 0x" + Long.toHexString(fmmRtti.getOffset()));
            // TypeDescriptor is at fmmRtti - 8
            Address typeDesc = fmmRtti.subtract(8);
            out.println("TypeDescriptor at: 0x" + Long.toHexString(typeDesc.getOffset()));

            // Find COL referencing this TypeDescriptor
            byte[] tdBytes = new byte[4];
            tdBytes[0] = (byte)(typeDesc.getOffset() & 0xFF);
            tdBytes[1] = (byte)((typeDesc.getOffset() >> 8) & 0xFF);
            tdBytes[2] = (byte)((typeDesc.getOffset() >> 16) & 0xFF);
            tdBytes[3] = (byte)((typeDesc.getOffset() >> 24) & 0xFF);

            Address colRef = mem.findBytes(dataStart, dataEnd, tdBytes, null, true, monitor);
            while (colRef != null) {
                // Check if this is at offset +12 in a COL (signature=0, offset, cdOffset, typeDesc)
                Address colStart = colRef.subtract(12);
                try {
                    int sig = mem.getInt(colStart);
                    int offset = mem.getInt(colStart.add(4));
                    if (sig == 0 && offset == 0) {
                        out.println("Primary COL at: 0x" + Long.toHexString(colStart.getOffset()));
                        // Find vtable[-1] pointing to this COL
                        byte[] colBytes = new byte[4];
                        colBytes[0] = (byte)(colStart.getOffset() & 0xFF);
                        colBytes[1] = (byte)((colStart.getOffset() >> 8) & 0xFF);
                        colBytes[2] = (byte)((colStart.getOffset() >> 16) & 0xFF);
                        colBytes[3] = (byte)((colStart.getOffset() >> 24) & 0xFF);
                        Address vtRef = mem.findBytes(dataStart, dataEnd, colBytes, null, true, monitor);
                        if (vtRef != null) {
                            Address vtableStart = vtRef.add(4);
                            out.println("Vtable starts at: 0x" + Long.toHexString(vtableStart.getOffset()));
                            // Read first 20 vtable entries
                            for (int i = 0; i < 20; i++) {
                                int entry = mem.getInt(vtableStart.add(i * 4));
                                if (entry >= 0x10001000 && entry < 0x1012F000) {
                                    Function f = fm.getFunctionAt(toAddr(entry));
                                    String name = f != null ? f.getName() : "???";
                                    out.println(String.format("  vtable[%d] = 0x%08X (%s)", i, entry, name));
                                } else {
                                    out.println(String.format("  vtable[%d] = 0x%08X (NOT CODE - vtable ends)", i, entry));
                                    break;
                                }
                            }
                        }
                    }
                } catch (Exception e) {}
                colRef = mem.findBytes(colRef.add(1), dataEnd, tdBytes, null, true, monitor);
            }
        }

        // === Section 4: Find MAID call sites by searching for call patterns ===
        out.println("\n=== POTENTIAL MAID ENTRYPOINT CALL SITES ===");
        // Search for pattern: push <constant> followed by call [reg+0x74]
        // MAID operations start with a case number (0=Open, 1=Close, etc.)
        searchAddr = textStart;
        int maidCallCount = 0;
        while (searchAddr != null && searchAddr.compareTo(textEnd) < 0 && maidCallCount < 50) {
            searchAddr = mem.findBytes(searchAddr, textEnd, new byte[]{(byte)0xff, (byte)0x56, (byte)0x74}, null, true, monitor);
            if (searchAddr == null) break;
            Function f = fm.getFunctionContaining(searchAddr);
            if (f != null && !f.getName().startsWith("FUN_")) {
                out.println(String.format("  0x%08X: call [esi+0x74] in %s @ 0x%08X",
                    searchAddr.getOffset(), f.getName(), f.getEntryPoint().getOffset()));
                maidCallCount++;
            } else if (f != null) {
                out.println(String.format("  0x%08X: call [esi+0x74] in %s",
                    searchAddr.getOffset(), f.getName()));
                maidCallCount++;
            }
            searchAddr = searchAddr.add(1);
        }

        // === Section 5: Decompile key queue functions ===
        out.println("\n=== KEY QUEUE FUNCTION DECOMPILATIONS ===");
        // Find functions containing "CommandQueue" in their vicinity
        long[] queueAddrs = {
            // Based on RTTI, these should be near the vtables
            // Let me just search for large functions in typical areas
        };

        // Instead, decompile functions that are referenced frequently
        // Let me find the CCommandQueue constructor
        // Search for the vtable pointer store pattern for CCommandQueue

        out.println("\n=== DONE ===");
        out.close();
        decomp.dispose();
        println("Output: " + outputPath);
    }
}
