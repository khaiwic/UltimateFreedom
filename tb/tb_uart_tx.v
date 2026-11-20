`timescale 1ns/1ps

module tb_uart_tx;
    localparam integer CLKS_PER_BIT = 434; // 115200 bps voi clock 50 MHz

    reg        clk      = 1'b0;
    reg        rst_n    = 1'b0;
    reg        tx_start = 1'b0;
    reg  [7:0] tx_data  = 8'h00;
    wire       tx_busy;
    wire       tx_serial;
    integer    b, err = 0;
    reg  [7:0] rx_byte;

    uart_tx #(
        .CLKS_PER_BIT (CLKS_PER_BIT)
    ) dut (
        .clk       (clk),
        .rst_n     (rst_n),
        .tx_start  (tx_start),
        .tx_data   (tx_data),
        .tx_busy   (tx_busy),
        .tx_serial (tx_serial)
    );

    always #10 clk = ~clk; // 50 MHz

    task send_and_check;
        input [7:0] exp_byte;
        begin
            @(negedge clk);
            tx_data  = exp_byte;
            tx_start = 1'b1;
            @(negedge clk);
            tx_start = 1'b0;

            @(negedge tx_serial);
            if (tx_busy !== 1'b1) begin
                err = err + 1;
                $display("LOI: tx_busy phai bang 1 khi bat dau truyen");
            end

            // Lay mau giua bit Start
            repeat (CLKS_PER_BIT / 2) @(posedge clk);
            if (tx_serial !== 1'b0) begin
                err = err + 1;
                $display("LOI: Bit Start khong bang 0 cho byte %h", exp_byte);
            end

            // Lay mau 8 bit du lieu (LSB truoc)
            rx_byte = 8'h00;
            for (b = 0; b < 8; b = b + 1) begin
                repeat (CLKS_PER_BIT) @(posedge clk);
                rx_byte[b] = tx_serial;
            end

            // Lay mau giua bit Stop
            repeat (CLKS_PER_BIT) @(posedge clk);
            if (tx_serial !== 1'b1) begin
                err = err + 1;
                $display("LOI: Bit Stop khong bang 1 cho byte %h", exp_byte);
            end

            if (rx_byte !== exp_byte) begin
                err = err + 1;
                $display("LOI: Thu duoc %h (mong doi %h)", rx_byte, exp_byte);
            end

            wait (tx_busy == 1'b0);
            repeat (10) @(posedge clk);
        end
    endtask

    initial begin
        $dumpfile("tb_uart_tx.vcd");
        $dumpvars(0, tb_uart_tx);

        rst_n = 1'b0; #100; rst_n = 1'b1; #100;
        if (tx_serial !== 1'b1) begin
            err = err + 1;
            $display("LOI: tx_serial khi nghi phai bang 1");
        end

        send_and_check(8'h55);
        send_and_check(8'hAA);
        send_and_check(8'h41); // 'A'
        send_and_check(8'h00);
        send_and_check(8'hFF);

        if (err == 0) $display("[PASS] tb_uart_tx: Phat UART 8N1 (115200 bps) dung!");
        else          $display("[FAIL] tb_uart_tx: Co %0d loi!", err);
        $finish;
    end
endmodule
