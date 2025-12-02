# Session 04: Windows API Basics

## 🎯 Learning Objectives

By the end of this session, you will:
- Understand how to call Windows APIs from assembly
- Know how to use LoadLibrary and GetProcAddress
- Understand string handling in assembly
- Know common Windows API patterns

---

## 📚 Part 1: Theory - Windows API Structure

### What is the Windows API?

The **Windows API** (also called Win32 API) is a set of functions provided by Windows that let you:
- Create windows and dialogs
- Work with files
- Manage processes and threads
- Handle network operations
- And much more!

### API Naming Conventions

Many Windows APIs come in two versions:

| Suffix | Meaning | Example |
|--------|---------|---------|
| **A** | ANSI (ASCII strings) | MessageBoxA |
| **W** | Wide (Unicode strings) | MessageBoxW |

```c
// ANSI version - uses char*
MessageBoxA(NULL, "Hello", "Title", MB_OK);

// Wide version - uses wchar_t*
MessageBoxW(NULL, L"Hello", L"Title", MB_OK);
```

For hooking, we typically hook BOTH versions if the program might use either.

### How Programs Access APIs

```
┌─────────────────────────────────────────────────────────────────┐
│                    API ACCESS FLOW                               │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  YOUR PROGRAM (.exe)                                            │
│       │                                                          │
│       │ call MessageBoxA                                        │
│       ▼                                                          │
│  IMPORT ADDRESS TABLE (IAT)                                      │
│       │                                                          │
│       │ Contains: MessageBoxA → 0x77D507EA                      │
│       ▼                                                          │
│  user32.dll (in memory)                                         │
│       │                                                          │
│       │ 0x77D507EA: mov edi, edi                                │
│       │             push ebp                                     │
│       │             mov ebp, esp                                 │
│       │             ...                                          │
│       ▼                                                          │
│  KERNEL (actual window creation)                                 │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

---

## 📚 Part 2: Key APIs for Hooking

### LoadLibraryA/W

Loads a DLL into memory and returns a handle:

```c
HMODULE LoadLibraryA(
    LPCSTR lpLibFileName    // DLL name, e.g., "user32.dll"
);
// Returns: Handle to loaded DLL, or NULL on failure
```

```asm
; Assembly
push OFFSET szDllName    ; "user32.dll"
call LoadLibraryA
; EAX = module handle (or 0 if failed)
```

### GetModuleHandleA/W

Gets handle to already-loaded DLL (faster if DLL is loaded):

```c
HMODULE GetModuleHandleA(
    LPCSTR lpModuleName    // DLL name (NULL = current exe)
);
```

```asm
; Assembly
push OFFSET szDllName    ; "user32.dll"
call GetModuleHandleA
; EAX = module handle
```

### GetProcAddress

Gets the address of an exported function:

```c
FARPROC GetProcAddress(
    HMODULE hModule,        // DLL handle from LoadLibrary
    LPCSTR  lpProcName      // Function name, e.g., "MessageBoxA"
);
// Returns: Function address, or NULL on failure
```

```asm
; Assembly
push OFFSET szFuncName   ; "MessageBoxA"
push hModule             ; Handle from LoadLibraryA
call GetProcAddress
; EAX = function address (or 0 if failed)
```

### Complete Example: Finding a Function

```asm
.data
    szUser32    db "user32.dll", 0
    szMsgBoxA   db "MessageBoxA", 0
    hUser32     dd 0
    pMsgBoxA    dd 0

.code
FindMessageBox PROC
    ; Step 1: Load/Get user32.dll
    push OFFSET szUser32
    call LoadLibraryA
    test eax, eax           ; Check if successful
    jz @failed
    mov hUser32, eax
    
    ; Step 2: Get MessageBoxA address
    push OFFSET szMsgBoxA
    push hUser32
    call GetProcAddress
    test eax, eax           ; Check if successful
    jz @failed
    mov pMsgBoxA, eax
    
    ; Success! pMsgBoxA now contains the function address
    ret
    
@failed:
    ; Handle error
    xor eax, eax
    ret
