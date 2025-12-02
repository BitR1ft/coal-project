# Session 08: The Trampoline Technique - Deep Dive

## 🎯 Learning Objectives

By the end of this session, you will:
- Master advanced trampoline construction
- Handle varying instruction lengths
- Understand different trampoline patterns
- Implement robust trampolines that work with any function

---

## 📚 Part 1: Theory - Trampoline Fundamentals

### What is a Trampoline?

A **trampoline** is a small piece of dynamically generated code that:
1. Executes the "stolen bytes" (original instructions we overwrote)
2. Jumps back to the original function to continue execution

```
┌─────────────────────────────────────────────────────────────────┐
│                    TRAMPOLINE CONCEPT                            │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  Think of it like a detour on a road:                           │
│                                                                  │
│  NORMAL ROAD:                                                    │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │ [Start] ──────────────────────────────────────▶ [End]   │    │
│  └─────────────────────────────────────────────────────────┘    │
│                                                                  │
│  WITH DETOUR (Hook):                                             │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │ [Start] ─┐                                               │    │
│  │          │  (our code runs here)                         │    │
│  │          ▼                                               │    │
│  │    ┌───────────┐                                         │    │
│  │    │ Detour    │ ← Our hook handler                      │    │
│  │    │  Area     │                                         │    │
│  │    └─────┬─────┘                                         │    │
│  │          │                                               │    │
│  │          ▼                                               │    │
│  │    ┌───────────┐                                         │    │
│  │    │Trampoline │ ← Stolen instructions                   │    │
│  │    └─────┬─────┘                                         │    │
│  │          │                                               │    │
│  │          └──────────────────────────────────▶ [End]     │    │
│  └─────────────────────────────────────────────────────────┘    │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### Why We Need Trampolines

Without a trampoline, we could only:
- Log the call and then BLOCK it (not call original)
- Or log and JMP to original, but lose the stolen bytes!

With a trampoline:
- We can execute our code AND call the original function
- We get the original return value
- The caller never knows a hook was involved

---

## 📚 Part 2: Trampoline Structure

### Basic Trampoline Layout

```
┌─────────────────────────────────────────────────────────────────┐
│                    TRAMPOLINE MEMORY LAYOUT                      │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  Offset  │ Bytes         │ Description                          │
│  ────────┼───────────────┼────────────────────────────────────  │
│  +0      │ XX XX XX ...  │ Stolen bytes (copied from original)  │
│  +N      │ E9 XX XX XX XX│ JMP back to original+N               │
│                                                                  │
│  Where N = number of stolen bytes (minimum 5)                   │
│                                                                  │
│  Example (5 stolen bytes):                                       │
│  +0      │ 8B FF         │ mov edi, edi (2 bytes)               │
│  +2      │ 55            │ push ebp (1 byte)                    │
│  +3      │ 8B EC         │ mov ebp, esp (2 bytes)               │
│  +5      │ E9 XX XX XX XX│ JMP original+5 (5 bytes)             │
│                                                                  │
│  Total trampoline size: 10 bytes                                │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### Trampoline Execution Flow

```
┌─────────────────────────────────────────────────────────────────┐
│                 TRAMPOLINE EXECUTION FLOW                        │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  1. Hook Handler calls/jumps to Trampoline                      │
│                     │                                            │
│                     ▼                                            │
│  2. Trampoline: Execute stolen bytes                            │
│     ┌─────────────────────────────────────┐                     │
│     │ 8B FF    mov edi, edi               │                     │
│     │ 55       push ebp                   │                     │
│     │ 8B EC    mov ebp, esp               │                     │
│     └───────────────────────┬─────────────┘                     │
│                             │                                    │
│                             ▼                                    │
│  3. Trampoline: JMP to original+5                               │
│     ┌─────────────────────────────────────┐                     │
│     │ E9 XX XX XX XX  JMP original+5      │                     │
│     └───────────────────────┬─────────────┘                     │
│                             │                                    │
│                             ▼                                    │
│  4. Original function continues from byte 6                     │
│     ┌─────────────────────────────────────┐                     │
│     │ original+5: sub esp, 50h            │                     │
│     │ original+8: push ebx                │                     │
│     │ ...                                 │                     │
│     │ original+N: ret 16                  │                     │
│     └───────────────────────┬─────────────┘                     │
│                             │                                    │
│                             ▼                                    │
│  5. Return to original caller                                   │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

---

## 📚 Part 3: Advanced Trampoline Scenarios

### Scenario 1: Relative Instructions in Stolen Bytes

Some instructions use **relative addressing**. If we copy them to the trampoline, they'll point to wrong locations!

```
Problem Instructions:
──────────────────────
JMP rel32      - Relative jump
CALL rel32     - Relative call
Jcc rel32      - Conditional jumps (JE, JNE, etc.)
LOOP/LOOPE     - Loop instructions

