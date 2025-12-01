;===============================================================================
; STEALTH INTERCEPTOR - Main Demo Application
;===============================================================================
; File:        demo_main.asm
; Description: Interactive demonstration of the API Hooking Engine
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
include \masm32\include\msvcrt.inc
includelib \masm32\lib\kernel32.lib
includelib \masm32\lib\user32.lib
includelib \masm32\lib\msvcrt.lib

;===============================================================================
; External Procedures
;===============================================================================
; Hook Engine
EXTERN InitializeHookEngine:PROC
EXTERN ShutdownHookEngine:PROC
EXTERN GetHookCount:PROC

; MessageBox Hooks
EXTERN InstallMessageBoxHook:PROC
EXTERN RemoveMessageBoxHook:PROC
EXTERN GetMessageBoxHookStats:PROC
EXTERN IsMessageBoxHookActive:PROC

; File Hooks
EXTERN InstallFileHooks:PROC
EXTERN RemoveFileHooks:PROC
EXTERN GetFileHookStats:PROC

; Network Hooks
EXTERN InstallNetworkHooks:PROC
EXTERN RemoveNetworkHooks:PROC
EXTERN GetNetworkHookStats:PROC

; Process Hooks
EXTERN InstallProcessHooks:PROC
EXTERN RemoveProcessHooks:PROC
EXTERN GetProcessHookStats:PROC

; Logging
EXTERN InitializeLogging:PROC
EXTERN ShutdownLogging:PROC
EXTERN LogMessage:PROC

;===============================================================================
; Constants
;===============================================================================
MAX_INPUT_LEN EQU 256

; Menu options
MENU_MSGBOX_HOOK   EQU 1
MENU_FILE_HOOK     EQU 2
MENU_NET_HOOK      EQU 3
MENU_PROC_HOOK     EQU 4
MENU_TEST_MSGBOX   EQU 5
MENU_SHOW_STATS    EQU 6
MENU_REMOVE_ALL    EQU 7
MENU_EXIT          EQU 8

