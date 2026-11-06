// result_checker.v
// Khoi doi chieu ket qua (Result Checker) cho bai demo RS tren DE10-Lite.
//
// Dac ta theo:
//   - README_RS_DE10_Lite.md (muc 3, 10)
//   - docs/rs_algorithm.md (muc 11, 13)
//   - rtl/memory/data_buffer.v (cong chk_addr / chk_data)
//
// Chuc nang:
//   - So sanh du lieu tu ma sau khi giai ma voi ban goc da luu trong data_buffer.
//   - Ho tro 2 che do doi chieu:
//       1. Che do bo nho (Memory-based Check):
//          Tu dong quet dia chi tu 0 den (length - 1) tren 2 cong doc cua
//          bo dem ban goc (orig_addr -> orig_data) va bo dem ket qua (dec_addr -> dec_data).
//       2. Che do luong (Stream-based Check):
//          Doi chieu truc tiep tung symbol khi rs_decoder dang xuat (stream_data, stream_valid)
//          so voi byte ban goc doc tai orig_addr.
//   - Dau ra:
//       + match = 1 neu 100% cac byte deu khop hoan toan; match = 0 neu co sai lech.
//       + mismatch_count: so byte khong khop.
//       + first_err_addr: vi tri byte loi dau tien duoc tim thay.
//       + busy, done: tin hieu trang thai bat tay FSM.

`include "rs_params.vh"

module result_checker #(
    parameter integer DEPTH  = `RS_N,
    parameter integer ADDR_W = (DEPTH > 1) ? $clog2(DEPTH) : 1,
    parameter integer CNT_W  = $clog2(DEPTH + 1),
    parameter integer DEF_LEN = `RS_K             // Mac dinh doi chieu K=11 byte du lieu goc
) (
    input  wire              clk,
    input  wire              rst_n,

    // Dieu khien bat dau kiem tra
    input  wire              start,
    input  wire [CNT_W-1:0]  check_length,        // Do dai can doi chieu (K=11 hoac N=15)
    input  wire              use_custom_len,      // 1 = dung check_length, 0 = dung DEF_LEN

    // Cong doc bo dem 1 (Ban goc da luu truoc do trong data_buffer)
    output wire [ADDR_W-1:0] orig_addr,
    input  wire [7:0]        orig_data,

    // Cong doc bo dem 2 (Ban giai ma tu rs_decoder trong data_buffer)
    output wire [ADDR_W-1:0] dec_addr,
    input  wire [7:0]        dec_data,

    // Cong giam sat luong truc tiep (tuy chon, khi decoder streaming out)
    input  wire              stream_mode,         // 1 = bat che do luong, 0 = che do bo nho
    input  wire [7:0]        stream_data,
    input  wire              stream_valid,
    input  wire              stream_last,

    // Ket qua kiem tra
    output wire              busy,
    output reg               done,
    output reg               match,               // 1 = khop 100%, 0 = co it nhat 1 byte sai
    output reg  [CNT_W-1:0]  mismatch_count,      // So luong byte bi sai lech
    output reg  [ADDR_W-1:0] first_err_addr       // Dia chi byte sai lech dau tien
);

    localparam [1:0] S_IDLE    = 2'd0,
                     S_MEM_CHK = 2'd1,
                     S_STR_CHK = 2'd2;

    reg [1:0]        state;
    reg [CNT_W-1:0]  cnt;
    reg [CNT_W-1:0]  len_latched;
    reg              has_err;

    assign busy = (state != S_IDLE);

    assign orig_addr = cnt[ADDR_W-1:0];
    assign dec_addr  = cnt[ADDR_W-1:0];

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state          <= S_IDLE;
            cnt            <= {CNT_W{1'b0}};
            len_latched    <= DEF_LEN;
            match          <= 1'b0;
            mismatch_count <= {CNT_W{1'b0}};
            first_err_addr <= {ADDR_W{1'b0}};
            has_err        <= 1'b0;
            done           <= 1'b0;
        end else begin
            done <= 1'b0;

            case (state)
                S_IDLE: begin
                    if (start) begin
                        cnt            <= {CNT_W{1'b0}};
                        len_latched    <= use_custom_len ? check_length : DEF_LEN;
                        match          <= 1'b1;
                        mismatch_count <= {CNT_W{1'b0}};
                        first_err_addr <= {ADDR_W{1'b0}};
                        has_err        <= 1'b0;

                        if (stream_mode)
                            state <= S_STR_CHK;
                        else
                            state <= S_MEM_CHK;
                    end
                end

                S_MEM_CHK: begin
                    // So sanh orig_data va dec_data tai dia chi cnt
                    if (orig_data !== dec_data) begin
                        match          <= 1'b0;
                        mismatch_count <= mismatch_count + 1'b1;
                        if (!has_err) begin
                            first_err_addr <= cnt[ADDR_W-1:0];
                            has_err        <= 1'b1;
                        end
                    end

                    cnt <= cnt + 1'b1;
                    if (cnt == len_latched - 1) begin
                        done  <= 1'b1;
                        state <= S_IDLE;
                    end
                end

                S_STR_CHK: begin
                    // So sanh symbol dang streaming voi byte tai orig_addr
                    if (stream_valid) begin
                        if (stream_data !== orig_data) begin
                            match          <= 1'b0;
                            mismatch_count <= mismatch_count + 1'b1;
                            if (!has_err) begin
                                first_err_addr <= cnt[ADDR_W-1:0];
                                has_err        <= 1'b1;
                            end
                        end

                        cnt <= cnt + 1'b1;
                        if (stream_last || (cnt == len_latched - 1)) begin
                            done  <= 1'b1;
                            state <= S_IDLE;
                        end
                    end
                end

                default: state <= S_IDLE;
            endcase
        end
    end

endmodule

