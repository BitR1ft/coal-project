;===============================================================================
; STEALTH INTERCEPTOR - String Utilities
;===============================================================================
; File:        string_utils.asm
; Description: String manipulation utilities
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

;===============================================================================
; Code Section
;===============================================================================
.code

;-------------------------------------------------------------------------------
; StrLen
;-------------------------------------------------------------------------------
; Description: Calculates the length of a null-terminated string
; Parameters:
;   [ebp+8] = lpszString - Pointer to string
; Returns:     EAX = String length (not including null terminator)
;-------------------------------------------------------------------------------
StrLen PROC EXPORT lpszString:DWORD
    push edi
    push ecx
    
    mov edi, lpszString
    test edi, edi
    jz @NullString
    
    xor eax, eax
    mov ecx, -1
    repne scasb
    not ecx
    dec ecx
    mov eax, ecx
    
    pop ecx
    pop edi
    ret

@NullString:
    pop ecx
    pop edi
    xor eax, eax
    ret
StrLen ENDP

;-------------------------------------------------------------------------------
; StrCopy
;-------------------------------------------------------------------------------
; Description: Copies a string to a destination buffer
; Parameters:
;   [ebp+8]  = lpszDest - Destination buffer
;   [ebp+12] = lpszSrc - Source string
; Returns:     EAX = Pointer to destination
;-------------------------------------------------------------------------------
StrCopy PROC EXPORT lpszDest:DWORD, lpszSrc:DWORD
    push esi
    push edi
    
    mov edi, lpszDest
    mov esi, lpszSrc
    
    test edi, edi
    jz @Done
    test esi, esi
    jz @EmptyString
    
@CopyLoop:
    lodsb
    stosb
    test al, al
    jnz @CopyLoop
    jmp @Done

@EmptyString:
    mov BYTE PTR [edi], 0

@Done:
    mov eax, lpszDest
    pop edi
    pop esi
    ret
StrCopy ENDP

;-------------------------------------------------------------------------------
; StrNCopy
;-------------------------------------------------------------------------------
; Description: Copies at most n characters from source to destination
; Parameters:
;   [ebp+8]  = lpszDest - Destination buffer
;   [ebp+12] = lpszSrc - Source string
;   [ebp+16] = dwMaxLen - Maximum characters to copy
; Returns:     EAX = Pointer to destination
;-------------------------------------------------------------------------------
StrNCopy PROC EXPORT lpszDest:DWORD, lpszSrc:DWORD, dwMaxLen:DWORD
    push esi
    push edi
    push ecx
    
    mov edi, lpszDest
    mov esi, lpszSrc
    mov ecx, dwMaxLen
    
    test edi, edi
    jz @Done
    test esi, esi
    jz @EmptyString
    test ecx, ecx
    jz @Done
    
@CopyLoop:
    lodsb
    stosb
    test al, al
    jz @Done
    loop @CopyLoop
    ; Ensure null termination
    mov BYTE PTR [edi-1], 0
    jmp @Done

@EmptyString:
    mov BYTE PTR [edi], 0

@Done:
    mov eax, lpszDest
    pop ecx
    pop edi
    pop esi
    ret
StrNCopy ENDP

;-------------------------------------------------------------------------------
; StrCat
;-------------------------------------------------------------------------------
; Description: Concatenates source string to destination
; Parameters:
;   [ebp+8]  = lpszDest - Destination string
;   [ebp+12] = lpszSrc - String to append
; Returns:     EAX = Pointer to destination
;-------------------------------------------------------------------------------
StrCat PROC EXPORT lpszDest:DWORD, lpszSrc:DWORD
    push esi
    push edi
    
    mov edi, lpszDest
    mov esi, lpszSrc
    
    test edi, edi
    jz @Done
    
    ; Find end of destination string
@FindEnd:
    cmp BYTE PTR [edi], 0
    je @FoundEnd
    inc edi
    jmp @FindEnd

@FoundEnd:
    test esi, esi
    jz @Done
    
    ; Append source
@AppendLoop:
    lodsb
    stosb
    test al, al
    jnz @AppendLoop

@Done:
    mov eax, lpszDest
    pop edi
    pop esi
    ret
StrCat ENDP

