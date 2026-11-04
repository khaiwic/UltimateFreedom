# Cấu hình RS và quy ước toán học

Tài liệu này tập hợp cấu hình mặc định và các quy ước phải dùng thống nhất
giữa encoder, decoder, model Python và vector kiểm thử. Giá trị cấu hình
được khai báo tại [`rtl/include/rs_params.vh`](../rtl/include/rs_params.vh).
Chi tiết phép toán và thuật toán nằm trong [gf256.md](gf256.md) và
[rs_algorithm.md](rs_algorithm.md).

[README](../README_RS_DE10_Lite.md) xác định mỗi symbol có 8 bit và để mở
các lựa chọn RS còn lại. Cấu hình RS(15,11) dưới đây là lựa chọn mặc định
đã ghi trong header, chưa phải kết quả đo hoặc xác nhận RTL đã hoạt động.

## 1. Bảng tham số hiện tại

| Macro trong header | Giá trị | Ý nghĩa |
| --- | --- | --- |
| `RS_M` | `8` | Số bit mỗi symbol |
| `GF_SIZE` | `256` | Số phần tử của GF(2^8) |
| `GF_ORDER` | `255` | Số phần tử khác 0, cũng là độ dài mã cha |
| `GF_PRIM_POLY` | `9'h11D` | Đa thức trường đầy đủ |
| `GF_ALPHA` | `8'h02` | Phần tử nguyên thủy |
| `RS_N` | `15` | Số symbol trong từ mã truyền |
| `RS_K` | `11` | Số symbol dữ liệu |
| `RS_R` | `4` | Số symbol parity, suy ra từ `RS_N - RS_K` |
| `RS_T` | `2` | Số lỗi symbol không biết vị trí bảo đảm sửa được |
| `RS_FIRST_ROOT` | `0` | Số mũ của nghiệm đầu trong đa thức sinh |
| `RS_ROOT_STEP` | `1` | Bước tăng số mũ giữa hai nghiệm liên tiếp |
| `RS_PARENT_N` | `255` | Độ dài từ mã cha đầy đủ |
| `RS_PARENT_K` | `251` | Số symbol dữ liệu của mã cha |
| `RS_SHORTEN` | `240` | Số symbol dữ liệu 0 bỏ ở đầu từ mã cha |

Các quan hệ suy ra:

```text
GF_SIZE     = 2^RS_M
GF_ORDER    = GF_SIZE - 1
RS_R        = RS_N - RS_K
RS_T        = floor(RS_R / 2)
RS_PARENT_N = GF_ORDER
RS_PARENT_K = RS_PARENT_N - RS_R
RS_SHORTEN  = RS_PARENT_N - RS_N = RS_PARENT_K - RS_K
```

Mỗi khối chứa 88 bit dữ liệu và 32 bit parity, tổng cộng 120 bit được truyền.
Khoảng cách tối thiểu của mã hiện tại là `d_min = RS_R + 1 = 5`.
Khả năng sửa 2 lỗi áp dụng cho tổng số symbol sai trong cả dữ liệu và parity;
một byte có nhiều bit sai vẫn là một lỗi symbol.

Đây là cấu hình tại thời điểm biên dịch, không phải các trường cấu hình
được thay đổi bằng switch trong lúc xử lý một khối.

## 2. Trường GF(256) và cách biểu diễn byte

Mỗi byte biểu diễn một đa thức nhị phân theo cơ sở đa thức:

```text
a[7:0] <-> a[7]*u^7 + ... + a[1]*u + a[0]
p(u) = u^8 + u^4 + u^3 + u^2 + 1
alpha = u <-> 0x02
```

Bit 0 ứng với hệ số hằng; bit 7 ứng với hệ số bậc 7. Ví dụ `0xA7` ứng với
`u^7 + u^5 + u^2 + u + 1`.

`GF_PRIM_POLY` cần 9 bit vì có hệ số của `u^8`. Khi nhân một byte với
`alpha`, phần thấp của đa thức rút gọn là `0x1D`, dùng sau khi bit bậc 8 đã
bị loại. Không lưu đa thức đầy đủ `0x11D` vào hằng 8 bit.

Các quy tắc số học cần giữ:

