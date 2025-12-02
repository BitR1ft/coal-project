# Session 02: Windows Architecture and Memory

## 🎯 Learning Objectives

By the end of this session, you will:
- Understand how Windows organizes memory
- Know the difference between virtual and physical memory
- Understand process address space
- Learn how DLLs are loaded and used
- Understand memory protection

---

## 📚 Part 1: Theory - Windows Memory Model

### Virtual Memory vs Physical Memory

**Physical Memory (RAM)**: The actual hardware memory in your computer (8GB, 16GB, etc.)

**Virtual Memory**: An abstraction that makes each process think it has its own private memory space.

```
┌─────────────────────────────────────────────────────────────────┐
│                     VIRTUAL MEMORY CONCEPT                       │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────┐       │
│  │  Process A   │    │  Process B   │    │  Process C   │       │
│  │              │    │              │    │              │       │
│  │ Virtual Addr │    │ Virtual Addr │    │ Virtual Addr │       │
│  │ 0x00000000   │    │ 0x00000000   │    │ 0x00000000   │       │
│  │ to           │    │ to           │    │ to           │       │
│  │ 0xFFFFFFFF   │    │ 0xFFFFFFFF   │    │ 0xFFFFFFFF   │       │
│  └──────┬───────┘    └──────┬───────┘    └──────┬───────┘       │
│         │                    │                   │               │
│         ▼                    ▼                   ▼               │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │                    PAGE TABLES                           │    │
│  │        (Translate Virtual to Physical)                   │    │
│  └───────────────────────────┬─────────────────────────────┘    │
│                              │                                   │
│                              ▼                                   │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │                  PHYSICAL MEMORY (RAM)                   │    │
│  │   ┌────┬────┬────┬────┬────┬────┬────┬────┬────┐        │    │
│  │   │ A  │ B  │ A  │ C  │ B  │ A  │ C  │ B  │ C  │        │    │
│  │   └────┴────┴────┴────┴────┴────┴────┴────┴────┘        │    │
│  └─────────────────────────────────────────────────────────┘    │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘

Each process THINKS it has the full 4GB (32-bit) address space!
Windows handles the translation transparently.
```

**Why is this important for hooking?**
- Each process has its own view of memory
- Hooking affects only the target process
- Addresses are virtual, not physical

### 32-bit Process Address Space

In a 32-bit Windows process, the 4GB virtual address space is divided:

```
0xFFFFFFFF ┌───────────────────────────────────────────┐
           │                                           │
           │            KERNEL SPACE                   │
           │         (2GB - System use)                │
           │        NOT ACCESSIBLE BY USER             │
           │                                           │
0x80000000 ├───────────────────────────────────────────┤
           │                                           │
           │            USER SPACE                     │
           │           (2GB - Your code)               │
           │                                           │
           │  ┌─────────────────────────────────────┐  │
           │  │ Stack (grows downward ↓)            │  │
           │  │ Thread local storage                │  │
           │  ├─────────────────────────────────────┤  │
           │  │                                     │  │
           │  │ FREE SPACE                          │  │
           │  │ (available for allocation)          │  │
           │  │                                     │  │
           │  ├─────────────────────────────────────┤  │
           │  │ Heap (grows upward ↑)               │  │
           │  │ Dynamic memory allocation           │  │
           │  ├─────────────────────────────────────┤  │
           │  │ DLLs                                │  │
           │  │ (user32.dll, kernel32.dll, etc.)    │  │
           │  ├─────────────────────────────────────┤  │
           │  │ Program Code (.exe)                 │  │
           │  │ (starting at 0x00400000)            │  │
           │  └─────────────────────────────────────┘  │
           │                                           │
0x00000000 └───────────────────────────────────────────┘
```

---

## 📚 Part 2: Memory Sections and Protection

### Executable Sections

When a program is loaded, it has different sections:

| Section | Purpose | Typical Protection |
|---------|---------|-------------------|
| .text   | Code (instructions) | Read + Execute |
| .data   | Initialized global variables | Read + Write |
| .rdata  | Read-only data (strings, constants) | Read only |
| .bss    | Uninitialized data | Read + Write |

