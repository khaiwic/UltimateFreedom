// tb_berlekamp_massey.v
// Testbench cho rtl/rs_decoder/berlekamp_massey.v  (RS(15,11), T = 2)
//
// *** GIAO DIEN GIA DINH (file RTL hien con trong). Sua phan noi cong `dut` neu khac. ***
//
//   module berlekamp_massey (
//     input  clk, rst_n,
//     input  start,                   // xung 1 chu ky, chap nhan khi busy = 0; chot `syn` luc nay
//     input  [8*R-1:0] syn,           // S[j] o [8*j +: 8]
//     output busy,
//     output done,                    // xung 1 chu ky; cac dau ra duoi giu den start ke tiep
//     output [8*(R+1)-1:0] lambda,    // lambda[j] (he so z^j, bac thap truoc) o [8*j +: 8]
//     output [3:0] lambda_deg,        // L
//     output fail                     // S != 0 va (L = 0 hoac L > T)  (docs muc 7)
//   );
//
// Noi dung test (docs/rs_algorithm.md muc 7):
//   1. Vi du docs: S = [F3,60,0D,24] -> L = 2, Lambda = 01 + 12 z + 13 z^2.
//   2. S = 0 -> L = 0, Lambda = 1, fail = 0.
//   3. Mot loi tai MOI vi tri x nhieu gia tri: L = 1, Lambda = 1 + X_i z (doc lap voi mo hinh).
//   4. Hai loi tai MOI cap vi tri: L = 2, lambda1 = X1+X2, lambda2 = X1*X2 (doc lap).
//   5. Ba/bon loi: so voi mo hinh BM tham chieu; fail dung khi L = 0 hoac L > T.
//   6. Syndrome khac 0 ngau nhien bat ky.
//   7. Cac lan chay lien tiep, ket qua giu on dinh sau done, reset giua phep tinh.
//
// Chay: vlog +incdir+../rtl/include +incdir+../tb ../rtl/gf_arithmetic/*.v \
//            ../rtl/rs_decoder/berlekamp_massey.v tb_berlekamp_massey.v
`timescale 1ns/1ps
`include "rs_params.vh"

