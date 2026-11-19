// Chien Search: quet 5 vi tri de tim nghiem cua Lambda(z) = 0 trong GF(8)
`include "rs_params.vh"

module chien_search (
    input  wire       clk,
    input  wire       rst_n,
    input  wire       start,
    input  wire [8:0] lambda,
    input  wire [2:0] lambda_deg,

    output wire       busy,
    output reg        done,
    output reg  [4:0] err_mask,
    output reg  [2:0] err_count,
    output reg        fail
);
    localparam integer N      = `RS_N; // 5
    localparam [2:0]   Z_INIT = 3'd3;  // alpha^(-4) = alpha^3 = 3 trong GF(8)

    localparam S_IDLE = 1'b0, S_RUN = 1'b1;

    reg       state;
    reg [2:0] cnt, deg, found;
    reg [8:0] lam;
    reg [2:0] z;

    assign busy = (state != S_IDLE);

    // Lay cac he so Lambda[0..deg]
    wire [2:0] c0 = lam[2:0];
    wire [2:0] c1 = (deg >= 3'd1) ? lam[5:3] : 3'd0;
    wire [2:0] c2 = (deg >= 3'd2) ? lam[8:6] : 3'd0;

    // Tinh gia tri Lambda(z) = c2*z^2 + c1*z + c0 bang so do Horner
    wire [2:0] p1, p0, z_next;
    wire [2:0] acc1 = p1 ^ c1;
    wire [2:0] acc0 = p0 ^ c0;

    gf8_mul u_h1 (.a(c2),   .b(z), .y(p1));
    gf8_mul u_h0 (.a(acc1), .b(z), .y(p0));

    gf8_mul u_zstep (.a(z), .b(`GF_ALPHA), .y(z_next));

    wire       is_root    = (acc0 == 3'd0);
    wire [2:0] found_next = found + (is_root ? 3'd1 : 3'd0);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state     <= S_IDLE;
            cnt       <= 3'd0;
            deg       <= 3'd0;
            lam       <= 9'd0;
            z         <= 3'd1;
            found     <= 3'd0;
            done      <= 1'b0;
            err_mask  <= 5'd0;
            err_count <= 3'd0;
            fail      <= 1'b0;
        end else begin
            done <= 1'b0;

            case (state)
                S_IDLE: begin
                    if (start) begin
                        lam       <= lambda;
                        deg       <= lambda_deg;
                        z         <= Z_INIT;
                        cnt       <= 3'd0;
                        found     <= 3'd0;
                        err_mask  <= 5'd0;
                        err_count <= 3'd0;
                        fail      <= 1'b0;
                        state     <= S_RUN;
                    end
                end

                S_RUN: begin
                    err_mask[cnt] <= is_root;
                    found         <= found_next;
                    z             <= z_next;
                    cnt           <= cnt + 3'd1;
                    if (cnt == N - 1) begin
                        err_count <= found_next;
                        fail      <= (found_next != deg);
                        done      <= 1'b1;
                        state     <= S_IDLE;
                    end
                end

                default: state <= S_IDLE;
            endcase
        end
    end
endmodule
