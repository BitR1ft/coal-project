;===============================================================================
; STEALTH INTERCEPTOR - Memory Manager
;===============================================================================
; File:        memory_manager.asm
; Description: Memory manipulation routines for hook installation
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
PAGE_SIZE EQU 4096

; Memory protection constants (for reference)
; PAGE_NOACCESS          = 0001h
; PAGE_READONLY          = 0002h
; PAGE_READWRITE         = 0004h
; PAGE_WRITECOPY         = 0008h
; PAGE_EXECUTE           = 0010h
; PAGE_EXECUTE_READ      = 0020h
; PAGE_EXECUTE_READWRITE = 0040h
; PAGE_EXECUTE_WRITECOPY = 0080h

;===============================================================================
; Memory Region Structure
;===============================================================================
MEMORY_REGION STRUCT
    pBaseAddress   DWORD ?
    dwSize         DWORD ?
    dwOldProtect   DWORD ?
    dwNewProtect   DWORD ?
MEMORY_REGION ENDS

;===============================================================================
; Data Section
;===============================================================================
.data
    ; Log messages
    szMemProtectChanged  BYTE "[Memory] Protection changed at ", 0
    szMemProtectFailed   BYTE "[Memory] Protection change failed at ", 0
    szMemAllocated       BYTE "[Memory] Allocated ", 0
    szMemFreed           BYTE "[Memory] Freed memory at ", 0
    szBytes              BYTE " bytes", 0
    szHexPrefix          BYTE "0x", 0
    
.data?
    g_LastError DWORD ?

;===============================================================================
; Code Section
;===============================================================================
.code

;-------------------------------------------------------------------------------
; ChangeMemoryProtection
;-------------------------------------------------------------------------------
; Description: Changes memory protection for a region
; Parameters:
;   [ebp+8]  = pAddress - Address of memory region
;   [ebp+12] = dwSize - Size of region
;   [ebp+16] = dwNewProtect - New protection flags
;   [ebp+20] = pdwOldProtect - Pointer to receive old protection
; Returns:     EAX = 1 on success, 0 on failure
;-------------------------------------------------------------------------------
ChangeMemoryProtection PROC EXPORT pAddress:DWORD, dwSize:DWORD, dwNewProtect:DWORD, pdwOldProtect:DWORD
    pushad
    
    ; Validate parameters
    cmp pAddress, 0
    je @Failed
    cmp dwSize, 0
    je @Failed
    
    ; Call VirtualProtect
    push pdwOldProtect
    push dwNewProtect
    push dwSize
    push pAddress
    call VirtualProtect
    test eax, eax
    jz @Failed
    
    popad
    mov eax, 1
    ret

@Failed:
    ; Get last error for debugging
    call GetLastError
    mov g_LastError, eax
    
    popad
    xor eax, eax
    ret
ChangeMemoryProtection ENDP

;-------------------------------------------------------------------------------
; MakeMemoryWritable
;-------------------------------------------------------------------------------
; Description: Makes a memory region writable (and executable)
; Parameters:
;   [ebp+8]  = pAddress - Address of memory region
;   [ebp+12] = dwSize - Size of region
;   [ebp+16] = pdwOldProtect - Pointer to receive old protection
; Returns:     EAX = 1 on success, 0 on failure
;-------------------------------------------------------------------------------
MakeMemoryWritable PROC EXPORT pAddress:DWORD, dwSize:DWORD, pdwOldProtect:DWORD
    push pdwOldProtect
    push PAGE_EXECUTE_READWRITE
    push dwSize
    push pAddress
    call ChangeMemoryProtection
    ret
MakeMemoryWritable ENDP

;-------------------------------------------------------------------------------
; RestoreMemoryProtection
;-------------------------------------------------------------------------------
; Description: Restores memory protection to previous state
; Parameters:
;   [ebp+8]  = pAddress - Address of memory region
;   [ebp+12] = dwSize - Size of region
;   [ebp+16] = dwOldProtect - Protection to restore
; Returns:     EAX = 1 on success, 0 on failure
;-------------------------------------------------------------------------------
RestoreMemoryProtection PROC EXPORT pAddress:DWORD, dwSize:DWORD, dwOldProtect:DWORD
    LOCAL dwDummy:DWORD
    
    lea eax, dwDummy
    push eax
    push dwOldProtect
    push dwSize
    push pAddress
    call ChangeMemoryProtection
    ret
RestoreMemoryProtection ENDP

;-------------------------------------------------------------------------------
; AllocateExecutableMemory
;-------------------------------------------------------------------------------
; Description: Allocates memory with execute permissions
; Parameters:
;   [ebp+8] = dwSize - Size to allocate
; Returns:     EAX = Pointer to allocated memory, or 0 on failure
;-------------------------------------------------------------------------------
AllocateExecutableMemory PROC EXPORT dwSize:DWORD
    push PAGE_EXECUTE_READWRITE
    push MEM_COMMIT or MEM_RESERVE
    push dwSize
    push NULL
    call VirtualAlloc
    ret
AllocateExecutableMemory ENDP

