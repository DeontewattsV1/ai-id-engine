// SPDX-License-Identifier: MIT
// Fault injection on pcr_bank built with `AI_ID_FAULT_DETECT
// (docs/FAULT-DETECTION.md). Faults are bit flips written straight into the
// coded PCR words or the controller state (single-event-upset model).
//   0. power-up values before the first reset do not latch the alarm;
//   1. clean extends match SHA-256(PCR || d) from test/gen_pcr_vectors.py and
//      never raise fault or fd_sec;
//   2. every single-bit flip of every coded word (128 x 39) is corrected on
//      read (digest_out and flat unchanged), sets fd_sec, and does not raise
//      fault; an extend over a corrected word still gives the right PCR;
//   3. double-bit flips inside one word raise fault;
//   4. every 1- and 2-bit upset of the controller state, idle and mid-extend,
//      raises fault, and the fault reaches a sticky fault_alarm.
// Any undetected injected fault fails the test.
`timescale 1ns/1ps
module tb_pcr_bank_fd;
    reg clk = 0;
    always #5 clk = ~clk;
    integer errors = 0;

    reg          rst_n = 0, extend = 0;
    reg  [3:0]   sel = 0;
    reg  [255:0] din = 0;
    wire [255:0] dout;
    wire [4095:0] flat;
    wire         busy, fault, fd_sec;
    pcr_bank dut (.clk(clk), .rst_n(rst_n), .extend(extend), .sel(sel),
        .digest_in(din), .digest_out(dout), .flat(flat), .busy(busy),
        .fault(fault), .fd_sec(fd_sec));

    wire        zeroize;
    wire [1:0]  alarm;
    fault_alarm #(.N(1)) u_alarm (.clk(clk), .fault(fault), .zeroize(zeroize), .alarm(alarm));

    reg [515:0] vec [0:23];
    reg [255:0] model [0:15];
    reg [255:0] got;
    integer v, w, b, b2, n, ok, s, t;

    task do_reset;
        begin
            rst_n = 0; extend = 0;
            u_alarm.a = 1'b0; u_alarm.b_n = 1'b1;   // power-on value
            repeat (2) @(negedge clk); rst_n = 1; @(negedge clk);
            for (t = 0; t < 16; t = t + 1) model[t] = 256'd0;
        end
    endtask
    task do_extend(input [3:0] s_i, input [255:0] d_i);
        begin
            @(negedge clk) begin sel = s_i; din = d_i; extend = 1; end
            @(negedge clk) extend = 0;
            while (busy) @(negedge clk);
        end
    endtask
    function [255:0] flat_pcr(input integer k);
        flat_pcr = flat[256*k +: 256];
    endfunction
    task check_all(input [255:0] tag);
        begin
            for (t = 0; t < 16; t = t + 1) begin
                sel = t[3:0]; #1;
                if (dout !== model[t] || flat_pcr(t) !== model[t]) begin
                    errors = errors + 1;
                    $display("FAIL %0s: PCR %0d = %h, want %h", tag, t, dout, model[t]);
                end
            end
        end
    endtask

    initial begin
        $readmemh("obj_dir/pcr_vectors.hex", vec);

        // 0. power-up before any reset: state 0 is not a legal code, but the
        //    detector is not armed yet, so the sticky alarm must stay clear.
        rst_n = 1; dut.st = 0; dut.pcr_c = {128*39{1'b1}};
        repeat (4) @(negedge clk);
        if (zeroize || fault) begin
            errors = errors + 1; $display("FAIL alarm latched before the first reset");
        end else $display("pcr_bank_fd: no alarm from power-up values before the first reset");

        // 1. clean extends
        do_reset;
        for (v = 0; v < 24; v = v + 1) begin
            do_extend(vec[v][515:512], vec[v][511:256]);
            model[vec[v][515:512]] = vec[v][255:0];
        end
        check_all("clean");
        if (fault || fd_sec || zeroize) begin
            errors = errors + 1; $display("FAIL false alarm on clean extends");
        end
        $display("pcr_bank_fd: 24 clean extends match SHA-256 reference, fault=%0d fd_sec=%0d",
                 fault, fd_sec);

        // 2. single-bit flips of every coded word: corrected
        n = 0; ok = 0;
        for (w = 0; w < 128; w = w + 1)
            for (b = 0; b < 39; b = b + 1) begin
                dut.pcr_c[39*w + b] = ~dut.pcr_c[39*w + b]; #1;
                sel = w / 8; #1; n = n + 1;
                if (dout === model[w / 8] && flat_pcr(w / 8) === model[w / 8] && !fault)
                    ok = ok + 1;
                else $display("single flip word %0d bit %0d not corrected", w, b);
                dut.pcr_c[39*w + b] = ~dut.pcr_c[39*w + b];
            end
        @(negedge clk);
        if (!fd_sec) begin errors = errors + 1; $display("FAIL fd_sec not set"); end
        $display("pcr_bank_fd: single-bit word upsets corrected %0d/%0d", ok, n);
        if (ok != n) errors = errors + 1;

        // extend over a PCR that carries a corrected single-bit upset
        do_reset;
        do_extend(4'd5, vec[0][511:256]);
        dut.pcr_c[39*(8*5 + 3) + 17] = ~dut.pcr_c[39*(8*5 + 3) + 17];
        do_extend(4'd5, vec[1][511:256]);
        sel = 5; #1;
        if (fault) begin errors = errors + 1; $display("FAIL fault after corrected extend"); end
        // expected = SHA(SHA(0||d0)||d1); the vectors file does not hold this
        // chain, so compare against a clean run of the same two extends.
        got = dout;
        do_reset;
        do_extend(4'd5, vec[0][511:256]);
        do_extend(4'd5, vec[1][511:256]);
        sel = 5; #1;
        if (dout !== got) begin
            errors = errors + 1; $display("FAIL extend over corrected word: %h vs %h", got, dout);
        end else $display("pcr_bank_fd: extend over a corrected word gives the clean result");

        // 3. double-bit flips inside one word: detected
        do_reset;
        for (v = 0; v < 24; v = v + 1) begin
            do_extend(vec[v][515:512], vec[v][511:256]);
            model[vec[v][515:512]] = vec[v][255:0];
        end
        n = 0; ok = 0;
        for (w = 0; w < 128; w = w + 3)
            for (b = 0; b < 39; b = b + 1)
                for (b2 = b + 1; b2 < 39; b2 = b2 + 7) begin
                    dut.pcr_c[39*w + b]  = ~dut.pcr_c[39*w + b];
                    dut.pcr_c[39*w + b2] = ~dut.pcr_c[39*w + b2]; #1;
                    n = n + 1;
                    if (fault) ok = ok + 1;
                    else $display("double flip word %0d bits %0d,%0d undetected", w, b, b2);
                    dut.pcr_c[39*w + b]  = ~dut.pcr_c[39*w + b];
                    dut.pcr_c[39*w + b2] = ~dut.pcr_c[39*w + b2]; #1;
                end
        $display("pcr_bank_fd: double-bit word upsets detected %0d/%0d", ok, n);
        if (ok != n) errors = errors + 1;
        if (fault) begin errors = errors + 1; $display("FAIL fault stuck after restore"); end

        // 4. controller state upsets, idle (S0) and mid-extend (waiting on SHA)
        n = 0; ok = 0;
        for (s = 0; s < 2; s = s + 1)
            for (b = 0; b < 7; b = b + 1)
                for (b2 = b; b2 < 7; b2 = b2 + 1) begin
                    do_reset;
                    if (s == 1) begin
                        @(negedge clk) begin sel = 2; din = vec[2][511:256]; extend = 1; end
                        @(negedge clk) extend = 0;
                        repeat (4) @(negedge clk);
                    end
                    dut.st = dut.st ^ (7'd1 << b) ^ ((b2 != b) ? (7'd1 << b2) : 7'd0);
                    #1; n = n + 1;
                    @(negedge clk); @(negedge clk);
                    if (fault && zeroize) ok = ok + 1;
                    else $display("FSM upset state %0d bits %0d/%0d undetected", s, b, b2);
                end
        $display("pcr_bank_fd: 1- and 2-bit controller upsets detected and latched %0d/%0d", ok, n);
        if (ok != n) errors = errors + 1;

        if (errors == 0) $display("PASS tb_pcr_bank_fd");
        else begin $display("FAIL tb_pcr_bank_fd (%0d errors)", errors); $fatal(1); end
        $finish;
    end
endmodule
