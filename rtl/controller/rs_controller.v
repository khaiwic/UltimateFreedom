// rs_controller.v
// Bo dieu phoi chinh (Master Controller) cho he thong Reed-Solomon tren DE10-Lite.
//
// Dac ta theo:
//   - README_RS_DE10_Lite.md (muc 1, 2, 3, 4, 6)
//   - docs/architecture.md, docs/interfaces.md
//
// Chuc nang:
//   1. Pha nhap (SW[8] = 0):
//      - Nhan K=11 symbol tu SW[7:0] qua nut nhan KEY[1] (confirm_pulse).
//      - Ghi tung symbol vao bo dem u_buf_input tai dia chi in_cnt (0..10).
//      - Xuat byte dang chon tren SW[7:0] ra byte_to_display de hien thi tren HEX1:HEX0.
//      - Giu LEDR[2:0] = 3'b000 (clear_status = 1).
//   2. Pha chay & xem ket qua (SW[8] = 1):
//      - Khi nhan confirm_pulse tu KEY[1]:
//          + Xoa co status cu tren display_control (clear_status_pulse).
//          + Phat xung start dong thoi cho: u_buf_input, rs_encoder, error_injector, rs_decoder.
//          + Assert busy = 1 (LEDR[0] sang).
//          + Toan bo chuoi pipeline tu dong stream:
//              buf_input (11B) -> rs_encoder -> error_injector (15B) -> rs_decoder (15B) -> buf_output (15B).
//          + Khi rs_decoder.done phat xung:
//              * Phat xung done = 1 de display_control chot sang LEDR[1].
//              * Chot co fail tu decoder sang LEDR[2].
//              * Ha busy = 0 de tat LEDR[0].
//      - Sau khi chay xong:
//          + Nguoi dung co the su dung cac switch SW[3:0] de xem 15 byte ket qua trong buf_output tren HEX1:HEX0.

