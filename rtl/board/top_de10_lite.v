// top_de10_lite.v
// Module Top-Level ket noi toan bo he thong ma hoa va giai ma Reed-Solomon tren DE10-Lite.
//
// Dac ta theo:
//   - README_RS_DE10_Lite.md (muc 4, 5, 6)
//   - docs/pin_assignment.md
//
// Kit su dung: Terasic DE10-Lite (FPGA MAX 10 10M50DAF484C7G).
//
// Phan cong ngoai vi:
//   - MAX10_CLK1_50: Nguon clock 50 MHz (PIN_P11)
//   - KEY[0]: Reset he thong (PIN_B8, tich cuc thap: nhan=0, tha=1)
//   - KEY[1]: Xac nhan nhap / Bat dau chay (PIN_A7, tich cuc thap)
//   - SW[7:0]: Byte du lieu 8-bit nhap vao (PIN_C10..PIN_A14)
//   - SW[8]: Chon pha (0 = Nhap du lieu, 1 = Chay / Xem ket qua)
//   - SW[9]: Cho phep tao loi (0 = Khong loi, 1 = Tao 2 loi de thu nghiem)
//   - LEDR[0]: Busy (he thong dang xu ly)
//   - LEDR[1]: Done (hoan tat, da chot sang de quan sat)
//   - LEDR[2]: Fail (giai ma that bai hoac loi vuot kha nang)
//   - HEX1:HEX0: Hai LED 7 doan hien thi byte du lieu dang xem (MSB nibble tren HEX1, LSB nibble tren HEX0)

