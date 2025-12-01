;===============================================================================
; STEALTH INTERCEPTOR - Core Hook Engine
;===============================================================================
; File:        hook_engine.asm
; Description: Main API Hooking Engine implementing the Trampoline technique
; Authors:     Muhammad Adeel Haider (241541), Umar Farooq (241575)
; Course:      COAL - 5th Semester, BS Cyber Security
; Date:        November 2024
;===============================================================================

.686                              ; Pentium Pro or later
.model flat, stdcall              ; 32-bit flat memory model, stdcall calling convention
option casemap:none               ; Case sensitive

;===============================================================================
; Include Files
;===============================================================================
include \masm32\include\windows.inc
include \masm32\include\kernel32.inc
include \masm32\include\user32.inc
includelib \masm32\lib\kernel32.lib
includelib \masm32\lib\user32.lib

;===============================================================================
; Constants and Definitions
;===============================================================================
HOOK_SIZE           EQU 5         ; Size of JMP instruction
MAX_HOOKS           EQU 256       ; Maximum number of concurrent hooks
TRAMPOLINE_SIZE     EQU 32        ; Size of trampoline buffer

; Hook status flags
HOOK_STATUS_INACTIVE EQU 0
HOOK_STATUS_ACTIVE   EQU 1
HOOK_STATUS_PAUSED   EQU 2

; Error codes
HOOK_SUCCESS         EQU 0
HOOK_ERR_INVALID_PTR EQU 1
HOOK_ERR_MEM_PROTECT EQU 2
HOOK_ERR_MAX_HOOKS   EQU 3
HOOK_ERR_NOT_FOUND   EQU 4
HOOK_ERR_ALLOC       EQU 5

;===============================================================================
; Hook Entry Structure
;===============================================================================
HOOK_ENTRY STRUCT
    pOriginalFunc    DWORD ?      ; Pointer to original function
    pHookFunc        DWORD ?      ; Pointer to our hook handler
    pTrampoline      DWORD ?      ; Pointer to trampoline code
    dwOriginalBytes  DWORD 8 DUP(?) ; Saved original bytes (up to 32 bytes)
    dwBytesStolen    DWORD ?      ; Number of bytes stolen
    dwStatus         DWORD ?      ; Hook status
    szFuncName       BYTE 64 DUP(?) ; Function name for debugging
HOOK_ENTRY ENDS

;===============================================================================
; Data Section
;===============================================================================
.data
    ; Hook table
    g_HookTable      HOOK_ENTRY MAX_HOOKS DUP(<>)
    g_dwHookCount    DWORD 0
    
    ; Logging strings
    szLogInit        BYTE "[Stealth Interceptor] Engine Initialized", 0
    szLogHookInstall BYTE "[Stealth Interceptor] Hook Installed: ", 0
    szLogHookRemove  BYTE "[Stealth Interceptor] Hook Removed: ", 0
    szLogError       BYTE "[Stealth Interceptor] Error: ", 0
    szNewLine        BYTE 13, 10, 0
    
    ; Critical section for thread safety
    g_CriticalSection CRITICAL_SECTION <>
    g_bInitialized   DWORD 0

;===============================================================================
; Uninitialized Data Section
;===============================================================================
.data?
    g_dwOldProtect   DWORD ?
    g_pTrampolineHeap DWORD ?

;===============================================================================
; Code Section
;===============================================================================
.code

