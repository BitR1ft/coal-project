# Session 07: Inline/Detour Hooking Technique

## 🎯 Learning Objectives

By the end of this session, you will:
- Implement a complete inline hook from scratch
- Handle different function prologues
- Write robust JMP instruction placement
- Create a reusable hook installation function

---

## 📚 Part 1: Theory - Complete Inline Hook Implementation

### The Inline Hook Strategy

Inline hooking (also called "detour" or "trampoline" hooking) works by:

1. **Overwriting** the first few bytes of the target function with a JMP
2. **Saving** those overwritten bytes to a "trampoline"
3. **Executing** your hook code when the function is called
4. **Optionally** calling the original function via the trampoline

```
┌─────────────────────────────────────────────────────────────────┐
│                    INLINE HOOK OVERVIEW                          │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  BEFORE HOOK:                                                    │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │ TargetFunction:                                          │   │
│  │   0x77D507EA: 8B FF        mov edi, edi                  │   │
│  │   0x77D507EC: 55           push ebp                      │   │
│  │   0x77D507ED: 8B EC        mov ebp, esp                  │   │
│  │   0x77D507EF: ... rest of function ...                   │   │
│  └──────────────────────────────────────────────────────────┘   │
│                                                                  │
│  AFTER HOOK:                                                     │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │ TargetFunction:                                          │   │
│  │   0x77D507EA: E9 XX XX XX XX    JMP HookHandler          │   │
│  │   0x77D507EF: ... rest of function (unchanged) ...       │   │
│  └──────────────────────────────────────────────────────────┘   │
│                          │                                       │
│                          ▼                                       │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │ HookHandler:                                              │   │
│  │   pushad / pushfd                                         │   │
│  │   ; ... your hook code ...                                │   │
│  │   popfd / popad                                           │   │
│  │   jmp Trampoline                                          │   │
│  └──────────────────────────────────────────────────────────┘   │
│                          │                                       │
│                          ▼                                       │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │ Trampoline (allocated executable memory):                 │   │
│  │   8B FF              mov edi, edi    ; stolen byte 1-2   │   │
│  │   55                 push ebp        ; stolen byte 3      │   │
│  │   8B EC              mov ebp, esp    ; stolen byte 4-5   │   │
│  │   E9 XX XX XX XX     JMP 0x77D507EF  ; back to original  │   │
│  └──────────────────────────────────────────────────────────┘   │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

---

## 📚 Part 2: The JMP Instruction In Depth

### Types of JMP Instructions

| Type | Opcode | Size | Range |
|------|--------|------|-------|
| Short JMP | EB | 2 bytes | -128 to +127 |
| Near JMP | E9 | 5 bytes | ±2GB |
| Far JMP | EA | 7 bytes | Any segment |
| Indirect JMP | FF 25 | 6 bytes | Any address |

For hooking, we use **Near JMP (E9)** because:
- 5 bytes is manageable
- ±2GB range covers any process address

### Near JMP Encoding

```
┌─────────────────────────────────────────────────────────────────┐
│                    NEAR JMP (E9) ENCODING                        │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  Byte:    [  E9  ] [  XX  ] [  XX  ] [  XX  ] [  XX  ]          │
│  Offset:     0        1        2        3        4               │
│                                                                  │
│  E9 = JMP opcode (relative near jump)                           │
│  XX XX XX XX = 32-bit signed offset (little-endian)             │
│                                                                  │
│  Offset Calculation:                                             │
│  offset = destination - (source + 5)                             │
│         = destination - source - 5                               │
│                                                                  │
│  The "+5" accounts for the size of the JMP instruction itself    │
│  (The offset is relative to the NEXT instruction)               │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### Offset Calculation Examples

```
Example 1: Forward Jump
─────────────────────────
JMP location:   0x77D507EA
Target:         0x00401000

offset = 0x00401000 - 0x77D507EA - 5
       = 0x00401000 - 0x77D507EF
       = 0x886AF811

Bytes at 0x77D507EA: E9 11 F8 6A 88

Example 2: Backward Jump
─────────────────────────
JMP location:   0x00401010
Target:         0x00401000

offset = 0x00401000 - 0x00401010 - 5
       = 0x00401000 - 0x00401015
       = 0xFFFFFFEB (negative = -21 in two's complement)

Bytes at 0x00401010: E9 EB FF FF FF
```

---

## 📚 Part 3: Function Prologue Patterns

### Why Prologues Matter

We need to steal **complete instructions** that total at least 5 bytes. Common patterns:

### Pattern 1: Hot-Patch Prologue (Most Windows APIs)

