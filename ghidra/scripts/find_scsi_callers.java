// Find all callers of SCSI command factories in LS5000.md3
// This reveals the scan sequence orchestration functions
// @category Analysis

import ghidra.app.script.GhidraScript;
import ghidra.app.decompiler.DecompInterface;
import ghidra.app.decompiler.DecompileResults;
import ghidra.program.model.listing.*;
import ghidra.program.model.address.*;
import ghidra.program.model.symbol.*;
import java.io.*;
import java.util.*;

public class find_scsi_callers extends GhidraScript {
    private PrintWriter out;
    private DecompInterface decomp;
    private Set<Long> decompiled = new HashSet<>();

    @Override
    public void run() throws Exception {
        String outputPath = System.getProperty("user.dir") + "/ghidra/exports/ls5000_scsi_callers.txt";
        out = new PrintWriter(new FileWriter(outputPath));
        decomp = new DecompInterface();
        decomp.openProgram(currentProgram);
        FunctionManager fm = currentProgram.getFunctionManager();
        ReferenceManager rm = currentProgram.getReferenceManager();

        // SCSI command factories from Phase 2 KB
        String[][] factories = {
            {"0x100aa2a0", "TUR_factory"},
            {"0x100aa2e0", "INQUIRY_factory"},
            {"0x100aa400", "SET_WINDOW_factory"},
            {"0x100aa3b0", "GET_WINDOW_factory"},
            {"0x100aa540", "SCAN_factory"},
            {"0x100aa4c0", "VENDOR_E0_factory"},
            {"0x100aa500", "VENDOR_E1_factory"},
            {"0x100aa580", "VENDOR_C1_factory"},
            {"0x100aa330", "RESERVE_factory"},
            {"0x100aa440", "MODE_SELECT_v2_factory"},
            {"0x100aa370", "SEND_DIAG_B_factory"},
            {"0x100b5000", "READ10_factory_1"},
            {"0x100b5060", "READ10_factory_2"},
            {"0x100b50c0", "WRITE10_factory"},
            {"0x100b5110", "READ_BUFFER_factory"},
            {"0x100b5160", "WRITE_BUFFER_factory"},
        };

        Set<Long> callerFunctions = new LinkedHashSet<>();

        for (String[] factory : factories) {
            long addr = Long.parseLong(factory[0].substring(2), 16);
            String name = factory[1];
            out.println(String.format("=== %s @ 0x%08X ===", name, addr));

            // Find all references to this address
            Reference[] refs = rm.getReferencesTo(toAddr(addr));
            if (refs.length == 0) {
                out.println("  No references found\n");
                continue;
            }

            for (Reference ref : refs) {
                Address fromAddr = ref.getFromAddress();
                Function caller = fm.getFunctionContaining(fromAddr);
                if (caller != null) {
                    out.println(String.format("  Called from: %s @ 0x%08X (ref at 0x%08X, type=%s)",
                        caller.getName(), caller.getEntryPoint().getOffset(),
                        fromAddr.getOffset(), ref.getReferenceType()));
                    callerFunctions.add(caller.getEntryPoint().getOffset());
                } else {
                    out.println(String.format("  Called from: <no func> at 0x%08X (type=%s)",
                        fromAddr.getOffset(), ref.getReferenceType()));
                }
            }
            out.println();
        }

        // Now decompile the unique caller functions (these are the scan sequence orchestrators)
        out.println("\n=== DECOMPILED CALLER FUNCTIONS ===\n");
        for (Long callerAddr : callerFunctions) {
            Function f = fm.getFunctionAt(toAddr(callerAddr));
            if (f != null && !decompiled.contains(callerAddr)) {
                decompFunc(f);
            }
        }

        out.println("\n=== DONE ===");
        out.close();
        decomp.dispose();
        println("Output: " + outputPath);
    }

    private void decompFunc(Function f) {
        if (f == null) return;
        long addr = f.getEntryPoint().getOffset();
        decompiled.add(addr);
        out.println(String.format("// === %s @ 0x%08X (%d bytes) ===",
            f.getName(), addr, f.getBody().getNumAddresses()));
        try {
            DecompileResults res = decomp.decompileFunction(f, 30, monitor);
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
