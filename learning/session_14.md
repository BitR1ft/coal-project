# Session 14: Network API Hooks

## 🎯 Learning Objectives

By the end of this session, you will:
- Hook Windows socket APIs
- Monitor network connections
- Track data sent and received
- Build a network activity monitor

---

## 📚 Part 1: Network APIs Overview

### Key Network APIs to Hook

| API | Purpose | DLL |
|-----|---------|-----|
| socket | Create a socket | ws2_32.dll |
| connect | Connect to server | ws2_32.dll |
| send/recv | Send/receive data | ws2_32.dll |
| sendto/recvfrom | UDP send/receive | ws2_32.dll |
| closesocket | Close socket | ws2_32.dll |
| WSAConnect | Extended connect | ws2_32.dll |
| WSASend/WSARecv | Async send/receive | ws2_32.dll |

### Socket Function Signatures

```c
SOCKET socket(
    int af,             // Address family (AF_INET, AF_INET6)
    int type,           // Socket type (SOCK_STREAM, SOCK_DGRAM)
    int protocol        // Protocol (IPPROTO_TCP, IPPROTO_UDP)
);

int connect(
    SOCKET s,                       // Socket handle
    const struct sockaddr* name,    // Server address
    int namelen                     // Size of address
);

int send(
    SOCKET s,           // Socket handle
    const char* buf,    // Data buffer
    int len,            // Length of data
    int flags           // Flags (usually 0)
);

int recv(
    SOCKET s,           // Socket handle
    char* buf,          // Buffer for received data
    int len,            // Buffer size
    int flags           // Flags
);
```

### The sockaddr_in Structure

```c
struct sockaddr_in {
    short   sin_family;     // AF_INET
    u_short sin_port;       // Port number (network byte order)
    struct  in_addr sin_addr; // IP address
    char    sin_zero[8];    // Padding
};
```

---

## 📚 Part 2: Network Hook Implementation

