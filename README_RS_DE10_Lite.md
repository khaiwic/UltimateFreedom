# Reed–Solomon trên DE10-Lite — Module và bảng chân

Tài liệu thiết kế cho bài tập lớn triển khai Reed–Solomon (RS) trong GF(256) trên board Terasic DE10-Lite bằng Verilog/SystemVerilog và Quartus.

> Trạng thái: kiến trúc và phân công chân đề xuất. Tài liệu này chưa khẳng định các module RTL đã được viết, mô phỏng hoặc chạy trên board.

## 1. Phạm vi và mục tiêu

- Mã hóa dữ liệu thành từ mã RS.
- Tạo lỗi có kiểm soát để thử nghiệm.
- Giải mã và sửa lỗi nếu phạm vi bài tập yêu cầu decoder.
- Nhập từng symbol bằng switch; hiển thị một byte bằng hai LED 7 đoạn.
- Bổ sung UART khi cần truyền cả khối dữ liệu với máy tính.
- Dùng một clock hệ thống 50 MHz cho phiên bản đầu.

Mỗi symbol GF(256) có 8 bit, tương ứng một byte. Các khối GF và RS nằm bên trong FPGA; chúng kết nối bằng tín hiệu nội bộ, không cần chân ngoại vi riêng cho từng khối.

Các thông số phải chốt trước khi triển khai encoder và decoder:

| Thông số | Ý nghĩa | Trạng thái |
| --- | --- | --- |
| `m = 8` | Số bit/symbol, làm việc trong GF(256) | Đã xác định |
| `n` | Số symbol của một từ mã | Cần chốt |
| `k` | Số symbol dữ liệu gốc | Cần chốt |
| `r = n - k` | Số symbol kiểm tra | Theo n và k |
| Đa thức trường `p(u)` | Quy định phép nhân/rút gọn trong GF(256) | Cần thống nhất |
| Phần tử nguyên thủy `alpha` | Cơ sở biểu diễn các phần tử khác 0 dưới dạng lũy thừa | Cần thống nhất |
| Nghiệm đầu của `g(x)` | Quy ước xây dựng đa thức sinh và syndrome | Cần thống nhất |
| Thứ tự hệ số/symbol | Byte đầu tương ứng hệ số bậc cao hay thấp | Cần thống nhất |

Đối với RS thông dụng có độ dài tối đa 255 symbol trên GF(256), có thể dùng mã rút ngắn để thử nghiệm với khối nhỏ. Khi không biết trước vị trí lỗi, khả năng sửa lỗi bảo đảm là `t = floor((n-k)/2)` symbol mỗi từ mã.

## 2. Các module chính

| Module / file dự kiến | Vai trò | Phạm vi |
| --- | --- | --- |
| `top_de10_lite.v` | Kết nối clock, ngoại vi, bộ điều khiển và các khối RS | Bắt buộc |
| `gf_mul.v` | Nhân hai phần tử GF(256) | Encoder và decoder |
| `gf_inv.v` hoặc `gf_div.v` | Nghịch đảo/chia trong GF(256) | Tùy kiến trúc decoder |
| `rs_encoder.v` | Nhận k symbol, tính parity và xuất từ mã | Phần mã hóa |
| `rs_decoder.v` | Tích hợp các bước tìm và sửa lỗi | Phần giải mã |
| `data_buffer.v` | Lưu dữ liệu, từ mã và kết quả | Thanh ghi hoặc RAM M9K |
| `rs_controller.v` | Quản lý các pha nhập, xử lý, xuất và hoàn tất | Có thể phân tán vào từng khối |
| `input_control.v` | Đồng bộ đầu vào, xử lý nút nhấn, tạo xung xác nhận | Giao tiếp board |
| `hex_decoder.v` | Đổi 4 bit thành mẫu 7 đoạn từ 0 đến F | Dùng hai instance |
| `display_control.v` | Chọn byte cần xem, điều khiển HEX và LED trạng thái | Giao tiếp board |
| `error_injector.v` | XOR mặt nạ lỗi vào các symbol được chọn | Demo/kiểm chứng |
| `uart_rx.v`, `uart_tx.v` | Truyền byte với máy tính | Mở rộng |

Tên module là gợi ý tổ chức. Các khối nhỏ có thể gộp trong cùng file khi hợp lý.

### 2.1. Phép toán GF

