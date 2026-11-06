// cycle_counter.v
// Bo dem chu ky xu ly (Cycle Counter) phuc vu do dac hieu nang va timing tren DE10-Lite.
//
// Dac ta theo:
//   - README_RS_DE10_Lite.md (muc 11)
//
// Chuc nang:
//   - Do chinh xac so luong chu ky xung nhip (clock cycles) can thiet de hoan tat
//     mot qua trinh (vi du: thoi gian ma hoa cua rs_encoder, thoi gian giai ma cua rs_decoder).
//   - Ho tro 2 che do do:
//       1. Che do Xung Start/Stop (Pulse Mode):
//          Xung `start` kich hoat bo dem bat dau chay; xung `stop` dung va chot so chu ky.
//       2. Che do Muc Enable (Level Mode):
//          Dem lien tuc trong khi tin hieu `count_en` (vi du tin hieu `busy`) o muc cao 1.
//   - Do rong 32-bit: dem toi da hon 4.2 ty chu ky (> 85 giay tai clock 50 MHz),
//     khong lo bi tran (overflow) trong cac giao dich thuc te.
//   - Ket qua duoc chot on dinh tai `cycles[31:0]` kem co `valid = 1` de de dang quan sat
//     tren SignalTap, hien thi LED/HEX hoac truyen qua UART len may tinh.

module cycle_counter #(
    parameter integer WIDTH = 32
) (
    input  wire             clk,
    input  wire             rst_n,

    // Tin hieu dieu khien do
    input  wire             start,          // Xung 1 chu ky bat dau dem (xoa bo dem cu va chay)
    input  wire             stop,           // Xung 1 chu ky ket thuc dem va chot ket qua
    input  wire             clear,          // Xoa bo dem ve 0
    input  wire             count_en,       // Cho phep dem theo muc (vi du noi truc tiep vao busy)
    input  wire             use_level_mode, // 1 = dem theo count_en, 0 = dem theo start/stop

    // Ket qua do dac
    output reg  [WIDTH-1:0] cycles,         // So chu ky dem duoc da chot
    output reg              running,        // 1 khi bo dem dang tich cuc dem
    output reg              valid,          // 1 khi ket qua do da san sang va hop le
    output reg              overflow        // 1 neu bo dem dat gia tri toi da
);

    reg [WIDTH-1:0] internal_cnt;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cycles       <= {WIDTH{1'b0}};
            internal_cnt <= {WIDTH{1'b0}};
            running      <= 1'b0;
            valid        <= 1'b0;
            overflow     <= 1'b0;
        end else begin
            if (clear) begin
                cycles       <= {WIDTH{1'b0}};
                internal_cnt <= {WIDTH{1'b0}};
                running      <= 1'b0;
                valid        <= 1'b0;
                overflow     <= 1'b0;
            end else if (use_level_mode) begin
                // Che do muc: dem khi count_en = 1
                if (count_en) begin
                    running <= 1'b1;
                    valid   <= 1'b0;
                    if (internal_cnt == {WIDTH{1'b1}})
                        overflow <= 1'b1;
                    else
                        internal_cnt <= internal_cnt + 1'b1;
                end else begin
                    if (running) begin
                        running <= 1'b0;
                        valid   <= 1'b1;
                        cycles  <= internal_cnt;
                    end
                end
            end else begin
                // Che do xung start / stop
                if (start) begin
                    internal_cnt <= {WIDTH{1'b0}};
                    running      <= 1'b1;
                    valid        <= 1'b0;
                    overflow     <= 1'b0;
                end else if (stop && running) begin
                    running <= 1'b0;
                    valid   <= 1'b1;
                    cycles  <= internal_cnt + 1'b1; // Tinh ca chu ky stop
                end else if (running) begin
                    if (internal_cnt == {WIDTH{1'b1}})
                        overflow <= 1'b1;
                    else
                        internal_cnt <= internal_cnt + 1'b1;
                end
            end
        end
    end

endmodule

