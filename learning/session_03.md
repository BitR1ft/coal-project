# Session 03: x86 Assembly Fundamentals

## 🎯 Learning Objectives

By the end of this session, you will:
- Understand CPU registers and their purposes
- Know basic x86 instructions
- Understand the stack and stack operations
- Know the stdcall calling convention
- Be able to read simple assembly code

---

## 📚 Part 1: Theory - CPU Registers

### What are Registers?

**Registers** are small, ultra-fast storage locations inside the CPU. They hold data that the CPU is actively working with.

Think of registers as the CPU's "hands" - it can only work with data that's in its hands (registers). Data in RAM must first be moved to registers.

### x86 General Purpose Registers

| Register | Name | Common Purpose |
|----------|------|----------------|
| **EAX** | Accumulator | Return values, arithmetic |
| **EBX** | Base | General storage, base pointer for data |
| **ECX** | Counter | Loop counters, shift counts |
| **EDX** | Data | I/O operations, extended precision |
| **ESI** | Source Index | Source pointer for string operations |
| **EDI** | Destination Index | Destination pointer for string operations |
| **EBP** | Base Pointer | Stack frame pointer |
| **ESP** | Stack Pointer | Points to top of stack |

```
┌─────────────────────────────────────────────────────────────────┐
│                    x86 REGISTER LAYOUT                           │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  32-bit (E = Extended)    16-bit      8-bit (High/Low)          │
│  ─────────────────────    ──────      ───────────────           │
│                                                                  │
│  EAX ┌────────────────────────────────────────┐                 │
│      │xxxxxxxx│xxxxxxxx│   AH    │    AL     │                  │
│      └────────────────────────────────────────┘                 │
│                          └─────────AX──────────┘                │
│                                                                  │
│  EBX ┌────────────────────────────────────────┐                 │
│      │xxxxxxxx│xxxxxxxx│   BH    │    BL     │                  │
│      └────────────────────────────────────────┘                 │
│                          └─────────BX──────────┘                │
│                                                                  │
│  ECX ┌────────────────────────────────────────┐                 │
│      │xxxxxxxx│xxxxxxxx│   CH    │    CL     │                  │
│      └────────────────────────────────────────┘                 │
│                          └─────────CX──────────┘                │
│                                                                  │
│  EDX ┌────────────────────────────────────────┐                 │
│      │xxxxxxxx│xxxxxxxx│   DH    │    DL     │                  │
│      └────────────────────────────────────────┘                 │
│                          └─────────DX──────────┘                │
│                                                                  │
│  ESI ┌────────────────────────────────────────┐                 │
│      │           32 bits (no sub-parts)       │                 │
│      └────────────────────────────────────────┘                 │
│                                                                  │
│  EDI ┌────────────────────────────────────────┐                 │
│      │           32 bits (no sub-parts)       │                 │
│      └────────────────────────────────────────┘                 │
│                                                                  │
│  EBP ┌────────────────────────────────────────┐                 │
│      │           Stack Base Pointer           │                 │
│      └────────────────────────────────────────┘                 │
│                                                                  │
│  ESP ┌────────────────────────────────────────┐                 │
│      │           Stack Top Pointer            │                 │
│      └────────────────────────────────────────┘                 │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### Special Registers

| Register | Purpose |
|----------|---------|
| **EIP** | Instruction Pointer - address of NEXT instruction |
| **EFLAGS** | Status flags (zero, carry, overflow, etc.) |

**You cannot directly modify EIP!** It changes automatically as code executes, or via JMP/CALL/RET.

---

## 📚 Part 2: Basic x86 Instructions

### Data Movement

```asm
; MOV - Copy data from source to destination
mov eax, 5          ; EAX = 5
mov ebx, eax        ; EBX = EAX (copy)
mov ecx, [address]  ; ECX = value at memory address
mov [address], edx  ; Memory at address = EDX

; LEA - Load Effective Address (gets address, not value)
lea eax, [ebx+4]    ; EAX = address of (EBX+4), NOT the value
```

### Arithmetic

```asm
; ADD - Addition
add eax, 5          ; EAX = EAX + 5
add eax, ebx        ; EAX = EAX + EBX

; SUB - Subtraction  
sub eax, 5          ; EAX = EAX - 5

; INC/DEC - Increment/Decrement
inc eax             ; EAX = EAX + 1
dec ebx             ; EBX = EBX - 1

; MUL/IMUL - Multiplication
imul eax, ebx       ; EAX = EAX * EBX
imul eax, 5         ; EAX = EAX * 5

; DIV/IDIV - Division (result in EAX, remainder in EDX)
```

### Comparison and Jumps

```asm
; CMP - Compare (sets flags, no result stored)
cmp eax, 5          ; Compare EAX with 5

