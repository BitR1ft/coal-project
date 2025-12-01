;===============================================================================
; STEALTH INTERCEPTOR - Trampoline Implementation
;===============================================================================
; File:        trampoline.asm
; Description: Implementation of the trampoline hooking technique
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
include \masm32\include\kernel32.inc
includelib \masm32\lib\kernel32.lib

;===============================================================================
; Constants
;===============================================================================
TRAMPOLINE_BUFFER_SIZE EQU 64       ; Size for each trampoline
MAX_INSTRUCTION_SIZE   EQU 15       ; Maximum x86 instruction size
JMP_SIZE              EQU 5         ; Size of near JMP instruction

; Instruction prefixes for disassembly
PREFIX_OPERAND_SIZE   EQU 066h
PREFIX_ADDRESS_SIZE   EQU 067h
PREFIX_LOCK           EQU 0F0h
PREFIX_REPNE          EQU 0F2h
PREFIX_REP            EQU 0F3h
PREFIX_CS             EQU 02Eh
PREFIX_SS             EQU 036h
PREFIX_DS             EQU 03Eh
PREFIX_ES             EQU 026h
PREFIX_FS             EQU 064h
PREFIX_GS             EQU 065h

;===============================================================================
; Trampoline Info Structure
;===============================================================================
TRAMPOLINE_INFO STRUCT
    pOriginalFunc    DWORD ?        ; Original function address
    pTrampolineCode  DWORD ?        ; Trampoline code address
    dwStolenBytes    DWORD ?        ; Number of stolen bytes
    aStolenCode      BYTE 32 DUP(?) ; Stored stolen instructions
    dwFlags          DWORD ?        ; Trampoline flags
TRAMPOLINE_INFO ENDS

;===============================================================================
; Data Section
;===============================================================================
.data
    ; JMP instruction template (E9 xx xx xx xx)
    g_JmpTemplate    BYTE 0E9h, 00h, 00h, 00h, 00h
    
    ; CALL instruction template (E8 xx xx xx xx)
    g_CallTemplate   BYTE 0E8h, 00h, 00h, 00h, 00h
    
    ; PUSH RET template for absolute jump
    ; PUSH imm32 / RET
    g_PushRetTemplate BYTE 068h, 00h, 00h, 00h, 00h, 0C3h
    
    ; Simple length table for common instructions
    ; This is a simplified version - real implementation would need full disassembler
    g_InstrLengthTable BYTE 256 DUP(1)  ; Default 1 byte

.data?
    g_pTrampolineBuffer DWORD ?
    g_dwTrampolineCount DWORD ?

;===============================================================================
; Code Section
;===============================================================================
.code

;-------------------------------------------------------------------------------
; InitializeTrampolineSystem
;-------------------------------------------------------------------------------
; Description: Initializes the trampoline allocation system
; Parameters:  None
; Returns:     EAX = 1 on success, 0 on failure
;-------------------------------------------------------------------------------
InitializeTrampolineSystem PROC EXPORT
    pushad
    
    ; Allocate memory for trampolines
    ; Using VirtualAlloc to ensure executable memory
    push PAGE_EXECUTE_READWRITE
    push MEM_COMMIT or MEM_RESERVE
    push TRAMPOLINE_BUFFER_SIZE * 256  ; Space for 256 trampolines
    push NULL
    call VirtualAlloc
    test eax, eax
    jz @AllocFailed
    mov g_pTrampolineBuffer, eax
    
    ; Initialize counter
    mov g_dwTrampolineCount, 0
    
    popad
    mov eax, 1
    ret

@AllocFailed:
    popad
    xor eax, eax
    ret
InitializeTrampolineSystem ENDP

;-------------------------------------------------------------------------------
; CleanupTrampolineSystem
;-------------------------------------------------------------------------------
; Description: Cleans up trampoline system resources
; Parameters:  None
; Returns:     None
;-------------------------------------------------------------------------------
CleanupTrampolineSystem PROC EXPORT
    pushad
    
    ; Free trampoline buffer
    cmp g_pTrampolineBuffer, 0
    je @NoBuffer
    
    push MEM_RELEASE
    push 0
    push g_pTrampolineBuffer
    call VirtualFree
    mov g_pTrampolineBuffer, 0

