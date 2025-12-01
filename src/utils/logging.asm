;===============================================================================
; STEALTH INTERCEPTOR - Logging Utilities
;===============================================================================
; File:        logging.asm
; Description: Logging system for hook activity
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
LOG_BUFFER_SIZE    EQU 4096
MAX_LOG_ENTRIES    EQU 1000
MAX_MESSAGE_LEN    EQU 256

; Log levels
LOG_LEVEL_DEBUG    EQU 0
LOG_LEVEL_INFO     EQU 1
LOG_LEVEL_WARNING  EQU 2
LOG_LEVEL_ERROR    EQU 3
LOG_LEVEL_CRITICAL EQU 4

; Log output targets
LOG_TARGET_DEBUG   EQU 1         ; OutputDebugString
LOG_TARGET_FILE    EQU 2         ; File output
LOG_TARGET_CONSOLE EQU 4         ; Console output
LOG_TARGET_ALL     EQU 7         ; All targets

;===============================================================================
; Log Entry Structure
;===============================================================================
LOG_ENTRY STRUCT
    dwTimestamp      DWORD ?
    dwLevel          DWORD ?
    dwCategory       DWORD ?
    szMessage        BYTE MAX_MESSAGE_LEN DUP(?)
LOG_ENTRY ENDS

;===============================================================================
; Data Section
;===============================================================================
.data
    ; Log level strings
    szDebug          BYTE "[DEBUG] ", 0
    szInfo           BYTE "[INFO] ", 0
    szWarning        BYTE "[WARN] ", 0
    szError          BYTE "[ERROR] ", 0
    szCritical       BYTE "[CRIT] ", 0
    
    ; Category strings
    szCatEngine      BYTE "[Engine] ", 0
    szCatHook        BYTE "[Hook] ", 0
    szCatMemory      BYTE "[Memory] ", 0
    szCatNetwork     BYTE "[Network] ", 0
    szCatFile        BYTE "[File] ", 0
    szCatProcess     BYTE "[Process] ", 0
    
    ; Other strings
    szNewLine        BYTE 13, 10, 0
    szTimestamp      BYTE "[", 0
    szTimestampEnd   BYTE "] ", 0
    szLogFileName    BYTE "stealth_interceptor.log", 0
    szLogHeader      BYTE "=== Stealth Interceptor Log ===", 13, 10, 0
    
    ; Log state
    g_dwLogLevel     DWORD LOG_LEVEL_INFO
    g_dwLogTarget    DWORD LOG_TARGET_DEBUG
    g_hLogFile       DWORD 0
    g_bLogEnabled    DWORD 1
    
    ; Log entry buffer
    g_dwLogIndex     DWORD 0
    g_dwLogCount     DWORD 0
    
    ; Statistics
    g_dwDebugCount   DWORD 0
    g_dwInfoCount    DWORD 0
    g_dwWarningCount DWORD 0
    g_dwErrorCount   DWORD 0

.data?
    g_LogBuffer      BYTE LOG_BUFFER_SIZE DUP(?)
    g_TempBuffer     BYTE MAX_MESSAGE_LEN DUP(?)
    g_LogEntries     LOG_ENTRY MAX_LOG_ENTRIES DUP(?)
    g_CritSection    CRITICAL_SECTION <>

;===============================================================================
; Code Section
;===============================================================================
.code

