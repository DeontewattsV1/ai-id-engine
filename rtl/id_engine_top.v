// top level
// SPDX-License-Identifier: MIT
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
    // DMA weight-measurement port
    input  wire        dma_valid, input wire [127:0] dma_data,
    input  wire        dma_last,
    output wire        dma_ready,
    // SPI to secure element (UDS escrow)
    output wire        se_cs_n, se_sck, se_mosi, input wire se_miso
);
    wire [255:0] uds;
    wire [255:0] cdi, alias_key;
    wire [255:0] pcr_d, pcr_r, cdi_out, unseal_out;
    wire [4095:0] pcr_flat;
    wire         pcr_ext, pcr_busy, quote_start, cdi_start;
    wire [3:0]   pcr_sel;
    wire [255:0] pcr_wdata, nonce, cdi_parent, seal_in;
    wire [127:0] cdi_label;
    wire [15:0]  seal_policy;
    wire [1:0]   seal_op;
    wire [7:0]   tamper_sticky;
    wire         zeroize;
    wire         seal_ok;
    wire [7:0]   quote_data;
    wire [15:0]  quote_len;
    wire         quote_valid, quote_err;
    wire [15:0]  status = {11'b0, seal_ok, quote_done, 1'b0, pcr_busy, 1'b1};
    wire         quote_done;

    // UDS: SRAM PUF, re-derived each power-on, never stored
    sram_puf u_puf (
        .clk(puf_clk), .rst_n(presetn), .zeroize(zeroize), .uds(uds)
    );

    dice_cdi u_cdi (
        .clk(pclk), .rst_n(presetn), .layer_start(cdi_start),
        .is_root(1'b1), .parent(uds), .label(cdi_label),
        .measurement(pcr_r), .cdi(cdi), .alias_key(alias_key), .valid()
    );

    key_ladder u_kl (
        .clk(pclk), .rst_n(presetn), .seed_load(cdi_start),
        .ratchet(quote_start), .seed(cdi), .key_out(), .counter()
    );

    pcr_bank u_pcr (
        .clk(pclk), .rst_n(presetn), .extend(pcr_ext),
        .sel(pcr_sel), .digest_in(pcr_wdata),
        .digest_out(pcr_r), .flat(pcr_flat), .busy(pcr_busy)
    );

    seal_unit u_seal (
        .clk(pclk), .rst_n(presetn), .op(seal_op), .policy(seal_policy),
        .pcr_flat(pcr_flat), .secret_in(seal_in),
        .secret_out(unseal_out), .ok(seal_ok), .wrapped()
    );

    quote_signer u_q (
        .clk(pclk), .rst_n(presetn), .sign_start(quote_start),
        .alias_key(alias_key), .nonce(nonce), .pcr_flat(pcr_flat),
        .model_digest(pcr_r), .config_digest(256'b0), .timestamp(64'b0),
        .fifo_data(quote_data), .fifo_valid(quote_valid), .quote_len(quote_len),
        .done(quote_done), .err(quote_err)
    );

    tamper_ctrl u_tamper (
        .clk(pclk), .rst_n(presetn), .sensors(tamper_sensors),
        .clear(zeroize_clear), .sticky(tamper_sticky), .zeroize(zeroize)
    );

    apb_regfile u_apb (
        .pclk(pclk), .presetn(presetn), .psel(psel), .penable(penable),
        .pwrite(pwrite), .paddr(paddr), .pwdata(pwdata),
        .prdata(prdata), .pready(pready),
        .o_pcr_data(pcr_wdata), .o_pcr_extend(pcr_ext), .o_pcr_sel(pcr_sel),
        .o_nonce(nonce), .o_quote_start(quote_start),
        .o_cdi_parent(cdi_parent), .o_cdi_start(cdi_start),
        .o_cdi_label(cdi_label), .o_seal_policy(seal_policy),
        .o_seal_in(seal_in), .o_seal_op(seal_op),
        .i_pcr_read(pcr_r), .i_cdi_out(cdi_out), .i_unseal_out(unseal_out),
        .i_tamper(tamper_sticky), .i_quote_len(quote_len),
        .i_quote_data(quote_data), .i_status(status)
    );
endmodule