; TEST - Bitwise AND comparison (sets flags)
test eax, eax       ; Check if EAX is zero

; Conditional Jumps
je  label           ; Jump if Equal (ZF=1)
jne label           ; Jump if Not Equal (ZF=0)
jg  label           ; Jump if Greater (signed)
jl  label           ; Jump if Less (signed)
jge label           ; Jump if Greater or Equal
jle label           ; Jump if Less or Equal
ja  label           ; Jump if Above (unsigned)
jb  label           ; Jump if Below (unsigned)
jz  label           ; Jump if Zero (same as JE)
jnz label           ; Jump if Not Zero (same as JNE)

; Unconditional Jump
jmp label           ; Always jump to label
```

### Stack Operations

```asm
; PUSH - Put value on stack (ESP decreases)
push eax            ; Push EAX onto stack
push 5              ; Push immediate value 5
push [address]      ; Push value at address

; POP - Take value from stack (ESP increases)
pop eax             ; Pop top of stack into EAX
pop ebx             ; Pop into EBX

; PUSHAD/POPAD - Push/Pop all general registers
pushad              ; Push EAX, ECX, EDX, EBX, ESP, EBP, ESI, EDI
popad               ; Pop all back

; PUSHFD/POPFD - Push/Pop flags
pushfd              ; Push EFLAGS
popfd               ; Pop EFLAGS
```

### Function Calls

```asm
; CALL - Call a function
call MyFunction     ; Push return address, jump to function
call eax            ; Call address in EAX
call [address]      ; Call address at memory location

; RET - Return from function
ret                 ; Pop return address, jump there
ret 8               ; Return and clean 8 bytes from stack
```

---

## 📚 Part 3: The Stack

### What is the Stack?

The **stack** is a region of memory used for:
- Storing local variables
- Passing function arguments
- Saving return addresses
- Storing saved registers

**The stack grows DOWNWARD** - when you PUSH, ESP decreases!

```
┌─────────────────────────────────────────────────────────────────┐
│                         THE STACK                                │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  HIGH ADDRESS                                                    │
│       ▲                                                          │
│       │   ┌─────────────────────────────────────┐                │
│       │   │ Previous function's data            │                │
│       │   ├─────────────────────────────────────┤                │
│       │   │ Return Address                      │ ← Saved by CALL│
│       │   ├─────────────────────────────────────┤                │
│       │   │ Saved EBP                           │ ← push ebp     │
│  EBP ─┼──▶├─────────────────────────────────────┤                │
│       │   │ Local Variable 1                    │                │
│       │   ├─────────────────────────────────────┤                │
│       │   │ Local Variable 2                    │                │
│       │   ├─────────────────────────────────────┤                │
│  ESP ─┼──▶│ TOP OF STACK                        │                │
│       │   └─────────────────────────────────────┘                │
│       │                                                          │
│       │   FREE SPACE                                             │
│       │   (Stack grows this way)                                 │
│       ▼                                                          │
│  LOW ADDRESS                                                     │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### PUSH Operation

```asm
; Before: ESP = 0x0019FF00
push eax
; After:  ESP = 0x0019FEFC (decreased by 4)
;         [ESP] now contains EAX value
```

```
Before PUSH:            After PUSH eax (eax = 0x12345678):
                        
ESP → 0x0019FF00        0x0019FF00 │ old data    │
                        ESP → 0x0019FEFC │ 0x12345678 │ ← EAX value
```

### POP Operation

```asm
; Before: ESP = 0x0019FEFC, [ESP] = 0x12345678
pop ebx
; After:  ESP = 0x0019FF00 (increased by 4)
;         EBX = 0x12345678
```

---

## 📚 Part 4: Calling Conventions

### What is a Calling Convention?

A **calling convention** defines:
1. How parameters are passed to functions
2. Who cleans up the stack (caller or callee)
3. Which registers must be preserved

### stdcall (Windows API Convention)

Windows APIs use **stdcall**:
- Parameters pushed **right to left**
- **Callee** cleans the stack
- Return value in **EAX**

```c
// C code
int result = MessageBoxA(NULL, "Hello", "Title", MB_OK);

// Parameters: hWnd=NULL, lpText="Hello", lpCaption="Title", uType=MB_OK
```

```asm
; Assembly equivalent
push MB_OK            ; 4th parameter (pushed first - right to left)
push offset szTitle   ; 3rd parameter  
push offset szText    ; 2nd parameter
push NULL             ; 1st parameter (pushed last)
call MessageBoxA      ; Call the function
; Stack is cleaned by MessageBoxA (stdcall)
; Return value is in EAX
mov result, eax       ; Save result
```

### Stack During Function Call

