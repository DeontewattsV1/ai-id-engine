// SPDX-License-Identifier: MIT
// Functions shared by secded39_enc / secded39_dec (included inside modules).
function automatic [38:0] secded39_encode(input [31:0] data_in);
    integer p, k, b;
    reg [38:0] w;
    begin
        w = 39'd0; k = 0;
        for (p = 1; p <= 38; p = p + 1)
            if ((p & (p - 1)) != 0) begin w[p] = data_in[k]; k = k + 1; end
        for (b = 0; b < 6; b = b + 1)
            for (p = 1; p <= 38; p = p + 1)
                if ((((p >> b) & 1) != 0) && (p != (1 << b))) w[1 << b] = w[1 << b] ^ w[p];
        w[0] = ^w[38:1];
        secded39_encode = w;
    end
endfunction
function automatic [5:0] secded39_syndrome(input [38:0] w);
    integer p;
    reg [5:0] s;
    begin
        s = 6'd0;
        for (p = 1; p <= 38; p = p + 1) if (w[p]) s = s ^ p[5:0];
        secded39_syndrome = s;
    end
endfunction
function automatic [31:0] secded39_data(input [38:0] w);
    integer p, k;
    reg [31:0] dv;
    begin
        dv = 32'd0; k = 0;
        for (p = 1; p <= 38; p = p + 1)
            if ((p & (p - 1)) != 0) begin dv[k] = w[p]; k = k + 1; end
        secded39_data = dv;
    end
endfunction
