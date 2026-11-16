// SPDX-License-Identifier: MIT
module gf_mult_formal;
    (* anyconst *) reg [10:0] a, b;
    wire [10:0] product;

    gf_mult dut (.a(a), .b(b), .p(product));

    always @* begin
        assert(a != 0 || product == 0);
        assert(b != 0 || product == 0);
        assert(a != 1 || product == b);
        assert(b != 1 || product == a);
    end
endmodule
