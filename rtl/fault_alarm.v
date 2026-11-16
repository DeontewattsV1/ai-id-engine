// SPDX-License-Identifier: MIT
// Duplicated, sticky fault alarm.
//   * Two independent latches with complementary encoding: a (set = 1) and
//     b_n (set = 0). Any fault input, or any disagreement between the two
//     latches, sets both on the next clock edge.
//   * zeroize = a | ~b_n: a fault that clears one latch still leaves zeroize
//     asserted, and the disagreement re-sets the cleared latch.
//   * There is NO reset input. Only power-on (configuration / initial value)
//     clears the alarm, so rst_n, software, or a debugger cannot clear it.
// Coding and duplication DETECT faults. They do not protect against side
// channels (power, EM, timing); see docs/FAULT-DETECTION.md.
`timescale 1ns/1ps

module fault_alarm #(
    parameter N = 4
) (
    input  wire         clk,
    input  wire [N-1:0] fault,      // level or pulse; any bit sets the alarm
    output wire         zeroize,    // held high forever once set
    output wire [1:0]   alarm       // {a, ~b_n} for status readback
);
    (* keep *) reg a;               // power-on: clear
    (* keep *) reg b_n;             // power-on: clear (complement)
    initial begin a = 1'b0; b_n = 1'b1; end   // configuration-time value
    wire set = (|fault) | (a ^ ~b_n);
    always @(posedge clk) if (set) a   <= 1'b1;
    always @(posedge clk) if (set) b_n <= 1'b0;
    assign zeroize = a | ~b_n;
    assign alarm   = {a, ~b_n};

`ifdef FORMAL
    // formal/fault_alarm.sby: sticky, duplicated.
    reg f_past = 1'b0;
    always @(posedge clk) f_past <= 1'b1;
    always @(posedge clk) if (f_past) begin
        if ($past(zeroize)) assert (zeroize);             // never clears
        if ($past(|fault))  assert (a && !b_n);           // any fault sets both
    end
`endif
endmodule
