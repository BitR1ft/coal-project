# Session 09: Building a Simple Trampoline - Hands-On

## 🎯 Learning Objectives

By the end of this session, you will:
- Build a trampoline step by step from scratch
- Debug and test trampolines
- Fix common trampoline bugs
- Complete multiple hands-on exercises

---

## 📚 Part 1: Step-by-Step Trampoline Construction

### The Complete Process

Let's build a trampoline for MessageBoxA step by step.

### Step 1: Gather Information

First, we need to know:
- Address of MessageBoxA
- First few bytes of MessageBoxA
- Where we'll store the trampoline

```asm
.data
    ; Storage
    pMessageBoxA    dd 0            ; Will hold function address
    pTrampoline     dd 0            ; Will hold trampoline address
    bStolenBytes    db 8 dup(0)     ; Save first 8 bytes (5 needed + 3 extra)
    
.code
; Get MessageBoxA address
GatherInfo PROC
    push OFFSET szUser32
    call GetModuleHandleA
    push OFFSET szMsgBoxA
    push eax
    call GetProcAddress
    mov pMessageBoxA, eax
    
    ; Copy first 8 bytes
    mov esi, eax
    lea edi, bStolenBytes
    mov ecx, 8
    rep movsb
    
    ret
GatherInfo ENDP
```

### Step 2: Analyze Stolen Bytes

For MessageBoxA, the first bytes are typically:
```
8B FF    mov edi, edi   ; 2 bytes
55       push ebp        ; 1 byte
8B EC    mov ebp, esp   ; 2 bytes
```

Total: 5 bytes - perfect!

```asm
; Verify we can steal exactly 5 bytes
VerifyPrologue PROC
    lea esi, bStolenBytes
    
    ; Check for 8B FF 55 8B EC pattern
    cmp BYTE PTR [esi], 08Bh
    jne @notHotPatch
    cmp BYTE PTR [esi+1], 0FFh
    jne @notHotPatch
    cmp BYTE PTR [esi+2], 055h
    jne @notHotPatch
    cmp BYTE PTR [esi+3], 08Bh
    jne @notHotPatch
    cmp BYTE PTR [esi+4], 0ECh
    jne @notHotPatch
    
    mov eax, 5          ; We can steal exactly 5 bytes
    ret

@notHotPatch:
    ; Different prologue - need more analysis
    xor eax, eax
    ret
VerifyPrologue ENDP
```

### Step 3: Allocate Executable Memory

```asm
AllocTrampoline PROC
    ; Allocate 32 bytes of executable memory
    push PAGE_EXECUTE_READWRITE
    push MEM_COMMIT or MEM_RESERVE
    push 32
    push NULL
    call VirtualAlloc
    mov pTrampoline, eax
    ret
AllocTrampoline ENDP
```

### Step 4: Copy Stolen Bytes

```asm
CopyStolenBytes PROC
    mov edi, pTrampoline    ; Destination: trampoline buffer
    lea esi, bStolenBytes   ; Source: saved bytes
    
    ; Copy 5 bytes
    mov cl, [esi]
    mov [edi], cl
    mov cl, [esi+1]
    mov [edi+1], cl
    mov cl, [esi+2]
    mov [edi+2], cl
    mov cl, [esi+3]
    mov [edi+3], cl
    mov cl, [esi+4]
    mov [edi+4], cl
    
    ret
CopyStolenBytes ENDP
```

### Step 5: Add JMP Back

```asm
AddJumpBack PROC
    mov edi, pTrampoline
    add edi, 5              ; Point after stolen bytes
    
    ; Write E9 (JMP opcode)
    mov BYTE PTR [edi], 0E9h
    
    ; Calculate offset
    ; Target = pMessageBoxA + 5 (skip past our hook)
    ; JMP is at pTrampoline + 5
    ; Next instruction at pTrampoline + 10
    ; Offset = Target - NextInstruction
    
    mov eax, pMessageBoxA
    add eax, 5              ; Target address
    
    mov ebx, pTrampoline
    add ebx, 10             ; Address after this JMP
    
    sub eax, ebx            ; Relative offset
    
    ; Write offset (little-endian)
    mov [edi+1], eax
    
    ret
AddJumpBack ENDP
```

