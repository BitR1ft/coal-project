# Session 10: Hooking MessageBoxA - Complete Implementation

## 🎯 Learning Objectives

By the end of this session, you will:
- Implement a complete, working MessageBoxA hook
- Log all MessageBox calls with parameters
- Handle both MessageBoxA and MessageBoxW
- Create a professional-quality hook

---

## 📚 Part 1: Complete MessageBoxA Hook

### The Complete Implementation

```asm
;===============================================================================
; messagebox_hook.asm
; Complete MessageBoxA hook with logging
;===============================================================================

.686
.model flat, stdcall
option casemap:none

include \masm32\include\windows.inc
include \masm32\include\kernel32.inc
include \masm32\include\user32.inc
includelib \masm32\lib\kernel32.lib
includelib \masm32\lib\user32.lib

;===============================================================================
; Constants
;===============================================================================
TRAMPOLINE_SIZE     EQU 32
MAX_LOG_LENGTH      EQU 512

;===============================================================================
; Data Section
;===============================================================================
.data
    ; DLL and function names
    szUser32        db "user32.dll", 0
    szMsgBoxA       db "MessageBoxA", 0
    szMsgBoxW       db "MessageBoxW", 0
    
    ; Debug output format strings
    szLogHeader     db "═══════════════════════════════════════════════════════", 13, 10, 0
    szLogPrefix     db "[MessageBoxA Hook] ", 0
    szLogText       db "  Text: ", 0
    szLogCaption    db "  Caption: ", 0
    szLogType       db "  Type: 0x", 0
    szLogCount      db "  Call #", 0
    szLogResult     db "  Result: ", 0
    szLogNewline    db 13, 10, 0
    szNull          db "(null)", 0
    
    ; Result strings
    szIDOK          db "IDOK", 0
    szIDCANCEL      db "IDCANCEL", 0
    szIDABORT       db "IDABORT", 0
    szIDRETRY       db "IDRETRY", 0
    szIDIGNORE      db "IDIGNORE", 0
    szIDYES         db "IDYES", 0
    szIDNO          db "IDNO", 0
    szUnknown       db "Unknown", 0
    
    ; Hook state
    hUser32         dd 0
    pOrigMsgBoxA    dd 0
    pOrigMsgBoxW    dd 0
    pTrampolineA    dd 0
    pTrampolineW    dd 0
    bOrigBytesA     db 16 dup(0)
    bOrigBytesW     db 16 dup(0)
    dwOldProtect    dd 0
    
    ; Statistics
    dwCallCountA    dd 0
    dwCallCountW    dd 0
    
    ; Flags
    bHookInstalledA db 0
    bHookInstalledW db 0

;===============================================================================
; Code Section
;===============================================================================
.code

;-------------------------------------------------------------------------------
; LogString - Output a string to debug output
;-------------------------------------------------------------------------------
LogString PROC pString:DWORD
    push pString
    call OutputDebugStringA
    ret
LogString ENDP

;-------------------------------------------------------------------------------
; LogDword - Output a DWORD in hex
;-------------------------------------------------------------------------------
LogDword PROC dwValue:DWORD
    LOCAL szBuffer[16]:BYTE
    
    pushad
    
    ; Simple hex conversion (would use wsprintfA for production)
    lea edi, szBuffer
    mov eax, dwValue
    
    ; Convert to hex string (8 digits)
    mov ecx, 8
@loop:
    rol eax, 4
    mov bl, al
    and bl, 0Fh
    cmp bl, 10
    jl @digit
    add bl, 'A' - 10
    jmp @store
@digit:
    add bl, '0'
@store:
    mov [edi], bl
    inc edi
    loop @loop
    
    mov BYTE PTR [edi], 0
    
    lea eax, szBuffer
    push eax
    call OutputDebugStringA
    
    popad
    ret
LogDword ENDP

;-------------------------------------------------------------------------------
; GetResultString - Get string for MessageBox result
;-------------------------------------------------------------------------------
GetResultString PROC dwResult:DWORD
    mov eax, dwResult
    
    cmp eax, IDOK
    jne @notOK
    mov eax, OFFSET szIDOK
    ret
@notOK:
    cmp eax, IDCANCEL
    jne @notCancel
    mov eax, OFFSET szIDCANCEL
    ret
@notCancel:
    cmp eax, IDYES
    jne @notYes
    mov eax, OFFSET szIDYES
    ret
@notYes:
    cmp eax, IDNO
    jne @notNo
    mov eax, OFFSET szIDNO
    ret
@notNo:
    cmp eax, IDABORT
    jne @notAbort
    mov eax, OFFSET szIDABORT
    ret
@notAbort:
    cmp eax, IDRETRY
    jne @notRetry
    mov eax, OFFSET szIDRETRY
    ret
@notRetry:
    cmp eax, IDIGNORE
    jne @notIgnore
    mov eax, OFFSET szIDIGNORE
    ret
@notIgnore:
    mov eax, OFFSET szUnknown
    ret
GetResultString ENDP

;-------------------------------------------------------------------------------
; MessageBoxAHookHandler - Our hook handler for MessageBoxA
;-------------------------------------------------------------------------------
MessageBoxAHookHandler PROC
    ; Parameters on stack:
    ; [ESP+4]  = hWnd
    ; [ESP+8]  = lpText
    ; [ESP+12] = lpCaption
    ; [ESP+16] = uType
    
    ; Set up frame
    push ebp
    mov ebp, esp
    sub esp, 8              ; Local storage
    
    ; Save registers
    push eax
    push ebx
    push ecx
    push edx
    
    ;═══════════════════════════════════════════════════════════════
    ; PRE-CALL LOGGING
    ;═══════════════════════════════════════════════════════════════
    
    ; Increment counter
    inc dwCallCountA
    
    ; Log header
    push OFFSET szLogHeader
    call LogString
    
    ; Log prefix
    push OFFSET szLogPrefix
    call LogString
    
    push OFFSET szLogNewline
    call LogString
    
    ; Log call count
    push OFFSET szLogCount
    call LogString
    push dwCallCountA
    call LogDword
    push OFFSET szLogNewline
    call LogString
    
    ; Log lpText
    push OFFSET szLogText
    call LogString
    mov eax, [ebp+12]       ; lpText
    test eax, eax
    jnz @hasText
    mov eax, OFFSET szNull
@hasText:
    push eax
    call LogString
    push OFFSET szLogNewline
    call LogString
    
    ; Log lpCaption
    push OFFSET szLogCaption
    call LogString
    mov eax, [ebp+16]       ; lpCaption
    test eax, eax
    jnz @hasCaption
    mov eax, OFFSET szNull
@hasCaption:
    push eax
    call LogString
    push OFFSET szLogNewline
    call LogString
    
    ; Log uType
    push OFFSET szLogType
    call LogString
    push [ebp+20]
    call LogDword
    push OFFSET szLogNewline
    call LogString
    
    ;═══════════════════════════════════════════════════════════════
    ; CALL ORIGINAL FUNCTION
    ;═══════════════════════════════════════════════════════════════
    
    ; Restore registers for the call
    pop edx
    pop ecx
    pop ebx
    pop eax
    
    ; Push parameters for trampoline call
    push [ebp+20]           ; uType
    push [ebp+16]           ; lpCaption
    push [ebp+12]           ; lpText
    push [ebp+8]            ; hWnd
    call pTrampolineA       ; Call original via trampoline
    
    ; Save return value
    mov [ebp-4], eax
    
    ;═══════════════════════════════════════════════════════════════
    ; POST-CALL LOGGING
    ;═══════════════════════════════════════════════════════════════
    
    ; Log result
    push OFFSET szLogResult
    call LogString
    
    push [ebp-4]
    call GetResultString
    push eax
    call LogString
    
    push OFFSET szLogNewline
    call LogString
    push OFFSET szLogHeader
    call LogString
    
    ; Return
    mov eax, [ebp-4]
    mov esp, ebp
    pop ebp
    ret 16                  ; stdcall: clean 4 parameters
    
MessageBoxAHookHandler ENDP

;-------------------------------------------------------------------------------
; BuildTrampoline - Creates a trampoline for a function
;-------------------------------------------------------------------------------
BuildTrampoline PROC pOriginal:DWORD, pBuffer:DWORD, pSavedBytes:DWORD
    pushad
    
    ; Copy 5 bytes to saved bytes
    mov esi, pOriginal
    mov edi, pSavedBytes
    mov ecx, 5
    rep movsb
    
    ; Copy 5 bytes to trampoline buffer
    mov esi, pSavedBytes
    mov edi, pBuffer
    mov ecx, 5
    rep movsb
    
    ; Add JMP back
    mov BYTE PTR [edi], 0E9h
    mov eax, pOriginal
    add eax, 5
    sub eax, edi
    sub eax, 5
    mov [edi+1], eax
    
    popad
    mov eax, 1
    ret
BuildTrampoline ENDP

;-------------------------------------------------------------------------------
; InstallHook - Installs the hook on a function
;-------------------------------------------------------------------------------
InstallHook PROC pOriginal:DWORD, pHandler:DWORD
    pushad
    
    ; Change protection
    push OFFSET dwOldProtect
    push PAGE_EXECUTE_READWRITE
    push 5
    push pOriginal
    call VirtualProtect
    test eax, eax
    jz @failed
    
    ; Write JMP
    mov edi, pOriginal
    mov BYTE PTR [edi], 0E9h
    mov eax, pHandler
    sub eax, edi
    sub eax, 5
    mov [edi+1], eax
    
    ; Restore protection
    push OFFSET dwOldProtect
    push dwOldProtect
    push 5
    push pOriginal
    call VirtualProtect
    
    ; Flush cache
    push 5
    push pOriginal
    push -1
    call FlushInstructionCache
    
    popad
    mov eax, 1
    ret
    
@failed:
    popad
    xor eax, eax
    ret
InstallHook ENDP

;-------------------------------------------------------------------------------
; InitializeMessageBoxHook - Main initialization function
;-------------------------------------------------------------------------------
InitializeMessageBoxHook PROC
    pushad
    
    ; Get user32.dll handle
    push OFFSET szUser32
    call GetModuleHandleA
    test eax, eax
    jz @failed
    mov hUser32, eax
    
    ;═══════════════════════════════════════════════════════════════
    ; Setup MessageBoxA hook
    ;═══════════════════════════════════════════════════════════════
    
    ; Get MessageBoxA address
    push OFFSET szMsgBoxA
    push hUser32
    call GetProcAddress
    test eax, eax
    jz @failed
    mov pOrigMsgBoxA, eax
    
    ; Allocate trampoline
    push PAGE_EXECUTE_READWRITE
    push MEM_COMMIT or MEM_RESERVE
    push TRAMPOLINE_SIZE
    push NULL
    call VirtualAlloc
    test eax, eax
    jz @failed
    mov pTrampolineA, eax
    
    ; Build trampoline
    push OFFSET bOrigBytesA
    push pTrampolineA
    push pOrigMsgBoxA
    call BuildTrampoline
    
    ; Install hook
    push OFFSET MessageBoxAHookHandler
    push pOrigMsgBoxA
    call InstallHook
    test eax, eax
    jz @failed
    
    mov bHookInstalledA, 1
    
    popad
    mov eax, 1
    ret
    
@failed:
    popad
    xor eax, eax
    ret
InitializeMessageBoxHook ENDP

;-------------------------------------------------------------------------------
; RemoveMessageBoxHook - Removes the hook
;-------------------------------------------------------------------------------
RemoveMessageBoxHook PROC
    pushad
    
    cmp bHookInstalledA, 0
    je @done
    
    ; Restore original bytes
    push OFFSET dwOldProtect
    push PAGE_EXECUTE_READWRITE
    push 5
    push pOrigMsgBoxA
    call VirtualProtect
    
    mov esi, OFFSET bOrigBytesA
    mov edi, pOrigMsgBoxA
    mov ecx, 5
    rep movsb
    
    push OFFSET dwOldProtect
    push dwOldProtect
    push 5
    push pOrigMsgBoxA
    call VirtualProtect
    
    push 5
    push pOrigMsgBoxA
    push -1
    call FlushInstructionCache
    
    ; Free trampoline
    cmp pTrampolineA, 0
    je @noFree
    push MEM_RELEASE
    push 0
    push pTrampolineA
    call VirtualFree
    mov pTrampolineA, 0
@noFree:
    
    mov bHookInstalledA, 0
    
@done:
    popad
    ret
RemoveMessageBoxHook ENDP

;-------------------------------------------------------------------------------
; GetMessageBoxACallCount - Returns the call count
;-------------------------------------------------------------------------------
GetMessageBoxACallCount PROC
    mov eax, dwCallCountA
    ret
GetMessageBoxACallCount ENDP

END
```

