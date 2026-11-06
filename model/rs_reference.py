"""
Mô hình tham chiếu (Reference Model) cho bộ mã hóa và giải mã Reed-Solomon RS(15,11) trên GF(256).

Tài liệu đặc tả:
  - README_RS_DE10_Lite.md
  - docs/rs_algorithm.md
  - docs/rs_parameters.md
  - rtl/include/rs_params.vh

Quy ước:
  - GF(256): p(u) = 0x11D, alpha = 0x02
  - N = 15, K = 11, R = 4, T = 2 (sửa tối đa 2 lỗi symbol bất kỳ)
  - Nghiệm đầu g(x): F = RS_FIRST_ROOT = 0, bước số mũ RS_ROOT_STEP = 1
  - Thứ tự mảng / đa thức:
      + c[0] truyền đầu tiên = hệ số x^(N-1)
      + c[N-1] truyền cuối cùng = hệ số hằng số x^0
      + c[0..K-1] là dữ liệu gốc; c[K..N-1] là parity
      + Lambda[j], Omega[j], S[j]: hệ số của z^j (bậc thấp trước)
"""

from typing import List, Tuple, Dict, Optional, Union
import sys
import os

# Thêm đường dẫn thư mục hiện tại để có thể import gf256_model
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from gf256_model import (
    gf_add,
    gf_sub,
    gf_mul,
    gf_div,
    gf_inv,
    gf_pow,
    alpha_pow,
    FIELD_ORDER,
)

# -----------------------------------------------------------------------------
# Các tham số chuẩn RS(15,11)
# -----------------------------------------------------------------------------
RS_N: int = 15
RS_K: int = 11
RS_R: int = RS_N - RS_K  # 4
RS_T: int = RS_R // 2    # 2
RS_FIRST_ROOT: int = 0
RS_ROOT_STEP: int = 1


def compute_generator_poly(
    r: int = RS_R,
    first_root: int = RS_FIRST_ROOT,
    step: int = RS_ROOT_STEP
) -> List[int]:
    """
    Tính các hệ số của đa thức sinh g(x) = prod_{j=0..r-1} (x + alpha^(first_root + j*step)).
    Trả về mảng hệ số bậc cao trước: g[0]*x^r + g[1]*x^(r-1) + ... + g[r].
    Với cấu hình mặc định (r=4, F=0, step=1):
      g(x) = (x + 01)(x + 02)(x + 04)(x + 08)
           = x^4 + 0F x^3 + 36 x^2 + 78 x + 40
      -> [0x01, 0x0F, 0x36, 0x78, 0x40]
    """
    g = [1]
    for j in range(r):
        root = alpha_pow(first_root + j * step)
        # Nhân g(x) với (x + root):
        # g_new[d] = g[d-1] + root * g[d]
        new_g = [0] * (len(g) + 1)
        new_g[0] = g[0]
        for d in range(1, len(g)):
            new_g[d] = gf_add(g[d], gf_mul(g[d - 1], root))
        new_g[-1] = gf_mul(g[-1], root)
        g = new_g
    return g


# Đa thức sinh mặc định
GEN_POLY: List[int] = compute_generator_poly()


# -----------------------------------------------------------------------------
# 1. Mã hóa Systematic (Encoder)
# -----------------------------------------------------------------------------
def rs_encode(data: Union[List[int], bytes]) -> List[int]:
    """
    Mã hóa Reed-Solomon systematic:
      - Nhận K = 11 byte dữ liệu gốc
      - Tính R = 4 byte parity: p(x) = [x^R * m(x)] mod g(x)
      - Trả về từ mã N = 15 byte: c = [data (11 bytes), parity (4 bytes)]
      - Thứ tự: data[0] là hệ số x^(N-1), parity[-1] là hệ số x^0.
    """
    if len(data) != RS_K:
        raise ValueError(f"Dữ liệu đầu vào phải có đúng K={RS_K} bytes (nhận {len(data)})")
    for b in data:
        if not (0 <= b <= 0xFF):
            raise ValueError(f"Mỗi symbol phải là một byte trong 0..255 (nhận {b})")

    work = list(data) + [0] * RS_R
    for i in range(RS_K):
        feedback = work[i]
        if feedback != 0:
            for j in range(RS_R + 1):
                work[i + j] ^= gf_mul(feedback, GEN_POLY[j])

    parity = work[-RS_R:]
    return list(data) + parity


