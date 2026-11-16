// SPDX-License-Identifier: MIT
// SEC-DED (39,32) decoder; see rtl/secded39_enc.v for the code definition.
`timescale 1ns/1ps

module secded39_dec (
    input  wire [38:0] c,
    output wire [31:0] d,     // corrected data
    output wire        sec,   // single error (corrected)
    output wire        ded    // double error (uncorrectable)
);
    `include "secded39_fn.vh"
    wire [5:0] syn    = secded39_syndrome(c);
    wire       parity = ^c;                       // even overall parity
    wire       sec_i  = parity;                   // odd number of flips
    wire       ded_i  = !parity && (syn != 6'd0);
    // A single flip of the overall parity bit has syn == 0: data is intact.
    wire [38:0] fixed = (sec_i && syn != 6'd0 && syn <= 6'd38)
                        ? (c ^ (39'd1 << syn)) : c;
    assign d   = secded39_data(fixed);
    assign sec = sec_i;
    assign ded = ded_i || (sec_i && syn > 6'd38);  // flip "outside" the code
endmodule
