// SPDX-License-Identifier: MIT
// trng health tests: healthy noise yields seeds; stuck-at trips the
// Repetition Count Test; a 90%-biased source trips the Adaptive Proportion Test.
`timescale 1ns/1ps
module tb_trng;
    reg clk = 0, rst_n = 0, zeroize = 0, ent = 0, ack = 0;
    wire [175:0] seed; wire seed_valid, fail; wire [1:0] cause;
    integer errors = 0, seeds = 0, mode = 0, n = 0;
    trng #(.SAMPLE_DIV(1)) dut (.clk(clk), .rst_n(rst_n), .zeroize(zeroize), .ent_bit(ent),
        .seed_ack(ack), .seed(seed), .seed_valid(seed_valid), .fail(fail), .fail_cause(cause));
    always #5 clk = ~clk;
    // mode 0: random, 1: stuck at 1, 2: "1111111110" repeated (90% ones, runs of 9)
    always @(negedge clk) begin
        n = n + 1;
        case (mode)
            0: ent = $random;
            1: ent = 1'b1;
            default: ent = (n % 10) != 0;
        endcase
        if (seed_valid && !ack) seeds = seeds + 1;
        ack = seed_valid && !ack;
    end
    task restart(input integer m);
        begin rst_n = 0; mode = m; seeds = 0; repeat (3) @(posedge clk); rst_n = 1; end
    endtask
    initial begin
        restart(0);
        repeat (20000) @(posedge clk);
        if (fail || seeds < 50) begin errors = errors + 1; $display("FAIL healthy source: fail=%0d seeds=%0d", fail, seeds); end
        restart(1);
        repeat (200) @(posedge clk);
        if (!fail || cause != 2'b01) begin errors = errors + 1; $display("FAIL stuck-at not caught by RCT: fail=%0d cause=%b", fail, cause); end
        seeds = 0; repeat (500) @(posedge clk);
        if (seeds != 0) begin errors = errors + 1; $display("FAIL seeds released after failure"); end
        restart(2);
        repeat (3000) @(posedge clk);
        if (!fail || cause[1] != 1'b1) begin errors = errors + 1; $display("FAIL bias not caught by APT: fail=%0d cause=%b", fail, cause); end
        if (errors == 0) $display("trng RTL PASS healthy/stuck-at(RCT)/biased(APT) cases");
        else $fatal(1, "trng RTL FAIL (%0d)", errors);
        $finish;
    end
endmodule
