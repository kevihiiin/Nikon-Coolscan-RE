// Decompile the central SCSI scan sequence orchestrator at 0x100b3b10
// and related scan operation functions in LS5000.md3
// @category Analysis

import ghidra.app.script.GhidraScript;
import ghidra.app.decompiler.DecompInterface;
import ghidra.app.decompiler.DecompileResults;
import ghidra.program.model.listing.*;
import ghidra.program.model.address.*;
import java.io.*;
import java.util.*;

public class decompile_scan_controller extends GhidraScript {
    private DecompInterface decomp;
    private PrintWriter out;
    private Set<Long> done = new HashSet<>();

    @Override
    public void run() throws Exception {
        String outputPath = System.getProperty("user.dir") + "/ghidra/exports/ls5000_scan_controller.txt";
        out = new PrintWriter(new FileWriter(outputPath));
        decomp = new DecompInterface();
        decomp.openProgram(currentProgram);
        FunctionManager fm = currentProgram.getFunctionManager();

        // Key addresses to decompile
        long[] targets = {
            0x100b3b10L,  // MAIN SCAN SEQUENCE (2736 bytes, 15 SCSI calls)
            0x100b4a40L,  // Secondary scan function (calls SET WINDOW)
            0x100b29b0L,  // Called from FUN_100b3ff0 and FUN_100b45c0 (scan setup)
            0x100b0400L,  // Focus/autofocus area (calls E0, C1, E1)
            0x100b0e00L,  // Second focus area (calls E0, C1, E1, WRITE10)
            0x100af200L,  // Init area (calls TUR, INQUIRY, RESERVE, etc.)
            0x100aff00L,  // Area calling GET_WINDOW
            0x100b1900L,  // Area calling INQUIRY, SEND_DIAG, READ10
            0x100b2000L,  // Area calling INQUIRY
            0x100b2200L,  // Area calling TUR, INQUIRY, SEND_DIAG
            0x100b2700L,  // Area calling TUR, SEND_DIAG
            0x100adf00L,  // Area calling READ10, WRITE10 (calibration data?)
        };

        for (long addr : targets) {
            Function f = fm.getFunctionAt(toAddr(addr));
            if (f == null) f = fm.getFunctionContaining(toAddr(addr));
            if (f != null && !done.contains(f.getEntryPoint().getOffset())) {
                out.println(String.format("// --- Function containing 0x%08X ---", addr));
                doDecomp(f);
            } else if (f == null) {
                out.println(String.format("// --- No function at/containing 0x%08X, trying to create ---", addr));
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

        out.println("\n=== DONE ===");
        out.close();
        decomp.dispose();
        println("Output: " + outputPath);
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