Example Problem:
────────────────
Original at 0x77D50000:
  0x77D50000: E8 10 00 00 00   CALL 0x77D50015  (relative call, offset=0x10)
  0x77D50005: 55               PUSH EBP
  ...

If we copy to trampoline at 0x00401000:
  0x00401000: E8 10 00 00 00   CALL 0x00401015  ← WRONG! Should call 0x77D50015!
  0x00401005: 55               PUSH EBP
```

**Solution**: Fix up relative instructions:
```asm
; Pseudo-code for fixing relative CALL
; original_target = source + offset + 5
; new_offset = original_target - trampoline_location - 5
```

### Scenario 2: Multi-Byte NOP Prologues

Some functions use multi-byte NOPs for alignment:
```
0F 1F 44 00 00   ; 5-byte NOP
66 0F 1F 44 00 00; 6-byte NOP
0F 1F 80 00 00 00 00 ; 7-byte NOP
```

These are safe to steal as-is.

### Scenario 3: RIP-Relative Addressing (x64)

In 64-bit code, many instructions are RIP-relative. This course focuses on x86 (32-bit) where this isn't an issue.

---

## 📚 Part 4: Building Robust Trampolines

### Complete Trampoline Builder

```asm
;===============================================================================
; BuildTrampoline - Builds a trampoline for the hook
;===============================================================================
; Parameters:
;   pOriginal     - Original function address
;   pTrampBuf     - Buffer for trampoline (must be executable)
;   dwStolenBytes - Number of bytes to steal
; Returns:
;   EAX = size of trampoline, or 0 on failure
;===============================================================================
BuildTrampoline PROC pOriginal:DWORD, pTrampBuf:DWORD, dwStolenBytes:DWORD
    pushad
    
    ; Validate parameters
    mov eax, pOriginal
    test eax, eax
    jz @failed
    
    mov eax, pTrampBuf
    test eax, eax
    jz @failed
    
    mov eax, dwStolenBytes
    cmp eax, 5
    jl @failed              ; Must steal at least 5 bytes
    cmp eax, 16
    jg @failed              ; Don't steal more than 16 bytes
    
    ;═══════════════════════════════════════════════════════════════
    ; Step 1: Copy stolen bytes to trampoline
    ;═══════════════════════════════════════════════════════════════
    mov esi, pOriginal
    mov edi, pTrampBuf
    mov ecx, dwStolenBytes
    rep movsb
    
    ;═══════════════════════════════════════════════════════════════
    ; Step 2: Add JMP back to original + stolenBytes
    ;═══════════════════════════════════════════════════════════════
    ; EDI now points right after stolen bytes in trampoline
    
    ; Write JMP opcode
    mov BYTE PTR [edi], 0E9h
    
    ; Calculate relative offset
    ; Target = pOriginal + dwStolenBytes
    ; JMP is at: pTrampBuf + dwStolenBytes
    ; Next instruction at: pTrampBuf + dwStolenBytes + 5
    ; Offset = Target - (JMP_location + 5)
    
    mov eax, pOriginal
    add eax, dwStolenBytes      ; Target address
    
    mov ebx, pTrampBuf
    add ebx, dwStolenBytes      ; JMP location
    add ebx, 5                  ; Next instruction
    
    sub eax, ebx                ; Relative offset
    mov DWORD PTR [edi+1], eax
    
    ;═══════════════════════════════════════════════════════════════
    ; Step 3: Calculate and return trampoline size
    ;═══════════════════════════════════════════════════════════════
    mov eax, dwStolenBytes
    add eax, 5                  ; Stolen bytes + JMP instruction
    mov [esp+28], eax           ; Store in saved EAX position
    
    popad
    ret

