// tb_forney.v
// Testbench cho rtl/rs_decoder/forney.v  (RS(15,11), F = 0)
//
// *** GIAO DIEN GIA DINH (file RTL hien con trong). Sua phan noi cong `dut` neu khac. ***
//
//   module forney (
//     input  clk, rst_n,
//     input  start,                    // xung 1 chu ky, chap nhan khi busy = 0; chot cac dau vao
//     input  [8*(R+1)-1:0] lambda,     // lambda[j] o [8*j +: 8]  (he so > L bang 0)
//     input  [8*R-1:0]     omega,      // omega[q] o [8*q +: 8]
//     input  [N-1:0]       err_mask,   // bit i = 1: vi tri truyen i la vi tri loi (tu Chien)
//     output busy,
//     output done,                     // xung 1 chu ky; ket qua giu den start ke tiep
//     output [8*N-1:0]     err_val,    // E_i o [8*i +: 8]; 0 tai vi tri khong co loi
//     output fail                      // Lambda'(z_i) = 0 tai mot vi tri loi (khong chia cho 0)
//   );
//
// Cong thuc (docs muc 10, F = 0, buoc so mu 1):
//   E_i = X_i * Omega(z_i) / Lambda'(z_i),  X_i = alpha^(N-1-i), z_i = X_i^-1
//   Lambda'(z) = lambda[1] + lambda[3] z^2 + ...   (dac so 2, chi so hang bac le)
// Phai nhan them X_i (khong dung cong thuc cua F = 1).
//
// Noi dung test:
//   1. Vi du docs: E_0 = 55, E_14 = A6.
//   2. Khong co vi tri loi -> err_val = 0, fail = 0.
//   3. Mot loi tai MOI vi tri x nhieu gia tri: err_val == mau loi that (doc lap voi mo hinh).
//   4. Hai loi tai moi cap (ke ca S[0] = 0, 2 gia tri bang nhau): err_val == mau loi that.
//   5. Lambda'(z_i) = 0 -> fail = 1.
//   6. Reset giua phep tinh; chay lien tiep, ket qua giu on dinh sau done.
`timescale 1ns/1ps
`include "rs_params.vh"

