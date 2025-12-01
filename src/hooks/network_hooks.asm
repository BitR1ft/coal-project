;===============================================================================
; STEALTH INTERCEPTOR - Network Hooks
;===============================================================================
; File:        network_hooks.asm
; Description: Hook implementations for network/socket APIs
; Authors:     Muhammad Adeel Haider (241541), Umar Farooq (241575)
; Course:      COAL - 5th Semester, BS Cyber Security
; Date:        November 2024
;===============================================================================

.686
.model flat, stdcall
option casemap:none

;===============================================================================
; Include Files
;===============================================================================
include \masm32\include\windows.inc
include \masm32\include\kernel32.inc
includelib \masm32\lib\kernel32.lib

;===============================================================================
; WinSock2 Constants (from ws2_32.dll)
;===============================================================================
AF_INET         EQU 2
SOCK_STREAM     EQU 1
SOCK_DGRAM      EQU 2
IPPROTO_TCP     EQU 6
IPPROTO_UDP     EQU 17

;===============================================================================
; Network Connection Log Structure
;===============================================================================
NET_CONNECTION_LOG STRUCT
    dwSocketHandle   DWORD ?
    dwAddressFamily  DWORD ?
    dwSocketType     DWORD ?
    dwProtocol       DWORD ?
    dwRemoteIP       DWORD ?
    dwRemotePort     WORD ?
    wPadding         WORD ?
    dwLocalPort      WORD ?
    wPadding2        WORD ?
    dwTimestamp      DWORD ?
    dwOperation      DWORD ?     ; 1=socket, 2=connect, 3=send, 4=recv
NET_CONNECTION_LOG ENDS

;===============================================================================
; Data Section
;===============================================================================
.data
    ; WS2_32.dll name
    szWs2_32             BYTE "ws2_32.dll", 0
    
    ; Function names
    szSocket             BYTE "socket", 0
    szConnect            BYTE "connect", 0
    szSend               BYTE "send", 0
    szRecv               BYTE "recv", 0
    szSendTo             BYTE "sendto", 0
    szRecvFrom           BYTE "recvfrom", 0
    szClosesocket        BYTE "closesocket", 0
    szBind               BYTE "bind", 0
    szListen             BYTE "listen", 0
    szAccept             BYTE "accept", 0
    
    ; Log messages
    szSocketLog          BYTE "[NetHook] socket() - AF: ", 0
    szConnectLog         BYTE "[NetHook] connect() - Socket: ", 0
    szSendLog            BYTE "[NetHook] send() - ", 0
    szRecvLog            BYTE "[NetHook] recv() - ", 0
    szBytesPrefix        BYTE " bytes", 0
    szIPPrefix           BYTE " IP: ", 0
    szPortPrefix         BYTE " Port: ", 0
    szHookInstalled      BYTE "[NetHook] Network hooks installed", 0
    szHookRemoved        BYTE "[NetHook] Network hooks removed", 0
    szHookFailed         BYTE "[NetHook] Failed to install network hooks", 0
    
    ; Protocol descriptions
    szTCP                BYTE "TCP", 0
    szUDP                BYTE "UDP", 0
    szUnknown            BYTE "Unknown", 0
    
    ; Hook state
    g_hWs2_32            DWORD 0
    g_pOrigSocket        DWORD 0
    g_pOrigConnect       DWORD 0
    g_pOrigSend          DWORD 0
    g_pOrigRecv          DWORD 0
    
    ; Trampolines
    g_pTrampolineSocket  DWORD 0
    g_pTrampolineConnect DWORD 0
    g_pTrampolineSend    DWORD 0
    g_pTrampolineRecv    DWORD 0
    
    g_bNetHooksEnabled   DWORD 0
    
    ; Statistics
    g_dwSocketCount      DWORD 0
    g_dwConnectCount     DWORD 0
    g_dwSendCount        DWORD 0
    g_dwRecvCount        DWORD 0
    g_dwBytesSent        DWORD 0
    g_dwBytesRecv        DWORD 0

