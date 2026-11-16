// SPDX-License-Identifier: MIT
`timescale 1ns/1ps
module tb_sha256_core;
    reg clk=0; always #5 clk=~clk;
    reg rst_n=0,start=0;
    reg [511:0] block=0;
    wire busy,done;
    wire [255:0] digest;
    sha256_core dut(.*);
    task check;
        input [511:0] blk;
        input [255:0] want;
        integer timeout;
        begin
            @(negedge clk); block=blk; start=1;
            @(negedge clk); start=0; timeout=0;
            while(!done && timeout<70) begin
                @(negedge clk); timeout=timeout+1;
            end
            if(!done || digest!==want)
                $fatal(1,"SHA256 mismatch got=%h expected=%h cycles=%0d",digest,want,timeout);
        end
    endtask
    initial begin
        repeat(3) @(negedge clk);
        rst_n=1;
        check({8'h80,440'd0,64'd0},
            256'he3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855);
        check({8'h61,8'h80,432'd0,64'd8},
            256'hca978112ca1bbdcafac231b39a23dc4da786eff8147c4e72b9807785afee48bb);
        check({8'h61,8'h62,8'h63,8'h80,416'd0,64'd24},
            256'hba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad);
        $display("sha256_core RTL PASS 3 NIST-format KAT vectors");
        $finish;
    end
endmodule
