#!/usr/bin/env bash
# Bootstrap all Ghidra projects with headless import + auto-analysis
# Usage: ./bootstrap_ghidra.sh

set -euo pipefail

PROJ_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
GHIDRA="/opt/ghidra/support/analyzeHeadless"
BINDIR="$PROJ_ROOT/binaries/software/NikonScan403_installed"
FWDIR="$PROJ_ROOT/binaries/firmware"
GHIDRA_PROJ="$PROJ_ROOT/ghidra/projects"

echo "=== Coolscan RE: Ghidra Headless Bootstrap ==="
echo "Project root: $PROJ_ROOT"
echo ""

# --- NikonScan_Drivers: NKDUSCAN.dll, NKDSBP2.dll, ICE DLLs ---
echo "[1/5] Importing NikonScan_Drivers..."
$GHIDRA "$GHIDRA_PROJ/NikonScan_Drivers" NikonScan_Drivers \
  -import "$BINDIR/Drivers/NKDUSCAN.dll" \
  -import "$BINDIR/Drivers/NKDSBP2.dll" \
  2>&1 | tail -5
echo ""

# --- NikonScan_ICE: ICEDLL.dll, ICENKNL1.dll, ICENKNX2.dll ---
echo "[2/5] Importing NikonScan_ICE..."
$GHIDRA "$GHIDRA_PROJ/NikonScan_ICE" NikonScan_ICE \
  -import "$BINDIR/Drivers/ICEDLL.dll" \
  -import "$BINDIR/Drivers/ICENKNL1.dll" \
  -import "$BINDIR/Drivers/ICENKNX2.dll" \
  2>&1 | tail -5
echo ""

# --- NikonScan_Modules: LS4000/5000/8000/9000.md3 ---
echo "[3/5] Importing NikonScan_Modules..."
$GHIDRA "$GHIDRA_PROJ/NikonScan_Modules" NikonScan_Modules \
  -import "$BINDIR/Module_E/LS4000.md3" \
  -import "$BINDIR/Module_E/LS5000.md3" \
  -import "$BINDIR/Module_E/LS8000.md3" \
  -import "$BINDIR/Module_E/LS9000.md3" \
  2>&1 | tail -5
echo ""

# --- NikonScan_TWAIN: NikonScan4.ds, DRAGNKL1.dll, DRAGNKX2.dll ---
echo "[4/5] Importing NikonScan_TWAIN..."
$GHIDRA "$GHIDRA_PROJ/NikonScan_TWAIN" NikonScan_TWAIN \
  -import "$BINDIR/Twain_Source/NikonScan4.ds" \
  -import "$BINDIR/Twain_Source/DRAGNKL1.dll" \
  -import "$BINDIR/Twain_Source/DRAGNKX2.dll" \
  2>&1 | tail -5
echo ""

# --- CoolscanFirmware: already imported in Phase 0 setup ---
echo "[5/5] Firmware already imported. Running analysis..."
$GHIDRA "$GHIDRA_PROJ/CoolscanFirmware" CoolscanFirmware \
  -process "Nikon LS-50 MBM29F400B TSOP48.bin" \
  2>&1 | tail -5
echo ""

echo "=== Bootstrap complete ==="