@NoBuffer:
    mov g_dwTrampolineCount, 0
    
    popad
    ret
CleanupTrampolineSystem ENDP

;-------------------------------------------------------------------------------
; AllocateTrampoline
;-------------------------------------------------------------------------------
; Description: Allocates a new trampoline from the buffer
; Parameters:  None
; Returns:     EAX = Pointer to trampoline, or 0 if failed
;-------------------------------------------------------------------------------
AllocateTrampoline PROC EXPORT
    pushad
    
    ; Check if buffer is initialized
    cmp g_pTrampolineBuffer, 0
    je @NoBuffer
    
    ; Check if we have room
    cmp g_dwTrampolineCount, 256
    jge @NoRoom
    
    ; Calculate address for new trampoline
    mov eax, g_dwTrampolineCount
    imul eax, TRAMPOLINE_BUFFER_SIZE
    add eax, g_pTrampolineBuffer
    
    ; Increment counter
    inc g_dwTrampolineCount
    
    ; Zero out the trampoline space
    push eax
    mov edi, eax
    mov ecx, TRAMPOLINE_BUFFER_SIZE
    xor al, al
    rep stosb
    pop eax
    
    mov [esp + 28], eax  ; Store result in EAX position on stack
    popad
    ret

@NoBuffer:
@NoRoom:
    popad
    xor eax, eax
    ret
AllocateTrampoline ENDP

;-------------------------------------------------------------------------------
; BuildTrampoline
;-------------------------------------------------------------------------------
; Description: Builds a trampoline for a target function
; Parameters:
;   [ebp+8]  = pOriginalFunc - Original function to hook
;   [ebp+12] = dwBytesToSteal - Number of bytes to copy
;   [ebp+16] = pTrampoline - Pre-allocated trampoline buffer
; Returns:     EAX = 1 on success, 0 on failure
;-------------------------------------------------------------------------------
BuildTrampoline PROC EXPORT pOriginalFunc:DWORD, dwBytesToSteal:DWORD, pTrampoline:DWORD
    LOCAL dwOffset:DWORD
    
    pushad
    
    ; Validate parameters
    cmp pOriginalFunc, 0
    je @Failed
    cmp pTrampoline, 0
    je @Failed
    cmp dwBytesToSteal, 0
    je @Failed
    cmp dwBytesToSteal, 32
    jg @Failed
    
    ; Copy stolen bytes to trampoline
    mov esi, pOriginalFunc
    mov edi, pTrampoline
    mov ecx, dwBytesToSteal
    rep movsb
    
    ; Now add jump back to original function + stolen bytes
    ; JMP rel32 (E9 xx xx xx xx)
    mov BYTE PTR [edi], 0E9h
    
    ; Calculate relative offset
    ; Offset = Target - (Current + 5)
    mov eax, pOriginalFunc
    add eax, dwBytesToSteal      ; Target = original + stolen
    mov ebx, edi
    add ebx, 5                    ; Current + 5 = address after JMP
    sub eax, ebx                  ; Relative offset
    mov [edi+1], eax
    
    popad
    mov eax, 1
    ret

@Failed:
    popad
    xor eax, eax
    ret
BuildTrampoline ENDP

;-------------------------------------------------------------------------------
; GetInstructionLength
;-------------------------------------------------------------------------------
; Description: Gets the length of an x86 instruction (simplified)
; Parameters:
;   [ebp+8] = pInstruction - Pointer to instruction
; Returns:     EAX = Length in bytes
; Note: This is a simplified implementation. A production version would
;       need a full x86 disassembler.
;-------------------------------------------------------------------------------
GetInstructionLength PROC EXPORT pInstruction:DWORD
    push ebx
    push ecx
    push esi
    
    mov esi, pInstruction
    xor eax, eax
    xor ecx, ecx              ; Prefix count
    
    ; Skip instruction prefixes
