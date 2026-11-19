`timescale 1ns/1ps

module tb_top;
    localparam integer SIM_DEBOUNCE = 5;
    localparam integer SIM_BLINK    = 4;
    localparam integer PRESS_CYCLES = 15;

    reg        clk = 1'b0;
    reg  [1:0] KEY = 2'b11;
    reg  [9:0] SW  = 10'd0;
    wire [9:0] LEDR;
    wire [7:0] HEX0, HEX1, HEX2;
    integer    k, saw_on, saw_off, err = 0;

    top_de10_lite #(
        .DEBOUNCE_MAX (SIM_DEBOUNCE),
        .BLINK_BIT    (SIM_BLINK)
    ) dut (
        .MAX10_CLK1_50 (clk),
        .KEY           (KEY),
        .SW            (SW),
        .LEDR          (LEDR),
        .HEX0          (HEX0),
        .HEX1          (HEX1),
        .HEX2          (HEX2)
    );

    always #10 clk = ~clk; // 50 MHz

    task press_key1;
        begin
            KEY[1] = 1'b0; repeat (PRESS_CYCLES) @(posedge clk);
            KEY[1] = 1'b1; repeat (PRESS_CYCLES) @(posedge clk);
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

        // Cho ma hoa & giai ma hoan tat
        repeat (40) @(posedge clk);

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

        repeat (40) @(posedge clk);
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

        repeat (40) @(posedge clk);
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

        repeat (40) @(posedge clk);
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

        if (err == 0) $display("[PASS] tb_top: Toan bo he thong RS(5,3) tren DE10-Lite hoat dong dung!");
        else          $display("[FAIL] tb_top: Co %0d loi!", err);
        $finish;
    end
endmodule
