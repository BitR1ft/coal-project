;===============================================================================
; MINI STEALTH INTERCEPTOR - Main Demo (Simplified)
;===============================================================================
; File:        demo_main.asm
; Description: Simplified demonstration of the API Hooking Engine
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
; External Procedures
;===============================================================================
EXTERN InitializeHookEngine:PROC
EXTERN ShutdownHookEngine:PROC
EXTERN InstallMessageBoxHook:PROC
EXTERN RemoveMessageBoxHook:PROC
EXTERN GetMessageBoxHookStats:PROC

;===============================================================================
; Constants
;===============================================================================
MAX_INPUT_LEN EQU 256

;===============================================================================
; Data Section
;===============================================================================
.data
    ; Banner
    szBanner1       BYTE 13, 10, "==========================================", 13, 10, 0
    szBanner2       BYTE "  MINI STEALTH INTERCEPTOR", 13, 10, 0
    szBanner3       BYTE "  Simplified API Hooking Demo", 13, 10, 0
    szBanner4       BYTE "==========================================", 13, 10, 0
    szBanner5       BYTE "  By: Muhammad Adeel Haider (241541)", 13, 10, 0
    szBanner6       BYTE "      Umar Farooq (241575)", 13, 10, 0
    szBanner7       BYTE "  COAL - BS Cyber Security", 13, 10, 0
    szBannerLine    BYTE "==========================================", 13, 10, 13, 10, 0
    
    ; Menu
    szMenuHeader    BYTE 13, 10, "--- Main Menu ---", 13, 10, 0
    szMenu1         BYTE "1. Install MessageBox Hook", 13, 10, 0
    szMenu2         BYTE "2. Remove MessageBox Hook", 13, 10, 0
    szMenu3         BYTE "3. Test MessageBox", 13, 10, 0
    szMenu4         BYTE "4. Show Statistics", 13, 10, 0
    szMenu5         BYTE "5. Exit", 13, 10, 0
    szMenuPrompt    BYTE 13, 10, "Choose (1-5): ", 0
    
    ; Messages
    szInitOK        BYTE "[+] Hook Engine initialized!", 13, 10, 0
    szInitFail      BYTE "[-] Failed to initialize!", 13, 10, 0
    szHookOn        BYTE "[+] MessageBox hook INSTALLED", 13, 10, 0
    szHookOff       BYTE "[+] MessageBox hook REMOVED", 13, 10, 0
    szTest          BYTE "[*] Testing MessageBox...", 13, 10, 0
    szTestTitle     BYTE "Mini Interceptor Test", 0
    szTestText      BYTE "If hook is active, this will be intercepted!", 0
    szStatsHeader   BYTE 13, 10, "--- Statistics ---", 13, 10, 0
    szStatsCount    BYTE "Interceptions: ", 0
    szExiting       BYTE 13, 10, "[*] Cleaning up...", 13, 10, 0
    szGoodbye       BYTE "Goodbye!", 13, 10, 0
    szInvalid       BYTE "[-] Invalid choice!", 13, 10, 0
    szNewLine       BYTE 13, 10, 0
    
    g_bHookActive   DWORD 0

.data?
    hConsoleOut     DWORD ?
    hConsoleIn      DWORD ?
    dwBytesWritten  DWORD ?
    dwBytesRead     DWORD ?
    szInputBuffer   BYTE MAX_INPUT_LEN DUP(?)
    szNumberBuffer  BYTE 16 DUP(?)
    dwInterceptCount DWORD ?

;===============================================================================
; Code Section
;===============================================================================
.code

;-------------------------------------------------------------------------------
; PrintString - Output string to console
;-------------------------------------------------------------------------------
PrintString PROC lpszString:DWORD
    pushad
    
    ; Get length
    mov edi, lpszString
    xor ecx, ecx
@CountLen:
    cmp BYTE PTR [edi+ecx], 0
    je @LenDone
    inc ecx
    jmp @CountLen
@LenDone:
    
    ; Write
    push 0
    lea eax, dwBytesWritten
    push eax
    push ecx
    push lpszString
    push hConsoleOut
    call WriteConsoleA
    
    popad
    ret
PrintString ENDP

;-------------------------------------------------------------------------------
; PrintNumber - Output number to console
;-------------------------------------------------------------------------------
PrintNumber PROC dwValue:DWORD
    pushad
    
    lea edi, szNumberBuffer
    mov eax, dwValue
    mov ebx, 10
    
    test eax, eax
    jnz @ConvertLoop
    mov BYTE PTR [edi], '0'
    inc edi
    jmp @PrintNum
    
@ConvertLoop:
    test eax, eax
    jz @Reverse
    xor edx, edx
    div ebx
    add dl, '0'
    push edx
    inc ecx
    jmp @ConvertLoop
    
@Reverse:
    test ecx, ecx
    jz @PrintNum
    pop edx
    mov [edi], dl
    inc edi
    dec ecx
    jmp @Reverse

