`timescale 1ns/1ps

module tb_syndrome;
    reg         clk   = 1'b0;
    reg         rst_n = 1'b0;
    reg         start = 1'b0;
    reg  [14:0] rx_in = 15'd0;
    wire        busy, done, syn_zero;
    wire  [5:0] syn;
    integer     err = 0;

    syndrome dut (
        .clk(clk), .rst_n(rst_n), .start(start), .rx_in(rx_in),
        .busy(busy), .done(done), .syn(syn), .syn_zero(syn_zero)
    );

    always #10 clk = ~clk;

    reg [14:0] cw, rx;

    task run_syn;
        input [14:0] data;
        input  [5:0] exp_syn;
        input        exp_zero;
        begin
            @(negedge clk);
            rx_in = data;
            start = 1'b1;
            @(negedge clk);
            start = 1'b0;
            @(posedge done);
            #1;
            if (syn !== exp_syn || syn_zero !== exp_zero) begin
                err = err + 1;
                $display("LOI: syn=%o, syn_zero=%b (mong doi %o, %b)", syn, syn_zero, exp_syn, exp_zero);
            end
        end
    endtask

    initial begin
        $dumpfile("tb_syndrome.vcd");
        $dumpvars(0, tb_syndrome);

        cw = {3'd4, 3'd4, 3'd3, 3'd2, 3'd1}; // [1, 2, 3, 4, 4]
        rst_n = 1'b0; #40; rst_n = 1'b1; #20;

        // Case 1: Tu ma khong loi -> S = 0
        run_syn(cw, 6'd0, 1'b1);

        // Case 2: Chen 1 loi (5) tai vi tri 0 -> S0=5, S1=3 -> {3'd3, 3'd5}
        rx = cw;
        rx[2:0] = rx[2:0] ^ 3'd5;
        run_syn(rx, {3'd3, 3'd5}, 1'b0);

        // Case 3: Chen 1 loi (5) tai vi tri 4 -> S0=5, S1=5 -> {3'd5, 3'd5}
        rx = cw;
        rx[14:12] = rx[14:12] ^ 3'd5;
        run_syn(rx, {3'd5, 3'd5}, 1'b0);

        if (err == 0) $display("[PASS] tb_syndrome: Tinh Syndrome RS(5,3) dung!");
        else          $display("[FAIL] tb_syndrome: Co %0d loi!", err);
        $finish;
    end
endmodule
