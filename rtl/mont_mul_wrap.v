// SPDX-License-Identifier: MIT
`timescale 1ns/1ps
// Drop-in wrapper: MASK_EN=0 plain mont_mul, 1 two-share v2, 2 three-share.
// Unmasked operands come in, so the wrapper splits them with caller-supplied
// randomness (rnd: nine independent lanes, each uniform in [0, m)) and
// recombines the output shares. The split and recombine are deliberately
// outside the masked datapath, which is the part that TVLA evaluates.
// In a real integration the shares would come straight from a masked
// producer. The bundled draft tied a1=b1=0 and derived all randomness from
// one word XOR constants, which removed the masking completely.
module mont_mul_wrap #(parameter integer MASK_EN = 0) (
    input  wire          clk, rst_n, start,
    input  wire [255:0]  a, b, modulus,
    input  wire [31:0]   n0prime,
    input  wire [9*256-1:0] rnd,
    output wire [255:0]  r,
    output wire          done
);
    function automatic [255:0] msub(input [255:0] x, input [255:0] y,
                                    input [255:0] m);
        msub = (x >= y) ? x - y : x + (m - y);
    endfunction
    function automatic [255:0] madd(input [255:0] x, input [255:0] y,
                                    input [255:0] m);
        reg [256:0] s;
        begin
            s = {1'b0, x} + {1'b0, y};
            madd = (s >= {1'b0, m}) ? s[255:0] - m : s[255:0];
        end
    endfunction
    generate
        if (MASK_EN == 2) begin : g_m3
            wire [255:0] r0, r1, r2;
            mont_mul_masked3 u_m (.clk(clk), .rst_n(rst_n), .start(start),
                .a0(rnd[0*256 +: 256]), .a1(rnd[1*256 +: 256]), .a2(msub(msub(a, rnd[0*256 +: 256], modulus), rnd[1*256 +: 256], modulus)),
                .b0(rnd[2*256 +: 256]), .b1(rnd[3*256 +: 256]), .b2(msub(msub(b, rnd[2*256 +: 256], modulus), rnd[3*256 +: 256], modulus)),
                .modulus(modulus), .n0prime(n0prime),
                .r_p0(rnd[4*256 +: 256]), .r_p1(rnd[5*256 +: 256]), .r_c(rnd[6*256 +: 256]), .r_s(rnd[7*256 +: 256]), .r_t(rnd[8*256 +: 256]),
                .r0(r0), .r1(r1), .r2(r2), .done(done));
            assign r = madd(madd(r0, r1, modulus), r2, modulus);
        end else if (MASK_EN == 1) begin : g_m2
            wire [255:0] r0, r1;
            wire unused_ok = &{1'b0, rnd[2*256 +: 256], rnd[7*256 +: 512]};
            mont_mul_masked_v2 u_m (.clk(clk), .rst_n(rst_n), .start(start),
                .a0(rnd[0*256 +: 256]), .a1(msub(a, rnd[0*256 +: 256], modulus)),
                .b0(rnd[1*256 +: 256]), .b1(msub(b, rnd[1*256 +: 256], modulus)),
                .modulus(modulus), .n0prime(n0prime),
                .r_p0(rnd[3*256 +: 256]), .r_p1(rnd[4*256 +: 256]), .r_c(rnd[5*256 +: 256]), .r_s(rnd[6*256 +: 256]),
                .r0(r0), .r1(r1), .done(done));
            assign r = madd(r0, r1, modulus);
        end else begin : g_plain
            wire unused_ok = &{1'b0, rnd};
            mont_mul u_m (.clk(clk), .rst_n(rst_n), .start(start), .a(a),
                .b(b), .modulus(modulus), .n0prime(n0prime), .r(r),
                .done(done));
        end
    endgenerate
endmodule
