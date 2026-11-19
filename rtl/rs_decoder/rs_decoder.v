// Bo giai ma Reed-Solomon RS(5,3) tren GF(8) sua toi da T=1 loi
// Chu trinh 5 buoc: Syndrome -> Berlekamp-Massey -> Omega -> Chien Search -> Forney & XOR
`include "rs_params.vh"

module rs_decoder (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        start,
    input  wire [14:0] rx_in,

    output wire        busy,
    output reg         done,
    output reg         fail,
    output reg  [14:0] corr_out
);
    localparam [2:0]
        S_IDLE   = 3'd0,
        S_SYN    = 3'd1,
        S_BM     = 3'd2,
        S_OMEGA  = 3'd3,
        S_CHIEN  = 3'd4,
        S_FORNEY = 3'd5;

    reg  [2:0] state;
    reg [14:0] rx_buf;

    assign busy = (state != S_IDLE);

    // 1. Khoi Syndrome
    reg        syn_start;
    wire       syn_done, syn_zero_out;
    wire [5:0] syn_out;

    syndrome u_syndrome (
        .clk      (clk),
        .rst_n    (rst_n),
        .start    (syn_start),
        .rx_in    (rx_buf),
        .busy     (),
        .done     (syn_done),
        .syn      (syn_out),
        .syn_zero (syn_zero_out)
    );

    // 2. Khoi Berlekamp-Massey
    reg        bm_start;
    reg  [5:0] syn_latched;
    wire       bm_done, bm_fail_out;
    wire [8:0] bm_lambda_out;
    wire [2:0] bm_deg_out;

    berlekamp_massey u_bm (
        .clk        (clk),
        .rst_n      (rst_n),
        .start      (bm_start),
        .syn        (syn_latched),
        .busy       (),
        .done       (bm_done),
        .lambda     (bm_lambda_out),
        .lambda_deg (bm_deg_out),
        .fail       (bm_fail_out)
    );

    // 3. Khoi Error Evaluator (Omega)
    reg        ee_start;
    reg  [8:0] lambda_latched;
    reg  [2:0] deg_latched;
    wire       ee_done;
    wire [5:0] ee_omega_out;

    error_evaluator u_ee (
        .clk        (clk),
        .rst_n      (rst_n),
        .start      (ee_start),
        .syn        (syn_latched),
        .lambda     (lambda_latched),
        .lambda_deg (deg_latched),
        .busy       (),
        .done       (ee_done),
        .omega      (ee_omega_out)
    );

    // 4. Khoi Chien Search
    reg        chien_start;
    wire       chien_done, chien_fail_out;
    wire [4:0] chien_mask_out;

    chien_search u_chien (
        .clk        (clk),
        .rst_n      (rst_n),
        .start      (chien_start),
        .lambda     (lambda_latched),
        .lambda_deg (deg_latched),
        .busy       (),
        .done       (chien_done),
        .err_mask   (chien_mask_out),
        .err_count  (),
        .fail       (chien_fail_out)
    );

    // 5. Khoi Forney
    reg         forney_start;
    reg   [5:0] omega_latched;
    reg   [4:0] mask_latched;
    wire        forney_done, forney_fail_out;
    wire [14:0] forney_val_out;

    forney u_forney (
        .clk      (clk),
        .rst_n    (rst_n),
        .start    (forney_start),
        .lambda   (lambda_latched),
        .omega    (omega_latched),
        .err_mask (mask_latched),
        .busy     (),
        .done     (forney_done),
        .err_val  (forney_val_out),
        .fail     (forney_fail_out)
    );

    // FSM dieu phoi 5 buoc giai ma
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state          <= S_IDLE;
            rx_buf         <= 15'd0;
            syn_latched    <= 6'd0;
            lambda_latched <= 9'd0;
            deg_latched    <= 3'd0;
            omega_latched  <= 6'd0;
            mask_latched   <= 5'd0;
            syn_start      <= 1'b0;
            bm_start       <= 1'b0;
            ee_start       <= 1'b0;
            chien_start    <= 1'b0;
            forney_start   <= 1'b0;
            corr_out       <= 15'd0;
            done           <= 1'b0;
            fail           <= 1'b0;
        end else begin
            done         <= 1'b0;
            syn_start    <= 1'b0;
            bm_start     <= 1'b0;
            ee_start     <= 1'b0;
            chien_start  <= 1'b0;
            forney_start <= 1'b0;

            case (state)
                S_IDLE: begin
                    if (start) begin
                        rx_buf    <= rx_in;
                        syn_start <= 1'b1;
                        state     <= S_SYN;
                    end
                end

                S_SYN: begin
                    if (syn_done) begin
                        if (syn_zero_out) begin
                            corr_out <= rx_buf;
                            fail     <= 1'b0;
                            done     <= 1'b1;
                            state    <= S_IDLE;
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
                            corr_out <= rx_buf;
                            fail     <= 1'b1;
                            done     <= 1'b1;
                            state    <= S_IDLE;
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
                            corr_out <= rx_buf;
                            fail     <= 1'b1;
                            done     <= 1'b1;
                            state    <= S_IDLE;
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
                            corr_out <= rx_buf;
                            fail     <= 1'b1;
                        end else begin
                            corr_out <= rx_buf ^ forney_val_out;
                            fail     <= 1'b0;
                        end
                        done  <= 1'b1;
                        state <= S_IDLE;
                    end
                end

                default: state <= S_IDLE;
            endcase
        end
    end
endmodule
