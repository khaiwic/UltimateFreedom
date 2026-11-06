onerror {resume}
quietly WaveActivateNextPane {} 0

# -----------------------------------------------------------------------------
# 1. Xung nhip va Reset he thong
# -----------------------------------------------------------------------------
add wave -noupdate -divider {=== CLOCK & RESET ===}
add wave -noupdate -color {Cyan}        -label {clk}           /clk
add wave -noupdate -color {Yellow}      -label {rst_n}         /rst_n
add wave -noupdate -color {Orange}      -label {start}         /start

# -----------------------------------------------------------------------------
# 2. Giao dien truyen stream (Valid / Ready Streaming Handshake)
# -----------------------------------------------------------------------------
add wave -noupdate -divider {=== STREAMING I/O ===}
add wave -noupdate -color {Green}       -label {in_valid}      /in_valid
add wave -noupdate -color {Green}       -label {in_ready}      /in_ready
add wave -noupdate -color {Magenta}     -label {data_in}       -radix hex /data_in
add wave -noupdate -color {Light Blue}  -label {out_valid}     /out_valid
add wave -noupdate -color {Light Blue}  -label {out_ready}     /out_ready
add wave -noupdate -color {Light Blue}  -label {out_last}      /out_last
add wave -noupdate -color {Cyan}        -label {data_out}      -radix hex /data_out

# -----------------------------------------------------------------------------
# 3. Tin hieu trang thai tong the
# -----------------------------------------------------------------------------
add wave -noupdate -divider {=== STATUS SIGNALS ===}
add wave -noupdate -color {Yellow}      -label {busy}          /busy
add wave -noupdate -color {Lime Green}  -label {done}          /done
add wave -noupdate -color {Red}         -label {fail}          /fail

# -----------------------------------------------------------------------------
# 4. FSM va bo dem noi bo bo giai ma (rs_decoder DUT)
# -----------------------------------------------------------------------------
add wave -noupdate -divider {=== DECODER FSM & REGS ===}
add wave -noupdate -color {Yellow}      -label {state}         -radix unsigned /dut/state
add wave -noupdate -color {White}       -label {rx_cnt}        -radix unsigned /dut/rx_cnt
add wave -noupdate -color {White}       -label {out_cnt}       -radix unsigned /dut/out_cnt
add wave -noupdate -color {White}       -label {ver_cnt}       -radix unsigned /dut/ver_cnt
add wave -noupdate -color {Gray}        -label {rx_buf}        -radix hex /dut/rx_buf
add wave -noupdate -color {Gold}        -label {candidate_buf} -radix hex /dut/candidate_buf
add wave -noupdate -color {Lime Green}  -label {corr_buf}      -radix hex /dut/corr_buf

# -----------------------------------------------------------------------------
# 5. Khoi Syndrome (Horner S[0..3])
# -----------------------------------------------------------------------------
add wave -noupdate -divider {=== SYNDROME ===}
add wave -noupdate -color {Orange}      -label {syn_start}     /dut/syn_start
add wave -noupdate -color {Orange}      -label {syn_busy}      /dut/syn_busy
add wave -noupdate -color {Orange}      -label {syn_done}      /dut/syn_done
add wave -noupdate -color {Red}         -label {syn_zero}      /dut/syn_zero_out
add wave -noupdate -color {Orange}      -label {syn_latched}   -radix hex /dut/syn_latched

# -----------------------------------------------------------------------------
# 6. Khoi Berlekamp-Massey (Tim Lambda(x))
# -----------------------------------------------------------------------------
add wave -noupdate -divider {=== BERLEKAMP-MASSEY ===}
add wave -noupdate -color {Cyan}        -label {bm_start}      /dut/bm_start
add wave -noupdate -color {Cyan}        -label {bm_busy}       /dut/bm_busy
add wave -noupdate -color {Cyan}        -label {bm_done}       /dut/bm_done
add wave -noupdate -color {White}       -label {deg_lambda}    -radix unsigned /dut/bm_deg_out
add wave -noupdate -color {Cyan}        -label {lambda}        -radix hex /dut/bm_lambda_out
add wave -noupdate -color {Red}         -label {bm_fail}       /dut/bm_fail_out

