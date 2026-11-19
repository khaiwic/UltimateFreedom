# Bộ giải mã Reed–Solomon RS(5,3) — `rs_decoder`

Module `rs_decoder` thực hiện giải mã và sửa tối đa $T = 1$ symbol lỗi cho từ mã **RS(5,3)** (5 symbol 3-bit, tổng 15-bit) trên trường **GF(8)**.

## 1. Thông số kỹ thuật

| Thông số | Giá trị | Ý nghĩa |
|---|---|---|
| Kích thước symbol $m$ | `3` bit | Phần tử $\text{GF}(8)$ (`0..7`), $p(u) = u^3 + u + 1$ |
| Độ dài từ mã $N$ | `5` symbol | 15-bit `rx_in[14:0]` |
| Độ dài dữ liệu $K$ | `3` symbol | 3 symbol dữ liệu gốc |
| Số parity $R = N - K$ | `2` symbol | 2 symbol kiểm tra |
| Khả năng sửa lỗi $T$ | `1` symbol | Sửa 1 symbol lỗi bất kỳ ở cả phần dữ liệu và parity |

## 2. Giao tiếp cổng

```verilog
module rs_decoder (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        start,
    input  wire [14:0] rx_in,

    output wire        busy,
    output reg         done,
    output reg         fail,
    output reg  [14:0] corr_out
);
```

## 3. Luồng xử lý 5 bước (FSM)

1. **`S_IDLE`**: Đợi xung `start`, chốt `rx_in` vào `rx_buf` và kích hoạt khối `syndrome`.
2. **`S_SYN`**: Tính 2 giá trị $S_0, S_1$ qua 5 chu kỳ bằng sơ đồ Horner (`syndrome.v`). Nếu $S_0 = S_1 = 0$, chuyển thẳng về `S_IDLE` với `fail = 0` (Fast-path).
3. **`S_BM`**: Chạy thuật toán Berlekamp–Massey (`berlekamp_massey.v`) tìm $\Lambda(z)$ và bậc $L$. Nếu $L = 0$ hoặc $L > 1$, báo `fail = 1`.
4. **`S_OMEGA`**: Tính đa thức đánh giá lỗi $\Omega(z) = [S(z)\Lambda(z)] \bmod z^2$ (`error_evaluator.v`).
5. **`S_CHIEN`**: Quét 5 vị trí truyền $i = 0..4$ với `Z_INIT = 3'd3` ($\alpha^{-4}$) (`chien_search.v`). Nếu số nghiệm khác $L$, báo `fail = 1`.
6. **`S_FORNEY`**: Tính giá trị lỗi $E_i = X_i \cdot \Omega(z_i) / \Lambda'(z_i)$ với `X_INIT = 3'd6`, `ALPHA_INV = 3'd5` (`forney.v`), rồi XOR khôi phục từ mã `corr_out <= rx_buf ^ forney_val_out`.
