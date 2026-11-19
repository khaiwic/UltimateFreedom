# Du lieu kiem thu Reed-Solomon RS(5,3) tren GF(8)

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