.data?
    g_dwOldProtect       DWORD ?
    g_LogBuffer          BYTE 512 DUP(?)
    g_NetConnLog         NET_CONNECTION_LOG 100 DUP(?)
    g_dwLogIndex         DWORD ?

;===============================================================================
; Code Section
;===============================================================================
.code

;-------------------------------------------------------------------------------
; DwordToHexString
;-------------------------------------------------------------------------------
; Description: Converts a DWORD to hexadecimal string
; Parameters:
;   EAX = Value to convert
;   EDI = Destination buffer
; Returns:     Nothing (modifies EDI)
;-------------------------------------------------------------------------------
DwordToHexString PROC
    push ebx
    push ecx
    push edx
    
    mov ecx, 8                  ; 8 hex digits
    add edi, 7                  ; Start from end
    
@ConvertLoop:
    mov ebx, eax
    and ebx, 0Fh               ; Get low nibble
    cmp bl, 9
    jbe @IsDigit
    add bl, 'A' - 10
    jmp @StoreChar
@IsDigit:
    add bl, '0'
@StoreChar:
    mov [edi], bl
    dec edi
    shr eax, 4
    loop @ConvertLoop
    
    add edi, 9                  ; Move past the 8 characters + 1
    
    pop edx
    pop ecx
    pop ebx
    ret
DwordToHexString ENDP

;-------------------------------------------------------------------------------
; DwordToDecString
;-------------------------------------------------------------------------------
; Description: Converts a DWORD to decimal string
; Parameters:
;   EAX = Value to convert
;   EDI = Destination buffer
; Returns:     EDI = Points past the last character
;-------------------------------------------------------------------------------
DwordToDecString PROC
    push ebx
    push ecx
    push edx
    push esi
    
    mov esi, edi                ; Save start position
    xor ecx, ecx                ; Digit count
    mov ebx, 10
    
    ; Handle zero case
    test eax, eax
    jnz @ConvertLoop
    mov BYTE PTR [edi], '0'
    inc edi
    jmp @Done
    
@ConvertLoop:
    test eax, eax
    jz @ReverseStart
    xor edx, edx
    div ebx                     ; EAX = quotient, EDX = remainder
    add dl, '0'
    push edx                    ; Save digit on stack
    inc ecx
    jmp @ConvertLoop
    
@ReverseStart:
    ; Pop digits in reverse order
@PopLoop:
    test ecx, ecx
    jz @Done
    pop edx
    mov [edi], dl
    inc edi
    dec ecx
    jmp @PopLoop

@Done:
    pop esi
    pop edx
    pop ecx
    pop ebx
    ret
DwordToDecString ENDP

;-------------------------------------------------------------------------------
; SocketHookHandler
;-------------------------------------------------------------------------------
; Description: Hook handler for socket()
; Parameters:
;   [ebp+8]  = af (address family)
;   [ebp+12] = type (socket type)
;   [ebp+16] = protocol
; Returns:     SOCKET
;-------------------------------------------------------------------------------
SocketHookHandler PROC
    push ebp
    mov ebp, esp
    
    pushad
    pushfd
    
    ; Increment counter
    inc g_dwSocketCount
    
    ; Build log message
    lea edi, g_LogBuffer
    lea esi, szSocketLog
@CopyPrefix:
    lodsb
    test al, al
    jz @PrefixDone
    stosb
    jmp @CopyPrefix
@PrefixDone:
    
    ; Add address family
    mov eax, [ebp+8]
    call DwordToDecString
    
    ; Add separator
    mov al, ' '
    stosb
    mov al, 'T'
    stosb
    mov al, 'y'
    stosb
    mov al, 'p'
    stosb
    mov al, 'e'
    stosb
    mov al, ':'
    stosb
    mov al, ' '
    stosb
    
    ; Add socket type
    mov eax, [ebp+12]
    call DwordToDecString
    
    ; Add separator
    mov al, ' '
    stosb
    mov al, 'P'
    stosb
    mov al, 'r'
    stosb
    mov al, 'o'
    stosb
    mov al, 't'
    stosb
    mov al, 'o'
    stosb
    mov al, ':'
    stosb
    mov al, ' '
    stosb
    
    ; Add protocol
    mov eax, [ebp+16]
    call DwordToDecString
    
    ; Null terminate
    xor al, al
    stosb
    
    ; Output log
    lea eax, g_LogBuffer
    push eax
    call OutputDebugStringA
    
    popfd
    popad
    
    ; Call original function
    push [ebp+16]               ; protocol
    push [ebp+12]               ; type
    push [ebp+8]                ; af
    call g_pTrampolineSocket
    
    mov esp, ebp
    pop ebp
    ret 12
