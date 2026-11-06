"""
Mô hình toán học các phép toán trong trường hữu hạn GF(256).

Đặc tả theo tài liệu:
  - docs/gf256.md
  - rtl/include/rs_params.vh
  - README_RS_DE10_Lite.md

Các tham số chuẩn:
  - Kích thước symbol m = 8 bit (1 byte, giá trị 0x00 .. 0xFF)
  - Đa thức trường p(u) = u^8 + u^4 + u^3 + u^2 + 1 (mã 0x11D, phần thấp 0x1D)
  - Phần tử nguyên thủy alpha = 0x02 (u)
  - Cấp của nhóm nhân: 255 (alpha^255 = 1, alpha^254 = inv(alpha))
"""

from typing import Union, List, Tuple

# Tham số chuẩn của dự án
FIELD_POLY: int = 0x11D       # p(u) = 9'h11D
POLY_LOW: int = FIELD_POLY & 0xFF  # 8'h1D: phần thấp sau khi dịch loại bỏ u^8
ALPHA: int = 0x02            # Phần tử nguyên thủy
FIELD_SIZE: int = 256        # 2^8
FIELD_ORDER: int = 255       # 2^8 - 1


# -----------------------------------------------------------------------------
# Xây dựng bảng lũy thừa (exp) và bảng logarit cơ số alpha
# -----------------------------------------------------------------------------
def _build_tables() -> Tuple[List[int], List[int]]:
    """
    Tạo bảng exp và log:
      exp_table[i] = alpha^i (với i = 0 .. 509)
      log_table[x] = i sao cho alpha^i = x (với x = 1 .. 255; log_table[0] = -1)
    """
    exp_tbl = [0] * (FIELD_ORDER * 2)
    log_tbl = [-1] * FIELD_SIZE

    cur = 1
    for i in range(FIELD_ORDER):
        exp_tbl[i] = cur
        exp_tbl[i + FIELD_ORDER] = cur
        log_tbl[cur] = i
        # Nhân với alpha = 0x02 (xtime)
        carry = cur & 0x80
        cur = ((cur << 1) & 0xFF)
        if carry:
            cur ^= POLY_LOW

    return exp_tbl, log_tbl


EXP_TABLE, LOG_TABLE = _build_tables()


# -----------------------------------------------------------------------------
# Các hàm tính toán cơ bản
# -----------------------------------------------------------------------------
def gf_add(a: int, b: int) -> int:
    """Cộng trong GF(256): phép XOR từng bit (docs/gf256.md mục 3)."""
    return (a ^ b) & 0xFF


def gf_sub(a: int, b: int) -> int:
    """Trừ trong GF(256): giống phép cộng (XOR từng bit)."""
    return (a ^ b) & 0xFF


def gf_mul_shift(a: int, b: int) -> int:
    """
    Nhân hai phần tử GF(256) bằng phương pháp dịch-và-cộng (docs/gf256.md mục 4.2).
    Thuật toán độc lập không dùng bảng tra ROM/LUT.
    """
    if not (0 <= a <= 0xFF and 0 <= b <= 0xFF):
        raise ValueError(f"Giá trị đầu vào phải nằm trong 0..255 (nhận a={a}, b={b})")
    
    product = 0
    cur_a = a
    cur_b = b
    for _ in range(8):
        if cur_b & 1:
            product ^= cur_a
        carry = cur_a & 0x80
        cur_a = (cur_a << 1) & 0xFF
        if carry:
            cur_a ^= POLY_LOW
        cur_b >>= 1
    return product


def gf_mul_lut(a: int, b: int) -> int:
    """Nhân hai phần tử GF(256) dùng bảng log và exp (docs/gf256.md mục 6)."""
    if not (0 <= a <= 0xFF and 0 <= b <= 0xFF):
        raise ValueError(f"Giá trị đầu vào phải nằm trong 0..255 (nhận a={a}, b={b})")
    if a == 0 or b == 0:
        return 0
    return EXP_TABLE[LOG_TABLE[a] + LOG_TABLE[b]]


# Phép nhân mặc định dùng bảng tra nhanh
gf_mul = gf_mul_lut


def gf_pow(a: int, exponent: int) -> int:
    """
    Lũy thừa a^exponent trong GF(256).
    Số mũ exponent là số nguyên không âm.
    """
    if not (0 <= a <= 0xFF):
        raise ValueError("Cơ số phải là byte GF(256)")
    if exponent < 0:
        raise ValueError("Số mũ phải không âm")
    if a == 0:
        return 1 if exponent == 0 else 0
    return EXP_TABLE[(LOG_TABLE[a] * (exponent % FIELD_ORDER)) % FIELD_ORDER]


def alpha_pow(exponent: int) -> int:
    """
    Tính alpha^exponent với exponent có thể là số nguyên bất kỳ (âm hoặc dương).
    Tự động rút gọn modulo 255.
    """
    e = exponent % FIELD_ORDER
    if e < 0:
        e += FIELD_ORDER
    return EXP_TABLE[e]


def gf_inv(a: int) -> int:
    """
    Nghịch đảo nhân trong GF(256): tìm y sao cho a * y = 1 (docs/gf256.md mục 5).
    Với a != 0: y = a^254 = alpha^((-log[a]) mod 255).
    Với a == 0: ném ra ngoại lệ ZeroDivisionError.
    """
    if not (0 <= a <= 0xFF):
        raise ValueError("Đầu vào phải là byte GF(256)")
    if a == 0:
        raise ZeroDivisionError("Số 0 không có nghịch đảo nhân trong GF(256)")
    return EXP_TABLE[FIELD_ORDER - LOG_TABLE[a]]


