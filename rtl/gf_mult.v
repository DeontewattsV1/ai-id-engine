// SPDX-License-Identifier: MIT
// GF(2^11) multiply, mod x^11 + x^2 + 1. 11x11 combinational + reduction.
`timescale 1ns/1ps

module gf_mult (input [10:0] a, b, output [10:0] p);
    function automatic [10:0] multiply(input [10:0] x, y);
        reg [21:0] product;
        integer i;
        begin
            product = 0;
            for (i = 0; i < 11; i = i + 1)
                if (y[i]) product = product ^ ({11'b0, x} << i);
            for (i = 21; i >= 11; i = i - 1)
                if (product[i])
                    product = product ^ (22'h805 << (i - 11));
            multiply = product[10:0];
        end
    endfunction

    assign p = multiply(a, b);
endmodule