`include "rs_params.vh"

module rs_controller #(
    parameter integer K = `RS_K,      // 11
    parameter integer N = `RS_N       // 15
) (
    input  wire        clk,
    input  wire        rst_n,

    // Giao dien tu input_control
    input  wire        confirm_pulse,
    input  wire [9:0]  sw_sync,
    input  wire [9:0]  sw_latched,

    // Dieu khien bo dem nhap (data_buffer input)
    output reg         buf_in_wr_en,
    output reg  [3:0]  buf_in_wr_addr,
    output reg  [7:0]  buf_in_wr_data,
    output reg         buf_in_clear,
    output reg         buf_in_stream_start,
    input  wire        buf_in_stream_done,

    // Dieu khien bo ma hoa (rs_encoder)
    output reg         encoder_start,
    input  wire        encoder_busy,
    input  wire        encoder_done,

    // Dieu khien bo tao loi (error_injector)
    output reg         injector_start,
    output wire        injector_enable,
    input  wire        injector_busy,
    input  wire        injector_done,

    // Dieu khien bo giai ma (rs_decoder)
    output reg         decoder_start,
    input  wire        decoder_busy,
    input  wire        decoder_done,
    input  wire        decoder_fail,

    // Dieu khien bo dem xuat (data_buffer output)
    output reg         buf_out_clear,

    // Dieu khien kiem tra ket qua & dem chu ky
    output reg         checker_start,
    output reg         counter_start,
    output reg         counter_stop,
    output reg         counter_clear,

    // Giao dien sang display_control
    output wire        clear_status,
    output reg         busy = 1'b0,
    output reg         done = 1'b0,
    output reg         fail = 1'b0,
    output reg  [7:0]  byte_to_display,

    // Du lieu doc tu cac bo dem phuc vu hien thi tren HEX
    input  wire [7:0]  buf_in_rd_data,
    input  wire [7:0]  buf_out_rd_data,
    output wire [3:0]  buf_in_rd_addr,
    output wire [3:0]  buf_out_rd_addr
);

    localparam integer CNT_W = $clog2(K + 1);

    localparam [1:0]
        S_IDLE  = 2'd0,   // Cho thao tac nguoi dung
        S_START = 2'd1,   // Phat xung start cho cac khoi (1 chu ky)
        S_RUN   = 2'd2,   // Dang chay pipeline (busy = 1)
        S_DONE  = 2'd3;   // Xong, phat xung done 1 chu ky roi quay ve S_IDLE

    reg [1:0]       state = S_IDLE;
    reg [CNT_W-1:0] in_cnt = {CNT_W{1'b0}};
    reg             has_run = 1'b0;
    reg             clear_status_pulse = 1'b0;
    reg             sw8_prev = 1'b0;

    assign injector_enable = sw_sync[9];

    // Clear status giu LEDR = 000 trong pha nhap, hoac phat xung khi bat dau luot chay moi
    assign clear_status = (sw_sync[8] == 1'b0) || clear_status_pulse;

    assign buf_in_rd_addr  = (sw_sync[3:0] < K) ? sw_sync[3:0] : 4'd0;
    assign buf_out_rd_addr = (sw_sync[3:0] < N) ? sw_sync[3:0] : 4'd0;

    // Hien thi tren HEX1:HEX0
    always @(*) begin
        if (sw_sync[8] == 1'b0) begin
            // Pha nhap: hien thi truc tiep byte nguoi dung dang chon tren SW[7:0]
            byte_to_display = sw_sync[7:0];
        end else begin
            // Pha chay & xem ket qua
            if (has_run)
                byte_to_display = buf_out_rd_data;
            else
                byte_to_display = buf_in_rd_data;
        end
    end

    // FSM dieu phoi giao dich
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state               <= S_IDLE;
            in_cnt              <= {CNT_W{1'b0}};
            has_run             <= 1'b0;
            sw8_prev            <= 1'b0;
            buf_in_wr_en        <= 1'b0;
            buf_in_wr_addr      <= 4'd0;
            buf_in_wr_data      <= 8'h00;
            buf_in_clear        <= 1'b0;
            buf_in_stream_start <= 1'b0;
            encoder_start       <= 1'b0;
            injector_start      <= 1'b0;
            decoder_start       <= 1'b0;
            buf_out_clear       <= 1'b0;
            checker_start       <= 1'b0;
            counter_start       <= 1'b0;
            counter_stop        <= 1'b0;
            counter_clear       <= 1'b0;
            clear_status_pulse  <= 1'b0;
            busy                <= 1'b0;
            done                <= 1'b0;
            fail                <= 1'b0;
        end else begin
            sw8_prev <= sw_sync[8];

            // Mac dinh cac xung dieu khien chi keo dai 1 chu ky
            buf_in_wr_en        <= 1'b0;
            buf_in_clear        <= 1'b0;
            buf_in_stream_start <= 1'b0;
            encoder_start       <= 1'b0;
            injector_start      <= 1'b0;
            decoder_start       <= 1'b0;
            buf_out_clear       <= 1'b0;
            checker_start       <= 1'b0;
            counter_start       <= 1'b0;
            counter_stop        <= 1'b0;
            counter_clear       <= 1'b0;
            clear_status_pulse  <= 1'b0;
            done                <= 1'b0;

            // Phat hien chuyen tu pha chay sang pha nhap: reset con tro nhap
            if (sw8_prev && !sw_sync[8]) begin
                in_cnt  <= {CNT_W{1'b0}};
                has_run <= 1'b0;
            end

            case (state)
                S_IDLE: begin
                    busy <= 1'b0;

                    if (sw_sync[8] == 1'b0) begin
                        // Pha nhap: nhan confirm_pulse de ghi 1 byte vao input buffer
                        if (confirm_pulse) begin
                            buf_in_wr_en   <= 1'b1;
                            buf_in_wr_addr <= in_cnt[3:0];
                            buf_in_wr_data <= sw_latched[7:0];

                            if (in_cnt < K - 1)
                                in_cnt <= in_cnt + 1'b1;
                            else
                                in_cnt <= {CNT_W{1'b0}};
                        end
                    end else begin
                        // Pha chay: nhan confirm_pulse de bat dau xu ly
                        if (confirm_pulse) begin
                            busy               <= 1'b1;
                            clear_status_pulse <= 1'b1;
                            state              <= S_START;
                        end
                    end
                end

                S_START: begin
                    busy                <= 1'b1;
                    buf_out_clear       <= 1'b1;
                    counter_clear       <= 1'b1;
                    counter_start       <= 1'b1;
                    encoder_start       <= 1'b1;
                    injector_start      <= 1'b1;
                    decoder_start       <= 1'b1;
                    buf_in_stream_start <= 1'b1;
                    state               <= S_RUN;
                end

                S_RUN: begin
                    busy <= 1'b1;

                    if (decoder_done) begin
                        busy          <= 1'b0;
                        done          <= 1'b1;
                        fail          <= decoder_fail;
                        counter_stop  <= 1'b1;
                        checker_start <= 1'b1;
                        has_run       <= 1'b1;
                        state         <= S_DONE;
                    end
                end

                S_DONE: begin
                    busy  <= 1'b0;
                    state <= S_IDLE;
                end

                default: begin
                    state <= S_IDLE;
                end
            endcase
        end
    end

endmodule