;-------------------------------------------------------------------------------
; FreeExecutableMemory
;-------------------------------------------------------------------------------
; Description: Frees memory allocated by AllocateExecutableMemory
; Parameters:
;   [ebp+8] = pMemory - Pointer to memory
; Returns:     EAX = 1 on success, 0 on failure
;-------------------------------------------------------------------------------
FreeExecutableMemory PROC EXPORT pMemory:DWORD
    cmp pMemory, 0
    je @Failed
    
    push MEM_RELEASE
    push 0
    push pMemory
    call VirtualFree
    ret

@Failed:
    xor eax, eax
    ret
FreeExecutableMemory ENDP

;-------------------------------------------------------------------------------
; SafeMemoryCopy
;-------------------------------------------------------------------------------
; Description: Safely copies memory, handling protection issues
; Parameters:
;   [ebp+8]  = pDest - Destination address
;   [ebp+12] = pSrc - Source address
;   [ebp+16] = dwSize - Size to copy
; Returns:     EAX = 1 on success, 0 on failure
;-------------------------------------------------------------------------------
SafeMemoryCopy PROC EXPORT pDest:DWORD, pSrc:DWORD, dwSize:DWORD
    LOCAL dwOldProtect:DWORD
    
    pushad
    
    ; Make destination writable
    lea eax, dwOldProtect
    push eax
    push dwSize
    push pDest
    call MakeMemoryWritable
    test eax, eax
    jz @Failed
    
    ; Copy memory
    mov edi, pDest
    mov esi, pSrc
    mov ecx, dwSize
    rep movsb
    
    ; Restore protection
    push dwOldProtect
    push dwSize
    push pDest
    call RestoreMemoryProtection
    
    popad
    mov eax, 1
    ret

@Failed:
    popad
    xor eax, eax
    ret
SafeMemoryCopy ENDP

;-------------------------------------------------------------------------------
; SafeWriteByte
;-------------------------------------------------------------------------------
; Description: Safely writes a byte to memory
; Parameters:
;   [ebp+8]  = pAddress - Address to write to
;   [ebp+12] = bValue - Byte value to write
; Returns:     EAX = 1 on success, 0 on failure
;-------------------------------------------------------------------------------
SafeWriteByte PROC EXPORT pAddress:DWORD, bValue:BYTE
    LOCAL dwOldProtect:DWORD
    
    pushad
    
    ; Make address writable
    lea eax, dwOldProtect
    push eax
    push 1
    push pAddress
    call MakeMemoryWritable
    test eax, eax
    jz @Failed
    
    ; Write byte
    mov edi, pAddress
    mov al, bValue
    mov [edi], al
    
    ; Restore protection
    push dwOldProtect
    push 1
    push pAddress
    call RestoreMemoryProtection
    
    popad
    mov eax, 1
    ret

@Failed:
    popad
    xor eax, eax
    ret
SafeWriteByte ENDP

;-------------------------------------------------------------------------------
; SafeWriteDword
;-------------------------------------------------------------------------------
; Description: Safely writes a DWORD to memory
; Parameters:
;   [ebp+8]  = pAddress - Address to write to
;   [ebp+12] = dwValue - DWORD value to write
; Returns:     EAX = 1 on success, 0 on failure
;-------------------------------------------------------------------------------
SafeWriteDword PROC EXPORT pAddress:DWORD, dwValue:DWORD
    LOCAL dwOldProtect:DWORD
    
    pushad
    
    ; Make address writable
    lea eax, dwOldProtect
    push eax
    push 4
    push pAddress
    call MakeMemoryWritable
    test eax, eax
    jz @Failed
    
    ; Write DWORD
    mov edi, pAddress
    mov eax, dwValue
    mov [edi], eax
    
    ; Restore protection
    push dwOldProtect
    push 4
    push pAddress
    call RestoreMemoryProtection
    
    popad
    mov eax, 1
    ret

@Failed:
    popad
    xor eax, eax
    ret
SafeWriteDword ENDP

;-------------------------------------------------------------------------------
; ReadProcessMemorySafe
;-------------------------------------------------------------------------------
; Description: Reads memory from target process (or current process)
; Parameters:
;   [ebp+8]  = hProcess - Process handle (-1 for current)
;   [ebp+12] = pAddress - Address to read from
;   [ebp+16] = pBuffer - Buffer to receive data
;   [ebp+20] = dwSize - Size to read
; Returns:     EAX = Bytes read, or 0 on failure
;-------------------------------------------------------------------------------
ReadProcessMemorySafe PROC EXPORT hProcess:DWORD, pAddress:DWORD, pBuffer:DWORD, dwSize:DWORD
    LOCAL dwBytesRead:DWORD
    
    ; If current process, just copy directly
    cmp hProcess, -1
    jne @UseAPI
    
    ; Direct copy for current process
    pushad
    mov esi, pAddress
    mov edi, pBuffer
    mov ecx, dwSize
    rep movsb
    popad
    mov eax, dwSize
    ret