;-------------------------------------------------------------------------------
; InitializeLogging
;-------------------------------------------------------------------------------
; Description: Initializes the logging system
; Parameters:
;   [ebp+8] = dwTarget - Log target flags
;   [ebp+12] = dwLevel - Minimum log level
; Returns:     EAX = 1 on success, 0 on failure
;-------------------------------------------------------------------------------
InitializeLogging PROC EXPORT dwTarget:DWORD, dwLevel:DWORD
    pushad
    
    ; Initialize critical section
    lea eax, g_CritSection
    push eax
    call InitializeCriticalSection
    
    ; Set log parameters
    mov eax, dwTarget
    mov g_dwLogTarget, eax
    mov eax, dwLevel
    mov g_dwLogLevel, eax
    
    ; Initialize file if needed
    mov eax, dwTarget
    test eax, LOG_TARGET_FILE
    jz @NoFile
    
    ; Create/Open log file
    push 0                      ; hTemplateFile
    push FILE_ATTRIBUTE_NORMAL  ; dwFlagsAndAttributes
    push CREATE_ALWAYS          ; dwCreationDisposition
    push 0                      ; lpSecurityAttributes
    push FILE_SHARE_READ        ; dwShareMode
    push GENERIC_WRITE          ; dwDesiredAccess
    push OFFSET szLogFileName   ; lpFileName
    call CreateFileA
    cmp eax, INVALID_HANDLE_VALUE
    je @NoFile
    mov g_hLogFile, eax
    
    ; Write header
    push 0                      ; lpOverlapped
    lea ecx, g_dwLogCount       ; Use as temp
    push ecx                    ; lpNumberOfBytesWritten
    push 31                     ; nNumberOfBytesToWrite
    push OFFSET szLogHeader     ; lpBuffer
    push g_hLogFile             ; hFile
    call WriteFile

@NoFile:
    ; Enable logging
    mov g_bLogEnabled, 1
    
    ; Reset counters
    mov g_dwLogIndex, 0
    mov g_dwLogCount, 0
    mov g_dwDebugCount, 0
    mov g_dwInfoCount, 0
    mov g_dwWarningCount, 0
    mov g_dwErrorCount, 0
    
    popad
    mov eax, 1
    ret
InitializeLogging ENDP

;-------------------------------------------------------------------------------
; ShutdownLogging
;-------------------------------------------------------------------------------
; Description: Shuts down the logging system
; Parameters:  None
; Returns:     None
;-------------------------------------------------------------------------------
ShutdownLogging PROC EXPORT
    pushad
    
    ; Close log file if open
    cmp g_hLogFile, 0
    je @NoFile
    push g_hLogFile
    call CloseHandle
    mov g_hLogFile, 0

@NoFile:
    ; Delete critical section
    lea eax, g_CritSection
    push eax
    call DeleteCriticalSection
    
    mov g_bLogEnabled, 0
    
    popad
    ret
ShutdownLogging ENDP

;-------------------------------------------------------------------------------
; LogMessage
;-------------------------------------------------------------------------------
; Description: Logs a message
; Parameters:
;   [ebp+8]  = dwLevel - Log level
;   [ebp+12] = dwCategory - Message category
;   [ebp+16] = lpszMessage - Message string
; Returns:     EAX = 1 on success, 0 if filtered
;-------------------------------------------------------------------------------
LogMessage PROC EXPORT dwLevel:DWORD, dwCategory:DWORD, lpszMessage:DWORD
    LOCAL dwBytesWritten:DWORD
    
    pushad
    
    ; Check if logging is enabled
    cmp g_bLogEnabled, 0
    je @Disabled
    
    ; Check log level filter
    mov eax, dwLevel
    cmp eax, g_dwLogLevel
    jb @Filtered
    
    ; Enter critical section
    lea eax, g_CritSection
    push eax
    call EnterCriticalSection
    
    ; Build log message in buffer
    lea edi, g_LogBuffer
    
    ; Add timestamp
    push edi
    call GetTickCount
    pop edi
    mov BYTE PTR [edi], '['
    inc edi
    call DwordToDecimalStr
    mov BYTE PTR [edi], ']'
    inc edi
    mov BYTE PTR [edi], ' '
    inc edi
    
    ; Add level prefix
    mov eax, dwLevel
    cmp eax, LOG_LEVEL_DEBUG
    jne @NotDebug
    lea esi, szDebug
    inc g_dwDebugCount
    jmp @CopyLevel
@NotDebug:
    cmp eax, LOG_LEVEL_INFO
    jne @NotInfo
    lea esi, szInfo
    inc g_dwInfoCount
    jmp @CopyLevel
@NotInfo:
    cmp eax, LOG_LEVEL_WARNING
    jne @NotWarning
    lea esi, szWarning
    inc g_dwWarningCount
    jmp @CopyLevel
@NotWarning:
    cmp eax, LOG_LEVEL_ERROR
    jne @NotError
    lea esi, szError
    inc g_dwErrorCount
    jmp @CopyLevel
@NotError:
    lea esi, szCritical
    inc g_dwErrorCount

