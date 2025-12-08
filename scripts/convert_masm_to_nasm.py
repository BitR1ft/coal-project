#!/usr/bin/env python3
"""
MASM to NASM Converter for Stealth Interceptor Project
Converts MASM32 x86 assembly to NASM Win32 syntax
"""

import re
import sys
import os

def convert_masm_to_nasm(masm_code, filename):
    """Convert MASM code to NASM syntax"""
    lines = masm_code.split('\n')
    nasm_lines = []
    in_data_section = False
    in_code_section = False
    in_bss_section = False
    
    # Skip header stuff
    skip_until_data = True
    
    for line in lines:
        original_line = line
        stripped = line.strip()
        
        # Skip MASM-specific directives
        if stripped.startswith('.686') or stripped.startswith('.model') or stripped.startswith('option'):
            continue
        
        # Skip MASM includes
        if stripped.startswith('include \\masm32') or stripped.startswith('includelib'):
            continue
        
        # Handle section directives
        if stripped == '.data':
            nasm_lines.append('section .data')
            in_data_section = True
            in_code_section = False
            in_bss_section = False
            skip_until_data = False
            continue
        
        if stripped == '.data?':
            nasm_lines.append('section .bss')
            in_bss_section = True
            in_data_section = False
            in_code_section = False
            skip_until_data = False
            continue
        
        if stripped == '.code':
            nasm_lines.append('section .text')
            in_code_section = True
            in_data_section = False
            in_bss_section = False
            skip_until_data = False
            continue
        
        if skip_until_data and not in_code_section:
            # Keep comments
            if stripped.startswith(';'):
                nasm_lines.append(line)
            continue
        
        # Convert data declarations
        if in_data_section:
            # BYTE -> db
            line = re.sub(r'\bBYTE\b', 'db', line)
            # WORD -> dw
            line = re.sub(r'\bWORD\b', 'dw', line)
            # DWORD -> dd
            line = re.sub(r'\bDWORD\b', 'dd', line)
            # QWORD -> dq
            line = re.sub(r'\bQWORD\b', 'dq', line)
            # DUP() syntax
            line = re.sub(r'(\d+)\s+DUP\s*\(([^)]+)\)', r'times \\1 \\2', line)
            # <> initialization
            line = re.sub(r'<>', '0', line)
            # PTR directive
            line = re.sub(r'\bPTR\b', '', line)
        
        # Convert BSS declarations
        if in_bss_section:
            # BYTE x DUP(?) -> resb x
            match = re.search(r'(\w+)\s+BYTE\s+(\d+)\s+DUP\s*\(\?\)', stripped)
            if match:
                name, count = match.groups()
                indent = len(line) - len(line.lstrip())
                line = ' ' * indent + f'{name} resb {count}'
            
            # WORD x DUP(?) -> resw x
            match = re.search(r'(\w+)\s+WORD\s+(\d+)\s+DUP\s*\(\?\)', stripped)
            if match:
                name, count = match.groups()
                indent = len(line) - len(line.lstrip())
                line = ' ' * indent + f'{name} resw {count}'
            
            # DWORD ? -> resd 1
            match = re.search(r'(\w+)\s+DWORD\s+\?', stripped)
            if match:
                name = match.group(1)
                indent = len(line) - len(line.lstrip())
                line = ' ' * indent + f'{name} resd 1'
        
        # Convert code
        if in_code_section:
            # PROC EXPORT -> global function
            match = re.search(r'(\w+)\s+PROC\s+EXPORT', stripped)
            if match:
                func_name = match.group(1)
                nasm_lines.append(f'global _{func_name}@0')
                nasm_lines.append(f'_{func_name}@0:')
                continue
            
            # PROC with parameters -> extract parameters
            match = re.search(r'(\w+)\s+PROC\s+(\w+):(\w+)', stripped)
            if match:
                func_name = match.group(1)
                nasm_lines.append(f'global _{func_name}@4')
                nasm_lines.append(f'_{func_name}@4:')
                continue
            
            # Simple PROC
            match = re.search(r'(\w+)\s+PROC\s*$', stripped)
            if match:
                func_name = match.group(1)
                nasm_lines.append(f'{func_name}:')
                continue
            
            # ENDP
            if re.search(r'\bENDP\b', stripped):
                # Add some spacing
                nasm_lines.append('')
                continue
            
            # END directive
            if re.search(r'^\s*END\s+', stripped):
                continue
            
            # Local labels starting with @
            line = re.sub(r'@(\w+):', r'.\\1:', line)
            line = re.sub(r'@(\w+)\b', r'.\\1', line)
            
            # OFFSET -> just the label name in NASM
            line = re.sub(r'\bOFFSET\s+', '', line)
            
            # PTR directive
            line = re.sub(r'\bBYTE\s+PTR\b', 'byte', line)
            line = re.sub(r'\bWORD\s+PTR\b', 'word', line)
            line = re.sub(r'\bDWORD\s+PTR\b', 'dword', line)
            
            # Memory references with registers
            # [reg] stays [reg]
            # [reg+offset] stays [reg+offset]
            
            # Hexadecimal numbers
            line = re.sub(r'(\W)([0-9A-F]+)h\b', r'\\10x\\2', line, flags=re.IGNORECASE)
        
        # EQU -> equ
        line = re.sub(r'\bEQU\b', 'equ', line)
        
        # Add the line
        nasm_lines.append(line)
    
    return '\n'.join(nasm_lines)

def process_file(input_file, output_file):
    """Process a single MASM file and convert to NASM"""
    with open(input_file, 'r', encoding='utf-8', errors='ignore') as f:
        masm_code = f.read()
    
    nasm_code = convert_masm_to_nasm(masm_code, os.path.basename(input_file))
    
    with open(output_file, 'w', encoding='utf-8') as f:
        f.write(nasm_code)
    
    print(f"Converted: {input_file} -> {output_file}")

if __name__ == "__main__":
    if len(sys.argv) < 3:
        print("Usage: python convert_masm_to_nasm.py <input.asm> <output.asm>")
        sys.exit(1)
    
    process_file(sys.argv[1], sys.argv[2])
