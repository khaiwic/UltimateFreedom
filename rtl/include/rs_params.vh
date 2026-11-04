`ifndef RS_PARAMS_VH
`define RS_PARAMS_VH

// Shared parameters for the RS encoder, decoder and testbenches.
// README_RS_DE10_Lite.md fixes m = 8, but leaves the other RS choices open.
// The values below select a small demo profile; they are project defaults,
// not additional requirements stated by the README.

// GF(2^8): polynomial-basis bytes, with bit i representing u^i.
// p(u) = u^8 + u^4 + u^3 + u^2 + 1; alpha = u.
// Keep the u^8 term: the field polynomial requires 9 bits.
`define RS_M             8
`define GF_SIZE          (1 << `RS_M)
`define GF_ORDER         (`GF_SIZE - 1)
`define GF_PRIM_POLY     9'h11D
`define GF_ALPHA         8'h02

// Shortened systematic RS(15,11) over GF(256), not over GF(16).
// Input: K data bytes. Output: those K bytes followed by R parity bytes.
// T is the guaranteed correction capacity for unknown symbol errors.
// Required: 0 < K < N <= GF_ORDER.
`define RS_N             15
`define RS_K             11
`define RS_R             (`RS_N - `RS_K)
`define RS_T             (`RS_R / 2)

// Generator and syndrome convention:
// g(x) = product_{j=0..R-1} (x + alpha^(FIRST_ROOT + j*ROOT_STEP)).
// S[j] = received(alpha^(FIRST_ROOT + j*ROOT_STEP)), j = 0..R-1.
// Addition and subtraction are both XOR in GF(256).
`define RS_FIRST_ROOT    0
`define RS_ROOT_STEP     1

// Shortening: start with RS(255,251), prepend SHORTEN zero data bytes,
// encode, then omit those leading zeros from the transmitted codeword.
`define RS_PARENT_N      `GF_ORDER
`define RS_PARENT_K      (`RS_PARENT_N - `RS_R)
`define RS_SHORTEN       (`RS_PARENT_N - `RS_N)

// Symbol/polynomial order (mandatory for all modules and the Python model):
//   c[0] is transmitted first and is the coefficient of x^(N-1).
//   c[N-1] is transmitted last and is the constant coefficient.
//   c[0..K-1] contains data; c[K..N-1] contains parity.
// For an error at transmitted index i, X_i = alpha^(N-1-i).
// With Lambda(z) = product_i (1 + X_i*z), Chien search tests X_i^(-1).
// The omitted leading zero symbols are not transmitted or entered on SW.
// Any change to this profile must also be applied to the Python reference,
// generated test vectors and all modules with precomputed coefficients.

`endif // RS_PARAMS_VH