- Cộng và trừ hệ số GF là XOR từng bit.
- Nhân hệ số là nhân đa thức nhị phân và rút gọn theo `p(u)`.
- Với `a != 0`, `a^255 = 1`, `inverse(a) = a^254`.
- Nghịch đảo của 0 và phép chia cho 0 không xác định.
- `alpha^0 = 0x01`; `alpha^255 = 0x01`; số 0 không phải một lũy thừa của alpha.
- Số mũ của alpha được tính bằng số học nguyên modulo 255; không dùng XOR
  thay cho phép cộng/trừ số mũ. Không tra `log[0]` như giá trị hợp lệ.

RS(15,11) ở đây vẫn dùng GF(256), không thay trường theo độ dài khối.

## 3. Tên biến và thứ tự hệ số

| Ký hiệu | Ý nghĩa |
| --- | --- |
| `u` | Biến đa thức nhị phân biểu diễn bên trong một byte |
| `x` | Biến đa thức dữ liệu, từ mã và đa thức sinh RS |
| `z` | Biến đa thức syndrome, định vị và đánh giá lỗi |
| `m[i]` | Byte dữ liệu tại chỉ số truyền `i` |
| `c[i]` | Byte từ mã hợp lệ tại chỉ số truyền `i` |
| `y[i]` | Byte nhận tại chỉ số truyền `i` |
| `E_i` | Giá trị lỗi XOR tại chỉ số truyền `i` |

Tất cả chỉ số symbol bắt đầu từ 0. Byte đầu truyền trước và là hệ số bậc cao:

```text
m(x) = m[0]*x^(K-1) + ... + m[K-1]
c(x) = c[0]*x^(N-1) + ... + c[N-1]
y(x) = c(x) + e(x)
```

Trong các công thức, `N = RS_N`, `K = RS_K`, `R = RS_R`, `T = RS_T`.
Thứ tự byte và thứ tự bit trong một byte là hai quy ước riêng; không đảo
bit của byte chỉ vì hệ số từ mã được truyền từ bậc cao xuống thấp.

Quy ước lưu mảng:

| Mảng | Hệ số tại chỉ số `j` |
| --- | --- |
| `m[j]` | Hệ số của `x^(K-1-j)` |
| `c[j]`, `y[j]` | Hệ số của `x^(N-1-j)` |
| `g[j]` | Hệ số của `x^(R-j)` |
| `parity[j]` | Hệ số của `x^(R-1-j)` trong phần dư |
| `S[j]` | Hệ số của `z^j` trong `S(z)` |
| `lambda[j]` | Hệ số của `z^j` trong `Lambda(z)` |
| `omega[j]` | Hệ số của `z^j` trong `Omega(z)` |

Đa thức dữ liệu/từ mã và mảng `g` có bậc cao trước; các mảng syndrome,
Lambda, Omega có bậc thấp trước. Khi dùng cùng một hàm đánh giá Horner,
phải chọn đúng chiều duyệt mảng.

## 4. Đa thức sinh và dạng systematic

Đặt `F = RS_FIRST_ROOT = 0`. Với bước số mũ bằng 1:

```text
g(x) = product từ j=0 đến R-1 của (x + alpha^(F+j))
     = (x + 01)(x + 02)(x + 04)(x + 08)
     = x^4 + 0F*x^3 + 36*x^2 + 78*x + 40
g = [01, 0F, 36, 78, 40]
```

Các hệ số hai chữ số ở trên viết ở hệ hexadecimal, phép nhân/cộng hệ số
thực hiện trong GF(256). `g[0] = 0x01` là hệ số cao nhất. Không đảo mảng hệ
số này khi dùng thuật toán chia đã mô tả trong tài liệu thuật toán.

Mã hóa systematic theo công thức:

```text
p(x) = [x^R * m(x)] mod g(x)
c(x) = x^R * m(x) + p(x)
c = [m[0], ..., m[K-1], parity[0], ..., parity[R-1]]
```

`p(x)` là phần dư parity, khác với đa thức trường `p(u)`. Phần dư được xuất
đủ `R` symbol, gồm cả các hệ số 0 ở đầu. Các chỉ số từ mã hiện tại là:

| Vùng | Chỉ số trong từ mã | Số symbol |
| --- | --- | --- |
| Dữ liệu | `0..10` | 11 |
| Parity | `11..14` | 4 |

## 5. Quy tắc rút ngắn mã

Cấu hình hiện tại rút ngắn mã cha RS(255,251) bằng cách cố định 240 symbol
dữ liệu đầu bằng 0, mã hóa và bỏ đúng 240 symbol đó khi truyền:

```text
Dữ liệu mã cha: [240 byte 00, 11 byte dữ liệu]
Từ mã cha:     [240 byte 00, 11 byte dữ liệu, 4 byte parity]
Từ mã truyền:              [11 byte dữ liệu, 4 byte parity]
```

Đa thức trường, alpha, các nghiệm và đa thức sinh được giữ theo cấu hình
mã cha. Có thể tính parity trực tiếp trên 11 byte khi trạng thái ban đầu
bằng 0. Decoder nhận đúng 15 byte thực sự truyền.

Nếu dùng chỉ số mã cha `j`, liên hệ với chỉ số truyền `i` là:

```text
j = RS_SHORTEN + i = 240 + i
RS_PARENT_N - 1 - j = RS_N - 1 - i = 14 - i
```

Đây là cơ sở để giữ nguyên công thức số mũ vị trí lỗi sau khi rút ngắn.
Các vị trí mã cha `0..239` không được xem là vị trí lỗi của khối nhận.

## 6. Quy ước syndrome

Syndrome bắt đầu ở chỉ số 0, ứng với nghiệm đầu `alpha^0`:

```text
S[j] = y(alpha^(F+j)), j = 0..R-1
S(z) = S[0] + S[1]*z + S[2]*z^2 + S[3]*z^3
```

| Chỉ số syndrome | Điểm đánh giá |
| --- | --- |
| `S[0]` | `alpha^0 = 0x01` |
| `S[1]` | `alpha^1 = 0x02` |
| `S[2]` | `alpha^2 = 0x04` |
| `S[3]` | `alpha^3 = 0x08` |

Phải đánh giá đủ `N` symbol, gồm cả parity. Tất cả syndrome bằng 0 là điều
kiện từ mã hợp lệ; chỉ riêng `S[0] = 0` không đủ để kết luận không có lỗi.

## 7. Định vị lỗi, Omega và Forney

Với mỗi vị trí lỗi `i` trong khối truyền:

```text
X_i = alpha^(N-1-i)
z_i = inverse(X_i)
Lambda(z) = product trên các vị trí lỗi i của (1 + X_i*z)
Lambda(0) = 1
Omega(z) = [S(z) * Lambda(z)] mod z^R
```

Chien search kiểm tra `Lambda(z_i) = 0`. Lambda được chuẩn hóa có hệ số
hằng bằng 1; kết quả của thuật toán có hệ số tỷ lệ khác phải được xử lý
nhất quán trước khi kết hợp với Omega và Forney.

Đạo hàm hình thức trong đặc số 2 là:

```text
Lambda'(z) = lambda[1] + lambda[3]*z^2 + lambda[5]*z^4 + ...
```

Với bước số mũ bằng 1, giá trị lỗi được tính theo quy ước:

```text
E_i = X_i^(1-F) * Omega(z_i) / Lambda'(z_i)
```

**Vì `F = 0`, cấu hình hiện tại yêu cầu:**

```text
E_i = X_i * Omega(z_i) / Lambda'(z_i)
corrected[i] = y[i] XOR E_i
```

Không bỏ hệ số `X_i`. Các phép nhân/chia trong công thức là phép toán GF;
mẫu số phải khác 0. Chi tiết thuật toán và nguồn đối chiếu công thức có
trong [rs_algorithm.md](rs_algorithm.md), mục 7–11.

Các mốc vị trí để kiểm tra việc ánh xạ:

| Chỉ số truyền `i` | Chỉ số mã cha `j` | Số mũ `N-1-i` | `X_i` | `z_i` |
| --- | --- | --- | --- | --- |
| 0 | 240 | 14 | `0x13` | `0x58` |
| 14 | 254 | 0 | `0x01` | `0x01` |

## 8. Điều kiện thành công và giới hạn

