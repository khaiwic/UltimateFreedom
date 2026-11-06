// tb_chien_search.v
// Testbench cho rtl/rs_decoder/chien_search.v  (RS(15,11), F = 0)
//
// *** GIAO DIEN GIA DINH (file RTL hien con trong). Sua phan noi cong `dut` neu khac. ***
//
//   module chien_search (
//     input  clk, rst_n,
//     input  start,                    // xung 1 chu ky, chap nhan khi busy = 0; chot lambda
//     input  [8*(R+1)-1:0] lambda,     // lambda[j] o [8*j +: 8]
//     input  [3:0]         lambda_deg, // L
//     output busy,
//     output done,                     // xung 1 chu ky; ket qua giu den start ke tiep
//     output [N-1:0] err_mask,         // bit i = 1 neu Lambda(X_i^-1) = 0, X_i = alpha^(N-1-i)
//     output [3:0]   err_count,        // so nghiem tim duoc trong 0..N-1
//     output fail                      // err_count != lambda_deg  (thieu nghiem trong vung truyen)
//   );
//
// Chi tim trong N = 15 vi tri thuc su duoc truyen (docs muc 9): nghiem thuoc 240 vi tri da
// rut gon khong duoc tinh va phai dan den fail.
//
// Noi dung test:
//   1. Vi du docs: Lambda = 01 12 13 -> vi tri 0 va 14.
//   2. Khong loi: L = 0, Lambda = 1 -> mask = 0, count = 0, fail = 0.
//   3. Mot loi tai MOI vi tri: mask co dung 1 bit (doc lap, Lambda = 1 + X_i z).
//   4. Hai loi tai MOI cap vi tri: mask dung 2 bit.
//   5. Nghiem nam ngoai vung truyen (X = alpha^k, k >= N): count < L -> fail = 1.
//   6. Lambda ngau nhien L = 1..T: so voi mo hinh, fail = (count != L).
//   7. Reset giua phep tinh; chay lien tiep.
//
// Chay: vlog +incdir+../rtl/include +incdir+../tb ../rtl/gf_arithmetic/*.v \
//            ../rtl/rs_decoder/chien_search.v tb_chien_search.v
`timescale 1ns/1ps
`include "rs_params.vh"