### Memory Protection Flags

Windows uses protection flags for each memory region:

| Flag | Value | Meaning |
|------|-------|---------|
| PAGE_NOACCESS | 0x01 | Cannot access at all |
| PAGE_READONLY | 0x02 | Can read only |
| PAGE_READWRITE | 0x04 | Can read and write |
| PAGE_EXECUTE | 0x10 | Can execute only |
| PAGE_EXECUTE_READ | 0x20 | Can execute and read |
| PAGE_EXECUTE_READWRITE | 0x40 | Can do everything |

### Why Protection Matters for Hooking

Code sections are usually **PAGE_EXECUTE_READ** - you can't write to them!

```
Before VirtualProtect:
┌────────────────────────────────────────┐
│ MessageBoxA code                       │
│ Protection: PAGE_EXECUTE_READ          │
│                                        │
│ If we try to write:                    │
│   mov byte ptr [address], 0xE9         │
│   → ACCESS VIOLATION! CRASH!           │
└────────────────────────────────────────┘

After VirtualProtect:
┌────────────────────────────────────────┐
│ MessageBoxA code                       │
│ Protection: PAGE_EXECUTE_READWRITE     │
│                                        │
│ Now we can write:                      │
│   mov byte ptr [address], 0xE9         │
│   → SUCCESS!                           │
└────────────────────────────────────────┘
```

---

## 📚 Part 3: DLLs (Dynamic Link Libraries)

### What is a DLL?

A **DLL** (Dynamic Link Library) is a file containing code and data that multiple programs can use simultaneously.

```
┌─────────────────────────────────────────────────────────────────┐
│                    DLL SHARING CONCEPT                           │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌──────────────┐          ┌──────────────────────────────┐     │
│  │ Notepad.exe  │─────────▶│                              │     │
│  └──────────────┘          │       user32.dll             │     │
│                            │                              │     │
│  ┌──────────────┐          │  Contains:                   │     │
│  │ Calculator   │─────────▶│  - MessageBoxA               │     │
│  └──────────────┘          │  - CreateWindowExA           │     │
│                            │  - SendMessageA              │     │
│  ┌──────────────┐          │  - (hundreds more...)        │     │
│  │ Your.exe     │─────────▶│                              │     │
│  └──────────────┘          └──────────────────────────────┘     │
│                                                                  │
│  All three programs share the SAME copy of user32.dll!           │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### Key Windows DLLs

| DLL | Purpose |
|-----|---------|
| kernel32.dll | Core Windows functions (files, processes, memory) |
| user32.dll | User interface functions (windows, messages, dialogs) |
| ntdll.dll | Native API (lower level than kernel32) |
| advapi32.dll | Advanced API (security, registry) |
| ws2_32.dll | Windows Sockets (networking) |

### How DLLs are Loaded

When your program uses a function from a DLL:

```
1. COMPILE TIME:
   Your code:
   │  MessageBoxA(...)
   │
   Compiler adds reference to Import Table

2. LOAD TIME:
   Windows Loader:
   │  1. Loads your .exe into memory
   │  2. Reads Import Table
   │  3. Loads required DLLs (user32.dll)
   │  4. Fills Import Address Table (IAT) with function addresses

3. RUN TIME:
   When you call MessageBoxA:
   │  1. Look up address in IAT
   │  2. Jump to that address (in user32.dll)
   │  3. Function executes
   │  4. Returns to your code
