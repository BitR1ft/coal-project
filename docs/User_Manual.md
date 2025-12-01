# User Manual: The Stealth Interceptor

## API Hooking Engine - User Guide

---

## Table of Contents

1. [Introduction](#1-introduction)
2. [System Requirements](#2-system-requirements)
3. [Installation](#3-installation)
4. [Quick Start Guide](#4-quick-start-guide)
5. [Using the Demo Application](#5-using-the-demo-application)
6. [Understanding the Hooks](#6-understanding-the-hooks)
7. [Viewing Hook Activity](#7-viewing-hook-activity)
8. [Troubleshooting](#8-troubleshooting)
9. [FAQ](#9-faq)
10. [Support](#10-support)

---

## 1. Introduction

### 1.1 What is The Stealth Interceptor?

The Stealth Interceptor is an educational API Hooking Engine that demonstrates how software can intercept Windows system calls. It's designed to teach Cyber Security students about:

- How antivirus and security software monitors system behavior
- How malware intercepts API calls
- Low-level Windows programming concepts
- x86 Assembly language techniques

### 1.2 Who Should Use This?

This tool is intended for:
- Cyber Security students
- Malware analysts
- Security researchers
- Assembly language learners
- Windows internals enthusiasts

### 1.3 Educational Purpose Disclaimer

⚠️ **IMPORTANT**: This software is for **educational purposes only**. Do not use it on systems you don't own or without proper authorization. The techniques demonstrated should be used responsibly and ethically.

---

## 2. System Requirements

### 2.1 Hardware Requirements

| Component | Minimum | Recommended |
|-----------|---------|-------------|
| Processor | x86/x64 CPU | Intel Core i5 or AMD equivalent |
| RAM | 2 GB | 4 GB or more |
| Disk Space | 100 MB | 500 MB |
| Display | 1024x768 | 1920x1080 |

### 2.2 Software Requirements

| Software | Version | Purpose |
|----------|---------|---------|
| Windows | 10/11 | Operating System |
| Visual Studio | 2019/2022 | Build environment |
| MASM32 | Latest | Assembler |
| x64dbg | Latest (optional) | Debugging |
| DebugView | Latest (optional) | Log viewing |

### 2.3 Required Visual Studio Components

When installing Visual Studio, ensure you select:
- Desktop development with C++
- Windows 10/11 SDK
- MSVC x86/x64 build tools

---

## 3. Installation

### 3.1 Step-by-Step Installation

#### Step 1: Install Visual Studio

1. Download Visual Studio from [visualstudio.microsoft.com](https://visualstudio.microsoft.com/)
2. Run the installer
3. Select "Desktop development with C++" workload
4. Click Install and wait for completion

#### Step 2: Install MASM32

1. Download MASM32 from [masm32.com](http://www.masm32.com/)
2. Extract to `C:\masm32`
3. Run the install script if provided
4. Verify installation:
   ```cmd
   C:\masm32\bin\ml.exe /?
   ```

#### Step 3: Clone the Repository

```cmd
git clone https://github.com/BitR1ft/coal-project.git
cd coal-project
```

#### Step 4: Run Setup Script

```cmd
scripts\setup.bat
```

This will:
- Check prerequisites
- Create necessary directories
- Set environment variables

#### Step 5: Build the Project

1. Open "Developer Command Prompt for VS 2022"
2. Navigate to project directory
3. Run:
   ```cmd
   scripts\build.bat
   ```

### 3.2 Verifying Installation

After building, you should see:
```
============================================================
  BUILD SUCCESSFUL!
============================================================
  Output: bin\Release\StealthInterceptor.exe
============================================================
```

---

## 4. Quick Start Guide

### 4.1 Running the Demo

1. Open Command Prompt as Administrator (recommended)
2. Navigate to project directory
3. Run:
   ```cmd
   bin\Release\StealthInterceptor.exe
   ```

### 4.2 Your First Hook

1. Start the application
2. Press `1` to install MessageBox hook
3. Press `5` to test MessageBox
4. Observe the interception message
5. Press `1` again to remove the hook

### 4.3 Viewing Hook Activity

1. Download and run [DebugView](https://docs.microsoft.com/en-us/sysinternals/downloads/debugview)
2. Enable "Capture Global Win32"
3. Run hooks and watch for `[Hook]` messages

---

## 5. Using the Demo Application

### 5.1 Main Menu

When you run StealthInterceptor.exe, you'll see:

```
====================================================
  THE STEALTH INTERCEPTOR - API Hooking Engine
  Version 1.0.0 - Educational Demo
====================================================
  By: Muhammad Adeel Haider & Umar Farooq
  Course: COAL - 5th Semester, BS Cyber Security
====================================================

--- Main Menu ---
1. Install/Remove MessageBox Hook
2. Install/Remove File Hooks
3. Install/Remove Network Hooks
4. Install/Remove Process Hooks
5. Test MessageBox (Trigger Hook)
6. Show Hook Statistics
7. Remove All Hooks
8. Exit

Enter your choice (1-8):
```

### 5.2 Menu Options Explained

#### Option 1: MessageBox Hook

Toggles hook on `MessageBoxA` and `MessageBoxW` functions.

When active:
- All MessageBox calls are intercepted
- Title and message are logged
- Original MessageBox still appears

#### Option 2: File Hooks

Toggles hooks on file operations:
- CreateFileA/W - File creation/opening
- ReadFile - File reading
- WriteFile - File writing
- DeleteFileA - File deletion

#### Option 3: Network Hooks

Toggles hooks on network functions:
- socket() - Socket creation
- connect() - Connection establishment
- send() - Data sending
- recv() - Data receiving

**Note**: Requires ws2_32.dll to be loaded

#### Option 4: Process Hooks

Toggles hooks on process functions:
- CreateProcessA/W - Process creation
- TerminateProcess - Process termination
- OpenProcess - Process handle acquisition

#### Option 5: Test MessageBox

Displays a test MessageBox to demonstrate hook interception.

#### Option 6: Show Statistics

Displays statistics for all installed hooks:
- Interception counts
- Bytes sent/received (network)
- Files accessed (file hooks)
- Processes monitored

#### Option 7: Remove All Hooks

Safely removes all installed hooks and restores original functions.

#### Option 8: Exit

Cleanly shuts down the application:
- Removes all hooks
- Frees allocated memory
- Restores system state

---

## 6. Understanding the Hooks

### 6.1 How Hooks Work

When a hook is installed:

1. **Original Function**:
   ```
   MessageBoxA:
     mov edi, edi
     push ebp
     mov ebp, esp
     ... (rest of function)
   ```

2. **After Hooking**:
   ```
   MessageBoxA:
     JMP HookHandler      <- Jump to our code
     nop
     mov ebp, esp
     ... (rest of function)
   ```

3. **Our Handler**:
   ```
   HookHandler:
     Save registers
     Log the call
     Increment counter
     Restore registers
     Call trampoline      <- Execute original code
     Return to caller
   ```

### 6.2 The Trampoline

The trampoline allows calling the original function:

```
Trampoline:
  mov edi, edi           <- Stolen bytes (original first instructions)
  push ebp
  JMP MessageBoxA+5      <- Jump back past our hook
```

### 6.3 Hook Lifecycle

```
┌─────────────────┐
│  Hook Inactive  │
└────────┬────────┘
         │ Install Hook
         ▼
┌─────────────────┐
│   Hook Active   │ ◀──────┐
└────────┬────────┘        │ Resume
         │                 │
    Remove │   Pause      │
         ▼         │       │
┌─────────────────┐        │
│  Hook Inactive  │        │
│    (Removed)    │ ───────┘
└─────────────────┘
```

---

## 7. Viewing Hook Activity

### 7.1 Using DebugView

1. Download from Microsoft Sysinternals
2. Run as Administrator
3. Go to Capture → Capture Global Win32
4. Messages appear with prefix `[Hook]`, `[FileHook]`, etc.

### 7.2 Log Messages Format

```
[Hook] MessageBoxA intercepted!
[Hook] Title: Test MessageBox | Message: This is a test...
[FileHook] CreateFile: C:\Users\...\file.txt (READ)
[NetHook] socket() - AF: 2 Type: 1 Proto: 6
[ProcHook] CreateProcess: notepad.exe
```

### 7.3 Log File

If file logging is enabled, logs are written to:
```
stealth_interceptor.log
```

---

## 8. Troubleshooting

### 8.1 Common Issues

#### Issue: "Access Denied" Error

**Solution**: Run as Administrator
```cmd
runas /user:Administrator bin\Release\StealthInterceptor.exe
```

#### Issue: Application Crashes

**Possible Causes**:
- Incompatible function prologue
- Memory corruption
- Missing DLL

**Solution**: 
1. Remove all hooks: Option 7
2. Restart application
3. Try hooks one at a time

#### Issue: Hooks Not Working

**Check**:
1. Is the hook active? (Option 6)
2. Are you using the correct function version (A vs W)?
3. Is the target DLL loaded?

#### Issue: Network Hooks Fail

**Reason**: ws2_32.dll not loaded yet

**Solution**: Make a network call first, then install hooks

#### Issue: Build Errors

**Check**:
1. Visual Studio installed correctly
2. MASM32 in C:\masm32
3. Running from Developer Command Prompt

### 8.2 Error Messages

| Error | Meaning | Solution |
|-------|---------|----------|
| "Hook Engine not initialized" | Engine failed to start | Check memory/permissions |
| "Maximum hooks reached" | 256 hooks limit | Remove unused hooks |
| "Memory protection failed" | VirtualProtect error | Check DEP settings |
| "DLL not loaded" | Target DLL missing | Load DLL first |

---

## 9. FAQ

### Q: Is this legal to use?

A: Yes, for educational purposes on your own systems. Never use on systems without authorization.

### Q: Will antivirus detect this?

A: Possibly. This uses techniques similar to malware. Add exceptions for educational use.

### Q: Can I hook any function?

A: Most user-mode functions can be hooked. Kernel functions require different techniques.

### Q: Why x86 and not x64?

A: x86 is simpler for learning. The concepts translate to x64 with modifications.

### Q: Can hooks crash my system?

A: Hooks only affect the current process. System stability is maintained.

### Q: How do I know if a hook is working?

A: Use DebugView to watch for log messages, or check statistics (Option 6).

### Q: Can I add my own hooks?

A: Yes! Study the existing hooks in `src/hooks/` and create new ones.

---

## 10. Support

### 10.1 Getting Help

- Check the [Technical Report](Technical_Report.md) for details
- Review the [API Reference](API_Reference.md) for function documentation
- Search existing issues on GitHub

### 10.2 Reporting Issues

When reporting issues, include:
1. Windows version
2. Visual Studio version
3. Error messages
4. Steps to reproduce
5. DebugView output

### 10.3 Contact

- **Muhammad Adeel Haider**: 241541@students.au.edu.pk
- **Umar Farooq**: 241575@students.au.edu.pk

---

## Appendix A: Keyboard Shortcuts

| Key | Action |
|-----|--------|
| 1-8 | Select menu option |
| Enter | Confirm selection |
| Ctrl+C | Emergency exit |

## Appendix B: File Locations

| File | Location |
|------|----------|
| Executable | `bin\Release\StealthInterceptor.exe` |
| Log File | `stealth_interceptor.log` |
| Source Code | `src\` |
| Documentation | `docs\` |

---

*User Manual v1.0 - The Stealth Interceptor*
*COAL Project - 5th Semester, BS Cyber Security*
