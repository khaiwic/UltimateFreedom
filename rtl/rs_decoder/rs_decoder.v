// rs_decoder.v
// Bo giai ma Reed-Solomon systematic RS(15,11) tren GF(256), kha nang sua T = 2 loi.
// Dieu phoi toan bo cac khoi con:
//   syndrome -> berlekamp_massey -> error_evaluator -> chien_search -> forney -> error_corrector
// va kiem tra lai syndrome sau khi sua.
//
// Dac ta theo:
//   - README_RS_DE10_Lite.md (muc 1, 2.2, 3, 5, 10, 13)
//   - docs/rs_algorithm.md
//   - rtl/include/rs_params.vh
//
// Hop dong giao tiep (tb/tb_rs_decoder.v):
//   - start: xung 1 chu ky khi IDLE (busy = 0). start luc busy bi bo qua.
//   - data_in, in_valid, in_ready: nhan dung N = 15 symbol (y[0] he so x^(N-1) truoc).
//     in_ready chi bang 1 trong pha nhan du lieu (busy = 1).
//   - data_out, out_valid, out_ready, out_last: xuat dung N symbol (du lieu da sua).
//     Giu on dinh khi out_valid = 1 va out_ready = 0. out_last = 1 tai symbol thu N.
//   - done: xung 1 chu ky ngay sau khi symbol cuoi cung duoc nhan o dau ra.
//   - busy: 1 tu khi nhan start den khi done.
//   - fail: hop le tai done va giu den start ke tiep. Bao fail neu:
//       + BM: L = 0 hoac L > T (khi S != 0).
//       + Chien: so nghiem trong vung truyen != L.
//       + Forney: mau so dao ham bang 0 tai vi tri loi.
//       + Verify: syndrome sau khi sua van khac 0.
//     Khi fail = 1, decoder van xuat du N symbol de giu dung giao thuc.
//   - rst_n: reset bat dong bo, tich cuc thap.

