// Module Top-Level he thong Reed-Solomon RS(5,3) tren GF(8) + UART Monitor cho DE10-Lite
`include "rs_params.vh"

module top_de10_lite #(
    parameter integer DEBOUNCE_MAX      = 499_999,
    parameter integer BLINK_BIT         = 24,
    parameter integer UART_CLKS_PER_BIT = 434
) (
    input  wire       MAX10_CLK1_50,
    input  wire [1:0] KEY,
    input  wire [9:0] SW,
    output wire [9:0] LEDR,
    output wire [7:0] HEX0,
    output wire [7:0] HEX1,
    output wire [7:0] HEX2,
    output wire       UART_TX
);
    wire clk   = MAX10_CLK1_50;
    wire rst_n = KEY[0];

    // 1. Bo chia xung tao nhip nhap nhay cho LEDR khi giai ma loi that bai
    reg [BLINK_BIT:0] blink_cnt;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            blink_cnt <= {(BLINK_BIT + 1){1'b0}};
        else
            blink_cnt <= blink_cnt + 1'b1;
    end
    wire blink_state = blink_cnt[BLINK_BIT];

    // 2. Chong doi nut nhan KEY[1] va dong bo Switch SW[9:0]
    wire [9:0] sw_sync, sw_latched;
    wire       confirm_pulse;

    input_control #(
        .DEBOUNCE_MAX (DEBOUNCE_MAX)
    ) u_input_ctrl (
        .clk           (clk),
        .rst_n         (rst_n),
        .key_confirm_n (KEY[1]),
        .sw_raw        (SW),
        .sw_sync       (sw_sync),
        .sw_latched    (sw_latched),
        .confirm_pulse (confirm_pulse)
    );

    // 3. Cac tin hieu noi bo giua controller, encoder, injector, decoder va UART
    wire        encoder_start, encoder_done;
    wire  [8:0] enc_data_in;
    wire [14:0] enc_code_out, noisy_code, dec_corr_out, ctrl_dec_out;
    wire        decoder_start, decoder_done, decoder_fail;
    wire        err_enable, ctrl_fail, log_start;
    wire  [8:0] err_syms;
    wire  [2:0] sym0_disp, sym1_disp, sym2_disp;

    wire  [5:0] dbg_syn, dbg_omega;
    wire        dbg_syn_zero;
    wire  [8:0] dbg_lambda;
    wire  [2:0] dbg_lambda_deg;
    wire  [4:0] dbg_err_mask;
    wire [14:0] dbg_err_val;

    // 4. Bo dieu khien trung tam
    rs_controller u_controller (
        .clk           (clk),
        .rst_n         (rst_n),
        .confirm_pulse (confirm_pulse),
        .sw_sync       (sw_sync),
        .sw_latched    (sw_latched),
        .blink_state   (blink_state),
        .encoder_start (encoder_start),
        .enc_data_in   (enc_data_in),
        .encoder_done  (encoder_done),
        .enc_code_out  (enc_code_out),
        .decoder_start (decoder_start),
        .decoder_done  (decoder_done),
        .decoder_fail  (decoder_fail),
        .dec_corr_out  (dec_corr_out),
        .err_enable    (err_enable),
        .err_syms      (err_syms),
        .busy          (),
        .fail          (ctrl_fail),
        .log_start     (log_start),
        .dec_out       (ctrl_dec_out),
        .sym0_disp     (sym0_disp),
        .sym1_disp     (sym1_disp),
        .sym2_disp     (sym2_disp),
        .led_out       (LEDR)
    );

    // 5. Bo ma hoa RS(5,3)
    rs_encoder u_encoder (
        .clk      (clk),
        .rst_n    (rst_n),
        .start    (encoder_start),
        .data_in  (enc_data_in),
        .busy     (),
        .done     (encoder_done),
        .code_out (enc_code_out)
    );

    // 6. Bo chen loi vao 3 symbol cuoi cua tu ma
    error_injector u_injector (
        .enable   (err_enable),
        .err_syms (err_syms),
        .code_in  (enc_code_out),
        .code_out (noisy_code)
    );

    // 7. Bo giai ma RS(5,3) + xuat tin hieu debug
    rs_decoder u_decoder (
        .clk            (clk),
        .rst_n          (rst_n),
        .start          (decoder_start),
        .rx_in          (noisy_code),
        .busy           (),
        .done           (decoder_done),
        .fail           (decoder_fail),
        .corr_out       (dec_corr_out),
        .dbg_syn        (dbg_syn),
        .dbg_syn_zero   (dbg_syn_zero),
        .dbg_lambda     (dbg_lambda),
        .dbg_lambda_deg (dbg_lambda_deg),
        .dbg_omega      (dbg_omega),
        .dbg_err_mask   (dbg_err_mask),
        .dbg_err_val    (dbg_err_val)
    );

    // 8. Hien thi 3 symbol len 3 LED 7 doan HEX2 (sym0), HEX1 (sym1), HEX0 (sym2)
    hex_decoder u_hex2 (
        .hex_digit ({1'b0, sym0_disp}),
        .seg_n     (),
        .hex_out   (HEX2)
    );

    hex_decoder u_hex1 (
        .hex_digit ({1'b0, sym1_disp}),
        .seg_n     (),
        .hex_out   (HEX1)
    );

    hex_decoder u_hex0 (
        .hex_digit ({1'b0, sym2_disp}),
        .seg_n     (),
        .hex_out   (HEX0)
    );

    // 9. Dong goi va gui log qua trinh giai ma len PC qua UART_TX (115200 bps)
    wire       uart_tx_start, uart_tx_busy;
    wire [7:0] uart_tx_data;

    uart_logger u_logger (
        .clk            (clk),
        .rst_n          (rst_n),
        .log_start      (log_start),
        .log_mode       (err_enable),
        .log_fail       (ctrl_fail),
        .data_in        (enc_data_in),
        .enc_code       (enc_code_out),
        .rx_code        (noisy_code),
        .dec_code       (ctrl_dec_out),
        .dbg_syn        (dbg_syn),
        .dbg_syn_zero   (dbg_syn_zero),
        .dbg_lambda     (dbg_lambda),
        .dbg_lambda_deg (dbg_lambda_deg),
        .dbg_omega      (dbg_omega),
        .dbg_err_mask   (dbg_err_mask),
        .dbg_err_val    (dbg_err_val),
        .tx_start       (uart_tx_start),
        .tx_data        (uart_tx_data),
        .tx_busy        (uart_tx_busy),
        .busy           ()
    );

    uart_tx #(
        .CLKS_PER_BIT (UART_CLKS_PER_BIT)
    ) u_uart_tx (
        .clk       (clk),
        .rst_n     (rst_n),
        .tx_start  (uart_tx_start),
        .tx_data   (uart_tx_data),
        .tx_busy   (uart_tx_busy),
        .tx_serial (UART_TX)
    );
endmodule
