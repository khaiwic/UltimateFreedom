# Timing constraints - Reed-Solomon tren DE10-Lite

# Clock he thong 50 MHz (chu ky 20 ns) tu bo dao dong tren board
create_clock -name sys_clk -period 20.000 [get_ports {MAX10_CLK1_50}]

# Tu tinh do bat dinh clock (jitter, skew) cho cac clock da khai bao
derive_clock_uncertainty
