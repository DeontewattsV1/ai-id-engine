// SPDX-License-Identifier: MIT
// 16 x 256-bit measurement registers. Extend semantics (TPM 2.0 style):
//   PCR[sel] <- SHA-256(PCR[sel] || digest_in)
// The 64-byte input needs two SHA-256 compressions (data block + padding).
//
// With `AI_ID_FAULT_DETECT (docs/FAULT-DETECTION.md):
//   * each PCR is held as 8 SEC-DED (39,32) words; single-bit upsets are
//     corrected on every read (fd_sec goes high and stays high until reset),
//     double-bit upsets raise fault;
//   * the controller state uses Hamming(7,4) codewords (distance 3), so any
//     1- or 2-bit state upset is an illegal code and raises fault.
// fault is a level, armed one cycle after reset is released; id_engine_top
// latches it in fault_alarm. Without the
// define, fault and fd_sec are tied to 0 and the logic is unchanged.
// Coding detects faults; it does not protect against side channels.
`timescale 1ns/1ps

module pcr_bank (
    input  wire         clk, rst_n,
    input  wire         extend,
    input  wire [3:0]   sel,
    input  wire [255:0] digest_in,
    output reg  [255:0] digest_out,
    output reg  [4095:0] flat,
    output wire         busy,
    output wire         fault,      // DED or illegal FSM code (level)
    output reg          fd_sec      // a single-bit error was corrected
);
    localparam [255:0] IV =
        256'h6a09e667bb67ae853c6ef372a54ff53a510e527f9b05688c1f83d9ab5be0cd19;
    // padding block for a 512-bit message: 0x80, zeros, length = 512
    localparam [511:0] PAD512 = {1'b1, 447'b0, 64'd512};

`ifdef AI_ID_FAULT_DETECT
    localparam SW = 7;
    localparam [6:0] S0 = 7'b0010011, S1 = 7'b0100101, S2 = 7'b1000110,
                     S3 = 7'b0001111, S4 = 7'b0111001;
`else
    localparam SW = 3;
    localparam [2:0] S0 = 3'd0, S1 = 3'd1, S2 = 3'd2, S3 = 3'd3, S4 = 3'd4;
`endif
    wire [255:0] pcr [0:15];       // decoded (corrected) PCR values
    reg [511:0] blk;
    reg [255:0] h_in;
    (* keep *) reg [SW-1:0] st;
    reg         h_start;
    /* verilator lint_off UNUSEDSIGNAL */
    wire        h_busy, h_done;
    /* verilator lint_on UNUSEDSIGNAL */
    wire [255:0] h_dig;
    reg [3:0]   sel_q;
`ifndef AI_ID_FAULT_DETECT
    integer i;
`endif

    assign busy = (st != S0);

`ifdef AI_ID_FAULT_DETECT
    `include "secded39_fn.vh"
    wire legal = (st == S0) || (st == S1) || (st == S2) || (st == S3) || (st == S4);
    reg  [128*39-1:0] pcr_c;       // 16 PCRs x 8 coded words, word w at [39w +: 39]
    wire [127:0] w_sec, w_ded;
    wire [4095:0] pcr_d;           // word w = 8*pcr + k holds bits 32k+31..32k
    genvar gw;
    generate for (gw = 0; gw < 128; gw = gw + 1) begin : g_dec
        secded39_dec u_dec (.c(pcr_c[39*gw +: 39]), .d(pcr_d[32*gw +: 32]),
                            .sec(w_sec[gw]), .ded(w_ded[gw]));
    end endgenerate
    generate for (gw = 0; gw < 16; gw = gw + 1) begin : g_pcr
        assign pcr[gw] = pcr_d[256*gw +: 256];
    end endgenerate
    // Armed only after reset has been released: before the first reset the
    // state and the words hold power-up values (0 is not a legal state code),
    // and a sticky alarm latched then would brick the part. While rst_n is
    // low every register is forced to a legal, wiped value anyway.
    reg fd_armed, fd_rst_seen;
    initial begin fd_armed = 1'b0; fd_rst_seen = 1'b0; end   // power-on value
    always @(posedge clk or negedge rst_n)
        if (!rst_n) begin fd_armed <= 1'b0; fd_rst_seen <= 1'b1; end
        else fd_armed <= fd_rst_seen;
    assign fault = fd_armed && ((|w_ded) || !legal);
    integer k;
