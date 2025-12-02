# Session 05: Your First Hook - Concept and Design

## 🎯 Learning Objectives

By the end of this session, you will:
- Understand the complete hook installation process
- Know what "stolen bytes" are and why they matter
- Design a basic hook handler
- Understand the difference between hooks and trampolines
- Create your first conceptual hook

---

## 📚 Part 1: Theory - The Hook Installation Process

### Overview of Hook Installation

Installing a hook involves these steps:

```
┌─────────────────────────────────────────────────────────────────┐
│                 HOOK INSTALLATION PROCESS                        │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  Step 1: LOCATE TARGET                                          │
│  ┌─────────────────────────────────────────┐                    │
│  │ GetModuleHandle("user32.dll")           │                    │
│  │ GetProcAddress(handle, "MessageBoxA")   │                    │
│  │ → Get address: 0x77D507EA               │                    │
│  └─────────────────────────────────────────┘                    │
│                         │                                        │
│                         ▼                                        │
│  Step 2: SAVE ORIGINAL BYTES                                    │
│  ┌─────────────────────────────────────────┐                    │
│  │ Copy first 5 bytes: 8B FF 55 8B EC      │                    │
│  │ Store in: bOriginalBytes[5]             │                    │
│  └─────────────────────────────────────────┘                    │
│                         │                                        │
│                         ▼                                        │
│  Step 3: CHANGE MEMORY PROTECTION                               │
│  ┌─────────────────────────────────────────┐                    │
│  │ VirtualProtect → PAGE_EXECUTE_READWRITE │                    │
│  │ Save old protection                     │                    │
│  └─────────────────────────────────────────┘                    │
│                         │                                        │
│                         ▼                                        │
│  Step 4: WRITE JMP INSTRUCTION                                  │
│  ┌─────────────────────────────────────────┐                    │
│  │ [target+0] = 0xE9 (JMP opcode)          │                    │
│  │ [target+1..4] = relative offset         │                    │
│  └─────────────────────────────────────────┘                    │
│                         │                                        │
│                         ▼                                        │
│  Step 5: RESTORE PROTECTION & FLUSH                             │
│  ┌─────────────────────────────────────────┐                    │
│  │ VirtualProtect → original protection    │                    │
│  │ FlushInstructionCache                   │                    │
│  └─────────────────────────────────────────┘                    │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

---

## 📚 Part 2: Understanding "Stolen Bytes"

### What are Stolen Bytes?

When we write our JMP instruction (5 bytes), we **overwrite** the original instructions. These overwritten bytes are called **"stolen bytes"**.

```
BEFORE HOOKING:
Address     Bytes           Instruction
─────────────────────────────────────────
0x77D507EA  8B FF          mov edi, edi     ← Will be overwritten
0x77D507EC  55             push ebp         ← Will be overwritten
0x77D507ED  8B EC          mov ebp, esp     ← Partially overwritten
0x77D507EF  ...            (rest of function)

AFTER HOOKING:
Address     Bytes           Instruction
─────────────────────────────────────────
0x77D507EA  E9 XX XX XX XX JMP HookHandler  ← Our 5-byte hook
0x77D507EF  ...            (rest of function - unchanged)
```

### Why Stolen Bytes Matter

1. **We must SAVE them** - We need to execute them later
2. **Instruction boundaries** - We can't cut an instruction in half
3. **Trampoline needs them** - To call the original function

### Instruction Boundary Problem

Consider this scenario:
```
Address     Bytes           Instruction
─────────────────────────────────────────
0x00401000  B8 12 34 56 78  mov eax, 78563412   ← 5-byte instruction
0x00401005  C3              ret

If we try to steal 5 bytes starting here:
- We'd steal the ENTIRE mov instruction
- That's GOOD - no broken instructions

But what if:
Address     Bytes           Instruction
─────────────────────────────────────────
0x00401000  89 E5           mov ebp, esp        ← 2 bytes
0x00401002  83 EC 10        sub esp, 10h        ← 3 bytes
0x00401005  ...

