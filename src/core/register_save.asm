;===============================================================================
; STEALTH INTERCEPTOR - Register Save/Restore
;===============================================================================
; File:        register_save.asm
; Description: CPU register preservation for safe hook execution
; Authors:     Muhammad Adeel Haider (241541), Umar Farooq (241575)
; Course:      COAL - 5th Semester, BS Cyber Security
; Date:        November 2024
;===============================================================================

.686
.model flat, stdcall
option casemap:none

;===============================================================================
; Include Files
;===============================================================================
include \masm32\include\windows.inc

;===============================================================================
; Constants
;===============================================================================
; Register indices
REG_EAX EQU 0
REG_ECX EQU 1
REG_EDX EQU 2
REG_EBX EQU 3
REG_ESP EQU 4
REG_EBP EQU 5
REG_ESI EQU 6
REG_EDI EQU 7

; Context flags
CONTEXT_FULL EQU 10007h

;===============================================================================
; Register Context Structure
;===============================================================================
REGISTER_CONTEXT STRUCT
    ; General purpose registers
    dwEax    DWORD ?
    dwEcx    DWORD ?
    dwEdx    DWORD ?
    dwEbx    DWORD ?
    dwEsp    DWORD ?
    dwEbp    DWORD ?
    dwEsi    DWORD ?
    dwEdi    DWORD ?
    
    ; Segment registers
    wCs      WORD ?
    wDs      WORD ?
    wEs      WORD ?
    wFs      WORD ?
    wGs      WORD ?
    wSs      WORD ?
    
    ; Flags register
    dwEflags DWORD ?
    
    ; Instruction pointer
    dwEip    DWORD ?
    
    ; FPU state (optional)
    fpuState BYTE 108 DUP(?)
    
    ; Reserved
    dwReserved DWORD 4 DUP(?)
REGISTER_CONTEXT ENDS

;===============================================================================
; Data Section
;===============================================================================
.data
    ; Global context storage for quick saves
    g_QuickContext REGISTER_CONTEXT <>
    g_ContextValid DWORD 0

;===============================================================================
; Code Section
;===============================================================================
.code

;-------------------------------------------------------------------------------
; SaveAllRegisters
;-------------------------------------------------------------------------------
; Description: Saves all general purpose registers to a context structure
;              This is a more controlled alternative to PUSHAD
; Parameters:
;   [ebp+8] = pContext - Pointer to REGISTER_CONTEXT structure
; Returns:     EAX = 1 on success
; Notes:       This preserves the exact register state for restoration
;-------------------------------------------------------------------------------
SaveAllRegisters PROC EXPORT pContext:DWORD
    ; We need to save EAX first, but we need it to access pContext
    ; So we save to global first, then copy
    push ebp
    mov ebp, esp
    
    ; Get context pointer
    mov ebp, [ebp+8]
    test ebp, ebp
    jz @InvalidContext
    
    ; Save all registers to context
    mov [ebp].REGISTER_CONTEXT.dwEax, eax
    mov [ebp].REGISTER_CONTEXT.dwEcx, ecx
    mov [ebp].REGISTER_CONTEXT.dwEdx, edx
    mov [ebp].REGISTER_CONTEXT.dwEbx, ebx
    ; ESP needs special handling - save the value before our PUSH EBP
    mov eax, esp
    add eax, 8              ; Compensate for PUSH EBP and return address
    mov [ebp].REGISTER_CONTEXT.dwEsp, eax
    ; EBP is our context pointer, save original from stack
    mov eax, [esp]          ; Original EBP is on stack
    mov [ebp].REGISTER_CONTEXT.dwEbp, eax
    mov [ebp].REGISTER_CONTEXT.dwEsi, esi
    mov [ebp].REGISTER_CONTEXT.dwEdi, edi
    
    ; Save segment registers
    mov ax, cs
    mov [ebp].REGISTER_CONTEXT.wCs, ax
    mov ax, ds
    mov [ebp].REGISTER_CONTEXT.wDs, ax
    mov ax, es
    mov [ebp].REGISTER_CONTEXT.wEs, ax
    mov ax, fs
    mov [ebp].REGISTER_CONTEXT.wFs, ax
    mov ax, gs
    mov [ebp].REGISTER_CONTEXT.wGs, ax
    mov ax, ss
    mov [ebp].REGISTER_CONTEXT.wSs, ax
    
    ; Save flags
    pushfd
    pop eax
    mov [ebp].REGISTER_CONTEXT.dwEflags, eax
    
    pop ebp
    mov eax, 1
    ret 4

@InvalidContext:
    pop ebp
    xor eax, eax
    ret 4
SaveAllRegisters ENDP

