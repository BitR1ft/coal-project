;===============================================================================
; STEALTH INTERCEPTOR - File Operation Hooks
;===============================================================================
; File:        file_hooks.asm
; Description: Hook implementations for file I/O APIs
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
MAX_PATH_LOG EQU 260
MAX_LOG_ENTRIES EQU 100

;===============================================================================
; File Access Log Entry Structure
;===============================================================================
FILE_ACCESS_LOG STRUCT
    szFilePath    BYTE MAX_PATH_LOG DUP(?)
    dwAccessMode  DWORD ?
    dwShareMode   DWORD ?
    dwCreateDisp  DWORD ?
    dwTimestamp   DWORD ?
    dwResult      DWORD ?
FILE_ACCESS_LOG ENDS

;===============================================================================
; Data Section
;===============================================================================
.data
    ; Kernel32 already loaded, just need function names
    szKernel32           BYTE "kernel32.dll", 0
    szCreateFileA        BYTE "CreateFileA", 0
    szCreateFileW        BYTE "CreateFileW", 0
    szReadFile           BYTE "ReadFile", 0
    szWriteFile          BYTE "WriteFile", 0
    szDeleteFileA        BYTE "DeleteFileA", 0
    szDeleteFileW        BYTE "DeleteFileW", 0
    szCopyFileA          BYTE "CopyFileA", 0
    szCopyFileW          BYTE "CopyFileW", 0
    
    ; Log messages
    szCreateFileLog      BYTE "[FileHook] CreateFile: ", 0
    szReadFileLog        BYTE "[FileHook] ReadFile called", 0
    szWriteFileLog       BYTE "[FileHook] WriteFile called", 0
    szDeleteFileLog      BYTE "[FileHook] DeleteFile: ", 0
    szCopyFileLog        BYTE "[FileHook] CopyFile: ", 0
    szAccessModeRead     BYTE " (READ)", 0
    szAccessModeWrite    BYTE " (WRITE)", 0
    szAccessModeRW       BYTE " (READ/WRITE)", 0
    szHookInstalled      BYTE "[FileHook] File hooks installed", 0
    szHookRemoved        BYTE "[FileHook] File hooks removed", 0
    
    ; Hook state
    g_hKernel32          DWORD 0
    g_pOrigCreateFileA   DWORD 0
    g_pOrigCreateFileW   DWORD 0
    g_pOrigReadFile      DWORD 0
    g_pOrigWriteFile     DWORD 0
    g_pOrigDeleteFileA   DWORD 0
    
    ; Trampolines
    g_pTrampolineCreateA DWORD 0
    g_pTrampolineCreateW DWORD 0
    g_pTrampolineRead    DWORD 0
    g_pTrampolineWrite   DWORD 0
    g_pTrampolineDeleteA DWORD 0
    
    g_bFileHooksEnabled  DWORD 0
    
    ; Statistics
    g_dwCreateFileCount  DWORD 0
    g_dwReadFileCount    DWORD 0
    g_dwWriteFileCount   DWORD 0
    g_dwDeleteFileCount  DWORD 0

.data?
    g_dwOldProtect       DWORD ?
    g_LogBuffer          BYTE 512 DUP(?)
    g_FileAccessLog      FILE_ACCESS_LOG MAX_LOG_ENTRIES DUP(?)
    g_dwLogIndex         DWORD ?

;===============================================================================
; Code Section
;===============================================================================
.code

;-------------------------------------------------------------------------------
; CreateFileAHookHandler
;-------------------------------------------------------------------------------
; Description: Hook handler for CreateFileA
; Parameters:  Same as CreateFileA
;   [ebp+8]  = lpFileName
;   [ebp+12] = dwDesiredAccess
;   [ebp+16] = dwShareMode
;   [ebp+20] = lpSecurityAttributes
;   [ebp+24] = dwCreationDisposition
;   [ebp+28] = dwFlagsAndAttributes
;   [ebp+32] = hTemplateFile
; Returns:     HANDLE
;-------------------------------------------------------------------------------
CreateFileAHookHandler PROC
    push ebp
    mov ebp, esp
    
    pushad
    pushfd
    
    ; Increment counter
    inc g_dwCreateFileCount
    
    ; Build log message
    lea edi, g_LogBuffer
    
    ; Copy prefix
    lea esi, szCreateFileLog
@CopyPrefix:
    lodsb
    test al, al
    jz @PrefixDone
    stosb
    jmp @CopyPrefix
@PrefixDone:
    
    ; Copy filename
    mov esi, [ebp+8]            ; lpFileName
    test esi, esi
    jz @NoFileName
    mov ecx, 200
@CopyFileName:
    lodsb
    test al, al
    jz @FileNameDone
    stosb
    loop @CopyFileName
@FileNameDone:
    jmp @AddAccessMode
