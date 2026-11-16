// SPDX-License-Identifier: MIT
`timescale 1ns/1ps
// SHA-256 of exactly one PREPADDED 512-bit block, starting from the
// standard FIPS 180-4 IV. Thin wrapper over sha256_compress; multi-block
// users (hmac_sha256, pcr_bank) chain sha256_compress directly.
module sha256_core(
    input wire clk, rst_n, start,
    input wire [511:0] block,
    output wire busy, done,
    output wire [255:0] digest
);
    sha256_compress u_c (
        .clk(clk), .rst_n(rst_n), .start(start),
        .h_in(256'h6a09e667bb67ae853c6ef372a54ff53a510e527f9b05688c1f83d9ab5be0cd19),
        .block(block), .busy(busy), .done(done), .digest(digest)
    );
endmodule
