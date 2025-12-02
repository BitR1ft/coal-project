# Session 01: Introduction to API Hooking

## 🎯 Learning Objectives

By the end of this session, you will:
- Understand what API hooking is
- Know why API hooking is used
- Recognize different types of hooking techniques
- Understand the ethical implications

---

## 📚 Part 1: Theory - What is API Hooking?

### What is an API?

**API** stands for **Application Programming Interface**. In Windows, APIs are functions provided by the operating system that programs can call to perform operations.

For example:
- `MessageBoxA()` - Shows a dialog box with a message
- `CreateFile()` - Opens or creates a file
- `connect()` - Connects to a network server
- `CreateProcess()` - Starts a new program

When you write a program in C/C++ and call these functions, you're using the Windows API.

```c
// Example: Calling Windows API
MessageBoxA(NULL, "Hello World!", "Title", MB_OK);
```

### What is API Hooking?

**API Hooking** is a technique that intercepts API function calls. Instead of the function running normally, YOUR code runs first!

Think of it like this:
```
NORMAL CALL:
[Your Program] --> [MessageBoxA] --> [Dialog Box Appears]

HOOKED CALL:
[Your Program] --> [YOUR HOOK CODE] --> [MessageBoxA] --> [Dialog Box Appears]
                          |
                          +--> [You can LOG, MODIFY, or BLOCK the call!]
```

### Why is API Hooking Used?

#### 1. Security Software (Good Use)
- **Antivirus**: Monitors file operations to detect malware
- **EDR (Endpoint Detection)**: Watches for suspicious behavior
- **Firewalls**: Monitors network connections

#### 2. System Monitoring (Good Use)
- **Process Monitor**: Shows all file/registry operations
- **API Monitor**: Records all API calls a program makes
- **Debugging tools**: Help developers find bugs

#### 3. Malware (Bad Use - for understanding only)
- **Keyloggers**: Hook keyboard input
- **Rootkits**: Hide malicious activity
- **Banking trojans**: Intercept credentials

### The Hook Process Visualized

```
BEFORE HOOK INSTALLED:
┌──────────────────────────────────────────────────────────────┐
│                     YOUR PROGRAM                              │
│                          │                                    │
│                          ▼                                    │
│              call MessageBoxA()                               │
│                          │                                    │
└──────────────────────────│───────────────────────────────────┘
                           │
                           ▼
┌──────────────────────────────────────────────────────────────┐
│                   WINDOWS DLL (user32.dll)                    │
│                                                               │
│  MessageBoxA:                                                 │
│      push ebp              ; Function prologue                │
│      mov ebp, esp          ; Standard setup                   │
│      ...                   ; Rest of function                 │
│      ret                   ; Return                           │
└──────────────────────────────────────────────────────────────┘

AFTER HOOK INSTALLED:
┌──────────────────────────────────────────────────────────────┐
│                     YOUR PROGRAM                              │
│                          │                                    │
│                          ▼                                    │
│              call MessageBoxA()                               │
│                          │                                    │
└──────────────────────────│───────────────────────────────────┘
                           │
                           ▼
┌──────────────────────────────────────────────────────────────┐
│                   WINDOWS DLL (user32.dll)                    │
│                                                               │
│  MessageBoxA:                                                 │
│      JMP HookHandler       ; ← MODIFIED! Jumps to our code   │
│      ...                   ; Rest of function (skipped)      │
│                                                               │
└──────────────────────────────────────────────────────────────┘
                           │
                           ▼
┌──────────────────────────────────────────────────────────────┐
│                   YOUR HOOK HANDLER                           │
│                                                               │
│  HookHandler:                                                 │
│      ; Log the call                                           │
│      ; Inspect parameters                                     │
│      ; Call original function                                 │
│      ; Modify return value (optional)                         │
│      ret                                                      │
└──────────────────────────────────────────────────────────────┘
```

---

## 📚 Part 2: Types of Hooking Techniques

### 1. IAT Hooking (Import Address Table)

**How it works**: Windows programs have a table (IAT) that contains addresses of API functions. We can modify this table to point to our function.

