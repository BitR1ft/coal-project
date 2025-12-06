# API Reference: Mini Stealth Interceptor

---

## Overview

This document provides a complete reference for all functions, procedures, and data structures in the Mini Stealth Interceptor API Hooking Engine.

---

## Table of Contents

1. [Hook Engine API](#hook-engine-api)
2. [MessageBox Hook API](#messagebox-hook-api)
3. [Data Structures](#data-structures)
4. [Constants](#constants)
5. [Error Codes](#error-codes)

---

## Hook Engine API

### InitializeHookEngine

**Description**: Initializes the hook engine and allocates necessary resources.

**Syntax**:
```asm
call InitializeHookEngine
```

**Parameters**: None

**Returns**:
- `EAX = 1` on success
- `EAX = 0` on failure

**Side Effects**:
- Allocates heap memory for trampolines
- Sets `g_bInitialized` to 1

**Example**:
```asm
call InitializeHookEngine
test eax, eax
jz @InitFailed

; Engine is now initialized
```

**Notes**:
- Must be called before any hook installation
- Can be called multiple times safely (returns success if already initialized)
- Allocates space for up to 16 trampolines

---

### ShutdownHookEngine

**Description**: Shuts down the hook engine and frees allocated resources.

**Syntax**:
```asm
call ShutdownHookEngine
```

**Parameters**: None

**Returns**:
- `EAX = 1` on success

**Side Effects**:
- Frees trampoline heap memory
- Sets `g_bInitialized` to 0

**Example**:
```asm
; Before exiting application
call ShutdownHookEngine
```

**Notes**:
- Should be called before application exit
- Automatically removes all hooks (in full version)
- Safe to call even if not initialized

---

## MessageBox Hook API

### InstallMessageBoxHook

**Description**: Installs a hook on the MessageBoxA API function.

**Syntax**:
```asm
call InstallMessageBoxHook
```

**Parameters**: None

**Returns**:
- `EAX = 1` on success
- `EAX = 0` on failure

**Side Effects**:
- Modifies MessageBoxA function in memory
- Creates a trampoline for the original function
- Sets `g_bHookEnabled` to 1
- Increments `g_dwInterceptCount` on each interception

**Example**:
```asm
call InstallMessageBoxHook
test eax, eax
jz @HookFailed

; Hook is now installed
; All MessageBoxA calls will be intercepted

@HookFailed:
; Handle error
```

**Technical Details**:
1. Loads user32.dll
2. Gets MessageBoxA address
3. Changes memory protection to PAGE_EXECUTE_READWRITE
4. Allocates 32 bytes for trampoline
5. Copies first 5 bytes of MessageBoxA to trampoline
6. Adds JMP instruction to trampoline
7. Overwrites first 5 bytes of MessageBoxA with JMP to hook handler
8. Flushes instruction cache

**Notes**:
- Requires Administrator privileges
- Hook persists until removed or application exits
- Can be called multiple times safely (returns success if already installed)

---

### RemoveMessageBoxHook

**Description**: Removes the MessageBox hook and restores original function.

**Syntax**:
```asm
call RemoveMessageBoxHook
```

**Parameters**: None

**Returns**:
- `EAX = 1` on success

**Side Effects**:
- Restores original MessageBoxA bytes
- Frees trampoline memory
- Sets `g_bHookEnabled` to 0

**Example**:
```asm
call RemoveMessageBoxHook

; MessageBoxA is now restored to original state
```

**Technical Details**:
1. Changes memory protection
2. Copies original 5 bytes from trampoline back to MessageBoxA
3. Frees trampoline memory
4. Flushes instruction cache

**Notes**:
- Safe to call even if hook not installed
- Should be called before application exit

---

### GetMessageBoxHookStats

**Description**: Retrieves statistics about MessageBox hook interceptions.

**Syntax**:
```asm
push pInterceptCount
call GetMessageBoxHookStats
```

**Parameters**:
- `pInterceptCount` (DWORD pointer): Pointer to receive interception count

**Returns**:
- `EAX = 1` if hook is active
- `EAX = 0` if hook is inactive
- `[pInterceptCount]` is set to the number of interceptions

**Example**:
```asm
.data?
    dwCount DWORD ?

.code
    lea eax, dwCount
    push eax
    call GetMessageBoxHookStats
    
    ; EAX contains hook status
    ; dwCount contains number of interceptions
```

**Notes**:
- `pInterceptCount` can be NULL if you only want status
- Counter is not reset when hook is removed/reinstalled

---

### MessageBoxAHookHandler (Internal)

**Description**: Internal hook handler that intercepts MessageBoxA calls.

**Syntax**: Not called directly - invoked automatically when MessageBoxA is called

**Parameters** (on stack):
- `[ebp+8]` = hWnd (HWND)
- `[ebp+12]` = lpText (LPCSTR)
- `[ebp+16]` = lpCaption (LPCSTR)
- `[ebp+20]` = uType (UINT)

**Returns**: Same as MessageBoxA

**Behavior**:
1. Saves all registers (PUSHAD, PUSHFD)
2. Outputs debug message
3. Increments interception counter
4. Restores registers (POPFD, POPAD)
5. Calls original MessageBoxA via trampoline
6. Returns result to caller

**Notes**:
- Preserves all registers and flags
- Maintains proper stack alignment
- Uses stdcall calling convention

---

## Data Structures

### Global Variables (Hook Engine)

```asm
g_bInitialized   DWORD ?  ; 1 if engine initialized, 0 otherwise
g_dwOldProtect   DWORD ?  ; Saved memory protection flags
g_pTrampolineHeap DWORD ? ; Pointer to trampoline heap
```

### Global Variables (MessageBox Hook)

```asm
g_hUser32            DWORD 0  ; Handle to user32.dll
g_pOriginalMsgBoxA   DWORD 0  ; Pointer to original MessageBoxA
g_pTrampolineA       DWORD 0  ; Pointer to trampoline code
g_bHookEnabled       DWORD 0  ; 1 if hook installed, 0 otherwise
g_dwInterceptCount   DWORD 0  ; Number of interceptions
```

---

## Constants

### Hook Engine Constants

```asm
HOOK_SIZE        EQU 5   ; Size of JMP instruction in bytes
MAX_HOOKS        EQU 16  ; Maximum concurrent hooks
TRAMPOLINE_SIZE  EQU 32  ; Size of each trampoline in bytes
```

### Memory Protection Constants

```asm
PAGE_EXECUTE_READWRITE  ; Memory protection flag (Windows API)
MEM_COMMIT              ; Memory allocation flag (Windows API)
MEM_RESERVE             ; Memory allocation flag (Windows API)
MEM_RELEASE             ; Memory deallocation flag (Windows API)
```

---

## Error Codes

| Value | Meaning |
|-------|---------|
| 1 | Success |
| 0 | Failure (generic) |

**Common Failure Causes**:
- Insufficient privileges (not Administrator)
- Failed memory allocation
- Failed to load DLL
- Failed to find API function
- Failed to change memory protection

---

## Calling Conventions

All exported procedures use the **stdcall** calling convention:
- Parameters pushed right-to-left
- Caller pushes parameters
- Callee cleans up stack
- Return value in EAX

**Example**:
```asm
; Calling GetMessageBoxHookStats(pInterceptCount)
push pInterceptCount  ; Push parameter
call GetMessageBoxHookStats  ; Call (callee cleans stack)
; Result in EAX
```

---

## Memory Management

### Trampoline Allocation

- Size: 32 bytes per trampoline
- Total allocation: 512 bytes (16 trampolines × 32 bytes)
- Permissions: PAGE_EXECUTE_READWRITE
- Lifetime: Until ShutdownHookEngine is called

### Memory Layout

```
Trampoline Structure (32 bytes):
+0  : [5 bytes] Stolen original instructions
+5  : [5 bytes] JMP back to original+5
+10 : [22 bytes] Unused (reserved)
```

---

## Best Practices

### Initialization Order

1. Call InitializeHookEngine
2. Call InstallMessageBoxHook
3. Use hooked functions
4. Call RemoveMessageBoxHook
5. Call ShutdownHookEngine

### Error Handling

Always check return values:
```asm
call InitializeHookEngine
test eax, eax
jz @Error

call InstallMessageBoxHook
test eax, eax
jz @Error

; Success path
jmp @Continue

@Error:
; Handle error
```

### Cleanup

Always clean up before exit:
```asm
; Before ExitProcess
call RemoveMessageBoxHook
call ShutdownHookEngine
push 0
call ExitProcess
```

---

## Platform-Specific Notes

### Windows Versions
- Tested on: Windows 10, Windows 11
- Should work on: Windows 7, Windows 8, Windows 8.1

### Architecture
- Target: x86 (32-bit)
- On x64 Windows: Runs via WoW64

### Dependencies
- kernel32.dll (always loaded)
- user32.dll (loaded by InstallMessageBoxHook)

---

**API Reference Version**: 1.0  
**Last Updated**: December 2024  
**Authors**: Muhammad Adeel Haider & Umar Farooq
