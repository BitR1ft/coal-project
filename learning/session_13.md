# Session 13: File Operation Hooks

## 🎯 Learning Objectives

By the end of this session, you will:
- Hook CreateFileA/CreateFileW
- Hook ReadFile and WriteFile
- Monitor all file access in an application
- Build a complete file activity logger

---

## 📚 Part 1: File APIs Overview

### Key File APIs to Hook

| API | Purpose | DLL |
|-----|---------|-----|
| CreateFileA/W | Open or create files | kernel32.dll |
| ReadFile | Read data from file | kernel32.dll |
| WriteFile | Write data to file | kernel32.dll |
| CloseHandle | Close file handle | kernel32.dll |
| DeleteFileA/W | Delete a file | kernel32.dll |
| CopyFileA/W | Copy a file | kernel32.dll |

### CreateFile Signature

```c
HANDLE CreateFileA(
    LPCSTR  lpFileName,         // File path
    DWORD   dwDesiredAccess,    // GENERIC_READ, GENERIC_WRITE
    DWORD   dwShareMode,        // FILE_SHARE_READ, etc.
    LPSECURITY_ATTRIBUTES lpSecurityAttributes,
    DWORD   dwCreationDisposition,  // CREATE_NEW, OPEN_EXISTING
    DWORD   dwFlagsAndAttributes,
    HANDLE  hTemplateFile
);
// Returns: File handle, or INVALID_HANDLE_VALUE on failure
```

### ReadFile/WriteFile Signatures

```c
BOOL ReadFile(
    HANDLE  hFile,              // File handle
    LPVOID  lpBuffer,           // Buffer for data
    DWORD   nNumberOfBytesToRead,
    LPDWORD lpNumberOfBytesRead,
    LPOVERLAPPED lpOverlapped
);

BOOL WriteFile(
    HANDLE  hFile,
    LPCVOID lpBuffer,           // Data to write
    DWORD   nNumberOfBytesToWrite,
    LPDWORD lpNumberOfBytesWritten,
    LPOVERLAPPED lpOverlapped
);
```

---

## 📚 Part 2: CreateFile Hook Implementation

### Complete CreateFileA Hook

