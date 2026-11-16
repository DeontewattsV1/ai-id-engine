// SPDX-License-Identifier: MIT
// Active tamper-mesh checker.
//
// Drives a 4-bit LFSR pattern onto mesh_out; the board routes the four
// traces as a serpentine shield over the secure area and back to mesh_in.
// After SYNC_LAT cycles (2-flop synchronizer + routing) the returned
// pattern must equal what was sent. A cut, short or probe that bridges
// traces makes them differ; MISMATCH_LIMIT consecutive mismatches raise
// `breach` (fed into tamper_ctrl sensor 0 = shield, which always zeroizes).
// The first ARM_DELAY cycles after reset are ignored while the pipeline fills.
`timescale 1ns/1ps

module tamper_mesh #(
    parameter integer MISMATCH_LIMIT = 2,
    parameter integer ARM_DELAY = 8
) (
    input  wire       clk,
    input  wire       rst_n,
    output wire [3:0] mesh_out,
    input  wire [3:0] mesh_in,
    output reg        breach
);
    reg [15:0] lfsr;
    reg [3:0]  d1, d2, d3;        // expected-value delay line
    reg [3:0]  s1, s2;            // input synchronizer
    reg [3:0]  arm;
    reg [1:0]  miss;

    assign mesh_out = lfsr[3:0];

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            lfsr <= 16'hACE1; d1 <= 0; d2 <= 0; d3 <= 0; s1 <= 0; s2 <= 0;
            arm <= 0; miss <= 0; breach <= 0;
        end else begin
            lfsr <= {lfsr[14:0], lfsr[15] ^ lfsr[13] ^ lfsr[12] ^ lfsr[10]};
            d1 <= lfsr[3:0]; d2 <= d1; d3 <= d2;
            s1 <= mesh_in; s2 <= s1;
            if (arm != ARM_DELAY[3:0]) arm <= arm + 4'd1;
            else if (s2 != d2) begin
                if (miss + 2'd1 >= MISMATCH_LIMIT[1:0]) breach <= 1;
                else miss <= miss + 2'd1;
            end else begin
                miss <= 0; breach <= 0;
            end
        end
    end
    wire unused_ok = &{1'b0, d3};
endmodule
