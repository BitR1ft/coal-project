;===============================================================================
; MINI STEALTH INTERCEPTOR - Simplified Hook Engine
;===============================================================================
; File:        hook_engine.asm
; Description: Simplified API Hooking Engine implementing the Trampoline technique
; Authors:     Muhammad Adeel Haider (241541), Umar Farooq (241575)
; Course:      COAL - 5th Semester, BS Cyber Security
;===============================================================================

.686
.model flat, stdcall
option casemap:none

;===============================================================================
; Include Files
;===============================================================================
include \masm32\include\windows.inc
include \masm32\include\kernel32.inc
include \masm32\include\user32.inc
includelib \masm32\lib\kernel32.lib
includelib \masm32\lib\user32.lib

;===============================================================================
; Constants
;===============================================================================
HOOK_SIZE           EQU 5         ; Size of JMP instruction
MAX_HOOKS           EQU 16        ; Maximum concurrent hooks (reduced for mini version)
TRAMPOLINE_SIZE     EQU 32        ; Size of trampoline buffer

;===============================================================================
; Data Section
;===============================================================================
.data
    ; Logging strings
    szLogInit        BYTE "[Mini Interceptor] Engine Initialized", 0
    
    ; State
    g_bInitialized   DWORD 0

.data?
    g_dwOldProtect   DWORD ?
    g_pTrampolineHeap DWORD ?

;===============================================================================
; Code Section
;===============================================================================
.code

;-------------------------------------------------------------------------------
; InitializeHookEngine - Initialize the hook engine
;-------------------------------------------------------------------------------
InitializeHookEngine PROC EXPORT
    pushad
    
    cmp g_bInitialized, 1
    je @AlreadyInit
    
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
    
    mov g_bInitialized, 1
    
    push OFFSET szLogInit
    call OutputDebugStringA
    
    popad
    mov eax, 1
    ret

@AlreadyInit:
    popad
    mov eax, 1
    ret

@AllocFailed:
    popad
    xor eax, eax
    ret
InitializeHookEngine ENDP

;-------------------------------------------------------------------------------
; ShutdownHookEngine - Shutdown the hook engine
;-------------------------------------------------------------------------------
ShutdownHookEngine PROC EXPORT
    pushad
    
    cmp g_bInitialized, 0
    je @NotInit
    
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
    mov g_bInitialized, 0
    
@NotInit:
    popad
    mov eax, 1
    ret
ShutdownHookEngine ENDP

END
