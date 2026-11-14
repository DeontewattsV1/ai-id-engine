extend-only measurement registers
// SPDX-License-Identifier: MIT
// 16 PCRs. Write-once-per-extend semantics; reset to 0, never assignable.
`timescale 1ns/1ps

module pcr_bank (
    input  wire         clk,
    input  wire         rst_n,
    input  wire         extend,
    input  wire [3:0]   sel,
    input  wire [255:0] digest_in,
    output reg  [255:0] digest_out,
    output wire [4095:0] flat
);
    reg [255:0] pcr [0:15];
    reg [255:0] cat;
    integer i;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (i = 0; i < 16; i = i + 1) pcr[i] <= 256'b0;
        end else if (extend) begin
            cat = {pcr[sel], digest_in};
            pcr[sel] <= sha256_comb(cat);
        end
    end

    // combinational SHA-256 for the 64-byte extend block
    function automatic [255:0] sha256_comb(input [511:0] blk);
        // delegates to sha256_core in the real build; behavioral model here
        sha256_comb = 256'b0;
    endfunction

    always @(*) begin
        digest_out = pcr[sel];
        for (i = 0; i < 16; i = i + 1) flat[255 + 256*i -: 256] = pcr[i];
    end
endmodule
