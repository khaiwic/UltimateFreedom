`timescale 1ns/1ps

module tb_berlekamp_massey;
    reg        clk   = 1'b0;
    reg        rst_n = 1'b0;
    reg        start = 1'b0;
    reg  [5:0] syn   = 6'd0;
    wire       busy, done, fail;
    wire [8:0] lambda;
    wire [2:0] lambda_deg;
    integer    err = 0;

    berlekamp_massey dut (
        .clk(clk), .rst_n(rst_n), .start(start), .syn(syn),
        .busy(busy), .done(done), .lambda(lambda), .lambda_deg(lambda_deg), .fail(fail)
    );

    always #10 clk = ~clk;

    task run_bm;
        input [5:0] s_in;
        input [8:0] exp_lam;
        input [2:0] exp_deg;
        input       exp_fail;
        begin
            @(negedge clk);
            syn   = s_in;
            start = 1'b1;
            @(negedge clk);
            start = 1'b0;
            @(posedge done);
            #1;
            if (lambda !== exp_lam || lambda_deg !== exp_deg || fail !== exp_fail) begin
                err = err + 1;
                $display("LOI: lam=%o, L=%0d, fail=%b (mong doi %o, %0d, %b)",
                         lambda, lambda_deg, fail, exp_lam, exp_deg, exp_fail);
            end
        end
    endtask

    initial begin
        $dumpfile("tb_berlekamp_massey.vcd");
        $dumpvars(0, tb_berlekamp_massey);

        rst_n = 1'b0; #40; rst_n = 1'b1; #20;

        // Case 1: Khong loi (S = 0)
        run_bm(6'd0, {3'd0, 3'd0, 3'd1}, 3'd0, 1'b0);

        // Case 2: 1 loi tai sym 0 (S = {3, 5}) -> Lambda = 1 + 6z, L = 1
        run_bm({3'd3, 3'd5}, {3'd0, 3'd6, 3'd1}, 3'd1, 1'b0);

        // Case 3: 1 loi tai sym 4 (S = {5, 5}) -> Lambda = 1 + z, L = 1
        run_bm({3'd5, 3'd5}, {3'd0, 3'd1, 3'd1}, 3'd1, 1'b0);

        // Case 4: 2 loi S0=0, S1=4 -> L = 2 > T=1 -> fail = 1
        run_bm({3'd4, 3'd0}, {3'd4, 3'd0, 3'd1}, 3'd2, 1'b1);

        if (err == 0) $display("[PASS] tb_berlekamp_massey: Tim Lambda(z) RS(5,3) dung!");
        else          $display("[FAIL] tb_berlekamp_massey: Co %0d loi!", err);
        $finish;
    end
endmodule