If we steal 5 bytes:
- We get: 89 E5 83 EC 10
- mov ebp, esp (2 bytes) - COMPLETE
- sub esp, 10h (3 bytes) - COMPLETE
- Total: 5 bytes - PERFECT!

But what if:
Address     Bytes           Instruction
─────────────────────────────────────────
0x00401000  89 E5           mov ebp, esp        ← 2 bytes
0x00401002  B8 12 34 56 78  mov eax, 78563412   ← 5 bytes

If we steal 5 bytes:
- We get: 89 E5 B8 12 34
- mov ebp, esp (2 bytes) - COMPLETE
- B8 12 34 - BROKEN! (incomplete mov eax, XXX)
- THIS WOULD CRASH!
```

### The "Hot Patch" Solution

Microsoft made this easier! Many Windows functions start with:

```asm
mov edi, edi     ; 8B FF - 2 bytes (does NOTHING - NOP equivalent!)
push ebp         ; 55    - 1 byte
mov ebp, esp     ; 8B EC - 2 bytes
                 ; Total: 5 bytes exactly!
```

The `mov edi, edi` is a deliberate 2-byte NOP to allow easy patching!

---

## 📚 Part 3: The JMP Instruction

### Understanding Relative JMP

The JMP instruction we use is `E9` followed by a **relative offset**:

```
┌────┬────┬────┬────┬────┐
│ E9 │ XX │ XX │ XX │ XX │  = 5 bytes total
└────┴────┴────┴────┴────┘
  │     └───────┬───────┘
  │             │
Opcode    Relative offset (signed 32-bit)
```

### Calculating the Offset

The offset is calculated as:
```
offset = destination - source - 5
```

Why `-5`? Because the offset is relative to the NEXT instruction (after the JMP).

### Example Calculation

```
Hook target:   0x77D507EA (MessageBoxA)
Hook handler:  0x00401000 (our function)

offset = 0x00401000 - 0x77D507EA - 5
       = 0x00401000 - 0x77D507EF
       = 0x886AF811 (as signed: negative number, jump backwards)

Final bytes at 0x77D507EA:
E9 11 F8 6A 88
```

### In Assembly

```asm
; Calculate and write JMP
mov edi, pTargetFunc         ; EDI = address to modify
mov BYTE PTR [edi], 0E9h     ; Write JMP opcode

mov eax, pHookHandler        ; EAX = our hook address
sub eax, edi                 ; EAX = hook - target
sub eax, 5                   ; Adjust for instruction size
mov DWORD PTR [edi+1], eax   ; Write the offset
```

---

## 📚 Part 4: Designing the Hook Handler

### What the Hook Handler Does

When our hook triggers, we need to:

```
┌─────────────────────────────────────────────────────────────────┐
│                    HOOK HANDLER FLOW                             │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  1. SAVE STATE                                                   │
│     └─ PUSHAD, PUSHFD (save all registers)                      │
│                                                                  │
│  2. DO OUR WORK                                                  │
│     ├─ Log the call                                              │
│     ├─ Inspect parameters                                        │
│     ├─ Modify parameters (optional)                              │
│     └─ Make decisions                                            │
│                                                                  │
│  3. RESTORE STATE                                                │
│     └─ POPFD, POPAD (restore all registers)                     │
│                                                                  │
│  4. CALL ORIGINAL (via trampoline)                              │
│     └─ Execute stolen bytes + JMP back                          │
│                                                                  │
│  5. RETURN TO CALLER                                             │
│     └─ Original return value in EAX                             │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### Basic Hook Handler Template

