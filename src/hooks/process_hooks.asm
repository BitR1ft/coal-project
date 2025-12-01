;===============================================================================
; STEALTH INTERCEPTOR - Process Hooks
;===============================================================================
; File:        process_hooks.asm
; Description: Hook implementations for process-related APIs
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
MAX_PROCESS_NAME EQU 260

;===============================================================================
; Process Event Log Structure
;===============================================================================
PROCESS_EVENT_LOG STRUCT
    szProcessName     BYTE MAX_PROCESS_NAME DUP(?)
    dwProcessId       DWORD ?
    dwParentProcessId DWORD ?
    dwEventType       DWORD ?     ; 1=Create, 2=Terminate, 3=Open
    dwTimestamp       DWORD ?
    dwFlags           DWORD ?
PROCESS_EVENT_LOG ENDS

;===============================================================================
; Data Section
;===============================================================================
.data
    ; Kernel32 is already loaded
    szKernel32           BYTE "kernel32.dll", 0
    
    ; Function names
    szCreateProcessA     BYTE "CreateProcessA", 0
    szCreateProcessW     BYTE "CreateProcessW", 0
    szTerminateProcess   BYTE "TerminateProcess", 0
    szOpenProcess        BYTE "OpenProcess", 0
    szExitProcess        BYTE "ExitProcess", 0
    szGetCurrentProcess  BYTE "GetCurrentProcessId", 0
    
    ; Log messages
    szCreateProcLog      BYTE "[ProcHook] CreateProcess: ", 0
    szTermProcLog        BYTE "[ProcHook] TerminateProcess - PID: ", 0
    szOpenProcLog        BYTE "[ProcHook] OpenProcess - PID: ", 0
    szExitProcLog        BYTE "[ProcHook] ExitProcess called with code: ", 0
    szHookInstalled      BYTE "[ProcHook] Process hooks installed", 0
    szHookRemoved        BYTE "[ProcHook] Process hooks removed", 0
    szCmdLine            BYTE " CmdLine: ", 0
    
    ; Hook state
    g_hKernel32          DWORD 0
    g_pOrigCreateProcA   DWORD 0
    g_pOrigCreateProcW   DWORD 0
    g_pOrigTermProc      DWORD 0
    g_pOrigOpenProc      DWORD 0
    
    ; Trampolines
    g_pTrampolineCreateA DWORD 0
    g_pTrampolineCreateW DWORD 0
    g_pTrampolineTerm    DWORD 0
    g_pTrampolineOpen    DWORD 0
    
    g_bProcHooksEnabled  DWORD 0
    
    ; Statistics
    g_dwCreateProcCount  DWORD 0
    g_dwTermProcCount    DWORD 0
    g_dwOpenProcCount    DWORD 0
    g_dwBlockedCount     DWORD 0

.data?
    g_dwOldProtect       DWORD ?
    g_LogBuffer          BYTE 1024 DUP(?)
    g_ProcessLog         PROCESS_EVENT_LOG 50 DUP(?)
    g_dwLogIndex         DWORD ?

;===============================================================================
; Code Section
;===============================================================================
.code

;-------------------------------------------------------------------------------
; DwordToDecStr - Helper to convert DWORD to decimal string
;-------------------------------------------------------------------------------
DwordToDecStr PROC
    push ebx
    push ecx
    push edx
    push esi
    
    mov esi, edi
    xor ecx, ecx
    mov ebx, 10
    
    test eax, eax
    jnz @Loop
    mov BYTE PTR [edi], '0'
    inc edi
    jmp @Done
    
@Loop:
    test eax, eax
    jz @Reverse
    xor edx, edx
    div ebx
    add dl, '0'
    push edx
    inc ecx
    jmp @Loop
    
@Reverse:
    test ecx, ecx
    jz @Done
    pop edx
    mov [edi], dl
    inc edi
    dec ecx
    jmp @Reverse

@Done:
    pop esi
    pop edx
    pop ecx
    pop ebx
    ret
DwordToDecStr ENDP

;-------------------------------------------------------------------------------
; CreateProcessAHookHandler
;-------------------------------------------------------------------------------
; Description: Hook handler for CreateProcessA
; Parameters:  Same as CreateProcessA (10 parameters)
;-------------------------------------------------------------------------------
CreateProcessAHookHandler PROC
    push ebp
    mov ebp, esp
    
    pushad
    pushfd
    
    ; Increment counter
    inc g_dwCreateProcCount
    
    ; Build log message
    lea edi, g_LogBuffer
    
    ; Copy prefix
    lea esi, szCreateProcLog
@CopyPrefix:
    lodsb
    test al, al
    jz @PrefixDone
    stosb
    jmp @CopyPrefix