`else
    reg  [255:0] pcr_r [0:15];
    genvar gp;
    generate for (gp = 0; gp < 16; gp = gp + 1) begin : g_pcr
        assign pcr[gp] = pcr_r[gp];
    end endgenerate
    assign fault = 1'b0;
`endif

    sha256_compress u_h (.clk(clk), .rst_n(rst_n), .start(h_start), .h_in(h_in),
                         .block(blk), .busy(h_busy), .done(h_done), .digest(h_dig));

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
`ifdef AI_ID_FAULT_DETECT
            pcr_c <= {128*39{1'b0}};       // encode(0) == 0: all PCRs read as 0
`else
            for (i = 0; i < 16; i = i + 1) pcr_r[i] <= 256'b0;
`endif
            st <= S0; h_start <= 0; sel_q <= 0; blk <= 0; h_in <= IV; fd_sec <= 0;
        end else begin
            h_start <= 0;
`ifdef AI_ID_FAULT_DETECT
            if (|w_sec) fd_sec <= 1'b1;
`endif
            case (st)
                S0: if (extend) begin
                       blk <= {pcr[sel], digest_in}; h_in <= IV;
                       sel_q <= sel; st <= S1;
                   end
                S1: begin h_start <= 1; st <= S2; end
                S2: if (h_done) begin h_in <= h_dig; blk <= PAD512; st <= S3; end
                S3: begin h_start <= 1; st <= S4; end
                S4: if (h_done) begin
`ifdef AI_ID_FAULT_DETECT
                       for (k = 0; k < 8; k = k + 1)
                           pcr_c[39*(8*sel_q + k) +: 39] <= secded39_encode(h_dig[32*k +: 32]);
`else
                       pcr_r[sel_q] <= h_dig;
`endif
                       st <= S0;
                   end
`ifdef AI_ID_FAULT_DETECT
                default: st <= st;     // illegal code: hold; fault -> alarm
`else
                default: st <= S0;
`endif
            endcase
        end
    end

`ifdef FORMAL
`ifndef AI_ID_FAULT_DETECT
    // formal/pcr_bank.sby: extend-only. A PCR changes only when an extend
    // completes, only the selected PCR changes, and it takes the SHA-256
    // output (never a caller-chosen value).
    reg         f_past_valid = 1'b0;
    reg [255:0] f_pcr [0:15];
    reg [SW-1:0] f_st;
    reg         f_done;
    reg [3:0]   f_sel;
    reg [255:0] f_dig;
    reg         f_rst = 1'b0;
    integer     fj;
    always @(posedge clk) begin
        f_past_valid <= 1'b1;
        for (fj = 0; fj < 16; fj = fj + 1) f_pcr[fj] <= pcr[fj];
        f_rst <= rst_n; f_st <= st; f_done <= h_done; f_sel <= sel_q; f_dig <= h_dig;
    end
    always @(*) begin
        if (f_past_valid && f_rst && rst_n)
            for (fj = 0; fj < 16; fj = fj + 1)
                if (pcr[fj] != f_pcr[fj]) begin
                    assert (f_st == S4 && f_done && f_sel == fj[3:0]);
                    assert (pcr[fj] == f_dig);
                end
    end
`else
    // formal/pcr_bank_fd.sby: once armed (a reset has been seen), the HD3
    // controller code is always legal in fault-free runs, so the FSM part of
    // `fault` never fires without an upset. Kept to the controller so the
    // proof stays fast: the extend-only property is proven on the uncoded
    // build (pcr_bank.sby), and the coded words are covered exhaustively by
    // tb/tb_pcr_bank_fd.sv (every 1-bit flip of every word, in-word 2-bit
    // flips, no false alarm on clean extends).
    always @(*) if (fd_armed) assert (legal);
`endif
`endif

    integer m;
    always @(*) begin
        digest_out = pcr[sel];
        for (m = 0; m < 16; m = m + 1) flat[255 + 256*m -: 256] = pcr[m];
    end
endmodule
