// hex_decoder.v
// Bo giai ma 4-bit (nibble 0..F) sang mau LED 7 doan tren DE10-Lite.
//
// Dac ta theo:
//   - README_RS_DE10_Lite.md (muc 2, 5.4)
//   - docs/pin_assignment.md (muc 5)
//
// Quy uoc phan cung DE10-Lite:
//   - Cac doan tich cuc thap: 0 sang, 1 tat.
//   - Thu tu doan: [0]=a, [1]=b, [2]=c, [3]=d, [4]=e, [5]=f, [6]=g, [7]=DP.
//   - Dau cham DP khong dung, luon dat bang 1 (tat).
//
// Mau 7 doan (tich cuc thap, DP = 1):
//   0: 8'hC0, 1: 8'hF9, 2: 8'hA4, 3: 8'hB0
//   4: 8'h99, 5: 8'h92, 6: 8'h82, 7: 8'hF8
//   8: 8'h80, 9: 8'h90, A: 8'h88, B: 8'h83
//   C: 8'hC6, D: 8'hA1, E: 8'h86, F: 8'h8E

module hex_decoder (
    input  wire [3:0] hex_digit,
    output reg  [6:0] seg_n,
    output wire [7:0] hex_out     // Cung cap san 8 bit kem DP = 1'b1 cho tien noi truc tiep vao HEX0/1
);

    always @(*) begin
        case (hex_digit)
            4'h0: seg_n = 7'b100_0000; // 0x40
            4'h1: seg_n = 7'b111_1001; // 0x79
            4'h2: seg_n = 7'b010_0100; // 0x24
            4'h3: seg_n = 7'b011_0000; // 0x30
            4'h4: seg_n = 7'b001_1001; // 0x19
            4'h5: seg_n = 7'b001_0010; // 0x12
            4'h6: seg_n = 7'b000_0010; // 0x02
            4'h7: seg_n = 7'b111_1000; // 0x78
            4'h8: seg_n = 7'b000_0000; // 0x00
            4'h9: seg_n = 7'b001_0000; // 0x10
            4'hA: seg_n = 7'b000_1000; // 0x08
            4'hB: seg_n = 7'b000_0011; // 0x03
            4'hC: seg_n = 7'b100_0110; // 0x46
            4'hD: seg_n = 7'b010_0001; // 0x21
            4'hE: seg_n = 7'b000_0110; // 0x06
            4'hF: seg_n = 7'b000_1110; // 0x0E
            default: seg_n = 7'b111_1111; // tat het
        endcase
    end

    // Bit 7 la dau cham DP, luon bang 1'b1 (tat)
    assign hex_out = {1'b1, seg_n};

endmodule

