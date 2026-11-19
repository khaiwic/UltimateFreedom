"""
Tu dong sinh cac vector kiem thu chuan cho RS(5,3) tren GF(8).
"""

import os
import sys
import json
from typing import List

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
    os.makedirs(os.path.dirname(filepath), exist_ok=True)
    with open(filepath, "w", encoding="utf-8") as f:
        for val in data:
            f.write(f"{val & 0x07:X}\n")


def write_readme_vectors(vectors_dir: str) -> None:
    readme_path = os.path.join(vectors_dir, "README.md")
    content = """# Du lieu kiem thu Reed-Solomon RS(5,3) tren GF(8)

Thu muc nay chua cac bo vector kiem thu chuan cho bo ma hoa va giai ma RS(5,3) tren GF(8),
duoc sinh tu dong boi script `model/generate_vectors.py` tu mo hinh tham chieu `rs_reference.py`.

## 1. Dinh dang file
- Moi dong chua 1 symbol 3-bit (`0`..`7`) theo chuan `$readmemh`.
- `input_data.hex`: $K = 3$ symbol du lieu goc $m[0..2]$.
- `encoded_data.hex`: $N = 5$ symbol tu ma systematic ($3$ data + $2$ parity).
- `corrupted_data.hex`: $N = 5$ symbol nhan duoc co hoac khong co loi.
- `expected_codeword.hex`: $N = 5$ symbol ky vong sau giai ma.

## 2. Cac kich ban kiem thu
| Kich ban | So loi | Vi tri va mat na XOR | Ket qua giai ma mong doi |
|---|---|---|---|
| `no_error/` | 0 | Khong co loi | `fail = 0`, giu nguyen 5 symbol |
| `one_error/` | 1 | Symbol `index = 4` (XOR `5`) | `fail = 0`, sua dung symbol tai index 4 |
| `two_errors/` | 2 | `index = 3` (XOR `2`), `index = 4` (XOR `5`) | Vuot nguong $T=1$ |
| `parity_error/` | 1 | Parity `index = 3` (XOR `6`) | `fail = 0`, sua dung parity |
| `beyond_capacity/` | 3 | 3 loi tai `index = 2, 3, 4` ($> T = 1$) | Vuot nguong sua sai |
"""
    with open(readme_path, "w", encoding="utf-8") as f:
        f.write(content)


def generate_all_vectors(base_vectors_dir: str = None) -> None:
    if base_vectors_dir is None:
        model_dir = os.path.dirname(os.path.abspath(__file__))
        project_dir = os.path.dirname(model_dir)
        base_vectors_dir = os.path.join(project_dir, "vectors")

    print(f"=== Dang sinh vector kiem thu vao: {base_vectors_dir} ===")

    # Case 1: no_error
    case1_dir = os.path.join(base_vectors_dir, "no_error")
    data_1 = [1, 2, 3]
    cw_1 = rs_encode(data_1)
    write_hex_file(os.path.join(case1_dir, "input_data.hex"), data_1)
    write_hex_file(os.path.join(case1_dir, "encoded_data.hex"), cw_1)
    write_hex_file(os.path.join(case1_dir, "corrupted_data.hex"), cw_1)
    write_hex_file(os.path.join(case1_dir, "expected_codeword.hex"), cw_1)

    # Case 2: one_error (tai symbol cuoi index=4, trong nguong T=1)
    case2_dir = os.path.join(base_vectors_dir, "one_error")
    data_2 = [1, 2, 3]
    cw_2 = rs_encode(data_2)
    corrupted_2 = list(cw_2)
    corrupted_2[4] ^= 5
    write_hex_file(os.path.join(case2_dir, "input_data.hex"), data_2)
    write_hex_file(os.path.join(case2_dir, "encoded_data.hex"), cw_2)
    write_hex_file(os.path.join(case2_dir, "corrupted_data.hex"), corrupted_2)
    write_hex_file(os.path.join(case2_dir, "expected_codeword.hex"), cw_2)
    dec_cw_2, err_cnt_2, fail_2 = rs_decode(corrupted_2)
    assert not fail_2 and err_cnt_2 == 1 and dec_cw_2 == cw_2

    # Case 3: parity_error (1 loi trong parity index=3)
    case3_dir = os.path.join(base_vectors_dir, "parity_error")
    data_3 = [5, 6, 7]
    cw_3 = rs_encode(data_3)
    corrupted_3 = list(cw_3)
    corrupted_3[3] ^= 6
    write_hex_file(os.path.join(case3_dir, "input_data.hex"), data_3)
    write_hex_file(os.path.join(case3_dir, "encoded_data.hex"), cw_3)
    write_hex_file(os.path.join(case3_dir, "corrupted_data.hex"), corrupted_3)
    write_hex_file(os.path.join(case3_dir, "expected_codeword.hex"), cw_3)
    dec_cw_3, err_cnt_3, fail_3 = rs_decode(corrupted_3)
    assert not fail_3 and err_cnt_3 == 1 and dec_cw_3 == cw_3

    # Case 4: two_errors (2 loi vuot nguong T=1)
    case4_dir = os.path.join(base_vectors_dir, "two_errors")
    data_4 = [1, 2, 3]
    cw_4 = rs_encode(data_4)
    corrupted_4 = list(cw_4)
    corrupted_4[3] ^= 2
    corrupted_4[4] ^= 5
    write_hex_file(os.path.join(case4_dir, "input_data.hex"), data_4)
    write_hex_file(os.path.join(case4_dir, "encoded_data.hex"), cw_4)
    write_hex_file(os.path.join(case4_dir, "corrupted_data.hex"), corrupted_4)
    write_hex_file(os.path.join(case4_dir, "expected_codeword.hex"), cw_4)

    # Case 5: beyond_capacity (3 loi tai 3 symbol cuoi > T=1)
    case5_dir = os.path.join(base_vectors_dir, "beyond_capacity")
    data_5 = [1, 2, 3]
    cw_5 = rs_encode(data_5)
    corrupted_5 = list(cw_5)
    corrupted_5[2] ^= 1
    corrupted_5[3] ^= 2
    corrupted_5[4] ^= 3
    write_hex_file(os.path.join(case5_dir, "input_data.hex"), data_5)
    write_hex_file(os.path.join(case5_dir, "encoded_data.hex"), cw_5)
    write_hex_file(os.path.join(case5_dir, "corrupted_data.hex"), corrupted_5)
    dec_cw_5, l_deg_5, fail_5 = rs_decode(corrupted_5)
    case_info = {
        "description": "Vuot qua kha nang sua loi (3 loi > T=1)",
        "code_parameters": {"n": RS_N, "k": RS_K, "r": RS_R, "t": RS_T},
        "errors_injected": [
            {"index": 2, "xor_mask": 1, "original_symbol": cw_5[2]},
            {"index": 3, "xor_mask": 2, "original_symbol": cw_5[3]},
            {"index": 4, "xor_mask": 3, "original_symbol": cw_5[4]},
        ],
        "expected_behavior": {
            "decoder_result_fail": fail_5,
            "decoded_matches_original": dec_cw_5 == cw_5,
            "lambda_degree": l_deg_5,
        },
    }
    with open(os.path.join(case5_dir, "case_info.json"), "w", encoding="utf-8") as f:
        json.dump(case_info, f, indent=4, ensure_ascii=False)

    write_readme_vectors(base_vectors_dir)
    print("[PASS] Toan bo vector kiem thu RS(5,3) da duoc tao thanh cong!")


if __name__ == "__main__":
    generate_all_vectors()
