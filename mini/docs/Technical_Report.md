# Technical Report: Mini Stealth Interceptor

## API Hooking Engine Using MASM x86 Assembly

---

### Project Information

| Field | Details |
|-------|---------|
| **Project Title** | Mini Stealth Interceptor - API Hooking Engine |
| **Course** | Computer Organization and Assembly Language (COAL) |
| **Semester** | 5th Semester |
| **Program** | BS Cyber Security (BSCYS-F24-A) |
| **Team Members** | Muhammad Adeel Haider (241541), Umar Farooq (241575) |
| **Submission Date** | December 2024 |

---

## Table of Contents

1. [Executive Summary](#1-executive-summary)
2. [Introduction](#2-introduction)
3. [Technical Architecture](#3-technical-architecture)
4. [Implementation Details](#4-implementation-details)
5. [Testing and Validation](#5-testing-and-validation)
6. [Challenges and Solutions](#6-challenges-and-solutions)
7. [Conclusion](#7-conclusion)
8. [References](#8-references)

---

## 1. Executive Summary

The Mini Stealth Interceptor is a simplified but fully functional API hooking engine implemented in pure x86 Assembly language. This project demonstrates the core concepts of API interception using the trampoline technique.

**Key Achievements:**
- Successfully implemented trampoline-based API hooking
- Created a working MessageBox interceptor
- Developed a user-friendly demonstration application
- Achieved stable execution without system crashes
- Documented all aspects of the implementation

---

## 2. Introduction

### 2.1 Project Motivation

As Cyber Security students, understanding API hooking is essential for:
- **Malware Analysis**: Understanding how malware hides activities
- **Security Research**: Building monitoring and detection tools
- **Low-Level Programming**: Mastering assembly and system internals

### 2.2 Project Scope

This mini version focuses on:
- Core hooking mechanism implementation
- MessageBox API interception
- Safe memory manipulation
- Interactive demonstration

---

## 3. Technical Architecture

### 3.1 System Components

```
┌─────────────────────────────────────┐
│      Hook Engine (hook_engine.asm)  │
│  - Initialization                   │
│  - Trampoline allocation            │
│  - Cleanup                          │
└────────────┬────────────────────────┘
             │
             ▼
┌─────────────────────────────────────┐
│   MessageBox Hook                   │
│   (messagebox_hook.asm)             │
│  - Hook installation                │
│  - Interception handler             │
│  - Statistics tracking              │
└────────────┬────────────────────────┘
             │
             ▼
┌─────────────────────────────────────┐
│      Demo Application               │
│      (demo_main.asm)                │
│  - User interface                   │
│  - Testing capabilities             │
│  - Statistics display               │
└─────────────────────────────────────┘
```

### 3.2 Hook Installation Process

1. **Locate Target Function**: Get MessageBoxA address from user32.dll
2. **Allocate Trampoline**: Create executable memory for relay code
3. **Save Original Bytes**: Store first 5 bytes of target function
4. **Build Trampoline**: Copy saved bytes + JMP back to original
5. **Install Hook**: Write JMP to our handler at target function
6. **Flush Cache**: Ensure CPU sees the changes

---

## 4. Implementation Details

### 4.1 Hook Engine (hook_engine.asm)

**Key Functions:**
- `InitializeHookEngine`: Sets up the hooking infrastructure
- `ShutdownHookEngine`: Cleans up allocated resources

**Design Decisions:**
- Limited to 16 concurrent hooks (sufficient for mini version)
- Simplified error handling
- Heap-based trampoline allocation

### 4.2 MessageBox Hook (messagebox_hook.asm)

**Hook Handler Flow:**
```
1. Save CPU state (PUSHAD, PUSHFD)
2. Log interception event
3. Increment statistics counter
4. Restore CPU state (POPAD, POPFD)
5. Call original function via trampoline
6. Return result to caller
```

**Trampoline Structure:**
```
[5 bytes: Stolen original instructions]
[5 bytes: JMP back to original+5]
```

### 4.3 Demo Application (demo_main.asm)

**Features:**
- Console-based menu system
- Hook installation/removal
- Live testing capability
- Statistics display
- Proper cleanup on exit

**Memory Management:**
- Console I/O buffering
- String conversion utilities
- Input parsing

---

## 5. Testing and Validation

### 5.1 Test Cases

| Test Case | Description | Result |
|-----------|-------------|--------|
| Engine Init | Initialize hook engine | ✅ Pass |
| Hook Install | Install MessageBox hook | ✅ Pass |
| Hook Trigger | Call MessageBoxA with hook active | ✅ Pass |
| Hook Remove | Remove hook and verify | ✅ Pass |
| Statistics | Verify counter increments | ✅ Pass |
| Cleanup | Proper resource cleanup | ✅ Pass |

### 5.2 Validation Methods

1. **Visual Verification**: Debug output shows interceptions
2. **Functional Testing**: MessageBox still works correctly
3. **Statistics Tracking**: Counter accurately reflects calls
4. **Stability Testing**: No crashes during operation

---

## 6. Challenges and Solutions

### 6.1 Challenge: Memory Protection

**Problem**: Cannot write to code section (read-only)

**Solution**: Use VirtualProtect to temporarily change permissions
```asm
push OFFSET g_dwOldProtect
push PAGE_EXECUTE_READWRITE
push 5
push pTargetFunction
call VirtualProtect
```

### 6.2 Challenge: Register Preservation

**Problem**: Modifying registers breaks calling convention

**Solution**: Save/restore all registers
```asm
pushad  ; Save all general-purpose registers
pushfd  ; Save flags
; ... our code ...
popfd   ; Restore flags
popad   ; Restore registers
```

### 6.3 Challenge: Instruction Cache

**Problem**: CPU doesn't see code modifications immediately

**Solution**: Flush instruction cache
```asm
push 5                      ; Size
push pTargetFunction        ; Address
push -1                     ; Current process
call FlushInstructionCache
```

---

## 7. Conclusion

### 7.1 Summary

This mini project successfully demonstrates:
- API hooking at the assembly level
- Memory manipulation techniques
- Safe code injection
- System-level programming skills

### 7.2 Learning Outcomes

1. Deep understanding of x86 architecture
2. Windows API and calling conventions
3. Memory management and protection
4. Low-level debugging skills

### 7.3 Future Enhancements

While this is a simplified version, potential extensions could include:
- Additional API hooks (File I/O, Network)
- Thread safety mechanisms
- More sophisticated disassembly
- Hook chaining support

---

## 8. References

1. Microsoft MASM Documentation
2. Windows API Reference
3. Intel x86 Architecture Manual
4. "Windows Internals" by Mark Russinovich
5. Security research papers on API hooking

---

**Document Version**: 1.0  
**Last Updated**: December 2024  
**Authors**: Muhammad Adeel Haider & Umar Farooq