```asm
;===============================================================================
; network_hooks.asm - Network operation hooks
;===============================================================================

.686
.model flat, stdcall
option casemap:none

include \masm32\include\windows.inc
include \masm32\include\kernel32.inc
include \masm32\include\ws2_32.inc
includelib \masm32\lib\kernel32.lib
includelib \masm32\lib\ws2_32.lib

; Address family
AF_INET     EQU 2
AF_INET6    EQU 23

; Socket types
SOCK_STREAM EQU 1
SOCK_DGRAM  EQU 2

.data
    ; DLL and function names
    szWs2_32        db "ws2_32.dll", 0
    szSocket        db "socket", 0
    szConnect       db "connect", 0
    szSend          db "send", 0
    szRecv          db "recv", 0
    
    ; Log format strings
    szLogSocket     db "[NET] socket(af=%d, type=%d, proto=%d)", 13, 10, 0
    szLogConnect    db "[NET] connect(sock=0x%08X, ip=%d.%d.%d.%d, port=%d)", 13, 10, 0
    szLogSend       db "[NET] send(sock=0x%08X, bytes=%d)", 13, 10, 0
    szLogRecv       db "[NET] recv(sock=0x%08X, bytes=%d)", 13, 10, 0
    szLogNewline    db 13, 10, 0
    
    ; Hook state
    hWs2_32         dd 0
    pOrigSocket     dd 0
    pOrigConnect    dd 0
    pOrigSend       dd 0
    pOrigRecv       dd 0
    
    pTrampolineSocket   dd 0
    pTrampolineConnect  dd 0
    pTrampolineSend     dd 0
    pTrampolineRecv     dd 0
    
    bOrigBytesSocket    db 16 dup(0)
    bOrigBytesConnect   db 16 dup(0)
    bOrigBytesSend      db 16 dup(0)
    bOrigBytesRecv      db 16 dup(0)
    
    dwOldProtect        dd 0
    
    ; Statistics
    dwSocketCount       dd 0
    dwConnectCount      dd 0
    dwSendCount         dd 0
    dwRecvCount         dd 0
    dwBytesSent         dd 0
    dwBytesReceived     dd 0
    
    ; Synchronization
    g_NetLock CRITICAL_SECTION <>

.code

;-------------------------------------------------------------------------------
; FormatIP - Convert IP address to string
;-------------------------------------------------------------------------------
FormatIP PROC pSockAddr:DWORD, pBuffer:DWORD
    pushad
    
    mov esi, pSockAddr
    add esi, 4                  ; Skip sin_family and sin_port to get to sin_addr
    
    mov edi, pBuffer
    
    ; Extract each octet
    movzx eax, byte ptr [esi]
    call WriteDecimal
    mov byte ptr [edi], '.'
    inc edi
    
    movzx eax, byte ptr [esi+1]
    call WriteDecimal
    mov byte ptr [edi], '.'
    inc edi
    
    movzx eax, byte ptr [esi+2]
    call WriteDecimal
    mov byte ptr [edi], '.'
    inc edi
    
    movzx eax, byte ptr [esi+3]
    call WriteDecimal
    
    mov byte ptr [edi], 0
    
    popad
    ret

WriteDecimal:
    ; Convert AL to decimal and write to EDI
    push eax
    push ebx
    push ecx
    
    mov ecx, 0
    mov ebx, 10
    
@divLoop:
    xor edx, edx
    div ebx
    push edx
    inc ecx
    test eax, eax
    jnz @divLoop
    
@writeLoop:
    pop eax
    add al, '0'
    mov [edi], al
    inc edi
    loop @writeLoop
    
    pop ecx
    pop ebx
    pop eax
    ret
FormatIP ENDP

;-------------------------------------------------------------------------------
; GetPort - Extract port from sockaddr (network byte order to host)
;-------------------------------------------------------------------------------
GetPort PROC pSockAddr:DWORD
    mov eax, pSockAddr
    movzx eax, word ptr [eax+2]     ; sin_port
    xchg al, ah                      ; Convert from network to host byte order
    ret
GetPort ENDP

;-------------------------------------------------------------------------------
; SocketHook - Hook handler for socket()
;-------------------------------------------------------------------------------
SocketHook PROC
    ; [ESP+4]  = af
    ; [ESP+8]  = type
    ; [ESP+12] = protocol
    
    push ebp
    mov ebp, esp
    push esi
    
    ;═══════════════════════════════════════════════════════════════
    ; Log before call
    ;═══════════════════════════════════════════════════════════════
    lea eax, g_NetLock
    push eax
    call EnterCriticalSection
    
    inc dwSocketCount
    
    ; Build log message
    push OFFSET szLogSocket
    call OutputDebugStringA
    
    lea eax, g_NetLock
    push eax
    call LeaveCriticalSection
    
    ;═══════════════════════════════════════════════════════════════
    ; Call original
    ;═══════════════════════════════════════════════════════════════
    push [ebp+16]               ; protocol
    push [ebp+12]               ; type
    push [ebp+8]                ; af
    call pTrampolineSocket
    mov esi, eax                ; Save socket handle
    
    mov eax, esi
    pop esi
    mov esp, ebp
    pop ebp
    ret 12
SocketHook ENDP

;-------------------------------------------------------------------------------
; ConnectHook - Hook handler for connect()
;-------------------------------------------------------------------------------
ConnectHook PROC
    ; [ESP+4]  = s (socket)
    ; [ESP+8]  = name (sockaddr*)
    ; [ESP+12] = namelen
    
    LOCAL szIPBuffer[32]:BYTE
    LOCAL dwPort:DWORD
    
    push ebp
    mov ebp, esp
    sub esp, 36
    push esi
    push edi
    
    ;═══════════════════════════════════════════════════════════════
    ; Extract connection details
    ;═══════════════════════════════════════════════════════════════
    lea eax, g_NetLock
    push eax
    call EnterCriticalSection
    
    inc dwConnectCount
    
    ; Get IP address
    mov eax, [ebp+12]           ; sockaddr*
    test eax, eax
    jz @noAddr
    
    ; Check if AF_INET
    movzx ebx, word ptr [eax]   ; sin_family
    cmp ebx, AF_INET
    jne @noAddr
    
    ; Format IP
    lea edi, szIPBuffer
    push edi
    push eax
    call FormatIP
    
    ; Get port
    push [ebp+12]
    call GetPort
    mov dwPort, eax
    
    ; Log connection
    push OFFSET szLogConnect
    call OutputDebugStringA
    
    lea eax, szIPBuffer
    push eax
    call OutputDebugStringA
    
@noAddr:
    push OFFSET szLogNewline
    call OutputDebugStringA
    
    lea eax, g_NetLock
    push eax
    call LeaveCriticalSection
    
    ;═══════════════════════════════════════════════════════════════
    ; Call original
    ;═══════════════════════════════════════════════════════════════
    push [ebp+16]               ; namelen
    push [ebp+12]               ; name
    push [ebp+8]                ; socket
    call pTrampolineConnect
    mov esi, eax
    
    mov eax, esi
    pop edi
    pop esi
    mov esp, ebp
    pop ebp
    ret 12
ConnectHook ENDP

;-------------------------------------------------------------------------------
; SendHook - Hook handler for send()
;-------------------------------------------------------------------------------
SendHook PROC
    ; [ESP+4]  = s
    ; [ESP+8]  = buf
    ; [ESP+12] = len
    ; [ESP+16] = flags
    
    push ebp
    mov ebp, esp
    push esi
    
    ;═══════════════════════════════════════════════════════════════
    ; Call original first
    ;═══════════════════════════════════════════════════════════════
    push [ebp+20]               ; flags
    push [ebp+16]               ; len
    push [ebp+12]               ; buf
    push [ebp+8]                ; socket
    call pTrampolineSend
    mov esi, eax                ; Save bytes sent
    
    ;═══════════════════════════════════════════════════════════════
    ; Log send
    ;═══════════════════════════════════════════════════════════════
    cmp esi, 0
    jle @sendFailed
    
    lea eax, g_NetLock
    push eax
    call EnterCriticalSection
    
    inc dwSendCount
    add dwBytesSent, esi
    
    push OFFSET szLogSend
    call OutputDebugStringA
    
    lea eax, g_NetLock
    push eax
    call LeaveCriticalSection
    
@sendFailed:
    mov eax, esi
    pop esi
    mov esp, ebp
    pop ebp
    ret 16
SendHook ENDP

;-------------------------------------------------------------------------------
; RecvHook - Hook handler for recv()
;-------------------------------------------------------------------------------
RecvHook PROC
    push ebp
    mov ebp, esp
    push esi
    
    ; Call original
    push [ebp+20]               ; flags
    push [ebp+16]               ; len
    push [ebp+12]               ; buf
    push [ebp+8]                ; socket
    call pTrampolineRecv
    mov esi, eax
    
    ; Log recv
    cmp esi, 0
    jle @recvFailed
    
    lea eax, g_NetLock
    push eax
    call EnterCriticalSection
    
    inc dwRecvCount
    add dwBytesReceived, esi
    
    push OFFSET szLogRecv
    call OutputDebugStringA
    
    lea eax, g_NetLock
    push eax
    call LeaveCriticalSection
    
@recvFailed:
    mov eax, esi
    pop esi
    mov esp, ebp
    pop ebp
    ret 16
RecvHook ENDP

;-------------------------------------------------------------------------------
; InstallNetworkHooks - Install all network hooks
;-------------------------------------------------------------------------------
InstallNetworkHooks PROC
    pushad
    
    ; Initialize lock
    lea eax, g_NetLock
    push eax
    call InitializeCriticalSection
    
    ; Load ws2_32.dll
    push OFFSET szWs2_32
    call LoadLibraryA
    test eax, eax
    jz @failed
    mov hWs2_32, eax
    
    ; Hook socket
    push OFFSET szSocket
    push hWs2_32
    call GetProcAddress
    mov pOrigSocket, eax
    
    ; (Build trampoline and install hook - similar to previous patterns)
    ; ... 
    
    popad
    mov eax, 1
    ret
    
@failed:
    popad
    xor eax, eax
    ret
InstallNetworkHooks ENDP

;-------------------------------------------------------------------------------
; GetNetworkStats - Get network statistics
;-------------------------------------------------------------------------------
GetNetworkStats PROC pSockets:DWORD, pConnects:DWORD, pSends:DWORD, pRecvs:DWORD, pBytesSent:DWORD, pBytesRecv:DWORD
    lea eax, g_NetLock
    push eax
    call EnterCriticalSection
    
    mov eax, pSockets
    mov ebx, dwSocketCount
    mov [eax], ebx
    
    mov eax, pConnects
    mov ebx, dwConnectCount
    mov [eax], ebx
    
    mov eax, pSends
    mov ebx, dwSendCount
    mov [eax], ebx
    
    mov eax, pRecvs
    mov ebx, dwRecvCount
    mov [eax], ebx
    
    mov eax, pBytesSent
    mov ebx, dwBytesSent
    mov [eax], ebx
    
    mov eax, pBytesRecv
    mov ebx, dwBytesReceived
    mov [eax], ebx
    
    lea eax, g_NetLock
    push eax
    call LeaveCriticalSection
    
    ret
GetNetworkStats ENDP

END
```

