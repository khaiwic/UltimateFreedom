// rs_tb_ref.vh
// Mo hinh tham chieu (golden model) dung chung cho cac testbench.
// KHONG phai RTL tong hop. File nay duoc `include BEN TRONG than module tb_*.
//
// Moi tham so lay tu rtl/include/rs_params.vh (RS(15,11) tren GF(256),
// p(u)=0x11D, alpha=0x02, nghiem dau F=0). Quy uoc (docs/rs_algorithm.md):
//   - Vector dong goi: symbol/he so thu i nam o bit [8*i +: 8].
//   - c[0] truyen dau tien = he so x^(N-1);  X_i = alpha^(N-1-i).
//   - lambda[j], omega[j], S[j]: he so cua z^j (bac thap truoc).
//   - Dung +incdir+../rtl/include +incdir+../tb khi bien dich.
//
// Ham/Task cung cap:
//   r_mul r_pow r_inv r_div r_gen r_encode r_syn r_bm r_omega r_chien
//   r_forney r_forney_bad r_popcnt
//   t_rand_data t_rand_err t_selfcheck_ref t_finish

`include "rs_params.vh"

localparam integer N  = `RS_N;
localparam integer K  = `RS_K;
localparam integer R  = `RS_R;
localparam integer T  = `RS_T;
localparam integer FR = `RS_FIRST_ROOT;

integer seed = 32'h1BADB002;
integer n_err = 0;
integer n_chk = 0;

// ---------------------------------------------------------------- GF(256)
// Nhan dich-va-cong (doc lap voi RTL ve cau truc code).
function [7:0] r_mul;
    input [7:0] a;
    input [7:0] b;
    reg   [8:0] x;
    reg   [7:0] acc;
    integer     i;
    begin
        x   = {1'b0, a};
        acc = 8'h00;
        for (i = 0; i < 8; i = i + 1) begin
            if (b[i]) acc = acc ^ x[7:0];
            x = x << 1;
            if (x[8]) x = x ^ `GF_PRIM_POLY;
        end
        r_mul = acc;
    end
endfunction

// alpha^e, e bat ky (am cung duoc), rut gon modulo 255
function [7:0] r_pow;
    input integer e;
    integer ee;
    integer i;
    reg [7:0] acc;
    begin
        ee = e % 255;
        if (ee < 0) ee = ee + 255;
        acc = 8'h01;
        for (i = 0; i < ee; i = i + 1)
            acc = r_mul(acc, `GF_ALPHA);
        r_pow = acc;
    end
endfunction

