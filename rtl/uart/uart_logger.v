// Dong goi thong tin qua trinh giai ma RS(5,3) thanh chuoi ASCII va gui qua UART TX
module uart_logger (
    input  wire        clk,
    input  wire        rst_n,

    input  wire        log_start,
    input  wire        log_mode,       // 0 = INFO, 1 = ERR
    input  wire        log_fail,       // 0 = PASS, 1 = FAIL
    input  wire  [8:0] data_in,
    input  wire [14:0] enc_code,
    input  wire [14:0] rx_code,
    input  wire [14:0] dec_code,
    input  wire  [5:0] dbg_syn,
    input  wire        dbg_syn_zero,
    input  wire  [8:0] dbg_lambda,
    input  wire  [2:0] dbg_lambda_deg,
    input  wire  [5:0] dbg_omega,
    input  wire  [4:0] dbg_err_mask,
    input  wire [14:0] dbg_err_val,

    output reg         tx_start,
    output reg   [7:0] tx_data,
    input  wire        tx_busy,
    output wire        busy
);
    localparam [7:0] LAST_CHAR = 8'd194;

    localparam [1:0]
        S_IDLE       = 2'd0,
        S_LOAD       = 2'd1,
        S_WAIT_START = 2'd2,
        S_WAIT_DONE  = 2'd3;

    reg [1:0]  state;
    reg [7:0]  char_idx;

    reg        mode_buf, fail_buf, syn_zero_buf;
    reg  [8:0] data_buf, lam_buf;
    reg [14:0] enc_buf, rx_buf, dec_buf, err_val_buf;
    reg  [5:0] syn_buf, omega_buf;
    reg  [2:0] lam_deg_buf;
    reg  [4:0] mask_buf;

    assign busy = (state != S_IDLE);

    function [7:0] sym_ascii;
        input [2:0] sym;
        begin
            sym_ascii = {5'b00110, sym}; // '0'..'7'
        end
    endfunction

    function [7:0] bit_ascii;
        input b;
        begin
            bit_ascii = {7'b0011000, b}; // '0' or '1'
        end
    endfunction

    reg [7:0] char_rom;
    always @(*) begin
        case (char_idx)
            // "\r\n=== RS(5,3) GF(8) [INFO/ERR ] ===\r\n" (0..31)
            8'd0:   char_rom = 8'h0D;
            8'd1:   char_rom = 8'h0A;
            8'd2:   char_rom = "=";
            8'd3:   char_rom = "=";
            8'd4:   char_rom = "=";
            8'd5:   char_rom = " ";
            8'd6:   char_rom = "R";
            8'd7:   char_rom = "S";
            8'd8:   char_rom = "(";
            8'd9:   char_rom = "5";
            8'd10:  char_rom = ",";
            8'd11:  char_rom = "3";
            8'd12:  char_rom = ")";
            8'd13:  char_rom = " ";
            8'd14:  char_rom = "G";
            8'd15:  char_rom = "F";
            8'd16:  char_rom = "(";
            8'd17:  char_rom = "8";
            8'd18:  char_rom = ")";
            8'd19:  char_rom = " ";
            8'd20:  char_rom = "[";
            8'd21:  char_rom = mode_buf ? "E" : "I";
            8'd22:  char_rom = mode_buf ? "R" : "N";
            8'd23:  char_rom = mode_buf ? "R" : "F";
            8'd24:  char_rom = mode_buf ? " " : "O";
            8'd25:  char_rom = "]";
            8'd26:  char_rom = " ";
            8'd27:  char_rom = "=";
            8'd28:  char_rom = "=";
            8'd29:  char_rom = "=";
            8'd30:  char_rom = 8'h0D;
            8'd31:  char_rom = 8'h0A;

            // "DATA: d0 d1 d2\r\n" (32..44)
            8'd32:  char_rom = "D";
            8'd33:  char_rom = "A";
            8'd34:  char_rom = "T";
            8'd35:  char_rom = "A";
            8'd36:  char_rom = ":";
            8'd37:  char_rom = " ";
            8'd38:  char_rom = sym_ascii(data_buf[2:0]);
            8'd39:  char_rom = " ";
            8'd40:  char_rom = sym_ascii(data_buf[5:3]);
            8'd41:  char_rom = " ";
            8'd42:  char_rom = sym_ascii(data_buf[8:6]);
            8'd43:  char_rom = 8'h0D;
            8'd44:  char_rom = 8'h0A;

            // "ENC : c0 c1 c2 c3 c4\r\n" (45..61)
            8'd45:  char_rom = "E";
            8'd46:  char_rom = "N";
            8'd47:  char_rom = "C";
            8'd48:  char_rom = " ";
            8'd49:  char_rom = ":";
            8'd50:  char_rom = " ";
            8'd51:  char_rom = sym_ascii(enc_buf[2:0]);
            8'd52:  char_rom = " ";
            8'd53:  char_rom = sym_ascii(enc_buf[5:3]);
            8'd54:  char_rom = " ";
            8'd55:  char_rom = sym_ascii(enc_buf[8:6]);
            8'd56:  char_rom = " ";
            8'd57:  char_rom = sym_ascii(enc_buf[11:9]);
            8'd58:  char_rom = " ";
            8'd59:  char_rom = sym_ascii(enc_buf[14:12]);
            8'd60:  char_rom = 8'h0D;
            8'd61:  char_rom = 8'h0A;

            // "RX  : r0 r1 r2 r3 r4\r\n" (62..78)
            8'd62:  char_rom = "R";
            8'd63:  char_rom = "X";
            8'd64:  char_rom = " ";
            8'd65:  char_rom = " ";
            8'd66:  char_rom = ":";
            8'd67:  char_rom = " ";
            8'd68:  char_rom = sym_ascii(rx_buf[2:0]);
            8'd69:  char_rom = " ";
            8'd70:  char_rom = sym_ascii(rx_buf[5:3]);
            8'd71:  char_rom = " ";
            8'd72:  char_rom = sym_ascii(rx_buf[8:6]);
            8'd73:  char_rom = " ";
            8'd74:  char_rom = sym_ascii(rx_buf[11:9]);
            8'd75:  char_rom = " ";
            8'd76:  char_rom = sym_ascii(rx_buf[14:12]);
            8'd77:  char_rom = 8'h0D;
            8'd78:  char_rom = 8'h0A;

            // "SYN : S0=s0 S1=s1 [FAST/ERR ]\r\n" (79..102)
            8'd79:  char_rom = "S";
            8'd80:  char_rom = "Y";
            8'd81:  char_rom = "N";
            8'd82:  char_rom = " ";
            8'd83:  char_rom = ":";
            8'd84:  char_rom = " ";
            8'd85:  char_rom = "S";
            8'd86:  char_rom = "0";
            8'd87:  char_rom = "=";
            8'd88:  char_rom = sym_ascii(syn_buf[2:0]);
            8'd89:  char_rom = " ";
            8'd90:  char_rom = "S";
            8'd91:  char_rom = "1";
            8'd92:  char_rom = "=";
            8'd93:  char_rom = sym_ascii(syn_buf[5:3]);
            8'd94:  char_rom = " ";
            8'd95:  char_rom = "[";
            8'd96:  char_rom = syn_zero_buf ? "F" : "E";
            8'd97:  char_rom = syn_zero_buf ? "A" : "R";
            8'd98:  char_rom = syn_zero_buf ? "S" : "R";
            8'd99:  char_rom = syn_zero_buf ? "T" : " ";
            8'd100: char_rom = "]";
            8'd101: char_rom = 8'h0D;
            8'd102: char_rom = 8'h0A;

            // "BM  : L=d LAM=[l0 l1 l2]\r\n" (103..125)
            8'd103: char_rom = "B";
            8'd104: char_rom = "M";
            8'd105: char_rom = " ";
            8'd106: char_rom = " ";
            8'd107: char_rom = ":";
            8'd108: char_rom = " ";
            8'd109: char_rom = "L";
            8'd110: char_rom = "=";
            8'd111: char_rom = sym_ascii(lam_deg_buf);
            8'd112: char_rom = " ";
            8'd113: char_rom = "L";
            8'd114: char_rom = "A";
            8'd115: char_rom = "M";
            8'd116: char_rom = "=";
            8'd117: char_rom = "[";
            8'd118: char_rom = sym_ascii(lam_buf[2:0]);
            8'd119: char_rom = " ";
            8'd120: char_rom = sym_ascii(lam_buf[5:3]);
            8'd121: char_rom = " ";
            8'd122: char_rom = sym_ascii(lam_buf[8:6]);
            8'd123: char_rom = "]";
            8'd124: char_rom = 8'h0D;
            8'd125: char_rom = 8'h0A;

            // "OMG : [w0 w1]\r\n" (126..138)
            8'd126: char_rom = "O";
            8'd127: char_rom = "M";
            8'd128: char_rom = "G";
            8'd129: char_rom = " ";
            8'd130: char_rom = ":";
            8'd131: char_rom = " ";
            8'd132: char_rom = "[";
            8'd133: char_rom = sym_ascii(omega_buf[2:0]);
            8'd134: char_rom = " ";
            8'd135: char_rom = sym_ascii(omega_buf[5:3]);
            8'd136: char_rom = "]";
            8'd137: char_rom = 8'h0D;
            8'd138: char_rom = 8'h0A;

            // "MASK: b4b3b2b1b0\r\n" (139..151)
            8'd139: char_rom = "M";
            8'd140: char_rom = "A";
            8'd141: char_rom = "S";
            8'd142: char_rom = "K";
            8'd143: char_rom = ":";
            8'd144: char_rom = " ";
            8'd145: char_rom = bit_ascii(mask_buf[4]);
            8'd146: char_rom = bit_ascii(mask_buf[3]);
            8'd147: char_rom = bit_ascii(mask_buf[2]);
            8'd148: char_rom = bit_ascii(mask_buf[1]);
            8'd149: char_rom = bit_ascii(mask_buf[0]);
            8'd150: char_rom = 8'h0D;
            8'd151: char_rom = 8'h0A;

            // "ERR : [e0 e1 e2 e3 e4]\r\n" (152..170)
            8'd152: char_rom = "E";
            8'd153: char_rom = "R";
            8'd154: char_rom = "R";
            8'd155: char_rom = " ";
            8'd156: char_rom = ":";
            8'd157: char_rom = " ";
            8'd158: char_rom = "[";
            8'd159: char_rom = sym_ascii(err_val_buf[2:0]);
            8'd160: char_rom = " ";
            8'd161: char_rom = sym_ascii(err_val_buf[5:3]);
            8'd162: char_rom = " ";
            8'd163: char_rom = sym_ascii(err_val_buf[8:6]);
            8'd164: char_rom = " ";
            8'd165: char_rom = sym_ascii(err_val_buf[11:9]);
            8'd166: char_rom = " ";
            8'd167: char_rom = sym_ascii(err_val_buf[14:12]);
            8'd168: char_rom = "]";
            8'd169: char_rom = 8'h0D;
            8'd170: char_rom = 8'h0A;

            // "DEC : o0 o1 o2 o3 o4 [PASS/FAIL]\r\n" (171..194)
            8'd171: char_rom = "D";
            8'd172: char_rom = "E";
            8'd173: char_rom = "C";
            8'd174: char_rom = " ";
            8'd175: char_rom = ":";
            8'd176: char_rom = " ";
            8'd177: char_rom = sym_ascii(dec_buf[2:0]);
            8'd178: char_rom = " ";
            8'd179: char_rom = sym_ascii(dec_buf[5:3]);
            8'd180: char_rom = " ";
            8'd181: char_rom = sym_ascii(dec_buf[8:6]);
            8'd182: char_rom = " ";
            8'd183: char_rom = sym_ascii(dec_buf[11:9]);
            8'd184: char_rom = " ";
            8'd185: char_rom = sym_ascii(dec_buf[14:12]);
            8'd186: char_rom = " ";
            8'd187: char_rom = "[";
            8'd188: char_rom = fail_buf ? "F" : "P";
            8'd189: char_rom = fail_buf ? "A" : "A";
            8'd190: char_rom = fail_buf ? "I" : "S";
            8'd191: char_rom = fail_buf ? "L" : "S";
            8'd192: char_rom = "]";
            8'd193: char_rom = 8'h0D;
            8'd194: char_rom = 8'h0A;

            default: char_rom = 8'h20;
        endcase
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state        <= S_IDLE;
            char_idx     <= 8'd0;
            tx_start     <= 1'b0;
            tx_data      <= 8'h00;
            mode_buf     <= 1'b0;
            fail_buf     <= 1'b0;
            syn_zero_buf <= 1'b0;
            data_buf     <= 9'd0;
            lam_buf      <= 9'd0;
            enc_buf      <= 15'd0;
            rx_buf       <= 15'd0;
            dec_buf      <= 15'd0;
            err_val_buf  <= 15'd0;
            syn_buf      <= 6'd0;
            omega_buf    <= 6'd0;
            lam_deg_buf  <= 3'd0;
            mask_buf     <= 5'd0;
        end else begin
            tx_start <= 1'b0;

            case (state)
                S_IDLE: begin
                    if (log_start) begin
                        mode_buf     <= log_mode;
                        fail_buf     <= log_fail;
                        syn_zero_buf <= dbg_syn_zero;
                        data_buf     <= data_in;
                        enc_buf      <= enc_code;
                        rx_buf       <= rx_code;
                        dec_buf      <= dec_code;
                        syn_buf      <= dbg_syn;
                        lam_buf      <= dbg_lambda;
                        lam_deg_buf  <= dbg_lambda_deg;
                        omega_buf    <= dbg_omega;
                        mask_buf     <= dbg_err_mask;
                        err_val_buf  <= dbg_err_val;
                        char_idx     <= 8'd0;
                        state        <= S_LOAD;
                    end
                end

                S_LOAD: begin
                    if (!tx_busy) begin
                        tx_data  <= char_rom;
                        tx_start <= 1'b1;
                        state    <= S_WAIT_START;
                    end
                end

                S_WAIT_START: begin
                    state <= S_WAIT_DONE;
                end

                S_WAIT_DONE: begin
                    if (!tx_busy) begin
                        if (char_idx == LAST_CHAR)
                            state <= S_IDLE;
                        else begin
                            char_idx <= char_idx + 8'd1;
                            state    <= S_LOAD;
                        end
                    end
                end

                default: state <= S_IDLE;
            endcase
        end
    end
endmodule
