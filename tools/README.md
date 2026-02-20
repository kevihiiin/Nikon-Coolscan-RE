# Third-Party Tools

## Ghidra H8/300H SLEIGH Module

**Source**: [carllom/sleigh-h8](https://github.com/carllom/sleigh-h8)
**Location**: `ghidra-h8/sleigh-h8/`
**Installed to**: `~/.config/ghidra/ghidra_12.0.3_PUBLIC/Extensions/H8/`

Provides H8/300 and H8/300H processor support for Ghidra.

### Build

The h8300h.slaspec must be compiled manually:

```bash
cd tools/ghidra-h8/sleigh-h8/data/languages/
/opt/ghidra/support/sleigh h8300h.slaspec
```

### Ghidra Language ID

- **Processor**: `H8:BE:32:H8300`
- **Compiler**: `default`

### Verified

- Disassembly at firmware reset vector (0x100) produces correct H8/300H instructions
- 32-bit register operations (mov.l, add.l) decode properly
- 24-bit absolute addressing works