def gf_div(a: int, b: int) -> int:
    """
    Chia hai phần tử trong GF(256): a / b = a * inv(b).
    Nếu b == 0: ném ra ngoại lệ ZeroDivisionError.
    """
    if not (0 <= a <= 0xFF and 0 <= b <= 0xFF):
        raise ValueError("Đầu vào phải là byte GF(256)")
    if b == 0:
        raise ZeroDivisionError("Chia cho 0 trong GF(256)")
    if a == 0:
        return 0
    diff = LOG_TABLE[a] - LOG_TABLE[b]
    if diff < 0:
        diff += FIELD_ORDER
    return EXP_TABLE[diff]


# -----------------------------------------------------------------------------
# Lớp tiện ích đóng gói phần tử GF(256)
# -----------------------------------------------------------------------------
class GF256:
    """Lớp đối tượng đại diện cho một phần tử trong trường GF(256)."""
    __slots__ = ("val",)

    def __init__(self, val: Union[int, "GF256"] = 0):
        if isinstance(val, GF256):
            self.val = val.val
        else:
            self.val = int(val) & 0xFF

    def __int__(self) -> int:
        return self.val

    def __index__(self) -> int:
        return self.val

    def __repr__(self) -> str:
        return f"GF256(0x{self.val:02X})"

    def __add__(self, other: Union[int, "GF256"]) -> "GF256":
        other_val = other.val if isinstance(other, GF256) else (int(other) & 0xFF)
        return GF256(gf_add(self.val, other_val))

    def __sub__(self, other: Union[int, "GF256"]) -> "GF256":
        other_val = other.val if isinstance(other, GF256) else (int(other) & 0xFF)
        return GF256(gf_sub(self.val, other_val))

    def __mul__(self, other: Union[int, "GF256"]) -> "GF256":
        other_val = other.val if isinstance(other, GF256) else (int(other) & 0xFF)
        return GF256(gf_mul(self.val, other_val))

    def __truediv__(self, other: Union[int, "GF256"]) -> "GF256":
        other_val = other.val if isinstance(other, GF256) else (int(other) & 0xFF)
        return GF256(gf_div(self.val, other_val))

    def __pow__(self, exponent: int) -> "GF256":
        return GF256(gf_pow(self.val, exponent))

    def __eq__(self, other: object) -> bool:
        if isinstance(other, GF256):
            return self.val == other.val
        if isinstance(other, int):
            return self.val == (other & 0xFF)
        return False

    def inv(self) -> "GF256":
        return GF256(gf_inv(self.val))


# -----------------------------------------------------------------------------
# Kiểm tra tự động tính đúng đắn khi thực thi file độc lập
# -----------------------------------------------------------------------------
def self_test():
    """Kiểm tra đối chiếu toàn bộ các tính chất đại số và các giá trị chuẩn."""
    print("=== Đang kiểm tra mô hình gf256_model.py ===")

    # 1. Kiểm tra cấp của alpha = 0x02
    assert EXP_TABLE[0] == 0x01, "alpha^0 != 0x01"
    assert EXP_TABLE[1] == 0x02, "alpha^1 != 0x02"
    assert EXP_TABLE[255] == 0x01, "alpha^255 != 0x01"
    visited = set(EXP_TABLE[:255])
    assert len(visited) == 255, "Alpha không sinh đủ 255 phần tử khác 0!"
    assert 0 not in visited, "Số 0 không được nằm trong bảng lũy thừa alpha!"

    # 2. Đối chiếu toàn bộ 256 x 256 cặp giữa dịch-và-cộng và bảng tra LUT
    for a in range(256):
        for b in range(256):
            res_shift = gf_mul_shift(a, b)
            res_lut = gf_mul_lut(a, b)
            assert res_shift == res_lut, f"Không khớp phép nhân tại {a} * {b}: {res_shift} != {res_lut}"

    # 3. Kiểm tra các giá trị tham chiếu trong tài liệu docs/gf256.md
    assert gf_mul(0x00, 0x57) == 0x00, "0x00 * 0x57 != 0x00"
    assert gf_mul(0x01, 0x57) == 0x57, "0x01 * 0x57 != 0x57"
    assert gf_mul(0x80, 0x02) == 0x1D, "0x80 * 0x02 != 0x1D"
    assert gf_mul(0xFF, 0x02) == 0xE3, "0xFF * 0x02 != 0xE3"
    assert gf_mul(0x57, 0x83) == 0x31, "0x57 * 0x83 != 0x31"
    assert gf_mul(0x02, 0x8E) == 0x01, "0x02 * 0x8E != 0x01"
    assert gf_inv(0x02) == 0x8E, "inv(0x02) != 0x8E"

    # 4. Kiểm tra nghịch đảo nhân cho toàn bộ 255 phần tử khác 0
    for a in range(1, 256):
        inv_a = gf_inv(a)
        assert gf_mul(a, inv_a) == 0x01, f"inv({a}) = {inv_a} nhưng tích != 1"
        assert gf_div(a, a) == 0x01, f"{a} / {a} != 1"

    # 5. Kiểm tra bắt lỗi chia cho 0
    try:
        gf_inv(0)
        assert False, "gf_inv(0) không ném lỗi"
    except ZeroDivisionError:
        pass

    try:
        gf_div(0x55, 0)
        assert False, "gf_div(x, 0) không ném lỗi"
    except ZeroDivisionError:
        pass

    print("[PASS] Tất cả 65,536 phép nhân và các phép nghịch đảo GF(256) đều hoàn toàn chính xác!")


if __name__ == "__main__":
    self_test()