FindMessageBox ENDP
```

---

## 📚 Part 3: Memory APIs for Hooking

### VirtualProtect

Changes memory protection (required before modifying code):

```c
BOOL VirtualProtect(
    LPVOID lpAddress,       // Starting address
    SIZE_T dwSize,          // Number of bytes
    DWORD  flNewProtect,    // New protection (PAGE_EXECUTE_READWRITE)
    PDWORD lpflOldProtect   // Receives old protection
);
// Returns: Non-zero on success
```

```asm
.data
    dwOldProtect dd 0

.code
    ; Make 5 bytes writable
    push OFFSET dwOldProtect    ; Old protection output
    push PAGE_EXECUTE_READWRITE ; New protection
    push 5                      ; Size (5 bytes for JMP)
    push pTargetFunction        ; Address to modify
    call VirtualProtect
    test eax, eax
    jz @error
```

### VirtualQuery

Gets information about a memory region:

```c
SIZE_T VirtualQuery(
    LPCVOID                   lpAddress,    // Address to query
    PMEMORY_BASIC_INFORMATION lpBuffer,     // Output buffer
    SIZE_T                    dwLength      // Size of buffer
);
```

### FlushInstructionCache

Required after modifying code to clear CPU cache:

```c
BOOL FlushInstructionCache(
    HANDLE  hProcess,       // Process handle (-1 for current)
    LPCVOID lpBaseAddress,  // Start address
    SIZE_T  dwSize          // Number of bytes
);
```

```asm
    push 5                   ; Size
    push pModifiedCode       ; Address
    push -1                  ; Current process
    call FlushInstructionCache
```

---

## 📚 Part 4: String Handling in Assembly

### Defining Strings

```asm
.data
    ; ANSI strings (1 byte per character)
    szHello     db "Hello, World!", 0          ; Null-terminated
    szTitle     db "My Title", 0
    
    ; Wide strings (2 bytes per character)
    wszHello    dw 'H','e','l','l','o',0       ; Unicode
    
    ; With newline
    szMessage   db "Line 1", 13, 10, "Line 2", 0
    
    ; Format strings
    szFormat    db "Value: %d", 0
```

### String Length Calculation

```asm
; Get length of string at ESI
; Result in ECX
GetStringLength PROC
    push esi
    xor ecx, ecx
    
@loop:
    mov al, [esi]           ; Get character
    test al, al             ; Is it null?
    jz @done
    inc ecx                 ; Increment length
    inc esi                 ; Next character
    jmp @loop
    
@done:
    pop esi
    ret
GetStringLength ENDP
```

### String Copy

```asm
; Copy string from ESI to EDI
CopyString PROC
    push esi
    push edi
    
@loop:
    mov al, [esi]           ; Get character
    mov [edi], al           ; Store character
    test al, al             ; Is it null?
    jz @done
    inc esi                 ; Next source char
    inc edi                 ; Next dest char
    jmp @loop
    
@done:
    pop edi
    pop esi
    ret
CopyString ENDP
```

### Using REP MOVSB

```asm
; Faster string copy using REP MOVSB
; ESI = source, EDI = destination, ECX = count
FastCopyString PROC
    cld                     ; Clear direction flag (forward)
    rep movsb               ; Copy ECX bytes from [ESI] to [EDI]
    ret
FastCopyString ENDP
```

---

## 📚 Part 5: Common API Patterns

### Pattern 1: Check Return Value

Almost all Windows APIs return 0 (or NULL) on failure:

```asm
    call SomeWindowsAPI
    test eax, eax           ; Is EAX zero?
    jz @HandleError         ; Yes, handle error
    ; No, continue with success
```

### Pattern 2: Get Error Information

When an API fails, use GetLastError:

```asm
    call SomeWindowsAPI
    test eax, eax
    jnz @success
    
    ; Failed - get error code
    call GetLastError
    ; EAX now contains error code
    
@success:
```

### Pattern 3: Save Handle for Later

```asm
.data
    hModule dd 0
    
.code
    push OFFSET szDllName
    call LoadLibraryA
    mov hModule, eax        ; Save for later use
```

### Pattern 4: Multiple API Calls

```asm
    ; Load library
    push OFFSET szUser32
    call LoadLibraryA
    mov hUser32, eax
    
    ; Get function 1
    push OFFSET szFunc1
    push hUser32
    call GetProcAddress
    mov pFunc1, eax
    
    ; Get function 2
    push OFFSET szFunc2
    push hUser32
    call GetProcAddress
    mov pFunc2, eax
