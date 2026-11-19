# Cấu hình RS(5,3) và quy ước toán học trên GF(8)

Tài liệu này quy định các tham số toán học thống nhất giữa RTL ([`rtl/include/rs_params.vh`](../rtl/include/rs_params.vh)), mô hình Python và testbench cho hệ thống **RS(5,3) trên GF(8)**.

## 1. Bảng tham số chuẩn

| Macro trong header | Giá trị | Ý nghĩa |
| --- | --- | --- |
| `RS_M` | `3` | Số bit mỗi symbol |
| `GF_SIZE` | `8` | Số phần tử của $\text{GF}(2^3)$ |
| `GF_ORDER` | `7` | Số phần tử khác 0, độ dài mã cha RS(7,5) |
| `GF_PRIM_POLY` | `4'b1011` | Đa thức nguyên thủy $p(u) = u^3 + u + 1$ |
| `GF_ALPHA` | `3'd2` | Phần tử nguyên thủy $\alpha = u$ |
| `RS_N` | `5` | Độ dài từ mã truyền (5 symbol = 15 bit) |
| `RS_K` | `3` | Số symbol dữ liệu gốc (3 symbol = 9 bit) |
| `RS_R` | `2` | Số symbol parity ($R = N - K$) |
| `RS_T` | `1` | Khả năng sửa tối đa $T = \lfloor R/2 \rfloor = 1$ symbol lỗi |
| `RS_FIRST_ROOT` | `0` | Số mũ nghiệm đầu của $g(x)$ |
| `RS_ROOT_STEP` | `1` | Bước tăng số mũ nghiệm |

## 2. Trường GF(8)

- Đa thức nguyên thủy: $p(u) = u^3 + u + 1$ (phần thấp 3-bit là `3'b011 = 3'd3`).
- Các lũy thừa của $\alpha = 2$:
  - $\alpha^0 = 1$, $\alpha^1 = 2$, $\alpha^2 = 4$, $\alpha^3 = 3$, $\alpha^4 = 6$, $\alpha^5 = 7$, $\alpha^6 = 5$, $\alpha^7 = 1$.
- Nghịch đảo nhân:
  - $\text{inv}(0) = 0$ (`zero_err = 1`), $\text{inv}(1) = 1$, $\text{inv}(2) = 5$, $\text{inv}(3) = 6$, $\text{inv}(4) = 7$, $\text{inv}(5) = 2$, $\text{inv}(6) = 3$, $\text{inv}(7) = 4$.

## 3. Đa thức sinh và quy ước từ mã

- Đa thức sinh ($F = 0$, $R = 2$):
  $$g(x) = (x + \alpha^0)(x + \alpha^1) = (x + 1)(x + 2) = x^2 + 3x + 2$$
- Từ mã systematic 15-bit gồm 5 symbol `[sym0, sym1, sym2, p0, p1]`:
  - `code_out[2:0]` = `sym0`, `code_out[5:3]` = `sym1`, `code_out[8:6]` = `sym2`, `code_out[11:9]` = `p0`, `code_out[14:12]` = `p1`.
- Ví dụ chuẩn: dữ liệu `[1, 2, 3]` $\rightarrow$ parity `[4, 4]` $\rightarrow$ từ mã `[1, 2, 3, 4, 4]`.

## 4. Quy ước Chien Search và Forney

- Tại vị trí truyền $i \in \{0..4\}$: $X_i = \alpha^{4-i}$, $z_i = X_i^{-1}$.
  - Tại $i = 0$: $X_0 = \alpha^4 = 6$, $z_0 = \alpha^{-4} = \alpha^3 = 3$.
  - Bước dịch mỗi chu kỳ: $X_{i+1} = X_i \cdot \alpha^{-1}$ ($\alpha^{-1} = 5$), $z_{i+1} = z_i \cdot \alpha$ ($\alpha = 2$).
- Công thức Forney với $F = 0$:
  $$E_i = X_i \cdot \frac{\Omega(z_i)}{\Lambda'(z_i)} = X_i \cdot \frac{\Omega_0 \oplus \Omega_1 z_i}{\lambda_1}$$
