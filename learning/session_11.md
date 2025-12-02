# Session 11: Register Preservation with PUSHAD/POPAD

## 🎯 Learning Objectives

By the end of this session, you will:
- Master register preservation in hooks
- Know when to use PUSHAD vs selective saves
- Understand performance implications
- Handle EFLAGS correctly

---

## 📚 Part 1: Why Register Preservation Matters

### The Problem

When your hook runs, you're interrupting normal program execution. The code that called the hooked function expects certain register values to be preserved.

```
┌─────────────────────────────────────────────────────────────────┐
│                  REGISTER CORRUPTION SCENARIO                    │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  CALLING CODE:                                                   │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │ mov ebx, important_value    ; EBX = something important  │    │
│  │ push params                                              │    │
│  │ call MessageBoxA            ; ← Hooked!                 │    │
│  │ mov [result], ebx           ; Expects EBX unchanged!    │    │
│  └─────────────────────────────────────────────────────────┘    │
│                                                                  │
│  YOUR HOOK (BAD):                                                │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │ mov ebx, counter            ; ← Corrupts EBX!           │    │
│  │ inc ebx                                                 │    │
│  │ mov counter, ebx                                        │    │
│  │ jmp trampoline                                          │    │
│  └─────────────────────────────────────────────────────────┘    │
│                                                                  │
│  RESULT: Caller's EBX is corrupted!                             │
│          Program may crash or behave incorrectly                │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### Register Categories

| Category | Registers | Rule |
|----------|-----------|------|
| **Volatile** | EAX, ECX, EDX | Caller expects these MAY change |
| **Non-volatile** | EBX, ESI, EDI, EBP | Caller expects these PRESERVED |
| **Special** | ESP | Stack pointer - always preserve! |
| **Return** | EAX | Function return value |
| **Flags** | EFLAGS | Often overlooked - important! |

---

## 📚 Part 2: PUSHAD and POPAD

### What PUSHAD Does

**PUSHAD** pushes all 8 general-purpose registers onto the stack:

```asm
; PUSHAD is equivalent to:
push eax
push ecx
push edx
push ebx
push esp        ; Value BEFORE pushad
push ebp
push esi
push edi
```

### Stack Layout After PUSHAD

```
Before PUSHAD:          After PUSHAD:
                        
ESP → [old data]        [old data]
                        [EAX]       ← ESP + 28
                        [ECX]       ← ESP + 24
                        [EDX]       ← ESP + 20
                        [EBX]       ← ESP + 16
                        [orig ESP]  ← ESP + 12
                        [EBP]       ← ESP + 8
                        [ESI]       ← ESP + 4
                  ESP → [EDI]       ← ESP + 0
```

### What POPAD Does

**POPAD** restores all registers in reverse order:

```asm
; POPAD is equivalent to:
pop edi
pop esi
pop ebp
add esp, 4      ; Skip saved ESP (we use current ESP)
pop ebx
pop edx
pop ecx
pop eax
```

### Basic Usage Pattern

```asm
MyHook PROC
    pushad              ; Save all registers
    pushfd              ; Save flags
    
    ; ═══════════════════════════════════════
    ; Your hook code here
    ; You can freely use ANY register
    mov eax, 1
    mov ebx, 2
    mov ecx, 3
    ; ... etc ...
    ; ═══════════════════════════════════════
    
    popfd               ; Restore flags
    popad               ; Restore all registers
    
    jmp trampoline
MyHook ENDP
```

---

## 📚 Part 3: EFLAGS Preservation

### Why EFLAGS Matter

The EFLAGS register contains status flags that many instructions modify:

| Flag | Bit | Purpose |
|------|-----|---------|
| CF | 0 | Carry flag |
| PF | 2 | Parity flag |
| AF | 4 | Auxiliary carry |
| ZF | 6 | Zero flag |
| SF | 7 | Sign flag |
| OF | 11 | Overflow flag |
| DF | 10 | Direction flag |

### The Problem with Flags

```asm
; CALLING CODE:
    cmp eax, ebx            ; Sets flags based on comparison
    call HookedFunction     ; ← Your hook runs
    je equal                ; Uses flags from BEFORE the call!

; YOUR HOOK (BAD):
MyHook:
    pushad                  ; Saves registers but NOT flags
    inc counter             ; ← Changes Zero Flag!
    test ecx, ecx           ; ← Changes multiple flags!
    popad
    jmp trampoline

; RESULT: The JE after the call uses wrong flags!
```

### The Solution: PUSHFD/POPFD

```asm
MyHook:
    pushad                  ; Save registers
    pushfd                  ; Save flags AFTER pushad
    
    ; Your code (flags can change)
    inc counter
    test ecx, ecx
    
    popfd                   ; Restore flags BEFORE popad
    popad                   ; Restore registers
    jmp trampoline
