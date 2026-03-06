// Decompile the LS5000.md3 eject/film advance MAID handlers
// @category Analysis

import ghidra.app.script.GhidraScript;
import ghidra.app.decompiler.DecompInterface;
import ghidra.app.decompiler.DecompileResults;
import ghidra.program.model.listing.*;
import java.io.*;
import java.util.*;

public class decompile_eject_maid extends GhidraScript {
    private DecompInterface decomp;
    private PrintWriter out;
    private Set<Long> done = new HashSet<>();

    @Override
    public void run() throws Exception {
        String outputPath = System.getProperty("user.dir") + "/ghidra/exports/ls5000_eject_maid.txt";
        out = new PrintWriter(new FileWriter(outputPath));
        decomp = new DecompInterface();
        decomp.openProgram(currentProgram);

        out.println("=== LS5000 EJECT/FILM MAID HANDLERS ===");
        
        // MAIDEntryPoint cases 5-9, 13 capability dispatcher
        decompAt(0x100273a0L, "FUN_100273a0 - capability object dispatcher (555 bytes)");
        
        // MAIDEntryPoint case 10 - start operation
        decompAt(0x100275d0L, "FUN_100275d0 - start operation (574 bytes)");
        
        // MAID capability object helpers
        decompAt(0x1001b490L, "FUN_1001b490 - find capability in tree");
        
        // Functions near the scan operations that might handle eject
        // The MAID eject would create a scan operation type (probably Type C or specific)
        decompAt(0x100b45c0L, "FUN_100b45c0 - scan operation constructor (type codes)");
        
        // SEND DIAGNOSTIC factory (used by multiple operations including init)
        decompAt(0x100aa540L, "FUN_100aa540 - SEND_DIAG CDB builder");
        
        // Film transport would likely use SEND DIAGNOSTIC with specific payload
        // Let's check what SEND_DIAG callers exist outside of scan operations
        decompAt(0x100af1f0L, "FUN_100af1f0 - init factory (has SEND_DIAG case 0x1D)");
        
        // Also look at the main execute function that sends SCSI
        decompAt(0x100ae3c0L, "FUN_100ae3c0 - core SCSI execute");

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
