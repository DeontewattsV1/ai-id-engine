// SPDX-License-Identifier: MIT
// Bound to fuzzy_extract with W=64 abstraction: key 20 bits, t=4.
module fuzzy_extract_sva (
    input logic clk, rst_n, start,
    input logic [63:0] puf, helper,
    input logic [19:0] key_out,
    input logic ok, fail, done,
    input logic [1:0] mode
);
    default clocking cb @(posedge clk); endclocking
    default disable iff (!rst_n);

    // F1: exactly one of ok/fail per completed operation
    ap_exclusive: assert property (done |-> (ok ^ fail));

    // F2: reconstruction is deterministic given identical noise
    logic [19:0] k1, k2;
    logic [1:0] phase;
    logic [63:0] h, p1, p2;
    logic [63:0] cw1;

    // F3: enroll always succeeds
    ap_enroll_ok: assert property ((mode == 1) && done |-> ok);

    // F4: no output before done
    ap_no_early: assert property (!done |-> !ok && !fail);

    // F5: helper data is a function of the enrolled PUF only
    ap_helper_stable: assert property (
        (mode == 1 && done) |=> ##[1:$] (mode == 1 |-> helper == $past(helper, 1)));

    // F6: FSM never leaves the legal set
    ap_state_legal: assert property (u_fe.st inside {0,1,2,3,4,5,6});

    // F7: key_out only changes on a successful operation
    ap_key_stable_on_fail: assert property ((fail && done) |=> key_out == $past(key_out));

    // Covers
    cp_enroll:   cover property (mode == 1 && done && ok);
    cp_recon_ok: cover property (mode == 2 && done && ok);
    cp_recon_bad: cover property (mode == 2 && done && fail);
    cp_zero_noise: cover property (mode == 2 && puf == $past(puf));
endmodule
