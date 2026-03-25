# @category Coolscan
# @runtime Jython
def dump_range(start, end, name):
    listing = currentProgram.getListing()
    space = currentProgram.getAddressFactory().getDefaultAddressSpace()
    print('=== %s ===' % name)
    # Force disassemble
    from ghidra.program.model.listing import CodeUnit
    import ghidra.app.cmd.disassemble
    from ghidra.app.cmd.disassemble import DisassembleCommand
    addr = space.getAddress(start)
    end_addr = space.getAddress(end)
    cmd = DisassembleCommand(addr, None, True)
    cmd.applyTo(currentProgram)
    insn = listing.getInstructionAt(addr)
    if insn is None:
        insn = listing.getInstructionAfter(addr)
        if insn:
            print('  (skipped to 0x%06X)' % insn.getAddress().getOffset())
    while insn is not None and insn.getAddress().compareTo(end_addr) < 0:
        offset = insn.getAddress().getOffset()
        mnemonic = insn.toString()
        raw = ' '.join(['%02X' % (b & 0xFF) for b in insn.getBytes()])
        print('  0x%06X: %-35s [%s]' % (offset, mnemonic, raw))
        insn = insn.getNext()
    print('')
dump_range(0x021866, 0x021950, 'REQUEST_SENSE_HANDLER_FULL')
