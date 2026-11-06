// display_control.v
// Dieu khien hien thi LED trang thai va hai LED 7 doan HEX0, HEX1 tren DE10-Lite.
//
// Dac ta theo:
//   - README_RS_DE10_Lite.md (muc 2, 3, 4, 5.3, 5.4)
//   - docs/pin_assignment.md (muc 4, 5)
//
// Chuc nang:
//   1. Chot trang thai LEDR (tich cuc cao: 1 la sang):
//      - LEDR[0]: busy (sang khi loi RS / bo dieu khien dang xu ly).
//      - LEDR[1]: done da chot (giu sang de quan sat sau khi core phat xung done 1 chu ky).
//      - LEDR[2]: fail da chot (giu sang neu giai ma that bai hoac loi vuot kha nang).
//      - clear_status (hoac khi bat dau luot moi / reset): xoa chot done va fail.
//   2. Hien thi byte du lieu tren 2 LED 7 doan:
//      - HEX1: hien thi 4 bit cao byte_in[7:4].
//      - HEX0: hien thi 4 bit thap byte_in[3:0].
//      - Su dung 2 instance hex_decoder de chuyen doi sang mau 7 doan tich cuc thap.
//      - Dau cham DP (bit 7) luon tat (= 1'b1).

module display_control (
    input  wire        clk,
    input  wire        rst_n,

    // Tin hieu trang thai tu he thong / loi RS
    input  wire        core_busy,
    input  wire        core_done,
    input  wire        core_fail,
    input  wire        clear_status,     // Xoa trang thai chot de bat dau luot moi

    // Byte du lieu can hien thi len HEX1:HEX0 (du lieu nhap hoac ket qua)
    input  wire [7:0]  byte_in,

    // Dau ra noi truc tiep vao cac chan ngoai vi DE10-Lite
    output wire [2:0]  LEDR,
    output wire [7:0]  HEX0,
    output wire [7:0]  HEX1
);

    // ------------------------------------------------------------------------
    // 1. Chot trang thai LEDR
    // ------------------------------------------------------------------------
    reg done_latched;
    reg fail_latched;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            done_latched <= 1'b0;
            fail_latched <= 1'b0;
        end else begin
            if (clear_status) begin
                done_latched <= 1'b0;
                fail_latched <= 1'b0;
            end else begin
                if (core_done)
                    done_latched <= 1'b1;
                if (core_fail)
                    fail_latched <= 1'b1;
            end
        end
    end

    // LEDR[0] = busy (hien tai), LEDR[1] = done (da chot), LEDR[2] = fail (da chot)
    assign LEDR[0] = core_busy;
    assign LEDR[1] = done_latched;
    assign LEDR[2] = fail_latched;

    // ------------------------------------------------------------------------
    // 2. Giai ma 7 doan cho byte_in[7:0]
    // ------------------------------------------------------------------------
    // HEX1: 4 bit cao (MSB nibble)
    hex_decoder u_hex1 (
        .hex_digit (byte_in[7:4]),
        .seg_n     (),
        .hex_out   (HEX1)
    );

    // HEX0: 4 bit thap (LSB nibble)
    hex_decoder u_hex0 (
        .hex_digit (byte_in[3:0]),
        .seg_n     (),
        .hex_out   (HEX0)
    );

endmodule