;-------------------------------------------------------------------------------
; StrCmp
;-------------------------------------------------------------------------------
; Description: Compares two strings
; Parameters:
;   [ebp+8]  = lpszStr1 - First string
;   [ebp+12] = lpszStr2 - Second string
; Returns:     
;   EAX < 0 if str1 < str2
;   EAX = 0 if str1 == str2
;   EAX > 0 if str1 > str2
;-------------------------------------------------------------------------------
StrCmp PROC EXPORT lpszStr1:DWORD, lpszStr2:DWORD
    push esi
    push edi
    
    mov esi, lpszStr1
    mov edi, lpszStr2
    
    ; Handle null pointers
    test esi, esi
    jz @Str1Null
    test edi, edi
    jz @Str2Null
    
@CompareLoop:
    lodsb
    mov ah, [edi]
    inc edi
    
    cmp al, ah
    jne @NotEqual
    test al, al
    jnz @CompareLoop
    
    ; Strings are equal
    xor eax, eax
    jmp @Done

@NotEqual:
    movzx eax, al
    movzx ecx, ah
    sub eax, ecx
    jmp @Done

@Str1Null:
    test edi, edi
    jz @BothNull
    mov eax, -1
    jmp @Done

@Str2Null:
    mov eax, 1
    jmp @Done

@BothNull:
    xor eax, eax

@Done:
    pop edi
    pop esi
    ret
StrCmp ENDP

;-------------------------------------------------------------------------------
; StrCmpI
;-------------------------------------------------------------------------------
; Description: Case-insensitive string comparison
; Parameters:
;   [ebp+8]  = lpszStr1 - First string
;   [ebp+12] = lpszStr2 - Second string
; Returns:     Same as StrCmp
;-------------------------------------------------------------------------------
StrCmpI PROC EXPORT lpszStr1:DWORD, lpszStr2:DWORD
    push esi
    push edi
    push ebx
    
    mov esi, lpszStr1
    mov edi, lpszStr2
    
    test esi, esi
    jz @Str1Null
    test edi, edi
    jz @Str2Null
    
@CompareLoop:
    lodsb
    mov bl, [edi]
    inc edi
    
    ; Convert to lowercase
    cmp al, 'A'
    jb @NoConvert1
    cmp al, 'Z'
    ja @NoConvert1
    add al, 32
@NoConvert1:
    
    cmp bl, 'A'
    jb @NoConvert2
    cmp bl, 'Z'
    ja @NoConvert2
    add bl, 32
@NoConvert2:
    
    cmp al, bl
    jne @NotEqual
    test al, al
    jnz @CompareLoop
    
    xor eax, eax
    jmp @Done

@NotEqual:
    movzx eax, al
    movzx ecx, bl
    sub eax, ecx
    jmp @Done

@Str1Null:
    test edi, edi
    jz @BothNull
    mov eax, -1
    jmp @Done

@Str2Null:
    mov eax, 1
    jmp @Done

@BothNull:
    xor eax, eax

@Done:
    pop ebx
    pop edi
    pop esi
    ret
StrCmpI ENDP

;-------------------------------------------------------------------------------
; StrChr
;-------------------------------------------------------------------------------
; Description: Finds first occurrence of a character in a string
; Parameters:
;   [ebp+8]  = lpszString - String to search
;   [ebp+12] = cChar - Character to find
; Returns:     EAX = Pointer to character, or 0 if not found
;-------------------------------------------------------------------------------
StrChr PROC EXPORT lpszString:DWORD, cChar:DWORD
    push edi
    
    mov edi, lpszString
    test edi, edi
    jz @NotFound
    
    mov eax, cChar
    
@SearchLoop:
    mov cl, [edi]
    cmp cl, al
    je @Found
    test cl, cl
    jz @NotFound
    inc edi
    jmp @SearchLoop

@Found:
    mov eax, edi
    pop edi
    ret

@NotFound:
    xor eax, eax
    pop edi
    ret
StrChr ENDP

;-------------------------------------------------------------------------------
; StrRChr
;-------------------------------------------------------------------------------
; Description: Finds last occurrence of a character in a string
; Parameters:
;   [ebp+8]  = lpszString - String to search
;   [ebp+12] = cChar - Character to find
; Returns:     EAX = Pointer to character, or 0 if not found
;-------------------------------------------------------------------------------
StrRChr PROC EXPORT lpszString:DWORD, cChar:DWORD
    push edi
    push ebx
    
    mov edi, lpszString
    test edi, edi
    jz @NotFound
    
    mov eax, cChar
    xor ebx, ebx                ; Last found position
    
