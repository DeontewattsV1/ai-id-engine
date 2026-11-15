`timescale 1ns/1ps
// SPDX-License-Identifier: MIT
`include "mont_params.vh"
module tb_fp_inv;
    reg clk=0;always #5 clk=~clk;
    reg rst_n=0,start=0;
    reg [255:0] a=0,m=0,r2=0,expected=0;
    reg [31:0] n0prime=0;
    wire [255:0] r;wire done;
    integer timeout;
    fp_inv dut(.clk(clk),.rst_n(rst_n),.start(start),
               .a(a),.m(m),.r2(r2),.n0prime(n0prime),
               .r(r),.done(done));
    task check;
        input [255:0] aa,mm,rr2,want;
        input [31:0] nn0;
        begin
            @(negedge clk);a=aa;m=mm;r2=rr2;n0prime=nn0;
            expected=want;start=1;
            @(negedge clk);start=0;timeout=0;
            while(!done && timeout<140000) begin
                @(negedge clk);timeout=timeout+1;
            end
            if(!done || r!==expected)
                $fatal(1,"fp_inv mismatch got=%h expected=%h clocks=%0d",r,expected,timeout);
        end
    endtask
    initial begin
        repeat(3) @(negedge clk);rst_n=1;
        check(1,P_MOD,P_R2,1,P_N0);
        check(2,P_MOD,P_R2,(P_MOD+1)>>1,P_N0);
        check(2,N_MOD,N_R2,(N_MOD+1)>>1,N_N0);
        $display("fp_inv PASS 3 field and subgroup inverse vectors");
        $finish;
    end
endmodule
