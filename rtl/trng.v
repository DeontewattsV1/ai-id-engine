// SPDX-License-Identifier: MIT
// Entropy source front end with SP 800-90B continuous health tests.
//
// `ent_bit` is the raw noise bit (FPGA: ring-oscillator sampler or an
// external noise pin; simulation: OS randomness from the testbench). One
// bit is sampled every SAMPLE_DIV clocks. Two online tests run on every
// sample (SP 800-90B section 4.4, design entropy assumption H = 0.5/bit):
//   Repetition Count Test : fail if RCT_CUTOFF identical bits in a row
//   Adaptive Proportion   : in each APT_WINDOW samples, fail if the first
//                           sample's value occurs >= APT_CUTOFF times
// Any failure latches `fail` until reset; no seed is released afterwards.
// Raw bits are packed into 176-bit seed chunks (`seed`, `seed_valid`) for
// hmac_drbg, which acts as the conditioner. The noise source itself is
// NOT characterized; see LIMITATIONS.md.
`timescale 1ns/1ps

module trng #(
    parameter integer SAMPLE_DIV = 4,
    parameter integer RCT_CUTOFF = 41,
    parameter integer APT_WINDOW = 1024,
    parameter integer APT_CUTOFF = 840
) (
    input  wire         clk,
    input  wire         rst_n,
    input  wire         zeroize,
    input  wire         ent_bit,
    input  wire         seed_ack,      // consumer took the chunk
    output reg  [175:0] seed,
    output reg          seed_valid,
    output reg          fail,
    output reg  [1:0]   fail_cause     // [0] RCT  [1] APT
);
    reg [1:0]  sync;
    reg [7:0]  div;
    reg [7:0]  run;
    reg        last;
    reg [10:0] apt_n, apt_cnt;
    reg        apt_ref;
    reg [7:0]  nbits;
    wire       b = sync[1];

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sync <= 0; div <= 0; run <= 0; last <= 0; apt_n <= 0; apt_cnt <= 0;
            apt_ref <= 0; nbits <= 0; seed <= 0; seed_valid <= 0; fail <= 0;
            fail_cause <= 0;
        end else if (zeroize) begin
            seed <= 0; seed_valid <= 0; nbits <= 0;
        end else if (fail) begin
            seed_valid <= 0;
        end else begin
            sync <= {sync[0], ent_bit};
            if (seed_ack) begin seed_valid <= 0; nbits <= 0; end
            div <= (div == SAMPLE_DIV[7:0] - 8'd1) ? 8'd0 : div + 8'd1;
            if (div == 0 && !fail) begin
                // Repetition count test
                if (b == last && run != 0) begin
                    run <= run + 8'd1;
                    if (run + 8'd1 >= RCT_CUTOFF[7:0]) begin
                        fail <= 1; fail_cause[0] <= 1;
                    end
                end else begin
                    run <= 8'd1;
                end
                last <= b;
                // Adaptive proportion test
                if (apt_n == 0) begin
                    apt_ref <= b; apt_cnt <= 11'd1; apt_n <= 11'd1;
                end else begin
                    if (b == apt_ref) begin
                        apt_cnt <= apt_cnt + 11'd1;
                        if (apt_cnt + 11'd1 >= APT_CUTOFF[10:0]) begin
                            fail <= 1; fail_cause[1] <= 1;
                        end
                    end
                    apt_n <= (apt_n == APT_WINDOW[10:0] - 11'd1) ? 11'd0 : apt_n + 11'd1;
                end
                // pack into seed chunk
                if (!seed_valid && !seed_ack) begin
                    seed  <= {seed[174:0], b};
                    nbits <= nbits + 8'd1;
                    if (nbits == 8'd175) seed_valid <= 1;
                end
            end
        end
    end
endmodule
