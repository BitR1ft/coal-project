;===============================================================================
; MINI STEALTH INTERCEPTOR - Simplified Hook Engine (NASM)
;===============================================================================
; File:        hook_engine_nasm.asm
; Description: Simplified API Hooking Engine (NASM syntax)
; Authors:     Muhammad Adeel Haider (241541), Umar Farooq (241575)
; Course:      COAL - 5th Semester, BS Cyber Security
;===============================================================================

bits 32
section .data
    ; Logging strings
    szLogInit        db "[Mini Interceptor] Engine Initialized", 0
    
    ; State
    g_bInitialized   dd 0
    g_pTrampolineHeap dd 0
    g_dwOldProtect   dd 0

; Constants
HEAP_ZERO_MEMORY     equ 0x00000008
TRAMPOLINE_SIZE      equ 32
MAX_HOOKS            equ 16

section .text
global _InitializeHookEngine@0
global _ShutdownHookEngine@0

extern _GetProcessHeap@0
extern _HeapAlloc@12
extern _HeapFree@12
extern _OutputDebugStringA@4

;-------------------------------------------------------------------------------
; InitializeHookEngine - Initialize the hook engine
;-------------------------------------------------------------------------------
_InitializeHookEngine@0:
    pushad
    
    cmp dword [g_bInitialized], 1
    je .AlreadyInit
    
    ; Allocate heap for trampolines
    push HEAP_ZERO_MEMORY
    push TRAMPOLINE_SIZE * MAX_HOOKS
    call _GetProcessHeap@0
    push eax
    call _HeapAlloc@12
    test eax, eax
    jz .AllocFailed
    mov [g_pTrampolineHeap], eax
    
    mov dword [g_bInitialized], 1
    
    push szLogInit
    call _OutputDebugStringA@4
    
    popad
    mov eax, 1
    ret

.AlreadyInit:
    popad
    mov eax, 1
    ret

.AllocFailed:
    popad
    xor eax, eax
    ret

;-------------------------------------------------------------------------------
; ShutdownHookEngine - Shutdown the hook engine
;-------------------------------------------------------------------------------
_ShutdownHookEngine@0:
    pushad
    
    cmp dword [g_bInitialized], 0
    je .NotInit
    
    ; Free trampoline heap
    cmp dword [g_pTrampolineHeap], 0
    je .SkipFreeHeap
    
    push dword [g_pTrampolineHeap]
    push 0
    call _GetProcessHeap@0
    push eax
    call _HeapFree@12
    mov dword [g_pTrampolineHeap], 0

.SkipFreeHeap:
    mov dword [g_bInitialized], 0
    
.NotInit:
    popad
    mov eax, 1
    ret