```asm
;===============================================================================
; file_hooks.asm - File operation hooks
;===============================================================================

.686
.model flat, stdcall
option casemap:none

include \masm32\include\windows.inc
include \masm32\include\kernel32.inc
includelib \masm32\lib\kernel32.lib

.data
    ; DLL and function names
    szKernel32      db "kernel32.dll", 0
    szCreateFileA   db "CreateFileA", 0
    szReadFile      db "ReadFile", 0
    szWriteFile     db "WriteFile", 0
    
    ; Log messages
    szLogOpen       db "[FILE] CreateFile: ", 0
    szLogRead       db "[FILE] ReadFile: Handle=0x", 0
    szLogWrite      db "[FILE] WriteFile: Handle=0x", 0
    szLogBytes      db " Bytes=", 0
    szLogAccess     db " Access=", 0
    szLogResult     db " Result=0x", 0
    szLogNewline    db 13, 10, 0
    szRead          db "READ", 0
    szWrite         db "WRITE", 0
    szReadWrite     db "READ|WRITE", 0
    
    ; Hook data
    hKernel32           dd 0
    pOrigCreateFileA    dd 0
    pOrigReadFile       dd 0
    pOrigWriteFile      dd 0
    pTrampolineCreate   dd 0
    pTrampolineRead     dd 0
    pTrampolineWrite    dd 0
    
    bOrigBytesCreate    db 16 dup(0)
    bOrigBytesRead      db 16 dup(0)
    bOrigBytesWrite     db 16 dup(0)
    
    dwOldProtect        dd 0
    
    ; Statistics
    dwFileOpens         dd 0
    dwFileReads         dd 0
    dwFileWrites        dd 0
    dwBytesRead         dd 0
    dwBytesWritten      dd 0
    
    ; Synchronization
    g_FileLock CRITICAL_SECTION <>

.code

;-------------------------------------------------------------------------------
; LogString - Helper to log strings
;-------------------------------------------------------------------------------
LogString PROC pStr:DWORD
    push pStr
    call OutputDebugStringA
    ret
LogString ENDP

;-------------------------------------------------------------------------------
; LogHex - Helper to log hex value
;-------------------------------------------------------------------------------
LogHex PROC dwValue:DWORD
    LOCAL szBuf[16]:BYTE
    pushad
    
    lea edi, szBuf
    mov eax, dwValue
    mov ecx, 8
    
@loop:
    rol eax, 4
    mov bl, al
    and bl, 0Fh
    cmp bl, 10
    jl @digit
    add bl, 'A'-10
    jmp @store
@digit:
    add bl, '0'
@store:
    mov [edi], bl
    inc edi
    loop @loop
    mov byte ptr [edi], 0
    
    lea eax, szBuf
    push eax
    call OutputDebugStringA
    
    popad
    ret
LogHex ENDP

;-------------------------------------------------------------------------------
; CreateFileAHook - Hook handler for CreateFileA
;-------------------------------------------------------------------------------
CreateFileAHook PROC
    ; Stack after call:
    ; [ESP+4]  = lpFileName
    ; [ESP+8]  = dwDesiredAccess
    ; [ESP+12] = dwShareMode
    ; [ESP+16] = lpSecurityAttributes
    ; [ESP+20] = dwCreationDisposition
    ; [ESP+24] = dwFlagsAndAttributes
    ; [ESP+28] = hTemplateFile
    
    push ebp
    mov ebp, esp
    push ebx
    push esi
    push edi
    
    ;═══════════════════════════════════════════════════════════════
    ; Pre-call logging
    ;═══════════════════════════════════════════════════════════════
    lea eax, g_FileLock
    push eax
    call EnterCriticalSection
    
    ; Increment counter
    inc dwFileOpens
    
    ; Log filename
    push OFFSET szLogOpen
    call LogString
    
    mov eax, [ebp+8]            ; lpFileName
    test eax, eax
    jz @noFileName
    push eax
    call LogString
@noFileName:
    
    ; Log access mode
    push OFFSET szLogAccess
    call LogString
    
    mov eax, [ebp+12]           ; dwDesiredAccess
    test eax, GENERIC_READ
    jz @notRead
    test eax, GENERIC_WRITE
    jz @readOnly
    push OFFSET szReadWrite
    jmp @logAccess
@readOnly:
    push OFFSET szRead
    jmp @logAccess
@notRead:
    test eax, GENERIC_WRITE
    jz @noAccess
    push OFFSET szWrite
    jmp @logAccess
@noAccess:
    push OFFSET szRead          ; Default
@logAccess:
    call LogString
    
    push OFFSET szLogNewline
    call LogString
    
    lea eax, g_FileLock
    push eax
    call LeaveCriticalSection
    
    ;═══════════════════════════════════════════════════════════════
    ; Call original function
    ;═══════════════════════════════════════════════════════════════
    push [ebp+32]               ; hTemplateFile
    push [ebp+28]               ; dwFlagsAndAttributes
    push [ebp+24]               ; dwCreationDisposition
    push [ebp+20]               ; lpSecurityAttributes
    push [ebp+16]               ; dwShareMode
    push [ebp+12]               ; dwDesiredAccess
    push [ebp+8]                ; lpFileName
    call pTrampolineCreate
    
    ; Save return value
    mov esi, eax
    
    ;═══════════════════════════════════════════════════════════════
    ; Post-call logging
    ;═══════════════════════════════════════════════════════════════
    lea eax, g_FileLock
    push eax
    call EnterCriticalSection
    
    push OFFSET szLogResult
    call LogString
    push esi
    call LogHex
    push OFFSET szLogNewline
    call LogString
    
    lea eax, g_FileLock
    push eax
    call LeaveCriticalSection
    
    ; Return original result
    mov eax, esi
    
    pop edi
    pop esi
    pop ebx
    mov esp, ebp
    pop ebp
    ret 28                      ; Clean 7 parameters
CreateFileAHook ENDP

;-------------------------------------------------------------------------------
; ReadFileHook - Hook handler for ReadFile
;-------------------------------------------------------------------------------
ReadFileHook PROC
    ; [ESP+4]  = hFile
    ; [ESP+8]  = lpBuffer
    ; [ESP+12] = nNumberOfBytesToRead
    ; [ESP+16] = lpNumberOfBytesRead
    ; [ESP+20] = lpOverlapped
    
    push ebp
    mov ebp, esp
    push ebx
    push esi
    
    ; Call original first
    push [ebp+24]               ; lpOverlapped
    push [ebp+20]               ; lpNumberOfBytesRead
    push [ebp+16]               ; nNumberOfBytesToRead
    push [ebp+12]               ; lpBuffer
    push [ebp+8]                ; hFile
    call pTrampolineRead
    mov esi, eax                ; Save result
    
    ; Log the read
    lea eax, g_FileLock
    push eax
    call EnterCriticalSection
    
    inc dwFileReads
    
    ; Add bytes read to total
    mov eax, [ebp+20]           ; lpNumberOfBytesRead
    test eax, eax
    jz @noBytes
    mov eax, [eax]              ; Actual bytes read
    add dwBytesRead, eax
@noBytes:
    
    push OFFSET szLogRead
    call LogString
    push [ebp+8]
    call LogHex
    push OFFSET szLogBytes
    call LogString
    push [ebp+16]
    call LogHex
    push OFFSET szLogNewline
    call LogString
    
    lea eax, g_FileLock
    push eax
    call LeaveCriticalSection
    
    mov eax, esi                ; Return original result
    
    pop esi
    pop ebx
    mov esp, ebp
    pop ebp
    ret 20                      ; Clean 5 parameters
ReadFileHook ENDP

;-------------------------------------------------------------------------------
; WriteFileHook - Hook handler for WriteFile  
;-------------------------------------------------------------------------------
WriteFileHook PROC
    push ebp
    mov ebp, esp
    push ebx
    push esi
    
    ; Call original first
    push [ebp+24]               ; lpOverlapped
    push [ebp+20]               ; lpNumberOfBytesWritten
    push [ebp+16]               ; nNumberOfBytesToWrite
    push [ebp+12]               ; lpBuffer
    push [ebp+8]                ; hFile
    call pTrampolineWrite
    mov esi, eax
    
    ; Log the write
    lea eax, g_FileLock
    push eax
    call EnterCriticalSection
    
    inc dwFileWrites
    
    ; Add bytes written to total
    mov eax, [ebp+20]
    test eax, eax
    jz @noBytes
    mov eax, [eax]
    add dwBytesWritten, eax
@noBytes:
    
    push OFFSET szLogWrite
    call LogString
    push [ebp+8]
    call LogHex
    push OFFSET szLogBytes
    call LogString
    push [ebp+16]
    call LogHex
    push OFFSET szLogNewline
    call LogString
    
    lea eax, g_FileLock
    push eax
    call LeaveCriticalSection
    
    mov eax, esi
    
    pop esi
    pop ebx
    mov esp, ebp
    pop ebp
    ret 20
WriteFileHook ENDP

;-------------------------------------------------------------------------------
; InstallFileHooks - Install all file hooks
;-------------------------------------------------------------------------------
InstallFileHooks PROC
    pushad
    
    ; Initialize critical section
    lea eax, g_FileLock
    push eax
    call InitializeCriticalSection
    
    ; Get kernel32 handle
    push OFFSET szKernel32
    call GetModuleHandleA
    mov hKernel32, eax
    
    ;═══════════════════════════════════════════════════════════════
    ; Hook CreateFileA
    ;═══════════════════════════════════════════════════════════════
    push OFFSET szCreateFileA
    push hKernel32
    call GetProcAddress
    mov pOrigCreateFileA, eax
    
    ; Allocate trampoline
    push PAGE_EXECUTE_READWRITE
    push MEM_COMMIT or MEM_RESERVE
    push 32
    push NULL
    call VirtualAlloc
    mov pTrampolineCreate, eax
    
    ; Build trampoline
    mov esi, pOrigCreateFileA
    mov edi, eax
    mov ecx, 5
    rep movsb
    mov byte ptr [edi], 0E9h
    mov eax, pOrigCreateFileA
    add eax, 5
    sub eax, edi
    sub eax, 5
    mov [edi+1], eax
    
    ; Install hook
    push OFFSET dwOldProtect
    push PAGE_EXECUTE_READWRITE
    push 5
    push pOrigCreateFileA
    call VirtualProtect
    
    mov edi, pOrigCreateFileA
    mov byte ptr [edi], 0E9h
    mov eax, OFFSET CreateFileAHook
    sub eax, edi
    sub eax, 5
    mov [edi+1], eax
    
    push 5
    push pOrigCreateFileA
    push -1
    call FlushInstructionCache
    
    ; (Similar code for ReadFile and WriteFile hooks...)
    
    popad
    mov eax, 1
    ret
InstallFileHooks ENDP

;-------------------------------------------------------------------------------
; GetFileStats - Get file operation statistics
;-------------------------------------------------------------------------------
GetFileStats PROC pOpens:DWORD, pReads:DWORD, pWrites:DWORD, pBytesR:DWORD, pBytesW:DWORD
    lea eax, g_FileLock
    push eax
    call EnterCriticalSection
    
    mov eax, pOpens
    mov ebx, dwFileOpens
    mov [eax], ebx
    
    mov eax, pReads
    mov ebx, dwFileReads
    mov [eax], ebx
    
    mov eax, pWrites
    mov ebx, dwFileWrites
    mov [eax], ebx
    
    mov eax, pBytesR
    mov ebx, dwBytesRead
    mov [eax], ebx
    
    mov eax, pBytesW
    mov ebx, dwBytesWritten
    mov [eax], ebx
    
    lea eax, g_FileLock
    push eax
    call LeaveCriticalSection
    
    ret
GetFileStats ENDP

END
```

