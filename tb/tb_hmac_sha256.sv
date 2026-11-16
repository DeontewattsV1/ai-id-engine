// SPDX-License-Identifier: MIT
// HMAC-SHA256 known-answer test. Expected MACs come from Python's hmac
// module (RFC 2104) for a fixed 32-byte key and messages of 0..55 bytes,
// covering every message length used by dice_cdi and key_ladder.
`timescale 1ns/1ps
module tb_hmac_sha256;
    reg clk=0; always #5 clk=~clk;
    reg rst_n=0, start=0;
    reg [255:0] key=256'h808182838485868788898a8b8c8d8e8f909192939495969798999a9b9c9d9e9f;
    reg [511:0] msg=0;
    reg [8:0] msg_bits=0;
    wire done;
    wire [255:0] mac;
    integer n=0;
    hmac_sha256 dut(.clk(clk),.rst_n(rst_n),.start(start),.key(key),
                    .msg(msg),.msg_bits(msg_bits),.done(done),.mac(mac));
    task check;
        input [511:0] m;
        input [8:0] b;
        input [255:0] want;
        integer timeout;
        begin
            @(negedge clk); msg=m; msg_bits=b; start=1;
            @(negedge clk); start=0; timeout=0;
            while(!done && timeout<400) begin @(negedge clk); timeout=timeout+1; end
            if(!done || mac!==want)
                $fatal(1,"HMAC mismatch bits=%0d got=%h want=%h",b,mac,want);
            n=n+1;
        end
    endtask
    initial begin
        repeat(3) @(negedge clk); rst_n=1;
        check(512'h00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000, 9'd0, 256'h93c3dd57a642d6e51b170ae4c59aa2a652cce239db0b23bcb6f4a2e8f4699d8f);
        check(512'h61626300000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000, 9'd24, 256'hbdd7c155b3722fddb816b7fded299706ed08b2e5d0ff0ae5e695fc8086b223dc);
        check(512'h52415443000000070000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000, 9'd64, 256'hff69c69d9f441bc70f6f8a9125957aadab455c3bbbcb4cce6a9b7f796003ecf4);
        check(512'h414c494161692d69642d656e67696e652d7631000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000, 9'd160, 256'h84ae7d0a2b24be883a1882d45e562baac6a5289f217e67c4af2dc1e7c57b988f);
        check(512'h000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f202122232425262728292a2b2c2d2e2f30313233000000000000000000000000, 9'd416, 256'hf9fce8f49f376d208198a49e36b848c7578188f75779661815bb9eb807e7478e);
        check(512'h6465666768696a6b6c6d6e6f707172737475767778797a7b7c7d7e7f808182838485868788898a8b8c8d8e8f909192939495969798999a000000000000000000, 9'd440, 256'h81e3afcf0ed192b69820a4f58a2048db513887d9fed55809bb337d215e4f3b67);
        $display("hmac_sha256 RTL PASS %0d RFC 2104 vectors", n);
        $finish;
    end
endmodule
