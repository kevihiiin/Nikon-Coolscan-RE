// dump_calibration.java -- Analyze calibration subsystem in LS-50 firmware
// Searches for: task table 05xx entries, debug labels, DAC/gain register accesses,
// flash write routines, calibration data patterns
//
// Run: analyzeHeadless ghidra/projects CoolscanFirmware -process "Nikon LS-50 MBM29F400B TSOP48.bin" -postScript dump_calibration.java -noanalysis -readOnly
//@category Nikon_Coolscan

import ghidra.app.script.GhidraScript;
import ghidra.program.model.address.*;
import ghidra.program.model.listing.*;
import ghidra.program.model.mem.*;
import ghidra.program.model.symbol.*;
import ghidra.program.model.lang.*;
import java.util.*;

public class dump_calibration extends GhidraScript {

    private Memory memory;
    private Listing listing;
    private AddressSpace addrSpace;

    @Override
    public void run() throws Exception {
        memory = currentProgram.getMemory();
        listing = currentProgram.getListing();
        addrSpace = currentProgram.getAddressFactory().getDefaultAddressSpace();

        println("==========================================================");
        println("CALIBRATION SUBSYSTEM ANALYSIS - Nikon LS-50 Firmware");
        println("==========================================================");
        println("");

        analyzeTaskTable();
        analyzeDebugLabels();
        analyzeDACRegisters();
        analyzeGainRegisters();
        analyzeFlashWrite();
        analyzeCalibrationData();
        analyzeCalibrationType3();
    }

    private Address addr(long offset) {
        return addrSpace.getAddress(offset);
    }

    private int readByte(long offset) throws Exception {
        return memory.getByte(addr(offset)) & 0xFF;
    }

    private int readShort(long offset) throws Exception {
        return memory.getShort(addr(offset)) & 0xFFFF;
    }

    private int readInt(long offset) throws Exception {
        return memory.getInt(addr(offset));
    }

    // ===== 1. Task Table Analysis (05xx calibration codes) =====
    private void analyzeTaskTable() throws Exception {
        println("=== SECTION 1: TASK TABLE ENTRIES (0x05xx = Calibration) ===");
        println("");

        long tableBase = 0x49910;
        int entryCount = 93;

        // Parse all entries, highlight 05xx
        println("Full task table (93 entries at 0x49910):");
        println("Offset     Code    Handler_Idx  Category");
        println("-------    ------  -----------  --------");

        Map<Integer, List<String>> byPrefix = new TreeMap<>();
        List<String> calEntries = new ArrayList<>();

        for (int i = 0; i < entryCount; i++) {
            long entryAddr = tableBase + i * 4;
            int code = readShort(entryAddr);
            int idx = readShort(entryAddr + 2);
            int prefix = (code >> 8) & 0xFF;

            String category = getCategoryName(prefix);
            String line = String.format("0x%05X  0x%04X    0x%04X     %s", entryAddr, code, idx, category);

            byPrefix.computeIfAbsent(prefix, k -> new ArrayList<>()).add(line);

            if (prefix == 0x05) {
                calEntries.add(line);
                println("** " + line);
            }
        }

        println("");
        println("--- Calibration entries (0x05xx) ---");
        for (String e : calEntries) {
            println("  " + e);
        }

        println("");
        println("--- Task code category summary ---");
        for (Map.Entry<Integer, List<String>> entry : byPrefix.entrySet()) {
            println(String.format("  0x%02Xxx: %d entries (%s)", entry.getKey(), entry.getValue().size(),
                    getCategoryName(entry.getKey())));
        }

        // Analyze dispatch code at 0x20DBE
        println("");
        println("--- Task dispatch code (references 0x49910 at 0x20DBE) ---");
        disassembleRange(0x20DB0, 0x20E90);

        println("");
    }

    private String getCategoryName(int prefix) {
        switch (prefix) {
            case 0x01: return "INIT/HOME";
            case 0x02: return "RESET";
            case 0x03: return "POSITION/MOVE";
            case 0x04: return "FEED/EJECT";
            case 0x05: return "CALIBRATION";
            case 0x06: return "FOCUS";
            case 0x08: return "SCAN";
            case 0x09: return "MOTOR";
            case 0x0F: return "DIAGNOSTIC";
            case 0x10: return "LAMP";
            case 0x11: return "LED_CONTROL";
            case 0x20: return "READ_DATA";
            case 0x30: return "WRITE_DATA";
            case 0x40: return "GET_STATUS";
            case 0x70: return "WINDOW_CTRL";
            case 0x80: return "MODE_SENSE";
            case 0x90: return "MODE_SELECT";
            default: return "UNKNOWN";
        }
    }

