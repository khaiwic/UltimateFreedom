// error_injector.v
// Khoi tao loi (Error Injector) cho bai demo RS(15,11) tren DE10-Lite.
//
// Dac ta theo:
//   - README_RS_DE10_Lite.md (muc 1, 2, 3, 4)
//   - docs/rs_algorithm.md (muc 12)
//
// Chuc nang:
//   - Hoat dong theo giao thuc Streaming valid/ready: nhan N symbol tu rs_encoder
//     hoac data_buffer va xuat sang rs_decoder.
//   - Neu enable == 1 (SW[9] gat len): XOR mat na loi vao cac symbol tai vi tri duoc chi dinh.
//     Mac dinh su dung 2 vi tri bien theo vi du muc 12 cua docs:
//       + Symbol 0 (dau khoi du lieu):  XOR 8'h55
//       + Symbol 14 (cuoi khoi parity): XOR 8'hA6
//     Ho tro nap vi tri va mat na tuy bien qua cac cong err_pos/err_mask.
//   - Neu enable == 0 (SW[9] gat xuong): Du lieu di qua nguyen ven khong bi bien doi.
//   - Tuan thu giao thuc bat tay: giu data_out on dinh khi out_valid = 1 va out_ready = 0.
//     out_last = 1 tai symbol thu N. done phat xung 1 chu ky khi xong khoi.

`include "rs_params.vh"

module error_injector #(
    parameter integer N             = `RS_N,
    parameter integer ADDR_W        = (N > 1) ? $clog2(N) : 1,
    parameter integer CNT_W         = $clog2(N + 1),
    parameter [ADDR_W-1:0] DEF_POS1 = 0,             // Vi tri 0 (dau khoi)
    parameter [7:0]        DEF_MSK1 = 8'h55,         // Mat na 0x55
    parameter [ADDR_W-1:0] DEF_POS2 = N - 1,         // Vi tri 14 (cuoi khoi)
    parameter [7:0]        DEF_MSK2 = 8'hA6          // Mat na 0xA6
) (
    input  wire              clk,
    input  wire              rst_n,

    // Tin hieu dieu khien khoi
    input  wire              start,
    input  wire              enable,               // Noi tu SW[9] de bat/tat tao loi
    input  wire              two_errors,           // 1 = tao 2 loi (POS1 va POS2), 0 = chi 1 loi (POS1)

    // Cac thong so vi tri va mat na loi (neu de trong se dung mac dinh)
    input  wire [ADDR_W-1:0] err_pos1,
    input  wire [7:0]        err_mask1,
    input  wire [ADDR_W-1:0] err_pos2,
    input  wire [7:0]        err_mask2,
    input  wire              use_custom_pattern,   // 1 = dung err_pos/mask ngoai, 0 = dung DEF_*

    // Cong nap luong (Streaming In)
    input  wire [7:0]        data_in,
    input  wire              in_valid,
    output wire              in_ready,

    // Cong phat luong (Streaming Out)
    output reg  [7:0]        data_out,
    output reg               out_valid,
    input  wire              out_ready,
    output reg               out_last,

    // Trang thai
    output wire              busy,
    output reg               done
);

    localparam [1:0] S_IDLE  = 2'd0,
                     S_PASS  = 2'd1,   // Dang nhan va xuat symbol
                     S_DRAIN = 2'd2;   // Cho symbol cuoi cung duoc doc

    reg [1:0]       state;
    reg [CNT_W-1:0] cnt;
    reg             en_latched;
    reg             two_err_latched;
    reg [ADDR_W-1:0] p1, p2;
    reg [7:0]        m1, m2;

    wire out_free = !out_valid || out_ready;
    assign in_ready = (state == S_PASS) && out_free;
    assign busy     = (state != S_IDLE);

    wire in_fire  = in_valid && in_ready;
    wire out_fire = out_valid && out_ready;

    // Tinh toan mat na XOR cho symbol hien tai
    wire is_err1 = (cnt == p1);
    wire is_err2 = two_err_latched && (cnt == p2);
    wire [7:0] xor_val = (is_err1 ? m1 : 8'h00) ^ (is_err2 ? m2 : 8'h00);
    wire [7:0] sym_corrupted = en_latched ? (data_in ^ xor_val) : data_in;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state           <= S_IDLE;
            cnt             <= {CNT_W{1'b0}};
            en_latched      <= 1'b0;
            two_err_latched <= 1'b1;
            p1              <= DEF_POS1;
            p2              <= DEF_POS2;
            m1              <= DEF_MSK1;
            m2              <= DEF_MSK2;
            data_out        <= 8'h00;
            out_valid       <= 1'b0;
            out_last        <= 1'b0;
            done            <= 1'b0;
        end else begin
            done <= 1'b0;

            if (out_fire) begin
                out_valid <= 1'b0;
                out_last  <= 1'b0;
            end

            case (state)
                S_IDLE: begin
                    if (start) begin
                        cnt             <= {CNT_W{1'b0}};
                        en_latched      <= enable;
                        two_err_latched <= two_errors;
                        p1              <= use_custom_pattern ? err_pos1 : DEF_POS1;
                        m1              <= use_custom_pattern ? err_mask1 : DEF_MSK1;
                        p2              <= use_custom_pattern ? err_pos2 : DEF_POS2;
                        m2              <= use_custom_pattern ? err_mask2 : DEF_MSK2;
                        state           <= S_PASS;
                    end
                end

                S_PASS: begin
                    if (in_fire) begin
                        data_out  <= sym_corrupted;
                        out_valid <= 1'b1;
                        out_last  <= (cnt == N - 1);

                        cnt <= cnt + 1'b1;
                        if (cnt == N - 1) begin
                            state <= S_DRAIN;
                        end
                    end
                end

                S_DRAIN: begin
                    if (out_fire) begin
                        done  <= 1'b1;
                        state <= S_IDLE;
                    end
                end

                default: state <= S_IDLE;
            endcase
        end
    end

endmodule