```asm
8B FF     mov edi, edi    ; 2 bytes (deliberate NOP for patching)
55        push ebp        ; 1 byte
8B EC     mov ebp, esp    ; 2 bytes
                          ; Total: 5 bytes - PERFECT!
```

### Pattern 2: Standard Prologue

```asm
55        push ebp        ; 1 byte
8B EC     mov ebp, esp    ; 2 bytes
83 EC XX  sub esp, XX     ; 3 bytes
                          ; Total: 6 bytes - We can take first 5
                          ; But 83 EC XX is 3 bytes, taking 5 would break it!
                          ; Solution: Take all 6 bytes
```

### Pattern 3: Push-Heavy Prologue

```asm
55        push ebp        ; 1 byte
8B EC     mov ebp, esp    ; 2 bytes
53        push ebx        ; 1 byte
56        push esi        ; 1 byte
                          ; Total: 5 bytes - PERFECT!
```

### Pattern 4: Simple Function

```asm
B8 XX XX XX XX  mov eax, imm32  ; 5 bytes
C3              ret             ; 1 byte
                                ; Take first 5 bytes - complete!
```

### The Instruction Length Problem

We MUST steal complete instructions. Possible solutions:

1. **Fixed 5 bytes**: Works for hot-patch functions
2. **Instruction decoder**: Parse x86 opcodes to find boundaries
3. **Pattern matching**: Recognize common prologues

---

## 📚 Part 4: Complete Hook Implementation

### Hook Manager Structure

```asm
; Hook information structure
HOOK_INFO STRUCT
    pOriginalFunc    DWORD ?      ; Original function address
    pHookFunc        DWORD ?      ; Our hook handler
    pTrampoline      DWORD ?      ; Trampoline address
    bOriginalBytes   BYTE 16 DUP(?); Saved original bytes
    dwBytesStolen    DWORD ?      ; Number of bytes stolen
    bInstalled       BYTE ?       ; Is hook currently installed?
HOOK_INFO ENDS
```

### Complete Hook Installation Code

