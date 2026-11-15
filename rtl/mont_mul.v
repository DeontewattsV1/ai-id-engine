// SPDX-License-Identifier: MIT
`timescale 1ns/1ps

module mont_mul #(parameter W = 8) (
    input  wire         clk, rst_n, start,
    input  wire [255:0] a, b, modulus,
    input  wire [31:0]  n0prime,
    output reg  [255:0] r,
    output reg          done
);
    reg [255:0] t;      // 9 words, t[8] carries
    reg [2:0]   i, j;
    reg [1:0]   st;
    reg [32:0]  c, s;
    reg [31:0]  m;
    reg [255:0] ta, tb, tmod;
    reg [31:0]  tn0;

    always @(*) begin
        ta = a; tb = b; tmod = modulus; tn0 = n0prime;
    end

    wire [31:0] a_i = ta[32*i +: 32];
    wire [31:0] b_j = tb[32*j +: 32];
    wire [31:0] m_j = tmod[32*j +: 32];
    wire [31:0] t_j = t[32*j +: 32];

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin st <= 0; done <= 0; r <= 0; t <= 0; end
        else begin
            done <= 0;
            case (st)
                0: if (start) begin t <= 0; i <= 0; j <= 0; st <= 1; end
                1: begin                        // multiply-accumulate row
                       c = {1'b0, t_j} + {1'b0, (a_i * b_j)} + 33'b0;
                       s = {1'b0, t_j} + {1'b0, (a_i * b_j)} + c[32];
                       t[32*j +: 32] <= s[31:0];
                       if (j == 7) begin
                           c = {1'b0, t[256 +: 32]} + c[32];
                           t[256 +: 32] <= c[31:0];
                           m <= (t[31:0] * tn0);   // t[0] * n0'
                           j <= 0; st <= 2;
                       end else j <= j + 1;
                   end
                2: begin                        // reduction row
                       c = {1'b0, t_j} + {1'b0, (m * m_j)} + 33'b0;
                       s = {1'b0, t_j} + {1'b0, (m * m_j)} + c[32];
                       if (j == 0) t[32*j +: 32] <= 0;
                       else        t[32*(j-1) +: 32] <= s[31:0];
                       if (j == 7) begin
                           c = {1'b0, t[256 +: 32]} + c[32];
                           t[224 +: 32] <= c[31:0];
                           t[256 +: 32] <= 0;
                           if (i == 7) st <= 3; else begin i <= i + 1; j <= 0; st <= 1; end
                       end else j <= j + 1;
                   end
                3: begin                        // unconditional conditional-subtract
                       r <= (t[255:0] >= tmod) ? (t[255:0] - tmod) : t[255:0];
                       done <= 1; st <= 0;
                   end
            endcase
        end
    end
endmodule