@failed:
    popad
    xor eax, eax
    ret
BuildTrampoline ENDP
```

### Trampoline with Instruction Fixup

For cases with relative instructions:

```asm
;===============================================================================
; BuildTrampolineWithFixup - Handles relative instructions
;===============================================================================
BuildTrampolineWithFixup PROC pOriginal:DWORD, pTrampBuf:DWORD, dwStolenBytes:DWORD
    LOCAL dwOffset:DWORD
    
    pushad
    
    mov esi, pOriginal          ; Source
    mov edi, pTrampBuf          ; Destination
    mov ecx, dwStolenBytes
    xor edx, edx                ; Current offset
    
@CopyLoop:
    cmp edx, ecx
    jge @DoneCopying
    
    ; Get current byte
    mov al, [esi + edx]
    
    ; Check for relative CALL (E8)
    cmp al, 0E8h
    je @HandleRelativeCall
    
    ; Check for relative JMP (E9)
    cmp al, 0E9h
    je @HandleRelativeJmp
    
    ; Check for short JMP (EB)
    cmp al, 0EBh
    je @HandleShortJmp
    
    ; Regular byte - just copy
    mov [edi + edx], al
    inc edx
    jmp @CopyLoop

@HandleRelativeCall:
    ; E8 XX XX XX XX - need to fix up the offset
    ; Copy the E8 opcode
    mov [edi + edx], al
    inc edx
    
    ; Get original offset
    mov eax, [esi + edx]
    
    ; Calculate original target
    ; target = (original + offset) + offset_value + 5
    mov ebx, pOriginal
    add ebx, edx
    add ebx, 4                  ; Point past the offset
    add eax, ebx                ; EAX = original target
    
    ; Calculate new offset
    ; new_offset = target - (trampoline + current + 4)
    mov ebx, pTrampBuf
    add ebx, edx
    add ebx, 4
    sub eax, ebx
    
    ; Store new offset
    mov [edi + edx], eax
    add edx, 4
    jmp @CopyLoop

@HandleRelativeJmp:
    ; Similar to CALL, E9 XX XX XX XX
    ; (implementation similar to above)
    jmp @CopyLoop

@HandleShortJmp:
    ; EB XX - short jump
    ; This is more complex - may need to convert to near JMP
    jmp @CopyLoop

@DoneCopying:
    ; Add JMP back to original
    mov BYTE PTR [edi + edx], 0E9h
    
    mov eax, pOriginal
    add eax, dwStolenBytes
    
    mov ebx, pTrampBuf
    add ebx, edx
    add ebx, 5
    
    sub eax, ebx
    mov DWORD PTR [edi + edx + 1], eax
    
    popad
    mov eax, dwStolenBytes
    add eax, 5
    ret
BuildTrampolineWithFixup ENDP
```

---

## 📚 Part 5: Calling the Trampoline

### Method 1: JMP to Trampoline (Simple, loses return address)

```asm
MyHookHandler PROC
    pushad
    pushfd
    ; ... hook code ...
    popfd
    popad
    
    jmp pTrampoline     ; Jump, don't call
    ; Note: We never return here - trampoline returns to original caller
MyHookHandler ENDP
```

### Method 2: CALL Trampoline (Get return value)

```asm
MyHookHandler PROC
    ; Set up stack frame
    push ebp
    mov ebp, esp
    
    ; Save registers we'll modify
    push eax
    push ecx
    push edx
    
    ; ... hook code ...
    
    ; Restore registers
    pop edx
    pop ecx
    pop eax
    
    ; Call original via trampoline
    ; Parameters are still on stack from original call
    push [ebp+20]       ; uType
    push [ebp+16]       ; lpCaption
    push [ebp+12]       ; lpText
    push [ebp+8]        ; hWnd
    call pTrampoline    ; Trampoline will execute and return
    ; EAX = return value from original function
    
    ; We can modify return value here if needed
    
    ; Clean up and return
    mov esp, ebp
    pop ebp
    ret 16              ; Clean 4 parameters (stdcall)