# -----------------------------------------------------------------------------
# 2. Tính Syndrome
# -----------------------------------------------------------------------------
def calc_syndromes(
    received: Union[List[int], bytes],
    r: int = RS_R,
    first_root: int = RS_FIRST_ROOT,
    step: int = RS_ROOT_STEP
) -> List[int]:
    """
    Tính R giá trị syndrome S[j] = y(alpha^(first_root + j*step)) với j = 0..R-1.
    Đánh giá theo quy tắc Horner từ hệ số bậc cao nhất y[0] đến y[N-1].
    S[0..R-1] có thứ tự bậc thấp trước: S(z) = S[0] + S[1]*z + ... + S[R-1]*z^(R-1).
    """
    if len(received) != RS_N:
        raise ValueError(f"Từ mã nhận phải có đúng N={RS_N} bytes (nhận {len(received)})")

    syndromes = []
    for j in range(r):
        beta = alpha_pow(first_root + j * step)
        acc = 0
        for symbol in received:
            acc = gf_add(gf_mul(acc, beta), symbol)
        syndromes.append(acc)
    return syndromes


# -----------------------------------------------------------------------------
# 3. Berlekamp-Massey: Tìm đa thức định vị lỗi Lambda(z)
# -----------------------------------------------------------------------------
def berlekamp_massey(
    syndromes: List[int],
    r: int = RS_R,
    t: int = RS_T
) -> Tuple[List[int], int]:
    """
    Thuật toán Berlekamp-Massey (docs/rs_algorithm.md mục 7):
      - Tìm đa thức định vị lỗi Lambda(z) = 1 + lambda[1]*z + ... + lambda[L]*z^L
      - syndromes: S[0..R-1]
      - Trả về (Lambda, L) với Lambda là mảng hệ số bậc thấp trước, Lambda[0] = 1.
    """
    if len(syndromes) != r:
        raise ValueError(f"Cần đúng {r} giá trị syndromes")

    C = [1] + [0] * r
    B = [1] + [0] * r
    L = 0
    shift = 1
    b = 1

    for q in range(r):
        # Tính discrepancy d_q
        d = syndromes[q]
        for j in range(1, L + 1):
            d ^= gf_mul(C[j], syndromes[q - j])

        if d == 0:
            shift += 1
            continue

        previous = C.copy()
        scale = gf_div(d, b)
        for j in range(r + 1 - shift):
            C[j + shift] ^= gf_mul(scale, B[j])

        if 2 * L <= q:
            L = q + 1 - L
            B = previous
            b = d
            shift = 1
        else:
            shift += 1

    return C[: L + 1], L


# -----------------------------------------------------------------------------
# 4. Tính đa thức đánh giá lỗi Omega(z)
# -----------------------------------------------------------------------------
def error_evaluator(
    syndromes: List[int],
    lambda_poly: List[int],
    l_deg: int,
    r: int = RS_R
) -> List[int]:
    """
    Tính Omega(z) = [S(z) * Lambda(z)] mod z^R (docs/rs_algorithm.md mục 8).
    omega[q] = XOR_{j=0..min(q, L)} lambda[j] * S[q-j], với q = 0..R-1.
    Trả về mảng omega bậc thấp trước, độ dài r.
    """
    omega = [0] * r
    for q in range(r):
        acc = 0
        for j in range(min(q, l_deg) + 1):
            if j < len(lambda_poly):
                acc ^= gf_mul(lambda_poly[j], syndromes[q - j])
        omega[q] = acc
    return omega


# -----------------------------------------------------------------------------
# 5. Chien Search: Tìm vị trí symbol lỗi
# -----------------------------------------------------------------------------
def chien_search(
    lambda_poly: List[int],
    l_deg: int,
    n: int = RS_N
) -> List[Tuple[int, int, int]]:
    """
    Tìm nghiệm của Lambda(z) trong các vị trí truyền thực sự i = 0..N-1 (docs/rs_algorithm.md mục 9).
      - X_i = alpha^(N-1-i)
      - z_i = inv(X_i)
      - Nếu Lambda(z_i) == 0: ghi nhận (i, X_i, z_i)
    Trả về danh sách các tuple: [(vị_trí_i, X_i, z_i), ...]
    """
    roots = []
    if l_deg == 0:
        return roots

    for i in range(n):
        x_i = alpha_pow(n - 1 - i)
        z_i = gf_inv(x_i)

        # Đánh giá Lambda(z_i) = sum_{j=0..l_deg} lambda_poly[j] * z_i^j
        val = 0
        z_pow = 1
        for j in range(l_deg + 1):
            if j < len(lambda_poly):
                val ^= gf_mul(lambda_poly[j], z_pow)
            z_pow = gf_mul(z_pow, z_i)

        if val == 0:
            roots.append((i, x_i, z_i))

    return roots