- Cộng và trừ: XOR từng bit.
- Nhân: nhân đa thức nhị phân rồi rút gọn theo đa thức trường.
- Nghịch đảo chỉ xác định với phần tử khác 0.
- Các hệ số cố định, bảng lũy thừa hoặc bảng log có thể lưu trong ROM.
- Không dùng phép nhân số nguyên `a * b` để thay trực tiếp cho nhân GF(256).
- Không bắt buộc tạo module `gf_add`; có thể viết `assign sum = a ^ b;`.

### 2.2. Các khối bên trong decoder

| Module con | Chức năng | Kết quả chính |
| --- | --- | --- |
| `syndrome_calc.v` | Đánh giá đa thức nhận tại các nghiệm quy định | Các syndrome |
| `key_equation_solver.v` | Dùng Berlekamp–Massey hoặc Euclid | Đa thức định vị lỗi Lambda |
| `error_evaluator.v` | Tính đa thức đánh giá lỗi từ syndrome và Lambda | Đa thức Omega |
| `chien_search.v` | Tìm nghiệm của Lambda và ánh xạ sang vị trí symbol | Danh sách vị trí lỗi |
| `forney_calc.v` | Tính giá trị lỗi tại các vị trí tìm được | Giá trị lỗi |
| `error_corrector.v` | XOR giá trị lỗi vào symbol nhận | Từ mã đã hiệu chỉnh |

Khối tính Omega có thể gộp vào bộ giải phương trình khóa. Chọn một quy ước đa thức và ánh xạ vị trí thống nhất cho toàn bộ decoder.

`fail` biểu thị thất bại mà decoder phát hiện. Khi số lỗi vượt khả năng sửa, decoder có thể giải mã nhầm; không được xem `fail = 0` là bảo đảm khôi phục đúng dữ liệu gốc trong mọi trường hợp.

## 3. Luồng xử lý và giao diện nội bộ

Luồng demo dự kiến:

1. Nhập k symbol và lưu bản gốc.
2. Encoder tạo n symbol của từ mã.
3. Bộ tạo lỗi giữ nguyên hoặc thay đổi một số symbol.
4. Decoder nhận từ mã và tìm/sửa lỗi.
5. Xuất dữ liệu; khi kiểm thử, đối chiếu với bản gốc.

Nếu đầu vào đã là từ mã cần sửa, có thể đưa trực tiếp vào decoder.

| Tín hiệu | Ý nghĩa |
| --- | --- |
| `clk` | Clock hệ thống |
| `rst_n` | Reset nội bộ, mức thấp có hiệu lực |
| `data_in[7:0]` | Symbol đưa vào một khối |
| `in_valid`, `in_ready` | Bắt tay đầu vào |
| `data_out[7:0]` | Symbol đầu ra |
| `out_valid`, `out_ready` | Bắt tay đầu ra |
| `start` | Yêu cầu bắt đầu một thao tác |
| `busy` | Đang xử lý |
| `done` | Thao tác đã hoàn tất |
| `fail` | Phát hiện giải mã thất bại |

Một symbol được chấp nhận tại cạnh lên clock khi `valid && ready`. Nguồn giữ nguyên dữ liệu trong lúc `valid = 1` nhưng `ready = 0`. Quy ước `start/done` dạng xung phải được ghi rõ trong từng module.

Đèn trạng thái cần giữ thông tin đủ lâu để quan sát. Nếu `done` hoặc `fail` của lõi chỉ kéo dài một chu kỳ, `display_control` phải chốt lại trạng thái đó.

## 4. Phân công ngoại vi cho bản demo

| Ngoại vi | Chức năng đề xuất |
| --- | --- |
| `MAX10_CLK1_50` | Clock 50 MHz |
| `KEY[0]` | Reset |
| `KEY[1]` | Xác nhận nhập / bắt đầu thao tác, tùy trạng thái |
| `SW[7:0]` | Một byte dữ liệu |
| `SW[8]` | Chọn pha nhập hoặc chạy; tùy chọn |
| `SW[9]` | Cho phép tạo lỗi; tùy chọn |
| `LEDR[0]` | Busy |
| `LEDR[1]` | Done đã chốt để quan sát |
| `LEDR[2]` | Fail đã chốt để quan sát |
| `HEX1` | Bốn bit cao của byte đang xem |
| `HEX0` | Bốn bit thấp của byte đang xem |