MyHookHandler ENDP
```

### Method 3: Transparent Pass-through

```asm
; Most elegant - completely transparent to caller
MyHookHandler PROC
    ; We're called just like the original function
    ; Stack: [ret addr] [hWnd] [lpText] [lpCaption] [uType]
    
    ; Save context
    pushad
    pushfd
    
    ; Our hook logic (parameters at ESP+36+4, +8, +12, +16)
    ; ...
    
    ; Restore context
    popfd
    popad
    
    ; Jump to trampoline - it will return directly to caller
    jmp pTrampoline
    
    ; We never get here
MyHookHandler ENDP
```

---

## 💻 Part 6: Practical - Advanced Trampoline

### Complete Example with Trampoline Management

```asm
; trampoline_demo.asm
; Demonstrates advanced trampoline techniques

.686
.model flat, stdcall
option casemap:none

include \masm32\include\windows.inc
include \masm32\include\kernel32.inc
include \masm32\include\user32.inc
includelib \masm32\lib\kernel32.lib
includelib \masm32\lib\user32.lib

.data
    szUser32        db "user32.dll", 0
    szMsgBoxA       db "MessageBoxA", 0
    szTitle         db "Trampoline Demo", 0
    szMessage1      db "First call - hooked!", 0
    szMessage2      db "Second call - also hooked!", 0
    szDone          db "Demo complete. Check debug output.", 0
    
    szDebugPrefix   db "[HOOK] Intercepted MessageBoxA", 13, 10, 0
    szDebugReturn   db "[HOOK] Original returned: 0x", 0
    
    pOriginalFunc   dd 0
    pTrampoline     dd 0
    dwStolenBytes   dd 5
    bOriginalBytes  db 16 dup(0)
    dwOldProtect    dd 0
    dwCallCount     dd 0

.code

;----------------------------------------------------------------------
; AllocExecutableMemory
;----------------------------------------------------------------------
AllocExecutableMemory PROC dwSize:DWORD
    push PAGE_EXECUTE_READWRITE
    push MEM_COMMIT or MEM_RESERVE
    push dwSize
    push NULL
    call VirtualAlloc
    ret
AllocExecutableMemory ENDP

;----------------------------------------------------------------------
; BuildTrampoline
;----------------------------------------------------------------------
BuildTrampoline PROC
    pushad
    
    ; Allocate executable memory
    push 32
    call AllocExecutableMemory
    test eax, eax
    jz @failed
    mov pTrampoline, eax
    mov edi, eax
    
    ; Copy stolen bytes
    lea esi, bOriginalBytes
    mov ecx, dwStolenBytes
    rep movsb
    
    ; Add JMP back
    mov BYTE PTR [edi], 0E9h
    mov eax, pOriginalFunc
    add eax, dwStolenBytes
    sub eax, edi
    sub eax, 5
    mov DWORD PTR [edi+1], eax
    
    popad
    mov eax, 1
    ret

@failed:
    popad
    xor eax, eax
    ret
BuildTrampoline ENDP

