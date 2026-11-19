module hex_decoder (
    input [3:0] hex_digit,
    output reg [6:0] seg_n,
    output [7:0] hex_out    
);

    always @(*) begin
        case (hex_digit)
            4'h0: seg_n = 7'b1000000; 
            4'h1: seg_n = 7'b111_1001; 
            4'h2: seg_n = 7'b010_0100;
            4'h3: seg_n = 7'b011_0000;
            4'h4: seg_n = 7'b001_1001;
            4'h5: seg_n = 7'b001_0010;
            4'h6: seg_n = 7'b000_0010;
            4'h7: seg_n = 7'b111_1000;
            4'h8: seg_n = 7'b000_0000;
            4'h9: seg_n = 7'b001_0000;
            4'hA: seg_n = 7'b000_1000;
            4'hB: seg_n = 7'b000_0011;
            4'hC: seg_n = 7'b100_0110;
            4'hD: seg_n = 7'b010_0001;
            4'hE: seg_n = 7'b000_0110;
            4'hF: seg_n = 7'b000_1110; 
            default: seg_n = 7'b111_1111;
        endcase
    end

    assign hex_out = {1'b1, seg_n};

endmodule