@PrefixDone:
    
    ; Copy application name if present
    mov esi, [ebp+8]            ; lpApplicationName
    test esi, esi
    jz @NoAppName
    mov ecx, 200
@CopyAppName:
    lodsb
    test al, al
    jz @AppNameDone
    stosb
    loop @CopyAppName
@AppNameDone:
    jmp @AddCmdLine
@NoAppName:
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

@AddCmdLine:
    ; Add command line label
    lea esi, szCmdLine
@CopyCmdLabel:
    lodsb
    test al, al
    jz @CmdLabelDone
    stosb
    jmp @CopyCmdLabel
@CmdLabelDone:
    
    ; Copy command line if present
    mov esi, [ebp+12]           ; lpCommandLine
    test esi, esi
    jz @NoCmdLine
    mov ecx, 300
@CopyCmdLine:
    lodsb
    test al, al
    jz @CmdLineDone
    stosb
    loop @CopyCmdLine
@CmdLineDone:
    jmp @EndLog
@NoCmdLine:
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
    
    ; Output log
    lea eax, g_LogBuffer
    push eax
    call OutputDebugStringA
    
    popfd
    popad
    
    ; Call original function
    ; 10 parameters for CreateProcessA
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
    
    call g_pTrampolineCreateA
    
    mov esp, ebp
    pop ebp
    ret 40
CreateProcessAHookHandler ENDP

;-------------------------------------------------------------------------------
; TerminateProcessHookHandler
;-------------------------------------------------------------------------------
; Description: Hook handler for TerminateProcess
; Parameters:
;   [ebp+8]  = hProcess
;   [ebp+12] = uExitCode
; Returns:     BOOL
;-------------------------------------------------------------------------------
TerminateProcessHookHandler PROC
    push ebp
    mov ebp, esp
    
    pushad
    pushfd
    
    ; Increment counter
    inc g_dwTermProcCount
    
    ; Build log message
    lea edi, g_LogBuffer
    lea esi, szTermProcLog
@CopyPrefix:
    lodsb
    test al, al
    jz @PrefixDone
    stosb
    jmp @CopyPrefix
@PrefixDone:
    
    ; Get process ID from handle
    push [ebp+8]
    call GetProcessId
    call DwordToDecStr
    
    ; Add exit code
    mov al, ' '
    stosb
    mov al, 'E'
    stosb
    mov al, 'x'
    stosb
    mov al, 'i'
    stosb
    mov al, 't'
    stosb
    mov al, ':'
    stosb
    mov al, ' '
    stosb
    
    mov eax, [ebp+12]
    call DwordToDecStr
    
    xor al, al
    stosb
    
    lea eax, g_LogBuffer
    push eax
    call OutputDebugStringA
    
    popfd
    popad
    
    ; Call original
    push [ebp+12]
    push [ebp+8]
    call g_pTrampolineTerm
    
    mov esp, ebp
    pop ebp
    ret 8
TerminateProcessHookHandler ENDP

;-------------------------------------------------------------------------------
; OpenProcessHookHandler
;-------------------------------------------------------------------------------
; Description: Hook handler for OpenProcess
; Parameters:
;   [ebp+8]  = dwDesiredAccess
;   [ebp+12] = bInheritHandle
;   [ebp+16] = dwProcessId
; Returns:     HANDLE
;-------------------------------------------------------------------------------
OpenProcessHookHandler PROC
    push ebp
    mov ebp, esp
    
    pushad
    pushfd
    
    ; Increment counter
    inc g_dwOpenProcCount
    
    ; Build log message
    lea edi, g_LogBuffer
    lea esi, szOpenProcLog
@CopyPrefix:
    lodsb
    test al, al
    jz @PrefixDone
    stosb
    jmp @CopyPrefix
@PrefixDone:
    
    ; Add process ID
    mov eax, [ebp+16]
    call DwordToDecStr
    
    ; Add access flags
    mov al, ' '
    stosb
    mov al, 'A'
    stosb
    mov al, 'c'
    stosb
    mov al, 'c'
    stosb
    mov al, 'e'
    stosb
    mov al, 's'
    stosb
    mov al, 's'
    stosb
    mov al, ':'
    stosb
    mov al, ' '
    stosb
    mov al, '0'
    stosb
    mov al, 'x'
    stosb
    
    ; Add access value in hex
    mov eax, [ebp+8]
    push edi
    add edi, 7
    mov ecx, 8
@HexLoop:
    mov ebx, eax
    and ebx, 0Fh
    cmp bl, 9
    jbe @Digit
    add bl, 'A' - 10
    jmp @Store
@Digit:
    add bl, '0'
