`timescale 1ns/1ps

module tb_forney;
    reg         clk   = 1'b0;
    reg         rst_n = 1'b0;
    reg         start = 1'b0;
    reg   [8:0] lambda   = 9'd0;
    reg   [5:0] omega    = 6'd0;
    reg   [4:0] err_mask = 5'd0;
    wire        busy, done, fail;
    wire [14:0] err_val;
    integer     err = 0;

    forney dut (
        .clk(clk), .rst_n(rst_n), .start(start),
        .lambda(lambda), .omega(omega), .err_mask(err_mask),
        .busy(busy), .done(done), .err_val(err_val), .fail(fail)
    );

    always #10 clk = ~clk;

    task run_forney;
        input  [8:0] lam_in;
        input  [5:0] om_in;
        input  [4:0] mask_in;
        input [14:0] exp_val;
        input        exp_fail;
        begin
            @(negedge clk);
            lambda = lam_in; omega = om_in; err_mask = mask_in; start = 1'b1;
            @(negedge clk);
            start = 1'b0;
            @(posedge done);
            #1;
            if (err_val !== exp_val || fail !== exp_fail) begin
                err = err + 1;
                $display("LOI: err_val=%o, fail=%b (mong doi %o, %b)", err_val, fail, exp_val, exp_fail);
            end
        end
    endtask

    initial begin
        $dumpfile("tb_forney.vcd");
        $dumpvars(0, tb_forney);

        rst_n = 1'b0; #40; rst_n = 1'b1; #20;

        // Case 1: Khong co loi
        run_forney({3'd0, 3'd0, 3'd1}, 6'd0, 5'b00000, 15'd0, 1'b0);

        // Case 2: Loi tai vi tri 0 -> E0 = 5
        run_forney({3'd0, 3'd6, 3'd1}, {3'd0, 3'd5}, 5'b00001, {3'd0, 3'd0, 3'd0, 3'd0, 3'd5}, 1'b0);

        // Case 3: Loi tai vi tri 4 -> E4 = 5
        run_forney({3'd0, 3'd1, 3'd1}, {3'd0, 3'd5}, 5'b10000, {3'd5, 3'd0, 3'd0, 3'd0, 3'd0}, 1'b0);

        // Case 4: Dao ham Lambda'(z) = 0 khi co loi -> fail = 1
        run_forney({3'd0, 3'd0, 3'd1}, {3'd0, 3'd5}, 5'b00001, 15'd0, 1'b1);

        if (err == 0) $display("[PASS] tb_forney: Tinh gia tri loi RS(5,3) dung!");
        else          $display("[FAIL] tb_forney: Co %0d loi!", err);
        $finish;
    end
endmodule
