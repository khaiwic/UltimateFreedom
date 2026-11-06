// tb_top.v
// Testbench cap board cho rtl/board/top_de10_lite.v  (README muc 4, 6; docs/pin_assignment.md)
//
// Kiem tra HANH VI NGOAI VI nhin tu cac chan cua board, khong can biet cau truc ben trong:
//   MAX10_CLK1_50, KEY[0] = reset (tich cuc thap), KEY[1] = xac nhan nhap / bat dau,
//   SW[7:0] = byte du lieu, SW[8] = pha nhap (0) / pha chay (1), SW[9] = cho phep tao loi,
//   LEDR[0] = busy, LEDR[1] = done (chot), LEDR[2] = fail (chot), HEX1:HEX0 = byte dang xem.
//
// Dung theo README, KHONG gia dinh them nhung gi README chua chot:
//   - Hien thi tung byte ket qua tren HEX (thu tu duyet) CHUA duoc README quy dinh nen chi kiem tra
//     HEX luon la mau 7 doan hop le (0..F hoac tat), DP tat (bit 7 = 1). Dat CHECK_HEX_ECHO = 1
//     neu thiet ke cua ban hien thi lai byte vua chot tren HEX; khi do se doi chieu mau 7 doan.
//   - Mau loi ban dau la hang so/kich ban thu trong thiet ke; mac dinh mong doi tao loi <= T
//     nen decoder sua duoc va fail = 0 (EXPECT_FAIL_WITH_ERR = 0). Dat 1 neu mau loi vuot T.
//
// Noi dung test:
//   1. Sau reset: LEDR = 000, HEX hop le, DP tat, khong X.
//   2. Pha nhap: nhap K = 11 symbol bang SW[7:0] + KEY[1]; trong pha nhap busy/done/fail = 0.
//   3. Nhieu ngan ngan (glitch) tren KEY[1] KHONG duoc bat dau xu ly (loc doi / debounce).
//   4. Chuyen SW[8] = 1 roi nhan KEY[1]: busy len 1 dung mot lan, ket thuc voi done = 1, busy = 0,
//      fail = 0; done duoc chot du lau de quan sat (HOLD_CYCLES); giu KEY[1] lau khong chay lai.
//   5. Lap lai voi SW[9] = 1 (tao loi): decoder van sua dung (fail = 0).
//   6. Reset (KEY[0]) trong luc busy / sau done xoa het LED; sau do chay lai dung.
//
// Thoi gian mo phong: input_control mac dinh DEBOUNCE_CYCLES = 500_000 (10 ms), moi lan nhan phai
// giu > 500_000 chu ky => mo phong day du tuong doi dai. De chay nhanh: dung defparam/giam
// DEBOUNCE_CYCLES trong input_control, dong thoi giam PRESS_CYCLES (> DEBOUNCE_CYCLES) va
// HOLD_CYCLES trong testbench nay.
//
// Chay: vlog +incdir+../rtl/include ../rtl/gf_arithmetic/*.v ../rtl/rs_encoder/*.v \
//            ../rtl/rs_decoder/*.v ../rtl/memory/*.v ../rtl/controller/*.v ../rtl/demo/*.v \
//            ../rtl/board/*.v tb_top.v
`timescale 1ns/1ps
`include "rs_params.vh"

