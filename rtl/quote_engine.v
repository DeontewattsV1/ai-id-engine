// SPDX-License-Identifier: MIT
// Attestation quote generator ("quote signer" block of the architecture).
//
// Builds the 660-byte AIQ2 quote body in hardware, hashes it with SHA-256
// (11 compressions incl. padding) and has the ATTACHED SECURE ELEMENT sign
// the digest with its ECDSA P-256 device key over SPI (se_spi_master).
// The engine never holds an ECDSA private key; this replaces the removed
// in-RTL ECDSA core, which leaked its key (research/unsafe-ecdsa/).
//
// Body layout (big-endian), mirrored by verifier/src/lib.rs::hw_transcript:
//   off   0  "AIQ2"                 4
//   off   4  hw_rev (OTP)           2
//   off   6  lifecycle (OTP)        1
//   off   7  tamper sticky flags    1
//   off   8  quote counter          4
//   off  12  timestamp (host time)  8
//   off  20  device_id              32   HMAC(CDI, "DVID"||label)
//   off  52  nonce                  32
//   off  84  PCR0..PCR15            512
//   off 596  model_digest           32   last weight measurement
//   off 628  config_digest          32
//   = 660 bytes. sig = ECDSA-P256(SE key, SHA-256(body)), r||s.
//
// Fail-closed gates (err=1, no SE request): no valid device identity,
// any tamper flag set, lifecycle not DEV/PROD, or zeroized.
`timescale 1ns/1ps

module quote_engine (
    input  wire         clk,
    input  wire         rst_n,
    input  wire         zeroize,
    input  wire         start,        // sign a quote
    input  wire         pub_start,    // fetch SE public key
    input  wire         id_valid,
    input  wire [255:0] device_id,
    input  wire [15:0]  hw_rev,
    input  wire [7:0]   lifecycle,
    input  wire [7:0]   tamper,
    input  wire [63:0]  timestamp,
    input  wire [255:0] nonce,
    input  wire [4095:0] pcr_flat,    // PCR i at [255+256*i -: 256]
    input  wire [255:0] model_digest,
    input  wire [255:0] config_digest,
    output reg  [511:0] sig,
    output reg  [511:0] se_pub,
    output reg          pub_valid,
    output reg  [159:0] hdr,          // first 20 body bytes of the last quote
    output reg  [255:0] body_digest,
    output reg  [15:0]  quote_len,    // 660 after a successful quote, else 0
    output reg  [31:0]  counter,
    output reg          done,         // level: last quote succeeded
    output reg          err,          // level: last request failed
    output reg  [3:0]   err_code,     // 1 no-id 2 tamper 3 lifecycle 4 SE 5 zeroized
    output wire         busy,
    output wire         se_cs_n, se_sck, se_mosi,
    input  wire         se_miso
);
    localparam [255:0] IV =
        256'h6a09e667bb67ae853c6ef372a54ff53a510e527f9b05688c1f83d9ab5be0cd19;
    localparam IDLE = 3'd0, KICK = 3'd1, HWAIT = 3'd2, SIGN = 3'd3,
               SWAIT = 3'd4, PWAIT = 3'd5;

    reg [2:0]   st;
    reg [255:0] h;
    reg [3:0]   blk_i;
    reg         c_start;
    /* verilator lint_off UNUSEDSIGNAL */
    wire        c_busy;
    /* verilator lint_on UNUSEDSIGNAL */
    wire        c_done;
    wire [255:0] c_dig;
    reg [255:0] id_q, nonce_q, model_q, cfg_q;
    reg         zeroized;

    // SPI to the secure element
    reg         s_start;
    reg [7:0]   s_cmd;
    wire [511:0] s_rx;
    wire        s_done, s_err, s_busy;

    se_spi_master u_spi (.clk(clk), .rst_n(rst_n), .start(s_start), .cmd(s_cmd),
        .tx_data(h), .tx_len(s_cmd == 8'h02 ? 6'd32 : 6'd0), .rx_data(s_rx),
        .done(s_done), .err(s_err), .busy(s_busy),
        .cs_n(se_cs_n), .sck(se_sck), .mosi(se_mosi), .miso(se_miso));

    // PCRs in index order, PCR0 first
    wire [4095:0] pcrs_be;
    genvar gi;
    generate for (gi = 0; gi < 16; gi = gi + 1) begin : g_pcr
        assign pcrs_be[4095 - 256*gi -: 256] = pcr_flat[255 + 256*gi -: 256];
    end endgenerate

    wire [5279:0] body   = {hdr, id_q, nonce_q, pcrs_be, model_q, cfg_q};
    wire [5631:0] padded = {body, 1'b1, 287'b0, 64'd5280};
    wire [511:0]  block  = padded[5631 - 512*blk_i -: 512];

    sha256_compress u_c (.clk(clk), .rst_n(rst_n), .start(c_start), .h_in(h),
                         .block(block), .busy(c_busy), .done(c_done), .digest(c_dig));

    assign busy = (st != IDLE) || s_busy;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            st <= IDLE; h <= IV; blk_i <= 0; c_start <= 0; id_q <= 0; nonce_q <= 0;
            model_q <= 0; cfg_q <= 0; hdr <= 0; sig <= 0; se_pub <= 0;
            pub_valid <= 0; body_digest <= 0; quote_len <= 0; counter <= 0;
            done <= 0; err <= 0; err_code <= 0; s_start <= 0; s_cmd <= 0;
            zeroized <= 0;
        end else if (zeroize) begin
            st <= IDLE; h <= IV; blk_i <= 0; c_start <= 0; id_q <= 0; nonce_q <= 0;
            model_q <= 0; cfg_q <= 0; hdr <= 0; sig <= 0; body_digest <= 0;
            quote_len <= 0; done <= 0; err <= 1; err_code <= 4'd5; s_start <= 0;
            zeroized <= 1;
        end else begin
            c_start <= 0; s_start <= 0;
            case (st)
                IDLE: begin
                    if (start) begin
                        done <= 0; quote_len <= 0; sig <= 0;
                        if (zeroized)                 begin err <= 1; err_code <= 4'd5; end
                        else if (!id_valid)           begin err <= 1; err_code <= 4'd1; end
                        else if (tamper != 8'h00)     begin err <= 1; err_code <= 4'd2; end
                        else if (lifecycle != 8'h02 && lifecycle != 8'h03)
                                                      begin err <= 1; err_code <= 4'd3; end
                        else begin
                            err <= 0; err_code <= 0;
                            hdr <= {32'h41495132, hw_rev, lifecycle, tamper, counter, timestamp};
                            id_q <= device_id; nonce_q <= nonce;
                            model_q <= model_digest; cfg_q <= config_digest;
                            h <= IV; blk_i <= 0; st <= KICK;
                        end
                    end else if (pub_start && !zeroized) begin
                        s_cmd <= 8'h01; s_start <= 1; st <= PWAIT;
                    end
                end
                KICK:  begin c_start <= 1; st <= HWAIT; end
                HWAIT: if (c_done) begin
                    h <= c_dig;
                    if (blk_i == 4'd10) st <= SIGN;
                    else begin blk_i <= blk_i + 4'd1; st <= KICK; end
                end
                SIGN:  begin body_digest <= h; s_cmd <= 8'h02; s_start <= 1; st <= SWAIT; end
                SWAIT: if (s_done) begin
                    if (s_err) begin err <= 1; err_code <= 4'd4; end
                    else begin
                        sig <= s_rx; done <= 1; quote_len <= 16'd660;
                        counter <= counter + 32'd1;
                    end
                    st <= IDLE;
                end
                PWAIT: if (s_done) begin
                    if (s_err) begin err <= 1; err_code <= 4'd4; end
                    else begin se_pub <= s_rx; pub_valid <= 1; end
                    st <= IDLE;
                end
                default: st <= IDLE;
            endcase
        end
    end
endmodule