@NoFileName:
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

@AddAccessMode:
    ; Add access mode description
    mov eax, [ebp+12]           ; dwDesiredAccess
    test eax, GENERIC_WRITE
    jz @CheckRead
    test eax, GENERIC_READ
    jz @WriteOnly
    ; Read/Write
    lea esi, szAccessModeRW
    jmp @CopyAccessMode
@WriteOnly:
    lea esi, szAccessModeWrite
    jmp @CopyAccessMode
@CheckRead:
    test eax, GENERIC_READ
    jz @AccessDone
    lea esi, szAccessModeRead

@CopyAccessMode:
    lodsb
    test al, al
    jz @AccessDone
    stosb
    jmp @CopyAccessMode

@AccessDone:
    ; Null terminate
    xor al, al
    stosb
    
    ; Output log
    lea eax, g_LogBuffer
    push eax
    call OutputDebugStringA
    
    popfd
    popad
    
    ; Call original function via trampoline
    push [ebp+32]               ; hTemplateFile
    push [ebp+28]               ; dwFlagsAndAttributes
    push [ebp+24]               ; dwCreationDisposition
    push [ebp+20]               ; lpSecurityAttributes
    push [ebp+16]               ; dwShareMode
    push [ebp+12]               ; dwDesiredAccess
    push [ebp+8]                ; lpFileName
    
    call g_pTrampolineCreateA
    
    ; EAX contains the return value (handle)
    
    mov esp, ebp
    pop ebp
    ret 28                      ; Clean up 7 parameters
CreateFileAHookHandler ENDP

;-------------------------------------------------------------------------------
; ReadFileHookHandler
;-------------------------------------------------------------------------------
; Description: Hook handler for ReadFile
; Parameters:  Same as ReadFile
;   [ebp+8]  = hFile
;   [ebp+12] = lpBuffer
;   [ebp+16] = nNumberOfBytesToRead
;   [ebp+20] = lpNumberOfBytesRead
;   [ebp+24] = lpOverlapped
; Returns:     BOOL
;-------------------------------------------------------------------------------
ReadFileHookHandler PROC
    push ebp
    mov ebp, esp
    
    pushad
    pushfd
    
    ; Increment counter
    inc g_dwReadFileCount
    
    ; Log the call
    push OFFSET szReadFileLog
    call OutputDebugStringA
    
    popfd
    popad
    
    ; Call original
    push [ebp+24]
    push [ebp+20]
    push [ebp+16]
    push [ebp+12]
    push [ebp+8]
    
    call g_pTrampolineRead
    
    mov esp, ebp
    pop ebp
    ret 20
ReadFileHookHandler ENDP

;-------------------------------------------------------------------------------
; WriteFileHookHandler
;-------------------------------------------------------------------------------
; Description: Hook handler for WriteFile
; Parameters:  Same as WriteFile
;   [ebp+8]  = hFile
;   [ebp+12] = lpBuffer
;   [ebp+16] = nNumberOfBytesToWrite
;   [ebp+20] = lpNumberOfBytesWritten
;   [ebp+24] = lpOverlapped
; Returns:     BOOL
;-------------------------------------------------------------------------------
WriteFileHookHandler PROC
    push ebp
    mov ebp, esp
    
    pushad
    pushfd
    
    ; Increment counter
    inc g_dwWriteFileCount
    
    ; Log the call
    push OFFSET szWriteFileLog
    call OutputDebugStringA
    
    popfd
    popad
    
    ; Call original
    push [ebp+24]
    push [ebp+20]
    push [ebp+16]
    push [ebp+12]
    push [ebp+8]
    
    call g_pTrampolineWrite
    
    mov esp, ebp
    pop ebp
    ret 20
WriteFileHookHandler ENDP

;-------------------------------------------------------------------------------
; DeleteFileAHookHandler
;-------------------------------------------------------------------------------
; Description: Hook handler for DeleteFileA
; Parameters:
;   [ebp+8] = lpFileName
; Returns:     BOOL
;-------------------------------------------------------------------------------
DeleteFileAHookHandler PROC
    push ebp
    mov ebp, esp
    
    pushad
    pushfd
    
    ; Increment counter
    inc g_dwDeleteFileCount
    
    ; Build log message
    lea edi, g_LogBuffer
    lea esi, szDeleteFileLog
@CopyPrefix:
    lodsb
    test al, al
    jz @PrefixDone
    stosb
    jmp @CopyPrefix
@PrefixDone:
    
    ; Copy filename
    mov esi, [ebp+8]
    test esi, esi
    jz @NoName
    mov ecx, 200
@CopyName:
    lodsb
    test al, al
    jz @NameDone
    stosb
    loop @CopyName
@NameDone:
    jmp @EndLog
