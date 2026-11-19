`timescale 1ns/1ps

module tb_error_evaluator;
    reg        clk   = 1'b0;
    reg        rst_n = 1'b0;
    reg        start = 1'b0;
    reg  [5:0] syn   = 6'd0;
    reg  [8:0] lambda = 9'd0;
    reg  [2:0] lambda_deg = 3'd0;
    wire       busy, done;
    wire [5:0] omega;
    integer    err = 0;

    error_evaluator dut (
        .clk(clk), .rst_n(rst_n), .start(start),
        .syn(syn), .lambda(lambda), .lambda_deg(lambda_deg),
        .busy(busy), .done(done), .omega(omega)
    );

    always #10 clk = ~clk;

    task run_eval;
        input [5:0] s_in;
        input [8:0] lam_in;
        input [2:0] deg_in;
        input [5:0] exp_omega;
        begin
            @(negedge clk);
            syn = s_in; lambda = lam_in; lambda_deg = deg_in; start = 1'b1;
            @(negedge clk);
            start = 1'b0;
            @(posedge done);
            #1;
            if (omega !== exp_omega) begin
                err = err + 1;
                $display("LOI: omega=%o (mong doi %o)", omega, exp_omega);
            end
        end
    endtask

    initial begin
        $dumpfile("tb_error_evaluator.vcd");
        $dumpvars(0, tb_error_evaluator);

        rst_n = 1'b0; #40; rst_n = 1'b1; #20;

        // Case 1: Khong loi -> Omega = 0
        run_eval(6'd0, {3'd0, 3'd0, 3'd1}, 3'd0, 6'd0);

        // Case 2: 1 loi tai sym 0: S={3,5}, Lambda=1+6z -> Omega={0,5}
        run_eval({3'd3, 3'd5}, {3'd0, 3'd6, 3'd1}, 3'd1, {3'd0, 3'd5});

        // Case 3: 1 loi tai sym 4: S={5,5}, Lambda=1+1z -> Omega={0,5}
        run_eval({3'd5, 3'd5}, {3'd0, 3'd1, 3'd1}, 3'd1, {3'd0, 3'd5});

        if (err == 0) $display("[PASS] tb_error_evaluator: Tinh Omega(z) RS(5,3) dung!");
        else          $display("[FAIL] tb_error_evaluator: Co %0d loi!", err);
        $finish;
    end
endmodule