```asm
; Our hook handler for MessageBoxA
MyMessageBoxAHook PROC
    ; ═══════════════════════════════════════════════════
    ; PHASE 1: Save all registers
    ; ═══════════════════════════════════════════════════
    pushad                      ; Save EAX, ECX, EDX, EBX, ESP, EBP, ESI, EDI
    pushfd                      ; Save EFLAGS
    
    ; ═══════════════════════════════════════════════════
    ; PHASE 2: Our hook logic
    ; ═══════════════════════════════════════════════════
    ; At this point:
    ;   [ESP + 36] = Return address (after pushad/pushfd)
    ;   [ESP + 40] = Parameter 1 (hWnd)
    ;   [ESP + 44] = Parameter 2 (lpText)
    ;   [ESP + 48] = Parameter 3 (lpCaption)
    ;   [ESP + 52] = Parameter 4 (uType)
    
    ; Example: Log that we intercepted the call
    push OFFSET szIntercepted
    call OutputDebugStringA
    
    ; Example: Increment call counter
    inc dwCallCount
    
    ; ═══════════════════════════════════════════════════
    ; PHASE 3: Restore all registers
    ; ═══════════════════════════════════════════════════
    popfd                       ; Restore EFLAGS
    popad                       ; Restore all registers
    
    ; ═══════════════════════════════════════════════════
    ; PHASE 4: Call original function via trampoline
    ; ═══════════════════════════════════════════════════
    jmp pTrampoline             ; Jump to trampoline
    
MyMessageBoxAHook ENDP
```

---

## 📚 Part 5: The Trampoline

### What is a Trampoline?

A **trampoline** is a small piece of code that:
1. Executes the stolen bytes
2. Jumps back to the original function (after the hook)

```
┌─────────────────────────────────────────────────────────────────┐
│                    TRAMPOLINE STRUCTURE                          │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ORIGINAL FUNCTION (after hook):                                 │
│  0x77D507EA: E9 XX XX XX XX  JMP MyHook                         │
│  0x77D507EF: 83 EC 50        sub esp, 50h   ← Continue from here │
│                                                                  │
│  TRAMPOLINE (allocated memory):                                  │
│  ┌─────────────────────────────────────────┐                    │
│  │ 8B FF           mov edi, edi  (stolen)  │                    │
│  │ 55              push ebp      (stolen)  │                    │
│  │ 8B EC           mov ebp, esp  (stolen)  │                    │
│  │ E9 XX XX XX XX  JMP 0x77D507EF          │                    │
│  └─────────────────────────────────────────┘                    │
│                                                                  │
│  FLOW:                                                           │
│  1. Caller calls MessageBoxA                                     │
│  2. JMP to MyHook                                                │
│  3. MyHook does its work                                         │
│  4. MyHook calls trampoline                                      │
│  5. Trampoline executes stolen bytes                            │
│  6. Trampoline JMPs to original+5                               │
│  7. Original function continues normally                         │
│  8. Original function returns to caller                          │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### Building the Trampoline

```asm
; Build trampoline for our hook
BuildTrampoline PROC pOriginal:DWORD, pTrampBuffer:DWORD, dwStolenSize:DWORD
    pushad
    
    ; Copy stolen bytes to trampoline
    mov esi, pOriginal          ; Source: original function
    mov edi, pTrampBuffer       ; Dest: trampoline buffer
    mov ecx, dwStolenSize       ; How many bytes
    rep movsb                   ; Copy!
    
    ; Now EDI points right after stolen bytes
    ; Add JMP back to original function + stolen size
    mov BYTE PTR [edi], 0E9h    ; JMP opcode
    
    ; Calculate offset: (original + stolenSize) - (trampoline + stolenSize + 5)
    mov eax, pOriginal
    add eax, dwStolenSize       ; Where to jump back to
    
    mov ebx, pTrampBuffer
    add ebx, dwStolenSize       ; Address of this JMP
    add ebx, 5                  ; Next instruction after JMP
    
    sub eax, ebx                ; Relative offset
    mov DWORD PTR [edi+1], eax  ; Store offset
    
    popad
    ret
