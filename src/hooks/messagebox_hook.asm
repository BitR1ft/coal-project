;===============================================================================
; STEALTH INTERCEPTOR - MessageBox Hook
;===============================================================================
; File:        messagebox_hook.asm
; Description: Hook implementation for MessageBox API
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
include \masm32\include\user32.inc
includelib \masm32\lib\kernel32.lib
includelib \masm32\lib\user32.lib

;===============================================================================
; External References
;===============================================================================
EXTERN InstallHook:PROC
EXTERN RemoveHook:PROC
EXTERN GetTrampoline:PROC

;===============================================================================
; Constants
;===============================================================================
MAX_LOG_SIZE EQU 1024

;===============================================================================
; Data Section
;===============================================================================
.data
    ; DLL and function names
    szUser32             BYTE "user32.dll", 0
    szMessageBoxA        BYTE "MessageBoxA", 0
    szMessageBoxW        BYTE "MessageBoxW", 0
    
    ; Log messages
    szInterceptedA       BYTE "[Hook] MessageBoxA intercepted!", 0
    szInterceptedW       BYTE "[Hook] MessageBoxW intercepted!", 0
    szHookInstalled      BYTE "[Hook] MessageBox hook installed successfully", 0
    szHookRemoved        BYTE "[Hook] MessageBox hook removed", 0
    szHookFailed         BYTE "[Hook] Failed to install MessageBox hook", 0
    szNewLine            BYTE 13, 10, 0
    
    ; Intercept log prefix
    szLogPrefix          BYTE "[INTERCEPTED] Title: ", 0
    szLogMessage         BYTE " | Message: ", 0
    
    ; Hook state
    g_hUser32            DWORD 0
    g_pOriginalMsgBoxA   DWORD 0
    g_pOriginalMsgBoxW   DWORD 0
    g_pTrampolineA       DWORD 0
    g_pTrampolineW       DWORD 0
    g_dwHookIdA          DWORD -1
    g_dwHookIdW          DWORD -1
    g_bHookEnabled       DWORD 0
    
    ; Statistics
    g_dwInterceptCount   DWORD 0
    g_dwBlockedCount     DWORD 0
    
    ; Custom message to prepend (for demo)
    szCustomPrefix       BYTE "[INTERCEPTED] ", 0
    szModifiedTitle      BYTE 256 DUP(0)

.data?
    g_dwOldProtect       DWORD ?
    g_LogBuffer          BYTE MAX_LOG_SIZE DUP(?)

;===============================================================================
; Code Section
;===============================================================================
.code

;-------------------------------------------------------------------------------
; MessageBoxAHookHandler
;-------------------------------------------------------------------------------
; Description: Hook handler for MessageBoxA
; Parameters:  Same as MessageBoxA
;   [ebp+8]  = hWnd - Owner window handle
;   [ebp+12] = lpText - Message text
;   [ebp+16] = lpCaption - Title text
;   [ebp+20] = uType - MessageBox type flags
; Returns:     Same as MessageBoxA
;-------------------------------------------------------------------------------
MessageBoxAHookHandler PROC
    ; Standard function prologue
    push ebp
    mov ebp, esp
    
    ; Save all registers
    pushad
    pushfd
    
    ; Log the interception
    push OFFSET szInterceptedA
    call OutputDebugStringA
    
    ; Increment intercept counter
    inc g_dwInterceptCount
    
    ; Log the message details
    ; Build log string: "[INTERCEPTED] Title: <title> | Message: <message>"
    lea edi, g_LogBuffer
    
    ; Copy prefix
    lea esi, szLogPrefix
@CopyPrefix:
    lodsb
    test al, al
    jz @PrefixDone
    stosb
    jmp @CopyPrefix
@PrefixDone:
    
    ; Copy title if present
    mov esi, [ebp+16]           ; lpCaption
    test esi, esi
    jz @NoTitle
    mov ecx, 100                ; Max chars to copy
@CopyTitle:
    lodsb
    test al, al
    jz @TitleDone
    stosb
    loop @CopyTitle
@TitleDone:
    jmp @AddSeparator
@NoTitle:
    mov al, '('
    stosb
    mov al, 'n'
    stosb
    mov al, 'u'
    stosb
    mov al, 'l'
    stosb
    mov al, 'l'
    stosb
    mov al, ')'
    stosb
    
@AddSeparator:
    ; Add separator
    lea esi, szLogMessage
@CopySep:
    lodsb
    test al, al
    jz @SepDone
    stosb
    jmp @CopySep
@SepDone:
    
    ; Copy message if present
    mov esi, [ebp+12]           ; lpText
    test esi, esi
    jz @NoMessage
    mov ecx, 200                ; Max chars to copy
@CopyMessage:
    lodsb
    test al, al
    jz @MessageDone
    stosb
    loop @CopyMessage