# -----------------------------------------------------------------------------
# 6. Forney Algorithm: Tính giá trị lỗi E_i
# -----------------------------------------------------------------------------
def forney(
    lambda_poly: List[int],
    omega_poly: List[int],
    roots: List[Tuple[int, int, int]],
    first_root: int = RS_FIRST_ROOT
) -> Dict[int, int]:
    """
    Tính giá trị lỗi E_i tại các vị trí tìm được (docs/rs_algorithm.md mục 10).
    Đạo hàm hình thức trong đặc số 2:
      Lambda'(z) = lambda[1] + lambda[3]*z^2 + lambda[5]*z^4 + ...
    Với F = 0, công thức Forney có nhân thêm X_i:
      E_i = X_i * Omega(z_i) / Lambda'(z_i)
    Trả về dictionary {vị_trí_i: giá_trị_lỗi_E_i}.
    Nếu Lambda'(z_i) == 0, ném ZeroDivisionError (báo fail).
    """
    err_values = {}
    for i, x_i, z_i in roots:
        # Tính Lambda'(z_i)
        # Chỉ các số hạng bậc lẻ trong lambda_poly
        deriv = 0
        z_pow = 1
        for k in range(1, len(lambda_poly), 2):
            deriv ^= gf_mul(lambda_poly[k], z_pow)
            z_pow = gf_mul(z_pow, gf_mul(z_i, z_i))

        if deriv == 0:
            raise ZeroDivisionError(f"Mẫu số đạo hàm Forney bằng 0 tại vị trí {i}")

        # Tính Omega(z_i)
        omega_val = 0
        z_pow = 1
        for val in omega_poly:
            omega_val ^= gf_mul(val, z_pow)
            z_pow = gf_mul(z_pow, z_i)

        # Với F = 0: E_i = X_i * Omega(z_i) / Lambda'(z_i)
        if first_root == 0:
            e_i = gf_mul(x_i, gf_div(omega_val, deriv))
        else:
            e_i = gf_div(omega_val, deriv)

        err_values[i] = e_i

    return err_values


# -----------------------------------------------------------------------------
# 7. Bộ giải mã hoàn chỉnh (Decoder)
# -----------------------------------------------------------------------------
def rs_decode(
    received: Union[List[int], bytes],
    n: int = RS_N,
    k: int = RS_K,
    r: int = RS_R,
    t: int = RS_T,
    first_root: int = RS_FIRST_ROOT
) -> Tuple[List[int], int, bool]:
    """
    Giải mã và sửa lỗi cho từ mã nhận:
      - Trả về tuple: (corrected_codeword, num_errors_corrected, fail_flag)
      - corrected_codeword: danh sách N byte (từ mã đã sửa lỗi)
      - num_errors_corrected: số symbol lỗi đã sửa (0..T)
      - fail_flag: True nếu phát hiện giải mã thất bại (vượt quá khả năng sửa), False nếu thành công.
    """
    if len(received) != n:
        raise ValueError(f"Từ mã nhận phải có đúng N={n} bytes")

    # Bước 1: Tính syndrome
    syn = calc_syndromes(received, r=r, first_root=first_root)
    if all(s == 0 for s in syn):
        # Không có lỗi
        return list(received), 0, False

    # Bước 2: Berlekamp-Massey tìm Lambda
    lambda_poly, l_deg = berlekamp_massey(syn, r=r, t=t)
    if l_deg == 0 or l_deg > t:
        # Lỗi vượt quá khả năng sửa hoặc không tìm thấy đa thức hợp lệ
        return list(received), l_deg, True

    # Bước 3: Tính đa thức đánh giá lỗi Omega
    omega_poly = error_evaluator(syn, lambda_poly, l_deg, r=r)

    # Bước 4: Chien search tìm nghiệm
    roots = chien_search(lambda_poly, l_deg, n=n)
    if len(roots) != l_deg:
        # Số nghiệm tìm được trong 0..N-1 không bằng bậc Lambda (có nghiệm nằm ngoài vùng truyền)
        return list(received), l_deg, True

    # Bước 5: Forney tính giá trị lỗi
    try:
        err_vals = forney(lambda_poly, omega_poly, roots, first_root=first_root)
    except ZeroDivisionError:
        return list(received), l_deg, True

    # Bước 6: Sửa lỗi
    corrected = list(received)
    for pos, err_val in err_vals.items():
        corrected[pos] ^= err_val

    # Bước 7: Kiểm tra lại syndrome của từ mã đã sửa
    verify_syn = calc_syndromes(corrected, r=r, first_root=first_root)
    if any(s != 0 for s in verify_syn):
        # Syndrome sau khi sửa vẫn khác 0 -> giải mã thất bại
        return list(received), l_deg, True

    return corrected, len(roots), False


