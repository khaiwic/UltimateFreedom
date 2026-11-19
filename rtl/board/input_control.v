// Loc doi phim (debounce) cho nut nhan KEY[1] va dong bo Switch SW[9:0]
module input_control #(
    parameter integer DEBOUNCE_MAX = 499_999
) (
    input  wire       clk,
    input  wire       rst_n,
    input  wire       key_confirm_n,
    input  wire [9:0] sw_raw,
    output reg  [9:0] sw_sync,
    output reg  [9:0] sw_latched,
    output reg        confirm_pulse
);
    reg        key_sync, key_stable;
    reg [18:0] cnt;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            key_sync      <= 1'b1;
            key_stable    <= 1'b1;
            sw_sync       <= 10'd0;
            sw_latched    <= 10'd0;
            cnt           <= 19'd0;
            confirm_pulse <= 1'b0;
        end else begin
            key_sync      <= key_confirm_n;
            sw_sync       <= sw_raw;
            confirm_pulse <= 1'b0;

            if (key_sync == key_stable) begin
                cnt <= 19'd0;
            end else if (cnt == DEBOUNCE_MAX) begin
                cnt        <= 19'd0;
                key_stable <= key_sync;
                if (key_sync == 1'b0) begin
                    confirm_pulse <= 1'b1;
                    sw_latched    <= sw_sync;
                end
            end else begin
                cnt <= cnt + 19'd1;
            end
        end
    end
endmodule