;-------------------------------------------------------------------------------
; InitializeHookEngine
;-------------------------------------------------------------------------------
; Description: Initializes the hook engine
; Parameters:  None
; Returns:     EAX = HOOK_SUCCESS on success, error code otherwise
;-------------------------------------------------------------------------------
InitializeHookEngine PROC EXPORT
    pushad
    
    ; Check if already initialized
    cmp g_bInitialized, 1
    je @AlreadyInit
    
    ; Initialize critical section for thread safety
    lea eax, g_CriticalSection
    push eax
    call InitializeCriticalSection
    
    ; Allocate heap for trampolines
    push HEAP_ZERO_MEMORY
    push TRAMPOLINE_SIZE * MAX_HOOKS
    push 0
    call GetProcessHeap
    push eax
    call HeapAlloc
    test eax, eax
    jz @AllocFailed
    mov g_pTrampolineHeap, eax
    
    ; Clear hook table
    lea edi, g_HookTable
    mov ecx, SIZEOF HOOK_ENTRY * MAX_HOOKS
    xor al, al
    rep stosb
    
    ; Reset hook count
    mov g_dwHookCount, 0
    
    ; Mark as initialized
    mov g_bInitialized, 1
    
    ; Log initialization
    push OFFSET szLogInit
    call OutputDebugStringA
    
    popad
    mov eax, HOOK_SUCCESS
    ret

@AlreadyInit:
    popad
    mov eax, HOOK_SUCCESS
    ret

@AllocFailed:
    popad
    mov eax, HOOK_ERR_ALLOC
    ret
InitializeHookEngine ENDP

;-------------------------------------------------------------------------------
; ShutdownHookEngine
;-------------------------------------------------------------------------------
; Description: Shuts down the hook engine and removes all hooks
; Parameters:  None
; Returns:     EAX = HOOK_SUCCESS on success
;-------------------------------------------------------------------------------
ShutdownHookEngine PROC EXPORT
    pushad
    
    ; Check if initialized
    cmp g_bInitialized, 0
    je @NotInit
    
    ; Remove all active hooks
    call RemoveAllHooks
    
    ; Free trampoline heap
    cmp g_pTrampolineHeap, 0
    je @SkipFreeHeap
    push g_pTrampolineHeap
    push 0
    call GetProcessHeap
    push eax
    call HeapFree
    mov g_pTrampolineHeap, 0

@SkipFreeHeap:
    ; Delete critical section
    lea eax, g_CriticalSection
    push eax
    call DeleteCriticalSection
    
    ; Mark as not initialized
    mov g_bInitialized, 0
    
@NotInit:
    popad
    mov eax, HOOK_SUCCESS
    ret
ShutdownHookEngine ENDP

;-------------------------------------------------------------------------------
; InstallHook
;-------------------------------------------------------------------------------
; Description: Installs a hook on the target function
; Parameters:  
;   [ebp+8]  = pTargetFunc - Pointer to function to hook
;   [ebp+12] = pHookFunc   - Pointer to our hook handler
;   [ebp+16] = pszFuncName - Function name for debugging (optional)
; Returns:     
;   EAX = Hook ID on success (0 to MAX_HOOKS-1), -1 on failure
;-------------------------------------------------------------------------------
InstallHook PROC EXPORT pTargetFunc:DWORD, pHookFunc:DWORD, pszFuncName:DWORD
    LOCAL dwHookId:DWORD
    LOCAL pTrampoline:DWORD
    LOCAL dwBytesToSteal:DWORD
    
    pushad
    
    ; Enter critical section
    lea eax, g_CriticalSection
    push eax
    call EnterCriticalSection
    
    ; Validate parameters
    mov eax, pTargetFunc
    test eax, eax
    jz @InvalidParam
    mov eax, pHookFunc
    test eax, eax
    jz @InvalidParam
    
    ; Check if we have room for more hooks
    mov eax, g_dwHookCount
    cmp eax, MAX_HOOKS
    jge @MaxHooksReached
    
    ; Find a free slot in hook table
    lea edi, g_HookTable
    xor ecx, ecx
    
@FindSlot:
    cmp [edi].HOOK_ENTRY.dwStatus, HOOK_STATUS_INACTIVE
    je @FoundSlot
    add edi, SIZEOF HOOK_ENTRY
    inc ecx
    cmp ecx, MAX_HOOKS
    jl @FindSlot
    jmp @MaxHooksReached

