// berlekamp_massey.v
// Tim da thuc dinh vi loi Lambda(z) bang thuat toan Berlekamp-Massey.
//
// Quy uoc (docs/rs_algorithm.md muc 7, rs_params.vh):
//   - syn[8*j +: 8] = S[j] (he so z^j, bac thap truoc).
//   - Lambda(z) = 1 + lambda[1]*z + ... + lambda[L]*z^L.
//   - lambda[8*j +: 8] chua he so bac thap truoc, lambda[0] = 8'h01.
//   - lambda_deg = L (bac thuc cua Lambda).
//   - fail = 1 neu S != 0 va (L == 0 hoac L > T).
//
// Hop dong giao tiep (tb/tb_berlekamp_massey.v):
//   - start: xung 1 chu ky khi busy = 0. Chot syn luc nay.
//   - busy = 1 tu start den done.
//   - done: xung 1 chu ky; ket qua giu den start ke tiep.

`include "rs_params.vh"

module berlekamp_massey (
    input  wire                       clk,
    input  wire                       rst_n,

    input  wire                       start,
    input  wire [8*`RS_R-1:0]         syn,

    output wire                       busy,
    output reg                        done,

    output reg  [8*(`RS_R+1)-1:0]     lambda,
    output reg  [3:0]                 lambda_deg,
    output reg                        fail
);

    localparam integer R = `RS_R;
    localparam integer T = `RS_T;

    localparam [1:0] S_IDLE   = 2'd0,
                     S_DISC   = 2'd1,   // Tinh discrepancy d
                     S_UPDATE = 2'd2,   // Tinh scale = d / b va cap nhat C, B, L
                     S_FINISH = 2'd3;

    reg [1:0]  state;
    reg [2:0]  q;
    reg [3:0]  L;
    reg [2:0]  shift;
    reg [7:0]  b;
    reg [7:0]  d_reg;
    reg [7:0]  C [0:R];
    reg [7:0]  B [0:R];
    reg [7:0]  s_reg [0:R-1];

    assign busy = (state != S_IDLE);

    // ------------------------------------------------------------------------
    // Tinh discrepancy d: d = S[q] ^ sum_{j=1..L} C[j] * S[q-j]
    // ------------------------------------------------------------------------
    wire [7:0] d_mul [1:R];
    wire [7:0] d_sum [0:R];
    assign d_sum[0] = (q < R) ? s_reg[q] : 8'h00;

    genvar gj;
    generate
        for (gj = 1; gj <= R; gj = gj + 1) begin : gen_d_sum
            wire [7:0] sq_j = (q >= gj) ? s_reg[q - gj] : 8'h00;
            gf256_mul u_dmul (
                .a((gj <= L) ? C[gj] : 8'h00),
                .b(sq_j),
                .y(d_mul[gj])
            );
            gf256_add u_dadd (
                .a(d_sum[gj-1]),
                .b(d_mul[gj]),
                .y(d_sum[gj])
            );
        end
    endgenerate

    wire [7:0] d_comb = d_sum[R];

    // ------------------------------------------------------------------------
    // Nghich dao cua b va tinh scale = d / b
    // ------------------------------------------------------------------------
    wire [7:0] b_inv;
    wire       b_inv_valid, b_inv_zero;
    gf256_inv u_binv (
        .a(b),
        .y(b_inv),
        .valid(b_inv_valid),
        .zero_err(b_inv_zero)
    );

    wire [7:0] scale;
    gf256_mul u_scale_mul (
        .a(d_reg),
        .b(b_inv),
        .y(scale)
    );

    // Mang C_next
    wire [7:0] sc_mul [0:R];
    generate
        for (gj = 0; gj <= R; gj = gj + 1) begin : gen_sc_mul
            gf256_mul u_bmul (
                .a(scale),
                .b(B[gj]),
                .y(sc_mul[gj])
            );
        end
    endgenerate

    // Kiem tra syn co toan 0 khong
    wire is_syn_all_zero;
    wire [R-1:0] syn_zero_bits;
    generate
        for (gj = 0; gj < R; gj = gj + 1) begin : gen_syn_zero
            assign syn_zero_bits[gj] = (s_reg[gj] == 8'h00);
        end
    endgenerate
    assign is_syn_all_zero = &syn_zero_bits;

    integer i;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state      <= S_IDLE;
            done       <= 1'b0;
            q          <= 3'd0;
            L          <= 4'd0;
            shift      <= 3'd1;
            b          <= 8'h01;
            d_reg      <= 8'h00;
            lambda     <= {8*(R+1){1'b0}};
            lambda_deg <= 4'd0;
            fail       <= 1'b0;
            for (i = 0; i <= R; i = i + 1) begin
                C[i] <= 8'h00;
                B[i] <= 8'h00;
            end
            for (i = 0; i < R; i = i + 1)
                s_reg[i] <= 8'h00;
        end else begin
            done <= 1'b0;

            case (state)
                S_IDLE: begin
                    if (start) begin
                        for (i = 0; i < R; i = i + 1)
                            s_reg[i] <= syn[8*i +: 8];

                        C[0] <= 8'h01;
                        B[0] <= 8'h01;
                        for (i = 1; i <= R; i = i + 1) begin
                            C[i] <= 8'h00;
                            B[i] <= 8'h00;
                        end

                        L     <= 4'd0;
                        shift <= 3'd1;
                        b     <= 8'h01;
                        q     <= 3'd0;
                        state <= S_DISC;
                    end
                end

                S_DISC: begin
                    d_reg <= d_comb;
                    state <= S_UPDATE;
                end

                S_UPDATE: begin
                    if (d_reg == 8'h00) begin
                        shift <= shift + 1'b1;
                    end else begin
                        // Cap nhat C: C[j + shift] = C[j + shift] ^ scale * B[j]
                        for (i = 0; i <= R; i = i + 1) begin
                            if (i >= shift)
                                C[i] <= C[i] ^ sc_mul[i - shift];
                        end

                        if (2 * L <= q) begin
                            L     <= (q + 1'b1) - L;
                            for (i = 0; i <= R; i = i + 1)
                                B[i] <= C[i];
                            b     <= d_reg;
                            shift <= 3'd1;
                        end else begin
                            shift <= shift + 1'b1;
                        end
                    end

                    if (q == R - 1) begin
                        state <= S_FINISH;
                    end else begin
                        q     <= q + 1'b1;
                        state <= S_DISC;
                    end
                end

                S_FINISH: begin
                    for (i = 0; i <= R; i = i + 1)
                        lambda[8*i +: 8] <= C[i];

                    lambda_deg <= L;
                    fail       <= (!is_syn_all_zero) && (L == 0 || L > T);
                    done       <= 1'b1;
                    state      <= S_IDLE;
                end

                default: state <= S_IDLE;
            endcase
        end
    end

endmodule
