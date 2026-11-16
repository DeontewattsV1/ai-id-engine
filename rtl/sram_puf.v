// SPDX-License-Identifier: MIT
// Simple SRAM PUF stub
// Provides a deterministic pseudo-unique secret for simulation/linting.

module sram_puf (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        zeroize,
    output reg [255:0] uds
);

    // On reset produce a fixed seed; zeroize clears the UDS; otherwise
    // produce a changing value so downstream modules can exercise behavior.
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            uds <= 256'hDEADBEEF_DEADBEEF_DEADBEEF_DEADBEEF_DEADBEEF_DEADBEEF_DEADBEEF_DEADBEEF;
        end else if (zeroize) begin
            uds <= 256'b0;
        end else begin
            uds <= uds + 256'h1; // simple evolution for simulation
        end
    end

endmodule
