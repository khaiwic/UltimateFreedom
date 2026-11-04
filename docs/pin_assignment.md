# Bảng chân DE10-Lite cho hệ thống Reed–Solomon

Tài liệu này tập hợp bảng chân và quy ước giao tiếp của bản demo RS từ
[README_RS_DE10_Lite.md](../README_RS_DE10_Lite.md), mục 4–9.
FPGA sử dụng là **MAX 10 `10M50DAF484C7G`**, top-level dự kiến là
`top_de10_lite`, với một clock hệ thống 50 MHz.

Bảng chân phần cứng và chức năng ngoại vi cần được phân biệt: chân FPGA giữ
theo README, còn cách dùng nút, switch và LED là phân công đề xuất của dự án.
Tài liệu này không xác nhận RTL đã được triển khai hoặc chạy trên board.

## 1. Giao diện top-level

Các tên cổng và độ rộng bus phải khớp với khai báo RTL và gán chân Quartus:

```verilog
module top_de10_lite (
    input  wire       MAX10_CLK1_50,
    input  wire [1:0] KEY,
    input  wire [9:0] SW,
    output wire [2:0] LEDR,
    output wire [7:0] HEX0,
    output wire [7:0] HEX1
);
    // Bo sung logic ket noi ngoai vi, bo dieu khien va loi RS.
endmodule
```

Đây là khung cổng, chưa phải thiết kế có thể nạp để chạy demo.
Các khối GF, encoder, decoder và bộ đệm giao tiếp bên trong FPGA nên không
cần gán chân ngoại vi riêng.

Các mã `PIN_...` dưới đây là vị trí chân trên chip FPGA. Chỉ số chân vật lý
trên đầu nối JP1 được ghi riêng ở phần UART.

## 2. Clock và nút nhấn

| Cổng top-level | Hướng | Chân FPGA | I/O Standard | Chức năng |
| --- | --- | --- | --- | --- |
| `MAX10_CLK1_50` | Input | `PIN_P11` | `3.3-V LVTTL` | Clock hệ thống 50 MHz |
| `KEY[0]` | Input | `PIN_B8` | `3.3 V SCHMITT TRIGGER` | Reset |
| `KEY[1]` | Input | `PIN_A7` | `3.3 V SCHMITT TRIGGER` | Xác nhận nhập hoặc bắt đầu xử lý |

Nút `KEY` tích cực thấp: nhấn là `0`, thả là `1`. Lấy mẫu nút bằng clock hệ
thống, đồng bộ và xử lý dội trước khi tạo xung điều khiển. Không dùng nút nhấn
làm clock cho lõi RS. Reset nội bộ dùng quy ước `rst_n` tích cực thấp theo README.

## 3. Switch nhập dữ liệu và chọn chế độ

Tất cả các switch dùng I/O Standard `3.3-V LVTTL` và là đầu vào FPGA.

| Cổng top-level | Chân FPGA | Chức năng đề xuất |
| --- | --- | --- |
| `SW[0]` | `PIN_C10` | Bit 0 của byte nhập, LSB |
| `SW[1]` | `PIN_C11` | Bit 1 của byte nhập |
| `SW[2]` | `PIN_D12` | Bit 2 của byte nhập |
| `SW[3]` | `PIN_C12` | Bit 3 của byte nhập |
| `SW[4]` | `PIN_A12` | Bit 4 của byte nhập |
| `SW[5]` | `PIN_B12` | Bit 5 của byte nhập |
| `SW[6]` | `PIN_A13` | Bit 6 của byte nhập |
| `SW[7]` | `PIN_A14` | Bit 7 của byte nhập, MSB |
| `SW[8]` | `PIN_B14` | Chọn pha nhập/chạy, tùy chọn |
| `SW[9]` | `PIN_F15` | Cho phép tạo lỗi, tùy chọn |

Theo quy ước board trong README, gạt xuống phía mép board là `0`, gạt lên là
`1`. Đặt byte trên `SW[7:0]`, giữ ổn định rồi nhấn `KEY[1]` để xác nhận.

