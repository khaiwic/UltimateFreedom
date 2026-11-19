`timescale 1ns/1ps

module tb_gf8_mul;
    reg  [2:0] a, b;
    wire [2:0] y;
    integer    i, j, err = 0;

    gf8_mul dut (.a(a), .b(b), .y(y));

    function [2:0] ref_mul;
        input [2:0] x, z;
        reg   [2:0] xx, acc;
        integer     k;
        begin
            xx  = x;
            acc = 3'd0;
            for (k = 0; k < 3; k = k + 1) begin
                if (z[k])
                    acc = acc ^ xx;
                xx = xx[2] ? ({xx[1:0], 1'b0} ^ 3'b011) : {xx[1:0], 1'b0};
            end
            ref_mul = acc;
        end
    endfunction

    task check_mul;
        input [2:0] in_a, in_b, exp_y;
        begin
            a = in_a; b = in_b; #10;
            if (y !== exp_y) begin
                err = err + 1;
                $display("LOI: %0d * %0d = %0d (mong doi %0d)", in_a, in_b, y, exp_y);
            end
        end
    endtask

    initial begin
        $dumpfile("tb_gf8_mul.vcd");
        $dumpvars(0, tb_gf8_mul);

        // Kiem tra cac cap dac trung
        check_mul(3'd0, 3'd5, 3'd0);
        check_mul(3'd1, 3'd7, 3'd7);
        check_mul(3'd2, 3'd4, 3'd3);
        check_mul(3'd2, 3'd5, 3'd1);
        check_mul(3'd3, 3'd6, 3'd1);

        // Kiem tra day du 8 x 8 = 64 cap trong GF(8)
        for (i = 0; i < 8; i = i + 1) begin
            for (j = 0; j < 8; j = j + 1) begin
                check_mul(i[2:0], j[2:0], ref_mul(i[2:0], j[2:0]));
            end
        end

        if (err == 0) $display("[PASS] tb_gf8_mul: Tat ca 64 phep nhan GF(8) deu dung!");
        else          $display("[FAIL] tb_gf8_mul: Co %0d loi!", err);
        $finish;
    end
endmodule
