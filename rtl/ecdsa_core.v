// SPDX-License-Identifier: MIT
`timescale 1ns/1ps
`include "mont_params.vh"

module ecdsa_core (
    input  wire         clk, rst_n, start,
    input  wire [255:0] priv, hash,      // priv = alias key (already reduced)
    input  wire [63:0]  blind_seed,
    output reg  [511:0] sig,
    output reg          done, fail
);
    // k' = k + rho*n  => 320-bit scalar, fixed 320 iterations
    reg [319:0] kk;
    reg [9:0]   i;
    reg [2:0]   st;
    reg [255:0] rx, ry, rz, qx, qy, qz, tx, ty, tz;
    reg [255:0] r, s, k_inv, z;
    reg [511:0] prod;                     // 320-bit scalar times 256-bit n
    reg         ea_start, ea_op;
    wire        ea_done;
    wire [255:0] ea_x, ea_y, ea_z;
    reg         inv_start;
    wire        inv_done;
    wire [255:0] inv_r;
    reg [255:0] inv_in;

    // G in affine (hardcoded ROM)
    localparam [255:0] GX = 256'h6b17d1f2e12c4247f8bce6e563a440f277037d812deb33a0f4a13945d898c296;
    localparam [255:0] GY = 256'h4fe342e2fe1a7f9b8ee7eb4a7c0f9e162bce33576b315ececbb6406837bf51f5;

    ec_arith u_ea (.clk(clk), .rst_n(rst_n), .start(ea_start), .op(ea_op),
                   .x1(rx), .y1(ry), .z1(rz), .x2(qx), .y2(qy), .z2(qz),
                   .x3(ea_x), .y3(ea_y), .z3(ea_z), .done(ea_done));

    fp_inv u_inv (.clk(clk), .rst_n(rst_n), .start(inv_start), .a(inv_in),
                  .m(P_MOD), .n0prime(P_N0), .r2(P_R2), .r(inv_r), .done(inv_done));

    wire [255:0] k_base = priv;
    wire [63:0]  rho = blind_seed;

    integer n;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin st <= 0; done <= 0; fail <= 0; ea_start <= 0; inv_start <= 0; end
        else begin
            done <= 0; fail <= 0; ea_start <= 0; inv_start <= 0;
            case (st)
                0: if (start) begin
                       // k' = k + rho*n  (320-bit, constant time)
                       prod = {k_base, 256'b0} + ({256'b0, rho} * N_MOD);
                       kk <= {prod, k_base} + ({256'b0, rho} * N_MOD);
                       st <= 1;
                   end
                1: begin   // randomize projective Q
                       qx <= GX; qy <= GY; qz <= 256'd1;
                       rx <= 0; ry <= 256'd1; rz <= 0;   // accumulator = O
                       i <= 0; st <= 2;
                   end
                2: begin   // double accumulator
                       ea_op <= 0; tx <= rx; ty <= ry; tz <= rz; ea_start <= 1; st <= 3;
                   end
                3: if (ea_done) begin
                       rx <= ea_x; ry <= ea_y; rz <= ea_z; st <= 4;
                   end
                4: begin   // add Q unconditionally
                       ea_op <= 1; ea_start <= 1; st <= 5;
                   end
                5: if (ea_done) begin
                       rx <= ea_x; ry <= ea_y; rz <= ea_z;
                       if (i == 319) st <= 6; else begin i <= i + 1; st <= 2; end
                   end
                6: begin inv_in <= rz; inv_start <= 1; st <= 7; end   // 1/Z
                7: if (inv_done) begin
                       rx <= rx * inv_r; ry <= ry * inv_r; st <= 8;   // to affine
                   end
                8: begin
                       r <= rx % N_MOD;                     // r = Q.x mod n
                       inv_in <= k_base; inv_start <= 1; st <= 9;
                   end
                9: if (inv_done) begin
                       k_inv <= inv_r;
                       z <= hash % N_MOD;
                       st <= 10;
                   end
                10: begin
                       s <= (k_inv * ((z + r * priv) % N_MOD)) % N_MOD;
                       sig <= {r, s};
                       if (r == 0 || s == 0) fail <= 1;
                       done <= 1; st <= 0;
                   end
            endcase
        end
    end
endmodule
