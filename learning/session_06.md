# Session 06: Memory Protection & VirtualProtect

## 🎯 Learning Objectives

By the end of this session, you will:
- Understand Windows memory protection in depth
- Master VirtualProtect and VirtualQuery
- Know common memory protection mistakes
- Implement safe memory modification patterns

---

## 📚 Part 1: Theory - Windows Memory Protection

### Why Memory Protection Exists

Memory protection prevents:
- **Accidental bugs**: Writing to wrong memory locations
- **Security exploits**: Code injection attacks
- **Stability issues**: Corrupting system code

### Protection Flags Deep Dive

| Flag | Value | Read | Write | Execute | Use Case |
|------|-------|------|-------|---------|----------|
| PAGE_NOACCESS | 0x01 | ❌ | ❌ | ❌ | Guard pages |
| PAGE_READONLY | 0x02 | ✅ | ❌ | ❌ | Constants |
| PAGE_READWRITE | 0x04 | ✅ | ✅ | ❌ | Variables |
| PAGE_WRITECOPY | 0x08 | ✅ | ✅* | ❌ | Copy-on-write |
| PAGE_EXECUTE | 0x10 | ❌ | ❌ | ✅ | Code (rare) |
| PAGE_EXECUTE_READ | 0x20 | ✅ | ❌ | ✅ | Normal code |
| PAGE_EXECUTE_READWRITE | 0x40 | ✅ | ✅ | ✅ | Self-modifying |
| PAGE_EXECUTE_WRITECOPY | 0x80 | ✅ | ✅* | ✅ | Code patching |

*WriteCopy: Creates private copy when written

### Memory Protection in Practice

```
┌─────────────────────────────────────────────────────────────────┐
│                TYPICAL PROCESS MEMORY MAP                        │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  Address Range    │ Protection         │ Contents               │
│  ─────────────────┼────────────────────┼───────────────────────  │
│  0x77XXXXXX       │ EXECUTE_READ       │ system DLLs (code)     │
│  0x77XXXXXX       │ READONLY           │ system DLLs (data)     │
│  0x75XXXXXX       │ EXECUTE_READ       │ user32.dll code        │
│  0x10XXXXXX       │ EXECUTE_READ       │ 3rd party DLLs         │
│  0x004XXXXX       │ EXECUTE_READ       │ your .exe code         │
│  0x004XXXXX       │ READWRITE          │ your .exe data         │
│  0x004XXXXX       │ READONLY           │ your .exe constants    │
│  0x00XXXXXX       │ READWRITE          │ heap                   │
│  0x001XXXXX       │ READWRITE + GUARD  │ stack                  │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

---

## 📚 Part 2: VirtualProtect Deep Dive

### Function Signature

```c
BOOL VirtualProtect(
    LPVOID lpAddress,       // Starting address
    SIZE_T dwSize,          // Size of region
    DWORD  flNewProtect,    // New protection
    PDWORD lpflOldProtect   // Previous protection (OUTPUT)
);
```

### Key Points

1. **lpAddress**: Must be on a page boundary OR within the page you want to modify
2. **dwSize**: Can span multiple pages
3. **flNewProtect**: New protection flags
4. **lpflOldProtect**: **MUST NOT BE NULL** - Required output parameter

### Common Mistake #1: Null Output Pointer

```asm
; WRONG - Will crash!
push NULL                   ; lpflOldProtect = NULL
push PAGE_EXECUTE_READWRITE
push 5
push pAddress
call VirtualProtect
; CRASH! Windows requires the old protection output

; CORRECT
push OFFSET dwOldProtect    ; Valid pointer
push PAGE_EXECUTE_READWRITE
push 5
push pAddress
call VirtualProtect
```

### Common Mistake #2: Not Checking Return Value

```asm
; WRONG - Ignoring failure
call VirtualProtect
mov edi, pAddress
mov BYTE PTR [edi], 0E9h   ; Might crash if VirtualProtect failed!

; CORRECT - Check return value
call VirtualProtect
test eax, eax              ; Did it succeed?
jz @HandleError            ; If not, handle error
mov edi, pAddress          ; Safe to proceed
mov BYTE PTR [edi], 0E9h
```

### Common Mistake #3: Not Restoring Protection

```asm
; WRONG - Leaving code writable (security risk!)
push OFFSET dwOldProtect
push PAGE_EXECUTE_READWRITE
push 5
push pAddress
call VirtualProtect
; ... modify code ...
; Forgot to restore!

; CORRECT - Always restore protection
push OFFSET dwOldProtect
push PAGE_EXECUTE_READWRITE
push 5
push pAddress
call VirtualProtect