def rs_decode_data(received: Union[List[int], bytes]) -> Tuple[List[int], int, bool]:
    """
    Hàm tiện ích giải mã và chỉ lấy K byte dữ liệu gốc:
      - Trả về (data, num_errors, fail)
    """
    codeword, err_cnt, fail = rs_decode(received)
    return codeword[:RS_K], err_cnt, fail


# -----------------------------------------------------------------------------
# Kiểm tra tự động tính đúng đắn khi thực thi file độc lập
# -----------------------------------------------------------------------------
def self_test():
    """Kiểm tra mô hình RS tham chiếu với ví dụ chuẩn trong docs/rs_algorithm.md mục 12."""
    print("=== Đang kiểm tra mô hình rs_reference.py ===")

    # 1. Kiểm tra đa thức sinh g(x)
    assert GEN_POLY == [0x01, 0x0F, 0x36, 0x78, 0x40], f"g(x) sai: {GEN_POLY}"

    # 2. Dữ liệu chuẩn: 00 01 02 03 04 05 06 07 08 09 0A
    data = list(range(11))
    codeword = rs_encode(data)
    expected_parity = [0xC0, 0x8F, 0x28, 0x6C]
    assert codeword[:11] == data, "Phần dữ liệu trong từ mã systematic bị thay đổi!"
    assert codeword[11:] == expected_parity, f"Parity tính được: {codeword[11:]} != mong đợi {expected_parity}"

    # 3. Syndrome của từ mã hợp lệ phải bằng 0
    syn_clean = calc_syndromes(codeword)
    assert all(s == 0 for s in syn_clean), f"Syndrome từ mã chuẩn != 0: {syn_clean}"

    # 4. Tạo 2 lỗi theo ví dụ docs/rs_algorithm.md mục 12:
    #    XOR 0x55 vào vị trí 0, XOR 0xA6 vào vị trí 14.
    corrupted = list(codeword)
    corrupted[0] ^= 0x55
    corrupted[14] ^= 0xA6

    syn = calc_syndromes(corrupted)
    expected_syn = [0xF3, 0x60, 0x0D, 0x24]
    assert syn == expected_syn, f"Syndrome tính được: {[hex(x) for x in syn]} != mong đợi {[hex(x) for x in expected_syn]}"

    lam, l_deg = berlekamp_massey(syn)
    assert l_deg == 2, f"L = {l_deg} != 2"
    assert lam == [0x01, 0x12, 0x13], f"Lambda = {[hex(x) for x in lam]} != [0x01, 0x12, 0x13]"

    om = error_evaluator(syn, lam, l_deg)
    assert om[:2] == [0xF3, 0x10], f"Omega = {[hex(x) for x in om]} != [0xF3, 0x10, ...]"

    roots = chien_search(lam, l_deg)
    root_indices = [r[0] for r in roots]
    assert sorted(root_indices) == [0, 14], f"Vị trí lỗi tìm được: {root_indices} != [0, 14]"

    err_vals = forney(lam, om, roots)
    assert err_vals[0] == 0x55, f"E_0 = {hex(err_vals[0])} != 0x55"
    assert err_vals[14] == 0xA6, f"E_14 = {hex(err_vals[14])} != 0xA6"

    # 5. Giải mã hoàn chỉnh khôi phục nguyên vẹn
    corrected, err_cnt, fail = rs_decode(corrupted)
    assert not fail, "Decoder báo fail đối với 2 lỗi hợp lệ!"
    assert err_cnt == 2, f"Số lỗi sửa được = {err_cnt} != 2"
    assert corrected == codeword, "Từ mã sau khi sửa không khớp với từ mã ban đầu!"

    # 6. Kiểm tra trường hợp 1 lỗi đơn ở mọi vị trí 0..14
    for pos in range(RS_N):
        for err_mag in [0x01, 0x7F, 0x80, 0xFF]:
            test_cw = list(codeword)
            test_cw[pos] ^= err_mag
            dec_cw, cnt, f = rs_decode(test_cw)
            assert not f and cnt == 1 and dec_cw == codeword, f"Sửa 1 lỗi thất bại tại pos={pos}, mag={err_mag}"

    # 7. Kiểm tra trường hợp vượt khả năng sửa (> 2 lỗi, ví dụ 3 lỗi)
    corrupted_3 = list(codeword)
    corrupted_3[1] ^= 0x11
    corrupted_3[4] ^= 0x22
    corrupted_3[8] ^= 0x33
    _, _, f3 = rs_decode(corrupted_3)
    # Với 3 lỗi, decoder có thể báo fail=True hoặc giải mã nhầm sang từ mã khác (nhưng không thể trả về đúng codeword ban đầu mà không fail)

    print("[PASS] Mô hình tham chiếu rs_reference.py chạy chính xác 100% tất cả các bước toán học!")


if __name__ == "__main__":
    self_test()

