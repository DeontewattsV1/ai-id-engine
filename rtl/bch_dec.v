// Syndrome, Berlekamp–Massey, and Chien-search decoder.
// SPDX-License-Identifier: MIT
`timescale 1ns/1ps

module bch_dec (
    input  wire         clk, rst_n, start,
    input  wire [2046:0] rx,
    output reg  [638:0]  msg,
    output reg           ok,        // 1 = decoded within t
    output reg           fail,
    output reg           done
);
    reg [10:0] synd [0:255];
    reg [10:0] sigma [0:128], sigma_b [0:128], omega;
    reg [10:0] alpha_pow [0:2046];
    reg [1:0]  st;
    reg [7:0]  iter, j;
    reg [8:0]  d, db;
    reg        L, Lb;
    reg [11:0] pos;
    reg [2046:0] e;
    integer i;

    function automatic [10:0] gf_mult(input [10:0] a, b);
        reg [21:0] product;
        integer bit_index;
        begin
            product = 0;
            for (bit_index = 0; bit_index < 11; bit_index = bit_index + 1)
                if (b[bit_index])
                    product = product ^ ({11'b0, a} << bit_index);
            for (bit_index = 21; bit_index >= 11; bit_index = bit_index - 1)
                if (product[bit_index])
                    product = product ^ (22'h805 << (bit_index - 11));
            gf_mult = product[10:0];
        end
    endfunction

    // alpha^i table from ROM
    initial $readmemh("alpha_pow.mem", alpha_pow);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin st <= 0; done <= 0; ok <= 0; fail <= 0; end
        else begin
            done <= 0; ok <= 0; fail <= 0;
            case (st)
                0: if (start) begin
                       // S1..S256 = sum_j r_j * alpha^(i*j)
                       for (i = 0; i < 256; i = i + 1) synd[i] <= 0;
                       pos <= 0; st <= 1;
                   end
                1: begin
                       for (i = 0; i < 256; i = i + 1)
                           if (rx[pos]) synd[i] <= synd[i] ^ alpha_pow[(i+1)*pos % 2047];
                       if (pos == 2046) begin st <= 2; iter <= 0; end
                       else pos <= pos + 1;
                   end
                2: begin  // Berlekamp-Massey, serialized
                       sigma[0] <= 11'd1; for (i = 1; i <= 128; i = i + 1) sigma[i] <= 0;
                       sigma_b <= 0; sigma_b[0] <= 11'd1;
                       L <= 0; Lb <= 0; db <= 0; st <= 3;
                   end
                3: begin
                       d = synd[iter];
                       for (j = 1; j <= L; j = j + 1)
                           d = d ^ gf_mult(sigma[j], synd[iter - j]);
                       if (d != 0 && 2*L <= iter) begin
                           for (i = 0; i <= 128; i = i + 1) begin
                               sigma_b[i] <= sigma[i];
                               sigma[i] <= sigma[i] ^ gf_mult(d, sigma_b[i] >> 1);
                           end
                           L <= iter + 1 - L; Lb <= L; db <= d;
                       end else if (d != 0) begin
                           for (i = 0; i <= 128; i = i + 1)
                               sigma[i] <= sigma[i] ^ gf_mult(d, sigma_b[i] >> 1);
                       end
                       if (iter == 255) st <= 4; else iter <= iter + 1;
                   end
                4: begin  // Chien search
                       e <= 0; pos <= 0; st <= 5;
                   end
                5: begin
                       omega = 0;
                       for (j = 0; j <= 128; j = j + 1)
                           omega = omega ^ gf_mult(sigma[j], alpha_pow[(j*pos) % 2047]);
                       if (omega == 0) e[pos] <= 1'b1;
                       if (pos == 2046) st <= 6; else pos <= pos + 1;
                   end
                6: begin
                       msg <= rx[638:0] ^ e[638:0];
                       if (L <= 128) ok <= 1; else fail <= 1;
                       done <= 1; st <= 0;
                   end
            endcase
        end
    end
endmodule