;===============================================================================
; Data Section
;===============================================================================
.data
    ; Application info
    szAppTitle      BYTE "The Stealth Interceptor - API Hooking Engine Demo", 0
    szAppVersion    BYTE "Version 1.0.0", 0
    szCopyright     BYTE "By Muhammad Adeel Haider (241541) & Umar Farooq (241575)", 0
    szCourse        BYTE "COAL - 5th Semester, BS Cyber Security", 0
    
    ; Banner
    szBanner1       BYTE 13, 10, "====================================================", 13, 10, 0
    szBanner2       BYTE "  THE STEALTH INTERCEPTOR - API Hooking Engine", 13, 10, 0
    szBanner3       BYTE "  Version 1.0.0 - Educational Demo", 13, 10, 0
    szBanner4       BYTE "====================================================", 13, 10, 0
    szBanner5       BYTE "  By: Muhammad Adeel Haider & Umar Farooq", 13, 10, 0
    szBanner6       BYTE "  Course: COAL - 5th Semester, BS Cyber Security", 13, 10, 0
    szBannerLine    BYTE "====================================================", 13, 10, 13, 10, 0
    
    ; Menu strings
    szMenuHeader    BYTE 13, 10, "--- Main Menu ---", 13, 10, 0
    szMenu1         BYTE "1. Install/Remove MessageBox Hook", 13, 10, 0
    szMenu2         BYTE "2. Install/Remove File Hooks", 13, 10, 0
    szMenu3         BYTE "3. Install/Remove Network Hooks", 13, 10, 0
    szMenu4         BYTE "4. Install/Remove Process Hooks", 13, 10, 0
    szMenu5         BYTE "5. Test MessageBox (Trigger Hook)", 13, 10, 0
    szMenu6         BYTE "6. Show Hook Statistics", 13, 10, 0
    szMenu7         BYTE "7. Remove All Hooks", 13, 10, 0
    szMenu8         BYTE "8. Exit", 13, 10, 0
    szMenuPrompt    BYTE 13, 10, "Enter your choice (1-8): ", 0
    
    ; Status messages
    szHookEngineInit    BYTE "[+] Hook Engine initialized successfully!", 13, 10, 0
    szHookEngineFail    BYTE "[-] Failed to initialize Hook Engine!", 13, 10, 0
    szLoggingInit       BYTE "[+] Logging system initialized!", 13, 10, 0
    
    ; MessageBox hook messages
    szMsgBoxHookOn      BYTE "[+] MessageBox hook INSTALLED", 13, 10, 0
    szMsgBoxHookOff     BYTE "[+] MessageBox hook REMOVED", 13, 10, 0
    szMsgBoxHookFail    BYTE "[-] Failed to install MessageBox hook", 13, 10, 0
    szMsgBoxHookStatus  BYTE "    Status: ", 0
    szActive            BYTE "ACTIVE", 13, 10, 0
    szInactive          BYTE "INACTIVE", 13, 10, 0
    
    ; File hook messages
    szFileHookOn        BYTE "[+] File hooks INSTALLED", 13, 10, 0
    szFileHookOff       BYTE "[+] File hooks REMOVED", 13, 10, 0
    
    ; Network hook messages
    szNetHookOn         BYTE "[+] Network hooks INSTALLED", 13, 10, 0
    szNetHookOff        BYTE "[+] Network hooks REMOVED", 13, 10, 0
    szNetHookFail       BYTE "[-] Failed to install Network hooks (ws2_32.dll may not be loaded)", 13, 10, 0
    
    ; Process hook messages
    szProcHookOn        BYTE "[+] Process hooks INSTALLED", 13, 10, 0
    szProcHookOff       BYTE "[+] Process hooks REMOVED", 13, 10, 0
    
    ; Test messages
    szTestMsgBox        BYTE "[*] Testing MessageBox - Watch for interception!", 13, 10, 0
    szTestMsgBoxTitle   BYTE "Test MessageBox", 0
    szTestMsgBoxText    BYTE "This is a test message. If the hook is active, this call was intercepted and logged!", 0
    
    ; Statistics header
    szStatsHeader       BYTE 13, 10, "--- Hook Statistics ---", 13, 10, 0
    szStatsMsgBox       BYTE "MessageBox Hook: ", 0
    szStatsFile         BYTE "File Hooks: ", 0
    szStatsNetwork      BYTE "Network Hooks: ", 0
    szStatsProcess      BYTE "Process Hooks: ", 0
    szStatsIntercepts   BYTE "    Interceptions: ", 0
    szStatsCreate       BYTE "    CreateFile: ", 0
    szStatsRead         BYTE "    ReadFile: ", 0
    szStatsWrite        BYTE "    WriteFile: ", 0
    szStatsSocket       BYTE "    Socket: ", 0
    szStatsConnect      BYTE "    Connect: ", 0
    szStatsBytesSent    BYTE "    Bytes Sent: ", 0
    szStatsBytesRecv    BYTE "    Bytes Recv: ", 0
    szStatsCreateProc   BYTE "    CreateProcess: ", 0
    szStatsTermProc     BYTE "    TerminateProcess: ", 0
    szStatsOpenProc     BYTE "    OpenProcess: ", 0
    
    ; Other messages
    szRemovedAll        BYTE "[+] All hooks removed!", 13, 10, 0
    szExiting           BYTE 13, 10, "[*] Shutting down and cleaning up...", 13, 10, 0
    szGoodbye           BYTE "[*] Thank you for using Stealth Interceptor!", 13, 10, 0
    szInvalidChoice     BYTE "[-] Invalid choice. Please try again.", 13, 10, 0
    szPressEnter        BYTE 13, 10, "Press Enter to continue...", 0
    szNewLine           BYTE 13, 10, 0
    szSpace             BYTE " ", 0
    
    ; Format strings
    szFmtDecimal        BYTE "%d", 0
    szFmtString         BYTE "%s", 0
    
    ; State tracking
    g_bMsgBoxHookActive DWORD 0
    g_bFileHookActive   DWORD 0
    g_bNetHookActive    DWORD 0
    g_bProcHookActive   DWORD 0

