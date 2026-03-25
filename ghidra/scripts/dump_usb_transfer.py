# Dump disassembly of USB data transfer functions for Phase 7 analysis
# @category Coolscan
# @runtime Jython

def dump_range(start, end, name):
    listing = currentProgram.getListing()
    space = currentProgram.getAddressFactory().getDefaultAddressSpace()

    print("=== %s ===" % name)
    addr = space.getAddress(start)
    end_addr = space.getAddress(end)

    insn = listing.getInstructionAt(addr)
    if insn is None:
        # Try to find next instruction
        insn = listing.getInstructionAfter(addr)

    while insn is not None and insn.getAddress().compareTo(end_addr) < 0:
        offset = insn.getAddress().getOffset()
        mnemonic = insn.toString()
        raw = " ".join(["%02X" % (b & 0xFF) for b in insn.getBytes()])
        print("  0x%06X: %-35s [%s]" % (offset, mnemonic, raw))
        insn = insn.getNext()

    print("")

dump_range(0x014090, 0x014120, "DATA_TRANSFER_0x014090")
dump_range(0x016458, 0x0164A0, "CDB_READ_0x016458")
dump_range(0x01232E, 0x012360, "DIVXU_HELPER_0x01232E")
dump_range(0x012258, 0x0122C0, "USB_FIFO_RW_0x012258")
dump_range(0x013D72, 0x013DC0, "BUFFER_SETUP_0x013D72")
dump_range(0x01374A, 0x0137D0, "RESPONSE_MANAGER_0x01374A")
dump_range(0x013C70, 0x013D00, "USB_READY_WAIT_0x013C70")
