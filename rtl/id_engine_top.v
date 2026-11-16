// top level
// SPDX-License-Identifier: MIT
// AI identity engine v0.1.0 - integration of every block in the
// architecture diagram (ARCHITECTURE.md maps each block to its file):
//
//   host bus ........ apb_regfile (APB3); axil_to_apb / uart_apb_bridge front it
//   UDS ............. sram_puf (sim test UDS | OTP-fused UDS | fail closed)
//   OTP fuses ....... otp_fuses (HW revision code, lifecycle, UDS, lock word)
//   TRNG ............ trng (SP 800-90B RCT/APT health tests) -> hmac_drbg (RNG)
//   DICE ............ dice_cdi (CDI, alias secret, public device_id)
//   key ladder ...... key_ladder (HMAC-DRBG from the alias secret -> key SRAM)
//   measurement ..... sha256_stream (weights via DMA or APB) -> pcr_bank
//   PCR bank ........ pcr_bank (16 x SHA-256, extend-only)
//   sealing ......... seal_unit (PCR-policy release, key = key SRAM slot 0)
//   quote ........... quote_engine -> se_spi_master -> secure element (ECDSA P-256)
//   tamper .......... tamper_mesh + tamper_ctrl -> zeroize
//   code page ....... hwcp_rom (boot banner and 8x8 glyph ROM)
`timescale 1ns/1ps

module id_engine_top #(
    parameter [15:0]  HW_REV    = 16'h4131,   // OTP image (see otp_fuses.v)
    parameter [7:0]   LIFECYCLE = 8'h02,
    parameter [63:0]  SERIAL    = 64'd1,
    parameter [255:0] UDS_FUSES = 256'b0,
    parameter [31:0]  OTP_LOCK  = 32'h0000001F
) (
    input  wire        pclk, presetn,
    input  wire        psel, penable, pwrite,
    input  wire [11:0] paddr,
    input  wire [31:0] pwdata,
    output wire [31:0] prdata,
    output wire        pready,
    output wire        irq,
    input  wire        puf_clk,
    input  wire [7:0]  tamper_sensors,
    input  wire        zeroize_clear,
    output wire [3:0]  mesh_out,
    input  wire [3:0]  mesh_in,
    input  wire        ent_bit,
    // weight-measurement DMA stream (128-bit beats, byte 0 = [127:120])
    input  wire        dma_valid,
    input  wire [127:0] dma_data,
    input  wire        dma_last,
    input  wire [4:0]  dma_nbytes,      // valid bytes in the last beat (1..16)
    output wire        dma_ready,
    // SPI to the secure element
    output wire        se_cs_n, se_sck, se_mosi,
    input  wire        se_miso
);
    // ---------------------------------------------------------------- wires
    wire [255:0] uds, cdi, alias_key, device_id, fuse_uds;
    wire         uds_valid, cdi_valid, cdi_busy;
    wire [255:0] pcr_r, unseal_out;
    wire [4095:0] pcr_flat;
    wire         pcr_busy, pcr_fault, fd_sec;
    wire [3:0]   pcr_sel;
    wire [255:0] pcr_wdata, nonce, cfg, seal_in;
    wire         apb_pcr_ext, quote_start, pub_start, cdi_start;
    wire [127:0] cdi_label;
    wire [63:0]  qtime;
    wire [15:0]  seal_policy;
    wire [1:0]   seal_op;
    wire [7:0]   tamper_sticky;
    wire         zeroize, unseal_ok;
    wire [15:0]  hw_rev;
    wire [7:0]   lifecycle;
    /* verilator lint_off UNUSEDSIGNAL */
    wire [31:0]  otp_features;
    wire [255:0] session_key;
    wire [31:0]  ladder_ctr;
    wire         ladder_busy;
    /* verilator lint_on UNUSEDSIGNAL */
    wire [31:0]  otp_rdata;
    wire         otp_prog_err;

    // --------------------------------------------------------- OTP + UDS
    wire [3:0]  otp_addr;
    wire        otp_prog;
    wire [31:0] otp_wdata;
    otp_fuses #(.HW_REV(HW_REV), .LIFECYCLE(LIFECYCLE), .SERIAL(SERIAL),
                .UDS(UDS_FUSES), .LOCK(OTP_LOCK)) u_otp (.clk(pclk), .rst_n(presetn), .addr(otp_addr), .prog(otp_prog),
        .wdata(otp_wdata), .rdata(otp_rdata), .prog_err(otp_prog_err),
        .hw_rev(hw_rev), .lifecycle(lifecycle), .features(otp_features), .uds(fuse_uds));

    sram_puf u_puf (.clk(puf_clk), .rst_n(presetn), .zeroize(zeroize),
        .fuse_uds(fuse_uds), .uds(uds), .uds_valid(uds_valid));

    // ------------------------------------------------------------ tamper
    wire mesh_breach;
    tamper_mesh u_mesh (.clk(pclk), .rst_n(presetn), .mesh_out(mesh_out),
                        .mesh_in(mesh_in), .breach(mesh_breach));
    wire tamper_zeroize, fd_zeroize;
    tamper_ctrl u_tamper (.clk(pclk), .rst_n(presetn),
        .sensors(tamper_sensors | {7'b0, mesh_breach}),
        .clear(zeroize_clear), .sticky(tamper_sticky), .zeroize(tamper_zeroize));
    // Coded fault detection (docs/FAULT-DETECTION.md). A double-bit PCR word
    // upset or an illegal PCR-controller code sets a duplicated, sticky alarm
    // that only power-on clears; while it is set, zeroize is held high, so
    // every secret-holding block stays wiped. Detection, not side-channel
    // hardening. Without the define the alarm and its status bits are 0.
    wire fd_alarm;
`ifdef AI_ID_FAULT_DETECT
    wire [1:0] fd_alarm_pair;
    fault_alarm #(.N(1)) u_falarm (.clk(pclk), .fault(pcr_fault),
        .zeroize(fd_zeroize), .alarm(fd_alarm_pair));
    assign fd_alarm = |fd_alarm_pair;