@MessageDone:
    jmp @EndLog
@NoMessage:
    mov al, '('
    stosb
    mov al, 'n'
    stosb
    mov al, 'u'
    stosb
    mov al, 'l'
    stosb
    mov al, 'l'
    stosb
    mov al, ')'
    stosb

@EndLog:
    ; Null terminate
    xor al, al
    stosb
    
    ; Output the log
    lea eax, g_LogBuffer
    push eax
    call OutputDebugStringA
    
    ; Restore registers
    popfd
    popad
    
    ; Now call the original function via trampoline
    ; Get parameters from stack
    mov eax, [ebp+20]           ; uType
    push eax
    mov eax, [ebp+16]           ; lpCaption
    push eax
    mov eax, [ebp+12]           ; lpText
    push eax
    mov eax, [ebp+8]            ; hWnd
    push eax
    
    ; Call original via trampoline
    call g_pTrampolineA
    
    ; Epilogue
    mov esp, ebp
    pop ebp
    ret 16                      ; Clean up 4 parameters
MessageBoxAHookHandler ENDP

;-------------------------------------------------------------------------------
; MessageBoxWHookHandler
;-------------------------------------------------------------------------------
; Description: Hook handler for MessageBoxW (Unicode version)
; Parameters:  Same as MessageBoxW
; Returns:     Same as MessageBoxW
;-------------------------------------------------------------------------------
MessageBoxWHookHandler PROC
    push ebp
    mov ebp, esp
    
    pushad
    pushfd
    
    ; Log the interception
    push OFFSET szInterceptedW
    call OutputDebugStringA
    
    ; Increment counter
    inc g_dwInterceptCount
    
    popfd
    popad
    
    ; Call original via trampoline
    mov eax, [ebp+20]           ; uType
    push eax
    mov eax, [ebp+16]           ; lpCaption
    push eax
    mov eax, [ebp+12]           ; lpText
    push eax
    mov eax, [ebp+8]            ; hWnd
    push eax
    
    call g_pTrampolineW
    
    mov esp, ebp
    pop ebp
    ret 16
MessageBoxWHookHandler ENDP

;-------------------------------------------------------------------------------
; InstallMessageBoxHook
;-------------------------------------------------------------------------------
; Description: Installs hooks on MessageBoxA and MessageBoxW
; Parameters:  None
; Returns:     EAX = 1 on success, 0 on failure
;-------------------------------------------------------------------------------
InstallMessageBoxHook PROC EXPORT
    pushad
    
    ; Check if already installed
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
    
    ; Get MessageBoxW address
    push OFFSET szMessageBoxW
    push g_hUser32
    call GetProcAddress
    test eax, eax
    jz @GetProcFailed
    mov g_pOriginalMsgBoxW, eax
    
    ;---------------------------------------------------
    ; Install hook on MessageBoxA
    ;---------------------------------------------------
    ; Change memory protection
    push OFFSET g_dwOldProtect
    push PAGE_EXECUTE_READWRITE
    push 5
    push g_pOriginalMsgBoxA
    call VirtualProtect
    test eax, eax
    jz @ProtectFailed
    
    ; Allocate trampoline for MessageBoxA
    push PAGE_EXECUTE_READWRITE
    push MEM_COMMIT or MEM_RESERVE
    push 32
    push NULL
    call VirtualAlloc
    test eax, eax
    jz @AllocFailed
    mov g_pTrampolineA, eax
    
    ; Build trampoline for MessageBoxA
    ; Copy first 5 bytes of original function
    mov edi, g_pTrampolineA
    mov esi, g_pOriginalMsgBoxA
    movsb
    movsb
    movsb
    movsb
    movsb
    
    ; Add JMP back to original + 5
    mov BYTE PTR [edi], 0E9h
    mov eax, g_pOriginalMsgBoxA
    add eax, 5
    sub eax, edi
    sub eax, 5
    mov [edi+1], eax
    
    ; Write JMP to our hook at original function
    mov edi, g_pOriginalMsgBoxA
    mov BYTE PTR [edi], 0E9h
    mov eax, OFFSET MessageBoxAHookHandler
    sub eax, edi
    sub eax, 5
    mov [edi+1], eax
    
    ;---------------------------------------------------
    ; Install hook on MessageBoxW
    ;---------------------------------------------------
    ; Change memory protection
    push OFFSET g_dwOldProtect
    push PAGE_EXECUTE_READWRITE
    push 5
    push g_pOriginalMsgBoxW
    call VirtualProtect
    
    ; Allocate trampoline for MessageBoxW
    push PAGE_EXECUTE_READWRITE
    push MEM_COMMIT or MEM_RESERVE
    push 32
    push NULL
    call VirtualAlloc
    test eax, eax
    jz @AllocFailed
    mov g_pTrampolineW, eax
    
    ; Build trampoline for MessageBoxW
    mov edi, g_pTrampolineW
    mov esi, g_pOriginalMsgBoxW
    movsb
    movsb
    movsb
    movsb
    movsb
    
    ; Add JMP back
    mov BYTE PTR [edi], 0E9h
    mov eax, g_pOriginalMsgBoxW
    add eax, 5
    sub eax, edi
    sub eax, 5
    mov [edi+1], eax
    
    ; Write JMP to our hook
    mov edi, g_pOriginalMsgBoxW
    mov BYTE PTR [edi], 0E9h
    mov eax, OFFSET MessageBoxWHookHandler
    sub eax, edi
    sub eax, 5
    mov [edi+1], eax
    
    ; Flush instruction cache
    push 5
    push g_pOriginalMsgBoxA
    push -1
    call FlushInstructionCache
    
    push 5
    push g_pOriginalMsgBoxW
    push -1
    call FlushInstructionCache
    
    ; Mark as enabled
    mov g_bHookEnabled, 1
    
    ; Log success
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
    push OFFSET szHookFailed
    call OutputDebugStringA
    popad
    xor eax, eax
    ret