@NoName:
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
    xor al, al
    stosb
    
    lea eax, g_LogBuffer
    push eax
    call OutputDebugStringA
    
    popfd
    popad
    
    ; Call original
    push [ebp+8]
    call g_pTrampolineDeleteA
    
    mov esp, ebp
    pop ebp
    ret 4
DeleteFileAHookHandler ENDP

;-------------------------------------------------------------------------------
; InstallFileHooks
;-------------------------------------------------------------------------------
; Description: Installs hooks on file I/O functions
; Parameters:  None
; Returns:     EAX = 1 on success, 0 on failure
;-------------------------------------------------------------------------------
InstallFileHooks PROC EXPORT
    LOCAL pFunc:DWORD
    
    pushad
    
    ; Check if already installed
    cmp g_bFileHooksEnabled, 1
    je @AlreadyInstalled
    
    ; Get kernel32 handle
    push OFFSET szKernel32
    call GetModuleHandleA
    test eax, eax
    jz @Failed
    mov g_hKernel32, eax
    
    ;---------------------------------------------------
    ; Hook CreateFileA
    ;---------------------------------------------------
    push OFFSET szCreateFileA
    push g_hKernel32
    call GetProcAddress
    test eax, eax
    jz @Failed
    mov g_pOrigCreateFileA, eax
    mov pFunc, eax
    
    ; Change protection
    push OFFSET g_dwOldProtect
    push PAGE_EXECUTE_READWRITE
    push 5
    push pFunc
    call VirtualProtect
    test eax, eax
    jz @Failed
    
    ; Allocate trampoline
    push PAGE_EXECUTE_READWRITE
    push MEM_COMMIT or MEM_RESERVE
    push 32
    push NULL
    call VirtualAlloc
    test eax, eax
    jz @Failed
    mov g_pTrampolineCreateA, eax
    
    ; Build trampoline
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
    
    ; Install hook
    mov edi, pFunc
    mov BYTE PTR [edi], 0E9h
    mov eax, OFFSET CreateFileAHookHandler
    sub eax, edi
    sub eax, 5
    mov [edi+1], eax
    
    ;---------------------------------------------------
    ; Hook ReadFile
    ;---------------------------------------------------
    push OFFSET szReadFile
    push g_hKernel32
    call GetProcAddress
    test eax, eax
    jz @SkipReadFile
    mov g_pOrigReadFile, eax
    mov pFunc, eax
    
    push OFFSET g_dwOldProtect
    push PAGE_EXECUTE_READWRITE
    push 5
    push pFunc
    call VirtualProtect
    test eax, eax
    jz @SkipReadFile
    
    push PAGE_EXECUTE_READWRITE
    push MEM_COMMIT or MEM_RESERVE
    push 32
    push NULL
    call VirtualAlloc
    test eax, eax
    jz @SkipReadFile
    mov g_pTrampolineRead, eax
    
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
    mov eax, OFFSET ReadFileHookHandler
    sub eax, edi
    sub eax, 5
    mov [edi+1], eax

@SkipReadFile:
    ;---------------------------------------------------
    ; Hook WriteFile
    ;---------------------------------------------------
    push OFFSET szWriteFile
    push g_hKernel32
    call GetProcAddress
    test eax, eax
    jz @SkipWriteFile
    mov g_pOrigWriteFile, eax
    mov pFunc, eax
    
    push OFFSET g_dwOldProtect
    push PAGE_EXECUTE_READWRITE
    push 5
    push pFunc
    call VirtualProtect
    test eax, eax
    jz @SkipWriteFile
    
    push PAGE_EXECUTE_READWRITE
    push MEM_COMMIT or MEM_RESERVE
    push 32
    push NULL
    call VirtualAlloc
    test eax, eax
    jz @SkipWriteFile
    mov g_pTrampolineWrite, eax
    
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
    mov eax, OFFSET WriteFileHookHandler
    sub eax, edi
    sub eax, 5
    mov [edi+1], eax

@SkipWriteFile:
    ;---------------------------------------------------
    ; Hook DeleteFileA
    ;---------------------------------------------------
    push OFFSET szDeleteFileA
    push g_hKernel32
    call GetProcAddress
    test eax, eax
    jz @SkipDeleteFile
    mov g_pOrigDeleteFileA, eax
    mov pFunc, eax
    
    push OFFSET g_dwOldProtect
    push PAGE_EXECUTE_READWRITE
    push 5
    push pFunc
    call VirtualProtect
    test eax, eax
    jz @SkipDeleteFile
    
    push PAGE_EXECUTE_READWRITE
    push MEM_COMMIT or MEM_RESERVE
    push 32
    push NULL
    call VirtualAlloc
    test eax, eax
    jz @SkipDeleteFile
    mov g_pTrampolineDeleteA, eax
    
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
    mov eax, OFFSET DeleteFileAHookHandler
    sub eax, edi
    sub eax, 5
    mov [edi+1], eax