`include "rs_params.vh"

module top_de10_lite #(
    parameter integer DEBOUNCE_CYCLES = 500_000   // 10 ms voi clock 50 MHz
) (
    input  wire       MAX10_CLK1_50,
    input  wire [1:0] KEY,
    input  wire [9:0] SW,
    output wire [2:0] LEDR,
    output wire [7:0] HEX0,
    output wire [7:0] HEX1
);

    localparam integer K = `RS_K;   // 11
    localparam integer N = `RS_N;   // 15

    wire clk = MAX10_CLK1_50;
    wire rst_n;

    // ------------------------------------------------------------------------
    // 1. Dong bo reset bat dong bo tu KEY[0]
    // ------------------------------------------------------------------------
    reset_sync #(
        .STAGES (2)
    ) u_reset_sync (
        .clk       (clk),
        .key_rst_n (KEY[0]),
        .rst_n     (rst_n)
    );

    // ------------------------------------------------------------------------
    // 2. Loc doi phim va dong bo tin hieu Switch tu KEY[1] va SW[9:0]
    // ------------------------------------------------------------------------
    wire [9:0] sw_sync;
    wire [9:0] sw_latched;
    wire       confirm_pulse;

    input_control #(
        .DEBOUNCE_CYCLES (DEBOUNCE_CYCLES)
    ) u_input_ctrl (
        .clk           (clk),
        .rst_n         (rst_n),
        .key_confirm_n (KEY[1]),
        .sw_raw        (SW),
        .sw_sync       (sw_sync),
        .sw_latched    (sw_latched),
        .confirm_pulse (confirm_pulse)
    );

    // ------------------------------------------------------------------------
    // 3. Cac duong tin hieu lien ket noi bo
    // ------------------------------------------------------------------------
    // Bo dem nhap
    wire       buf_in_wr_en;
    wire [3:0] buf_in_wr_addr;
    wire [7:0] buf_in_wr_data;
    wire       buf_in_clear;
    wire       buf_in_stream_start;
    wire       buf_in_stream_done;
    wire [7:0] buf_in_data_out;
    wire       buf_in_out_valid;
    wire       buf_in_out_ready;
    wire [3:0] buf_in_rd_addr;
    wire [7:0] buf_in_rd_data;

    // Bo ma hoa (Encoder)
    wire       encoder_start;
    wire [7:0] enc_data_out;
    wire       enc_out_valid;
    wire       enc_out_ready;
    wire       enc_out_last;
    wire       encoder_busy;
    wire       encoder_done;

    // Bo tao loi (Error Injector)
    wire       injector_start;
    wire       injector_enable;
    wire [7:0] inj_data_out;
    wire       inj_out_valid;
    wire       inj_out_ready;
    wire       inj_out_last;
    wire       injector_busy;
    wire       injector_done;

    // Bo giai ma (Decoder)
    wire       decoder_start;
    wire [7:0] dec_data_out;
    wire       dec_out_valid;
    wire       dec_out_ready;
    wire       dec_out_last;
    wire       decoder_busy;
    wire       decoder_done;
    wire       decoder_fail;

    // Bo dem xuat
    wire       buf_out_clear;
    wire [3:0] buf_out_rd_addr;
    wire [7:0] buf_out_rd_data;

    // Result Checker & Cycle Counter
    wire       checker_start;
    wire       counter_start;
    wire       counter_stop;
    wire       counter_clear;
    wire [3:0] chk_orig_addr;
    wire [7:0] chk_orig_data;
    wire [3:0] chk_dec_addr;
    wire [7:0] chk_dec_data;
    wire       checker_match;
    wire [3:0] checker_mismatch_count;
    wire [31:0] cycles_count;

    // Controller & Display
    wire       controller_busy;
    wire       controller_done;
    wire       controller_fail;
    wire       clear_status;
    wire [7:0] byte_to_display;

    // ------------------------------------------------------------------------
    // 4. Bo dem du lieu nhap (Input Buffer - Luu K=11 symbol)
    // ------------------------------------------------------------------------
    data_buffer #(
        .DEPTH  (K),
        .ADDR_W (4)
    ) u_buf_input (
        .clk          (clk),
        .rst_n        (rst_n),
        .clear        (buf_in_clear),
        .data_in      (8'h00),
        .in_valid     (1'b0),
        .in_ready     (),
        .wr_en        (buf_in_wr_en),
        .wr_addr      (buf_in_wr_addr),
        .wr_data      (buf_in_wr_data),
        .stream_start (buf_in_stream_start),
        .data_out     (buf_in_data_out),
        .out_valid    (buf_in_out_valid),
        .out_ready    (buf_in_out_ready),
        .out_last     (),
        .stream_busy  (),
        .stream_done  (buf_in_stream_done),
        .rd_addr      (buf_in_rd_addr),
        .rd_data      (buf_in_rd_data),
        .chk_addr     (chk_orig_addr),
        .chk_data     (chk_orig_data),
        .count        (),
        .full         (),
        .empty        ()
    );

    // ------------------------------------------------------------------------
    // 5. Bo ma hoa Reed-Solomon (RS Encoder)
    // ------------------------------------------------------------------------
    wire enc_in_ready;
    assign buf_in_out_ready = enc_in_ready;

    rs_encoder u_encoder (
        .clk       (clk),
        .rst_n     (rst_n),
        .start     (encoder_start),
        .data_in   (buf_in_data_out),
        .in_valid  (buf_in_out_valid),
        .in_ready  (enc_in_ready),
        .data_out  (enc_data_out),
        .out_valid (enc_out_valid),
        .out_ready (enc_out_ready),
        .out_last  (enc_out_last),
        .busy      (encoder_busy),
        .done      (encoder_done)
    );

    // ------------------------------------------------------------------------
    // 6. Khoi tao loi (Error Injector)
    // ------------------------------------------------------------------------
    wire inj_in_ready;
    assign enc_out_ready = inj_in_ready;

    error_injector #(
        .N        (N),
        .DEF_POS1 (4'd0),
        .DEF_MSK1 (8'h55),
        .DEF_POS2 (4'd14),
        .DEF_MSK2 (8'hA6)
    ) u_injector (
        .clk                (clk),
        .rst_n              (rst_n),
        .start              (injector_start),
        .enable             (sw_sync[9]),
        .two_errors         (1'b1),
        .err_pos1           (4'd0),
        .err_mask1          (8'h55),
        .err_pos2           (4'd14),
        .err_mask2          (8'hA6),
        .use_custom_pattern (1'b0),
        .data_in            (enc_data_out),
        .in_valid           (enc_out_valid),
        .in_ready           (inj_in_ready),
        .data_out           (inj_data_out),
        .out_valid          (inj_out_valid),
        .out_ready          (inj_out_ready),
        .out_last           (inj_out_last),
        .busy               (injector_busy),
        .done               (injector_done)
    );

    // ------------------------------------------------------------------------
    // 7. Bo giai ma Reed-Solomon (RS Decoder)
    // ------------------------------------------------------------------------
    wire dec_in_ready;
    assign inj_out_ready = dec_in_ready;

    rs_decoder u_decoder (
        .clk       (clk),
        .rst_n     (rst_n),
        .start     (decoder_start),
        .data_in   (inj_data_out),
        .in_valid  (inj_out_valid),
        .in_ready  (dec_in_ready),
        .data_out  (dec_data_out),
        .out_valid (dec_out_valid),
        .out_ready (dec_out_ready),
        .out_last  (dec_out_last),
        .busy      (decoder_busy),
        .done      (decoder_done),
        .fail      (decoder_fail)
    );

    // ------------------------------------------------------------------------
    // 8. Bo dem du lieu xuat (Output Buffer - Luu N=15 symbol da sua)
    // ------------------------------------------------------------------------
    wire buf_out_in_ready;
    assign dec_out_ready = buf_out_in_ready;

    data_buffer #(
        .DEPTH  (N),
        .ADDR_W (4)
    ) u_buf_output (
        .clk          (clk),
        .rst_n        (rst_n),
        .clear        (buf_out_clear),
        .data_in      (dec_data_out),
        .in_valid     (dec_out_valid),
        .in_ready     (buf_out_in_ready),
        .wr_en        (1'b0),
        .wr_addr      (4'd0),
        .wr_data      (8'h00),
        .stream_start (1'b0),
        .data_out     (),
        .out_valid    (),
        .out_ready    (1'b0),
        .out_last     (),
        .stream_busy  (),
        .stream_done  (),
        .rd_addr      (buf_out_rd_addr),
        .rd_data      (buf_out_rd_data),
        .chk_addr     (chk_dec_addr),
        .chk_data     (chk_dec_data),
        .count        (),
        .full         (),
        .empty        ()
    );

    // ------------------------------------------------------------------------
    // 9. Khoi doi chieu ket qua (Result Checker)
    // ------------------------------------------------------------------------
    result_checker #(
        .DEPTH   (N),
        .ADDR_W  (4),
        .DEF_LEN (K)
    ) u_checker (
        .clk            (clk),
        .rst_n          (rst_n),
        .start          (checker_start),
        .check_length   (4'd11),
        .use_custom_len (1'b0),
        .orig_addr      (chk_orig_addr),
        .orig_data      (chk_orig_data),
        .dec_addr       (chk_dec_addr),
        .dec_data       (chk_dec_data),
        .stream_mode    (1'b0),
        .stream_data    (8'h00),
        .stream_valid   (1'b0),
        .match          (checker_match),
        .mismatch_count (checker_mismatch_count),
        .first_err_addr (),
        .busy           (),
        .done           ()
    );

    // ------------------------------------------------------------------------
    // 10. Bo dem chu ky xu ly (Cycle Counter)
    // ------------------------------------------------------------------------
    cycle_counter #(
        .WIDTH (32)
    ) u_counter (
        .clk            (clk),
        .rst_n          (rst_n),
        .start          (counter_start),
        .stop           (counter_stop),
        .clear          (counter_clear),
        .count_en       (1'b0),
        .use_level_mode (1'b0),
        .cycles         (cycles_count),
        .running        (),
        .valid          (),
        .overflow       ()
    );

    // ------------------------------------------------------------------------
    // 11. Bo dieu phoi chinh (RS Controller)
    // ------------------------------------------------------------------------
    rs_controller #(
        .K (K),
        .N (N)
    ) u_controller (
        .clk                 (clk),
        .rst_n               (rst_n),
        .confirm_pulse       (confirm_pulse),
        .sw_sync             (sw_sync),
        .sw_latched          (sw_latched),
        .buf_in_wr_en        (buf_in_wr_en),
        .buf_in_wr_addr      (buf_in_wr_addr),
        .buf_in_wr_data      (buf_in_wr_data),
        .buf_in_clear        (buf_in_clear),
        .buf_in_stream_start (buf_in_stream_start),
        .buf_in_stream_done  (buf_in_stream_done),
        .encoder_start       (encoder_start),
        .encoder_busy        (encoder_busy),
        .encoder_done        (encoder_done),
        .injector_start      (injector_start),
        .injector_enable     (injector_enable),
        .injector_busy       (injector_busy),
        .injector_done       (injector_done),
        .decoder_start       (decoder_start),
        .decoder_busy        (decoder_busy),
        .decoder_done        (decoder_done),
        .decoder_fail        (decoder_fail),
        .buf_out_clear       (buf_out_clear),
        .checker_start       (checker_start),
        .counter_start       (counter_start),
        .counter_stop        (counter_stop),
        .counter_clear       (counter_clear),
        .clear_status        (clear_status),
        .busy                (controller_busy),
        .done                (controller_done),
        .fail                (controller_fail),
        .byte_to_display     (byte_to_display),
        .buf_in_rd_data      (buf_in_rd_data),
        .buf_out_rd_data     (buf_out_rd_data),
        .buf_in_rd_addr      (buf_in_rd_addr),
        .buf_out_rd_addr     (buf_out_rd_addr)
    );

    // ------------------------------------------------------------------------
    // 12. Dieu khien hien thi LED trang thai va 2 LED 7 doan HEX1:HEX0
    // ------------------------------------------------------------------------
    display_control u_display_ctrl (
        .clk          (clk),
        .rst_n        (rst_n),
        .core_busy    (controller_busy),
        .core_done    (controller_done),
        .core_fail    (controller_fail),
        .clear_status (clear_status),
        .byte_in      (byte_to_display),
        .LEDR         (LEDR),
        .HEX0         (HEX0),
        .HEX1         (HEX1)
    );

endmodule

