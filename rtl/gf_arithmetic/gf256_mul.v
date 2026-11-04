// gf256_mul.v
// Phep nhan hai phan tu trong GF(256) theo da thuc truong p(u) =GF_PRIM_POLY.
//
// Cau hinh mac dinh tu rs_params.vh:
//   p(u) = u^8 + u^4 + u^3 + u^2 + 1 (0x11D, phan thap 8 bit = 0x1D)
//   Bit i cua byte bieu dien he so cua u^i.
//
// Kien truc: logic to hop (8 buoc dich xtime va XOR).
// Khi mot toan hang la hang so, bo tong hop Quartus tu rut gon thanh mang XOR.

`include "rs_params.vh"

module gf256_mul (
    input  wire [7:0] a,
    input  wire [7:0] b,
    output reg  [7:0] y
);

    localparam [8:0] PRIM_POLY = `GF_PRIM_POLY;
    localparam [7:0] POLY_LOW  = PRIM_POLY[7:0]; // 8'h1D

    reg [7:0] aa;
    reg [7:0] acc;
    integer   i;

    always @(*) begin
        aa  = a;
        acc = 8'h00;
        for (i = 0; i < 8; i = i + 1) begin
            if (b[i])
                acc = acc ^ aa;
            aa = aa[7] ? ((aa << 1) ^ POLY_LOW) : (aa << 1);
        end
        y = acc;
    end

endmodule
