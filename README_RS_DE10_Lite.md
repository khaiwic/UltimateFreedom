# Reed–Solomon trên DE10-Lite — Module và bảng chân

Tài liệu thiết kế và đặc tả kỹ thuật cho bài tập lớn triển khai bộ mã hóa và giải mã Reed–Solomon (RS) trong GF(256) trên kit phát triển Terasic DE10-Lite bằng Verilog HDL và Quartus Prime.

> **Trạng thái**: Các thông số kiến trúc đã được chốt và thống nhất. Toàn bộ các module số học GF(256), bộ mã hóa (`rs_encoder`), các khối con giải mã và bộ giải mã tích hợp (`rs_decoder`), cùng các khối giao tiếp ngoại vi (`hex_decoder`, `display_control`, `reset_sync`, `data_buffer`) đã được triển khai, kiểm chứng độc lập với mô hình Python và đạt 100% testbench mô phỏng.

---

## 1. Phạm vi và mục tiêu

- **Mã hóa systematic**: Nhận $K$ byte dữ liệu gốc, tính toán $R$ byte kiểm tra (parity) và xuất từ mã $N$ byte.
- **Tạo lỗi có kiểm soát**: Cho phép thử nghiệm tiêm lỗi ngẫu nhiên hoặc có chủ đích để kiểm tra khả năng sửa sai.
- **Giải mã và sửa lỗi tự động**: Tích hợp chuỗi thuật toán Syndrome $\rightarrow$ Berlekamp–Massey $\rightarrow$ Error Evaluator $\rightarrow$ Chien Search $\rightarrow$ Forney $\rightarrow$ Error Corrector $\rightarrow$ Re-verify.
- **Giao tiếp ngoại vi trực quan**:
  - Nhập từng symbol 8-bit bằng thanh Switch `SW[7:0]`, chốt bằng nút nhấn `KEY[1]`.
  - Hiển thị trực tiếp từng byte dữ liệu/kết quả dạng hexadecimal bằng hai LED 7 đoạn `HEX1:HEX0`.
  - Theo dõi tiến trình qua LED đỏ trạng thái: `LEDR[0]` (Busy), `LEDR[1]` (Done đã chốt), `LEDR[2]` (Fail đã chốt).
- **Clock hệ thống**: Dùng nguồn clock 50 MHz (`MAX10_CLK1_50`, chu kỳ 20 ns).

### Bảng thông số kỹ thuật chuẩn của hệ thống:

| Thông số | Giá trị chuẩn | Ý nghĩa | Trạng thái |
| --- |:---:| --- |:---:|
| Kích thước symbol `m` | **`8` bit** | Làm việc trong trường Galois GF(256), mỗi symbol là 1 byte | **Đã chốt** |
| Độ dài từ mã `n` | **`15` symbol** | Mã rút ngắn từ mã cha RS(255, 251) | **Đã chốt** |
| Độ dài dữ liệu `k` | **`11` symbol** | Số symbol dữ liệu gốc trong một khối mã | **Đã chốt** |
| Số parity `r = n - k` | **`4` symbol** | Số symbol kiểm tra redundancy thêm vào cuối khối | **Đã chốt** |
| Khả năng sửa lỗi `t` | **`2` symbol** | Sửa tối đa $t = \lfloor (n-k)/2 \rfloor = 2$ symbol lỗi bất kỳ trong từ mã 15 bytes | **Đã chốt** |
| Đa thức trường `p(u)` | **`9'h11D`** | $p(u) = u^8 + u^4 + u^3 + u^2 + 1$ (phần thấp 8-bit: `8'h1D`) | **Đã chốt** |
| Phần tử nguyên thủy `alpha` | **`8'h02`** | $\alpha = u$, chu kỳ 255 phần tử khác 0 | **Đã chốt** |
| Nghiệm đầu của `g(x)` | **`0`** | $g(x) = \prod_{j=0}^{R-1} (x + \alpha^{F + j})$ với $F = 0$ | **Đã chốt** |
| Bước số mũ nghiệm | **`1`** | Các nghiệm là $\alpha^0, \alpha^1, \alpha^2, \alpha^3$ | **Đã chốt** |
| Đa thức sinh $g(x)$ | **`x^4 + 0Fx^3 + 36x^2 + 78x + 40`** | Hệ số mảng: `[0x01, 0x0F, 0x36, 0x78, 0x40]` | **Đã chốt** |
| Thứ tự truyền / lưu trữ | **Hệ số bậc cao trước** | $c[0]$ tương ứng $x^{N-1} = x^{14}$ truyền đầu; $c[N-1]$ tương ứng $x^0$ truyền cuối | **Đã chốt** |