@FoundSlot:
    mov dwHookId, ecx
    
    ; Calculate trampoline address
    mov eax, g_pTrampolineHeap
    mov ebx, dwHookId
    imul ebx, TRAMPOLINE_SIZE
    add eax, ebx
    mov pTrampoline, eax
    
    ; Determine how many bytes to steal (minimum 5 for JMP)
    ; For simplicity, we'll steal exactly 5 bytes
    ; In production, you'd need to disassemble to find instruction boundaries
    mov dwBytesToSteal, HOOK_SIZE
    
    ; Store hook entry information
    mov eax, pTargetFunc
    mov [edi].HOOK_ENTRY.pOriginalFunc, eax
    mov eax, pHookFunc
    mov [edi].HOOK_ENTRY.pHookFunc, eax
    mov eax, pTrampoline
    mov [edi].HOOK_ENTRY.pTrampoline, eax
    mov eax, dwBytesToSteal
    mov [edi].HOOK_ENTRY.dwBytesStolen, eax
    
    ; Copy function name if provided
    mov eax, pszFuncName
    test eax, eax
    jz @SkipName
    lea esi, pszFuncName
    mov esi, [esi]
    lea edi, [edi].HOOK_ENTRY.szFuncName
    mov ecx, 63
    
@CopyName:
    lodsb
    stosb
    test al, al
    jz @NameDone
    loop @CopyName
@NameDone:
    mov BYTE PTR [edi], 0
    
@SkipName:
    ; Reload EDI to point to hook entry
    lea edi, g_HookTable
    mov eax, dwHookId
    imul eax, SIZEOF HOOK_ENTRY
    add edi, eax
    
    ; Save original bytes
    mov esi, pTargetFunc
    lea ebx, [edi].HOOK_ENTRY.dwOriginalBytes
    mov ecx, dwBytesToSteal
    
@SaveBytes:
    mov al, [esi]
    mov [ebx], al
    inc esi
    inc ebx
    loop @SaveBytes
    
    ; Change memory protection to allow writing
    push OFFSET g_dwOldProtect
    push PAGE_EXECUTE_READWRITE
    push dwBytesToSteal
    push pTargetFunc
    call VirtualProtect
    test eax, eax
    jz @ProtectFailed
    
    ;---------------------------------------------------
    ; Build the trampoline
    ;---------------------------------------------------
    ; Trampoline layout:
    ;   [Saved original bytes] - Execute stolen instructions
    ;   [JMP back to original+N] - Resume execution
    ;---------------------------------------------------
    mov edi, pTrampoline
    
    ; Copy stolen bytes to trampoline
    lea esi, g_HookTable
    mov eax, dwHookId
    imul eax, SIZEOF HOOK_ENTRY
    add esi, eax
    lea esi, [esi].HOOK_ENTRY.dwOriginalBytes
    mov ecx, dwBytesToSteal
    rep movsb
    
    ; Add JMP back to original function + stolen bytes
    mov BYTE PTR [edi], 0E9h        ; JMP opcode
    mov eax, pTargetFunc
    add eax, dwBytesToSteal         ; Address after stolen bytes
    sub eax, edi
    sub eax, 5                      ; Relative to next instruction
    mov [edi+1], eax
    
    ; Make trampoline executable
    push OFFSET g_dwOldProtect
    push PAGE_EXECUTE_READWRITE
    push TRAMPOLINE_SIZE
    push pTrampoline
    call VirtualProtect
    
    ;---------------------------------------------------
    ; Install the hook (write JMP to target function)
    ;---------------------------------------------------
    mov edi, pTargetFunc
    
    ; Write JMP instruction
    mov BYTE PTR [edi], 0E9h        ; JMP opcode
    mov eax, pHookFunc
    sub eax, edi
    sub eax, 5                      ; Relative to next instruction
    mov [edi+1], eax
    
    ; Restore original memory protection
    push OFFSET g_dwOldProtect
    push g_dwOldProtect
    push dwBytesToSteal
    push pTargetFunc
    call VirtualProtect
    
    ; Update hook entry status
    lea edi, g_HookTable
    mov eax, dwHookId
    imul eax, SIZEOF HOOK_ENTRY
    add edi, eax
    mov [edi].HOOK_ENTRY.dwStatus, HOOK_STATUS_ACTIVE
    
    ; Increment hook count
    inc g_dwHookCount
    
    ; Flush instruction cache
    push dwBytesToSteal
    push pTargetFunc
    push -1                          ; Current process
    call FlushInstructionCache
    
    ; Leave critical section
    lea eax, g_CriticalSection
    push eax
    call LeaveCriticalSection
    
    popad
    mov eax, dwHookId
    ret