    // ===== 2. Debug Labels (DA_COARSE, DA_FINE, EXP_TIME, GAIN) =====
    private void analyzeDebugLabels() throws Exception {
        println("=== SECTION 2: CALIBRATION DEBUG LABELS ===");
        println("");

        // String locations found from hex analysis
        long[] stringAddrs = {0x49EDC, 0x49EE6, 0x49EEE, 0x49EF7};
        String[] stringNames = {"DA_COARSE", "DA_FINE", "EXP_TIME", "GAIN"};

        // String pointer table at 0x49F48
        println("Debug label strings and their pointer table:");
        for (int i = 0; i < stringAddrs.length; i++) {
            println(String.format("  %s at 0x%05X (ptr at 0x%05X)",
                    stringNames[i], stringAddrs[i], 0x49F48 + i * 4));
        }

        // The pointer table 0x49EFC contains pointers to various label strings
        println("");
        println("Full label pointer table at 0x49EFC:");
        for (int i = 0; i < 24; i++) {
            long ptrAddr = 0x49EFC + i * 4;
            int ptr = readInt(ptrAddr);
            if (ptr == 0) {
                println(String.format("  [%2d] 0x%05X: NULL", i, ptrAddr));
            } else {
                // Try to read the string
                String str = readStringAt(ptr);
                println(String.format("  [%2d] 0x%05X: -> 0x%05X \"%s\"", i, ptrAddr, ptr, str));
            }
        }

        // Code references to the label pointers
        println("");
        println("Code references to calibration label table:");

        // Known references from hex search
        long[][] refs = {
            {0x261C9, 0x49F18},
            {0x261E5, 0x49F28},
            {0x26201, 0x49F48},
            {0x2621D, 0x49F50},
            {0x2651B, 0x49F54}
        };

        for (long[] ref : refs) {
            println(String.format("  Code at 0x%05X references table entry at 0x%05X", ref[0], ref[1]));
        }

        // Disassemble the calibration label usage code
        println("");
        println("--- Disassembly around calibration label references (0x26190-0x26270) ---");
        disassembleRange(0x26190, 0x26270);

        println("");
        println("--- GAIN label usage code (0x264F0-0x26570) ---");
        disassembleRange(0x264F0, 0x26570);

        println("");
    }

    // ===== 3. DAC Register Accesses (0x2000C0-0x2000C7) =====
    private void analyzeDACRegisters() throws Exception {
        println("=== SECTION 3: DAC/ADC REGISTER ACCESSES (0x2000C0-0x2000C7) ===");
        println("");

        // Known references from hex search
        String[][] dacRefs = {
            {"0x2000C0", "0x100E3", "I/O init table entry"},
            {"0x2000C0", "0x200E3", "I/O init table entry (mirror)"},
            {"0x2000C1", "0x100E9", "I/O init table entry"},
            {"0x2000C1", "0x200E9", "I/O init table entry (mirror)"},
            {"0x2000C2", "0x13AD9", "Calibration code - DAC write"},
            {"0x2000C2", "0x1412B", "Scan setup - DAC config"},
            {"0x2000C2", "0x142B7", "Scan setup - DAC config"},
            {"0x2000C2", "0x14E2B", "Scan code"},
            {"0x2000C2", "0x3D12D", "Calibration routine"},
            {"0x2000C2", "0x3DE51", "Calibration routine"},
            {"0x2000C2", "0x3EEF9", "Calibration routine"},
            {"0x2000C2", "0x3F897", "Calibration routine"},
            {"0x2000C4", "0x293B7", "ADC control"},
            {"0x2000C6", "0x27C67", "ADC readback"},
            {"0x2000C7", "0x142C7", "DAC fine control"},
            {"0x2000C7", "0x142F9", "DAC fine control"},
        };

        println("DAC/ADC Register Reference Map:");
        println("Register     Offset     Context");
        println("---------    --------   -------");
        for (String[] ref : dacRefs) {
            println(String.format("  %s   %s   %s", ref[0], ref[1], ref[2]));
        }

        // Disassemble key DAC access functions
        println("");
        println("--- DAC write code at 0x13AC0 (writes to 0x2000C2) ---");
        disassembleRange(0x13AC0, 0x13B40);

        println("");
        println("--- Scan setup DAC code at 0x14110 (configures 0x2000C2 + 0x2000C7) ---");
        disassembleRange(0x14110, 0x14320);

        // Calibration-specific DAC code in 0x3D000+ area
        println("");
        println("--- Calibration DAC routines (0x3D120-0x3D180) ---");
        disassembleRange(0x3D120, 0x3D180);

        println("");
        println("--- Calibration DAC routines (0x3DE40-0x3DEA0) ---");
        disassembleRange(0x3DE40, 0x3DEA0);

        println("");
        println("--- Calibration DAC routines (0x3EEE0-0x3EF40) ---");
        disassembleRange(0x3EEE0, 0x3EF40);

        println("");
        println("--- Calibration DAC routines (0x3F880-0x3F8E0) ---");
        disassembleRange(0x3F880, 0x3F8E0);

        println("");
    }

