// Phep nhan trong GF(8) voi da thuc nguyen thuy p(x) = x^3 + x + 1 (4'b1011)
module gf8_mul (
    input  wire [2:0] a,
    input  wire [2:0] b,
    output reg  [2:0] y
);
    reg [2:0] aa, acc;
    integer   i;

    always @(*) begin
        aa  = a;
        acc = 3'd0;
        for (i = 0; i < 3; i = i + 1) begin
            if (b[i])
                acc = acc ^ aa;
            aa = aa[2] ? ({aa[1:0], 1'b0} ^ 3'b011) : {aa[1:0], 1'b0};
        end
        y = acc;
    end
endmodule