---

## 📚 Part 3: Practical Applications

### Application 1: File Access Monitor

```asm
; Monitor which files an application accesses
; Useful for: Understanding application behavior, security auditing
```

### Application 2: File Content Filter

```asm
; Block writes containing certain content
WriteFileHookWithFilter PROC
    ; Check buffer for sensitive content
    mov esi, [esp+8]            ; lpBuffer
    mov ecx, [esp+12]           ; nNumberOfBytesToWrite
    
    ; Search for "password" string
    push ecx
    push OFFSET szPassword
    push esi
    call SearchBuffer
    test eax, eax
    jnz @block
    
    ; Allow the write
    jmp pTrampolineWrite
    
@block:
    ; Block the write - return failure
    xor eax, eax
    ret 20
WriteFileHookWithFilter ENDP
```

### Application 3: File Access Logger

```asm
; Log all file operations to a log file
LogToFile PROC pMessage:DWORD
    LOCAL hFile:DWORD
    LOCAL dwWritten:DWORD
    
    ; Open log file
    push NULL
    push FILE_ATTRIBUTE_NORMAL
    push OPEN_ALWAYS
    push NULL
    push FILE_SHARE_READ
    push GENERIC_WRITE
    push OFFSET szLogFileName
    call CreateFileA
    mov hFile, eax
    
    ; Seek to end
    push FILE_END
    push 0
    push 0
    push hFile
    call SetFilePointer
    
    ; Write message
    push NULL
    lea eax, dwWritten
    push eax
    ; Get string length...
    push pMessage
    push hFile
    call WriteFile
    
    ; Close
    push hFile
    call CloseHandle
    
    ret
LogToFile ENDP
```

