// ratcheting key derivation from CDI
// SPDX-License-Identifier: MIT
// Monotonic ratchet: K_{n+1} = HMAC(K_n, counter). Forward-secret.
`timescale 1ns/1ps

module key_ladder (
    input  wire         clk,
    input  wire         rst_n,
    input  wire         seed_load,
    input  wire         ratchet,
    input  wire [255:0] seed,
    output reg  [255:0] key_out,
    output reg  [31:0]  counter
);
    reg [511:0] msg;
    reg [1:0]   state;
    reg         h_start;
    wire        h_done;
    wire [255:0] h_mac;

    hmac_sha256 u_h (
        .clk(clk), .rst_n(rst_n), .start(h_start),
        .key(key_out), .msg(msg), .msg_bits(9'd288),
        .done(h_done), .mac(h_mac)
    );

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= 0; key_out <= 0; counter <= 0; h_start <= 0;
        end else begin
            h_start <= 0;
            case (state)
                0: begin
                    if (seed_load) begin key_out <= seed; counter <= 0; end
                    else if (ratchet) begin
                        msg <= {32'h52415443, counter, 224'b0};
                        state <= 1;
                    end
                end
                1: begin h_start <= 1; state <= 2; end
                2: if (h_done) begin
                       key_out <= h_mac; counter <= counter + 1; state <= 0;
                   end
            endcase
        end
    end
endmodule
