# Hướng dẫn cài đặt, Build, Chạy Testbench, Xem Sóng & Nạp Board DE10-Lite trên Windows 11

## Mục lục
1. [Chuẩn bị & Tải mã nguồn về máy Windows 11](#1-chuẩn-bị--tải-mã-nguồn-về-máy-windows-11)
2. [Cài đặt Python 3 & kiểm tra mô hình toán học](#2-cài-đặt-python-3--kiểm-tra-mô-hình-toán-học)
3. [Cài đặt Icarus Verilog + GTKWave & chạy Testbench](#3-cài-đặt-icarus-verilog--gtkwave--chạy-testbench)
4. [Hướng dẫn mở & đọc giản đồ sóng trong GTKWave](#4-hướng-dẫn-mở--đọc-giản-đồ-sóng-trong-gtkwave)
5. [Cài đặt Intel Quartus Prime Lite & Driver USB-Blaster](#5-cài-đặt-intel-quartus-prime-lite--driver-usb-blaster)
6. [Build chương trình tạo file `.sof` và `.pof` trong Quartus](#6-build-chương-trình-tạo-file-sof-và-pof-trong-quartus)
7. [Nạp file `.pof` (lưu vĩnh viễn) vào board DE10-Lite](#7-nạp-file-pof-lưu-vĩnh-viễn-vào-board-de10-lite)
8. [Kết nối CP2101, cài Hercules & Demo thực tế trên board](#8-kết-nối-cp2101-cài-hercules--demo-thực-tế-trên-board)
9. [Khắc phục lỗi thường gặp trên Windows 11](#9-khắc-phục-lỗi-thường-gặp-trên-windows-11)

---

## 1. Chuẩn bị & Tải mã nguồn về máy Windows 11

> [!IMPORTANT]
> **Quy tắc chọn thư mục lưu dự án:** Đặt code ở đường dẫn **không dấu tiếng Việt và không chứa khoảng trắng** (ví dụ `D:\UltimateFreedom` hoặc `C:\FPGA\UltimateFreedom`) để Quartus và Icarus Verilog không bị lỗi đọc file.

### Cách 1: Dùng Git (Khuyên dùng)
1. Mở **PowerShell** hoặc **Terminal** trên Windows 11, cài Git nếu máy chưa có:
   ```powershell
   winget install --id Git.Git --exact --accept-package-agreements --accept-source-agreements
   ```
2. Đóng Terminal rồi mở lại, sau đó clone repo về máy:
   ```powershell
   D:
   mkdir Projects
   cd D:\Projects
   git clone -b master git@github.com:khaiwic/UltimateFreedom.git
   cd UltimateFreedom
   ```
   *(Kiểm tra bằng `dir`: đảm bảo bạn đang ở thư mục gốc dự án có chứa các thư mục `rtl`, `tb`, `sim`, `model`, `vectors`, `quartus`).*
---

## 2. Cài đặt Python 3 & kiểm tra mô hình toán học

1. **Cài Python 3** (nếu máy chưa có):
   ```powershell
   winget install --id Python.Python.3.12 --exact --accept-package-agreements --accept-source-agreements
   ```
   *(Hoặc tải từ [python.org](https://www.python.org/downloads/windows/) — nhớ tích chọn **Add python.exe to PATH** khi cài).*

2. **Mở cửa sổ PowerShell mới**, di chuyển vào thư mục gốc dự án và chạy kiểm chứng mô hình tham chiếu:
   ```powershell
   cd D:\UltimateFreedom\UltimateFreedom
   python model\gf8_model.py
   python model\rs_reference.py
   python model\generate_vectors.py
   ```
   Kết quả phải báo **`[PASS]`** ở cả 3 lệnh.

---

## 3. Cài đặt Icarus Verilog + GTKWave & chạy Testbench

**Icarus Verilog** là trình biên dịch/mô phỏng Verilog miễn phí, gọn nhẹ, đi kèm sẵn **GTKWave** để xem giản đồ sóng và **không cần license**.

### 3.1. Cài đặt trên Windows 11
* **Cách A — Cài nhanh 1 lệnh bằng PowerShell (Khuyên dùng):**
  ```powershell
  winget install --id Icarus.Verilog --exact --accept-package-agreements --accept-source-agreements
  ```
* **Cách B — Tải bộ cài `.exe` thủ công:**
  1. Tải bản cài mới nhất cho Windows từ: [bleyer.org/icarus](https://bleyer.org/icarus/) (file dạng `iverilog-v12-xxxxxxxx-x64_setup.exe`).
  2. Chạy file `.exe` $\rightarrow$ nhấn **Next**, ở bước chọn thành phần nhớ **tích chọn cả GTKWave** và **Add executable folder(s) to the user PATH** $\rightarrow$ cài vào mặc định `C:\iverilog`.

> **Lưu ý:** Sau khi cài xong, **đóng cửa sổ PowerShell cũ và mở lại cửa sổ mới** để Windows cập nhật biến `PATH`. Kiểm tra nhanh bằng lệnh:
> ```powershell
> iverilog -V
> ```

### 3.2. Cho phép chạy script PowerShell (làm 1 lần trên Windows 11)
Mặc định Windows 11 chặn chạy file `.ps1`. Mở PowerShell và chạy lệnh sau (chọn `Y` nếu được hỏi):
```powershell
Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned
```

### 3.3. Chạy toàn bộ 11 Testbench
Trong thư mục `sim\` đã có sẵn script `run_iverilog.ps1`:
```powershell
cd D:\UltimateFreedom\UltimateFreedom\sim
.\run_iverilog.ps1
```
Script sẽ tự động biên dịch và chạy lần lượt cả **11 testbench**, đồng thời tạo 11 file dạng sóng `.vcd` ngay trong thư mục `sim\`:
1. `tb_gf8_mul` — Kiểm tra toàn bộ 64 phép nhân $\text{GF}(8)$.
2. `tb_gf8_inv` — Kiểm tra toàn bộ 8 phép nghịch đảo $\text{GF}(8)$.
3. `tb_rs_encoder` — Kiểm tra mã hóa $\text{RS}(5,3)$.
4. `tb_syndrome` — Kiểm tra tính 2 Syndrome $S_0, S_1$.
5. `tb_berlekamp_massey` — Kiểm tra tìm $\Lambda(z)$ (0 lỗi, 1 lỗi, 2 lỗi fail).
6. `tb_error_evaluator` — Kiểm tra tính $\Omega(z)$.
7. `tb_chien_search` — Kiểm tra tìm vị trí lỗi trong 5 vị trí.
8. `tb_forney` — Kiểm tra tính giá trị lỗi $E_i$.
9. `tb_rs_decoder` — Kiểm tra toàn bộ 35 trường hợp 1 lỗi + không lỗi + quá ngưỡng.
10. `tb_uart_tx` — Kiểm tra phát khung UART `8N1` (`115200 bps`).
11. `tb_top` — Kiểm tra cấp board DE10-Lite (`SW`, `KEY`, `LEDR`, `HEX2:HEX0`, và giải mã toàn bộ log ASCII gửi qua `UART_TX`).

Kết quả chuẩn ở cuối mỗi testbench đều phải hiển thị **`[PASS]`**.

### 3.4. Chạy riêng 1 Testbench và mở ngay GTKWave
Thay `tb_top` bằng tên testbench bất kỳ ở danh sách trên:
```powershell
cd D:\UltimateFreedom\UltimateFreedom\sim
.\run_iverilog.ps1 tb_top -Wave
```
*(Nếu không dùng `.ps1`, bạn có thể gọi thủ công bằng PowerShell)*:
```powershell
cd D:\UltimateFreedom\UltimateFreedom\sim
C:\iverilog\bin\iverilog.exe -g2005 -I ../rtl/include -I ../tb -o $env:TEMP\tb_top.vvp (Get-Content rtl_files.f | Where-Object { $_ -and $_ -notmatch '^(#|\+)' }) ../tb/tb_top.v
C:\iverilog\bin\vvp.exe $env:TEMP\tb_top.vvp
C:\iverilog\gtkwave\bin\gtkwave.exe tb_top.vcd
```

---

## 4. Hướng dẫn mở & đọc giản đồ sóng trong GTKWave

Khi GTKWave vừa mở file `.vcd`, vùng hiển thị sóng bên phải mặc định sẽ **đen trống** cho đến khi bạn chọn tín hiệu muốn xem:

1. **Chọn module cần soi**:
   * Ở khung **SST** (góc trên bên trái), bấm vào chữ `tb_top` (hoặc bấm dấu **`+`** để mở sâu vào `dut` $\rightarrow$ `u_controller`, `u_decoder`, `u_logger`, `u_uart_tx`...).
2. **Đưa tín hiệu sang vùng sóng**:
   * Ở khung **Type / Signals** ngay bên dưới SST, bấm chọn các tín hiệu muốn xem (hoặc bấm **`Ctrl + A`** để chọn tất cả), rồi bấm nút **`Append`** ở góc dưới bên trái.
3. **Phóng to / thu gọn thời gian**:
   * Nhấn **`Alt + F`** (hoặc bấm nút kính lúp **Zoom Fit** trên thanh công cụ) để hiển thị toàn bộ thời gian mô phỏng.
   * Cuộn chuột hoặc dùng kính lúp `+` / `-` để phóng to vào một đoạn xung clock cụ thể.
4. **Đổi định dạng hiển thị cho dễ đọc**:
   * Nhấp chuột phải vào tên tín hiệu ở cột **Signals** $\rightarrow$ **Data Format**:
     * Bus dữ liệu symbol 3-bit / 15-bit (`enc_code_out`, `corr_out`, `syn`...): chọn **Octal** (mỗi chữ số `0..7` tương ứng đúng 1 symbol $\text{GF}(8)$!).
     * Switch / LED (`SW`, `LEDR`): chọn **Binary** để nhìn rõ từng chân `SW[9]`, `SW[2:0]`, `LEDR[9:0]`.
     * Byte ASCII / 7-segment (`tx_data`, `HEX0..2`): chọn **Hex** hoặc **ASCII** (riêng `tx_data` chọn **ASCII** sẽ đọc được thẳng chữ `DATA`, `ENC`, `PASS` trên sóng!).
5. **Lưu lại bố cục sóng (tuỳ chọn)**:
   * Chọn **File $\rightarrow$ Write Save File** (lưu thành `tb_top.gtkw`) để lần sau mở lại không cần chọn lại tín hiệu.

---

## 5. Cài đặt Intel Quartus Prime Lite & Driver USB-Blaster

Để tổng hợp thiết kế Verilog và nạp file xuống kit **DE10-Lite**, bạn cần **Quartus Prime Lite Edition** (bản miễn phí, không cần license).

### 5.1. Tải và cài đặt Quartus Prime Lite
1. Truy cập trang tải chính thức của Altera / Intel FPGA:
   [https://www.intel.com/content/www/us/en/collections/products/fpga/software/downloads.html](https://www.intel.com/content/www/us/en/collections/products/fpga/software/downloads.html)
   *(Hoặc tìm `Quartus Prime Lite Edition Windows download`, đăng nhập/tạo tài khoản miễn phí nếu trang yêu cầu).*
2. Chọn phiên bản **Quartus Prime Lite Edition** (bản `22.1std` / `23.1std` / `24.1std` / `25.1std` đều dùng tốt).
3. **Quan trọng:** Khi chọn gói tải (Combined Files hoặc Individual Files), bắt buộc phải có cả 2 mục:
   * **Quartus Prime Lite Edition (Software)**
   * **MAX 10 FPGA device support** (`.qdz`) — vì chip trên DE10-Lite là `10M50DAF484C7G` thuộc họ MAX 10.
   *(Mục QuestaSim không cần cài nếu bạn đã dùng Icarus Verilog + GTKWave).*
4. Chạy bộ cài:
   * Cài vào đường dẫn mặc định (ví dụ `C:\intelFPGA_lite\23.1std` hoặc `C:\altera_lite\25.1std`).
   * Ở bước cuối cùng của trình cài đặt, tích chọn **Launch USB-Blaster II / USB-Blaster driver installation** để cài luôn driver mạch nạp.

### 5.2. Cài đặt Driver USB-Blaster thủ công (nếu Windows 11 chưa nhận kit)
1. Cắm cáp USB từ máy tính vào cổng **USB-Blaster** (cổng USB Type-B vuông lớn) trên kit DE10-Lite.
2. Nhấp chuột phải vào nút Start $\rightarrow$ chọn **Device Manager**.
3. Nếu thấy **Altera USB-Blaster** nằm trong mục **Other devices** (có dấu chấm than vàng):
   * Nhấp chuột phải $\rightarrow$ **Update driver** $\rightarrow$ **Browse my computer for drivers**.
   * Trỏ đến thư mục driver trong bộ cài Quartus:
     ```text
     C:\altera_lite\25.1std\quartus\drivers\usb-blaster
     ```
     *(Thay `C:\altera_lite\25.1std` bằng thư mục Quartus trên máy bạn; nhớ tích **Include subfolders**).*
   * Nhấn **Next** $\rightarrow$ **Install** để hoàn tất. Khi thành công, trong Device Manager mục **Universal Serial Bus controllers** sẽ hiện **`Altera USB-Blaster`**.

---

## 6. Build chương trình tạo file `.sof` và `.pof` trong Quartus

Project đã cấu hình sẵn chế độ **Internal Flash (`SINGLE IMAGE WITH ERAM`)** trong `quartus\ReedSolomon.qsf`, nên khi biên dịch xong Quartus sẽ tự động sinh **cả hai file**:
* `quartus\output_files\ReedSolomon.sof`: file nạp vào SRAM (chạy ngay, mất khi rút điện).
* `quartus\output_files\ReedSolomon.pof`: file nạp vào **Internal Flash (CFM)** của MAX 10 (lưu vĩnh viễn, tắt nguồn bật lại vẫn chạy).

### Cách 1: Build bằng giao diện Quartus Prime
1. Mở **Quartus Prime Lite** $\rightarrow$ **File $\rightarrow$ Open Project...** $\rightarrow$ chọn:
   ```text
   D:\UltimateFreedom\UltimateFreedom\quartus\ReedSolomon.qpf
   ```
2. Kiểm tra nhanh ở khung **Project Navigator** bên trái:
   * **Device**: `10M50DAF484C7G`
   * **Top-Level Entity**: `top_de10_lite`
3. Nhấn **`Ctrl + L`** (hoặc bấm biểu tượng nút Play **Start Compilation** trên thanh công cụ).
4. Đợi tất cả 4 bước (**Analysis & Synthesis**, **Fitter**, **Assembler**, **TimeQuest Timing Analysis**) chuyển sang dấu tích xanh **100% (0 errors)**.

### Cách 2: Build nhanh bằng dòng lệnh (PowerShell)
Thay đường dẫn `quartus\bin64` đúng với máy bạn:
```powershell
cd D:\UltimateFreedom\UltimateFreedom\quartus
$QBIN = "C:\altera_lite\25.1std\quartus\bin64"
& "$QBIN\quartus_map.exe" ReedSolomon
& "$QBIN\quartus_fit.exe" ReedSolomon
& "$QBIN\quartus_asm.exe" ReedSolomon
& "$QBIN\quartus_sta.exe" ReedSolomon
```

---

## 7. Nạp file `.pof` (lưu vĩnh viễn) vào board DE10-Lite

1. Cắm cáp USB-Blaster kết nối máy tính với kit DE10-Lite (đảm bảo đèn nguồn xanh trên board sáng).
2. Trong Quartus Prime, chọn **Tools $\rightarrow$ Programmer**.
3. Nhấn **Hardware Setup...** (góc trên bên trái):
   * Ở mục **Currently selected hardware**, nhấp đúp chọn **`USB-Blaster [USB-0]`** $\rightarrow$ **Close**.
   * Mục **Mode** chọn **`JTAG`**.
4. Nếu trong bảng danh sách đang có sẵn file `.sof`, chọn dòng đó rồi nhấn **Delete** ở menu bên trái để xóa đi.
5. Nhấn **Add File...** $\rightarrow$ đi tới `quartus\output_files\` $\rightarrow$ chọn **`ReedSolomon.pof`** $\rightarrow$ **Open**.
6. Tích chọn vào ô **`Program/Configure`** (Quartus sẽ tự tích cho các phân vùng Flash nội như `CFM0` / `UFM` / `10M50DA`).
7. Nhấn nút **Start** (góc trên bên trái) và đợi thanh **Progress** báo **`100% (Successful)`**.
8. **Quan trọng sau khi nạp `.pof`:** Rút cáp nguồn USB của kit DE10-Lite ra rồi cắm lại (Power-cycle) để chip MAX 10 tự động nạp chương trình từ Flash nội lên hoạt động. Từ giờ trở đi, mỗi lần cấp nguồn (kể cả qua sạc dự phòng / adapter), mạch RS(5,3) sẽ tự chạy ngay lập tức mà không cần máy tính nạp lại.

*(Mẹo: Trong quá trình test sửa code liên tục, bạn có thể nạp file **`ReedSolomon.sof`** cho nhanh; khi nào hoàn thiện mang đi bảo vệ hoặc demo thì nạp **`ReedSolomon.pof`**).*

### Nạp `.pof` nhanh bằng dòng lệnh (tuỳ chọn)
```powershell
cd D:\UltimateFreedom\UltimateFreedom\quartus
& "C:\altera_lite\25.1std\quartus\bin64\quartus_pgm.exe" -c "USB-Blaster" -m JTAG -o "p;output_files\ReedSolomon.pof"
```

---

## 8. Kết nối CP2101, cài Hercules & Demo thực tế trên board

### 8.1. Cắm dây CP2101 vào đầu cắm `JP1` (GPIO) của DE10-Lite
> [!WARNING]
> **Tuyệt đối KHÔNG cắm dây `3.3V` hoặc `5V`** giữa CP2101 và DE10-Lite. Chỉ cắm đúng **3 dây** tín hiệu & mass.

| Chân trên CP2101 | Cắm vào chân `JP1` (DE10-Lite) | Vị trí trên `JP1` (hàng chân 2×20) |
|---|---|---|
| **`TXD`** | **Pin 1** (`GPIO[0]` / `PIN_V10`) | Hàng 1, cột trái (sát FPGA) — *(dự phòng)* |
| **`RXD`** | **Pin 2** (`GPIO[1]` / `PIN_W10`) | Hàng 1, cột phải (sát mép board) |
| **`GND`** | **Pin 12** (`GND`) | Hàng 6 từ trên xuống, cột phải *(cẩn thận Pin 11 bên trái là 5V!)* |

### 8.2. Cài Driver CP2101 & Mở Hercules
1. Cắm CP2101 vào cổng USB máy tính. Mở **Device Manager $\rightarrow$ Ports (COM & LPT)** để xem số cổng `COMx` của **`Silicon Labs CP210x USB to UART Bridge`**.
   * Nếu chưa nhận driver trên Windows 11, tải và cài **CP210x Universal Windows Driver** từ [silabs.com/developers/usb-to-uart-bridge-vcp-drivers](https://www.silabs.com/developers/usb-to-uart-bridge-vcp-drivers) (giải nén $\rightarrow$ chuột phải file `silabser.inf` $\rightarrow$ **Install**).
2. Tải phần mềm **Hercules SETUP utility** (miễn phí, chạy trực tiếp không cần cài đặt từ [hw-group.com](https://www.hw-group.com/software/hercules-setup-utility)).
3. Mở Hercules $\rightarrow$ chọn tab **Serial**:
   * **Name**: `COMx` (đúng cổng của CP2101).
   * **Baud**: **`115200`**.
   * **Data size**: **`8`**, **Parity**: **`none`**, **Handshake**: **`OFF`**.
   * Nhấn **Open**.

### 8.3. Thao tác Demo kiểm chứng trên board
1. **Pha 1 — Nhập thông tin (`SW[9] = 0`, `SW[8] = 0`)**:
   * Lần lượt gạt `SW[2:0]` chọn 3 symbol (ví dụ `1`, `2`, `3`) $\rightarrow$ đèn `LEDR[1]`, `LEDR[2]`, `LEDR[3]` sáng tương ứng $\rightarrow$ nhấn `KEY[1]` sau mỗi symbol.
   * Sau lần bấm thứ 3, `HEX2 HEX1 HEX0` hiển thị **`1 2 3`**, và Hercules nhận bản tin giải mã `[INFO] ... [PASS]`.
2. **Pha 2A — Nhập 1 lỗi sửa được (`SW[9] = 1`)**:
   * Gạt `SW[9] = 1`.
   * Nhập 1 lỗi `(5, 0, 0)` (hoặc gạt `SW[8] = 1` ở lần bấm 1 để giải mã ngay sau 1 lỗi).
   * Bộ giải mã sửa đúng $\rightarrow$ **tất cả `LEDR[9:0]` TẮT**, `HEX2:HEX0` vẫn là `1 2 3`, Hercules in chi tiết `SYN`, `BM`, `OMG`, `MASK=10000`, `ERR=[0 0 0 0 5]`, `DEC: 1 2 3 4 4 [PASS]`.
3. **Pha 2B — Nhập 2 hoặc 3 lỗi vượt ngưỡng (`SW[9] = 1`)**:
   * Nhấn `KEY[1]` một lần để bắt đầu lượt lỗi mới.
   * Nhập từ 2 giá trị khác `0` trở lên (ví dụ `1`, `2`, `3`).
   * Vượt ngưỡng $T = 1$ $\rightarrow$ **toàn bộ 10 đèn `LEDR[9:0]` NHẤP NHÁY**, Hercules in `[FAIL]`.
4. Nhấn **`KEY[0]`** bất kỳ lúc nào để Reset hệ thống.

---

## 9. Khắc phục lỗi thường gặp trên Windows 11

* **PowerShell báo `cannot be loaded because running scripts is disabled on this system`:**
  Chạy `Set-ExecutionPolicy -Scope CurrentUser RemoteSigned` hoặc chạy trực tiếp:
  ```powershell
  powershell -ExecutionPolicy Bypass -File .\run_iverilog.ps1
  ```
* **Gõ `iverilog` báo `is not recognized...`:**
  Đóng PowerShell mở lại. Nếu vẫn lỗi, kiểm tra biến môi trường `Path` đã có `C:\iverilog\bin` và `C:\iverilog\gtkwave\bin` chưa.
* **Quartus Programmer báo `No Hardware` hoặc lỗi không nạp được USB-Blaster trên Windows 11:**
  1. Kiểm tra đã cài driver `usb-blaster` trong Device Manager.
  2. Thử đổi cổng USB (ưu tiên cổng USB 2.0/USB-A trực tiếp trên máy, tránh hub chia cổng).
  3. Nếu máy bật **Core Isolation / Memory Integrity** quá chặt chặn driver cũ, hãy tải bộ cài Quartus phiên bản mới (`23.1std` / `25.1std`) có driver ký số tương thích Windows 11.
* **Quartus báo lỗi không tìm thấy `rs_params.vh`:**
  Mở đúng file project `quartus\ReedSolomon.qpf` (không tạo project mới thiếu `SEARCH_PATH ../rtl/include`), hoặc vào **Assignments $\rightarrow$ Settings $\rightarrow$ Libraries** thêm `../rtl/include`.
* **Bấm `Run RTL Simulation` trong Quartus bị báo lỗi License QuestaSim:**
  Bản QuestaSim yêu cầu file license gắn theo địa chỉ MAC từng máy. Hãy dùng **Icarus Verilog + GTKWave** ở **Mục 3 và Mục 4** để chạy mô phỏng và xem sóng miễn phí trên mọi máy Windows 11.
xcxc