@Store:
    mov [edi], bl
    dec edi
    shr eax, 4
    loop @HexLoop
    pop edi
    add edi, 8
    
    xor al, al
    stosb
    
    lea eax, g_LogBuffer
    push eax
    call OutputDebugStringA
    
    popfd
    popad
    
    ; Call original
    push [ebp+16]
    push [ebp+12]
    push [ebp+8]
    call g_pTrampolineOpen
    
    mov esp, ebp
    pop ebp
    ret 12
OpenProcessHookHandler ENDP

;-------------------------------------------------------------------------------
; InstallProcessHooks
;-------------------------------------------------------------------------------
; Description: Installs hooks on process-related functions
; Parameters:  None
; Returns:     EAX = 1 on success, 0 on failure
;-------------------------------------------------------------------------------
InstallProcessHooks PROC EXPORT
    LOCAL pFunc:DWORD
    
    pushad
    
    ; Check if already installed
    cmp g_bProcHooksEnabled, 1
    je @AlreadyInstalled
    
    ; Get kernel32 handle
    push OFFSET szKernel32
    call GetModuleHandleA
    test eax, eax
    jz @Failed
    mov g_hKernel32, eax
    
    ;---------------------------------------------------
    ; Hook CreateProcessA
    ;---------------------------------------------------
    push OFFSET szCreateProcessA
    push g_hKernel32
    call GetProcAddress
    test eax, eax
    jz @SkipCreateA
    mov g_pOrigCreateProcA, eax
    mov pFunc, eax
    
    push OFFSET g_dwOldProtect
    push PAGE_EXECUTE_READWRITE
    push 5
    push pFunc
    call VirtualProtect
    test eax, eax
    jz @SkipCreateA
    
    push PAGE_EXECUTE_READWRITE
    push MEM_COMMIT or MEM_RESERVE
    push 32
    push NULL
    call VirtualAlloc
    test eax, eax
    jz @SkipCreateA
    mov g_pTrampolineCreateA, eax
    
    mov edi, eax
    mov esi, pFunc
    movsb
    movsb
    movsb
    movsb
    movsb
    
    mov BYTE PTR [edi], 0E9h
    mov eax, pFunc
    add eax, 5
    sub eax, edi
    sub eax, 5
    mov [edi+1], eax
    
    mov edi, pFunc
    mov BYTE PTR [edi], 0E9h
    mov eax, OFFSET CreateProcessAHookHandler
    sub eax, edi
    sub eax, 5
    mov [edi+1], eax

@SkipCreateA:
    ;---------------------------------------------------
    ; Hook TerminateProcess
    ;---------------------------------------------------
    push OFFSET szTerminateProcess
    push g_hKernel32
    call GetProcAddress
    test eax, eax
    jz @SkipTerm
    mov g_pOrigTermProc, eax
    mov pFunc, eax
    
    push OFFSET g_dwOldProtect
    push PAGE_EXECUTE_READWRITE
    push 5
    push pFunc
    call VirtualProtect
    test eax, eax
    jz @SkipTerm
    
    push PAGE_EXECUTE_READWRITE
    push MEM_COMMIT or MEM_RESERVE
    push 32
    push NULL
    call VirtualAlloc
    test eax, eax
    jz @SkipTerm
    mov g_pTrampolineTerm, eax
    
    mov edi, eax
    mov esi, pFunc
    movsb
    movsb
    movsb
    movsb
    movsb
    
    mov BYTE PTR [edi], 0E9h
    mov eax, pFunc
    add eax, 5
    sub eax, edi
    sub eax, 5
    mov [edi+1], eax
    
    mov edi, pFunc
    mov BYTE PTR [edi], 0E9h
    mov eax, OFFSET TerminateProcessHookHandler
    sub eax, edi
    sub eax, 5
    mov [edi+1], eax

@SkipTerm:
    ;---------------------------------------------------
    ; Hook OpenProcess
    ;---------------------------------------------------
    push OFFSET szOpenProcess
    push g_hKernel32
    call GetProcAddress
    test eax, eax
    jz @SkipOpen
    mov g_pOrigOpenProc, eax
    mov pFunc, eax
    
    push OFFSET g_dwOldProtect
    push PAGE_EXECUTE_READWRITE
    push 5
    push pFunc
    call VirtualProtect
    test eax, eax
    jz @SkipOpen
    
    push PAGE_EXECUTE_READWRITE
    push MEM_COMMIT or MEM_RESERVE
    push 32
    push NULL
    call VirtualAlloc
    test eax, eax
    jz @SkipOpen
    mov g_pTrampolineOpen, eax
    
    mov edi, eax
    mov esi, pFunc
    movsb
    movsb
    movsb
    movsb
    movsb
    
    mov BYTE PTR [edi], 0E9h
    mov eax, pFunc
    add eax, 5
    sub eax, edi
    sub eax, 5
    mov [edi+1], eax
    
    mov edi, pFunc
    mov BYTE PTR [edi], 0E9h
    mov eax, OFFSET OpenProcessHookHandler
    sub eax, edi
    sub eax, 5
    mov [edi+1], eax

