`timescale 1ns/1ps
// SPDX-License-Identifier: MIT
`include "mont_params.vh"
module tb_mod_n_mul;
    reg clk=0; always #5 clk=~clk;
    reg rst_n=0,start=0;
    reg [255:0] a=0,b=0;
    reg [255:0] expected=0;
    wire [255:0] r;
    wire done;
    integer timeout;
    mod_n_mul dut(.*);
    task check;
        input [255:0] aa,bb,want;
        begin
            @(negedge clk); a=aa; b=bb; expected=want; start=1;
            @(negedge clk);start=0;timeout=0;
            while(!done && timeout<2100) begin
                @(negedge clk);timeout=timeout+1;
            end
            if(!done || r!==expected)
                $fatal(1,"mod_n_mul expected=%h actual=%h",expected,r);
        end
    endtask
    initial begin
        repeat(4) @(negedge clk);
        rst_n=1;
        check(0,0,0);
        check(1,1,1);
        check(5,7,35);
        check(N_MOD-1,N_MOD-1,1);
        $display("mod_n_mul RTL PASS 4 arithmetic vectors");
        $finish;
    end
endmodule
