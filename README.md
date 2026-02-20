# Nikon Coolscan Reverse Engineering

Reverse engineering Nikon Coolscan film scanner firmware and Windows drivers to document the complete SCSI communication protocol. Goal: enable modern cross-platform drivers (Linux, macOS).

## Target Scanners

| Model | Name | Resolution | Film | Interface |
|-------|------|-----------|------|-----------|
| **LS-50** | Coolscan V ED | 4000 DPI | 35mm | USB 2.0 |
| LS-5000 | Super Coolscan 5000 ED | 4000 DPI | 35mm | USB 2.0 |
| LS-4000 | Coolscan 4000 ED | 2900 DPI | 35mm | IEEE 1394 + USB |
| LS-8000 | Super Coolscan 8000 ED | 4000 DPI | 35mm + 120 | IEEE 1394 + USB |
| LS-9000 | Super Coolscan 9000 ED | 4000 DPI | 35mm + 120 | IEEE 1394 + USB |

Primary target is the LS-50 (firmware dump available).

## Architecture

```
NikonScan4.ds (TWAIN) -> LS5000.md3 (MAID) -> NKDUSCAN.dll (USB) -> usbscan.sys -> Scanner (H8/3003)
```

## Project Structure

- `CLAUDE.md` -- Bootstrap for Claude Code sessions
- `docs/phases/` -- Per-phase methodology and completion criteria
- `binaries/` -- Firmware dump + NikonScan 4.03 files (not in git)
- `ghidra/` -- Ghidra projects, scripts, exports
- `r2/` -- radare2 scripts and projects
- `scripts/` -- Python and shell analysis scripts
- `kb/` -- Knowledge base (the main output)
- `logs/` -- Progress and attempt logs
- `tools/` -- Third-party tools (H8/300H SLEIGH module)

## Status

See `logs/general.md` for current progress.

## References

- [kosma/coolscan-mods](https://github.com/kosma/coolscan-mods) -- Hardware RE, memory map, GPIO
- H8/300H Programming Manual
- ISP1581 Datasheet
- SCSI-2 Scanner Device Specification
