// control plane
// SPDX-License-Identifier: MIT
// APB3 slave. Decodes register writes into module strobes.
//
// Register map (byte offsets; 256-bit values move as 8 big-endian words
// through one address, 128-bit values as 4 words):
//   0x000 R   ID = 0x49444531 ("IDE1")
//   0x004 R   STATUS  [0] ready  [1] pcr_busy  [2] cdi_valid
//                     [3] quote_done [4] unseal_ok [5] quote_err
//                     [6] cdi_busy   [7] uds_valid
//   0x020 W   PCR_SEL
//   0x024 W   PCR_DATA   (8 words)
//   0x028 R   PCR_READ   (8 words of PCR[PCR_SEL])
//   0x02C W   PCR_EXTEND (bit0 = go)
//   0x060 W   CDI_LABEL  (4 words)
//   0x06C W   CDI_START  (bit0 = go; root layer from UDS, measurement = PCR[PCR_SEL])
//   0x070 R   CDI_READ   (8 words; returns zeros unless AI_ID_DEBUG_READBACK)
//   0x080 W   NONCE      (8 words)
//   0x0A0 W   QUOTE_START
//   0x0A4 R   QUOTE_LEN  (0: the quote path is fail-closed, see quote_signer)
//   0x0C0 W   SEAL_POLICY (bitmask of PCRs)
//   0x0C4 W   SEAL_IN    (8 words)
//   0x0C8 R   UNSEAL_OUT (8 words)
//   0x0CC W   SEAL_OP    (1 = seal, 2 = unseal)
//   0x0F0 R   TAMPER sticky flags
// The word index auto-increments while the same address is accessed
// back to back and restarts at word 0 whenever a different address is used.
`timescale 1ns/1ps

module apb_regfile (
    input  wire        pclk, presetn, psel, penable, pwrite,
    input  wire [11:0] paddr,
    input  wire [31:0] pwdata,
    output reg  [31:0] prdata,
    output reg         pready,
    // strobes to identity engine
    output reg  [255:0] o_pcr_data, output reg o_pcr_extend,
    output reg  [3:0]   o_pcr_sel,
    output reg  [255:0] o_nonce, output reg o_quote_start,
    output reg  o_cdi_start,
    output reg  [127:0] o_cdi_label,
    output reg  [15:0]  o_seal_policy, output reg [255:0] o_seal_in,
    output reg  [1:0]   o_seal_op,
    input  wire [255:0] i_pcr_read, i_cdi_out, i_unseal_out,
    input  wire [15:0]  i_quote_len,
    input  wire [7:0]   i_tamper,
    input  wire [15:0]  i_status
);
    reg [2:0]  wcnt;
    reg [11:0] last_addr;
    wire       access = psel && penable && !pready;   // one decode per transfer
    wire [2:0] idx    = (paddr == last_addr) ? wcnt : 3'd0;
    wire [1:0] idx4   = idx[1:0];

    always @(posedge pclk or negedge presetn) begin
        if (!presetn) begin
            pready <= 0; o_pcr_extend <= 0; o_quote_start <= 0;
            o_cdi_start <= 0; o_seal_op <= 0; wcnt <= 0; last_addr <= 12'hFFF;
            prdata <= 0; o_pcr_data <= 0; o_pcr_sel <= 0; o_nonce <= 0;
            o_cdi_label <= 0; o_seal_policy <= 0; o_seal_in <= 0;
        end else begin
            pready <= psel && penable && !pready;
            o_pcr_extend <= 0; o_quote_start <= 0;
            o_cdi_start <= 0; o_seal_op <= 0;

            if (access) begin
                last_addr <= paddr;
                wcnt      <= idx + 3'd1;
            end

            if (access && pwrite) begin
                case (paddr)
                    12'h020: o_pcr_sel <= pwdata[3:0];
                    12'h024: o_pcr_data[255 - 32*idx -: 32] <= pwdata;
                    12'h02C: o_pcr_extend <= pwdata[0];
                    12'h060: o_cdi_label[127 - 32*idx4 -: 32] <= pwdata;
                    12'h06C: o_cdi_start <= pwdata[0];
                    12'h080: o_nonce[255 - 32*idx -: 32] <= pwdata;
                    12'h0A0: o_quote_start <= pwdata[0];
                    12'h0C0: o_seal_policy <= pwdata[15:0];
                    12'h0C4: o_seal_in[255 - 32*idx -: 32] <= pwdata;
                    12'h0CC: o_seal_op <= pwdata[1:0];
                    default: ;
                endcase
            end

            if (access && !pwrite) begin
                case (paddr)
                    12'h000: prdata <= 32'h49444531;
                    12'h004: prdata <= {16'b0, i_status};
                    12'h028: prdata <= i_pcr_read[255 - 32*idx -: 32];
                    12'h070: prdata <= i_cdi_out[255 - 32*idx -: 32];
                    12'h0A4: prdata <= {16'b0, i_quote_len};
                    12'h0C8: prdata <= i_unseal_out[255 - 32*idx -: 32];
                    12'h0F0: prdata <= {24'b0, i_tamper};
                    default: prdata <= 32'hDEADBEEF;
                endcase
            end
        end
    end
endmodule