```

### The Import Address Table (IAT)

The **IAT** is a table in your program that contains addresses of imported functions:

```
┌──────────────────────────────────────────────────────────────┐
│                  YOUR PROGRAM'S IAT                          │
├──────────────────────────────────────────────────────────────┤
│                                                              │
│  ┌─────────────────────┬───────────────────────┐            │
│  │ Function Name       │ Address               │            │
│  ├─────────────────────┼───────────────────────┤            │
│  │ MessageBoxA         │ 0x77D507EA  ──────────┼───▶ user32 │
│  │ MessageBoxW         │ 0x77D50855  ──────────┼───▶ user32 │
│  │ CreateFileA         │ 0x7C801A28  ──────────┼───▶ kernel32│
│  │ ReadFile            │ 0x7C801812  ──────────┼───▶ kernel32│
│  │ socket              │ 0x71AB1234  ──────────┼───▶ ws2_32 │
│  └─────────────────────┴───────────────────────┘            │
│                                                              │
│  When your code calls MessageBoxA, it actually does:         │
│     call dword ptr [IAT.MessageBoxA]                         │
│  which calls the address stored in the IAT                   │
│                                                              │
└──────────────────────────────────────────────────────────────┘
```

---

## 📚 Part 4: Finding Function Addresses

### Using GetProcAddress

```c
// Step 1: Get handle to the DLL
HMODULE hModule = LoadLibraryA("user32.dll");
// or
HMODULE hModule = GetModuleHandleA("user32.dll");

// Step 2: Get function address
FARPROC pFunc = GetProcAddress(hModule, "MessageBoxA");

// Now pFunc points to MessageBoxA's code!
```

### In Assembly

```asm
; Step 1: Load the library
push OFFSET szUser32          ; "user32.dll"
call LoadLibraryA
mov hUser32, eax              ; Save handle

; Step 2: Get function address
push OFFSET szMessageBoxA     ; "MessageBoxA"
push hUser32
call GetProcAddress
mov pMessageBoxA, eax         ; Save address

; Now pMessageBoxA contains the address!
```

---

## 💻 Part 5: Practical - Exploring Memory

### Exercise 1: View Process Memory

Create this program to explore process memory:

```c
// save as: explore_memory.c
// compile: cl explore_memory.c

#include <windows.h>
#include <stdio.h>

int main() {
    // Get base address of our own module
    HMODULE hSelf = GetModuleHandleA(NULL);
    printf("Our .exe base address: 0x%p\n\n", hSelf);
    
    // Get loaded DLLs
    printf("Loaded DLLs:\n");
    printf("%-20s %s\n", "DLL Name", "Base Address");
    printf("%-20s %s\n", "--------", "------------");
    
    HMODULE hKernel32 = GetModuleHandleA("kernel32.dll");
    HMODULE hUser32 = GetModuleHandleA("user32.dll");
    HMODULE hNtdll = GetModuleHandleA("ntdll.dll");
    
    printf("%-20s 0x%p\n", "kernel32.dll", hKernel32);
    printf("%-20s 0x%p\n", "user32.dll", hUser32);
    printf("%-20s 0x%p\n", "ntdll.dll", hNtdll);
    
    // Get some function addresses
    printf("\nFunction Addresses:\n");
    printf("%-25s %s\n", "Function", "Address");
    printf("%-25s %s\n", "--------", "-------");
    
    FARPROC pMessageBoxA = GetProcAddress(hUser32, "MessageBoxA");
    FARPROC pCreateFileA = GetProcAddress(hKernel32, "CreateFileA");
    FARPROC pVirtualProtect = GetProcAddress(hKernel32, "VirtualProtect");
    
    printf("%-25s 0x%p\n", "MessageBoxA", pMessageBoxA);
    printf("%-25s 0x%p\n", "CreateFileA", pCreateFileA);
    printf("%-25s 0x%p\n", "VirtualProtect", pVirtualProtect);
    
    printf("\nPress Enter to exit...");
    getchar();
    return 0;
}
```

### Exercise 2: Memory Protection Query

```c
// save as: query_protection.c
// compile: cl query_protection.c

#include <windows.h>
#include <stdio.h>

const char* GetProtectionString(DWORD protect) {
    switch(protect) {
        case PAGE_EXECUTE: return "EXECUTE";
        case PAGE_EXECUTE_READ: return "EXECUTE_READ";
        case PAGE_EXECUTE_READWRITE: return "EXECUTE_READWRITE";
        case PAGE_NOACCESS: return "NOACCESS";
        case PAGE_READONLY: return "READONLY";
        case PAGE_READWRITE: return "READWRITE";
        default: return "UNKNOWN";
    }
}

