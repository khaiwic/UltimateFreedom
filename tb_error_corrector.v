`timescale 1ns/1ps
`include "rs_params.vh"

module tb_error_corrector;
    localparam integer N = `RS_N;
    reg clk = 0;
    reg rst_n = 0;
    reg start = 0;
    reg [8*N-1:0] received = 0, err_val = 0;
    wire busy, done;
    wire [8*N-1:0] corrected;
    reg [8*N-1:0] original, errors, saved;
    integer i, t, cycles, failures = 0;
    integer seed = 12345;

    error_corrector dut (
        .clk(clk), .rst_n(rst_n), .start(start),
        .received(received), .err_val(err_val),
        .busy(busy), .done(done), .corrected(corrected)
    );
    always #5 clk = ~clk;

    task check;
        input condition;
        input [511:0] message;
        begin
            if (condition !== 1'b1) begin
                failures = failures + 1;
                $display("ERROR: %0s", message);
            end
        end
    endtask

    task run_case;
        input [8*N-1:0] data;
        input [8*N-1:0] mask;
        begin
            @(negedge clk);
            received = data ^ mask; err_val = mask; start = 1;
            @(negedge clk);
            check(busy && !done, "start accepted");
            start = 0; received = {8*N{1'bx}}; err_val = {8*N{1'bx}};
            for (cycles = 0; cycles < N; cycles = cycles + 1) begin
                // A new start while busy must not replace the current block.
                start = (cycles == 0);
                @(negedge clk);
                if (cycles < N-1) check(busy && !done, "scan latency");
            end
            start = 0;
            check(done && !busy, "completion at N cycles");
            check(corrected === data, "restored original codeword");
            saved = corrected;
            repeat (3) begin
                @(negedge clk);
                check(!done && !busy && corrected === saved, "result held, done pulsed");
            end
        end
    endtask

    initial begin
        repeat (2) @(negedge clk);
        check(!busy && !done && corrected == 0, "reset outputs");
        rst_n = 1;
        for (i = 0; i < N; i = i + 1) original[8*i +: 8] = i;
        run_case(original, {8*N{1'b0}});
        for (i = 0; i < N; i = i + 1) begin
            errors = 0; errors[8*i +: 8] = 8'hA6;
            run_case(original, errors);
        end
        for (t = 0; t < 50; t = t + 1) begin
            for (i = 0; i < N; i = i + 1) begin
                original[8*i +: 8] = $random(seed);
                errors[8*i +: 8] = $random(seed);
            end
            run_case(original, errors);
        end
        @(negedge clk); received = original; err_val = errors; start = 1;
        @(negedge clk); start = 0;
        @(negedge clk); rst_n = 0;
        #1; check(!busy && !done && corrected == 0, "asynchronous reset during scan");
        @(negedge clk); rst_n = 1;
        run_case(original, errors);
        if (failures == 0) $display("[PASS] tb_error_corrector");
        else $display("[FAIL] tb_error_corrector: %0d errors", failures);
        $finish;
    end
    initial begin
        #1000000;
        $display("[FAIL] timeout");
        $finish;
    end
endmodule
