// SPDX-License-Identifier: MIT
`timescale 1ns/1ps
// Systematic binary BCH(2047,639), designed t=171.
// g(x) is monic degree 1408, represented as one 1409-bit hex word.
// Encodes message polynomial MSB first; codeword is {msg, parity}.
module bch_enc (
    input  wire         clk, rst_n, start,
    input  wire [638:0] msg,
    output reg  [1407:0] parity,
    output reg          done
);
    reg [1408:0] g_rom [0:0];
    initial $readmemh("rtl/bch_g.mem", g_rom);
    wire [1407:0] g_lower = g_rom[0][1407:0];
    reg [638:0] latched_msg;
    reg [9:0] index;
    reg [1:0] state;
    localparam [1:0] IDLE=0, SHIFT=1, FINISH=2;
    wire feedback = parity[1407] ^ latched_msg[638-index];

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE; done <= 0; parity <= 0;
            latched_msg <= 0; index <= 0;
        end else begin
            done <= 0;
            case (state)
                IDLE: if (start) begin
                    latched_msg <= msg; parity <= 0;
                    index <= 0; state <= SHIFT;
                end
                SHIFT: begin
                    parity <= {parity[1406:0], 1'b0} ^
                              (feedback ? g_lower : 1408'd0);
                    if (index == 10'd638) state <= FINISH;
                    else index <= index + 1'b1;
                end
                FINISH: begin done <= 1; state <= IDLE; end
                default: state <= IDLE;
            endcase
        end
    end
endmodule
