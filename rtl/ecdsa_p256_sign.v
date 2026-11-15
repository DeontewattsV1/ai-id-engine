// SPDX-License-Identifier: MIT
`timescale 1ns/1ps

module ecdsa_p256_sign (
    input  wire         clk, rst_n, start,
    input  wire [255:0] priv, hash,
    input  wire [63:0]  blind_seed,
    output reg          done,
    output reg  [511:0] sig
);
`ifdef VERILATOR
    import "DPI-C" function void c_ecdsa_sign(
        input bit [255:0] priv, input bit [255:0] hash, output bit [511:0] sig);
    always @(posedge clk) begin
        if (!rst_n) done <= 0;
        else if (start) begin c_ecdsa_sign(priv, hash, sig); done <= 1; end
        else done <= 0;
    end
`else
    ecdsa_core u_core (.clk(clk), .rst_n(rst_n), .start(start),
                       .priv(priv), .hash(hash), .blind_seed(blind_seed),
                       .sig(sig), .done(done), .fail());
`endif
endmodule
