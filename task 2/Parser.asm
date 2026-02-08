.386
.model flat, stdcall
option casemap:none

; --- Tự định nghĩa các hàm WinAPI (Bypass windows.inc) ---
includelib kernel32.lib
extern GetStdHandle@4:proc
extern CreateFileA@28:proc
extern WriteFile@20:proc
extern CloseHandle@4:proc
extern ExitProcess@4:proc

; --- Định nghĩa hằng số ---
STD_OUTPUT_HANDLE    equ -11
GENERIC_READ         equ 80000000h
FILE_SHARE_READ      equ 1
OPEN_EXISTING        equ 3
FILE_ATTRIBUTE_NORMAL equ 80h

.data
    sFileName       db "test.exe", 0
    msgErr          db "Loi: Khong tim thay file test.exe trong thu muc nay!", 13, 10, 0
    msgSuccess      db "Mo file thanh cong!", 13, 10, 0
    
    hConsole        dd 0
    hFile           dd 0
    bytesWritten    dd 0

.code
start:
    ; 1. Lấy Handle Console
    push STD_OUTPUT_HANDLE
    call GetStdHandle@4
    mov hConsole, eax

    ; 2. Mở file test.exe
    push 0
    push FILE_ATTRIBUTE_NORMAL
    push OPEN_EXISTING
    push 0
    push FILE_SHARE_READ
    push GENERIC_READ
    push offset sFileName
    call CreateFileA@28
    
    mov hFile, eax
    cmp eax, -1 ; INVALID_HANDLE_VALUE = -1
    je  LoiMoFile

    ; Nếu thành công
    push offset msgSuccess
    call InChuoi
    
    push hFile
    call CloseHandle@4
    jmp Thoat

LoiMoFile:
    push offset msgErr
    call InChuoi

Thoat:
    push 0
    call ExitProcess@4

; --- Hàm phụ trợ in chuoi ---
InChuoi proc ptrString:DWORD
    pushad
    mov edi, [ptrString]
    xor al, al
    mov ecx, -1
    repne scasb
    not ecx
    dec ecx ; Do dai chuoi
    
    push 0
    push offset bytesWritten
    push ecx
    push [ptrString]
    push hConsole
    call WriteFile@20
    popad
    ret
InChuoi endp

end start