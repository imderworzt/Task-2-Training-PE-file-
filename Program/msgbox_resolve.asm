.386
.model flat, stdcall
option casemap:none

; Thay vì dùng include, ta định nghĩa trực tiếp nguyên mẫu hàm (Prototypes)
extern LoadLibraryA@4 : proc
extern GetProcAddress@8 : proc
extern ExitProcess@4 : proc
extern FreeLibrary@4 : proc

; Alias để gọi cho thuận tiện
LoadLibraryA    equ <LoadLibraryA@4>
GetProcAddress  equ <GetProcAddress@8>
ExitProcess     equ <ExitProcess@4>
FreeLibrary     equ <FreeLibrary@4>

; Vẫn cần Linker biết tìm các hàm trên ở đâu (không cần file .inc)
includelib kernel32.lib 

.data
    szUser32        db "user32.dll", 0
    szMessageBoxA   db "MessageBoxA", 0
    szTitle         db "Fix Error Success", 0
    szContent       db "API đã được resolve thành công!", 0
    
    hUser32         dd 0
    pMessageBoxA    dd 0

.code
start:
    push offset szUser32
    call LoadLibraryA
    
    .if eax != 0
        mov hUser32, eax
        push offset szMessageBoxA
        push hUser32
        call GetProcAddress
        
        .if eax != 0
            mov pMessageBoxA, eax
            push 0              
            push offset szTitle
            push offset szContent
            push 0              
            call pMessageBoxA   
        .endif
        
        push hUser32
        call FreeLibrary
    .endif

    push 0
    call ExitProcess
end start