    // ===== 4. Analog Gain Register Accesses (0x200456-0x200458) =====
    private void analyzeGainRegisters() throws Exception {
        println("=== SECTION 4: ANALOG GAIN REGISTER ACCESSES (0x200456-0x200458) ===");
        println("");

        println("Gain register references (from I/O init table):");
        println("  0x200456 at 0x102D5 (init table) and 0x202D5 (mirror)");
        println("  0x200457 at 0x102DB (init table) and 0x202DB (mirror) - default=0x63");
        println("  0x200458 at 0x102E1 (init table) and 0x202E1 (mirror) - default=0x63");
        println("");
        println("Note: Default gain value 0x63 (99 decimal) for both channels");
        println("These registers appear ONLY in the I/O init table, suggesting");
        println("gain is set once during init and modified by writing to ASIC RAM");
        println("or via a different register path during calibration.");

        // Check for references to nearby gain-related ASIC registers
        println("");
        println("Searching for code accessing ASIC registers 0x200450-0x200460:");

        for (int reg = 0x200450; reg <= 0x200460; reg++) {
            byte[] regBytes = new byte[3];
            regBytes[0] = (byte) ((reg >> 16) & 0xFF);
            regBytes[1] = (byte) ((reg >> 8) & 0xFF);
            regBytes[2] = (byte) (reg & 0xFF);

            Address searchAddr = addr(0);
            int count = 0;
            // Simple byte search in code area
            try {
                byte[] allBytes = new byte[0x49000];
                memory.getBytes(addr(0x100), allBytes);
                for (int i = 0; i < allBytes.length - 2; i++) {
                    if (allBytes[i] == regBytes[0] && allBytes[i + 1] == regBytes[1] && allBytes[i + 2] == regBytes[2]) {
                        count++;
                        if (count <= 4) {
                            println(String.format("  0x%06X at code offset 0x%05X", reg, i + 0x100));
                        }
                    }
                }
                if (count > 4) {
                    println(String.format("  ... and %d more references", count - 4));
                }
            } catch (Exception e) {
                // Skip on memory errors
            }
        }

        println("");
    }

    // ===== 5. Flash Write Routines =====
    private void analyzeFlashWrite() throws Exception {
        println("=== SECTION 5: FLASH WRITE ROUTINES (MBM29F400B Programming) ===");
        println("");

        println("MBM29F400B Flash Programming Sequence:");
        println("  Byte mode: write 0xAA -> 0x555, write 0x55 -> 0x2AA, write CMD -> 0x555");
        println("  Program: CMD=0xA0, then write data to target address");
        println("  Sector Erase: CMD=0x80, then 0xAA->0x555, 0x55->0x2AA, 0x30->sector_addr");
        println("");

        // The flash programming function is around 0x3A340
        println("Flash address constant 0x0555 found at 0x3A35B");
        println("Flash routine appears to start around 0x3A300");
        println("");

        println("--- Flash programming routine (0x3A300-0x3A500) ---");
        disassembleRange(0x3A300, 0x3A500);

        // The 0x12FCC area with mov.b #0xAA
        println("");
        println("--- Code with mov.b #0xAA at 0x12FC0 (possible flash-related) ---");
        disassembleRange(0x12FA0, 0x13040);

        // Search for flash sector addresses (calibration area 0x4C000+)
        println("");
        println("Searching for references to calibration flash sectors (0x4C000-0x4F000):");
        searchForAddressRefs(0x4C000, 0x4F000, 0x1000);

        println("");
    }

