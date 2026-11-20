# Danh sach file RTL cho RS(5,3) tren GF(8) + UART Monitor
+incdir+../rtl/include

# 1. Phep toan GF(8)
../rtl/gf_arithmetic/gf8_mul.v
../rtl/gf_arithmetic/gf8_inv.v

# 2. Bo ma hoa & tao loi
../rtl/rs_encoder/rs_encoder.v
../rtl/demo/error_injector.v

# 3. Bo giai ma va cac khoi con
../rtl/rs_decoder/syndrome.v
../rtl/rs_decoder/berlekamp_massey.v
../rtl/rs_decoder/error_evaluator.v
../rtl/rs_decoder/chien_search.v
../rtl/rs_decoder/forney.v
../rtl/rs_decoder/rs_decoder.v

# 4. Giao tiep UART 115200 bps
../rtl/uart/uart_tx.v
../rtl/uart/uart_logger.v

# 5. Ngoai vi va dieu khien DE10-Lite
../rtl/board/hex_decoder.v
../rtl/board/input_control.v
../rtl/controller/rs_controller.v
../rtl/board/top_de10_lite.v
