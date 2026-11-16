// SPDX-License-Identifier: MIT
`timescale 1ns/1ps
// mont_mul with a residue check (fault DETECTION, not side-channel hardening).
//
// The datapath is the same radix-2 Montgomery recurrence as rtl/mont_mul.v.
// It also records the quotient bits Q = sum q_i 2^i. After 256 steps the
// exact integer identity
//       2^256 * t = a*b + Q*m        and  r = t - s*m   (s = final subtract)
// holds. With M = 2^16 - 1, 2^256 = 1 (mod M), so the block checks
//       |r| + s*|m|  ==  |a|*|b| + |Q|*|m|   (mod M)
// where |a|, |b|, |m| are residues taken straight from the input PORTS at
// start (an independent path from the aa/bb/nn registers the datapath uses).
// Any fault that changes r, Q or an operand register by an amount that is not
// a multiple of 65535 raises rc_err with done. Errors that are multiples of
// 65535 escape (about 1 in 65535 for random corruption).
module mont_mul_rc (
    input  wire         clk, rst_n, start,
    input  wire [255:0] a, b, modulus,
    input  wire [31:0]  n0prime,
    output reg  [255:0] r,
    output reg          done,
    output reg          rc_err      // residue mismatch, valid with done
);
    localparam [1:0] IDLE=2'd0, RUN=2'd1, REDUCE=2'd2;
    reg [1:0] state;
    reg [255:0] aa, bb, nn, q;
    reg [257:0] t;
    reg [7:0] bit_index;
    reg [15:0] ra, rb, rm;
    wire [257:0] t_plus_a = t + (bb[bit_index] ? {2'b0, aa} : 258'd0);
    wire [257:0] t_plus_n = t_plus_a +
                           (t_plus_a[0] ? {2'b0, nn} : 258'd0);
    wire         sub      = (t >= {2'b0, nn});
    wire [257:0] reduced  = sub ? t-{2'b0, nn} : t;

    // x mod (2^16 - 1) by 16-bit end-around-carry folding.
    function automatic [15:0] res258(input [257:0] x);
        integer k;
        reg [17:0] acc;
        begin
            acc = 18'd0;
            for (k = 0; k < 17; k = k + 1) begin
                acc = acc + {2'b0, (k == 16) ? {14'd0, x[257:256]} : x[16*k +: 16]};
                acc = {2'b0, acc[15:0]} + {16'd0, acc[17:16]};
            end
            acc = {2'b0, acc[15:0]} + {16'd0, acc[17:16]};
            res258 = (acc[15:0] == 16'hFFFF) ? 16'd0 : acc[15:0];
        end
    endfunction
    function automatic [15:0] mulm(input [15:0] x, input [15:0] y);
        reg [31:0] p;
        begin
            p = x * y;
            mulm = res258({226'd0, p});
        end
    endfunction
    function automatic [15:0] addm(input [15:0] x, input [15:0] y);
        addm = res258({241'd0, {1'b0, x} + {1'b0, y}});
    endfunction

    wire [15:0] lhs = addm(res258(reduced), sub ? rm : 16'd0);
    wire [15:0] rhs = addm(mulm(ra, rb), mulm(res258({2'b0, q}), rm));
    wire unused_ok = &{1'b0, n0prime};

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE; done <= 1'b0; r <= 0; rc_err <= 1'b0;
            aa <= 0; bb <= 0; nn <= 0; t <= 0; q <= 0; bit_index <= 0;
            ra <= 0; rb <= 0; rm <= 0;
        end else begin
            done <= 1'b0; rc_err <= 1'b0;
            case (state)
                IDLE: if (start) begin
                    aa <= a; bb <= b; nn <= modulus;
                    ra <= res258({2'b0, a}); rb <= res258({2'b0, b});
                    rm <= res258({2'b0, modulus});
                    t <= 0; q <= 0; bit_index <= 0; state <= RUN;
                end
                RUN: begin
                    t <= t_plus_n >> 1;
                    q[bit_index] <= t_plus_a[0];
                    if (bit_index == 8'd255) state <= REDUCE;
                    else bit_index <= bit_index + 1'b1;
                end
                REDUCE: begin
                    r <= reduced[255:0];
                    rc_err <= (lhs != rhs) || (reduced[257:256] != 2'b00);
                    done <= 1'b1;
                    state <= IDLE;
                end
                default: state <= IDLE;
            endcase
        end
    end
endmodule
