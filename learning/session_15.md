# Session 15: Process API Hooks

## 🎯 Learning Objectives

By the end of this session, you will:
- Hook CreateProcess APIs
- Monitor process creation
- Capture command lines and executable paths
- Build a process creation monitor

---

## 📚 Part 1: Process APIs Overview

### Key Process APIs to Hook

| API | Purpose | DLL |
|-----|---------|-----|
| CreateProcessA/W | Create new process | kernel32.dll |
| CreateProcessAsUserA/W | Create process as user | advapi32.dll |
| ShellExecuteA/W | Execute/open file | shell32.dll |
| WinExec | Run application | kernel32.dll |
| TerminateProcess | End a process | kernel32.dll |

### CreateProcess Signature

```c
BOOL CreateProcessA(
    LPCSTR                lpApplicationName,    // Application path
    LPSTR                 lpCommandLine,        // Command line
    LPSECURITY_ATTRIBUTES lpProcessAttributes,
    LPSECURITY_ATTRIBUTES lpThreadAttributes,
    BOOL                  bInheritHandles,
    DWORD                 dwCreationFlags,
    LPVOID                lpEnvironment,
    LPCSTR                lpCurrentDirectory,
    LPSTARTUPINFOA        lpStartupInfo,
    LPPROCESS_INFORMATION lpProcessInformation
);
// Returns: TRUE on success
```

---

## 📚 Part 2: Process Hook Implementation

```asm
;===============================================================================
; process_hooks.asm - Process creation monitoring
;===============================================================================

.686
.model flat, stdcall
option casemap:none

include \masm32\include\windows.inc
include \masm32\include\kernel32.inc
includelib \masm32\lib\kernel32.lib

.data
    szKernel32          db "kernel32.dll", 0
    szCreateProcessA    db "CreateProcessA", 0
    
    szLogCreate         db "[PROC] CreateProcess:", 13, 10, 0
    szLogApp            db "  App: ", 0
    szLogCmd            db "  Cmd: ", 0
    szLogDir            db "  Dir: ", 0
    szLogFlags          db "  Flags: 0x", 0
    szLogPID            db "  PID: ", 0
    szLogResult         db "  Result: ", 0
    szLogSuccess        db "SUCCESS", 13, 10, 0
    szLogFailure        db "FAILED", 13, 10, 0
    szNull              db "(null)", 0
    szNewline           db 13, 10, 0
    
    hKernel32           dd 0
    pOrigCreateProcessA dd 0
    pTrampolineCreate   dd 0
    bOrigBytes          db 16 dup(0)
    dwOldProtect        dd 0
    
    dwProcessCount      dd 0
    dwSuccessCount      dd 0
    dwFailCount         dd 0
    
    g_ProcLock CRITICAL_SECTION <>

.code

;-------------------------------------------------------------------------------
; CreateProcessAHook - Monitor process creation
;-------------------------------------------------------------------------------
CreateProcessAHook PROC
    ; Parameters:
    ; [ESP+4]  = lpApplicationName
    ; [ESP+8]  = lpCommandLine
    ; [ESP+12] = lpProcessAttributes
    ; [ESP+16] = lpThreadAttributes
    ; [ESP+20] = bInheritHandles
    ; [ESP+24] = dwCreationFlags
    ; [ESP+28] = lpEnvironment
    ; [ESP+32] = lpCurrentDirectory
    ; [ESP+36] = lpStartupInfo
    ; [ESP+40] = lpProcessInformation
    
    push ebp
    mov ebp, esp
    push esi
    push edi
    push ebx
    
    ;═══════════════════════════════════════════════════════════════
    ; Pre-call Logging
    ;═══════════════════════════════════════════════════════════════
    lea eax, g_ProcLock
    push eax
    call EnterCriticalSection
    
    inc dwProcessCount
    
    ; Log header
    push OFFSET szLogCreate
    call OutputDebugStringA
    
    ; Log application name
    push OFFSET szLogApp
    call OutputDebugStringA
    mov eax, [ebp+8]
    test eax, eax
    jnz @hasApp
    mov eax, OFFSET szNull
@hasApp:
    push eax
    call OutputDebugStringA
    push OFFSET szNewline
    call OutputDebugStringA
    
    ; Log command line
    push OFFSET szLogCmd
    call OutputDebugStringA
    mov eax, [ebp+12]
    test eax, eax
    jnz @hasCmd
    mov eax, OFFSET szNull
@hasCmd:
    push eax
    call OutputDebugStringA
    push OFFSET szNewline
    call OutputDebugStringA
    
    ; Log current directory
    push OFFSET szLogDir
    call OutputDebugStringA
    mov eax, [ebp+36]
    test eax, eax
    jnz @hasDir
    mov eax, OFFSET szNull
@hasDir:
    push eax
    call OutputDebugStringA
    push OFFSET szNewline
    call OutputDebugStringA
    
    lea eax, g_ProcLock
    push eax
    call LeaveCriticalSection
    
    ;═══════════════════════════════════════════════════════════════
    ; Call Original
    ;═══════════════════════════════════════════════════════════════
    push [ebp+44]               ; lpProcessInformation
    push [ebp+40]               ; lpStartupInfo
    push [ebp+36]               ; lpCurrentDirectory
    push [ebp+32]               ; lpEnvironment
    push [ebp+28]               ; dwCreationFlags
    push [ebp+24]               ; bInheritHandles
    push [ebp+20]               ; lpThreadAttributes
    push [ebp+16]               ; lpProcessAttributes
    push [ebp+12]               ; lpCommandLine
    push [ebp+8]                ; lpApplicationName
    call pTrampolineCreate
    mov esi, eax                ; Save result
    
    ;═══════════════════════════════════════════════════════════════
    ; Post-call Logging
    ;═══════════════════════════════════════════════════════════════
    lea eax, g_ProcLock
    push eax
    call EnterCriticalSection
    
    ; Log result
    push OFFSET szLogResult
    call OutputDebugStringA
    
    test esi, esi
    jz @failed
    
    inc dwSuccessCount
    push OFFSET szLogSuccess
    call OutputDebugStringA
    
    ; Log PID if successful
    mov eax, [ebp+44]           ; lpProcessInformation
    test eax, eax
    jz @done
    mov eax, [eax+8]            ; dwProcessId
    push OFFSET szLogPID
    call OutputDebugStringA
    ; (Would format and print PID here)
    jmp @done
    
@failed:
    inc dwFailCount
    push OFFSET szLogFailure
    call OutputDebugStringA
    
@done:
    lea eax, g_ProcLock
    push eax
    call LeaveCriticalSection
    
    mov eax, esi
    pop ebx
    pop edi
    pop esi
    mov esp, ebp
    pop ebp
    ret 40                      ; Clean 10 parameters
CreateProcessAHook ENDP

;-------------------------------------------------------------------------------
; InstallProcessHooks
;-------------------------------------------------------------------------------
InstallProcessHooks PROC
    pushad
    
    lea eax, g_ProcLock
    push eax
    call InitializeCriticalSection
    
    push OFFSET szKernel32
    call GetModuleHandleA
    mov hKernel32, eax
    
    push OFFSET szCreateProcessA
    push hKernel32
    call GetProcAddress
    mov pOrigCreateProcessA, eax
    
    ; Allocate trampoline
    push PAGE_EXECUTE_READWRITE
    push MEM_COMMIT or MEM_RESERVE
    push 32
    push NULL
    call VirtualAlloc
    mov pTrampolineCreate, eax
    
    ; Build trampoline
    mov esi, pOrigCreateProcessA
    mov edi, eax
    mov ecx, 5
    rep movsb
    mov byte ptr [edi], 0E9h
    mov eax, pOrigCreateProcessA
    add eax, 5
    sub eax, edi
    sub eax, 5
    mov [edi+1], eax
    
    ; Install hook
    push OFFSET dwOldProtect
    push PAGE_EXECUTE_READWRITE
    push 5
    push pOrigCreateProcessA
    call VirtualProtect
    
    mov edi, pOrigCreateProcessA
    mov byte ptr [edi], 0E9h
    mov eax, OFFSET CreateProcessAHook
    sub eax, edi
    sub eax, 5
    mov [edi+1], eax
    
    push 5
    push pOrigCreateProcessA
    push -1
    call FlushInstructionCache
    
    popad
    mov eax, 1
    ret
InstallProcessHooks ENDP

END
```