```asm
;===============================================================================
; InstallInlineHook - Installs an inline hook
;===============================================================================
; Parameters:
;   pTarget   - Address of function to hook
;   pHandler  - Address of our hook handler
;   pHookInfo - Pointer to HOOK_INFO structure (output)
; Returns:
;   EAX = 1 on success, 0 on failure
;===============================================================================
InstallInlineHook PROC pTarget:DWORD, pHandler:DWORD, pHookInfo:DWORD
    LOCAL dwOldProtect:DWORD
    LOCAL pTrampoline:DWORD
    
    pushad
    
    ; Initialize hook info
    mov edi, pHookInfo
    mov eax, pTarget
    mov [edi].HOOK_INFO.pOriginalFunc, eax
    mov eax, pHandler
    mov [edi].HOOK_INFO.pHookFunc, eax
    
    ; Determine bytes to steal (assuming hot-patch, 5 bytes)
    mov [edi].HOOK_INFO.dwBytesStolen, 5
    
    ;═══════════════════════════════════════════════════════════════
    ; Step 1: Allocate executable memory for trampoline
    ;═══════════════════════════════════════════════════════════════
    push PAGE_EXECUTE_READWRITE
    push MEM_COMMIT or MEM_RESERVE
    push 32                         ; 32 bytes should be enough
    push NULL
    call VirtualAlloc
    test eax, eax
    jz @AllocFailed
    mov pTrampoline, eax
    
    mov edi, pHookInfo
    mov [edi].HOOK_INFO.pTrampoline, eax
    
    ;═══════════════════════════════════════════════════════════════
    ; Step 2: Save original bytes
    ;═══════════════════════════════════════════════════════════════
    mov esi, pTarget
    mov edi, pHookInfo
    lea edi, [edi].HOOK_INFO.bOriginalBytes
    mov ecx, 5
    rep movsb
    
    ;═══════════════════════════════════════════════════════════════
    ; Step 3: Build trampoline
    ;═══════════════════════════════════════════════════════════════
    ; Copy stolen bytes to trampoline
    mov edi, pTrampoline
    mov esi, pHookInfo
    lea esi, [esi].HOOK_INFO.bOriginalBytes
    mov ecx, 5
    rep movsb
    
    ; Add JMP back to original+5
    mov BYTE PTR [edi], 0E9h
    mov eax, pTarget
    add eax, 5                      ; Jump back to original+5
    sub eax, edi                    ; Relative to this JMP
    sub eax, 5                      ; Account for JMP size
    mov DWORD PTR [edi+1], eax
    
    ;═══════════════════════════════════════════════════════════════
    ; Step 4: Change protection on target function
    ;═══════════════════════════════════════════════════════════════
    lea eax, dwOldProtect
    push eax
    push PAGE_EXECUTE_READWRITE
    push 5
    push pTarget
    call VirtualProtect
    test eax, eax
    jz @ProtectFailed
    
    ;═══════════════════════════════════════════════════════════════
    ; Step 5: Write JMP to hook handler
    ;═══════════════════════════════════════════════════════════════
    mov edi, pTarget
    mov BYTE PTR [edi], 0E9h
    mov eax, pHandler
    sub eax, edi
    sub eax, 5
    mov DWORD PTR [edi+1], eax
    
    ;═══════════════════════════════════════════════════════════════
    ; Step 6: Restore protection and flush cache
    ;═══════════════════════════════════════════════════════════════
    lea eax, dwOldProtect
    push eax
    push dwOldProtect
    push 5
    push pTarget
    call VirtualProtect
    
    push 5
    push pTarget
    push -1
    call FlushInstructionCache
    
    ; Mark as installed
    mov edi, pHookInfo
    mov [edi].HOOK_INFO.bInstalled, 1
    
    popad
    mov eax, 1
    ret

@AllocFailed:
@ProtectFailed:
    popad
    xor eax, eax
    ret
InstallInlineHook ENDP

;===============================================================================
; RemoveInlineHook - Removes a previously installed hook
;===============================================================================
RemoveInlineHook PROC pHookInfo:DWORD
    LOCAL dwOldProtect:DWORD
    
    pushad
    
    ; Check if installed
    mov edi, pHookInfo
    cmp [edi].HOOK_INFO.bInstalled, 0
    je @NotInstalled
    
    ; Change protection
    lea eax, dwOldProtect
    push eax
    push PAGE_EXECUTE_READWRITE
    push 5
    push [edi].HOOK_INFO.pOriginalFunc
    call VirtualProtect
    test eax, eax
    jz @Failed
    
    ; Restore original bytes
    mov edi, pHookInfo
    mov esi, edi
    lea esi, [esi].HOOK_INFO.bOriginalBytes
    mov edi, [edi].HOOK_INFO.pOriginalFunc
    mov ecx, 5
    rep movsb
    
    ; Restore protection
    mov edi, pHookInfo
    lea eax, dwOldProtect
    push eax
    push dwOldProtect
    push 5
    push [edi].HOOK_INFO.pOriginalFunc
    call VirtualProtect
    
    ; Flush cache
    mov edi, pHookInfo
    push 5
    push [edi].HOOK_INFO.pOriginalFunc
    push -1
    call FlushInstructionCache
    
    ; Free trampoline
    mov edi, pHookInfo
    push MEM_RELEASE
    push 0
    push [edi].HOOK_INFO.pTrampoline
    call VirtualFree
    
    ; Mark as not installed
    mov edi, pHookInfo
    mov [edi].HOOK_INFO.bInstalled, 0
    
    popad
    mov eax, 1
    ret

@NotInstalled:
@Failed:
    popad
    xor eax, eax
    ret
RemoveInlineHook ENDP
```

---

## 📚 Part 5: Hook Handler Template

### Complete Hook Handler Structure

```asm
;===============================================================================
; MyMessageBoxHook - Our hook handler for MessageBoxA
;===============================================================================
; Called when MessageBoxA is called
; Stack layout when we're called:
;   [ESP]   = Return address (to caller)
;   [ESP+4] = hWnd
;   [ESP+8] = lpText
;   [ESP+12] = lpCaption
;   [ESP+16] = uType
;===============================================================================
MyMessageBoxHook PROC
    ;═══════════════════════════════════════════════════════════════
    ; Phase 1: Save ALL registers
    ;═══════════════════════════════════════════════════════════════
    pushad                          ; Save EAX, ECX, EDX, EBX, ESP, EBP, ESI, EDI
    pushfd                          ; Save EFLAGS
    
    ; After pushad/pushfd:
    ; [ESP+0]  = EFLAGS
    ; [ESP+4]  = EDI
    ; [ESP+8]  = ESI
    ; [ESP+12] = EBP
    ; [ESP+16] = original ESP
    ; [ESP+20] = EBX
    ; [ESP+24] = EDX
    ; [ESP+28] = ECX
    ; [ESP+32] = EAX
    ; [ESP+36] = Return address
    ; [ESP+40] = hWnd
    ; [ESP+44] = lpText
    ; [ESP+48] = lpCaption
    ; [ESP+52] = uType
    
    ;═══════════════════════════════════════════════════════════════
    ; Phase 2: Our custom hook logic
    ;═══════════════════════════════════════════════════════════════
    
    ; Example: Log to debug output
    push OFFSET szHookTriggered
    call OutputDebugStringA
    
    ; Example: Count calls
    inc dwHookCount
    
    ; Example: Access parameters
    ; mov eax, [esp+44]   ; lpText
    ; mov ebx, [esp+48]   ; lpCaption
    
    ;═══════════════════════════════════════════════════════════════
    ; Phase 3: Restore ALL registers
    ;═══════════════════════════════════════════════════════════════
    popfd                           ; Restore EFLAGS
    popad                           ; Restore all registers
    
    ;═══════════════════════════════════════════════════════════════
    ; Phase 4: Call original function via trampoline
    ;═══════════════════════════════════════════════════════════════
    jmp [hookInfo.pTrampoline]      ; Execute stolen bytes + continue
    
MyMessageBoxHook ENDP

.data
    szHookTriggered db "[HOOK] MessageBoxA intercepted!", 0
    dwHookCount dd 0
    hookInfo HOOK_INFO <>
```

