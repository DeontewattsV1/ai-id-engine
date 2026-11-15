// SPDX-License-Identifier: MIT
`timescale 1ns/1ps

module pcr_bank (
    input  wire         clk, rst_n,
    input  wire         extend,
    input  wire [3:0]   sel,
    input  wire [255:0] digest_in,
    output reg  [255:0] digest_out,
    output wire [4095:0] flat,
    output wire         busy
);
    reg [255:0] pcr [0:15];
    reg [511:0] blk;
    reg [1:0]   st;
    reg         h_start;
    wire        h_busy, h_done;
    wire [255:0] h_dig;
    reg [3:0]   sel_q;
    integer i;

    assign busy = st != 0;

    sha256_core u_h (.clk(clk), .rst_n(rst_n), .start(h_start),
                     .block(blk), .busy(h_busy), .done(h_done), .digest(h_dig));

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (i = 0; i < 16; i = i + 1) pcr[i] <= 256'b0;
            st <= 0; h_start <= 0; sel_q <= 0;
        end else begin
            h_start <= 0;
            case (st)
                0: if (extend) begin
                       blk <= {pcr[sel], digest_in}; sel_q <= sel; st <= 1;
                   end
                1: begin h_start <= 1; st <= 2; end
                2: if (h_done) begin pcr[sel_q] <= h_dig; st <= 0; end
            endcase
        end
    end

    always @(*) begin
        digest_out = pcr[sel];
        for (i = 0; i < 16; i = i + 1) flat[255 + 256*i -: 256] = pcr[i];
    end
endmodule