@CheckPrefix:
    movzx ebx, BYTE PTR [esi]
    
    ; Check for common prefixes
    cmp bl, PREFIX_OPERAND_SIZE
    je @HasPrefix
    cmp bl, PREFIX_ADDRESS_SIZE
    je @HasPrefix
    cmp bl, PREFIX_LOCK
    je @HasPrefix
    cmp bl, PREFIX_REPNE
    je @HasPrefix
    cmp bl, PREFIX_REP
    je @HasPrefix
    cmp bl, PREFIX_CS
    je @HasPrefix
    cmp bl, PREFIX_SS
    je @HasPrefix
    cmp bl, PREFIX_DS
    je @HasPrefix
    cmp bl, PREFIX_ES
    je @HasPrefix
    cmp bl, PREFIX_FS
    je @HasPrefix
    cmp bl, PREFIX_GS
    je @HasPrefix
    jmp @NoMorePrefixes

@HasPrefix:
    inc esi
    inc ecx
    cmp ecx, 4                ; Max 4 prefixes
    jl @CheckPrefix
    
@NoMorePrefixes:
    ; Get opcode
    movzx eax, BYTE PTR [esi]
    
    ; Handle common instructions (simplified)
    ; This covers the most common function prologues
    
    ; MOV EDI, EDI (8B FF) - 2 bytes
    cmp al, 08Bh
    jne @NotMov1
    cmp BYTE PTR [esi+1], 0FFh
    jne @NotMov1
    add ecx, 2
    jmp @Done

@NotMov1:
    ; PUSH EBP (55) - 1 byte
    cmp al, 055h
    jne @NotPushEbp
    add ecx, 1
    jmp @Done

@NotPushEbp:
    ; MOV EBP, ESP (8B EC or 89 E5) - 2 bytes
    cmp al, 08Bh
    jne @NotMovEbpEsp1
    cmp BYTE PTR [esi+1], 0ECh
    jne @NotMovEbpEsp1
    add ecx, 2
    jmp @Done

@NotMovEbpEsp1:
    cmp al, 089h
    jne @NotMovEbpEsp2
    cmp BYTE PTR [esi+1], 0E5h
    jne @NotMovEbpEsp2
    add ecx, 2
    jmp @Done

@NotMovEbpEsp2:
    ; SUB ESP, imm8 (83 EC xx) - 3 bytes
    cmp al, 083h
    jne @NotSubEsp
    cmp BYTE PTR [esi+1], 0ECh
    jne @NotSubEsp
    add ecx, 3
    jmp @Done

@NotSubEsp:
    ; PUSH reg (50-57) - 1 byte
    cmp al, 050h
    jl @NotPushReg
    cmp al, 057h
    jg @NotPushReg
    add ecx, 1
    jmp @Done

@NotPushReg:
    ; NOP (90) - 1 byte
    cmp al, 090h
    jne @NotNop
    add ecx, 1
    jmp @Done

@NotNop:
    ; JMP short (EB xx) - 2 bytes
    cmp al, 0EBh
    jne @NotJmpShort
    add ecx, 2
    jmp @Done

@NotJmpShort:
    ; JMP near (E9 xx xx xx xx) - 5 bytes
    cmp al, 0E9h
    jne @NotJmpNear
    add ecx, 5
    jmp @Done

@NotJmpNear:
    ; CALL (E8 xx xx xx xx) - 5 bytes
    cmp al, 0E8h
    jne @NotCall
    add ecx, 5
    jmp @Done

@NotCall:
    ; RET (C3) - 1 byte
    cmp al, 0C3h
    jne @NotRet
    add ecx, 1
    jmp @Done

@NotRet:
    ; Default: assume 1 byte instruction
    add ecx, 1

@Done:
    mov eax, ecx
    
    pop esi
    pop ecx
    pop ebx
    ret
GetInstructionLength ENDP