```
Before CALL:                After CALL:

High Address               High Address
     │                          │
     │                          │
     ├─────────────┤           ├─────────────┤
     │ MB_OK       │           │ MB_OK       │
     ├─────────────┤           ├─────────────┤
     │ "Title"     │           │ "Title"     │
     ├─────────────┤           ├─────────────┤
     │ "Hello"     │           │ "Hello"     │
     ├─────────────┤           ├─────────────┤
ESP→ │ NULL        │           │ NULL        │
     └─────────────┘           ├─────────────┤
                         ESP→  │ Return Addr │ ← CALL pushed this
                               └─────────────┘
```

### Function Prologue and Epilogue

**Prologue** (beginning of function):
```asm
push ebp            ; Save old base pointer
mov ebp, esp        ; Set up new stack frame
sub esp, N          ; Allocate N bytes for local variables
```

**Epilogue** (end of function):
```asm
mov esp, ebp        ; Restore stack pointer
pop ebp             ; Restore old base pointer
ret N               ; Return and clean N bytes of parameters
```

### Complete Function Example

```asm
; int Add(int a, int b)
; Parameters: [ebp+8] = a, [ebp+12] = b
Add PROC
    ; Prologue
    push ebp
    mov ebp, esp
    
    ; Function body
    mov eax, [ebp+8]    ; Get 'a' parameter
    add eax, [ebp+12]   ; Add 'b' parameter
    ; Result is in EAX (return value)
    
    ; Epilogue
    pop ebp
    ret 8               ; Clean 2 parameters (4 bytes each)
Add ENDP
```

---

## 📚 Part 5: Register Preservation

### Why Preserve Registers?

When you hook a function, you're interrupting normal execution. The calling code expects certain register values to remain unchanged.

**Volatile Registers** (can be changed):
- EAX (return value)
- ECX
- EDX

**Non-volatile Registers** (must be preserved):
- EBX
- ESI
- EDI
- EBP
- ESP

### Using PUSHAD/POPAD

```asm
; Hook handler that CORRECTLY preserves state
HookHandler PROC
    pushad              ; Save ALL registers
    pushfd              ; Save flags
    
    ; Your hook code here
    ; You can freely use any registers
    mov eax, 5
    mov ebx, 10
    ; ... etc ...
    
    popfd               ; Restore flags
    popad               ; Restore ALL registers
    
    ; Now all registers are back to original values!
    ; Continue with original function...
HookHandler ENDP
```

### PUSHAD Order

PUSHAD pushes registers in this order:
```
ESP (original) → ┌─────────────┐
                 │    EAX      │  ← First pushed (top after pushad)
                 ├─────────────┤
                 │    ECX      │
                 ├─────────────┤
                 │    EDX      │
                 ├─────────────┤
                 │    EBX      │
                 ├─────────────┤
                 │ ESP(orig)   │
                 ├─────────────┤
                 │    EBP      │
                 ├─────────────┤
                 │    ESI      │
                 ├─────────────┤
       ESP new → │    EDI      │  ← Last pushed (ESP after pushad)
                 └─────────────┘
```

---

## 💻 Part 6: Practical - Assembly Exercises

### Exercise 1: Simple Assembly Program (MASM)

Create `first_asm.asm`:

```asm
; first_asm.asm
; Compile with: ml /c /coff first_asm.asm
; Link with: link /subsystem:console first_asm.obj kernel32.lib

.686
.model flat, stdcall
option casemap:none

; Windows API declarations
ExitProcess PROTO :DWORD
GetStdHandle PROTO :DWORD
WriteConsoleA PROTO :DWORD, :DWORD, :DWORD, :DWORD, :DWORD

STD_OUTPUT_HANDLE EQU -11

.data
    szMessage db "Hello from Assembly!", 13, 10, 0
    dwWritten dd 0

.code
main PROC
    ; Get console handle
    push STD_OUTPUT_HANDLE
    call GetStdHandle
    ; EAX now has console handle
    
    ; Write message
    push 0                      ; lpReserved
    push OFFSET dwWritten       ; lpNumberOfCharsWritten
    push 22                     ; nNumberOfCharsToWrite (length of message)
    push OFFSET szMessage       ; lpBuffer
    push eax                    ; hConsoleOutput
    call WriteConsoleA
    
    ; Exit
    push 0
    call ExitProcess
main ENDP

END main
```

### Exercise 2: Function with Parameters

```asm
; add_function.asm

.686
.model flat, stdcall
option casemap:none

.code
; int AddNumbers(int a, int b)
AddNumbers PROC a:DWORD, b:DWORD
    ; Note: MASM automatically handles prologue/epilogue
    mov eax, a
    add eax, b
    ret
AddNumbers ENDP

; int MultiplyNumbers(int a, int b)
MultiplyNumbers PROC a:DWORD, b:DWORD
    mov eax, a
    imul eax, b
    ret
MultiplyNumbers ENDP

END
```