SocketHookHandler ENDP

;-------------------------------------------------------------------------------
; ConnectHookHandler
;-------------------------------------------------------------------------------
; Description: Hook handler for connect()
; Parameters:
;   [ebp+8]  = s (socket)
;   [ebp+12] = name (sockaddr pointer)
;   [ebp+16] = namelen
; Returns:     int
;-------------------------------------------------------------------------------
ConnectHookHandler PROC
    push ebp
    mov ebp, esp
    
    pushad
    pushfd
    
    ; Increment counter
    inc g_dwConnectCount
    
    ; Build log message
    lea edi, g_LogBuffer
    lea esi, szConnectLog
@CopyPrefix:
    lodsb
    test al, al
    jz @PrefixDone
    stosb
    jmp @CopyPrefix
@PrefixDone:
    
    ; Add socket handle
    mov eax, [ebp+8]
    call DwordToHexString
    
    ; Null terminate
    xor al, al
    stosb
    
    ; Output log
    lea eax, g_LogBuffer
    push eax
    call OutputDebugStringA
    
    popfd
    popad
    
    ; Call original function
    push [ebp+16]
    push [ebp+12]
    push [ebp+8]
    call g_pTrampolineConnect
    
    mov esp, ebp
    pop ebp
    ret 12
ConnectHookHandler ENDP

;-------------------------------------------------------------------------------
; SendHookHandler
;-------------------------------------------------------------------------------
; Description: Hook handler for send()
; Parameters:
;   [ebp+8]  = s (socket)
;   [ebp+12] = buf (data buffer)
;   [ebp+16] = len (data length)
;   [ebp+20] = flags
; Returns:     int (bytes sent)
;-------------------------------------------------------------------------------
SendHookHandler PROC
    push ebp
    mov ebp, esp
    
    pushad
    pushfd
    
    ; Increment counter
    inc g_dwSendCount
    
    ; Add to bytes sent
    mov eax, [ebp+16]
    add g_dwBytesSent, eax
    
    ; Build log message
    lea edi, g_LogBuffer
    lea esi, szSendLog
@CopyPrefix:
    lodsb
    test al, al
    jz @PrefixDone
    stosb
    jmp @CopyPrefix
@PrefixDone:
    
    ; Add byte count
    mov eax, [ebp+16]
    call DwordToDecString
    
    ; Add " bytes"
    lea esi, szBytesPrefix
@CopyBytes:
    lodsb
    test al, al
    jz @BytesDone
    stosb
    jmp @CopyBytes
@BytesDone:
    
    ; Null terminate
    xor al, al
    stosb
    
    ; Output log
    lea eax, g_LogBuffer
    push eax
    call OutputDebugStringA
    
    popfd
    popad
    
    ; Call original function
    push [ebp+20]
    push [ebp+16]
    push [ebp+12]
    push [ebp+8]
    call g_pTrampolineSend
    
    mov esp, ebp
    pop ebp
    ret 16
SendHookHandler ENDP

