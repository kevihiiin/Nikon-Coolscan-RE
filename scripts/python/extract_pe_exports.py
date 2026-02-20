#!/usr/bin/env python3
"""Extract PE export tables from DLL/EXE files to CSV.

Usage: python3 extract_pe_exports.py <binary_path> [<binary_path> ...]
Output: CSV to stdout (name, ordinal, rva, binary)
"""

import sys
import os
import csv

# Add venv site-packages if running from project venv
venv_site = os.path.join(os.path.dirname(__file__), '..', '..', '.venv', 'lib')
if os.path.exists(venv_site):
    import glob
    for p in glob.glob(os.path.join(venv_site, 'python*/site-packages')):
        sys.path.insert(0, p)

import pefile


def extract_exports(pe_path):
    """Extract exports from a PE file."""
    pe = pefile.PE(pe_path)
    binary_name = os.path.basename(pe_path)
    results = []

    if hasattr(pe, 'DIRECTORY_ENTRY_EXPORT'):
        for exp in pe.DIRECTORY_ENTRY_EXPORT.symbols:
            name = exp.name.decode('utf-8', errors='replace') if exp.name else ''
            results.append({
                'binary': binary_name,
                'name': name,
                'ordinal': exp.ordinal,
                'rva': f'0x{exp.address:08X}',
                'forwarder': exp.forwarder.decode('utf-8', errors='replace') if exp.forwarder else '',
            })

    pe.close()
    return results


def extract_imports(pe_path):
    """Extract imports from a PE file."""
    pe = pefile.PE(pe_path)
    binary_name = os.path.basename(pe_path)
    results = []

    if hasattr(pe, 'DIRECTORY_ENTRY_IMPORT'):
        for entry in pe.DIRECTORY_ENTRY_IMPORT:
            dll_name = entry.dll.decode('utf-8', errors='replace')
            for imp in entry.imports:
                name = imp.name.decode('utf-8', errors='replace') if imp.name else ''
                results.append({
                    'binary': binary_name,
                    'dll': dll_name,
                    'name': name,
                    'ordinal': imp.ordinal if imp.ordinal else '',
                    'hint': imp.hint if hasattr(imp, 'hint') else '',
                })

    pe.close()
    return results


def main():
    if len(sys.argv) < 2:
        print(f"Usage: {sys.argv[0]} <binary_path> [<binary_path> ...]", file=sys.stderr)
        sys.exit(1)

    all_exports = []
    all_imports = []

    for path in sys.argv[1:]:
        if not os.path.exists(path):
            print(f"Warning: {path} not found, skipping", file=sys.stderr)
            continue

        print(f"Processing: {os.path.basename(path)}", file=sys.stderr)
        try:
            all_exports.extend(extract_exports(path))
            all_imports.extend(extract_imports(path))
        except Exception as e:
            print(f"Error processing {path}: {e}", file=sys.stderr)

    # Write exports CSV
    if all_exports:
        print("--- EXPORTS ---")
        writer = csv.DictWriter(sys.stdout, fieldnames=['binary', 'name', 'ordinal', 'rva', 'forwarder'])
        writer.writeheader()
        writer.writerows(all_exports)

    # Write imports CSV
    if all_imports:
        print("\n--- IMPORTS ---")
        writer = csv.DictWriter(sys.stdout, fieldnames=['binary', 'dll', 'name', 'ordinal', 'hint'])
        writer.writeheader()
        writer.writerows(all_imports)

    print(f"\nTotal: {len(all_exports)} exports, {len(all_imports)} imports from {len(sys.argv)-1} binaries",
          file=sys.stderr)


if __name__ == '__main__':
    main()
