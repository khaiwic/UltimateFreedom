# Hệ thống Mã hóa & Giải mã Reed–Solomon RS(5,3) trên FPGA Terasic DE10-Lite

Dự án thiết kế và triển khai hệ thống mã hóa và giải mã sửa sai **Reed–Solomon RS(5,3)** trên trường Galois $\text{GF}(8)$ bằng ngôn ngữ **Verilog HDL** cho kit **Terasic DE10-Lite** (`10M50DAF484C7G`), kèm mô hình tham chiếu **Python** và bộ 10 testbench mô phỏng.

---

## 1. Thông số kỹ thuật của hệ thống

| Thông số | Ký hiệu | Giá trị chuẩn | Ý nghĩa |
|---|:---:|:---:|---|
| Kích thước symbol | $m$ | **`3` bit** | Hoạt động trên trường $\text{GF}(8)$, mỗi symbol có giá trị `0..7` |
| Độ dài từ mã | $N$ | **`5` symbol** | 15 bit gồm 3 symbol thông tin + 2 symbol parity |
| Độ dài dữ liệu | $K$ | **`3` symbol** | 9 bit dữ liệu gốc |
| Số symbol kiểm tra | $R = N - K$ | **`2` symbol** | 6 bit parity |
| Khả năng sửa lỗi | $T = \lfloor R/2 \rfloor$ | **`1` symbol** | Sửa tối đa 1 symbol lỗi bất kỳ; $\ge 2$ lỗi vượt ngưỡng |
| Đa thức nguyên thủy | $p(u)$ | **`4'b1011`** | $p(u) = u^3 + u + 1$ (phần thấp `3'b011`) |
| Phần tử nguyên thủy | $\alpha$ | **`3'd2`** | Chu kỳ 7 phần tử khác 0 |
| Đa thức sinh | $g(x)$ | **`x^2 + 3x + 2`** | Nghiệm $\alpha^0 = 1, \alpha^1 = 2$ ($F = 0$) |

---

## 2. Cấu trúc thư mục chính

- [`rtl/`](file:///d:/UltimateFreedom/UltimateFreedom/rtl): Mã nguồn Verilog HDL (`rs_params.vh`, `gf8_mul.v`, `gf8_inv.v`, `rs_encoder.v`, `error_injector.v`, `syndrome.v`, `berlekamp_massey.v`, `error_evaluator.v`, `chien_search.v`, `forney.v`, `rs_decoder.v`, `uart_tx.v`, `uart_logger.v`, `rs_controller.v`, `input_control.v`, `hex_decoder.v`, `top_de10_lite.v`).
- [`tb/`](file:///d:/UltimateFreedom/UltimateFreedom/tb): 11 testbench độc lập (`tb_gf8_mul.v`, `tb_gf8_inv.v`, `tb_rs_encoder.v`, `tb_syndrome.v`, `tb_berlekamp_massey.v`, `tb_error_evaluator.v`, `tb_chien_search.v`, `tb_forney.v`, `tb_rs_decoder.v`, `tb_uart_tx.v`, `tb_top.v`).
- [`model/`](file:///d:/UltimateFreedom/UltimateFreedom/model): Mô hình tham chiếu Python (`gf8_model.py`, `rs_reference.py`, `generate_vectors.py`).
- [`vectors/`](file:///d:/UltimateFreedom/UltimateFreedom/vectors): Các bộ vector kiểm thử sinh tự động.
- [`sim/`](file:///d:/UltimateFreedom/UltimateFreedom/sim): Kịch bản biên dịch và mô phỏng ModelSim / QuestaSim (`rtl_files.f`, `run.do`, `wave.do`).
- [`quartus/`](file:///d:/UltimateFreedom/UltimateFreedom/quartus): Project tổng hợp Quartus Prime (`ReedSolomon.qpf`, `ReedSolomon.qsf`, `timing.sdc`).

---

## 3. Phân công ngoại vi trên kit DE10-Lite

| Ngoại vi | Chức năng |
|---|---|
| `KEY[0]` | Reset toàn bộ hệ thống (tích cực mức thấp) |
| `KEY[1]` | Chốt từng symbol / xác nhận giá trị lỗi (có lọc dội 10 ms) |
| `SW[2:0]` | Đặt giá trị symbol 3-bit (`0..7`) hoặc mặt nạ lỗi |
| `SW[8]` | Trong chế độ lỗi (`SW[9]=1`): kéo lên `1` ở lần bấm thứ 1 hoặc 2 để kết thúc nhập lỗi sớm |
| `SW[9]` | `0` = Chế độ nhập 3 symbol thông tin & giải mã đúng; `1` = Chế độ nhập tối đa 3 lỗi vào 3 symbol cuối |
| `HEX2`, `HEX1`, `HEX0` | Hiển thị đồng thời 3 symbol thông tin (`HEX2`: symbol 0, `HEX1`: symbol 1, `HEX0`: symbol 2) |
| `LEDR[9:0]` | Khi đang nhập: sáng 1 đèn theo giá trị `SW[2:0]` (`1 << SW[2:0]`). Sau giải mã ở chế độ lỗi: **tắt hết** nếu giải mã đúng; **nhấp nháy cả 10 LED** nếu giải mã sai |
| `UART_TX` | Chân `PIN_W10` (`JP1 Pin 2` $\rightarrow$ `CP2101 RXD`): tự động gửi log từng bước giải mã (`115200 bps`, `8N1`) lên phần mềm **Hercules** trên PC |

---

## 4. Hướng dẫn vận hành nhanh trên board

1. **Pha nhập thông tin (`SW[9] = 0`)**:
   - Lần lượt đặt `SW[2:0]` cho 3 symbol (ví dụ `1`, `2`, `3`), sau mỗi symbol bấm `KEY[1]`.
   - Khi đang gạt `SW[2:0]`, đèn `LEDR[SW[2:0]]` sáng tương ứng.
   - Sau lần bấm thứ 3, mạch tự động mã hóa RS(5,3) và giải mã không lỗi, hiển thị `1 2 3` trên `HEX2 HEX1 HEX0`.
2. **Pha nhập lỗi (`SW[9] = 1`)**:
   - Gạt `SW[9]` lên `1` để chuyển sang chế độ nhập lỗi.
   - Nhấn `KEY[1]` tối đa 3 lần để nạp lỗi vào 3 symbol cuối cùng của từ mã (lần 1 vào symbol 4, lần 2 vào symbol 3, lần 3 vào symbol 2; có thể gạt `SW[8] = 1` để kích hoạt giải mã sớm sau 1 hoặc 2 lần bấm).
   - Kết thúc nhập lỗi, mạch tự động giải mã:
     - Nếu có $\le 1$ symbol lỗi (giải mã đúng): toàn bộ `LEDR[9:0]` **tắt hết**, `HEX2:HEX0` vẫn hiển thị đúng `1 2 3`.
     - Nếu có $\ge 2$ symbol lỗi (giải mã sai / vượt ngưỡng $T=1$): toàn bộ `LEDR[9:0]` **nhấp nháy cảnh báo**.
   - Bấm `KEY[1]` lại khi đang xem kết quả lỗi để thực hiện lượt thử lỗi mới, hoặc gạt `SW[9] = 0` để nhập bộ thông tin mới.
