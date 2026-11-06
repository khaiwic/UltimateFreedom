// reset_sync.v
// Bo dong bo reset cho nut KEY[0] tren DE10-Lite.
//
// - KEY[0] tich cuc thap: nhan = 0, tha = 1.
// - Assert bat dong bo: nhan KEY[0] -> rst_n = 0 ngay lap tuc, khong can clock.
// - Deassert dong bo: tha KEY[0] -> rst_n len 1 sau STAGES canh len cua clk,
//   tranh metastability / recovery-removal violation khi thoat reset.
// - rst_n dung cho cac khoi co dang: always @(posedge clk or negedge rst_n).

module reset_sync #(
    parameter integer STAGES = 2    // So tang flip-flop dong bo, phai >= 2
) (
    input  wire clk,                // Clock he thong (MAX10_CLK1_50)
    input  wire key_rst_n,          // Noi truc tiep vao KEY[0]
    output wire rst_n               // Reset noi bo, tich cuc thap
);

    (* altera_attribute = "-name SYNCHRONIZER_IDENTIFICATION FORCED_IF_ASYNCHRONOUS" *)
    reg [STAGES-1:0] sync_chain = {STAGES{1'b0}};

    always @(posedge clk or negedge key_rst_n) begin
        if (!key_rst_n)
            sync_chain <= {STAGES{1'b0}};
        else
            sync_chain <= {sync_chain[STAGES-2:0], 1'b1};
    end

    assign rst_n = sync_chain[STAGES-1];

endmodule