---

## 📝 Part 4: Tasks

### Task 1: Complete File Hook Suite (40 minutes)
Implement hooks for:
1. CreateFileA and CreateFileW
2. ReadFile
3. WriteFile
4. CloseHandle

### Task 2: Path Filter (30 minutes)
Create a hook that:
1. Logs only access to specific directories (e.g., C:\Windows)
2. Blocks access to specific files
3. Shows warning for suspicious access

### Task 3: File Statistics Dashboard (35 minutes)
Build a display that shows:
1. Total files opened
2. Files currently open
3. Total bytes read/written
4. Most accessed file

### Task 4: Binary File Logger (45 minutes)
Create a hook that:
1. Logs complete file read/write content
2. Saves to a binary log file
3. Includes timestamps and file handles

---

## ✅ Session Checklist

Before moving to Session 14, make sure you can:

- [ ] Hook CreateFileA/W correctly
- [ ] Hook ReadFile and WriteFile
- [ ] Log file paths and access modes
- [ ] Track file operation statistics
- [ ] Handle the multiple parameters correctly

---

## 🔜 Next Session

In **Session 14: Network API Hooks**, we'll learn:
- Hook socket operations
- Monitor network connections
- Track data sent/received
- Build a network monitor

[Continue to Session 14 →](session_14.md)
