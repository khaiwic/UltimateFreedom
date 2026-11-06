// tb_rs_encoder.v
// Testbench cho rtl/rs_encoder/rs_encoder.v  (RS(15,11) tren GF(256))
//
// Hop dong kiem tra (header rs_encoder.v, README muc 3):
//   - start: xung 1 chu ky, nhan khi IDLE; start luc busy bi bo qua.
//   - Dau vao nhan khi in_valid && in_ready, dung K symbol/khoi; in_ready chi khi busy.
//   - Dau ra: K byte du lieu (systematic) roi R byte parity, out_last o symbol thu N,
//     data_out giu on dinh khi out_valid=1, out_ready=0.
//   - done: xung 1 chu ky sau symbol cuoi; busy ha xuong sau do.
//
// Noi dung test:
//   1. Trang thai sau reset.
//   2. Vi du co dinh trong docs: 00..0A -> parity C0 8F 28 6C.
//   3. Cac khoi dac biet: toan 0, toan FF, xung don vi tai tung vi tri (K khoi).
//   4. 150 khoi ngau nhien, to hop (khoang nghi dau vao) x (back-pressure dau ra).
//   5. Tu ma sinh ra co syndrome = 0.
//   6. in_valid khi chua start khong duoc nhan; start luc busy bi bo qua.
//   7. Reset giua khoi roi ma hoa khoi moi dung (thanh ghi parity da xoa).
//   8. Hai khoi lien tiep (start ngay sau done).
//
// Chay: vlog +incdir+../rtl/include +incdir+../tb ../rtl/gf_arithmetic/*.v \
//            ../rtl/rs_encoder/rs_encoder.v tb_rs_encoder.v
`timescale 1ns/1ps
`include "rs_params.vh"