### Exercise 3: Using the Stack Manually

```asm
; stack_demo.asm

.686
.model flat, stdcall
option casemap:none

.code
; Manual prologue/epilogue demo
ManualFunction PROC
    ; Manual prologue
    push ebp                ; Save old base pointer
    mov ebp, esp            ; Set up stack frame
    sub esp, 8              ; Allocate 8 bytes (2 local variables)
    
    ; Local variables:
    ; [ebp-4] = localVar1
    ; [ebp-8] = localVar2
    
    ; Initialize local variables
    mov DWORD PTR [ebp-4], 100    ; localVar1 = 100
    mov DWORD PTR [ebp-8], 200    ; localVar2 = 200
    
    ; Add them
    mov eax, [ebp-4]
    add eax, [ebp-8]
    ; EAX = 300
    
    ; Manual epilogue
    mov esp, ebp            ; Restore stack pointer
    pop ebp                 ; Restore base pointer
    ret
ManualFunction ENDP

END
```

### Exercise 4: Understanding a Real Hook Handler

```asm
; hook_handler_example.asm
; This shows what a real hook handler looks like

.686
.model flat, stdcall
option casemap:none

.data
    g_OriginalFunction dd 0     ; Pointer to original function
    g_HookCallCount dd 0        ; Counter

.code
; This is what runs when hooked function is called
ExampleHookHandler PROC
    ; 1. Save ALL registers (critical!)
    pushad
    pushfd
    
    ; 2. Our hook logic
    inc g_HookCallCount         ; Count how many times called
    
    ; 3. Restore ALL registers
    popfd
    popad
    
    ; 4. Jump to trampoline (execute original function)
    ; This would be: jmp g_pTrampoline
    
    ret
ExampleHookHandler ENDP

END
```

---

## 💻 Part 7: Reading Assembly - Practice

### Decode This Assembly

```asm
push ebp
mov ebp, esp
sub esp, 8
mov dword ptr [ebp-4], 0
mov dword ptr [ebp-8], 1

@loop:
    mov eax, [ebp-4]
    cmp eax, 10
    jge @done
    
    mov eax, [ebp-8]
    add eax, eax        ; What does this do?
    mov [ebp-8], eax
    
    inc dword ptr [ebp-4]
    jmp @loop

@done:
    mov eax, [ebp-8]
    mov esp, ebp
    pop ebp
    ret
```

**Question**: What does this function return?

<details>
<summary>Click for Answer</summary>

This function calculates 2^10 = 1024

- [ebp-4] is a counter (0 to 9)
- [ebp-8] starts at 1, doubles each iteration
- After 10 iterations: 1 → 2 → 4 → 8 → 16 → 32 → 64 → 128 → 256 → 512 → 1024
</details>

---

## 📝 Part 8: Tasks

### Task 1: Register Practice (20 minutes)
1. Draw all 8 general-purpose registers
2. Show the relationship between EAX, AX, AH, and AL
3. Give an example use for each register

### Task 2: Stack Drawing (25 minutes)
Draw the stack state after each instruction:
```asm
push 10
push 20
push 30
pop eax
push 40
```

### Task 3: Calling Convention (30 minutes)
1. Write the assembly for calling this C function:
   ```c
   int SomeFunc(int a, int b, int c);
   // Call with a=5, b=10, c=15
   ```
2. How many bytes are on the stack before CALL?
3. If this is stdcall, who cleans the stack?

### Task 4: Translate C to Assembly (30 minutes)
Translate this C function to assembly:
```c
int Maximum(int a, int b) {
    if (a > b)
        return a;
    else
        return b;
}
```

---

## ✅ Session Checklist

Before moving to Session 4, make sure you can:

- [ ] Name all 8 general-purpose x86 registers
- [ ] Explain the difference between MOV and LEA
- [ ] Explain how the stack grows (direction)
- [ ] Write a basic function with prologue/epilogue
- [ ] Explain stdcall calling convention
- [ ] Use PUSHAD/POPAD for register preservation
- [ ] Read and understand basic assembly code

---

## 🔜 Next Session

In **Session 04: Windows API Basics**, we'll learn:
- How to call Windows APIs from assembly
- LoadLibrary and GetProcAddress
- Common API patterns
- String handling in assembly

[Continue to Session 04 →](session_04.md)

---

## 📖 Additional Resources

- [Intel x86 Instruction Reference](https://www.felixcloutier.com/x86/)
- [x86 Assembly Guide - University of Virginia](https://www.cs.virginia.edu/~evans/cs216/guides/x86.html)
- [MASM Documentation](https://docs.microsoft.com/en-us/cpp/assembler/masm/masm-for-x64-ml64-exe)
