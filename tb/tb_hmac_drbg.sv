// SPDX-License-Identifier: MIT
// hmac_drbg vs. the Python reference (test/gen_drbg_vectors.py).
`timescale 1ns/1ps
`include "drbg_vectors.svh"
module tb_hmac_drbg;
    reg clk = 0, rst_n = 0, zeroize = 0, op_init = 0, op_update = 0, op_gen = 0, data_valid = 0;
    reg [175:0] data = 0;
    wire busy, done, inst; wire [255:0] out; wire [31:0] gen_count;
    integer errors = 0;
    hmac_drbg dut (.clk(clk), .rst_n(rst_n), .zeroize(zeroize), .op_init(op_init), .op_update(op_update),
        .op_gen(op_gen), .data(data), .data_valid(data_valid), .busy(busy), .done(done), .out(out),
        .instantiated(inst), .gen_count(gen_count));
    always #5 clk = ~clk;
    task op(input integer which, input [175:0] d, input dv);
        begin
            @(negedge clk); data = d; data_valid = dv;
            op_init = (which == 0); op_update = (which == 1); op_gen = (which == 2);
            @(negedge clk); op_init = 0; op_update = 0; op_gen = 0;
            while (!done) @(posedge clk);
            @(negedge clk);
        end
    endtask
    task expect_out(input [255:0] want, input [8*8-1:0] name);
        if (out !== want) begin errors = errors + 1; $display("FAIL %0s: got %h want %h", name, out, want); end
    endtask
    initial begin
        #22 rst_n = 1;
        if (inst) begin errors = errors + 1; $display("FAIL instantiated before init"); end
        op(0, `DRBG_SEED1, 1);
        if (!inst) begin errors = errors + 1; $display("FAIL not instantiated after init"); end
        op(2, 0, 0); expect_out(`DRBG_G1, "gen1");
        op(2, 0, 0); expect_out(`DRBG_G2, "gen2");
        if (gen_count != 2) begin errors = errors + 1; $display("FAIL gen_count %0d", gen_count); end
        op(1, `DRBG_SEED2, 1);
        if (gen_count != 0) begin errors = errors + 1; $display("FAIL gen_count not reset by reseed"); end
        op(2, 0, 0); expect_out(`DRBG_G3, "gen3");
        op(1, 0, 0);
        op(2, 0, 0); expect_out(`DRBG_G4, "gen4");
        @(negedge clk); zeroize = 1; @(negedge clk); zeroize = 0; @(negedge clk);
        if (inst || out !== 0) begin errors = errors + 1; $display("FAIL zeroize left state"); end
        if (errors == 0) $display("hmac_drbg RTL PASS 4 SP 800-90A reference blocks + reseed/zeroize");
        else $fatal(1, "hmac_drbg RTL FAIL (%0d)", errors);
        $finish;
    end
    initial begin #20000000; $fatal(1, "hmac_drbg timeout"); end
endmodule
