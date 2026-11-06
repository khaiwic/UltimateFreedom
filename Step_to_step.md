# Hướng dẫn từng bước: Mô phỏng ModelSim, Biên dịch Quartus Prime và Nạp mạch lên kit Terasic DE10-Lite

Tài liệu này hướng dẫn chi tiết từng thao tác thực tế giúp bạn tự tay chạy mô phỏng waveform trong **ModelSim / QuestaSim**, biên dịch tổng hợp trên **Quartus Prime**, nạp file xuống FPGA **Intel MAX 10** và tiến hành các bài thí nghiệm mã hóa / sửa sai Reed–Solomon trực quan trên kit phát triển **Terasic DE10-Lite**.

---

## Mục lục
1. [Tổng quan hệ thống và bảng chân phần cứng](#1-tổng-quan-hệ-thống-và-bảng-chân-phần-cứng)
2. [Phần 1: Chạy mô phỏng RTL với ModelSim / QuestaSim](#2-phần-1-chạy-mô-phỏng-rtl-với-modelsim--questasim)
3. [Phần 2: Biên dịch và tổng hợp dự án trong Quartus Prime](#3-phần-2-biên-dịch-và-tổng-hợp-dự-án-trong-quartus-prime)
4. [Phần 3: Nạp mạch (Program / Flash) lên kit DE10-Lite](#4-phần-3-nạp-mạch-program--flash-lên-kit-de10-lite)
5. [Phần 4: Hướng dẫn tự tay thao tác kiểm chứng trên kit thật](#5-phần-4-hướng-dẫn-tự-tay-thao-tác-kiểm-chứng-trên-kit-thật)
6. [Xử lý sự cố thường gặp (Troubleshooting)](#6-xử-lý-sự-cố-thường-gặp-troubleshooting)

---

## 1. Tổng quan hệ thống và bảng chân phần cứng

### 1.1. Thông số kỹ thuật chuẩn của hệ thống RS
- **Mã Reed–Solomon**: RS(15, 11) rút ngắn từ RS(255, 251) trong trường Galois $\text{GF}(256)$.
- **Kích thước symbol**: $m = 8$ bit (1 byte, giá trị `0x00` .. `0xFF`).
- **Độ dài từ mã**: $N = 15$ symbol ($K = 11$ byte dữ liệu gốc, $R = 4$ byte kiểm tra parity).
- **Khả năng sửa sai**: Sửa tối đa $T = \lfloor R/2 \rfloor = 2$ byte lỗi bất kỳ trong khối 15 bytes.
- **Đa thức trường**: $p(u) = u^8 + u^4 + u^3 + u^2 + 1$ (`0x11D`). Phần tử nguyên thủy $\alpha = \text{0x02}$.
- **Đa thức sinh**: $g(x) = (x+01)(x+02)(x+04)(x+08) = x^4 + 0Fx^3 + 36x^2 + 78x + 40$ ($F=0$).
- **Thứ tự truyền**: Hệ số bậc cao trước ($x^{14}$ truyền trước, $x^0$ truyền sau).

### 1.2. Bảng gán chân ngoại vi trên kit DE10-Lite (MAX 10 `10M50DAF484C7G`)

| Ngoại vi | Chân FPGA | Kiểu I/O | Chức năng hoạt động |
|---|:---:|:---:|---|
| `MAX10_CLK1_50` | `PIN_P11` | 3.3-V LVTTL | Xung nhịp hệ thống 50 MHz (chu kỳ 20.0 ns) |
| `KEY[0]` | `PIN_B8` | 3.3 V Schmitt Trigger | Nút nhấn Reset hệ thống (Nhấn = `0`, Thả = `1`) |
| `KEY[1]` | `PIN_A7` | 3.3 V Schmitt Trigger | Xác nhận chốt 1 byte từ SW / Bắt đầu chạy xử lý |
| `SW[7:0]` | `PIN_C10` .. `PIN_A14` | 3.3-V LVTTL | 8 switch đặt giá trị 1 byte dữ liệu đầu vào |
| `SW[8]` | `PIN_B14` | 3.3-V LVTTL | Chế độ: `0` = Pha nhập dữ liệu, `1` = Pha chạy / Xem kết quả |
| `SW[9]` | `PIN_F15` | 3.3-V LVTTL | Chế độ tạo lỗi: `0` = Không lỗi, `1` = Chèn 2 lỗi thử nghiệm |
| `LEDR[0]` | `PIN_A8` | 3.3-V LVTTL | Đèn đỏ báo **Busy** (Sáng khi mạch đang xử lý) |
| `LEDR[1]` | `PIN_A9` | 3.3-V LVTTL | Đèn đỏ báo **Done** (Chốt sáng sau khi hoàn tất) |
| `LEDR[2]` | `PIN_A10` | 3.3-V LVTTL | Đèn đỏ báo **Fail** (Chốt sáng nếu giải mã thất bại) |
| `HEX1` | `PIN_C18` .. `PIN_A16` | 3.3-V LVTTL | Hiển thị 4 bit cao (MSB nibble) của byte đang xem |
| `HEX0` | `PIN_C14` .. `PIN_D15` | 3.3-V LVTTL | Hiển thị 4 bit thấp (LSB nibble) của byte đang xem |

---

## 2. Phần 1: Chạy mô phỏng RTL với ModelSim / QuestaSim

Thư mục `sim/` đã được cấu hình sẵn toàn bộ kịch bản tự động hóa gồm:
- `rtl_files.f`: Danh sách đầy đủ 21 module RTL theo đúng thứ tự phụ thuộc.
- `run.do`: Tcl macro tự động xóa/tạo thư viện `work`, biên dịch RTL, nạp testbench và gọi `wave.do`.
- `wave.do`: Cấu hình cửa sổ dạng sóng (phân nhóm màu sắc cho Clock, Handshake, FSM, Syndrome, BM, Chien, Forney, Corrector, LED, HEX).

### Cách 1: Chạy trực tiếp từ ModelSim / QuestaSim GUI (Khuyên dùng)
1. Khởi động **ModelSim** (hoặc **QuestaSim** / **ModelSim-Intel FPGA Edition**).
2. Tại thanh nhập lệnh phía dưới (**Transcript Window**), chuyển thư mục làm việc đến thư mục `sim/` của dự án:
   ```tcl
   cd D:/UltimateFreedom/UltimateFreedom/sim
   ```
3. Chạy script mô phỏng:
   - **Mô phỏng bộ giải mã hoàn chỉnh (mặc định)**:
     ```tcl
     do run.do
     ```
   - **Mô phỏng bộ mã hóa (RS Encoder)**:
     ```tcl
     do run.do tb_rs_encoder
     ```
   - **Mô phỏng tích hợp cấp Board DE10-Lite**:
     ```tcl
     do run.do tb_top
     ```
4. Quan sát cửa sổ sóng **Waveform Window**:
   - Tín hiệu đã được phân nhóm rõ ràng theo các dải màu trực quan.
   - Bấm phím **F** (Zoom Full) hoặc biểu tượng kính lúp màu xanh để phóng to toàn bộ dạng sóng.
   - Nhấp chuột trái vào bất kỳ vị trí nào trên trục thời gian để đặt thước đo (Cursor) và kiểm tra giá trị của các bus dữ liệu (`data_in`, `data_out`, `syndromes`, `lambda`, `forney_err_val`).

### Cách 2: Khởi chạy ModelSim từ giao diện Quartus Prime
1. Mở Quartus Prime, mở project `quartus/ReedSolomon.qpf`.
2. Trên thanh menu chọn: **Tools** $\rightarrow$ **Run Simulation Tool** $\rightarrow$ **RTL Simulation**.
3. Quartus sẽ tự động khởi động ModelSim và nạp môi trường NativeLink.
4. Trong cửa sổ Transcript của ModelSim, bạn có thể gõ:
   ```tcl
   cd ../sim
   do run.do
   ```

### Cách 3: Kiểm tra nhanh từ dòng lệnh (Icarus Verilog nếu không mở GUI)
Nếu muốn chạy kiểm tra nhanh không cần mở giao diện đồ họa ModelSim:
```powershell
cd D:\UltimateFreedom\UltimateFreedom\sim
iverilog -g2012 -I ../tb -s tb_rs_decoder -f rtl_files.f ../tb/tb_rs_decoder.v -o sim_test.vvp
vvp sim_test.vvp
```
Kết quả mong đợi: `[PASS] tb_rs_decoder : 4465 kiem tra, 0 loi`.

---

## 3. Phần 2: Biên dịch và tổng hợp dự án trong Quartus Prime

### Bước 1: Mở Project trong Quartus Prime
1. Mở phần mềm **Quartus Prime** (bản Lite / Standard / Pro 18.1 đến 25.1 đều tương thích).
2. Chọn menu **File** $\rightarrow$ **Open Project...** (hoặc nhấn tổ hợp phím `Ctrl + O`).
3. Điều hướng đến thư mục:
   ```text
   D:\UltimateFreedom\UltimateFreedom\quartus\
   ```
4. Chọn file **`ReedSolomon.qpf`** và nhấn **Open**.

### Bước 2: Kiểm tra cấu hình Project
1. Tại cửa sổ **Project Navigator** (bên trái), chọn thẻ **Hierarchy**:
   - **Family**: `MAX 10`
   - **Device**: `10M50DAF484C7G`
   - **Top-Level Entity**: `top_de10_lite`
2. Kiểm tra danh sách file:
   - Chọn menu **Assignments** $\rightarrow$ **Settings...** $\rightarrow$ chọn mục **Files**.
   - Đảm bảo danh sách chứa đầy đủ các file RTL trong `rtl/` và file ràng buộc thời gian `timing.sdc`.
   - Đảm bảo mục **Search Path** có đường dẫn `../rtl/include`.

### Bước 3: Tiến hành biên dịch toàn bộ (Full Compilation)
1. Nhấn nút **Start Compilation** (biểu tượng nút Play màu tím trên thanh công cụ) hoặc bấm tổ hợp phím:
   ```text
   Ctrl + L
   ```
2. Theo dõi tiến trình qua cửa sổ **Tasks** bên góc trái dưới:
   - **Analysis & Synthesis**: Phân tích cú pháp Verilog và suy luận mạch tổ hợp/thanh ghi.
   - **Fitter (Place & Route)**: Phân bố logic và định tuyến đường dây trên chip MAX 10.
   - **Assembler**: Sinh file nạp `.sof` (SRAM Object File) vào thư mục `quartus/output_files/`.
   - **TimeQuest Timing Analysis**: Kiểm tra độ trễ xung nhịp 50 MHz theo `timing.sdc`.

### Bước 4: Kiểm tra kết quả biên dịch (Compilation Report)
Khi tiến trình đạt **100% (Compilation Report - Successful)**, kiểm tra các chỉ số tài nguyên:
- **Flow Status**: `Successful`.
- **Total logic elements**: Chiếm khoảng $3\% \dots 6\%$ trên tổng số 49,760 LEs của chip MAX 10 (rất tiết kiệm tài nguyên).
- **Total registers**: Chiếm khoảng 800 - 1,200 flip-flops.
- **Total pins**: 33 pins (Clock, KEY, SW, LEDR, HEX).
- **TimeQuest Timing Analyzer**:
  - Tần số tối đa đạt được ($F_{\max}$) vượt mức $50\text{ MHz}$ (thực tế mạch đạt $> 65\text{ MHz}$).
  - Cột **Worst-Case Slack** (Setup/Hold) đều là số dương màu đen (không có vi phạm timing màu đỏ).

---

## 4. Phần 3: Nạp mạch (Program / Flash) lên kit DE10-Lite

### Bước 1: Kết nối kit với máy tính
1. Cắm cáp nạp USB (chuẩn USB-A to Type-B / Mini-B đi kèm kit) từ máy tính vào cổng **USB Blaster** trên kit DE10-Lite.
2. Kiểm tra đèn LED báo nguồn màu xanh lam trên kit sáng lên.

### Bước 2: Mở công cụ Quartus Programmer
1. Trong Quartus Prime, chọn menu: **Tools** $\rightarrow$ **Programmer**.
2. Cửa sổ Programmer hiện ra.

### Bước 3: Thiết lập phần cứng (Hardware Setup)
1. Ở góc trên bên trái, kiểm tra dòng **Hardware Setup...**:
   - Nếu hiển thị: `No Hardware`, nhấp chuột vào nút **Hardware Setup...**.
   - Trong bảng chọn **Currently selected hardware**, nhấp đúp chọn: **USB-Blaster [USB-0]**.
   - Bấm **Close**.
2. Mục **Mode**: Chọn chế độ **`JTAG`**.

### Bước 4: Nạp file cấu hình `.sof`
1. Nếu chưa có file hiển thị trên danh sách mạch nạp:
   - Nhấn nút **Add File...** ở menu bên trái.
   - Tìm đến thư mục:
     ```text
     D:\UltimateFreedom\UltimateFreedom\quartus\output_files\
     ```
   - Chọn file **`top_de10_lite.sof`** (hoặc `ReedSolomon.sof`) và nhấn **Open**.
2. Đánh dấu tích vào ô **Program/Configure** ở dòng tương ứng với chip `10M50DA`.
3. Nhấn nút **Start** ở góc trên bên trái để bắt đầu nạp.
4. Theo dõi thanh tiến trình **Progress**:
   - Khi thanh báo **100% (Successful)**: FPGA đã được nạp thành công và hệ thống bắt đầu chạy trực tiếp trên phần cứng thật!

---

## 5. Phần 4: Hướng dẫn tự tay thao tác kiểm chứng trên kit thật

Sau khi nạp xong, hệ thống ở trạng thái sẵn sàng. Toàn bộ đèn đỏ `LEDR[2:0]` tắt (`3'b000`), màn hình `HEX1:HEX0` hiển thị `00`.

---

### Kịch bản 1: Nhập dữ liệu gốc và chạy giải mã không lỗi (Fast-path)

Mục tiêu: Nhập khối 11 byte mẫu, kiểm tra quá trình tính 4 byte Parity và giải mã nhanh khi không có lỗi.

1. **Bước 1 — Chọn Pha nhập liệu**:
   - Gạt switch **`SW[8] = 0`** (gạt xuống mép dưới của board).
2. **Bước 2 — Nhập tuần tự 11 byte dữ liệu**:
   Ví dụ nhập chuỗi 11 byte từ `0x10` đến `0x1A`:
   - Byte 1: Gạt `SW[7:0]` thành `8'h10` (nhị phân: `0001_0000`). Màn hình hiển thị `10`. Nhấn nút **`KEY[1]`** 1 lần để chốt.
   - Byte 2: Gạt `SW[7:0]` thành `8'h11` (nhị phân: `0001_0001`). Màn hình hiển thị `11`. Nhấn nút **`KEY[1]`** 1 lần để chốt.
   - Byte 3: Gạt `SW[7:0]` thành `8'h12` $\rightarrow$ Nhấn `KEY[1]`.
   - ... Tiếp tục tương tự cho đến:
   - Byte 11: Gạt `SW[7:0]` thành `8'h1A` $\rightarrow$ Nhấn `KEY[1]`.
   *(Lưu ý: Trong suốt pha nhập, đèn LEDR luôn tắt `000`).*
3. **Bước 3 — Chuẩn bị chạy**:
   - Gạt switch **`SW[8] = 1`** (gạt lên phía trên để chuyển sang pha chạy).
   - Gạt switch **`SW[9] = 0`** (chế độ giữ nguyên từ mã chuẩn, không tạo lỗi).
4. **Bước 4 — Bắt đầu xử lý**:
   - Nhấn nút **`KEY[1]`** 1 lần.
5. **Bước 5 — Quan sát kết quả**:
   - Đèn `LEDR[0]` (Busy) nhấp nháy trong tích tắc (khoảng vài micro-giây).
   - Ngay sau đó, đèn **`LEDR[1]` (Done) chốt sáng liên tục**.
   - Đèn **`LEDR[2]` (Fail) tắt** (báo hiệu giải mã thành công).
   - Gạt các switch `SW[3:0]` từ `0000` đến `1010` để duyệt xem lại các byte dữ liệu đã giải mã trên `HEX1:HEX0`.

---

### Kịch bản 2: Tự động chèn 2 byte lỗi và chứng minh khả năng sửa sai $T=2$

Mục tiêu: Giữ nguyên dữ liệu, bật bộ tiêm lỗi tự động chèn sai lệch vào symbol 0 và symbol 14, chứng minh bộ giải mã tự động tìm đúng vị trí, tính đúng giá trị lỗi và khôi phục 100% dữ liệu gốc.

1. **Bước 1 — Chọn chế độ tạo lỗi**:
   - Switch chế độ vẫn giữ **`SW[8] = 1`** (Pha chạy).
   - Gạt switch **`SW[9] = 1`** (gạt lên để kích hoạt khối `error_injector` chèn 2 lỗi: byte 0 bị XOR với `0x55`, byte 14 bị XOR với `0xA6`).
2. **Bước 2 — Bắt đầu chạy giải mã**:
   - Nhấn nút **`KEY[1]`** 1 lần.
3. **Bước 3 — Quan sát trạng thái xử lý**:
   - Bộ điều khiển `rs_controller` nhận lệnh, xóa cờ cũ, khởi chạy pipeline:
     - `rs_encoder` tính ra từ mã 15 byte chuẩn.
     - `error_injector` tự động làm biến dạng 2 byte trong từ mã.
     - `rs_decoder` phát hiện 4 syndrome khác 0 $\rightarrow$ chạy Berlekamp–Massey tìm $\Lambda(z)$ $\rightarrow$ Error Evaluator tìm $\Omega(z)$ $\rightarrow$ Chien Search quét tìm 2 vị trí lỗi $\rightarrow$ Forney tính ra chính xác giá trị `0x55` và `0xA6` $\rightarrow$ Error Corrector sửa lại từ mã $\rightarrow$ Tính lại syndrome xác nhận từ mã đã hoàn toàn sạch lỗi.
4. **Bước 4 — Kết quả hiển thị**:
   - Đèn **`LEDR[1]` (Done) chốt sáng**.
   - Đèn **`LEDR[2]` (Fail) TẮT** (khẳng định bộ giải mã đã sửa thành công toàn bộ 2 lỗi!).
   - Gạt `SW[3:0] = 0000` (địa chỉ symbol 0): Màn hình `HEX1:HEX0` vẫn hiển thị đúng giá trị gốc ban đầu là **`10`** (dù trên đường truyền byte này đã bị lỗi thành `0x10 ^ 0x55 = 0x45`).

---

### Kịch bản 3: Thử nghiệm nút Reset (`KEY[0]`)
1. Bất kỳ lúc nào, khi nhấn nút **`KEY[0]`**:
   - Toàn bộ các đèn LED trạng thái `LEDR[2:0]` tắt ngay lập tức.
   - Màn hình `HEX1:HEX0` trở về mẫu `00`.
   - Các bộ đệm nội vi được làm sạch, hệ thống sẵn sàng cho lượt nhập mới từ đầu.

---

## 6. Xử lý sự cố thường gặp (Troubleshooting)

### Vấn đề 1: Quartus Programmer báo `No Hardware` hoặc không nhận USB Blaster
- **Nguyên nhân**: Chưa cài đặt Driver USB-Blaster cho Windows.
- **Cách khắc phục**:
  1. Mở **Device Manager** trên Windows.
  2. Tìm mục **Other devices** $\rightarrow$ nhấp chuột phải vào `USB-Blaster` $\rightarrow$ chọn **Update driver**.
  3. Chọn **Browse my computer for drivers**, trỏ đến thư mục driver có sẵn trong bộ cài Quartus:
     ```text
     C:\intelFPGA_lite\<version>\quartus\drivers\usb-blaster
     ```
  4. Nhấn **Next** để hoàn tất cài đặt driver.

### Vấn đề 2: Lỗi không tìm thấy file `rs_params.vh` khi biên dịch
- **Nguyên nhân**: Thư mục include chưa được thêm vào Search Path của Quartus.
- **Cách khắc phục**:
  - Mở file `quartus/ReedSolomon.qsf` kiểm tra dòng sau đã tồn tại:
    ```tcl
    set_global_assignment -name SEARCH_PATH ../rtl/include
    ```
  - Hoặc vào **Assignments** $\rightarrow$ **Settings...** $\rightarrow$ **Libraries** $\rightarrow$ thêm đường dẫn đến `rtl/include`.

### Vấn đề 3: Lỗi ModelSim không tự khởi động từ Quartus
- **Nguyên nhân**: Đường dẫn thực thi ModelSim trong Quartus chưa được chỉ định.
- **Cách khắc phục**:
  1. Trong Quartus Prime, chọn **Tools** $\rightarrow$ **Options...** $\rightarrow$ chọn mục **EDA Tool Options**.
  2. Tại ô **ModelSim-Altera** (hoặc **Questa Intel FPGA**), điền đúng đường dẫn thư mục cài đặt `win64`, ví dụ:
     ```text
     C:\intelFPGA_lite\<version>\modelsim_ase\win64oem
     ```

---

> **Chúc mừng bạn!** Toàn bộ hệ thống mã hóa và giải mã Reed–Solomon RS(15,11) trên GF(256) đã sẵn sàng để bạn tự tay vận hành và trình diễn thành công trên kit Terasic DE10-Lite.

