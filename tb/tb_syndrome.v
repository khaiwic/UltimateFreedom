`timescale 1ns/1ps
`include "rs_params.vh"

module tb_syndrome;

    `include "rs_tb_ref.vh"

    reg          clk = 1'b0;
    reg          rst_n = 1'b0;
    reg          start = 1'b0;
    reg  [7:0]   data_in = 8'h00;
    reg          in_valid = 1'b0;
    wire         in_ready;
    wire [8*R-1:0] syn;
    wire         syn_zero;
    wire         busy;
    wire         done;

    syndrome dut (
        .clk(clk), .rst_n(rst_n), .start(start),
        .data_in(data_in), .in_valid(in_valid), .in_ready(in_ready),
        .syn(syn), .syn_zero(syn_zero), .busy(busy), .done(done)
    );

    always #10 clk = ~clk;

    // ---------------------------------------------------------- monitor
    integer       done_cnt = 0;
    reg [8*R-1:0] syn_at_done;
    reg           zero_at_done;
    reg           pv_done = 1'b0;
    always @(negedge clk) begin
        #8;
        if (rst_n) begin
            if (done) begin
                done_cnt = done_cnt + 1;
                syn_at_done = syn; zero_at_done = syn_zero;
                if (pv_done) begin n_err = n_err + 1; $display("[%0t] LOI: done keo dai > 1 chu ky", $time); end
            end
            if (in_ready && !busy) begin
                n_err = n_err + 1; $display("[%0t] LOI: in_ready=1 khi busy=0", $time);
            end
        end
        pv_done = done && rst_n;
    end

    // ---------------------------------------------------------- driver
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
            done_cnt = 0;
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
            while (done_cnt == 0 && w < 500) begin @(negedge clk); w = w + 1; end
            repeat (4) @(negedge clk);
        end
    endtask

    task run_word;
        input [8*N-1:0] y;
        input integer   gapmode;
        input [255:0]   tag;
        reg [8*R-1:0] exp;
        begin
            exp = r_syn(y);
            send_word(y, gapmode);
            wait_done;
            n_chk = n_chk + 5;
            if (done_cnt !== 1) begin
                n_err = n_err + 1; $display("LOI [%0s]: so xung done = %0d", tag, done_cnt);
            end
            if (syn_at_done !== exp) begin
                n_err = n_err + 1;
                if (n_err <= 25) $display("LOI [%0s]: y=%h S=%h (mong doi %h)", tag, y, syn_at_done, exp);
            end
            if (zero_at_done !== (exp == {8*R{1'b0}})) begin
                n_err = n_err + 1; $display("LOI [%0s]: syn_zero=%b (mong doi %b)", tag, zero_at_done, (exp == 0));
            end
            if (syn !== exp) begin
                n_err = n_err + 1; $display("LOI [%0s]: syn khong giu on dinh sau done (%h)", tag, syn);
            end
            if (busy !== 1'b0) begin
                n_err = n_err + 1; $display("LOI [%0s]: busy van = 1 sau done", tag);
            end
        end
    endtask

    // ---------------------------------------------------------- test
    integer p, q, v, t;
    reg [8*K-1:0] d;
    reg [8*N-1:0] cw, y, em;

    initial begin
        t_selfcheck_ref(0);

        rst_n = 1'b0;
        repeat (4) @(negedge clk);
        n_chk = n_chk + 2;
        if (busy !== 1'b0 || done !== 1'b0) begin n_err = n_err + 1; $display("LOI: busy/done sau reset"); end
        rst_n = 1'b1;
        repeat (3) @(negedge clk);

        // ---- 1. Vi du docs
        if (N == 15 && K == 11) begin
            for (p = 0; p < K; p = p + 1) d[8*p +: 8] = p;
            cw = r_encode(d);
            y = cw;
            y[8*0 +: 8]  = y[8*0 +: 8]  ^ 8'h55;
            y[8*14 +: 8] = y[8*14 +: 8] ^ 8'hA6;
            run_word(y, 0, "docs muc 12");
            n_chk = n_chk + 1;
            if (syn_at_done !== 32'h240D60F3) begin
                n_err = n_err + 1; $display("LOI: S docs = %h (mong doi F3 60 0D 24)", syn_at_done);
            end
        end

        // ---- 2. Khong loi
        d = {8*K{1'b0}};
        run_word(r_encode(d), 0, "toan 0");
        n_chk = n_chk + 1;
        if (zero_at_done !== 1'b1) begin n_err = n_err + 1; $display("LOI: toan 0 phai syn_zero=1"); end
        for (t = 0; t < 20; t = t + 1) begin
            t_rand_data(d);
            run_word(r_encode(d), t % 2, "tu ma hop le");
            n_chk = n_chk + 1;
            if (zero_at_done !== 1'b1 || syn_at_done !== {8*R{1'b0}}) begin
                n_err = n_err + 1; $display("LOI: tu ma hop le phai co S = 0");
            end
        end

        // ---- 3. Mot loi tai moi vi tri
        t_rand_data(d);
        cw = r_encode(d);
        for (p = 0; p < N; p = p + 1)
            for (v = 1; v < 256; v = v + 17) begin
                em = {8*N{1'b0}}; em[8*p +: 8] = v;
                run_word(cw ^ em, 0, "1 loi");
            end

        // ---- 4. Hai loi tai moi cap vi tri
        for (p = 0; p < N; p = p + 1)
            for (q = p + 1; q < N; q = q + 1) begin
                t_rand_data(d); cw = r_encode(d);
                em = {8*N{1'b0}};
                em[8*p +: 8] = $random(seed) | 8'h01;
                em[8*q +: 8] = $random(seed) | 8'h01;
                run_word(cw ^ em, p % 2, "2 loi");
                // S[0] = 0: hai gia tri loi bang nhau
                em = {8*N{1'b0}};
                v = ($random(seed) & 8'hFF) | 8'h02;
                em[8*p +: 8] = v; em[8*q +: 8] = v;
                run_word(cw ^ em, 0, "2 loi S0=0");
                n_chk = n_chk + 2;
                if (syn_at_done[7:0] !== 8'h00) begin
                    n_err = n_err + 1; $display("LOI: S[0] phai = 0 khi hai loi bang nhau");
                end
                if (syn_at_done[8*R-1:8] === {8*(R-1){1'b0}}) begin
                    n_err = n_err + 1; $display("LOI: cac S khac khong duoc dong thoi = 0");
                end
            end

        // ---- 5. Tu nhan ngau nhien + nhieu loi
        for (t = 0; t < 100; t = t + 1) begin
            for (p = 0; p < N; p = p + 1) y[8*p +: 8] = $random(seed);
            run_word(y, t % 2, "ngau nhien");
        end
        for (t = 0; t < 60; t = t + 1) begin
            t_rand_data(d); cw = r_encode(d);
            t_rand_err(3 + (t % (R - 2)), em);
            run_word(cw ^ em, 1, "nhieu loi > T");
        end

        // ---- 7. Reset giua khoi, roi hai khoi lien tiep
        t_rand_data(d); cw = r_encode(d);
        @(negedge clk); start = 1'b1;
        @(negedge clk); start = 1'b0;
        for (p = 0; p < 6; p = p + 1) begin
            @(negedge clk); in_valid = 1'b1; data_in = $random(seed); #8;
        end
        @(negedge clk); in_valid = 1'b0;
        do_reset;
        n_chk = n_chk + 1;
        if (busy !== 1'b0) begin n_err = n_err + 1; $display("LOI: busy != 0 sau reset giua khoi"); end
        t_rand_err(2, em);
        run_word(cw ^ em, 0, "sau reset giua khoi");

        t_rand_err(1, em); run_word(cw ^ em, 0, "lien tiep #1");
        t_rand_err(2, em); run_word(cw ^ em, 1, "lien tiep #2");

        t_finish("tb_syndrome");
    end

    initial begin
        #100_000_000;
        $display("[FAIL] tb_syndrome: het thoi gian");
        $finish;
    end

endmodule

