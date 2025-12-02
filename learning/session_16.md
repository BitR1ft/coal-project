# Session 16: Building a Hook Manager

## 🎯 Learning Objectives

By the end of this session, you will:
- Create a centralized hook management system
- Build a reusable hook library
- Manage multiple hooks dynamically
- Implement hook chaining

---

## 📚 Part 1: Hook Manager Architecture

### Design Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                    HOOK MANAGER ARCHITECTURE                     │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌────────────────────────────────────────────────────────┐     │
│  │                   HOOK MANAGER                          │     │
│  │                                                         │     │
│  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  │     │
│  │  │ Hook Table   │  │ Trampoline   │  │ Statistics   │  │     │
│  │  │              │  │ Pool         │  │ Tracker      │  │     │
│  │  │ Entry 0      │  │              │  │              │  │     │
│  │  │ Entry 1      │  │ Tramp 0      │  │ Calls: XXX   │  │     │
│  │  │ Entry 2      │  │ Tramp 1      │  │ Active: X    │  │     │
│  │  │ ...          │  │ ...          │  │              │  │     │
│  │  └──────────────┘  └──────────────┘  └──────────────┘  │     │
│  │                                                         │     │
│  │  ┌─────────────────────────────────────────────────┐   │     │
│  │  │                 API Functions                    │   │     │
│  │  │  HM_Initialize()    HM_Shutdown()               │   │     │
│  │  │  HM_InstallHook()   HM_RemoveHook()             │   │     │
│  │  │  HM_PauseHook()     HM_ResumeHook()             │   │     │
│  │  │  HM_GetTrampoline() HM_GetStats()               │   │     │
│  │  └─────────────────────────────────────────────────┘   │     │
│  └────────────────────────────────────────────────────────┘     │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

---

## 📚 Part 2: Hook Manager Implementation

