// SPDX-License-Identifier: MIT
// Non-interference miter for key_store_fd: two copies driven by identical
// control inputs but INDEPENDENT key values. The unkeyed outputs (status,
// zeroize, key_valid) must be identical at every cycle, i.e. no key bit ever
// reaches an unkeyed output. key_out is the only keyed port.
`timescale 1ns/1ps
module key_store_nonint (
    input wire         clk, rst_n, load, clear, fault_ext,
    input wire [255:0] key_a, key_b
);
    wire [255:0] ko_a, ko_b;
    wire         kv_a, kv_b, z_a, z_b;
    wire [15:0]  s_a, s_b;
    key_store_fd u_a (.clk(clk), .rst_n(rst_n), .load(load), .key_in(key_a),
        .clear(clear), .fault_ext(fault_ext), .key_out(ko_a), .key_valid(kv_a),
        .status(s_a), .zeroize(z_a));
    key_store_fd u_b (.clk(clk), .rst_n(rst_n), .load(load), .key_in(key_b),
        .clear(clear), .fault_ext(fault_ext), .key_out(ko_b), .key_valid(kv_b),
        .status(s_b), .zeroize(z_b));
    reg f_init = 1'b0;
    always @(posedge clk) f_init <= 1'b1;
    always @(*) if (!f_init) assume (!rst_n);
    always @(*) if (f_init) begin
        assert (s_a == s_b);
        assert (z_a == z_b);
        assert (kv_a == kv_b);
    end
endmodule
