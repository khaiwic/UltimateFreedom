// Nghich dao trong GF(8) voi p(x) = x^3 + x + 1 (bang tra 8 gia tri)
module gf8_inv (
    input  wire [2:0] a,
    output reg  [2:0] y,
    output wire       valid,
    output wire       zero_err
);
    always @(*) begin
        case (a)
            3'd0: y = 3'd0;
            3'd1: y = 3'd1;
            3'd2: y = 3'd5;
            3'd3: y = 3'd6;
            3'd4: y = 3'd7;
            3'd5: y = 3'd2;
            3'd6: y = 3'd3;
            3'd7: y = 3'd4;
            default: y = 3'd0;
        endcase
    end

    assign zero_err = (a == 3'd0);
    assign valid    = !zero_err;
endmodule