;-------------------------------------------------------------------------------
; CalculateMinimumBytes
;-------------------------------------------------------------------------------
; Description: Calculates minimum bytes needed for hook installation
; Parameters:
;   [ebp+8] = pFunction - Pointer to function
;   [ebp+12] = dwMinimum - Minimum bytes needed (usually 5 for JMP)
; Returns:     EAX = Number of bytes to steal (aligned to instruction boundary)
;-------------------------------------------------------------------------------
CalculateMinimumBytes PROC EXPORT pFunction:DWORD, dwMinimum:DWORD
    LOCAL dwTotal:DWORD
    LOCAL pCurrent:DWORD
    
    push ebx
    push ecx
    push esi
    
    mov dwTotal, 0
    mov eax, pFunction
    mov pCurrent, eax
    
@CountLoop:
    ; Get length of current instruction
    push pCurrent
    call GetInstructionLength
    
    ; Add to total
    add dwTotal, eax
    add pCurrent, eax
    
    ; Check if we have enough bytes
    mov ebx, dwTotal
    cmp ebx, dwMinimum
    jl @CountLoop
    
    mov eax, dwTotal
    
    pop esi
    pop ecx
    pop ebx
    ret
CalculateMinimumBytes ENDP

;-------------------------------------------------------------------------------
; InstallTrampolineHook
;-------------------------------------------------------------------------------
; Description: Complete trampoline hook installation
; Parameters:
;   [ebp+8]  = pTargetFunc - Function to hook
;   [ebp+12] = pHookFunc - Hook handler function
;   [ebp+16] = ppTrampoline - Pointer to receive trampoline address
; Returns:     EAX = 1 on success, 0 on failure
;-------------------------------------------------------------------------------
InstallTrampolineHook PROC EXPORT pTargetFunc:DWORD, pHookFunc:DWORD, ppTrampoline:DWORD
    LOCAL pTrampoline:DWORD
    LOCAL dwBytesToSteal:DWORD
    LOCAL dwOldProtect:DWORD
    
    pushad
    
    ; Calculate bytes to steal
    push JMP_SIZE
    push pTargetFunc
    call CalculateMinimumBytes
    mov dwBytesToSteal, eax
    
    ; Allocate trampoline
    call AllocateTrampoline
    test eax, eax
    jz @Failed
    mov pTrampoline, eax
    
    ; Store trampoline address for caller
    mov ebx, ppTrampoline
    test ebx, ebx
    jz @SkipStore
    mov [ebx], eax

@SkipStore:
    ; Build the trampoline
    push pTrampoline
    push dwBytesToSteal
    push pTargetFunc
    call BuildTrampoline
    test eax, eax
    jz @Failed
    
    ; Change target function memory protection
    lea eax, dwOldProtect
    push eax
    push PAGE_EXECUTE_READWRITE
    push dwBytesToSteal
    push pTargetFunc
    call VirtualProtect
    test eax, eax
    jz @Failed
    
    ; Write JMP to hook function
    mov edi, pTargetFunc
    mov BYTE PTR [edi], 0E9h
    mov eax, pHookFunc
    sub eax, edi
    sub eax, 5
    mov [edi+1], eax
    
    ; NOP out remaining stolen bytes if any
    mov ecx, dwBytesToSteal
    sub ecx, 5
    jle @NoNops
    lea edi, [edi+5]
    mov al, 090h                  ; NOP
    rep stosb

@NoNops:
    ; Restore memory protection
    lea eax, dwOldProtect
    push eax
    push dwOldProtect
    push dwBytesToSteal
    push pTargetFunc
    call VirtualProtect
    
    ; Flush instruction cache
    push dwBytesToSteal
    push pTargetFunc
    push -1
    call FlushInstructionCache
    
    popad
    mov eax, 1
    ret

@Failed:
    popad
    xor eax, eax
    ret
InstallTrampolineHook ENDP

;-------------------------------------------------------------------------------
; ExecuteTrampoline
;-------------------------------------------------------------------------------
; Description: Macro/helper to call the original function via trampoline
; Note: This is typically done inline in the hook handler
;-------------------------------------------------------------------------------
ExecuteTrampoline PROC EXPORT pTrampoline:DWORD
    ; This is a helper - in practice, the hook handler would
    ; call the trampoline directly using: call [pTrampoline]
    mov eax, pTrampoline
    call eax
    ret
ExecuteTrampoline ENDP

END