`include "rs_params.vh"

module rs_decoder (
    input  wire                 clk,
    input  wire                 rst_n,

    input  wire                 start,

    input  wire [7:0]           data_in,
    input  wire                 in_valid,
    output wire                 in_ready,

    output reg  [7:0]           data_out,
    output reg                  out_valid,
    input  wire                 out_ready,
    output reg                  out_last,

    output wire                 busy,
    output reg                  done,
    output reg                  fail
);

    localparam integer N = `RS_N;
    localparam integer K = `RS_K;
    localparam integer R = `RS_R;
    localparam integer T = `RS_T;

    localparam integer CNT_W = $clog2(N + 1);

    // ------------------------------------------------------------------------
    // Cac trang thai FSM dieu phoi
    // ------------------------------------------------------------------------
    localparam [3:0] S_IDLE        = 4'd0,
                     S_RECV        = 4'd1,   // Nhan N symbol vao rx_buf va syndrome
                     S_WAIT_SYN1   = 4'd2,   // Cho syndrome lan 1 xong
                     S_BM          = 4'd3,   // Berlekamp-Massey tim Lambda
                     S_OMEGA       = 4'd4,   // Tinh Omega
                     S_CHIEN       = 4'd5,   // Chien search tim vi tri loi
                     S_FORNEY      = 4'd6,   // Forney tinh gia tri loi
                     S_CORRECT     = 4'd7,   // XOR sua tu ma
                     S_VERIFY_FEED = 4'd8,   // Dua tu ma ung vien vao syndrome kiem tra lai
                     S_VERIFY_WAIT = 4'd9,   // Cho syndrome lan 2 xong
                     S_OUT_PREP    = 4'd10,  // Chuan bi phat du lieu ra
                     S_OUT         = 4'd11;  // Xuat N symbol theo bat tay valid/ready

    reg [3:0]       state;
    reg [CNT_W-1:0] rx_cnt;
    reg [CNT_W-1:0] out_cnt;
    reg [CNT_W-1:0] ver_cnt;

    reg [8*N-1:0]   rx_buf;
    reg [8*N-1:0]   candidate_buf;
    reg [8*N-1:0]   corr_buf;

    assign busy = (state != S_IDLE);

    // ------------------------------------------------------------------------
    // 1. Module syndrome (dung chung cho ca lan 1 va kiem tra lai)
    // ------------------------------------------------------------------------
    reg             syn_start;
    wire [7:0]      syn_data_in  = (state == S_VERIFY_FEED) ? candidate_buf[8*ver_cnt +: 8] : data_in;
    wire            syn_in_valid = (state == S_VERIFY_FEED) ? 1'b1 : ((state == S_RECV) && in_valid);
    wire            syn_in_ready;
    wire [8*R-1:0]  syn_out;
    wire            syn_zero_out;
    wire            syn_busy;
    wire            syn_done;

    syndrome u_syndrome (
        .clk      (clk),
        .rst_n    (rst_n),
        .start    (syn_start),
        .data_in  (syn_data_in),
        .in_valid (syn_in_valid),
        .in_ready (syn_in_ready),
        .syn      (syn_out),
        .syn_zero (syn_zero_out),
        .busy     (syn_busy),
        .done     (syn_done)
    );

    assign in_ready = (state == S_RECV) && syn_in_ready;
    wire in_fire    = in_valid && in_ready;
    wire out_fire   = out_valid && out_ready;

    // ------------------------------------------------------------------------
    // 2. Module Berlekamp-Massey
    // ------------------------------------------------------------------------
    reg                   bm_start;
    reg  [8*R-1:0]        syn_latched;
    wire                  bm_busy;
    wire                  bm_done;
    wire [8*(R+1)-1:0]    bm_lambda_out;
    wire [3:0]            bm_deg_out;
    wire                  bm_fail_out;

    berlekamp_massey u_bm (
        .clk        (clk),
        .rst_n      (rst_n),
        .start      (bm_start),
        .syn        (syn_latched),
        .busy       (bm_busy),
        .done       (bm_done),
        .lambda     (bm_lambda_out),
        .lambda_deg (bm_deg_out),
        .fail       (bm_fail_out)
    );

    // ------------------------------------------------------------------------
    // 3. Module Error Evaluator (Omega)
    // ------------------------------------------------------------------------
    reg                   ee_start;
    reg  [8*(R+1)-1:0]    lambda_latched;
    reg  [3:0]            deg_latched;
    wire                  ee_busy;
    wire                  ee_done;
    wire [8*R-1:0]        ee_omega_out;

    error_evaluator u_ee (
        .clk        (clk),
        .rst_n      (rst_n),
        .start      (ee_start),
        .syn        (syn_latched),
        .lambda     (lambda_latched),
        .lambda_deg (deg_latched),
        .busy       (ee_busy),
        .done       (ee_done),
        .omega      (ee_omega_out)
    );

    // ------------------------------------------------------------------------
    // 4. Module Chien Search
    // ------------------------------------------------------------------------
    reg                   chien_start;
    wire                  chien_busy;
    wire                  chien_done;
    wire [N-1:0]          chien_mask_out;
    wire [3:0]            chien_count_out;
    wire                  chien_fail_out;

    chien_search u_chien (
        .clk        (clk),
        .rst_n      (rst_n),
        .start      (chien_start),
        .lambda     (lambda_latched),
        .lambda_deg (deg_latched),
        .busy       (chien_busy),
        .done       (chien_done),
        .err_mask   (chien_mask_out),
        .err_count  (chien_count_out),
        .fail       (chien_fail_out)
    );

    // ------------------------------------------------------------------------
    // 5. Module Forney
    // ------------------------------------------------------------------------
    reg                   forney_start;
    reg  [8*R-1:0]        omega_latched;
    reg  [N-1:0]          mask_latched;
    wire                  forney_busy;
    wire                  forney_done;
    wire [8*N-1:0]        forney_val_out;
    wire                  forney_fail_out;

    forney u_forney (
        .clk      (clk),
        .rst_n    (rst_n),
        .start    (forney_start),
        .lambda   (lambda_latched),
        .omega    (omega_latched),
        .err_mask (mask_latched),
        .busy     (forney_busy),
        .done     (forney_done),
        .err_val  (forney_val_out),
        .fail     (forney_fail_out)
    );

    // ------------------------------------------------------------------------
    // 6. Module Error Corrector
    // ------------------------------------------------------------------------
    reg                   ec_start;
    reg  [8*N-1:0]        err_val_latched;
    wire                  ec_busy;
    wire                  ec_done;
    wire [8*N-1:0]        ec_corr_out;

    error_corrector u_ec (
        .clk       (clk),
        .rst_n     (rst_n),
        .start     (ec_start),
        .received  (rx_buf),
        .err_val   (err_val_latched),
        .busy      (ec_busy),
        .done      (ec_done),
        .corrected (ec_corr_out)
    );

    // ------------------------------------------------------------------------
    // FSM dieu phoi chinh
    // ------------------------------------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state           <= S_IDLE;
            rx_cnt          <= {CNT_W{1'b0}};
            out_cnt         <= {CNT_W{1'b0}};
            ver_cnt         <= {CNT_W{1'b0}};
            rx_buf          <= {8*N{1'b0}};
            candidate_buf   <= {8*N{1'b0}};
            corr_buf        <= {8*N{1'b0}};
            syn_latched     <= {8*R{1'b0}};
            lambda_latched  <= {8*(R+1){1'b0}};
            deg_latched     <= 4'd0;
            omega_latched   <= {8*R{1'b0}};
            mask_latched    <= {N{1'b0}};
            err_val_latched <= {8*N{1'b0}};

            syn_start       <= 1'b0;
            bm_start        <= 1'b0;
            ee_start        <= 1'b0;
            chien_start     <= 1'b0;
            forney_start    <= 1'b0;
            ec_start        <= 1'b0;

            data_out        <= 8'h00;
            out_valid       <= 1'b0;
            out_last        <= 1'b0;
            done            <= 1'b0;
            fail            <= 1'b0;
        end else begin
            done         <= 1'b0;
            syn_start    <= 1'b0;
            bm_start     <= 1'b0;
            ee_start     <= 1'b0;
            chien_start  <= 1'b0;
            forney_start <= 1'b0;
            ec_start     <= 1'b0;

            case (state)
                S_IDLE: begin
                    if (start) begin
                        rx_cnt    <= {CNT_W{1'b0}};
                        syn_start <= 1'b1;
                        state     <= S_RECV;
                    end
                end

                S_RECV: begin
                    if (in_fire) begin
                        rx_buf[8*rx_cnt +: 8] <= data_in;
                        rx_cnt <= rx_cnt + 1'b1;
                        if (rx_cnt == N - 1) begin
                            state <= S_WAIT_SYN1;
                        end
                    end
                end

                S_WAIT_SYN1: begin
                    if (syn_done) begin
                        if (syn_zero_out) begin
                            // Khong co loi: bo qua tat ca cac buoc sua
                            fail     <= 1'b0;
                            corr_buf <= rx_buf;
                            state    <= S_OUT_PREP;
                        end else begin
                            syn_latched <= syn_out;
                            bm_start    <= 1'b1;
                            state       <= S_BM;
                        end
                    end
                end

                S_BM: begin
                    if (bm_done) begin
                        if (bm_fail_out) begin
                            fail     <= 1'b1;
                            corr_buf <= rx_buf;
                            state    <= S_OUT_PREP;
                        end else begin
                            lambda_latched <= bm_lambda_out;
                            deg_latched    <= bm_deg_out;
                            ee_start       <= 1'b1;
                            state          <= S_OMEGA;
                        end
                    end
                end

                S_OMEGA: begin
                    if (ee_done) begin
                        omega_latched <= ee_omega_out;
                        chien_start   <= 1'b1;
                        state         <= S_CHIEN;
                    end
                end

                S_CHIEN: begin
                    if (chien_done) begin
                        if (chien_fail_out) begin
                            fail     <= 1'b1;
                            corr_buf <= rx_buf;
                            state    <= S_OUT_PREP;
                        end else begin
                            mask_latched <= chien_mask_out;
                            forney_start <= 1'b1;
                            state        <= S_FORNEY;
                        end
                    end
                end

                S_FORNEY: begin
                    if (forney_done) begin
                        if (forney_fail_out) begin
                            fail     <= 1'b1;
                            corr_buf <= rx_buf;
                            state    <= S_OUT_PREP;
                        end else begin
                            err_val_latched <= forney_val_out;
                            ec_start        <= 1'b1;
                            state           <= S_CORRECT;
                        end
                    end
                end

                S_CORRECT: begin
                    if (ec_done) begin
                        candidate_buf <= ec_corr_out;
                        syn_start     <= 1'b1;
                        ver_cnt       <= {CNT_W{1'b0}};
                        state         <= S_VERIFY_FEED;
                    end
                end

                S_VERIFY_FEED: begin
                    if (syn_in_ready) begin
                        ver_cnt <= ver_cnt + 1'b1;
                        if (ver_cnt == N - 1) begin
                            state <= S_VERIFY_WAIT;
                        end
                    end
                end

                S_VERIFY_WAIT: begin
                    if (syn_done) begin
                        if (syn_zero_out) begin
                            fail     <= 1'b0;
                            corr_buf <= candidate_buf;
                        end else begin
                            // Syndrome sau sua van khac 0: giai ma that bai
                            fail     <= 1'b1;
                            corr_buf <= rx_buf;
                        end
                        state <= S_OUT_PREP;
                    end
                end

                S_OUT_PREP: begin
                    out_cnt   <= {CNT_W{1'b0}};
                    data_out  <= corr_buf[7:0];
                    out_valid <= 1'b1;
                    out_last  <= (N == 1);
                    state     <= S_OUT;
                end

                S_OUT: begin
                    if (out_fire) begin
                        if (out_cnt == N - 1) begin
                            out_valid <= 1'b0;
                            out_last  <= 1'b0;
                            done      <= 1'b1;
                            state     <= S_IDLE;
                        end else begin
                            data_out <= corr_buf[8*(out_cnt + 1'b1) +: 8];
                            out_last <= (out_cnt + 1'b1 == N - 1);
                            out_cnt  <= out_cnt + 1'b1;
                        end
                    end
                end

                default: state <= S_IDLE;
            endcase
        end
    end

endmodule
