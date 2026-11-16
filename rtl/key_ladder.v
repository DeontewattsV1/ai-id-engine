// SPDX-License-Identifier: MIT
// HMAC-DRBG key ladder -> secure key SRAM.
//
// When a fresh DICE alias secret arrives (seed_load), an hmac_drbg instance
// is instantiated deterministically from it:
//     init(seed[255:80]); update({seed[79:0], "KLAD", 64'b0})
// and NSLOTS 256-bit keys are generated into an internal key SRAM:
//     slot 0 : seal/unseal wrapping key (consumer: seal_unit)
//     slot 1 : session key, rotated by `ratchet` (forward secrecy: the
//              previous value is overwritten by the next DRBG output)
//     slot 2,3: reserved (storage / SE pairing keys in a later revision)
// Keys never reach the register file: there is no read path from the APB
// bus to this SRAM; only the hard-wired consumer ports below. `zeroize`
// clears the DRBG state and every slot.
`timescale 1ns/1ps

module key_ladder #(parameter integer NSLOTS = 4) (  // NSLOTS <= 4
    input  wire         clk,
    input  wire         rst_n,
    input  wire         zeroize,
    input  wire         seed_load,
    input  wire         ratchet,
    input  wire [255:0] seed,
    output wire [255:0] seal_key,    // slot 0
    output wire [255:0] session_key, // slot 1
    output reg          keys_ready,
    output reg  [31:0]  counter,
    output wire         busy
);
    reg [255:0] slot [0:NSLOTS-1];
    reg [2:0]   st;
    reg [2:0]   idx;
    reg         d_init, d_upd, d_gen;
    reg [175:0] d_data;
    wire        d_busy, d_done;
    wire [255:0] d_out;
    /* verilator lint_off UNUSEDSIGNAL */
    wire        d_inst;
    wire [31:0] d_cnt;
    /* verilator lint_on UNUSEDSIGNAL */
    integer i;

    hmac_drbg u_drbg (.clk(clk), .rst_n(rst_n), .zeroize(zeroize),
        .op_init(d_init), .op_update(d_upd), .op_gen(d_gen), .data(d_data),
        .data_valid(1'b1), .busy(d_busy), .done(d_done), .out(d_out),
        .instantiated(d_inst), .gen_count(d_cnt));

    assign seal_key    = slot[0];
    assign session_key = slot[1];
    assign busy        = (st != 0) || d_busy;

    localparam IDLE = 3'd0, INIT_W = 3'd1, UPD = 3'd2, UPD_W = 3'd3,
               GEN = 3'd4, GEN_W = 3'd5, RAT_W = 3'd6;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            st <= IDLE; idx <= 0; d_init <= 0; d_upd <= 0; d_gen <= 0;
            d_data <= 0; keys_ready <= 0; counter <= 0;
            for (i = 0; i < NSLOTS; i = i + 1) slot[i] <= 256'b0;
        end else if (zeroize) begin
            st <= IDLE; idx <= 0; d_init <= 0; d_upd <= 0; d_gen <= 0;
            d_data <= 0; keys_ready <= 0; counter <= 0;
            for (i = 0; i < NSLOTS; i = i + 1) slot[i] <= 256'b0;
        end else begin
            d_init <= 0; d_upd <= 0; d_gen <= 0;
            case (st)
                IDLE: if (seed_load) begin
                          keys_ready <= 0; counter <= 0;
                          d_data <= seed[255:80]; d_init <= 1; st <= INIT_W;
                      end else if (ratchet && keys_ready) begin
                          d_gen <= 1; st <= RAT_W;
                      end
                INIT_W: if (d_done) st <= UPD;
                UPD:    begin d_data <= {seed[79:0], 32'h4b4c4144, 64'b0};
                              d_upd <= 1; st <= UPD_W; end
                UPD_W:  if (d_done) begin d_data <= 0; idx <= 0; st <= GEN; end
                GEN:    begin d_gen <= 1; st <= GEN_W; end
                GEN_W:  if (d_done) begin
                            slot[idx[1:0]] <= d_out;
                            if (idx == NSLOTS[2:0] - 3'd1) begin keys_ready <= 1; st <= IDLE; end
                            else begin idx <= idx + 3'd1; st <= GEN; end
                        end
                RAT_W:  if (d_done) begin
                            slot[1] <= d_out; counter <= counter + 32'd1; st <= IDLE;
                        end
                default: st <= IDLE;
            endcase
        end
    end
endmodule
