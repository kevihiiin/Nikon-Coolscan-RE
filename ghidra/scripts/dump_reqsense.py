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
        if insn:
            print('  (first instruction after requested start: 0x%06X)' % insn.getAddress().getOffset())
    while insn is not None and insn.getAddress().compareTo(end_addr) < 0:
        offset = insn.getAddress().getOffset()
        mnemonic = insn.toString()
        raw = ' '.join(['%02X' % (b & 0xFF) for b in insn.getBytes()])
        print('  0x%06X: %-35s [%s]' % (offset, mnemonic, raw))
        insn = insn.getNext()
    print('')
dump_range(0x021860, 0x0219E0, 'REQUEST_SENSE_HANDLER_0x021866')
