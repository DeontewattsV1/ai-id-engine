// SPDX-License-Identifier: MIT
// Sensor aggregation -> zeroize strobe. Sticky flags, W1C clear.
`timescale 1ns/1ps

module tamper_ctrl (
    input  wire        clk,
    input  wire        rst_n,
    input  wire [7:0]  sensors,     // shield, voltage, clock, temp, light,
                                    // JTAG, case-open, glitch
    input  wire        clear,
    output reg  [7:0]  sticky,
    output reg         zeroize
);
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sticky <= 8'hFF;        // power-on counts as tamper
            zeroize <= 1;
        end else begin
            zeroize <= 0;
            sticky <= sticky | sensors;
            if (|(sensors & ~sticky)) zeroize <= 1;
            if (|(sensors & 8'h01)) zeroize <= 1;   // shield always zeroizes
            if (clear) sticky <= 8'h00;
        end
    end
endmodule
