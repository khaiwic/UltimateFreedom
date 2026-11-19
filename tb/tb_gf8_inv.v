`timescale 1ns/1ps

module tb_gf8_inv;
    reg  [2:0] a;
    wire [2:0] y;
    wire       valid, zero_err;
    integer    err = 0;

    gf8_inv dut (.a(a), .y(y), .valid(valid), .zero_err(zero_err));

    task check_inv;
        input [2:0] in_a, exp_y;
        input       exp_valid, exp_zero;
        begin
            a = in_a; #10;
            if (y !== exp_y || valid !== exp_valid || zero_err !== exp_zero) begin
                err = err + 1;
                $display("LOI: inv(%0d) = %0d, valid=%b, zero=%b", in_a, y, valid, zero_err);
            end
        end
    endtask

    initial begin
        $dumpfile("tb_gf8_inv.vcd");
        $dumpvars(0, tb_gf8_inv);

        check_inv(3'd0, 3'd0, 1'b0, 1'b1);
        check_inv(3'd1, 3'd1, 1'b1, 1'b0);
        check_inv(3'd2, 3'd5, 1'b1, 1'b0);
        check_inv(3'd3, 3'd6, 1'b1, 1'b0);
        check_inv(3'd4, 3'd7, 1'b1, 1'b0);
        check_inv(3'd5, 3'd2, 1'b1, 1'b0);
        check_inv(3'd6, 3'd3, 1'b1, 1'b0);
        check_inv(3'd7, 3'd4, 1'b1, 1'b0);

        if (err == 0) $display("[PASS] tb_gf8_inv: Tat ca 8 phep nghich dao GF(8) deu dung!");
        else          $display("[FAIL] tb_gf8_inv: Co %0d loi!", err);
        $finish;
    end
endmodule
