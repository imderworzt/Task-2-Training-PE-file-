.386
.model flat, stdcall
option casemap:none

; ---------------------------------------------------------
; TỰ KHAI BÁO CÁC HÀM VÀ HẰNG SỐ (Không cần include file)
; ---------------------------------------------------------

; Khai báo các hàm từ Kernel32.lib
ExitProcess PROTO :DWORD
CreateFileA PROTO :DWORD, :DWORD, :DWORD, :DWORD, :DWORD, :DWORD, :DWORD
CreateFileMappingA PROTO :DWORD, :DWORD, :DWORD, :DWORD, :DWORD, :DWORD
MapViewOfFile PROTO :DWORD, :DWORD, :DWORD, :DWORD, :DWORD
WriteFile PROTO :DWORD, :DWORD, :DWORD, :DWORD, :DWORD
lstrlenA PROTO :DWORD
GetStdHandle PROTO :DWORD
UnmapViewOfFile PROTO :DWORD
CloseHandle PROTO :DWORD

includelib kernel32.lib
; Nếu bạn cần user32 (MessageBox), thêm ở đây. Code này chỉ dùng kernel32.

; Định nghĩa các hằng số (Windows Constants)
GENERIC_READ     EQU 80000000h
FILE_SHARE_READ  EQU 00000001h
OPEN_EXISTING    EQU 3
PAGE_READONLY    EQU 2
FILE_MAP_READ    EQU 4
STD_OUTPUT_HANDLE EQU -11
INVALID_HANDLE_VALUE EQU -1

; ---------------------------------------------------------
; DATA SECTION
; ---------------------------------------------------------
.data
    filename        db "target.exe", 0   ; <--- ĐỔI TÊN FILE CẦN TEST Ở ĐÂY
    
    msgSuccess      db "--- PE PARSER (Manual Import/Export) ---", 13, 10, 0
    msgErrFile      db "Error: Cannot open target.exe", 13, 10, 0
    msgErrPE        db "Error: Not a valid PE file", 13, 10, 0
    
    fmtDos          db "DOS Header: MZ Signature found.", 13, 10, 0
    fmtPE           db "NT Header: PE Signature found.", 13, 10, 0
    
    lblImport       db 13, 10, "--- IMPORT TABLE ---", 13, 10, 0
    fmtImportLib    db "DLL: ", 0
    
    lblExport       db 13, 10, "--- EXPORT TABLE ---", 13, 10, 0
    fmtExportFunc   db "Func: ", 0
    
    crlf            db 13, 10, 0
    
    ; Biến toàn cục
    hFile           dd 0
    hMap            dd 0
    pMemory         dd 0 ; Base address của file trong RAM
    bytesWritten    dd 0
    hStdOut         dd 0

; ---------------------------------------------------------
; CODE SECTION
; ---------------------------------------------------------
.code

; --- Hàm phụ trợ: In chuỗi ra màn hình ---
PrintString proc pStr:DWORD
    push eax
    push ecx
    push edx
    
    ; Lấy handle stdout nếu chưa có
    cmp hStdOut, 0
    jnz @write
    push STD_OUTPUT_HANDLE
    call GetStdHandle
    mov hStdOut, eax
    cmp eax, INVALID_HANDLE_VALUE
    je @done_print

@write:
    ; Tính độ dài chuỗi
    push pStr
    call lstrlenA
    mov ecx, eax        ; Độ dài vào ECX

    ; Gọi WriteFile
    push 0              ; lpOverlapped
    push offset bytesWritten
    push ecx            ; nNumberOfBytesToWrite
    push pStr           ; lpBuffer
    push hStdOut        ; hFile
    call WriteFile
    
@done_print:
    pop edx
    pop ecx
    pop eax
    ret 4
PrintString endp

