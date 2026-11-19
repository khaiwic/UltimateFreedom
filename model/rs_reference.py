"""
Mo hinh tham chieu (Reference Model) cho bo ma hoa va giai ma Reed-Solomon RS(5,3) tren GF(8).

Quy uoc:
  - GF(8): p(u) = u^3 + u + 1 (0x0B), alpha = 2
  - N = 5, K = 3, R = 2, T = 1 (sua toi da 1 symbol loi bat ky)
  - Nghiem dau g(x): F = 0, buoc so mu = 1 -> g(x) = (x + 1)(x + 2) = x^2 + 3x + 2
  - Thu tu mang:
      + c[0] truyen dau tien = he so x^4 (sym 0)
      + c[4] truyen cuoi cung = he so x^0 (sym 4)
      + c[0..2] la 3 symbol du lieu; c[3..4] la 2 symbol parity
"""

from typing import List, Tuple, Dict, Union
import sys
import os

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from gf8_model import (
    gf_add,
    gf_mul,
    gf_div,
    gf_inv,
    alpha_pow,
)

RS_N: int = 5
RS_K: int = 3
RS_R: int = RS_N - RS_K  # 2
RS_T: int = RS_R // 2    # 1
RS_FIRST_ROOT: int = 0
RS_ROOT_STEP: int = 1


def compute_generator_poly(
    r: int = RS_R,
    first_root: int = RS_FIRST_ROOT,
    step: int = RS_ROOT_STEP
) -> List[int]:
    """g(x) = (x + 1)(x + 2) = x^2 + 3x + 2 -> [1, 3, 2]."""
    g = [1]
    for j in range(r):
        root = alpha_pow(first_root + j * step)
        new_g = [0] * (len(g) + 1)
        new_g[0] = g[0]
        for d in range(1, len(g)):
            new_g[d] = gf_add(g[d], gf_mul(g[d - 1], root))
        new_g[-1] = gf_mul(g[-1], root)
        g = new_g
    return g


GEN_POLY: List[int] = compute_generator_poly()


def rs_encode(data: Union[List[int], bytes]) -> List[int]:
    if len(data) != RS_K:
        raise ValueError(f"Du lieu dau vao phai co dung K={RS_K} symbol (nhan {len(data)})")
    for s in data:
        if not (0 <= s <= 7):
            raise ValueError(f"Moi symbol phai nam trong 0..7 (nhan {s})")

    work = list(data) + [0] * RS_R
    for i in range(RS_K):
        feedback = work[i]
        if feedback != 0:
            for j in range(RS_R + 1):
                work[i + j] ^= gf_mul(feedback, GEN_POLY[j])

    parity = work[-RS_R:]
    return list(data) + parity


def calc_syndromes(
    received: Union[List[int], bytes],
    r: int = RS_R,
    first_root: int = RS_FIRST_ROOT,
    step: int = RS_ROOT_STEP
) -> List[int]:
    if len(received) != RS_N:
        raise ValueError(f"Tu ma nhan phai co dung N={RS_N} symbol (nhan {len(received)})")

    syndromes = []
    for j in range(r):
        beta = alpha_pow(first_root + j * step)
        acc = 0
        for symbol in received:
            acc = gf_add(gf_mul(acc, beta), symbol)
        syndromes.append(acc)
    return syndromes


def berlekamp_massey(
    syndromes: List[int],
    r: int = RS_R,
    t: int = RS_T
) -> Tuple[List[int], int]:
    if len(syndromes) != r:
        raise ValueError(f"Can dung {r} gia tri syndromes")

    C = [1] + [0] * r
    B = [1] + [0] * r
    L = 0
    shift = 1
    b = 1

    for q in range(r):
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


def error_evaluator(
    syndromes: List[int],
    lambda_poly: List[int],
    l_deg: int,
    r: int = RS_R
) -> List[int]:
    omega = [0] * r
    for q in range(r):
        acc = 0
        for j in range(min(q, l_deg) + 1):
            if j < len(lambda_poly):
                acc ^= gf_mul(lambda_poly[j], syndromes[q - j])
        omega[q] = acc
    return omega


def chien_search(
    lambda_poly: List[int],
    l_deg: int,
    n: int = RS_N
) -> List[Tuple[int, int, int]]:
    roots = []
    if l_deg == 0:
        return roots

    for i in range(n):
        x_i = alpha_pow(n - 1 - i)
        z_i = gf_inv(x_i)

        val = 0
        z_pow = 1
        for j in range(l_deg + 1):
            if j < len(lambda_poly):
                val ^= gf_mul(lambda_poly[j], z_pow)
            z_pow = gf_mul(z_pow, z_i)

        if val == 0:
            roots.append((i, x_i, z_i))

    return roots


