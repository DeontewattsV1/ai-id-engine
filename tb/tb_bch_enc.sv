// SPDX-License-Identifier: MIT
`timescale 1ns/1ps
module tb_bch_enc;
    reg clk=0;
    always #5 clk=~clk;
    reg rst_n=0,start=0;
    reg [638:0] msg=0;
    reg [1407:0] expected=0;
    wire [1407:0] parity;
    wire done;
    integer fd,got,cases=0,timeout;
    bch_enc dut(.*);
    initial begin
        fd=$fopen("test/bch_vectors.txt","r");
        if(!fd) $fatal(1,"missing BCH vectors");
        repeat(3) @(negedge clk);
        rst_n=1;
        while (!$feof(fd)) begin
            got=$fscanf(fd,"%h %h\n",msg,expected);
            if(got==2) begin
                @(negedge clk);start=1;
                @(negedge clk);start=0;
                timeout=0;
                while(!done && timeout<650) begin
                    @(negedge clk);timeout=timeout+1;
                end
                if(!done || parity!==expected)
                    $fatal(1,"bch_enc vector %0d mismatch",cases);
                cases=cases+1;
            end
        end
        $fclose(fd);
        if(cases!=12) $fatal(1,"expected 12, got %0d",cases);
        $display("bch_enc RTL PASS %0d vectors",cases);
        $finish;
    end
endmodule
