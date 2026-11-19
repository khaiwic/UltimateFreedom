# Reed–Solomon RS(5,3) trên DE10-Lite — Module và bảng chân

Tài liệu đặc tả kỹ thuật cho hệ thống mã hóa và giải mã **Reed–Solomon RS(5,3)** trên trường Galois **GF(8)** triển khai trên kit **Terasic DE10-Lite** (`10M50DAF484C7G`).

## 1. Thông số hệ thống

| Thông số | Giá trị | Ý nghĩa |
| --- |:---:| --- |
| Kích thước symbol `m` | **`3` bit** | Phần tử $\text{GF}(8)$, giá trị `0..7` |
| Độ dài từ mã `N` | **`5` symbol** | 15 bit (`[14:0]`) |
| Độ dài dữ liệu `K` | **`3` symbol** | 9 bit (`[8:0]`) |
| Số parity `R = N - K` | **`2` symbol** | 6 bit (`p0`, `p1`) |
| Khả năng sửa lỗi `T` | **`1` symbol** | Sửa tối đa $T = \lfloor R/2 \rfloor = 1$ symbol lỗi bất kỳ |
| Đa thức trường `p(u)` | **`4'b1011`** | $p(u) = u^3 + u + 1$, phần tử nguyên thủy $\alpha = 2$ |
| Đa thức sinh `g(x)` | **`x^2 + 3x + 2`** | Nghiệm $\alpha^0 = 1, \alpha^1 = 2$ ($F = 0$) |

## 2. Các module RTL chính

| Module / File RTL | Vai trò | Vị trí |
| --- | --- | --- |
| `gf8_mul.v` | Nhân hai phần tử 3-bit trong $\text{GF}(8)$ | `rtl/gf_arithmetic/` |
| `gf8_inv.v` | Nghịch đảo nhân trong $\text{GF}(8)$ (bảng tra 8 giá trị) | `rtl/gf_arithmetic/` |
| `rs_encoder.v` | Mã hóa systematic 3 symbol dữ liệu thành từ mã 5 symbol | `rtl/rs_encoder/` |
| `error_injector.v` | Chèn mặt nạ lỗi `err_syms[8:0]` vào 3 symbol cuối của từ mã | `rtl/demo/` |
| `syndrome.v` | Tính 2 syndrome $S_0, S_1$ bằng sơ đồ Horner | `rtl/rs_decoder/` |
| `berlekamp_massey.v` | Tìm đa thức định vị lỗi $\Lambda(z)$ và bậc $L$ | `rtl/rs_decoder/` |
| `error_evaluator.v` | Tính đa thức giá trị lỗi $\Omega(z)$ | `rtl/rs_decoder/` |
| `chien_search.v` | Quét 5 vị trí truyền tìm nghiệm $\Lambda(z_i) = 0$ | `rtl/rs_decoder/` |
| `forney.v` | Tính độ lớn lỗi $E_i = X_i \cdot \Omega(z_i) / \Lambda'(z_i)$ | `rtl/rs_decoder/` |
| `rs_decoder.v` | Điều phối chuỗi 5 bước giải mã và xuất từ mã sửa lỗi | `rtl/rs_decoder/` |
| `input_control.v` | Lọc dội phím `KEY[1]` và đồng bộ `SW[9:0]` | `rtl/board/` |
| `hex_decoder.v` | Giải mã symbol 3-bit (`0..7`) ra LED 7 đoạn | `rtl/board/` |
| `rs_controller.v` | Quản lý chế độ nhập thông tin (`SW[9]=0`), chế độ nhập lỗi (`SW[9]=1`), điều khiển `HEX2:HEX0` và `LEDR[9:0]` | `rtl/controller/` |
| `top_de10_lite.v` | Module Top-Level kết nối ngoại vi DE10-Lite và các lõi RS | `rtl/board/` |

## 3. Phân công ngoại vi trên board DE10-Lite

| Ngoại vi | Chân FPGA | Chức năng |
| --- | --- | --- |
| `MAX10_CLK1_50` | `PIN_P11` | Clock 50 MHz |
| `KEY[0]` | `PIN_B8` | Reset tích cực mức thấp |
| `KEY[1]` | `PIN_A7` | Chốt symbol / xác nhận giá trị lỗi |
| `SW[2:0]` | `PIN_C10, PIN_C11, PIN_D12` | Giá trị symbol 3-bit (`0..7`) hoặc mặt nạ lỗi |
| `SW[8]` | `PIN_B14` | Trong chế độ lỗi (`SW[9]=1`): `1` = kết thúc nhập lỗi sớm sau 1 hoặc 2 lần bấm |
| `SW[9]` | `PIN_F15` | `0` = Chế độ nhập thông tin & giải mã đúng; `1` = Chế độ nhập tối đa 3 lỗi vào 3 symbol cuối |
| `LEDR[9:0]` | `PIN_A8` .. `PIN_B11` | Đang nhập: sáng 1 đèn theo `SW[2:0]`. Sau giải mã lỗi: tắt hết nếu đúng; nhấp nháy toàn bộ nếu sai |
| `HEX0` | `PIN_C14` .. `PIN_D15` | Hiển thị symbol 2 (`0..7`) |
| `HEX1` | `PIN_C18` .. `PIN_A16` | Hiển thị symbol 1 (`0..7`) |
| `HEX2` | `PIN_B20` .. `PIN_A19` | Hiển thị symbol 0 (`0..7`) |
