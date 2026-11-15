// Layered identity derivation.
// SPDX-License-Identifier: MIT
// DICE layer: CDI_n = HMAC(UDS_or_CDI_{n-1}, "DICE" || label || measurement)
// Alias key = HMAC(CDI_n, "ALIAS" || label)
`timescale 1ns/1ps

module dice_cdi (
    input  wire         clk,
    input  wire         rst_n,
    input  wire         layer_start,
    input  wire         is_root,        // 1 = derive from UDS, 0 = from prior CDI
    input  wire [255:0] parent,         // UDS or CDI_{n-1}
    input  wire [127:0] label,
    input  wire [255:0] measurement,
    output reg  [255:0] cdi,
    output reg  [255:0] alias_key,
    output reg          valid
);
    reg [511:0] msg;
    reg [2:0]   state;
    reg         h_start;
    wire        h_done;
    wire [255:0] h_mac;

    hmac_sha256 u_h (
        .clk(clk), .rst_n(rst_n), .start(h_start),
        .key(parent), .msg(msg), .msg_bits(9'd384),
        .done(h_done), .mac(h_mac)
    );

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= 0; valid <= 0; cdi <= 0; alias_key <= 0; h_start <= 0;
        end else begin
            h_start <= 0; valid <= 0;
            case (state)
                0: if (layer_start) begin
                       msg <= {is_root ? 32'h44494345 : 32'h4c415945,
                               label, measurement, 64'b0};
                       state <= 1;
                   end
                1: begin h_start <= 1; state <= 2; end
                2: if (h_done) begin cdi <= h_mac; msg <= {32'h414c4941,
                       label, 192'b0}; state <= 3; end
                3: begin h_start <= 1; state <= 4; end
                4: if (h_done) begin alias_key <= h_mac; valid <= 1; state <= 0; end
                default: state <= 0;
            endcase
        end
    end
endmodule