; ... modify code ...

; Restore original protection
push OFFSET dwDummy         ; We need an output, but don't care about value
push dwOldProtect          ; Restore old protection
push 5
push pAddress
call VirtualProtect
```

---

## 📚 Part 3: VirtualQuery Explained

### Function Signature

```c
SIZE_T VirtualQuery(
    LPCVOID                   lpAddress,    // Address to query
    PMEMORY_BASIC_INFORMATION lpBuffer,     // Output structure
    SIZE_T                    dwLength      // Size of buffer
);
```

### MEMORY_BASIC_INFORMATION Structure

```c
typedef struct _MEMORY_BASIC_INFORMATION {
    PVOID  BaseAddress;        // Base of this region
    PVOID  AllocationBase;     // Base of allocation
    DWORD  AllocationProtect;  // Protection when allocated
    SIZE_T RegionSize;         // Size of this region
    DWORD  State;              // MEM_COMMIT, MEM_FREE, MEM_RESERVE
    DWORD  Protect;            // Current protection
    DWORD  Type;               // MEM_IMAGE, MEM_MAPPED, MEM_PRIVATE
} MEMORY_BASIC_INFORMATION;
```

### Memory States

| State | Value | Meaning |
|-------|-------|---------|
| MEM_COMMIT | 0x1000 | Memory is allocated and usable |
| MEM_FREE | 0x10000 | Memory is not allocated |
| MEM_RESERVE | 0x2000 | Memory is reserved but not usable |

### Memory Types

| Type | Value | Meaning |
|------|-------|---------|
| MEM_IMAGE | 0x1000000 | Memory mapped from an image file (DLL/EXE) |
| MEM_MAPPED | 0x40000 | Memory mapped from a file |
| MEM_PRIVATE | 0x20000 | Private memory |

---

## 📚 Part 4: Safe Memory Modification Pattern

### The Complete Safe Pattern

```asm
;----------------------------------------------------------------------
; SafeWriteMemory - Safely writes to potentially protected memory
;----------------------------------------------------------------------
; Parameters:
;   pDest   - Destination address
;   pSrc    - Source address
;   dwSize  - Number of bytes to write
; Returns:
;   EAX = 1 on success, 0 on failure
;----------------------------------------------------------------------
SafeWriteMemory PROC pDest:DWORD, pSrc:DWORD, dwSize:DWORD
    LOCAL dwOldProtect:DWORD
    LOCAL mbi:MEMORY_BASIC_INFORMATION
    
    pushad
    
    ; Step 1: Query current protection
    push SIZEOF MEMORY_BASIC_INFORMATION
    lea eax, mbi
    push eax
    push pDest
    call VirtualQuery
    test eax, eax
    jz @QueryFailed
    
    ; Step 2: Check if memory is committed
    mov eax, mbi.State
    cmp eax, MEM_COMMIT
    jne @NotCommitted
    
    ; Step 3: Check if we need to change protection
    mov eax, mbi.Protect
    and eax, PAGE_READWRITE or PAGE_EXECUTE_READWRITE or PAGE_WRITECOPY or PAGE_EXECUTE_WRITECOPY
    jnz @AlreadyWritable
    
    ; Step 4: Change protection
    lea eax, dwOldProtect
    push eax
    push PAGE_EXECUTE_READWRITE
    push dwSize
    push pDest
    call VirtualProtect
    test eax, eax
    jz @ProtectFailed
    
    ; Step 5: Copy the data
    mov edi, pDest
    mov esi, pSrc
    mov ecx, dwSize
    rep movsb
    
    ; Step 6: Restore original protection
    lea eax, dwOldProtect
    push eax
    push dwOldProtect
    push dwSize
    push pDest
    call VirtualProtect
    
    ; Step 7: Flush instruction cache (if this is code)
    push dwSize
    push pDest
    push -1
    call FlushInstructionCache
    
    popad
    mov eax, 1
    ret

@AlreadyWritable:
    ; Memory is already writable, just copy
    mov edi, pDest
    mov esi, pSrc
    mov ecx, dwSize
    rep movsb
    
    popad
    mov eax, 1
    ret

@QueryFailed:
@NotCommitted:
@ProtectFailed:
    popad
    xor eax, eax
    ret
