// SPDX-License-Identifier: MIT
`timescale 1ns/1ps
// Fixed-latency, bit-serial radix-2 Montgomery product for 256-bit odd moduli.
// Requires 0 <= a,b < modulus and n0prime == -modulus^-1 (mod 2^32).
// Result = a*b*2^(-256) mod modulus. This block is NOT masked against DPA.
module mont_mul (
    input  wire         clk, rst_n, start,
    input  wire [255:0] a, b, modulus,
    input  wire [31:0]  n0prime,
    output reg  [255:0] r,
    output reg          done
);
    localparam [1:0] IDLE=2'd0, RUN=2'd1, REDUCE=2'd2;
    reg [1:0] state;
    reg [255:0] aa, bb, nn;
    reg [257:0] t;
    reg [7:0] bit_index;
    wire [257:0] t_plus_a = t + (bb[bit_index] ? {2'b0, aa} : 258'd0);
    wire [257:0] t_plus_n = t_plus_a +
                           (t_plus_a[0] ? {2'b0, nn} : 258'd0);
    wire [257:0] reduced = (t >= {2'b0, nn}) ? t-{2'b0, nn} : t;
    // Final subtraction is 258-bit; only [255:0] is the result (t < 2n
    // guarantees bits 257:256 are zero after the subtract).
    wire unused_ok_reduced = &{1'b0, reduced[257:256]};

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE; done <= 1'b0; r <= 0;
            aa <= 0; bb <= 0; nn <= 0; t <= 0; bit_index <= 0;
        end else begin
            done <= 1'b0;
            case (state)
                IDLE: if (start) begin
`ifndef SYNTHESIS
                    if (!modulus[0] || a >= modulus || b >= modulus ||
                        (modulus[31:0]*n0prime) != 32'hffffffff)
                        $fatal(1, "mont_mul: invalid operand or modulus parameters");
`endif
                    aa <= a; bb <= b; nn <= modulus;
                    t <= 0; bit_index <= 0; state <= RUN;
                end
                RUN: begin
                    t <= t_plus_n >> 1;
                    if (bit_index == 8'd255) state <= REDUCE;
                    else bit_index <= bit_index+1'b1;
                end
                REDUCE: begin
                    r <= reduced[255:0];
                    done <= 1'b1;
                    state <= IDLE;
                end
                default: state <= IDLE;
            endcase
        end
    end
endmodule
