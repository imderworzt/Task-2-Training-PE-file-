# Task-2-Training (PE file)

## Khái niệm:

PE (Portable Executable) là định dạng file riêng của Win 32, tất cả các file có thể thực thi được trên Win 32 đều là định dạng PE.

## Cấu trúc cơ bản một file PE

<img width="451" height="524" alt="image" src="https://github.com/user-attachments/assets/ecc46c20-06bd-4410-85d1-c479784bc5d1" />

Header: Lưu các giá trị định dạng file và offset của các section.

## DOS MZ Header

  - e_magic: Chữ ký của PE file, giá trị: 4Dh, 5Ah (Ký tự “MZ”, tên của người sáng lập MS-DOS: Mark Zbikowsky). Giá trị này đánh dấu một DOS Header hợp lệ và được phép thực thi tiếp.

  - e_lfanew: là một DWORD nằm ở cuối cùng của DOS Header, là trường chứa offset của PE Header so với vị trí đầu file.

## DOS STUB

DOS Stub chỉ là một chương trình DOS EXE nhỏ hiển thị một thông báo lỗi, là phần để tương thích với Windows 16bit. Ví dụ như trong hình minh họa dưới đây, thông báo sẽ hiện ra như sau: “This is program cannot be run in DOS mode”

<img width="479" height="65" alt="image" src="https://github.com/user-attachments/assets/782b1249-3eea-49f6-ab84-93aada4b57a9" />

## PE Header

PE Header thực chất là cấu trúc IMAGE_NT_HEADERS bao gồm các thông tin cần thiết cho quá trình loader load file lên bộ nhớ. Cấu trúc này gồm 3 phần được định nghĩa trong windows.inc

<img width="768" height="163" alt="image" src="https://github.com/user-attachments/assets/b098022d-2749-40fb-be93-8b75a5dceb19" />

FILE_HEADER: bao gồm 20 bytes tiếp theo của PE Header, phần này chứa thông tin về sơ đồ bố trí vật lý và các đặc tính của file. 

OPTIONAL_HEADER: bao gồm 224 bytes tiếp theo sau FILE_HEADER. Cấu trúc này được định nghĩa trong windows.inc, đây là phần chứa thông tin về sơ đồ logic trong PE file. Dưới đây là danh sách các trường trong cấu trúc này, đồng thời sẽ đưa ra một số chỉ dẫn về thông tin của một số trường cần quan tâm khi muốn chỉnh sửa file.

## Selection table

Section Table là thành phần ngày sau PE Header, bao gồm một mảng những cấu trúc IMAGE_SECTION_HEADER, mỗi phần tử chứa thông tin về một section trong PE file.

## Cách một chương trình được nạp từ ổ đĩa lên RAM

Khi thực hiện khởi động 1 chương trình, Hệ điều hành sẽ nhận được tín hiệu và bắt đầu tìm kiếm tệp tin thực thi

Sau đó, Trình nạp (Loader) của hệ điều hành đọc cấu trúc của tệp tin thực thi. Tệp này không chỉ chứa mã máy mà còn có các thông tin như:

  - Kích thước của chương trình.

  - Các thư viện liên kết động (DLL) cần thiết.

  - Điểm bắt đầu của mã lệnh (Entry point).

Sau đó, hệ điều hành sẽ tìm một khoảng trống trong RAM đủ lớn để chứa chương trình.

Rồi dữ liệu được chuyển dần từ ổ đĩa sang RAM, bao gồm:

  - Mã lệnh (Code Segment): Các chỉ dẫn để CPU thực hiện.

  - Dữ liệu tĩnh (Data Segment): Các biến toàn cục hoặc hằng số đã được định nghĩa sẵn.

  - Thiết lập Stack và Heap: Đây là các vùng nhớ trống được chuẩn bị để chương trình sử dụng trong quá trình chạy (lưu biến tạm, đối tượng mới...).

Rồi Loader tìm các thư viện chương trình sử dụng, nạp chúng vào RAM rồi liên kết với chương trình. Cuối cùng CPU sẽ bắt đầu đọc vùng nhớ chứa lệnh đầu tiên của chương trình trong RAM và chương trình chạy từ đây.
