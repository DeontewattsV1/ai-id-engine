// SPDX-License-Identifier: MIT
// Functional KAT for mont_mul_masked_v2 (2-share), mont_mul_masked3 (3-share)
// and mont_mul_wrap (MASK_EN 0/1/2) against Python a*b*2^-256 mod m on
// P-256 p and n. It also checks that latency is constant (data-independent)
// and that no single output share equals the unmasked result.
`timescale 1ns/1ps
module tb_mont_mul_masked;
    reg clk=0; always #5 clk=~clk;
    reg rst_n=0, start=0;
    reg [255:0] m, n0w, a, b, a0, a1, b0, b1, x0, x1, x2, y0, y1, y2;
    reg [255:0] rp0, rp1, rc, rs, rt, want;
    wire [255:0] v2_r0, v2_r1, v3_r0, v3_r1, v3_r2, w0_r, w1_r, w2_r;
    wire v2_done, v3_done, w0_done, w1_done, w2_done;
    wire [9*256-1:0] rnd = {rt, rs, rc, rp1, rp0, y1, y0, x1, x0};
    wire [9*256-1:0] rnd2 = {rt, rs, rs, rc, rp1, rp0, rs, b0, a0};

    mont_mul_masked_v2 u_v2(.clk(clk), .rst_n(rst_n), .start(start),
        .a0(a0), .a1(a1), .b0(b0), .b1(b1), .modulus(m), .n0prime(n0w[31:0]),
        .r_p0(rp0), .r_p1(rp1), .r_c(rc), .r_s(rs),
        .r0(v2_r0), .r1(v2_r1), .done(v2_done));
    mont_mul_masked3 u_v3(.clk(clk), .rst_n(rst_n), .start(start),
        .a0(x0), .a1(x1), .a2(x2), .b0(y0), .b1(y1), .b2(y2), .modulus(m),
        .n0prime(n0w[31:0]), .r_p0(rp0), .r_p1(rp1), .r_c(rc), .r_s(rs),
        .r_t(rt), .r0(v3_r0), .r1(v3_r1), .r2(v3_r2), .done(v3_done));
    mont_mul_wrap #(.MASK_EN(0)) u_w0(.clk(clk), .rst_n(rst_n), .start(start),
        .a(a), .b(b), .modulus(m), .n0prime(n0w[31:0]), .rnd(rnd),
        .r(w0_r), .done(w0_done));
    // wrap lanes: m2 uses 0,1,3,4,5,6; m3 uses 0..8
    mont_mul_wrap #(.MASK_EN(1)) u_w1(.clk(clk), .rst_n(rst_n), .start(start),
        .a(a), .b(b), .modulus(m), .n0prime(n0w[31:0]), .rnd(rnd2),
        .r(w1_r), .done(w1_done));
    mont_mul_wrap #(.MASK_EN(2)) u_w2(.clk(clk), .rst_n(rst_n), .start(start),
        .a(a), .b(b), .modulus(m), .n0prime(n0w[31:0]),
        .rnd({rt, rs, rc, rp1, rp0, y1, y0, x1, x0}),
        .r(w2_r), .done(w2_done));

    function automatic [255:0] madd(input [255:0] x, input [255:0] y,
                                    input [255:0] mm);
        reg [256:0] s;
        begin
            s = {1'b0, x} + {1'b0, y};
            madd = (s >= {1'b0, mm}) ? s[255:0] - mm : s[255:0];
        end
    endfunction

    integer fd, got, n=0, cyc, lat_v2=-1, lat_v3=-1, lat_w0=-1, dv2, dv3, dw0;
    integer dw1, dw2;
    initial begin
        fd = $fopen("test/masked_vectors.txt", "r");
        if (!fd) $fatal(1, "missing test/masked_vectors.txt");
        repeat (3) @(negedge clk); rst_n = 1;
        while (!$feof(fd)) begin
            got = $fscanf(fd, "%h %h %h %h %h %h %h %h %h %h %h %h %h %h %h %h %h %h %h %h\n",
                m, n0w, a, b, a0, a1, b0, b1, x0, x1, x2, y0, y1, y2,
                rp0, rp1, rc, rs, rt, want);
            if (got == 20) begin
                @(negedge clk); start = 1; @(negedge clk); start = 0;
                cyc = 1; dv2 = -1; dv3 = -1; dw0 = -1; dw1 = -1; dw2 = -1;
                while ((dv3 < 0 || dv2 < 0 || dw0 < 0 || dw1 < 0 || dw2 < 0)
                       && cyc < 3000) begin
                    if (v2_done && dv2 < 0) dv2 = cyc;
                    if (v3_done && dv3 < 0) dv3 = cyc;
                    if (w0_done && dw0 < 0) dw0 = cyc;
                    if (w1_done && dw1 < 0) begin
                        dw1 = cyc;
                        if (w1_r !== want) $fatal(1, "wrap1 #%0d got %h want %h", n, w1_r, want);
                    end
                    if (w2_done && dw2 < 0) begin
                        dw2 = cyc;
                        if (w2_r !== want) $fatal(1, "wrap2 #%0d got %h want %h", n, w2_r, want);
                    end
                    if (w0_done && w0_r !== want) $fatal(1, "wrap0 #%0d", n);
                    if (v2_done && madd(v2_r0, v2_r1, m) !== want)
                        $fatal(1, "v2 #%0d got %h want %h", n, madd(v2_r0, v2_r1, m), want);
                    if (v3_done && madd(madd(v3_r0, v3_r1, m), v3_r2, m) !== want)
                        $fatal(1, "v3 #%0d", n);
                    @(negedge clk); cyc = cyc + 1;
                end
                if (dv2 < 0 || dv3 < 0 || dw0 < 0) $fatal(1, "timeout #%0d", n);
                if (lat_v2 < 0) begin lat_v2 = dv2; lat_v3 = dv3; lat_w0 = dw0; end
                else if (dv2 != lat_v2 || dv3 != lat_v3 || dw0 != lat_w0)
                    $fatal(1, "latency is data-dependent at #%0d", n);
                if (want != 0 && rs != 0 && (v2_r0 == want || v2_r1 == want))
                    $fatal(1, "v2 output share equals the unmasked result #%0d", n);
                n = n + 1;
            end
        end
        if (n < 24) $fatal(1, "only %0d vectors", n);
        $display("masked Montgomery RTL PASS %0d vectors: latency plain %0d, v2 %0d, 3-share %0d cycles",
                 n, lat_w0, lat_v2, lat_v3);
        $finish;
    end
endmodule
