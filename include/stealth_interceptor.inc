;===============================================================================
; STEALTH INTERCEPTOR - Main Include File
;===============================================================================
; File:        stealth_interceptor.inc
; Description: Main include file with all constants and prototypes
; Authors:     Muhammad Adeel Haider (241541), Umar Farooq (241575)
; Course:      COAL - 5th Semester, BS Cyber Security
; Date:        November 2024
;===============================================================================

;===============================================================================
; Version Information
;===============================================================================
STEALTH_VERSION_MAJOR   EQU 1
STEALTH_VERSION_MINOR   EQU 0
STEALTH_VERSION_PATCH   EQU 0

;===============================================================================
; Hook Engine Constants
;===============================================================================
HOOK_SIZE               EQU 5           ; Size of JMP instruction
MAX_HOOKS               EQU 256         ; Maximum concurrent hooks
TRAMPOLINE_SIZE         EQU 32          ; Size of trampoline buffer

; Hook status flags
HOOK_STATUS_INACTIVE    EQU 0
HOOK_STATUS_ACTIVE      EQU 1
HOOK_STATUS_PAUSED      EQU 2
HOOK_STATUS_ERROR       EQU 3

; Error codes
HOOK_SUCCESS            EQU 0
HOOK_ERR_INVALID_PTR    EQU 1
HOOK_ERR_MEM_PROTECT    EQU 2
HOOK_ERR_MAX_HOOKS      EQU 3
HOOK_ERR_NOT_FOUND      EQU 4
HOOK_ERR_ALLOC          EQU 5
HOOK_ERR_ALREADY_HOOKED EQU 6
HOOK_ERR_NOT_HOOKED     EQU 7

;===============================================================================
; Logging Constants
;===============================================================================
LOG_BUFFER_SIZE         EQU 4096
MAX_LOG_ENTRIES         EQU 1000
MAX_MESSAGE_LEN         EQU 256

; Log levels
LOG_LEVEL_DEBUG         EQU 0
LOG_LEVEL_INFO          EQU 1
LOG_LEVEL_WARNING       EQU 2
LOG_LEVEL_ERROR         EQU 3
LOG_LEVEL_CRITICAL      EQU 4

; Log output targets
LOG_TARGET_DEBUG        EQU 1           ; OutputDebugString
LOG_TARGET_FILE         EQU 2           ; File output
LOG_TARGET_CONSOLE      EQU 4           ; Console output
LOG_TARGET_ALL          EQU 7           ; All targets

; Log categories
LOG_CAT_ENGINE          EQU 1
LOG_CAT_HOOK            EQU 2
LOG_CAT_MEMORY          EQU 3
LOG_CAT_NETWORK         EQU 4
LOG_CAT_FILE            EQU 5
LOG_CAT_PROCESS         EQU 6

;===============================================================================
; Hook Entry Structure
;===============================================================================
HOOK_ENTRY STRUCT
    pOriginalFunc       DWORD ?         ; Pointer to original function
    pHookFunc           DWORD ?         ; Pointer to hook handler
    pTrampoline         DWORD ?         ; Pointer to trampoline code
    dwOriginalBytes     DWORD 8 DUP(?)  ; Saved original bytes
    dwBytesStolen       DWORD ?         ; Number of bytes stolen
    dwStatus            DWORD ?         ; Hook status
    szFuncName          BYTE 64 DUP(?)  ; Function name for debugging
HOOK_ENTRY ENDS

;===============================================================================
; Trampoline Info Structure
;===============================================================================
TRAMPOLINE_INFO STRUCT
    pOriginalFunc       DWORD ?         ; Original function address
    pTrampolineCode     DWORD ?         ; Trampoline code address
    dwStolenBytes       DWORD ?         ; Number of stolen bytes
    aStolenCode         BYTE 32 DUP(?)  ; Stored stolen instructions
    dwFlags             DWORD ?         ; Trampoline flags
TRAMPOLINE_INFO ENDS