module tb_forney;

    `include "rs_tb_ref.vh"

    reg          clk = 1'b0;
    reg          rst_n = 1'b0;
    reg          start = 1'b0;
    reg  [8*(R+1)-1:0] lambda = {8*(R+1){1'b0}};
    reg  [8*R-1:0]     omega = {8*R{1'b0}};
    reg  [N-1:0]       err_mask = {N{1'b0}};
    wire         busy;
    wire         done;
    wire [8*N-1:0] err_val;
    wire         fail;

    forney dut (
        .clk(clk), .rst_n(rst_n), .start(start),
        .lambda(lambda), .omega(omega), .err_mask(err_mask),
        .busy(busy), .done(done), .err_val(err_val), .fail(fail)
    );

    always #10 clk = ~clk;

    integer done_cnt = 0;
    reg     pv_done = 1'b0;
    reg [8*N-1:0] val_at_done;
    reg           fail_at_done;
    always @(negedge clk) begin
        #8;
        if (rst_n && done) begin
            done_cnt = done_cnt + 1;
            val_at_done = err_val; fail_at_done = fail;
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

    task run_forney;
        input [8*(R+1)-1:0] lam;
        input [8*R-1:0]     om;
        input [N-1:0]       mk;
        integer w;
        begin
            done_cnt = 0;
            @(negedge clk); lambda = lam; omega = om; err_mask = mk; start = 1'b1;
            @(negedge clk); start = 1'b0;
            lambda = {8*(R+1){1'bx}}; omega = {8*R{1'bx}}; err_mask = {N{1'bx}};   // phai chot luc start
            w = 0;
            while (done_cnt == 0 && w < 1000) begin @(negedge clk); w = w + 1; end
            repeat (3) @(negedge clk);
            n_chk = n_chk + 3;
            if (done_cnt !== 1) begin n_err = n_err + 1; $display("LOI: done_cnt = %0d", done_cnt); end
            if (busy !== 1'b0)  begin n_err = n_err + 1; $display("LOI: busy van = 1 sau done"); end
            if (err_val !== val_at_done || fail !== fail_at_done) begin
                n_err = n_err + 1; $display("LOI: ket qua khong giu on dinh sau done");
            end
        end
    endtask

    // Day du chuoi: mau loi em -> S -> BM -> Omega -> mask -> Forney; ket qua phai bang em.
    task test_pattern;
        input [8*N-1:0] em;
        input [255:0]   tag;
        reg [8*R-1:0]     s, om;
        reg [8*(R+1)+7:0] bm;
        reg [8*(R+1)-1:0] lam;
        reg [N-1:0]       mk;
        reg [8*N-1:0]     rv;
        integer Lb, i;
        begin
            s   = r_syn(em);
            bm  = r_bm(s);
            lam = bm[8*(R+1)-1:0];
            Lb  = bm[8*(R+1) +: 8];
            om  = r_omega(s, lam, Lb);
            // mask duoc suy ra tu mau loi that (doc lap voi Chien)
            for (i = 0; i < N; i = i + 1) mk[i] = (em[8*i +: 8] != 8'h00);
            rv = r_forney(lam, om, mk);
            n_chk = n_chk + 1;
            if (rv !== em) begin
                n_err = n_err + 1; $display("REF-BUG [%0s]: mo hinh Forney %h != mau loi %h", tag, rv, em);
            end
            run_forney(lam, om, mk);
            n_chk = n_chk + 2;
            if (val_at_done !== em) begin
                n_err = n_err + 1;
                if (n_err <= 25) $display("LOI [%0s]: err_val=%h (mong doi %h)", tag, val_at_done, em);
            end
            if (fail_at_done !== 1'b0) begin
                n_err = n_err + 1; $display("LOI [%0s]: fail=1 voi mau loi hop le %h", tag, em);
            end
        end
    endtask

    // ---------------------------------------------------------- test
    integer p, q, v, t;
    reg [8*N-1:0] em;
    reg [8*(R+1)-1:0] lam;
    reg [8*R-1:0] om;
    reg [N-1:0] mk;

    initial begin
        t_selfcheck_ref(0);

        rst_n = 1'b0;
        repeat (4) @(negedge clk);
        n_chk = n_chk + 2;
        if (busy !== 1'b0 || done !== 1'b0) begin n_err = n_err + 1; $display("LOI: busy/done sau reset"); end
        rst_n = 1'b1;
        repeat (3) @(negedge clk);

        // ---- 1. Vi du docs
        if (N == 15 && R == 4) begin
            lam = {8*(R+1){1'b0}}; lam[23:0] = 24'h131201;
            om  = {8*R{1'b0}};     om[15:0]  = 16'h10F3;
            mk  = {N{1'b0}}; mk[0] = 1'b1; mk[14] = 1'b1;
            run_forney(lam, om, mk);
            n_chk = n_chk + 4;
            if (val_at_done[7:0] !== 8'h55) begin n_err = n_err + 1; $display("LOI: E0 = %h (mong doi 55)", val_at_done[7:0]); end
            if (val_at_done[8*14 +: 8] !== 8'hA6) begin n_err = n_err + 1; $display("LOI: E14 = %h (mong doi A6)", val_at_done[8*14 +: 8]); end
            if (val_at_done[8*14-1:8] !== {8*13{1'b0}}) begin n_err = n_err + 1; $display("LOI: err_val khac 0 o vi tri khong loi"); end
            if (fail_at_done !== 1'b0) begin n_err = n_err + 1; $display("LOI: fail docs"); end
        end

        // ---- 2. Khong co vi tri loi
        lam = {8*(R+1){1'b0}}; lam[7:0] = 8'h01;
        run_forney(lam, {8*R{1'b0}}, {N{1'b0}});
        n_chk = n_chk + 2;
        if (val_at_done !== {8*N{1'b0}} || fail_at_done !== 1'b0) begin
            n_err = n_err + 1; $display("LOI: khong loi: err_val=%h fail=%b", val_at_done, fail_at_done);
        end

        // ---- 3. Mot loi tai moi vi tri
        for (p = 0; p < N; p = p + 1)
            for (v = 1; v < 256; v = v + 7) begin
                em = {8*N{1'b0}}; em[8*p +: 8] = v;
                test_pattern(em, "1 loi");
            end

        // ---- 4. Hai loi tai moi cap
        for (p = 0; p < N; p = p + 1)
            for (q = p + 1; q < N; q = q + 1) begin
                for (t = 0; t < 3; t = t + 1) begin
                    em = {8*N{1'b0}};
                    em[8*p +: 8] = ($random(seed) | 8'h01);
                    em[8*q +: 8] = ($random(seed) | 8'h01);
                    if (t == 1) em[8*q +: 8] = em[8*p +: 8];    // S[0] = 0
                    test_pattern(em, "2 loi");
                end
            end

        // Bien: loi dau/cuoi/parity
        em = {8*N{1'b0}}; em[7:0] = 8'hFF; em[8*(N-1) +: 8] = 8'hFF;
        test_pattern(em, "dau+cuoi FF");
        em = {8*N{1'b0}}; em[8*(N-2) +: 8] = 8'h01; em[8*(N-1) +: 8] = 8'h80;
        test_pattern(em, "2 loi parity");

        // ---- 5. Lambda'(z_i) = 0 -> fail
        lam = {8*(R+1){1'b0}}; lam[7:0] = 8'h01;      // Lambda = 1, Lambda' = 0
        om  = {8*R{1'b0}}; om[7:0] = 8'h33;
        for (p = 0; p < N; p = p + 4) begin
            mk = {N{1'b0}}; mk[p] = 1'b1;
            run_forney(lam, om, mk);
            n_chk = n_chk + 1;
            if (fail_at_done !== 1'b1) begin
                n_err = n_err + 1; $display("LOI: Lambda'=0 tai vi tri %0d phai bao fail", p);
            end
        end
        // Lambda = 1 + c z^2 (chi so hang chan) -> Lambda' = 0
        lam = {8*(R+1){1'b0}}; lam[7:0] = 8'h01; lam[23:16] = 8'h07;
        mk = {N{1'b0}}; mk[5] = 1'b1;
        run_forney(lam, om, mk);
        n_chk = n_chk + 1;
        if (fail_at_done !== 1'b1) begin n_err = n_err + 1; $display("LOI: Lambda chi bac chan phai bao fail"); end

        // ---- 6. Ket qua hop le ngay sau fail (khong con trang thai du), reset giua phep tinh
        em = {8*N{1'b0}}; em[8*3 +: 8] = 8'h42; em[8*9 +: 8] = 8'h99;
        test_pattern(em, "sau fail");

        t_rand_err(2, em);
        lam = {8*(R+1){1'b0}}; lam[7:0] = 8'h01; lam[15:8] = 8'h12; lam[23:16] = 8'h13;
        om = {8*R{1'b0}}; om[15:0] = 16'h10F3;
        mk = {N{1'b0}}; mk[0] = 1'b1; mk[14] = 1'b1;
        @(negedge clk); lambda = lam; omega = om; err_mask = mk; start = 1'b1;
        @(negedge clk); start = 1'b0;
        do_reset;
        n_chk = n_chk + 1;
        if (busy !== 1'b0) begin n_err = n_err + 1; $display("LOI: busy != 0 sau reset giua phep tinh"); end
        t_rand_err(2, em);
        test_pattern(em, "sau reset");

        for (t = 0; t < 40; t = t + 1) begin
            t_rand_err(1 + (t % 2), em);
            test_pattern(em, "lien tiep");
        end

        t_finish("tb_forney");
    end

    initial begin
        #400_000_000;
        $display("[FAIL] tb_forney: het thoi gian");
        $finish;
    end

endmodule

