// Thuat toan Berlekamp-Massey tim da thuc dinh vi loi Lambda(z) cho RS(5,3)
`include "rs_params.vh"

module berlekamp_massey (
    input  wire       clk,
    input  wire       rst_n,
    input  wire       start,
    input  wire [5:0] syn,

    output wire       busy,
    output reg        done,
    output reg  [8:0] lambda,     // {C[2], C[1], C[0]}
    output reg  [2:0] lambda_deg,
    output reg        fail
);
    localparam integer R = `RS_R; // 2
    localparam integer T = `RS_T; // 1

    localparam [1:0] S_IDLE = 2'd0, S_DISC = 2'd1, S_UPDATE = 2'd2, S_FINISH = 2'd3;

    reg [1:0] state;
    reg [1:0] q, shift;
    reg [2:0] L;
    reg [2:0] b, d_reg;
    reg [2:0] C [0:2];
    reg [2:0] B [0:2];
    reg [2:0] s_reg [0:1];

    assign busy = (state != S_IDLE);

    // Tinh discrepancy: d = S[q] ^ C[1]*S[q-1] (voi R=2, q chi co gia tri 0 hoac 1)
    wire [2:0] c1_active = (q == 2'd1 && L >= 3'd1) ? C[1] : 3'd0;
    wire [2:0] d_mul1;
    gf8_mul u_dmul1 (.a(c1_active), .b(s_reg[0]), .y(d_mul1));
    wire [2:0] d_comb = (q == 2'd0) ? s_reg[0] : (s_reg[1] ^ d_mul1);

    // Tinh scale = d_reg / b va scale * B[j]
    wire [2:0] b_inv, scale;
    gf8_inv u_binv (.a(b), .y(b_inv), .valid(), .zero_err());
    gf8_mul u_smul (.a(d_reg), .b(b_inv), .y(scale));

    wire [2:0] sc_mul0, sc_mul1, sc_mul2;
    gf8_mul u_bmul0 (.a(scale), .b(B[0]), .y(sc_mul0));
    gf8_mul u_bmul1 (.a(scale), .b(B[1]), .y(sc_mul1));
    gf8_mul u_bmul2 (.a(scale), .b(B[2]), .y(sc_mul2));

    wire is_syn_all_zero = (s_reg[0] == 3'd0) && (s_reg[1] == 3'd0);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state      <= S_IDLE;
            done       <= 1'b0;
            q          <= 2'd0;
            L          <= 3'd0;
            shift      <= 2'd1;
            b          <= 3'd1;
            d_reg      <= 3'd0;
            lambda     <= 9'd0;
            lambda_deg <= 3'd0;
            fail       <= 1'b0;
            C[0] <= 3'd0; C[1] <= 3'd0; C[2] <= 3'd0;
            B[0] <= 3'd0; B[1] <= 3'd0; B[2] <= 3'd0;
            s_reg[0] <= 3'd0;
            s_reg[1] <= 3'd0;
        end else begin
            done <= 1'b0;

            case (state)
                S_IDLE: begin
                    if (start) begin
                        s_reg[0] <= syn[2:0];
                        s_reg[1] <= syn[5:3];
                        C[0]     <= 3'd1; C[1] <= 3'd0; C[2] <= 3'd0;
                        B[0]     <= 3'd1; B[1] <= 3'd0; B[2] <= 3'd0;
                        L        <= 3'd0;
                        shift    <= 2'd1;
                        b        <= 3'd1;
                        q        <= 2'd0;
                        state    <= S_DISC;
                    end
                end

                S_DISC: begin
                    d_reg <= d_comb;
                    state <= S_UPDATE;
                end

                S_UPDATE: begin
                    if (d_reg == 3'd0) begin
                        shift <= shift + 2'd1;
                    end else begin
                        if (shift == 2'd1) begin
                            C[1] <= C[1] ^ sc_mul0;
                            C[2] <= C[2] ^ sc_mul1;
                        end else if (shift == 2'd2) begin
                            C[2] <= C[2] ^ sc_mul0;
                        end

                        if (2 * L <= q) begin
                            L     <= ({1'b0, q} + 3'd1) - L;
                            B[0]  <= C[0];
                            B[1]  <= C[1];
                            B[2]  <= C[2];
                            b     <= d_reg;
                            shift <= 2'd1;
                        end else begin
                            shift <= shift + 2'd1;
                        end
                    end

                    if (q == R - 1) begin
                        state <= S_FINISH;
                    end else begin
                        q     <= q + 2'd1;
                        state <= S_DISC;
                    end
                end

                S_FINISH: begin
                    lambda     <= {C[2], C[1], C[0]};
                    lambda_deg <= L;
                    fail       <= (!is_syn_all_zero) && (L == 3'd0 || L > T);
                    done       <= 1'b1;
                    state      <= S_IDLE;
                end

                default: state <= S_IDLE;
            endcase
        end
    end
endmodule