# -----------------------------------------------------------------------------
# 7. Khoi Error Evaluator (Tim Omega(x))
# -----------------------------------------------------------------------------
add wave -noupdate -divider {=== ERROR EVALUATOR ===}
add wave -noupdate -color {Lime Green}  -label {ee_start}      /dut/ee_start
add wave -noupdate -color {Lime Green}  -label {ee_busy}       /dut/ee_busy
add wave -noupdate -color {Lime Green}  -label {ee_done}       /dut/ee_done
add wave -noupdate -color {Lime Green}  -label {omega}         -radix hex /dut/ee_omega_out

# -----------------------------------------------------------------------------
# 8. Khoi Chien Search (Quet vi tri loi)
# -----------------------------------------------------------------------------
add wave -noupdate -divider {=== CHIEN SEARCH ===}
add wave -noupdate -color {Magenta}     -label {chien_start}   /dut/chien_start
add wave -noupdate -color {Magenta}     -label {chien_busy}    /dut/chien_busy
add wave -noupdate -color {Magenta}     -label {chien_done}    /dut/chien_done
add wave -noupdate -color {White}       -label {chien_err_cnt} -radix unsigned /dut/chien_count_out
add wave -noupdate -color {Magenta}     -label {chien_mask}    -radix bin /dut/chien_mask_out
add wave -noupdate -color {Red}         -label {chien_fail}    /dut/chien_fail_out

# -----------------------------------------------------------------------------
# 9. Khoi Forney (Tinh gia tri loi tai moi vi tri)
# -----------------------------------------------------------------------------
add wave -noupdate -divider {=== FORNEY ===}
add wave -noupdate -color {Light Blue}  -label {forney_start}  /dut/forney_start
add wave -noupdate -color {Light Blue}  -label {forney_busy}   /dut/forney_busy
add wave -noupdate -color {Light Blue}  -label {forney_done}   /dut/forney_done
add wave -noupdate -color {Light Blue}  -label {forney_val}    -radix hex /dut/forney_val_out
add wave -noupdate -color {Red}         -label {forney_fail}   /dut/forney_fail_out

# -----------------------------------------------------------------------------
# 10. Khoi Error Corrector (Sua tu ma)
# -----------------------------------------------------------------------------
add wave -noupdate -divider {=== ERROR CORRECTOR ===}
add wave -noupdate -color {Pink}        -label {ec_start}      /dut/ec_start
add wave -noupdate -color {Pink}        -label {ec_busy}       /dut/ec_busy
add wave -noupdate -color {Pink}        -label {ec_done}       /dut/ec_done
add wave -noupdate -color {Pink}        -label {ec_corr_out}   -radix hex /dut/ec_corr_out

# -----------------------------------------------------------------------------
# 11. Tin hieu Kit DE10-Lite (Neu chay tb_top)
# -----------------------------------------------------------------------------
add wave -noupdate -divider {=== BOARD DE10-LITE (tb_top) ===}
add wave -noupdate -color {Cyan}        -label {MAX10_CLK1_50} /MAX10_CLK1_50
add wave -noupdate -color {Yellow}      -label {KEY}           -radix bin /KEY
add wave -noupdate -color {Light Blue}  -label {SW}            -radix bin /SW
add wave -noupdate -color {Red}         -label {LEDR}          -radix bin /LEDR
add wave -noupdate -color {Orange}      -label {HEX1}          -radix hex /HEX1
add wave -noupdate -color {Orange}      -label {HEX0}          -radix hex /HEX0

# -----------------------------------------------------------------------------
# Thiet lap giao dien cua so Waveform
# -----------------------------------------------------------------------------
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {0 ps} 0}
quietly wave cursor active 1
configure wave -namecolwidth 220
configure wave -valuecolwidth 100
configure wave -justifyvalue left
configure wave -signalnamewidth 1
configure wave -snapdistance 10
configure wave -datasetprefix 0
configure wave -rowmargin 4
configure wave -childrowmargin 2
configure wave -gridoffset 0
configure wave -gridperiod 1
configure wave -griddelta 40
configure wave -timeline 0
configure wave -timelineunits ns
update

