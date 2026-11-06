// tb_error_evaluator.v
// Testbench cho rtl/rs_decoder/error_evaluator.v  (RS(15,11), F = 0)
//
// *** GIAO DIEN GIA DINH (file RTL hien con trong). Sua phan noi cong `dut` neu khac. ***
//
//   module error_evaluator (
//     input  clk, rst_n,
//     input  start,                    // xung 1 chu ky, chap nhan khi busy = 0; chot cac dau vao
//     input  [8*R-1:0]     syn,        // S[j] o [8*j +: 8]
//     input  [8*(R+1)-1:0] lambda,     // lambda[j] o [8*j +: 8]
//     input  [3:0]         lambda_deg, // L
//     output busy,
//     output done,                     // xung 1 chu ky; omega giu den start ke tiep
//     output [8*R-1:0]     omega       // omega[q] o [8*q +: 8]
//   );
//
// Cong thuc (docs muc 8):  Omega(z) = [S(z) * Lambda(z)] mod z^R,
//   omega[q] = XOR_{j=0..min(q,L)} lambda[j] * S[q-j],  q = 0..R-1
//
// Noi dung test:
//   1. Vi du docs: S = [F3,60,0D,24], Lambda = 01 12 13 -> Omega = [F3, 10, 00, 00].
//   2. Khong loi (S = 0, L = 0) -> Omega = 0.
//   3. Mot loi tai MOI vi tri: Omega = [E, 0, 0, 0] (F = 0) -- doc lap voi mo hinh.
//   4. Hai loi tai moi cap: deg(Omega) < L, omega[L..R-1] = 0, doi chieu mo hinh.
//   5. Lambda/S ngau nhien voi L = 0..R (chi he so j <= L co nghia): kiem tra phep nhan da thuc.
//   6. Reset giua phep tinh va chay lien tiep.
//
`timescale 1ns/1ps
`include "rs_params.vh"