module tb_rs_encoder;

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

    rs_encoder dut (
        .clk(clk), .rst_n(rst_n), .start(start),
        .data_in(data_in), .in_valid(in_valid), .in_ready(in_ready),
        .data_out(data_out), .out_valid(out_valid), .out_ready(out_ready),
        .out_last(out_last), .busy(busy), .done(done)
    );

    always #10 clk = ~clk;      // 50 MHz

    // ------------------------------------------------------------ back-pressure
    integer bp_mode = 0;        // 0: luon san sang, 1: ngau nhien 50%, 2: bi chan lau
    integer cyc = 0;
    always @(negedge clk) begin
        cyc = cyc + 1;
        case (bp_mode)
            0: out_ready = 1'b1;
            1: out_ready = $random(seed);
            default: out_ready = ((cyc % 40) >= 30);
        endcase
    end

    // ------------------------------------------------------------ scoreboard
    reg [8*N-1:0] got;
    integer       ocnt = 0;
    integer       done_cnt = 0;
    reg           pv_valid = 1'b0, pv_ready = 1'b0, pv_done = 1'b0;
    reg [7:0]     pv_data = 8'h00;

    task clear_sb;
        begin
            got = {8*N{1'b0}}; ocnt = 0; done_cnt = 0;
        end
    endtask

    always @(negedge clk) begin
        #8;                         // lay mau 2 ns truoc canh len
        if (rst_n) begin
            // du lieu on dinh khi valid && !ready
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
    task do_reset;
        begin
            @(negedge clk); rst_n = 1'b0; start = 1'b0; in_valid = 1'b0;
            repeat (3) @(negedge clk);
            rst_n = 1'b1;
            repeat (2) @(negedge clk);
        end
    endtask

    reg abort_send = 1'b0;      // bo dang gui khi test chu dong reset giua chung

    // gapmode: 0 = in_valid lien tuc, 1 = chen khoang nghi ngau nhien
    // start_at: gui them xung start sau khi da nhan start_at symbol (-1: khong)
    task send_block;
        input [8*K-1:0] d;
        input integer   gapmode;
        input integer   start_at;
        integer i;
        reg     hold, fire, extra;
        begin
            @(negedge clk); start = 1'b1;
            @(negedge clk); start = 1'b0;
            i = 0; hold = 1'b0; extra = 1'b0;
            while (i < K && !abort_send) begin
                @(negedge clk);
                start = 1'b0;
                if (start_at >= 0 && i == start_at && !extra) begin
                    start = 1'b1; extra = 1'b1;
                end
                if (!hold && gapmode != 0 && ({$random(seed)} % 3) == 0) begin
                    in_valid = 1'b0; data_in = $random(seed);
                end else begin
                    in_valid = 1'b1; data_in = d[8*i +: 8]; hold = 1'b1;
                end
                #8;
                fire = in_valid && in_ready;
                if (fire) begin i = i + 1; hold = 1'b0; end
            end
            @(negedge clk); in_valid = 1'b0; start = 1'b0; data_in = 8'h00;
        end
    endtask

    task wait_done;
        integer w;
        begin
            w = 0;
            while (done_cnt == 0 && w < 3000) begin @(negedge clk); w = w + 1; end
            repeat (6) @(negedge clk);
        end
    endtask

    task check_block;
        input [8*K-1:0] d;
        input [255:0]   tag;
        reg [8*N-1:0] exp;
        begin
            exp = r_encode(d);
            n_chk = n_chk + 5;
            if (ocnt !== N) begin
                n_err = n_err + 1; $display("LOI [%0s]: so symbol dau ra = %0d (mong doi %0d)", tag, ocnt, N);
            end
            if (done_cnt !== 1) begin
                n_err = n_err + 1; $display("LOI [%0s]: so xung done = %0d (mong doi 1)", tag, done_cnt);
            end
            if (got !== exp) begin
                n_err = n_err + 1; $display("LOI [%0s]: tu ma %h, mong doi %h", tag, got, exp);
            end
            if (got[8*K-1:0] !== d) begin
                n_err = n_err + 1; $display("LOI [%0s]: K byte dau khong phai du lieu goc", tag);
            end
            if (r_syn(got) !== {8*R{1'b0}}) begin
                n_err = n_err + 1; $display("LOI [%0s]: tu ma dau ra co syndrome != 0", tag);
            end
            if (busy !== 1'b0) begin
                n_chk = n_chk + 1; n_err = n_err + 1; $display("LOI [%0s]: busy van = 1 sau done", tag);
            end
        end
    endtask

    task run_one;
        input [8*K-1:0] d;
        input integer   gapmode;
        input integer   bpm;
        input [255:0]   tag;
        begin
            bp_mode = bpm;
            clear_sb;
            send_block(d, gapmode, -1);
            wait_done;
            check_block(d, tag);
        end
    endtask

    // ------------------------------------------------------------ test
    integer t, p, gm, bm;
    reg [8*K-1:0] d;
    reg [8*N-1:0] cw;
    integer idle_acc;

    initial begin
        t_selfcheck_ref(0);

        // ---- 1. Reset
        rst_n = 1'b0;
        repeat (4) @(negedge clk);
        n_chk = n_chk + 4;
        if (busy !== 1'b0 || out_valid !== 1'b0 || done !== 1'b0 || in_ready !== 1'b0) begin
            n_err = n_err + 1;
            $display("LOI: trang thai trong reset busy=%b out_valid=%b done=%b in_ready=%b",
                     busy, out_valid, done, in_ready);
        end
        rst_n = 1'b1;
        repeat (3) @(negedge clk);
        n_chk = n_chk + 3;
        if (busy !== 1'b0 || out_valid !== 1'b0 || in_ready !== 1'b0) begin
            n_err = n_err + 1; $display("LOI: sau reset phai IDLE");
        end

        // ---- 6a. in_valid khi chua start khong duoc nhan
        in_valid = 1'b1; data_in = 8'hAA;
        idle_acc = 0;
        repeat (10) begin
            @(negedge clk); #8;
            if (in_ready) idle_acc = idle_acc + 1;
        end
        in_valid = 1'b0;
        n_chk = n_chk + 2;
        if (idle_acc != 0) begin n_err = n_err + 1; $display("LOI: in_ready=1 truoc khi start"); end
        if (ocnt != 0)     begin n_err = n_err + 1; $display("LOI: dau ra xuat hien khi chua start"); end

        // ---- 2. Vi du trong docs: 00..0A
        for (p = 0; p < K; p = p + 1) d[8*p +: 8] = p;
        run_one(d, 0, 0, "docs 00..0A");
        n_chk = n_chk + 1;
        if (N == 15 && K == 11 && got[8*K +: 32] !== 32'h6C288FC0) begin
            n_err = n_err + 1; $display("LOI: parity vi du docs = %h (mong doi C0 8F 28 6C)", got[8*K +: 32]);
        end

        // ---- 3. Khoi dac biet
        d = {8*K{1'b0}};            run_one(d, 0, 0, "toan 0");
        n_chk = n_chk + 1;
        if (got[8*N-1:8*K] !== {8*R{1'b0}}) begin
            n_err = n_err + 1; $display("LOI: du lieu toan 0 phai co parity toan 0");
        end
        d = {8*K{1'b1}};            run_one(d, 0, 0, "toan FF");
        for (p = 0; p < K; p = p + 1) begin
            d = {8*K{1'b0}}; d[8*p +: 8] = 8'h01;
            run_one(d, 0, 0, "xung don vi");
            d = {8*K{1'b0}}; d[8*p +: 8] = 8'h80;
            run_one(d, 0, 0, "xung 80");
        end

        // ---- 4. Ngau nhien x gap x back-pressure
        for (t = 0; t < 150; t = t + 1) begin
            t_rand_data(d);
            gm = t % 2;
            bm = (t / 2) % 3;
            run_one(d, gm, bm, "ngau nhien");
        end

        // ---- 6b. start trong luc busy bi bo qua
        bp_mode = 0;
        t_rand_data(d);
        clear_sb;
        send_block(d, 0, 4);
        wait_done;
        check_block(d, "start khi busy");

        // ---- 7. Reset giua khoi
        bp_mode = 0;
        t_rand_data(d);
        @(negedge clk); start = 1'b1;
        @(negedge clk); start = 1'b0;
        for (p = 0; p < 5; p = p + 1) begin
            @(negedge clk); in_valid = 1'b1; data_in = d[8*p +: 8];
            #8;
        end
        @(negedge clk); in_valid = 1'b0;
        do_reset;
        n_chk = n_chk + 3;
        if (busy !== 1'b0 || out_valid !== 1'b0 || in_ready !== 1'b0) begin
            n_err = n_err + 1; $display("LOI: sau reset giua khoi phai IDLE");
        end
        t_rand_data(d);
        run_one(d, 1, 0, "sau reset giua khoi");

        // Reset khi dau ra dang bi chan
        bp_mode = 2;
        t_rand_data(d);
        clear_sb;
        fork
            send_block(d, 0, -1);
            begin
                repeat (18) @(negedge clk);
                rst_n = 1'b0;
                repeat (3) @(negedge clk);
                rst_n = 1'b1;
                abort_send = 1'b1;
            end
        join
        abort_send = 1'b0;
        repeat (4) @(negedge clk);
        bp_mode = 0;
        in_valid = 1'b0; start = 1'b0;
        repeat (3) @(negedge clk);
        n_chk = n_chk + 1;
        if (busy !== 1'b0) begin n_err = n_err + 1; $display("LOI: busy != 0 sau reset khi bi chan"); end
        t_rand_data(d);
        run_one(d, 0, 1, "sau reset khi bi chan");

        // ---- 8. Hai khoi lien tiep (start ngay sau done)
        bp_mode = 0;
        t_rand_data(d); clear_sb;
        send_block(d, 0, -1);
        wait_done;
        check_block(d, "lien tiep #1");
        t_rand_data(d); clear_sb;
        send_block(d, 1, -1);
        wait_done;
        check_block(d, "lien tiep #2");

        t_finish("tb_rs_encoder");
    end

    initial begin
        #200_000_000;
        $display("[FAIL] tb_rs_encoder: het thoi gian");
        $finish;
    end

endmodule