```

---

## 💻 Part 6: Practical - API Calling in Assembly

### Exercise 1: Complete MessageBox Example

```asm
; messagebox_demo.asm
; Demonstrates calling MessageBoxA from assembly

.686
.model flat, stdcall
option casemap:none

; Windows include and library
include \masm32\include\windows.inc
include \masm32\include\kernel32.inc
include \masm32\include\user32.inc
includelib \masm32\lib\kernel32.lib
includelib \masm32\lib\user32.lib

.data
    szMessage db "Hello from Assembly!", 0
    szTitle   db "MASM Demo", 0

.code
main PROC
    ; Call MessageBoxA
    ; Parameters: hWnd, lpText, lpCaption, uType
    push MB_ICONINFORMATION or MB_OKCANCEL
    push OFFSET szTitle
    push OFFSET szMessage
    push NULL               ; No parent window
    call MessageBoxA
    
    ; Check return value
    cmp eax, IDOK
    je @ClickedOK
    cmp eax, IDCANCEL
    je @ClickedCancel
    jmp @Exit
    
@ClickedOK:
    ; User clicked OK
    push MB_OK
    push OFFSET szTitle
    push OFFSET szOK
    push NULL
    call MessageBoxA
    jmp @Exit
    
@ClickedCancel:
    ; User clicked Cancel
    push MB_OK
    push OFFSET szTitle
    push OFFSET szCancel
    push NULL
    call MessageBoxA
    
@Exit:
    push 0
    call ExitProcess
main ENDP

.data
    szOK     db "You clicked OK!", 0
    szCancel db "You clicked Cancel!", 0

END main
```

### Exercise 2: Dynamic Function Loading

```asm
; dynamic_load.asm
; Demonstrates LoadLibrary and GetProcAddress

.686
.model flat, stdcall
option casemap:none

include \masm32\include\windows.inc
include \masm32\include\kernel32.inc
includelib \masm32\lib\kernel32.lib

.data
    szUser32    db "user32.dll", 0
    szMsgBoxA   db "MessageBoxA", 0
    szTitle     db "Dynamic Load", 0
    szText      db "Function loaded dynamically!", 0
    szError     db "Failed to load function!", 0
    
    hUser32     dd 0
    pMessageBox dd 0

.code
main PROC
    ; Step 1: Load user32.dll
    push OFFSET szUser32
    call LoadLibraryA
    test eax, eax
    jz @LoadFailed
    mov hUser32, eax
    
    ; Step 2: Get MessageBoxA address
    push OFFSET szMsgBoxA
    push hUser32
    call GetProcAddress
    test eax, eax
    jz @GetProcFailed
    mov pMessageBox, eax
    
    ; Step 3: Call MessageBoxA dynamically!
    push MB_OK
    push OFFSET szTitle
    push OFFSET szText
    push NULL
    call pMessageBox        ; Call through pointer
    
    jmp @Exit
    
@LoadFailed:
@GetProcFailed:
    ; Use static import to show error
    push 0
    call GetStdHandle
    ; ... write error message ...
    
@Exit:
    push 0
    call ExitProcess
main ENDP

END main
```

### Exercise 3: Memory Protection Demo

```asm
; virtual_protect_demo.asm
; Shows how to change memory protection

.686
.model flat, stdcall
option casemap:none

include \masm32\include\windows.inc
include \masm32\include\kernel32.inc
include \masm32\include\user32.inc
includelib \masm32\lib\kernel32.lib
includelib \masm32\lib\user32.lib

.data
    szUser32      db "user32.dll", 0
    szMsgBoxA     db "MessageBoxA", 0
    szTitle       db "VirtualProtect Demo", 0
    szBefore      db "First bytes: %02X %02X %02X %02X %02X", 0
    szSuccess     db "Protection changed successfully!", 0
    szFailed      db "VirtualProtect failed!", 0
    
    dwOldProtect  dd 0
    hUser32       dd 0
    pMsgBoxA      dd 0