InstallMessageBoxHook ENDP

;-------------------------------------------------------------------------------
; RemoveMessageBoxHook
;-------------------------------------------------------------------------------
; Description: Removes the MessageBox hooks
; Parameters:  None
; Returns:     EAX = 1 on success, 0 on failure
;-------------------------------------------------------------------------------
RemoveMessageBoxHook PROC EXPORT
    pushad
    
    ; Check if hooks are installed
    cmp g_bHookEnabled, 0
    je @NotInstalled
    
    ;---------------------------------------------------
    ; Restore MessageBoxA
    ;---------------------------------------------------
    ; Change protection
    push OFFSET g_dwOldProtect
    push PAGE_EXECUTE_READWRITE
    push 5
    push g_pOriginalMsgBoxA
    call VirtualProtect
    
    ; Copy original bytes back from trampoline
    mov edi, g_pOriginalMsgBoxA
    mov esi, g_pTrampolineA
    movsb
    movsb
    movsb
    movsb
    movsb
    
    ; Free trampoline memory
    push MEM_RELEASE
    push 0
    push g_pTrampolineA
    call VirtualFree
    mov g_pTrampolineA, 0
    
    ;---------------------------------------------------
    ; Restore MessageBoxW
    ;---------------------------------------------------
    push OFFSET g_dwOldProtect
    push PAGE_EXECUTE_READWRITE
    push 5
    push g_pOriginalMsgBoxW
    call VirtualProtect
    
    mov edi, g_pOriginalMsgBoxW
    mov esi, g_pTrampolineW
    movsb
    movsb
    movsb
    movsb
    movsb
    
    push MEM_RELEASE
    push 0
    push g_pTrampolineW
    call VirtualFree
    mov g_pTrampolineW, 0
    
    ; Flush instruction cache
    push 5
    push g_pOriginalMsgBoxA
    push -1
    call FlushInstructionCache
    
    push 5
    push g_pOriginalMsgBoxW
    push -1
    call FlushInstructionCache
    
    ; Mark as disabled
    mov g_bHookEnabled, 0
    
    ; Log
    push OFFSET szHookRemoved
    call OutputDebugStringA
    
@NotInstalled:
    popad
    mov eax, 1
    ret
RemoveMessageBoxHook ENDP

;-------------------------------------------------------------------------------
; GetMessageBoxHookStats
;-------------------------------------------------------------------------------
; Description: Gets hook statistics
; Parameters:
;   [ebp+8]  = pInterceptCount - Pointer to receive intercept count
;   [ebp+12] = pBlockedCount - Pointer to receive blocked count
; Returns:     EAX = 1 if hooks are enabled, 0 otherwise
;-------------------------------------------------------------------------------
GetMessageBoxHookStats PROC EXPORT pInterceptCount:DWORD, pBlockedCount:DWORD
    mov eax, pInterceptCount
    test eax, eax
    jz @SkipIntercept
    mov ecx, g_dwInterceptCount
    mov [eax], ecx
@SkipIntercept:
    
    mov eax, pBlockedCount
    test eax, eax
    jz @SkipBlocked
    mov ecx, g_dwBlockedCount
    mov [eax], ecx
@SkipBlocked:
    
    mov eax, g_bHookEnabled
    ret
GetMessageBoxHookStats ENDP

;-------------------------------------------------------------------------------
; IsMessageBoxHookActive
;-------------------------------------------------------------------------------
; Description: Checks if MessageBox hook is active
; Parameters:  None
; Returns:     EAX = 1 if active, 0 otherwise
;-------------------------------------------------------------------------------
IsMessageBoxHookActive PROC EXPORT
    mov eax, g_bHookEnabled
    ret
IsMessageBoxHookActive ENDP

END