`else
    wire unused_ok_fd = &{1'b0, pcr_fault};
    assign fd_zeroize = 1'b0;
    assign fd_alarm   = 1'b0;
`endif
    assign zeroize = tamper_zeroize | fd_zeroize;
    reg zeroized;
    always @(posedge pclk or negedge presetn)
        if (!presetn) zeroized <= 0; else if (zeroize) zeroized <= 1;

    // -------------------------------------------------------------- DICE
    dice_cdi u_cdi (.clk(pclk), .rst_n(presetn), .layer_start(cdi_start && uds_valid),
        .zeroize(zeroize), .is_root(1'b1), .parent(uds), .label(cdi_label),
        .measurement(pcr_r), .cdi(cdi), .alias_key(alias_key), .device_id(device_id),
        .valid(cdi_valid), .busy(cdi_busy));

    reg cdi_valid_q;
    always @(posedge pclk or negedge presetn)
        if (!presetn) cdi_valid_q <= 1'b0; else cdi_valid_q <= cdi_valid;

    // ---------------------------------------- HMAC-DRBG key ladder + key SRAM
    wire ratchet, keys_ready, seal_key_unused;
    wire [255:0] seal_key;
    key_ladder u_kl (.clk(pclk), .rst_n(presetn), .zeroize(zeroize),
        .seed_load(cdi_valid && !cdi_valid_q), .ratchet(ratchet), .seed(alias_key),
        .seal_key(seal_key), .session_key(session_key), .keys_ready(keys_ready),
        .counter(ladder_ctr), .busy(ladder_busy));
    assign seal_key_unused = 1'b0;

    // ------------------------------------------------------- TRNG + RNG DRBG
    wire [175:0] trng_seed;
    wire         trng_seed_valid, trng_fail;
    wire [1:0]   trng_cause;
    reg          trng_ack, r_init, r_upd, r_gen;
    wire         r_busy, r_done, r_inst;
    wire [255:0] r_out;
    wire [31:0]  r_cnt;
    reg  [255:0] rng_buf;
    reg  [2:0]   rng_ptr;
    reg          rng_have, rng_wait;
    wire         rng_pop;

    trng u_trng (.clk(pclk), .rst_n(presetn), .zeroize(zeroize), .ent_bit(ent_bit),
        .seed_ack(trng_ack), .seed(trng_seed), .seed_valid(trng_seed_valid),
        .fail(trng_fail), .fail_cause(trng_cause));

    hmac_drbg u_rng (.clk(pclk), .rst_n(presetn), .zeroize(zeroize),
        .op_init(r_init), .op_update(r_upd), .op_gen(r_gen), .data(trng_seed),
        .data_valid(1'b1), .busy(r_busy), .done(r_done), .out(r_out),
        .instantiated(r_inst), .gen_count(r_cnt));

    // instantiate from the TRNG, reseed every 64 blocks, keep one block ready
    always @(posedge pclk or negedge presetn) begin
        if (!presetn) begin
            trng_ack <= 0; r_init <= 0; r_upd <= 0; r_gen <= 0; rng_buf <= 0;
            rng_ptr <= 0; rng_have <= 0; rng_wait <= 0;
        end else if (zeroize || zeroized || trng_fail) begin
            trng_ack <= 0; r_init <= 0; r_upd <= 0; r_gen <= 0; rng_buf <= 0;
            rng_ptr <= 0; rng_have <= 0; rng_wait <= 0;
        end else begin
            trng_ack <= 0; r_init <= 0; r_upd <= 0; r_gen <= 0;
            if (rng_pop && rng_have) begin
                rng_ptr <= rng_ptr + 3'd1;
                if (rng_ptr == 3'd7) begin rng_have <= 0; rng_buf <= 0; end
            end
            if (rng_wait) begin
                if (r_done) begin
                    rng_wait <= 0;
                    if (r_cnt != 0) begin rng_buf <= r_out; rng_have <= 1; rng_ptr <= 0; end
                end
            end else if (!r_busy) begin
                if (!r_inst && trng_seed_valid) begin
                    r_init <= 1; trng_ack <= 1; rng_wait <= 1;
                end else if (r_inst && r_cnt >= 32'd64 && trng_seed_valid) begin
                    r_upd <= 1; trng_ack <= 1; rng_wait <= 1;
                end else if (r_inst && !rng_have) begin
                    r_gen <= 1; rng_wait <= 1;
                end
            end
        end
    end
    wire [31:0] rng_word = rng_have ? rng_buf[255 - 32*rng_ptr -: 32] : 32'h0;

    // ------------------------------------------------- measurement engine
    wire        m_start, m_auto, m_apb_wv, m_apb_fin;
    wire [3:0]  m_pcr;
    wire [31:0] m_apb_word, m_tail;
    wire [1:0]  m_apb_fin_n;
    wire        m_ready, m_busy, m_done;
    wire [255:0] m_digest;
    wire [63:0] m_len;
    reg         m_valid_dig;

    // DMA beat -> words adapter
    reg [127:0] beat;
    reg         have, last_q;
    reg [4:0]   nb_q;
    reg [2:0]   widx;
    wire [2:0]  full_w   = nb_q[4:2];
    wire [31:0] beat_w   = beat[127 - 32*widx[1:0] -: 32];
    wire        d_word_v = have && (widx < full_w);
    wire        d_fin    = have && (widx >= full_w) && last_q;
    assign dma_ready = !have && m_busy && !zeroized;

    always @(posedge pclk or negedge presetn) begin
        if (!presetn) begin
            beat <= 0; have <= 0; last_q <= 0; nb_q <= 0; widx <= 0;
        end else if (zeroize) begin
            beat <= 0; have <= 0; last_q <= 0; nb_q <= 0; widx <= 0;
        end else if (!have) begin
            if (dma_valid && dma_ready) begin
                beat <= dma_data; have <= 1; last_q <= dma_last; widx <= 0;
                nb_q <= dma_last ? dma_nbytes : 5'd16;
            end
        end else if (d_word_v) begin
            if (m_ready) widx <= widx + 3'd1;
        end else if (d_fin) begin
            if (m_ready) have <= 0;
        end else begin
            have <= 0;                        // full beat consumed, not last
        end
    end

    sha256_stream u_meas (.clk(pclk), .rst_n(presetn), .zeroize(zeroize),
        .start(m_start), .word_valid(m_apb_wv | d_word_v),
        .word(d_word_v ? beat_w : m_apb_word),
        .fin(m_apb_fin | d_fin),
        .fin_word(d_fin ? (widx[2] ? 32'h0 : beat_w) : m_tail),
        .fin_n(d_fin ? nb_q[1:0] : m_apb_fin_n),
        .ready(m_ready), .busy(m_busy), .done(m_done), .digest(m_digest),
        .total_bytes(m_len));

    // ---------------------------------------------------------- PCR bank
    wire quote_busy;
    reg  meas_ext_pend;
    wire meas_ext = meas_ext_pend && !pcr_busy && !apb_pcr_ext && !quote_busy;
    always @(posedge pclk or negedge presetn) begin
        if (!presetn) begin meas_ext_pend <= 0; m_valid_dig <= 0; end
        else if (zeroize) begin meas_ext_pend <= 0; m_valid_dig <= 0; end
        else begin
            if (m_start) m_valid_dig <= 0;
            if (m_done) begin m_valid_dig <= 1; if (m_auto) meas_ext_pend <= 1; end
            else if (meas_ext) meas_ext_pend <= 0;
        end
    end
    pcr_bank u_pcr (.clk(pclk), .rst_n(presetn),
        .extend((apb_pcr_ext && !quote_busy) || meas_ext),
        .sel(meas_ext ? m_pcr : pcr_sel),
        .digest_in(meas_ext ? m_digest : pcr_wdata),
        .digest_out(pcr_r), .flat(pcr_flat), .busy(pcr_busy),
        .fault(pcr_fault), .fd_sec(fd_sec));

    // ------------------------------------------------------------ sealing
    /* verilator lint_off PINCONNECTEMPTY */
    seal_unit u_seal (.clk(pclk), .rst_n(presetn), .zeroize(zeroize),
        .op(keys_ready ? seal_op : 2'd0), .policy(seal_policy), .pcr_flat(pcr_flat),
        .seal_key(seal_key), .secret_in(seal_in), .secret_out(unseal_out),
        .ok(unseal_ok), .wrapped());
    /* verilator lint_on PINCONNECTEMPTY */

    // ------------------------------------------------------------- quote
    wire [511:0] q_sig, se_pub;
    wire [159:0] q_hdr;
    wire [255:0] q_digest;
    wire [15:0]  q_len;
    wire [31:0]  q_ctr;
    wire         q_done, q_err, pub_valid;
    wire [3:0]   q_code;
    quote_engine u_q (.clk(pclk), .rst_n(presetn), .zeroize(zeroize),
        .start(quote_start), .pub_start(pub_start), .id_valid(cdi_valid),
        .device_id(device_id), .hw_rev(hw_rev), .lifecycle(lifecycle),
        .tamper(tamper_sticky), .timestamp(qtime), .nonce(nonce),
        .pcr_flat(pcr_flat), .model_digest(m_valid_dig ? m_digest : 256'b0),
        .config_digest(cfg), .sig(q_sig), .se_pub(se_pub), .pub_valid(pub_valid),
        .hdr(q_hdr), .body_digest(q_digest), .quote_len(q_len), .counter(q_ctr),
        .done(q_done), .err(q_err), .err_code(q_code), .busy(quote_busy),
        .se_cs_n(se_cs_n), .se_sck(se_sck), .se_mosi(se_mosi), .se_miso(se_miso));

    // ------------------------------------------------- code page ROM
    wire [9:0]  hwcp_addr;
    wire [7:0]  hwcp_byte;
    wire [2:0]  banner_idx;
    wire [31:0] banner_word;
    hwcp_rom u_rom (.glyph_addr(hwcp_addr), .glyph_byte(hwcp_byte),
                    .banner_word(banner_idx), .banner(banner_word));

    // ------------------------------------------------------------ IRQ
    wire [3:0] irq_en, irq_clr;
    reg  [3:0] irq_st;
    reg        q_done_q, q_err_q;
    always @(posedge pclk or negedge presetn) begin
        if (!presetn) begin irq_st <= 0; q_done_q <= 0; q_err_q <= 0; end
        else begin
            q_done_q <= q_done; q_err_q <= q_err;
            irq_st <= (irq_st & ~irq_clr) |
                      {q_err && !q_err_q, zeroize, m_done, q_done && !q_done_q};
        end
    end
    assign irq = |(irq_st & irq_en);

`ifdef AI_ID_DEBUG_READBACK
    wire [255:0] cdi_dbg = cdi;      // simulation/debug builds only
`else
    wire [255:0] cdi_dbg = 256'b0;   // CDI never leaves the engine
`endif

    wire [31:0] status = {6'b0, fd_sec, fd_alarm, q_code, 2'b0, mesh_breach, otp_prog_err,
                          zeroized, pub_valid, trng_fail, rng_have,
                          keys_ready, m_valid_dig, m_busy, quote_busy,
                          uds_valid, cdi_busy, q_err, unseal_ok,
                          q_done, cdi_valid, pcr_busy, 1'b1};

    apb_regfile u_apb (
        .pclk(pclk), .presetn(presetn), .psel(psel), .penable(penable),
        .pwrite(pwrite), .paddr(paddr), .pwdata(pwdata),
        .prdata(prdata), .pready(pready),
        .o_pcr_data(pcr_wdata), .o_pcr_extend(apb_pcr_ext), .o_pcr_sel(pcr_sel),
        .o_cdi_start(cdi_start), .o_cdi_label(cdi_label),
        .o_nonce(nonce), .o_config(cfg), .o_time(qtime),
        .o_quote_start(quote_start), .o_pub_start(pub_start),
        .o_seal_policy(seal_policy), .o_seal_in(seal_in), .o_seal_op(seal_op),
        .o_meas_start(m_start), .o_meas_pcr(m_pcr), .o_meas_auto(m_auto),
        .o_meas_word_v(m_apb_wv), .o_meas_word(m_apb_word),
        .o_meas_fin(m_apb_fin), .o_meas_fin_n(m_apb_fin_n), .o_meas_tail(m_tail),
        .i_meas_ready(m_ready),
        .o_ratchet(ratchet), .o_rng_pop(rng_pop),
        .o_otp_addr(otp_addr), .o_otp_prog(otp_prog), .o_otp_wdata(otp_wdata),
        .o_hwcp_addr(hwcp_addr), .o_irq_en(irq_en), .o_irq_clr(irq_clr),
        .i_pcr_read(pcr_r), .i_cdi_out(cdi_dbg), .i_unseal_out(unseal_out),
        .i_device_id(device_id), .i_meas_digest(m_valid_dig ? m_digest : 256'b0),
        .i_quote_digest(q_digest), .i_meas_len(m_len),
        .i_quote_sig(q_sig), .i_se_pub(se_pub), .i_quote_hdr(q_hdr),
        .i_quote_len(q_len), .i_quote_counter(q_ctr), .i_tamper(tamper_sticky),
        .i_status(status), .i_hwinfo({hw_rev, lifecycle, 8'h00}), .i_rng(rng_word),
        .i_otp_rdata(otp_rdata), .i_hwcp_byte(hwcp_byte),
        .i_banner_word(banner_word), .o_banner_idx(banner_idx),
        .i_irq_status(irq_st)
    );
    wire unused_ok = &{1'b0, trng_cause, seal_key_unused, r_out[0], cdi};
endmodule