SafeWriteMemory ENDP
```

---

## 📚 Part 5: Protection and DEP

### What is DEP?

**DEP** (Data Execution Prevention) prevents code execution from data regions:

```
WITH DEP ENABLED:
┌────────────────────────────┬─────────────────────────────┐
│ Memory Region              │ Can Execute?                 │
├────────────────────────────┼─────────────────────────────┤
│ Code section (.text)       │ ✅ Yes                       │
│ Data section (.data)       │ ❌ No - DEP blocks!         │
│ Heap                       │ ❌ No - DEP blocks!         │
│ Stack                      │ ❌ No - DEP blocks!         │
└────────────────────────────┴─────────────────────────────┘
```

### Implications for Hooks

Your **trampoline** must be in executable memory!

```asm
; WRONG - Trampoline in .data section (DEP will block execution!)
.data
    bTrampoline db 32 dup(0)

; BETTER - Allocate executable memory
.code
AllocateTrampoline PROC
    push PAGE_EXECUTE_READWRITE  ; Make it executable
    push MEM_COMMIT or MEM_RESERVE
    push 64                      ; Size
    push NULL                    ; Let system choose address
    call VirtualAlloc
    ; EAX = executable memory buffer
    ret
AllocateTrampoline ENDP
```

### Making Static Buffer Executable

If you must use a static buffer:

```asm
.data
    bTrampoline db 32 dup(0)
    dwTrampolineProtect dd 0

.code
MakeTrampolineExecutable PROC
    push OFFSET dwTrampolineProtect
    push PAGE_EXECUTE_READWRITE
    push 32
    push OFFSET bTrampoline
    call VirtualProtect
    ret
MakeTrampolineExecutable ENDP
```

---

## 💻 Part 6: Practical Exercises

### Exercise 1: Memory Info Viewer

```c
// memory_viewer.c
// View detailed memory information
// Compile: cl memory_viewer.c

#include <windows.h>
#include <stdio.h>

const char* GetProtectionString(DWORD protect) {
    static char buffer[64];
    buffer[0] = 0;
    
    if (protect & PAGE_NOACCESS) strcat(buffer, "NOACCESS ");
    if (protect & PAGE_READONLY) strcat(buffer, "READONLY ");
    if (protect & PAGE_READWRITE) strcat(buffer, "READWRITE ");
    if (protect & PAGE_WRITECOPY) strcat(buffer, "WRITECOPY ");
    if (protect & PAGE_EXECUTE) strcat(buffer, "EXECUTE ");
    if (protect & PAGE_EXECUTE_READ) strcat(buffer, "EXEC_READ ");
    if (protect & PAGE_EXECUTE_READWRITE) strcat(buffer, "EXEC_RW ");
    if (protect & PAGE_EXECUTE_WRITECOPY) strcat(buffer, "EXEC_WC ");
    if (protect & PAGE_GUARD) strcat(buffer, "GUARD ");
    if (protect & PAGE_NOCACHE) strcat(buffer, "NOCACHE ");
    
    return buffer[0] ? buffer : "UNKNOWN";
}

const char* GetStateString(DWORD state) {
    switch(state) {
        case MEM_COMMIT: return "COMMITTED";
        case MEM_FREE: return "FREE";
        case MEM_RESERVE: return "RESERVED";
        default: return "UNKNOWN";
    }
}

const char* GetTypeString(DWORD type) {
    switch(type) {
        case MEM_IMAGE: return "IMAGE";
        case MEM_MAPPED: return "MAPPED";
        case MEM_PRIVATE: return "PRIVATE";
        default: return "UNKNOWN";
    }
}

void ShowMemoryInfo(LPCVOID address, const char* name) {
    MEMORY_BASIC_INFORMATION mbi;
    
    printf("\n=== %s (0x%p) ===\n", name, address);
    
    if (VirtualQuery(address, &mbi, sizeof(mbi))) {
        printf("Base Address:       0x%p\n", mbi.BaseAddress);
        printf("Allocation Base:    0x%p\n", mbi.AllocationBase);
        printf("Region Size:        0x%zX (%zu KB)\n", 
               mbi.RegionSize, mbi.RegionSize / 1024);
        printf("State:              %s (0x%X)\n", 
               GetStateString(mbi.State), mbi.State);
        printf("Protection:         %s(0x%X)\n", 
               GetProtectionString(mbi.Protect), mbi.Protect);
        printf("Type:               %s (0x%X)\n", 
               GetTypeString(mbi.Type), mbi.Type);
    } else {
        printf("VirtualQuery failed! Error: %d\n", GetLastError());
    }
}

