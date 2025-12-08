;===============================================================================
; MINI STEALTH INTERCEPTOR - Main Demo (NASM)
;===============================================================================
; File:        demo_main_nasm.asm
; Description: Simplified demonstration (NASM syntax)
; Authors:     Muhammad Adeel Haider (241541), Umar Farooq (241575)
; Course:      COAL - 5th Semester, BS Cyber Security
;===============================================================================

bits 32

; Constants
MAX_INPUT_LEN       equ 256
STD_OUTPUT_HANDLE   equ -11
STD_INPUT_HANDLE    equ -10
MB_OK               equ 0x00000000
MB_ICONINFORMATION  equ 0x00000040

section .data
    ; Banner
    szBanner1       db 13, 10, "==========================================", 13, 10, 0
    szBanner2       db "  MINI STEALTH INTERCEPTOR", 13, 10, 0
    szBanner3       db "  Simplified API Hooking Demo", 13, 10, 0
    szBanner4       db "==========================================", 13, 10, 0
    szBanner5       db "  By: Muhammad Adeel Haider (241541)", 13, 10, 0
    szBanner6       db "      Umar Farooq (241575)", 13, 10, 0
    szBanner7       db "  COAL - BS Cyber Security", 13, 10, 0
    szBannerLine    db "==========================================", 13, 10, 13, 10, 0
    
    ; Menu
    szMenuHeader    db 13, 10, "--- Main Menu ---", 13, 10, 0
    szMenu1         db "1. Install MessageBox Hook", 13, 10, 0
    szMenu2         db "2. Remove MessageBox Hook", 13, 10, 0
    szMenu3         db "3. Test MessageBox", 13, 10, 0
    szMenu4         db "4. Show Statistics", 13, 10, 0
    szMenu5         db "5. Exit", 13, 10, 0
    szMenuPrompt    db 13, 10, "Choose (1-5): ", 0
    
    ; Messages
    szInitOK        db "[+] Hook Engine initialized!", 13, 10, 0
    szInitFail      db "[-] Failed to initialize!", 13, 10, 0
    szHookOn        db "[+] MessageBox hook INSTALLED", 13, 10, 0
    szHookOff       db "[+] MessageBox hook REMOVED", 13, 10, 0
    szTest          db "[*] Testing MessageBox...", 13, 10, 0
    szTestTitle     db "Mini Interceptor Test", 0
    szTestText      db "If hook is active, this will be intercepted!", 0
    szStatsHeader   db 13, 10, "--- Statistics ---", 13, 10, 0
    szStatsCount    db "Interceptions: ", 0
    szExiting       db 13, 10, "[*] Cleaning up...", 13, 10, 0
    szGoodbye       db "Goodbye!", 13, 10, 0
    szInvalid       db "[-] Invalid choice!", 13, 10, 0
    szNewLine       db 13, 10, 0
    
    g_bHookActive   dd 0
    
section .bss
    hConsoleOut     resd 1
    hConsoleIn      resd 1
    dwBytesWritten  resd 1
    dwBytesRead     resd 1
    szInputBuffer   resb MAX_INPUT_LEN
    szNumberBuffer  resb 16
    dwInterceptCount resd 1
    dwChoice        resd 1

section .text
global _main

extern _InitializeHookEngine@0
extern _ShutdownHookEngine@0
extern _InstallMessageBoxHook@0
extern _RemoveMessageBoxHook@0
extern _GetMessageBoxHookStats@4
extern _GetStdHandle@4
extern _WriteConsoleA@20
extern _ReadConsoleA@20
extern _MessageBoxA@16
extern _ExitProcess@4

;-------------------------------------------------------------------------------
; PrintString - Output string to console
;-------------------------------------------------------------------------------
PrintString:
    push ebp
    mov ebp, esp
    pushad
    
    ; Get length
    mov edi, [ebp+8]
    xor ecx, ecx
.CountLen:
    cmp byte [edi+ecx], 0
    je .LenDone
    inc ecx
    jmp .CountLen
.LenDone:
    
    ; Write
    push 0
    push dwBytesWritten
    push ecx
    push dword [ebp+8]
    push dword [hConsoleOut]
    call _WriteConsoleA@20
    
    popad
    pop ebp
    ret 4

;-------------------------------------------------------------------------------
; PrintNumber - Output number to console
;-------------------------------------------------------------------------------
PrintNumber:
    push ebp
    mov ebp, esp
    pushad
    
    mov edi, szNumberBuffer
    mov eax, [ebp+8]
    xor ecx, ecx
    mov ebx, 10
    
    test eax, eax
    jnz .ConvertLoop
    mov byte [edi], '0'
    inc edi
    jmp .PrintNum
    
.ConvertLoop:
    test eax, eax
    jz .Reverse
    xor edx, edx
    div ebx
    add dl, '0'
    push edx
    inc ecx
    jmp .ConvertLoop
    