// a^254 = a^-1 (a != 0); a = 0 -> 0
function [7:0] r_inv;
    input [7:0] a;
    integer i;
    reg [7:0] acc;
    begin
        acc = 8'h01;
        if (a == 8'h00) acc = 8'h00;
        else for (i = 0; i < 254; i = i + 1) acc = r_mul(acc, a);
        r_inv = acc;
    end
endfunction

function [7:0] r_div;
    input [7:0] a;
    input [7:0] b;
    begin
        r_div = r_mul(a, r_inv(b));
    end
endfunction

// base^e (e >= 0)
function [7:0] r_ipow;
    input [7:0] base;
    input integer e;
    integer i;
    reg [7:0] acc;
    begin
        acc = 8'h01;
        for (i = 0; i < e; i = i + 1) acc = r_mul(acc, base);
        r_ipow = acc;
    end
endfunction

// ---------------------------------------------------------------- RS
// g(x) = prod_{j=0..R-1} (x + alpha^(FR+j)); he so x^d o [8*d +: 8]
function [8*(R+1)-1:0] r_gen;
    input integer dummy;
    reg [8*(R+1)-1:0] c;
    reg [7:0] root;
    integer j, d;
    begin
        c = {8*(R+1){1'b0}};
        c[7:0] = 8'h01;
        for (j = 0; j < R; j = j + 1) begin
            root = r_pow(FR + j);
            for (d = R; d > 0; d = d - 1)
                c[8*d +: 8] = c[8*(d-1) +: 8] ^ r_mul(c[8*d +: 8], root);
            c[7:0] = r_mul(c[7:0], root);
        end
        r_gen = c;
    end
endfunction

// Ma hoa systematic: {parity[R-1..0], data[K-1..0]} (symbol 0 o bit thap nhat)
function [8*N-1:0] r_encode;
    input [8*K-1:0] d;
    reg [8*(R+1)-1:0] g;
    reg [8*N-1:0]     w;
    reg [7:0]         fb;
    integer i, j;
    begin
        g = r_gen(0);
        w = {8*N{1'b0}};
        w[8*K-1:0] = d;
        for (i = 0; i < K; i = i + 1) begin
            fb = w[8*i +: 8];
            for (j = 0; j <= R; j = j + 1)
                w[8*(i+j) +: 8] = w[8*(i+j) +: 8] ^ r_mul(fb, g[8*(R-j) +: 8]);
        end
        r_encode = {w[8*N-1:8*K], d};
    end
endfunction

// Syndrome S[j] = y(alpha^(FR+j)), Horner theo thu tu truyen
function [8*R-1:0] r_syn;
    input [8*N-1:0] y;
    reg [8*R-1:0] s;
    reg [7:0]     beta, acc;
    integer j, i;
    begin
        s = {8*R{1'b0}};
        for (j = 0; j < R; j = j + 1) begin
            beta = r_pow(FR + j);
            acc  = 8'h00;
            for (i = 0; i < N; i = i + 1)
                acc = r_mul(acc, beta) ^ y[8*i +: 8];
            s[8*j +: 8] = acc;
        end
        r_syn = s;
    end
endfunction

// Berlekamp-Massey (docs/rs_algorithm.md muc 7).
// Tra ve {L[7:0], lambda[R..0]}; lambda[j] o [8*j +: 8], L o [8*(R+1) +: 8]
function [8*(R+1)+7:0] r_bm;
    input [8*R-1:0] s;
    reg [8*(R+1)-1:0] C, B, P;
    reg [7:0] d, bb, sc;
    integer L, q, j, shift;
    begin
        C = {8*(R+1){1'b0}};
        C[7:0] = 8'h01;
        B = C;
        L = 0; shift = 1; bb = 8'h01;
        for (q = 0; q < R; q = q + 1) begin
            d = s[8*q +: 8];
            for (j = 1; j <= L; j = j + 1)
                d = d ^ r_mul(C[8*j +: 8], s[8*(q-j) +: 8]);
            if (d == 8'h00) begin
                shift = shift + 1;
            end else begin
                P  = C;
                sc = r_div(d, bb);
                for (j = 0; j + shift <= R; j = j + 1)
                    C[8*(j+shift) +: 8] = C[8*(j+shift) +: 8] ^ r_mul(sc, B[8*j +: 8]);
                if (2*L <= q) begin
                    L = q + 1 - L;
                    B = P;
                    bb = d;
                    shift = 1;
                end else begin
                    shift = shift + 1;
                end
            end
        end
        r_bm = {L[7:0], C};
    end
endfunction

// Omega(z) = [S(z)*Lambda(z)] mod z^R ; omega[q] o [8*q +: 8]
function [8*R-1:0] r_omega;
    input [8*R-1:0]     s;
    input [8*(R+1)-1:0] lam;
    input integer       L;
    reg [8*R-1:0] om;
    reg [7:0] acc;
    integer q, j;
    begin
        om = {8*R{1'b0}};
        for (q = 0; q < R; q = q + 1) begin
            acc = 8'h00;
            for (j = 0; j <= q && j <= L; j = j + 1)
                acc = acc ^ r_mul(lam[8*j +: 8], s[8*(q-j) +: 8]);
            om[8*q +: 8] = acc;
        end
        r_omega = om;
    end
endfunction

// Chien: mask[i] = 1 neu Lambda(X_i^-1) = 0, X_i = alpha^(N-1-i)
function [N-1:0] r_chien;
    input [8*(R+1)-1:0] lam;
    input integer       L;
    reg [N-1:0] m;
    reg [7:0] z, v;
    integer i, j;
    begin
        m = {N{1'b0}};
        for (i = 0; i < N; i = i + 1) begin
            z = r_inv(r_pow(N - 1 - i));
            v = 8'h00;
            for (j = L; j >= 0; j = j - 1)
                v = r_mul(v, z) ^ lam[8*j +: 8];
            m[i] = (v == 8'h00);
        end
        r_chien = m;
    end
endfunction

// Lambda'(z) trong dac so 2: chi cac so hang bac le
function [7:0] r_lamd;
    input [8*(R+1)-1:0] lam;
    input [7:0]         z;
    reg [7:0] dv;
    integer j;
    begin
        dv = 8'h00;
        for (j = 1; j <= R; j = j + 2)
            dv = dv ^ r_mul(lam[8*j +: 8], r_ipow(z, j - 1));
        r_lamd = dv;
    end
endfunction

// Forney: E_i = X_i * Omega(z_i) / Lambda'(z_i) (F = 0). 0 neu khong phai vi tri loi.
function [8*N-1:0] r_forney;
    input [8*(R+1)-1:0] lam;
    input [8*R-1:0]     om;
    input [N-1:0]       mask;
    reg [8*N-1:0] ev;
    reg [7:0] x, z, ov, dv;
    integer i, j;
    begin
        ev = {8*N{1'b0}};
        for (i = 0; i < N; i = i + 1) begin
            if (mask[i]) begin
                x  = r_pow(N - 1 - i);
                z  = r_inv(x);
                ov = 8'h00;
                for (j = R - 1; j >= 0; j = j - 1)
                    ov = r_mul(ov, z) ^ om[8*j +: 8];
                dv = r_lamd(lam, z);
                if (dv != 8'h00)
                    ev[8*i +: 8] = r_mul(x, r_div(ov, dv));
            end
        end
        r_forney = ev;
    end
endfunction

// 1 neu co vi tri trong mask co Lambda'(z_i) = 0 (Forney phai bao fail)
function r_forney_bad;
    input [8*(R+1)-1:0] lam;
    input [N-1:0]       mask;
    integer i;
    reg bad;
    begin
        bad = 1'b0;
        for (i = 0; i < N; i = i + 1)
            if (mask[i] && r_lamd(lam, r_inv(r_pow(N - 1 - i))) == 8'h00)
                bad = 1'b1;
        r_forney_bad = bad;
    end
endfunction

function integer r_popcnt;
    input [N-1:0] m;
    integer i, c;
    begin
        c = 0;
        for (i = 0; i < N; i = i + 1) if (m[i]) c = c + 1;
        r_popcnt = c;
    end
endfunction

// ---------------------------------------------------------------- tasks
task t_rand_data;
    output [8*K-1:0] d;
    integer i;
    begin
        for (i = 0; i < K; i = i + 1)
            d[8*i +: 8] = $random(seed);
    end
endtask

// Mau loi ngau nhien: nerr symbol phan biet, gia tri khac 0
task t_rand_err;
    input  integer nerr;
    output [8*N-1:0] em;
    integer c, p;
    reg [7:0] v;
    reg [N-1:0] used;
    begin
        em = {8*N{1'b0}};
        used = {N{1'b0}};
        c = 0;
        while (c < nerr) begin
            p = {$random(seed)} % N;
            if (!used[p]) begin
                used[p] = 1'b1;
                v = $random(seed);
                if (v == 8'h00) v = 8'h01;
                em[8*p +: 8] = v;
                c = c + 1;
            end
        end
    end
endtask

// Kiem tra chinh mo hinh tham chieu bang vi du so trong docs/rs_algorithm.md muc 12
// (chi ap dung khi RS(15,11), F = 0).
task t_selfcheck_ref;
    input integer dummy;
    reg [8*K-1:0] d;
    reg [8*N-1:0] cw, y;
    reg [8*R-1:0] s, om;
    reg [8*(R+1)+7:0] bm;
    reg [8*(R+1)-1:0] lam;
    reg [N-1:0] mk;
    reg [8*N-1:0] ev;
    integer j;
    begin
        if (N == 15 && K == 11 && FR == 0 && `GF_PRIM_POLY == 9'h11D) begin
            for (j = 0; j < K; j = j + 1) d[8*j +: 8] = j;
            cw = r_encode(d);
            n_chk = n_chk + 1;
            if (cw[8*K +: 32] !== 32'h6C288FC0) begin
                n_err = n_err + 1; $display("REF-BUG: parity=%h (mong doi 6C288FC0)", cw[8*K +: 32]);
            end
            y = cw;
            y[8*0 +: 8]  = y[8*0 +: 8]  ^ 8'h55;
            y[8*14 +: 8] = y[8*14 +: 8] ^ 8'hA6;
            s = r_syn(y);
            n_chk = n_chk + 1;
            if (s !== 32'h240D60F3) begin
                n_err = n_err + 1; $display("REF-BUG: S=%h (mong doi 240D60F3)", s);
            end
            bm  = r_bm(s);
            lam = bm[8*(R+1)-1:0];
            n_chk = n_chk + 1;
            if (bm[8*(R+1) +: 8] !== 8'd2 || lam[23:0] !== 24'h131201) begin
                n_err = n_err + 1; $display("REF-BUG: L=%0d lambda=%h (mong doi L=2, 131201)", bm[8*(R+1) +: 8], lam);
            end
            om = r_omega(s, lam, 2);
            n_chk = n_chk + 1;
            if (om[15:0] !== 16'h10F3 || om[31:16] !== 16'h0000) begin
                n_err = n_err + 1; $display("REF-BUG: omega=%h (mong doi 000010F3)", om);
            end
            mk = r_chien(lam, 2);
            n_chk = n_chk + 1;
            if (mk !== ((15'h1 << 0) | (15'h1 << 14))) begin
                n_err = n_err + 1; $display("REF-BUG: chien mask=%b", mk);
            end
            ev = r_forney(lam, om, mk);
            n_chk = n_chk + 1;
            if (ev[7:0] !== 8'h55 || ev[8*14 +: 8] !== 8'hA6) begin
                n_err = n_err + 1; $display("REF-BUG: forney E0=%h E14=%h", ev[7:0], ev[8*14 +: 8]);
            end
        end
    end
endtask

task t_finish;
    input [8*24-1:0] name;
    begin
        $display("------------------------------------------------------------");
        if (n_err == 0)
            $display("[PASS] %0s : %0d kiem tra, 0 loi", name, n_chk);
        else
            $display("[FAIL] %0s : %0d kiem tra, %0d loi", name, n_chk, n_err);
        $display("------------------------------------------------------------");
        $finish;
    end
endtask

