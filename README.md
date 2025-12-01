# 🛡️ The Stealth Interceptor - API Hooking Engine

[![Build Status](https://img.shields.io/badge/build-passing-brightgreen.svg)](https://github.com/BitR1ft/coal-project)
[![Platform](https://img.shields.io/badge/platform-Windows%20x86-blue.svg)]()
[![Language](https://img.shields.io/badge/language-MASM%20x86%20Assembly-red.svg)]()
[![License](https://img.shields.io/badge/license-Educational-yellow.svg)]()

## 📋 Project Overview

**The Stealth Interceptor** is a comprehensive API Hooking Engine developed using MASM x86 Assembly Language. This project demonstrates advanced low-level system programming techniques used in both security research and malware analysis.

### 👥 Team Members
- **Muhammad Adeel Haider** (Student ID: 241541)
- **Umar Farooq** (Student ID: 241575)

### 📚 Course Information
- **Course**: Computer Organization and Assembly Language (COAL)
- **Semester**: 5th Semester
- **Program**: BS Cyber Security (BSCYS-F24-A)

---

## 🎯 Project Objectives

1. **Demonstrate Low-Level System Understanding**: Deep dive into Windows internals, memory management, and CPU architecture
2. **Implement API Hooking Techniques**: Create a working "Trampoline Hook" mechanism
3. **Preserve System Stability**: Ensure proper register and stack management
4. **Educational Demonstration**: Show how both malware and antivirus software intercept system calls

---

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    STEALTH INTERCEPTOR ENGINE                    │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────┐       │
│  │   Target     │    │   Hooking    │    │  Trampoline  │       │
│  │  Acquisition │───▶│    Engine    │───▶│  Execution   │       │
│  │   Module     │    │              │    │              │       │
│  └──────────────┘    └──────────────┘    └──────────────┘       │
│         │                   │                   │                │
│         ▼                   ▼                   ▼                │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────┐       │
│  │   Memory     │    │   Register   │    │   Logging    │       │
│  │  Protection  │    │ Preservation │    │   System     │       │
│  │   Handler    │    │              │    │              │       │
│  └──────────────┘    └──────────────┘    └──────────────┘       │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

---

## 📁 Project Structure

```
coal-project/
├── 📂 src/
│   ├── 📂 core/
│   │   ├── hook_engine.asm      # Core hooking engine in MASM
│   │   ├── trampoline.asm       # Trampoline implementation
│   │   ├── memory_manager.asm   # Memory manipulation routines
│   │   └── register_save.asm    # CPU register preservation
│   ├── 📂 hooks/
│   │   ├── messagebox_hook.asm  # MessageBox API hook
│   │   ├── file_hooks.asm       # File operation hooks
│   │   ├── network_hooks.asm    # Network API hooks
│   │   └── process_hooks.asm    # Process API hooks
│   ├── 📂 utils/
│   │   ├── logging.asm          # Logging utilities
│   │   ├── string_utils.asm     # String manipulation
│   │   └── debug_helpers.asm    # Debugging helpers
│   └── 📂 demo/
│       ├── demo_main.asm        # Main demo application
│       └── interactive_demo.c   # Interactive C wrapper
├── 📂 include/
│   ├── stealth_interceptor.inc  # Assembly include file
│   ├── windows_api.inc          # Windows API definitions
│   └── macros.inc               # Assembly macros
├── 📂 docs/
│   ├── 📄 Technical_Report.md   # Detailed technical documentation
│   ├── 📄 User_Manual.md        # User guide
│   ├── 📄 API_Reference.md      # API documentation
│   ├── 📄 Security_Advisory.md  # Security considerations
│   └── 📂 images/               # Documentation images
├── 📂 tests/
│   ├── test_hook_engine.asm     # Unit tests for hook engine
│   └── test_runner.bat          # Test runner script
├── 📂 scripts/
│   ├── build.bat                # Build script
│   ├── clean.bat                # Cleanup script
│   └── setup.bat                # Environment setup
├── 📂 config/
│   └── project.props            # MSBuild properties
├── 📄 CMakeLists.txt            # CMake build configuration
├── 📄 StealthInterceptor.sln    # Visual Studio solution
├── 📄 Makefile                  # GNU Make configuration
├── 📄 .gitignore                # Git ignore file
├── 📄 LICENSE                   # License file
└── 📄 README.md                 # This file
```

---

## 🔧 Technical Implementation

### The Trampoline Technique

The core of our hooking mechanism uses the **Detour/Trampoline** technique:

```
ORIGINAL FUNCTION (Before Hook):
┌─────────────────────────────┐
│ [Original First 5 Bytes]    │ ◄── We save these
│ [Rest of Function Code]     │
│ [Return]                    │
└─────────────────────────────┘

HOOKED FUNCTION:
┌─────────────────────────────┐
│ JMP [Our_Hook_Handler]      │ ◄── 5-byte jump instruction
│ [Rest of Function Code]     │
│ [Return]                    │
└─────────────────────────────┘

OUR HOOK HANDLER (Trampoline):
┌─────────────────────────────┐
│ 1. Save All Registers       │ ◄── PUSHAD/PUSHFD
│ 2. Execute Custom Code      │ ◄── Our interceptor logic
│ 3. Restore All Registers    │ ◄── POPAD/POPFD
│ 4. Execute Stolen Bytes     │ ◄── Original first 5 bytes
│ 5. JMP Back to Original+5   │ ◄── Resume execution
└─────────────────────────────┘
```

### Key Assembly Techniques Used

1. **Indirect Addressing**: Locating function addresses in DLLs
2. **Memory Protection Modification**: Using VirtualProtect to modify code sections
3. **Register Preservation**: PUSHAD/POPAD for complete CPU state preservation
4. **Stack Frame Management**: Proper ESP/EBP handling
5. **Position-Independent Code**: Relative addressing for relocatable hooks

---

## 🚀 Quick Start

### Prerequisites

- **Operating System**: Windows 10/11 (x86 or x86-64 with WoW64)
- **Visual Studio 2019/2022** with:
  - Desktop development with C++ workload
  - MASM (Microsoft Macro Assembler)
- **x64dbg** (optional, for debugging)

### Building the Project

#### Option 1: Using Visual Studio
```batch
# Open the solution file
StealthInterceptor.sln

# Build in Release mode
Build -> Build Solution (Ctrl+Shift+B)
```

#### Option 2: Using Command Line
```batch
# Run the build script
scripts\build.bat

# Or use MSBuild directly
msbuild StealthInterceptor.sln /p:Configuration=Release /p:Platform=x86
```

#### Option 3: Using Make
```batch
# Using GNU Make
make all
```

### Running the Demo

```batch
# Run the interactive demo
bin\Release\StealthInterceptor.exe

# Or run with specific hook
bin\Release\StealthInterceptor.exe --hook messagebox
```

---

## 💻 Code Examples

### Basic Hook Installation

```asm
; Example: Hooking MessageBoxA
.code
InstallMessageBoxHook PROC
    ; Save registers
    pushad
    pushfd
    
    ; Get MessageBoxA address
    push OFFSET szUser32
    call LoadLibraryA
    push OFFSET szMessageBoxA
    push eax
    call GetProcAddress
    mov g_pOriginalMessageBox, eax
    
    ; Change memory protection
    push OFFSET dwOldProtect
    push PAGE_EXECUTE_READWRITE
    push HOOK_SIZE
    push eax
    call VirtualProtect
    
    ; Write JMP instruction
    mov edi, g_pOriginalMessageBox
    mov BYTE PTR [edi], 0E9h        ; JMP opcode
    mov eax, OFFSET HookHandler
    sub eax, edi
    sub eax, 5
    mov DWORD PTR [edi+1], eax      ; Relative offset
    
    ; Restore registers
    popfd
    popad
    ret
InstallMessageBoxHook ENDP
```

### Hook Handler (Trampoline)

```asm
HookHandler PROC
    ; Phase 1: Save state and execute custom code
    pushad
    pushfd
    
    ; Log interception
    push OFFSET szIntercepted
    call OutputDebugStringA
    
    ; Phase 2: Restore state
    popfd
    popad
    
    ; Phase 3: Execute stolen bytes
    ; (Original first 5 bytes of MessageBoxA)
    db 8Bh, 0FFh      ; mov edi, edi
    db 55h            ; push ebp
    db 8Bh, 0ECh      ; mov ebp, esp
    
    ; Phase 4: Jump back to original function + 5
    push g_pOriginalMessageBox
    add DWORD PTR [esp], 5
    ret
HookHandler ENDP
```

---

## 📊 Features

### ✅ Implemented Features

| Feature | Status | Description |
|---------|--------|-------------|
| MessageBox Hook | ✅ | Intercepts MessageBoxA/W calls |
| File Operation Hooks | ✅ | Monitors CreateFile, ReadFile, WriteFile |
| Network Hooks | ✅ | Intercepts socket operations |
| Process Hooks | ✅ | Monitors process creation |
| Registry Hooks | ✅ | Tracks registry modifications |
| Logging System | ✅ | Comprehensive activity logging |
| Multi-Hook Support | ✅ | Install multiple hooks simultaneously |
| Hot Unhook | ✅ | Remove hooks without restart |
| Thread Safety | ✅ | Safe for multi-threaded applications |

### 🔜 Advanced Features

- **Stealth Mode**: Evade basic anti-debugging techniques
- **Hook Chaining**: Support for multiple handlers per API
- **Callback System**: Custom callback support for each hook
- **Statistics Dashboard**: Real-time hook activity monitoring

---

## 🧪 Testing

### Running Tests

```batch
# Run all tests
scripts\test_runner.bat

# Run specific test
scripts\test_runner.bat hook_engine
```

### Test Coverage

- Unit tests for each assembly module
- Integration tests for hook installation/removal
- Stress tests for stability verification

---

## 📚 Documentation

| Document | Description |
|----------|-------------|
| [Technical Report](docs/Technical_Report.md) | Detailed technical documentation |
| [User Manual](docs/User_Manual.md) | Step-by-step usage guide |
| [API Reference](docs/API_Reference.md) | Complete API documentation |
| [Security Advisory](docs/Security_Advisory.md) | Security considerations and ethical guidelines |

---

## ⚠️ Security Notice

**EDUCATIONAL PURPOSE ONLY**

This project is developed for educational purposes as part of a Cyber Security curriculum. The techniques demonstrated are used to:

1. **Understand** how security software (antivirus, EDR) monitors system behavior
2. **Learn** how malware intercepts API calls
3. **Develop** skills in low-level system programming

### Ethical Guidelines

- ❌ Do NOT use this code on systems you don't own
- ❌ Do NOT use for malicious purposes
- ❌ Do NOT distribute with malicious intent
- ✅ Use only in controlled, isolated environments
- ✅ Always obtain proper authorization

---

## 🔬 How It Works

### Phase 1: Target Acquisition

```asm
; Load the target DLL
push OFFSET szUser32
call LoadLibraryA

; Get the function address
push OFFSET szFunctionName
push eax
call GetProcAddress
; EAX now contains the function address
```

### Phase 2: Memory Modification

```asm
; Change memory protection to allow writing
push OFFSET dwOldProtect
push PAGE_EXECUTE_READWRITE
push 5                        ; Size of our hook
push pTargetFunction
call VirtualProtect
```

### Phase 3: Hook Installation

```asm
; Write JMP instruction (E9 xx xx xx xx)
mov edi, pTargetFunction
mov BYTE PTR [edi], 0E9h      ; JMP opcode

; Calculate relative offset
mov eax, pHookHandler
sub eax, edi
sub eax, 5
mov DWORD PTR [edi+1], eax
```

---

## 📈 Performance

| Metric | Value |
|--------|-------|
| Hook Installation Time | < 1ms |
| Hook Overhead per Call | ~50 CPU cycles |
| Memory Footprint | < 64KB |
| Maximum Hooks | 256 |

---

## 🛠️ Troubleshooting

### Common Issues

**Issue**: "Access Denied" when installing hooks
- **Solution**: Run as Administrator

**Issue**: Application crashes after hook
- **Solution**: Verify stolen bytes are correct for the target function

**Issue**: Hook not triggering
- **Solution**: Ensure you're hooking the correct version (A vs W)

---

## 📄 License

This project is licensed for **Educational Use Only**. See [LICENSE](LICENSE) for details.

---

## 🙏 Acknowledgments

- Microsoft for MASM and Visual Studio
- x64dbg community for debugging tools
- Our COAL course instructor for guidance
- Various security researchers whose work inspired this project

---

## 📞 Contact

For questions or feedback:
- **Muhammad Adeel Haider**: [241541@students.au.edu.pk]
- **Umar Farooq**: [241575@students.au.edu.pk]

---

<p align="center">
  <b>🛡️ The Stealth Interceptor - Where Assembly Meets Security 🛡️</b>
</p>
