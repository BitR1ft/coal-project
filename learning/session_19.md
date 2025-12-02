# Session 19: Debugging Hooks with x64dbg

## 🎯 Learning Objectives
- Use x64dbg to debug hooks
- Set breakpoints in hooked code
- Analyze memory and registers
- Trace hook execution flow

---

## 📚 x64dbg Basics

### Opening a Program
1. File → Open
2. Select your executable
3. Run until main (F9)

### Key Shortcuts
| Key | Action |
|-----|--------|
| F2 | Set breakpoint |
| F7 | Step into |
| F8 | Step over |
| F9 | Run |
| Ctrl+G | Go to address |

---

## 📚 Debugging Your Hook

### Step 1: Find the Original Function
1. Ctrl+G → Enter function name (e.g., "MessageBoxA")
2. Note the address and bytes

### Step 2: Set Breakpoint on Hook
1. F2 on your hook handler address
2. Run the target program
3. Breakpoint hits when function is called

### Step 3: Verify Hook Installation
1. Check first bytes of target function
2. Should see `E9 XX XX XX XX` (JMP)
3. Calculate target address

### Step 4: Trace Through Trampoline
1. Step through stolen bytes
2. Verify JMP back to original

---

## 📝 Tasks

1. Debug a MessageBox hook
2. Verify register preservation
3. Check trampoline execution
4. Analyze return value handling

---

[Continue to Session 20 →](session_20.md)