### Step 6: Verify Trampoline

```asm
VerifyTrampoline PROC
    mov edi, pTrampoline
    
    ; Check stolen bytes are copied
    lea esi, bStolenBytes
    mov ecx, 5
    
@checkLoop:
    mov al, [esi]
    cmp al, [edi]
    jne @failed
    inc esi
    inc edi
    loop @checkLoop
    
    ; Check JMP opcode
    cmp BYTE PTR [edi], 0E9h
    jne @failed
    
    mov eax, 1
    ret

@failed:
    xor eax, eax
    ret
VerifyTrampoline ENDP
```

---

## 📚 Part 2: Testing the Trampoline

### Test Method 1: Direct Call

```asm
TestTrampoline PROC
    ; Call the trampoline directly with MessageBoxA parameters
    push MB_OK
    push OFFSET szTestCaption
    push OFFSET szTestMessage
    push NULL
    
    call pTrampoline        ; Call trampoline, not MessageBoxA
    
    ; If we see the message box, trampoline works!
    ret
TestTrampoline ENDP
```

### Test Method 2: Compare Results

```asm
CompareResults PROC
    ; Call original (before installing hook)
    push MB_OK
    push OFFSET szCaption
    push OFFSET szMessage
    push NULL
    call MessageBoxA        ; Use IAT (original)
    mov ebx, eax            ; Save result
    
    ; Call trampoline
    push MB_OK
    push OFFSET szCaption
    push OFFSET szMessage
    push NULL
    call pTrampoline
    
    ; Compare results
    cmp eax, ebx
    je @success
    
    ; Different results - problem!
    xor eax, eax
    ret

@success:
    mov eax, 1
    ret
CompareResults ENDP
```

---

## 📚 Part 3: Common Trampoline Bugs

### Bug 1: Wrong JMP Offset Calculation

**Symptom**: Crash when calling trampoline

**Cause**: Forgot to subtract 5 for instruction size

```asm
; WRONG
mov eax, pMessageBoxA
add eax, 5
sub eax, pTrampoline
sub eax, 5
; Result points to wrong location!

; CORRECT
mov eax, pMessageBoxA
add eax, 5              ; Target
mov ebx, pTrampoline
add ebx, 5              ; Where JMP is
add ebx, 5              ; Next instruction (JMP is 5 bytes)
sub eax, ebx            ; Offset = Target - NextInstr
```

### Bug 2: Non-Executable Memory

**Symptom**: Access violation when calling trampoline

**Cause**: Forgot PAGE_EXECUTE_READWRITE

```asm
; WRONG
push PAGE_READWRITE     ; Can't execute!
push MEM_COMMIT
push 32
push NULL
call VirtualAlloc

; CORRECT
push PAGE_EXECUTE_READWRITE
push MEM_COMMIT or MEM_RESERVE
push 32
push NULL
call VirtualAlloc
```

### Bug 3: Incomplete Instruction Copy

**Symptom**: Random behavior or crash

**Cause**: Stole middle of an instruction

```asm
; If function starts with:
; B8 12 34 56 78    mov eax, 78563412  (5 bytes)
; 89 E5             mov ebp, esp       (2 bytes)

; Stealing 5 bytes is fine (complete instruction)
; But if function starts with:
; 55                push ebp           (1 byte)
; 8B EC             mov ebp, esp       (2 bytes)
; 83 EC 20          sub esp, 20h       (3 bytes)

; Stealing 5 bytes cuts "sub esp, 20h" in half!
; Solution: Steal 6 bytes (1+2+3 = 6)
```

### Bug 4: Register Corruption

**Symptom**: Program behaves incorrectly after hooked call

**Cause**: Hook modifies registers that caller expects preserved