```

### Order Matters!

```asm
; CORRECT order:
pushad      ; First - save registers
pushfd      ; Second - save flags
; ... code ...
popfd       ; First - restore flags
popad       ; Second - restore registers

; WRONG order would corrupt stack!
```

---

## 📚 Part 4: Selective Register Saving

### When PUSHAD is Overkill

If your hook only uses a few registers, PUSHAD/POPAD is inefficient:

```asm
; Using PUSHAD/POPAD: 16 bytes pushed, 16 bytes popped
MyHook:
    pushad              ; 1 byte
    pushfd              ; 1 byte
    
    inc dwCounter       ; Only uses memory!
    
    popfd               ; 1 byte
    popad               ; 1 byte
    jmp trampoline

; More efficient: Don't save anything!
MyHook:
    inc dwCounter       ; Just does the increment
    jmp trampoline      ; Nothing to restore
```

### Selective Saving

```asm
; Only save what you'll modify
MyHook:
    push eax                ; Only using EAX
    push ecx                ; Only using ECX
    pushfd                  ; Always save flags if doing comparisons
    
    mov eax, [counter]
    inc eax
    mov [counter], eax
    
    popfd
    pop ecx
    pop eax
    jmp trampoline
```

### Trade-offs

| Approach | Pros | Cons |
|----------|------|------|
| PUSHAD/POPAD | Simple, safe | Slower, uses more stack |
| Selective | Faster | Must track what you use |
| No saving | Fastest | Only for volatile regs |

---

## 📚 Part 5: Stack Frame Considerations

### Accessing Parameters After PUSHAD

After PUSHAD/PUSHFD, the stack has 36 extra bytes:
- PUSHAD: 8 registers × 4 bytes = 32 bytes
- PUSHFD: 4 bytes

```asm
; Before hook runs:
; [ESP+0]  = Return address
; [ESP+4]  = Parameter 1
; [ESP+8]  = Parameter 2
; [ESP+12] = Parameter 3
; [ESP+16] = Parameter 4

; After PUSHAD/PUSHFD in hook:
; [ESP+0]  = EFLAGS (from PUSHFD)
; [ESP+4]  = EDI (from PUSHAD)
; [ESP+8]  = ESI
; [ESP+12] = EBP
; [ESP+16] = ESP (original)
; [ESP+20] = EBX
; [ESP+24] = EDX
; [ESP+28] = ECX
; [ESP+32] = EAX
; [ESP+36] = Return address      ← Add 36 to original offsets!
; [ESP+40] = Parameter 1
; [ESP+44] = Parameter 2
; [ESP+48] = Parameter 3
; [ESP+52] = Parameter 4
```

### Accessing Parameters Example

```asm
MyHook:
    pushad
    pushfd
    
    ; Access parameter 1 (e.g., hWnd for MessageBox)
    mov eax, [esp + 40]     ; 36 (pushad/pushfd) + 4 (ret addr) = 40
    
    ; Access parameter 2 (e.g., lpText)
    mov ebx, [esp + 44]
    
    popfd
    popad
    jmp trampoline
```

### Using EBP for Clearer Access

```asm
MyHook:
    push ebp
    mov ebp, esp
    pushad
    pushfd
    
    ; Now parameters are at fixed EBP offsets:
    ; [EBP+8]  = Parameter 1 (ret addr at +4, saved EBP at +0)
    ; But wait - we pushed more after setting EBP!
    
    ; Better approach:
MyHook2:
    pushad
    pushfd
    
    ; Use ESP directly with known offset
    mov eax, [esp + 40]     ; First parameter
    
    popfd
    popad
    jmp trampoline
```

---

## 📚 Part 6: Complete Examples

### Example 1: Safe Counter Hook

```asm
;-------------------------------------------------------------------------------
; SafeCounterHook - Safely counts calls
;-------------------------------------------------------------------------------
SafeCounterHook PROC
    ; Save everything
    pushad
    pushfd
    
    ; Safe to use any registers now
    inc dword ptr [dwCallCount]
    
    ; Restore everything
    popfd
    popad
    
    ; Continue to original
    jmp pTrampoline