module tb_berlekamp_massey;

    `include "rs_tb_ref.vh"

    reg          clk = 1'b0;
    reg          rst_n = 1'b0;
    reg          start = 1'b0;
    reg  [8*R-1:0] syn = {8*R{1'b0}};
    wire         busy;
    wire         done;
    wire [8*(R+1)-1:0] lambda;
    wire [3:0]   lambda_deg;
    wire         fail;

    berlekamp_massey dut (
        .clk(clk), .rst_n(rst_n), .start(start), .syn(syn),
        .busy(busy), .done(done),
        .lambda(lambda), .lambda_deg(lambda_deg), .fail(fail)
    );

    always #10 clk = ~clk;

    integer done_cnt = 0;
    reg     pv_done = 1'b0;
    reg [8*(R+1)-1:0] lam_at_done;
    reg [3:0]         deg_at_done;
    reg               fail_at_done;
    always @(negedge clk) begin
        #8;
        if (rst_n && done) begin
            done_cnt = done_cnt + 1;
            lam_at_done = lambda; deg_at_done = lambda_deg; fail_at_done = fail;
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

    // Chay mot phep tinh; tra ket qua vao lam_at_done/deg_at_done/fail_at_done
    task run_bm;
        input [8*R-1:0] s;
        integer w;
        begin
            done_cnt = 0;
            @(negedge clk); syn = s; start = 1'b1;
            @(negedge clk); start = 1'b0;
            syn = {8*R{1'bx}};              // `syn` phai duoc chot luc start
            w = 0;
            while (done_cnt == 0 && w < 500) begin @(negedge clk); w = w + 1; end
            repeat (3) @(negedge clk);
            n_chk = n_chk + 3;
            if (done_cnt !== 1) begin n_err = n_err + 1; $display("LOI: done_cnt = %0d (S=%h)", done_cnt, s); end
            if (busy !== 1'b0)  begin n_err = n_err + 1; $display("LOI: busy van = 1 sau done"); end
            if (lambda !== lam_at_done || lambda_deg !== deg_at_done || fail !== fail_at_done) begin
                n_err = n_err + 1; $display("LOI: ket qua khong giu on dinh sau done");
            end
        end
    endtask

    // So voi mo hinh tham chieu. Khi fail mong doi = 1 chi kiem tra co fail.
    task check_vs_ref;
        input [8*R-1:0] s;
        input [255:0]   tag;
        reg [8*(R+1)+7:0] rb;
        reg [8*(R+1)-1:0] rl;
        integer rL, j;
        reg exp_fail;
        begin
            rb = r_bm(s);
            rl = rb[8*(R+1)-1:0];
            rL = rb[8*(R+1) +: 8];
            exp_fail = (s != {8*R{1'b0}}) && (rL == 0 || rL > T);
            n_chk = n_chk + 1;
            if (fail_at_done !== exp_fail) begin
                n_err = n_err + 1;
                $display("LOI [%0s]: S=%h fail=%b (mong doi %b, L tham chieu = %0d)", tag, s, fail_at_done, exp_fail, rL);
            end
            if (!exp_fail) begin
                n_chk = n_chk + 1;
                if (deg_at_done !== rL[3:0]) begin
                    n_err = n_err + 1; $display("LOI [%0s]: S=%h L=%0d (mong doi %0d)", tag, s, deg_at_done, rL);
                end
                for (j = 0; j <= rL; j = j + 1) begin
                    n_chk = n_chk + 1;
                    if (lam_at_done[8*j +: 8] !== rl[8*j +: 8]) begin
                        n_err = n_err + 1;
                        if (n_err <= 25)
                            $display("LOI [%0s]: S=%h lambda[%0d]=%h (mong doi %h)", tag, s, j, lam_at_done[8*j +: 8], rl[8*j +: 8]);
                    end
                end
            end
        end
    endtask

    // ---------------------------------------------------------- test
    integer p, q, v, t;
    reg [8*N-1:0] em;
    reg [7:0] x1, x2;
    reg [8*R-1:0] s;

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
            run_bm(32'h240D60F3);
            n_chk = n_chk + 3;
            if (deg_at_done !== 4'd2) begin n_err = n_err + 1; $display("LOI: L docs = %0d (mong doi 2)", deg_at_done); end
            if (lam_at_done[23:0] !== 24'h131201) begin
                n_err = n_err + 1; $display("LOI: Lambda docs = %h (mong doi 13 12 01)", lam_at_done[23:0]);
            end
            if (fail_at_done !== 1'b0) begin n_err = n_err + 1; $display("LOI: fail docs"); end
        end

        // ---- 2. S = 0
        run_bm({8*R{1'b0}});
        n_chk = n_chk + 3;
        if (deg_at_done !== 4'd0 || lam_at_done[7:0] !== 8'h01 || fail_at_done !== 1'b0) begin
            n_err = n_err + 1; $display("LOI: S=0 phai cho L=0, lambda0=1, fail=0 (L=%0d l0=%h fail=%b)",
                                        deg_at_done, lam_at_done[7:0], fail_at_done);
        end

        // ---- 3. Mot loi (doc lap): Lambda = 1 + X_i z
        for (p = 0; p < N; p = p + 1)
            for (v = 1; v < 256; v = v + 11) begin
                em = {8*N{1'b0}}; em[8*p +: 8] = v;
                s = r_syn(em);
                run_bm(s);
                x1 = r_pow(N - 1 - p);
                n_chk = n_chk + 4;
                if (deg_at_done !== 4'd1 || fail_at_done !== 1'b0) begin
                    n_err = n_err + 1; $display("LOI 1 loi: pos=%0d val=%h L=%0d fail=%b", p, v[7:0], deg_at_done, fail_at_done);
                end
                if (lam_at_done[7:0] !== 8'h01 || lam_at_done[15:8] !== x1) begin
                    n_err = n_err + 1; $display("LOI 1 loi: pos=%0d Lambda=%h (mong doi 1 + %h z)", p, lam_at_done[15:0], x1);
                end
                if (lam_at_done[8*(R+1)-1:16] !== {8*(R-1){1'b0}}) begin
                    n_err = n_err + 1; $display("LOI 1 loi: he so bac cao khac 0");
                end
            end

        // ---- 4. Hai loi tai moi cap (doc lap)
        for (p = 0; p < N; p = p + 1)
            for (q = p + 1; q < N; q = q + 1)
                for (t = 0; t < 4; t = t + 1) begin
                    em = {8*N{1'b0}};
                    em[8*p +: 8] = ($random(seed) | 8'h01);
                    em[8*q +: 8] = ($random(seed) | 8'h01);
                    if (t == 1) em[8*q +: 8] = em[8*p +: 8];   // S[0] = 0
                    s = r_syn(em);
                    run_bm(s);
                    x1 = r_pow(N - 1 - p);
                    x2 = r_pow(N - 1 - q);
                    n_chk = n_chk + 4;
                    if (deg_at_done !== 4'd2 || fail_at_done !== 1'b0) begin
                        n_err = n_err + 1; $display("LOI 2 loi: pos=%0d,%0d L=%0d fail=%b", p, q, deg_at_done, fail_at_done);
                    end
                    if (lam_at_done[7:0] !== 8'h01) begin
                        n_err = n_err + 1; $display("LOI 2 loi: lambda0 = %h", lam_at_done[7:0]);
                    end
                    if (lam_at_done[15:8] !== (x1 ^ x2)) begin
                        n_err = n_err + 1; $display("LOI 2 loi: pos=%0d,%0d lambda1=%h (mong doi %h)", p, q, lam_at_done[15:8], x1 ^ x2);
                    end
                    if (lam_at_done[23:16] !== r_mul(x1, x2)) begin
                        n_err = n_err + 1; $display("LOI 2 loi: pos=%0d,%0d lambda2=%h (mong doi %h)", p, q, lam_at_done[23:16], r_mul(x1, x2));
                    end
                    check_vs_ref(s, "2 loi vs ref");
                end

        // ---- 5. Ba va bon loi (> T): so voi mo hinh tham chieu
        for (t = 0; t < 150; t = t + 1) begin
            t_rand_err(3 + (t % (R - 2)), em);
            s = r_syn(em);
            run_bm(s);
            check_vs_ref(s, "> T loi");
        end

        // ---- 6. Syndrome ngau nhien
        for (t = 0; t < 200; t = t + 1) begin
            for (p = 0; p < R; p = p + 1) s[8*p +: 8] = $random(seed);
            run_bm(s);
            check_vs_ref(s, "S ngau nhien");
        end
        // Syndrome chi S[0] != 0 (cac S khac = 0): khong phai chuoi hop le cua <= T loi
        s = {8*R{1'b0}}; s[7:0] = 8'h5A;
        run_bm(s); check_vs_ref(s, "chi S0");

        // ---- 7. Reset giua phep tinh
        t_rand_err(2, em); s = r_syn(em);
        @(negedge clk); syn = s; start = 1'b1;
        @(negedge clk); start = 1'b0;
        do_reset;
        n_chk = n_chk + 1;
        if (busy !== 1'b0) begin n_err = n_err + 1; $display("LOI: busy != 0 sau reset giua phep tinh"); end
        run_bm(s);
        check_vs_ref(s, "sau reset");

        // lien tiep
        for (t = 0; t < 6; t = t + 1) begin
            t_rand_err(1 + (t % 2), em); s = r_syn(em);
            run_bm(s); check_vs_ref(s, "lien tiep");
        end

        t_finish("tb_berlekamp_massey");
    end

    initial begin
        #400_000_000;
        $display("[FAIL] tb_berlekamp_massey: het thoi gian");
        $finish;
    end

endmodule