    // ===== 6. Calibration Data Analysis =====
    private void analyzeCalibrationData() throws Exception {
        println("=== SECTION 6: CALIBRATION DATA AREA (0x4C000-0x4EFFF) ===");
        println("");

        // Region map
        println("Flash calibration data region map:");
        println("  0x4C000-0x4E83F: 10304 bytes of calibration data (00/01 pattern)");
        println("  0x4E840-0x4E8AF: 112 bytes zeroed");
        println("  0x4E8B0-0x4EFFF: 1872 bytes of calibration data");
        println("");

        // Analyze structure of the data
        byte[] calData = new byte[0x3000];
        memory.getBytes(addr(0x4C000), calData);

        // Look for record boundaries
        println("Record structure analysis:");
        println("  Byte values: only 0x00 and 0x01");
        println("  This is likely per-pixel correction data (defect map or offset table)");
        println("");

        // Check if there's a pattern with period matching CCD width
        // CCD on LS-50 has about 5340 active pixels
        // Let's look for periodicity
        int[] transitions = new int[100];
        int transCount = 0;
        for (int i = 1; i < Math.min(calData.length, 0x2840) && transCount < 100; i++) {
            if (calData[i] != calData[i - 1]) {
                transitions[transCount++] = i;
            }
        }

        println("First 30 byte-value transitions in calibration data:");
        for (int i = 0; i < Math.min(30, transCount); i++) {
            int pos = transitions[i];
            println(String.format("  0x%05X (offset %d): %d -> %d",
                    0x4C000 + pos, pos,
                    calData[pos - 1] & 0xFF, calData[pos] & 0xFF));
        }

        // Analyze 0x4D000 area (sparser pattern)
        println("");
        println("0x4D000 area analysis (sparser 01 pattern):");
        int zeroRuns = 0;
        int oneRuns = 0;
        int currentRun = 1;
        for (int i = 0x1001; i < 0x2000; i++) {
            if (calData[i] == calData[i - 1]) {
                currentRun++;
            } else {
                if ((calData[i - 1] & 0xFF) == 0) zeroRuns++;
                else oneRuns++;
                currentRun = 1;
            }
        }
        println(String.format("  Zero runs: %d, One runs: %d", zeroRuns, oneRuns));

        // Check for a row structure
        println("");
        println("Checking for row structure (bytes per row):");
        for (int stride : new int[]{42, 84, 160, 168, 336, 672, 1340, 2680, 5340}) {
            int matches = 0;
            int total = 0;
            for (int row = 0; row < 5 && (row + 1) * stride < 0x2840; row++) {
                for (int col = 0; col < stride; col++) {
                    int b1 = calData[row * stride + col] & 0xFF;
                    int b2 = calData[(row + 1) * stride + col] & 0xFF;
                    if (b1 == b2) matches++;
                    total++;
                }
            }
            if (total > 0) {
                println(String.format("  Stride %d (%d pixels): %d/%d match (%.1f%%)",
                        stride, stride, matches, total, 100.0 * matches / total));
            }
        }

        println("");
    }

    // ===== 7. Calibration Scan (Operation Type 3) =====
    private void analyzeCalibrationType3() throws Exception {
        println("=== SECTION 7: CALIBRATION SCAN PATTERNS ===");
        println("");

        println("Looking for calibration-related patterns:");
        println("  - Dark frame: move to covered area, read CCD, average");
        println("  - White reference: use internal light, read CCD, normalize");
        println("  - Operation type 3 in SCAN handler = calibration scan");
        println("");

        // Search for common calibration constants
        // Averaging typically involves division - look for shift instructions near CCD read code
        // The calibration routines at 0x3D000+ area are promising

        println("--- Broad calibration area disassembly (0x3D000-0x3D200) ---");
        disassembleRange(0x3D000, 0x3D200);

        println("");
        println("--- Calibration routine at 0x3DE00 ---");
        disassembleRange(0x3DE00, 0x3DF00);

        println("");
        println("--- Calibration routine at 0x3EE00 ---");
        disassembleRange(0x3EE00, 0x3EF80);

        // Look for references to RAM addresses that could be calibration buffers
        // ASIC RAM at 0x800000, Buffer RAM at 0xC00000
        println("");
        println("Searching for ASIC RAM buffer refs (0x800000) in calibration code area:");
        searchForConstant(0x3D000, 0x40000, new byte[]{(byte) 0x80, 0x00, 0x00});

        println("");
        println("Searching for Buffer RAM refs (0xC00000) in calibration code area:");
        searchForConstant(0x3D000, 0x40000, new byte[]{(byte) 0xC0, 0x00, 0x00});

        println("");
    }

