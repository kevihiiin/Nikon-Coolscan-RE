// Decompile the vendor extension list initialization in LS5000.md3
// to discover what MAID param IDs are in the vendor extension area
// @category Analysis

import ghidra.app.script.GhidraScript;
import ghidra.app.decompiler.DecompInterface;
import ghidra.app.decompiler.DecompileResults;
import ghidra.program.model.listing.*;
import java.io.*;
import java.util.*;

public class decompile_vendor_ext_init extends GhidraScript {
    private DecompInterface decomp;
    private PrintWriter out;
    private Set<Long> done = new HashSet<>();

    @Override
    public void run() throws Exception {
        String outputPath = System.getProperty("user.dir") + "/ghidra/exports/ls5000_vendor_ext_init.txt";
        out = new PrintWriter(new FileWriter(outputPath));
        decomp = new DecompInterface();
        decomp.openProgram(currentProgram);

        out.println("=== VENDOR EXTENSION PARAM LIST INITIALIZATION ===");
        
        // FUN_100a0370 - get vendor extension param ID by index
        decompAt(0x100a0370L, "FUN_100a0370 - get vendor param ID (iterator)");
        
        // FUN_100a0bc0 - get vendor extension data size by index
        decompAt(0x100a0bc0L, "FUN_100a0bc0 - get vendor param data size");
        
        // FUN_100a0360 - get total vendor extension size
        decompAt(0x100a0360L, "FUN_100a0360 - get total vendor ext size");
        
        // FUN_1009d730 - ICE/DRAG check
        decompAt(0x1009d730L, "FUN_1009d730 - ICE/DRAG support check");
        
        // FUN_1009fc20 - ICE/DRAG extension size
        decompAt(0x1009fc20L, "FUN_1009fc20 - ICE/DRAG ext size");
        
        // FUN_1009fce0 - ICE/DRAG param data size
        decompAt(0x1009fce0L, "FUN_1009fce0 - ICE/DRAG param size");
        
        // FUN_1009fc60 - ICE/DRAG param value
        decompAt(0x1009fc60L, "FUN_1009fc60 - ICE/DRAG param value");
        
        // Now trace where the vendor extension list at scanner_state+0x27c is populated
        // This is likely during scanner initialization. Let me find callers of the list builder.
        // FUN_100a02a0 or similar - the function that populates scanner_state+0x27c
        decompAt(0x100a02a0L, "FUN_100a02a0 - possible vendor list builder");
        decompAt(0x100a0300L, "FUN_100a0300 - possible vendor list init");
        
        // Film type related - check what MAID params correspond to film type
        // Film type in NikonScan4.ds is at source+0x1C, comes from GetFilmTypeItem
        // Let me check the scanner state initialization that creates the internal param list
        decompAt(0x1009c170L, "FUN_1009c170 - scanner state init (param list population)");
        decompAt(0x1009c2e0L, "FUN_1009c2e0 - following init function");
        decompAt(0x1009c400L, "FUN_1009c400 - possible param registration");
        decompAt(0x1009c530L, "FUN_1009c530 - possible param registration");
        
        // Also look at the specific param add function
        decompAt(0x1009c0c0L, "FUN_1009c0c0 - std::map tree lookup/insert");

        out.println("\n=== DONE ===");
        out.close();
        decomp.dispose();
        println("Output: " + outputPath);
    }

    private void decompAt(long addr, String desc) {
        FunctionManager fm = currentProgram.getFunctionManager();
        Function f = fm.getFunctionAt(toAddr(addr));
        if (f == null) f = fm.getFunctionContaining(toAddr(addr));
        if (f != null && !done.contains(f.getEntryPoint().getOffset())) {
            out.println(String.format("\n// --- %s ---", desc));
            done.add(f.getEntryPoint().getOffset());
            out.println(String.format("// === %s @ 0x%08X (%d bytes) ===",
                f.getName(), f.getEntryPoint().getOffset(), f.getBody().getNumAddresses()));
            try {
                DecompileResults res = decomp.decompileFunction(f, 60, monitor);
                if (res.decompileCompleted()) out.println(res.getDecompiledFunction().getC());
                else out.println("// Decompilation failed\n");
            } catch (Exception e) {
                out.println("// Error: " + e.getMessage() + "\n");
            }
        }
    }
}
