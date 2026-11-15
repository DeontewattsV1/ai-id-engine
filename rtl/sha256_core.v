// SPDX-License-Identifier: MIT
`timescale 1ns/1ps
// SHA-256 compression of exactly one PREPADDED 512-bit message block.
// Uses standard initial IV; NOT a multi-block streaming hash engine.
// Caller must supply correct SHA-256 padding. See tb/tb_sha256_core.sv.
module sha256_core(
    input wire clk, rst_n, start,
    input wire [511:0] block,
    output reg busy, done,
    output reg [255:0] digest
);
    function automatic [31:0] rotr;
        input [31:0] x;
        input [4:0] n;
        begin rotr=(x>>n)|(x<<(32-n)); end
    endfunction
    function automatic [31:0] BS0;
        input [31:0] x;
        begin BS0=rotr(x,2)^rotr(x,13)^rotr(x,22); end
    endfunction
    function automatic [31:0] BS1;
        input [31:0] x;
        begin BS1=rotr(x,6)^rotr(x,11)^rotr(x,25); end
    endfunction
    function automatic [31:0] SS0;
        input [31:0] x;
        begin SS0=rotr(x,7)^rotr(x,18)^(x>>3); end
    endfunction
    function automatic [31:0] SS1;
        input [31:0] x;
        begin SS1=rotr(x,17)^rotr(x,19)^(x>>10); end
    endfunction
    reg [31:0] k[0:63];
    initial begin
        k[ 0]=32'h428a2f98; k[ 1]=32'h71374491; k[ 2]=32'hb5c0fbcf; k[ 3]=32'he9b5dba5;
        k[ 4]=32'h3956c25b; k[ 5]=32'h59f111f1; k[ 6]=32'h923f82a4; k[ 7]=32'hab1c5ed5;
        k[ 8]=32'hd807aa98; k[ 9]=32'h12835b01; k[10]=32'h243185be; k[11]=32'h550c7dc3;
        k[12]=32'h72be5d74; k[13]=32'h80deb1fe; k[14]=32'h9bdc06a7; k[15]=32'hc19bf174;
        k[16]=32'he49b69c1; k[17]=32'hefbe4786; k[18]=32'h0fc19dc6; k[19]=32'h240ca1cc;
        k[20]=32'h2de92c6f; k[21]=32'h4a7484aa; k[22]=32'h5cb0a9dc; k[23]=32'h76f988da;
        k[24]=32'h983e5152; k[25]=32'ha831c66d; k[26]=32'hb00327c8; k[27]=32'hbf597fc7;
        k[28]=32'hc6e00bf3; k[29]=32'hd5a79147; k[30]=32'h06ca6351; k[31]=32'h14292967;
        k[32]=32'h27b70a85; k[33]=32'h2e1b2138; k[34]=32'h4d2c6dfc; k[35]=32'h53380d13;
        k[36]=32'h650a7354; k[37]=32'h766a0abb; k[38]=32'h81c2c92e; k[39]=32'h92722c85;
        k[40]=32'ha2bfe8a1; k[41]=32'ha81a664b; k[42]=32'hc24b8b70; k[43]=32'hc76c51a3;
        k[44]=32'hd192e819; k[45]=32'hd6990624; k[46]=32'hf40e3585; k[47]=32'h106aa070;
        k[48]=32'h19a4c116; k[49]=32'h1e376c08; k[50]=32'h2748774c; k[51]=32'h34b0bcb5;
        k[52]=32'h391c0cb3; k[53]=32'h4ed8aa4a; k[54]=32'h5b9cca4f; k[55]=32'h682e6ff3;
        k[56]=32'h748f82ee; k[57]=32'h78a5636f; k[58]=32'h84c87814; k[59]=32'h8cc70208;
        k[60]=32'h90befffa; k[61]=32'ha4506ceb; k[62]=32'hbef9a3f7; k[63]=32'hc67178f2;
    end
    reg [31:0] w[0:63];
    reg [31:0] a,b,c,d,e,f,g,h;
    reg [6:0] round;
    reg active;
    integer j;
    wire [31:0] current_word = (round < 16) ? w[round] :
        (SS1(w[round-2]) + w[round-7] + SS0(w[round-15]) + w[round-16]);
    wire [31:0] T1 = h + BS1(e) + ((e & f) ^ (~e & g)) + k[round] + current_word;
    wire [31:0] T2 = BS0(a) + ((a & b) ^ (a & c) ^ (b & c));
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            busy<=0; done<=0; active<=0; round<=0; digest<=0;
        end else begin
            done<=0;
            if (start && !busy) begin
                for(j=0;j<16;j=j+1) w[j]<=block[511-32*j -:32];
                a<=32'h6a09e667; b<=32'hbb67ae85;
                c<=32'h3c6ef372; d<=32'ha54ff53a;
                e<=32'h510e527f; f<=32'h9b05688c;
                g<=32'h1f83d9ab; h<=32'h5be0cd19;
                round<=0; busy<=1; active<=1;
            end else if (active) begin
                w[round]<=current_word;
                h<=g; g<=f; f<=e;
                e<=d+T1; d<=c; c<=b; b<=a; a<=T1+T2;
                if (round==63) begin
                    digest[255:224] <= 32'h6a09e667 + T1+T2;
                    digest[223:192] <= 32'hbb67ae85 + a;
                    digest[191:160] <= 32'h3c6ef372 + b;
                    digest[159:128] <= 32'ha54ff53a + c;
                    digest[127:96] <= 32'h510e527f + d+T1;
                    digest[95:64] <= 32'h9b05688c + e;
                    digest[63:32] <= 32'h1f83d9ab + f;
                    digest[31:0] <= 32'h5be0cd19 + g;
                    active<=0; busy<=0; done<=1;
                end else round<=round+1'b1;
            end
        end
    end
endmodule