;-------------------------------------------------------------------------------
; RestoreAllRegisters
;-------------------------------------------------------------------------------
; Description: Restores all registers from a context structure
; Parameters:
;   [ebp+8] = pContext - Pointer to REGISTER_CONTEXT structure
; Returns:     Does not return normally - restores execution context
; Notes:       This is typically used for full context restoration
;-------------------------------------------------------------------------------
RestoreAllRegisters PROC EXPORT pContext:DWORD
    push ebp
    mov ebp, esp
    
    ; Get context pointer
    mov esi, [ebp+8]
    test esi, esi
    jz @InvalidContext
    
    ; Restore flags first (before we modify other registers)
    push [esi].REGISTER_CONTEXT.dwEflags
    popfd
    
    ; Restore general purpose registers
    mov eax, [esi].REGISTER_CONTEXT.dwEax
    mov ecx, [esi].REGISTER_CONTEXT.dwEcx
    mov edx, [esi].REGISTER_CONTEXT.dwEdx
    mov ebx, [esi].REGISTER_CONTEXT.dwEbx
    mov edi, [esi].REGISTER_CONTEXT.dwEdi
    mov ebp, [esi].REGISTER_CONTEXT.dwEbp
    
    ; ESI must be restored last since we're using it
    mov esi, [esi].REGISTER_CONTEXT.dwEsi
    
    ; Note: ESP restoration is tricky and context-dependent
    ; The caller should handle stack restoration
    
    ret 4

@InvalidContext:
    pop ebp
    xor eax, eax
    ret 4
RestoreAllRegisters ENDP

;-------------------------------------------------------------------------------
; QuickSaveContext
;-------------------------------------------------------------------------------
; Description: Quickly saves context to global storage (PUSHAD equivalent)
; Parameters:  None
; Returns:     None
; Notes:       Fast but not re-entrant
;-------------------------------------------------------------------------------
QuickSaveContext PROC EXPORT
    ; Save to global context
    mov g_QuickContext.dwEax, eax
    mov g_QuickContext.dwEcx, ecx
    mov g_QuickContext.dwEdx, edx
    mov g_QuickContext.dwEbx, ebx
    mov g_QuickContext.dwEsp, esp
    mov g_QuickContext.dwEbp, ebp
    mov g_QuickContext.dwEsi, esi
    mov g_QuickContext.dwEdi, edi
    
    ; Save flags
    pushfd
    pop eax
    mov g_QuickContext.dwEflags, eax
    
    ; Restore EAX
    mov eax, g_QuickContext.dwEax
    
    mov g_ContextValid, 1
    ret
QuickSaveContext ENDP

;-------------------------------------------------------------------------------
; QuickRestoreContext
;-------------------------------------------------------------------------------
; Description: Restores context from global storage (POPAD equivalent)
; Parameters:  None
; Returns:     None
;-------------------------------------------------------------------------------
QuickRestoreContext PROC EXPORT
    ; Check if context is valid
    cmp g_ContextValid, 0
    je @NoRestore
    
    ; Restore flags
    push g_QuickContext.dwEflags
    popfd
    
    ; Restore registers
    mov eax, g_QuickContext.dwEax
    mov ecx, g_QuickContext.dwEcx
    mov edx, g_QuickContext.dwEdx
    mov ebx, g_QuickContext.dwEbx
    mov ebp, g_QuickContext.dwEbp
    mov esi, g_QuickContext.dwEsi
    mov edi, g_QuickContext.dwEdi
    
    mov g_ContextValid, 0

@NoRestore:
    ret
QuickRestoreContext ENDP

;-------------------------------------------------------------------------------
; SaveFPUState
;-------------------------------------------------------------------------------
; Description: Saves FPU/MMX state
; Parameters:
;   [ebp+8] = pBuffer - Pointer to 108-byte buffer
; Returns:     EAX = 1 on success
;-------------------------------------------------------------------------------
SaveFPUState PROC EXPORT pBuffer:DWORD
    push edi
    
    mov edi, pBuffer
    test edi, edi
    jz @InvalidBuffer
    
    ; Save FPU state
    fsave [edi]
    
    pop edi
    mov eax, 1
    ret

@InvalidBuffer:
    pop edi
    xor eax, eax
    ret
SaveFPUState ENDP

;-------------------------------------------------------------------------------
; RestoreFPUState
;-------------------------------------------------------------------------------
; Description: Restores FPU/MMX state
; Parameters:
;   [ebp+8] = pBuffer - Pointer to saved state
; Returns:     EAX = 1 on success
;-------------------------------------------------------------------------------
RestoreFPUState PROC EXPORT pBuffer:DWORD
    push esi
    
    mov esi, pBuffer
    test esi, esi
    jz @InvalidBuffer
    
    ; Restore FPU state
    frstor [esi]
    
    pop esi
    mov eax, 1
    ret

@InvalidBuffer:
    pop esi
    xor eax, eax
    ret
