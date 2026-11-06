"""
Tự động sinh các vector kiểm thử chuẩn (test vectors) cho RS(15,11) trên GF(256).

Script này tạo ra dữ liệu kiểm thử trong thư mục vectors/ theo cấu trúc:
  vectors/
  ├── README.md
  ├── no_error/
  │   ├── input_data.hex          (11 bytes dữ liệu gốc)
  │   ├── encoded_data.hex        (15 bytes từ mã hợp lệ)
  │   ├── corrupted_data.hex      (15 bytes từ mã nhận - không lỗi)
  │   └── expected_codeword.hex   (15 bytes kết quả mong đợi sau giải mã)
  ├── one_error/
  │   ├── input_data.hex
  │   ├── encoded_data.hex
  │   ├── corrupted_data.hex      (1 lỗi tại phần dữ liệu)
  │   └── expected_codeword.hex
  ├── two_errors/
  │   ├── input_data.hex
  │   ├── encoded_data.hex
  │   ├── corrupted_data.hex      (2 lỗi: vị trí đầu 0 và cuối 14 theo docs)
  │   └── expected_codeword.hex
  ├── parity_error/
  │   ├── input_data.hex
  │   ├── encoded_data.hex
  │   ├── corrupted_data.hex      (2 lỗi nằm hoàn toàn trong phần parity)
  │   └── expected_codeword.hex
  └── beyond_capacity/
      ├── input_data.hex
      ├── encoded_data.hex
      ├── corrupted_data.hex      (3 lỗi > T=2: vượt quá khả năng sửa)
      └── case_info.json          (Mô tả kịch bản lỗi và kết quả kỳ vọng)

Định dạng file .hex: Mỗi dòng chứa 1 byte ở hệ thập lục phân 2 chữ số (chuẩn $readmemh).
"""

import os
import sys
import json
from typing import List

# Import mô hình tham chiếu RS
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from rs_reference import (
    rs_encode,
    rs_decode,
    RS_N,
    RS_K,
    RS_R,
    RS_T,
)


def write_hex_file(filepath: str, data: List[int]) -> None:
    """Ghi danh sách byte vào file hex (mỗi dòng 1 byte 2 chữ số in hoa)."""
    os.makedirs(os.path.dirname(filepath), exist_ok=True)
    with open(filepath, "w", encoding="utf-8") as f:
        for val in data:
            f.write(f"{val & 0xFF:02X}\n")


def write_readme_vectors(vectors_dir: str) -> None:
    """Tạo file README.md cho thư mục vectors."""
    readme_path = os.path.join(vectors_dir, "README.md")
    content = """# Dữ liệu kiểm thử Reed-Solomon (Test Vectors)

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
"""
    with open(readme_path, "w", encoding="utf-8") as f:
        f.write(content)


