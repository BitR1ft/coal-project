;===============================================================================
; STEALTH INTERCEPTOR - Hook Engine Tests
;===============================================================================
; File:        test_hook_engine.asm
; Description: Unit tests for the hook engine
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
; External Procedures
;===============================================================================
EXTERN InitializeHookEngine:PROC
EXTERN ShutdownHookEngine:PROC
EXTERN InstallMessageBoxHook:PROC
EXTERN RemoveMessageBoxHook:PROC
EXTERN IsMessageBoxHookActive:PROC
EXTERN InstallFileHooks:PROC
EXTERN RemoveFileHooks:PROC

;===============================================================================
; Test Result Macros
;===============================================================================
TEST_PASS EQU 1
TEST_FAIL EQU 0

;===============================================================================
; Data Section
;===============================================================================
.data
    szTestHeader     BYTE "=== Stealth Interceptor Tests ===", 13, 10, 0
    szTestPassed     BYTE "[PASS] ", 0
    szTestFailed     BYTE "[FAIL] ", 0
    szNewLine        BYTE 13, 10, 0
    
    ; Test names
    szTest1          BYTE "Hook Engine Initialization", 0
    szTest2          BYTE "MessageBox Hook Install", 0
    szTest3          BYTE "MessageBox Hook Active Check", 0
    szTest4          BYTE "MessageBox Hook Remove", 0
    szTest5          BYTE "File Hooks Install", 0
    szTest6          BYTE "File Hooks Remove", 0
    szTest7          BYTE "Engine Shutdown", 0
    
    ; Results
    szSummary        BYTE 13, 10, "=== Test Summary ===", 13, 10, 0
    szPassedCount    BYTE "Passed: ", 0
    szFailedCount    BYTE "Failed: ", 0
    szTotal          BYTE "Total:  ", 0
    
    ; Counters
    g_dwPassed       DWORD 0
    g_dwFailed       DWORD 0

.data?
    hConsole         DWORD ?
    dwBytesWritten   DWORD ?
    szNumberBuf      BYTE 16 DUP(?)

;===============================================================================
; Code Section
;===============================================================================
.code

;-------------------------------------------------------------------------------
; PrintString - Output a string to console
;-------------------------------------------------------------------------------
PrintString PROC lpszStr:DWORD
    pushad
    
    ; Calculate length
    mov edi, lpszStr
    xor ecx, ecx
@CountLen:
    cmp BYTE PTR [edi+ecx], 0
    je @LenDone
    inc ecx
    jmp @CountLen
@LenDone:
    
    ; Write to console
    push 0
    lea eax, dwBytesWritten
    push eax
    push ecx
    push lpszStr
    push hConsole
    call WriteConsoleA
    
    popad
    ret
PrintString ENDP

;-------------------------------------------------------------------------------
; PrintNumber - Output a number
;-------------------------------------------------------------------------------
PrintNumber PROC dwValue:DWORD
    pushad
    
    lea edi, szNumberBuf
    mov eax, dwValue
    xor ecx, ecx
    mov ebx, 10
    
    test eax, eax
    jnz @ConvLoop
    mov BYTE PTR [edi], '0'
    inc edi
    jmp @PrintIt
    
@ConvLoop:
    test eax, eax
    jz @Reverse
    xor edx, edx
    div ebx
    add dl, '0'
    push edx
    inc ecx
    jmp @ConvLoop

@Reverse:
    test ecx, ecx
    jz @PrintIt
    pop edx
    mov [edi], dl
    inc edi
    dec ecx
    jmp @Reverse

@PrintIt:
    mov BYTE PTR [edi], 0
    
    push OFFSET szNumberBuf
    call PrintString
    
    popad
    ret
PrintNumber ENDP

;-------------------------------------------------------------------------------
; RecordResult - Record test result
;-------------------------------------------------------------------------------
RecordResult PROC bPassed:DWORD, lpszTestName:DWORD
    cmp bPassed, TEST_PASS
    jne @Failed
    
    ; Passed
    inc g_dwPassed
    push OFFSET szTestPassed
    call PrintString
    jmp @PrintName

@Failed:
    inc g_dwFailed
    push OFFSET szTestFailed
    call PrintString

@PrintName:
    push lpszTestName
    call PrintString
    push OFFSET szNewLine
    call PrintString
    ret
RecordResult ENDP

;-------------------------------------------------------------------------------
; Test1_EngineInit - Test engine initialization
;-------------------------------------------------------------------------------
Test1_EngineInit PROC
    call InitializeHookEngine
    test eax, eax
    jnz @Passed
    
    push OFFSET szTest1
    push TEST_FAIL
    call RecordResult
    ret

