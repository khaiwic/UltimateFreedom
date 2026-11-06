// tb_gf256_mul.v
// Testbench cho rtl/gf_arithmetic/gf256_mul.v (README muc 10: "tb_gf256_mul").
//
// Noi dung:
//   1. Tu kiem tra bang log/exp: alpha co bac dung 255 (bang exp khong lap).
//   2. Doi chieu day du 256 x 256 = 65536 cap voi mo hinh log/exp
//      (doc lap voi phep dich-va-cong cua RTL).
//   3. Tinh chat dai so: giao hoan, ket hop, phan phoi tren XOR, 0 va 1.
//   4. Vi du co dinh: 02*80 = 1D (rut gon theo 0x11D), 02*8E = 01.
//   5. Phep nhan phai la phep nhan GF, khong phai a*b nguyen (10*10 = 1D).
//
// Chay: vlog +incdir+../rtl/include +incdir+../tb ../rtl/gf_arithmetic/gf256_mul.v tb_gf256_mul.v
`timescale 1ns/1ps
`include "rs_params.vh"

module tb_gf256_mul;

    `include "rs_tb_ref.vh"

    reg  [7:0] a, b;
    wire [7:0] y;

    gf256_mul dut (.a(a), .b(b), .y(y));

    // Mo hinh log/exp doc lap
    reg [7:0] exp_t [0:509];
    reg [8:0] log_t [0:255];

    function [7:0] ref_mul;
        input [7:0] x;
        input [7:0] z;
        begin
            if (x == 8'h00 || z == 8'h00) ref_mul = 8'h00;
            else ref_mul = exp_t[log_t[x] + log_t[z]];
        end
    endfunction

    integer i, j, k;
    reg [7:0] xr;
    reg [7:0] y1, y2, y3;
    reg [7:0] c;
    reg [7:0] ra, rb, rc;

    task apply;
        input [7:0] ta;
        input [7:0] tb_v;
        begin
            a = ta; b = tb_v; #1;
        end
    endtask

    initial begin
        // ---- 1. Xay bang log/exp va kiem tra alpha nguyen thuy
        xr = 8'h01;
        for (i = 0; i < 255; i = i + 1) begin
            exp_t[i] = xr;
            log_t[xr] = i;
            exp_t[i + 255] = xr;
            xr = {xr[6:0], 1'b0} ^ (xr[7] ? (`GF_PRIM_POLY & 9'hFF) : 8'h00);
            if (xr == 8'h01 && i != 254) begin
                n_err = n_err + 1;
                $display("LOI: alpha co bac %0d < 255", i + 1);
            end
        end
        n_chk = n_chk + 1;
        if (xr !== 8'h01) begin
            n_err = n_err + 1; $display("LOI: alpha^255 != 1");
        end
        for (i = 1; i < 256; i = i + 1) begin
            n_chk = n_chk + 1;
            if (exp_t[log_t[i]] !== i[7:0]) begin
                n_err = n_err + 1; $display("LOI: bang log/exp khong nhat quan tai %0h", i);
            end
        end

        // ---- 2. Day du 65536 cap
        for (i = 0; i < 256; i = i + 1)
            for (j = 0; j < 256; j = j + 1) begin
                apply(i[7:0], j[7:0]);
                n_chk = n_chk + 1;
                if (y !== ref_mul(i[7:0], j[7:0])) begin
                    n_err = n_err + 1;
                    if (n_err <= 20)
                        $display("LOI nhan: %h * %h = %h (mong doi %h)", a, b, y, ref_mul(i[7:0], j[7:0]));
                end
            end

        // ---- 3. Tinh chat dai so
        for (i = 0; i < 256; i = i + 1) begin
            apply(i[7:0], 8'h00);
            n_chk = n_chk + 1; if (y !== 8'h00) begin n_err = n_err + 1; $display("LOI: %h*0 != 0", i); end
            apply(8'h00, i[7:0]);
            n_chk = n_chk + 1; if (y !== 8'h00) begin n_err = n_err + 1; $display("LOI: 0*%h != 0", i); end
            apply(i[7:0], 8'h01);
            n_chk = n_chk + 1; if (y !== i[7:0]) begin n_err = n_err + 1; $display("LOI: %h*1 != %h", i, i); end
            apply(8'h01, i[7:0]);
            n_chk = n_chk + 1; if (y !== i[7:0]) begin n_err = n_err + 1; $display("LOI: 1*%h != %h", i, i); end
        end

        for (k = 0; k < 2000; k = k + 1) begin
            ra = $random(seed); rb = $random(seed); rc = $random(seed);
            // giao hoan
            apply(ra, rb); y1 = y;
            apply(rb, ra); y2 = y;
            n_chk = n_chk + 1;
            if (y1 !== y2) begin n_err = n_err + 1; $display("LOI giao hoan: %h,%h", ra, rb); end
            // phan phoi: a*(b^c) = a*b ^ a*c
            apply(ra, rb); y1 = y;
            apply(ra, rc); y2 = y;
            apply(ra, rb ^ rc); y3 = y;
            n_chk = n_chk + 1;
            if (y3 !== (y1 ^ y2)) begin n_err = n_err + 1; $display("LOI phan phoi: %h,%h,%h", ra, rb, rc); end
            // ket hop: (a*b)*c = a*(b*c)
            apply(ra, rb); y1 = y;
            apply(y1, rc); y1 = y;
            apply(rb, rc); y2 = y;
            apply(ra, y2); y2 = y;
            n_chk = n_chk + 1;
            if (y1 !== y2) begin n_err = n_err + 1; $display("LOI ket hop: %h,%h,%h", ra, rb, rc); end
        end

        // ---- 4. Vi du co dinh
        apply(8'h02, 8'h80);
        n_chk = n_chk + 1;
        if (y !== 8'h1D) begin n_err = n_err + 1; $display("LOI: 02*80 = %h (mong doi 1D)", y); end
        apply(8'h80, 8'h02);
        n_chk = n_chk + 1;
        if (y !== 8'h1D) begin n_err = n_err + 1; $display("LOI: 80*02 = %h (mong doi 1D)", y); end
        apply(8'h02, 8'h8E);   // 8E = nghich dao cua 02
        n_chk = n_chk + 1;
        if (y !== 8'h01) begin n_err = n_err + 1; $display("LOI: 02*8E = %h (mong doi 01)", y); end

        // ---- 5. Khong phai nhan nguyen: 0x10 * 0x10 = alpha^8 = 0x1D (khong phai 0x100)
        apply(8'h10, 8'h10);
        n_chk = n_chk + 1;
        if (y !== 8'h1D) begin n_err = n_err + 1; $display("LOI: 10*10 = %h (mong doi 1D)", y); end

        t_finish("tb_gf256_mul");
    end

    initial begin
        #200_000_000;
        $display("[FAIL] tb_gf256_mul: het thoi gian");
        $finish;
    end

endmodule