int main() {
    MEMORY_BASIC_INFORMATION mbi;
    
    // Get address of MessageBoxA
    HMODULE hUser32 = GetModuleHandleA("user32.dll");
    LPVOID pMessageBoxA = (LPVOID)GetProcAddress(hUser32, "MessageBoxA");
    
    printf("MessageBoxA at: 0x%p\n\n", pMessageBoxA);
    
    // Query memory info
    if(VirtualQuery(pMessageBoxA, &mbi, sizeof(mbi))) {
        printf("Memory Region Info:\n");
        printf("  Base Address:       0x%p\n", mbi.BaseAddress);
        printf("  Allocation Base:    0x%p\n", mbi.AllocationBase);
        printf("  Region Size:        0x%X (%d KB)\n", 
               (DWORD)mbi.RegionSize, (DWORD)mbi.RegionSize / 1024);
        printf("  Protection:         0x%X (%s)\n", 
               mbi.Protect, GetProtectionString(mbi.Protect));
        printf("  State:              %s\n", 
               mbi.State == MEM_COMMIT ? "COMMITTED" : "OTHER");
        printf("  Type:               %s\n", 
               mbi.Type == MEM_IMAGE ? "IMAGE (DLL/EXE)" : "OTHER");
    }
    
    printf("\nPress Enter to exit...");
    getchar();
    return 0;
}
```

### Exercise 3: Changing Memory Protection

```c
// save as: change_protection.c
// compile: cl change_protection.c

#include <windows.h>
#include <stdio.h>

int main() {
    DWORD oldProtect;
    
    // Get MessageBoxA address
    HMODULE hUser32 = GetModuleHandleA("user32.dll");
    LPVOID pMessageBoxA = (LPVOID)GetProcAddress(hUser32, "MessageBoxA");
    
    printf("MessageBoxA at: 0x%p\n\n", pMessageBoxA);
    
    // Try to read first byte (should work)
    printf("Reading first byte: 0x%02X\n", *(unsigned char*)pMessageBoxA);
    
    // Try to write (this would crash without VirtualProtect!)
    printf("\n--- Changing protection ---\n");
    
    if(VirtualProtect(pMessageBoxA, 5, PAGE_EXECUTE_READWRITE, &oldProtect)) {
        printf("Protection changed to EXECUTE_READWRITE\n");
        printf("Old protection was: 0x%X\n", oldProtect);
        
        // Now we COULD write... but we won't actually modify anything
        printf("We could now write to this memory!\n");
        
        // Restore protection
        VirtualProtect(pMessageBoxA, 5, oldProtect, &oldProtect);
        printf("Protection restored.\n");
    } else {
        printf("VirtualProtect failed! Error: %d\n", GetLastError());
    }
    
    printf("\nPress Enter to exit...");
    getchar();
    return 0;
}
```

---

## 💻 Part 6: Practical - Dumping Function Bytes

### Exercise 4: See What We'll Be Modifying

```c
// save as: dump_function.c
// compile: cl dump_function.c

#include <windows.h>
#include <stdio.h>

void DumpBytes(const char* name, LPVOID addr, int count) {
    unsigned char* bytes = (unsigned char*)addr;
    
    printf("\n%s at 0x%p:\n", name, addr);
    printf("┌");
    for(int i = 0; i < count; i++) printf("─────");
    printf("┐\n│");
    
    for(int i = 0; i < count; i++) {
        printf(" %02X  ", bytes[i]);
    }
    printf("│\n└");
    for(int i = 0; i < count; i++) printf("─────");
    printf("┘\n");
    
    // Try to show as assembly
    printf("Likely disassembly:\n");
    
    int offset = 0;
    while(offset < count) {
        printf("  +%d: ", offset);
        
        // Common patterns
        if(bytes[offset] == 0x8B && bytes[offset+1] == 0xFF) {
            printf("mov edi, edi   (2 bytes - NOP equivalent)\n");
            offset += 2;
        }
        else if(bytes[offset] == 0x55) {
            printf("push ebp       (1 byte)\n");
            offset += 1;
        }
        else if(bytes[offset] == 0x8B && bytes[offset+1] == 0xEC) {
            printf("mov ebp, esp   (2 bytes)\n");
            offset += 2;
        }
        else if(bytes[offset] == 0xE9) {
            printf("jmp XXXXXXXX   (5 bytes - HOOK!)\n");
            offset += 5;
        }
        else if(bytes[offset] == 0x90) {
            printf("nop            (1 byte)\n");
            offset += 1;
        }
        else {
            printf("%02X             (unknown)\n", bytes[offset]);
            offset += 1;
        }
        
        if(offset >= 10) break;
    }
}

