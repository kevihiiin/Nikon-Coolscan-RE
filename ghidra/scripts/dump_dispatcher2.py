# @category Coolscan
# @runtime Jython
def dump_range(start, end, name):
    listing = currentProgram.getListing()
    space = currentProgram.getAddressFactory().getDefaultAddressSpace()
    print('=== %s ===' % name)
    addr = space.getAddress(start)
    end_addr = space.getAddress(end)
    insn = listing.getInstructionAt(addr)
    if insn is None:
        insn = listing.getInstructionAfter(addr)
    while insn is not None and insn.getAddress().compareTo(end_addr) < 0:
        offset = insn.getAddress().getOffset()
        mnemonic = insn.toString()
        raw = ' '.join(['%02X' % (b & 0xFF) for b in insn.getBytes()])
        print('  0x%06X: %-35s [%s]' % (offset, mnemonic, raw))
        insn = insn.getNext()
    print('')
dump_range(0x020B48, 0x020E00, 'DISPATCHER_CDB_AND_HANDLERS')
dump_range(0x0137C4, 0x013840, 'CDB_PARSE_SETUP')
