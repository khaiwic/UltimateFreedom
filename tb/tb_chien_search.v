`timescale 1ns/1ps

module tb_chien_search;
    reg        clk   = 1'b0;
    reg        rst_n = 1'b0;
    reg        start = 1'b0;
    reg  [8:0] lambda = 9'd0;
    reg  [2:0] lambda_deg = 3'd0;
    wire       busy, done, fail;
    wire [4:0] err_mask;
    wire [2:0] err_count;
    integer    err = 0;

    chien_search dut (
        .clk(clk), .rst_n(rst_n), .start(start),
        .lambda(lambda), .lambda_deg(lambda_deg),
        .busy(busy), .done(done), .err_mask(err_mask), .err_count(err_count), .fail(fail)
    );

    always #10 clk = ~clk;

    task run_chien;
        input [8:0] lam_in;
        input [2:0] deg_in;
        input [4:0] exp_mask;
        input [2:0] exp_cnt;
        input       exp_fail;
        begin
            @(negedge clk);
            lambda = lam_in; lambda_deg = deg_in; start = 1'b1;
            @(negedge clk);
            start = 1'b0;
            @(posedge done);
            #1;
            if (err_mask !== exp_mask || err_count !== exp_cnt || fail !== exp_fail) begin
                err = err + 1;
                $display("LOI: mask=%b, cnt=%0d, fail=%b (mong doi %b, %0d, %b)",
                         err_mask, err_count, fail, exp_mask, exp_cnt, exp_fail);
            end
        end
    endtask

    initial begin
        $dumpfile("tb_chien_search.vcd");
        $dumpvars(0, tb_chien_search);

        rst_n = 1'b0; #40; rst_n = 1'b1; #20;

        // Case 1: Khong loi -> mask = 0
        run_chien({3'd0, 3'd0, 3'd1}, 3'd0, 5'b00000, 3'd0, 1'b0);

        // Case 2: Lambda = 1 + 6z -> loi o vi tri 0 (mask = 5'b00001)
        run_chien({3'd0, 3'd6, 3'd1}, 3'd1, 5'b00001, 3'd1, 1'b0);

        // Case 3: Lambda = 1 + 1z -> loi o vi tri 4 (mask = 5'b10000)
        run_chien({3'd0, 3'd1, 3'd1}, 3'd1, 5'b10000, 3'd1, 1'b0);

        // Case 4: Nghiem nam ngoai vung rut gon RS(5,3) (Lambda = 1 + 7z) -> fail = 1
        run_chien({3'd0, 3'd7, 3'd1}, 3'd1, 5'b00000, 3'd0, 1'b1);

        if (err == 0) $display("[PASS] tb_chien_search: Tim vi tri loi RS(5,3) dung!");
        else          $display("[FAIL] tb_chien_search: Co %0d loi!", err);
        $finish;
    end
endmodule
