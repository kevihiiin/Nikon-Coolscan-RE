// Dump all function names, addresses, sizes, and signatures from the Ghidra project
// Usage: analyzeHeadless <proj_dir> <proj_name> -process -scriptPath <dir> -postScript dump_all_functions.java <output>

import ghidra.app.script.GhidraScript;
import ghidra.program.model.listing.*;
import ghidra.program.model.address.*;
import ghidra.program.model.symbol.*;
import java.io.*;
import java.util.*;

public class dump_all_functions extends GhidraScript {
    @Override
    public void run() throws Exception {
        String[] args = getScriptArgs();
        if (args.length < 1) {
            println("Usage: dump_all_functions.java <output_file>");
            return;
        }

        PrintWriter out = new PrintWriter(new BufferedWriter(new FileWriter(args[0])));
        FunctionManager fm = currentProgram.getFunctionManager();

        out.println("// Nikon LS-50 Firmware — All Functions");
        out.println("// Total functions: " + fm.getFunctionCount());
        out.println();
        out.println("// Address    | Size | Name                          | Signature");
        out.println("// -----------+------+-------------------------------+------------------------------------------");

        FunctionIterator iter = fm.getFunctions(true);
        int count = 0;
        while (iter.hasNext()) {
            Function func = iter.next();
            long addr = func.getEntryPoint().getOffset();
            long size = func.getBody().getNumAddresses();
            String name = func.getName();
            String sig = func.getPrototypeString(false, false);

            // Get callers/callees count
            int callerCount = func.getCallingFunctions(monitor).size();
            int calleeCount = func.getCalledFunctions(monitor).size();

            out.printf("0x%06X  %5d  %-40s  callers=%d callees=%d  %s%n",
                addr, size, name, callerCount, calleeCount, sig);
            count++;
        }

        out.println();
        out.println("// Total: " + count + " functions");
        out.close();
        println("Dumped " + count + " functions to " + args[0]);
    }
}
