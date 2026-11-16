// control plane
// SPDX-License-Identifier: MIT
// APB3 slave: register file and doorbells of the identity engine.
// The authoritative register map is fw/id_engine_regs.h; test/check_regmap.py
// fails CI if it and this decoder disagree.
//
// Multi-word values move as big-endian 32-bit words through one address.
// The word index auto-increments while the same address is accessed back to
// back and restarts at word 0 whenever a different address is used.
// Writes to MEAS_DATA / MEAS_FINAL insert APB wait states (pready low) until
// the measurement engine can accept the word.
`timescale 1ns/1ps

module apb_regfile (
    input  wire        pclk, presetn, psel, penable, pwrite,
    input  wire [11:0] paddr,
    input  wire [31:0] pwdata,
    output reg  [31:0] prdata,
    output reg         pready,
    // PCR bank
    output reg  [255:0] o_pcr_data, output reg o_pcr_extend,
    output reg  [3:0]   o_pcr_sel,
    // DICE
    output reg          o_cdi_start,
    output reg  [127:0] o_cdi_label,
    // quote
    output reg  [255:0] o_nonce, output reg [255:0] o_config,
    output reg  [63:0]  o_time,
    output reg          o_quote_start, output reg o_pub_start,
    // seal
    output reg  [15:0]  o_seal_policy, output reg [255:0] o_seal_in,
    output reg  [1:0]   o_seal_op,
    // measurement engine
    output reg          o_meas_start, output reg [3:0] o_meas_pcr,
    output reg          o_meas_auto,
    output reg          o_meas_word_v, output reg [31:0] o_meas_word,
    output reg          o_meas_fin, output reg [1:0] o_meas_fin_n,
    output reg  [31:0]  o_meas_tail,
    input  wire         i_meas_ready,
    // key ladder, RNG, OTP, HWCP, IRQ
    output reg          o_ratchet,
    output reg          o_rng_pop,
    output reg  [3:0]   o_otp_addr, output reg o_otp_prog, output reg [31:0] o_otp_wdata,
    output reg  [9:0]   o_hwcp_addr,
    output reg  [3:0]   o_irq_en, output reg [3:0] o_irq_clr,
    // read-back
    input  wire [255:0] i_pcr_read, i_cdi_out, i_unseal_out, i_device_id,
    input  wire [255:0] i_meas_digest, i_quote_digest,
    input  wire [63:0]  i_meas_len,
    input  wire [511:0] i_quote_sig, i_se_pub,
    input  wire [159:0] i_quote_hdr,
    input  wire [15:0]  i_quote_len,
    input  wire [31:0]  i_quote_counter,
    input  wire [7:0]   i_tamper,
    input  wire [31:0]  i_status,
    input  wire [31:0]  i_hwinfo,
    input  wire [31:0]  i_rng,
    input  wire [31:0]  i_otp_rdata,
    input  wire [7:0]   i_hwcp_byte,
    input  wire [31:0]  i_banner_word,
    output wire [2:0]   o_banner_idx,
    input  wire [3:0]   i_irq_status
);
    localparam [11:0] A_MEAS_DATA = 12'h034, A_MEAS_FINAL = 12'h038;

    reg  [3:0]  wcnt;
    reg  [11:0] last_addr;
    wire        is_meas_w = pwrite && (paddr == A_MEAS_DATA || paddr == A_MEAS_FINAL);
    wire        can_go    = !is_meas_w || i_meas_ready;
    wire        access    = psel && penable && !pready && can_go;
    wire [3:0]  idx       = (paddr == last_addr) ? wcnt : 4'd0;
    wire [2:0]  i8        = idx[2:0];
    wire [1:0]  i4        = idx[1:0];
    wire        i2        = idx[0];
    wire [2:0]  i5        = (idx > 4'd4) ? 3'd4 : idx[2:0];
    assign o_banner_idx = i8;

    always @(posedge pclk or negedge presetn) begin
        if (!presetn) begin
            pready <= 0; wcnt <= 0; last_addr <= 12'hFFF; prdata <= 0;
            o_pcr_data <= 0; o_pcr_extend <= 0; o_pcr_sel <= 0;
            o_cdi_start <= 0; o_cdi_label <= 0;
            o_nonce <= 0; o_config <= 0; o_time <= 0; o_quote_start <= 0; o_pub_start <= 0;
            o_seal_policy <= 0; o_seal_in <= 0; o_seal_op <= 0;
            o_meas_start <= 0; o_meas_pcr <= 4'd2; o_meas_auto <= 1;
            o_meas_word_v <= 0; o_meas_word <= 0; o_meas_fin <= 0; o_meas_fin_n <= 0;
            o_meas_tail <= 0; o_ratchet <= 0; o_rng_pop <= 0;
            o_otp_addr <= 0; o_otp_prog <= 0; o_otp_wdata <= 0; o_hwcp_addr <= 0;
            o_irq_en <= 0; o_irq_clr <= 0;
        end else begin
            pready <= access;
            o_pcr_extend <= 0; o_quote_start <= 0; o_pub_start <= 0; o_cdi_start <= 0;
            o_seal_op <= 0; o_meas_start <= 0; o_meas_word_v <= 0; o_meas_fin <= 0;
            o_ratchet <= 0; o_rng_pop <= 0; o_otp_prog <= 0; o_irq_clr <= 0;

            if (access) begin
                last_addr <= paddr;
                wcnt      <= idx + 4'd1;
            end

            if (access && pwrite) begin
                case (paddr)
                    12'h010: o_irq_clr <= pwdata[3:0];
                    12'h014: o_irq_en <= pwdata[3:0];
                    12'h020: o_pcr_sel <= pwdata[3:0];
                    12'h024: o_pcr_data[255 - 32*i8 -: 32] <= pwdata;
                    12'h02C: o_pcr_extend <= pwdata[0];
                    12'h030: begin o_meas_start <= pwdata[0]; o_meas_pcr <= pwdata[7:4];
                                   o_meas_auto <= pwdata[8]; end
                    12'h034: begin o_meas_word <= pwdata; o_meas_word_v <= 1; end
                    12'h038: begin o_meas_fin_n <= pwdata[1:0]; o_meas_fin <= 1; end
                    12'h03C: o_meas_tail <= pwdata;
                    12'h060: o_cdi_label[127 - 32*i4 -: 32] <= pwdata;
                    12'h06C: o_cdi_start <= pwdata[0];
                    12'h080: o_nonce[255 - 32*i8 -: 32] <= pwdata;
                    12'h084: o_config[255 - 32*i8 -: 32] <= pwdata;
                    12'h088: o_time[63 - 32*i2 -: 32] <= pwdata;
                    12'h0A0: begin o_quote_start <= pwdata[0]; o_pub_start <= pwdata[1]; end
                    12'h0C0: o_seal_policy <= pwdata[15:0];
                    12'h0C4: o_seal_in[255 - 32*i8 -: 32] <= pwdata;
                    12'h0CC: o_seal_op <= pwdata[1:0];
                    12'h0D4: o_ratchet <= pwdata[0];
                    12'h0E0: o_otp_addr <= pwdata[3:0];
                    12'h0E8: begin o_otp_wdata <= pwdata; o_otp_prog <= 1; end
                    12'h100: o_hwcp_addr <= pwdata[9:0];
                    default: ;
                endcase
            end

            if (access && !pwrite) begin
                case (paddr)
                    12'h000: prdata <= 32'h49444531;
                    12'h004: prdata <= i_status;
                    12'h008: prdata <= 32'h00000100;          // v0.1.0
                    12'h00C: prdata <= i_hwinfo;
                    12'h010: prdata <= {28'b0, i_irq_status};
                    12'h014: prdata <= {28'b0, o_irq_en};
                    12'h020: prdata <= {28'b0, o_pcr_sel};
                    12'h028: prdata <= i_pcr_read[255 - 32*i8 -: 32];
                    12'h040: prdata <= i_meas_digest[255 - 32*i8 -: 32];
                    12'h044: prdata <= i_meas_len[63 - 32*i2 -: 32];
                    12'h070: prdata <= i_cdi_out[255 - 32*i8 -: 32];
                    12'h074: prdata <= i_device_id[255 - 32*i8 -: 32];
                    12'h0A4: prdata <= {16'b0, i_quote_len};
                    12'h0A8: prdata <= i_quote_sig[511 - 32*idx -: 32];
                    12'h0AC: prdata <= i_quote_hdr[159 - 32*i5 -: 32];
                    12'h0B0: prdata <= i_se_pub[511 - 32*idx -: 32];
                    12'h0B4: prdata <= i_quote_counter;
                    12'h0B8: prdata <= i_quote_digest[255 - 32*i8 -: 32];
                    12'h0C8: prdata <= i_unseal_out[255 - 32*i8 -: 32];
                    12'h0D0: begin prdata <= i_rng; o_rng_pop <= 1; end
                    12'h0E4: prdata <= i_otp_rdata;
                    12'h0F0: prdata <= {24'b0, i_tamper};
                    12'h104: begin prdata <= {24'b0, i_hwcp_byte};
                                   o_hwcp_addr <= o_hwcp_addr + 10'd1; end
                    12'h108: prdata <= i_banner_word;
                    default: prdata <= 32'hDEADBEEF;
                endcase
            end
        end
    end
endmodule
