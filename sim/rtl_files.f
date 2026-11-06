# =============================================================================
# rtl_files.f - Danh sach cac file ma nguon RTL du an Reed-Solomon tren DE10-Lite
#
# Cac duong dan duoc quy uoc tuong doi so voi thu muc hien hanh (sim/)
# Su dung trong ModelSim / QuestaSim: vlog -f rtl_files.f
# Hoac trong Icarus Verilog: iverilog -c rtl_files.f
# =============================================================================

# Thu muc tim kiem file header `include (rs_params.vh)
+incdir+../rtl/include

# -----------------------------------------------------------------------------
# 1. Cac phep toan so hoc trong truong Galois GF(256)
# -----------------------------------------------------------------------------
../rtl/gf_arithmetic/gf256_add.v
../rtl/gf_arithmetic/gf256_mul.v
../rtl/gf_arithmetic/gf256_inv.v

# -----------------------------------------------------------------------------
# 2. Bo ma hoa Reed-Solomon (RS Encoder)
# -----------------------------------------------------------------------------
../rtl/rs_encoder/rs_encoder.v

# -----------------------------------------------------------------------------
# 3. Bo giai ma Reed-Solomon va cac khoi con (RS Decoder Submodules)
# -----------------------------------------------------------------------------
../rtl/rs_decoder/syndrome.v
../rtl/rs_decoder/berlekamp_massey.v
../rtl/rs_decoder/error_evaluator.v
../rtl/rs_decoder/chien_search.v
../rtl/rs_decoder/forney.v
../rtl/rs_decoder/error_corrector.v
../rtl/rs_decoder/rs_decoder.v

# -----------------------------------------------------------------------------
# 4. Bo dem du lieu (Data Buffer)
# -----------------------------------------------------------------------------
../rtl/memory/data_buffer.v

# -----------------------------------------------------------------------------
# 5. Khoi ho tro kiem chung va demo (Demo / Verification Blocks)
# -----------------------------------------------------------------------------
../rtl/demo/cycle_counter.v
../rtl/demo/error_injector.v
../rtl/demo/result_checker.v

# -----------------------------------------------------------------------------
# 6. Giao tiep ngoai vi va dieu khien tren kit DE10-Lite (Board Peripherals)
# -----------------------------------------------------------------------------
../rtl/board/reset_sync.v
../rtl/board/hex_decoder.v
../rtl/board/input_control.v
../rtl/board/display_control.v
../rtl/controller/rs_controller.v
../rtl/board/top_de10_lite.v

