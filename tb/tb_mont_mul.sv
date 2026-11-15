// SPDX-License-Identifier: MIT
`timescale 1ns/1ps
module tb_mont_mul;
    reg clk=0;
    always #5 clk=~clk;
    reg rst_n=0,start=0;
    reg [255:0] a=0,b=0,modulus=0;
    reg [31:0] n0prime=0;
    wire [255:0] r;
    wire done;
    reg [255:0] expected;
    integer fd,got,cases=0,timeout;
    mont_mul dut(.*);
    initial begin
        fd=$fopen("test/mont_vectors.txt","r");
        if (!fd) $fatal(1,"missing Montgomery vectors");
        repeat(3) @(negedge clk);
        rst_n=1;
        while (!$feof(fd)) begin
            got=$fscanf(fd,"%h %h %h %h %h\n",modulus,n0prime,a,b,expected);
            if (got==5) begin
                @(negedge clk);start=1;
                @(negedge clk);start=0;
                timeout=0;
                while (!done && timeout<270) begin
                    @(negedge clk);timeout=timeout+1;
                end
                if (!done || r!==expected)
                    $fatal(1,"mont vector %0d: actual %h expected %h",cases,r,expected);
                cases=cases+1;
            end
        end
        $fclose(fd);
        if(cases!=32) $fatal(1,"expected 32, got %0d",cases);
        $display("mont_mul RTL PASS %0d vectors",cases);
        $finish;
    end
endmodule
