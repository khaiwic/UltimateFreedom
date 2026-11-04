module gf_arithmetic (
    input  [7:0] a,
    input  [7:0] b,
    output [7:0] out_add,
    output [7:0] out_mul,
    output [7:0] out_mul_alpha
);

    // 1. Phép cộng trong GF(256) (Phép XOR từng bit)
    assign out_add = a ^ b;

    // 2. Phép nhân với phần tử nguyên thủy Alpha
    function [7:0] gf_mult_alpha;
        input [7:0] val;
        begin
            if (val[7] == 1'b1) 
                // Dịch trái và XOR với phần dư của đa thức sinh 0x11D
                gf_mult_alpha = (val << 1) ^ 8'b00011101;
            else
                // Không tràn bit, chỉ việc dịch trái
                gf_mult_alpha = val << 1;
        end
    endfunction
    
    // Ánh xạ hàm tính nhân Alpha ra output
    assign out_mul_alpha = gf_mult_alpha(a);

    // 3. Phép nhân 2 phần tử bất kỳ trong GF(256) sử dụng thuật toán carry-less
    function [7:0] gf_mult;
        input [7:0] x;
        input [7:0] y;
        reg   [7:0] p; // Lưu kết quả tạm thời
        reg   [7:0] temp_x;
        integer i;
        begin
            p = 8'b0;
            temp_x = x;
            // Thuật toán nhân chuỗi: duyệt qua 8 bit của y
            for (i = 0; i < 8; i = i + 1) begin
                if (y[i] == 1'b1) begin
                    p = p ^ temp_x; // Phép cộng trong GF(256) là XOR
                end
                // Chuẩn bị temp_x cho chu kỳ bit tiếp theo của y (nhân với alpha)
                temp_x = gf_mult_alpha(temp_x);
            end
            gf_mult = p;
        end
    endfunction

    // Ánh xạ hàm nhân ra output
    assign out_mul = gf_mult(a, b);

endmodule