BuildTrampoline ENDP
```

---

## 📚 Part 6: Complete Hook Flow

### Visual Flow Diagram

```
┌──────────────────────────────────────────────────────────────────────────┐
│                        COMPLETE HOOK EXECUTION FLOW                       │
├──────────────────────────────────────────────────────────────────────────┤
│                                                                           │
│    CALLER                                                                 │
│    ┌─────────────────────┐                                               │
│    │ call MessageBoxA    │                                               │
│    │   push MB_OK        │                                               │
│    │   push "Title"      │                                               │
│    │   push "Text"       │                                               │
│    │   push NULL         │                                               │
│    │   call [IAT entry]  │───────────────────────────────┐               │
│    └─────────────────────┘                               │               │
│                                                          │               │
│                                                          ▼               │
│    ORIGINAL MESSAGEBOXA (HOOKED)                                         │
│    ┌─────────────────────────────────────────────────────┐               │
│ ┌─▶│ 0x77D507EA: E9 XX XX XX XX  JMP HookHandler         │               │
│ │  │ 0x77D507EF: (rest of function...)                   │               │
│ │  └───────────────────────────────┬─────────────────────┘               │
│ │                                  │                                      │
│ │                                  ▼                                      │
│ │  OUR HOOK HANDLER                                                       │
│ │  ┌─────────────────────────────────────────────────────┐               │
│ │  │ pushad / pushfd                                     │               │
│ │  │ ; Log the call                                      │               │
│ │  │ ; Inspect parameters                                │               │
│ │  │ popfd / popad                                       │               │
│ │  │ jmp Trampoline ─────────────────────────┐           │               │
│ │  └─────────────────────────────────────────│───────────┘               │
│ │                                            │                            │
│ │                                            ▼                            │
│ │  TRAMPOLINE                                                             │
│ │  ┌─────────────────────────────────────────────────────┐               │
│ │  │ mov edi, edi   (stolen byte 1-2)                    │               │
│ │  │ push ebp       (stolen byte 3)                      │               │
│ │  │ mov ebp, esp   (stolen byte 4-5)                    │               │
│ │  │ jmp 0x77D507EF ─────────────────────────┐           │               │
│ │  └─────────────────────────────────────────│───────────┘               │
│ │                                            │                            │
│ │                                            ▼                            │
│ │  ORIGINAL FUNCTION (AFTER HOOK)                                         │
│ │  ┌─────────────────────────────────────────────────────┐               │
│ └──│ 0x77D507EF: sub esp, 50h                            │               │
│    │ 0x77D507F2: ...                                     │               │
│    │ (rest of original MessageBoxA)                      │               │
│    │ ...                                                 │               │
│    │ ret 16  ────────────────────────────────────────────┼───┐           │
│    └─────────────────────────────────────────────────────┘   │           │
│                                                              │           │
│    BACK TO CALLER                                            │           │
│    ┌─────────────────────┐                                   │           │
│    │ (after call returns)│◀──────────────────────────────────┘           │
│    │ ; EAX = return value│                                               │
│    └─────────────────────┘                                               │
│                                                                           │
└──────────────────────────────────────────────────────────────────────────┘
```

---

## 💻 Part 7: Practical - First Complete Hook

### Exercise 1: Understanding the Hook in C First

Before doing assembly, let's understand in C:

```c
// first_hook.c
// This is a SIMPLIFIED concept demo
// Compile: cl first_hook.c user32.lib kernel32.lib

#include <windows.h>
#include <stdio.h>

// Original function pointer
typedef int (WINAPI *fnMessageBoxA)(HWND, LPCSTR, LPCSTR, UINT);
fnMessageBoxA pOriginalMessageBox = NULL;

// Counter
int g_HookCallCount = 0;

// Our hook function
int WINAPI HookedMessageBoxA(HWND hWnd, LPCSTR lpText, LPCSTR lpCaption, UINT uType) {
    // Log the call
    printf("[HOOK] MessageBoxA called!\n");
    printf("[HOOK] Text: %s\n", lpText);
    printf("[HOOK] Caption: %s\n", lpCaption);
    g_HookCallCount++;
    
    // Modify the message (example)
    char newText[256];
    sprintf(newText, "[HOOKED] %s", lpText);
    
    // Call original (in real hook, this goes through trampoline)
    return pOriginalMessageBox(hWnd, newText, lpCaption, uType);
}

