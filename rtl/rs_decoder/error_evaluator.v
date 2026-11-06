// Omega(z) = [S(z) * Lambda(z)] mod z^R.
// He so bac thap truoc: syn[j], lambda[j], omega[j] o [8*j +: 8].
// start chi duoc chap nhan khi !busy; dau vao duoc chot tai start.
// Tinh mot he so moi chu ky: R chu ky sau canh chap nhan start.
// done la xung 1 chu ky; omega hop le tai done va giu den start ke tiep.
// He so lambda[j] voi j > lambda_deg bi bo qua.
// Kiem tra bac Lambda/Omega va kha nang sua loi thuoc decoder dieu phoi.
`include "rs_params.vh"

module error_evaluator (
    input  wire                       clk,
    input  wire                       rst_n,
    input  wire                       start,
    input  wire [8*`RS_R-1:0]         syn,
    input  wire [8*(`RS_R+1)-1:0]     lambda,
    input  wire [3:0]                 lambda_deg,
    output wire                       busy,
    output reg                        done,
    output reg [8*`RS_R-1:0]          omega
);
    localparam integer R = `RS_R;
    localparam integer CNT_W = $clog2(R + 1);

    reg running;
    reg [CNT_W-1:0] q;
    reg [8*R-1:0] s;
    reg [8*(R+1)-1:0] lam;
    reg [3:0] deg;
    assign busy = running;

    // Tich chap: omega[q] = XOR_j lambda[j] * S[q-j].
    wire [7:0] product [0:R-1];
    wire [7:0] sum [0:R];
    assign sum[0] = 8'h00;
    genvar j;
    generate
        for (j = 0; j < R; j = j + 1) begin : gen_convolution
            wire [7:0] sj;
            assign sj = (q >= j) ? s[8*(q-j) +: 8] : 8'h00;
            gf256_mul u_mul (
                .a((j <= deg) ? lam[8*j +: 8] : 8'h00),
                .b(sj), .y(product[j])
            );
            gf256_add u_add (.a(sum[j]), .b(product[j]), .y(sum[j+1]));
        end
    endgenerate

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            running <= 1'b0;
            done    <= 1'b0;
            q       <= {CNT_W{1'b0}};
            s       <= {8*R{1'b0}};
            lam     <= {8*(R+1){1'b0}};
            deg     <= 4'd0;
            omega   <= {8*R{1'b0}};
        end else begin
            done <= 1'b0;
            if (!running) begin
                if (start) begin
                    s       <= syn;
                    lam     <= lambda;
                    deg     <= lambda_deg;
                    q       <= {CNT_W{1'b0}};
                    omega   <= {8*R{1'b0}};
                    running <= 1'b1;
                end
            end else begin
                omega[8*q +: 8] <= sum[R];
                if (q == R - 1) begin
                    running <= 1'b0;
                    done    <= 1'b1;
                end else begin
                    q <= q + 1'b1;
                end
            end
        end
    end
endmodule