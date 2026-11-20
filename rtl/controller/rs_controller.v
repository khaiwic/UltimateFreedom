// Bo dieu khien trung tam cho he thong Reed-Solomon RS(5,3) tren GF(8)
// - Che do nhap thong tin (SW[9]=0): nhap 3 symbol qua SW[2:0] + KEY[1], ma hoa va giai ma dung
// - Che do nhap loi (SW[9]=1): nhap toi da 3 loi vao 3 symbol cuoi cua tu ma
// - LEDR[9:0]: sang 1 LED theo SW[2:0] khi nhap; giai ma loi dung -> tat het, sai -> nhap nhay
`include "rs_params.vh"

module rs_controller (
    input  wire        clk,
    input  wire        rst_n,

    input  wire        confirm_pulse,
    input  wire  [9:0] sw_sync,
    input  wire  [9:0] sw_latched,
    input  wire        blink_state,

    // Giao tiep rs_encoder
    output reg         encoder_start,
    output reg   [8:0] enc_data_in,
    input  wire        encoder_done,
    input  wire [14:0] enc_code_out,

    // Giao tiep rs_decoder
    output reg         decoder_start,
    input  wire        decoder_done,
    input  wire        decoder_fail,
    input  wire [14:0] dec_corr_out,

    // Dieu khien error_injector
    output reg         err_enable,
    output reg   [8:0] err_syms,

    // Trang thai & hien thi ra 3 LED 7 doan + 10 LED don
    output reg         busy,
    output reg         fail,
    output reg         log_start,
    output wire [14:0] dec_out,
    output reg   [2:0] sym0_disp,
    output reg   [2:0] sym1_disp,
    output reg   [2:0] sym2_disp,
    output reg   [9:0] led_out
);
    localparam [1:0] S_IDLE = 2'd0, S_ENC = 2'd1, S_DEC = 2'd2;

    reg  [1:0] state;
    reg  [1:0] in_cnt, err_cnt;
    reg        info_ready, err_done, sw9_prev;
    reg [14:0] out_buf;

    assign dec_out = out_buf;

    // Chon 3 symbol hien thi ra HEX2, HEX1, HEX0
    always @(*) begin
        if (info_ready) begin
            sym0_disp = out_buf[2:0];
            sym1_disp = out_buf[5:3];
            sym2_disp = out_buf[8:6];
        end else if (state != S_IDLE) begin
            sym0_disp = enc_data_in[2:0];
            sym1_disp = enc_data_in[5:3];
            sym2_disp = enc_data_in[8:6];
        end else begin
            case (in_cnt)
                2'd0: begin
                    sym0_disp = sw_sync[2:0];
                    sym1_disp = 3'd0;
                    sym2_disp = 3'd0;
                end
                2'd1: begin
                    sym0_disp = enc_data_in[2:0];
                    sym1_disp = sw_sync[2:0];
                    sym2_disp = 3'd0;
                end
                2'd2: begin
                    sym0_disp = enc_data_in[2:0];
                    sym1_disp = enc_data_in[5:3];
                    sym2_disp = sw_sync[2:0];
                end
                default: begin
                    sym0_disp = enc_data_in[2:0];
                    sym1_disp = enc_data_in[5:3];
                    sym2_disp = enc_data_in[8:6];
                end
            endcase
        end
    end

    // Dieu khien 10 LED don LEDR[9:0]
    always @(*) begin
        if (sw_sync[9] && err_done) begin
            if (fail)
                led_out = blink_state ? 10'h3FF : 10'h000;
            else
                led_out = 10'h000;
        end else begin
            led_out = (10'd1 << sw_sync[2:0]);
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state         <= S_IDLE;
            in_cnt        <= 2'd0;
            err_cnt       <= 2'd0;
            info_ready    <= 1'b0;
            err_done      <= 1'b0;
            sw9_prev      <= 1'b0;
            enc_data_in   <= 9'd0;
            out_buf       <= 15'd0;
            err_enable    <= 1'b0;
            err_syms      <= 9'd0;
            encoder_start <= 1'b0;
            decoder_start <= 1'b0;
            busy          <= 1'b0;
            fail          <= 1'b0;
            log_start     <= 1'b0;
        end else begin
            sw9_prev      <= sw_sync[9];
            encoder_start <= 1'b0;
            decoder_start <= 1'b0;
            log_start     <= 1'b0;

            case (state)
                S_IDLE: begin
                    busy <= 1'b0;

                    if (!sw9_prev && sw_sync[9]) begin
                        // Chuyen sang che do nhap loi (SW[9]: 0 -> 1)
                        err_cnt    <= 2'd0;
                        err_syms   <= 9'd0;
                        err_done   <= 1'b0;
                        err_enable <= 1'b0;
                        fail       <= 1'b0;
                        if (info_ready)
                            out_buf <= enc_code_out;
                    end else if (sw9_prev && !sw_sync[9]) begin
                        // Quay ve che do nhap thong tin moi (SW[9]: 1 -> 0)
                        in_cnt      <= 2'd0;
                        err_cnt     <= 2'd0;
                        info_ready  <= 1'b0;
                        err_done    <= 1'b0;
                        err_enable  <= 1'b0;
                        err_syms    <= 9'd0;
                        fail        <= 1'b0;
                        enc_data_in <= 9'd0;
                        out_buf     <= 15'd0;
                    end else if (confirm_pulse) begin
                        if (sw_sync[9] == 1'b0) begin
                            // Che do 0: nhap 3 symbol thong tin
                            if (info_ready) begin
                                info_ready       <= 1'b0;
                                fail             <= 1'b0;
                                enc_data_in[2:0] <= sw_latched[2:0];
                                enc_data_in[8:3] <= 6'd0;
                                in_cnt           <= 2'd1;
                            end else begin
                                case (in_cnt)
                                    2'd0: begin
                                        enc_data_in[2:0] <= sw_latched[2:0];
                                        in_cnt           <= 2'd1;
                                    end
                                    2'd1: begin
                                        enc_data_in[5:3] <= sw_latched[2:0];
                                        in_cnt           <= 2'd2;
                                    end
                                    2'd2: begin
                                        enc_data_in[8:6] <= sw_latched[2:0];
                                        in_cnt           <= 2'd0;
                                        err_enable       <= 1'b0;
                                        busy             <= 1'b1;
                                        fail             <= 1'b0;
                                        encoder_start    <= 1'b1;
                                        state            <= S_ENC;
                                    end
                                    default: in_cnt <= 2'd0;
                                endcase
                            end
                        end else if (info_ready) begin
                            // Che do 1: nhap toi da 3 loi vao 3 symbol cuoi cua tu ma
                            if (err_done) begin
                                err_done   <= 1'b0;
                                err_cnt    <= 2'd0;
                                err_syms   <= 9'd0;
                                err_enable <= 1'b0;
                                fail       <= 1'b0;
                                out_buf    <= enc_code_out;
                            end else begin
                                case (err_cnt)
                                    2'd0: err_syms[8:6] <= sw_latched[2:0]; // Symbol cuoi (sym 4)
                                    2'd1: err_syms[5:3] <= sw_latched[2:0]; // Symbol ke cuoi (sym 3)
                                    2'd2: err_syms[2:0] <= sw_latched[2:0]; // Symbol thu 3 tu cuoi (sym 2)
                                    default: ;
                                endcase

                                if (err_cnt == 2'd2 || sw_sync[8] == 1'b1) begin
                                    err_cnt       <= 2'd0;
                                    err_enable    <= 1'b1;
                                    busy          <= 1'b1;
                                    fail          <= 1'b0;
                                    decoder_start <= 1'b1;
                                    state         <= S_DEC;
                                end else begin
                                    err_cnt <= err_cnt + 2'd1;
                                end
                            end
                        end
                    end
                end

                S_ENC: begin
                    busy <= 1'b1;
                    if (encoder_done) begin
                        decoder_start <= 1'b1;
                        state         <= S_DEC;
                    end
                end

                S_DEC: begin
                    busy <= 1'b1;
                    if (decoder_done) begin
                        out_buf   <= dec_corr_out;
                        busy      <= 1'b0;
                        log_start <= 1'b1;
                        if (!err_enable) begin
                            info_ready <= 1'b1;
                            fail       <= decoder_fail;
                        end else begin
                            err_done <= 1'b1;
                            fail     <= decoder_fail || (dec_corr_out != enc_code_out);
                        end
                        state <= S_IDLE;
                    end
                end

                default: state <= S_IDLE;
            endcase
        end
    end
endmodule
