// SPDX-License-Identifier: MIT
`timescale 1ns/1ps
// Research safety gate: the existing EAT/COSE/signature path is not validated.
// The default hardware must never stream an unsigned or forged attestation.
// UNSAFE_EXPERIMENTAL_QUOTE_ONLY is forbidden in production.
`ifndef UNSAFE_EXPERIMENTAL_QUOTE_ONLY
module quote_signer (
    input wire clk,rst_n,sign_start,
    input wire [255:0] alias_key,nonce,model_digest,config_digest,
    input wire [4095:0] pcr_flat,
    input wire [63:0] timestamp,
    output reg [7:0] fifo_data,
    output reg fifo_valid,
    output reg [15:0] quote_len,
    output reg done,err
);
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            fifo_data <= 0; fifo_valid <= 0; quote_len <= 0;
            done <= 0; err <= 1;
        end else begin
            fifo_data <= 0; fifo_valid <= 0; quote_len <= 0;
            done <= 0; err <= 1; // fail closed; no quote is issued
        end
    end
endmodule
`else
module quote_signer (
    input  wire         clk,
    input  wire         rst_n,
    input  wire         sign_start,
    input  wire [255:0] alias_key,
    input  wire [255:0] nonce,
    input  wire [4095:0] pcr_flat,
    input  wire [255:0] model_digest,
    input  wire [255:0] config_digest,
    input  wire [63:0]  timestamp,
    output reg  [7:0]   fifo_data,
    output reg          fifo_valid,
    output reg  [15:0]  quote_len,
    output reg          done,
    output reg          err
);
    reg [2:0] state;
    reg [7:0] payload [0:511];
    reg [15:0] plen, idx;

    // ECDSA core handshake
    reg         ec_start;
    wire        ec_done;
    wire [511:0] ec_sig;

    // secp256r1 signer, hardened (constant-time ladder, blinding)
    ecdsa_p256_sign u_ec (
        .clk(clk), .rst_n(rst_n), .start(ec_start),
        .priv(alias_key), .hash(payload_hash), .done(ec_done), .sig(ec_sig)
    );

    wire [255:0] payload_hash;  // sha256 of payload[0..plen-1]

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= 0; done <= 0; err <= 0; fifo_valid <= 0; quote_len <= 0;
        end else begin
            fifo_valid <= 0; done <= 0;
            case (state)
                0: if (sign_start) begin
                       plen <= 0;
                       // CBOR map header + claims (abbreviated)
                       payload[0] <= 8'hA6;              // map(6)
                       payload[1] <= 8'h63; payload[2] <= "n"; payload[3] <= "c";
                       payload[4] <= 8'h58; payload[5] <= 8'h20;  // bstr(32)
                       // nonce
                       // ... pcr digest, model digest, config digest, ts, policy
                       plen <= 16'd120;
                       state <= 1;
                   end
                1: begin ec_start <= 1; state <= 2; end
                2: if (ec_done) begin
                       // COSE_Sign1 = [protected, unprotected, payload, sig]
                       quote_len <= plen + 16'd72;
                       idx <= 0; state <= 3;
                   end
                3: begin
                       fifo_data  <= payload[idx];
                       fifo_valid <= 1;
                       idx <= idx + 1;
                       if (idx == plen - 1) begin state <= 4; idx <= 0; end
                   end
                4: begin
                       fifo_data  <= ec_sig[511 - 8*idx -: 8];
                       fifo_valid <= 1;
                       idx <= idx + 1;
                       if (idx == 63) begin state <= 5; done <= 1; end
                   end
                default: state <= 0;
            endcase
        end
    end
endmodule

`endif
