// SPDX-License-Identifier: MIT
`timescale 1ns/1ps
`include "mont_params.vh"

// Top-level container module to satisfy Verilator's DECLFILENAME rule
// (first module name must match the filename base "fp_ops").
// This module is intentionally empty and not instantiated.
module fp_ops;
endmodule

module fp_add (input [255:0] a, b, m, output [255:0] r);
    wire [256:0] s = {1'b0, a} + {1'b0, b};
    assign r = (s >= {1'b0, m}) ? s[255:0] - m : s[255:0];
endmodule

module fp_sub (input [255:0] a, b, m, output [255:0] r);
    wire [256:0] d = {1'b0, a} - {1'b0, b};
    assign r = d[256] ? d[255:0] + m : d[255:0];
endmodule

// Fermat modular inverse over odd prime m (P_MOD or N_MOD).
// 256 fixed exponent iterations; two Montgomery passes per bit.
// a must be a NONZERO canonical field element. Not DPA masked.
module fp_inv (
    input wire clk,rst_n,start,
    input wire [255:0] a,m,
    input wire [31:0] n0prime,
    input wire [255:0] r2,
    output reg [255:0] r,
    output reg done
);
    reg [3:0] st;
    reg [255:0] m_reg, a_reg, r2_reg, one_m, base_m, acc_m, square;
    reg [255:0] exponent;
    reg [31:0] n0_reg;
    reg [7:0] bit_idx;
    reg mm_start;
    reg [255:0] mm_a,mm_b;
    wire [255:0] mm_r;
    wire mm_done;
    mont_mul mm(.clk(clk),.rst_n(rst_n),.start(mm_start),
        .a(mm_a),.b(mm_b),.modulus(m_reg),.n0prime(n0_reg),
        .r(mm_r),.done(mm_done));
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            st<=0;done<=0;mm_start<=0;r<=0;
            m_reg<=0;a_reg<=0;r2_reg<=0;one_m<=0;
            base_m<=0;acc_m<=0;square<=0;exponent<=0;
            bit_idx<=0;mm_a<=0;mm_b<=0;n0_reg<=0;
        end else begin
            done<=0;mm_start<=0;
            case(st)
                0: if(start) begin
`ifndef SYNTHESIS
                    if(a==0 || a>=m || !m[0]) $fatal(1,"fp_inv invalid input");
`endif
                    m_reg<=m; a_reg<=a; r2_reg<=r2;
                    n0_reg<=n0prime; exponent<=m-256'd2;
                    mm_a<=256'd1;mm_b<=r2;mm_start<=1;st<=1;
                end
                1: if(mm_done) begin one_m<=mm_r;st<=2; end
                2: begin mm_a<=a_reg;mm_b<=r2_reg;mm_start<=1;st<=3; end
                3: if(mm_done) begin
                    base_m<=mm_r;acc_m<=one_m;bit_idx<=8'd255;st<=4;
                end
                4: begin mm_a<=acc_m;mm_b<=acc_m;mm_start<=1;st<=5; end
                5: if(mm_done) begin square<=mm_r;st<=6; end
                6: begin
                    mm_a<=square;
                    mm_b<=exponent[bit_idx]?base_m:one_m;
                    mm_start<=1;st<=7;
                end
                7: if(mm_done) begin
                    acc_m<=mm_r;
                    if(bit_idx==0) st<=8;
                    else begin bit_idx<=bit_idx-1'b1;st<=4; end
                end
                8: begin mm_a<=acc_m;mm_b<=256'd1;mm_start<=1;st<=9; end
                9: if(mm_done) begin r<=mm_r;done<=1;st<=0; end
                default: st<=0;
            endcase
        end
    end
endmodule
