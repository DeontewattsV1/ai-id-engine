// SPDX-License-Identifier: MIT
// GF(2^11) multiply, mod x^11 + x^2 + 1. 11x11 combinational + reduction.
`timescale 1ns/1ps

module gf_mult (input [10:0] a, b, output [10:0] p);
    wire [21:0] raw;
    genvar i, j;
    generate
        for (i = 0; i < 11; i = i + 1)
            for (j = 0; j < 11; j = j + 1)
                assign raw[i+j] = a[i] & b[j];
    endgenerate

    wire [10:0] r;
    assign r[10] = raw[10] ^ raw[21] ^ raw[13] ^ raw[20] ^ raw[12];
    assign r[9]  = raw[9]  ^ raw[20] ^ raw[12] ^ raw[19] ^ raw[11];
    assign r[8]  = raw[8]  ^ raw[19] ^ raw[11] ^ raw[18] ^ raw[10];
    assign r[7]  = raw[7]  ^ raw[18] ^ raw[10];
    assign r[6]  = raw[6]  ^ raw[17] ^ raw[9];
    assign r[5]  = raw[5]  ^ raw[16] ^ raw[8];
    assign r[4]  = raw[4]  ^ raw[15] ^ raw[7];
    assign r[3]  = raw[3]  ^ raw[14] ^ raw[6];
    assign r[2]  = raw[2]  ^ raw[13] ^ raw[5] ^ raw[21] ^ raw[12];
    assign r[1]  = raw[1]  ^ raw[12] ^ raw[4] ^ raw[20] ^ raw[11];
    assign r[0]  = raw[0]  ^ raw[11] ^ raw[3] ^ raw[19] ^ raw[10];
    assign p = r;
endmodule
