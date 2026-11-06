module input_control #(
    parameter integer DEBOUNCE_CYCLES = 500_000
) (
    input wire          clk,
    input wire          rst_n,

    input wire          key_confirm_n,
    input wire [9:0]    sw_raw,

    output reg [9:0]    sw_sync,
    output reg [9:0]    sw_latched,
    output reg          confirm_pulse
);

    // Debounce_cycles phai >= 1
    // Bao dam bo dem co it nhat 1 bit
    localparam integer COUNTER_WIDTH = 
        (DEBOUNCE_CYCLES > 1)
        ? $clog2(DEBOUNCE_CYCLES)
        : 1;

    reg key_meta;
    reg key_sync;

    reg [9:0] sw_meta;

    reg key_stable;
    reg [COUNTER_WIDTH-1:0] debounce_count;

    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            key_meta <= 1'b1;
            key_sync <= 1'b1;

            sw_meta <= 10'b0;
            sw_sync <= 10'b0;
        end
        else begin
            key_meta <= key_confirm_n;
            key_sync <= key_meta;

            sw_meta <= sw_raw;
            sw_sync <= sw_meta;
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            key_stable <= 1'b1;
            debounce_count <= {COUNTER_WIDTH{1'b0}};

            confirm_pulse <= 1'b0;
            sw_latched <= 10'b0;
        end
        else begin 
            confirm_pulse <= 1'b0;

            if(key_sync == key_stable) begin
                debounce_count <= {COUNTER_WIDTH{1'b0}};
            end
            else begin
                if(debounce_count == DEBOUNCE_CYCLES - 1) begin
                    debounce_count <= {COUNTER_WIDTH{1'b0}};
                    key_stable <= key_sync;

                    if(key_sync == 1'b0) begin
                        confirm_pulse <= 1'b1;
                        sw_latched <= sw_sync;
                    end
                end 
                else begin
                    debounce_count <= debounce_count + 1'b1;
                end
            end
        end
    end
    
endmodule