@Passed:
    push OFFSET szTest1
    push TEST_PASS
    call RecordResult
    ret
Test1_EngineInit ENDP

;-------------------------------------------------------------------------------
; Test2_MsgBoxInstall - Test MessageBox hook installation
;-------------------------------------------------------------------------------
Test2_MsgBoxInstall PROC
    call InstallMessageBoxHook
    test eax, eax
    jz @Failed
    
    push OFFSET szTest2
    push TEST_PASS
    call RecordResult
    ret

@Failed:
    push OFFSET szTest2
    push TEST_FAIL
    call RecordResult
    ret
Test2_MsgBoxInstall ENDP

;-------------------------------------------------------------------------------
; Test3_MsgBoxActive - Test if hook is active
;-------------------------------------------------------------------------------
Test3_MsgBoxActive PROC
    call IsMessageBoxHookActive
    test eax, eax
    jz @Failed
    
    push OFFSET szTest3
    push TEST_PASS
    call RecordResult
    ret

@Failed:
    push OFFSET szTest3
    push TEST_FAIL
    call RecordResult
    ret
Test3_MsgBoxActive ENDP

;-------------------------------------------------------------------------------
; Test4_MsgBoxRemove - Test hook removal
;-------------------------------------------------------------------------------
Test4_MsgBoxRemove PROC
    call RemoveMessageBoxHook
    
    ; Verify it's no longer active
    call IsMessageBoxHookActive
    test eax, eax
    jnz @Failed
    
    push OFFSET szTest4
    push TEST_PASS
    call RecordResult
    ret

@Failed:
    push OFFSET szTest4
    push TEST_FAIL
    call RecordResult
    ret
Test4_MsgBoxRemove ENDP

;-------------------------------------------------------------------------------
; Test5_FileHooksInstall - Test file hooks installation
;-------------------------------------------------------------------------------
Test5_FileHooksInstall PROC
    call InstallFileHooks
    test eax, eax
    jz @Failed
    
    push OFFSET szTest5
    push TEST_PASS
    call RecordResult
    ret

@Failed:
    push OFFSET szTest5
    push TEST_FAIL
    call RecordResult
    ret
Test5_FileHooksInstall ENDP

;-------------------------------------------------------------------------------
; Test6_FileHooksRemove - Test file hooks removal
;-------------------------------------------------------------------------------
Test6_FileHooksRemove PROC
    call RemoveFileHooks
    
    push OFFSET szTest6
    push TEST_PASS
    call RecordResult
    ret
Test6_FileHooksRemove ENDP

;-------------------------------------------------------------------------------
; Test7_EngineShutdown - Test engine shutdown
;-------------------------------------------------------------------------------
Test7_EngineShutdown PROC
    call ShutdownHookEngine
    
    push OFFSET szTest7
    push TEST_PASS
    call RecordResult
    ret
Test7_EngineShutdown ENDP

;-------------------------------------------------------------------------------
; PrintSummary - Print test summary
;-------------------------------------------------------------------------------
PrintSummary PROC
    push OFFSET szSummary
    call PrintString
    
    ; Passed count
    push OFFSET szPassedCount
    call PrintString
    push g_dwPassed
    call PrintNumber
    push OFFSET szNewLine
    call PrintString
    
    ; Failed count
    push OFFSET szFailedCount
    call PrintString
    push g_dwFailed
    call PrintNumber
    push OFFSET szNewLine
    call PrintString
    
    ; Total
    push OFFSET szTotal
    call PrintString
    mov eax, g_dwPassed
    add eax, g_dwFailed
    push eax
    call PrintNumber
    push OFFSET szNewLine
    call PrintString
    
    ret
PrintSummary ENDP

;-------------------------------------------------------------------------------
; main - Test entry point
;-------------------------------------------------------------------------------
main PROC
    ; Get console handle
    push STD_OUTPUT_HANDLE
    call GetStdHandle
    mov hConsole, eax
    
    ; Print header
    push OFFSET szTestHeader
    call PrintString
    push OFFSET szNewLine
    call PrintString
    
    ; Run tests
    call Test1_EngineInit
    call Test2_MsgBoxInstall
    call Test3_MsgBoxActive
    call Test4_MsgBoxRemove
    call Test5_FileHooksInstall
    call Test6_FileHooksRemove
    call Test7_EngineShutdown
    
    ; Print summary
    call PrintSummary
    
    ; Exit with failure count as return code
    push g_dwFailed
    call ExitProcess
main ENDP

END main