; --- Hàm: RvaToOffset ---
; Input: EAX = RVA, ESI = Pointer to NT Headers
; Output: EAX = File Offset (0 nếu lỗi)
RvaToOffset proc
    push ebx
    push ecx
    push edx
    push esi
    push edi

    mov edi, esi ; EDI = NT Headers
    
    ; Lấy số lượng section (FileHeader.NumberOfSections) tại offset 6
    movzx ecx, word ptr [edi + 6] 
    
    ; Tính địa chỉ Section Header đầu tiên
    ; SizeOfOptionalHeader tại offset 20
    movzx ebx, word ptr [edi + 20] 
    add edi, 24          ; Bỏ qua Signature(4) + FileHeader(20)
    add edi, ebx         ; Nhảy qua Optional Header -> Tới Section đầu tiên

@find_section:
    cmp ecx, 0
    jz @not_found

    ; Section Structure: [VirtualAddress +12], [VirtualSize +8], [PointerToRawData +20]
    mov ebx, [edi + 12]  ; VirtualAddress (RVA start)
    mov edx, [edi + 8]   ; VirtualSize
    
    ; Kiểm tra: RVA >= VirtualAddress && RVA < VirtualAddress + VirtualSize
    cmp eax, ebx
    jl @next_section     ; Nếu RVA < Section Start -> Next
    
    push edx
    add edx, ebx         ; Section End
    cmp eax, edx
    pop edx
    jge @next_section    ; Nếu RVA >= Section End -> Next
    
    ; Found! Offset = RVA - VirtualAddress + PointerToRawData
    sub eax, ebx         ; EAX = Offset trong section
    add eax, [edi + 20]  ; Cộng Raw Offset của section
    jmp @done_rva

@next_section:
    add edi, 40          ; Size of IMAGE_SECTION_HEADER = 40 bytes
    dec ecx
    jmp @find_section

@not_found:
    mov eax, 0

@done_rva:
    pop edi
    pop esi
    pop edx
    pop ecx
    pop ebx
    ret
RvaToOffset endp

; ---------------------------------------------------------
; MAIN ENTRY
; ---------------------------------------------------------
start:
    ; 1. Open File "target.exe"
    push 0
    push 0
    push OPEN_EXISTING
    push 0
    push FILE_SHARE_READ
    push GENERIC_READ
    push offset filename
    call CreateFileA
    
    cmp eax, INVALID_HANDLE_VALUE
    je @error_file
    mov hFile, eax

    ; 2. Create Mapping
    push 0
    push 0
    push 0
    push PAGE_READONLY
    push 0
    push hFile
    call CreateFileMappingA
    test eax, eax
    jz @error_file ; Mapping failed
    mov hMap, eax

    ; 3. Map View
    push 0
    push 0
    push 0
    push FILE_MAP_READ
    push hMap
    call MapViewOfFile
    test eax, eax
    jz @error_file
    mov pMemory, eax

    push offset msgSuccess
    call PrintString

    ; --- PE PARSING START ---
    mov esi, pMemory    ; ESI = DOS Header Base
    
    ; Check MZ
    cmp word ptr [esi], 5A4Dh ; 'MZ'
    jnz @error_pe
    
    push offset fmtDos
    call PrintString

    ; Get NT Header
    mov eax, [esi + 3Ch] ; e_lfanew
    add eax, esi         ; EAX = NT Header Address
    mov esi, eax         ; ESI bây giờ là NT Header
    
    ; Check PE
    cmp dword ptr [esi], 00004550h ; 'PE'
    jnz @error_pe

    push offset fmtPE
    call PrintString

    ; =====================================================
    ; XỬ LÝ IMPORT TABLE
    ; =====================================================
    push offset lblImport
    call PrintString

    ; Import Table RVA nằm ở DataDirectory[1]
    ; DataDirectory bắt đầu tại: OptionalHeader + 96 (Standard fields etc)
    ; OptionalHeader bắt đầu tại: NT Header + 24
    ; => DataDirectory[0] tại: NT + 24 + 96 = NT + 120 (0x78)
    ; => DataDirectory[1] (Import) tại: NT + 128 (0x80)
    
    mov eax, [esi + 80h] ; Import RVA
    test eax, eax
    jz @process_exports ; Không có import, nhảy sang export

    ; Convert RVA -> Offset
    push esi            ; Save NT Header
    call RvaToOffset
    mov ebx, eax        ; EBX = File Offset của Import Descriptor
    pop esi             ; Restore NT Header
    
    test ebx, ebx
    jz @process_exports ; Lỗi convert
    add ebx, pMemory    ; EBX trỏ vào mảng IMPORT_DESCRIPTOR trong RAM

