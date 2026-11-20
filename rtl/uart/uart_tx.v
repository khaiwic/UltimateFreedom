// Bo phat UART chuan 8N1 (115200 bps voi clock 50 MHz -> CLKS_PER_BIT = 434)
module uart_tx #(
    parameter integer CLKS_PER_BIT = 434
) (
    input  wire       clk,
    input  wire       rst_n,
    input  wire       tx_start,
    input  wire [7:0] tx_data,
    output wire       tx_busy,
    output reg        tx_serial
);
    localparam [1:0]
        S_IDLE  = 2'd0,
        S_START = 2'd1,
        S_DATA  = 2'd2,
        S_STOP  = 2'd3;

    reg [1:0]  state;
    reg [15:0] clk_cnt;
    reg [2:0]  bit_idx;
    reg [7:0]  data_buf;

    assign tx_busy = (state != S_IDLE);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state     <= S_IDLE;
            clk_cnt   <= 16'd0;
            bit_idx   <= 3'd0;
            data_buf  <= 8'h00;
            tx_serial <= 1'b1;
        end else begin
            case (state)
                S_IDLE: begin
                    tx_serial <= 1'b1;
                    clk_cnt   <= 16'd0;
                    bit_idx   <= 3'd0;
                    if (tx_start) begin
                        data_buf <= tx_data;
                        state    <= S_START;
                    end
                end

                S_START: begin
                    tx_serial <= 1'b0;
                    if (clk_cnt < CLKS_PER_BIT - 1) begin
                        clk_cnt <= clk_cnt + 16'd1;
                    end else begin
                        clk_cnt <= 16'd0;
                        state   <= S_DATA;
                    end
                end

                S_DATA: begin
                    tx_serial <= data_buf[bit_idx];
                    if (clk_cnt < CLKS_PER_BIT - 1) begin
                        clk_cnt <= clk_cnt + 16'd1;
                    end else begin
                        clk_cnt <= 16'd0;
                        if (bit_idx == 3'd7)
                            state <= S_STOP;
                        else
                            bit_idx <= bit_idx + 3'd1;
                    end
                end

                S_STOP: begin
                    tx_serial <= 1'b1;
                    if (clk_cnt < CLKS_PER_BIT - 1) begin
                        clk_cnt <= clk_cnt + 16'd1;
                    end else begin
                        clk_cnt <= 16'd0;
                        state   <= S_IDLE;
                    end
                end

                default: state <= S_IDLE;
            endcase
        end
    end
endmodule