@CopyLevel:
    ; Copy level string
@CopyLevelLoop:
    lodsb
    test al, al
    jz @LevelDone
    stosb
    jmp @CopyLevelLoop
@LevelDone:
    
    ; Add category prefix based on dwCategory
    mov eax, dwCategory
    cmp eax, 0
    je @SkipCategory
    cmp eax, 1
    jne @NotEngine
    lea esi, szCatEngine
    jmp @CopyCategory
@NotEngine:
    cmp eax, 2
    jne @NotHook
    lea esi, szCatHook
    jmp @CopyCategory
@NotHook:
    cmp eax, 3
    jne @NotMemory
    lea esi, szCatMemory
    jmp @CopyCategory
@NotMemory:
    cmp eax, 4
    jne @NotNetwork
    lea esi, szCatNetwork
    jmp @CopyCategory
@NotNetwork:
    cmp eax, 5
    jne @NotFile
    lea esi, szCatFile
    jmp @CopyCategory
@NotFile:
    lea esi, szCatProcess

@CopyCategory:
@CopyCatLoop:
    lodsb
    test al, al
    jz @CatDone
    stosb
    jmp @CopyCatLoop
@CatDone:
@SkipCategory:
    
    ; Copy message
    mov esi, lpszMessage
    test esi, esi
    jz @NoMessage
    mov ecx, MAX_MESSAGE_LEN - 50  ; Leave room for prefix
@CopyMessage:
    lodsb
    test al, al
    jz @MessageDone
    stosb
    loop @CopyMessage
@MessageDone:
@NoMessage:
    
    ; Add newline
    mov BYTE PTR [edi], 13
    inc edi
    mov BYTE PTR [edi], 10
    inc edi
    mov BYTE PTR [edi], 0
    
    ; Calculate message length
    lea eax, g_LogBuffer
    mov ecx, edi
    sub ecx, eax
    
    ; Output to debug if enabled
    mov eax, g_dwLogTarget
    test eax, LOG_TARGET_DEBUG
    jz @SkipDebug
    lea eax, g_LogBuffer
    push eax
    call OutputDebugStringA
@SkipDebug:
    
    ; Output to file if enabled
    mov eax, g_dwLogTarget
    test eax, LOG_TARGET_FILE
    jz @SkipFile
    cmp g_hLogFile, 0
    je @SkipFile
    
    ; Calculate length (ECX still has it)
    lea eax, dwBytesWritten
    push 0
    push eax
    push ecx
    lea eax, g_LogBuffer
    push eax
    push g_hLogFile
    call WriteFile
@SkipFile:
    
    ; Output to console if enabled
    mov eax, g_dwLogTarget
    test eax, LOG_TARGET_CONSOLE
    jz @SkipConsole
    ; Get console handle
    push STD_OUTPUT_HANDLE
    call GetStdHandle
    cmp eax, INVALID_HANDLE_VALUE
    je @SkipConsole
    
    ; Calculate length again
    lea ecx, g_LogBuffer
    mov edi, ecx
@CountLen:
    cmp BYTE PTR [edi], 0
    je @LenDone
    inc edi
    jmp @CountLen
@LenDone:
    sub edi, ecx
    
    ; Write to console
    lea ebx, dwBytesWritten
    push 0
    push ebx
    push edi
    lea ecx, g_LogBuffer
    push ecx
    push eax
    call WriteFile
@SkipConsole:
    
    ; Store in log entry buffer for retrieval
    mov eax, g_dwLogIndex
    imul eax, SIZEOF LOG_ENTRY
    lea edi, g_LogEntries
    add edi, eax
    
    call GetTickCount
    mov [edi].LOG_ENTRY.dwTimestamp, eax
    mov eax, dwLevel
    mov [edi].LOG_ENTRY.dwLevel, eax
    mov eax, dwCategory
    mov [edi].LOG_ENTRY.dwCategory, eax
    
    ; Copy message to entry
    lea edi, [edi].LOG_ENTRY.szMessage
    mov esi, lpszMessage
    test esi, esi
    jz @NoMsgCopy
    mov ecx, MAX_MESSAGE_LEN - 1
