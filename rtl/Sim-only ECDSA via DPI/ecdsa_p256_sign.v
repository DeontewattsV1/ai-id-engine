Sim-only ECDSA via DPI
// SPDX-License-Identifier: MIT
`timescale 1ns/1ps

module ecdsa_p256_sign (
    input  wire         clk, rst_n, start,
    input  wire [255:0] priv, hash,
    output reg          done,
    output reg  [511:0] sig
);
`ifdef VERILATOR
    import "DPI-C" function void c_ecdsa_sign(
        input bit [255:0] priv, input bit [255:0] hash,
        output bit [511:0] sig);
    always @(posedge clk) begin
        if (!rst_n) done <= 0;
        else if (start) begin c_ecdsa_sign(priv, hash, sig); done <= 1; end
        else done <= 0;
    end
`else
    // hardened constant-time ladder (see Part D note)
    ecdsa_core u_core (.*);
`endif
endmodule
