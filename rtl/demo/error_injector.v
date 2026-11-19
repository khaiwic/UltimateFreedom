// Khoi tao loi cho 3 symbol cuoi cua tu ma RS(5,3)
module error_injector (
    input  wire        enable,    // 1 = chen loi, 0 = giu nguyen
    input  wire  [8:0] err_syms,  // [8:6]=loi sym4, [5:3]=loi sym3, [2:0]=loi sym2
    input  wire [14:0] code_in,
    output wire [14:0] code_out
);
    assign code_out = enable ? (code_in ^ {err_syms, 6'd0}) : code_in;
endmodule