---

## 📚 Part 2: Using the Hook

### Main Program Example

```asm
; main.asm
; Demonstrates using the MessageBox hook

.686
.model flat, stdcall
option casemap:none

include \masm32\include\windows.inc
include \masm32\include\kernel32.inc
include \masm32\include\user32.inc
includelib \masm32\lib\kernel32.lib
includelib \masm32\lib\user32.lib

; External declarations
EXTERNDEF InitializeMessageBoxHook:PROC
EXTERNDEF RemoveMessageBoxHook:PROC
EXTERNDEF GetMessageBoxACallCount:PROC

.data
    szTitle         db "Hook Demo", 0
    szMsg1          db "First message - this is hooked!", 0
    szMsg2          db "Second message - also hooked!", 0
    szMsg3          db "Choose Yes or No", 0
    szComplete      db "Demo complete! Check DebugView for logs.", 0
    szCountFmt      db "Total MessageBoxA calls: %d", 0
    szCountBuf      db 64 dup(0)

.code
main PROC
    ; Initialize the hook
    call InitializeMessageBoxHook
    test eax, eax
    jz @hookFailed
    
    ; Test 1: Simple OK message
    push MB_OK or MB_ICONINFORMATION
    push OFFSET szTitle
    push OFFSET szMsg1
    push NULL
    call MessageBoxA
    
    ; Test 2: Another message
    push MB_OKCANCEL or MB_ICONQUESTION
    push OFFSET szTitle
    push OFFSET szMsg2
    push NULL
    call MessageBoxA
    
    ; Test 3: Yes/No message
    push MB_YESNO or MB_ICONWARNING
    push OFFSET szTitle
    push OFFSET szMsg3
    push NULL
    call MessageBoxA
    
    ; Remove the hook
    call RemoveMessageBoxHook
    
    ; Show final message (not hooked)
    push MB_OK
    push OFFSET szTitle
    push OFFSET szComplete
    push NULL
    call MessageBoxA
    
    jmp @exit
    
@hookFailed:
    push MB_ICONERROR
    push OFFSET szTitle
    push OFFSET szComplete
    push NULL
    call MessageBoxA
    
@exit:
    push 0
    call ExitProcess
main ENDP

END main
```

