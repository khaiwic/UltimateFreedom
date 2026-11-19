// Bo ma hoa Reed-Solomon RS(5,3) tren GF(8) dung LFSR
// Da thuc sinh: g(x) = (x + 1)(x + 2) = x^2 + 3x + 2
`include "rs_params.vh"

module rs_encoder (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        start,
    input  wire  [8:0] data_in,   // 3 symbol du lieu: [2:0]=sym0, [5:3]=sym1, [8:6]=sym2
    output wire        busy,
    output reg         done,
    output reg  [14:0] code_out   // 5 symbol tu ma: {p1, p0, sym2, sym1, sym0}
);
    localparam integer K = `RS_K; // 3

    reg       running;
    reg [1:0] cnt;
    reg [8:0] d_buf;
    reg [2:0] p0, p1;
    reg [2:0] cur_sym;

    assign busy = running;

    always @(*) begin
        case (cnt)
            2'd0:    cur_sym = d_buf[2:0];
            2'd1:    cur_sym = d_buf[5:3];
            2'd2:    cur_sym = d_buf[8:6];
            default: cur_sym = 3'd0;
        endcase
    end

    wire [2:0] feedback = cur_sym ^ p0;
    wire [2:0] m0, m1;

    // Nhan voi he so cua g(x) = x^2 + 3x + 2
    gf8_mul u_mul0 (.a(feedback), .b(3'd3), .y(m0));
    gf8_mul u_mul1 (.a(feedback), .b(3'd2), .y(m1));

    wire [2:0] next0 = p1 ^ m0;
    wire [2:0] next1 = m1;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            running  <= 1'b0;
            cnt      <= 2'd0;
            d_buf    <= 9'd0;
            p0       <= 3'd0;
            p1       <= 3'd0;
            code_out <= 15'd0;
            done     <= 1'b0;
        end else begin
            done <= 1'b0;

            if (!running) begin
                if (start) begin
                    d_buf   <= data_in;
                    cnt     <= 2'd0;
                    p0      <= 3'd0;
                    p1      <= 3'd0;
                    running <= 1'b1;
                end
            end else begin
                p0 <= next0;
                p1 <= next1;

                if (cnt == K - 1) begin
                    code_out <= {next1, next0, d_buf};
                    running  <= 1'b0;
                    done     <= 1'b1;
                end else begin
                    cnt <= cnt + 2'd1;
                end
            end
        end
    end
endmodule
