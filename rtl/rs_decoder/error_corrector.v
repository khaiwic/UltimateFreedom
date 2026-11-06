// Sua ca N symbol (du lieu va parity): corrected[i] = received[i] XOR E_i.
// err_val tu Forney phai bang 0 tai cac vi tri khong loi.
// Symbol i o [8*i +: 8], theo thu tu truyen.
// start chi chap nhan khi !busy; chot received va err_val tai start.
// Xu ly mot symbol/chu ky: N chu ky sau canh chap nhan start.
// done la xung 1 chu ky; corrected hop le tai done, giu den start ke tiep.
// rst_n: reset bat dong bo, tich cuc thap.
// Decoder chi khoi dong khi cac buoc truoc thanh cong, va phai kiem tra
// lai syndrome sau sua. Khoi nay chi XOR, khong tu xac nhan sua thanh cong.
`include "rs_params.vh"

module error_corrector (
    input  wire                      clk,
    input  wire                      rst_n,
    input  wire                      start,
    input  wire [8*`RS_N-1:0]        received,
    input  wire [8*`RS_N-1:0]        err_val,
    output wire                      busy,
    output reg                       done,
    output reg [8*`RS_N-1:0]         corrected
);
    localparam integer N = `RS_N;
    localparam integer CNT_W = $clog2(N + 1);

    reg running;
    reg [CNT_W-1:0] cnt;
    reg [8*N-1:0] rx, errors;
    assign busy = running;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            running   <= 1'b0;
            done      <= 1'b0;
            cnt       <= {CNT_W{1'b0}};
            rx        <= {8*N{1'b0}};
            errors    <= {8*N{1'b0}};
            corrected <= {8*N{1'b0}};
        end else begin
            done <= 1'b0;
            if (!running) begin
                if (start) begin
                    rx        <= received;
                    errors    <= err_val;
                    cnt       <= {CNT_W{1'b0}};
                    corrected <= {8*N{1'b0}};
                    running   <= 1'b1;
                end
            end else begin
                corrected[8*cnt +: 8] <= rx[8*cnt +: 8] ^ errors[8*cnt +: 8];
                if (cnt == N - 1) begin
                    running <= 1'b0;
                    done    <= 1'b1;
                end else begin
                    cnt <= cnt + 1'b1;
                end
            end
        end
    end
endmodule