---

## 📚 Part 3: Testing with DebugView

### Step 1: Download DebugView
1. Get DebugView from Microsoft Sysinternals
2. Run as Administrator

### Step 2: Configure DebugView
1. Check "Capture → Capture Win32"
2. Optional: Filter by "[MessageBoxA" to see only our logs

### Step 3: Run Your Program
You should see output like:
```
═══════════════════════════════════════════════════════
[MessageBoxA Hook] 
  Call #1
  Text: First message - this is hooked!
  Caption: Hook Demo
  Type: 0x00000040
  Result: IDOK
═══════════════════════════════════════════════════════
```

---

## 📚 Part 4: Extending to MessageBoxW

### Adding Unicode Support

```asm
;-------------------------------------------------------------------------------
; MessageBoxWHookHandler - Hook for Unicode version
;-------------------------------------------------------------------------------
MessageBoxWHookHandler PROC
    push ebp
    mov ebp, esp
    
    pushad
    
    ; Increment counter
    inc dwCallCountW
    
    ; Log (simplified - would need Unicode-to-ANSI conversion for OutputDebugStringA)
    push OFFSET szLogPrefix
    call LogString
    
    ; ... similar logging code but handle wchar_t* ...
    
    popad
    
    ; Call original
    push [ebp+20]
    push [ebp+16]
    push [ebp+12]
    push [ebp+8]
    call pTrampolineW
    
    mov esp, ebp
    pop ebp
    ret 16
MessageBoxWHookHandler ENDP
```

