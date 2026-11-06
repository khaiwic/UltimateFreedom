# Mô hình tham chiếu Reed–Solomon trên Python

Thư mục này chứa toàn bộ mô hình toán học và thuật toán tham chiếu độc lập cho hệ thống mã hóa/giải mã Reed–Solomon (RS) trên GF(256), phục vụ kiểm chứng theo yêu cầu trong [README_RS_DE10_Lite.md](../README_RS_DE10_Lite.md) và các tài liệu đặc tả tại [`docs/`](../docs/).

## 1. Cấu trúc thư mục

```text
model/
├── gf256_model.py       # Mô hình các phép toán số học trong trường GF(256)
├── rs_reference.py      # Mô hình tham chiếu encoder và decoder RS(15,11)
├── generate_vectors.py  # Script sinh tự động các file vector kiểm thử (.hex)
└── README.md            # Tài liệu hướng dẫn sử dụng và quy ước tham số
```

## 2. Quy ước toán học và tham số

Mô hình tuân thủ tuyệt đối các quy ước đã thống nhất tại [`rs_params.vh`](../rtl/include/rs_params.vh), [`docs/gf256.md`](../docs/gf256.md) và [`docs/rs_algorithm.md`](../docs/rs_algorithm.md):

| Tham số | Giá trị | Ý nghĩa |
|---|---|---|
| Kích thước trường $m$ | `8` bit | Mỗi symbol là một byte (`0x00` .. `0xFF`) |
| Đa thức trường $p(u)$ | `0x11D` | $p(u) = u^8 + u^4 + u^3 + u^2 + 1$ (phần thấp `0x1D`) |
| Phần tử nguyên thủy $\alpha$ | `0x02` | $\alpha = u$, chu kỳ 255 phần tử khác 0 |
| Độ dài từ mã $N$ | `15` symbol | Từ mã RS rút ngắn từ mã cha RS(255,251) |
| Độ dài dữ liệu $K$ | `11` symbol | Số byte dữ liệu gốc đưa vào mã hóa |
| Số parity $R = N - K$ | `4` symbol | Số byte kiểm tra thêm vào cuối khối |
| Khả năng sửa lỗi $T$ | `2` symbol | Sửa tối đa 2 symbol lỗi bất kỳ trong từ mã 15 bytes |
| Nghiệm đầu $F$ | `0` | Nghiệm đầu của $g(x)$ là $\alpha^0 = 0x01$ |
| Bước số mũ | `1` | Các nghiệm là $\alpha^0, \alpha^1, \alpha^2, \alpha^3$ |

### Quy ước thứ tự byte và mảng
- **Từ mã $c(x)$:** Hệ số bậc cao trước. $c[0]$ tương ứng với $x^{N-1} = x^{14}$ truyền đầu tiên; $c[N-1]$ là hệ số tự do $x^0$ truyền cuối cùng.
  - $c[0..10]$: 11 byte dữ liệu gốc (mã systematic).
  - $c[11..14]$: 4 byte parity.
- **Đa thức sinh $g(x)$:** Hệ số bậc cao trước:
  $$g(x) = (x + 01)(x + 02)(x + 04)(x + 08) = x^4 + 0F x^3 + 36 x^2 + 78 x + 40$$
  Mảng hệ số: `[0x01, 0x0F, 0x36, 0x78, 0x40]`.
- **Syndrome, $\Lambda(z)$, $\Omega(z)$:** Mảng lưu theo thứ tự bậc thấp trước:
  - $S(z) = S[0] + S[1] z + S[2] z^2 + S[3] z^3$
  - $\Lambda(z) = 1 + \lambda_1 z + \lambda_2 z^2$
  - $\Omega(z) = [S(z) \cdot \Lambda(z)] \pmod{z^R}$
- **Vị trí lỗi (Chien search):** Tại vị trí truyền $i \in [0, N-1]$:
  $$X_i = \alpha^{N-1-i} = \alpha^{14-i}, \quad z_i = X_i^{-1}$$
  Nghiệm thỏa mãn $\Lambda(z_i) = 0$.
- **Thuật toán Forney:** Với $F = 0$, công thức tính giá trị lỗi có nhân thêm $X_i$:
  $$E_i = X_i \cdot \frac{\Omega(z_i)}{\Lambda'(z_i)}$$
  trong đó $\Lambda'(z)$ là đạo hàm hình thức trong đặc số 2 (chỉ giữ các số hạng bậc lẻ).

## 3. Mô tả chi tiết từng file

### 3.1. `gf256_model.py`
Cung cấp toàn bộ các hàm toán học trường Galois GF(256):
- `gf_add(a, b)`, `gf_sub(a, b)`: Cộng/trừ (XOR từng bit).
- `gf_mul(a, b)`: Nhân theo bảng tra log/exp hoặc thuật toán dịch-và-cộng `gf_mul_shift`.
- `gf_inv(a)`: Nghịch đảo nhân (tính theo $a^{254}$, báo `ZeroDivisionError` nếu $a = 0$).
- `gf_div(a, b)`: Chia hai phần tử GF(256).
- `gf_pow(a, exp)`, `alpha_pow(exp)`: Lũy thừa phần tử và lũy thừa của $\alpha$ (hỗ trợ số mũ âm).
- Lớp `GF256`: Đóng gói phần tử trường với các toán tử nạp chồng `+`, `-`, `*`, `/`, `**`.

### 3.2. `rs_reference.py`
Triển khai toàn bộ luồng mã hóa và giải mã RS theo chuẩn:
- `rs_encode(data)`: Nhận 11 byte dữ liệu, tính 4 byte parity bằng phép chia đa thức modulo $g(x)$, trả về từ mã 15 byte.
- `calc_syndromes(received)`: Tính 4 syndrome bằng thuật toán Horner theo thứ tự truyền.
- `berlekamp_massey(syndromes)`: Giải phương trình khóa tìm đa thức định vị lỗi $\Lambda(z)$ và bậc $L$.
- `error_evaluator(syndromes, lambda_poly, l_deg)`: Tính đa thức đánh giá lỗi $\Omega(z)$.
- `chien_search(lambda_poly, l_deg)`: Quét tìm nghiệm trong phạm vi $i = 0..N-1$.
- `forney(lambda_poly, omega_poly, roots)`: Tính giá trị lỗi $E_i$ tại các vị trí tìm được.
- `rs_decode(received)`: Bộ giải mã trọn vẹn, trả về `(corrected_codeword, num_errors, fail_flag)`.

### 3.3. `generate_vectors.py`
Script sinh dữ liệu mẫu chuẩn cho mô phỏng RTL:
- Tạo các thư mục kiểm thử trong `vectors/`: `no_error`, `one_error`, `two_errors`, `parity_error`, `beyond_capacity`.
- Mỗi thư mục chứa các file `.hex` tương thích trực tiếp với lệnh `$readmemh` trong Verilog testbench.

## 4. Hướng dẫn chạy và kiểm thử

### Kiểm tra tính đúng đắn của trường GF(256)
Chạy lệnh kiểm tra 65,536 cặp nhân và toàn bộ các phép nghịch đảo:
```bash
python model/gf256_model.py
```

### Kiểm tra bộ mã hóa và giải mã tham chiếu
Chạy kiểm tra luồng mã hóa, giải mã và đối chiếu với ví dụ chuẩn trong tài liệu đặc tả (mục 12):
```bash
python model/rs_reference.py
```

### Tái sinh các vector kiểm thử cho Verilog
Tự động tính toán và ghi đè các file hex kiểm thử vào thư mục `vectors/`:
```bash
python model/generate_vectors.py
```

