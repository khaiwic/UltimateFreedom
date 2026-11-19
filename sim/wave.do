onerror {resume}
quietly WaveActivateNextPane {} 0

add wave -noupdate -divider {=== CLOCK & CONTROL ===}
add wave -noupdate -color {Cyan}        -label {clk}      /clk
add wave -noupdate -color {Yellow}      -label {rst_n}    /rst_n
add wave -noupdate -color {Orange}      -label {start}    /start
add wave -noupdate -color {Yellow}      -label {busy}     /busy
add wave -noupdate -color {Lime Green}  -label {done}     /done
add wave -noupdate -color {Red}         -label {fail}     /fail

add wave -noupdate -divider {=== DATA BUS (RS 5,3 - GF 8) ===}
add wave -noupdate -color {Magenta}     -label {rx_in}    -radix octal /rx_in
add wave -noupdate -color {Cyan}        -label {corr_out} -radix octal /corr_out

add wave -noupdate -divider {=== DECODER FSM ===}
add wave -noupdate -color {Yellow}      -label {state}       -radix unsigned /dut/state
add wave -noupdate -color {Orange}      -label {syn_done}    /dut/syn_done
add wave -noupdate -color {Orange}      -label {syn_zero}    /dut/syn_zero_out
add wave -noupdate -color {Orange}      -label {syn_latched} -radix octal /dut/syn_latched
add wave -noupdate -color {Cyan}        -label {bm_done}     /dut/bm_done
add wave -noupdate -color {Cyan}        -label {lambda}      -radix octal /dut/bm_lambda_out
add wave -noupdate -color {Lime Green}  -label {omega}       -radix octal /dut/ee_omega_out
add wave -noupdate -color {Magenta}     -label {err_mask}    -radix bin /dut/chien_mask_out
add wave -noupdate -color {Light Blue}  -label {forney_val}  -radix octal /dut/forney_val_out

TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {0 ps} 0}
quietly wave cursor active 1
configure wave -namecolwidth 180
configure wave -valuecolwidth 120
configure wave -justifyvalue left
configure wave -signalnamewidth 1
update