RestoreFPUState ENDP

;-------------------------------------------------------------------------------
; HOOK_PROLOG Macro
;-------------------------------------------------------------------------------
; Description: Standard hook function prolog - saves all state
; Usage:       Call at the beginning of hook handlers
;-------------------------------------------------------------------------------
; This would typically be a macro, shown here as a function
HookProlog PROC EXPORT
    ; Save all general purpose registers
    pushad
    ; Save flags
    pushfd
    ; Save FPU state if needed
    ; sub esp, 108
    ; fsave [esp]
    ret
HookProlog ENDP

;-------------------------------------------------------------------------------
; HOOK_EPILOG Macro
;-------------------------------------------------------------------------------
; Description: Standard hook function epilog - restores all state
; Usage:       Call at the end of hook handlers before jumping to original
;-------------------------------------------------------------------------------
HookEpilog PROC EXPORT
    ; Restore FPU state if saved
    ; frstor [esp]
    ; add esp, 108
    ; Restore flags
    popfd
    ; Restore all general purpose registers
    popad
    ret
HookEpilog ENDP

;-------------------------------------------------------------------------------
; GetRegisterValue
;-------------------------------------------------------------------------------
; Description: Gets a specific register value from context
; Parameters:
;   [ebp+8]  = pContext - Pointer to REGISTER_CONTEXT
;   [ebp+12] = dwRegIndex - Register index (REG_EAX, REG_ECX, etc.)
; Returns:     EAX = Register value, or 0 if invalid
;-------------------------------------------------------------------------------
GetRegisterValue PROC EXPORT pContext:DWORD, dwRegIndex:DWORD
    push esi
    
    mov esi, pContext
    test esi, esi
    jz @Invalid
    
    mov eax, dwRegIndex
    cmp eax, 7
    ja @Invalid
    
    ; Calculate offset into context (each register is a DWORD)
    shl eax, 2              ; Multiply by 4
    add esi, eax
    mov eax, [esi]
    
    pop esi
    ret

@Invalid:
    pop esi
    xor eax, eax
    ret
GetRegisterValue ENDP

;-------------------------------------------------------------------------------
; SetRegisterValue
;-------------------------------------------------------------------------------
; Description: Sets a specific register value in context
; Parameters:
;   [ebp+8]  = pContext - Pointer to REGISTER_CONTEXT
;   [ebp+12] = dwRegIndex - Register index
;   [ebp+16] = dwValue - Value to set
; Returns:     EAX = 1 on success, 0 on failure
;-------------------------------------------------------------------------------
SetRegisterValue PROC EXPORT pContext:DWORD, dwRegIndex:DWORD, dwValue:DWORD
    push esi
    
    mov esi, pContext
    test esi, esi
    jz @Invalid
    
    mov eax, dwRegIndex
    cmp eax, 7
    ja @Invalid
    
    ; Calculate offset
    shl eax, 2
    add esi, eax
    mov eax, dwValue
    mov [esi], eax
    
    pop esi
    mov eax, 1
    ret

@Invalid:
    pop esi
    xor eax, eax
    ret
SetRegisterValue ENDP

;-------------------------------------------------------------------------------
; DumpRegisters
;-------------------------------------------------------------------------------
; Description: Outputs register values to debug output
; Parameters:
;   [ebp+8] = pContext - Pointer to REGISTER_CONTEXT
; Returns:     None
; Notes:       For debugging purposes
;-------------------------------------------------------------------------------
DumpRegisters PROC EXPORT pContext:DWORD
    ; This would format and output register values
    ; Left as a stub - implementation would use OutputDebugString
    ret
DumpRegisters ENDP

;-------------------------------------------------------------------------------
; CompareContexts
;-------------------------------------------------------------------------------
; Description: Compares two register contexts
; Parameters:
;   [ebp+8]  = pContext1 - First context
;   [ebp+12] = pContext2 - Second context
; Returns:     EAX = 1 if equal, 0 if different
;-------------------------------------------------------------------------------
CompareContexts PROC EXPORT pContext1:DWORD, pContext2:DWORD
    push esi
    push edi
    push ecx
    
    mov esi, pContext1
    mov edi, pContext2
    
    test esi, esi
    jz @Different
    test edi, edi
    jz @Different
    
    ; Compare first 8 DWORDs (general purpose registers)
    mov ecx, 8

@CompareLoop:
    mov eax, [esi]
    cmp eax, [edi]
    jne @Different
    add esi, 4
    add edi, 4
    loop @CompareLoop
    
    ; Contexts are equal
    pop ecx
    pop edi
    pop esi
    mov eax, 1
    ret

@Different:
    pop ecx
    pop edi
    pop esi
    xor eax, eax
    ret
CompareContexts ENDP

END