;----------------------------------------------------------------------
; MyMessageBoxHook - Advanced hook with return value capture
;----------------------------------------------------------------------
MyMessageBoxHook PROC
    ; Prologue
    push ebp
    mov ebp, esp
    
    ; Save volatile registers
    push eax
    push ecx
    push edx
    
    ; Increment counter
    inc dwCallCount
    
    ; Log to debug output
    push OFFSET szDebugPrefix
    call OutputDebugStringA
    
    ; Restore volatile registers
    pop edx
    pop ecx
    pop eax
    
    ; Call original through trampoline
    ; Re-push parameters (they're still on our stack)
    push [ebp+20]       ; uType
    push [ebp+16]       ; lpCaption
    push [ebp+12]       ; lpText
    push [ebp+8]        ; hWnd
    call pTrampoline
    ; EAX = return value
    
    ; We could modify the return value here
    ; For demo, we'll just pass it through
    
    ; Epilogue
    mov esp, ebp
    pop ebp
    ret 16              ; Clean 4 DWORD parameters
MyMessageBoxHook ENDP

;----------------------------------------------------------------------
; InstallHook
;----------------------------------------------------------------------
InstallHook PROC
    pushad
    
    ; Get target function
    push OFFSET szUser32
    call GetModuleHandleA
    push OFFSET szMsgBoxA
    push eax
    call GetProcAddress
    test eax, eax
    jz @failed
    mov pOriginalFunc, eax
    
    ; Save original bytes
    mov esi, eax
    lea edi, bOriginalBytes
    mov ecx, 8
    rep movsb
    
    ; Build trampoline
    call BuildTrampoline
    test eax, eax
    jz @failed
    
    ; Patch original function
    push OFFSET dwOldProtect
    push PAGE_EXECUTE_READWRITE
    push 5
    push pOriginalFunc
    call VirtualProtect
    
    mov edi, pOriginalFunc
    mov BYTE PTR [edi], 0E9h
    mov eax, OFFSET MyMessageBoxHook
    sub eax, edi
    sub eax, 5
    mov DWORD PTR [edi+1], eax
    
    push OFFSET dwOldProtect
    push dwOldProtect
    push 5
    push pOriginalFunc
    call VirtualProtect
    
    push 5
    push pOriginalFunc
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

;----------------------------------------------------------------------
; main
;----------------------------------------------------------------------
main PROC
    call InstallHook
    test eax, eax
    jz @exit
    
    ; Test the hook
    push MB_YESNO
    push OFFSET szTitle
    push OFFSET szMessage1
    push NULL
    call MessageBoxA
    ; EAX = IDYES or IDNO
    
    push MB_OK
    push OFFSET szTitle
    push OFFSET szMessage2
    push NULL
    call MessageBoxA
    
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

### Task 1: Trampoline Verification (20 minutes)
Write a function that:
1. Verifies the trampoline was built correctly
2. Compares stolen bytes in trampoline with original
3. Verifies the JMP offset is correct

### Task 2: Return Value Modification (25 minutes)
Modify the hook to:
1. Capture the return value from MessageBoxA
2. Always return IDOK regardless of what user clicked
3. Log the original return value

### Task 3: Pre/Post Processing (30 minutes)
Create a hook that has:
1. Pre-call hook (before original is called)
2. Call to original via trampoline
3. Post-call hook (after original returns)
4. Log "PRE: MessageBoxA called" and "POST: returned X"

### Task 4: Dynamic Stolen Bytes (45 minutes)
Implement a simple instruction length decoder that:
1. Handles common x86 instructions
2. Determines how many bytes to steal (minimum 5)
3. Works with different function prologues

---

## ✅ Session Checklist

Before moving to Session 9, make sure you can:

- [ ] Explain why trampolines are necessary
- [ ] Build a basic trampoline from stolen bytes
- [ ] Calculate the JMP offset correctly
- [ ] Understand different hook-to-trampoline calling methods
- [ ] Handle the return value from the original function
- [ ] Know when instruction fixup is needed

---

## 🔜 Next Session

In **Session 09: Building a Simple Trampoline**, we'll learn:
- Step-by-step trampoline construction
- Testing and debugging trampolines
- Common trampoline bugs and fixes
- Practice exercises

[Continue to Session 09 →](session_09.md)

---

## 📖 Additional Resources

- [Hooking by Manually Modifying Function Code](https://guidedhacking.com/threads/how-to-hook-functions-code-detouring-guide.14185/)
- [x86 Instruction Encoding](https://wiki.osdev.org/X86-64_Instruction_Encoding)
- [Microsoft Detours Technical Overview](https://github.com/microsoft/Detours/wiki/Technical-Overview)