@SkipOpen:
    ; Flush instruction cache
    push 0
    push 0
    push -1
    call FlushInstructionCache
    
    ; Mark as enabled
    mov g_bProcHooksEnabled, 1
    
    ; Log success
    push OFFSET szHookInstalled
    call OutputDebugStringA
    
@AlreadyInstalled:
    popad
    mov eax, 1
    ret

@Failed:
    popad
    xor eax, eax
    ret
InstallProcessHooks ENDP

;-------------------------------------------------------------------------------
; RemoveProcessHooks
;-------------------------------------------------------------------------------
; Description: Removes all process hooks
; Parameters:  None
; Returns:     EAX = 1 on success
;-------------------------------------------------------------------------------
RemoveProcessHooks PROC EXPORT
    pushad
    
    cmp g_bProcHooksEnabled, 0
    je @NotInstalled
    
    ; Restore CreateProcessA
    cmp g_pTrampolineCreateA, 0
    je @Skip1
    push OFFSET g_dwOldProtect
    push PAGE_EXECUTE_READWRITE
    push 5
    push g_pOrigCreateProcA
    call VirtualProtect
    mov edi, g_pOrigCreateProcA
    mov esi, g_pTrampolineCreateA
    movsb
    movsb
    movsb
    movsb
    movsb
    push MEM_RELEASE
    push 0
    push g_pTrampolineCreateA
    call VirtualFree
    mov g_pTrampolineCreateA, 0
@Skip1:
    
    ; Restore TerminateProcess
    cmp g_pTrampolineTerm, 0
    je @Skip2
    push OFFSET g_dwOldProtect
    push PAGE_EXECUTE_READWRITE
    push 5
    push g_pOrigTermProc
    call VirtualProtect
    mov edi, g_pOrigTermProc
    mov esi, g_pTrampolineTerm
    movsb
    movsb
    movsb
    movsb
    movsb
    push MEM_RELEASE
    push 0
    push g_pTrampolineTerm
    call VirtualFree
    mov g_pTrampolineTerm, 0
@Skip2:
    
    ; Restore OpenProcess
    cmp g_pTrampolineOpen, 0
    je @Skip3
    push OFFSET g_dwOldProtect
    push PAGE_EXECUTE_READWRITE
    push 5
    push g_pOrigOpenProc
    call VirtualProtect
    mov edi, g_pOrigOpenProc
    mov esi, g_pTrampolineOpen
    movsb
    movsb
    movsb
    movsb
    movsb
    push MEM_RELEASE
    push 0
    push g_pTrampolineOpen
    call VirtualFree
    mov g_pTrampolineOpen, 0
@Skip3:
    
    ; Flush instruction cache
    push 0
    push 0
    push -1
    call FlushInstructionCache
    
    mov g_bProcHooksEnabled, 0
    
    push OFFSET szHookRemoved
    call OutputDebugStringA

@NotInstalled:
    popad
    mov eax, 1
    ret
RemoveProcessHooks ENDP

;-------------------------------------------------------------------------------
; GetProcessHookStats
;-------------------------------------------------------------------------------
; Description: Gets process hook statistics
; Parameters:
;   [ebp+8]  = pCreateCount
;   [ebp+12] = pTermCount
;   [ebp+16] = pOpenCount
;   [ebp+20] = pBlockedCount
; Returns:     EAX = 1 if hooks enabled
;-------------------------------------------------------------------------------
GetProcessHookStats PROC EXPORT pCreateCount:DWORD, pTermCount:DWORD, pOpenCount:DWORD, pBlockedCount:DWORD
    mov eax, pCreateCount
    test eax, eax
    jz @Skip1
    mov ecx, g_dwCreateProcCount
    mov [eax], ecx
@Skip1:
    mov eax, pTermCount
    test eax, eax
    jz @Skip2
    mov ecx, g_dwTermProcCount
    mov [eax], ecx
@Skip2:
    mov eax, pOpenCount
    test eax, eax
    jz @Skip3
    mov ecx, g_dwOpenProcCount
    mov [eax], ecx
@Skip3:
    mov eax, pBlockedCount
    test eax, eax
    jz @Skip4
    mov ecx, g_dwBlockedCount
    mov [eax], ecx
@Skip4:
    mov eax, g_bProcHooksEnabled
    ret
GetProcessHookStats ENDP

END
