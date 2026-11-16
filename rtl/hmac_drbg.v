// SPDX-License-Identifier: MIT
// HMAC_DRBG (NIST SP 800-90A Rev.1, section 10.1.2) over HMAC-SHA256.
//
//   op_init   : K = 0x00..00, V = 0x01..01, then Update(data)
//   op_update : Update(data)                      (reseed / absorb more seed)
//   op_gen    : V = HMAC(K, V); out = V; Update() (one 256-bit block)
//   Update(d) : K = HMAC(K, V||0x00||d); V = HMAC(K, V)
//               if d present: K = HMAC(K, V||0x01||d); V = HMAC(K, V)
//
// Deviation from SP 800-90A (documented in LIMITATIONS.md): provided data
// is at most 176 bits (22 bytes) per call because hmac_sha256 takes a
// single <=440-bit message. Longer seed material is absorbed with several
// op_update calls. The reference model in tb/tb_id_engine.cpp implements
// the same semantics with OpenSSL HMAC and the RTL is checked bit-exactly.
// No prediction-resistance or reseed-interval policy lives here; the
// caller (rng / key ladder) owns that. Not CAVP-validated.
`timescale 1ns/1ps

module hmac_drbg (
    input  wire         clk,
    input  wire         rst_n,
    input  wire         zeroize,
    input  wire         op_init,
    input  wire         op_update,
    input  wire         op_gen,
    input  wire [175:0] data,       // provided data for init/update
    input  wire         data_valid, // 0: Update() without provided data
    output wire         busy,
    output reg          done,       // pulse at the end of any op
    output reg  [255:0] out,        // last generated block
    output reg          instantiated,
    output reg  [31:0]  gen_count   // generates since last init/update
);
    reg [255:0] K, V;
    reg [175:0] d_q;
    reg         d_has;
    reg [3:0]   st;
    reg         gen_mode;
    reg         h_start;
    reg [511:0] h_msg;
    reg [8:0]   h_bits;
    reg [255:0] h_key;
    wire        h_done;
    wire [255:0] h_mac;

    hmac_sha256 u_h (.clk(clk), .rst_n(rst_n), .start(h_start), .key(h_key),
                     .msg(h_msg), .msg_bits(h_bits), .done(h_done), .mac(h_mac));

    assign busy = (st != 0);

    localparam IDLE = 4'd0, GEN_V = 4'd1, GEN_VW = 4'd2,
               U_K0 = 4'd3, U_K0W = 4'd4, U_V0 = 4'd5, U_V0W = 4'd6,
               U_K1 = 4'd7, U_K1W = 4'd8, U_V1 = 4'd9, U_V1W = 4'd10;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            K <= 0; V <= 0; d_q <= 0; d_has <= 0; st <= IDLE; gen_mode <= 0;
            h_start <= 0; h_msg <= 0; h_bits <= 0; h_key <= 0; done <= 0;
            out <= 0; instantiated <= 0; gen_count <= 0;
        end else if (zeroize) begin
            K <= 0; V <= 0; d_q <= 0; d_has <= 0; st <= IDLE; gen_mode <= 0;
            h_start <= 0; h_msg <= 0; h_key <= 0; done <= 0;
            out <= 0; instantiated <= 0; gen_count <= 0;
        end else begin
            h_start <= 0; done <= 0;
            case (st)
                IDLE: begin
                    if (op_init) begin
                        K <= 256'b0; V <= {32{8'h01}};
                        d_q <= data; d_has <= data_valid; gen_mode <= 0;
                        instantiated <= 1; gen_count <= 0; st <= U_K0;
                    end else if (op_update && instantiated) begin
                        d_q <= data; d_has <= data_valid; gen_mode <= 0;
                        gen_count <= 0; st <= U_K0;
                    end else if (op_gen && instantiated) begin
                        d_has <= 0; gen_mode <= 1; st <= GEN_V;
                    end
                end
                GEN_V:  begin h_key <= K; h_msg <= {V, 256'b0}; h_bits <= 9'd256;
                              h_start <= 1; st <= GEN_VW; end
                GEN_VW: if (h_done) begin V <= h_mac; out <= h_mac;
                              gen_count <= gen_count + 1; st <= U_K0; end
                // K = HMAC(K, V || 0x00 || d)
                U_K0:   begin h_key <= K;
                              h_msg <= d_has ? {V, 8'h00, d_q, 72'b0} : {V, 8'h00, 248'b0};
                              h_bits <= d_has ? 9'd440 : 9'd264;
                              h_start <= 1; st <= U_K0W; end
                U_K0W:  if (h_done) begin K <= h_mac; st <= U_V0; end
                U_V0:   begin h_key <= K; h_msg <= {V, 256'b0}; h_bits <= 9'd256;
                              h_start <= 1; st <= U_V0W; end
                U_V0W:  if (h_done) begin V <= h_mac;
                              if (d_has) st <= U_K1;
                              else begin st <= IDLE; done <= 1; end
                        end
                U_K1:   begin h_key <= K; h_msg <= {V, 8'h01, d_q, 72'b0};
                              h_bits <= 9'd440; h_start <= 1; st <= U_K1W; end
                U_K1W:  if (h_done) begin K <= h_mac; st <= U_V1; end
                U_V1:   begin h_key <= K; h_msg <= {V, 256'b0}; h_bits <= 9'd256;
                              h_start <= 1; st <= U_V1W; end
                U_V1W:  if (h_done) begin V <= h_mac; st <= IDLE; done <= 1;
                              d_q <= 0; end
                default: st <= IDLE;
            endcase
        end
    end
    wire unused_ok = &{1'b0, gen_mode};
endmodule
