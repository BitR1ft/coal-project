# 🛡️ The Stealth Interceptor - NASM Build Guide

## Overview

This project has been converted to use **NASM (Netwide Assembler)** instead of MASM, providing:
- ✅ Cross-platform assembly (Windows/Linux)
- ✅ Modern, clear syntax
- ✅ Better error messages
- ✅ No dependency on Visual Studio

## Build Status

| Project | Status | Description |
|---------|--------|-------------|
| **Mini Version** | ✅ **Working** | Simplified version with MessageBox hook |
| **Full Version** | 🚧 In Progress | Complete version with all features |

## Quick Start

### Prerequisites

#### On Linux (Ubuntu/Debian)
```bash
# Install NASM
sudo apt-get update
sudo apt-get install nasm

# Install MinGW for Windows cross-compilation
sudo apt-get install mingw-w64 gcc-mingw-w64-i686
```

#### On Windows
1. Download and install NASM from https://www.nasm.us/
2. Add NASM to your PATH
3. Install Visual Studio (for the linker) OR GoLink

### Building the Mini Project

#### On Linux
```bash
# Using the build script (recommended)
./scripts/build_nasm.sh mini

# Or manually
cd mini
make -f Makefile_nasm all
```

#### On Windows
```batch
REM Using the build script (recommended)
scripts\build_nasm.bat mini

REM Or manually
cd mini
nasm -f win32 -o build\obj\hook_engine_nasm.obj src\core\hook_engine_nasm.asm
nasm -f win32 -o build\obj\messagebox_hook_nasm.obj src\hooks\messagebox_hook_nasm.asm
nasm -f win32 -o build\obj\demo_main_nasm.obj src\demo\demo_main_nasm.asm
link /SUBSYSTEM:CONSOLE /ENTRY:_main /OUT:bin\MiniStealthInterceptor.exe build\obj\*.obj kernel32.lib user32.lib
```

### Running the Executable

#### On Windows
```batch
mini\bin\MiniStealthInterceptor.exe
```

#### On Linux (with Wine)
```bash
wine mini/bin/MiniStealthInterceptor.exe
```

## Project Structure (NASM Version)

```
coal-project/
├── mini/                              # Mini project (WORKING)
│   ├── src/
│   │   ├── core/
│   │   │   └── hook_engine_nasm.asm   # Hook engine in NASM
│   │   ├── hooks/
│   │   │   └── messagebox_hook_nasm.asm # MessageBox hook in NASM
│   │   └── demo/
│   │       └── demo_main_nasm.asm      # Demo application in NASM
│   ├── Makefile_nasm                   # NASM Makefile
│   └── bin/
│       └── MiniStealthInterceptor.exe  # Built executable (15KB)
├── scripts/
│   ├── build_nasm.sh                   # Linux build script
│   ├── build_nasm.bat                  # Windows build script
│   └── convert_masm_to_nasm.py         # Conversion utility
├── include/
│   └── stealth_interceptor_nasm.inc    # NASM include file
└── Makefile_nasm                       # Root NASM Makefile
```

## Key Differences: MASM vs NASM

| Feature | MASM | NASM |
|---------|------|------|
| **Platform** | Windows only | Cross-platform |
| **Syntax** | Intel (with macros) | Intel (pure) |
| **Data Declarations** | `BYTE`, `DWORD` | `db`, `dd` |
| **Procedures** | `PROC`/`ENDP` | Labels with `:` |
| **Structures** | `STRUCT`/`ENDS` | `struc`/`endstruc` |
| **Sections** | `.data`, `.code` | `section .data`, `section .text` |
| **Labels** | `@label:` | `.label:` |
| **Hex Numbers** | `0FFh` | `0xFF` |
| **Offset** | `OFFSET label` | `label` |

## NASM Syntax Examples

### Data Declaration
```nasm
; MASM
szMessage BYTE "Hello", 0
dwCount   DWORD 10
dwArray   DWORD 5 DUP(0)

; NASM
szMessage db "Hello", 0
dwCount   dd 10
dwArray   times 5 dd 0
```

### Function Definition
```nasm
; MASM
MyFunction PROC EXPORT
    push ebp
    mov ebp, esp
    ; ... code ...
    pop ebp
    ret
MyFunction ENDP

; NASM
global _MyFunction@0
_MyFunction@0:
    push ebp
    mov ebp, esp
    ; ... code ...
    pop ebp
    ret
```

### Memory Access
```nasm
; MASM
mov eax, DWORD PTR [esi]
mov BYTE PTR [edi], al

; NASM
mov eax, [esi]
mov byte [edi], al
```

## Building Full Project

The full project conversion is in progress. Currently available:
- ✅ NASM include file with all constants
- ✅ Conversion script for automated conversion
- ✅ Build infrastructure (Makefiles, scripts)
- 🚧 Individual module conversions (in progress)

To convert additional modules:
```bash
python3 scripts/convert_masm_to_nasm.py src/core/module.asm src/core/module_nasm.asm
```

## Troubleshooting

### NASM not found
```bash
# Linux
sudo apt-get install nasm

# Windows
# Download from https://www.nasm.us/ and add to PATH
```

### MinGW not found (Linux)
```bash
sudo apt-get install mingw-w64 gcc-mingw-w64-i686
```

### Linker errors on Windows
- Install Visual Studio with C++ desktop development
- OR download GoLink (lightweight alternative)

### Wine errors on Linux
```bash
# Install Wine
sudo apt-get install wine wine32

# Run with Wine
wine mini/bin/MiniStealthInterceptor.exe
```

## Testing

The mini project executable can be tested with:
1. Install MessageBox hook
2. Test with MessageBox
3. View statistics
4. Remove hook

All operations are logged to the debug output (use DebugView on Windows).

## Performance

The NASM-compiled executable:
- Size: 15KB (comparable to MASM version)
- Performance: Identical to MASM (native x86 code)
- Compatibility: Windows XP through Windows 11

## Future Work

1. Complete conversion of all full project modules
2. Add automated testing
3. Create debug symbols support
4. Add Linux native version (using ptrace instead of Windows APIs)

## Contributing

When adding new assembly code, please:
1. Use NASM syntax
2. Follow the existing code style
3. Add comments for complex operations
4. Test on both Windows and Linux (with Wine)

## License

Educational Use Only - See LICENSE file

---

**Authors:**
- Muhammad Adeel Haider (241541)
- Umar Farooq (241575)

**Course:** COAL - 5th Semester, BS Cyber Security
