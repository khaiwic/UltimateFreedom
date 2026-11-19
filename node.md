# Ghi chú kiến trúc nhanh: RS(5,3) trên GF(8)

- Trường Galois: GF(8), $m = 3$ bit, $p(x) = x^3 + x + 1$ (`4'b1011`), $\alpha = 2$.
- Mã Reed-Solomon: RS(5,3) với $N = 5$, $K = 3$, $R = 2$, $T = 1$, $g(x) = x^2 + 3x + 2$.
- Giao diện DE10-Lite:
  - `SW[2:0]`: nhập giá trị symbol (`0..7`), chốt bằng `KEY[1]`.
  - `SW[9]`: `0` = chế độ nhập 3 symbol thông tin và giải mã đúng; `1` = chế độ nhập tối đa 3 lỗi vào 3 symbol cuối (`SW[8]=1` để kết thúc sớm sau 1 hoặc 2 lỗi).
  - `HEX2`, `HEX1`, `HEX0`: hiển thị đồng thời 3 symbol thông tin (`0..7`).
  - `LEDR[9:0]`: sáng 1 đèn theo giá trị `SW[2:0]` khi nhập; sau khi giải mã ở chế độ lỗi: tắt hết nếu giải mã đúng, nhấp nháy toàn bộ `LEDR[9:0]` nếu giải mã sai.
