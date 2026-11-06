// forney.v
// Forney: tinh gia tri loi E_i tai cac vi tri loi do Chien search tim duoc.
//
// Cong thuc (docs/rs_algorithm.md muc 10; F = RS_FIRST_ROOT = 0, buoc so mu 1):
//   X_i = alpha^(N-1-i),  z_i = X_i^-1
//   Lambda'(z) = lambda[1] + lambda[3]*z^2 + lambda[5]*z^4 + ...   (dac so 2)
//   E_i = X_i * Omega(z_i) / Lambda'(z_i)
// Phai nhan them X_i (khong dung cong thuc cua F = 1). Neu Lambda'(z_i) = 0 tai mot
// vi tri loi thi bao fail, khong chia cho 0.
//
// Hop dong giao tiep:
//   - start: xung 1 chu ky, chi chap nhan khi busy = 0 (start luc busy bi bo qua).
//     lambda, omega, err_mask duoc chot tai start.
//   - busy = 1 tu luc chap nhan start den khi done.
//   - done: xung 1 chu ky. Cung luc do err_val va fail hop le va duoc giu den start ke tiep.
//   - err_val[8*i +: 8] = E_i tai vi tri loi; 00 tai vi tri khac (va tai vi tri bi fail).
//   - fail = 1 neu co vi tri loi voi Lambda'(z_i) = 0.
//   - Do tre: N chu ky (1 vi tri/chu ky) + 1 chu ky chap nhan start.
//   - rst_n: reset bat dong bo, tich cuc thap.
//
// Duong du lieu moi chu ky (to hop, dung gf256_mul/gf256_add/gf256_inv):
//   x <- x * alpha^-1, z <- z * alpha moi vi tri; Omega(z) va Lambda'(z) bang Horner;
//   E = x * Omega(z) * inv(Lambda'(z)).

`include "rs_params.vh"

module forney (
    input  wire                    clk,
    input  wire                    rst_n,

    input  wire                    start,
    input  wire [8*(`RS_R+1)-1:0]  lambda,
    input  wire [8*`RS_R-1:0]      omega,
    input  wire [`RS_N-1:0]        err_mask,

    output wire                    busy,
    output reg                     done,

    output reg  [8*`RS_N-1:0]      err_val,
    output reg                     fail
);

    localparam integer N     = `RS_N;
    localparam integer R     = `RS_R;
    localparam integer ODD   = (R + 1) / 2;            // so he so bac le cua Lambda
    localparam integer CNT_W = $clog2(N + 1);
    localparam [7:0]   ALPHA = `GF_ALPHA;

    // alpha^e (alpha = 0x02), e bat ky, tinh luc elaboration cho gia tri khoi dau
    function [7:0] alpha_pow;
        input integer e;
        reg [7:0] acc;
        reg [8:0] x;
        integer k, ee;
        begin
            ee = e % `GF_ORDER;
            if (ee < 0) ee = ee + `GF_ORDER;
            acc = 8'h01;
            for (k = 0; k < ee; k = k + 1) begin
                x = {1'b0, acc} << 1;
                if (x[8]) x = x ^ `GF_PRIM_POLY;
                acc = x[7:0];
            end
            alpha_pow = acc;
        end
    endfunction

    localparam [7:0] X_INIT     = alpha_pow(N - 1);    // X_0
    localparam [7:0] Z_INIT     = alpha_pow(-(N - 1)); // z_0 = X_0^-1
    localparam [7:0] ALPHA_INV  = alpha_pow(-1);

    localparam S_IDLE = 1'b0,
               S_RUN  = 1'b1;

    reg                    state;
    reg [CNT_W-1:0]        cnt;
    reg [8*(R+1)-1:0]      lam;
    reg [8*R-1:0]          om;
    reg [N-1:0]            mask;
    reg [7:0]              x, z;
    reg                    fail_acc;

    assign busy = (state != S_IDLE);

    // ---------------- Omega(z): Horner, om_acc[j] = om_acc[j+1]*z + omega[j]
    wire [7:0] om_acc [0:R-1];
    wire [7:0] om_mul [0:R-2];
    assign om_acc[R-1] = om[8*(R-1) +: 8];
    genvar j;
    generate
        for (j = R - 2; j >= 0; j = j - 1) begin : gen_omega
            gf256_mul u_mul (.a(om_acc[j+1]), .b(z), .y(om_mul[j]));
            gf256_add u_add (.a(om_mul[j]), .b(om[8*j +: 8]), .y(om_acc[j]));
        end
    endgenerate

    // ---------------- Lambda'(z) = sum_m lambda[2m+1] * (z^2)^m: Horner theo z^2
    wire [7:0] z2;
    gf256_mul u_z2 (.a(z), .b(z), .y(z2));

    wire [7:0] ld_acc [0:ODD-1];
    wire [7:0] ld_mul [0:ODD-2];
    assign ld_acc[ODD-1] = lam[8*(2*(ODD-1)+1) +: 8];
    generate
        for (j = ODD - 2; j >= 0; j = j - 1) begin : gen_lamd
            gf256_mul u_mul (.a(ld_acc[j+1]), .b(z2), .y(ld_mul[j]));
            gf256_add u_add (.a(ld_mul[j]), .b(lam[8*(2*j+1) +: 8]), .y(ld_acc[j]));
        end
    endgenerate

    wire [7:0] dv = ld_acc[0];

    // ---------------- E = x * Omega(z) / Lambda'(z)
    wire [7:0] dv_inv;
    wire       dv_valid, dv_zero;
    gf256_inv u_inv (.a(dv), .y(dv_inv), .valid(dv_valid), .zero_err(dv_zero));

    wire [7:0] q_val, e_val;
    gf256_mul u_q (.a(om_acc[0]), .b(dv_inv), .y(q_val));
    gf256_mul u_e (.a(x),         .b(q_val),  .y(e_val));

    wire [7:0] x_next, z_next;
    gf256_mul u_xstep (.a(x), .b(ALPHA_INV), .y(x_next));
    gf256_mul u_zstep (.a(z), .b(ALPHA),     .y(z_next));

    wire is_err   = mask[cnt];
    wire bad_here = is_err && dv_zero;
    wire [7:0] val_here = (is_err && !dv_zero) ? e_val : 8'h00;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state    <= S_IDLE;
            cnt      <= {CNT_W{1'b0}};
            lam      <= {8*(R+1){1'b0}};
            om       <= {8*R{1'b0}};
            mask     <= {N{1'b0}};
            x        <= 8'h01;
            z        <= 8'h01;
            fail_acc <= 1'b0;
            done     <= 1'b0;
            err_val  <= {8*N{1'b0}};
            fail     <= 1'b0;
        end else begin
            done <= 1'b0;

            case (state)
                S_IDLE: begin
                    if (start) begin
                        lam      <= lambda;
                        om       <= omega;
                        mask     <= err_mask;
                        x        <= X_INIT;
                        z        <= Z_INIT;
                        cnt      <= {CNT_W{1'b0}};
                        fail_acc <= 1'b0;
                        err_val  <= {8*N{1'b0}};
                        fail     <= 1'b0;
                        state    <= S_RUN;
                    end
                end

                S_RUN: begin
                    err_val[8*cnt +: 8] <= val_here;
                    fail_acc            <= fail_acc | bad_here;
                    x                   <= x_next;
                    z                   <= z_next;
                    cnt                 <= cnt + 1'b1;
                    if (cnt == N - 1) begin
                        fail  <= fail_acc | bad_here;
                        done  <= 1'b1;
                        state <= S_IDLE;
                    end
                end

                default: state <= S_IDLE;
            endcase
        end
    end

endmodule
