// Trace MAID capability → SCSI command chain in LS5000.md3
// Decompile: capability factory, scan operation controller, SET WINDOW param builders
// @category Analysis

import ghidra.app.script.GhidraScript;
import ghidra.app.decompiler.DecompInterface;
import ghidra.app.decompiler.DecompileResults;
import ghidra.program.model.listing.*;
import ghidra.program.model.address.*;
import java.io.*;
import java.util.*;

public class trace_scan_sequences extends GhidraScript {
    private DecompInterface decomp;
    private PrintWriter out;
    private Set<Long> decompiled = new HashSet<>();

    @Override
    public void run() throws Exception {
        String outputPath = System.getProperty("user.dir") + "/ghidra/exports/ls5000_scan_sequences.txt";
        out = new PrintWriter(new FileWriter(outputPath));
        decomp = new DecompInterface();
        decomp.openProgram(currentProgram);

        // === 1. Capability Object Factory ===
        out.println("=== CAPABILITY OBJECT FACTORY ===");
        decompAt(0x10053bc0L, "FUN_10053bc0 - capability object factory (creates cap objects with vtables)");
        decompAt(0x10053c90L, "FUN_10053c90 - capability object deregistration");

        // === 2. Scan Operation Controller (opcode 10 path) ===
        // These are the functions that orchestrate SCSI command sequences
        out.println("\n=== SCAN OPERATION CONTROLLER ===");
        // FUN_100275d0 is opcode 10 handler - already have it but need callees
        // Let's get the functions it calls
        decompAt(0x10054580L, "FUN_10054580 - called from opcode 10 handler (scan start completion)");
        decompAt(0x1001b490L, "FUN_1001b490 - creates capability 0x8005 (scan params) - called in multiple handlers");

        // === 3. SET WINDOW Parameter Building ===
        // These should be where MAID capabilities translate to SCSI SET WINDOW fields
        out.println("\n=== SET WINDOW PARAMETER BUILDING ===");
        // SET WINDOW factory is at 0x100aa400, builder at 0x100aa650
        // But the data that goes INTO SET WINDOW must come from somewhere
        // Let's look at functions that call the SET WINDOW factory
        // From Phase 2, scan ops are in 0x100b3c00-0x100b4c00 range
        decompAt(0x100b3c00L, "Scan ops area - check if SET WINDOW sequence start");
        decompAt(0x100b3d00L, "Scan ops area");
        decompAt(0x100b3e00L, "Scan ops area");
        decompAt(0x100b3f00L, "Scan ops area");
        decompAt(0x100b4000L, "Scan ops area");
        decompAt(0x100b4100L, "Scan ops area");
        decompAt(0x100b4200L, "Scan ops area");
        decompAt(0x100b4300L, "Scan ops area");
        decompAt(0x100b4400L, "Scan ops area");
        decompAt(0x100b4500L, "Scan ops area");
        decompAt(0x100b4600L, "Scan ops area");
        decompAt(0x100b4700L, "Scan ops area");

        // === 4. Functions near SET WINDOW factory ===
        out.println("\n=== SET WINDOW AREA ===");
        decompAt(0x100aa400L, "SET WINDOW factory");
        decompAt(0x100aa650L, "SET WINDOW CDB builder");

        // === 5. SCAN (0x1B) and related ===
        out.println("\n=== SCAN COMMAND AND SEQUENCES ===");
        decompAt(0x100aa540L, "SCAN factory");
        decompAt(0x100aa6d0L, "SCAN CDB builder");

        // === 6. Capability object vtable handlers ===
        // These are the per-capability-type handlers called when opcode 6 (set) is dispatched
        // through FUN_100273a0 → cap_object_vtable[method]
        // We need to find what vtables FUN_10053bc0 installs
        out.println("\n=== CAPABILITY OBJECT INTERNALS ===");
        // Near the factory at 0x10053bc0, look for constructors
        decompAt(0x10053a00L, "Near cap factory - possible cap object constructor");
        decompAt(0x10053a80L, "Near cap factory - possible cap object method");
        decompAt(0x10053b00L, "Near cap factory - possible cap object method");
        decompAt(0x10053b40L, "Near cap factory - possible cap object method");
        decompAt(0x10053b80L, "Near cap factory - possible cap object method");

        // === 7. Scan data flow functions ===
        out.println("\n=== SCAN DATA FLOW ===");
        // Inline READ(10) sites from Phase 2 KB
        decompAt(0x10086600L, "Near scan data read path 0x100866d9");
        decompAt(0x10086d00L, "Near scan data read path 0x10086dfa");
        decompAt(0x10087800L, "Near scan data read path 0x1008781a");

        // === 8. Init/open sequence ===
        out.println("\n=== INIT/OPEN SEQUENCE ===");
        // FUN_10028560 is opcode 0 (open/init) - already have it
        // But let's get its main callee FUN_10028150
        decompAt(0x10028150L, "FUN_10028150 - called from open handler (init sequence)");

        // === 9. Focus/autofocus area ===
        out.println("\n=== FOCUS / AUTOFOCUS ===");
        // Vendor E0/E1 commands are for focus/exposure
        // Look for functions calling E0/E1 factories
        decompAt(0x100aa4c0L, "Vendor 0xE0 factory (focus/exposure write)");
        decompAt(0x100aa500L, "Vendor 0xE1 factory (focus/exposure read)");
        decompAt(0x100aa580L, "Vendor 0xC1 factory (control trigger)");

        // === 10. Film advance / motor control ===
        out.println("\n=== FILM ADVANCE / MOTOR CONTROL ===");
        // These likely use MODE SELECT or vendor commands
        // MODE SELECT v1 (Group A) factory at 0x100aa1d0 area
        decompAt(0x100aa2a0L, "TUR factory");

        out.println("\n=== DONE ===");
        out.close();
        decomp.dispose();
        println("Output: " + outputPath);
    }

    private void decompAt(long addr, String desc) {
        FunctionManager fm = currentProgram.getFunctionManager();
        Function f = fm.getFunctionAt(toAddr(addr));
        if (f == null) f = fm.getFunctionContaining(toAddr(addr));
        if (f != null) {
            if (decompiled.contains(f.getEntryPoint().getOffset())) {
                out.println(String.format("\n// Already decompiled: %s @ 0x%08X [%s]",
                    f.getName(), f.getEntryPoint().getOffset(), desc));
                return;
            }
            out.println(String.format("\n// --- %s ---", desc));
            decompFunc(f);
        } else {
            out.println(String.format("\n// --- %s ---", desc));
            out.println(String.format("// No function at 0x%08X, creating...", addr));
            try {
                createFunction(toAddr(addr), null);
                f = fm.getFunctionAt(toAddr(addr));
                if (f != null) {
                    decompFunc(f);
                } else {
                    out.println("// Could not create function");
                }
            } catch (Exception e) {
                out.println("// Error creating function: " + e.getMessage());
            }
        }
    }

    private void decompFunc(Function f) {
        if (f == null) return;
        decompiled.add(f.getEntryPoint().getOffset());
        out.println(String.format("// === %s @ 0x%08X (%d bytes) ===",
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