```
IAT Table (Before):
┌─────────────────┬──────────────────────┐
│ Function Name   │ Address              │
├─────────────────┼──────────────────────┤
│ MessageBoxA     │ 0x77D507EA           │ ← Points to real function
│ CreateFileA     │ 0x7C801A28           │
└─────────────────┴──────────────────────┘

IAT Table (After Hook):
┌─────────────────┬──────────────────────┐
│ Function Name   │ Address              │
├─────────────────┼──────────────────────┤
│ MessageBoxA     │ 0x00401000           │ ← Points to OUR function!
│ CreateFileA     │ 0x7C801A28           │
└─────────────────┴──────────────────────┘
```

**Pros**: Easy to implement
**Cons**: Only works for imported functions, can be bypassed

### 2. Inline/Detour Hooking (What we'll learn!)

**How it works**: We modify the first few bytes of the target function to jump to our code.

```
Original Function:
0x77D507EA: 8B FF        mov edi, edi
0x77D507EC: 55           push ebp
0x77D507ED: 8B EC        mov ebp, esp
0x77D507EF: ...          (rest of function)

After Hook:
0x77D507EA: E9 XX XX XX XX   JMP OurHookHandler (5 bytes)
0x77D507EF: ...              (rest of function)
```

**Pros**: Works on any function, very powerful
**Cons**: More complex, must handle stolen bytes

### 3. VTable Hooking

**How it works**: For object-oriented code (C++), we modify virtual function tables.

**Pros**: Good for COM objects
**Cons**: Only works for virtual functions

### 4. SSDT Hooking (Kernel Level)

**How it works**: Modify kernel-level system call tables.

**Pros**: System-wide, very powerful
**Cons**: Requires kernel driver, complex

---

## 📚 Part 3: Key Concepts You Need to Know

### 1. Function Prologue

Most functions start with the same pattern:
```asm
push ebp        ; Save old base pointer
mov ebp, esp    ; Set up new stack frame
sub esp, XX     ; Allocate local variables
```

This is called the **function prologue**. We'll use this knowledge when hooking.

### 2. The JMP Instruction

The `JMP` instruction changes program execution to a different address:
```asm
JMP address     ; Jump to 'address'
```

For hooking, we use a **relative JMP** which is 5 bytes:
- 1 byte: Opcode (E9)
- 4 bytes: Relative offset

### 3. Register Preservation

When your hook runs, you must NOT corrupt the CPU registers. The original function expects certain values in registers.

```asm
; Save all registers
pushad     ; Push EAX, ECX, EDX, EBX, ESP, EBP, ESI, EDI
pushfd     ; Push flags

; Your hook code here

; Restore all registers
popfd      ; Pop flags
popad      ; Pop all registers
```

### 4. Memory Protection

Code memory is usually read-only. We must change protection before modifying:

```c
VirtualProtect(address, size, PAGE_EXECUTE_READWRITE, &oldProtect);
// Now we can modify the code
VirtualProtect(address, size, oldProtect, &dummy);  // Restore
```

---

## 💻 Part 4: Practical - Let's See Hooks in Action!

In this practical, we'll use a simple C program to understand the concept before diving into assembly.

### Exercise 1: Watch API Calls with API Monitor

