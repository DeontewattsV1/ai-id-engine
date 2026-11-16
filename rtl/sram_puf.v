// SPDX-License-Identifier: MIT
// Unique Device Secret (UDS) source.
//
// The real design derives the UDS from an SRAM PUF through the fuzzy
// extractor (rtl/fuzzy_extract.v, rtl/bch_*.v). That path is NOT
// characterized (see docs/REMEDIATION.md), so this module is a
// placeholder with two builds:
//
//  * default (synthesis / lint): fail closed. uds is all zeros and
//    uds_valid stays low, so nothing downstream can claim a device identity.
//  * `AI_ID_SIM_PUF` (simulation only, set by `make sim`): a fixed, PUBLIC
//    test UDS so the identity pipeline can be exercised end to end.
//    Never define AI_ID_SIM_PUF in a hardware build.
//  * `AI_ID_FUSE_UDS` (FPGA prototype, set by fpga/Makefile): the UDS is
//    the read-protected OTP words 5..12 (DICE "UDS in fuses" option). It is
//    valid once the fuses are non-blank. On an FPGA the fuse image is part
//    of the bitstream, so this is a prototype identity, not a secret one.
//
// Zeroize wipes the UDS until the next reset (power cycle).
`timescale 1ns/1ps

module sram_puf (
    input  wire         clk,
    input  wire         rst_n,
    input  wire         zeroize,
    input  wire [255:0] fuse_uds,
    output reg  [255:0] uds,
    output reg          uds_valid
);
`ifdef AI_ID_SIM_PUF
    localparam [255:0] SIM_UDS =
        256'h000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f;
    reg killed;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            uds <= 0; uds_valid <= 0; killed <= 0;
        end else if (zeroize || killed) begin
            uds <= 0; uds_valid <= 0; killed <= 1;
        end else begin
            uds <= SIM_UDS; uds_valid <= 1;
        end
    end
    wire unused_ok = &{1'b0, fuse_uds};
`elsif AI_ID_FUSE_UDS
    reg killed;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            uds <= 0; uds_valid <= 0; killed <= 0;
        end else if (zeroize || killed) begin
            uds <= 0; uds_valid <= 0; killed <= 1;
        end else begin
            uds <= fuse_uds; uds_valid <= |fuse_uds;
        end
    end
`else
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            uds <= 0; uds_valid <= 0;
        end else begin
            uds <= 0; uds_valid <= 0;   // fail closed: no characterized PUF
        end
    end
    wire unused_ok = &{1'b0, zeroize, fuse_uds};
`endif
endmodule