;===============================================================================
; Register Context Structure
;===============================================================================
REGISTER_CONTEXT STRUCT
    ; General purpose registers
    dwEax               DWORD ?
    dwEcx               DWORD ?
    dwEdx               DWORD ?
    dwEbx               DWORD ?
    dwEsp               DWORD ?
    dwEbp               DWORD ?
    dwEsi               DWORD ?
    dwEdi               DWORD ?
    
    ; Segment registers
    wCs                 WORD ?
    wDs                 WORD ?
    wEs                 WORD ?
    wFs                 WORD ?
    wGs                 WORD ?
    wSs                 WORD ?
    
    ; Flags register
    dwEflags            DWORD ?
    
    ; Instruction pointer
    dwEip               DWORD ?
    
    ; FPU state (optional)
    fpuState            BYTE 108 DUP(?)
    
    ; Reserved
    dwReserved          DWORD 4 DUP(?)
REGISTER_CONTEXT ENDS

;===============================================================================
; Log Entry Structure
;===============================================================================
LOG_ENTRY STRUCT
    dwTimestamp         DWORD ?
    dwLevel             DWORD ?
    dwCategory          DWORD ?
    szMessage           BYTE MAX_MESSAGE_LEN DUP(?)
LOG_ENTRY ENDS

;===============================================================================
; File Access Log Structure
;===============================================================================
FILE_ACCESS_LOG STRUCT
    szFilePath          BYTE 260 DUP(?)
    dwAccessMode        DWORD ?
    dwShareMode         DWORD ?
    dwCreateDisp        DWORD ?
    dwTimestamp         DWORD ?
    dwResult            DWORD ?
FILE_ACCESS_LOG ENDS

;===============================================================================
; Network Connection Log Structure
;===============================================================================
NET_CONNECTION_LOG STRUCT
    dwSocketHandle      DWORD ?
    dwAddressFamily     DWORD ?
    dwSocketType        DWORD ?
    dwProtocol          DWORD ?
    dwRemoteIP          DWORD ?
    dwRemotePort        WORD ?
    wPadding            WORD ?
    dwLocalPort         WORD ?
    wPadding2           WORD ?
    dwTimestamp         DWORD ?
    dwOperation         DWORD ?
NET_CONNECTION_LOG ENDS

;===============================================================================
; Process Event Log Structure
;===============================================================================
PROCESS_EVENT_LOG STRUCT
    szProcessName       BYTE 260 DUP(?)
    dwProcessId         DWORD ?
    dwParentProcessId   DWORD ?
    dwEventType         DWORD ?
    dwTimestamp         DWORD ?
    dwFlags             DWORD ?
PROCESS_EVENT_LOG ENDS

;===============================================================================
; Hook Engine Function Prototypes
;===============================================================================
InitializeHookEngine    PROTO
ShutdownHookEngine      PROTO
InstallHook             PROTO :DWORD, :DWORD, :DWORD
RemoveHook              PROTO :DWORD
RemoveAllHooks          PROTO
GetTrampoline           PROTO :DWORD
GetHookCount            PROTO
IsHookActive            PROTO :DWORD
PauseHook               PROTO :DWORD
ResumeHook              PROTO :DWORD

;===============================================================================
; Trampoline Function Prototypes
;===============================================================================
InitializeTrampolineSystem  PROTO
CleanupTrampolineSystem     PROTO
AllocateTrampoline          PROTO
BuildTrampoline             PROTO :DWORD, :DWORD, :DWORD
GetInstructionLength        PROTO :DWORD
CalculateMinimumBytes       PROTO :DWORD, :DWORD
InstallTrampolineHook       PROTO :DWORD, :DWORD, :DWORD
ExecuteTrampoline           PROTO :DWORD

;===============================================================================
; Memory Manager Function Prototypes
;===============================================================================
ChangeMemoryProtection      PROTO :DWORD, :DWORD, :DWORD, :DWORD
MakeMemoryWritable          PROTO :DWORD, :DWORD, :DWORD
RestoreMemoryProtection     PROTO :DWORD, :DWORD, :DWORD
AllocateExecutableMemory    PROTO :DWORD
FreeExecutableMemory        PROTO :DWORD
SafeMemoryCopy              PROTO :DWORD, :DWORD, :DWORD
SafeWriteByte               PROTO :DWORD, :BYTE
SafeWriteDword              PROTO :DWORD, :DWORD
ReadProcessMemorySafe       PROTO :DWORD, :DWORD, :DWORD, :DWORD
WriteProcessMemorySafe      PROTO :DWORD, :DWORD, :DWORD, :DWORD
QueryMemoryInfo             PROTO :DWORD, :DWORD
IsMemoryExecutable          PROTO :DWORD
IsMemoryWritable            PROTO :DWORD
GetLastMemoryError          PROTO

