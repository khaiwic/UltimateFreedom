"""
Tuong thich import cho ten cu gf256_model -> chuyen tiep sang gf8_model (GF(8)).
"""

from gf8_model import (  # noqa: F401
    FIELD_POLY,
    POLY_LOW,
    ALPHA,
    FIELD_SIZE,
    FIELD_ORDER,
    EXP_TABLE,
    LOG_TABLE,
    gf_add,
    gf_sub,
    gf_mul_shift,
    gf_mul_lut,
    gf_mul,
    gf_pow,
    alpha_pow,
    gf_inv,
    gf_div,
    GF8,
    self_test,
)

GF256 = GF8

if __name__ == "__main__":
    self_test()