.data?
    hConsoleOut     DWORD ?
    hConsoleIn      DWORD ?
    dwBytesWritten  DWORD ?
    dwBytesRead     DWORD ?
    szInputBuffer   BYTE MAX_INPUT_LEN DUP(?)
    szNumberBuffer  BYTE 16 DUP(?)
    
    ; Statistics
    dwMsgBoxCount   DWORD ?
    dwBlockedCount  DWORD ?
    dwCreateCount   DWORD ?
    dwReadCount     DWORD ?
    dwWriteCount    DWORD ?
    dwDeleteCount   DWORD ?
    dwSocketCount   DWORD ?
    dwConnectCount  DWORD ?
    dwBytesSent     DWORD ?
    dwBytesRecv     DWORD ?
    dwCreateProc    DWORD ?
    dwTermProc      DWORD ?
    dwOpenProc      DWORD ?

;===============================================================================
; Code Section
;===============================================================================
.code

;-------------------------------------------------------------------------------
; PrintString - Outputs a string to console
;-------------------------------------------------------------------------------
PrintString PROC lpszString:DWORD
    pushad
    
    ; Get string length
    mov edi, lpszString
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
    push lpszString
    push hConsoleOut
    call WriteConsoleA
    
    popad
    ret
PrintString ENDP

;-------------------------------------------------------------------------------
; PrintNumber - Outputs a number to console
;-------------------------------------------------------------------------------
PrintNumber PROC dwValue:DWORD
    LOCAL dwTemp:DWORD
    pushad
    
    lea edi, szNumberBuffer
    mov eax, dwValue
    xor ecx, ecx
    mov ebx, 10
    
    ; Handle zero
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
    
    ; Calculate length
    lea eax, szNumberBuffer
    mov ecx, edi
    sub ecx, eax
    
    ; Write
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
; ReadInput - Reads a line from console
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
    
    ; Remove CR/LF
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
; ShowBanner - Displays the application banner
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
    push OFFSET szBannerLine
    call PrintString
    ret
ShowBanner ENDP

;-------------------------------------------------------------------------------
; ShowMenu - Displays the main menu
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
    push OFFSET szMenu6
    call PrintString
    push OFFSET szMenu7
    call PrintString
    push OFFSET szMenu8
    call PrintString
    push OFFSET szMenuPrompt
    call PrintString
    ret
ShowMenu ENDP

;-------------------------------------------------------------------------------
; ToggleMessageBoxHook
;-------------------------------------------------------------------------------
ToggleMessageBoxHook PROC
    cmp g_bMsgBoxHookActive, 0
    jne @RemoveHook
    
    ; Install hook
    call InstallMessageBoxHook
    test eax, eax
    jz @Failed
    mov g_bMsgBoxHookActive, 1
    push OFFSET szMsgBoxHookOn
    call PrintString
    ret

@RemoveHook:
    call RemoveMessageBoxHook
    mov g_bMsgBoxHookActive, 0
    push OFFSET szMsgBoxHookOff
    call PrintString
    ret

@Failed:
    push OFFSET szMsgBoxHookFail
    call PrintString
    ret
ToggleMessageBoxHook ENDP

;-------------------------------------------------------------------------------
; ToggleFileHooks
;-------------------------------------------------------------------------------
ToggleFileHooks PROC
    cmp g_bFileHookActive, 0
    jne @RemoveHook
    
    call InstallFileHooks
    test eax, eax
    jz @Failed
    mov g_bFileHookActive, 1
    push OFFSET szFileHookOn
    call PrintString
    ret

@RemoveHook:
    call RemoveFileHooks
    mov g_bFileHookActive, 0
    push OFFSET szFileHookOff
    call PrintString
    ret

@Failed:
    ret
ToggleFileHooks ENDP

;-------------------------------------------------------------------------------
; ToggleNetworkHooks
;-------------------------------------------------------------------------------
ToggleNetworkHooks PROC
    cmp g_bNetHookActive, 0
    jne @RemoveHook
    
    call InstallNetworkHooks
    test eax, eax
    jz @Failed
    mov g_bNetHookActive, 1
    push OFFSET szNetHookOn
    call PrintString
    ret

@RemoveHook:
    call RemoveNetworkHooks
    mov g_bNetHookActive, 0
    push OFFSET szNetHookOff
    call PrintString
    ret

@Failed:
    push OFFSET szNetHookFail
    call PrintString
    ret
ToggleNetworkHooks ENDP

;-------------------------------------------------------------------------------
; ToggleProcessHooks
;-------------------------------------------------------------------------------
ToggleProcessHooks PROC
    cmp g_bProcHookActive, 0
    jne @RemoveHook
    
    call InstallProcessHooks
    test eax, eax
    jz @Failed
    mov g_bProcHookActive, 1
    push OFFSET szProcHookOn
    call PrintString
    ret

