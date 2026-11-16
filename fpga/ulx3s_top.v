// SPDX-License-Identifier: MIT
// FPGA prototype top for the Radiona ULX3S (Lattice ECP5 LFE5U-85F).
//
//   USB-UART (FTDI)  -> uart_apb_bridge -> id_engine_top APB port
//   GPIO header      -> secure element SPI (gp0 CS, gp1 SCK, gp2 MOSI, gn2 MISO)
//                    -> tamper mesh: gp4..gp7 out, gn4..gn7 in (loop back
//                       through a serpentine shield trace / jumper wires)
//                    -> gp8: optional external noise source
//   entropy          -> ring-oscillator sampler XOR gp8
//   buttons          -> btn1 zeroize_clear; btn3..btn6 tamper sensors 4..7
//   LEDs             -> heartbeat, irq, SE activity, mesh/tamper indications
// Host software: tools/aiid_uart.py. The OTP image (UDS) is injected at build
// time by fpga/Makefile (random per build); it is inside the bitstream, so
// this board's identity is a PROTOTYPE identity, not a protected secret.
`timescale 1ns/1ps
`ifndef AIID_FPGA_UDS
`define AIID_FPGA_UDS 256'h0
`endif
`ifndef AIID_FPGA_SERIAL
`define AIID_FPGA_SERIAL 64'h0000000000000001
`endif

module ulx3s_top (
    input  wire       clk_25mhz,
    input  wire       ftdi_txd,      // FPGA receives
    output wire       ftdi_rxd,      // FPGA transmits
    input  wire [6:0] btn,
    output wire [7:0] led,
    output wire       se_cs_n,       // gp0
    output wire       se_sck,        // gp1
    output wire       se_mosi,       // gp2
    input  wire       se_miso,       // gn2
    output wire [3:0] mesh_o,        // gp4..gp7
    input  wire [3:0] mesh_i,        // gn4..gn7
    input  wire       noise_in       // gp8
);
    wire clk = clk_25mhz;

    // power-on reset
    reg [15:0] por = 0;
    wire rst_n = &por;
    always @(posedge clk) if (!rst_n) por <= por + 16'd1;

    // APB from the UART bridge
    wire        psel, penable, pwrite, pready;
    wire [11:0] paddr;
    wire [31:0] pwdata, prdata;
    uart_apb_bridge #(.CLK_HZ(25_000_000), .BAUD(115_200)) u_uart (
        .clk(clk), .rst_n(rst_n), .rxd(ftdi_txd), .txd(ftdi_rxd),
        .psel(psel), .penable(penable), .pwrite(pwrite), .paddr(paddr),
        .pwdata(pwdata), .prdata(prdata), .pready(pready));

    // entropy: free-running ring oscillators sampled by clk, XOR external pin
    wire ro_bit;
    ro_entropy_ecp5 #(.N(4)) u_ro (.clk(clk), .bit_out(ro_bit));
    wire ent = ro_bit ^ noise_in;

    wire irq;

    id_engine_top #(.LIFECYCLE(8'h02), .SERIAL(`AIID_FPGA_SERIAL),
                    .UDS_FUSES(`AIID_FPGA_UDS)) u_eng (
        .pclk(clk), .presetn(rst_n), .psel(psel), .penable(penable), .pwrite(pwrite),
        .paddr(paddr), .pwdata(pwdata), .prdata(prdata), .pready(pready), .irq(irq),
        .puf_clk(clk), .tamper_sensors({~btn[6:3], 4'b0}), .zeroize_clear(btn[1]),
        .mesh_out(mesh_o), .mesh_in(mesh_i), .ent_bit(ent),
        .dma_valid(1'b0), .dma_data(128'b0), .dma_last(1'b0), .dma_nbytes(5'd0),
        .dma_ready(),
        .se_cs_n(se_cs_n), .se_sck(se_sck), .se_mosi(se_mosi), .se_miso(se_miso));

    reg [24:0] hb;
    always @(posedge clk) hb <= hb + 25'd1;
    assign led = {mesh_o[0], 3'b0, ~mesh_i[0], ~se_cs_n, irq, hb[24]};
endmodule
