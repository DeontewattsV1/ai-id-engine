// SPDX-License-Identifier: MIT
// Ring-oscillator entropy sampler for ECP5 (FPGA prototype only).
// N three-stage inverter rings built from LUT4 primitives with `keep`, so
// synthesis cannot collapse them. Their outputs are XORed and sampled by the
// system clock through a 2-flop synchronizer; jitter between the free-running
// rings and clk is the noise. The output feeds trng.v, whose SP 800-90B
// health tests reject a dead or locked source. NOT characterized.
`timescale 1ns/1ps

module ro_entropy_ecp5 #(parameter integer N = 4) (
    input  wire clk,
    output reg  bit_out
);
    wire [N-1:0] tap;
    genvar r;
    generate for (r = 0; r < N; r = r + 1) begin : g_ring
        (* keep *) wire n0, n1, n2;
        (* keep *) LUT4 #(.INIT(16'h5555)) i0 (.A(n2), .B(1'b0), .C(1'b0), .D(1'b0), .Z(n0));
        (* keep *) LUT4 #(.INIT(16'h5555)) i1 (.A(n0), .B(1'b0), .C(1'b0), .D(1'b0), .Z(n1));
        (* keep *) LUT4 #(.INIT(16'h5555)) i2 (.A(n1), .B(1'b0), .C(1'b0), .D(1'b0), .Z(n2));
        assign tap[r] = n2;
    end endgenerate
    reg s1;
    always @(posedge clk) begin s1 <= ^tap; bit_out <= s1; end
endmodule
