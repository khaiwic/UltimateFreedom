// gf256_inv.v
// Nghich dao nhan trong GF(256): tim y = a^(-1) sao cho gf_mul(a, y) = 8'h01.
//
// Theo docs/gf256.md muc 5 & 6:
//   - Voi a != 0: a^(-1) = a^254 = alpha^((-log[a]) mod 255), valid = 1, zero_err = 0.
//   - Voi a == 0: 0 khong co nghich dao, tra ve y = 8'h00, valid = 0, zero_err = 1.
//   - Bang tra (LUT 256 byte) duoc sinh tu dong luc tong hop tu GF_PRIM_POLY va GF_ALPHA.

`include "rs_params.vh"

module gf256_inv (
    input  wire [7:0] a,
    output wire [7:0] y,
    output wire       valid,
    output wire       zero_err
);

    localparam [8:0] PRIM_POLY = `GF_PRIM_POLY;
    localparam [7:0] POLY_LOW  = PRIM_POLY[7:0];
    localparam [7:0] ALPHA     = `GF_ALPHA;

    function [7:0] gf_mul_const;
        input [7:0] x;
        input [7:0] z;
        reg   [7:0] xx;
        reg   [7:0] acc;
        integer     k;
        begin
            xx  = x;
            acc = 8'h00;
            for (k = 0; k < 8; k = k + 1) begin
                if (z[k])
                    acc = acc ^ xx;
                xx = xx[7] ? ((xx << 1) ^ POLY_LOW) : (xx << 1);
            end
            gf_mul_const = acc;
        end
    endfunction

    // Sinh bang nghich dao 256 byte tu bang luy thua alpha^i
    function [256*8-1:0] build_inv_lut;
        input integer dummy;
        reg [255*8-1:0] exp_tbl;
        reg [256*8-1:0] lut;
        reg [7:0]       cur;
        reg [7:0]       elem;
        reg [7:0]       inv_elem;
        integer         i;
        begin
            cur = 8'h01;
            for (i = 0; i < 255; i = i + 1) begin
                exp_tbl[8*i +: 8] = cur;
                cur = gf_mul_const(cur, ALPHA);
            end

            lut        = {256*8{1'b0}};
            lut[8*1 +: 8] = 8'h01; // inv(1) = 1
            for (i = 1; i < 255; i = i + 1) begin
                elem     = exp_tbl[8*i +: 8];
                inv_elem = exp_tbl[8*(255 - i) +: 8];
                lut[8*elem +: 8] = inv_elem;
            end
            build_inv_lut = lut;
        end
    endfunction

    localparam [256*8-1:0] INV_LUT = build_inv_lut(0);

    assign y        = INV_LUT[8*a +: 8];
    assign zero_err = (a == 8'h00);
    assign valid    = !zero_err;

endmodule