def generate_all_vectors(base_vectors_dir: str = None) -> None:
    """Sinh toàn bộ các vector kiểm thử vào thư mục vectors/."""
    if base_vectors_dir is None:
        model_dir = os.path.dirname(os.path.abspath(__file__))
        project_dir = os.path.dirname(model_dir)
        base_vectors_dir = os.path.join(project_dir, "vectors")

    print(f"=== Đang sinh vector kiểm thử vào: {base_vectors_dir} ===")

    # -------------------------------------------------------------------------
    # Case 1: no_error (Từ mã hoàn hảo không lỗi)
    # -------------------------------------------------------------------------
    case1_dir = os.path.join(base_vectors_dir, "no_error")
    data_1 = list(range(RS_K))  # 00 01 02 .. 0A
    cw_1 = rs_encode(data_1)
    write_hex_file(os.path.join(case1_dir, "input_data.hex"), data_1)
    write_hex_file(os.path.join(case1_dir, "encoded_data.hex"), cw_1)
    write_hex_file(os.path.join(case1_dir, "corrupted_data.hex"), cw_1)
    write_hex_file(os.path.join(case1_dir, "expected_codeword.hex"), cw_1)
    # Tự kiểm tra với decoder
    dec_cw_1, err_cnt_1, fail_1 = rs_decode(cw_1)
    assert not fail_1 and err_cnt_1 == 0 and dec_cw_1 == cw_1
    print("  [x] no_error: Hoàn thành")

    # -------------------------------------------------------------------------
    # Case 2: one_error (1 lỗi trong khối dữ liệu)
    # -------------------------------------------------------------------------
    case2_dir = os.path.join(base_vectors_dir, "one_error")
    data_2 = [0x10, 0x21, 0x32, 0x43, 0x54, 0x65, 0x76, 0x87, 0x98, 0xA9, 0xBA]
    cw_2 = rs_encode(data_2)
    corrupted_2 = list(cw_2)
    err_pos_2 = 3
    err_mask_2 = 0xA5
    corrupted_2[err_pos_2] ^= err_mask_2
    write_hex_file(os.path.join(case2_dir, "input_data.hex"), data_2)
    write_hex_file(os.path.join(case2_dir, "encoded_data.hex"), cw_2)
    write_hex_file(os.path.join(case2_dir, "corrupted_data.hex"), corrupted_2)
    write_hex_file(os.path.join(case2_dir, "expected_codeword.hex"), cw_2)
    # Tự kiểm tra với decoder
    dec_cw_2, err_cnt_2, fail_2 = rs_decode(corrupted_2)
    assert not fail_2 and err_cnt_2 == 1 and dec_cw_2 == cw_2
    print("  [x] one_error: Hoàn thành (Lỗi tại index 3, XOR 0xA5)")

    # -------------------------------------------------------------------------
    # Case 3: two_errors (2 lỗi tại biên đầu và cuối: pos 0 và pos 14)
    # Đúng với ví dụ trong docs/rs_algorithm.md mục 12
    # -------------------------------------------------------------------------
    case3_dir = os.path.join(base_vectors_dir, "two_errors")
    data_3 = list(range(RS_K))  # 00 .. 0A
    cw_3 = rs_encode(data_3)    # Parity C0 8F 28 6C
    corrupted_3 = list(cw_3)
    corrupted_3[0] ^= 0x55      # Vị trí đầu
    corrupted_3[14] ^= 0xA6     # Vị trí cuối (trong parity)
    write_hex_file(os.path.join(case3_dir, "input_data.hex"), data_3)
    write_hex_file(os.path.join(case3_dir, "encoded_data.hex"), cw_3)
    write_hex_file(os.path.join(case3_dir, "corrupted_data.hex"), corrupted_3)
    write_hex_file(os.path.join(case3_dir, "expected_codeword.hex"), cw_3)
    # Tự kiểm tra với decoder
    dec_cw_3, err_cnt_3, fail_3 = rs_decode(corrupted_3)
    assert not fail_3 and err_cnt_3 == 2 and dec_cw_3 == cw_3
    print("  [x] two_errors: Hoàn thành (Lỗi tại index 0 XOR 0x55 và index 14 XOR 0xA6)")

    # -------------------------------------------------------------------------
    # Case 4: parity_error (2 lỗi chỉ nằm trong các byte parity)
    # -------------------------------------------------------------------------
    case4_dir = os.path.join(base_vectors_dir, "parity_error")
    data_4 = [0xAA, 0x55, 0xAA, 0x55, 0xAA, 0x55, 0xAA, 0x55, 0xAA, 0x55, 0xAA]
    cw_4 = rs_encode(data_4)
    corrupted_4 = list(cw_4)
    corrupted_4[11] ^= 0x3C     # Byte parity đầu tiên
    corrupted_4[13] ^= 0xC3     # Byte parity thứ ba
    write_hex_file(os.path.join(case4_dir, "input_data.hex"), data_4)
    write_hex_file(os.path.join(case4_dir, "encoded_data.hex"), cw_4)
    write_hex_file(os.path.join(case4_dir, "corrupted_data.hex"), corrupted_4)
    write_hex_file(os.path.join(case4_dir, "expected_codeword.hex"), cw_4)
    # Tự kiểm tra với decoder
    dec_cw_4, err_cnt_4, fail_4 = rs_decode(corrupted_4)
    assert not fail_4 and err_cnt_4 == 2 and dec_cw_4 == cw_4
    print("  [x] parity_error: Hoàn thành (Lỗi tại parity index 11 và 13)")

    # -------------------------------------------------------------------------
    # Case 5: beyond_capacity (3 lỗi > T=2: vượt quá khả năng sửa)
    # -------------------------------------------------------------------------
    case5_dir = os.path.join(base_vectors_dir, "beyond_capacity")
    data_5 = [0x11, 0x22, 0x33, 0x44, 0x55, 0x66, 0x77, 0x88, 0x99, 0xAA, 0xBB]
    cw_5 = rs_encode(data_5)
    corrupted_5 = list(cw_5)
    corrupted_5[1] ^= 0x45
    corrupted_5[5] ^= 0x67
    corrupted_5[9] ^= 0x89
    write_hex_file(os.path.join(case5_dir, "input_data.hex"), data_5)
    write_hex_file(os.path.join(case5_dir, "encoded_data.hex"), cw_5)
    write_hex_file(os.path.join(case5_dir, "corrupted_data.hex"), corrupted_5)

    # Đánh giá bằng decoder tham chiếu
    _, l_deg_5, fail_5 = rs_decode(corrupted_5)

    case_info = {
        "description": "Vượt quá khả năng sửa lỗi (3 lỗi > T=2)",
        "code_parameters": {"n": RS_N, "k": RS_K, "r": RS_R, "t": RS_T},
        "errors_injected": [
            {"index": 1, "xor_mask": "0x45", "original_byte": f"0x{cw_5[1]:02X}"},
            {"index": 5, "xor_mask": "0x67", "original_byte": f"0x{cw_5[5]:02X}"},
            {"index": 9, "xor_mask": "0x89", "original_byte": f"0x{cw_5[9]:02X}"}
        ],
        "expected_behavior": {
            "fail_flag_expected": True,
            "decoder_result_fail": fail_5,
            "lambda_degree": l_deg_5,
            "note": "Khi số lỗi vượt quá T=2, bộ giải mã RS có thể báo cờ fail=1 hoặc giải mã nhầm sang từ mã khác có khoảng cách gần hơn."
        }
    }
    with open(os.path.join(case5_dir, "case_info.json"), "w", encoding="utf-8") as f:
        json.dump(case_info, f, indent=4, ensure_ascii=False)
    print("  [x] beyond_capacity: Hoàn thành (3 lỗi, kèm case_info.json)")

    # Viết README cho thư mục vectors
    write_readme_vectors(base_vectors_dir)
    print("  [x] vectors/README.md: Hoàn thành")

    print("[PASS] Toàn bộ vector kiểm thử đã được tạo thành công!")


if __name__ == "__main__":
    generate_all_vectors()

