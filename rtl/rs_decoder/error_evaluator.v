// Tinh da thuc gia tri loi Omega(z) = [S(z) * Lambda(z)] mod z^2 cho RS(5,3)
`include "rs_params.vh"

module error_evaluator (
    input  wire       clk,
    input  wire       rst_n,
    input  wire       start,
    input  wire [5:0] syn,
    input  wire [8:0] lambda,
    input  wire [2:0] lambda_deg,

    output wire       busy,
    output reg        done,
    output reg  [5:0] omega
);
    reg       running;
    reg       q;
    reg [5:0] s;
    reg [8:0] lam;
    reg [2:0] deg;

    assign busy = running;

    // Tich chap: omega[q] = XOR_{j=0..1} lambda[j] * S[q-j]
    wire [2:0] lj0 = lam[2:0];
    wire [2:0] sj0 = (q == 1'b0) ? s[2:0] : s[5:3];
    wire [2:0] lj1 = (q == 1'b1 && deg >= 3'd1) ? lam[5:3] : 3'd0;
    wire [2:0] sj1 = s[2:0];

    wire [2:0] prod0, prod1;
    gf8_mul u_mul0 (.a(lj0), .b(sj0), .y(prod0));
    gf8_mul u_mul1 (.a(lj1), .b(sj1), .y(prod1));

    wire [2:0] omega_q = prod0 ^ prod1;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            running <= 1'b0;
            done    <= 1'b0;
            q       <= 1'b0;
            s       <= 6'd0;
            lam     <= 9'd0;
            deg     <= 3'd0;
            omega   <= 6'd0;
        end else begin
            done <= 1'b0;
            if (!running) begin
                if (start) begin
                    s       <= syn;
                    lam     <= lambda;
                    deg     <= lambda_deg;
                    q       <= 1'b0;
                    omega   <= 6'd0;
                    running <= 1'b1;
                end
            end else begin
                if (q == 1'b0) begin
                    omega[2:0] <= omega_q;
                    q          <= 1'b1;
                end else begin
                    omega[5:3] <= omega_q;
                    running    <= 1'b0;
                    done       <= 1'b1;
                end
            end
        end
    end
endmodule
