// layered identity derivation
// SPDX-License-Identifier: MIT
// DICE layer:
//   CDI_n     = HMAC-SHA256(UDS_or_CDI_{n-1}, tag || label || measurement)
//               tag = "DICE" for the root layer, "LAYE" otherwise (52 bytes)
//   alias_key = HMAC-SHA256(CDI_n, "ALIA" || label)          (20 bytes)
//   device_id = HMAC-SHA256(CDI_n, "DVID" || label)          (20 bytes)
// alias_key is secret (seeds the key ladder); device_id is public and is
// the hardware identity carried in every quote (a DICE compound device ID:
// it changes if the UDS or the measured layer changes).
// The parent secret is latched at layer_start. Outputs are cleared by
// zeroize. Verified bit-exactly against OpenSSL HMAC in tb/tb_id_engine.cpp.
`timescale 1ns/1ps

module dice_cdi (
    input  wire         clk,
    input  wire         rst_n,
    input  wire         layer_start,
    input  wire         zeroize,
    input  wire         is_root,        // 1 = derive from UDS, 0 = from prior CDI
    input  wire [255:0] parent,         // UDS or CDI_{n-1}
    input  wire [127:0] label,
    input  wire [255:0] measurement,
    output reg  [255:0] cdi,
    output reg  [255:0] alias_key,
    output reg  [255:0] device_id,
    output reg          valid,          // level: outputs hold a derived value
    output wire         busy
);
    reg [511:0] msg;
    reg [8:0]   msg_bits;
    reg [255:0] key;
    reg [127:0] label_q;
    reg [2:0]   state;
    reg         h_start;
    wire        h_done;
    wire [255:0] h_mac;

    assign busy = (state != 0);

    hmac_sha256 u_h (
        .clk(clk), .rst_n(rst_n), .start(h_start),
        .key(key), .msg(msg), .msg_bits(msg_bits),
        .done(h_done), .mac(h_mac)
    );

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= 0; valid <= 0; cdi <= 0; alias_key <= 0; device_id <= 0; h_start <= 0;
            msg <= 0; msg_bits <= 0; key <= 0; label_q <= 0;
        end else if (zeroize) begin
            state <= 0; valid <= 0; cdi <= 0; alias_key <= 0; device_id <= 0; h_start <= 0;
            msg <= 0; key <= 0;
        end else begin
            h_start <= 0;
            case (state)
                0: if (layer_start) begin
                       key <= parent; label_q <= label; valid <= 0;
                       msg <= {is_root ? 32'h44494345 : 32'h4c415945,
                               label, measurement, 96'b0};
                       msg_bits <= 9'd416;
                       state <= 1;
                   end
                1: begin h_start <= 1; state <= 2; end
                2: if (h_done) begin
                       cdi <= h_mac; key <= h_mac;
                       msg <= {32'h414c4941, label_q, 352'b0};
                       msg_bits <= 9'd160;
                       state <= 3;
                   end
                3: begin h_start <= 1; state <= 4; end
                4: if (h_done) begin
                       alias_key <= h_mac; key <= cdi;
                       msg <= {32'h44564944, label_q, 352'b0};
                       msg_bits <= 9'd160;
                       state <= 5;
                   end
                5: begin h_start <= 1; state <= 6; end
                6: if (h_done) begin
                       device_id <= h_mac; valid <= 1; key <= 0; state <= 0;
                   end
                default: state <= 0;
            endcase
        end
    end
endmodule