;-------------------------------------------------------------------------------
; RecvHookHandler
;-------------------------------------------------------------------------------
; Description: Hook handler for recv()
; Parameters:
;   [ebp+8]  = s (socket)
;   [ebp+12] = buf (receive buffer)
;   [ebp+16] = len (buffer length)
;   [ebp+20] = flags
; Returns:     int (bytes received)
;-------------------------------------------------------------------------------
RecvHookHandler PROC
    push ebp
    mov ebp, esp
    LOCAL dwBytesReceived:DWORD
    
    ; Call original function first to get result
    push [ebp+20]
    push [ebp+16]
    push [ebp+12]
    push [ebp+8]
    call g_pTrampolineRecv
    mov dwBytesReceived, eax
    
    pushad
    pushfd
    
    ; Increment counter
    inc g_dwRecvCount
    
    ; Add to bytes received (only if positive)
    cmp dwBytesReceived, 0
    jle @SkipAdd
    mov eax, dwBytesReceived
    add g_dwBytesRecv, eax
@SkipAdd:
    
    ; Build log message
    lea edi, g_LogBuffer
    lea esi, szRecvLog
@CopyPrefix:
    lodsb
    test al, al
    jz @PrefixDone
    stosb
    jmp @CopyPrefix
@PrefixDone:
    
    ; Add byte count received
    mov eax, dwBytesReceived
    call DwordToDecString
    
    ; Add " bytes"
    lea esi, szBytesPrefix
@CopyBytes:
    lodsb
    test al, al
    jz @BytesDone
    stosb
    jmp @CopyBytes
@BytesDone:
    
    ; Null terminate
    xor al, al
    stosb
    
    ; Output log
    lea eax, g_LogBuffer
    push eax
    call OutputDebugStringA
    
    popfd
    popad
    
    mov eax, dwBytesReceived
    mov esp, ebp
    pop ebp
    ret 16
RecvHookHandler ENDP

;-------------------------------------------------------------------------------
; InstallNetworkHooks
;-------------------------------------------------------------------------------
; Description: Installs hooks on network functions
; Parameters:  None
; Returns:     EAX = 1 on success, 0 on failure
;-------------------------------------------------------------------------------
InstallNetworkHooks PROC EXPORT
    LOCAL pFunc:DWORD
    
    pushad
    
    ; Check if already installed
    cmp g_bNetHooksEnabled, 1
    je @AlreadyInstalled
    
    ; Load ws2_32.dll
    push OFFSET szWs2_32
    call LoadLibraryA
    test eax, eax
    jz @Failed
    mov g_hWs2_32, eax
    
    ;---------------------------------------------------
    ; Hook socket()
    ;---------------------------------------------------
    push OFFSET szSocket
    push g_hWs2_32
    call GetProcAddress
    test eax, eax
    jz @SkipSocket
    mov g_pOrigSocket, eax
    mov pFunc, eax
    
    push OFFSET g_dwOldProtect
    push PAGE_EXECUTE_READWRITE
    push 5
    push pFunc
    call VirtualProtect
    test eax, eax
    jz @SkipSocket
    
    push PAGE_EXECUTE_READWRITE
    push MEM_COMMIT or MEM_RESERVE
    push 32
    push NULL
    call VirtualAlloc
    test eax, eax
    jz @SkipSocket
    mov g_pTrampolineSocket, eax
    
    mov edi, eax
    mov esi, pFunc
    movsb
    movsb
    movsb
    movsb
    movsb
    
    mov BYTE PTR [edi], 0E9h
    mov eax, pFunc
    add eax, 5
    sub eax, edi
    sub eax, 5
    mov [edi+1], eax
    
    mov edi, pFunc
    mov BYTE PTR [edi], 0E9h
    mov eax, OFFSET SocketHookHandler
    sub eax, edi
    sub eax, 5
    mov [edi+1], eax

@SkipSocket:
    ;---------------------------------------------------
    ; Hook connect()
    ;---------------------------------------------------
    push OFFSET szConnect
    push g_hWs2_32
    call GetProcAddress
    test eax, eax
    jz @SkipConnect
    mov g_pOrigConnect, eax
    mov pFunc, eax
    
    push OFFSET g_dwOldProtect
    push PAGE_EXECUTE_READWRITE
    push 5
    push pFunc
    call VirtualProtect
    test eax, eax
    jz @SkipConnect
    
    push PAGE_EXECUTE_READWRITE
    push MEM_COMMIT or MEM_RESERVE
    push 32
    push NULL
    call VirtualAlloc
    test eax, eax
    jz @SkipConnect
    mov g_pTrampolineConnect, eax
    
    mov edi, eax
    mov esi, pFunc
    movsb
    movsb
    movsb
    movsb
    movsb
    
    mov BYTE PTR [edi], 0E9h
    mov eax, pFunc
    add eax, 5
    sub eax, edi
    sub eax, 5
    mov [edi+1], eax
    
    mov edi, pFunc
    mov BYTE PTR [edi], 0E9h
    mov eax, OFFSET ConnectHookHandler
    sub eax, edi
    sub eax, 5
    mov [edi+1], eax