---

## 💻 Part 6: Practical - Complete Working Example

### Full Program: MessageBox Hook

```asm
; complete_hook.asm
; A complete, working inline hook example

.686
.model flat, stdcall
option casemap:none

include \masm32\include\windows.inc
include \masm32\include\kernel32.inc
include \masm32\include\user32.inc
includelib \masm32\lib\kernel32.lib
includelib \masm32\lib\user32.lib

; Hook info structure
HOOK_INFO STRUCT
    pOriginalFunc    DWORD ?
    pHookFunc        DWORD ?
    pTrampoline      DWORD ?
    bOriginalBytes   BYTE 16 DUP(?)
    dwBytesStolen    DWORD ?
    bInstalled       BYTE ?
    bPadding         BYTE 3 DUP(?)
HOOK_INFO ENDS

.data
    szUser32    db "user32.dll", 0
    szMsgBoxA   db "MessageBoxA", 0
    
    szTitle     db "Hook Test", 0
    szTest1     db "Test message 1 - Should be hooked!", 0
    szTest2     db "Test message 2 - Also hooked!", 0
    szDone      db "Hook test complete!", 0
    
    szDebugHook db "[HOOK] MessageBoxA called! Count: ", 0
    
    dwOldProtect dd 0
    dwHookCount  dd 0
    
    hookInfo HOOK_INFO <>

.code

;----------------------------------------------------------------------
; MyMessageBoxHook - Our hook handler
;----------------------------------------------------------------------
MyMessageBoxHook PROC
    pushad
    pushfd
    
    ; Increment call counter
    inc dwHookCount
    
    ; Log to debug output
    push OFFSET szDebugHook
    call OutputDebugStringA
    
    popfd
    popad
    
    ; Jump to trampoline to call original
    jmp hookInfo.pTrampoline
MyMessageBoxHook ENDP

;----------------------------------------------------------------------
; InstallHook
;----------------------------------------------------------------------
InstallHook PROC
    pushad
    
    ; Get MessageBoxA address
    push OFFSET szUser32
    call GetModuleHandleA
    push OFFSET szMsgBoxA
    push eax
    call GetProcAddress
    test eax, eax
    jz @failed
    mov hookInfo.pOriginalFunc, eax
    
    ; Store hook handler address
    mov hookInfo.pHookFunc, OFFSET MyMessageBoxHook
    mov hookInfo.dwBytesStolen, 5
    
    ; Allocate executable memory for trampoline
    push PAGE_EXECUTE_READWRITE
    push MEM_COMMIT or MEM_RESERVE
    push 32
    push NULL
    call VirtualAlloc
    test eax, eax
    jz @failed
    mov hookInfo.pTrampoline, eax
    
    ; Save original bytes
    mov esi, hookInfo.pOriginalFunc
    lea edi, hookInfo.bOriginalBytes
    mov ecx, 5
    rep movsb
    
    ; Build trampoline: stolen bytes + JMP back
    mov edi, hookInfo.pTrampoline
    lea esi, hookInfo.bOriginalBytes
    mov ecx, 5
    rep movsb
    
    ; JMP back to original+5
    mov BYTE PTR [edi], 0E9h
    mov eax, hookInfo.pOriginalFunc
    add eax, 5
    sub eax, edi
    sub eax, 5
    mov DWORD PTR [edi+1], eax
    
    ; Change protection
    push OFFSET dwOldProtect
    push PAGE_EXECUTE_READWRITE
    push 5
    push hookInfo.pOriginalFunc
    call VirtualProtect
    test eax, eax
    jz @failed
    
    ; Write JMP to hook handler
    mov edi, hookInfo.pOriginalFunc
    mov BYTE PTR [edi], 0E9h
    mov eax, OFFSET MyMessageBoxHook
    sub eax, edi
    sub eax, 5
    mov DWORD PTR [edi+1], eax
    
    ; Restore protection
    push OFFSET dwOldProtect
    push dwOldProtect
    push 5
    push hookInfo.pOriginalFunc
    call VirtualProtect
    
    ; Flush cache
    push 5
    push hookInfo.pOriginalFunc
    push -1
    call FlushInstructionCache
    
    mov hookInfo.bInstalled, 1
    
    popad
    mov eax, 1
    ret

@failed:
    popad
    xor eax, eax
    ret
InstallHook ENDP

;----------------------------------------------------------------------
; RemoveHook
;----------------------------------------------------------------------
RemoveHook PROC
    pushad
    
    cmp hookInfo.bInstalled, 0
    je @done
    
    ; Change protection
    push OFFSET dwOldProtect
    push PAGE_EXECUTE_READWRITE
    push 5
    push hookInfo.pOriginalFunc
    call VirtualProtect
    
    ; Restore original bytes
    mov edi, hookInfo.pOriginalFunc
    lea esi, hookInfo.bOriginalBytes
    mov ecx, 5
    rep movsb
    
    ; Restore protection
    push OFFSET dwOldProtect
    push dwOldProtect
    push 5
    push hookInfo.pOriginalFunc
    call VirtualProtect
    
    ; Flush cache
    push 5
    push hookInfo.pOriginalFunc
    push -1
    call FlushInstructionCache
    
    ; Free trampoline
    push MEM_RELEASE
    push 0
    push hookInfo.pTrampoline
    call VirtualFree
    
    mov hookInfo.bInstalled, 0

@done:
    popad
    ret
RemoveHook ENDP

;----------------------------------------------------------------------
; main
;----------------------------------------------------------------------
main PROC
    ; Install the hook
    call InstallHook
    test eax, eax
    jz @exit
    
    ; Call MessageBoxA - should be hooked!
    push MB_OK
    push OFFSET szTitle
    push OFFSET szTest1
    push NULL
    call MessageBoxA
    
    ; Call again
    push MB_OK
    push OFFSET szTitle
    push OFFSET szTest2
    push NULL
    call MessageBoxA
    
    ; Remove hook
    call RemoveHook
    
    ; Final message (not hooked anymore)
    push MB_OK
    push OFFSET szTitle
    push OFFSET szDone
    push NULL
    call MessageBoxA

@exit:
    push 0
    call ExitProcess
main ENDP

END main
```

