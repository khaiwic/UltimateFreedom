# Hướng dẫn từng bước: Mô phỏng, Tổng hợp Quartus Prime và Thử nghiệm trên DE10-Lite

## 1. Thông số hệ thống RS(5,3) trên GF(8)
- **Trường Galois**: $\text{GF}(8)$, $m = 3$ bit (`0..7`), $p(u) = u^3 + u + 1$ (`4'b1011`), $\alpha = 2$.
- **Mã RS(5,3)**: $N = 5$ symbol, $K = 3$ symbol thông tin, $R = 2$ symbol parity, sửa tối đa $T = 1$ symbol lỗi.
- **Hiển thị**: 3 LED 7 đoạn `HEX2` (symbol 0), `HEX1` (symbol 1), `HEX0` (symbol 2) và 10 LED đơn `LEDR[9:0]`.

## 2. Biên dịch và chạy trong ModelSim / QuestaSim
1. Chuyển tới thư mục `sim/`:
   ```tcl
   cd D:/UltimateFreedom/UltimateFreedom/sim
   ```
2. Chạy macro mô phỏng cho từng testbench (`tb_gf8_mul`, `tb_gf8_inv`, `tb_rs_encoder`, `tb_syndrome`, `tb_berlekamp_massey`, `tb_error_evaluator`, `tb_chien_search`, `tb_forney`, `tb_rs_decoder`, `tb_top`):
   ```tcl
   do run.do tb_top
   ```

## 3. Biên dịch và nạp kit trong Quartus Prime
1. Mở project [`quartus/ReedSolomon.qpf`](file:///d:/UltimateFreedom/UltimateFreedom/quartus/ReedSolomon.qpf).
2. Nhấn `Ctrl + L` (**Start Compilation**) để tạo file `quartus/output_files/ReedSolomon.sof`.
3. Mở **Tools -> Programmer**, chọn **USB-Blaster**, nạp file `ReedSolomon.sof` xuống kit DE10-Lite.

## 4. Kịch bản thử nghiệm trực tiếp trên kit DE10-Lite

### Bước 1: Nhập 3 symbol thông tin & Giải mã đúng (`SW[9] = 0`)
1. Gạt `SW[9] = 0`, `SW[8] = 0`.
2. Đặt `SW[2:0] = 001` (`1`) $\rightarrow$ đèn `LEDR[1]` sáng $\rightarrow$ nhấn `KEY[1]`.
3. Đặt `SW[2:0] = 010` (`2`) $\rightarrow$ đèn `LEDR[2]` sáng $\rightarrow$ nhấn `KEY[1]`.
4. Đặt `SW[2:0] = 011` (`3`) $\rightarrow$ đèn `LEDR[3]` sáng $\rightarrow$ nhấn `KEY[1]`.
5. Hệ thống tự động mã hóa RS(5,3) và giải mã không lỗi; màn hình `HEX2 HEX1 HEX0` hiển thị **`1 2 3`**.

### Bước 2: Chế độ nhập lỗi với 1 lỗi (Giải mã đúng $\rightarrow$ Tất cả `LEDR[9:0]` tắt)
1. Gạt `SW[9] = 1` để vào chế độ nhập lỗi.
2. Đặt `SW[2:0] = 101` (`5`, đèn `LEDR[5]` sáng) $\rightarrow$ nhấn `KEY[1]` (chèn lỗi vào symbol cuối cùng).
3. Đặt `SW[2:0] = 000` (`0`, đèn `LEDR[0]` sáng) $\rightarrow$ nhấn `KEY[1]` (symbol kế cuối không lỗi).
4. Đặt `SW[2:0] = 000` (`0`) $\rightarrow$ nhấn `KEY[1]` (symbol thứ 3 từ cuối không lỗi).
   *(Hoặc gạt `SW[8] = 1` ở bước 2 để chạy giải mã ngay sau 1 lỗi).*
5. Kết quả: bộ giải mã sửa thành công 1 lỗi, toàn bộ **`LEDR[9:0]` TẮT HẾT**, `HEX2:HEX0` vẫn hiển thị đúng **`1 2 3`**.

### Bước 3: Chế độ nhập lỗi với 2 hoặc 3 lỗi (Giải mã sai $\rightarrow$ `LEDR[9:0]` nhấp nháy)
1. Nhấn `KEY[1]` một lần để bắt đầu lượt nhập lỗi mới.
2. Lần lượt nhập các giá trị khác `0` bằng `SW[2:0]` và nhấn `KEY[1]` cho 2 hoặc 3 symbol cuối (ví dụ: `1`, `2`, `3`).
3. Kết quả: vượt quá khả năng sửa $T = 1$, toàn bộ 10 đèn **`LEDR[9:0]` NHẤP NHÁY** để báo giải mã thất bại.
4. Nhấn `KEY[0]` bất kỳ lúc nào để Reset toàn bộ hệ thống.