1. Download **API Monitor** from http://www.rohitab.com/apimonitor
2. Run API Monitor as Administrator
3. In the left panel, expand "User32.dll" and check "MessageBoxA"
4. Click "Monitor New Process"
5. Run any program that shows message boxes (like Notepad's "About")
6. Watch the API calls appear in the monitor!

**What you learned**: You can see exactly when programs call APIs, what parameters they use, and what they return.

### Exercise 2: Understanding Function Addresses

Create a simple C program to see function addresses:

```c
// save as: view_addresses.c
// compile with: cl view_addresses.c user32.lib

#include <windows.h>
#include <stdio.h>

int main() {
    // Get address of MessageBoxA
    HMODULE hUser32 = LoadLibraryA("user32.dll");
    FARPROC pMessageBoxA = GetProcAddress(hUser32, "MessageBoxA");
    
    printf("user32.dll loaded at: 0x%p\n", hUser32);
    printf("MessageBoxA is at:    0x%p\n", pMessageBoxA);
    
    // Show the first bytes of the function
    unsigned char* bytes = (unsigned char*)pMessageBoxA;
    printf("\nFirst 10 bytes of MessageBoxA:\n");
    for(int i = 0; i < 10; i++) {
        printf("%02X ", bytes[i]);
    }
    printf("\n");
    
    // Call it normally
    MessageBoxA(NULL, "This is a normal call!", "Normal", MB_OK);
    
    return 0;
}
```

**Expected Output** (addresses will vary):
```
user32.dll loaded at: 0x77D10000
MessageBoxA is at:    0x77D507EA

First 10 bytes of MessageBoxA:
8B FF 55 8B EC 83 EC 50 A1 ...
```

**What you learned**: 
- Functions have specific memory addresses
- We can find these addresses using `GetProcAddress`
- We can read the actual bytes of the function

### Exercise 3: Conceptual Hook (No actual hooking yet)

```c
// save as: concept_hook.c
// This shows the CONCEPT - we're not actually hooking yet!

#include <windows.h>
#include <stdio.h>

// Original function pointer
typedef int (WINAPI *OriginalMessageBoxA)(HWND, LPCSTR, LPCSTR, UINT);
OriginalMessageBoxA g_OriginalMessageBox;

// Our "hook" function
int WINAPI MyMessageBoxA(HWND hWnd, LPCSTR lpText, LPCSTR lpCaption, UINT uType) {
    printf("[HOOK] MessageBoxA intercepted!\n");
    printf("[HOOK] Text: %s\n", lpText);
    printf("[HOOK] Caption: %s\n", lpCaption);
    
    // Call the original function
    return g_OriginalMessageBox(hWnd, lpText, lpCaption, uType);
}

int main() {
    // Store original function
    g_OriginalMessageBox = (OriginalMessageBoxA)GetProcAddress(
        GetModuleHandleA("user32.dll"), "MessageBoxA");
    
    printf("If we were hooking, we would redirect MessageBoxA to MyMessageBoxA\n");
    printf("Original: 0x%p\n", g_OriginalMessageBox);
    printf("Our Hook: 0x%p\n", MyMessageBoxA);
    
    // Simulate what would happen if hooked
    printf("\n--- Simulating hook ---\n");
    MyMessageBoxA(NULL, "Hello!", "Test", MB_OK);
    
    return 0;
}
```

**What you learned**: The concept of having a hook function that logs information then calls the original.

---

## 📝 Part 5: Tasks

Complete these tasks to reinforce your learning:

### Task 1: Research (30 minutes)
Write answers to these questions in a text file:
1. What is the difference between IAT hooking and inline hooking?
2. Name three legitimate uses of API hooking
3. What is a function prologue?
4. Why do we need to preserve registers?

### Task 2: API Monitor Practice (20 minutes)
1. Use API Monitor to monitor "CreateFileA" in Notepad
2. Create a new text file and save it
3. Document all the CreateFileA calls you see
4. What parameters were passed?

### Task 3: Code Exploration (20 minutes)
1. Modify Exercise 2 to also show the address of `CreateFileA`
2. Compare the first 10 bytes of `MessageBoxA` and `CreateFileA`
3. Are they similar? (Hint: Look for the function prologue pattern)

### Task 4: Visualization (15 minutes)
Draw a diagram (on paper or digital) showing:
1. A normal API call flow
2. A hooked API call flow
3. Label all the components

---

## ✅ Session Checklist

Before moving to Session 2, make sure you can:

- [ ] Explain what API hooking is in your own words
- [ ] Name at least 3 types of hooking techniques
- [ ] Understand why register preservation is important
- [ ] Know what a function prologue looks like
- [ ] Use API Monitor to watch API calls
- [ ] Find the address of a Windows API function

---

## 🔜 Next Session

In **Session 02: Windows Architecture & Memory**, we'll learn:
- How Windows organizes memory
- Virtual memory and physical memory
- Process address space
- DLLs and how they're loaded

[Continue to Session 02 →](session_02.md)

---

## 📖 Additional Resources

- [Microsoft Windows API Documentation](https://docs.microsoft.com/en-us/windows/win32/apiindex/windows-api-list)
- [Intel x86 Assembly Guide](https://www.cs.virginia.edu/~evans/cs216/guides/x86.html)
- [API Monitor Download](http://www.rohitab.com/apimonitor)