```asm
; WRONG - Corrupts EBX which caller might need
MyHook PROC
    mov ebx, 12345      ; EBX is non-volatile!
    jmp pTrampoline
MyHook ENDP

; CORRECT - Save and restore
MyHook PROC
    push ebx
    mov ebx, 12345
    pop ebx
    jmp pTrampoline
MyHook ENDP
```

---

## 💻 Part 4: Complete Working Example

```asm
; trampoline_builder.asm
; Complete step-by-step trampoline builder

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
    
    szStep1         db "Step 1: Got MessageBoxA address", 0
    szStep2         db "Step 2: Saved original bytes", 0
    szStep3         db "Step 3: Allocated trampoline memory", 0
    szStep4         db "Step 4: Built trampoline", 0
    szStep5         db "Step 5: Testing via direct call...", 0
    szSuccess       db "TRAMPOLINE WORKS!", 0
    szFailed        db "Trampoline failed!", 0
    szTitle         db "Trampoline Builder", 0
    
    ; Storage
    pMessageBoxA    dd 0
    pTrampoline     dd 0
    bStolenBytes    db 16 dup(0)
    
.code

;----------------------------------------------------------------------
; DisplayStep - Show progress
;----------------------------------------------------------------------
DisplayStep PROC pMessage:DWORD
    push MB_OK
    push OFFSET szTitle
    push pMessage
    push NULL
    call MessageBoxA
    ret
DisplayStep ENDP

;----------------------------------------------------------------------
; Step1_GetAddress
;----------------------------------------------------------------------
Step1_GetAddress PROC
    push OFFSET szUser32
    call GetModuleHandleA
    test eax, eax
    jz @failed
    
    push OFFSET szMsgBoxA
    push eax
    call GetProcAddress
    test eax, eax
    jz @failed
    
    mov pMessageBoxA, eax
    
    push OFFSET szStep1
    call DisplayStep
    
    mov eax, 1
    ret
    
@failed:
    xor eax, eax
    ret
Step1_GetAddress ENDP

;----------------------------------------------------------------------
; Step2_SaveBytes
;----------------------------------------------------------------------
Step2_SaveBytes PROC
    mov esi, pMessageBoxA
    lea edi, bStolenBytes
    
    ; Copy 8 bytes (more than we need)
    mov ecx, 8
    rep movsb
    
    push OFFSET szStep2
    call DisplayStep
    
    mov eax, 1
    ret
Step2_SaveBytes ENDP

;----------------------------------------------------------------------
; Step3_AllocateMemory
;----------------------------------------------------------------------
Step3_AllocateMemory PROC
    push PAGE_EXECUTE_READWRITE
    push MEM_COMMIT or MEM_RESERVE
    push 32
    push NULL
    call VirtualAlloc
    test eax, eax
    jz @failed
    
    mov pTrampoline, eax
    
    push OFFSET szStep3
    call DisplayStep
    
    mov eax, 1
    ret
    
@failed:
    xor eax, eax
    ret
Step3_AllocateMemory ENDP

;----------------------------------------------------------------------
; Step4_BuildTrampoline
;----------------------------------------------------------------------
Step4_BuildTrampoline PROC
    ; Copy 5 stolen bytes
    mov edi, pTrampoline
    lea esi, bStolenBytes
    mov ecx, 5
    rep movsb
    
    ; EDI now at pTrampoline + 5
    ; Write JMP E9
    mov BYTE PTR [edi], 0E9h
    
    ; Calculate offset
    mov eax, pMessageBoxA
    add eax, 5                  ; Target: original + 5
    
    mov ebx, pTrampoline
    add ebx, 10                 ; NextInstr: trampoline + 5 + 5
    
    sub eax, ebx                ; Offset
    mov [edi+1], eax
    
    push OFFSET szStep4
    call DisplayStep
    
    mov eax, 1
    ret
Step4_BuildTrampoline ENDP

;----------------------------------------------------------------------
; Step5_TestTrampoline
;----------------------------------------------------------------------
Step5_TestTrampoline PROC
    push OFFSET szStep5
    call DisplayStep
    
    ; Call trampoline directly
    push MB_ICONINFORMATION
    push OFFSET szTitle
    push OFFSET szSuccess
    push NULL
    call pTrampoline            ; Call trampoline!
    
    ; If we get here and saw the message, it worked!
    ret
Step5_TestTrampoline ENDP

;----------------------------------------------------------------------
; main
;----------------------------------------------------------------------
main PROC
    ; Step 1: Get function address
    call Step1_GetAddress
    test eax, eax
    jz @failed
    
    ; Step 2: Save original bytes
    call Step2_SaveBytes
    test eax, eax
    jz @failed
    
    ; Step 3: Allocate executable memory
    call Step3_AllocateMemory
    test eax, eax
    jz @failed
    
    ; Step 4: Build the trampoline
    call Step4_BuildTrampoline
    test eax, eax
    jz @failed
    
    ; Step 5: Test it!
    call Step5_TestTrampoline
    
    jmp @exit
    
@failed:
    push MB_ICONERROR
    push OFFSET szTitle
    push OFFSET szFailed
    push NULL
    call MessageBoxA
    
@exit:
    push 0
    call ExitProcess
main ENDP

END main
```

