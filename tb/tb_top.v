`timescale 1ns/1ps

module tb_top;
    localparam integer SIM_DEBOUNCE   = 5;
    localparam integer SIM_BLINK      = 4;
    localparam integer SIM_UART_CLKS  = 4;
    localparam integer PRESS_CYCLES   = 15;

    reg        clk = 1'b0;
    reg  [1:0] KEY = 2'b11;
    reg  [9:0] SW  = 10'd0;
    wire [9:0] LEDR;
    wire [7:0] HEX0, HEX1, HEX2;
    wire       UART_TX;
    integer    k, saw_on, saw_off, err = 0;

    // Bien phuc vu thu & kiem tra log UART phat ra chan UART_TX
    integer    uart_rx_cnt = 0;
    integer    uart_bit_idx;
    reg  [7:0] uart_rx_byte;

    top_de10_lite #(
        .DEBOUNCE_MAX      (SIM_DEBOUNCE),
        .BLINK_BIT         (SIM_BLINK),
        .UART_CLKS_PER_BIT (SIM_UART_CLKS)
    ) dut (
        .MAX10_CLK1_50 (clk),
        .KEY           (KEY),
        .SW            (SW),
        .LEDR          (LEDR),
        .HEX0          (HEX0),
        .HEX1          (HEX1),
        .HEX2          (HEX2),
        .UART_TX       (UART_TX)
    );

    always #10 clk = ~clk; // 50 MHz

    // Bo thu UART gia lap Hercules de in chuoi ASCII nhan duoc tu FPGA
    initial begin
        @(posedge KEY[0]);
        forever begin
            @(negedge UART_TX);
            repeat (SIM_UART_CLKS / 2) @(posedge clk);
            if (UART_TX !== 1'b0) begin
                err = err + 1;
                $display("LOI UART: Bit Start sai!");
            end
            uart_rx_byte = 8'h00;
            for (uart_bit_idx = 0; uart_bit_idx < 8; uart_bit_idx = uart_bit_idx + 1) begin
                repeat (SIM_UART_CLKS) @(posedge clk);
                uart_rx_byte[uart_bit_idx] = UART_TX;
            end
            repeat (SIM_UART_CLKS) @(posedge clk);
            if (UART_TX !== 1'b1) begin
                err = err + 1;
                $display("LOI UART: Bit Stop sai!");
            end
            uart_rx_cnt = uart_rx_cnt + 1;
            $write("%c", uart_rx_byte);
        end
    end

    task press_key1;
        begin
            KEY[1] = 1'b0; repeat (PRESS_CYCLES) @(posedge clk);
            KEY[1] = 1'b1; repeat (PRESS_CYCLES) @(posedge clk);
        end
    endtask

    task wait_uart_done;
        begin
            repeat (40) @(posedge clk);
            wait (dut.u_logger.busy == 1'b0);
            repeat (50) @(posedge clk);
        end
    endtask

    initial begin
        $dumpfile("tb_top.vcd");
        $dumpvars(0, tb_top);

        // 1. Reset he thong bang KEY[0]
        KEY[0] = 1'b0; repeat (10) @(posedge clk);
        KEY[0] = 1'b1; repeat (10) @(posedge clk);

        // 2. Che do nhap thong tin (SW[9]=0): nhap 3 symbol 1, 2, 3 bang SW[2:0]
        SW[9] = 1'b0; SW[8] = 1'b0;

        SW[2:0] = 3'd1;
        repeat (5) @(posedge clk);
        if (LEDR !== 10'b0000000010) begin
            err = err + 1;
            $display("LOI LED (sym0=1): LEDR=%b (mong doi 0000000010)", LEDR);
        end
        press_key1;

        SW[2:0] = 3'd2;
        repeat (5) @(posedge clk);
        if (LEDR !== 10'b0000000100) begin
            err = err + 1;
            $display("LOI LED (sym1=2): LEDR=%b (mong doi 0000000100)", LEDR);
        end
        press_key1;

        SW[2:0] = 3'd3;
        repeat (5) @(posedge clk);
        if (LEDR !== 10'b0000001000) begin
            err = err + 1;
            $display("LOI LED (sym2=3): LEDR=%b (mong doi 0000001000)", LEDR);
        end
        press_key1;

        // Cho ma hoa, giai ma va gui log UART hoan tat
        wait_uart_done;

        // Kiem tra 3 LED 7 doan: HEX2='1'(F9), HEX1='2'(A4), HEX0='3'(B0)
        if (HEX2 !== 8'hF9 || HEX1 !== 8'hA4 || HEX0 !== 8'hB0) begin
            err = err + 1;
            $display("LOI HEX: HEX2=%h HEX1=%h HEX0=%h (mong doi F9 A4 B0)", HEX2, HEX1, HEX0);
        end

        // 3. Gat SW[9]=1 sang che do nhap loi:
        //    Test A: Nhap 1 loi (5) vao symbol cuoi, 2 lan sau nhap 0 -> giai ma dung -> tat het LEDR
        SW[9] = 1'b1; SW[8] = 1'b0;
        SW[2:0] = 3'd5; repeat (5) @(posedge clk);
        if (LEDR !== 10'b0000100000) begin
            err = err + 1;
            $display("LOI LED khi nhap loi=5: LEDR=%b", LEDR);
        end
        press_key1;

        SW[2:0] = 3'd0; repeat (5) @(posedge clk); press_key1;
        SW[2:0] = 3'd0; repeat (5) @(posedge clk); press_key1;

        wait_uart_done;
        if (LEDR !== 10'b0000000000) begin
            err = err + 1;
            $display("LOI (1 loi giai ma dung): LEDR=%b (mong doi tat het 0000000000)", LEDR);
        end
        if (HEX2 !== 8'hF9 || HEX1 !== 8'hA4 || HEX0 !== 8'hB0) begin
            err = err + 1;
            $display("LOI HEX sau sua 1 loi: HEX2=%h HEX1=%h HEX0=%h", HEX2, HEX1, HEX0);
        end

        // 4. Test B: Nhan KEY[1] de bat dau dot nhap loi moi, nhap 3 loi (1, 2, 3) -> nhap nhay LEDR
        press_key1; // Reset ket qua cu de nhap 3 loi moi
        SW[2:0] = 3'd1; repeat (5) @(posedge clk); press_key1;
        SW[2:0] = 3'd2; repeat (5) @(posedge clk); press_key1;
        SW[2:0] = 3'd3; repeat (5) @(posedge clk); press_key1;

        wait_uart_done;
        saw_on = 0; saw_off = 0;
        for (k = 0; k < 50; k = k + 1) begin
            @(posedge clk);
            if (LEDR === 10'b1111111111) saw_on  = 1;
            if (LEDR === 10'b0000000000) saw_off = 1;
        end
        if (!saw_on || !saw_off) begin
            err = err + 1;
            $display("LOI (3 loi giai ma sai): LEDR khong nhap nhay (saw_on=%0d, saw_off=%0d)", saw_on, saw_off);
        end

        // 5. Test C: Nhap 2 loi dung SW[8]=1 kich hoat som -> giai ma sai -> nhap nhay LEDR
        SW[8] = 1'b0;
        press_key1; // Reset dot nhap loi
        SW[2:0] = 3'd5; repeat (5) @(posedge clk); press_key1;
        SW[8] = 1'b1; SW[2:0] = 3'd5; repeat (5) @(posedge clk); press_key1;

        wait_uart_done;
        saw_on = 0; saw_off = 0;
        for (k = 0; k < 50; k = k + 1) begin
            @(posedge clk);
            if (LEDR === 10'b1111111111) saw_on  = 1;
            if (LEDR === 10'b0000000000) saw_off = 1;
        end
        if (!saw_on || !saw_off) begin
            err = err + 1;
            $display("LOI (2 loi voi SW[8]=1): LEDR khong nhap nhay (saw_on=%0d, saw_off=%0d)", saw_on, saw_off);
        end

        // Kiem tra so ky tu UART da gui: 4 ban tin x 195 ky tu = 780 ky tu
        if (uart_rx_cnt !== 780) begin
            err = err + 1;
            $display("LOI UART: Tong so ky tu thu duoc = %0d (mong doi 780)", uart_rx_cnt);
        end

        if (err == 0) $display("[PASS] tb_top: Toan bo he thong RS(5,3) + UART Monitor hoat dong dung!");
        else          $display("[FAIL] tb_top: Co %0d loi!", err);
        $finish;
    end
endmodule