    // ===== Helper Methods =====

    private void disassembleRange(long start, long end) {
        try {
            InstructionIterator iter = listing.getInstructions(addr(start), true);
            while (iter.hasNext()) {
                Instruction inst = iter.next();
                if (inst.getAddress().getOffset() >= end) break;

                String label = "";
                Symbol[] syms = currentProgram.getSymbolTable().getSymbols(inst.getAddress());
                if (syms != null && syms.length > 0) {
                    label = " <" + syms[0].getName() + ">";
                }

                println(String.format("  0x%05X: %-30s%s",
                        inst.getAddress().getOffset(),
                        inst.toString(),
                        label));
            }
        } catch (Exception e) {
            println("  [Disassembly not available - trying raw bytes]");
            try {
                byte[] raw = new byte[(int) (end - start)];
                memory.getBytes(addr(start), raw);
                StringBuilder sb = new StringBuilder();
                for (int i = 0; i < raw.length; i++) {
                    if (i % 16 == 0) {
                        if (i > 0) {
                            println("  " + sb.toString());
                            sb = new StringBuilder();
                        }
                        sb.append(String.format("0x%05X: ", start + i));
                    }
                    sb.append(String.format("%02X ", raw[i] & 0xFF));
                }
                if (sb.length() > 0) println("  " + sb.toString());
            } catch (Exception e2) {
                println("  [Cannot read memory at this range]");
            }
        }
    }

    private String readStringAt(long address) {
        try {
            StringBuilder sb = new StringBuilder();
            for (int i = 0; i < 32; i++) {
                int b = memory.getByte(addr(address + i)) & 0xFF;
                if (b == 0) break;
                if (b >= 0x20 && b < 0x7F) {
                    sb.append((char) b);
                } else {
                    sb.append('.');
                }
            }
            return sb.toString();
        } catch (Exception e) {
            return "<unreadable>";
        }
    }

    private void searchForAddressRefs(long startAddr, long endAddr, long step) {
        try {
            byte[] codeArea = new byte[0x49000];
            memory.getBytes(addr(0x100), codeArea);

            for (long target = startAddr; target < endAddr; target += step) {
                byte[] targetBytes = new byte[3];
                targetBytes[0] = (byte) ((target >> 16) & 0xFF);
                targetBytes[1] = (byte) ((target >> 8) & 0xFF);
                targetBytes[2] = (byte) (target & 0xFF);

                for (int i = 0; i < codeArea.length - 2; i++) {
                    if (codeArea[i] == targetBytes[0] && codeArea[i + 1] == targetBytes[1] && codeArea[i + 2] == targetBytes[2]) {
                        println(String.format("  Ref to 0x%06X at code offset 0x%05X", target, i + 0x100));
                    }
                }
            }
        } catch (Exception e) {
            println("  [Search error: " + e.getMessage() + "]");
        }
    }

    private void searchForConstant(long searchStart, long searchEnd, byte[] pattern) {
        try {
            int len = (int) (searchEnd - searchStart);
            byte[] area = new byte[len];
            memory.getBytes(addr(searchStart), area);

            int count = 0;
            for (int i = 0; i < area.length - pattern.length; i++) {
                boolean match = true;
                for (int j = 0; j < pattern.length; j++) {
                    if (area[i + j] != pattern[j]) {
                        match = false;
                        break;
                    }
                }
                if (match) {
                    count++;
                    if (count <= 20) {
                        // Show context
                        int ctxStart = Math.max(0, i - 2);
                        int ctxEnd = Math.min(area.length, i + pattern.length + 4);
                        StringBuilder ctx = new StringBuilder();
                        for (int k = ctxStart; k < ctxEnd; k++) {
                            ctx.append(String.format("%02X", area[k] & 0xFF));
                        }
                        println(String.format("  0x%05X: %s", searchStart + i, ctx.toString()));
                    }
                }
            }
            if (count > 20) {
                println(String.format("  ... and %d more", count - 20));
            }
            println(String.format("  Total: %d references", count));
        } catch (Exception e) {
            println("  [Search error: " + e.getMessage() + "]");
        }
    }
}