@PrintNum:
    mov BYTE PTR [edi], 0
    
    lea eax, szNumberBuffer
    mov ecx, edi
    sub ecx, eax
    
    push 0
    lea eax, dwBytesWritten
    push eax
    push ecx
    lea eax, szNumberBuffer
    push eax
    push hConsoleOut
    call WriteConsoleA
    
    popad
    ret
PrintNumber ENDP

;-------------------------------------------------------------------------------
; ReadInput - Read line from console
;-------------------------------------------------------------------------------
ReadInput PROC
    pushad
    
    push 0
    lea eax, dwBytesRead
    push eax
    push MAX_INPUT_LEN
    lea eax, szInputBuffer
    push eax
    push hConsoleIn
    call ReadConsoleA
    
    ; Null-terminate and strip newline
    mov ecx, dwBytesRead
    lea edi, szInputBuffer
    mov BYTE PTR [edi+ecx], 0
    
    dec ecx
    cmp BYTE PTR [edi+ecx], 10
    jne @NoLF
    mov BYTE PTR [edi+ecx], 0
    dec ecx
@NoLF:
    cmp ecx, 0
    jl @Done
    cmp BYTE PTR [edi+ecx], 13
    jne @Done
    mov BYTE PTR [edi+ecx], 0

@Done:
    popad
    ret
ReadInput ENDP

;-------------------------------------------------------------------------------
; ShowBanner - Display banner
;-------------------------------------------------------------------------------
ShowBanner PROC
    push OFFSET szBanner1
    call PrintString
    push OFFSET szBanner2
    call PrintString
    push OFFSET szBanner3
    call PrintString
    push OFFSET szBanner4
    call PrintString
    push OFFSET szBanner5
    call PrintString
    push OFFSET szBanner6
    call PrintString
    push OFFSET szBanner7
    call PrintString
    push OFFSET szBannerLine
    call PrintString
    ret
ShowBanner ENDP

;-------------------------------------------------------------------------------
; ShowMenu - Display menu
;-------------------------------------------------------------------------------
ShowMenu PROC
    push OFFSET szMenuHeader
    call PrintString
    push OFFSET szMenu1
    call PrintString
    push OFFSET szMenu2
    call PrintString
    push OFFSET szMenu3
    call PrintString
    push OFFSET szMenu4
    call PrintString
    push OFFSET szMenu5
    call PrintString
    push OFFSET szMenuPrompt
    call PrintString
    ret
ShowMenu ENDP

;-------------------------------------------------------------------------------
; Main - Entry point
;-------------------------------------------------------------------------------
main PROC
    LOCAL dwChoice:DWORD
    
    ; Get console handles
    push STD_OUTPUT_HANDLE
    call GetStdHandle
    mov hConsoleOut, eax
    
    push STD_INPUT_HANDLE
    call GetStdHandle
    mov hConsoleIn, eax
    
    call ShowBanner
    
    ; Initialize hook engine
    call InitializeHookEngine
    test eax, eax
    jz @InitFailed
    push OFFSET szInitOK
    call PrintString
    jmp @MainLoop

@InitFailed:
    push OFFSET szInitFail
    call PrintString
    jmp @Exit

@MainLoop:
    call ShowMenu
    call ReadInput
    
    ; Parse choice
    lea esi, szInputBuffer
    movzx eax, BYTE PTR [esi]
    sub eax, '0'
    mov dwChoice, eax
    
    ; Handle choice
    cmp dwChoice, 1
    jne @NotInstall
    call InstallMessageBoxHook
    test eax, eax
    jz @MainLoop
    mov g_bHookActive, 1
    push OFFSET szHookOn
    call PrintString
    jmp @MainLoop

@NotInstall:
    cmp dwChoice, 2
    jne @NotRemove
    call RemoveMessageBoxHook
    mov g_bHookActive, 0
    push OFFSET szHookOff
    call PrintString
    jmp @MainLoop

@NotRemove:
    cmp dwChoice, 3
    jne @NotTest
    push OFFSET szTest
    call PrintString
    push MB_OK or MB_ICONINFORMATION
    push OFFSET szTestTitle
    push OFFSET szTestText
    push 0
    call MessageBoxA
    jmp @MainLoop

@NotTest:
    cmp dwChoice, 4
    jne @NotStats
    push OFFSET szStatsHeader
    call PrintString
    push OFFSET szStatsCount
    call PrintString
    lea eax, dwInterceptCount
    push eax
    call GetMessageBoxHookStats
    push dwInterceptCount
    call PrintNumber
    push OFFSET szNewLine
    call PrintString
    jmp @MainLoop

@NotStats:
    cmp dwChoice, 5
    jne @Invalid
    jmp @Cleanup

@Invalid:
    push OFFSET szInvalid
    call PrintString
    jmp @MainLoop

@Cleanup:
    push OFFSET szExiting
    call PrintString
    
    cmp g_bHookActive, 0
    je @SkipRemove
    call RemoveMessageBoxHook
@SkipRemove:
    
    call ShutdownHookEngine
    
    push OFFSET szGoodbye
    call PrintString

@Exit:
    push 0
    call ExitProcess
main ENDP

END main