@InvalidParam:
    lea eax, g_CriticalSection
    push eax
    call LeaveCriticalSection
    popad
    mov eax, -1
    ret

@MaxHooksReached:
    lea eax, g_CriticalSection
    push eax
    call LeaveCriticalSection
    popad
    mov eax, -1
    ret

@ProtectFailed:
    lea eax, g_CriticalSection
    push eax
    call LeaveCriticalSection
    popad
    mov eax, -1
    ret
InstallHook ENDP

;-------------------------------------------------------------------------------
; RemoveHook
;-------------------------------------------------------------------------------
; Description: Removes a previously installed hook
; Parameters:  
;   [ebp+8] = dwHookId - Hook ID returned by InstallHook
; Returns:     
;   EAX = HOOK_SUCCESS on success, error code otherwise
;-------------------------------------------------------------------------------
RemoveHook PROC EXPORT dwHookId:DWORD
    LOCAL pOriginalFunc:DWORD
    LOCAL dwBytesToRestore:DWORD
    
    pushad
    
    ; Enter critical section
    lea eax, g_CriticalSection
    push eax
    call EnterCriticalSection
    
    ; Validate hook ID
    mov eax, dwHookId
    cmp eax, MAX_HOOKS
    jge @InvalidHookId
    
    ; Get hook entry
    lea edi, g_HookTable
    imul eax, SIZEOF HOOK_ENTRY
    add edi, eax
    
    ; Check if hook is active
    cmp [edi].HOOK_ENTRY.dwStatus, HOOK_STATUS_ACTIVE
    jne @NotActive
    
    ; Get original function pointer and bytes to restore
    mov eax, [edi].HOOK_ENTRY.pOriginalFunc
    mov pOriginalFunc, eax
    mov eax, [edi].HOOK_ENTRY.dwBytesStolen
    mov dwBytesToRestore, eax
    
    ; Change memory protection
    push OFFSET g_dwOldProtect
    push PAGE_EXECUTE_READWRITE
    push dwBytesToRestore
    push pOriginalFunc
    call VirtualProtect
    test eax, eax
    jz @ProtectFailed
    
    ; Restore original bytes
    ; Save EDI on stack for thread safety
    push edi
    mov esi, edi
    lea esi, [esi].HOOK_ENTRY.dwOriginalBytes
    mov edi, pOriginalFunc
    mov ecx, dwBytesToRestore
    rep movsb
    pop edi
    
    ; Restore memory protection
    push OFFSET g_dwOldProtect
    push g_dwOldProtect
    push dwBytesToRestore
    push pOriginalFunc
    call VirtualProtect
    
    ; Flush instruction cache
    push dwBytesToRestore
    push pOriginalFunc
    push -1
    call FlushInstructionCache
    
    ; Mark hook as inactive
    mov [edi].HOOK_ENTRY.dwStatus, HOOK_STATUS_INACTIVE
    dec g_dwHookCount
    
    ; Leave critical section
    lea eax, g_CriticalSection
    push eax
    call LeaveCriticalSection
    
    popad
    mov eax, HOOK_SUCCESS
    ret

@InvalidHookId:
@NotActive:
@ProtectFailed:
    lea eax, g_CriticalSection
    push eax
    call LeaveCriticalSection
    popad
    mov eax, HOOK_ERR_NOT_FOUND
    ret
RemoveHook ENDP

;-------------------------------------------------------------------------------
; RemoveAllHooks
;-------------------------------------------------------------------------------
; Description: Removes all installed hooks
; Parameters:  None
; Returns:     EAX = Number of hooks removed
;-------------------------------------------------------------------------------
RemoveAllHooks PROC EXPORT
    LOCAL dwRemoved:DWORD
    
    pushad
    mov dwRemoved, 0
    
    xor ecx, ecx
    
