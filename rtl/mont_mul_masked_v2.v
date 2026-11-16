// SPDX-License-Identifier: MIT
`timescale 1ns/1ps
// Two-share (first-order) arithmetically masked Montgomery product, v2.
//
//   inputs : a = a0 + a1 (mod m),  b = b0 + b1 (mod m),  0 <= ai,bi < m
//   outputs: r0 + r1 (mod m) = a*b*2^-256 (mod m)     (same result as mont_mul)
//
// One radix-2 Montgomery datapath (the same algorithm as rtl/mont_mul.v) is
// time-shared over the four share products a_i*b_j. Product (i,j) accumulates
// into output share i, and both accumulators start with a fresh mask:
//   s0 = r_s,  s1 = m - r_s.
// Four independent random ports, each consumed once per operation:
//   r_p0 - precharge for the A operand register between share loads
//   r_p1 - precharge for the B operand register between share loads
//   r_c  - precharge for the product register between products
//   r_s  - accumulator refresh mask, uniform in [0, m)
// Operand selection uses AND-gated, one-hot load enables (kept nets), so no
// net ever switches directly between share 0 and share 1 of the same secret.
// That holds in a zero-delay model only. Glitches are not modelled; see
// docs/TVLA.md.
//
// Fixes relative to the bundled draft: real modular arithmetic (the draft
// XORed partial products, so r0^r1 was not a*b); counters sized for 256
// iterations; no variable part-selects; a0i/b0j-style wires are gone; case has
// a default; the four random inputs are independent (the draft derived them
// from one word with constants).
module mont_mul_masked_v2 (
    input  wire         clk, rst_n, start,
    input  wire [255:0] a0, a1, b0, b1, modulus,
    input  wire [31:0]  n0prime,
    input  wire [255:0] r_p0, r_p1, r_c, r_s,
    output reg  [255:0] r0, r1,
    output reg          done
);
    localparam [2:0] IDLE=3'd0, PRE=3'd1, LOAD=3'd2, RUN=3'd3, RED=3'd4,
                     ACC=3'd5, OUT=3'd6;
    reg [2:0]   state;
    reg [1:0]   k;          // product index: {i, j}
    reg [7:0]   bit_index;
    reg [255:0] aa, bb, nn, p, s0, s1;
    reg [257:0] t;

    // One-hot, AND-gated operand selection (never a 2:1 mux between shares).
    wire ld   = (state == LOAD);
    wire ld_a0 = ld & ~k[1], ld_a1 = ld & k[1];
    wire ld_b0 = ld & ~k[0], ld_b1 = ld & k[0];
    (* keep *) wire [255:0] ga0 = a0 & {256{ld_a0}};
    (* keep *) wire [255:0] ga1 = a1 & {256{ld_a1}};
    (* keep *) wire [255:0] gb0 = b0 & {256{ld_b0}};
    (* keep *) wire [255:0] gb1 = b1 & {256{ld_b1}};

    // Radix-2 Montgomery datapath (identical recurrence to mont_mul).
    wire [257:0] t_plus_a = t + (bb[bit_index] ? {2'b0, aa} : 258'd0);
    wire [257:0] t_plus_n = t_plus_a + (t_plus_a[0] ? {2'b0, nn} : 258'd0);
    wire [257:0] reduced  = (t >= {2'b0, nn}) ? t - {2'b0, nn} : t;

    // Gated product into exactly one accumulator.
    wire acc = (state == ACC);
    (* keep *) wire [255:0] pg0 = p & {256{acc & ~k[1]}};
    (* keep *) wire [255:0] pg1 = p & {256{acc &  k[1]}};
    wire [256:0] sum0 = {1'b0, s0} + {1'b0, pg0};
    wire [256:0] sum1 = {1'b0, s1} + {1'b0, pg1};
    wire [256:0] dif0 = sum0 - {1'b0, nn};
    wire [256:0] dif1 = sum1 - {1'b0, nn};
    wire [255:0] add0 = dif0[256] ? sum0[255:0] : dif0[255:0];
    wire [255:0] add1 = dif1[256] ? sum1[255:0] : dif1[255:0];
    wire [255:0] s1_init = (r_s == 256'd0) ? 256'd0 : modulus - r_s;
    wire unused_ok = &{1'b0, n0prime, reduced[257:256]};

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE; done <= 1'b0; k <= 2'd0; bit_index <= 8'd0;
            aa <= 0; bb <= 0; nn <= 0; p <= 0; s0 <= 0; s1 <= 0; t <= 0;
            r0 <= 0; r1 <= 0;
        end else begin
            done <= 1'b0;
            case (state)
                IDLE: if (start) begin
`ifndef SYNTHESIS
                    if (!modulus[0] || a0 >= modulus || a1 >= modulus ||
                        b0 >= modulus || b1 >= modulus || r_s >= modulus)
                        $fatal(1, "mont_mul_masked_v2: share/mask out of range");
`endif
                    nn <= modulus; s0 <= r_s; s1 <= s1_init; k <= 2'd0;
                    state <= PRE;
                end
                PRE: begin
                    aa <= r_p0; bb <= r_p1; p <= r_c; state <= LOAD;
                end
                LOAD: begin
                    aa <= ga0 | ga1; bb <= gb0 | gb1;
                    t <= 0; bit_index <= 8'd0; state <= RUN;
                end
                RUN: begin
                    t <= t_plus_n >> 1;
                    if (bit_index == 8'd255) state <= RED;
                    else bit_index <= bit_index + 1'b1;
                end
                RED: begin p <= reduced[255:0]; state <= ACC; end
                ACC: begin
                    s0 <= add0; s1 <= add1;
                    if (k == 2'd3) state <= OUT;
                    else begin k <= k + 2'd1; state <= PRE; end
                end
                OUT: begin r0 <= s0; r1 <= s1; done <= 1'b1; state <= IDLE; end
                default: state <= IDLE;
            endcase
        end
    end
endmodule