@import_loop:
    ; Check Name RVA (offset +12)
    mov eax, [ebx + 12]
    test eax, eax
    jz @process_exports ; Hết danh sách (NULL struct)

    ; Lấy tên DLL
    push esi
    call RvaToOffset    ; Convert Name RVA -> Offset
    pop esi
    
    add eax, pMemory    ; EAX = Pointer to DLL Name String
    
    push offset fmtImportLib
    call PrintString
    push eax            ; Tên DLL
    call PrintString
    push offset crlf
    call PrintString

    add ebx, 20         ; Next descriptor (20 bytes)
    jmp @import_loop

    ; =====================================================
    ; XỬ LÝ EXPORT TABLE
    ; =====================================================
@process_exports:
    push offset lblExport
    call PrintString

    ; Export Table RVA nằm ở DataDirectory[0] => Offset 0x78 từ đầu NT Header
    mov eax, [esi + 78h]
    test eax, eax
    jz @finish          ; Không có export

    ; Convert Export Dir RVA -> Offset
    push esi
    call RvaToOffset
    mov ebx, eax
    pop esi
    
    test ebx, ebx
    jz @finish
    add ebx, pMemory    ; EBX = IMAGE_EXPORT_DIRECTORY

    ; Cấu trúc Export Directory:
    ; +24: NumberOfNames
    ; +32: AddressOfNames (RVA)
    
    mov ecx, [ebx + 24] ; Số lượng hàm export
    mov edx, [ebx + 32] ; RVA của mảng tên
    
    test ecx, ecx
    jz @finish
    test edx, edx
    jz @finish

    ; Convert AddressOfNames RVA -> Offset
    mov eax, edx
    push esi
    push ecx            ; Save counter
    call RvaToOffset
    mov edx, eax        ; EDX = Offset mảng tên
    pop ecx             ; Restore counter
    pop esi
    
    add edx, pMemory    ; EDX = Pointer to Array of Name RVAs (Mỗi phần tử 4 byte)

@export_loop:
    cmp ecx, 0
    jz @finish

    ; Lấy RVA tên hàm từ mảng (4 byte đầu)
    mov eax, [edx]
    
    push edx            ; Save mảng pointer
    push ecx            ; Save counter
    push esi            ; Save NT Header
    
    call RvaToOffset    ; Convert RVA chuỗi tên -> Offset
    
    pop esi
    pop ecx
    pop edx
    
    push eax            ; Offset chuỗi tên (tạm)
    add eax, pMemory    ; EAX = Chuỗi tên thật
    
    ; In ra màn hình
    push offset fmtExportFunc
    call PrintString
    push eax
    call PrintString
    push offset crlf
    call PrintString
    
    pop eax             ; Dọn stack (cái offset chuỗi tên tạm nãy push)

    add edx, 4          ; Next name RVA in array
    dec ecx
    jmp @export_loop

@error_file:
    push offset msgErrFile
    call PrintString
    jmp @exit_prog

@error_pe:
    push offset msgErrPE
    call PrintString
    jmp @exit_prog

@finish:
    ; Dọn dẹp handles (Ở đây để OS tự dọn khi ExitProcess cho gọn code asm)

@exit_prog:
    push 0
    call ExitProcess

end start