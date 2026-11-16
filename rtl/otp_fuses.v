// SPDX-License-Identifier: MIT
// One-time-programmable fuse array MODEL (16 x 32-bit words).
//
// Semantics of an antifuse/eFuse macro:
//   * bits can only be programmed 0 -> 1 (prog ORs data into the word)
//   * word 15 is the lock word: bit i set => word i can no longer change
//     (bit 15 locks the lock word itself)
//   * reads are always allowed; there are no secret words in this map
// The power-on image comes from the INIT parameter (loaded at configuration,
// not on reset). On an FPGA this array is
// flip-flops, so programming lasts only until reconfiguration; real
// silicon would use a foundry OTP macro behind this same interface.
//
// Word map (big-endian fields):
//   0  vendor ID            ("AIID")
//   1  [31:16] HW revision code (2 ASCII chars, e.g. "A1")
//      [15:8]  lifecycle: 00 blank, 01 TEST, 02 DEV, 03 PROD, FF RMA
//      [7:0]   SKU
//   2,3 device serial number (64 bits)
//   4  feature/debug fuses: [0] JTAG disabled [1] debug readback disabled
//   5..12 UDS (256-bit Unique Device Secret, DICE root) - READ-PROTECTED:
//         OTP_DATA reads return 0; only the hard-wired uds port sees them
//   13,14 spare
//   15 lock word
`timescale 1ns/1ps

module otp_fuses #(
    parameter [15:0]  HW_REV    = 16'h4131,     // "A1"
    parameter [7:0]   LIFECYCLE = 8'h02,        // DEV
    parameter [63:0]  SERIAL    = 64'd1,
    parameter [255:0] UDS       = 256'b0,       // blank: provisioned later
    parameter [31:0]  LOCK      = 32'h0000001F, // words 0-4 locked
    parameter [511:0] INIT = {
        32'h41494944,                    // 0 "AIID"
        HW_REV, LIFECYCLE, 8'h00,        // 1 HW code, lifecycle, SKU 0
        SERIAL,                          // 2,3 serial
        32'h00000003,                    // 4 JTAG off, readback off
        UDS,                             // 5..12 UDS
        {2{32'h00000000}},               // 13,14
        LOCK                             // 15 lock word
    }
) (
    input  wire        clk,
    input  wire        rst_n,
    input  wire [3:0]  addr,
    input  wire        prog,
    input  wire [31:0] wdata,
    output wire [31:0] rdata,
    output reg         prog_err,      // attempted write to a locked word
    output wire [15:0] hw_rev,
    output wire [7:0]  lifecycle,
    output wire [31:0] features,
    output wire [255:0] uds
);
    reg [31:0] f [0:15];
    integer i;
    wire   secret    = (addr >= 4'd5) && (addr <= 4'd12);
    assign rdata     = secret ? 32'h0 : f[addr];
    assign uds       = {f[5], f[6], f[7], f[8], f[9], f[10], f[11], f[12]};
    assign hw_rev    = f[1][31:16];
    assign lifecycle = f[1][15:8];
    assign features  = f[4];

    // Power-on image (FPGA configuration init values). Not touched by
    // rst_n: programmed fuses survive a warm reset, like real OTP.
    initial for (i = 0; i < 16; i = i + 1) f[i] = INIT[511 - 32*i -: 32];

    always @(posedge clk) begin
        if (prog && !f[15][{1'b0, addr}])
            f[addr] <= f[addr] | wdata;            // 0 -> 1 only
    end
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)    prog_err <= 0;
        else if (prog) prog_err <= f[15][{1'b0, addr}];
    end

`ifdef FORMAL
    // formal/otp_fuses.sby: OTP semantics hold for every reachable state.
    reg        f_past_valid = 1'b0;
    reg [31:0] f_past [0:15];
    integer    fi;
    always @(posedge clk) begin
        f_past_valid <= 1'b1;
        for (fi = 0; fi < 16; fi = fi + 1) f_past[fi] <= f[fi];
    end
    always @(*) begin
        if (f_past_valid)
            for (fi = 0; fi < 16; fi = fi + 1) begin
                assert ((f_past[fi] & ~f[fi]) == 32'h0);           // never 1 -> 0
                if (f_past[15][fi]) assert (f[fi] == f_past[fi]);   // locked => frozen
            end
        if (secret) assert (rdata == 32'h0);                       // UDS unreadable
    end
`endif
endmodule
