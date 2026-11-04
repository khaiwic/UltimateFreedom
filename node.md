module top_de10_lite (
    input  wire       MAX10_CLK1_50,
    input  wire [1:0] KEY,
    input  wire [9:0] SW,
    output wire [2:0] LEDR,
    output wire [7:0] HEX0,
    output wire [7:0] HEX1
);
    wire clk = MAX10_CLK1_50;
    wire rst_n;

    // 1. Dong bo nut nhan KEY[0] thanh tin hieu reset noi bo rst_n
    reset_sync u_reset_sync (
        .clk       (clk),
        .key_rst_n (KEY[0]),
        .rst_n     (rst_n)
    );

    // 2. Noi clk va rst_n vao khoi rs_encoder
    rs_encoder u_rs_encoder (
        .clk       (clk),
        .rst_n     (rst_n),
        .start     (enc_start),
        .data_in   (enc_data_in),
        .in_valid  (enc_in_valid),
        .in_ready  (enc_in_ready),
        .data_out  (enc_data_out),
        .out_valid (enc_out_valid),
        .out_ready (enc_out_ready),
        .out_last  (enc_out_last),
        .busy      (enc_busy),
        .done      (enc_done)
    );
endmodule