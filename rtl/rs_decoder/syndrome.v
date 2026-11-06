// syndrome.v
// Tinh R gia tri syndrome tu chuoi N symbol nhan duoc: S[j] = y(alpha^(F + j)).
//
// Quy uoc (docs/rs_algorithm.md muc 6, rs_params.vh):
//   - Symbol nhan data_in truyen theo thu tu: y[0] (he so bac cao nhat x^(N-1)) den y[N-1].
//   - Tinh bang thuat toan Horner: acc = gf_mul(acc, beta_j) XOR data_in moi khi co fire.
//   - Ket qua syn[8*j +: 8] = S[j] (he so z^j, bac thap truoc).
//   - syn_zero = 1 khi tat ca S[j] = 0.
//
// Hop dong giao tiep (tb/tb_syndrome.v):
//   - start: xung 1 chu ky khi busy = 0. Xoa bo tich luy va bat dau khoi moi.
//   - in_ready: chi bang 1 trong pha nhan du lieu (busy = 1).
//   - done: xung 1 chu ky ngay khi symbol thu N duoc nhan.
//   - syn va syn_zero hop le tai done va duoc giu nguyen den start ke tiep.
//   - busy = 1 tu start den done.

`include "rs_params.vh"

module syndrome (
    input  wire                 clk,
    input  wire                 rst_n,

    input  wire                 start,

    input  wire [7:0]           data_in,
    input  wire                 in_valid,
    output wire                 in_ready,

    output reg  [8*`RS_R-1:0]   syn,
    output reg                  syn_zero,

    output wire                 busy,
    output reg                  done
);

    localparam integer N          = `RS_N;
    localparam integer R          = `RS_R;
    localparam integer FIRST_ROOT = `RS_FIRST_ROOT;
    localparam integer ROOT_STEP  = `RS_ROOT_STEP;
    localparam [8:0]   PRIM_POLY  = `GF_PRIM_POLY;
    localparam [7:0]   POLY_LOW   = PRIM_POLY[7:0];
    localparam [7:0]   ALPHA      = `GF_ALPHA;
    localparam integer CNT_W      = $clog2(N + 1);

    // Ham hang tinh alpha^e luc elaboration
    function [7:0] gf_mul_const;
        input [7:0] a;
        input [7:0] b;
        reg   [7:0] aa;
        reg   [7:0] acc;
        integer     k;
        begin
            aa  = a;
            acc = 8'h00;
            for (k = 0; k < 8; k = k + 1) begin
                if (b[k])
                    acc = acc ^ aa;
                aa = aa[7] ? ((aa << 1) ^ POLY_LOW) : (aa << 1);
            end
            gf_mul_const = acc;
        end
    endfunction

    function [7:0] gf_pow_alpha;
        input integer e;
        reg   [7:0] acc;
        integer     k, ee;
        begin
            ee = e % `GF_ORDER;
            if (ee < 0) ee = ee + `GF_ORDER;
            acc = 8'h01;
            for (k = 0; k < ee; k = k + 1)
                acc = gf_mul_const(acc, ALPHA);
            gf_pow_alpha = acc;
        end
    endfunction

    // Mang beta_j cho R syndrome
    function [8*R-1:0] get_betas;
        input integer dummy;
        reg [8*R-1:0] b;
        integer j;
        begin
            for (j = 0; j < R; j = j + 1)
                b[8*j +: 8] = gf_pow_alpha(FIRST_ROOT + j * ROOT_STEP);
            get_betas = b;
        end
    endfunction

    localparam [8*R-1:0] BETAS = get_betas(0);

    localparam S_IDLE = 1'b0,
               S_RECV = 1'b1;

    reg             state;
    reg [CNT_W-1:0] cnt;
    reg [7:0]       acc [0:R-1];

    assign in_ready = (state == S_RECV);
    assign busy     = (state != S_IDLE);

    wire in_fire = in_valid && in_ready;

    // Horner tren moi nhanh j: acc_next[j] = acc[j] * beta_j ^ data_in
    wire [7:0] mul_out [0:R-1];
    wire [7:0] acc_next [0:R-1];
    genvar g;
    generate
        for (g = 0; g < R; g = g + 1) begin : gen_horner_taps
            gf256_mul u_mul (
                .a(acc[g]),
                .b(BETAS[8*g +: 8]),
                .y(mul_out[g])
            );
            gf256_add u_add (
                .a(mul_out[g]),
                .b(data_in),
                .y(acc_next[g])
            );
        end
    endgenerate

    // Kiem tra tat ca acc_next bang 0
    wire is_all_zero;
    wire [R-1:0] zero_check;
    generate
        for (g = 0; g < R; g = g + 1) begin : gen_zero_check
            assign zero_check[g] = (acc_next[g] == 8'h00);
        end
    endgenerate
    assign is_all_zero = &zero_check;

    integer i;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state    <= S_IDLE;
            cnt      <= {CNT_W{1'b0}};
            done     <= 1'b0;
            syn      <= {8*R{1'b0}};
            syn_zero <= 1'b1;
            for (i = 0; i < R; i = i + 1)
                acc[i] <= 8'h00;
        end else begin
            done <= 1'b0;

            case (state)
                S_IDLE: begin
                    if (start) begin
                        cnt   <= {CNT_W{1'b0}};
                        state <= S_RECV;
                        for (i = 0; i < R; i = i + 1)
                            acc[i] <= 8'h00;
                    end
                end

                S_RECV: begin
                    if (in_fire) begin
                        for (i = 0; i < R; i = i + 1)
                            acc[i] <= acc_next[i];

                        cnt <= cnt + 1'b1;
                        if (cnt == N - 1) begin
                            for (i = 0; i < R; i = i + 1)
                                syn[8*i +: 8] <= acc_next[i];
                            syn_zero <= is_all_zero;
                            done     <= 1'b1;
                            state    <= S_IDLE;
                        end
                    end
                end

                default: state <= S_IDLE;
            endcase
        end
    end

endmodule