@RemoveLoop:
    push ecx
    
    ; Check if hook is active
    lea edi, g_HookTable
    mov eax, ecx
    imul eax, SIZEOF HOOK_ENTRY
    add edi, eax
    cmp [edi].HOOK_ENTRY.dwStatus, HOOK_STATUS_ACTIVE
    jne @SkipRemove
    
    ; Remove this hook
    push ecx
    call RemoveHook
    inc dwRemoved

@SkipRemove:
    pop ecx
    inc ecx
    cmp ecx, MAX_HOOKS
    jl @RemoveLoop
    
    popad
    mov eax, dwRemoved
    ret
RemoveAllHooks ENDP

;-------------------------------------------------------------------------------
; GetTrampoline
;-------------------------------------------------------------------------------
; Description: Gets the trampoline address for a hook
; Parameters:  
;   [ebp+8] = dwHookId - Hook ID
; Returns:     
;   EAX = Trampoline address, or 0 if not found
;-------------------------------------------------------------------------------
GetTrampoline PROC EXPORT dwHookId:DWORD
    mov eax, dwHookId
    cmp eax, MAX_HOOKS
    jge @NotFound
    
    lea edi, g_HookTable
    imul eax, SIZEOF HOOK_ENTRY
    add edi, eax
    
    cmp [edi].HOOK_ENTRY.dwStatus, HOOK_STATUS_ACTIVE
    jne @NotFound
    
    mov eax, [edi].HOOK_ENTRY.pTrampoline
    ret

@NotFound:
    xor eax, eax
    ret
GetTrampoline ENDP

;-------------------------------------------------------------------------------
; GetHookCount
;-------------------------------------------------------------------------------
; Description: Returns the number of active hooks
; Parameters:  None
; Returns:     EAX = Number of active hooks
;-------------------------------------------------------------------------------
GetHookCount PROC EXPORT
    mov eax, g_dwHookCount
    ret
GetHookCount ENDP

;-------------------------------------------------------------------------------
; IsHookActive
;-------------------------------------------------------------------------------
; Description: Checks if a hook is active
; Parameters:  
;   [ebp+8] = dwHookId - Hook ID
; Returns:     
;   EAX = 1 if active, 0 otherwise
;-------------------------------------------------------------------------------
IsHookActive PROC EXPORT dwHookId:DWORD
    mov eax, dwHookId
    cmp eax, MAX_HOOKS
    jge @NotActive
    
    lea edi, g_HookTable
    imul eax, SIZEOF HOOK_ENTRY
    add edi, eax
    
    cmp [edi].HOOK_ENTRY.dwStatus, HOOK_STATUS_ACTIVE
    jne @NotActive
    
    mov eax, 1
    ret

@NotActive:
    xor eax, eax
    ret
IsHookActive ENDP

;-------------------------------------------------------------------------------
; PauseHook
;-------------------------------------------------------------------------------
; Description: Temporarily pauses a hook (restores original bytes)
; Parameters:  
;   [ebp+8] = dwHookId - Hook ID
; Returns:     
;   EAX = HOOK_SUCCESS on success
;-------------------------------------------------------------------------------
PauseHook PROC EXPORT dwHookId:DWORD
    ; Similar to RemoveHook but sets status to PAUSED
    ; Implementation left as exercise
    mov eax, HOOK_SUCCESS
    ret
PauseHook ENDP

;-------------------------------------------------------------------------------
; ResumeHook
;-------------------------------------------------------------------------------
; Description: Resumes a paused hook
; Parameters:  
;   [ebp+8] = dwHookId - Hook ID
; Returns:     
;   EAX = HOOK_SUCCESS on success
;-------------------------------------------------------------------------------
ResumeHook PROC EXPORT dwHookId:DWORD
    ; Re-installs the hook if paused
    ; Implementation left as exercise
    mov eax, HOOK_SUCCESS
    ret
ResumeHook ENDP

END