module tb_chien_search;

    `include "rs_tb_ref.vh"

    reg          clk = 1'b0;
    reg          rst_n = 1'b0;
    reg          start = 1'b0;
    reg  [8*(R+1)-1:0] lambda = {8*(R+1){1'b0}};
    reg  [3:0]   lambda_deg = 4'd0;
    wire         busy;
    wire         done;
    wire [N-1:0] err_mask;
    wire [3:0]   err_count;
    wire         fail;

    chien_search dut (
        .clk(clk), .rst_n(rst_n), .start(start),
        .lambda(lambda), .lambda_deg(lambda_deg),
        .busy(busy), .done(done),
        .err_mask(err_mask), .err_count(err_count), .fail(fail)
    );

    always #10 clk = ~clk;

    integer done_cnt = 0;
    reg     pv_done = 1'b0;
    reg [N-1:0] mask_at_done;
    reg [3:0]   cnt_at_done;
    reg         fail_at_done;
    always @(negedge clk) begin
        #8;
        if (rst_n && done) begin
            done_cnt = done_cnt + 1;
            mask_at_done = err_mask; cnt_at_done = err_count; fail_at_done = fail;
            if (pv_done) begin n_err = n_err + 1; $display("[%0t] LOI: done keo dai > 1 chu ky", $time); end
        end
        pv_done = done && rst_n;
    end

    task do_reset;
        begin
            @(negedge clk); rst_n = 1'b0; start = 1'b0;
            repeat (3) @(negedge clk);
            rst_n = 1'b1;
            repeat (2) @(negedge clk);
        end
    endtask

    task run_chien;
        input [8*(R+1)-1:0] lam;
        input integer       L;
        integer w;
        begin
            done_cnt = 0;
            @(negedge clk); lambda = lam; lambda_deg = L; start = 1'b1;
            @(negedge clk); start = 1'b0;
            lambda = {8*(R+1){1'bx}}; lambda_deg = 4'bxxxx;      // phai chot luc start
            w = 0;
            while (done_cnt == 0 && w < 1000) begin @(negedge clk); w = w + 1; end
            repeat (3) @(negedge clk);
            n_chk = n_chk + 3;
            if (done_cnt !== 1) begin n_err = n_err + 1; $display("LOI: done_cnt = %0d", done_cnt); end
            if (busy !== 1'b0)  begin n_err = n_err + 1; $display("LOI: busy van = 1 sau done"); end
            if (err_mask !== mask_at_done || err_count !== cnt_at_done || fail !== fail_at_done) begin
                n_err = n_err + 1; $display("LOI: ket qua khong giu on dinh sau done");
            end
        end
    endtask

    // Kiem tra voi mask mong doi; count/fail suy ra tu mask va L
    task check_mask;
        input [N-1:0] exp_mask;
        input integer L;
        input [255:0] tag;
        integer ec;
        reg ef;
        begin
            ec = r_popcnt(exp_mask);
            ef = (ec != L);
            n_chk = n_chk + 3;
            if (mask_at_done !== exp_mask) begin
                n_err = n_err + 1;
                if (n_err <= 25) $display("LOI [%0s]: mask=%b (mong doi %b), L=%0d", tag, mask_at_done, exp_mask, L);
            end
            if (cnt_at_done !== ec[3:0]) begin
                n_err = n_err + 1; $display("LOI [%0s]: err_count=%0d (mong doi %0d)", tag, cnt_at_done, ec);
            end
            if (fail_at_done !== ef) begin
                n_err = n_err + 1; $display("LOI [%0s]: fail=%b (mong doi %b), mask=%b L=%0d", tag, fail_at_done, ef, exp_mask, L);
            end
        end
    endtask

    // Lambda = prod (1 + X z) cho 1 hoac 2 nghiem
    function [8*(R+1)-1:0] lam1;
        input [7:0] x;
        reg [8*(R+1)-1:0] l;
        begin
            l = {8*(R+1){1'b0}}; l[7:0] = 8'h01; l[15:8] = x;
            lam1 = l;
        end
    endfunction

    function [8*(R+1)-1:0] lam2;
        input [7:0] x1;
        input [7:0] x2;
        reg [8*(R+1)-1:0] l;
        begin
            l = {8*(R+1){1'b0}}; l[7:0] = 8'h01; l[15:8] = x1 ^ x2; l[23:16] = r_mul(x1, x2);
            lam2 = l;
        end
    endfunction

    // ---------------------------------------------------------- test
    integer p, q, k, t, L;
    reg [8*(R+1)-1:0] lam;
    reg [N-1:0] expm;

    initial begin
        t_selfcheck_ref(0);

        rst_n = 1'b0;
        repeat (4) @(negedge clk);
        n_chk = n_chk + 2;
        if (busy !== 1'b0 || done !== 1'b0) begin n_err = n_err + 1; $display("LOI: busy/done sau reset"); end
        rst_n = 1'b1;
        repeat (3) @(negedge clk);

        // ---- 1. Vi du docs: vi tri 0 va 14
        lam = {8*(R+1){1'b0}}; lam[23:0] = 24'h131201;
        run_chien(lam, 2);
        expm = {N{1'b0}}; expm[0] = 1'b1; expm[N-1] = 1'b1;
        check_mask(expm, 2, "docs");

        // ---- 2. Khong loi
        run_chien(lam1(8'h00), 0);
        check_mask({N{1'b0}}, 0, "khong loi");

        // ---- 3. Mot loi tai moi vi tri
        for (p = 0; p < N; p = p + 1) begin
            run_chien(lam1(r_pow(N - 1 - p)), 1);
            expm = {N{1'b0}}; expm[p] = 1'b1;
            check_mask(expm, 1, "1 loi");
        end

        // ---- 4. Hai loi tai moi cap
        for (p = 0; p < N; p = p + 1)
            for (q = p + 1; q < N; q = q + 1) begin
                run_chien(lam2(r_pow(N - 1 - p), r_pow(N - 1 - q)), 2);
                expm = {N{1'b0}}; expm[p] = 1'b1; expm[q] = 1'b1;
                check_mask(expm, 2, "2 loi");
            end

        // ---- 5. Nghiem ngoai vung truyen -> fail
        for (k = N; k < 255; k = k + 7) begin
            run_chien(lam1(r_pow(N - 1 - 0 + (k - N + 1))), 1);   // X = alpha^(N + j), j >= 0
            check_mask({N{1'b0}}, 1, "1 nghiem ngoai vung");
            n_chk = n_chk + 1;
            if (fail_at_done !== 1'b1) begin n_err = n_err + 1; $display("LOI: nghiem ngoai vung phai fail"); end
        end
        // Mot nghiem trong vung, mot ngoai vung
        for (p = 0; p < N; p = p + 3) begin
            run_chien(lam2(r_pow(N - 1 - p), r_pow(100)), 2);
            expm = {N{1'b0}}; expm[p] = 1'b1;
            check_mask(expm, 2, "1 trong 1 ngoai");
            n_chk = n_chk + 1;
            if (fail_at_done !== 1'b1) begin n_err = n_err + 1; $display("LOI: thieu nghiem phai fail"); end
        end
        // Hai nghiem ngoai vung
        run_chien(lam2(r_pow(50), r_pow(120)), 2);
        check_mask({N{1'b0}}, 2, "2 ngoai vung");
        n_chk = n_chk + 1;
        if (fail_at_done !== 1'b1) begin n_err = n_err + 1; $display("LOI: 2 nghiem ngoai vung phai fail"); end

        // ---- 6. Lambda ngau nhien L = 1..T, so voi mo hinh
        for (t = 0; t < 300; t = t + 1) begin
            L = 1 + (t % T);
            lam = {8*(R+1){1'b0}};
            lam[7:0] = 8'h01;
            for (p = 1; p <= L; p = p + 1) lam[8*p +: 8] = $random(seed);
            if (lam[8*L +: 8] == 8'h00) lam[8*L +: 8] = 8'h01;     // deg dung bang L
            run_chien(lam, L);
            check_mask(r_chien(lam, L), L, "ngau nhien");
        end

        // ---- 7. Reset giua phep tinh
        lam = lam2(r_pow(3), r_pow(9));
        @(negedge clk); lambda = lam; lambda_deg = 4'd2; start = 1'b1;
        @(negedge clk); start = 1'b0;
        do_reset;
        n_chk = n_chk + 1;
        if (busy !== 1'b0) begin n_err = n_err + 1; $display("LOI: busy != 0 sau reset giua phep tinh"); end
        run_chien(lam, 2);
        expm = {N{1'b0}}; expm[N-1-3] = 1'b1; expm[N-1-9] = 1'b1;
        check_mask(expm, 2, "sau reset");

        t_finish("tb_chien_search");
    end

    initial begin
        #200_000_000;
        $display("[FAIL] tb_chien_search: het thoi gian");
        $finish;
    end

endmodule

