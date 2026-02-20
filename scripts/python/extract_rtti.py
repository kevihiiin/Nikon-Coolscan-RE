#!/usr/bin/env python3
"""Extract MSVC RTTI class names from PE binaries.

Searches for MSVC type_info name strings (`.?AV` prefix) and reconstructs
class names. Also attempts to find class hierarchy from RTTIClassHierarchyDescriptor.

Usage: python3 extract_rtti.py <binary_path> [<binary_path> ...]
Output: JSON to stdout
"""

import sys
import os
import re
import json
import struct

# Add venv site-packages
venv_site = os.path.join(os.path.dirname(__file__), '..', '..', '.venv', 'lib')
if os.path.exists(venv_site):
    import glob
    for p in glob.glob(os.path.join(venv_site, 'python*/site-packages')):
        sys.path.insert(0, p)

import pefile


def demangle_rtti_name(raw_name):
    """Convert MSVC RTTI mangled name to readable form.

    .?AVCMyClass@@ -> CMyClass
    .?AVCUSBSession@@  -> CUSBSession
    .?AVCUSBDeviceTable@@ -> CUSBDeviceTable
    """
    # Remove .?AV prefix and @@ suffix
    name = raw_name
    if name.startswith('.?AV'):
        name = name[4:]
    elif name.startswith('.?AU'):
        name = name[4:]  # struct

    # Remove trailing @@ and any namespace separators
    name = name.rstrip('@')

    # Handle namespaces (reversed in MSVC mangling)
    parts = [p for p in name.split('@') if p]
    if len(parts) > 1:
        parts.reverse()
        return '::'.join(parts)
    return name


def extract_rtti_names(pe_path):
    """Extract RTTI type_info names from a PE binary."""
    with open(pe_path, 'rb') as f:
        data = f.read()

    binary_name = os.path.basename(pe_path)
    results = []

    # Find all .?AV (class) and .?AU (struct) type descriptors
    pattern = rb'\.(\?A[VU][A-Za-z0-9_@:]+@@)'

    for match in re.finditer(pattern, data):
        raw = match.group(0).decode('ascii', errors='replace')
        offset = match.start()
        demangled = demangle_rtti_name(raw)

        results.append({
            'binary': binary_name,
            'raw_name': raw,
            'demangled': demangled,
            'offset': f'0x{offset:08X}',
            'type': 'class' if raw.startswith('.?AV') else 'struct',
        })

    return results


def extract_rtti_hierarchy(pe_path):
    """Attempt to extract class hierarchy from RTTI structures.

    MSVC RTTI layout (32-bit):
    - type_info: vtable_ptr(4) + spare(4) + name(variable)
    - RTTICompleteObjectLocator: signature(4) + offset(4) + cd_offset(4) +
      type_descriptor_ptr(4) + class_hierarchy_ptr(4)
    - RTTIClassHierarchyDescriptor: signature(4) + attributes(4) + num_base_classes(4) +
      base_class_array_ptr(4)

    This is a simplified extraction -- full hierarchy requires resolving pointer chains.
    """
    pe = pefile.PE(pe_path)

    # Find .rdata section for RTTI data
    rdata_section = None
    for section in pe.sections:
        name = section.Name.decode('utf-8', errors='replace').rstrip('\x00')
        if name == '.rdata':
            rdata_section = section
            break

    pe.close()

    # For now, just return the type names -- full hierarchy needs Ghidra
    return None


def main():
    if len(sys.argv) < 2:
        print(f"Usage: {sys.argv[0]} <binary_path> [<binary_path> ...]", file=sys.stderr)
        sys.exit(1)

    all_results = {}

    for path in sys.argv[1:]:
        if not os.path.exists(path):
            print(f"Warning: {path} not found, skipping", file=sys.stderr)
            continue

        binary = os.path.basename(path)
        print(f"Processing: {binary}", file=sys.stderr)

        try:
            names = extract_rtti_names(path)
            all_results[binary] = {
                'class_count': sum(1 for n in names if n['type'] == 'class'),
                'struct_count': sum(1 for n in names if n['type'] == 'struct'),
                'classes': [n for n in names if n['type'] == 'class'],
                'structs': [n for n in names if n['type'] == 'struct'],
            }
            print(f"  Found {len(names)} RTTI entries ({all_results[binary]['class_count']} classes, "
                  f"{all_results[binary]['struct_count']} structs)", file=sys.stderr)
        except Exception as e:
            print(f"Error processing {path}: {e}", file=sys.stderr)

    json.dump(all_results, sys.stdout, indent=2)
    print()

    total = sum(r['class_count'] + r['struct_count'] for r in all_results.values())
    print(f"\nTotal: {total} RTTI entries across {len(all_results)} binaries", file=sys.stderr)


if __name__ == '__main__':
    main()