.Reverse:
    test ecx, ecx
    jz .PrintNum
    pop edx
    mov [edi], dl
    inc edi
    dec ecx
    jmp .Reverse

.PrintNum:
    mov byte [edi], 0
    
    mov eax, szNumberBuffer
    mov ecx, edi
    sub ecx, eax
    
    push 0
    push dwBytesWritten
    push ecx
    push szNumberBuffer
    push dword [hConsoleOut]
    call _WriteConsoleA@20
    
    popad
    pop ebp
    ret 4

;-------------------------------------------------------------------------------
; ReadInput - Read line from console
;-------------------------------------------------------------------------------
ReadInput:
    pushad
    
    push 0
    push dwBytesRead
    push MAX_INPUT_LEN
    push szInputBuffer
    push dword [hConsoleIn]
    call _ReadConsoleA@20
    
    ; Null-terminate and strip newline
    mov ecx, [dwBytesRead]
    mov edi, szInputBuffer
    mov byte [edi+ecx], 0
    
    dec ecx
    cmp byte [edi+ecx], 10
    jne .NoLF
    mov byte [edi+ecx], 0
    dec ecx
.NoLF:
    cmp ecx, 0
    jl .Done
    cmp byte [edi+ecx], 13
    jne .Done
    mov byte [edi+ecx], 0

.Done:
    popad
    ret

;-------------------------------------------------------------------------------
; ShowBanner - Display banner
;-------------------------------------------------------------------------------
ShowBanner:
    push szBanner1
    call PrintString
    push szBanner2
    call PrintString
    push szBanner3
    call PrintString
    push szBanner4
    call PrintString
    push szBanner5
    call PrintString
    push szBanner6
    call PrintString
    push szBanner7
    call PrintString
    push szBannerLine
    call PrintString
    ret

;-------------------------------------------------------------------------------
; ShowMenu - Display menu
;-------------------------------------------------------------------------------
ShowMenu:
    push szMenuHeader
    call PrintString
    push szMenu1
    call PrintString
    push szMenu2
    call PrintString
    push szMenu3
    call PrintString
    push szMenu4
    call PrintString
    push szMenu5
    call PrintString
    push szMenuPrompt
    call PrintString
    ret

;-------------------------------------------------------------------------------
; Main - Entry point
;-------------------------------------------------------------------------------
_main:
    ; Get console handles
    push STD_OUTPUT_HANDLE
    call _GetStdHandle@4
    mov [hConsoleOut], eax
    
    push STD_INPUT_HANDLE
    call _GetStdHandle@4
    mov [hConsoleIn], eax
    
    call ShowBanner
    
    ; Initialize hook engine
    call _InitializeHookEngine@0
    test eax, eax
    jz .InitFailed
    push szInitOK
    call PrintString
    jmp .MainLoop

.InitFailed:
    push szInitFail
    call PrintString
    jmp .Exit

.MainLoop:
    call ShowMenu
    call ReadInput
    
    ; Parse choice
    mov esi, szInputBuffer
    movzx eax, byte [esi]
    sub eax, '0'
    mov [dwChoice], eax
    
    ; Handle choice
    cmp dword [dwChoice], 1
    jne .NotInstall
    call _InstallMessageBoxHook@0
    test eax, eax
    jz .MainLoop
    mov dword [g_bHookActive], 1
    push szHookOn
    call PrintString
    jmp .MainLoop

.NotInstall:
    cmp dword [dwChoice], 2
    jne .NotRemove
    call _RemoveMessageBoxHook@0
    mov dword [g_bHookActive], 0
    push szHookOff
    call PrintString
    jmp .MainLoop

.NotRemove:
    cmp dword [dwChoice], 3
    jne .NotTest
    push szTest
    call PrintString
    push MB_OK | MB_ICONINFORMATION
    push szTestTitle
    push szTestText
    push 0
    call _MessageBoxA@16
    jmp .MainLoop

.NotTest:
    cmp dword [dwChoice], 4
    jne .NotStats
    push szStatsHeader
    call PrintString
    push szStatsCount
    call PrintString
    push dwInterceptCount
    call _GetMessageBoxHookStats@4
    push dword [dwInterceptCount]
    call PrintNumber
    push szNewLine
    call PrintString
    jmp .MainLoop

.NotStats:
    cmp dword [dwChoice], 5
    jne .Invalid
    jmp .Cleanup

.Invalid:
    push szInvalid
    call PrintString
    jmp .MainLoop

.Cleanup:
    push szExiting
    call PrintString
    
    cmp dword [g_bHookActive], 0
    je .SkipRemove
    call _RemoveMessageBoxHook@0
.SkipRemove:
    
    call _ShutdownHookEngine@0
    
    push szGoodbye
    call PrintString

.Exit:
    push 0
    call _ExitProcess@4