---

## 📚 Part 5: Advanced Features

### Feature 1: Message Modification

```asm
; Prepend "[HOOKED] " to every message
ModifyMessage PROC pOrigText:DWORD, pBuffer:DWORD
    pushad
    
    mov edi, pBuffer
    
    ; Write prefix
    mov esi, OFFSET szHookedPrefix  ; "[HOOKED] "
@copyPrefix:
    lodsb
    test al, al
    jz @copyOriginal
    stosb
    jmp @copyPrefix
    
@copyOriginal:
    mov esi, pOrigText
@copyOrig:
    lodsb
    stosb
    test al, al
    jnz @copyOrig
    
    popad
    ret
ModifyMessage ENDP
```

### Feature 2: Call Blocking

```asm
; Block certain messages
ShouldBlockMessage PROC pText:DWORD
    pushad
    
    ; Check if message contains "password"
    push OFFSET szPassword
    push pText
    call StrStrIA               ; Case-insensitive search
    test eax, eax
    jnz @block
    
    popad
    xor eax, eax                ; Don't block
    ret
    
@block:
    popad
    mov eax, 1                  ; Block this call
    ret
ShouldBlockMessage ENDP
```

### Feature 3: Statistics

```asm
.data
    dwTotalCalls    dd 0
    dwOKCount       dd 0
    dwCancelCount   dd 0
    dwYesCount      dd 0
    dwNoCount       dd 0

; Track result statistics
TrackResult PROC dwResult:DWORD
    inc dwTotalCalls
    
    mov eax, dwResult
    cmp eax, IDOK
    jne @notOK
    inc dwOKCount
    ret
@notOK:
    cmp eax, IDCANCEL
    jne @notCancel
    inc dwCancelCount
    ret
@notCancel:
    ; ... etc ...
    ret
TrackResult ENDP
```