Với khối nhận có lỗi trong giới hạn, cần tìm được đúng số nghiệm phân biệt
bằng bậc Lambda trong miền vị trí truyền, tính được giá trị lỗi và đưa đủ
`R` syndrome sau sửa về 0. Decoder hiện được đặc tả cho lỗi không biết vị
trí; hỗ trợ erasure chưa nằm trong cấu hình này.

`fail` biểu thị thất bại phát hiện được, ví dụ bậc Lambda vượt `T`, nghiệm
không đủ, mẫu số Forney bằng 0 hoặc syndrome sau sửa còn khác 0. `fail = 0`
không bảo đảm khôi phục đúng dữ liệu gốc nếu số lỗi vượt quá `T`. Checker
của demo cần so sánh kết quả với bản gốc đã lưu.

Kết quả toán học là từ mã đã sửa `N` symbol; dữ liệu gốc nằm trong `K`
symbol đầu. Hợp đồng module phải xác định đầu ra xuất `K` symbol hay `N`
symbol. Độ trễ, thời điểm `start/done` và bắt tay không được suy ra từ các
tham số toán học; chúng cần được quy định riêng trong giao diện RTL.

## 9. Ví dụ chuẩn để đối chiếu cấu hình

Với đầu vào 11 byte tăng dần, cấu hình này cho:

```text
Data     = 00 01 02 03 04 05 06 07 08 09 0A
Parity   = C0 8F 28 6C
Codeword = 00 01 02 03 04 05 06 07 08 09 0A C0 8F 28 6C
Syndrome = 00 00 00 00
```

Ví dụ này xác định đồng thời đa thức trường, các nghiệm, cách ghép parity
và thứ tự symbol cần đối chiếu. Nó là một vector mẫu; không thay thế toàn
bộ kiểm thử. Trường hợp sửa hai lỗi trên cùng từ mã được mô tả trong tài
liệu thuật toán, mục 12.

## 10. Sử dụng và thay đổi cấu hình

Trong RTL hoặc testbench, include header rồi lấy macro làm tham số cục bộ
thay vì chép các giá trị rời rạc:

```verilog
`include "rs_params.vh"

// Dat cac khai bao nay ben trong module su dung.
localparam integer SYMBOL_W = `RS_M;
localparam integer CODE_N   = `RS_N;
localparam integer DATA_K   = `RS_K;
localparam integer PARITY_R = `RS_R;
localparam [8:0] FIELD_POLY = `GF_PRIM_POLY;
localparam [7:0] ALPHA      = `GF_ALPHA;
```

Công cụ tổng hợp và simulator cần có `rtl/include` trong đường dẫn tìm
include. Model Python phải dùng cùng giá trị và quy ước; không mặc định
một thư viện RS bất kỳ đã khớp với cấu hình dự án.

Khi thay đổi cấu hình, đối chiếu các điều kiện và phần phụ thuộc sau:

- Giữ `0 < K < N <= 255`, `R = N - K` và `T = floor(R/2)` cho profile
  GF(256) hiện tại; mã cha có `N_parent = 255`, `K_parent = 255 - R`.
- Kiểm tra đa thức trường và tính nguyên thủy của alpha nếu đổi trường.
  Header hiện dùng hằng đa thức 9 bit và alpha 8 bit; đổi riêng `RS_M`
  không tự tạo ra thiết kế tổng quát cho GF(2^m).
- Sinh lại hệ số `g`, bảng GF, điểm syndrome, hệ số nhân cố định và vector
  nếu đổi các giá trị ảnh hưởng đến chúng.
- Giữ `RS_ROOT_STEP = 1` cho các công thức vị trí/Forney trong tài liệu
  hiện tại; việc đổi bước cần xét lại các công thức và triển khai decoder.
- Cập nhật kích thước bộ đệm, bộ đếm, số hệ số, số chu kỳ xử lý và logic
  giao tiếp nếu thay `N`, `K` hoặc `R`.
- Đồng bộ header, model, testbench và cả ba tài liệu toán học trước khi
  dùng cấu hình mới để tạo kết quả tham chiếu.

Clock board 50 MHz và bảng chân là cấu hình phần cứng được mô tả riêng
trong [pin_assignment.md](pin_assignment.md); chúng không thay đổi phép
toán GF hay khả năng sửa lỗi của mã.