.code
main PROC
    ; Get MessageBoxA address
    push OFFSET szUser32
    call GetModuleHandleA
    mov hUser32, eax
    
    push OFFSET szMsgBoxA
    push hUser32
    call GetProcAddress
    mov pMsgBoxA, eax
    
    ; Change protection to READWRITE
    push OFFSET dwOldProtect
    push PAGE_EXECUTE_READWRITE
    push 5
    push pMsgBoxA
    call VirtualProtect
    test eax, eax
    jz @Failed
    
    ; Show success message
    push MB_ICONINFORMATION
    push OFFSET szTitle
    push OFFSET szSuccess
    push NULL
    call MessageBoxA
    
    ; Restore original protection (good practice!)
    push OFFSET dwOldProtect
    push dwOldProtect
    push 5
    push pMsgBoxA
    call VirtualProtect
    
    jmp @Exit
    
@Failed:
    push MB_ICONERROR
    push OFFSET szTitle
    push OFFSET szFailed
    push NULL
    call MessageBoxA
    
@Exit:
    push 0
    call ExitProcess
main ENDP

END main
```

### Exercise 4: Console Output

```asm
; console_output.asm
; Shows console output patterns

.686
.model flat, stdcall
option casemap:none

include \masm32\include\windows.inc
include \masm32\include\kernel32.inc
includelib \masm32\lib\kernel32.lib

.data
    szMessage   db "Hello from Console!", 13, 10, 0
    szLoading   db "Loading user32.dll...", 13, 10, 0
    szFound     db "Found MessageBoxA at: ", 0
    szHex       db "0x%08X", 13, 10, 0
    szUser32    db "user32.dll", 0
    szMsgBoxA   db "MessageBoxA", 0
    
    hConsole    dd 0
    dwWritten   dd 0
    szBuffer    db 64 dup(0)

.code
; Simple console print function
PrintString PROC pString:DWORD
    push esi
    
    ; Get string length
    mov esi, pString
    xor ecx, ecx
    
@@:
    mov al, [esi + ecx]
    test al, al
    jz @done
    inc ecx
    jmp @b
    
@done:
    ; Write to console
    push 0
    push OFFSET dwWritten
    push ecx                    ; Length
    push pString
    push hConsole
    call WriteConsoleA
    
    pop esi
    ret
PrintString ENDP

main PROC
    ; Get console handle
    push STD_OUTPUT_HANDLE
    call GetStdHandle
    mov hConsole, eax
    
    ; Print loading message
    push OFFSET szLoading
    call PrintString
    
    ; Load user32 and get MessageBoxA
    push OFFSET szUser32
    call GetModuleHandleA
    push OFFSET szMsgBoxA
    push eax
    call GetProcAddress
    
    ; Print "Found MessageBoxA at: "
    push OFFSET szFound
    call PrintString
    
    ; TODO: Print hex address (would use wsprintf)
    
    ; Exit
    push 0
    call ExitProcess
main ENDP

END main
```

---

## 💻 Part 7: Complete Hook Setup Template

Here's a template that puts it all together:

```asm
; hook_template.asm
; Template for setting up API hooks

.686
.model flat, stdcall
option casemap:none

include \masm32\include\windows.inc
include \masm32\include\kernel32.inc
include \masm32\include\user32.inc
includelib \masm32\lib\kernel32.lib
includelib \masm32\lib\user32.lib

.data
    ; DLL and function names
    szUser32        db "user32.dll", 0
    szMessageBoxA   db "MessageBoxA", 0
    
    ; Handles and addresses
    hUser32         dd 0
    pMessageBoxA    dd 0
    
    ; Saved bytes (will store original first 5 bytes)
    bOriginalBytes  db 5 dup(0)
    
    ; Protection
    dwOldProtect    dd 0
    
    ; Hook status
    bHookInstalled  dd 0

.code

;----------------------------------------------------------------------
; SetupHook - Prepares for hooking (call once at start)
;----------------------------------------------------------------------
SetupHook PROC
    pushad
    
    ; Get user32.dll handle
    push OFFSET szUser32
    call GetModuleHandleA
    test eax, eax
    jz @failed
    mov hUser32, eax
    
    ; Get MessageBoxA address
    push OFFSET szMessageBoxA
    push hUser32
    call GetProcAddress
    test eax, eax
    jz @failed
    mov pMessageBoxA, eax
    
    ; Save original bytes
    mov esi, pMessageBoxA
    lea edi, bOriginalBytes
    mov ecx, 5
    rep movsb
    
    popad
    mov eax, 1          ; Success
    ret
    
