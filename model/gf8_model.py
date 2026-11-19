"""
Mo hinh toan hoc cac phep toan trong truong huu han GF(8).

Cac tham so chuan:
  - Kich thuoc symbol m = 3 bit (gia tri 0 .. 7)
  - Da thuc truong p(u) = u^3 + u + 1 (ma 4'b1011 = 0xB, phan thap 3'b011 = 3)
  - Phan tu nguyen thuy alpha = 2 (u)
  - Cap cua nhom nhan: 7 (alpha^7 = 1, alpha^6 = inv(alpha) = 5)
"""

from typing import Union, List, Tuple

FIELD_POLY: int = 0x0B       # p(u) = u^3 + u + 1
POLY_LOW: int = 0x03         # Phan thap 3-bit
ALPHA: int = 0x02            # Phan tu nguyen thuy
FIELD_SIZE: int = 8          # 2^3
FIELD_ORDER: int = 7         # 2^3 - 1


def _build_tables() -> Tuple[List[int], List[int]]:
    exp_tbl = [0] * (FIELD_ORDER * 2)
    log_tbl = [-1] * FIELD_SIZE

    cur = 1
    for i in range(FIELD_ORDER):
        exp_tbl[i] = cur
        exp_tbl[i + FIELD_ORDER] = cur
        log_tbl[cur] = i
        carry = cur & 0x04
        cur = (cur << 1) & 0x07
        if carry:
            cur ^= POLY_LOW

    return exp_tbl, log_tbl


EXP_TABLE, LOG_TABLE = _build_tables()


def gf_add(a: int, b: int) -> int:
    return (a ^ b) & 0x07


def gf_sub(a: int, b: int) -> int:
    return (a ^ b) & 0x07


def gf_mul_shift(a: int, b: int) -> int:
    if not (0 <= a <= 7 and 0 <= b <= 7):
        raise ValueError(f"Gia tri phai nam trong 0..7 (nhan a={a}, b={b})")
    product = 0
    cur_a = a
    cur_b = b
    for _ in range(3):
        if cur_b & 1:
            product ^= cur_a
        carry = cur_a & 0x04
        cur_a = (cur_a << 1) & 0x07
        if carry:
            cur_a ^= POLY_LOW
        cur_b >>= 1
    return product


def gf_mul_lut(a: int, b: int) -> int:
    if not (0 <= a <= 7 and 0 <= b <= 7):
        raise ValueError(f"Gia tri phai nam trong 0..7 (nhan a={a}, b={b})")
    if a == 0 or b == 0:
        return 0
    return EXP_TABLE[LOG_TABLE[a] + LOG_TABLE[b]]


gf_mul = gf_mul_lut


def gf_pow(a: int, exponent: int) -> int:
    if not (0 <= a <= 7):
        raise ValueError("Co so phai la symbol GF(8) trong 0..7")
    if exponent < 0:
        raise ValueError("So mu phai khong am")
    if a == 0:
        return 1 if exponent == 0 else 0
    return EXP_TABLE[(LOG_TABLE[a] * (exponent % FIELD_ORDER)) % FIELD_ORDER]


def alpha_pow(exponent: int) -> int:
    e = exponent % FIELD_ORDER
    if e < 0:
        e += FIELD_ORDER
    return EXP_TABLE[e]


def gf_inv(a: int) -> int:
    if not (0 <= a <= 7):
        raise ValueError("Dau vao phai nam trong 0..7")
    if a == 0:
        raise ZeroDivisionError("So 0 khong co nghich dao trong GF(8)")
    return EXP_TABLE[FIELD_ORDER - LOG_TABLE[a]]


def gf_div(a: int, b: int) -> int:
    if not (0 <= a <= 7 and 0 <= b <= 7):
        raise ValueError("Dau vao phai nam trong 0..7")
    if b == 0:
        raise ZeroDivisionError("Chia cho 0 trong GF(8)")
    if a == 0:
        return 0
    diff = LOG_TABLE[a] - LOG_TABLE[b]
    if diff < 0:
        diff += FIELD_ORDER
    return EXP_TABLE[diff]


class GF8:
    __slots__ = ("val",)

    def __init__(self, val: Union[int, "GF8"] = 0):
        self.val = val.val if isinstance(val, GF8) else (int(val) & 0x07)

    def __int__(self) -> int:
        return self.val

    def __index__(self) -> int:
        return self.val

    def __repr__(self) -> str:
        return f"GF8({self.val})"

    def __add__(self, other: Union[int, "GF8"]) -> "GF8":
        ov = other.val if isinstance(other, GF8) else (int(other) & 0x07)
        return GF8(gf_add(self.val, ov))

    def __sub__(self, other: Union[int, "GF8"]) -> "GF8":
        ov = other.val if isinstance(other, GF8) else (int(other) & 0x07)
        return GF8(gf_sub(self.val, ov))

    def __mul__(self, other: Union[int, "GF8"]) -> "GF8":
        ov = other.val if isinstance(other, GF8) else (int(other) & 0x07)
        return GF8(gf_mul(self.val, ov))

    def __truediv__(self, other: Union[int, "GF8"]) -> "GF8":
        ov = other.val if isinstance(other, GF8) else (int(other) & 0x07)
        return GF8(gf_div(self.val, ov))

    def __pow__(self, exponent: int) -> "GF8":
        return GF8(gf_pow(self.val, exponent))

    def __eq__(self, other: object) -> bool:
        if isinstance(other, GF8):
            return self.val == other.val
        if isinstance(other, int):
            return self.val == (other & 0x07)
        return False

    def inv(self) -> "GF8":
        return GF8(gf_inv(self.val))


def self_test():
    print("=== Dang kiem tra mo hinh gf8_model.py ===")
    assert EXP_TABLE[:7] == [1, 2, 4, 3, 6, 7, 5], f"EXP_TABLE sai: {EXP_TABLE[:7]}"
    assert EXP_TABLE[7] == 1

    for a in range(8):
        for b in range(8):
            assert gf_mul_shift(a, b) == gf_mul_lut(a, b)

    expected_inv = {1: 1, 2: 5, 3: 6, 4: 7, 5: 2, 6: 3, 7: 4}
    for a in range(1, 8):
        assert gf_inv(a) == expected_inv[a]
        assert gf_mul(a, gf_inv(a)) == 1

    print("[PASS] Tat ca 64 phep nhan va 7 phep nghich dao GF(8) deu chinh xac!")


if __name__ == "__main__":
    self_test()
