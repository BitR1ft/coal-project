# User Manual: Mini Stealth Interceptor

---

## Welcome to Mini Stealth Interceptor!

This user manual will guide you through building, running, and using the Mini Stealth Interceptor API Hooking demonstration.

---

## Table of Contents

1. [System Requirements](#system-requirements)
2. [Installation](#installation)
3. [Building the Project](#building-the-project)
4. [Running the Demo](#running-the-demo)
5. [Using the Application](#using-the-application)
6. [Troubleshooting](#troubleshooting)
7. [FAQ](#faq)

---

## System Requirements

### Minimum Requirements

- **Operating System**: Windows 10 or Windows 11
- **Architecture**: x86 (32-bit) or x64 with WoW64 support
- **RAM**: 512 MB
- **Disk Space**: 10 MB for source code and binaries

### Software Requirements

- **MASM32**: Microsoft Macro Assembler
  - Download from: http://www.masm32.com/
  - Default installation path: C:\masm32

### Optional Tools

- **Text Editor**: Notepad++, VS Code, or any text editor
- **Debugger**: x32dbg or OllyDbg (for advanced users)

---

## Installation

### Step 1: Install MASM32

1. Download MASM32 installer from http://www.masm32.com/
2. Run the installer
3. Install to the default location (C:\masm32)
4. Complete the installation

### Step 2: Get the Source Code

The Mini Stealth Interceptor is located in the `mini/` folder of the main project.

```
coal-project/
└── mini/          ← You are here
```

---

## Building the Project

### Method 1: Using the Build Script (Recommended)

1. Open Command Prompt
2. Navigate to the mini project directory:
   ```batch
   cd path\to\coal-project\mini
   ```
3. Run the build script:
   ```batch
   scripts\build.bat
   ```
4. Wait for compilation to complete

### Method 2: Using Make

If you have GNU Make installed:

```batch
make all
```

### Method 3: Manual Build

For advanced users who want to understand the build process:

```batch
REM Create directories
mkdir build\obj\core
mkdir build\obj\hooks
mkdir build\obj\demo
mkdir bin

REM Compile hook engine
C:\masm32\bin\ml.exe /c /coff /Zi /IC:\masm32\include ^
    /Fobuild\obj\core\hook_engine.obj src\core\hook_engine.asm

REM Compile messagebox hook
C:\masm32\bin\ml.exe /c /coff /Zi /IC:\masm32\include ^
    /Fobuild\obj\hooks\messagebox_hook.obj src\hooks\messagebox_hook.asm

REM Compile demo
C:\masm32\bin\ml.exe /c /coff /Zi /IC:\masm32\include ^
    /Fobuild\obj\demo\demo_main.obj src\demo\demo_main.asm

REM Link
C:\masm32\bin\link.exe /SUBSYSTEM:CONSOLE /LIBPATH:C:\masm32\lib ^
    /OUT:bin\MiniStealthInterceptor.exe ^
    build\obj\demo\demo_main.obj ^
    build\obj\core\hook_engine.obj ^
    build\obj\hooks\messagebox_hook.obj ^
    kernel32.lib user32.lib
```

### Verifying the Build

After successful compilation, you should have:
```
mini/
└── bin/
    └── MiniStealthInterceptor.exe  ← Your executable
```

---

## Running the Demo

### Starting the Application

1. Open Command Prompt as **Administrator** (recommended)
2. Navigate to the mini directory
3. Run the executable:
   ```batch
   bin\MiniStealthInterceptor.exe
   ```

### What You'll See

```
==========================================
  MINI STEALTH INTERCEPTOR
  Simplified API Hooking Demo
==========================================
  By: Muhammad Adeel Haider (241541)
      Umar Farooq (241575)
  COAL - BS Cyber Security
==========================================

[+] Hook Engine initialized!

--- Main Menu ---
1. Install MessageBox Hook
2. Remove MessageBox Hook
3. Test MessageBox
4. Show Statistics
5. Exit

Choose (1-5):
```

---

## Using the Application

### Option 1: Install MessageBox Hook

**What it does**: Installs an interceptor on the MessageBoxA Windows API function.

**Steps:**
1. Type `1` and press Enter
2. You'll see: `[+] MessageBox hook INSTALLED`
3. The hook is now active

**What happens now:**
- All MessageBoxA calls will be intercepted
- Debug output will show `[Mini Hook] MessageBoxA intercepted!`
- Statistics counter will increment

---

### Option 2: Remove MessageBox Hook

**What it does**: Removes the hook and restores original MessageBoxA function.

**Steps:**
1. Type `2` and press Enter
2. You'll see: `[+] MessageBox hook REMOVED`
3. The hook is now inactive

---

### Option 3: Test MessageBox

**What it does**: Displays a MessageBox to test if the hook is working.

**Steps:**
1. Ensure the hook is installed (Option 1)
2. Type `3` and press Enter
3. A MessageBox will appear
4. Click OK to dismiss it

**Expected behavior:**
- If hook is active: Console shows interception message
- If hook is inactive: MessageBox appears normally (no logging)

---

### Option 4: Show Statistics

**What it does**: Displays the number of intercepted MessageBox calls.

**Steps:**
1. Type `4` and press Enter
2. You'll see:
   ```
   --- Statistics ---
   Interceptions: X
   ```
   Where X is the number of times MessageBoxA was called while the hook was active.

---

### Option 5: Exit

**What it does**: Cleanly shuts down the application.

**Steps:**
1. Type `5` and press Enter
2. The application will:
   - Remove any active hooks
   - Free allocated memory
   - Display goodbye message
   - Exit

---

## Troubleshooting

### Problem: "MASM32 not found"

**Cause**: MASM32 is not installed or not in the expected location.

**Solutions:**
1. Install MASM32 to C:\masm32
2. Or, edit the build scripts to point to your MASM32 location

---

### Problem: "Access Denied" or crashes

**Cause**: Insufficient permissions to modify memory.

**Solutions:**
1. Run Command Prompt as Administrator
2. Ensure you're on Windows (not Wine/Linux)
3. Check antivirus isn't blocking the program

---

### Problem: "Hook not triggering"

**Cause**: Hook may not be installed correctly.

**Solutions:**
1. Verify hook is installed (use Option 4 to check)
2. Try removing and reinstalling the hook
3. Restart the application

---

### Problem: Build fails with "error A2008"

**Cause**: MASM syntax error or missing includes.

**Solutions:**
1. Verify MASM32 is properly installed
2. Check that include paths are correct
3. Ensure all source files are present

---

## FAQ

### Q: Is this safe to use?

**A**: Yes, when used for educational purposes on your own system. Always run in a controlled environment.

---

### Q: Will this work on 64-bit Windows?

**A**: Yes, through WoW64 (Windows-on-Windows 64-bit), which allows 32-bit applications to run on 64-bit Windows.

---

### Q: Can I hook other functions?

**A**: This mini version only hooks MessageBoxA. The full version (in the parent directory) has more hooks.

---

### Q: Why do I need Administrator rights?

**A**: Modifying code in memory requires elevated privileges for security reasons.

---

### Q: What's the difference between this and the full version?

**A**: This mini version:
- Has fewer features (only MessageBox hook)
- Is simpler to understand
- Uses less code (~500 lines vs 2000+)
- Demonstrates core concepts

---

### Q: Can I use this for my own projects?

**A**: Yes, but remember it's for educational purposes only. Always follow ethical guidelines and legal requirements.

---

### Q: Where can I learn more?

**A**: Check the other documentation files:
- Technical_Report.md - Detailed technical information
- API_Reference.md - API documentation
- Security_Advisory.md - Security considerations

---

## Need Help?

If you encounter issues not covered in this manual:

1. Check the Technical Report for implementation details
2. Review the source code comments
3. Contact the developers:
   - Muhammad Adeel Haider: 241541@students.au.edu.pk
   - Umar Farooq: 241575@students.au.edu.pk

---

**Manual Version**: 1.0  
**Last Updated**: December 2024  
**Authors**: Muhammad Adeel Haider & Umar Farooq
