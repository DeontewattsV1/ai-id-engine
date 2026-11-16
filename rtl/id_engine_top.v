// top level
// SPDX-License-Identifier: MIT
// Integration of the identity pipeline:
//   UDS (sram_puf) -> DICE CDI / alias key (dice_cdi, HMAC-SHA256)
//   measurement chain (pcr_bank, SHA-256 extend)
//   PCR-policy sealing (seal_unit, functional model)
//   key ratchet (key_ladder), tamper/zeroize (tamper_ctrl)
//   quote_signer: FAIL-CLOSED until the ECDSA path is verified.
// DMA and secure-element SPI ports are reserved and tied off.
`timescale 1ns/1ps

module id_engine_top (
    input  wire        pclk, presetn,
    input  wire        psel, penable, pwrite,
    input  wire [11:0] paddr,
    input  wire [31:0] pwdata,
    output wire [31:0] prdata,
    output wire        pready,
    input  wire        puf_clk,
    input  wire [7:0]  tamper_sensors,
    input  wire        zeroize_clear,
    // DMA weight-measurement port (reserved; not implemented)
    input  wire        dma_valid, input wire [127:0] dma_data,
    input  wire        dma_last,
    output wire        dma_ready,
    // SPI to secure element (reserved; not implemented)
    output wire        se_cs_n, se_sck, se_mosi, input wire se_miso
);
    wire [255:0] uds, cdi, alias_key;
    wire         uds_valid;
    wire [255:0] pcr_r, unseal_out;
    wire [4095:0] pcr_flat;
    wire         pcr_ext, pcr_busy, quote_start, cdi_start, cdi_valid, cdi_busy;
    wire [3:0]   pcr_sel;
    wire [255:0] pcr_wdata, nonce, seal_in;
    wire [127:0] cdi_label;
    wire [15:0]  seal_policy, quote_len;
    wire [1:0]   seal_op;
    wire [7:0]   tamper_sticky;
    wire         zeroize, quote_done, quote_err, unseal_ok;
    wire [15:0]  status = {8'b0, uds_valid, cdi_busy, quote_err, unseal_ok,
                           quote_done, cdi_valid, pcr_busy, 1'b1};

    // Reserved interfaces: tied off, never leak state.
    assign dma_ready = 1'b0;
    assign se_cs_n   = 1'b1;
    assign se_sck    = 1'b0;
    assign se_mosi   = 1'b0;
    wire unused_ok = &{1'b0, dma_valid, dma_data, dma_last, se_miso};

    // UDS: SRAM PUF placeholder (see rtl/sram_puf.v)
    sram_puf u_puf (
        .clk(puf_clk), .rst_n(presetn), .zeroize(zeroize),
        .uds(uds), .uds_valid(uds_valid)
    );

    dice_cdi u_cdi (
        .clk(pclk), .rst_n(presetn), .layer_start(cdi_start && uds_valid),
        .zeroize(zeroize), .is_root(1'b1), .parent(uds), .label(cdi_label),
        .measurement(pcr_r), .cdi(cdi), .alias_key(alias_key),
        .valid(cdi_valid), .busy(cdi_busy)
    );

    // Seed the ratchet once per freshly derived CDI.
    reg cdi_valid_q;
    always @(posedge pclk or negedge presetn)
        if (!presetn) cdi_valid_q <= 1'b0; else cdi_valid_q <= cdi_valid;

    /* verilator lint_off PINCONNECTEMPTY */
    key_ladder u_kl (
        .clk(pclk), .rst_n(presetn), .seed_load(cdi_valid && !cdi_valid_q),
        .ratchet(quote_start), .seed(cdi), .key_out(), .counter()
    );
    /* verilator lint_on PINCONNECTEMPTY */

    pcr_bank u_pcr (
        .clk(pclk), .rst_n(presetn), .extend(pcr_ext),
        .sel(pcr_sel), .digest_in(pcr_wdata),
        .digest_out(pcr_r), .flat(pcr_flat), .busy(pcr_busy)
    );

    /* verilator lint_off PINCONNECTEMPTY */
    seal_unit u_seal (
        .clk(pclk), .rst_n(presetn), .zeroize(zeroize), .op(seal_op),
        .policy(seal_policy), .pcr_flat(pcr_flat), .seal_key(cdi),
        .secret_in(seal_in), .secret_out(unseal_out), .ok(unseal_ok),
        .wrapped()
    );

    quote_signer u_q (
        .clk(pclk), .rst_n(presetn), .sign_start(quote_start),
        .alias_key(alias_key), .nonce(nonce), .pcr_flat(pcr_flat),
        .model_digest(pcr_r), .config_digest(256'b0), .timestamp(64'b0),
        .fifo_data(), .fifo_valid(), .quote_len(quote_len),
        .done(quote_done), .err(quote_err)
    );
    /* verilator lint_on PINCONNECTEMPTY */

    tamper_ctrl u_tamper (
        .clk(pclk), .rst_n(presetn), .sensors(tamper_sensors),
        .clear(zeroize_clear), .sticky(tamper_sticky), .zeroize(zeroize)
    );

`ifdef AI_ID_DEBUG_READBACK
    wire [255:0] cdi_dbg = cdi;      // simulation/debug builds only
`else
    wire [255:0] cdi_dbg = 256'b0;   // CDI never leaves the engine
`endif

    apb_regfile u_apb (
        .pclk(pclk), .presetn(presetn), .psel(psel), .penable(penable),
        .pwrite(pwrite), .paddr(paddr), .pwdata(pwdata),
        .prdata(prdata), .pready(pready),
        .o_pcr_data(pcr_wdata), .o_pcr_extend(pcr_ext), .o_pcr_sel(pcr_sel),
        .o_nonce(nonce), .o_quote_start(quote_start),
        .o_cdi_start(cdi_start),
        .o_cdi_label(cdi_label), .o_seal_policy(seal_policy),
        .o_seal_in(seal_in), .o_seal_op(seal_op),
        .i_pcr_read(pcr_r), .i_cdi_out(cdi_dbg), .i_unseal_out(unseal_out),
        .i_quote_len(quote_len), .i_tamper(tamper_sticky), .i_status(status)
    );
endmodule
