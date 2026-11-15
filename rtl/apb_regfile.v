// APB control plane.
// SPDX-License-Identifier: MIT
// APB3 slave. Decodes register writes into module strobes.
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
    output reg  [255:0] o_cdi_parent, output reg o_cdi_start,
    output reg  [127:0] o_cdi_label,
    output reg  [15:0]  o_seal_policy, output reg [255:0] o_seal_in,
    output reg  [1:0]   o_seal_op,
    input  wire [255:0] i_pcr_read, i_cdi_out, i_unseal_out,
    input  wire [7:0]   i_tamper,
    input  wire [15:0]  i_quote_len,
    input  wire [7:0]   i_quote_data,
    input  wire [15:0]  i_status
);
    reg [2:0] wcnt;

    always @(posedge pclk or negedge presetn) begin
        if (!presetn) begin
            pready <= 0; o_pcr_extend <= 0; o_quote_start <= 0;
            o_cdi_start <= 0; o_seal_op <= 0; wcnt <= 0;
        end else begin
            pready <= psel && penable && !pready;
            o_pcr_extend <= 0; o_quote_start <= 0;
            o_cdi_start <= 0; o_seal_op <= 0;

            if (psel && penable && pwrite) begin
                case (paddr)
                    12'h020: o_pcr_sel <= pwdata[3:0];
                    12'h024: begin o_pcr_data[255 - 32*wcnt -: 32] <= pwdata;
                                  wcnt <= wcnt + 1; end
                    12'h02C: o_pcr_extend <= pwdata[0];
                    12'h060: begin o_cdi_label[127 - 32*wcnt -: 32] <= pwdata;
                                  wcnt <= wcnt + 1; end
                    12'h070: begin o_cdi_parent[255 - 32*wcnt -: 32] <= pwdata;
                                  wcnt <= wcnt + 1; end
                    12'h080: begin o_nonce[255 - 32*wcnt -: 32] <= pwdata;
                                  wcnt <= wcnt + 1; end
                    12'h0A0: o_quote_start <= pwdata[0];
                    12'h0C0: o_seal_policy <= pwdata[15:0];
                    12'h0C4: begin o_seal_in[255 - 32*wcnt -: 32] <= pwdata;
                                  wcnt <= wcnt + 1; end
                    12'h0CC: o_seal_op <= pwdata[1:0];
                    default: ;
                endcase
            end

            if (psel && penable && !pwrite) begin
                case (paddr)
                    12'h000: prdata <= 32'h49444531;
                    12'h004: prdata <= {16'b0, i_status};
                    12'h028: begin prdata <= i_pcr_read[255 - 32*wcnt -: 32];
                                  wcnt <= wcnt + 1; end
                    12'h070: begin prdata <= i_cdi_out[255 - 32*wcnt -: 32];
                                  wcnt <= wcnt + 1; end
                    12'h0A4: prdata <= {16'b0, i_quote_len};
                    12'h0A8: prdata <= {24'b0, i_quote_data};
                    12'h0C8: begin prdata <= i_unseal_out[255 - 32*wcnt -: 32];
                                  wcnt <= wcnt + 1; end
                    12'h0F0: prdata <= {24'b0, i_tamper};
                    default: prdata <= 32'hDEADBEEF;
                endcase
            end
        end
    end
endmodule