@SkipDeleteFile:
    ; Flush instruction cache
    push 0
    push 0
    push -1
    call FlushInstructionCache
    
    ; Mark as enabled
    mov g_bFileHooksEnabled, 1
    
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
InstallFileHooks ENDP

;-------------------------------------------------------------------------------
; RemoveFileHooks
;-------------------------------------------------------------------------------
; Description: Removes all file hooks
; Parameters:  None
; Returns:     EAX = 1 on success
;-------------------------------------------------------------------------------
RemoveFileHooks PROC EXPORT
    pushad
    
    cmp g_bFileHooksEnabled, 0
    je @NotInstalled
    
    ; Restore CreateFileA
    cmp g_pTrampolineCreateA, 0
    je @SkipRestoreCreate
    push OFFSET g_dwOldProtect
    push PAGE_EXECUTE_READWRITE
    push 5
    push g_pOrigCreateFileA
    call VirtualProtect
    
    mov edi, g_pOrigCreateFileA
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
@SkipRestoreCreate:
    
    ; Restore ReadFile
    cmp g_pTrampolineRead, 0
    je @SkipRestoreRead
    push OFFSET g_dwOldProtect
    push PAGE_EXECUTE_READWRITE
    push 5
    push g_pOrigReadFile
    call VirtualProtect
    
    mov edi, g_pOrigReadFile
    mov esi, g_pTrampolineRead
    movsb
    movsb
    movsb
    movsb
    movsb
    
    push MEM_RELEASE
    push 0
    push g_pTrampolineRead
    call VirtualFree
    mov g_pTrampolineRead, 0
@SkipRestoreRead:
    
    ; Restore WriteFile
    cmp g_pTrampolineWrite, 0
    je @SkipRestoreWrite
    push OFFSET g_dwOldProtect
    push PAGE_EXECUTE_READWRITE
    push 5
    push g_pOrigWriteFile
    call VirtualProtect
    
    mov edi, g_pOrigWriteFile
    mov esi, g_pTrampolineWrite
    movsb
    movsb
    movsb
    movsb
    movsb
    
    push MEM_RELEASE
    push 0
    push g_pTrampolineWrite
    call VirtualFree
    mov g_pTrampolineWrite, 0
@SkipRestoreWrite:
    
    ; Restore DeleteFileA
    cmp g_pTrampolineDeleteA, 0
    je @SkipRestoreDelete
    push OFFSET g_dwOldProtect
    push PAGE_EXECUTE_READWRITE
    push 5
    push g_pOrigDeleteFileA
    call VirtualProtect
    
    mov edi, g_pOrigDeleteFileA
    mov esi, g_pTrampolineDeleteA
    movsb
    movsb
    movsb
    movsb
    movsb
    
    push MEM_RELEASE
    push 0
    push g_pTrampolineDeleteA
    call VirtualFree
    mov g_pTrampolineDeleteA, 0
@SkipRestoreDelete:
    
    ; Flush instruction cache
    push 0
    push 0
    push -1
    call FlushInstructionCache
    
    mov g_bFileHooksEnabled, 0
    
    push OFFSET szHookRemoved
    call OutputDebugStringA

@NotInstalled:
    popad
    mov eax, 1
    ret
RemoveFileHooks ENDP

;-------------------------------------------------------------------------------
; GetFileHookStats
;-------------------------------------------------------------------------------
; Description: Gets file hook statistics
; Parameters:
;   [ebp+8]  = pCreateCount - Pointer for CreateFile count
;   [ebp+12] = pReadCount - Pointer for ReadFile count
;   [ebp+16] = pWriteCount - Pointer for WriteFile count
;   [ebp+20] = pDeleteCount - Pointer for DeleteFile count
; Returns:     EAX = 1 if hooks enabled, 0 otherwise
;-------------------------------------------------------------------------------
GetFileHookStats PROC EXPORT pCreateCount:DWORD, pReadCount:DWORD, pWriteCount:DWORD, pDeleteCount:DWORD
    mov eax, pCreateCount
    test eax, eax
    jz @Skip1
    mov ecx, g_dwCreateFileCount
    mov [eax], ecx
@Skip1:
    mov eax, pReadCount
    test eax, eax
    jz @Skip2
    mov ecx, g_dwReadFileCount
    mov [eax], ecx
@Skip2:
    mov eax, pWriteCount
    test eax, eax
    jz @Skip3
    mov ecx, g_dwWriteFileCount
    mov [eax], ecx
@Skip3:
    mov eax, pDeleteCount
    test eax, eax
    jz @Skip4
    mov ecx, g_dwDeleteFileCount
    mov [eax], ecx
@Skip4:
    mov eax, g_bFileHooksEnabled
    ret
GetFileHookStats ENDP

END