@SkipConnect:
    ;---------------------------------------------------
    ; Hook send()
    ;---------------------------------------------------
    push OFFSET szSend
    push g_hWs2_32
    call GetProcAddress
    test eax, eax
    jz @SkipSend
    mov g_pOrigSend, eax
    mov pFunc, eax
    
    push OFFSET g_dwOldProtect
    push PAGE_EXECUTE_READWRITE
    push 5
    push pFunc
    call VirtualProtect
    test eax, eax
    jz @SkipSend
    
    push PAGE_EXECUTE_READWRITE
    push MEM_COMMIT or MEM_RESERVE
    push 32
    push NULL
    call VirtualAlloc
    test eax, eax
    jz @SkipSend
    mov g_pTrampolineSend, eax
    
    mov edi, eax
    mov esi, pFunc
    movsb
    movsb
    movsb
    movsb
    movsb
    
    mov BYTE PTR [edi], 0E9h
    mov eax, pFunc
    add eax, 5
    sub eax, edi
    sub eax, 5
    mov [edi+1], eax
    
    mov edi, pFunc
    mov BYTE PTR [edi], 0E9h
    mov eax, OFFSET SendHookHandler
    sub eax, edi
    sub eax, 5
    mov [edi+1], eax

@SkipSend:
    ;---------------------------------------------------
    ; Hook recv()
    ;---------------------------------------------------
    push OFFSET szRecv
    push g_hWs2_32
    call GetProcAddress
    test eax, eax
    jz @SkipRecv
    mov g_pOrigRecv, eax
    mov pFunc, eax
    
    push OFFSET g_dwOldProtect
    push PAGE_EXECUTE_READWRITE
    push 5
    push pFunc
    call VirtualProtect
    test eax, eax
    jz @SkipRecv
    
    push PAGE_EXECUTE_READWRITE
    push MEM_COMMIT or MEM_RESERVE
    push 32
    push NULL
    call VirtualAlloc
    test eax, eax
    jz @SkipRecv
    mov g_pTrampolineRecv, eax
    
    mov edi, eax
    mov esi, pFunc
    movsb
    movsb
    movsb
    movsb
    movsb
    
    mov BYTE PTR [edi], 0E9h
    mov eax, pFunc
    add eax, 5
    sub eax, edi
    sub eax, 5
    mov [edi+1], eax
    
    mov edi, pFunc
    mov BYTE PTR [edi], 0E9h
    mov eax, OFFSET RecvHookHandler
    sub eax, edi
    sub eax, 5
    mov [edi+1], eax

@SkipRecv:
    ; Flush instruction cache
    push 0
    push 0
    push -1
    call FlushInstructionCache
    
    ; Mark as enabled
    mov g_bNetHooksEnabled, 1
    
    ; Log success
    push OFFSET szHookInstalled
    call OutputDebugStringA
    
@AlreadyInstalled:
    popad
    mov eax, 1
    ret

@Failed:
    push OFFSET szHookFailed
    call OutputDebugStringA
    popad
    xor eax, eax
    ret
InstallNetworkHooks ENDP