@SearchLoop:
    mov cl, [edi]
    test cl, cl
    jz @Done
    cmp cl, al
    jne @Next
    mov ebx, edi               ; Remember this position
@Next:
    inc edi
    jmp @SearchLoop

@Done:
    mov eax, ebx
    pop ebx
    pop edi
    ret

@NotFound:
    xor eax, eax
    pop ebx
    pop edi
    ret
StrRChr ENDP

;-------------------------------------------------------------------------------
; StrStr
;-------------------------------------------------------------------------------
; Description: Finds first occurrence of a substring
; Parameters:
;   [ebp+8]  = lpszString - String to search
;   [ebp+12] = lpszSubStr - Substring to find
; Returns:     EAX = Pointer to substring, or 0 if not found
;-------------------------------------------------------------------------------
StrStr PROC EXPORT lpszString:DWORD, lpszSubStr:DWORD
    push esi
    push edi
    push ebx
    
    mov edi, lpszString
    mov esi, lpszSubStr
    
    test edi, edi
    jz @NotFound
    test esi, esi
    jz @NotFound
    
    ; Check if substring is empty
    cmp BYTE PTR [esi], 0
    je @Found                   ; Empty substring matches at start

@OuterLoop:
    mov al, [edi]
    test al, al
    jz @NotFound
    
    ; Compare substring at current position
    mov ebx, edi
    push esi
    
@InnerLoop:
    mov cl, [esi]
    test cl, cl
    jz @FoundMatch             ; End of substring = match
    mov al, [ebx]
    test al, al
    jz @NoMatch                ; End of string = no match
    cmp al, cl
    jne @NoMatch
    inc ebx
    inc esi
    jmp @InnerLoop

@FoundMatch:
    pop esi
    jmp @Found

@NoMatch:
    pop esi
    inc edi
    jmp @OuterLoop

@Found:
    mov eax, edi
    pop ebx
    pop edi
    pop esi
    ret

@NotFound:
    xor eax, eax
    pop ebx
    pop edi
    pop esi
    ret
StrStr ENDP

;-------------------------------------------------------------------------------
; IntToStr
;-------------------------------------------------------------------------------
; Description: Converts an integer to a string
; Parameters:
;   [ebp+8]  = dwValue - Value to convert
;   [ebp+12] = lpszBuffer - Destination buffer
;   [ebp+16] = dwRadix - Base (2-36)
; Returns:     EAX = Pointer to buffer
;-------------------------------------------------------------------------------
IntToStr PROC EXPORT dwValue:DWORD, lpszBuffer:DWORD, dwRadix:DWORD
    push ebx
    push ecx
    push edx
    push edi
    push esi
    
    mov edi, lpszBuffer
    test edi, edi
    jz @Done
    
    mov eax, dwValue
    mov ebx, dwRadix
    
    ; Validate radix
    cmp ebx, 2
    jl @InvalidRadix
    cmp ebx, 36
    jg @InvalidRadix
    
    ; Handle zero
    test eax, eax
    jnz @Convert
    mov BYTE PTR [edi], '0'
    mov BYTE PTR [edi+1], 0
    jmp @Done
    
@Convert:
    ; Count digits and push them
    xor ecx, ecx
@CountLoop:
    test eax, eax
    jz @WriteDigits
    xor edx, edx
    div ebx
    push edx
    inc ecx
    jmp @CountLoop

@WriteDigits:
    test ecx, ecx
    jz @Terminate
    pop eax
    cmp al, 9
    jbe @Digit
    add al, 'A' - 10
    jmp @Store
@Digit:
    add al, '0'
@Store:
    stosb
    dec ecx
    jmp @WriteDigits

@Terminate:
    mov BYTE PTR [edi], 0
    jmp @Done

@InvalidRadix:
    mov BYTE PTR [edi], 0

@Done:
    mov eax, lpszBuffer
    pop esi
    pop edi
    pop edx
    pop ecx
    pop ebx
    ret
IntToStr ENDP

;-------------------------------------------------------------------------------
; StrToInt
;-------------------------------------------------------------------------------
; Description: Converts a string to an integer
; Parameters:
;   [ebp+8] = lpszString - String to convert
; Returns:     EAX = Integer value
;-------------------------------------------------------------------------------
StrToInt PROC EXPORT lpszString:DWORD
    push ebx
    push ecx
    push esi
    
    mov esi, lpszString
    test esi, esi
    jz @Zero
    
    xor eax, eax               ; Result
    xor ecx, ecx               ; Sign flag
    mov ebx, 10                ; Radix
    
    ; Skip whitespace