Cách dùng dự kiến: đặt byte bằng SW[7:0], nhấn KEY[1] để chốt từng symbol; sau khi đủ dữ liệu, chuyển sang pha chạy rồi nhấn KEY[1]. Các switch chọn chế độ phải được chốt tại thời điểm thích hợp, tránh đổi chế độ giữa một lần xử lý.

SW[9] chỉ cho phép tạo lỗi; vị trí và mặt nạ lỗi ban đầu có thể đặt bằng hằng số hoặc kịch bản thử. Việc duyệt nhiều byte kết quả cần được thiết kế trong bộ điều khiển; hai HEX chỉ hiển thị một byte tại một thời điểm.

## 5. Bảng chân FPGA dùng trong Quartus

Các mã PIN dưới đây là vị trí chân của chip FPGA, không phải số thứ tự chân trên đầu nối GPIO.

### 5.1. Clock và nút nhấn

| Cổng top-level | Chân FPGA | I/O Standard |
| --- | --- | --- |
| `MAX10_CLK1_50` | `PIN_P11` | 3.3-V LVTTL |
| `KEY[0]` | `PIN_B8` | 3.3 V SCHMITT TRIGGER |
| `KEY[1]` | `PIN_A7` | 3.3 V SCHMITT TRIGGER |

KEY là nút tích cực thấp: nhấn = 0, thả = 1. Dùng clock hệ thống để lấy mẫu và tạo xung từ nút nhấn; không dùng nút làm clock cho lõi RS. Đồng bộ tín hiệu và xử lý dội theo yêu cầu thực tế.

### 5.2. Switch

| Cổng top-level | Chân FPGA | Phân công |
| --- | --- | --- |
| `SW[0]` | `PIN_C10` | Bit 0, LSB |
| `SW[1]` | `PIN_C11` | Bit 1 |
| `SW[2]` | `PIN_D12` | Bit 2 |
| `SW[3]` | `PIN_C12` | Bit 3 |
| `SW[4]` | `PIN_A12` | Bit 4 |
| `SW[5]` | `PIN_B12` | Bit 5 |
| `SW[6]` | `PIN_A13` | Bit 6 |
| `SW[7]` | `PIN_A14` | Bit 7, MSB |
| `SW[8]` | `PIN_B14` | Chọn chế độ, tùy chọn |
| `SW[9]` | `PIN_F15` | Cho phép tạo lỗi, tùy chọn |

I/O Standard: 3.3-V LVTTL. Theo tài liệu board, gạt xuống phía mép board là 0; gạt lên là 1.

### 5.3. LED trạng thái

| Cổng top-level | Chân FPGA | Phân công |
| --- | --- | --- |
| `LEDR[0]` | `PIN_A8` | Busy |
| `LEDR[1]` | `PIN_A9` | Done |
| `LEDR[2]` | `PIN_A10` | Fail |

I/O Standard: 3.3-V LVTTL. LED đỏ sáng khi đầu ra bằng 1.

### 5.4. HEX0 và HEX1

| Chỉ số | Đoạn | Chân HEX0 | Chân HEX1 |
| --- | --- | --- | --- |
| `[0]` | a — trên | `PIN_C14` | `PIN_C18` |
| `[1]` | b — phải trên | `PIN_E15` | `PIN_D18` |
| `[2]` | c — phải dưới | `PIN_C15` | `PIN_E18` |
| `[3]` | d — dưới | `PIN_C16` | `PIN_B16` |
| `[4]` | e — trái dưới | `PIN_E16` | `PIN_A17` |
| `[5]` | f — trái trên | `PIN_D17` | `PIN_A18` |
| `[6]` | g — giữa | `PIN_C17` | `PIN_B17` |
| `[7]` | DP — dấu chấm | `PIN_D15` | `PIN_A16` |

I/O Standard: 3.3-V LVTTL. Các đoạn tích cực thấp: 0 sáng, 1 tắt. Đặt `HEX0[7] = HEX1[7] = 1'b1` nếu không dùng dấu chấm.

Ví dụ byte `8'hA7`: HEX1 hiển thị A, HEX0 hiển thị 7. Cần đổi từng nibble qua bộ giải mã 7 đoạn, không nối trực tiếp 4 bit dữ liệu vào chân đoạn.