// Hook installer
BOOL InstallHook() {
    DWORD oldProtect;
    
    // Get original function address
    HMODULE hUser32 = GetModuleHandleA("user32.dll");
    pOriginalMessageBox = (fnMessageBoxA)GetProcAddress(hUser32, "MessageBoxA");
    
    printf("Original MessageBoxA at: 0x%p\n", pOriginalMessageBox);
    printf("Our hook function at: 0x%p\n", HookedMessageBoxA);
    
    // In a REAL hook, we would:
    // 1. Save original bytes
    // 2. VirtualProtect
    // 3. Write JMP
    // 4. Create trampoline
    
    // For this demo, we'll just show the concept
    printf("\n--- In real hook, we would modify bytes at 0x%p ---\n", pOriginalMessageBox);
    printf("Original bytes: ");
    unsigned char* bytes = (unsigned char*)pOriginalMessageBox;
    for(int i = 0; i < 5; i++) printf("%02X ", bytes[i]);
    printf("\n");
    
    return TRUE;
}

int main() {
    printf("=== First Hook Concept Demo ===\n\n");
    
    // Install hook (conceptual)
    InstallHook();
    
    printf("\n--- Calling our hooked function directly ---\n");
    HookedMessageBoxA(NULL, "Hello World!", "Test", MB_OK);
    
    printf("\n--- Normal MessageBoxA call (not actually hooked in this demo) ---\n");
    MessageBoxA(NULL, "This is NOT hooked in this demo", "Normal", MB_OK);
    
    printf("\nTotal hook calls: %d\n", g_HookCallCount);
    
    return 0;
}
```

### Exercise 2: Minimal Assembly Hook

```asm
; minimal_hook.asm
; A minimal but complete hook example

.686
.model flat, stdcall
option casemap:none

include \masm32\include\windows.inc
include \masm32\include\kernel32.inc
include \masm32\include\user32.inc
includelib \masm32\lib\kernel32.lib
includelib \masm32\lib\user32.lib

.data
    ; Strings
    szUser32        db "user32.dll", 0
    szMsgBoxA       db "MessageBoxA", 0
    szHooked        db "[HOOKED!] ", 0
    szTitle         db "Hook Demo", 0
    szTest          db "Original message", 0
    
    ; Addresses
    hUser32         dd 0
    pOriginalMsgBox dd 0
    pTrampoline     dd 0
    
    ; Saved bytes
    bOriginalBytes  db 8 dup(0)
    
    ; Protection
    dwOldProtect    dd 0
    
    ; Trampoline buffer (needs to be executable)
    bTrampoline     db 32 dup(0)
    
    ; Hook call counter
    dwHookCount     dd 0

.code

;----------------------------------------------------------------------
; Our hook handler for MessageBoxA
;----------------------------------------------------------------------
MyMessageBoxHook PROC
    ; Save all registers
    pushad
    pushfd
    
    ; Increment counter
    inc dwHookCount
    
    ; Log to debug output
    push OFFSET szHooked
    call OutputDebugStringA
    
    ; Restore registers
    popfd
    popad
    
    ; Jump to trampoline (calls original function)
    jmp pTrampoline

MyMessageBoxHook ENDP

