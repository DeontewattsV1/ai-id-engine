`timescale 1ns/1ps
// SPDX-License-Identifier: MIT
// n-field multiplication using four Montgomery passes: to R-domain,
// product in R-domain, and explicit exit via mont_mul(product_R, 1).
// Inputs MUST be canonical, < N_MOD; not DPA masked.
// Isolated arithmetic building block, NOT a valid ECDSA signer.
`include "mont_params.vh"
module mod_n_mul(
    input wire clk,rst_n,start,
    input wire [255:0] a,b,
    output reg [255:0] r,
    output reg done
);
    reg [2:0] st;
    reg mm_start;
    reg [255:0] mm_a,mm_b;
    reg [255:0] aa_m,bb_m,prod_m;
    wire [255:0] mm_r;
    wire mm_done;
    mont_mul mm(.clk(clk),.rst_n(rst_n),.start(mm_start),
        .a(mm_a),.b(mm_b),.modulus(N_MOD),.n0prime(N_N0),
        .r(mm_r),.done(mm_done));
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            st<=0;mm_start<=0;r<=0;done<=0;
            mm_a<=0;mm_b<=0;aa_m<=0;bb_m<=0;prod_m<=0;
        end else begin
            done<=0;mm_start<=0;
            case(st)
                0: if(start) begin
`ifndef SYNTHESIS
                    if(a>=N_MOD || b>=N_MOD)
                        $fatal(1,"noncanonical mod_n_mul operands");
`endif
                    mm_a<=a;mm_b<=N_R2;mm_start<=1;st<=1;
                end
                1: if(mm_done) begin aa_m<=mm_r;st<=2; end
                2: begin mm_a<=b;mm_b<=N_R2;mm_start<=1;st<=3; end
                3: if(mm_done) begin bb_m<=mm_r;st<=4; end
                4: begin mm_a<=aa_m;mm_b<=bb_m;mm_start<=1;st<=5; end
                5: if(mm_done) begin prod_m<=mm_r;st<=6; end
                6: begin mm_a<=prod_m;mm_b<=256'd1;mm_start<=1;st<=7; end
                7: if(mm_done) begin r<=mm_r;done<=1;st<=0; end
                default: st<=0;
            endcase
        end
    end
endmodule
