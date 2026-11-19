# Mô hình tham chiếu Reed–Solomon RS(5,3) trên Python

Thư mục này chứa mô hình toán học độc lập cho hệ thống mã hóa và giải mã Reed–Solomon **RS(5,3)** trên trường hữu hạn **GF(8)**.

## 1. Cấu trúc thư mục

```text
model/
├── gf8_model.py         # Các phép toán trong GF(8), p(u) = u^3 + u + 1
├── gf256_model.py       # Chuyển tiếp tương thích sang gf8_model
├── rs_reference.py      # Mô hình tham chiếu encoder và decoder RS(5,3)
├── generate_vectors.py  # Script sinh tự động các file vector kiểm thử (.hex)
└── README.md            # Tài liệu hướng dẫn
```

## 2. Tham số toán học

| Tham số | Giá trị | Ý nghĩa |
|---|---|---|
| Kích thước symbol $m$ | `3` bit | Mỗi symbol thuộc $\text{GF}(8)$, giá trị `0..7` |
| Đa thức trường $p(u)$ | `4'b1011` (`0xB`) | $p(u) = u^3 + u + 1$ |
| Phần tử nguyên thủy $\alpha$ | `2` | Chu kỳ 7 phần tử khác 0 |
| Độ dài từ mã $N$ | `5` symbol | Từ mã 15-bit |
| Độ dài dữ liệu $K$ | `3` symbol | 3 symbol thông tin (9-bit) |
| Số parity $R = N - K$ | `2` symbol | 2 symbol kiểm tra (6-bit) |
| Khả năng sửa lỗi $T$ | `1` symbol | Sửa tối đa 1 symbol lỗi bất kỳ |
| Đa thức sinh $g(x)$ | `x^2 + 3x + 2` | Nghiệm $\alpha^0=1, \alpha^1=2$ ($F=0$) |

## 3. Hướng dẫn chạy kiểm thử

```bash
python model/gf8_model.py
python model/rs_reference.py
python model/generate_vectors.py
```
