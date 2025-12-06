;===============================================================================
; MINI STEALTH INTERCEPTOR - MessageBox Hook (Simplified)
;===============================================================================
; File:        messagebox_hook.asm
; Description: Simplified hook for MessageBox API
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
; Data Section
;===============================================================================
.data
    szUser32             BYTE "user32.dll", 0
    szMessageBoxA        BYTE "MessageBoxA", 0
    
    szInterceptedA       BYTE "[Mini Hook] MessageBoxA intercepted!", 0
    szHookInstalled      BYTE "[Mini Hook] MessageBox hook installed", 0
    szHookRemoved        BYTE "[Mini Hook] MessageBox hook removed", 0
    
    g_hUser32            DWORD 0
    g_pOriginalMsgBoxA   DWORD 0
    g_pTrampolineA       DWORD 0
    g_bHookEnabled       DWORD 0
    g_dwInterceptCount   DWORD 0

.data?
    g_dwOldProtect       DWORD ?

;===============================================================================
; Code Section
;===============================================================================
.code

;-------------------------------------------------------------------------------
; MessageBoxAHookHandler - Hook handler for MessageBoxA
;-------------------------------------------------------------------------------
MessageBoxAHookHandler PROC
    push ebp
    mov ebp, esp
    
    pushad
    pushfd
    
    ; Log interception
    push OFFSET szInterceptedA
    call OutputDebugStringA
    
    ; Increment counter
    inc g_dwInterceptCount
    
    popfd
    popad
    
    ; Call original via trampoline
    mov eax, [ebp+20]
    push eax
    mov eax, [ebp+16]
    push eax
    mov eax, [ebp+12]
    push eax
    mov eax, [ebp+8]
    push eax
    
    call g_pTrampolineA
    
    mov esp, ebp
    pop ebp
    ret 16
MessageBoxAHookHandler ENDP

;-------------------------------------------------------------------------------
; InstallMessageBoxHook - Install hook on MessageBoxA
;-------------------------------------------------------------------------------
InstallMessageBoxHook PROC EXPORT
    pushad
    
    cmp g_bHookEnabled, 1
    je @AlreadyInstalled
    
    ; Load user32.dll
    push OFFSET szUser32
    call LoadLibraryA
    test eax, eax
    jz @LoadFailed
    mov g_hUser32, eax
    
    ; Get MessageBoxA address
    push OFFSET szMessageBoxA
    push eax
    call GetProcAddress
    test eax, eax
    jz @GetProcFailed
    mov g_pOriginalMsgBoxA, eax
    
    ; Change memory protection
    push OFFSET g_dwOldProtect
    push PAGE_EXECUTE_READWRITE
    push 5
    push g_pOriginalMsgBoxA
    call VirtualProtect
    test eax, eax
    jz @ProtectFailed
    
    ; Allocate trampoline
    push PAGE_EXECUTE_READWRITE
    push MEM_COMMIT or MEM_RESERVE
    push 32
    push NULL
    call VirtualAlloc
    test eax, eax
    jz @AllocFailed
    mov g_pTrampolineA, eax
    
    ; Build trampoline - Copy first 5 bytes
    mov edi, g_pTrampolineA
    mov esi, g_pOriginalMsgBoxA
    mov ecx, 5
    rep movsb
    
    ; Add JMP back to original + 5
    mov BYTE PTR [edi], 0E9h
    mov eax, g_pOriginalMsgBoxA
    add eax, 5
    sub eax, edi
    sub eax, 5
    mov [edi+1], eax
    
    ; Write JMP to our hook
    mov edi, g_pOriginalMsgBoxA
    mov BYTE PTR [edi], 0E9h
    mov eax, OFFSET MessageBoxAHookHandler
    sub eax, edi
    sub eax, 5
    mov [edi+1], eax
    
    ; Flush cache
    push 5
    push g_pOriginalMsgBoxA
    push -1
    call FlushInstructionCache
    
    mov g_bHookEnabled, 1
    
    push OFFSET szHookInstalled
    call OutputDebugStringA
    
    popad
    mov eax, 1
    ret

@AlreadyInstalled:
    popad
    mov eax, 1
    ret

@LoadFailed:
@GetProcFailed:
@ProtectFailed:
@AllocFailed:
    popad
    xor eax, eax
    ret
InstallMessageBoxHook ENDP

;-------------------------------------------------------------------------------
; RemoveMessageBoxHook - Remove the MessageBox hook
;-------------------------------------------------------------------------------
RemoveMessageBoxHook PROC EXPORT
    pushad
    
    cmp g_bHookEnabled, 0
    je @NotInstalled
    
    ; Change protection
    push OFFSET g_dwOldProtect
    push PAGE_EXECUTE_READWRITE
    push 5
    push g_pOriginalMsgBoxA
    call VirtualProtect
    
    ; Restore original bytes from trampoline
    mov edi, g_pOriginalMsgBoxA
    mov esi, g_pTrampolineA
    mov ecx, 5
    rep movsb
    
    ; Free trampoline
    push MEM_RELEASE
    push 0
    push g_pTrampolineA
    call VirtualFree
    mov g_pTrampolineA, 0
    
    ; Flush cache
    push 5
    push g_pOriginalMsgBoxA
    push -1
    call FlushInstructionCache
    
    mov g_bHookEnabled, 0
    
    push OFFSET szHookRemoved
    call OutputDebugStringA
    
@NotInstalled:
    popad
    mov eax, 1
    ret
RemoveMessageBoxHook ENDP

;-------------------------------------------------------------------------------
; GetMessageBoxHookStats - Get hook statistics
;-------------------------------------------------------------------------------
GetMessageBoxHookStats PROC EXPORT pInterceptCount:DWORD
    mov eax, pInterceptCount
    test eax, eax
    jz @SkipIntercept
    mov ecx, g_dwInterceptCount
    mov [eax], ecx
@SkipIntercept:
    
    mov eax, g_bHookEnabled
    ret
GetMessageBoxHookStats ENDP

END