;-------------------------------------------------------------------------------
; RemoveNetworkHooks
;-------------------------------------------------------------------------------
; Description: Removes all network hooks
; Parameters:  None
; Returns:     EAX = 1 on success
;-------------------------------------------------------------------------------
RemoveNetworkHooks PROC EXPORT
    pushad
    
    cmp g_bNetHooksEnabled, 0
    je @NotInstalled
    
    ; Restore each function and free trampolines
    ; socket()
    cmp g_pTrampolineSocket, 0
    je @Skip1
    push OFFSET g_dwOldProtect
    push PAGE_EXECUTE_READWRITE
    push 5
    push g_pOrigSocket
    call VirtualProtect
    mov edi, g_pOrigSocket
    mov esi, g_pTrampolineSocket
    movsb
    movsb
    movsb
    movsb
    movsb
    push MEM_RELEASE
    push 0
    push g_pTrampolineSocket
    call VirtualFree
    mov g_pTrampolineSocket, 0
@Skip1:
    
    ; connect()
    cmp g_pTrampolineConnect, 0
    je @Skip2
    push OFFSET g_dwOldProtect
    push PAGE_EXECUTE_READWRITE
    push 5
    push g_pOrigConnect
    call VirtualProtect
    mov edi, g_pOrigConnect
    mov esi, g_pTrampolineConnect
    movsb
    movsb
    movsb
    movsb
    movsb
    push MEM_RELEASE
    push 0
    push g_pTrampolineConnect
    call VirtualFree
    mov g_pTrampolineConnect, 0
@Skip2:
    
    ; send()
    cmp g_pTrampolineSend, 0
    je @Skip3
    push OFFSET g_dwOldProtect
    push PAGE_EXECUTE_READWRITE
    push 5
    push g_pOrigSend
    call VirtualProtect
    mov edi, g_pOrigSend
    mov esi, g_pTrampolineSend
    movsb
    movsb
    movsb
    movsb
    movsb
    push MEM_RELEASE
    push 0
    push g_pTrampolineSend
    call VirtualFree
    mov g_pTrampolineSend, 0
@Skip3:
    
    ; recv()
    cmp g_pTrampolineRecv, 0
    je @Skip4
    push OFFSET g_dwOldProtect
    push PAGE_EXECUTE_READWRITE
    push 5
    push g_pOrigRecv
    call VirtualProtect
    mov edi, g_pOrigRecv
    mov esi, g_pTrampolineRecv
    movsb
    movsb
    movsb
    movsb
    movsb
    push MEM_RELEASE
    push 0
    push g_pTrampolineRecv
    call VirtualFree
    mov g_pTrampolineRecv, 0
@Skip4:
    
    ; Flush instruction cache
    push 0
    push 0
    push -1
    call FlushInstructionCache
    
    mov g_bNetHooksEnabled, 0
    
    push OFFSET szHookRemoved
    call OutputDebugStringA

@NotInstalled:
    popad
    mov eax, 1
    ret
RemoveNetworkHooks ENDP

;-------------------------------------------------------------------------------
; GetNetworkHookStats
;-------------------------------------------------------------------------------
; Description: Gets network hook statistics
; Parameters:
;   [ebp+8]  = pSocketCount
;   [ebp+12] = pConnectCount
;   [ebp+16] = pBytesSent
;   [ebp+20] = pBytesRecv
; Returns:     EAX = 1 if hooks enabled
;-------------------------------------------------------------------------------
GetNetworkHookStats PROC EXPORT pSocketCount:DWORD, pConnectCount:DWORD, pBytesSent:DWORD, pBytesRecv:DWORD
    mov eax, pSocketCount
    test eax, eax
    jz @Skip1
    mov ecx, g_dwSocketCount
    mov [eax], ecx
@Skip1:
    mov eax, pConnectCount
    test eax, eax
    jz @Skip2
    mov ecx, g_dwConnectCount
    mov [eax], ecx
@Skip2:
    mov eax, pBytesSent
    test eax, eax
    jz @Skip3
    mov ecx, g_dwBytesSent
    mov [eax], ecx
@Skip3:
    mov eax, pBytesRecv
    test eax, eax
    jz @Skip4
    mov ecx, g_dwBytesRecv
    mov [eax], ecx
@Skip4:
    mov eax, g_bNetHooksEnabled
    ret
GetNetworkHookStats ENDP

END