module tb_error_evaluator;

    `include "rs_tb_ref.vh"

    reg          clk = 1'b0;
    reg          rst_n = 1'b0;
    reg          start = 1'b0;
    reg  [8*R-1:0]     syn = {8*R{1'b0}};
    reg  [8*(R+1)-1:0] lambda = {8*(R+1){1'b0}};
    reg  [3:0]   lambda_deg = 4'd0;
    wire         busy;
    wire         done;
    wire [8*R-1:0] omega;

    error_evaluator dut (
        .clk(clk), .rst_n(rst_n), .start(start),
        .syn(syn), .lambda(lambda), .lambda_deg(lambda_deg),
        .busy(busy), .done(done), .omega(omega)
    );

    always #10 clk = ~clk;

    integer done_cnt = 0;
    reg     pv_done = 1'b0;
    reg [8*R-1:0] om_at_done;
    always @(negedge clk) begin
        #8;
        if (rst_n && done) begin
            done_cnt = done_cnt + 1;
            om_at_done = omega;
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

    task run_eval;
        input [8*R-1:0]     s;
        input [8*(R+1)-1:0] lam;
        input integer       L;
        integer w;
        begin
            done_cnt = 0;
            @(negedge clk); syn = s; lambda = lam; lambda_deg = L; start = 1'b1;
            @(negedge clk); start = 1'b0;
            syn = {8*R{1'bx}}; lambda = {8*(R+1){1'bx}}; lambda_deg = 4'bxxxx;   // phai chot luc start
            w = 0;
            while (done_cnt == 0 && w < 500) begin @(negedge clk); w = w + 1; end
            repeat (3) @(negedge clk);
            n_chk = n_chk + 3;
            if (done_cnt !== 1) begin n_err = n_err + 1; $display("LOI: done_cnt = %0d", done_cnt); end
            if (busy !== 1'b0)  begin n_err = n_err + 1; $display("LOI: busy van = 1 sau done"); end
            if (omega !== om_at_done) begin n_err = n_err + 1; $display("LOI: omega khong giu on dinh sau done"); end
        end
    endtask

    task check_omega;
        input [8*R-1:0]     s;
        input [8*(R+1)-1:0] lam;
        input integer       L;
        input [255:0]       tag;
        reg [8*R-1:0] exp;
        begin
            exp = r_omega(s, lam, L);
            n_chk = n_chk + 1;
            if (om_at_done !== exp) begin
                n_err = n_err + 1;
                if (n_err <= 25)
                    $display("LOI [%0s]: S=%h Lambda=%h L=%0d Omega=%h (mong doi %h)", tag, s, lam, L, om_at_done, exp);
            end
        end
    endtask

    // ---------------------------------------------------------- test
    integer p, q, v, t, L;
    reg [8*N-1:0] em;
    reg [8*R-1:0] s, exp_om;
    reg [8*(R+1)+7:0] bm;
    reg [8*(R+1)-1:0] lam;
    integer Lb, j;

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
            run_eval(32'h240D60F3, lam, 2);
            n_chk = n_chk + 1;
            if (om_at_done !== 32'h000010F3) begin
                n_err = n_err + 1; $display("LOI: Omega docs = %h (mong doi 00 00 10 F3)", om_at_done);
            end
        end

        // ---- 2. Khong loi
        lam = {8*(R+1){1'b0}}; lam[7:0] = 8'h01;
        run_eval({8*R{1'b0}}, lam, 0);
        n_chk = n_chk + 1;
        if (om_at_done !== {8*R{1'b0}}) begin n_err = n_err + 1; $display("LOI: S=0 phai cho Omega=0"); end

        // ---- 3. Mot loi tai moi vi tri: Omega = E (F = 0)
        for (p = 0; p < N; p = p + 1)
            for (v = 1; v < 256; v = v + 23) begin
                em = {8*N{1'b0}}; em[8*p +: 8] = v;
                s = r_syn(em);
                lam = {8*(R+1){1'b0}}; lam[7:0] = 8'h01; lam[15:8] = r_pow(N - 1 - p);
                run_eval(s, lam, 1);
                exp_om = {8*R{1'b0}}; exp_om[7:0] = v;
                n_chk = n_chk + 1;
                if (om_at_done !== exp_om) begin
                    n_err = n_err + 1; $display("LOI 1 loi: pos=%0d E=%h Omega=%h (mong doi %h)", p, v[7:0], om_at_done, exp_om);
                end
            end

        // ---- 4. Hai loi: Lambda = (1+X1 z)(1+X2 z)
        for (p = 0; p < N; p = p + 1)
            for (q = p + 1; q < N; q = q + 1) begin
                em = {8*N{1'b0}};
                em[8*p +: 8] = ($random(seed) | 8'h01);
                em[8*q +: 8] = ($random(seed) | 8'h01);
                s = r_syn(em);
                lam = {8*(R+1){1'b0}};
                lam[7:0]   = 8'h01;
                lam[15:8]  = r_pow(N - 1 - p) ^ r_pow(N - 1 - q);
                lam[23:16] = r_mul(r_pow(N - 1 - p), r_pow(N - 1 - q));
                run_eval(s, lam, 2);
                check_omega(s, lam, 2, "2 loi");
                // Omega(z) = sum_i E_i * prod_{k != i}(1 + X_k z)  (F = 0): bac < L
                n_chk = n_chk + 1;
                if (om_at_done[8*R-1:16] !== {8*(R-2){1'b0}}) begin
                    n_err = n_err + 1; $display("LOI 2 loi: omega[2..] != 0 (Omega=%h)", om_at_done);
                end
                // omega[0] = E1 + E2 (omega[1] = E1*X2 + E2*X1 duoc kiem tra qua mo hinh o tren)
                n_chk = n_chk + 1;
                if (om_at_done[7:0] !== (em[8*p +: 8] ^ em[8*q +: 8])) begin
                    n_err = n_err + 1; $display("LOI 2 loi: omega[0]=%h (mong doi E1^E2=%h)", om_at_done[7:0], em[8*p +: 8] ^ em[8*q +: 8]);
                end
            end

        // ---- 4b. Lambda tu BM (> T loi cung chay dung phep nhan da thuc)
        for (t = 0; t < 100; t = t + 1) begin
            t_rand_err(1 + (t % 4), em);
            s = r_syn(em);
            bm = r_bm(s);
            lam = bm[8*(R+1)-1:0];
            Lb = bm[8*(R+1) +: 8];
            for (j = Lb + 1; j <= R; j = j + 1) lam[8*j +: 8] = 8'h00;
            run_eval(s, lam, Lb);
            check_omega(s, lam, Lb, "Lambda tu BM");
        end

        // ---- 5. Ngau nhien, L = 0..R
        for (t = 0; t < 300; t = t + 1) begin
            for (p = 0; p < R; p = p + 1) s[8*p +: 8] = $random(seed);
            L = t % (R + 1);
            lam = {8*(R+1){1'b0}};
            for (p = 0; p <= L; p = p + 1) lam[8*p +: 8] = $random(seed);
            lam[7:0] = 8'h01;
            run_eval(s, lam, L);
            check_omega(s, lam, L, "ngau nhien");
        end

        // ---- 6. Reset giua phep tinh, roi chay lai
        t_rand_err(2, em); s = r_syn(em);
        lam = {8*(R+1){1'b0}}; lam[7:0] = 8'h01; lam[15:8] = 8'h12; lam[23:16] = 8'h13;
        @(negedge clk); syn = s; lambda = lam; lambda_deg = 4'd2; start = 1'b1;
        @(negedge clk); start = 1'b0;
        do_reset;
        n_chk = n_chk + 1;
        if (busy !== 1'b0) begin n_err = n_err + 1; $display("LOI: busy != 0 sau reset giua phep tinh"); end
        run_eval(s, lam, 2);
        check_omega(s, lam, 2, "sau reset");

        t_finish("tb_error_evaluator");
    end

    initial begin
        #200_000_000;
        $display("[FAIL] tb_error_evaluator: het thoi gian");
        $finish;
    end

endmodule