int main() {
    // Get various addresses
    HMODULE hKernel32 = GetModuleHandleA("kernel32.dll");
    HMODULE hUser32 = GetModuleHandleA("user32.dll");
    
    FARPROC pMessageBoxA = GetProcAddress(hUser32, "MessageBoxA");
    FARPROC pVirtualProtect = GetProcAddress(hKernel32, "VirtualProtect");
    
    // Stack variable
    int stackVar = 42;
    
    // Heap variable
    int* heapVar = (int*)malloc(sizeof(int));
    *heapVar = 100;
    
    // Show info
    ShowMemoryInfo(pMessageBoxA, "MessageBoxA (code)");
    ShowMemoryInfo(pVirtualProtect, "VirtualProtect (code)");
    ShowMemoryInfo(&stackVar, "Stack variable");
    ShowMemoryInfo(heapVar, "Heap variable");
    ShowMemoryInfo(main, "main() function");
    
    // Try changing protection
    printf("\n=== Attempting to change MessageBoxA protection ===\n");
    DWORD oldProtect;
    if (VirtualProtect((LPVOID)pMessageBoxA, 5, PAGE_EXECUTE_READWRITE, &oldProtect)) {
        printf("SUCCESS! Old protection: 0x%X (%s)\n", 
               oldProtect, GetProtectionString(oldProtect));
        
        // Restore
        VirtualProtect((LPVOID)pMessageBoxA, 5, oldProtect, &oldProtect);
        printf("Protection restored.\n");
    } else {
        printf("FAILED! Error: %d\n", GetLastError());
    }
    
    free(heapVar);
    printf("\nPress Enter to exit...");
    getchar();
    return 0;
}
```

### Exercise 2: Safe Memory Write in Assembly

```asm
; safe_write.asm
; Demonstrates safe memory writing

.686
.model flat, stdcall
option casemap:none

include \masm32\include\windows.inc
include \masm32\include\kernel32.inc
include \masm32\include\user32.inc
includelib \masm32\lib\kernel32.lib
includelib \masm32\lib\user32.lib

MEMORY_BASIC_INFORMATION STRUCT
    BaseAddress       DWORD ?
    AllocationBase    DWORD ?
    AllocationProtect DWORD ?
    RegionSize        DWORD ?
    State             DWORD ?
    Protect           DWORD ?
    dType             DWORD ?
MEMORY_BASIC_INFORMATION ENDS

.data
    szUser32    db "user32.dll", 0
    szMsgBoxA   db "MessageBoxA", 0
    szSuccess   db "Successfully modified memory!", 0
    szFailed    db "Memory modification failed!", 0
    szTitle     db "Safe Write Demo", 0
    
    dwOldProtect dd 0
    mbi MEMORY_BASIC_INFORMATION <>

.code

;----------------------------------------------------------------------
; SafeModifyCode - Safely modifies code memory
;----------------------------------------------------------------------
SafeModifyCode PROC pAddress:DWORD, bNewByte:BYTE
    pushad
    
    ; Query memory info first
    push SIZEOF MEMORY_BASIC_INFORMATION
    lea eax, mbi
    push eax
    push pAddress
    call VirtualQuery
    test eax, eax
    jz @failed
    
    ; Check if committed
    cmp mbi.State, MEM_COMMIT
    jne @failed
    
    ; Change protection
    push OFFSET dwOldProtect
    push PAGE_EXECUTE_READWRITE
    push 1
    push pAddress
    call VirtualProtect
    test eax, eax
    jz @failed
    
    ; Write the byte
    mov edi, pAddress
    mov al, bNewByte
    mov [edi], al
    
    ; Restore protection
    push OFFSET dwOldProtect
    push dwOldProtect
    push 1
    push pAddress
    call VirtualProtect
    
    ; Flush instruction cache
    push 1
    push pAddress
    push -1
    call FlushInstructionCache
    
    popad
    mov eax, 1
    ret

@failed:
    popad
    xor eax, eax
    ret
SafeModifyCode ENDP

;----------------------------------------------------------------------
; main
;----------------------------------------------------------------------
main PROC
    ; Get MessageBoxA address
    push OFFSET szUser32
    call GetModuleHandleA
    push OFFSET szMsgBoxA
    push eax
    call GetProcAddress
    ; EAX = MessageBoxA address
    
    ; Read original byte
    mov edi, eax
    movzx ebx, BYTE PTR [edi]   ; Save original first byte
    
    ; Try to modify (then restore immediately)
    push 90h                     ; NOP instruction
    push edi
    call SafeModifyCode
    test eax, eax
    jz @failure
    
    ; Restore original byte
    push ebx
    push edi
    call SafeModifyCode
    
    ; Show success
    push MB_ICONINFORMATION
    push OFFSET szTitle
    push OFFSET szSuccess
    push NULL
    call MessageBoxA
    jmp @exit

@failure:
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

### Exercise 3: Executable Memory Allocation

