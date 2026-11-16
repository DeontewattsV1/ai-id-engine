// SPDX-License-Identifier: MIT
// SEC-DED (39,32): extended Hamming code over one 32-bit word.
//   * Hamming(38,32): codeword positions 1..38, check bits at 1,2,4,8,16,32,
//     data bits at the remaining positions in ascending order;
//   * bit 0 of the 39-bit codeword is the overall parity bit.
// Any single-bit error is corrected (sec=1) and any double-bit error is
// detected (ded=1). Triple and higher errors can be miscorrected: this is a
// fault DETECTION code, not a side-channel countermeasure.
`timescale 1ns/1ps

module secded39_enc (
    input  wire [31:0] d,
    output wire [38:0] c
);
    `include "secded39_fn.vh"
    assign c = secded39_encode(d);
endmodule