```asm
;===============================================================================
; hook_manager.asm - Centralized Hook Management System
;===============================================================================

.686
.model flat, stdcall
option casemap:none

include \masm32\include\windows.inc
include \masm32\include\kernel32.inc
includelib \masm32\lib\kernel32.lib

;===============================================================================
; Constants
;===============================================================================
MAX_HOOKS           EQU 64
TRAMPOLINE_SIZE     EQU 32
HOOK_NAME_SIZE      EQU 64

; Hook status
HOOK_INACTIVE       EQU 0
HOOK_ACTIVE         EQU 1
HOOK_PAUSED         EQU 2

; Error codes
HM_SUCCESS          EQU 0
HM_ERR_INVALID      EQU 1
HM_ERR_FULL         EQU 2
HM_ERR_NOTFOUND     EQU 3
HM_ERR_MEMORY       EQU 4
HM_ERR_PROTECT      EQU 5

;===============================================================================
; Structures
;===============================================================================
HOOK_ENTRY STRUCT
    dwID             DWORD ?         ; Unique hook ID
    pOriginalFunc    DWORD ?         ; Original function address
    pHookHandler     DWORD ?         ; User's hook handler
    pTrampoline      DWORD ?         ; Trampoline address
    bOriginalBytes   BYTE 16 DUP(?)  ; Saved original bytes
    dwBytesStolen    DWORD ?         ; Number of bytes stolen
    dwStatus         DWORD ?         ; Current status
    dwCallCount      DWORD ?         ; Number of times called
    szName           BYTE HOOK_NAME_SIZE DUP(?) ; Hook name
HOOK_ENTRY ENDS

;===============================================================================
; Data
;===============================================================================
.data
    ; Hook table
    g_HookTable      HOOK_ENTRY MAX_HOOKS DUP(<>)
    g_dwNextID       DWORD 1
    g_dwHookCount    DWORD 0
    
    ; Trampoline pool
    g_pTrampolinePool DWORD 0
    
    ; Manager state
    g_bInitialized   DWORD 0
    g_dwOldProtect   DWORD 0
    
    ; Synchronization
    g_ManagerLock    CRITICAL_SECTION <>
    
    ; Log strings
    szHMInit         db "[HookManager] Initialized", 13, 10, 0
    szHMShutdown     db "[HookManager] Shutdown", 13, 10, 0
    szHMInstall      db "[HookManager] Hook installed: ", 0
    szHMRemove       db "[HookManager] Hook removed: ", 0

;===============================================================================
; Code
;===============================================================================
.code

;-------------------------------------------------------------------------------
; HM_Initialize - Initialize the Hook Manager
;-------------------------------------------------------------------------------
; Returns: HM_SUCCESS or error code
;-------------------------------------------------------------------------------
HM_Initialize PROC EXPORT
    pushad
    
    ; Check if already initialized
    cmp g_bInitialized, 1
    je @AlreadyInit
    
    ; Initialize critical section
    lea eax, g_ManagerLock
    push eax
    call InitializeCriticalSection
    
    ; Allocate trampoline pool
    push PAGE_EXECUTE_READWRITE
    push MEM_COMMIT or MEM_RESERVE
    push TRAMPOLINE_SIZE * MAX_HOOKS
    push NULL
    call VirtualAlloc
    test eax, eax
    jz @AllocFailed
    mov g_pTrampolinePool, eax
    
    ; Zero out hook table
    lea edi, g_HookTable
    mov ecx, SIZEOF HOOK_ENTRY * MAX_HOOKS
    xor al, al
    rep stosb
    
    ; Reset counters
    mov g_dwNextID, 1
    mov g_dwHookCount, 0
    
    ; Mark initialized
    mov g_bInitialized, 1
    
    ; Log
    push OFFSET szHMInit
    call OutputDebugStringA
    
    popad
    mov eax, HM_SUCCESS
    ret

@AlreadyInit:
    popad
    mov eax, HM_SUCCESS
    ret

@AllocFailed:
    popad
    mov eax, HM_ERR_MEMORY
    ret
HM_Initialize ENDP

;-------------------------------------------------------------------------------
; HM_Shutdown - Shutdown the Hook Manager
;-------------------------------------------------------------------------------
HM_Shutdown PROC EXPORT
    pushad
    
    cmp g_bInitialized, 0
    je @NotInit
    
    ; Remove all hooks
    call HM_RemoveAllHooks
    
    ; Free trampoline pool
    cmp g_pTrampolinePool, 0
    je @SkipFree
    push MEM_RELEASE
    push 0
    push g_pTrampolinePool
    call VirtualFree
    mov g_pTrampolinePool, 0
@SkipFree:
    
    ; Delete critical section
    lea eax, g_ManagerLock
    push eax
    call DeleteCriticalSection
    
    mov g_bInitialized, 0
    
    push OFFSET szHMShutdown
    call OutputDebugStringA

@NotInit:
    popad
    mov eax, HM_SUCCESS
    ret
HM_Shutdown ENDP

;-------------------------------------------------------------------------------
; HM_InstallHook - Install a new hook
;-------------------------------------------------------------------------------
; Parameters:
;   pTarget   - Function to hook
;   pHandler  - Hook handler
;   pszName   - Hook name (optional)
; Returns: Hook ID (>0) or 0 on failure
;-------------------------------------------------------------------------------
HM_InstallHook PROC EXPORT pTarget:DWORD, pHandler:DWORD, pszName:DWORD
    LOCAL dwSlot:DWORD
    LOCAL pTrampoline:DWORD
    LOCAL dwHookID:DWORD
    
    pushad
    
    ; Validate
    cmp g_bInitialized, 0
    je @Failed
    mov eax, pTarget
    test eax, eax
    jz @Failed
    mov eax, pHandler
    test eax, eax
    jz @Failed
    
    ; Lock
    lea eax, g_ManagerLock
    push eax
    call EnterCriticalSection
    
    ; Find free slot
    lea edi, g_HookTable
    xor ecx, ecx
    
@FindSlot:
    cmp [edi].HOOK_ENTRY.dwStatus, HOOK_INACTIVE
    je @FoundSlot
    add edi, SIZEOF HOOK_ENTRY
    inc ecx
    cmp ecx, MAX_HOOKS
    jl @FindSlot
    jmp @Unlock
    
@FoundSlot:
    mov dwSlot, ecx
    
    ; Calculate trampoline address
    mov eax, g_pTrampolinePool
    mov ebx, ecx
    imul ebx, TRAMPOLINE_SIZE
    add eax, ebx
    mov pTrampoline, eax
    
    ; Assign ID
    mov eax, g_dwNextID
    mov dwHookID, eax
    inc g_dwNextID
    mov [edi].HOOK_ENTRY.dwID, eax
    
    ; Store hook info
    mov eax, pTarget
    mov [edi].HOOK_ENTRY.pOriginalFunc, eax
    mov eax, pHandler
    mov [edi].HOOK_ENTRY.pHookHandler, eax
    mov eax, pTrampoline
    mov [edi].HOOK_ENTRY.pTrampoline, eax
    mov [edi].HOOK_ENTRY.dwBytesStolen, 5
    mov [edi].HOOK_ENTRY.dwCallCount, 0
    
    ; Copy name if provided
    mov eax, pszName
    test eax, eax
    jz @SkipName
    push edi
    lea edi, [edi].HOOK_ENTRY.szName
    mov esi, pszName
    mov ecx, HOOK_NAME_SIZE - 1
@CopyName:
    lodsb
    stosb
    test al, al
    jz @NameDone
    loop @CopyName
@NameDone:
    mov byte ptr [edi], 0
    pop edi
@SkipName:
    
    ; Save original bytes
    push edi
    mov esi, pTarget
    lea edi, [edi].HOOK_ENTRY.bOriginalBytes
    mov ecx, 5
    rep movsb
    pop edi
    
    ; Build trampoline
    push edi                        ; Save hook entry pointer
    mov esi, pTarget
    mov edi, pTrampoline
    mov ecx, 5
    rep movsb                       ; Copy stolen bytes
    
    mov byte ptr [edi], 0E9h        ; JMP opcode
    mov eax, pTarget
    add eax, 5
    sub eax, edi
    sub eax, 5
    mov [edi+1], eax
    pop edi                         ; Restore hook entry pointer
    
    ; Modify target function
    push OFFSET g_dwOldProtect
    push PAGE_EXECUTE_READWRITE
    push 5
    push pTarget
    call VirtualProtect
    test eax, eax
    jz @ProtectFailed
    
    ; Write JMP to handler
    push edi
    mov edi, pTarget
    mov byte ptr [edi], 0E9h
    mov eax, pHandler
    sub eax, edi
    sub eax, 5
    mov [edi+1], eax
    pop edi
    
    ; Restore protection
    push OFFSET g_dwOldProtect
    push g_dwOldProtect
    push 5
    push pTarget
    call VirtualProtect
    
    ; Flush cache
    push 5
    push pTarget
    push -1
    call FlushInstructionCache
    
    ; Mark as active
    mov [edi].HOOK_ENTRY.dwStatus, HOOK_ACTIVE
    inc g_dwHookCount
    
    ; Log
    push OFFSET szHMInstall
    call OutputDebugStringA
    lea eax, [edi].HOOK_ENTRY.szName
    push eax
    call OutputDebugStringA
    
@Unlock:
    lea eax, g_ManagerLock
    push eax
    call LeaveCriticalSection
    
    popad
    mov eax, dwHookID
    ret

@ProtectFailed:
    lea eax, g_ManagerLock
    push eax
    call LeaveCriticalSection
    
@Failed:
    popad
    xor eax, eax
    ret
HM_InstallHook ENDP

;-------------------------------------------------------------------------------
; HM_RemoveHook - Remove a hook by ID
;-------------------------------------------------------------------------------
HM_RemoveHook PROC EXPORT dwHookID:DWORD
    LOCAL pEntry:DWORD
    
    pushad
    
    ; Find hook by ID
    lea edi, g_HookTable
    xor ecx, ecx
    
@FindHook:
    cmp [edi].HOOK_ENTRY.dwID, 0
    je @Next
    mov eax, dwHookID
    cmp [edi].HOOK_ENTRY.dwID, eax
    je @Found
@Next:
    add edi, SIZEOF HOOK_ENTRY
    inc ecx
    cmp ecx, MAX_HOOKS
    jl @FindHook
    jmp @NotFound
    
@Found:
    mov pEntry, edi
    
    cmp [edi].HOOK_ENTRY.dwStatus, HOOK_INACTIVE
    je @NotFound
    
    ; Lock
    lea eax, g_ManagerLock
    push eax
    call EnterCriticalSection
    
    ; Restore original bytes
    push OFFSET g_dwOldProtect
    push PAGE_EXECUTE_READWRITE
    push 5
    push [edi].HOOK_ENTRY.pOriginalFunc
    call VirtualProtect
    
    mov edi, pEntry
    mov esi, edi
    lea esi, [esi].HOOK_ENTRY.bOriginalBytes
    mov edi, [edi].HOOK_ENTRY.pOriginalFunc
    mov ecx, 5
    rep movsb
    
    mov edi, pEntry
    push OFFSET g_dwOldProtect
    push g_dwOldProtect
    push 5
    push [edi].HOOK_ENTRY.pOriginalFunc
    call VirtualProtect
    
    push 5
    push [edi].HOOK_ENTRY.pOriginalFunc
    push -1
    call FlushInstructionCache
    
    ; Mark inactive
    mov [edi].HOOK_ENTRY.dwStatus, HOOK_INACTIVE
    mov [edi].HOOK_ENTRY.dwID, 0
    dec g_dwHookCount
    
    ; Unlock
    lea eax, g_ManagerLock
    push eax
    call LeaveCriticalSection
    
    popad
    mov eax, HM_SUCCESS
    ret

@NotFound:
    popad
    mov eax, HM_ERR_NOTFOUND
    ret
HM_RemoveHook ENDP

;-------------------------------------------------------------------------------
; HM_RemoveAllHooks - Remove all active hooks
;-------------------------------------------------------------------------------
HM_RemoveAllHooks PROC EXPORT
    LOCAL dwRemoved:DWORD
    
    pushad
    mov dwRemoved, 0
    
    lea edi, g_HookTable
    xor ecx, ecx
    
@Loop:
    push ecx
    cmp [edi].HOOK_ENTRY.dwStatus, HOOK_INACTIVE
    je @Skip
    
    push [edi].HOOK_ENTRY.dwID
    call HM_RemoveHook
    inc dwRemoved
    
@Skip:
    pop ecx
    add edi, SIZEOF HOOK_ENTRY
    inc ecx
    cmp ecx, MAX_HOOKS
    jl @Loop
    
    popad
    mov eax, dwRemoved
    ret
HM_RemoveAllHooks ENDP

;-------------------------------------------------------------------------------
; HM_GetTrampoline - Get trampoline address for a hook
;-------------------------------------------------------------------------------
HM_GetTrampoline PROC EXPORT dwHookID:DWORD
    lea edi, g_HookTable
    xor ecx, ecx
    
@Find:
    mov eax, dwHookID
    cmp [edi].HOOK_ENTRY.dwID, eax
    je @Found
    add edi, SIZEOF HOOK_ENTRY
    inc ecx
    cmp ecx, MAX_HOOKS
    jl @Find
    
    xor eax, eax
    ret
    
@Found:
    mov eax, [edi].HOOK_ENTRY.pTrampoline
    ret
HM_GetTrampoline ENDP

;-------------------------------------------------------------------------------
; HM_GetHookCount - Get number of active hooks
;-------------------------------------------------------------------------------
HM_GetHookCount PROC EXPORT
    mov eax, g_dwHookCount
    ret
HM_GetHookCount ENDP

END
```

---

## 📝 Part 3: Tasks

### Task 1: Add Pause/Resume (30 minutes)
Implement HM_PauseHook and HM_ResumeHook functions.

### Task 2: Hook Statistics (25 minutes)
Add call counting and timing statistics per hook.

### Task 3: Hook Chaining (45 minutes)
Allow multiple handlers for the same target function.

---

## ✅ Session Checklist

- [ ] Create centralized hook management
- [ ] Manage multiple hooks dynamically
- [ ] Use proper synchronization
- [ ] Implement hook add/remove operations

---

## 🔜 Next Session

In **Session 17: Logging and Statistics**, we'll:
- Build a comprehensive logging system
- Track detailed hook statistics
- Create reporting functions

[Continue to Session 17 →](session_17.md)
