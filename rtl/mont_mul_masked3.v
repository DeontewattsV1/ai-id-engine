// SPDX-License-Identifier: MIT
`timescale 1ns/1ps
// Three-share (second-order target) arithmetically masked Montgomery product.
//
//   a = a0+a1+a2, b = b0+b1+b2 (mod m);  r0+r1+r2 = a*b*2^-256 (mod m)
//
// Same structure as mont_mul_masked_v2: one time-shared radix-2 datapath and
// nine share products a_i*b_j, each accumulated into output share i. The
// accumulators start at (r_s, r_t, m - r_s - r_t), so the masks sum to 0.
// Random ports are independent: r_p0/r_p1 precharge the operands, r_c
// precharges the product register, and r_s/r_t are uniform in [0, m).
// Use it when gate.py returns exit 2, i.e. a second-order leak in the
// 2-share design.
module mont_mul_masked3 (
    input  wire         clk, rst_n, start,
    input  wire [255:0] a0, a1, a2, b0, b1, b2, modulus,
    input  wire [31:0]  n0prime,
    input  wire [255:0] r_p0, r_p1, r_c, r_s, r_t,
    output reg  [255:0] r0, r1, r2,
    output reg          done
);
    localparam [2:0] IDLE=3'd0, PRE=3'd1, LOAD=3'd2, RUN=3'd3, RED=3'd4,
                     ACC=3'd5, OUT=3'd6, INIT=3'd7;
    reg [2:0]   state;
    reg [1:0]   ki, kj;      // product (ki, kj), ki,kj in 0..2
    reg [7:0]   bit_index;
    reg [255:0] aa, bb, nn, p, s0, s1, s2;
    reg [257:0] t;

    wire ld = (state == LOAD);
    (* keep *) wire [255:0] ga0 = a0 & {256{ld & (ki == 2'd0)}};
    (* keep *) wire [255:0] ga1 = a1 & {256{ld & (ki == 2'd1)}};
    (* keep *) wire [255:0] ga2 = a2 & {256{ld & (ki == 2'd2)}};
    (* keep *) wire [255:0] gb0 = b0 & {256{ld & (kj == 2'd0)}};
    (* keep *) wire [255:0] gb1 = b1 & {256{ld & (kj == 2'd1)}};
    (* keep *) wire [255:0] gb2 = b2 & {256{ld & (kj == 2'd2)}};

    wire [257:0] t_plus_a = t + (bb[bit_index] ? {2'b0, aa} : 258'd0);
    wire [257:0] t_plus_n = t_plus_a + (t_plus_a[0] ? {2'b0, nn} : 258'd0);
    wire [257:0] reduced  = (t >= {2'b0, nn}) ? t - {2'b0, nn} : t;

    wire acc = (state == ACC);
    (* keep *) wire [255:0] pg0 = p & {256{acc & (ki == 2'd0)}};
    (* keep *) wire [255:0] pg1 = p & {256{acc & (ki == 2'd1)}};
    (* keep *) wire [255:0] pg2 = p & {256{acc & (ki == 2'd2)}};

    function automatic [255:0] madd(input [255:0] x, input [255:0] y,
                                    input [255:0] m);
        reg [256:0] s, d;
        begin
            s = {1'b0, x} + {1'b0, y};
            d = s - {1'b0, m};
            madd = d[256] ? s[255:0] : d[255:0];
        end
    endfunction
    function automatic [255:0] mneg(input [255:0] x, input [255:0] m);
        mneg = (x == 256'd0) ? 256'd0 : m - x;
    endfunction

    wire [255:0] add0 = madd(s0, pg0, nn);
    wire [255:0] add1 = madd(s1, pg1, nn);
    wire [255:0] add2 = madd(s2, pg2, nn);
    // s2 = m - r_s - r_t, built in two steps across IDLE/INIT: IDLE registers
    // m - r_s, INIT adds m - r_t to that register. The two masks therefore do
    // meet in the INIT adder; what the split avoids is ever computing
    // r_s + r_t from the raw ports in the same cycle they are sampled.
    wire [255:0] s2_step1 = mneg(r_s, modulus);
    wire [255:0] s2_step2 = madd(s2, mneg(r_t, nn), nn);
    wire unused_ok = &{1'b0, n0prime, reduced[257:256]};

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE; done <= 1'b0; ki <= 2'd0; kj <= 2'd0;
            bit_index <= 8'd0; aa <= 0; bb <= 0; nn <= 0; p <= 0;
            s0 <= 0; s1 <= 0; s2 <= 0; t <= 0; r0 <= 0; r1 <= 0; r2 <= 0;
        end else begin
            done <= 1'b0;
            case (state)
                IDLE: if (start) begin
`ifndef SYNTHESIS
                    if (!modulus[0] || a0 >= modulus || a1 >= modulus ||
                        a2 >= modulus || b0 >= modulus || b1 >= modulus ||
                        b2 >= modulus || r_s >= modulus || r_t >= modulus)
                        $fatal(1, "mont_mul_masked3: share/mask out of range");
`endif
                    nn <= modulus; s0 <= r_s; s1 <= r_t; s2 <= s2_step1;
                    ki <= 2'd0; kj <= 2'd0; state <= INIT;
                end
                INIT: begin s2 <= s2_step2; state <= PRE; end
                PRE: begin aa <= r_p0; bb <= r_p1; p <= r_c; state <= LOAD; end
                LOAD: begin
                    aa <= ga0 | ga1 | ga2; bb <= gb0 | gb1 | gb2;
                    t <= 0; bit_index <= 8'd0; state <= RUN;
                end
                RUN: begin
                    t <= t_plus_n >> 1;
                    if (bit_index == 8'd255) state <= RED;
                    else bit_index <= bit_index + 1'b1;
                end
                RED: begin p <= reduced[255:0]; state <= ACC; end
                ACC: begin
                    s0 <= add0; s1 <= add1; s2 <= add2;
                    if (ki == 2'd2 && kj == 2'd2) state <= OUT;
                    else begin
                        if (kj == 2'd2) begin kj <= 2'd0; ki <= ki + 2'd1; end
                        else kj <= kj + 2'd1;
                        state <= PRE;
                    end
                end
                OUT: begin
                    r0 <= s0; r1 <= s1; r2 <= s2; done <= 1'b1; state <= IDLE;
                end
                default: state <= IDLE;
            endcase
        end
    end
endmodule