README chưa chốt mức `0/1` của `SW[8]` tương ứng với từng pha. Bộ điều khiển
cần xác định quy ước này và chốt các lựa chọn chế độ tại thời điểm thích hợp.
`SW[9]` chỉ cho phép tạo lỗi; vị trí và mặt nạ lỗi do bộ tạo lỗi quy định.

## 4. LED trạng thái

Các LED là đầu ra FPGA, dùng I/O Standard `3.3-V LVTTL`, sáng khi đầu ra bằng `1`.

| Cổng top-level | Chân FPGA | Chức năng đề xuất |
| --- | --- | --- |
| `LEDR[0]` | `PIN_A8` | `busy`: hệ thống đang xử lý |
| `LEDR[1]` | `PIN_A9` | `done`: hoàn tất, đã chốt để quan sát |
| `LEDR[2]` | `PIN_A10` | `fail`: phát hiện giải mã thất bại, đã chốt để quan sát |

Nếu `done` hoặc `fail` chỉ là xung một chu kỳ clock, khối điều khiển hiển thị
phải giữ lại trạng thái và xác định thời điểm xóa cho lượt xử lý tiếp theo.
`fail = 0` không bảo đảm dữ liệu đúng khi số lỗi vượt khả năng sửa của mã.

## 5. LED 7 đoạn HEX0 và HEX1

Hai cổng HEX là đầu ra FPGA, dùng I/O Standard `3.3-V LVTTL`.
Các đoạn tích cực thấp: `0` làm sáng, `1` làm tắt.

| Bit | Đoạn | Vị trí | Chân `HEX0` | Chân `HEX1` |
| --- | --- | --- | --- | --- |
| `[0]` | a | Trên | `PIN_C14` | `PIN_C18` |
| `[1]` | b | Phải trên | `PIN_E15` | `PIN_D18` |
| `[2]` | c | Phải dưới | `PIN_C15` | `PIN_E18` |
| `[3]` | d | Dưới | `PIN_C16` | `PIN_B16` |
| `[4]` | e | Trái dưới | `PIN_E16` | `PIN_A17` |
| `[5]` | f | Trái trên | `PIN_D17` | `PIN_A18` |
| `[6]` | g | Giữa | `PIN_C17` | `PIN_B17` |
| `[7]` | DP | Dấu chấm | `PIN_D15` | `PIN_A16` |

`HEX1` hiển thị nibble cao, `HEX0` hiển thị nibble thấp. Ví dụ, byte `8'hA7`
được hiển thị thành `A7`. Mỗi nibble phải đi qua bộ giải mã 7 đoạn; không nối
trực tiếp bốn bit dữ liệu vào các chân đoạn.

Nếu giữ cổng HEX rộng 8 bit nhưng không hiển thị dấu chấm, đặt:

```verilog
assign HEX0[7] = 1'b1;
assign HEX1[7] = 1'b1;
```

Với giao diện ở mục 1, có **32 chân tín hiệu**, bao gồm hai chân DP dù chúng
luôn tắt. Nếu bỏ hẳn hai chân DP, đổi cả hai cổng thành `[6:0]` và xóa hai gán
chân tương ứng trong QSF; khi đó còn **30 chân tín hiệu**.

Hai HEX chỉ hiển thị một byte tại một thời điểm. Thao tác duyệt các byte kết
quả cần được quy định trong bộ điều khiển demo.

## 6. Mẫu cấu hình QSF

Đưa đoạn sau vào [quartus/ReedSolomon.qsf](../quartus/ReedSolomon.qsf) khi
triển khai project, hoặc nhập các gán chân tương ứng bằng Pin Planner.
Đoạn này dùng đúng giao diện mục 1, bao gồm hai chân DP.