---

## 📚 Part 3: Practical Applications

### Application 1: Process Whitelist

```asm
; Only allow specific processes to run
IsAllowedProcess PROC lpApplicationName:DWORD, lpCommandLine:DWORD
    ; Check against whitelist
    ; Return 1 if allowed, 0 if blocked
    ret
IsAllowedProcess ENDP
```

### Application 2: Command Line Analyzer

```asm
; Analyze command line for suspicious patterns
AnalyzeCommandLine PROC lpCmd:DWORD
    ; Check for:
    ; - powershell.exe -enc (encoded commands)
    ; - cmd.exe /c (command execution)
    ; - Suspicious paths
    ret
AnalyzeCommandLine ENDP
```

---

## 📝 Part 4: Tasks

### Task 1: Process Tree Logger (35 minutes)
Track parent-child process relationships.

### Task 2: Security Alert System (40 minutes)
Alert on suspicious process creation:
- Processes from temp directories
- Known malware names
- Unusual parent processes

### Task 3: Complete Process Monitor (45 minutes)
Hook both CreateProcessA and CreateProcessW with full logging.

---

## ✅ Session Checklist

- [ ] Hook CreateProcessA/W
- [ ] Log application names and command lines
- [ ] Track process creation statistics
- [ ] Understand PROCESS_INFORMATION structure

---

## 🔜 Next Session

In **Session 16: Building a Hook Manager**, we'll:
- Create a centralized hook management system
- Build a reusable hook library
- Implement multiple hook types

[Continue to Session 16 →](session_16.md)
