`timescale 1ns/1ps

module tb_rs_decoder;
    reg         clk   = 1'b0;
    reg         rst_n = 1'b0;
    reg         start = 1'b0;
    reg  [14:0] rx_in = 15'd0;
    wire        busy, done, fail;
    wire [14:0] corr_out;
    integer     pos, mag, err = 0;

    rs_decoder dut (
        .clk(clk), .rst_n(rst_n), .start(start), .rx_in(rx_in),
        .busy(busy), .done(done), .fail(fail), .corr_out(corr_out)
    );

    always #10 clk = ~clk; // 50 MHz

    reg [14:0] cw, rx;

    task run_dec;
        input [14:0] din;
        input        exp_fail;
        input [14:0] exp_out;
        begin
            @(negedge clk);
            rx_in = din;
            start = 1'b1;
            @(negedge clk);
            start = 1'b0;
            @(posedge done);
            #1;
            if (fail !== exp_fail || (!exp_fail && corr_out !== exp_out)) begin
                err = err + 1;
                $display("LOI: fail=%b (mong doi %b), out=%o (mong doi %o)", fail, exp_fail, corr_out, exp_out);
            end
        end
    endtask

    initial begin
        $dumpfile("tb_rs_decoder.vcd");
        $dumpvars(0, tb_rs_decoder);

        // Tu ma chuan cua du lieu [1, 2, 3] -> [1, 2, 3, 4, 4]
        cw = {3'd4, 3'd4, 3'd3, 3'd2, 3'd1};

        rst_n = 1'b0; #40; rst_n = 1'b1; #20;

        // 1. Truong hop khong co loi
        run_dec(cw, 1'b0, cw);

        // 2. Kiem tra tat ca 5 vi tri x 7 gia tri loi don (trong nguong T=1)
        for (pos = 0; pos < 5; pos = pos + 1) begin
            for (mag = 1; mag < 8; mag = mag + 1) begin
                rx = cw;
                rx[3*pos +: 3] = rx[3*pos +: 3] ^ mag[2:0];
                run_dec(rx, 1'b0, cw);
            end
        end

        // 3. Truong hop 2 loi giong nhau (S0=0, S1!=0 -> L=2 > T=1) -> bao fail = 1
        rx = cw;
        rx[11:9]  = rx[11:9]  ^ 3'd5;
        rx[14:12] = rx[14:12] ^ 3'd5;
        run_dec(rx, 1'b1, rx);

        // 4. Truong hop 3 loi tai 3 symbol cuoi -> bao fail = 1
        rx = cw;
        rx[8:6]   = rx[8:6]   ^ 3'd1;
        rx[11:9]  = rx[11:9]  ^ 3'd2;
        rx[14:12] = rx[14:12] ^ 3'd3;
        run_dec(rx, 1'b1, rx);

        if (err == 0) $display("[PASS] tb_rs_decoder: Giai ma RS(5,3) dung toan bo cac truong hop!");
        else          $display("[FAIL] tb_rs_decoder: Co %0d loi!", err);
        $finish;
    end
endmodule