@SkipSpace:
    mov cl, [esi]
    cmp cl, ' '
    je @NextSpace
    cmp cl, 9                  ; Tab
    jne @CheckSign
@NextSpace:
    inc esi
    jmp @SkipSpace

@CheckSign:
    cmp cl, '-'
    jne @CheckPlus
    mov ecx, 1                 ; Negative
    inc esi
    jmp @Convert
@CheckPlus:
    cmp cl, '+'
    jne @Convert
    inc esi

@Convert:
    movzx edx, BYTE PTR [esi]
    cmp dl, '0'
    jb @ApplySign
    cmp dl, '9'
    ja @ApplySign
    
    sub dl, '0'
    imul eax, ebx
    add eax, edx
    inc esi
    jmp @Convert

@ApplySign:
    test ecx, ecx
    jz @Done
    neg eax
    jmp @Done

@Zero:
    xor eax, eax

@Done:
    pop esi
    pop ecx
    pop ebx
    ret
StrToInt ENDP

;-------------------------------------------------------------------------------
; HexToStr
;-------------------------------------------------------------------------------
; Description: Converts a value to hexadecimal string
; Parameters:
;   [ebp+8]  = dwValue - Value to convert
;   [ebp+12] = lpszBuffer - Destination buffer
;   [ebp+16] = dwMinDigits - Minimum digits (padded with zeros)
; Returns:     EAX = Pointer to buffer
;-------------------------------------------------------------------------------
HexToStr PROC EXPORT dwValue:DWORD, lpszBuffer:DWORD, dwMinDigits:DWORD
    push edi
    push ecx
    push edx
    
    mov edi, lpszBuffer
    test edi, edi
    jz @Done
    
    mov eax, dwValue
    mov ecx, dwMinDigits
    cmp ecx, 8
    jle @ValidDigits
    mov ecx, 8                 ; Max 8 hex digits for 32-bit
@ValidDigits:
    test ecx, ecx
    jnz @HasMinDigits
    mov ecx, 1                 ; At least 1 digit
@HasMinDigits:
    
    ; Write hex digits from end
    add edi, ecx
    mov BYTE PTR [edi], 0      ; Null terminate
    dec edi
    
@HexLoop:
    mov edx, eax
    and edx, 0Fh
    cmp dl, 9
    jbe @HexDigit
    add dl, 'A' - 10
    jmp @HexStore
@HexDigit:
    add dl, '0'
@HexStore:
    mov [edi], dl
    shr eax, 4
    dec edi
    dec ecx
    jnz @HexLoop

@Done:
    mov eax, lpszBuffer
    pop edx
    pop ecx
    pop edi
    ret
HexToStr ENDP

;-------------------------------------------------------------------------------
; ToUpper
;-------------------------------------------------------------------------------
; Description: Converts a string to uppercase
; Parameters:
;   [ebp+8] = lpszString - String to convert (in-place)
; Returns:     EAX = Pointer to string
;-------------------------------------------------------------------------------
ToUpper PROC EXPORT lpszString:DWORD
    push edi
    
    mov edi, lpszString
    test edi, edi
    jz @Done
    
@Loop:
    mov al, [edi]
    test al, al
    jz @Done
    cmp al, 'a'
    jb @Next
    cmp al, 'z'
    ja @Next
    sub al, 32
    mov [edi], al
@Next:
    inc edi
    jmp @Loop

@Done:
    mov eax, lpszString
    pop edi
    ret
ToUpper ENDP

;-------------------------------------------------------------------------------
; ToLower
;-------------------------------------------------------------------------------
; Description: Converts a string to lowercase
; Parameters:
;   [ebp+8] = lpszString - String to convert (in-place)
; Returns:     EAX = Pointer to string
;-------------------------------------------------------------------------------
ToLower PROC EXPORT lpszString:DWORD
    push edi
    
    mov edi, lpszString
    test edi, edi
    jz @Done
    
@Loop:
    mov al, [edi]
    test al, al
    jz @Done
    cmp al, 'A'
    jb @Next
    cmp al, 'Z'
    ja @Next
    add al, 32
    mov [edi], al
@Next:
    inc edi
    jmp @Loop

@Done:
    mov eax, lpszString
    pop edi
    ret
ToLower ENDP

END
