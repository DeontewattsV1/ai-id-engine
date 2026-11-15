// KDF for the key ladder.
// SPDX-License-Identifier: MIT
// HMAC-SHA256(key, msg). msg <= 64 bytes. One-shot, ~3 block ops.
`timescale 1ns/1ps

module hmac_sha256 (
    input  wire         clk,
    input  wire         rst_n,
    input  wire         start,
    input  wire [255:0] key,
    input  wire [511:0] msg,
    input  wire [8:0]   msg_bits,
    output reg          done,
    output reg  [255:0] mac
);
    localparam IPAD = 8'h36, OPAD = 8'h5c;

    reg [511:0] kpad;
    reg [511:0] blk;
    reg [255:0] inner;
    reg [2:0]   state;
    reg         s_start;
    wire        s_busy, s_done;
    wire [255:0] s_dig;

    sha256_core u_sha (
        .clk(clk), .rst_n(rst_n), .start(s_start),
        .block(blk), .busy(s_busy), .done(s_done), .digest(s_dig)
    );

    integer i;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= 0; done <= 0; s_start <= 0; mac <= 0;
        end else begin
            s_start <= 0; done <= 0;
            case (state)
                0: if (start) begin
                       for (i = 0; i < 32; i = i + 1)
                           kpad[255 - 8*i -: 8] <= key[255 - 8*i -: 8] ^ IPAD;
                       for (i = 32; i < 64; i = i + 1)
                           kpad[255 - 8*i -: 8] <= IPAD;
                       blk <= {kpad[511:256], msg[511:256]};
                       state <= 1;
                   end
                1: begin s_start <= 1; state <= 2; end
                2: if (s_done) begin inner <= s_dig; blk <= {kpad[511:256],
                       inner, msg[255:0]}; state <= 3; end
                3: begin s_start <= 1; state <= 4; end
                4: if (s_done) begin
                       for (i = 0; i < 32; i = i + 1)
                           blk[511 - 8*i -: 8] <= key[255 - 8*i -: 8] ^ OPAD;
                       for (i = 32; i < 64; i = i + 1)
                           blk[511 - 8*i -: 8] <= OPAD;
                       state <= 5;
                   end
                5: begin s_start <= 1; state <= 6; end
                6: if (s_done) begin mac <= s_dig; done <= 1; state <= 0; end
                default: state <= 0;
            endcase
        end
    end
endmodule  