;----------------------------------------------------------------------
; InstallHook - Installs the hook
;----------------------------------------------------------------------
InstallHook PROC
    pushad
    
    ; Get MessageBoxA address
    push OFFSET szUser32
    call GetModuleHandleA
    mov hUser32, eax
    
    push OFFSET szMsgBoxA
    push hUser32
    call GetProcAddress
    test eax, eax
    jz @failed
    mov pOriginalMsgBox, eax
    
    ; Save original bytes (5 bytes for JMP + 3 extra for safety)
    mov esi, pOriginalMsgBox
    lea edi, bOriginalBytes
    mov ecx, 8
    rep movsb
    
    ; Make trampoline buffer executable
    lea eax, bTrampoline
    push OFFSET dwOldProtect
    push PAGE_EXECUTE_READWRITE
    push 32
    push eax
    call VirtualProtect
    
    ; Build trampoline
    lea edi, bTrampoline
    mov pTrampoline, edi
    
    ; Copy stolen bytes (first 5) to trampoline
    lea esi, bOriginalBytes
    mov ecx, 5
    rep movsb
    
    ; Add JMP back to original + 5
    mov BYTE PTR [edi], 0E9h
    mov eax, pOriginalMsgBox
    add eax, 5                  ; Jump to original + 5
    lea ebx, bTrampoline
    add ebx, 5                  ; Address of this JMP
    add ebx, 5                  ; Size of JMP instruction
    sub eax, ebx                ; Relative offset
    mov DWORD PTR [edi+1], eax
    
    ; Change protection on original function
    push OFFSET dwOldProtect
    push PAGE_EXECUTE_READWRITE
    push 5
    push pOriginalMsgBox
    call VirtualProtect
    test eax, eax
    jz @failed
    
    ; Write JMP to our hook
    mov edi, pOriginalMsgBox
    mov BYTE PTR [edi], 0E9h
    
    mov eax, OFFSET MyMessageBoxHook
    sub eax, edi
    sub eax, 5
    mov DWORD PTR [edi+1], eax
    
    ; Flush instruction cache
    push 5
    push pOriginalMsgBox
    push -1
    call FlushInstructionCache
    
    ; Restore protection
    push OFFSET dwOldProtect
    push dwOldProtect
    push 5
    push pOriginalMsgBox
    call VirtualProtect
    
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
    ; Install the hook
    call InstallHook
    test eax, eax
    jz @exit
    
    ; Call MessageBoxA - it will be hooked!
    push MB_OK
    push OFFSET szTitle
    push OFFSET szTest
    push NULL
    call MessageBoxA
    
    ; Call again
    push MB_OK
    push OFFSET szTitle
    push OFFSET szTest
    push NULL
    call MessageBoxA
    
@exit:
    push 0
    call ExitProcess
main ENDP

END main
```

---

## 📝 Part 8: Tasks

### Task 1: Diagram Drawing (20 minutes)
Draw the memory layout showing:
1. Original MessageBoxA location
2. Your hook handler location
3. Trampoline location
4. The JMP instructions connecting them

### Task 2: Calculate JMP Offsets (25 minutes)
Given these addresses, calculate the relative JMP offset:

| Source (JMP location) | Destination | Calculate Offset |
|----------------------|-------------|------------------|
| 0x77D507EA | 0x00401000 | ? |
| 0x00401100 | 0x00401500 | ? |
| 0x00401500 | 0x00401100 | ? |

Show your work!

### Task 3: Stolen Bytes Analysis (20 minutes)
For each function prologue, determine:
1. How many bytes must be stolen (minimum 5)
2. What complete instructions are stolen

```
Example A:
8B FF           mov edi, edi
55              push ebp
8B EC           mov ebp, esp
83 EC 20        sub esp, 20h

Example B:
55              push ebp
8B EC           mov ebp, esp
6A FF           push -1
68 XX XX XX XX  push offset SEH_handler

Example C:
B8 XX XX XX XX  mov eax, immediate
C3              ret
```

### Task 4: Hook Design (30 minutes)
Design (on paper or in pseudocode) a hook for `CreateFileA` that:
1. Logs the filename being opened
2. Logs whether it's for read or write
3. Calls the original function
4. Returns the original result

---

## ✅ Session Checklist

Before moving to Session 6, make sure you can:

- [ ] Explain the 5 steps of hook installation
- [ ] Define "stolen bytes" and why they matter
- [ ] Calculate relative JMP offsets
- [ ] Explain what a trampoline does
- [ ] Write basic hook handler structure
- [ ] Understand the complete hook flow

---

## 🔜 Next Session

In **Session 06: Memory Protection & VirtualProtect**, we'll learn:
- Deep dive into Windows memory protection
- VirtualProtect and VirtualQuery
- Common mistakes and how to avoid them
- Protection patterns for hooks

[Continue to Session 06 →](session_06.md)

---

## 📖 Additional Resources

- [Microsoft Detours Library](https://github.com/microsoft/Detours)
- [x86 Instruction Length Decoder](https://wiki.osdev.org/X86-64_Instruction_Encoding)
- [Hot Patching in Windows](https://devblogs.microsoft.com/oldnewthing/20110921-00/?p=9583)