int main() {
    HMODULE hUser32 = GetModuleHandleA("user32.dll");
    HMODULE hKernel32 = GetModuleHandleA("kernel32.dll");
    
    // Dump MessageBoxA
    LPVOID pMessageBoxA = (LPVOID)GetProcAddress(hUser32, "MessageBoxA");
    DumpBytes("MessageBoxA", pMessageBoxA, 10);
    
    // Dump MessageBoxW
    LPVOID pMessageBoxW = (LPVOID)GetProcAddress(hUser32, "MessageBoxW");
    DumpBytes("MessageBoxW", pMessageBoxW, 10);
    
    // Dump CreateFileA
    LPVOID pCreateFileA = (LPVOID)GetProcAddress(hKernel32, "CreateFileA");
    DumpBytes("CreateFileA", pCreateFileA, 10);
    
    printf("\nPress Enter to exit...");
    getchar();
    return 0;
}
```

**Expected Output (approximately):**
```
MessageBoxA at 0x77D507EA:
┌────────────────────────────────────────────────────────┐
│ 8B   FF   55   8B   EC   83   EC   50   A1   XX   │
└────────────────────────────────────────────────────────┘
Likely disassembly:
  +0: mov edi, edi   (2 bytes - NOP equivalent)
  +2: push ebp       (1 byte)
  +3: mov ebp, esp   (2 bytes)
```

---

## 📝 Part 7: Tasks

### Task 1: Memory Map (30 minutes)
1. Run `explore_memory.c` and note all the addresses
2. Draw a memory map showing where each DLL is loaded
3. Calculate the size of user32.dll (hint: look at the next DLL's address)

### Task 2: Protection Investigation (20 minutes)
1. Use `query_protection.c` to check protection of:
   - MessageBoxA
   - CreateFileA
   - A variable in your program
2. Are they the same protection? Why or why not?

### Task 3: Function Prologue Analysis (25 minutes)
1. Run `dump_function.c` on at least 5 different functions
2. Document the first 5 bytes of each
3. Do they all start with the same pattern?
4. Research: What is "hot patching" and why do Windows functions start with `mov edi, edi`?

### Task 4: Write a Memory Viewer (30 minutes)
Create a program that:
1. Takes a DLL name as input
2. Takes a function name as input
3. Shows the function's address
4. Shows the first 20 bytes
5. Shows the memory protection

---

## ✅ Session Checklist

Before moving to Session 3, make sure you can:

- [ ] Explain virtual memory vs physical memory
- [ ] Draw the 32-bit address space layout
- [ ] List at least 4 memory protection flags
- [ ] Explain what a DLL is
- [ ] Use GetModuleHandle and GetProcAddress
- [ ] Use VirtualQuery to check memory protection
- [ ] Use VirtualProtect to change memory protection
- [ ] Explain what the IAT is

---

## 🔜 Next Session

In **Session 03: x86 Assembly Fundamentals**, we'll learn:
- CPU registers and their purposes
- Basic x86 instructions
- Calling conventions (stdcall)
- Stack operations

[Continue to Session 03 →](session_03.md)

---

## 📖 Additional Resources

- [Microsoft Virtual Memory Documentation](https://docs.microsoft.com/en-us/windows/win32/memory/virtual-memory)
- [PE File Format](https://docs.microsoft.com/en-us/windows/win32/debug/pe-format)
- [Understanding the Import Address Table](https://resources.infosecinstitute.com/topic/the-import-address-table/)