```asm
; exec_alloc.asm
; Demonstrates allocating executable memory for trampolines

.686
.model flat, stdcall
option casemap:none

include \masm32\include\windows.inc
include \masm32\include\kernel32.inc
include \masm32\include\user32.inc
includelib \masm32\lib\kernel32.lib
includelib \masm32\lib\user32.lib

.data
    szTitle     db "Executable Memory Demo", 0
    szAllocated db "Allocated executable memory at: 0x", 0
    szHex       db "00000000", 0
    szCalled    db "Trampoline called successfully!", 0
    
    pExecMemory dd 0

.code

;----------------------------------------------------------------------
; AllocExecutableMemory - Allocates executable memory
;----------------------------------------------------------------------
AllocExecutableMemory PROC dwSize:DWORD
    push PAGE_EXECUTE_READWRITE
    push MEM_COMMIT or MEM_RESERVE
    push dwSize
    push NULL
    call VirtualAlloc
    ; EAX = pointer to executable memory (or NULL on failure)
    ret
AllocExecutableMemory ENDP

;----------------------------------------------------------------------
; FreeExecutableMemory - Frees allocated memory
;----------------------------------------------------------------------
FreeExecutableMemory PROC pMemory:DWORD
    push MEM_RELEASE
    push 0
    push pMemory
    call VirtualFree
    ret
FreeExecutableMemory ENDP

;----------------------------------------------------------------------
; main
;----------------------------------------------------------------------
main PROC
    ; Allocate 64 bytes of executable memory
    push 64
    call AllocExecutableMemory
    test eax, eax
    jz @failed
    mov pExecMemory, eax
    
    ; Write a simple function to this memory:
    ;   push offset szCalled
    ;   call MessageBoxA  ; (simplified, just show message)
    ;   ret
    
    ; Actually, let's write: mov eax, 12345678h / ret
    mov edi, pExecMemory
    mov BYTE PTR [edi], 0B8h        ; MOV EAX, imm32
    mov DWORD PTR [edi+1], 12345678h
    mov BYTE PTR [edi+5], 0C3h      ; RET
    
    ; Call our dynamically created function!
    call pExecMemory
    ; EAX should now be 12345678h
    
    ; Clean up
    push pExecMemory
    call FreeExecutableMemory
    
    push MB_OK
    push OFFSET szTitle
    push OFFSET szCalled
    push NULL
    call MessageBoxA
    
    jmp @exit

@failed:
    push MB_ICONERROR
    push OFFSET szTitle
    push OFFSET szAllocated
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

### Task 1: Memory Protection Explorer (25 minutes)
Modify Exercise 1 to also show:
1. The entire memory map of your process (loop through all regions)
2. Which regions belong to which DLLs
3. Total executable vs non-executable memory

### Task 2: Error Handling (20 minutes)
Write a function that attempts to modify protected memory and:
1. Uses GetLastError to get the error code
2. Translates error codes to human-readable messages
3. Handles ERROR_INVALID_ADDRESS, ERROR_ACCESS_DENIED, etc.

### Task 3: DEP Test (25 minutes)
Create a program that:
1. Allocates memory without EXECUTE flag
2. Writes code to it
3. Tries to execute it (should fail with DEP)
4. Then allocates with EXECUTE flag and succeeds

### Task 4: Protection State Machine (20 minutes)
Draw a state diagram showing:
1. What protections allow what operations
2. Which protection changes are allowed
3. What happens when you violate protection

---

## ✅ Session Checklist

Before moving to Session 7, make sure you can:

- [ ] List all memory protection flags
- [ ] Use VirtualProtect correctly
- [ ] Use VirtualQuery to check protection
- [ ] Always restore protection after modification
- [ ] Allocate executable memory with VirtualAlloc
- [ ] Explain why FlushInstructionCache is needed
- [ ] Handle DEP considerations for trampolines

---

## 🔜 Next Session

In **Session 07: Inline/Detour Hooking Technique**, we'll learn:
- Implementing the complete inline hook
- Writing the JMP instruction
- Handling different function prologues
- Creating a reusable hook function

[Continue to Session 07 →](session_07.md)

---

## 📖 Additional Resources

- [VirtualProtect Documentation](https://docs.microsoft.com/en-us/windows/win32/api/memoryapi/nf-memoryapi-virtualprotect)
- [VirtualQuery Documentation](https://docs.microsoft.com/en-us/windows/win32/api/memoryapi/nf-memoryapi-virtualquery)
- [Data Execution Prevention](https://docs.microsoft.com/en-us/windows/win32/memory/data-execution-prevention)
