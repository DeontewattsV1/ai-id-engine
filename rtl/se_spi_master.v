// SPDX-License-Identifier: MIT
// SPI master (mode 0, MSB first) to the attached secure element (SE).
//
// The SE holds the device attestation key (ECDSA P-256) generated inside
// the SE; the private key never exists in this engine. Transaction, all in
// one chip-select window:
//     MOSI: CMD, payload[0..TX_LEN-1], then 0x00 filler while reading
//     MISO: ignored during CMD/payload; then the master polls bytes until
//           it sees SYNC_OK (0xA5) or SYNC_ERR (0xEE) (SE busy = any other
//           byte, max POLL_MAX polls), then reads RX_LEN response bytes.
// Commands (see tb/se_model.h for the reference SE):
//     0x01 GET_PUBKEY  tx 0  bytes  rx 64 (X||Y)
//     0x02 SIGN_DIGEST tx 32 bytes  rx 64 (r||s, ECDSA P-256 over the digest)
// SCK = clk / (2*DIV).
`timescale 1ns/1ps

module se_spi_master #(
    parameter integer DIV = 2,
    parameter integer POLL_MAX = 4096
) (
    input  wire         clk,
    input  wire         rst_n,
    input  wire         start,
    input  wire [7:0]   cmd,
    input  wire [255:0] tx_data,     // payload, byte 0 = [255:248]
    input  wire [5:0]   tx_len,      // 0 or 32
    output reg  [511:0] rx_data,     // response, byte 0 = [511:504]
    output reg          done,
    output reg          err,         // SE reported error or poll timeout
    output wire         busy,
    output reg          cs_n,
    output reg          sck,
    output reg          mosi,
    input  wire         miso
);
    localparam SYNC_OK = 8'hA5, SYNC_ERR = 8'hEE;
    localparam IDLE = 3'd0, XFER = 3'd1, NEXT = 3'd2, FIN = 3'd3;
    localparam PH_TX = 2'd0, PH_POLL = 2'd1, PH_RX = 2'd2;

    reg [2:0]   st;
    reg [1:0]   ph;
    reg [7:0]   txb, rxb;
    reg [2:0]   bitn;
    reg [7:0]   divc;
    reg [6:0]   bytes;      // bytes done in the current phase
    reg [12:0]  polls;
    reg [7:0]   cmd_q;
    reg [255:0] tx_q;
    reg [5:0]   txlen_q;

    assign busy = (st != IDLE);

    // byte to send after `bytes` bytes of the TX phase (byte 0 is CMD)
    wire [7:0] next_tx = (bytes < {1'b0, txlen_q}) ? tx_q[255 - 8*bytes[4:0] -: 8] : 8'h00;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            st <= IDLE; ph <= PH_TX; txb <= 0; rxb <= 0; bitn <= 0; divc <= 0;
            bytes <= 0; polls <= 0; cmd_q <= 0; tx_q <= 0; txlen_q <= 0;
            rx_data <= 0; done <= 0; err <= 0; cs_n <= 1; sck <= 0; mosi <= 0;
        end else begin
            done <= 0;
            case (st)
                IDLE: if (start) begin
                    cmd_q <= cmd; tx_q <= tx_data; txlen_q <= tx_len;
                    cs_n <= 0; sck <= 0; txb <= cmd; mosi <= cmd[7];
                    bitn <= 0; divc <= 0; bytes <= 0; polls <= 0; ph <= PH_TX;
                    err <= 0; rx_data <= 0; st <= XFER;
                end
                XFER: begin
                    if (divc == DIV[7:0] - 8'd1) begin
                        divc <= 0;
                        if (!sck) begin               // rising edge: sample
                            sck <= 1;
                            rxb <= {rxb[6:0], miso};
                        end else begin                // falling edge: shift
                            sck <= 0;
                            if (bitn == 3'd7) begin
                                st <= NEXT;
                            end else begin
                                bitn <= bitn + 3'd1;
                                txb  <= {txb[6:0], 1'b0};
                                mosi <= txb[6];
                            end
                        end
                    end else divc <= divc + 8'd1;
                end
                NEXT: begin                           // one full byte exchanged
                    bitn <= 0;
                    st <= XFER;
                    case (ph)
                        PH_TX: begin
                            if (bytes == {1'b0, txlen_q}) begin
                                ph <= PH_POLL; bytes <= 0;
                                txb <= 8'h00; mosi <= 1'b0;
                            end else begin
                                txb <= next_tx; mosi <= next_tx[7];
                                bytes <= bytes + 7'd1;
                            end
                        end
                        PH_POLL: begin
                            txb <= 8'h00; mosi <= 1'b0;
                            if (rxb == SYNC_OK) begin ph <= PH_RX; bytes <= 0; end
                            else if (rxb == SYNC_ERR || polls == POLL_MAX[12:0]) begin
                                err <= 1; st <= FIN;
                            end else polls <= polls + 13'd1;
                        end
                        default: begin                // PH_RX
                            txb <= 8'h00; mosi <= 1'b0;
                            rx_data <= {rx_data[503:0], rxb};
                            if (bytes == 7'd63) st <= FIN;
                            else bytes <= bytes + 7'd1;
                        end
                    endcase
                end
                FIN: begin cs_n <= 1; sck <= 0; mosi <= 0; done <= 1; st <= IDLE; end
                default: st <= IDLE;
            endcase
        end
    end
    wire unused_ok = &{1'b0, cmd_q, txb[7]};
endmodule
