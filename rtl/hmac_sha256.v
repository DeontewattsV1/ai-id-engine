// KDF for the key ladder and DICE layers
// SPDX-License-Identifier: MIT
// HMAC-SHA256 (RFC 2104 / FIPS 198-1) with a 256-bit key and a single
// left-aligned message of msg_bits <= 440 bits (55 bytes), so that the
// padded message fits one block after the key block. Four chained
// SHA-256 compressions; verified against OpenSSL HMAC in tb/tb_id_engine.cpp.
// Not constant-power; no side-channel hardening is claimed.
`timescale 1ns/1ps

module hmac_sha256 (
    input  wire         clk,
    input  wire         rst_n,
    input  wire         start,
    input  wire [255:0] key,
    input  wire [511:0] msg,        // left-aligned message bits
    input  wire [8:0]   msg_bits,   // must be <= 440
    output reg          done,
    output reg  [255:0] mac
);
    localparam [255:0] IV =
        256'h6a09e667bb67ae853c6ef372a54ff53a510e527f9b05688c1f83d9ab5be0cd19;
    localparam [255:0] IPAD32 = {32{8'h36}};
    localparam [255:0] OPAD32 = {32{8'h5c}};

    reg [255:0] k_q, inner, h_in;
    reg [511:0] m_q, blk;
    reg [8:0]   bits_q;
    reg [3:0]   state;
    reg         s_start;
    /* verilator lint_off UNUSEDSIGNAL */
    wire        s_busy, s_done;
    /* verilator lint_on UNUSEDSIGNAL */
    wire [255:0] s_dig;

    sha256_compress u_sha (
        .clk(clk), .rst_n(rst_n), .start(s_start), .h_in(h_in),
        .block(blk), .busy(s_busy), .done(s_done), .digest(s_dig)
    );

    // FIPS 180-4 padding for the second inner block: total length is the
    // 512-bit key block plus msg_bits.
    wire [511:0] keep_mask = ~(512'b0) << (10'd512 - {1'b0, bits_q});
    wire [511:0] one_bit   = {1'b1, 511'b0} >> bits_q;
    wire [511:0] inner_pad = (m_q & keep_mask) | one_bit |
                             {448'b0, 64'd512 + {55'b0, bits_q}};

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= 0; done <= 0; s_start <= 0; mac <= 0;
            k_q <= 0; m_q <= 0; bits_q <= 0; inner <= 0; h_in <= IV; blk <= 0;
        end else begin
            s_start <= 0; done <= 0;
            case (state)
                0: if (start) begin
                       k_q <= key; m_q <= msg; bits_q <= msg_bits;
                       h_in <= IV; blk <= {key ^ IPAD32, IPAD32};
                       state <= 1;
                   end
                1: begin s_start <= 1; state <= 2; end
                2: if (s_done) begin h_in <= s_dig; blk <= inner_pad; state <= 3; end
                3: begin s_start <= 1; state <= 4; end
                4: if (s_done) begin
                       inner <= s_dig; h_in <= IV;
                       blk <= {k_q ^ OPAD32, OPAD32}; state <= 5;
                   end
                5: begin s_start <= 1; state <= 6; end
                6: if (s_done) begin
                       h_in <= s_dig;
                       blk <= {inner, 1'b1, 191'b0, 64'd768}; state <= 7;
                   end
                7: begin s_start <= 1; state <= 8; end
                8: if (s_done) begin mac <= s_dig; done <= 1; state <= 0; end
                default: state <= 0;
            endcase
        end
    end
endmodule
