# Bảng chân DE10-Lite cho hệ thống Reed–Solomon RS(5,3)

Tài liệu này mô tả giao diện top-level `top_de10_lite` và bảng gán chân trên FPGA **Intel MAX 10 `10M50DAF484C7G`** (kit **Terasic DE10-Lite**), khớp với [`quartus/ReedSolomon.qsf`](../quartus/ReedSolomon.qsf).

## 1. Giao diện top-level

```verilog
module top_de10_lite #(
    parameter integer DEBOUNCE_MAX      = 499_999,
    parameter integer BLINK_BIT         = 24,
    parameter integer UART_CLKS_PER_BIT = 434
) (
    input  wire       MAX10_CLK1_50,
    input  wire [1:0] KEY,
    input  wire [9:0] SW,
    output wire [9:0] LEDR,
    output wire [7:0] HEX0,
    output wire [7:0] HEX1,
    output wire [7:0] HEX2,
    output wire       UART_TX
);
```

## 2. Clock và nút nhấn

| Cổng | Hướng | Chân FPGA | I/O Standard | Chức năng |
| --- | --- | --- | --- | --- |
| `MAX10_CLK1_50` | Input | `PIN_P11` | `3.3-V LVTTL` | Clock hệ thống 50 MHz |
| `KEY[0]` | Input | `PIN_B8` | `3.3 V SCHMITT TRIGGER` | Reset tích cực mức thấp (`rst_n`) |
| `KEY[1]` | Input | `PIN_A7` | `3.3 V SCHMITT TRIGGER` | Chốt symbol hoặc xác nhận nhập lỗi (lọc dội 10 ms) |

## 3. Switch nhập liệu và chọn chế độ

| Cổng | Chân FPGA | Chức năng |
| --- | --- | --- |
| `SW[2:0]` | `PIN_C10`, `PIN_C11`, `PIN_D12` | Giá trị symbol 3-bit (`0..7`) hoặc mặt nạ lỗi |
| `SW[7:3]` | `PIN_C12` .. `PIN_A14` | Không sử dụng trong RS(5,3) |
| `SW[8]` | `PIN_B14` | Trong chế độ lỗi (`SW[9]=1`): `1` = kết thúc nhập lỗi sớm sau 1 hoặc 2 lỗi |
| `SW[9]` | `PIN_F15` | `0` = Chế độ nhập thông tin & giải mã đúng; `1` = Chế độ nhập lỗi (tối đa 3 lỗi) |

## 4. 10 LED đơn (`LEDR[9:0]`)

| Cổng | Chân FPGA | Chức năng |
| --- | --- | --- |
| `LEDR[0]` .. `LEDR[9]` | `PIN_A8, PIN_A9, PIN_A10, PIN_B10, PIN_D13, PIN_C13, PIN_E14, PIN_D14, PIN_A11, PIN_B11` | Khi đang nhập: sáng 1 đèn theo giá trị `SW[2:0]` (`1 << SW[2:0]`). Sau giải mã lỗi: tắt hết nếu đúng; nhấp nháy toàn bộ 10 đèn nếu sai |

## 5. 3 LED 7 đoạn (`HEX2`, `HEX1`, `HEX0`)

Các đoạn tích cực mức thấp (`0` sáng, `1` tắt); dấu chấm `DP` (`[7]`) luôn tắt (`1`).

| Bit | Đoạn | `HEX0` (Symbol 2) | `HEX1` (Symbol 1) | `HEX2` (Symbol 0) |
| --- | --- | --- | --- | --- |
| `[0]` | a | `PIN_C14` | `PIN_C18` | `PIN_B20` |
| `[1]` | b | `PIN_E15` | `PIN_D18` | `PIN_A20` |
| `[2]` | c | `PIN_C15` | `PIN_E18` | `PIN_B19` |
| `[3]` | d | `PIN_C16` | `PIN_B16` | `PIN_A21` |
| `[4]` | e | `PIN_E16` | `PIN_A17` | `PIN_B21` |
| `[5]` | f | `PIN_D17` | `PIN_A18` | `PIN_C22` |
| `[6]` | g | `PIN_C17` | `PIN_B17` | `PIN_B22` |
| `[7]` | DP | `PIN_D15` | `PIN_A16` | `PIN_A19` |

## 6. Giao tiếp UART Monitor (`JP1`)

| Cổng | Chân FPGA | Chân vật lý `JP1` | Nối với CP2101 | Chuẩn |
| --- | --- | --- | --- | --- |
| `UART_TX` | `PIN_W10` | `Pin 2` (`GPIO[1]`) | `RXD` | `3.3-V LVTTL`, `115200 bps`, `8N1` |
| `GND` | — | `Pin 12` | `GND` | Chung mass *(không cắm dây nguồn 3.3V/5V)* |

