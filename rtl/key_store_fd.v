// SPDX-License-Identifier: MIT
`timescale 1ns/1ps
// Fault-detecting key store: the reference composition of the v0.2.0 coded
// logic (docs/FAULT-DETECTION.md).
//   * The 256-bit key is held as 8 SEC-DED (39,32) words. Single-bit errors
//     are corrected on the way out (and counted); double-bit errors raise a
//     fault.
//   * The controller FSM uses 7-bit codewords of the Hamming(7,4) code, so
//     any two legal states are at Hamming distance >= 3 and neither all-0
//     nor all-1 is legal. Any 1- or 2-bit upset lands on an illegal code,
//     which raises a fault. (Plain one-hot has distance 2.)
//   * Faults from here and from outside (fault_ext, e.g. mont_mul_rc's
//     rc_err) feed a duplicated, sticky fault_alarm. Its zeroize output wipes
//     the store and can only be cleared by power-on.
//   * key_out is the only KEYED output. status is UNKEYED: formal/
//     key_store_nonint.sby proves status never depends on the key.
// Coding detects faults; it does not harden against side channels.
module key_store_fd (
    input  wire         clk, rst_n,
    input  wire         load,
    input  wire [255:0] key_in,
    input  wire         clear,          // normal (non-fault) wipe
    input  wire         fault_ext,
    output wire [255:0] key_out,        // keyed: to the consumer only
    output wire         key_valid,
    output wire [15:0]  status,         // unkeyed
    output wire         zeroize
);
    localparam [6:0] S_IDLE  = 7'b0010011,
                     S_LOAD  = 7'b0100101,
                     S_READY = 7'b1000110,
                     S_WIPE  = 7'b0111001;
    (* keep *) reg [6:0] st;
    reg [38:0] w [0:7];
    reg [255:0] key_q;
    reg        sec_seen;
    integer    i;

    wire legal = (st == S_IDLE) || (st == S_LOAD) || (st == S_READY) || (st == S_WIPE);

    wire [255:0] dec_d;
    wire [7:0]   dec_sec, dec_ded;
    wire [38:0]  enc_c [0:7];
    genvar g;
    generate for (g = 0; g < 8; g = g + 1) begin : g_w
        secded39_enc u_enc (.d(key_q[32*g +: 32]), .c(enc_c[g]));
        secded39_dec u_dec (.c(w[g]), .d(dec_d[32*g +: 32]),
                            .sec(dec_sec[g]), .ded(dec_ded[g]));
    end endgenerate

    wire [1:0] alarm_pair;
    wire fsm_fault = !legal;
    wire ded_fault = |dec_ded;
    fault_alarm #(.N(3)) u_alarm (.clk(clk),
        .fault({fault_ext, ded_fault, fsm_fault}), .zeroize(zeroize), .alarm(alarm_pair));

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            st <= S_IDLE; key_q <= 256'd0; sec_seen <= 1'b0;
            for (i = 0; i < 8; i = i + 1) w[i] <= 39'd0;
        end else if (zeroize) begin
            st <= S_WIPE; key_q <= 256'd0;
            for (i = 0; i < 8; i = i + 1) w[i] <= 39'd0;
        end else begin
            if (|dec_sec) sec_seen <= 1'b1;
            case (st)
                S_IDLE:  if (load) begin key_q <= key_in; st <= S_LOAD; end
                S_LOAD:  begin
                             for (i = 0; i < 8; i = i + 1) w[i] <= enc_c[i];
                             key_q <= 256'd0; st <= S_READY;
                         end
                S_READY: if (clear) st <= S_WIPE;
                         else if (load) begin key_q <= key_in; st <= S_LOAD; end
                S_WIPE:  begin
                             for (i = 0; i < 8; i = i + 1) w[i] <= 39'd0;
                             st <= S_IDLE;
                         end
                default: st <= st;      // illegal: hold; the alarm wipes
            endcase
        end
    end

    assign key_valid = (st == S_READY) && !zeroize;
    assign key_out   = key_valid ? dec_d : 256'd0;
    assign status = {sec_seen, ded_fault, fsm_fault, key_valid, alarm_pair,
                     st, 3'b000};

`ifdef FORMAL
    // formal/key_store_fd.sby. Start from reset, then: illegal controller
    // states are unreachable without an injected fault, the stored words are
    // always valid codewords (so no fault-free run raises the alarm from
    // here), and a key is never presented while zeroize is high.
    reg f_init = 1'b0;
    always @(posedge clk) f_init <= 1'b1;
    always @(*) if (!f_init) assume (!rst_n);
    always @(*) if (f_init) begin
        assert (legal);
        assert (dec_sec == 8'd0 && dec_ded == 8'd0);
        if (zeroize) assert (key_out == 256'd0 && !key_valid);
    end
`endif
endmodule