Bảng này gồm 32 chân tín hiệu nếu dùng cả hai DP; 30 chân nếu bỏ hai DP.

## 6. Khai báo cổng top-level dự kiến

Đây chỉ là khung khai báo cổng; cần bổ sung logic trước khi tổng hợp và nạp.

```verilog
module top_de10_lite (
    input  wire       MAX10_CLK1_50,
    input  wire [1:0] KEY,
    input  wire [9:0] SW,
    output wire [2:0] LEDR,
    output wire [7:0] HEX0,
    output wire [7:0] HEX1
);
    // Ket noi bo dieu khien, khoi RS va ngoai vi tai day.
endmodule
```

Các tên cổng phải khớp chính xác với tên dùng trong QSF. Nếu đổi tên cổng hoặc độ rộng bus, cập nhật bảng gán chân tương ứng.

## 7. Mẫu gán chân QSF

Đoạn dưới dành cho giao diện top-level ở mục 6, dùng cả hai DP. Dùng Pin Planner hoặc đưa các lệnh này vào QSF của project. Tránh giữ các gán chân cũ trùng với tín hiệu đang dùng.

```tcl
# Clock
set_location_assignment PIN_P11 -to MAX10_CLK1_50

# Keys
set_location_assignment PIN_B8 -to {KEY[0]}
set_location_assignment PIN_A7 -to {KEY[1]}

# Switches
set_location_assignment PIN_C10 -to {SW[0]}
set_location_assignment PIN_C11 -to {SW[1]}
set_location_assignment PIN_D12 -to {SW[2]}
set_location_assignment PIN_C12 -to {SW[3]}
set_location_assignment PIN_A12 -to {SW[4]}
set_location_assignment PIN_B12 -to {SW[5]}
set_location_assignment PIN_A13 -to {SW[6]}
set_location_assignment PIN_A14 -to {SW[7]}
set_location_assignment PIN_B14 -to {SW[8]}
set_location_assignment PIN_F15 -to {SW[9]}

# Status LEDs
set_location_assignment PIN_A8  -to {LEDR[0]}
set_location_assignment PIN_A9  -to {LEDR[1]}
set_location_assignment PIN_A10 -to {LEDR[2]}

# HEX0
set_location_assignment PIN_C14 -to {HEX0[0]}
set_location_assignment PIN_E15 -to {HEX0[1]}
set_location_assignment PIN_C15 -to {HEX0[2]}
set_location_assignment PIN_C16 -to {HEX0[3]}
set_location_assignment PIN_E16 -to {HEX0[4]}
set_location_assignment PIN_D17 -to {HEX0[5]}
set_location_assignment PIN_C17 -to {HEX0[6]}
set_location_assignment PIN_D15 -to {HEX0[7]}

# HEX1
set_location_assignment PIN_C18 -to {HEX1[0]}
set_location_assignment PIN_D18 -to {HEX1[1]}
set_location_assignment PIN_E18 -to {HEX1[2]}
set_location_assignment PIN_B16 -to {HEX1[3]}
set_location_assignment PIN_A17 -to {HEX1[4]}
set_location_assignment PIN_A18 -to {HEX1[5]}
set_location_assignment PIN_B17 -to {HEX1[6]}
set_location_assignment PIN_A16 -to {HEX1[7]}

# I/O standards
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to MAX10_CLK1_50
set_instance_assignment -name IO_STANDARD "3.3 V SCHMITT TRIGGER" -to {KEY[0]}
set_instance_assignment -name IO_STANDARD "3.3 V SCHMITT TRIGGER" -to {KEY[1]}

foreach port {SW[0] SW[1] SW[2] SW[3] SW[4] SW[5] SW[6] SW[7] SW[8] SW[9] LEDR[0] LEDR[1] LEDR[2] HEX0[0] HEX0[1] HEX0[2] HEX0[3] HEX0[4] HEX0[5] HEX0[6] HEX0[7] HEX1[0] HEX1[1] HEX1[2] HEX1[3] HEX1[4] HEX1[5] HEX1[6] HEX1[7]} {
    set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to $port
}
```

Project cần chọn đúng FPGA `10M50DAF484C7G` và top-level `top_de10_lite`.

## 8. Clock và ràng buộc thời gian

Clock 50 MHz có chu kỳ 20 ns. Khai báo clock cơ sở trong SDC:

