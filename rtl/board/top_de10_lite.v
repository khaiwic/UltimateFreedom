// Module Top-Level he thong Reed-Solomon RS(5,3) tren GF(8) cho kit DE10-Lite
`include "rs_params.vh"

module top_de10_lite #(
    parameter integer DEBOUNCE_MAX = 499_999,
    parameter integer BLINK_BIT    = 24
) (
    input  wire       MAX10_CLK1_50,
    input  wire [1:0] KEY,
    input  wire [9:0] SW,
    output wire [9:0] LEDR,
    output wire [7:0] HEX0,
    output wire [7:0] HEX1,
    output wire [7:0] HEX2
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

    // 3. Cac tin hieu noi bo giua controller, encoder, injector va decoder
    wire        encoder_start, encoder_done;
    wire  [8:0] enc_data_in;
    wire [14:0] enc_code_out, noisy_code, dec_corr_out;
    wire        decoder_start, decoder_done, decoder_fail;
    wire        err_enable;
    wire  [8:0] err_syms;
    wire  [2:0] sym0_disp, sym1_disp, sym2_disp;

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
        .fail          (),
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

    // 7. Bo giai ma RS(5,3)
    rs_decoder u_decoder (
        .clk      (clk),
        .rst_n    (rst_n),
        .start    (decoder_start),
        .rx_in    (noisy_code),
        .busy     (),
        .done     (decoder_done),
        .fail     (decoder_fail),
        .corr_out (dec_corr_out)
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
endmodule
