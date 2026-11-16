// SPDX-License-Identifier: MIT
// Fault-injection simulation for the v0.2.0 fault-detection RTL.
// Faults are injected as bit flips written straight into DUT registers
// (single-event-upset model). Prints counts; any undetected single fault fails.
`timescale 1ns/1ps
module tb_fault_detect;
    reg clk = 0;
    always #5 clk = ~clk;
    integer errors = 0;

    // ---------------- 1. SEC-DED (39,32): exhaustive 1- and 2-bit flips ------
    reg  [31:0] sd_d;
    wire [38:0] sd_c;
    reg  [38:0] sd_e;
    wire [31:0] sd_q;
    wire        sd_sec, sd_ded;
    secded39_enc u_se (.d(sd_d), .c(sd_c));
    secded39_dec u_sd (.c(sd_c ^ sd_e), .d(sd_q), .sec(sd_sec), .ded(sd_ded));

    integer wi, i, j, n1, n2, n1ok, n2ok;
    task secded_check;
        begin
            n1 = 0; n2 = 0; n1ok = 0; n2ok = 0;
            for (wi = 0; wi < 64; wi = wi + 1) begin
                case (wi)
                    0: sd_d = 32'h0;  1: sd_d = 32'hffffffff;
                    2: sd_d = 32'haaaaaaaa; 3: sd_d = 32'h55555555;
                    default: sd_d = $urandom;
                endcase
                sd_e = 0; #1;
                if (sd_q !== sd_d || sd_sec || sd_ded) begin
                    errors = errors + 1; $display("FAIL secded clean %h", sd_d);
                end
                for (i = 0; i < 39; i = i + 1) begin
                    sd_e = 39'd1 << i; #1; n1 = n1 + 1;
                    if (sd_q === sd_d && sd_sec && !sd_ded) n1ok = n1ok + 1;
                    for (j = i + 1; j < 39; j = j + 1) begin
                        sd_e = (39'd1 << i) | (39'd1 << j); #1; n2 = n2 + 1;
                        if (sd_ded && !sd_sec) n2ok = n2ok + 1;
                    end
                end
            end
            $display("secded39: single flips corrected %0d/%0d, double flips detected %0d/%0d",
                     n1ok, n1, n2ok, n2);
            if (n1ok != n1 || n2ok != n2) errors = errors + 1;
        end
    endtask

    // ---------------- 2./3./4. key store: alarm, FSM, SEC-DED words ----------
    reg          rst_n = 0, load = 0, clear = 0, fault_ext = 0;
    reg  [255:0] key_in;
    wire [255:0] key_out;
    wire         key_valid, zeroize;
    wire [15:0]  status;
    key_store_fd u_ks (.clk(clk), .rst_n(rst_n), .load(load), .key_in(key_in),
        .clear(clear), .fault_ext(fault_ext), .key_out(key_out),
        .key_valid(key_valid), .status(status), .zeroize(zeroize));

    // Power cycle: the ONLY way to clear the alarm (re-applies the power-on
    // configuration value; there is no reset path in fault_alarm).
    task power_cycle;
        begin
            rst_n = 0; load = 0; clear = 0; fault_ext = 0;
            u_ks.u_alarm.a = 1'b0; u_ks.u_alarm.b_n = 1'b1;
            repeat (2) @(posedge clk); #1 rst_n = 1;
        end
    endtask
    task load_key(input [255:0] k);
        begin
            @(negedge clk) begin key_in = k; load = 1; end
            @(negedge clk) load = 0;
            repeat (2) @(negedge clk);
        end
    endtask

    reg [6:0] legal [0:3];
    reg [6:0] code;
    integer s, b1, b2, fsm_n, fsm_ok, word, k1, kn, kok, kd, e0;
    reg [255:0] key;

    task alarm_check;
        begin
            e0 = errors;
            power_cycle; key = {8{$urandom}}; load_key(key);
            if (!key_valid || key_out !== key || zeroize) begin
                errors = errors + 1; $display("FAIL key store load");
            end
            @(negedge clk) fault_ext = 1; @(negedge clk) fault_ext = 0;
            @(negedge clk);
            if (!zeroize || key_valid || key_out !== 0) begin
                errors = errors + 1; $display("FAIL alarm did not zeroize");
            end
            // reset must not clear it
            rst_n = 0; repeat (3) @(negedge clk); rst_n = 1; repeat (3) @(negedge clk);
            if (!zeroize) begin errors = errors + 1; $display("FAIL alarm cleared by reset"); end
            // a key loaded after the alarm is refused
            load_key(key);
            if (key_valid || key_out !== 0) begin
                errors = errors + 1; $display("FAIL key accepted after alarm");
            end
            // fault in one alarm latch: clear 'a' only, zeroize stays, a re-sets
            @(negedge clk) u_ks.u_alarm.a = 1'b0; #1;
            if (!zeroize) begin errors = errors + 1; $display("FAIL single latch upset cleared zeroize"); end
            @(negedge clk);
            if (u_ks.u_alarm.a !== 1'b1) begin errors = errors + 1; $display("FAIL latch not re-set"); end
            @(negedge clk) u_ks.u_alarm.b_n = 1'b1; #1;
            if (!zeroize) begin errors = errors + 1; $display("FAIL b_n upset cleared zeroize"); end
            @(negedge clk);
            if (u_ks.u_alarm.b_n !== 1'b0) begin errors = errors + 1; $display("FAIL b_n not re-set"); end
            // clean run: no false alarm over 200 cycles with load/clear traffic
            power_cycle;
            for (i = 0; i < 20; i = i + 1) begin
                load_key({8{$urandom}});
                @(negedge clk) clear = 1; @(negedge clk) clear = 0; repeat (3) @(negedge clk);
            end
            if (zeroize) begin errors = errors + 1; $display("FAIL false alarm"); end
            $display("fault_alarm: set by fault, survives rst_n, single-latch upsets re-set: %s",
                     errors == e0 ? "PASS" : "FAIL");
        end
    endtask

    task fsm_check;
        begin
            legal[0] = 7'b0010011; legal[1] = 7'b0100101;
            legal[2] = 7'b1000110; legal[3] = 7'b0111001;
            for (i = 0; i < 4; i = i + 1)
                for (j = i + 1; j < 4; j = j + 1)
                    if ($countones(legal[i] ^ legal[j]) < 3) begin
                        errors = errors + 1; $display("FAIL FSM distance");
                    end
            fsm_n = 0; fsm_ok = 0;
            for (b1 = 0; b1 < 7; b1 = b1 + 1)
                for (b2 = b1; b2 < 7; b2 = b2 + 1) begin   // b2 == b1: single flip
                    power_cycle; key = {8{$urandom}}; load_key(key);   // st = READY
                    code = u_ks.st ^ (7'd1 << b1) ^ ((b2 != b1) ? (7'd1 << b2) : 7'd0);
                    @(negedge clk) u_ks.st = code;
                    @(negedge clk); @(negedge clk);
                    fsm_n = fsm_n + 1;
                    if (zeroize && key_out === 0 && u_ks.w[0] === 0) fsm_ok = fsm_ok + 1;
                    else $display("FSM flip %0d/%0d undetected (code %b)", b1, b2, code);
                end
            // also exercise flips from IDLE
            for (b1 = 0; b1 < 7; b1 = b1 + 1) begin
                power_cycle;
                @(negedge clk) u_ks.st = u_ks.st ^ (7'd1 << b1);
                @(negedge clk); @(negedge clk);
                fsm_n = fsm_n + 1;
                if (zeroize) fsm_ok = fsm_ok + 1;
            end
            $display("fsm HD3: 1- and 2-bit state upsets detected %0d/%0d", fsm_ok, fsm_n);
            if (fsm_ok != fsm_n) errors = errors + 1;
        end
    endtask

    task keyword_check;
        begin
            k1 = 0; kok = 0; kn = 0; kd = 0;
            for (word = 0; word < 8; word = word + 1)
                for (i = 0; i < 39; i = i + 1) begin
                    power_cycle; key = {$urandom, $urandom, $urandom, $urandom,
                                        $urandom, $urandom, $urandom, $urandom};
                    load_key(key);
                    @(negedge clk) u_ks.w[word] = u_ks.w[word] ^ (39'd1 << i);
                    @(negedge clk);
                    k1 = k1 + 1;
                    if (key_out === key && !zeroize && status[15]) kok = kok + 1;
                    else $display("SEC word %0d bit %0d: not corrected", word, i);
                end
            for (word = 0; word < 8; word = word + 1)
                for (i = 0; i < 6; i = i + 1) begin
                    power_cycle; key = {8{$urandom}}; load_key(key);
                    j = (i * 7 + 3) % 39;
                    @(negedge clk) u_ks.w[word] = u_ks.w[word] ^ (39'd1 << i) ^ (39'd1 << (i + 1 + j % 30));
                    @(negedge clk); @(negedge clk);
                    kn = kn + 1;
                    if (zeroize && key_out === 0 && u_ks.w[word] === 0) kd = kd + 1;
                    else begin errors = errors + 1; $display("DED word %0d not detected", word); end
                end
            $display("key store: single-bit word upsets corrected %0d/%0d; double-bit upsets -> zeroize %0d/%0d",
                     kok, k1, kd, kn);
            if (kok != k1) errors = errors + 1;
        end
    endtask

    // ---------------- 5. Montgomery residue check ----------------------------
    localparam [255:0] P = 256'hffffffff00000001000000000000000000000000ffffffffffffffffffffffff;
    reg          m_rst_n = 0, m_start = 0;
    reg  [255:0] ma, mb;
    wire [255:0] r_ref, r_rc;
    wire         d_ref, d_rc, rc_err;
    mont_mul    u_ref (.clk(clk), .rst_n(m_rst_n), .start(m_start), .a(ma), .b(mb),
                       .modulus(P), .n0prime(32'd1), .r(r_ref), .done(d_ref));
    mont_mul_rc u_rc  (.clk(clk), .rst_n(m_rst_n), .start(m_start), .a(ma), .b(mb),
                       .modulus(P), .n0prime(32'd1), .r(r_rc), .done(d_rc), .rc_err(rc_err));

    integer trial, when, bit_i, target, eff, det, noeff, falsepos, clean, esc;
    reg     got_err;
    function [255:0] rand_lt_p(input integer dummy);
        rand_lt_p = {$urandom & 32'h7fffffff, $urandom, $urandom, $urandom,
                     $urandom, $urandom, $urandom, $urandom};
    endfunction
    task mont_run(input integer inject);
        begin
            ma = rand_lt_p(0); mb = rand_lt_p(0);
            @(negedge clk) m_start = 1; @(negedge clk) m_start = 0;
            if (inject) begin
                when = $urandom % 257;              // RUN cycles 0..255, REDUCE
                target = $urandom % 5;
                bit_i = $urandom % 256;
                repeat (when) @(negedge clk);
                case (target)
                    0: u_rc.t[bit_i % 258] = ~u_rc.t[bit_i % 258];
                    1: u_rc.aa[bit_i] = ~u_rc.aa[bit_i];
                    2: u_rc.bb[bit_i] = ~u_rc.bb[bit_i];
                    3: u_rc.nn[bit_i] = ~u_rc.nn[bit_i];
                    default: u_rc.q[bit_i] = ~u_rc.q[bit_i];
                endcase
            end
            got_err = 0;
            while (!d_rc) @(posedge clk);
            got_err = rc_err;
            @(negedge clk);
        end
    endtask
    task mont_check;
        begin
            m_rst_n = 0; repeat (2) @(negedge clk); m_rst_n = 1;
            clean = 0; falsepos = 0;
            for (trial = 0; trial < 40; trial = trial + 1) begin
                mont_run(0);
                if (r_rc !== r_ref) begin errors = errors + 1; $display("FAIL mont_mul_rc result"); end
                if (got_err) falsepos = falsepos + 1;
                clean = clean + 1;
            end
            eff = 0; det = 0; noeff = 0; esc = 0;
            for (trial = 0; trial < 400; trial = trial + 1) begin
                mont_run(1);
                if (r_rc !== r_ref) begin
                    eff = eff + 1;
                    if (got_err) det = det + 1;
                    else begin esc = esc + 1; $display("ESCAPE target %0d bit %0d at %0d", target, bit_i, when); end
                end else if (got_err) begin det = det + 1; eff = eff + 1; end
                else noeff = noeff + 1;
            end
            $display("mont_mul_rc: clean runs %0d, false alarms %0d", clean, falsepos);
            $display("mont_mul_rc: 400 single-bit upsets: %0d corrupted or flagged, %0d detected, %0d escaped, %0d masked (no effect on r)",
                     eff, det, esc, noeff);
            if (falsepos != 0 || esc != 0) errors = errors + 1;
        end
    endtask

    initial begin
        secded_check;
        alarm_check;
        fsm_check;
        keyword_check;
        mont_check;
        if (errors == 0) $display("PASS tb_fault_detect");
        else begin $display("FAIL tb_fault_detect: %0d error(s)", errors); $fatal(1); end
        $finish;
    end
endmodule
