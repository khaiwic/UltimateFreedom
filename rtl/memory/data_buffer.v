// data_buffer.v
// Bo dem luu du lieu goc (K byte), tu ma RS (N byte) hoac ket qua giai ma.
//
// Ho tro 2 che do truy cap:
//   1. Giao tiep luong (Streaming valid/ready theo README muc 3):
//      - Nap noi tiep qua (data_in, in_valid, in_ready): tu dong tang con tro
//        ghi va bo dem count den khi day (full = 1).
//      - Phat noi tiep qua (stream_start -> data_out, out_valid, out_ready,
//        out_last, stream_done): day du lieu tu dia chi 0 den (count - 1) sang
//        rs_encoder, error_injector hoac rs_decoder. Giu nguyen data_out khi
//        out_valid = 1 nhung out_ready = 0.
//   2. Truy cap ngau nhien theo dia chi (Random Access):
//      - Ghi truc tiep 1 byte tai wr_addr khi wr_en = 1.
//      - 2 cong doc to hop doc lap:
//          + (rd_addr  -> rd_data):  dung cho display_control (xem tren HEX)
//                                    hoac bo dieu khien.
//          + (chk_addr -> chk_data): dung cho result_checker doi chieu ket qua.

`include "rs_params.vh"

module data_buffer #(
    parameter integer DEPTH  = `RS_N,
    parameter integer ADDR_W = (DEPTH > 1) ? $clog2(DEPTH) : 1,
    parameter integer CNT_W  = $clog2(DEPTH + 1)
) (
    input  wire              clk,
    input  wire              rst_n,

    // Xoa bo dem va dua con tro ve 0
    input  wire              clear,

    // 1. Cong nap luong (Streaming Write)
    input  wire [7:0]        data_in,
    input  wire              in_valid,
    output wire              in_ready,

    // 2. Cong ghi ngau nhien theo dia chi (Random-Access Write)
    input  wire              wr_en,
    input  wire [ADDR_W-1:0] wr_addr,
    input  wire [7:0]        wr_data,

    // 3. Cong phat luong (Streaming Read)
    input  wire              stream_start,
    output wire [7:0]        data_out,
    output wire              out_valid,
    input  wire              out_ready,
    output wire              out_last,
    output wire              stream_busy,
    output reg               stream_done,

    // 4. Hai cong doc ngau nhien theo dia chi (Random-Access Read)
    input  wire [ADDR_W-1:0] rd_addr,
    output wire [7:0]        rd_data,

    input  wire [ADDR_W-1:0] chk_addr,
    output wire [7:0]        chk_data,

    // 5. Trang thai bo dem
    output reg  [CNT_W-1:0]  count,
    output wire              full,
    output wire              empty
);

    // Mang thanh ghi luu symbol (15 byte rat nho, dung FF cho phép doc da cong
    // khong tre va xoa tuc thi khi reset/clear).
    reg [7:0] mem [0:DEPTH-1];

    reg              streaming;
    reg [ADDR_W-1:0] rd_ptr;
    reg [CNT_W-1:0]  stream_len;

    assign full        = (count == DEPTH[CNT_W-1:0]);
    assign empty       = (count == {CNT_W{1'b0}});
    assign in_ready    = !streaming && !full;
    assign stream_busy = streaming;

    wire in_fire  = in_valid && in_ready;
    wire out_fire = out_valid && out_ready;

    // Dau ra luong
    assign out_valid = streaming;
    assign data_out  = (streaming && (rd_ptr < DEPTH)) ? mem[rd_ptr] : 8'h00;
    assign out_last  = streaming && ({1'b0, rd_ptr} + 1'b1 == stream_len);

    // Hai cong doc ngau nhien (kiem tra bien an toan khi DEPTH khong phai luy thua 2)
    assign rd_data   = (rd_addr  < DEPTH) ? mem[rd_addr]  : 8'h00;
    assign chk_data  = (chk_addr < DEPTH) ? mem[chk_addr] : 8'h00;

    // So luong symbol se phat khi nhan stream_start:
    // Neu da nap theo luong (count > 0) thi phat count symbol;
    // neu nap qua wr_en (count == 0) thi phat du DEPTH symbol.
    wire [CNT_W-1:0] eff_len = (count != {CNT_W{1'b0}}) ? count : DEPTH[CNT_W-1:0];

    integer i;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            count       <= {CNT_W{1'b0}};
            streaming   <= 1'b0;
            rd_ptr      <= {ADDR_W{1'b0}};
            stream_len  <= {CNT_W{1'b0}};
            stream_done <= 1'b0;
            for (i = 0; i < DEPTH; i = i + 1)
                mem[i] <= 8'h00;
        end else begin
            stream_done <= 1'b0;

            if (clear) begin
                count      <= {CNT_W{1'b0}};
                streaming  <= 1'b0;
                rd_ptr     <= {ADDR_W{1'b0}};
                stream_len <= {CNT_W{1'b0}};
                for (i = 0; i < DEPTH; i = i + 1)
                    mem[i] <= 8'h00;
            end else begin
                // 1. Ghi ngau nhien theo dia chi
                if (wr_en && (wr_addr < DEPTH)) begin
                    mem[wr_addr] <= wr_data;
                    if ((wr_addr + {{(CNT_W-1){1'b0}}, 1'b1}) > count)
                        count <= wr_addr + {{(CNT_W-1){1'b0}}, 1'b1};
                end

                // 2. Nap noi tiep theo luong valid/ready
                if (in_fire) begin
                    mem[count[ADDR_W-1:0]] <= data_in;
                    count                  <= count + 1'b1;
                end

                // 3. Phat noi tiep theo luong valid/ready
                if (!streaming) begin
                    if (stream_start) begin
                        streaming  <= 1'b1;
                        rd_ptr     <= {ADDR_W{1'b0}};
                        stream_len <= eff_len;
                    end
                end else if (out_fire) begin
                    if (out_last) begin
                        streaming   <= 1'b0;
                        rd_ptr      <= {ADDR_W{1'b0}};
                        stream_done <= 1'b1;
                    end else begin
                        rd_ptr <= rd_ptr + 1'b1;
                    end
                end
            end
        end
    end

endmodule
