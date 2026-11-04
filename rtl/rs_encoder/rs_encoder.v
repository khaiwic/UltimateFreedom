// rs_encoder.v
// Bo ma hoa Reed-Solomon systematic tren GF(256), dang luong (streaming).
// Su dung cac module phep toan truong huu han trong rtl/gf_arithmetic/
// (gf256_add.v, gf256_mul.v).
//
// Cau hinh lay tu rs_params.vh (mac dinh RS(15,11), R = 4, p(u) = 0x11D,
// alpha = 0x02, nghiem dau F = 0):
//   g(x) = (x + 01)(x + 02)(x + 04)(x + 08) = x^4 + 0F x^3 + 36 x^2 + 78 x + 40
//   p(x) = [x^R * m(x)] mod g(x)
//   c    = [m[0], ..., m[K-1], parity[0], ..., parity[R-1]]
// c[0] duoc truyen dau tien va la he so bac cao nhat x^(N-1).
// He so g(x) duoc tinh luc tong hop tu cac macro, khong viet tay.
//
// Hop dong giao tiep:
//   - start: xung 1 chu ky, chi duoc chap nhan khi IDLE (busy = 0). Xoa thanh
//     ghi parity va bat dau mot khoi moi. start trong luc busy bi bo qua.
//   - Dau vao: symbol data_in duoc nhan tai canh len khi in_valid && in_ready.
//     in_ready chi bang 1 trong pha nhan du lieu va khi thanh ghi dau ra trong
//     hoac dang duoc doc. Nhan dung K symbol moi khoi.
//   - Dau ra: data_out duoc xuat khi out_valid && out_ready. data_out giu on
//     dinh khi out_valid = 1 va out_ready = 0. Thu tu: K byte du lieu (di qua
//     nguyen ven) roi R byte parity. out_last = 1 o symbol thu N.
//   - done: xung 1 chu ky, ngay sau khi symbol cuoi cung duoc nhan o dau ra.
//   - busy: 1 tu luc chap nhan start den khi done.
//   - Do tre: moi symbol dau ra tre 1 chu ky so voi dau vao; khi out_ready luon
//     bang 1, ca khoi mat N chu ky (khong tinh start va done).
//   - rst_n: reset bat dong bo, tich cuc thap (lay tu reset_sync).