```tcl
create_clock -name sys_clk -period 20.000 [get_ports {MAX10_CLK1_50}]
```

Đây là khai báo clock tối thiểu, chưa phải toàn bộ ràng buộc thời gian cho một hệ thống hoàn chỉnh. Bổ sung ràng buộc phù hợp khi thiết kế đồng bộ đầu vào, reset, PLL hoặc giao tiếp ngoài. Không thêm ngoại lệ timing chỉ để che cảnh báo.

## 9. UART khi mở rộng

Phiên bản nhập bằng switch chưa cần UART. Khi bổ sung USB–UART TTL mức 3,3 V, có thể chọn:

| Tín hiệu dự kiến | Chân vật lý JP1 | Chân FPGA |
| --- | --- | --- |
| FPGA RX — `GPIO[0]` | 1 | `PIN_V10` |
| FPGA TX — `GPIO[1]` | 2 | `PIN_W10` |
| GND | 12 | Không gán trong Quartus |

Đây là phân công tùy chọn cho GPIO, không phải UART cố định trên chip. Nối TX của bộ chuyển vào FPGA RX, RX vào FPGA TX và nối chung GND. GPIO digital dùng mức 3,3 V.

Nếu dùng UART, thêm các port RX/TX và gán chân trong project. Cổng USB-Blaster trên board phục vụ nạp/debug qua JTAG; nó không tự trở thành cổng COM của UART RTL.

## 10. Kiểm chứng

| Thành phần kiểm tra | Mục đích |
| --- | --- |
| Mô hình Python | Kết quả tham chiếu độc lập |
| `tb_gf_mul` | Kiểm tra phép nhân GF; có thể đối chiếu đủ 256 x 256 cặp |
| `tb_rs_encoder` | Kiểm tra toàn bộ từ mã và parity |
| `tb_rs_decoder` | Kiểm tra các mẫu lỗi và dữ liệu khôi phục |
| `tb_top` | Kiểm tra thứ tự nhập, bắt tay và điều khiển |

Các trường hợp cần có: không lỗi; một lỗi; nhiều lỗi đến giới hạn sửa; lỗi ở đầu/cuối khối; dữ liệu toàn 0; reset; dữ liệu đến có khoảng nghỉ; đầu ra bị chặn nếu dùng ready/valid. Với lỗi vượt giới hạn, ghi nhận cả báo fail và khả năng giải mã nhầm.

Testbench chạy trên simulator, không nạp thành phần cứng. Mô hình Python và RTL phải dùng cùng tham số RS và quy ước symbol.

## 11. Thứ tự triển khai

1. Kiểm tra clock, switch, nút nhấn, LED và HEX.
2. Hoàn thành GF multiplier và testbench.
3. Hoàn thành encoder, đối chiếu với Python.
4. Chạy encoder trên board với bộ đệm và FSM.
5. Triển khai lần lượt các khối decoder.
6. Thêm bộ tạo lỗi và kiểm chứng end-to-end.
7. Bổ sung UART và đo chu kỳ xử lý, tài nguyên, timing.

Chưa cần SDRAM ngoài, VGA hay xử lý ảnh QR cho bản demo lõi RS đầu tiên. Nếu dùng dữ liệu QR, máy tính có thể trích xuất đúng từng khối RS và gửi các codeword sang FPGA.

## 12. Tài liệu tham khảo

- [Terasic — DE10-Lite Specifications](https://www.terasic.com.tw/cgi-bin/page/archive.pl?CategoryNo=218&Language=English&No=1021&PartNo=2).
- [DE10-Lite User Manual — bản Terasic ngày 05/06/2020](https://e2e.ti.com/cfs-file/__key/communityserver-discussions-components-files/73/DE10_2D00_Lite_5F00_User_5F00_Manual.pdf): trang in 24–29 cho clock/KEY/SW/LED/HEX; trang 30–31 cho JP1.
- [MathWorks — RS Decoder, kiến trúc giải mã hỗ trợ HDL](https://www.mathworks.com/help/wireless-hdl/ref/rsdecoder.html).
- [MathWorks — Integer-Output RS Decoder, khả năng sửa lỗi symbol](https://www.mathworks.com/help/comm/ref/integeroutputrsdecoder.html).

Bảng chân lấy từ tài liệu phần cứng; chức năng nút, switch, LED, cách chia module và giao thức điều khiển là đề xuất của dự án.

