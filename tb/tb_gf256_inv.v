`timescale 1ns/1ps
`include "rs_params.vh"

module tb_gf256_inv;

    `include "rs_tb_ref.vh"

    reg  [7:0] a;
    wire [7:0] y;
    wire       valid;
    wire       zero_err;

    gf256_inv dut (.a(a), .y(y), .valid(valid), .zero_err(zero_err));

    integer i;
    reg [7:0] yi;
    reg       seen [0:255];

    initial begin
        for (i = 0; i < 256; i = i + 1) seen[i] = 1'b0;

        // ---- a = 0
        a = 8'h00; #1;
        n_chk = n_chk + 3;
        if (y !== 8'h00)       begin n_err = n_err + 1; $display("LOI: inv(0) y=%h (mong doi 00)", y); end
        if (valid !== 1'b0)    begin n_err = n_err + 1; $display("LOI: inv(0) valid=%b (mong doi 0)", valid); end
        if (zero_err !== 1'b1) begin n_err = n_err + 1; $display("LOI: inv(0) zero_err=%b (mong doi 1)", zero_err); end

        // ---- a != 0: duyet day du
        for (i = 1; i < 256; i = i + 1) begin
            a = i[7:0]; #1;
            yi = y;
            n_chk = n_chk + 5;
            if (^{y, valid, zero_err} === 1'bx) begin
                n_err = n_err + 1; $display("LOI: inv(%h) co X/Z", a);
            end
            if (valid !== 1'b1)    begin n_err = n_err + 1; $display("LOI: inv(%h) valid=%b", a, valid); end
            if (zero_err !== 1'b0) begin n_err = n_err + 1; $display("LOI: inv(%h) zero_err=%b", a, zero_err); end
            if (r_mul(a, yi) !== 8'h01) begin
                n_err = n_err + 1;
                if (n_err <= 20) $display("LOI: %h * inv(%h)=%h -> %h (mong doi 01)", a, a, yi, r_mul(a, yi));
            end
            if (yi !== r_inv(a)) begin
                n_err = n_err + 1;
                if (n_err <= 20) $display("LOI: inv(%h)=%h (tham chieu %h)", a, yi, r_inv(a));
            end
            // song anh
            if (seen[yi]) begin n_err = n_err + 1; $display("LOI: inv khong la song anh, %h lap", yi); end
            seen[yi] = 1'b1;
            // inv(inv(a)) = a
            a = yi; #1;
            n_chk = n_chk + 1;
            if (y !== i[7:0]) begin n_err = n_err + 1; $display("LOI: inv(inv(%h)) = %h", i, y); end
        end
        n_chk = n_chk + 1;
        if (seen[0] !== 1'b0) begin n_err = n_err + 1; $display("LOI: inv cua phan tu khac 0 bang 0"); end

        // ---- Gia tri co dinh
        a = 8'h01; #1; n_chk = n_chk + 1;
        if (y !== 8'h01) begin n_err = n_err + 1; $display("LOI: inv(01) = %h", y); end
        a = 8'h02; #1; n_chk = n_chk + 1;
        if (y !== 8'h8E) begin n_err = n_err + 1; $display("LOI: inv(02) = %h (mong doi 8E)", y); end
        a = 8'h8E; #1; n_chk = n_chk + 1;
        if (y !== 8'h02) begin n_err = n_err + 1; $display("LOI: inv(8E) = %h (mong doi 02)", y); end

        // ---- Quay lai 0 sau khi dung phan tu khac 0: valid/zero_err phai cap nhat
        a = 8'h37; #1;
        a = 8'h00; #1;
        n_chk = n_chk + 1;
        if (y !== 8'h00 || valid !== 1'b0 || zero_err !== 1'b1) begin
            n_err = n_err + 1; $display("LOI: dau ra khong cap nhat khi a quay ve 0");
        end

        t_finish("tb_gf256_inv");
    end

    initial begin
        #10_000_000;
        $display("[FAIL] tb_gf256_inv: het thoi gian");
        $finish;
    end

endmodule