module tb_top;

    parameter integer PRESS_CYCLES   = 600_000;     // thoi gian giu KEY[1], phai > DEBOUNCE_CYCLES
    parameter integer GLITCH_CYCLES  = 5;           // xung nhieu ngan, phai << DEBOUNCE_CYCLES
    parameter integer RUN_TIMEOUT    = 3_000_000;   // chu ky cho toi khi done
    parameter integer HOLD_CYCLES    = 1_000_000;   // done/fail phai giu it nhat bay nhieu chu ky
    parameter integer CHECK_HEX_ECHO = 0;
    parameter integer EXPECT_FAIL_WITH_ERR = 0;

    localparam integer K = `RS_K;

    reg         MAX10_CLK1_50 = 1'b0;
    reg  [1:0]  KEY = 2'b11;
    reg  [9:0]  SW  = 10'b0;
    wire [2:0]  LEDR;
    wire [7:0]  HEX0;
    wire [7:0]  HEX1;

    top_de10_lite dut (
        .MAX10_CLK1_50(MAX10_CLK1_50),
        .KEY(KEY),
        .SW(SW),
        .LEDR(LEDR),
        .HEX0(HEX0),
        .HEX1(HEX1)
    );

    always #10 MAX10_CLK1_50 = ~MAX10_CLK1_50;     // 50 MHz, chu ky 20 ns

    integer n_err = 0;
    integer n_chk = 0;

    // ------------------------------------------------------------ 7 doan
    function [7:0] seg;                              // tich cuc thap, DP tat
        input [3:0] h;
        begin
            case (h)
                4'h0: seg = 8'hC0; 4'h1: seg = 8'hF9; 4'h2: seg = 8'hA4; 4'h3: seg = 8'hB0;
                4'h4: seg = 8'h99; 4'h5: seg = 8'h92; 4'h6: seg = 8'h82; 4'h7: seg = 8'hF8;
                4'h8: seg = 8'h80; 4'h9: seg = 8'h90; 4'hA: seg = 8'h88; 4'hB: seg = 8'h83;
                4'hC: seg = 8'hC6; 4'hD: seg = 8'hA1; 4'hE: seg = 8'h86; default: seg = 8'h8E;
            endcase
        end
    endfunction

    function is_seg;                                  // mau hop le: 0..F hoac tat hoan toan
        input [7:0] s;
        integer k;
        reg ok;
        begin
            ok = (s === 8'hFF);
            for (k = 0; k < 16; k = k + 1)
                if (s === seg(k[3:0])) ok = 1'b1;
            is_seg = ok;
        end
    endfunction

    // ------------------------------------------------------------ monitor LED
    integer busy_rises = 0;
    reg     busy_seen  = 1'b0;
    reg     pv_busy    = 1'b0;
    reg     led_x      = 1'b0;
    always @(posedge MAX10_CLK1_50) begin
        if (LEDR[0] === 1'b1 && pv_busy === 1'b0) busy_rises = busy_rises + 1;
        if (LEDR[0] === 1'b1) busy_seen = 1'b1;
        pv_busy = (LEDR[0] === 1'b1);
        if (^LEDR === 1'bx) led_x = 1'b1;
    end

    // ------------------------------------------------------------ tac vu co ban
    task wait_cycles;
        input integer n;
        begin repeat (n) @(posedge MAX10_CLK1_50); end
    endtask

    task do_reset;
        begin
            KEY[1] = 1'b1;
            KEY[0] = 1'b0;
            wait_cycles(20);
            KEY[0] = 1'b1;
            wait_cycles(20);
        end
    endtask

    task press_key1;
        begin
            KEY[1] = 1'b0; wait_cycles(PRESS_CYCLES);
            KEY[1] = 1'b1; wait_cycles(PRESS_CYCLES);
        end
    endtask

    task glitch_key1;
        begin
            KEY[1] = 1'b0; wait_cycles(GLITCH_CYCLES);
            KEY[1] = 1'b1; wait_cycles(GLITCH_CYCLES * 4);
        end
    endtask

    task check_hex_valid;
        input [255:0] tag;
        begin
            n_chk = n_chk + 3;
            if (HEX0[7] !== 1'b1 || HEX1[7] !== 1'b1) begin
                n_err = n_err + 1; $display("LOI [%0s]: DP khong tat (HEX1[7]=%b HEX0[7]=%b)", tag, HEX1[7], HEX0[7]);
            end
            if (!is_seg(HEX0)) begin
                n_err = n_err + 1; $display("LOI [%0s]: HEX0 = %h khong phai mau 7 doan hop le", tag, HEX0);
            end
            if (!is_seg(HEX1)) begin
                n_err = n_err + 1; $display("LOI [%0s]: HEX1 = %h khong phai mau 7 doan hop le", tag, HEX1);
            end
        end
    endtask

    task check_leds;
        input [2:0]   exp;
        input [255:0] tag;
        begin
            n_chk = n_chk + 1;
            if (LEDR !== exp) begin
                n_err = n_err + 1; $display("LOI [%0s]: LEDR = %b (mong doi %b = fail,done,busy)", tag, LEDR, exp);
            end
        end
    endtask

    // ------------------------------------------------------------ mot giao dich day du
    reg [7:0] blk [0:K-1];
    integer   i, w;
    reg       hold_ok;
    integer   hold_cnt;

    task enter_block;
        integer k;
        begin
            SW[8] = 1'b0;
            for (k = 0; k < K; k = k + 1) begin
                SW[7:0] = blk[k];
                wait_cycles(20);
                press_key1;
                n_chk = n_chk + 1;
                if (LEDR[2:0] !== 3'b000) begin
                    n_err = n_err + 1; $display("LOI: LEDR = %b sau khi nhap symbol %0d (pha nhap phai = 000)", LEDR, k);
                end
                if (CHECK_HEX_ECHO) begin
                    n_chk = n_chk + 2;
                    if (HEX1 !== seg(blk[k][7:4]) || HEX0 !== seg(blk[k][3:0])) begin
                        n_err = n_err + 1; $display("LOI: HEX = %h%h khong khop byte %h", HEX1, HEX0, blk[k]);
                    end
                end
                check_hex_valid("pha nhap");
            end
        end
    endtask

    reg got;                    // wait_for_done: 1 neu LEDR[1] (done) len 1 trong RUN_TIMEOUT
    task wait_for_done;
        begin
            got = 1'b0; w = 0;
            while (!got && w < RUN_TIMEOUT) begin
                @(posedge MAX10_CLK1_50);
                w = w + 1;
                if (LEDR[1] === 1'b1) got = 1'b1;
            end
        end
    endtask

    task run_transaction;
        input         inject;
        input [255:0] tag;
        reg [2:0] snap;
        begin
            do_reset;
            check_leds(3'b000, "sau reset");
            check_hex_valid("sau reset");

            enter_block;

            // Pha chay; SW[9] chot truoc khi bat dau
            SW[8] = 1'b1;
            SW[9] = inject;
            wait_cycles(100);
            n_chk = n_chk + 1;
            if (LEDR[0] !== 1'b0) begin
                n_err = n_err + 1; $display("LOI [%0s]: busy=1 truoc khi nhan KEY[1] o pha chay", tag);
            end

            // Nhieu ngan: khong duoc bat dau
            busy_seen = 1'b0; busy_rises = 0;
            glitch_key1; glitch_key1; glitch_key1;
            wait_cycles(5000);
            n_chk = n_chk + 2;
            if (busy_seen || LEDR[1] === 1'b1) begin
                n_err = n_err + 1; $display("LOI [%0s]: nhieu ngan tren KEY[1] da kich hoat xu ly (loc doi that bai)", tag);
            end

            // Nhan that su
            busy_seen = 1'b0; busy_rises = 0;
            KEY[1] = 1'b0;
            wait_cycles(PRESS_CYCLES);
            wait_for_done;             // KEY[1] van dang giu: khong duoc chay lai
            n_chk = n_chk + 1;
            if (!got) begin
                n_err = n_err + 1; $display("LOI [%0s]: het thoi gian cho done (LEDR[1])", tag);
            end
            wait_cycles(PRESS_CYCLES);
            KEY[1] = 1'b1;
            wait_cycles(PRESS_CYCLES);

            n_chk = n_chk + 5;
            if (!busy_seen) begin n_err = n_err + 1; $display("LOI [%0s]: busy khong bao gio len 1", tag); end
            if (busy_rises !== 1) begin
                n_err = n_err + 1; $display("LOI [%0s]: busy len %0d lan (mong doi dung 1, KEY giu lau khong duoc lap lai)", tag, busy_rises);
            end
            if (LEDR[0] !== 1'b0) begin n_err = n_err + 1; $display("LOI [%0s]: busy van = 1 sau done", tag); end
            if (LEDR[1] !== 1'b1) begin n_err = n_err + 1; $display("LOI [%0s]: done khong duoc chot", tag); end
            if (inject && EXPECT_FAIL_WITH_ERR) begin
                if (LEDR[2] !== 1'b1) begin n_err = n_err + 1; $display("LOI [%0s]: mong doi fail = 1", tag); end
            end else begin
                if (LEDR[2] !== 1'b0) begin n_err = n_err + 1; $display("LOI [%0s]: fail = 1 voi loi <= T hoac khong loi", tag); end
            end
            check_hex_valid(tag);

            // done duoc chot du lau de quan sat
            snap = LEDR; hold_ok = 1'b1; hold_cnt = 0;
            while (hold_ok && hold_cnt < HOLD_CYCLES) begin
                @(posedge MAX10_CLK1_50);
                hold_cnt = hold_cnt + 1;
                if (LEDR !== snap) hold_ok = 1'b0;
            end
            n_chk = n_chk + 1;
            if (!hold_ok) begin
                n_err = n_err + 1; $display("LOI [%0s]: LEDR thay doi sau %0d chu ky (done/fail phai duoc chot)", tag, hold_cnt);
            end
        end
    endtask

    // ------------------------------------------------------------ test chinh
    initial begin
        for (i = 0; i < K; i = i + 1) blk[i] = 8'h10 + i;

        // ---- Khoi dong: giu KEY[0] de reset
        KEY = 2'b01; SW = 10'b0;
        wait_cycles(10);
        n_chk = n_chk + 1;
        KEY[0] = 1'b1;
        wait_cycles(20);
        check_leds(3'b000, "khoi dong");
        check_hex_valid("khoi dong");

        // ---- Giao dich khong tao loi
        run_transaction(1'b0, "khong tao loi");

        // ---- Reset sau done: xoa LED
        do_reset;
        check_leds(3'b000, "reset sau done");

        // ---- Giao dich co tao loi (SW[9] = 1)
        run_transaction(1'b1, "tao loi SW[9]=1");

        // ---- Reset trong luc busy (neu bat duoc busy)
        do_reset;
        enter_block;
        SW[8] = 1'b1; SW[9] = 1'b1;
        wait_cycles(100);
        busy_seen = 1'b0;
        KEY[1] = 1'b0;
        w = 0;
        while (LEDR[0] !== 1'b1 && w < RUN_TIMEOUT) begin @(posedge MAX10_CLK1_50); w = w + 1; end
        if (LEDR[0] === 1'b1) begin
            KEY[0] = 1'b0;
            wait_cycles(10);
            KEY[0] = 1'b1;
            KEY[1] = 1'b1;
            wait_cycles(20);
            check_leds(3'b000, "reset luc busy");
        end else begin
            $display("GHI CHU: khong bat duoc busy kip truoc done, bo qua kiem tra reset luc busy (can trace noi bo).");
            KEY[1] = 1'b1;
        end
        wait_cycles(PRESS_CYCLES);

        // ---- Sau reset, chay lai dung
        run_transaction(1'b0, "chay lai sau reset");

        n_chk = n_chk + 1;
        if (led_x) begin n_err = n_err + 1; $display("LOI: LEDR co gia tri X/Z trong luc mo phong"); end

        $display("------------------------------------------------------------");
        if (n_err == 0) $display("[PASS] tb_top : %0d kiem tra, 0 loi", n_chk);
        else            $display("[FAIL] tb_top : %0d kiem tra, %0d loi", n_chk, n_err);
        $display("------------------------------------------------------------");
        $finish;
    end

    initial begin
        repeat (20000) #1_000_000;      // tong cong 20 s thoi gian mo phong
        $display("[FAIL] tb_top: het thoi gian mo phong");
        $finish;
    end

endmodule