@CopyMsgToEntry:
    lodsb
    test al, al
    jz @MsgCopyDone
    stosb
    loop @CopyMsgToEntry
@MsgCopyDone:
@NoMsgCopy:
    mov BYTE PTR [edi], 0
    
    ; Update index (circular buffer)
    inc g_dwLogIndex
    cmp g_dwLogIndex, MAX_LOG_ENTRIES
    jl @NoWrap
    mov g_dwLogIndex, 0
@NoWrap:
    
    ; Update count
    cmp g_dwLogCount, MAX_LOG_ENTRIES
    jge @MaxReached
    inc g_dwLogCount
@MaxReached:
    
    ; Leave critical section
    lea eax, g_CritSection
    push eax
    call LeaveCriticalSection
    
    popad
    mov eax, 1
    ret

@Disabled:
@Filtered:
    popad
    xor eax, eax
    ret
LogMessage ENDP

;-------------------------------------------------------------------------------
; DwordToDecimalStr - Helper
;-------------------------------------------------------------------------------
DwordToDecimalStr PROC
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
DwordToDecimalStr ENDP

;-------------------------------------------------------------------------------
; LogDebug - Convenience function for debug messages
;-------------------------------------------------------------------------------
LogDebug PROC EXPORT lpszMessage:DWORD
    push 0                      ; Category
    push lpszMessage
    push LOG_LEVEL_DEBUG
    call LogMessage
    add esp, 12
    ret
LogDebug ENDP

;-------------------------------------------------------------------------------
; LogInfo - Convenience function for info messages
;-------------------------------------------------------------------------------
LogInfo PROC EXPORT lpszMessage:DWORD
    push 0
    push lpszMessage
    push LOG_LEVEL_INFO
    call LogMessage
    add esp, 12
    ret
LogInfo ENDP

;-------------------------------------------------------------------------------
; LogWarning - Convenience function for warning messages
;-------------------------------------------------------------------------------
LogWarning PROC EXPORT lpszMessage:DWORD
    push 0
    push lpszMessage
    push LOG_LEVEL_WARNING
    call LogMessage
    add esp, 12
    ret
LogWarning ENDP

;-------------------------------------------------------------------------------
; LogError - Convenience function for error messages
;-------------------------------------------------------------------------------
LogError PROC EXPORT lpszMessage:DWORD
    push 0
    push lpszMessage
    push LOG_LEVEL_ERROR
    call LogMessage
    add esp, 12
    ret
LogError ENDP

;-------------------------------------------------------------------------------
; SetLogLevel
;-------------------------------------------------------------------------------
SetLogLevel PROC EXPORT dwLevel:DWORD
    mov eax, dwLevel
    mov g_dwLogLevel, eax
    ret
SetLogLevel ENDP

;-------------------------------------------------------------------------------
; SetLogTarget
;-------------------------------------------------------------------------------
SetLogTarget PROC EXPORT dwTarget:DWORD
    mov eax, dwTarget
    mov g_dwLogTarget, eax
    ret
SetLogTarget ENDP

;-------------------------------------------------------------------------------
; GetLogStats
;-------------------------------------------------------------------------------
GetLogStats PROC EXPORT pDebug:DWORD, pInfo:DWORD, pWarning:DWORD, pError:DWORD
    mov eax, pDebug
    test eax, eax
    jz @Skip1
    mov ecx, g_dwDebugCount
    mov [eax], ecx
@Skip1:
    mov eax, pInfo
    test eax, eax
    jz @Skip2
    mov ecx, g_dwInfoCount
    mov [eax], ecx
@Skip2:
    mov eax, pWarning
    test eax, eax
    jz @Skip3
    mov ecx, g_dwWarningCount
    mov [eax], ecx
@Skip3:
    mov eax, pError
    test eax, eax
    jz @Skip4
    mov ecx, g_dwErrorCount
    mov [eax], ecx
@Skip4:
    mov eax, g_dwLogCount
    ret
GetLogStats ENDP

;-------------------------------------------------------------------------------
; FlushLog
;-------------------------------------------------------------------------------
FlushLog PROC EXPORT
    cmp g_hLogFile, 0
    je @NoFile
    push g_hLogFile
    call FlushFileBuffers
@NoFile:
    ret
FlushLog ENDP

END
