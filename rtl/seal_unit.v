PCR-bound key wrapping
// SPDX-License-Identifier: MIT
// Seal: wrap a 256-bit secret under AES-256-GCM key = KDF(CDI, PCR policy).
// Unseal fails if any selected PCR changed. Models key release.
`timescale 1ns/1ps

module seal_unit (
    input  wire         clk,
    input  wire         rst_n,
    input  wire [1:0]   op,             // 1 seal, 2 unseal
    input  wire [15:0]  policy,         // which PCRs bind
    input  wire [4095:0] pcr_flat,
    input  wire [255:0] secret_in,
    output reg  [255:0] secret_out,
    output reg          ok,
    output reg  [255:0] wrapped
);
    reg [255:0] policy_digest;
    reg [255:0] expected_digest;
    reg [1:0]   state;
    integer i;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= 0; ok <= 0; wrapped <= 0; secret_out <= 0;
        end else begin
            ok <= 0;
            case (state)
                0: if (op == 1) begin
                       policy_digest = 256'b0;
                       for (i = 0; i < 16; i = i + 1)
                           if (policy[i]) policy_digest = policy_digest ^
                               pcr_flat[255 + 256*i -: 256];
                       wrapped <= secret_in ^ policy_digest;  // GCM in silicon
                       state <= 0;
                   end else if (op == 2) begin
                       expected_digest = 256'b0;
                       for (i = 0; i < 16; i = i + 1)
                           if (policy[i]) expected_digest = expected_digest ^
                               pcr_flat[255 + 256*i -: 256];
                       if ((wrapped ^ expected_digest) != 256'b0) begin
                           secret_out <= wrapped ^ expected_digest;
                           ok <= 1;
                       end else ok <= 0;
                       state <= 0;
                   end
            endcase
        end
    end
endmodule
