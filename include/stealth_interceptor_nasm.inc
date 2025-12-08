;===============================================================================
; STEALTH INTERCEPTOR - NASM Include File
;===============================================================================
; File:        stealth_interceptor_nasm.inc
; Description: Constants and structures for NASM version
; Authors:     Muhammad Adeel Haider (241541), Umar Farooq (241575)
; Course:      COAL - 5th Semester, BS Cyber Security
;===============================================================================

; Version Information
%define STEALTH_VERSION_MAJOR   1
%define STEALTH_VERSION_MINOR   0
%define STEALTH_VERSION_PATCH   0

; Hook Engine Constants
%define HOOK_SIZE               5           ; Size of JMP instruction
%define MAX_HOOKS               256         ; Maximum concurrent hooks
%define TRAMPOLINE_SIZE         32          ; Size of trampoline buffer

; Hook status flags
%define HOOK_STATUS_INACTIVE    0
%define HOOK_STATUS_ACTIVE      1
%define HOOK_STATUS_PAUSED      2
%define HOOK_STATUS_ERROR       3

; Error codes
%define HOOK_SUCCESS            0
%define HOOK_ERR_INVALID_PTR    1
%define HOOK_ERR_MEM_PROTECT    2
%define HOOK_ERR_MAX_HOOKS      3
%define HOOK_ERR_NOT_FOUND      4
%define HOOK_ERR_ALLOC          5
%define HOOK_ERR_ALREADY_HOOKED 6
%define HOOK_ERR_NOT_HOOKED     7

; Logging Constants
%define LOG_BUFFER_SIZE         4096
%define MAX_LOG_ENTRIES         1000
%define MAX_MESSAGE_LEN         256

; Log levels
%define LOG_LEVEL_DEBUG         0
%define LOG_LEVEL_INFO          1
%define LOG_LEVEL_WARNING       2
%define LOG_LEVEL_ERROR         3
%define LOG_LEVEL_CRITICAL      4

; Log output targets
%define LOG_TARGET_DEBUG        1           ; OutputDebugString
%define LOG_TARGET_FILE         2           ; File output
%define LOG_TARGET_CONSOLE      4           ; Console output
%define LOG_TARGET_ALL          7           ; All targets

; Log categories
%define LOG_CAT_ENGINE          1
%define LOG_CAT_HOOK            2
%define LOG_CAT_MEMORY          3
%define LOG_CAT_NETWORK         4
%define LOG_CAT_FILE            5
%define LOG_CAT_PROCESS         6

; Windows API Constants
%define NULL                    0
%define TRUE                    1
%define FALSE                   0

; Memory protection constants
%define PAGE_NOACCESS           0x01
%define PAGE_READONLY           0x02
%define PAGE_READWRITE          0x04
%define PAGE_WRITECOPY          0x08
%define PAGE_EXECUTE            0x10
%define PAGE_EXECUTE_READ       0x20
%define PAGE_EXECUTE_READWRITE  0x40
%define PAGE_EXECUTE_WRITECOPY  0x80

; Memory allocation constants
%define MEM_COMMIT              0x1000
%define MEM_RESERVE             0x2000
%define MEM_DECOMMIT            0x4000
%define MEM_RELEASE             0x8000
%define MEM_FREE                0x10000
%define MEM_PRIVATE             0x20000
%define MEM_MAPPED              0x40000
%define MEM_RESET               0x80000

; Heap flags
%define HEAP_NO_SERIALIZE       0x00000001
%define HEAP_GENERATE_EXCEPTIONS 0x00000004
%define HEAP_ZERO_MEMORY        0x00000008

; Console handles
%define STD_INPUT_HANDLE        -10
%define STD_OUTPUT_HANDLE       -11
%define STD_ERROR_HANDLE        -12

; File constants
%define GENERIC_READ            0x80000000
%define GENERIC_WRITE           0x40000000
%define FILE_SHARE_READ         0x00000001
%define FILE_SHARE_WRITE        0x00000002
%define CREATE_NEW              1
%define CREATE_ALWAYS           2
%define OPEN_EXISTING           3
%define OPEN_ALWAYS             4
%define TRUNCATE_EXISTING       5

%define FILE_ATTRIBUTE_NORMAL   0x00000080
%define INVALID_HANDLE_VALUE    -1

; MessageBox constants
%define MB_OK                   0x00000000
%define MB_OKCANCEL             0x00000001
%define MB_ABORTRETRYIGNORE     0x00000002
%define MB_YESNOCANCEL          0x00000003
%define MB_YESNO                0x00000004
%define MB_RETRYCANCEL          0x00000005

%define MB_ICONHAND             0x00000010
%define MB_ICONQUESTION         0x00000020
%define MB_ICONEXCLAMATION      0x00000030
%define MB_ICONASTERISK         0x00000040
%define MB_ICONWARNING          MB_ICONEXCLAMATION
%define MB_ICONERROR            MB_ICONHAND
%define MB_ICONINFORMATION      MB_ICONASTERISK

; Socket constants
%define AF_INET                 2
%define SOCK_STREAM             1
%define SOCK_DGRAM              2
%define IPPROTO_TCP             6
%define IPPROTO_UDP             17

; Process constants
%define PROCESS_ALL_ACCESS      0x001F0FFF
%define CREATE_SUSPENDED        0x00000004

; Hook Entry Structure (size = 120 bytes)
struc HOOK_ENTRY
    .pOriginalFunc:     resd 1      ; Pointer to original function
    .pHookFunc:         resd 1      ; Pointer to hook handler
    .pTrampoline:       resd 1      ; Pointer to trampoline code
    .dwOriginalBytes:   resd 8      ; Saved original bytes
    .dwBytesStolen:     resd 1      ; Number of bytes stolen
    .dwStatus:          resd 1      ; Hook status
    .szFuncName:        resb 64     ; Function name for debugging
endstruc

; Register Context Structure
struc REGISTER_CONTEXT
    .dwEax:             resd 1
    .dwEcx:             resd 1
    .dwEdx:             resd 1
    .dwEbx:             resd 1
    .dwEsp:             resd 1
    .dwEbp:             resd 1
    .dwEsi:             resd 1
    .dwEdi:             resd 1
    .dwEFlags:          resd 1
endstruc

; Log Entry Structure
struc LOG_ENTRY
    .dwTimestamp:       resd 1
    .dwLevel:           resd 1
    .dwCategory:        resd 1
    .szMessage:         resb MAX_MESSAGE_LEN
endstruc
