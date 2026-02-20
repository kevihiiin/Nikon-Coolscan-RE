# Ghidra headless script: verify firmware disassembly at reset vector
# @category CoolscanRE

from ghidra.program.model.address import AddressSet
from ghidra.app.cmd.disassemble import DisassembleCommand

addr = currentProgram.getAddressFactory().getDefaultAddressSpace().getAddress(0x100)
print("Reset vector entry point: 0x{:06X}".format(addr.getOffset()))

# Try to disassemble at 0x100
dis_cmd = DisassembleCommand(addr, None, True)
dis_cmd.applyTo(currentProgram, monitor)

# Read first 10 instructions
listing = currentProgram.getListing()
instr = listing.getInstructionAt(addr)
count = 0
while instr is not None and count < 15:
    print("  0x{:06X}: {}".format(instr.getAddress().getOffset(), instr.toString()))
    instr = instr.getNext()
    count += 1

# Also check vector table entries
print("\nVector table (first 16 entries):")
mem = currentProgram.getMemory()
for i in range(16):
    vec_addr = currentProgram.getAddressFactory().getDefaultAddressSpace().getAddress(i * 4)
    b0 = mem.getByte(vec_addr) & 0xFF
    b1 = mem.getByte(vec_addr.add(1)) & 0xFF
    b2 = mem.getByte(vec_addr.add(2)) & 0xFF
    b3 = mem.getByte(vec_addr.add(3)) & 0xFF
    target = (b0 << 24) | (b1 << 16) | (b2 << 8) | b3
    print("  Vector {:2d} (0x{:03X}): -> 0x{:06X}".format(i, i*4, target))