@RemoveHook:
    call RemoveProcessHooks
    mov g_bProcHookActive, 0
    push OFFSET szProcHookOff
    call PrintString
    ret

@Failed:
    ret
ToggleProcessHooks ENDP

;-------------------------------------------------------------------------------
; TestMessageBox
;-------------------------------------------------------------------------------
TestMessageBox PROC
    push OFFSET szTestMsgBox
    call PrintString
    
    push MB_OK or MB_ICONINFORMATION
    push OFFSET szTestMsgBoxTitle
    push OFFSET szTestMsgBoxText
    push 0
    call MessageBoxA
    ret
TestMessageBox ENDP

;-------------------------------------------------------------------------------
; ShowStatistics
;-------------------------------------------------------------------------------
ShowStatistics PROC
    push OFFSET szStatsHeader
    call PrintString
    
    ; MessageBox stats
    push OFFSET szStatsMsgBox
    call PrintString
    cmp g_bMsgBoxHookActive, 0
    je @MsgBoxInactive
    push OFFSET szActive
    call PrintString
    jmp @MsgBoxDone
@MsgBoxInactive:
    push OFFSET szInactive
    call PrintString
@MsgBoxDone:
    
    cmp g_bMsgBoxHookActive, 0
    je @SkipMsgBoxStats
    push OFFSET szStatsIntercepts
    call PrintString
    lea eax, dwBlockedCount
    push eax
    lea eax, dwMsgBoxCount
    push eax
    call GetMessageBoxHookStats
    push dwMsgBoxCount
    call PrintNumber
    push OFFSET szNewLine
    call PrintString
@SkipMsgBoxStats:
    
    ; File hook stats
    push OFFSET szStatsFile
    call PrintString
    cmp g_bFileHookActive, 0
    je @FileInactive
    push OFFSET szActive
    call PrintString
    
    push OFFSET szStatsCreate
    call PrintString
    lea eax, dwDeleteCount
    push eax
    lea eax, dwWriteCount
    push eax
    lea eax, dwReadCount
    push eax
    lea eax, dwCreateCount
    push eax
    call GetFileHookStats
    push dwCreateCount
    call PrintNumber
    push OFFSET szNewLine
    call PrintString
    
    push OFFSET szStatsRead
    call PrintString
    push dwReadCount
    call PrintNumber
    push OFFSET szNewLine
    call PrintString
    
    push OFFSET szStatsWrite
    call PrintString
    push dwWriteCount
    call PrintNumber
    push OFFSET szNewLine
    call PrintString
    jmp @FileDone
@FileInactive:
    push OFFSET szInactive
    call PrintString
@FileDone:
    
    ; Network hook stats
    push OFFSET szStatsNetwork
    call PrintString
    cmp g_bNetHookActive, 0
    je @NetInactive
    push OFFSET szActive
    call PrintString
    
    push OFFSET szStatsSocket
    call PrintString
    lea eax, dwBytesRecv
    push eax
    lea eax, dwBytesSent
    push eax
    lea eax, dwConnectCount
    push eax
    lea eax, dwSocketCount
    push eax
    call GetNetworkHookStats
    push dwSocketCount
    call PrintNumber
    push OFFSET szNewLine
    call PrintString
    
    push OFFSET szStatsConnect
    call PrintString
    push dwConnectCount
    call PrintNumber
    push OFFSET szNewLine
    call PrintString
    
    push OFFSET szStatsBytesSent
    call PrintString
    push dwBytesSent
    call PrintNumber
    push OFFSET szNewLine
    call PrintString
    
    push OFFSET szStatsBytesRecv
    call PrintString
    push dwBytesRecv
    call PrintNumber
    push OFFSET szNewLine
    call PrintString
    jmp @NetDone
@NetInactive:
    push OFFSET szInactive
    call PrintString
