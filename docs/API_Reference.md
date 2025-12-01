# API Reference: The Stealth Interceptor

## Complete Function Reference

---

## Table of Contents

1. [Hook Engine Core](#1-hook-engine-core)
2. [Trampoline System](#2-trampoline-system)
3. [Memory Manager](#3-memory-manager)
4. [Register Management](#4-register-management)
5. [MessageBox Hooks](#5-messagebox-hooks)
6. [File Hooks](#6-file-hooks)
7. [Network Hooks](#7-network-hooks)
8. [Process Hooks](#8-process-hooks)
9. [Logging System](#9-logging-system)
10. [String Utilities](#10-string-utilities)
11. [Constants and Structures](#11-constants-and-structures)

---

## 1. Hook Engine Core

### InitializeHookEngine

Initializes the hook engine and allocates necessary resources.

```asm
InitializeHookEngine PROC EXPORT
```

**Parameters**: None

**Returns**: 
- `EAX = HOOK_SUCCESS (0)` on success
- `EAX = error code` on failure

**Example**:
```asm
call InitializeHookEngine
test eax, eax
jnz @Error
```

---

### ShutdownHookEngine

Shuts down the engine and removes all hooks.

```asm
ShutdownHookEngine PROC EXPORT
```

**Parameters**: None

**Returns**: `EAX = HOOK_SUCCESS (0)`

---

### InstallHook

Installs a hook on a target function.

```asm
InstallHook PROC EXPORT pTargetFunc:DWORD, pHookFunc:DWORD, pszFuncName:DWORD
```

**Parameters**:
| Parameter | Type | Description |
|-----------|------|-------------|
| pTargetFunc | DWORD | Address of function to hook |
| pHookFunc | DWORD | Address of hook handler |
| pszFuncName | DWORD | Optional function name (can be NULL) |

**Returns**:
- `EAX = Hook ID (0-255)` on success
- `EAX = -1` on failure

**Example**:
```asm
push OFFSET szMessageBoxA
push OFFSET MyHookHandler
push g_pOriginalMessageBox
call InstallHook
cmp eax, -1
je @Failed
mov g_dwHookId, eax
```

---

### RemoveHook

Removes a previously installed hook.

```asm
RemoveHook PROC EXPORT dwHookId:DWORD
```

**Parameters**:
| Parameter | Type | Description |
|-----------|------|-------------|
| dwHookId | DWORD | Hook ID from InstallHook |

**Returns**:
- `EAX = HOOK_SUCCESS (0)` on success
- `EAX = HOOK_ERR_NOT_FOUND (4)` if hook not found

---

### RemoveAllHooks

Removes all installed hooks.

```asm
RemoveAllHooks PROC EXPORT
```

**Parameters**: None

**Returns**: `EAX = Number of hooks removed`

---

### GetTrampoline

Gets the trampoline address for a hook.

```asm
GetTrampoline PROC EXPORT dwHookId:DWORD
```

**Parameters**:
| Parameter | Type | Description |
|-----------|------|-------------|
| dwHookId | DWORD | Hook ID |

**Returns**:
- `EAX = Trampoline address` on success
- `EAX = 0` if not found

---

### GetHookCount

Returns the number of active hooks.

```asm
GetHookCount PROC EXPORT
```

**Parameters**: None

**Returns**: `EAX = Number of active hooks`

---

### IsHookActive

Checks if a specific hook is active.

```asm
IsHookActive PROC EXPORT dwHookId:DWORD
```

**Parameters**:
| Parameter | Type | Description |
|-----------|------|-------------|
| dwHookId | DWORD | Hook ID to check |

**Returns**:
- `EAX = 1` if active
- `EAX = 0` if inactive

---

## 2. Trampoline System

### InitializeTrampolineSystem

Initializes the trampoline allocation system.

```asm
InitializeTrampolineSystem PROC EXPORT
```

**Returns**: `EAX = 1` on success, `0` on failure

---

### AllocateTrampoline

Allocates a new trampoline buffer.

```asm
AllocateTrampoline PROC EXPORT
```

**Returns**: `EAX = Pointer to trampoline buffer`

---

### BuildTrampoline

Builds a trampoline for a target function.

```asm
BuildTrampoline PROC EXPORT pOriginalFunc:DWORD, dwBytesToSteal:DWORD, pTrampoline:DWORD
```

**Parameters**:
| Parameter | Type | Description |
|-----------|------|-------------|
| pOriginalFunc | DWORD | Original function address |
| dwBytesToSteal | DWORD | Number of bytes to copy |
| pTrampoline | DWORD | Pre-allocated trampoline buffer |

**Returns**: `EAX = 1` on success

---

### GetInstructionLength

Gets the length of an x86 instruction.

```asm
GetInstructionLength PROC EXPORT pInstruction:DWORD
```

**Parameters**:
| Parameter | Type | Description |
|-----------|------|-------------|
| pInstruction | DWORD | Pointer to instruction |

**Returns**: `EAX = Instruction length in bytes`

**Note**: Simplified implementation handles common prologues.

---

### CalculateMinimumBytes

Calculates minimum bytes needed for hook installation.

```asm
CalculateMinimumBytes PROC EXPORT pFunction:DWORD, dwMinimum:DWORD
```

**Parameters**:
| Parameter | Type | Description |
|-----------|------|-------------|
| pFunction | DWORD | Function address |
| dwMinimum | DWORD | Minimum bytes needed (usually 5) |

**Returns**: `EAX = Number of bytes to steal (aligned to instruction boundary)`

---

## 3. Memory Manager

### ChangeMemoryProtection

Changes memory protection for a region.

```asm
ChangeMemoryProtection PROC EXPORT pAddress:DWORD, dwSize:DWORD, dwNewProtect:DWORD, pdwOldProtect:DWORD
```

**Parameters**:
| Parameter | Type | Description |
|-----------|------|-------------|
| pAddress | DWORD | Address of memory region |
| dwSize | DWORD | Size of region |
| dwNewProtect | DWORD | New protection flags |
| pdwOldProtect | DWORD | Pointer to receive old protection |

**Returns**: `EAX = 1` on success, `0` on failure

---

### MakeMemoryWritable

Makes a memory region writable and executable.

```asm
MakeMemoryWritable PROC EXPORT pAddress:DWORD, dwSize:DWORD, pdwOldProtect:DWORD
```

**Parameters**:
| Parameter | Type | Description |
|-----------|------|-------------|
| pAddress | DWORD | Memory address |
| dwSize | DWORD | Size in bytes |
| pdwOldProtect | DWORD | Pointer for old protection |

**Returns**: `EAX = 1` on success

---

### AllocateExecutableMemory

Allocates memory with execute permissions.

```asm
AllocateExecutableMemory PROC EXPORT dwSize:DWORD
```

**Parameters**:
| Parameter | Type | Description |
|-----------|------|-------------|
| dwSize | DWORD | Size to allocate |

**Returns**: `EAX = Pointer to allocated memory`

---

### SafeMemoryCopy

Safely copies memory, handling protection issues.

```asm
SafeMemoryCopy PROC EXPORT pDest:DWORD, pSrc:DWORD, dwSize:DWORD
```

**Parameters**:
| Parameter | Type | Description |
|-----------|------|-------------|
| pDest | DWORD | Destination address |
| pSrc | DWORD | Source address |
| dwSize | DWORD | Bytes to copy |

**Returns**: `EAX = 1` on success

---

### IsMemoryExecutable

Checks if memory region is executable.

```asm
IsMemoryExecutable PROC EXPORT pAddress:DWORD
```

**Returns**: `EAX = 1` if executable, `0` otherwise

---

## 4. Register Management

### SaveAllRegisters

Saves all general purpose registers to a context structure.

```asm
SaveAllRegisters PROC EXPORT pContext:DWORD
```

**Parameters**:
| Parameter | Type | Description |
|-----------|------|-------------|
| pContext | DWORD | Pointer to REGISTER_CONTEXT |

**Returns**: `EAX = 1` on success

---

### RestoreAllRegisters

Restores all registers from a context structure.

```asm
RestoreAllRegisters PROC EXPORT pContext:DWORD
```

**Parameters**:
| Parameter | Type | Description |
|-----------|------|-------------|
| pContext | DWORD | Pointer to REGISTER_CONTEXT |

---

### QuickSaveContext

Quickly saves context to global storage (like PUSHAD).

```asm
QuickSaveContext PROC EXPORT
```

**Note**: Not re-entrant. Use for simple cases only.

---

### QuickRestoreContext

Restores context from global storage (like POPAD).

```asm
QuickRestoreContext PROC EXPORT
```

---

## 5. MessageBox Hooks

### InstallMessageBoxHook

Installs hooks on MessageBoxA and MessageBoxW.

```asm
InstallMessageBoxHook PROC EXPORT
```

**Returns**: `EAX = 1` on success, `0` on failure

---

### RemoveMessageBoxHook

Removes the MessageBox hooks.

```asm
RemoveMessageBoxHook PROC EXPORT
```

**Returns**: `EAX = 1`

---

### GetMessageBoxHookStats

Gets hook statistics.

```asm
GetMessageBoxHookStats PROC EXPORT pInterceptCount:DWORD, pBlockedCount:DWORD
```

**Parameters**:
| Parameter | Type | Description |
|-----------|------|-------------|
| pInterceptCount | DWORD | Pointer for intercept count |
| pBlockedCount | DWORD | Pointer for blocked count |

**Returns**: `EAX = 1` if hooks enabled

---

### IsMessageBoxHookActive

Checks if MessageBox hook is active.

```asm
IsMessageBoxHookActive PROC EXPORT
```

**Returns**: `EAX = 1` if active, `0` otherwise

---

## 6. File Hooks

### InstallFileHooks

Installs hooks on file I/O functions.

```asm
InstallFileHooks PROC EXPORT
```

**Hooks Installed**:
- CreateFileA
- ReadFile
- WriteFile
- DeleteFileA

**Returns**: `EAX = 1` on success

---

### RemoveFileHooks

Removes all file hooks.

```asm
RemoveFileHooks PROC EXPORT
```

**Returns**: `EAX = 1`

---

### GetFileHookStats

Gets file hook statistics.

```asm
GetFileHookStats PROC EXPORT pCreateCount:DWORD, pReadCount:DWORD, pWriteCount:DWORD, pDeleteCount:DWORD
```

**Returns**: `EAX = 1` if hooks enabled

---

## 7. Network Hooks

### InstallNetworkHooks

Installs hooks on network functions.

```asm
InstallNetworkHooks PROC EXPORT
```

**Hooks Installed**:
- socket()
- connect()
- send()
- recv()

**Returns**: `EAX = 1` on success, `0` if ws2_32.dll not loaded

---

### RemoveNetworkHooks

Removes all network hooks.

```asm
RemoveNetworkHooks PROC EXPORT
```

**Returns**: `EAX = 1`

---

### GetNetworkHookStats

Gets network hook statistics.

```asm
GetNetworkHookStats PROC EXPORT pSocketCount:DWORD, pConnectCount:DWORD, pBytesSent:DWORD, pBytesRecv:DWORD
```

---

## 8. Process Hooks

### InstallProcessHooks

Installs hooks on process-related functions.

```asm
InstallProcessHooks PROC EXPORT
```

**Hooks Installed**:
- CreateProcessA
- TerminateProcess
- OpenProcess

**Returns**: `EAX = 1`

---

### RemoveProcessHooks

Removes all process hooks.

```asm
RemoveProcessHooks PROC EXPORT
```

---

### GetProcessHookStats

Gets process hook statistics.

```asm
GetProcessHookStats PROC EXPORT pCreateCount:DWORD, pTermCount:DWORD, pOpenCount:DWORD, pBlockedCount:DWORD
```

---

## 9. Logging System

### InitializeLogging

Initializes the logging system.

```asm
InitializeLogging PROC EXPORT dwTarget:DWORD, dwLevel:DWORD
```

**Parameters**:
| Parameter | Type | Description |
|-----------|------|-------------|
| dwTarget | DWORD | LOG_TARGET_* flags |
| dwLevel | DWORD | Minimum LOG_LEVEL_* |

**Target Flags**:
- `LOG_TARGET_DEBUG = 1` - OutputDebugString
- `LOG_TARGET_FILE = 2` - File output
- `LOG_TARGET_CONSOLE = 4` - Console output
- `LOG_TARGET_ALL = 7` - All targets

**Log Levels**:
- `LOG_LEVEL_DEBUG = 0`
- `LOG_LEVEL_INFO = 1`
- `LOG_LEVEL_WARNING = 2`
- `LOG_LEVEL_ERROR = 3`
- `LOG_LEVEL_CRITICAL = 4`

---

### LogMessage

Logs a message.

```asm
LogMessage PROC EXPORT dwLevel:DWORD, dwCategory:DWORD, lpszMessage:DWORD
```

**Parameters**:
| Parameter | Type | Description |
|-----------|------|-------------|
| dwLevel | DWORD | Log level |
| dwCategory | DWORD | Category (1-6) |
| lpszMessage | DWORD | Message string |

---

### LogDebug / LogInfo / LogWarning / LogError

Convenience functions for specific log levels.

```asm
LogDebug PROC EXPORT lpszMessage:DWORD
LogInfo PROC EXPORT lpszMessage:DWORD
LogWarning PROC EXPORT lpszMessage:DWORD
LogError PROC EXPORT lpszMessage:DWORD
```

---

## 10. String Utilities

### StrLen

Returns string length.

```asm
StrLen PROC EXPORT lpszString:DWORD
```

**Returns**: `EAX = String length`

---

### StrCopy

Copies a string.

```asm
StrCopy PROC EXPORT lpszDest:DWORD, lpszSrc:DWORD
```

**Returns**: `EAX = Destination pointer`

---

### StrCmp

Compares two strings.

```asm
StrCmp PROC EXPORT lpszStr1:DWORD, lpszStr2:DWORD
```

**Returns**:
- `EAX < 0` if str1 < str2
- `EAX = 0` if str1 == str2
- `EAX > 0` if str1 > str2

---

### StrCmpI

Case-insensitive string comparison.

```asm
StrCmpI PROC EXPORT lpszStr1:DWORD, lpszStr2:DWORD
```

---

### IntToStr

Converts integer to string.

```asm
IntToStr PROC EXPORT dwValue:DWORD, lpszBuffer:DWORD, dwRadix:DWORD
```

**Parameters**:
| Parameter | Type | Description |
|-----------|------|-------------|
| dwValue | DWORD | Value to convert |
| lpszBuffer | DWORD | Output buffer |
| dwRadix | DWORD | Base (2-36) |

---

### StrToInt

Converts string to integer.

```asm
StrToInt PROC EXPORT lpszString:DWORD
```

**Returns**: `EAX = Integer value`

---

## 11. Constants and Structures

### Hook Status Constants

```asm
HOOK_STATUS_INACTIVE    EQU 0
HOOK_STATUS_ACTIVE      EQU 1
HOOK_STATUS_PAUSED      EQU 2
HOOK_STATUS_ERROR       EQU 3
```

### Error Codes

```asm
HOOK_SUCCESS            EQU 0
HOOK_ERR_INVALID_PTR    EQU 1
HOOK_ERR_MEM_PROTECT    EQU 2
HOOK_ERR_MAX_HOOKS      EQU 3
HOOK_ERR_NOT_FOUND      EQU 4
HOOK_ERR_ALLOC          EQU 5
```

### HOOK_ENTRY Structure

```asm
HOOK_ENTRY STRUCT
    pOriginalFunc    DWORD ?
    pHookFunc        DWORD ?
    pTrampoline      DWORD ?
    dwOriginalBytes  DWORD 8 DUP(?)
    dwBytesStolen    DWORD ?
    dwStatus         DWORD ?
    szFuncName       BYTE 64 DUP(?)
HOOK_ENTRY ENDS
```

### REGISTER_CONTEXT Structure

```asm
REGISTER_CONTEXT STRUCT
    dwEax    DWORD ?
    dwEcx    DWORD ?
    dwEdx    DWORD ?
    dwEbx    DWORD ?
    dwEsp    DWORD ?
    dwEbp    DWORD ?
    dwEsi    DWORD ?
    dwEdi    DWORD ?
    wCs      WORD ?
    wDs      WORD ?
    wEs      WORD ?
    wFs      WORD ?
    wGs      WORD ?
    wSs      WORD ?
    dwEflags DWORD ?
    dwEip    DWORD ?
REGISTER_CONTEXT ENDS
```

---

*API Reference v1.0 - The Stealth Interceptor*
