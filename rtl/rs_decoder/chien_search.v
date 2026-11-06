// chien_search.v
// Chien search: tim vi tri symbol loi tu da thuc dinh vi loi Lambda(z).
//
// Quy uoc (docs/rs_algorithm.md muc 9, rs_params.vh):
//   - Vi tri truyen i = 0..N-1, X_i = alpha^(N-1-i), z_i = X_i^-1.
//   - err_mask[i] = 1 neu Lambda(z_i) = 0.
//   - Chi quet N vi tri thuc su duoc truyen; nghiem thuoc vung da rut gon khong
//     duoc tim thay nen err_count < lambda_deg va fail = 1.
//
// Hop dong giao tiep:
//   - start: xung 1 chu ky, chi chap nhan khi busy = 0 (start luc busy bi bo qua).
//     lambda va lambda_deg duoc chot tai start. He so lambda[j] voi j > L bi bo qua.
//   - busy = 1 tu luc chap nhan start den khi done.
//   - done: xung 1 chu ky. Cung luc do err_mask, err_count, fail hop le va duoc giu
//     nguyen cho den start ke tiep.
//   - fail = (err_count != lambda_deg).
//   - Do tre: N chu ky quet (1 vi tri/chu ky) + 1 chu ky chap nhan start.
//   - rst_n: reset bat dong bo, tich cuc thap.
//
// Duong du lieu: z_i duoc cap nhat z <= z * alpha moi chu ky; Lambda(z) tinh bang
// Horner voi chuoi gf256_mul / XOR.

`include "rs_params.vh"

module chien_search (
    input  wire                    clk,
    input  wire                    rst_n,

    input  wire                    start,
    input  wire [8*(`RS_R+1)-1:0]  lambda,
    input  wire [3:0]              lambda_deg,

    output wire                    busy,
    output reg                     done,

    output reg  [`RS_N-1:0]        err_mask,
    output reg  [3:0]              err_count,
    output reg                     fail
);

    localparam integer N     = `RS_N;
    localparam integer R     = `RS_R;
    localparam integer CNT_W = $clog2(N + 1);
    localparam [7:0]   ALPHA = `GF_ALPHA;

    // z_0 = alpha^-(N-1) = alpha^(255-(N-1)) (tinh luc elaboration)
    function [7:0] alpha_pow;
        input integer e;
        reg [7:0] acc;
        reg [8:0] x;
        integer k, ee;
        begin
            ee  = e % `GF_ORDER;
            if (ee < 0) ee = ee + `GF_ORDER;
            acc = 8'h01;
            for (k = 0; k < ee; k = k + 1) begin
                // nhan voi alpha = 0x02 (GF_ALPHA): dich trai 1 bit roi rut gon
                x = {1'b0, acc} << 1;
                if (x[8]) x = x ^ `GF_PRIM_POLY;
                acc = x[7:0];
            end
            alpha_pow = acc;
        end
    endfunction

    localparam [7:0] Z_INIT = alpha_pow(-(N - 1));

    localparam S_IDLE = 1'b0,
               S_RUN  = 1'b1;

    reg                    state;
    reg [CNT_W-1:0]        cnt;
    reg [3:0]              deg;
    reg [8*(R+1)-1:0]      lam;
    reg [7:0]              z;
    reg [3:0]              found;

    assign busy = (state != S_IDLE);

    // He so lambda[j] voi j > L bi bo qua
    wire [7:0] coef [0:R];
    genvar j;
    generate
        for (j = 0; j <= R; j = j + 1) begin : gen_coef
            assign coef[j] = (j <= deg) ? lam[8*j +: 8] : 8'h00;
        end
    endgenerate

    // Horner: acc[R] = coef[R]; acc[j] = acc[j+1]*z + coef[j]
    wire [7:0] acc [0:R];
    wire [7:0] mulo [0:R-1];
    assign acc[R] = coef[R];
    generate
        for (j = R - 1; j >= 0; j = j - 1) begin : gen_horner
            gf256_mul u_mul (.a(acc[j+1]), .b(z), .y(mulo[j]));
            gf256_add u_add (.a(mulo[j]), .b(coef[j]), .y(acc[j]));
        end
    endgenerate

    wire [7:0] z_next;
    gf256_mul u_zstep (.a(z), .b(ALPHA), .y(z_next));

    wire is_root     = (acc[0] == 8'h00);
    wire [3:0] found_next = found + (is_root ? 4'd1 : 4'd0);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state     <= S_IDLE;
            cnt       <= {CNT_W{1'b0}};
            deg       <= 4'd0;
            lam       <= {8*(R+1){1'b0}};
            z         <= 8'h01;
            found     <= 4'd0;
            done      <= 1'b0;
            err_mask  <= {N{1'b0}};
            err_count <= 4'd0;
            fail      <= 1'b0;
        end else begin
            done <= 1'b0;

            case (state)
                S_IDLE: begin
                    if (start) begin
                        lam       <= lambda;
                        deg       <= lambda_deg;
                        z         <= Z_INIT;
                        cnt       <= {CNT_W{1'b0}};
                        found     <= 4'd0;
                        err_mask  <= {N{1'b0}};
                        err_count <= 4'd0;
                        fail      <= 1'b0;
                        state     <= S_RUN;
                    end
                end

                S_RUN: begin
                    err_mask[cnt] <= is_root;
                    found         <= found_next;
                    z             <= z_next;
                    cnt           <= cnt + 1'b1;
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
