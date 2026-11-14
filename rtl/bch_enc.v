systematic LFSR division
// SPDX-License-Identifier: MIT
// g(x) coefficient ROM loaded from bch_g.mem (1408 entries, 11-bit).
`timescale 1ns/1ps

module bch_enc (
    input  wire         clk, rst_n, start,
    input  wire [638:0] msg,
    output reg  [1407:0] parity,
    output reg          done
);
    reg [10:0] lfsr [0:127];   // 128-stage pipelined LFSR
    reg [1407:0] g;            // generator, packed 128 coeffs
    reg [1:0] st;
    reg [10:0] fb;
    integer i, rnd;

    initial $readmemh("bch_g.mem", g);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin st <= 0; done <= 0; end
        else begin
            done <= 0;
            case (st)
                0: if (start) begin
                       for (i = 0; i < 128; i = i + 1) lfsr[i] <= 0;
                       rnd <= 0; st <= 1;
                   end
                1: begin
                       for (i = 0; i < 128; i = i + 1) begin
                           fb = lfsr[i] ^ (i < 11 ? msg[638 - (rnd*11 + i)] : 1'b0);
                           lfsr[i] <= lfsr[i+1] ^ gf_mult(fb, g[i*11 +: 11]);
                       end
                       if (rnd == 57) st <= 2; else rnd <= rnd + 1;
                   end
                2: begin
                       for (i = 0; i < 128; i = i + 1)
                           parity[i*11 +: 11] <= lfsr[i];
                       done <= 1; st <= 0;
                   end
            endcase
        end
    end
endmodule
