// SPDX-License-Identifier: MIT
`timescale 1ns/1ps
`include "mont_params.vh"

module fp_add (input [255:0] a, b, m, output [255:0] r);
    wire [256:0] s = {1'b0, a} + {1'b0, b};
    assign r = (s >= {1'b0, m}) ? s[255:0] - m : s[255:0];
endmodule

module fp_sub (input [255:0] a, b, m, output [255:0] r);
    wire [256:0] d = {1'b0, a} - {1'b0, b};
    assign r = d[256] ? d[255:0] + m : d[255:0];
endmodule

// one-shot modular inverse by Fermat: a^(m-2). 256 sq + ~128 mul.
module fp_inv (
    input  wire         clk, rst_n, start,
    input  wire [255:0] a, m,
    input  wire [31:0]  n0prime, r2,
    output reg  [255:0] r,
    output reg          done
);
    reg [255:0] base, acc, e;
    reg [9:0]   i;
    reg [1:0]   st;
    wire [255:0] mm_r;
    wire         mm_done;
    reg          mm_start;
    reg [255:0]  mm_a, mm_b;
    reg          use_acc;

    mont_mul u_mm (.clk(clk), .rst_n(rst_n), .start(mm_start),
                   .a(mm_a), .b(mm_b), .modulus(m),
                   .n0prime(n0prime), .r(mm_r), .done(mm_done));

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin st <= 0; done <= 0; mm_start <= 0; r <= 0; end
        else begin
            done <= 0; mm_start <= 0;
            case (st)
                0: if (start) begin
                       base <= a; acc <= r2;      // acc = 1 in Montgomery form
                       e <= m - 2; i <= 0; st <= 1;
                   end
                1: begin                          // square always
                       mm_a <= base; mm_b <= base; mm_start <= 1; st <= 2;
                   end
                2: if (mm_done) begin
                       base <= mm_r;
                       if (e[0]) begin
                           mm_a <= acc; mm_b <= base; mm_start <= 1; st <= 3;
                       end else begin
                           e <= e >> 1; i <= i + 1;
                           if (i == 255) st <= 5; else st <= 1;
                       end
                   end
                3: if (mm_done) begin
                       acc <= mm_r; e <= e >> 1; i <= i + 1;
                       if (i == 255) st <= 5; else st <= 1;
                   end
                5: begin                          // out of Montgomery form
                       mm_a <= acc; mm_b <= 256'd1; mm_start <= 1; st <= 6;
                   end
                6: if (mm_done) begin r <= mm_r; done <= 1; st <= 0; end
            endcase
        end
    end
endmodule