def forney(
    lambda_poly: List[int],
    omega_poly: List[int],
    roots: List[Tuple[int, int, int]],
    first_root: int = RS_FIRST_ROOT
) -> Dict[int, int]:
    err_values = {}
    for i, x_i, z_i in roots:
        deriv = 0
        z_pow = 1
        for k in range(1, len(lambda_poly), 2):
            deriv ^= gf_mul(lambda_poly[k], z_pow)
            z_pow = gf_mul(z_pow, gf_mul(z_i, z_i))

        if deriv == 0:
            raise ZeroDivisionError(f"Mau so dao ham Forney bang 0 tai vi tri {i}")

        omega_val = 0
        z_pow = 1
        for val in omega_poly:
            omega_val ^= gf_mul(val, z_pow)
            z_pow = gf_mul(z_pow, z_i)

        if first_root == 0:
            e_i = gf_mul(x_i, gf_div(omega_val, deriv))
        else:
            e_i = gf_div(omega_val, deriv)

        err_values[i] = e_i

    return err_values


def rs_decode(
    received: Union[List[int], bytes],
    n: int = RS_N,
    k: int = RS_K,
    r: int = RS_R,
    t: int = RS_T,
    first_root: int = RS_FIRST_ROOT
) -> Tuple[List[int], int, bool]:
    if len(received) != n:
        raise ValueError(f"Tu ma nhan phai co dung N={n} symbol")

    syn = calc_syndromes(received, r=r, first_root=first_root)
    if all(s == 0 for s in syn):
        return list(received), 0, False

    lambda_poly, l_deg = berlekamp_massey(syn, r=r, t=t)
    if l_deg == 0 or l_deg > t:
        return list(received), l_deg, True

    omega_poly = error_evaluator(syn, lambda_poly, l_deg, r=r)

    roots = chien_search(lambda_poly, l_deg, n=n)
    if len(roots) != l_deg:
        return list(received), l_deg, True

    try:
        err_vals = forney(lambda_poly, omega_poly, roots, first_root=first_root)
    except ZeroDivisionError:
        return list(received), l_deg, True

    corrected = list(received)
    for pos, err_val in err_vals.items():
        corrected[pos] ^= err_val

    verify_syn = calc_syndromes(corrected, r=r, first_root=first_root)
    if any(s != 0 for s in verify_syn):
        return list(received), l_deg, True

    return corrected, len(roots), False


def rs_decode_data(received: Union[List[int], bytes]) -> Tuple[List[int], int, bool]:
    codeword, err_cnt, fail = rs_decode(received)
    return codeword[:RS_K], err_cnt, fail


def self_test():
    print("=== Dang kiem tra mo hinh rs_reference.py (RS(5,3) tren GF(8)) ===")
    assert GEN_POLY == [1, 3, 2], f"g(x) sai: {GEN_POLY}"

    data = [1, 2, 3]
    codeword = rs_encode(data)
    assert codeword == [1, 2, 3, 4, 4], f"codeword = {codeword} != [1, 2, 3, 4, 4]"
    assert calc_syndromes(codeword) == [0, 0]

    # Kiem tra tat ca 5 vi tri x 7 gia tri loi don
    for pos in range(RS_N):
        for err_mag in range(1, 8):
            rx = list(codeword)
            rx[pos] ^= err_mag
            dec_cw, cnt, f = rs_decode(rx)
            assert not f and cnt == 1 and dec_cw == codeword, (
                f"Sua 1 loi that bai tai pos={pos}, mag={err_mag}"
            )

    # In mot so gia tri tham chieu de doi chieu testbench
    rx_ex = list(codeword)
    rx_ex[4] ^= 5  # Loi 5 tai vi tri cuoi (sym 4)
    syn_ex = calc_syndromes(rx_ex)
    lam_ex, deg_ex = berlekamp_massey(syn_ex)
    om_ex = error_evaluator(syn_ex, lam_ex, deg_ex)
    roots_ex = chien_search(lam_ex, deg_ex)
    eval_ex = forney(lam_ex, om_ex, roots_ex)
    print(f"  Vi du 1 loi (sym4 ^= 5): rx={rx_ex}, syn={syn_ex}, lam={lam_ex}, omega={om_ex}, roots={roots_ex}, err={eval_ex}")

    print("[PASS] Mo hinh tham chieu rs_reference.py RS(5,3) tren GF(8) chinh xac 100%!")


if __name__ == "__main__":
    self_test()
