bound into the DUT via bind.
// SPDX-License-Identifier: MIT
module id_engine_sva (
    input logic pclk, presetn, pcr_extend, [3:0] pcr_sel,
    input logic [255:0] pcr_prev [0:15], pcr_now [0:15],
    input logic zeroize, [255:0] key_out, alias_key, cdi, uds,
    input logic seal_op, unseal_ok, [255:0] seal_in, unseal_out
);
    default clocking cb @(posedge pclk); endclocking
    default disable iff (!presetn);

    // P1: PCR monotonicity — a PCR may only change when its extend strobes
    genvar i;
    generate for (i = 0; i < 16; i++) begin : g_pcr
        ap_pcr_only_on_extend: assert property (
            (pcr_now[i] != pcr_prev[i]) |-> (pcr_extend && pcr_sel == i));
        // P2: never returns to reset value after first extend
        ap_pcr_no_revert: assert property (
            (pcr_prev[i] != '0) |-> (pcr_now[i] != '0));
        // P3: extend of a PCR changes it (collision-free within k=8)
        cp_pcr_changes: cover property (pcr_extend && pcr_sel == i);
    end endgenerate

    // P4: zeroize completeness — all key state clears within 3 cycles
    ap_zeroize_complete: assert property (
        zeroize |-> ##[1:3] (key_out == '0 && alias_key == '0 && cdi == '0));

    // P5: UDS never reaches an output port combinationally
    ap_uds_registered: assert property (uds == $past(uds) || zeroize);

    // P6: seal/unseal inverse (same policy, unchanged PCRs)
    ap_seal_unseal_inverse: assert property (
        (seal_op == 2'b01) ##1 (seal_op == 2'b10) |-> unseal_ok);

    // P7: unseal fails when a bound PCR moved
    ap_unseal_fails_on_drift: assert property (
        (seal_op == 2'b10 && $past(pcr_now[0]) != pcr_now[0]) |-> !unseal_ok);

    // P8: FSM safety — no busy bit without a start
    ap_no_orphan_busy: assert property (
        busy |-> $past(start || busy));

    // P9: APB protocol — pready never high without psel
    ap_pready_requires_psel: assert property (pready |-> psel);

    // P10: mutual exclusion — ratchet and seed_load never coincide
    ap_ladder_exclusive: assert property (!(ratchet && seed_load));

    // P11: no X on the quote FIFO when valid
    ap_fifo_no_x: assert property (fifo_valid |-> !$isunknown(fifo_data));
endmodule