---

## 💻 Part 5: Debugging Trampolines

### Using Debug Output

```asm
; Debug helper: Print bytes
PrintBytes PROC pBytes:DWORD, dwCount:DWORD
    LOCAL szBuffer[64]:BYTE
    
    pushad
    
    lea edi, szBuffer
    mov esi, pBytes
    mov ecx, dwCount
    
@loop:
    movzx eax, BYTE PTR [esi]
    ; Convert to hex and store in szBuffer
    ; (simplified - would use wsprintfA in real code)
    inc esi
    loop @loop
    
    lea eax, szBuffer
    push eax
    call OutputDebugStringA
    
    popad
    ret
PrintBytes ENDP
```

### Using x64dbg

1. Load your program in x64dbg
2. Set breakpoint at trampoline address
3. Step through and verify:
   - Stolen bytes execute correctly
   - JMP goes to correct address
   - Stack is correct after execution

---

## 📝 Part 6: Tasks

### Task 1: Manual Byte Calculation (20 minutes)
Given:
- MessageBoxA at 0x77D10000
- Trampoline at 0x00A00000

Calculate by hand:
1. What bytes go at trampoline+0 through +4?
2. What bytes go at trampoline+5 through +9?
3. Show all your work!

### Task 2: Different Prologues (30 minutes)
Create trampolines for these prologues:
```
Prologue A: 55 8B EC 83 EC 20
Prologue B: 8B FF 55 8B EC
Prologue C: 55 8B EC 53 56
```
How many bytes must you steal for each?

### Task 3: Trampoline Verifier (30 minutes)
Write a function that verifies a trampoline is correct:
1. Check stolen bytes match original
2. Check JMP opcode is 0xE9
3. Calculate expected offset and compare
4. Return TRUE if all checks pass

### Task 4: Create Test Suite (40 minutes)
Build a test program that:
1. Creates 3 trampolines for different functions
2. Tests each one individually
3. Reports pass/fail for each
4. Shows debug info on failure

---

## ✅ Session Checklist

Before moving to Session 10, make sure you can:

- [ ] Build a trampoline manually, step by step
- [ ] Calculate JMP offsets correctly
- [ ] Debug common trampoline problems
- [ ] Verify trampoline correctness
- [ ] Test trampolines before using in hooks

---

## 🔜 Next Session

In **Session 10: Hooking MessageBoxA - Complete Implementation**, we'll:
- Put everything together
- Create a complete MessageBoxA hook
- Add logging functionality
- Handle edge cases

[Continue to Session 10 →](session_10.md)

---

## 📖 Additional Resources

- [x64dbg Documentation](https://help.x64dbg.com/)
- [WinDbg Commands](https://docs.microsoft.com/en-us/windows-hardware/drivers/debugger/)
- [Assembly Debugging Tips](https://stackoverflow.com/questions/tagged/assembly+debugging)
