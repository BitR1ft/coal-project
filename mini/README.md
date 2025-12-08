# 🛡️ Mini Stealth Interceptor - API Hooking Engine

[![Platform](https://img.shields.io/badge/platform-Windows%20x86-blue.svg)]()
[![Language](https://img.shields.io/badge/language-NASM%20x86%20Assembly-red.svg)]()
[![License](https://img.shields.io/badge/license-Educational-yellow.svg)]()
[![Build](https://img.shields.io/badge/build-passing-brightgreen.svg)]()

> **✅ NASM Version - Fully Working!** Cross-platform assembly, builds on Linux and Windows.

## 📋 Project Overview

**Mini Stealth Interceptor** is a simplified version of a comprehensive API Hooking Engine developed using NASM x86 Assembly Language. This mini project demonstrates the core concepts of low-level API hooking and serves as a proof of concept for understanding system-level programming.

### 👥 Team Members
- **Muhammad Adeel Haider** (Student ID: 241541)
- **Umar Farooq** (Student ID: 241575)

### 📚 Course Information
- **Course**: Computer Organization and Assembly Language (COAL)
- **Semester**: 5th Semester
- **Program**: BS Cyber Security (BSCYS-F24-A)

---

## 🎯 Project Objectives

1. **Demonstrate Low-Level System Understanding**: Understanding Windows internals and CPU architecture
2. **Implement API Hooking**: Create a working "Trampoline Hook" mechanism
3. **Educational Demonstration**: Show how API interception works
4. **Minimal but Complete**: Provide a fully functional mini version

---

## 🏗️ Architecture

```
┌─────────────────────────────────────────────┐
│      MINI STEALTH INTERCEPTOR ENGINE         │
├─────────────────────────────────────────────┤
│                                              │
│  ┌──────────────┐    ┌──────────────┐       │
│  │   Hooking    │───▶│  MessageBox  │       │
│  │   Engine     │    │     Hook     │       │
│  └──────────────┘    └──────────────┘       │
│         │                   │                │
│         ▼                   ▼                │
│  ┌──────────────┐    ┌──────────────┐       │
│  │  Trampoline  │    │   Logging    │       │
│  │  Management  │    │   System     │       │
│  └──────────────┘    └──────────────┘       │
│                                              │
└─────────────────────────────────────────────┘
```

---

## 📁 Project Structure

```
mini/
├── 📂 src/
│   ├── 📂 core/
│   │   └── hook_engine.asm      # Simplified hooking engine
│   ├── 📂 hooks/
│   │   └── messagebox_hook.asm  # MessageBox API hook
│   └── 📂 demo/
│       └── demo_main.asm        # Interactive demo
├── 📂 docs/
│   ├── 📄 Technical_Report.md   # Technical documentation
│   ├── 📄 User_Manual.md        # User guide
│   ├── 📄 API_Reference.md      # API documentation
│   └── 📄 Security_Advisory.md  # Security considerations
├── 📂 tests/
│   └── test_basic.asm           # Basic tests
├── 📂 scripts/
│   ├── build.bat                # Build script
│   ├── clean.bat                # Cleanup script
│   └── test_runner.bat          # Test runner
├── 📄 CMakeLists.txt            # CMake configuration
├── 📄 Makefile                  # GNU Make configuration
├── 📄 LICENSE                   # License file
└── 📄 README.md                 # This file
```

---

## 🔧 Technical Implementation

### The Trampoline Technique

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
│ 2. Log the Call             │ ◄── Our interceptor logic
│ 3. Restore All Registers    │ ◄── POPAD/POPFD
│ 4. Execute Stolen Bytes     │ ◄── Original first 5 bytes
│ 5. JMP Back to Original+5   │ ◄── Resume execution
└─────────────────────────────┘
```

### Key Techniques Used

1. **Memory Protection Modification**: Using VirtualProtect to modify code sections
2. **Register Preservation**: PUSHAD/POPAD for CPU state preservation
3. **Trampoline Creation**: Building relay code for original function execution
4. **Instruction Cache Flushing**: Ensuring changes are visible to CPU

---

## 🚀 Quick Start

### Prerequisites

#### NASM Version (Current - Fully Working)
- **NASM**: Netwide Assembler ([download](https://www.nasm.us/))
- **Linux**: MinGW cross-compiler (`sudo apt-get install mingw-w64 gcc-mingw-w64-i686`)
- **Windows**: NASM + any linker (Visual Studio LINK.exe or GoLink)

#### MASM Version (Original)
- **Operating System**: Windows 10/11 (x86 or x86-64 with WoW64)
- **MASM32**: Microsoft Macro Assembler (download from http://www.masm32.com/)

### Building the Project

#### Using NASM (Recommended)

**On Linux:**
```bash
# Using Makefile
make -f Makefile_nasm all

# Output: bin/MiniStealthInterceptor.exe (15KB)

# Or use the build script from root
cd ..
./scripts/build_nasm.sh mini
```

**On Windows:**
```batch
REM Using build script
..\scripts\build_nasm.bat mini

REM Or manually
nasm -f win32 -o build\obj\hook_engine_nasm.obj src\core\hook_engine_nasm.asm
nasm -f win32 -o build\obj\messagebox_hook_nasm.obj src\hooks\messagebox_hook_nasm.asm
nasm -f win32 -o build\obj\demo_main_nasm.obj src\demo\demo_main_nasm.asm
link /SUBSYSTEM:CONSOLE /ENTRY:_main /OUT:bin\MiniStealthInterceptor.exe build\obj\*.obj kernel32.lib user32.lib
```

#### Using MASM (Original)

**Using the Build Script:**
```batch
# Run the build script
scripts\build.bat
```

**Using Make:**
```batch
# Using GNU Make
make all
```

### Running the Demo

**On Windows:**
```batch
# Run the executable
bin\MiniStealthInterceptor.exe
```

**On Linux (with Wine):**
```bash
# Install Wine if needed
sudo apt-get install wine wine32

# Run with Wine
wine bin/MiniStealthInterceptor.exe
```

### Interactive Menu

Once running, you'll see:
```
==========================================
  MINI STEALTH INTERCEPTOR
  Simplified API Hooking Demo
==========================================
  By: Muhammad Adeel Haider (241541)
      Umar Farooq (241575)
  COAL - BS Cyber Security
==========================================

--- Main Menu ---
1. Install MessageBox Hook
2. Remove MessageBox Hook
3. Test MessageBox
4. Show Statistics
5. Exit

Choose (1-5):
```

### Usage Example
1. Press `1` to install the MessageBox hook
2. Press `3` to test - you'll see a MessageBox appear (intercepted!)
3. Press `4` to view statistics showing interception count
4. Press `2` to remove the hook
5. Press `5` to exit

---

## 💻 Code Example

### Basic Hook Installation

```asm
; Install hook on MessageBoxA
call InstallMessageBoxHook
test eax, eax
jz @Failed

; Hook is now active
; Any MessageBoxA calls will be intercepted

@Failed:
; Handle error
```

---

## 📊 Features

### ✅ Implemented Features

| Feature | Status | Description |
|---------|--------|-------------|
| MessageBox Hook | ✅ | Intercepts MessageBoxA calls |
| Hook Engine | ✅ | Core hooking infrastructure |
| Trampoline System | ✅ | Safe function redirection |
| Statistics Tracking | ✅ | Count intercepted calls |
| Interactive Demo | ✅ | User-friendly demonstration |

---

## 🧪 Testing

### Running Tests

```batch
# Run the test
scripts\test_runner.bat
```

### Manual Testing
1. Build the project
2. Run the executable
3. Install the MessageBox hook (option 1)
4. Test with MessageBox (option 3)
5. Check statistics (option 4)

---

## 📚 Documentation

| Document | Description |
|----------|-------------|
| [Technical Report](docs/Technical_Report.md) | Detailed technical documentation |
| [User Manual](docs/User_Manual.md) | Step-by-step usage guide |
| [API Reference](docs/API_Reference.md) | API documentation |
| [Security Advisory](docs/Security_Advisory.md) | Security considerations |

---

## ⚠️ Security Notice

**EDUCATIONAL PURPOSE ONLY**

This mini project is developed for educational purposes to demonstrate:

1. **Understanding** how API hooking works at a low level
2. **Learning** assembly language programming
3. **Practicing** system-level development skills

### Ethical Guidelines

- ❌ Do NOT use this code on systems you don't own
- ❌ Do NOT use for malicious purposes
- ✅ Use only in controlled, isolated environments
- ✅ Always obtain proper authorization

---

## 📈 Differences from Full Version

This mini version is simplified compared to the full project:

| Feature | Full Version | Mini Version |
|---------|-------------|--------------|
| Hook Types | Multiple (File, Network, Process) | MessageBox only |
| Max Hooks | 256 | 16 |
| Thread Safety | Full critical sections | Basic |
| Hook Management | Advanced (pause/resume) | Basic (install/remove) |
| Code Size | ~2000+ lines | ~500 lines |

---

## 🛠️ Troubleshooting

### Common Issues

**Issue**: "MASM32 not found"
- **Solution**: Install MASM32 to C:\masm32 or update paths in build scripts

**Issue**: Application crashes
- **Solution**: Run as Administrator, verify you're on Windows x86 or WoW64

**Issue**: Hook not triggering
- **Solution**: Ensure the hook is installed before testing

---

## 📄 License

This project is licensed for **Educational Use Only**. See [LICENSE](LICENSE) for details.

---

## 🙏 Acknowledgments

- Microsoft for MASM and Windows API documentation
- Our COAL course instructor for guidance
- The broader security research community

---

## 📞 Contact

For questions or feedback:
- **Muhammad Adeel Haider**: [241541@students.au.edu.pk]
- **Umar Farooq**: [241575@students.au.edu.pk]

---

<p align="center">
  <b>🛡️ Mini Stealth Interceptor - Learning Assembly & Security 🛡️</b>
</p>