```tcl
set_global_assignment -name FAMILY "MAX 10"
set_global_assignment -name DEVICE 10M50DAF484C7G
set_global_assignment -name TOP_LEVEL_ENTITY top_de10_lite

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

foreach port {
    SW[0] SW[1] SW[2] SW[3] SW[4] SW[5] SW[6] SW[7] SW[8] SW[9]
    LEDR[0] LEDR[1] LEDR[2]
    HEX0[0] HEX0[1] HEX0[2] HEX0[3] HEX0[4] HEX0[5] HEX0[6] HEX0[7]
    HEX1[0] HEX1[1] HEX1[2] HEX1[3] HEX1[4] HEX1[5] HEX1[6] HEX1[7]
} {
    set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to $port
}
```

Đây là phần cấu hình device, top-level và chân; project vẫn cần danh sách file
RTL, đường dẫn include và file SDC phù hợp. Xóa các gán chân cũ bị trùng, và
cập nhật QSF khi thay đổi tên cổng hoặc độ rộng bus.

## 7. Ràng buộc clock

Clock 50 MHz có chu kỳ 20 ns. Khai báo clock cơ sở trong
[quartus/timing.sdc](../quartus/timing.sdc):

```tcl
create_clock -name sys_clk -period 20.000 [get_ports {MAX10_CLK1_50}]
```

Với QSF nằm trong thư mục `quartus`, đăng ký file SDC bằng:

```tcl
set_global_assignment -name SDC_FILE timing.sdc
```

Đây là ràng buộc clock tối thiểu. Bổ sung ràng buộc phù hợp với mạch đồng bộ
đầu vào, reset và giao tiếp ngoài khi triển khai. Không thêm ngoại lệ timing
chỉ để che cảnh báo.

## 8. UART mở rộng trên JP1

Bản demo nhập bằng switch chưa cần UART. Nếu bổ sung bộ chuyển USB–UART TTL
mức 3,3 V, có thể dùng phân công sau theo README:

| Cổng top-level đề xuất | Hướng nhìn từ FPGA | Tín hiệu board | Chân vật lý JP1 | Chân FPGA |
| --- | --- | --- | --- | --- |
| `UART_RX` | Input | `GPIO[0]` | 1 | `PIN_V10` |
| `UART_TX` | Output | `GPIO[1]` | 2 | `PIN_W10` |
| GND | Nguồn tham chiếu | GND | 12 | Không gán trong Quartus |

`UART_RX` và `UART_TX` là tên cổng đề xuất khi mở rộng top-level. Chúng dùng
hai chân board được gọi là `GPIO[0]` và `GPIO[1]`; không khai báo thêm cổng
GPIO trùng lên cùng hai chân FPGA.

Nối TX của bộ chuyển vào `UART_RX`, RX vào `UART_TX` và nối chung GND.
GPIO digital dùng mức 3,3 V. USB-Blaster phục vụ nạp/debug qua JTAG, không tự
trở thành cổng COM cho UART RTL.

Sau khi thêm hai cổng UART vào top-level, bổ sung QSF:

```tcl
set_location_assignment PIN_V10 -to UART_RX
set_location_assignment PIN_W10 -to UART_TX
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to UART_RX
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to UART_TX
```

Không đưa các gán chân UART vào cấu hình cơ sở khi RTL chưa có các cổng này.

## 9. Đối chiếu khi tích hợp

- Chọn đúng device `10M50DAF484C7G` và top-level `top_de10_lite`.
- Đối chiếu tên cổng, độ rộng bus, vị trí chân và I/O Standard trong Pin Planner.
- Giữ đúng cực tính: KEY và HEX tích cực thấp, LEDR tích cực cao.
- Đăng ký file SDC và kiểm tra clock 50 MHz trong báo cáo timing.
- Kiểm tra riêng nút, switch, LED và HEX trước khi ghép luồng RS.

Nguồn của các bảng chân là README dự án; tài liệu này chưa đối chiếu độc lập
với sơ đồ mạch hoặc kiểm chứng trên board. Các tài liệu phần cứng tham khảo
được liệt kê tại mục 12 của [README](../README_RS_DE10_Lite.md).
