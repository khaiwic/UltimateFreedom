// Tinh 2 Syndrome S[0..1] tu tu ma 5 symbol bang so do Horner tren GF(8)
`include "rs_params.vh"

module syndrome (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        start,
    input  wire [14:0] rx_in,

    output wire        busy,
    output reg         done,
    output reg   [5:0] syn,       // [2:0]=S0, [5:3]=S1
    output reg         syn_zero
);
    localparam integer N = `RS_N; // 5

    reg        running;
    reg  [2:0] cnt;
    reg [14:0] rx_buf;
    reg  [2:0] acc0, acc1;
    reg  [2:0] cur_sym;

    assign busy = running;

    always @(*) begin
        case (cnt)
            3'd0:    cur_sym = rx_buf[2:0];
            3'd1:    cur_sym = rx_buf[5:3];
            3'd2:    cur_sym = rx_buf[8:6];
            3'd3:    cur_sym = rx_buf[11:9];
            3'd4:    cur_sym = rx_buf[14:12];
            default: cur_sym = 3'd0;
        endcase
    end

    wire [2:0] m0 = acc0; // alpha^0 = 1
    wire [2:0] m1;
    gf8_mul u_mul1 (.a(acc1), .b(3'd2), .y(m1)); // alpha^1 = 2

    wire [2:0] next0 = m0 ^ cur_sym;
    wire [2:0] next1 = m1 ^ cur_sym;
    wire       is_all_zero = (next0 == 3'd0) && (next1 == 3'd0);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            running  <= 1'b0;
            cnt      <= 3'd0;
            rx_buf   <= 15'd0;
            acc0     <= 3'd0;
            acc1     <= 3'd0;
            syn      <= 6'd0;
            syn_zero <= 1'b1;
            done     <= 1'b0;
        end else begin
            done <= 1'b0;

            if (!running) begin
                if (start) begin
                    rx_buf  <= rx_in;
                    cnt     <= 3'd0;
                    acc0    <= 3'd0;
                    acc1    <= 3'd0;
                    running <= 1'b1;
                end
            end else begin
                acc0 <= next0;
                acc1 <= next1;

                if (cnt == N - 1) begin
                    syn      <= {next1, next0};
                    syn_zero <= is_all_zero;
                    running  <= 1'b0;
                    done     <= 1'b1;
                end else begin
                    cnt <= cnt + 3'd1;
                end
            end
        end
    end
endmodule