`include "rs_params.vh"

module rs_encoder (
    input  wire       clk,
    input  wire       rst_n,

    input  wire       start,

    input  wire [7:0] data_in,
    input  wire       in_valid,
    output wire       in_ready,

    output reg  [7:0] data_out,
    output reg        out_valid,
    input  wire       out_ready,
    output reg        out_last,

    output wire       busy,
    output reg        done
);

    /*Parameters
    */
    localparam integer N          = `RS_N;
    localparam integer K          = `RS_K;
    localparam integer R          = `RS_R;
    localparam integer FIRST_ROOT = `RS_FIRST_ROOT;
    localparam integer ROOT_STEP  = `RS_ROOT_STEP;
    localparam [8:0]   PRIM_POLY  = `GF_PRIM_POLY;
    localparam [7:0]   POLY_LOW   = PRIM_POLY[7:0];             // 0x1D
    localparam [7:0]   ALPHA      = `GF_ALPHA;

    localparam integer CNT_W      = $clog2(N + 1);

    // ------------------------------------------------------------------------
    // Ham hang (constant functions) CHI dung luc elaboration de tinh he so
    // da thuc sinh g(x) cho localparam GEN. Cac phep toan tren duong du lieu
    // phan cung ben duoi deu dung module gf256_mul va gf256_add.
    // ------------------------------------------------------------------------
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
        integer     k;
        begin
            acc = 8'h01;
            for (k = 0; k < e; k = k + 1)
                acc = gf_mul_const(acc, ALPHA);
            gf_pow_alpha = acc;
        end
    endfunction

    // Da thuc sinh g(x) = prod_{j=0..R-1} (x + alpha^(FIRST_ROOT + j*ROOT_STEP)).
    // Ket qua: he so cua x^d nam tai bit [8*d +: 8].
    // Mang bac cao truoc trong tai lieu: g[j] = he so cua x^(R-j).
    function [8*(R+1)-1:0] gen_poly;
        input integer dummy;
        reg   [8*(R+1)-1:0] c;
        reg   [7:0]         root;
        integer             j;
        integer             d;
        begin
            c        = {8*(R+1){1'b0}};
            c[7:0]   = 8'h01;                       // g(x) = 1
            for (j = 0; j < R; j = j + 1) begin
                root = gf_pow_alpha(FIRST_ROOT + j * ROOT_STEP);
                // Nhan voi (x + root): c'[d] = c[d-1] + root*c[d]
                for (d = R; d > 0; d = d - 1)
                    c[8*d +: 8] = c[8*(d-1) +: 8] ^ gf_mul_const(c[8*d +: 8], root);
                c[7:0] = gf_mul_const(c[7:0], root);
            end
            gen_poly = c;
        end
    endfunction

    // GEN[8*d +: 8] = he so cua x^d; GEN cua x^R luon bang 0x01 (monic).
    localparam [8*(R+1)-1:0] GEN = gen_poly(0);

    // ------------------------------------------------------------------------
    // FSM & Thanh ghi parity
    // ------------------------------------------------------------------------
    localparam [1:0] S_IDLE   = 2'd0,
                     S_DATA   = 2'd1,   // nhan K symbol du lieu
                     S_PARITY = 2'd2,   // day R symbol parity ra
                     S_DRAIN  = 2'd3;   // cho symbol cuoi duoc doc

    reg [1:0]       state;
    reg [CNT_W-1:0] in_cnt;             // so symbol du lieu da nhan
    reg [CNT_W-1:0] par_cnt;            // so symbol parity da nap vao dau ra

    // parity[0] la he so bac cao nhat cua p(x), duoc xuat truoc.
    reg [7:0] parity [0:R-1];

    wire out_free = !out_valid || out_ready;    // thanh ghi dau ra co the nap
    wire in_fire  = in_valid && in_ready;
    wire out_fire = out_valid && out_ready;

    assign in_ready = (state == S_DATA) && out_free;
    assign busy     = (state != S_IDLE);

    // ------------------------------------------------------------------------
    // Duong du lieu LFSR su dung gf256_add va gf256_mul tu rtl/gf_arithmetic/
    // ------------------------------------------------------------------------
    wire [7:0] feedback;
    wire [7:0] fb_mul   [0:R-1];
    wire [7:0] par_next [0:R-1];

    // Phan hoi LFSR: feedback = data_in + parity[0]
    gf256_add u_fb_add (
        .a (data_in),
        .b (parity[0]),
        .y (feedback)
    );

    // R nhanh nhan he so da thuc sinh va cong voi thanh ghi parity ke tiep
    genvar g;
    generate
        for (g = 0; g < R; g = g + 1) begin : gen_lfsr_taps
            gf256_mul u_tap_mul (
                .a (feedback),
                .b (GEN[8*(R-1-g) +: 8]),
                .y (fb_mul[g])
            );

            if (g < R - 1) begin : gen_tap_add
                gf256_add u_tap_add (
                    .a (parity[g+1]),
                    .b (fb_mul[g]),
                    .y (par_next[g])
                );
            end else begin : gen_tap_last
                assign par_next[g] = fb_mul[g];
            end
        end
    endgenerate

    integer i;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state     <= S_IDLE;
            in_cnt    <= {CNT_W{1'b0}};
            par_cnt   <= {CNT_W{1'b0}};
            data_out  <= 8'h00;
            out_valid <= 1'b0;
            out_last  <= 1'b0;
            done      <= 1'b0;
            for (i = 0; i < R; i = i + 1)
                parity[i] <= 8'h00;
        end else begin
            done <= 1'b0;

            // Symbol hien tai da duoc doc; bi ghi de neu nap symbol moi ben duoi.
            if (out_fire) begin
                out_valid <= 1'b0;
                out_last  <= 1'b0;
            end

            case (state)
                S_IDLE: begin
                    if (start) begin
                        in_cnt  <= {CNT_W{1'b0}};
                        par_cnt <= {CNT_W{1'b0}};
                        for (i = 0; i < R; i = i + 1)
                            parity[i] <= 8'h00;
                        state <= S_DATA;
                    end
                end

                S_DATA: begin
                    if (in_fire) begin
                        // Du lieu di qua nguyen ven (ma systematic)
                        data_out  <= data_in;
                        out_valid <= 1'b1;
                        out_last  <= 1'b0;

                        // Cap nhat thanh ghi parity tu mang gf256_mul + gf256_add
                        for (i = 0; i < R; i = i + 1)
                            parity[i] <= par_next[i];

                        in_cnt <= in_cnt + 1'b1;
                        if (in_cnt == K - 1)
                            state <= S_PARITY;
                    end
                end

                S_PARITY: begin
                    if (out_free) begin
                        data_out  <= parity[0];
                        out_valid <= 1'b1;
                        out_last  <= (par_cnt == R - 1);

                        for (i = 0; i < R - 1; i = i + 1)
                            parity[i] <= parity[i+1];
                        parity[R-1] <= 8'h00;

                        par_cnt <= par_cnt + 1'b1;
                        if (par_cnt == R - 1)
                            state <= S_DRAIN;
                    end
                end

                S_DRAIN: begin
                    if (out_fire) begin
                        done  <= 1'b1;
                        state <= S_IDLE;
                    end
                end

                default: state <= S_IDLE;
            endcase
        end
    end

endmodule
