// SPDX-License-Identifier: MIT
// 16 x 256-bit measurement registers. Extend semantics (TPM 2.0 style):
//   PCR[sel] <- SHA-256(PCR[sel] || digest_in)
// The 64-byte input needs two SHA-256 compressions (data block + padding).
`timescale 1ns/1ps

module pcr_bank (
    input  wire         clk, rst_n,
    input  wire         extend,
    input  wire [3:0]   sel,
    input  wire [255:0] digest_in,
    output reg  [255:0] digest_out,
    output reg  [4095:0] flat,
    output wire         busy
);
    localparam [255:0] IV =
        256'h6a09e667bb67ae853c6ef372a54ff53a510e527f9b05688c1f83d9ab5be0cd19;
    // padding block for a 512-bit message: 0x80, zeros, length = 512
    localparam [511:0] PAD512 = {1'b1, 447'b0, 64'd512};

    reg [255:0] pcr [0:15];
    reg [511:0] blk;
    reg [255:0] h_in;
    reg [2:0]   st;
    reg         h_start;
    /* verilator lint_off UNUSEDSIGNAL */
    wire        h_busy, h_done;
    /* verilator lint_on UNUSEDSIGNAL */
    wire [255:0] h_dig;
    reg [3:0]   sel_q;
    integer i;

    assign busy = (st != 0);

    sha256_compress u_h (.clk(clk), .rst_n(rst_n), .start(h_start), .h_in(h_in),
                         .block(blk), .busy(h_busy), .done(h_done), .digest(h_dig));

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (i = 0; i < 16; i = i + 1) pcr[i] <= 256'b0;
            st <= 0; h_start <= 0; sel_q <= 0; blk <= 0; h_in <= IV;
        end else begin
            h_start <= 0;
            case (st)
                0: if (extend) begin
                       blk <= {pcr[sel], digest_in}; h_in <= IV;
                       sel_q <= sel; st <= 1;
                   end
                1: begin h_start <= 1; st <= 2; end
                2: if (h_done) begin h_in <= h_dig; blk <= PAD512; st <= 3; end
                3: begin h_start <= 1; st <= 4; end
                4: if (h_done) begin pcr[sel_q] <= h_dig; st <= 0; end
                default: st <= 0;
            endcase
        end
    end

`ifdef FORMAL
    // formal/pcr_bank.sby: extend-only. A PCR changes only when an extend
    // completes, only the selected PCR changes, and it takes the SHA-256
    // output (never a caller-chosen value).
    reg         f_past_valid = 1'b0;
    reg [255:0] f_pcr [0:15];
    reg [2:0]   f_st;
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
                    assert (f_st == 3'd4 && f_done && f_sel == fj[3:0]);
                    assert (pcr[fj] == f_dig);
                end
    end
`endif

    integer m;
    always @(*) begin
        digest_out = pcr[sel];
        for (m = 0; m < 16; m = m + 1) flat[255 + 256*m -: 256] = pcr[m];
    end
endmodule