@NetDone:
    
    ; Process hook stats
    push OFFSET szStatsProcess
    call PrintString
    cmp g_bProcHookActive, 0
    je @ProcInactive
    push OFFSET szActive
    call PrintString
    
    push OFFSET szStatsCreateProc
    call PrintString
    lea eax, dwBlockedCount
    push eax
    lea eax, dwOpenProc
    push eax
    lea eax, dwTermProc
    push eax
    lea eax, dwCreateProc
    push eax
    call GetProcessHookStats
    push dwCreateProc
    call PrintNumber
    push OFFSET szNewLine
    call PrintString
    
    push OFFSET szStatsTermProc
    call PrintString
    push dwTermProc
    call PrintNumber
    push OFFSET szNewLine
    call PrintString
    
    push OFFSET szStatsOpenProc
    call PrintString
    push dwOpenProc
    call PrintNumber
    push OFFSET szNewLine
    call PrintString
    jmp @ProcDone
@ProcInactive:
    push OFFSET szInactive
    call PrintString
@ProcDone:
    ret
ShowStatistics ENDP

;-------------------------------------------------------------------------------
; RemoveAllHooks
;-------------------------------------------------------------------------------
RemoveAllHooksProc PROC
    cmp g_bMsgBoxHookActive, 0
    je @Skip1
    call RemoveMessageBoxHook
    mov g_bMsgBoxHookActive, 0
@Skip1:
    
    cmp g_bFileHookActive, 0
    je @Skip2
    call RemoveFileHooks
    mov g_bFileHookActive, 0
@Skip2:
    
    cmp g_bNetHookActive, 0
    je @Skip3
    call RemoveNetworkHooks
    mov g_bNetHookActive, 0
@Skip3:
    
    cmp g_bProcHookActive, 0
    je @Skip4
    call RemoveProcessHooks
    mov g_bProcHookActive, 0
@Skip4:
    
    push OFFSET szRemovedAll
    call PrintString
    ret
RemoveAllHooksProc ENDP

;-------------------------------------------------------------------------------
; WaitForEnter
;-------------------------------------------------------------------------------
WaitForEnter PROC
    push OFFSET szPressEnter
    call PrintString
    call ReadInput
    ret
WaitForEnter ENDP

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
    
    ; Show banner
    call ShowBanner
    
    ; Initialize hook engine
    call InitializeHookEngine
    test eax, eax
    jz @InitFailed
    push OFFSET szHookEngineInit
    call PrintString
    jmp @MainLoop

@InitFailed:
    push OFFSET szHookEngineFail
    call PrintString
    jmp @Exit

@MainLoop:
    ; Show menu
    call ShowMenu
    
    ; Get user input
    call ReadInput
    
    ; Parse choice
    lea esi, szInputBuffer
    movzx eax, BYTE PTR [esi]
    sub eax, '0'
    mov dwChoice, eax
    
    ; Handle choice
    cmp dwChoice, MENU_MSGBOX_HOOK
    jne @NotMsgBox
    call ToggleMessageBoxHook
    jmp @MainLoop

@NotMsgBox:
    cmp dwChoice, MENU_FILE_HOOK
    jne @NotFile
    call ToggleFileHooks
    jmp @MainLoop

@NotFile:
    cmp dwChoice, MENU_NET_HOOK
    jne @NotNet
    call ToggleNetworkHooks
    jmp @MainLoop

@NotNet:
    cmp dwChoice, MENU_PROC_HOOK
    jne @NotProc
    call ToggleProcessHooks
    jmp @MainLoop

@NotProc:
    cmp dwChoice, MENU_TEST_MSGBOX
    jne @NotTest
    call TestMessageBox
    jmp @MainLoop

@NotTest:
    cmp dwChoice, MENU_SHOW_STATS
    jne @NotStats
    call ShowStatistics
    call WaitForEnter
    jmp @MainLoop

@NotStats:
    cmp dwChoice, MENU_REMOVE_ALL
    jne @NotRemove
    call RemoveAllHooksProc
    jmp @MainLoop

@NotRemove:
    cmp dwChoice, MENU_EXIT
    jne @Invalid
    jmp @Cleanup

@Invalid:
    push OFFSET szInvalidChoice
    call PrintString
    jmp @MainLoop

@Cleanup:
    push OFFSET szExiting
    call PrintString
    
    ; Remove all hooks
    call RemoveAllHooksProc
    
    ; Shutdown hook engine
    call ShutdownHookEngine
    
    push OFFSET szGoodbye
    call PrintString

@Exit:
    push 0
    call ExitProcess
main ENDP

END main
