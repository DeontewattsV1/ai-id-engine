// SPDX-License-Identifier: MIT
`timescale 1ns/1ps

`ifndef SYNTHESIS
// Deterministic simulation model; synthesis must bind a technology-specific PUF.
module sram_puf #(
    parameter [255:0] SIM_PUF_VALUE = {
        128'hd6b8e4a19c732f05a2d0c8416e5f397b,
        128'h81c3a7d92e640bf5d1a96c3087e254ab
    }
) (
    input  wire         clk,
    input  wire         rst_n,
    input  wire         zeroize,
    output reg  [255:0] uds
);
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            uds <= SIM_PUF_VALUE;
        else if (zeroize)
            uds <= 256'b0;
    end
endmodule
`else
(* blackbox *)
module sram_puf (
    input  wire         clk,
    input  wire         rst_n,
    input  wire         zeroize,
    output wire [255:0] uds
);
endmodule
`endif