---

## 📝 Part 6: Tasks

### Task 1: Add Timestamp Logging (25 minutes)
Modify the hook to log:
1. Current date and time when MessageBox is called
2. Use GetLocalTime API
3. Format as "YYYY-MM-DD HH:MM:SS"

### Task 2: Hook MessageBoxW (30 minutes)
Add complete support for MessageBoxW:
1. Create MessageBoxWHookHandler
2. Build trampoline for MessageBoxW
3. Install hook on both A and W versions

### Task 3: Message Filter (25 minutes)
Create a hook that:
1. Checks lpText for specific keywords
2. If found, shows a different message instead
3. Example: Replace "error" with "notice"

### Task 4: Call Logging to File (35 minutes)
Instead of debug output:
1. Open a log file at hook init
2. Write all call info to the file
3. Close file at hook removal
4. Use CreateFileA, WriteFile, CloseHandle

---

## ✅ Session Checklist

Before moving to Session 11, make sure you can:

- [ ] Implement a complete MessageBoxA hook
- [ ] Log all parameters (hWnd, lpText, lpCaption, uType)
- [ ] Handle the return value correctly
- [ ] Use DebugView to see hook activity
- [ ] Properly clean up when removing hook

---

## 🔜 Next Session

In **Session 11: Register Preservation with PUSHAD/POPAD**, we'll learn:
- Deep dive into register preservation
- When to save which registers
- Alternatives to PUSHAD/POPAD
- Performance considerations

[Continue to Session 11 →](session_11.md)

---

## 📖 Additional Resources

- [DebugView Download](https://docs.microsoft.com/en-us/sysinternals/downloads/debugview)
- [MessageBox Documentation](https://docs.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-messageboxa)
- [OutputDebugString Documentation](https://docs.microsoft.com/en-us/windows/win32/api/debugapi/nf-debugapi-outputdebugstringa)
