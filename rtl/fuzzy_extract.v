// SPDX-License-Identifier: MIT
// ENROLL: PUF -> key(639) -> bch_enc -> helper -> OTP
// RECON:  PUF + helper -> bch_dec -> key -> SHA-256 -> UDS
`timescale 1ns/1ps

module fuzzy_extract (
    input  wire         clk, rst_n,
    input  wire [1:0]   mode,        // 1 enroll, 2 recon
    input  wire [2046:0] puf_raw,
    input  wire [1407:0] helper_in,
    output reg  [255:0]  uds,
    output reg  [1407:0] helper_out,
    output reg           ok, fail, done
);
    reg [638:0] key;
    reg [2046:0] cw;
    reg [1:0] st;
    wire enc_done, dec_done, dec_ok, dec_fail;
    wire [1407:0] enc_parity;
    wire [638:0]  dec_msg;
    reg  h_start, e_start, d_start;

    bch_enc u_enc (.clk(clk), .rst_n(rst_n), .start(e_start),
                   .msg(key), .parity(enc_parity), .done(enc_done));
    bch_dec u_dec (.clk(clk), .rst_n(rst_n), .start(d_start),
                   .rx(cw), .msg(dec_msg), .ok(dec_ok), .fail(dec_fail),
                   .done(dec_done));

    reg [511:0] hblk; reg hs;
    wire hd; wire [255:0] hdig;
    sha256_core u_h (.clk(clk), .rst_n(rst_n), .start(hs), .block(hblk),
                     .busy(), .done(hd), .digest(hdig));

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin st <= 0; done <= 0; ok <= 0; fail <= 0;
                           uds <= 0; helper_out <= 0; e_start <= 0;
                           d_start <= 0; hs <= 0; end
        else begin
            done <= 0; ok <= 0; fail <= 0; e_start <= 0; d_start <= 0; hs <= 0;
            case (st)
                0: if (mode == 1) begin
                       key <= puf_raw[638:0]; e_start <= 1; st <= 1;
                   end else if (mode == 2) begin
                       cw <= puf_raw ^ {helper_in, 639'b0}; d_start <= 1; st <= 4;
                   end
                1: if (enc_done) begin helper_out <= enc_parity; st <= 2; end
                2: begin hblk <= {key, 383'b0}; hs <= 1; st <= 3; end
                3: if (hd) begin uds <= hdig; ok <= 1; done <= 1; st <= 0; end
                4: if (dec_done) begin
                       if (dec_ok) begin key <= dec_msg; st <= 5; end
                       else begin fail <= 1; done <= 1; st <= 0; end
                   end
                5: begin hblk <= {key, 383'b0}; hs <= 1; st <= 6; end
                6: if (hd) begin uds <= hdig; ok <= 1; done <= 1; st <= 0; end
            endcase
        end
    end
endmodule