;===============================================================================
; Register Save/Restore Function Prototypes
;===============================================================================
SaveAllRegisters            PROTO :DWORD
RestoreAllRegisters         PROTO :DWORD
QuickSaveContext            PROTO
QuickRestoreContext         PROTO
SaveFPUState                PROTO :DWORD
RestoreFPUState             PROTO :DWORD
HookProlog                  PROTO
HookEpilog                  PROTO
GetRegisterValue            PROTO :DWORD, :DWORD
SetRegisterValue            PROTO :DWORD, :DWORD, :DWORD
DumpRegisters               PROTO :DWORD
CompareContexts             PROTO :DWORD, :DWORD

;===============================================================================
; MessageBox Hook Prototypes
;===============================================================================
InstallMessageBoxHook       PROTO
RemoveMessageBoxHook        PROTO
GetMessageBoxHookStats      PROTO :DWORD, :DWORD
IsMessageBoxHookActive      PROTO

;===============================================================================
; File Hook Prototypes
;===============================================================================
InstallFileHooks            PROTO
RemoveFileHooks             PROTO
GetFileHookStats            PROTO :DWORD, :DWORD, :DWORD, :DWORD

;===============================================================================
; Network Hook Prototypes
;===============================================================================
InstallNetworkHooks         PROTO
RemoveNetworkHooks          PROTO
GetNetworkHookStats         PROTO :DWORD, :DWORD, :DWORD, :DWORD

;===============================================================================
; Process Hook Prototypes
;===============================================================================
InstallProcessHooks         PROTO
RemoveProcessHooks          PROTO
GetProcessHookStats         PROTO :DWORD, :DWORD, :DWORD, :DWORD

;===============================================================================
; Logging Function Prototypes
;===============================================================================
InitializeLogging           PROTO :DWORD, :DWORD
ShutdownLogging             PROTO
LogMessage                  PROTO :DWORD, :DWORD, :DWORD
LogDebug                    PROTO :DWORD
LogInfo                     PROTO :DWORD
LogWarning                  PROTO :DWORD
LogError                    PROTO :DWORD
SetLogLevel                 PROTO :DWORD
SetLogTarget                PROTO :DWORD
GetLogStats                 PROTO :DWORD, :DWORD, :DWORD, :DWORD
FlushLog                    PROTO

;===============================================================================
; String Utility Prototypes
;===============================================================================
StrLen                      PROTO :DWORD
StrCopy                     PROTO :DWORD, :DWORD
StrNCopy                    PROTO :DWORD, :DWORD, :DWORD
StrCat                      PROTO :DWORD, :DWORD
StrCmp                      PROTO :DWORD, :DWORD
StrCmpI                     PROTO :DWORD, :DWORD
StrChr                      PROTO :DWORD, :DWORD
StrRChr                     PROTO :DWORD, :DWORD
StrStr                      PROTO :DWORD, :DWORD
IntToStr                    PROTO :DWORD, :DWORD, :DWORD
StrToInt                    PROTO :DWORD
HexToStr                    PROTO :DWORD, :DWORD, :DWORD
ToUpper                     PROTO :DWORD
ToLower                     PROTO :DWORD

;===============================================================================
; Useful Macros
;===============================================================================

; Save all registers before hook handler code
HOOK_SAVE_CONTEXT MACRO
    pushad
    pushfd
ENDM

; Restore all registers after hook handler code
HOOK_RESTORE_CONTEXT MACRO
    popfd
    popad
ENDM

; Standard hook handler prologue
HOOK_HANDLER_PROLOG MACRO
    push ebp
    mov ebp, esp
    HOOK_SAVE_CONTEXT
ENDM

; Standard hook handler epilogue
HOOK_HANDLER_EPILOG MACRO paramBytes:REQ
    HOOK_RESTORE_CONTEXT
    mov esp, ebp
    pop ebp
    ret paramBytes
ENDM

; Log a debug message
LOG_DEBUG MACRO message:REQ
    push OFFSET message
    call LogDebug
ENDM

; Log an info message
LOG_INFO MACRO message:REQ
    push OFFSET message
    call LogInfo
ENDM

; Log a warning message
LOG_WARNING MACRO message:REQ
    push OFFSET message
    call LogWarning
ENDM

; Log an error message
LOG_ERROR MACRO message:REQ
    push OFFSET message
    call LogError
ENDM