---

## 📚 Part 3: Practical Applications

### Application 1: Connection Logger

Log all outgoing connections with IP and port:

```
[NET] connect(sock=0x00000104, ip=142.250.80.100, port=443)
[NET] connect(sock=0x00000108, ip=52.23.101.50, port=80)
```

### Application 2: Data Inspector

View data being sent:

```asm
; In SendHook, examine the buffer
mov esi, [ebp+12]           ; buf
mov ecx, [ebp+16]           ; len
; Log first N bytes of data
```

### Application 3: Connection Blocker

```asm
; Block connections to specific IPs
ConnectHookWithFilter PROC
    mov eax, [ebp+12]           ; sockaddr*
    
    ; Check if IP matches blocked list
    ; ... compare sin_addr ...
    
    jne @allow
    
    ; Block: return SOCKET_ERROR
    mov eax, SOCKET_ERROR
    ret 12
    
@allow:
    jmp pTrampolineConnect
ConnectHookWithFilter ENDP
```

---

## 📝 Part 4: Tasks

### Task 1: DNS Hook (30 minutes)
Hook `gethostbyname` to:
1. Log all DNS lookups
2. Show hostname being resolved
3. Show resolved IP addresses

### Task 2: Port Filter (25 minutes)
Create a hook that:
1. Logs only connections to specific ports (e.g., 80, 443)
2. Blocks connections to suspicious ports
3. Shows warning for blocked attempts

### Task 3: Data Content Monitor (40 minutes)
Build a hook that:
1. Captures first 100 bytes of sent data
2. Logs it in hex dump format
3. Detects HTTP requests vs other protocols

### Task 4: Network Dashboard (45 minutes)
Create real-time display of:
1. Active connections
2. Bytes sent/received per second
3. Most contacted IP addresses

---

## ✅ Session Checklist

Before moving to Session 15, make sure you can:

- [ ] Hook socket(), connect(), send(), recv()
- [ ] Extract IP addresses from sockaddr structures
- [ ] Convert network byte order (port numbers)
- [ ] Track network statistics
- [ ] Log network activity safely

---

## 🔜 Next Session

In **Session 15: Process API Hooks**, we'll learn:
- Hook CreateProcess
- Monitor process creation
- Track command lines
- Build a process monitor

[Continue to Session 15 →](session_15.md)