@UseAPI:
    ; Use ReadProcessMemory API
    lea eax, dwBytesRead
    push eax
    push dwSize
    push pBuffer
    push pAddress
    push hProcess
    call ReadProcessMemory
    test eax, eax
    jz @Failed
    
    mov eax, dwBytesRead
    ret

@Failed:
    xor eax, eax
    ret
ReadProcessMemorySafe ENDP

;-------------------------------------------------------------------------------
; WriteProcessMemorySafe
;-------------------------------------------------------------------------------
; Description: Writes memory to target process (or current process)
; Parameters:
;   [ebp+8]  = hProcess - Process handle (-1 for current)
;   [ebp+12] = pAddress - Address to write to
;   [ebp+16] = pData - Data to write
;   [ebp+20] = dwSize - Size to write
; Returns:     EAX = Bytes written, or 0 on failure
;-------------------------------------------------------------------------------
WriteProcessMemorySafe PROC EXPORT hProcess:DWORD, pAddress:DWORD, pData:DWORD, dwSize:DWORD
    LOCAL dwBytesWritten:DWORD
    LOCAL dwOldProtect:DWORD
    
    ; If current process, use SafeMemoryCopy
    cmp hProcess, -1
    jne @UseAPI
    
    push dwSize
    push pData
    push pAddress
    call SafeMemoryCopy
    test eax, eax
    jz @Failed
    
    mov eax, dwSize
    ret

@UseAPI:
    ; Change protection on target
    push PAGE_EXECUTE_READWRITE
    push PAGE_EXECUTE_READWRITE
    push dwSize
    push pAddress
    push hProcess
    call VirtualProtectEx
    test eax, eax
    jz @Failed
    
    ; Use WriteProcessMemory API
    lea eax, dwBytesWritten
    push eax
    push dwSize
    push pData
    push pAddress
    push hProcess
    call WriteProcessMemory
    test eax, eax
    jz @Failed
    
    mov eax, dwBytesWritten
    ret

@Failed:
    xor eax, eax
    ret
WriteProcessMemorySafe ENDP

;-------------------------------------------------------------------------------
; QueryMemoryInfo
;-------------------------------------------------------------------------------
; Description: Gets information about a memory region
; Parameters:
;   [ebp+8]  = pAddress - Address to query
;   [ebp+12] = pInfo - Pointer to MEMORY_BASIC_INFORMATION structure
; Returns:     EAX = Size of information returned, or 0 on failure
;-------------------------------------------------------------------------------
QueryMemoryInfo PROC EXPORT pAddress:DWORD, pInfo:DWORD
    push SIZEOF MEMORY_BASIC_INFORMATION
    push pInfo
    push pAddress
    call VirtualQuery
    ret
QueryMemoryInfo ENDP

;-------------------------------------------------------------------------------
; IsMemoryExecutable
;-------------------------------------------------------------------------------
; Description: Checks if memory region is executable
; Parameters:
;   [ebp+8] = pAddress - Address to check
; Returns:     EAX = 1 if executable, 0 otherwise
;-------------------------------------------------------------------------------
IsMemoryExecutable PROC EXPORT pAddress:DWORD
    LOCAL mbi:MEMORY_BASIC_INFORMATION
    
    ; Query memory info
    lea eax, mbi
    push eax
    push pAddress
    call QueryMemoryInfo
    test eax, eax
    jz @NotExecutable
    
    ; Check protection flags
    mov eax, mbi.Protect
    and eax, (PAGE_EXECUTE or PAGE_EXECUTE_READ or PAGE_EXECUTE_READWRITE or PAGE_EXECUTE_WRITECOPY)
    jz @NotExecutable
    
    mov eax, 1
    ret

@NotExecutable:
    xor eax, eax
    ret
IsMemoryExecutable ENDP

;-------------------------------------------------------------------------------
; IsMemoryWritable
;-------------------------------------------------------------------------------
; Description: Checks if memory region is writable
; Parameters:
;   [ebp+8] = pAddress - Address to check
; Returns:     EAX = 1 if writable, 0 otherwise
;-------------------------------------------------------------------------------
IsMemoryWritable PROC EXPORT pAddress:DWORD
    LOCAL mbi:MEMORY_BASIC_INFORMATION
    
    ; Query memory info
    lea eax, mbi
    push eax
    push pAddress
    call QueryMemoryInfo
    test eax, eax
    jz @NotWritable
    
    ; Check protection flags
    mov eax, mbi.Protect
    and eax, (PAGE_READWRITE or PAGE_WRITECOPY or PAGE_EXECUTE_READWRITE or PAGE_EXECUTE_WRITECOPY)
    jz @NotWritable
    
    mov eax, 1
    ret

@NotWritable:
    xor eax, eax
    ret
IsMemoryWritable ENDP

;-------------------------------------------------------------------------------
; GetLastMemoryError
;-------------------------------------------------------------------------------
; Description: Gets the last error from memory operations
; Parameters:  None
; Returns:     EAX = Last error code
;-------------------------------------------------------------------------------
GetLastMemoryError PROC EXPORT
    mov eax, g_LastError
    ret
GetLastMemoryError ENDP

END