---

## 📝 Part 7: Tasks

### Task 1: Hook Counter Display (25 minutes)
Modify the complete example to:
1. Display the hook count in the message box caption
2. Show something like "Hook Test (Call #3)"

### Task 2: Parameter Logging (30 minutes)
Modify the hook to:
1. Extract the lpText parameter from the stack
2. Log it to a debug output
3. Use DebugView to see the logs

### Task 3: Message Modification (30 minutes)
Modify the hook to:
1. Prepend "[HOOKED] " to every message
2. You'll need to allocate memory for the new string
3. Clean up the memory after the call

### Task 4: Multiple Hooks (45 minutes)
Extend the code to:
1. Hook both MessageBoxA and MessageBoxW
2. Use an array of HOOK_INFO structures
3. Provide InstallAllHooks and RemoveAllHooks functions

---

## ✅ Session Checklist

Before moving to Session 8, make sure you can:

- [ ] Explain the complete inline hook process
- [ ] Calculate relative JMP offsets correctly
- [ ] Identify instruction boundaries in function prologues
- [ ] Install and remove hooks properly
- [ ] Create proper hook handlers with register preservation
- [ ] Build working trampolines

---

## 🔜 Next Session

In **Session 08: The Trampoline Technique**, we'll learn:
- Advanced trampoline construction
- Handling varying instruction lengths
- Multiple return scenarios
- Trampoline optimization

[Continue to Session 08 →](session_08.md)

---

## 📖 Additional Resources

- [x86 Opcode Reference](http://ref.x86asm.net/)
- [Intel Manual Volume 2 - Instruction Set Reference](https://software.intel.com/content/www/us/en/develop/articles/intel-sdm.html)
- [Microsoft Detours](https://github.com/microsoft/Detours)
