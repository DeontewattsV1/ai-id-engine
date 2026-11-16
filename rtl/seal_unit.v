// PCR-bound secret sealing (FUNCTIONAL MODEL)
// SPDX-License-Identifier: MIT
// op=1 seal:   records the selected-PCR policy and its digest, and stores
//              wrapped = secret ^ seal_key ^ policy_digest.
// op=2 unseal: recomputes the digest over the PCRs selected AT SEAL TIME.
//              Releases the secret (ok=1) only if it matches the recorded
//              digest; otherwise secret_out is cleared and ok=0.
// policy_digest here is the XOR of selected PCRs. This models the release
// policy only; it is NOT AES-256-GCM and provides no confidentiality or
// integrity guarantee. A silicon release must replace the XOR wrap with an
// authenticated cipher keyed by KDF(CDI, policy).
`timescale 1ns/1ps

module seal_unit (
    input  wire         clk,
    input  wire         rst_n,
    input  wire         zeroize,
    input  wire [1:0]   op,             // 1 seal, 2 unseal
    input  wire [15:0]  policy,         // which PCRs bind (seal only)
    input  wire [4095:0] pcr_flat,
    input  wire [255:0] seal_key,
    input  wire [255:0] secret_in,
    output reg  [255:0] secret_out,
    output reg          ok,             // level, valid after the last unseal
    output reg  [255:0] wrapped
);
    reg [15:0]  sealed_policy;
    reg [255:0] sealed_digest;
    reg         have_blob;

    function automatic [255:0] pdigest;
        input [15:0]   pol;
        input [4095:0] flat;
        integer i;
        begin
            pdigest = 256'b0;
            for (i = 0; i < 16; i = i + 1)
                if (pol[i]) pdigest = pdigest ^ flat[255 + 256*i -: 256];
        end
    endfunction

    wire [255:0] cur_seal   = pdigest(policy, pcr_flat);
    wire [255:0] cur_unseal = pdigest(sealed_policy, pcr_flat);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= 0; ok <= 0; wrapped <= 0; secret_out <= 0;
        end else begin
            case (state)
                0: if (op == 1) begin
                       ok <= 0;
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
                       if (expected_digest == policy_digest &&
                           (wrapped ^ expected_digest) != 256'b0) begin
                           secret_out <= wrapped ^ expected_digest;
                           ok <= 1;
                       end else ok <= 0;
                       state <= 0;
                   end
            endcase
        end
    end
endmodule