SafeCounterHook ENDP
```

### Example 2: Hook with Parameter Logging

```asm
;-------------------------------------------------------------------------------
; LoggingHook - Logs first parameter
;-------------------------------------------------------------------------------
LoggingHook PROC
    pushad
    pushfd
    
    ; Get first parameter
    mov eax, [esp + 40]     ; After pushad(32) + pushfd(4) + ret(4)
    
    ; Log it (OutputDebugStringA if it's a string)
    test eax, eax
    jz @noParam
    push eax
    call OutputDebugStringA
@noParam:
    
    popfd
    popad
    jmp pTrampoline
LoggingHook ENDP
```

### Example 3: Conditional Hook

```asm
;-------------------------------------------------------------------------------
; ConditionalHook - Only logs certain calls
;-------------------------------------------------------------------------------
ConditionalHook PROC
    pushad
    pushfd
    
    ; Check parameter value
    mov eax, [esp + 40]
    test eax, eax
    jz @skip                ; Skip if NULL
    
    ; Check first character
    cmp byte ptr [eax], 'E'
    jne @skip               ; Skip if not starting with 'E'
    
    ; Log this call
    push OFFSET szMatched
    call OutputDebugStringA
    inc dwMatchCount
    
@skip:
    popfd
    popad
    jmp pTrampoline
ConditionalHook ENDP
```

### Example 4: Optimized Hook (Selective Save)

```asm
;-------------------------------------------------------------------------------
; OptimizedHook - Only saves what's needed
;-------------------------------------------------------------------------------
OptimizedHook PROC
    ; We only use EAX and modify flags
    push eax
    pushfd
    
    ; Simple increment
    mov eax, [dwCounter]
    inc eax
    mov [dwCounter], eax
    
    popfd
    pop eax
    jmp pTrampoline
OptimizedHook ENDP
```

---

## 💻 Part 7: Practical Exercises

### Exercise 1: Verify Preservation

```asm
; Test that registers are preserved
TestPreservation PROC
    ; Set known values
    mov eax, 11111111h
    mov ebx, 22222222h
    mov ecx, 33333333h
    mov edx, 44444444h
    mov esi, 55555555h
    mov edi, 66666666h
    
    ; Call hooked function
    push MB_OK
    push OFFSET szCaption
    push OFFSET szText
    push NULL
    call MessageBoxA
    
    ; Verify non-volatile registers
    cmp ebx, 22222222h
    jne @ebxCorrupted
    cmp esi, 55555555h
    jne @esiCorrupted
    cmp edi, 66666666h
    jne @ediCorrupted
    
    ; All good!
    ret
    
@ebxCorrupted:
@esiCorrupted:
@ediCorrupted:
    ; Show error
    ret
TestPreservation ENDP
```

### Exercise 2: Flag Preservation Test

```asm
TestFlagPreservation PROC
    ; Set up comparison
    mov eax, 5
    cmp eax, 5          ; Sets ZF=1
    
    ; Call hooked function
    push MB_OK
    push OFFSET szCaption
    push OFFSET szText
    push NULL
    call MessageBoxA
    
    ; Check if ZF is still set
    jnz @flagsCorrupted
    
    ; Flags preserved!
    ret
    
@flagsCorrupted:
    ; Show error
    ret
TestFlagPreservation ENDP
```

---

## 📝 Part 8: Tasks

### Task 1: Stack Diagram (20 minutes)
Draw the complete stack after:
1. Function call pushes 4 parameters
2. CALL instruction pushes return address
3. Hook does PUSHAD then PUSHFD

Show every value and its ESP offset.

### Task 2: Optimized Hook (25 minutes)
Write a hook that:
1. Only increments a counter
2. Uses minimum possible stack space
3. Still preserves flags properly

### Task 3: Parameter Extraction (30 minutes)
Write a hook that:
1. Extracts all 4 MessageBox parameters
2. Stores them in global variables
3. Uses correct ESP offsets

### Task 4: Preservation Tester (35 minutes)
Create a test program that:
1. Sets all registers to known values
2. Calls a hooked function
3. Verifies all non-volatile registers
4. Reports pass/fail for each register

---

## ✅ Session Checklist

Before moving to Session 12, make sure you can:

- [ ] Explain volatile vs non-volatile registers
- [ ] Use PUSHAD/POPAD correctly
- [ ] Always save EFLAGS with PUSHFD/POPFD
- [ ] Calculate correct ESP offsets for parameters
- [ ] Choose between full and selective saving
- [ ] Verify register preservation works

---

## 🔜 Next Session

In **Session 12: Thread Safety in Hooking**, we'll learn:
- Why hooks must be thread-safe
- Critical sections in assembly
- Atomic operations
- Thread-local storage

[Continue to Session 12 →](session_12.md)

---

## 📖 Additional Resources

- [x86 Calling Conventions](https://docs.microsoft.com/en-us/cpp/cpp/calling-conventions)
- [PUSHAD/POPAD Reference](https://www.felixcloutier.com/x86/pusha:pushad)
- [EFLAGS Register](https://en.wikipedia.org/wiki/FLAGS_register)
