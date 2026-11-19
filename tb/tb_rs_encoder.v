`timescale 1ns/1ps

module tb_rs_encoder;
    reg         clk   = 1'b0;
    reg         rst_n = 1'b0;
    reg         start = 1'b0;
    reg   [8:0] data_in = 9'd0;
    wire        busy, done;
    wire [14:0] code_out;
    integer     err = 0;

    rs_encoder dut (
        .clk(clk), .rst_n(rst_n), .start(start),
        .data_in(data_in), .busy(busy), .done(done), .code_out(code_out)
    );

    always #10 clk = ~clk; // 50 MHz

    task run_enc;
        input  [8:0] din;
        input [14:0] exp_code;
        begin
            @(negedge clk);
            data_in = din;
            start   = 1'b1;
            @(negedge clk);
            start   = 1'b0;
            @(posedge done);
            #1;
            if (code_out !== exp_code) begin
                err = err + 1;
                $display("LOI: code_out = %o (mong doi %o)", code_out, exp_code);
            end
        end
    endtask

    initial begin
        $dumpfile("tb_rs_encoder.vcd");
        $dumpvars(0, tb_rs_encoder);

        rst_n = 1'b0; #40; rst_n = 1'b1; #20;

        // Case 1: Du lieu toan 0
        run_enc(9'd0, 15'd0);

        // Case 2: Du lieu [1, 2, 3] -> parity [4, 4] -> tu ma [1, 2, 3, 4, 4]
        run_enc({3'd3, 3'd2, 3'd1}, {3'd4, 3'd4, 3'd3, 3'd2, 3'd1});

        // Case 3: Du lieu [5, 6, 7] -> parity [4, 0] -> tu ma [5, 6, 7, 4, 0]
        run_enc({3'd7, 3'd6, 3'd5}, {3'd0, 3'd4, 3'd7, 3'd6, 3'd5});

        // Case 4: Du lieu [7, 7, 7] -> parity [0, 7] -> tu ma [7, 7, 7, 0, 7]
        run_enc({3'd7, 3'd7, 3'd7}, {3'd7, 3'd0, 3'd7, 3'd7, 3'd7});

        if (err == 0) $display("[PASS] tb_rs_encoder: Ma hoa RS(5,3) tren GF(8) dung!");
        else          $display("[FAIL] tb_rs_encoder: Co %0d loi!", err);
        $finish;
    end
endmodule