@failed:
    popad
    xor eax, eax        ; Failure
    ret
SetupHook ENDP

;----------------------------------------------------------------------
; InstallHook - Actually installs the hook
;----------------------------------------------------------------------
InstallHook PROC pHookHandler:DWORD
    pushad
    
    ; Change protection
    push OFFSET dwOldProtect
    push PAGE_EXECUTE_READWRITE
    push 5
    push pMessageBoxA
    call VirtualProtect
    test eax, eax
    jz @failed
    
    ; Write JMP instruction
    mov edi, pMessageBoxA
    mov BYTE PTR [edi], 0E9h          ; JMP opcode
    
    ; Calculate relative offset
    mov eax, pHookHandler
    sub eax, pMessageBoxA
    sub eax, 5
    mov DWORD PTR [edi+1], eax
    
    ; Restore protection
    push OFFSET dwOldProtect
    push dwOldProtect
    push 5
    push pMessageBoxA
    call VirtualProtect
    
    ; Flush instruction cache
    push 5
    push pMessageBoxA
    push -1
    call FlushInstructionCache
    
    mov bHookInstalled, 1
    
    popad
    mov eax, 1
    ret
    
@failed:
    popad
    xor eax, eax
    ret
InstallHook ENDP

;----------------------------------------------------------------------
; RemoveHook - Removes the hook
;----------------------------------------------------------------------
RemoveHook PROC
    pushad
    
    ; Check if hook is installed
    cmp bHookInstalled, 0
    je @done
    
    ; Change protection
    push OFFSET dwOldProtect
    push PAGE_EXECUTE_READWRITE
    push 5
    push pMessageBoxA
    call VirtualProtect
    test eax, eax
    jz @failed
    
    ; Restore original bytes
    mov edi, pMessageBoxA
    lea esi, bOriginalBytes
    mov ecx, 5
    rep movsb
    
    ; Restore protection
    push OFFSET dwOldProtect
    push dwOldProtect
    push 5
    push pMessageBoxA
    call VirtualProtect
    
    ; Flush
    push 5
    push pMessageBoxA
    push -1
    call FlushInstructionCache
    
    mov bHookInstalled, 0
    
@done:
    popad
    mov eax, 1
    ret
    
@failed:
    popad
    xor eax, eax
    ret
RemoveHook ENDP

END
```

---

## 📝 Part 8: Tasks

### Task 1: API Research (20 minutes)
Look up these Windows APIs and write their:
- Full function signature
- Return value meaning
- One sentence description

APIs: `CreateFileA`, `WriteFile`, `CloseHandle`, `VirtualAlloc`

### Task 2: Assembly API Calls (30 minutes)
Write assembly code to:
1. Create a file called "test.txt"
2. Write "Hello!" to it
3. Close the file
(Hint: CreateFileA, WriteFile, CloseHandle)

### Task 3: Function Finder (25 minutes)
Create a program that:
1. Asks user for a DLL name
2. Asks user for a function name
3. Loads the DLL
4. Gets the function address
5. Displays the address

### Task 4: Byte Dumper (30 minutes)
Create an assembly program that:
1. Loads user32.dll
2. Gets addresses of 3 different functions
3. Displays the first 10 bytes of each
4. Uses console output (not MessageBox)

---

## ✅ Session Checklist

Before moving to Session 5, make sure you can:

- [ ] Use LoadLibraryA to load a DLL
- [ ] Use GetProcAddress to find a function
- [ ] Use VirtualProtect to change memory protection
- [ ] Handle ANSI strings in assembly
- [ ] Check API return values properly
- [ ] Write a complete ASM program that calls multiple APIs

---

## 🔜 Next Session

In **Session 05: Your First Hook - Concept and Design**, we'll learn:
- The complete hook installation process
- Designing our hook handler
- Understanding what "stolen bytes" are
- Creating our first working hook!

[Continue to Session 05 →](session_05.md)

---

## 📖 Additional Resources

- [Windows API Documentation](https://docs.microsoft.com/en-us/windows/win32/apiindex/windows-api-list)
- [MASM32 Library Reference](http://www.masm32.com/board/)
- [PE Format Specification](https://docs.microsoft.com/en-us/windows/win32/debug/pe-format)
