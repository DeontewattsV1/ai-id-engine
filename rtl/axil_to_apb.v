// SPDX-License-Identifier: MIT
// AXI4-Lite slave -> APB3 master bridge (host CPU "AXI" port of the diagram).
// One outstanding transaction; writes win over reads when both are pending.
// AWPROT/ARPROT are ignored; WSTRB must be all ones (32-bit registers only,
// partial writes answer SLVERR without touching the engine).
`timescale 1ns/1ps

module axil_to_apb (
    input  wire        aclk,
    input  wire        aresetn,
    // AXI4-Lite slave
    input  wire [11:0] s_awaddr,  input wire s_awvalid, output reg s_awready,
    input  wire [31:0] s_wdata,   input wire [3:0] s_wstrb,
    input  wire        s_wvalid,  output reg s_wready,
    output reg  [1:0]  s_bresp,   output reg s_bvalid, input wire s_bready,
    input  wire [11:0] s_araddr,  input wire s_arvalid, output reg s_arready,
    output reg  [31:0] s_rdata,   output reg [1:0] s_rresp,
    output reg         s_rvalid,  input wire s_rready,
    // APB3 master
    output reg         psel, penable, pwrite,
    output reg  [11:0] paddr,
    output reg  [31:0] pwdata,
    input  wire [31:0] prdata,
    input  wire        pready
);
    localparam IDLE = 3'd0, SETUP = 3'd1, ACCESS = 3'd2, BRESP = 3'd3, RRESP = 3'd4;
    reg [2:0] st;

    always @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            st <= IDLE; s_awready <= 0; s_wready <= 0; s_bresp <= 0; s_bvalid <= 0;
            s_arready <= 0; s_rdata <= 0; s_rresp <= 0; s_rvalid <= 0;
            psel <= 0; penable <= 0; pwrite <= 0; paddr <= 0; pwdata <= 0;
        end else begin
            s_awready <= 0; s_wready <= 0; s_arready <= 0;
            case (st)
                IDLE: begin
                    if (s_awvalid && s_wvalid) begin
                        s_awready <= 1; s_wready <= 1;
                        if (s_wstrb != 4'hF) begin
                            s_bresp <= 2'b10; s_bvalid <= 1; st <= BRESP;
                        end else begin
                            paddr <= s_awaddr; pwdata <= s_wdata; pwrite <= 1;
                            psel <= 1; st <= SETUP;
                        end
                    end else if (s_arvalid) begin
                        s_arready <= 1;
                        paddr <= s_araddr; pwrite <= 0; psel <= 1; st <= SETUP;
                    end
                end
                SETUP:  begin penable <= 1; st <= ACCESS; end
                ACCESS: if (pready) begin
                    psel <= 0; penable <= 0;
                    if (pwrite) begin s_bresp <= 2'b00; s_bvalid <= 1; st <= BRESP; end
                    else begin s_rdata <= prdata; s_rresp <= 2'b00; s_rvalid <= 1; st <= RRESP; end
                end
                BRESP: if (s_bready) begin s_bvalid <= 0; st <= IDLE; end
                RRESP: if (s_rready) begin s_rvalid <= 0; st <= IDLE; end
                default: st <= IDLE;
            endcase
        end
    end
endmodule
