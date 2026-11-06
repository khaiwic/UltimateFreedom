`timescale 1ns/1ps
`include "rs_params.vh"

module tb_rs_decoder;

    `include "rs_tb_ref.vh"

    reg        clk = 1'b0;
    reg        rst_n = 1'b0;
    reg        start = 1'b0;
    reg  [7:0] data_in = 8'h00;
    reg        in_valid = 1'b0;
    wire       in_ready;
    wire [7:0] data_out;
    wire       out_valid;
    reg        out_ready = 1'b1;
    wire       out_last;
    wire       busy;
    wire       done;
    wire       fail;

    rs_decoder dut (
        .clk(clk), .rst_n(rst_n), .start(start),
        .data_in(data_in), .in_valid(in_valid), .in_ready(in_ready),
        .data_out(data_out), .out_valid(out_valid), .out_ready(out_ready),
        .out_last(out_last), .busy(busy), .done(done), .fail(fail)
    );

    always #10 clk = ~clk;

    // ------------------------------------------------------------ back-pressure
    integer bp_mode = 0;
    integer cyc = 0;
    always @(negedge clk) begin
        cyc = cyc + 1;
        case (bp_mode)
            0: out_ready = 1'b1;
            1: out_ready = $random(seed);
            default: out_ready = ((cyc % 50) >= 40);
        endcase
    end

    // ------------------------------------------------------------ scoreboard
    reg [8*N-1:0] got;
    integer       ocnt = 0;
    integer       done_cnt = 0;
    reg           fail_at_done = 1'b0;
    reg           pv_valid = 1'b0, pv_ready = 1'b0, pv_done = 1'b0;
    reg [7:0]     pv_data = 8'h00;

    task clear_sb;
        begin
            got = {8*N{1'b0}}; ocnt = 0; done_cnt = 0; fail_at_done = 1'b0;
        end
    endtask

    always @(negedge clk) begin
        #8;
        if (rst_n) begin
            if (pv_valid && !pv_ready && !(out_valid && data_out === pv_data)) begin
                n_err = n_err + 1; $display("[%0t] LOI: data_out/out_valid khong giu on dinh khi out_ready=0", $time);
            end
            if (out_valid && out_ready) begin
                if (ocnt < N) got[8*ocnt +: 8] = data_out;
                if (out_last !== (ocnt == N - 1)) begin
                    n_err = n_err + 1; $display("[%0t] LOI: out_last=%b o symbol %0d", $time, out_last, ocnt);
                end
                ocnt = ocnt + 1;
            end
            if (done) begin
                done_cnt = done_cnt + 1;
                fail_at_done = fail;
                if (pv_done) begin n_err = n_err + 1; $display("[%0t] LOI: done keo dai > 1 chu ky", $time); end
            end
            if (in_ready && !busy) begin
                n_err = n_err + 1; $display("[%0t] LOI: in_ready=1 khi busy=0", $time);
            end
            if (^{in_ready, out_valid, busy, done} === 1'bx) begin
                n_err = n_err + 1; $display("[%0t] LOI: dieu khien X", $time);
            end
        end
        pv_valid = out_valid && rst_n;
        pv_ready = out_ready;
        pv_data  = data_out;
        pv_done  = done && rst_n;
    end

    // ------------------------------------------------------------ driver
    reg abort_send = 1'b0;

    task do_reset;
        begin
            @(negedge clk); rst_n = 1'b0; start = 1'b0; in_valid = 1'b0;
            repeat (3) @(negedge clk);
            rst_n = 1'b1;
            repeat (2) @(negedge clk);
        end
    endtask

    task send_word;
        input [8*N-1:0] y;
        input integer   gapmode;
        integer i;
        reg hold, fire;
        begin
            @(negedge clk); start = 1'b1;
            @(negedge clk); start = 1'b0;
            i = 0; hold = 1'b0;
            while (i < N && !abort_send) begin
                @(negedge clk);
                if (!hold && gapmode != 0 && ({$random(seed)} % 3) == 0) begin
                    in_valid = 1'b0; data_in = $random(seed);
                end else begin
                    in_valid = 1'b1; data_in = y[8*i +: 8]; hold = 1'b1;
                end
                #8;
                fire = in_valid && in_ready;
                if (fire) begin i = i + 1; hold = 1'b0; end
            end
            @(negedge clk); in_valid = 1'b0; data_in = 8'h00;
        end
    endtask

    task wait_done;
        integer w;
        begin
            w = 0;
            while (done_cnt == 0 && w < 6000) begin @(negedge clk); w = w + 1; end
            repeat (6) @(negedge clk);
        end
    endtask

    // Thong ke ket qua cho truong hop vuot gioi han
    integer st_fail = 0, st_miscorrect = 0, st_recovered = 0;

    // Giai ma khoi y (tu ma goc cw); nerr = so loi that su da chen
    task decode_check;
        input [8*N-1:0] cw;
        input [8*N-1:0] y;
        input integer   nerr;
        input integer   gapmode;
        input integer   bpm;
        input [255:0]   tag;
        begin
            bp_mode = bpm;
            clear_sb;
            send_word(y, gapmode);
            wait_done;
            n_chk = n_chk + 4;
            if (done_cnt !== 1) begin
                n_err = n_err + 1; $display("LOI [%0s]: so xung done = %0d (mong doi 1)", tag, done_cnt);
            end
            if (ocnt !== N) begin
                n_err = n_err + 1; $display("LOI [%0s]: so symbol dau ra = %0d (mong doi %0d)", tag, ocnt, N);
            end
            if (busy !== 1'b0) begin
                n_err = n_err + 1; $display("LOI [%0s]: busy van = 1 sau done", tag);
            end
            if (nerr <= T) begin
                // Trong gioi han: phai sua dung, khong fail
                n_chk = n_chk + 2;
                if (fail_at_done !== 1'b0) begin
                    n_err = n_err + 1; $display("LOI [%0s]: fail=1 voi %0d loi (<= T). y=%h", tag, nerr, y);
                end
                if (got !== cw) begin
                    n_err = n_err + 1;
                    if (n_err <= 25) $display("LOI [%0s]: %0d loi, dau ra %h (mong doi %h), y=%h", tag, nerr, got, cw, y);
                end
                if (got[8*K-1:0] !== cw[8*K-1:0]) begin
                    n_chk = n_chk + 1; n_err = n_err + 1; $display("LOI [%0s]: K byte du lieu khoi phuc sai", tag);
                end
            end else begin
                // Vuot gioi han: ghi nhan, khong yeu cau fail
                if (fail_at_done === 1'b1) begin
                    st_fail = st_fail + 1;
                end else begin
                    n_chk = n_chk + 1;
                    if (r_syn(got) !== {8*R{1'b0}}) begin
                        n_err = n_err + 1;
                        $display("LOI [%0s]: fail=0 nhung dau ra khong phai tu ma hop le (syndrome != 0). y=%h", tag, y);
                    end else if (got === cw) begin
                        st_recovered = st_recovered + 1;
                    end else begin
                        st_miscorrect = st_miscorrect + 1;
                    end
                end
            end
        end
    endtask

    // ------------------------------------------------------------ test
    integer p, q, v, t, nb;
    reg [8*K-1:0] d;
    reg [8*N-1:0] cw, y, em;
    integer idle_acc;

    initial begin
        t_selfcheck_ref(0);

        // ---- Reset
        rst_n = 1'b0;
        repeat (4) @(negedge clk);
        n_chk = n_chk + 4;
        if (busy !== 1'b0 || out_valid !== 1'b0 || done !== 1'b0 || in_ready !== 1'b0) begin
            n_err = n_err + 1;
            $display("LOI: trang thai trong reset busy=%b out_valid=%b done=%b in_ready=%b", busy, out_valid, done, in_ready);
        end
        rst_n = 1'b1;
        repeat (3) @(negedge clk);

        // in_valid khi chua start khong duoc nhan
        in_valid = 1'b1; data_in = 8'h5A;
        idle_acc = 0;
        repeat (10) begin
            @(negedge clk); #8;
            if (in_ready) idle_acc = idle_acc + 1;
        end
        in_valid = 1'b0;
        n_chk = n_chk + 2;
        if (idle_acc != 0) begin n_err = n_err + 1; $display("LOI: in_ready=1 truoc khi start"); end
        if (ocnt != 0)     begin n_err = n_err + 1; $display("LOI: dau ra xuat hien khi chua start"); end

        // ---- 1a. Vi du docs: loi XOR 55 tai vi tri 0, XOR A6 tai vi tri 14
        if (N == 15 && K == 11) begin
            for (p = 0; p < K; p = p + 1) d[8*p +: 8] = p;
            cw = r_encode(d);
            em = {8*N{1'b0}}; em[7:0] = 8'h55; em[8*14 +: 8] = 8'hA6;
            decode_check(cw, cw ^ em, 2, 0, 0, "docs muc 12");
        end

        // ---- 1b. Khong loi
        d = {8*K{1'b0}};
        cw = r_encode(d);
        decode_check(cw, cw, 0, 0, 0, "toan 0, khong loi");
        for (t = 0; t < 10; t = t + 1) begin
            t_rand_data(d); cw = r_encode(d);
            decode_check(cw, cw, 0, t % 2, t % 3, "khong loi");
        end
        d = {8*K{1'b1}}; cw = r_encode(d);
        decode_check(cw, cw, 0, 0, 0, "toan FF, khong loi");

        // ---- 2. Mot loi tai moi vi tri
        for (p = 0; p < N; p = p + 1)
            for (v = 1; v < 256; v = v + 17) begin
                t_rand_data(d); cw = r_encode(d);
                em = {8*N{1'b0}}; em[8*p +: 8] = v;
                decode_check(cw, cw ^ em, 1, 0, 0, "1 loi");
            end
        // 1 loi tren du lieu toan 0 (symbol 0 ban dau bi loi)
        d = {8*K{1'b0}}; cw = r_encode(d);
        for (p = 0; p < N; p = p + 1) begin
            em = {8*N{1'b0}}; em[8*p +: 8] = 8'hFF;
            decode_check(cw, cw ^ em, 1, 1, 1, "1 loi, du lieu 0");
        end

        // ---- 3. Hai loi tai moi cap
        for (p = 0; p < N; p = p + 1)
            for (q = p + 1; q < N; q = q + 1) begin
                t_rand_data(d); cw = r_encode(d);
                em = {8*N{1'b0}};
                em[8*p +: 8] = ($random(seed) | 8'h01);
                em[8*q +: 8] = ($random(seed) | 8'h01);
                decode_check(cw, cw ^ em, 2, p % 2, 0, "2 loi");
                // S[0] = 0 (hai gia tri loi bang nhau)
                em = {8*N{1'b0}};
                v = ($random(seed) & 8'hFF) | 8'h02;
                em[8*p +: 8] = v; em[8*q +: 8] = v;
                decode_check(cw, cw ^ em, 2, 0, q % 3, "2 loi S0=0");
            end

        // ---- 4. Truong hop bien
        t_rand_data(d); cw = r_encode(d);
        em = {8*N{1'b0}}; em[7:0] = 8'h80; em[8*(N-1) +: 8] = 8'h01;
        decode_check(cw, cw ^ em, 2, 0, 0, "loi dau + cuoi");
        em = {8*N{1'b0}}; em[8*K +: 8] = 8'hFF; em[8*(N-1) +: 8] = 8'h5A;
        decode_check(cw, cw ^ em, 2, 0, 0, "2 loi chi parity");
        em = {8*N{1'b0}}; em[8*(K-1) +: 8] = 8'h11; em[8*K +: 8] = 8'h22;
        decode_check(cw, cw ^ em, 2, 0, 0, "loi giap ranh gioi du lieu/parity");
        for (p = 0; p < 8; p = p + 1) begin
            em = {8*N{1'b0}}; em[8*(p+2) +: 8] = (8'h01 << p);
            decode_check(cw, cw ^ em, 1, 0, 0, "1 bit sai");
        end
        em = {8*N{1'b0}}; em[8*4 +: 8] = 8'hFF;         // nhieu bit sai trong 1 symbol van la 1 loi
        decode_check(cw, cw ^ em, 1, 0, 0, "8 bit sai trong 1 symbol");

        // ---- 5. Vuot gioi han
        for (t = 0; t < 200; t = t + 1) begin
            t_rand_data(d); cw = r_encode(d);
            t_rand_err(3 + (t % (R - 2)), em);
            decode_check(cw, cw ^ em, 3 + (t % (R - 2)), t % 2, 0, "vuot gioi han");
        end
        // Toan bo tu nhan la ngau nhien (khong phai tu ma + loi)
        for (t = 0; t < 100; t = t + 1) begin
            for (p = 0; p < N; p = p + 1) y[8*p +: 8] = $random(seed);
            decode_check(y, y, N, 0, 0, "tu nhan ngau nhien");
        end
        $display("Vuot gioi han: fail = %0d, giai ma nham = %0d, tinh co khoi phuc dung = %0d",
                 st_fail, st_miscorrect, st_recovered);

        // ---- 6. Khoang nghi dau vao x back-pressure dau ra
        for (t = 0; t < 60; t = t + 1) begin
            t_rand_data(d); cw = r_encode(d);
            nb = t % (T + 1);
            t_rand_err(nb, em);
            decode_check(cw, cw ^ em, nb, t % 2, (t / 2) % 3, "gap x bp");
        end

        // ---- 7. Reset giua khoi
        bp_mode = 0;
        t_rand_data(d); cw = r_encode(d);
        t_rand_err(2, em);
        // (a) khi dang nhan
        @(negedge clk); start = 1'b1;
        @(negedge clk); start = 1'b0;
        for (p = 0; p < 7; p = p + 1) begin
            @(negedge clk); in_valid = 1'b1; data_in = (cw ^ em) >> (8*p); #8;
        end
        @(negedge clk); in_valid = 1'b0;
        do_reset;
        n_chk = n_chk + 3;
        if (busy !== 1'b0 || out_valid !== 1'b0 || in_ready !== 1'b0) begin
            n_err = n_err + 1; $display("LOI: sau reset khi dang nhan phai IDLE");
        end
        decode_check(cw, cw ^ em, 2, 0, 0, "sau reset luc nhan");

        // (b) khi dang xu ly: gui du N symbol roi reset ngay
        t_rand_err(2, em);
        clear_sb;
        send_word(cw ^ em, 0);
        repeat (3) @(negedge clk);
        do_reset;
        n_chk = n_chk + 3;
        if (busy !== 1'b0 || out_valid !== 1'b0 || in_ready !== 1'b0) begin
            n_err = n_err + 1; $display("LOI: sau reset khi dang xu ly phai IDLE");
        end
        t_rand_err(1, em);
        decode_check(cw, cw ^ em, 1, 0, 0, "sau reset luc xu ly");

        // (c) khi dau ra dang bi chan
        bp_mode = 2;
        t_rand_err(2, em);
        clear_sb;
        fork
            send_word(cw ^ em, 0);
            begin
                repeat (60) @(negedge clk);
                rst_n = 1'b0;
                repeat (3) @(negedge clk);
                rst_n = 1'b1;
                abort_send = 1'b1;
            end
        join
        abort_send = 1'b0;
        in_valid = 1'b0; start = 1'b0; bp_mode = 0;
        repeat (4) @(negedge clk);
        n_chk = n_chk + 1;
        if (busy !== 1'b0) begin n_err = n_err + 1; $display("LOI: busy != 0 sau reset khi bi chan"); end
        t_rand_err(2, em);
        decode_check(cw, cw ^ em, 2, 0, 1, "sau reset luc bi chan");

        // ---- 8. Hai khoi lien tiep, khac nhau
        t_rand_data(d); cw = r_encode(d); t_rand_err(1, em);
        decode_check(cw, cw ^ em, 1, 0, 0, "lien tiep #1");
        t_rand_data(d); cw = r_encode(d); t_rand_err(2, em);
        decode_check(cw, cw ^ em, 2, 1, 1, "lien tiep #2");
        t_rand_data(d); cw = r_encode(d);
        decode_check(cw, cw, 0, 0, 0, "lien tiep #3 (khong loi)");

        t_finish("tb_rs_decoder");
    end

    initial begin
        #800_000_000;
        $display("[FAIL] tb_rs_decoder: het thoi gian");
        $finish;
    end

endmodule

