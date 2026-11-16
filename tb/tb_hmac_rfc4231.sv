// SPDX-License-Identifier: MIT
// HMAC-SHA256 RFC 4231 test cases 1-5 (expected values asserted against the
// RFC text at generation time). Cases 6-7 use 131-byte keys; the RTL key port
// is 256 bits (keys <= 32 bytes, zero-padded per RFC 2104), so the host must
// pre-hash longer keys and those cases are out of the core's interface.
`timescale 1ns/1ps
module tb_hmac_rfc4231;
    reg clk=0; always #5 clk=~clk;
    reg rst_n=0, start=0; reg [255:0] key; reg [511:0] msg; reg [8:0] msg_bits;
    wire done; wire [255:0] mac; integer n=0, t;
    hmac_sha256 dut(.clk(clk),.rst_n(rst_n),.start(start),.key(key),.msg(msg),.msg_bits(msg_bits),.done(done),.mac(mac));
    task tc(input integer id, input [255:0] k, input [511:0] m, input [8:0] b, input [255:0] want, input integer bits); begin
        @(negedge clk); key=k; msg=m; msg_bits=b; start=1; @(negedge clk); start=0; t=0;
        while(!done && t<600) begin @(negedge clk); t=t+1; end
        if(!done || (mac >> (256-bits)) !== (want >> (256-bits))) $fatal(1,"RFC 4231 TC%0d: %h",id,mac);
        n=n+1; end endtask
    initial begin repeat(3) @(negedge clk); rst_n=1;
        tc(1, 256'h0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b000000000000000000000000, 512'h48692054686572650000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000, 9'd64, 256'hb0344c61d8db38535ca8afceaf0bf12b881dc200c9833da726e9376c2e32cff7, 256);
        tc(2, 256'h4a65666500000000000000000000000000000000000000000000000000000000, 512'h7768617420646f2079612077616e7420666f72206e6f7468696e673f000000000000000000000000000000000000000000000000000000000000000000000000, 9'd224, 256'h5bdcc146bf60754e6a042426089575c75a003f089d2739839dec58b964ec3843, 256);
        tc(3, 256'haaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa000000000000000000000000, 512'hdddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd0000000000000000000000000000, 9'd400, 256'h773ea91e36800e46854db8ebd09181a72959098b3ef8c122d9635514ced565fe, 256);
        tc(4, 256'h0102030405060708090a0b0c0d0e0f1011121314151617181900000000000000, 512'hcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcd0000000000000000000000000000, 9'd400, 256'h82558a389a443c0ea4cc819899f2083a85f0faa3e578f8077a2e3ff46729665b, 256);
        tc(5, 256'h0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c000000000000000000000000, 512'h546573742057697468205472756e636174696f6e0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000, 9'd160, 256'ha3b6167473100ee06e0c796c2955552bfa6f7c0a6a8aef8b93f860aab0cd20c5, 128);
        $display("hmac_sha256 RTL PASS %0d RFC 4231 test cases (TC1-TC5)", n);
        $finish;
    end
endmodule