---

## 2. Các module RTL chính trong dự án

| Module / File RTL | Vai trò | Vị trí thư mục | Trạng thái |
| --- | --- | --- |:---:|
| `gf256_add.v` | Cộng/trừ trong GF(256) (phép XOR từng bit) | `rtl/gf_arithmetic/` | **Hoàn thành** |
| `gf256_mul.v` | Nhân hai phần tử GF(256) (logic tổ hợp 8 bước dịch và rút gọn) | `rtl/gf_arithmetic/` | **Hoàn thành** |
| `gf256_inv.v` | Nghịch đảo nhân $a^{-1} = a^{254}$ trong GF(256) qua LUT 256 byte | `rtl/gf_arithmetic/` | **Hoàn thành** |
| `rs_encoder.v` | Nhận 11 byte dữ liệu, tính 4 byte parity qua LFSR, xuất từ mã 15 byte | `rtl/rs_encoder/` | **Hoàn thành** |
| `syndrome.v` | Tính $R=4$ syndrome $S[0..3]$ từ chuỗi 15 symbol bằng thuật toán Horner | `rtl/rs_decoder/` | **Hoàn thành** |
| `berlekamp_massey.v` | Tìm đa thức định vị lỗi $\Lambda(z)$ và bậc $L$ qua thuật toán BM | `rtl/rs_decoder/` | **Hoàn thành** |
| `error_evaluator.v` | Tính đa thức đánh giá lỗi $\Omega(z) = [S(z) \cdot \Lambda(z)] \bmod z^R$ | `rtl/rs_decoder/` | **Hoàn thành** |
| `chien_search.v` | Quét nghiệm của $\Lambda(z)$ tại 15 vị trí truyền ($X_i = \alpha^{14-i}$) | `rtl/rs_decoder/` | **Hoàn thành** |
| `forney.v` | Tính giá trị lỗi $E_i = X_i \cdot \frac{\Omega(z_i)}{\Lambda'(z_i)}$ ($F=0$) | `rtl/rs_decoder/` | **Hoàn thành** |
| `error_corrector.v` | XOR giá trị lỗi vào các symbol nhận để khôi phục từ mã | `rtl/rs_decoder/` | **Hoàn thành** |
| `rs_decoder.v` | Bộ giải mã tích hợp điều phối toàn bộ các khối con và kiểm tra lại | `rtl/rs_decoder/` | **Hoàn thành** |
| `data_buffer.v` | Bộ đệm lưu dữ liệu gốc và từ mã (hỗ trợ streaming và random access) | `rtl/memory/` | **Hoàn thành** |
| `reset_sync.v` | Bộ đồng bộ reset 2 tầng flip-flop cho nút nhấn `KEY[0]` | `rtl/board/` | **Hoàn thành** |
| `hex_decoder.v` | Giải mã 4-bit nibble sang mẫu LED 7 đoạn (tích cực thấp, DP tắt) | `rtl/board/` | **Hoàn thành** |
| `display_control.v` | Chọn byte cần xem, chốt LEDR (Busy, Done, Fail) và điều khiển HEX1:HEX0 | `rtl/board/` | **Hoàn thành** |
| `input_control.v` | Lọc dội phím (debounce) và đồng bộ Switch/Button | `rtl/board/` | **Hoàn thành** |
| `rs_controller.v` | Bộ điều phối toàn bộ chuỗi giao dịch demo và pipeline mã hóa/giải mã | `rtl/controller/` | **Hoàn thành** |
| `top_de10_lite.v` | Module Top-Level kết nối ngoại vi board DE10-Lite, controller và lõi RS | `rtl/board/` | **Hoàn thành** |

---

## 3. Luồng xử lý và giao diện bắt tay nội bộ

Luồng hoạt động chuẩn của hệ thống:
1. **Pha nhập (Input Phase)**: Nhập $K=11$ symbol qua switch `SW[7:0]`, nhấn `KEY[1]` để chốt từng symbol vào bộ đệm `data_buffer`.
2. **Pha mã hóa (Encoding)**: `rs_encoder` đọc 11 byte dữ liệu, tính 4 byte parity và tạo từ mã $N=15$ byte.
3. **Pha tạo lỗi (Error Injection - Tùy chọn)**: Nếu gạt switch `SW[9] = 1`, bộ tiêm lỗi XOR mặt nạ lỗi vào một số symbol được chọn để thử nghiệm.
4. **Pha giải mã (Decoding)**: `rs_decoder` nhận từ mã và tiến hành sửa lỗi theo 2 nhánh:
   - **Nhánh không lỗi (Fast-path)**: Nếu toàn bộ 4 syndrome $S[0..3] = 0$, giữ nguyên từ mã nhận, chuyển thẳng sang xuất kết quả (`fail = 0`).
   - **Nhánh có lỗi**: Thực hiện tuần tự Berlekamp–Massey $\rightarrow$ Error Evaluator $\rightarrow$ Chien Search $\rightarrow$ Forney $\rightarrow$ Error Corrector, sau đó tính lại syndrome trên từ mã đã sửa để xác nhận thành công hay thất bại.
5. **Pha xuất & hiển thị (Output & Display)**: Dữ liệu được ghi vào bộ đệm kết quả, người dùng có thể duyệt từng byte để xem trên 2 LED 7 đoạn `HEX1:HEX0`.

### Giao thức bắt tay Streaming:
- Mỗi symbol được chấp nhận tại cạnh lên clock khi `valid && ready`.
- Nguồn phát giữ nguyên dữ liệu trong suốt thời gian `valid = 1` nhưng `ready = 0` (hỗ trợ backpressure đầy đủ).
- Tín hiệu `busy = 1` từ lúc bắt đầu nhận `start` đến khi hoàn tất.
- Tín hiệu `done` phát xung 1 chu kỳ ngay khi symbol cuối cùng được nhận ở đầu ra.
- Tín hiệu `fail` báo trạng thái thất bại được `display_control` chốt lại trên LED đỏ để người dùng quan sát.

---

## 4. Phân công ngoại vi trên board DE10-Lite

| Ngoại vi | Chân FPGA | I/O Standard | Chức năng hoạt động |
| --- |:---:|:---:| --- |
| `MAX10_CLK1_50` | `PIN_P11` | 3.3-V LVTTL | Nguồn xung nhịp hệ thống 50 MHz (chu kỳ 20.0 ns) |
| `KEY[0]` | `PIN_B8` | 3.3 V SCHMITT TRIGGER | Nút nhấn Reset hệ thống (tích cực thấp: nhấn = 0, thả = 1) |
| `KEY[1]` | `PIN_A7` | 3.3 V SCHMITT TRIGGER | Xác nhận chốt 1 byte từ SW / Bắt đầu thao tác chạy |
| `SW[7:0]` | `PIN_C10` .. `PIN_A14` | 3.3-V LVTTL | Đặt giá trị 8-bit cho 1 symbol (gạt lên = 1, gạt xuống = 0) |
| `SW[8]` | `PIN_B14` | 3.3-V LVTTL | Chọn chế độ: `0` = Pha nhập dữ liệu, `1` = Pha xử lý / xem kết quả |
| `SW[9]` | `PIN_F15` | 3.3-V LVTTL | Cho phép tiêm lỗi: `0` = Giữ nguyên, `1` = Tạo lỗi thử nghiệm |
| `LEDR[0]` | `PIN_A8` | 3.3-V LVTTL | Đèn đỏ báo `Busy` (sáng khi mạch đang xử lý) |
| `LEDR[1]` | `PIN_A9` | 3.3-V LVTTL | Đèn đỏ báo `Done` (đã chốt sáng sau khi hoàn tất xử lý) |
| `LEDR[2]` | `PIN_A10` | 3.3-V LVTTL | Đèn đỏ báo `Fail` (đã chốt sáng nếu phát hiện giải mã thất bại) |
| `HEX1` | `PIN_C18` .. `PIN_A16` | 3.3-V LVTTL | Hiển thị 4 bit cao (MSB nibble) của byte đang xem |
| `HEX0` | `PIN_C14` .. `PIN_D15` | 3.3-V LVTTL | Hiển thị 4 bit thấp (LSB nibble) của byte đang xem |

---

## 5. Bảng chân chi tiết LED 7 đoạn HEX0 và HEX1

Cả hai bộ hiển thị đều tích cực mức thấp (`0` là sáng đoạn, `1` là tắt đoạn). Dấu chấm thập phân `DP` luôn đặt bằng `1'b1` (tắt).

| Chỉ số bit | Đoạn LED | Vị trí trên LED | Chân `HEX0` | Chân `HEX1` | Mẫu hiển thị ví dụ `8'hA7` |
|:---:|:---:|:---:|:---:|:---:|---|
| `[0]` | **a** | Cạnh trên | `PIN_C14` | `PIN_C18` | `HEX1` hiển thị chữ **A** (`8'h88`) |
| `[1]` | **b** | Cạnh phải trên | `PIN_E15` | `PIN_D18` | `HEX0` hiển thị số **7** (`8'hF8`) |
| `[2]` | **c** | Cạnh phải dưới | `PIN_C15` | `PIN_E18` | |
| `[3]` | **d** | Cạnh dưới | `PIN_C16` | `PIN_B16` | |
| `[4]` | **e** | Cạnh trái dưới | `PIN_E16` | `PIN_A17` | |
| `[5]` | **f** | Cạnh trái trên | `PIN_D17` | `PIN_A18` | |
| `[6]` | **g** | Vạch giữa | `PIN_C17` | `PIN_B17` | |
| `[7]` | **DP** | Dấu chấm | `PIN_D15` | `PIN_A16` | Luôn tắt (`1'b1`) |

---

## 6. Khai báo Top-Level và ràng buộc SDC

### Khung module Top-Level:
```verilog
module top_de10_lite (
    input  wire       MAX10_CLK1_50,
    input  wire [1:0] KEY,
    input  wire [9:0] SW,
    output wire [2:0] LEDR,
    output wire [7:0] HEX0,
    output wire [7:0] HEX1
);
    // Kết nối reset_sync, input_control, data_buffer, rs_controller,
    // rs_encoder, rs_decoder, display_control và hex_decoder tại đây.
endmodule
```

### Ràng buộc thời gian (Timing Constraint - SDC):
```tcl
create_clock -name sys_clk -period 20.000 [get_ports {MAX10_CLK1_50}]
derive_clock_uncertainty
```

---

## 7. Kế hoạch kiểm chứng và kết quả đạt được

Hệ thống được xác minh bằng 3 tầng kiểm chứng độc lập:
1. **Mô hình tham chiếu Python (`model/`)**:
   - `gf256_model.py`: Kiểm chứng $100\%$ đúng đắn cho $65,536$ phép nhân và toàn bộ phép nghịch đảo.
   - `rs_reference.py`: Mô phỏng thuật toán toán học, đối chiếu với chuẩn lý thuyết và sinh các vector kiểm thử mẫu (`vectors/`).
2. **Bộ Testbench Verilog (`tb/`)**:
   - `tb_gf256_mul`: **PASS** (72,820 kiểm tra).
   - `tb_gf256_inv`: **PASS** (1,538 kiểm tra).
   - `tb_rs_encoder`: **PASS** (921 kiểm tra).
   - `tb_syndrome`: **PASS** (3,341 kiểm tra).
   - `tb_berlekamp_massey`: **PASS** (10,437 kiểm tra).
   - `tb_error_evaluator`: **PASS** (2,971 kiểm tra).
   - `tb_chien_search`: **PASS** (2,834 kiểm tra).
   - `tb_forney`: **PASS** (5,525 kiểm tra).
   - `tb_rs_decoder`: **PASS** (4,465 kiểm tra).
   - `tb_top`: Kiểm tra giao dịch ngoại vi, nút bấm, debounce và LED hiển thị.
3. **Kiểm thử trên phần cứng thực tế**:
   - Chạy trên FPGA Cyclone 10 LP / MAX 10 `10M50DAF484C7G` với kit DE10-Lite.
