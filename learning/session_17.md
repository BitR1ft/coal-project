# Session 17: Logging and Statistics

## 🎯 Learning Objectives
- Build a comprehensive logging system
- Track detailed hook statistics
- Create reporting functions
- Implement file-based logging

---

## 📚 Key Concepts

### Logging Levels
```asm
LOG_DEBUG   EQU 0
LOG_INFO    EQU 1
LOG_WARNING EQU 2
LOG_ERROR   EQU 3
```

### Statistics Tracking
- Call counts per hook
- Timing information
- Success/failure rates
- Parameter patterns

### Implementation Example

```asm
LogMessage PROC dwLevel:DWORD, pMessage:DWORD
    pushad
    ; Add timestamp
    ; Add log level prefix
    ; Output to debug and/or file
    call OutputDebugStringA
    popad
    ret
LogMessage ENDP
```

---

## 📝 Tasks

1. Create a log file writer
2. Implement log rotation
3. Add timestamp formatting
4. Build statistics aggregation

---

[Continue to Session 18 →](session_18.md)
