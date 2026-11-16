// SPDX-License-Identifier: MIT
// Streaming SHA-256 measurement engine (model-weight measurement block).
//
// Accepts a byte stream as big-endian 32-bit words, applies FIPS 180-4
// padding in hardware and returns the digest of the whole stream.
//   start               : reset the hash state (H = IV, length = 0)
//   word_valid/word     : append 4 bytes {b0,b1,b2,b3}; accepted when ready
//   fin/fin_word/fin_n  : append fin_n (0..3) leading bytes of fin_word,
//                         pad, and finish. Accepted when ready.
//   done (pulse) + digest
// Throughput: 16 words per block, then one 64-round compression.
// Checked against OpenSSL SHA-256 for many lengths in tb/tb_id_engine.cpp
// (including the 0/55/56/63/64/65-byte padding edges) and on a 17.7 MB
// real model file in the integration demo.
`timescale 1ns/1ps

module sha256_stream (
    input  wire         clk,
    input  wire         rst_n,
    input  wire         zeroize,
    input  wire         start,
    input  wire         word_valid,
    input  wire [31:0]  word,
    input  wire         fin,
    input  wire [31:0]  fin_word,
    input  wire [1:0]   fin_n,
    output wire         ready,
    output wire         busy,
    output reg          done,
    output reg  [255:0] digest,
    output reg  [63:0]  total_bytes
);
    localparam [255:0] IV =
        256'h6a09e667bb67ae853c6ef372a54ff53a510e527f9b05688c1f83d9ab5be0cd19;
    localparam S_IDLE = 3'd0, S_RUN = 3'd1, S_KICK = 3'd2, S_WAIT = 3'd3,
               S_LEN = 3'd4, S_KICK2 = 3'd5, S_WAIT2 = 3'd6;

    reg [2:0]   st;
    reg [255:0] h;
    reg [511:0] blk;
    reg [4:0]   wcnt;          // words in blk (0..16)
    reg         c_start;
    reg         finishing;     // padding already appended
    reg         need_len_blk;  // length goes into an extra block
    /* verilator lint_off UNUSEDSIGNAL */
    wire        c_busy;
    /* verilator lint_on UNUSEDSIGNAL */
    wire        c_done;
    wire [255:0] c_dig;

    sha256_compress u_c (.clk(clk), .rst_n(rst_n), .start(c_start), .h_in(h),
                         .block(blk), .busy(c_busy), .done(c_done), .digest(c_dig));

    assign ready = (st == S_RUN) && (wcnt != 5'd16);
    assign busy  = (st != S_IDLE);

    // last partial word: fin_n data bytes followed by the 0x80 marker
    reg [31:0] padw;
    always @(*) begin
        case (fin_n)
            2'd0: padw = 32'h80000000;
            2'd1: padw = {fin_word[31:24], 24'h800000};
            2'd2: padw = {fin_word[31:16], 16'h8000};
            default: padw = {fin_word[31:8], 8'h80};
        endcase
    end
    wire unused_ok = &{1'b0, fin_word[7:0]};  // at most 3 tail bytes
    wire [63:0] bitlen_fin = (total_bytes + {62'b0, fin_n}) << 3;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            st <= S_IDLE; h <= IV; blk <= 0; wcnt <= 0; c_start <= 0; done <= 0;
            digest <= 0; total_bytes <= 0; finishing <= 0; need_len_blk <= 0;
        end else if (zeroize) begin
            st <= S_IDLE; h <= IV; blk <= 0; wcnt <= 0; c_start <= 0; done <= 0;
            digest <= 0; total_bytes <= 0; finishing <= 0; need_len_blk <= 0;
        end else begin
            c_start <= 0; done <= 0;
            if (start) begin
                st <= S_RUN; h <= IV; blk <= 0; wcnt <= 0; total_bytes <= 0;
                finishing <= 0; need_len_blk <= 0;
            end else case (st)
                S_RUN: begin
                    if (wcnt == 5'd16) begin
                        st <= S_KICK;
                    end else if (fin) begin
                        blk[511 - 32*wcnt[3:0] -: 32] <= padw;
                        total_bytes <= total_bytes + {62'b0, fin_n};
                        finishing <= 1;
                        if (wcnt <= 5'd13) begin
                            blk[63:0] <= bitlen_fin;
                            need_len_blk <= 0;
                        end else begin
                            need_len_blk <= 1;
                        end
                        st <= S_KICK;
                    end else if (word_valid) begin
                        blk[511 - 32*wcnt[3:0] -: 32] <= word;
                        wcnt <= wcnt + 5'd1;
                        total_bytes <= total_bytes + 64'd4;
                    end
                end
                S_KICK: begin c_start <= 1; st <= S_WAIT; end
                S_WAIT: if (c_done) begin
                    h <= c_dig; blk <= 0; wcnt <= 0;
                    if (!finishing) st <= S_RUN;
                    else if (need_len_blk) st <= S_LEN;
                    else begin digest <= c_dig; done <= 1; st <= S_IDLE; end
                end
                S_LEN: begin blk <= {448'b0, total_bytes << 3}; st <= S_KICK2; end
                S_KICK2: begin c_start <= 1; st <= S_WAIT2; end
                S_WAIT2: if (c_done) begin
                    h <= c_dig; digest <= c_dig; done <= 1; st <= S_IDLE; blk <= 0;
                end
                default: st <= S_IDLE;
            endcase
        end
    end
endmodule
