;===============================================================================
; MINI STEALTH INTERCEPTOR - MessageBox Hook (NASM)
;===============================================================================
; File:        messagebox_hook_nasm.asm
; Description: Simplified hook for MessageBox API (NASM syntax)
; Authors:     Muhammad Adeel Haider (241541), Umar Farooq (241575)
; Course:      COAL - 5th Semester, BS Cyber Security
;===============================================================================

bits 32

; Windows API constants
NULL                    equ 0
PAGE_EXECUTE_READWRITE  equ 0x40
MEM_COMMIT              equ 0x1000
MEM_RESERVE             equ 0x2000
MEM_RELEASE             equ 0x8000

section .data
    szUser32             db "user32.dll", 0
    szMessageBoxA        db "MessageBoxA", 0
    
    szInterceptedA       db "[Mini Hook] MessageBoxA intercepted!", 0
    szHookInstalled      db "[Mini Hook] MessageBox hook installed", 0
    szHookRemoved        db "[Mini Hook] MessageBox hook removed", 0
    
    g_hUser32            dd 0
    g_pOriginalMsgBoxA   dd 0
    g_pTrampolineA       dd 0
    g_bHookEnabled       dd 0
    g_dwInterceptCount   dd 0
    g_dwOldProtect       dd 0

section .text
global _InstallMessageBoxHook@0
global _RemoveMessageBoxHook@0
global _GetMessageBoxHookStats@4

extern _LoadLibraryA@4
extern _GetProcAddress@8
extern _VirtualProtect@16
extern _VirtualAlloc@16
extern _VirtualFree@12
extern _FlushInstructionCache@12
extern _OutputDebugStringA@4

;-------------------------------------------------------------------------------
; MessageBoxAHookHandler - Hook handler for MessageBoxA
;-------------------------------------------------------------------------------
MessageBoxAHookHandler:
    push ebp
    mov ebp, esp
    
    pushad
    pushfd
    
    ; Log interception
    push szInterceptedA
    call _OutputDebugStringA@4
    
    ; Increment counter
    inc dword [g_dwInterceptCount]
    
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
    
    call [g_pTrampolineA]
    
    mov esp, ebp
    pop ebp
    ret 16

;-------------------------------------------------------------------------------
; InstallMessageBoxHook - Install hook on MessageBoxA
;-------------------------------------------------------------------------------
_InstallMessageBoxHook@0:
    pushad
    
    cmp dword [g_bHookEnabled], 1
    je .AlreadyInstalled
    
    ; Load user32.dll
    push szUser32
    call _LoadLibraryA@4
    test eax, eax
    jz .LoadFailed
    mov [g_hUser32], eax
    
    ; Get MessageBoxA address
    push szMessageBoxA
    push eax
    call _GetProcAddress@8
    test eax, eax
    jz .GetProcFailed
    mov [g_pOriginalMsgBoxA], eax
    
    ; Change memory protection
    push g_dwOldProtect
    push PAGE_EXECUTE_READWRITE
    push 5
    push dword [g_pOriginalMsgBoxA]
    call _VirtualProtect@16
    test eax, eax
    jz .ProtectFailed
    
    ; Allocate trampoline
    push PAGE_EXECUTE_READWRITE
    push MEM_COMMIT | MEM_RESERVE
    push 32
    push NULL
    call _VirtualAlloc@16
    test eax, eax
    jz .AllocFailed
    mov [g_pTrampolineA], eax
    
    ; Build trampoline - Copy first 5 bytes
    mov edi, [g_pTrampolineA]
    mov esi, [g_pOriginalMsgBoxA]
    mov ecx, 5
    rep movsb
    
    ; Add JMP back to original + 5
    mov byte [edi], 0xE9        ; JMP opcode
    mov eax, [g_pOriginalMsgBoxA]
    add eax, 5
    sub eax, edi
    sub eax, 5
    mov [edi+1], eax
    
    ; Write JMP to our hook at the original function
    mov edi, [g_pOriginalMsgBoxA]
    mov byte [edi], 0xE9        ; JMP opcode
    mov eax, MessageBoxAHookHandler
    sub eax, edi
    sub eax, 5
    mov [edi+1], eax
    
    ; Flush cache
    push 5
    push dword [g_pOriginalMsgBoxA]
    push -1
    call _FlushInstructionCache@12
    
    mov dword [g_bHookEnabled], 1
    
    push szHookInstalled
    call _OutputDebugStringA@4
    
    popad
    mov eax, 1
    ret

.AlreadyInstalled:
    popad
    mov eax, 1
    ret

.LoadFailed:
.GetProcFailed:
.ProtectFailed:
.AllocFailed:
    popad
    xor eax, eax
    ret

;-------------------------------------------------------------------------------
; RemoveMessageBoxHook - Remove the MessageBox hook
;-------------------------------------------------------------------------------
_RemoveMessageBoxHook@0:
    pushad
    
    cmp dword [g_bHookEnabled], 0
    je .NotInstalled
    
    ; Change protection
    push g_dwOldProtect
    push PAGE_EXECUTE_READWRITE
    push 5
    push dword [g_pOriginalMsgBoxA]
    call _VirtualProtect@16
    
    ; Restore original bytes from trampoline
    mov edi, [g_pOriginalMsgBoxA]
    mov esi, [g_pTrampolineA]
    mov ecx, 5
    rep movsb
    
    ; Free trampoline
    push MEM_RELEASE
    push 0
    push dword [g_pTrampolineA]
    call _VirtualFree@12
    mov dword [g_pTrampolineA], 0
    
    ; Flush cache
    push 5
    push dword [g_pOriginalMsgBoxA]
    push -1
    call _FlushInstructionCache@12
    
    mov dword [g_bHookEnabled], 0
    
    push szHookRemoved
    call _OutputDebugStringA@4
    
.NotInstalled:
    popad
    mov eax, 1
    ret

;-------------------------------------------------------------------------------
; GetMessageBoxHookStats - Get hook statistics
;-------------------------------------------------------------------------------
_GetMessageBoxHookStats@4:
    push ebp
    mov ebp, esp
    
    mov eax, [ebp+8]        ; pInterceptCount parameter
    test eax, eax
    jz .SkipIntercept
    mov ecx, [g_dwInterceptCount]
    mov [eax], ecx
    
.SkipIntercept:
    mov eax, [g_bHookEnabled]
    
    pop ebp
    ret 4
