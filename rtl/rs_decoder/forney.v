// Thuat toan Forney: tinh do lon loi E_i = X_i * Omega(z_i) / Lambda'(z_i) tren GF(8)
`include "rs_params.vh"

module forney (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        start,
    input  wire  [8:0] lambda,
    input  wire  [5:0] omega,
    input  wire  [4:0] err_mask,

    output wire        busy,
    output reg         done,
    output reg  [14:0] err_val,
    output reg         fail
);
    localparam integer N         = `RS_N; // 5
    localparam [2:0]   X_INIT    = 3'd6;  // alpha^4 = 6
    localparam [2:0]   Z_INIT    = 3'd3;  // alpha^(-4) = 3
    localparam [2:0]   ALPHA_INV = 3'd5;  // alpha^(-1) = 5

    localparam S_IDLE = 1'b0, S_RUN = 1'b1;

    reg       state;
    reg [2:0] cnt;
    reg [8:0] lam;
    reg [5:0] om;
    reg [4:0] mask;
    reg [2:0] x, z;
    reg       fail_acc;

    assign busy = (state != S_IDLE);

    // Tinh Omega(z) = omega[1]*z + omega[0]
    wire [2:0] op0;
    gf8_mul u_om0 (.a(om[5:3]), .b(z), .y(op0));
    wire [2:0] om0 = op0 ^ om[2:0];

    // Dao ham hinh thuc: Lambda'(z) = lambda[1]
    wire [2:0] dv = lam[5:3];

    // E = x * Omega(z) * inv(Lambda'(z))
    wire [2:0] dv_inv, q_val, e_val, x_next, z_next;
    wire       dv_zero;
    gf8_inv u_inv (.a(dv),  .y(dv_inv), .valid(), .zero_err(dv_zero));
    gf8_mul u_q   (.a(om0), .b(dv_inv), .y(q_val));
    gf8_mul u_e   (.a(x),   .b(q_val),  .y(e_val));

    gf8_mul u_xstep (.a(x), .b(ALPHA_INV), .y(x_next));
    gf8_mul u_zstep (.a(z), .b(`GF_ALPHA), .y(z_next));

    wire       is_err   = (cnt < N) ? mask[cnt] : 1'b0;
    wire       bad_here = is_err && dv_zero;
    wire [2:0] val_here = (is_err && !dv_zero) ? e_val : 3'd0;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state    <= S_IDLE;
            cnt      <= 3'd0;
            lam      <= 9'd0;
            om       <= 6'd0;
            mask     <= 5'd0;
            x        <= 3'd1;
            z        <= 3'd1;
            fail_acc <= 1'b0;
            done     <= 1'b0;
            err_val  <= 15'd0;
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
                        cnt      <= 3'd0;
                        fail_acc <= 1'b0;
                        err_val  <= 15'd0;
                        fail     <= 1'b0;
                        state    <= S_RUN;
                    end
                end

                S_RUN: begin
                    case (cnt)
                        3'd0: err_val[2:0]   <= val_here;
                        3'd1: err_val[5:3]   <= val_here;
                        3'd2: err_val[8:6]   <= val_here;
                        3'd3: err_val[11:9]  <= val_here;
                        3'd4: err_val[14:12] <= val_here;
                        default: ;
                    endcase

                    fail_acc <= fail_acc | bad_here;
                    x        <= x_next;
                    z        <= z_next;
                    cnt      <= cnt + 3'd1;

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
