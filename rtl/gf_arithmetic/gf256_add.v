// gf256_add.v
// Phep cong / tru hai phan tu trong GF(256).
// Trong truong dac so 2, cong va tru deu la phep XOR tung bit:
//   y = a + b = a - b = a ^ b

`include "rs_params.vh"

module gf256_add (
    input  wire [7:0] a,
    input  wire [7:0] b,
    output wire [7:0] y
);

    assign y = a ^ b;

endmodule
