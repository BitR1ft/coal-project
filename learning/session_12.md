# Session 12: Thread Safety in Hooking

## 🎯 Learning Objectives

By the end of this session, you will:
- Understand why thread safety is crucial for hooks
- Implement thread-safe hooks using Critical Sections
- Use atomic operations where applicable
- Handle multi-threaded scenarios correctly

---

## 📚 Part 1: The Thread Safety Problem

### Why Hooks Need Thread Safety

In a multi-threaded application, multiple threads can call the same hooked function simultaneously:

```
┌─────────────────────────────────────────────────────────────────┐
│                  MULTI-THREADED HOOK SCENARIO                    │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  Thread 1          Thread 2          Thread 3                   │
│     │                 │                 │                        │
│     ▼                 ▼                 ▼                        │
│  ┌──────────────────────────────────────────────────────┐       │
│  │              MessageBoxA (Hooked)                     │       │
│  └───────────────────────┬──────────────────────────────┘       │
│                          │                                       │
│                          ▼                                       │
│  ┌──────────────────────────────────────────────────────┐       │
│  │                 Your Hook Handler                     │       │
│  │                                                       │       │
│  │   Thread 1 runs:  inc dwCounter                      │       │
│  │   Thread 2 runs:  inc dwCounter    ← RACE CONDITION! │       │
│  │   Thread 3 runs:  inc dwCounter                      │       │
│  └──────────────────────────────────────────────────────┘       │
│                                                                  │
│  Problem: If all three increment simultaneously,                │
│  dwCounter might increase by 1 instead of 3!                   │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### Race Condition Example

```asm
; NON-THREAD-SAFE counter increment:
; 
; Thread 1 reads dwCounter = 5
; Thread 2 reads dwCounter = 5  (before Thread 1 writes)
; Thread 1 writes dwCounter = 6
; Thread 2 writes dwCounter = 6  (overwrites Thread 1's result!)
;
; Expected: 7, Actual: 6

inc dwCounter       ; NOT atomic on multi-core CPUs!
```

### What Can Go Wrong

| Problem | Description | Result |
|---------|-------------|--------|
| Lost updates | Two threads increment same counter | Wrong count |
| Corrupted data | Partial writes | Garbage values |
| Deadlocks | Circular waiting | Program hangs |
| Race conditions | Timing-dependent bugs | Intermittent failures |

---

## 📚 Part 2: Critical Sections

### What is a Critical Section?

A **Critical Section** is a synchronization object that allows only ONE thread to execute a protected code block at a time.

```asm
; Only one thread at a time can be between Enter and Leave
call EnterCriticalSection
; ... protected code ...
call LeaveCriticalSection
```

### Setting Up Critical Sections

```asm
.data
    g_CriticalSection CRITICAL_SECTION <>

.code
; Initialize at program start
InitSync PROC
    lea eax, g_CriticalSection
    push eax
    call InitializeCriticalSection
    ret
InitSync ENDP

; Cleanup at program end
CleanupSync PROC
    lea eax, g_CriticalSection
    push eax
    call DeleteCriticalSection
    ret
CleanupSync ENDP
```

### Using Critical Sections in Hooks

```asm
;-------------------------------------------------------------------------------
; ThreadSafeHook - Properly synchronized hook
;-------------------------------------------------------------------------------
ThreadSafeHook PROC
    pushad
    pushfd
    
    ; Enter critical section
    lea eax, g_CriticalSection
    push eax
    call EnterCriticalSection
    
    ; ═══════════════════════════════════════
    ; PROTECTED CODE - Only one thread here
    ; ═══════════════════════════════════════
    inc dwCallCount
    
    ; Access shared data safely
    mov eax, [dwLastCaller]
    mov [dwPreviousCaller], eax
    
    call GetCurrentThreadId
    mov [dwLastCaller], eax
    ; ═══════════════════════════════════════
    
    ; Leave critical section
    lea eax, g_CriticalSection
    push eax
    call LeaveCriticalSection
    
    popfd
    popad
    jmp pTrampoline
ThreadSafeHook ENDP
```

---

## 📚 Part 3: Atomic Operations

### What are Atomic Operations?

**Atomic operations** are guaranteed to complete without interruption. The CPU provides special instructions for this.

### The LOCK Prefix

The `LOCK` prefix makes an instruction atomic:

```asm
; NON-ATOMIC (can be interrupted between read and write)
inc dwCounter

; ATOMIC (guaranteed to complete fully)
lock inc dwCounter
```

### Interlocked Functions

Windows provides helper functions:

```asm
; Atomic increment
push OFFSET dwCounter
call InterlockedIncrement
; EAX = new value

; Atomic decrement
push OFFSET dwCounter
call InterlockedDecrement
; EAX = new value

; Atomic exchange
push newValue
push OFFSET dwValue
call InterlockedExchange
; EAX = old value

; Atomic compare-and-swap
push newValue
push expectedValue
push OFFSET dwValue
call InterlockedCompareExchange
; EAX = original value (compare with expectedValue to see if swap happened)
```

### Atomic Operations in Hooks

```asm
;-------------------------------------------------------------------------------
; AtomicCounterHook - Uses atomic increment
;-------------------------------------------------------------------------------
AtomicCounterHook PROC
    pushad
    pushfd
    
    ; Atomic increment - no lock needed!
    push OFFSET dwCallCount
    call InterlockedIncrement
    ; EAX = new count
    
    popfd
    popad
    jmp pTrampoline
AtomicCounterHook ENDP
```

---

## 📚 Part 4: When to Use What

### Decision Guide

| Scenario | Recommended Approach |
|----------|---------------------|
| Simple counter | `lock inc` or `InterlockedIncrement` |
| Multiple related updates | Critical Section |
| Read-only access | No synchronization needed |
| Complex data structures | Critical Section |
| One-time flag set | `InterlockedExchange` |

### Example: Complex State Update

```asm
; Multiple related values - need Critical Section
.data
    g_Stats STRUCT
        dwCalls     dd 0
        dwSuccess   dd 0
        dwFailure   dd 0
        dwLastTime  dd 0
    g_Stats ENDS
    
    g_HookStats g_Stats <>
    g_StatLock CRITICAL_SECTION <>

.code
UpdateStats PROC bSuccess:BYTE
    ; Enter critical section
    lea eax, g_StatLock
    push eax
    call EnterCriticalSection
    
    ; Update all stats atomically (as a group)
    inc g_HookStats.dwCalls
    
    cmp bSuccess, 0
    je @failure
    inc g_HookStats.dwSuccess
    jmp @done
@failure:
    inc g_HookStats.dwFailure
@done:
    
    call GetTickCount
    mov g_HookStats.dwLastTime, eax
    
    ; Leave critical section
    lea eax, g_StatLock
    push eax
    call LeaveCriticalSection
    ret
UpdateStats ENDP
```

---

## 📚 Part 5: Avoiding Deadlocks

### What is a Deadlock?

A **deadlock** occurs when two or more threads wait for each other forever.

```
Thread 1: Holds Lock A, waiting for Lock B
Thread 2: Holds Lock B, waiting for Lock A
→ Neither can proceed!
```

### Deadlock Prevention Rules

1. **Always acquire locks in the same order**
2. **Don't hold locks while calling unknown code**
3. **Use timeouts where possible**
4. **Keep critical sections small**

### Dangerous Pattern

```asm
; DANGEROUS: Calling external code while holding lock
EnterCriticalSection
    ; ... our code ...
    call SomeExternalFunction   ; ← This might try to acquire our lock!
    ; ... more code ...
LeaveCriticalSection
```

### Safe Pattern

```asm
; SAFE: Release lock before external calls
EnterCriticalSection
    ; ... our code ...
    mov savedData, eax          ; Save what we need
LeaveCriticalSection

call SomeExternalFunction       ; External call outside lock

EnterCriticalSection
    ; ... more code with savedData ...
LeaveCriticalSection
```

---

## 📚 Part 6: Thread-Safe Hook Template

### Complete Thread-Safe Hook

```asm
;===============================================================================
; thread_safe_hook.asm
; Complete thread-safe hook implementation
;===============================================================================

.686
.model flat, stdcall
option casemap:none

include \masm32\include\windows.inc
include \masm32\include\kernel32.inc
include \masm32\include\user32.inc
includelib \masm32\lib\kernel32.lib
includelib \masm32\lib\user32.lib

.data
    ; Synchronization
    g_HookLock CRITICAL_SECTION <>
    g_bLockInitialized dd 0
    
    ; Thread-safe statistics
    g_dwTotalCalls dd 0
    g_dwCurrentActive dd 0
    g_dwMaxActive dd 0
    g_dwLastThreadId dd 0
    
    ; Trampoline
    pTrampoline dd 0

.code

;-------------------------------------------------------------------------------
; InitializeHookSync - Initialize synchronization
;-------------------------------------------------------------------------------
InitializeHookSync PROC
    cmp g_bLockInitialized, 1
    je @alreadyInit
    
    lea eax, g_HookLock
    push eax
    call InitializeCriticalSection
    
    mov g_bLockInitialized, 1
    
@alreadyInit:
    ret
InitializeHookSync ENDP

;-------------------------------------------------------------------------------
; CleanupHookSync - Cleanup synchronization
;-------------------------------------------------------------------------------
CleanupHookSync PROC
    cmp g_bLockInitialized, 0
    je @notInit
    
    lea eax, g_HookLock
    push eax
    call DeleteCriticalSection
    
    mov g_bLockInitialized, 0
    
@notInit:
    ret
CleanupHookSync ENDP

;-------------------------------------------------------------------------------
; ThreadSafeMessageBoxHook - Thread-safe hook handler
;-------------------------------------------------------------------------------
ThreadSafeMessageBoxHook PROC
    pushad
    pushfd
    
    ;═══════════════════════════════════════════════════════════════
    ; Enter Critical Section
    ;═══════════════════════════════════════════════════════════════
    lea eax, g_HookLock
    push eax
    call EnterCriticalSection
    
    ;═══════════════════════════════════════════════════════════════
    ; PROTECTED CODE START
    ;═══════════════════════════════════════════════════════════════
    
    ; Increment total calls
    inc g_dwTotalCalls
    
    ; Track active calls
    inc g_dwCurrentActive
    mov eax, g_dwCurrentActive
    cmp eax, g_dwMaxActive
    jle @notMax
    mov g_dwMaxActive, eax
@notMax:
    
    ; Get thread ID
    call GetCurrentThreadId
    mov g_dwLastThreadId, eax
    
    ;═══════════════════════════════════════════════════════════════
    ; PROTECTED CODE END
    ;═══════════════════════════════════════════════════════════════
    
    lea eax, g_HookLock
    push eax
    call LeaveCriticalSection
    
    ;═══════════════════════════════════════════════════════════════
    ; Call Original Function (outside lock!)
    ;═══════════════════════════════════════════════════════════════
    popfd
    popad
    
    ; Must call original and then decrement active count
    ; Use a wrapper approach
    
    call CallOriginalAndTrack
    ret                         ; Return EAX from original
    
ThreadSafeMessageBoxHook ENDP

;-------------------------------------------------------------------------------
; CallOriginalAndTrack - Calls original and updates active count
;-------------------------------------------------------------------------------
CallOriginalAndTrack PROC
    ; Get parameters from our stack (we were called, so params are offset)
    ; This is tricky - need to restructure for real use
    
    ; For now, simplified:
    call pTrampoline            ; Call original
    push eax                    ; Save return value
    
    ; Decrement active count
    lea eax, g_HookLock
    push eax
    call EnterCriticalSection
    
    dec g_dwCurrentActive
    
    lea eax, g_HookLock
    push eax
    call LeaveCriticalSection
    
    pop eax                     ; Restore return value
    ret
CallOriginalAndTrack ENDP

;-------------------------------------------------------------------------------
; GetHookStats - Thread-safe stat retrieval
;-------------------------------------------------------------------------------
GetHookStats PROC pTotal:DWORD, pMax:DWORD, pCurrent:DWORD
    lea eax, g_HookLock
    push eax
    call EnterCriticalSection
    
    mov eax, pTotal
    mov ebx, g_dwTotalCalls
    mov [eax], ebx
    
    mov eax, pMax
    mov ebx, g_dwMaxActive
    mov [eax], ebx
    
    mov eax, pCurrent
    mov ebx, g_dwCurrentActive
    mov [eax], ebx
    
    lea eax, g_HookLock
    push eax
    call LeaveCriticalSection
    
    ret
GetHookStats ENDP

END
```

---

## 💻 Part 7: Testing Thread Safety

### Multi-Thread Test Program

```asm
; Thread function that calls MessageBox repeatedly
ThreadFunc PROC lpParam:DWORD
    mov ecx, 10                 ; Call 10 times
    
@loop:
    push ecx
    
    push MB_OK
    push OFFSET szCaption
    push OFFSET szText
    push NULL
    call MessageBoxA
    
    pop ecx
    loop @loop
    
    ret
ThreadFunc ENDP

; Create multiple threads
TestMultiThread PROC
    ; Create 5 threads
    mov ecx, 5
    
@createLoop:
    push ecx
    
    push NULL
    push 0
    push NULL
    push OFFSET ThreadFunc
    push 0
    push NULL
    call CreateThread
    
    pop ecx
    loop @createLoop
    
    ; Wait for completion...
    ret
TestMultiThread ENDP
```

---

## 📝 Part 8: Tasks

### Task 1: Race Condition Demo (25 minutes)
Create a hook WITHOUT synchronization and demonstrate:
1. Run with multiple threads
2. Show counter is incorrect
3. Then add synchronization and show it works

### Task 2: Atomic Counter (20 minutes)
Implement a hook using only `InterlockedIncrement`:
1. No Critical Section
2. Just atomic operations
3. Verify correctness under load

### Task 3: Deadlock Scenario (30 minutes)
Create code that WOULD deadlock:
1. Two locks acquired in different orders
2. Document why it deadlocks
3. Show the fix

### Task 4: Performance Comparison (35 minutes)
Compare performance of:
1. No synchronization (baseline)
2. Critical Section
3. Interlocked functions
Measure time for 100,000 hook calls.

---

## ✅ Session Checklist

Before moving to Session 13, make sure you can:

- [ ] Explain why hooks need thread safety
- [ ] Use Critical Sections correctly
- [ ] Use `lock` prefix and Interlocked functions
- [ ] Avoid common deadlock patterns
- [ ] Choose appropriate synchronization method
- [ ] Test hooks with multiple threads

---

## 🔜 Next Session

In **Session 13: File Operation Hooks**, we'll learn:
- Hook CreateFileA/W
- Hook ReadFile and WriteFile
- Monitor all file access
- Build a file activity logger

[Continue to Session 13 →](session_13.md)

---

## 📖 Additional Resources

- [Critical Section Objects](https://docs.microsoft.com/en-us/windows/win32/sync/critical-section-objects)
- [Interlocked Functions](https://docs.microsoft.com/en-us/windows/win32/sync/interlocked-variable-access)
- [Synchronization Best Practices](https://docs.microsoft.com/en-us/windows/win32/sync/synchronization)
