// SPDX-License-Identifier: MIT
`timescale 1ns/1ps
`include "mont_params.vh"

module ec_arith (
    input  wire         clk, rst_n, start,
    input  wire         op,              // 0 = double, 1 = add
    input  wire [255:0] x1, y1, z1, x2, y2, z2,
    output reg  [255:0] x3, y3, z3,
    output reg          done
);
    reg [255:0] g [0:15];
    reg [5:0]   pc;
    reg [1:0]   st;
    reg         mm_start;
    reg [3:0]   mm_dst;   // destination latched for the pending product
    reg [255:0] mm_a, mm_b;
    wire [255:0] mm_r;
    wire         mm_done;

    mont_mul u_mm (.clk(clk), .rst_n(rst_n), .start(mm_start),
                   .a(mm_a), .b(mm_b), .modulus(P_MOD),
                   .n0prime(P_N0), .r(mm_r), .done(mm_done));

    // Pure field helpers. Inputs must be canonical (< P_MOD).
    function automatic [255:0] fp_add;
        input [255:0] a,b,m;
        reg [256:0] tmp;
        begin tmp={1'b0,a}+{1'b0,b};
              fp_add=(tmp >= {1'b0,m}) ? tmp-{1'b0,m} : tmp; end
    endfunction
    function automatic [255:0] fp_sub;
        input [255:0] a,b,m;
        begin fp_sub=(a>=b) ? (a-b) : (m-b+a); end
    endfunction

    // microcode: each step names a destination and a source pair
    task step_mul(input [3:0] dst, input [3:0] s1, input [3:0] s2);
        begin mm_a <= g[s1]; mm_b <= g[s2]; mm_dst <= dst; mm_start <= 1;
              pc <= pc + 1; st <= 1; end
    endtask

    integer k;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin st <= 0; done <= 0; mm_start <= 0; mm_dst <= 0; pc <= 0; end
        else begin
            done <= 0; mm_start <= 0;
            case (st)
                0: if (start) begin
                       g[0] <= x1; g[1] <= y1; g[2] <= z1;
                       g[3] <= x2; g[4] <= y2; g[5] <= z2; pc <= 0; st <= 2;
                   end
                1: if (mm_done) begin g[mm_dst] <= mm_r; st <= 2; end
                2: begin
                    if (op == 0) begin              // ---------- doubling
                        case (pc)
                            0: step_mul(6,2,2);     // delta = Z1^2
                            1: step_mul(7,1,1);     // gamma = Y1^2
                            2: step_mul(8,0,7);     // beta = X1*gamma
                            3: begin g[9]<=fp_sub(g[0],g[6],P_MOD);
                                     g[10]<=fp_add(g[0],g[6],P_MOD); pc<=4; end
                            4: step_mul(11,9,10);   // alpha=(X1-d)(X1+d)
                            5: begin
                                   // alpha = 3*(X1-d)(X1+d), NOT 4*alpha.
                                   g[11]<=fp_add(fp_add(g[11],g[11],P_MOD),g[11],P_MOD);
                                   pc<=6;
                               end
                            6: step_mul(12,11,11);  // alpha^2 after 3x update
                            7: begin
                                   g[12]<=fp_sub(g[12],fp_add(
                                     fp_add(fp_add(g[8],g[8],P_MOD),
                                            fp_add(g[8],g[8],P_MOD),P_MOD),
                                     fp_add(fp_add(g[8],g[8],P_MOD),
                                            fp_add(g[8],g[8],P_MOD),P_MOD),P_MOD),P_MOD);
                                   g[13]<=fp_add(g[1],g[2],P_MOD); pc<=8;
                               end
                            8: step_mul(13,13,13);
                            9: begin
                                   g[13]<=fp_sub(fp_sub(g[13],g[7],P_MOD),g[6],P_MOD);
                                   step_mul(14,7,7);
                               end
                            10: begin
                                    g[14]<=fp_add(fp_add(
                                      fp_add(g[14],g[14],P_MOD),
                                      fp_add(g[14],g[14],P_MOD),P_MOD),fp_add(
                                      fp_add(g[14],g[14],P_MOD),
                                      fp_add(g[14],g[14],P_MOD),P_MOD),P_MOD);
                                    g[15]<=fp_sub(fp_add(
                                      fp_add(g[8],g[8],P_MOD),
                                      fp_add(g[8],g[8],P_MOD),P_MOD),g[12],P_MOD);
                                    pc<=11;
                                end
                            11: step_mul(15,11,15);
                            12: begin
                                    x3<=g[12]; y3<=fp_sub(g[15],g[14],P_MOD);
                                    z3<=g[13]; done<=1; st<=0;
                                end
                        endcase
                    end else begin                   // ---------- addition
                        case (pc)
                            0: step_mul(6, 2, 2);        // Z1Z1
                            1: step_mul(7, 5, 5);        // Z2Z2
                            2: step_mul(8, 0, 7);        // U1
                            3: step_mul(9, 3, 6);        // U2
                            4: step_mul(10, 1, 5);       // Y1*Z2
                            5: step_mul(10, 10, 7);      // S1
                            6: step_mul(11, 4, 2);       // Y2*Z1
                            7: step_mul(11, 11, 6);      // S2
                            8: begin g[12] <= fp_sub(g[9],  g[8],  P_MOD);  // H
                                     g[13] <= fp_sub(g[11], g[10], P_MOD);  // r
                                     pc <= 9; end
                            9: step_mul(14, 12, 12);     // H2
                            10: step_mul(15, 14, 12);    // H3
                            11: step_mul(8,  8,  14);    // V
                            12: step_mul(9,  13, 13);    // r^2
                            13: begin
                                      g[9] <= fp_sub(fp_sub(g[9],g[15],P_MOD),
                                                    fp_add(g[8],g[8],P_MOD),P_MOD);
                                      g[10] <= fp_sub(g[8],fp_sub(
                                          fp_sub(g[9],g[15],P_MOD),
                                          fp_add(g[8],g[8],P_MOD),P_MOD),P_MOD);
                                      pc <= 14; end
                            14: step_mul(10, 13, 10);    // r*(V-X3)
                            15: step_mul(11, 10, 15);    // S1*H3
                            16: step_mul(12, 2, 5);      // Z1*Z2
                            17: step_mul(12, 12, 15);    // Z3 = Z1Z2H
                            18: begin
                                    // Y3 must use the computed value, not a stale register.
                                    // constant-time special cases
                                    if (g[12] == 256'd0) begin
                                        // H==0: either P==Q or P==-Q
                                        if (g[13] == 256'd0) begin
                                            x3 <= x1; y3 <= y1; z3 <= z1; // fallback
                                        end else begin
                                            x3 <= 0; y3 <= 256'd1; z3 <= 0; // infinity
                                        end
                                    end else begin
                                        x3 <= g[9]; y3 <= fp_sub(g[10],g[11],P_MOD); z3 <= g[12];
                                    end
                                    done <= 1; st <= 0;
                                end
                        endcase
                    end
                end
            endcase
        end
    end
endmodule
