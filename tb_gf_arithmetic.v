`timescale 1ns/1ps

module tb_gf_arithmetic();

    reg [7:0] a_tb;
    reg [7:0] b_tb;
    wire [7:0] add_out_tb;
    wire [7:0] mul_out_tb;
    wire [7:0] mul_alpha_out_tb;

    integer i, j;

    // Gọi module cần test
    gf_arithmetic uut (
        .a(a_tb),
        .b(b_tb),
        .out_add(add_out_tb),
        .out_mul(mul_out_tb),
        .out_mul_alpha(mul_alpha_out_tb)
    );

    initial begin
        // Khởi tạo
        a_tb = 8'h00;
        b_tb = 8'h00;
        
        $display("Bat dau kiem thu GF(256) Arithmetic...");

        // Test cộng: 0x89 ^ 0x2A = 0xA3
        a_tb = 8'b10001001; // 0x89
        b_tb = 8'b00101010; // 0x2A
        #10;
        if(add_out_tb == 8'hA3) $display("Phep cong: PASS");
        else $display("Phep cong: FAIL");

        // Test nhân: 0x89 * 0x2A = 0xC3 (có modular reduction 0x11D)
        #10;
        if(mul_out_tb == 8'hC3) $display("Phep nhan: PASS (Dap an: 0xC3)");
        else $display("Phep nhan: FAIL. Ket qua: %h", mul_out_tb);

        // Duyệt exhaustive testing (mọi cặp giá trị)
        // Cảnh báo: vòng lặp này sẽ chạy 65536 lần. 
        // Trong thực tế mô phỏng, bạn có thể comment lại phần này nếu muốn chạy nhanh.
        for (i = 0; i < 256; i = i + 1) begin
            for (j = 0; j < 256; j = j + 1) begin
                a_tb = i;
                b_tb = j;
                #1; // Đợi 1 thời gian mô phỏng
            end
        end
        $display("Hoan thanh kiem thu.");
        $stop;
    end

endmodule