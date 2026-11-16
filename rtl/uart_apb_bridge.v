// SPDX-License-Identifier: MIT
// UART -> APB3 master bridge, so a PC can drive the engine on an FPGA board
// through the board's USB-UART (8N1, CLK_HZ/BAUD clocks per bit).
//
// Protocol (all multi-byte fields big-endian):
//   host -> 'W' (0x57) addr_hi addr_lo d3 d2 d1 d0    device -> 'K'
//   host -> 'R' (0x52) addr_hi addr_lo                device -> d3 d2 d1 d0
//   anything else                                     device -> '?'
// tools/aiid_uart.py implements the host side.
`timescale 1ns/1ps

module uart_apb_bridge #(
    parameter integer CLK_HZ = 25_000_000,
    parameter integer BAUD   = 115_200
) (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        rxd,
    output reg         txd,
    output reg         psel, penable, pwrite,
    output reg  [11:0] paddr,
    output reg  [31:0] pwdata,
    input  wire [31:0] prdata,
    input  wire        pready
);
    localparam integer DIV = CLK_HZ / BAUD;

    // ------------------------------------------------------------ RX
    reg [1:0]  rs;
    reg [15:0] rcnt;
    reg [3:0]  rbit;
    reg [7:0]  rsh;
    reg        rbusy, rvalid;
    reg [7:0]  rbyte;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rs <= 2'b11; rcnt <= 0; rbit <= 0; rsh <= 0; rbusy <= 0; rvalid <= 0; rbyte <= 0;
        end else begin
            rs <= {rs[0], rxd};
            rvalid <= 0;
            if (!rbusy) begin
                if (!rs[1]) begin rbusy <= 1; rcnt <= DIV[15:0] / 16'd2; rbit <= 0; end
            end else if (rcnt != 0) rcnt <= rcnt - 16'd1;
            else begin
                rcnt <= DIV[15:0] - 16'd1;
                if (rbit == 0) begin
                    if (rs[1]) rbusy <= 0;          // false start
                    else rbit <= 1;
                end else if (rbit <= 8) begin
                    rsh <= {rs[1], rsh[7:1]}; rbit <= rbit + 4'd1;
                end else begin                      // stop bit
                    rbusy <= 0;
                    if (rs[1]) begin rbyte <= rsh; rvalid <= 1; end
                end
            end
        end
    end

    // ------------------------------------------------------------ TX
    reg [15:0] tcnt;
    reg [3:0]  tbit;
    reg [9:0]  tsh;
    reg        tbusy, tstart;
    reg [7:0]  tbyte;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin txd <= 1; tcnt <= 0; tbit <= 0; tsh <= 10'h3FF; tbusy <= 0; end
        else if (!tbusy) begin
            txd <= 1;
            if (tstart) begin tsh <= {1'b1, tbyte, 1'b0}; tbusy <= 1; tbit <= 0; tcnt <= 0; end
        end else if (tcnt != 0) tcnt <= tcnt - 16'd1;
        else begin
            tcnt <= DIV[15:0] - 16'd1;
            if (tbit == 4'd10) begin tbusy <= 0; txd <= 1; end
            else begin txd <= tsh[0]; tsh <= {1'b1, tsh[9:1]}; tbit <= tbit + 4'd1; end
        end
    end

    // ------------------------------------------------------- command FSM
    localparam C_CMD = 4'd0, C_ARG = 4'd1, C_APB1 = 4'd2, C_APB2 = 4'd3,
               C_SEND = 4'd4, C_WAITTX = 4'd5;
    reg [3:0]  cs;
    reg [7:0]  cmd;
    reg [2:0]  nargs, got;
    reg [47:0] args;
    wire       unused_ok = &{1'b0, args[47:44]};  // 12-bit APB address space
    reg [31:0] resp;
    reg [2:0]  nresp;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cs <= C_CMD; cmd <= 0; nargs <= 0; got <= 0; args <= 0; resp <= 0; nresp <= 0;
            psel <= 0; penable <= 0; pwrite <= 0; paddr <= 0; pwdata <= 0;
            tstart <= 0; tbyte <= 0;
        end else begin
            tstart <= 0;
            case (cs)
                C_CMD: if (rvalid) begin
                    cmd <= rbyte; got <= 0; args <= 0;
                    if (rbyte == 8'h57) begin nargs <= 3'd6; cs <= C_ARG; end
                    else if (rbyte == 8'h52) begin nargs <= 3'd2; cs <= C_ARG; end
                    else begin resp <= {8'h3F, 24'b0}; nresp <= 1; cs <= C_SEND; end
                end
                C_ARG: if (rvalid) begin
                    args <= {args[39:0], rbyte}; got <= got + 3'd1;
                    if (got + 3'd1 == nargs) cs <= C_APB1;
                end
                C_APB1: begin
                    psel <= 1; penable <= 0;
                    if (cmd == 8'h57) begin
                        pwrite <= 1; paddr <= args[43:32]; pwdata <= args[31:0];
                    end else begin
                        pwrite <= 0; paddr <= args[11:0];
                    end
                    cs <= C_APB2;
                end
                C_APB2: begin
                    penable <= 1;
                    if (penable && pready) begin
                        psel <= 0; penable <= 0;
                        if (pwrite) begin resp <= {8'h4B, 24'b0}; nresp <= 1; end
                        else begin resp <= prdata; nresp <= 4; end
                        cs <= C_SEND;
                    end
                end
                C_SEND: if (!tbusy && !tstart) begin
                    tbyte <= resp[31:24]; tstart <= 1; resp <= {resp[23:0], 8'h00};
                    nresp <= nresp - 3'd1; cs <= C_WAITTX;
                end
                C_WAITTX: if (!tstart && !tbusy) cs <= (nresp == 0) ? C_CMD : C_SEND;
                default: cs <= C_CMD;
            endcase
        end
    end
endmodule
