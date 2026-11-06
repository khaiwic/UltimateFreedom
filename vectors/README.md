# Dữ liệu kiểm thử Reed-Solomon (Test Vectors)

Thư mục này chứa các bộ vector kiểm thử chuẩn cho bộ mã hóa và giải mã RS(15,11) trên GF(256),
được sinh tự động bởi script `model/generate_vectors.py` từ mô hình toán học tham chiếu `rs_reference.py`.

## 1. Định dạng file

- Các file `.hex` tuân thủ cú pháp của tác vụ `$readmemh` trong Verilog/SystemVerilog.
- Mỗi dòng chứa đúng một byte biểu diễn ở hệ thập lục phân (hexadecimal) gồm 2 chữ số (từ `00` đến `FF`).
- `input_data.hex`: Chứa đúng $K = 11$ dòng (11 bytes dữ liệu gốc $m[0..10]$).
- `encoded_data.hex`: Chứa đúng $N = 15$ dòng (11 bytes dữ liệu + 4 bytes parity $p[0..3]$).
- `corrupted_data.hex`: Chứa đúng $N = 15$ dòng (từ mã nhận $y[0..14]$ đưa vào decoder).
- `expected_codeword.hex`: Chứa đúng $N = 15$ dòng (từ mã chuẩn kỳ vọng decoder khôi phục).

## 2. Các kịch bản kiểm thử (Test Cases)

| Kịch bản | Số lỗi | Vị trí lỗi và mặt nạ XOR | Kết quả giải mã mong đợi |
|---|---|---|---|
| `no_error/` | 0 | Không có lỗi nào | `fail = 0`, giữ nguyên 15 bytes, 0 lỗi cần sửa |
| `one_error/` | 1 | Vị trí dữ liệu `index = 3` (XOR `0xA5`) | `fail = 0`, sửa đúng symbol tại index 3 |
| `two_errors/` | 2 | Vị trí đầu `index = 0` (XOR `0x55`) và cuối `index = 14` (XOR `0xA6`) | `fail = 0`, sửa đúng 2 symbol lỗi biên (ví dụ chuẩn mục 12) |
| `parity_error/` | 2 | Vị trí parity `index = 11` (XOR `0x3C`) và `index = 13` (XOR `0xC3`) | `fail = 0`, khôi phục parity, dữ liệu gốc không bị ảnh hưởng |
| `beyond_capacity/` | 3 | 3 lỗi tại `index = 1, 5, 9` (> T = 2) | Vượt quá khả năng sửa: mong đợi `fail = 1` hoặc báo lỗi |

## 3. Cách tái tạo hoặc cập nhật vector

Chạy lệnh từ thư mục gốc của dự án:

```bash
python model/generate_vectors.py
```
