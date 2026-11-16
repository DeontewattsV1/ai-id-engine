// SPDX-License-Identifier: MIT
// uart_apb_bridge: serial W / R / unknown commands against an APB model.
`timescale 1ns/1ps
module tb_uart_apb_bridge;
    localparam integer DIV = 10;
    reg clk = 0, rst_n = 0, rxd = 1;
    wire txd, psel, penable, pwrite; wire [11:0] paddr; wire [31:0] pwdata;
    reg [31:0] mem [0:1023]; reg [31:0] prdata = 0; reg pready = 0;
    integer errors = 0, i;
    uart_apb_bridge #(.CLK_HZ(1_000_000), .BAUD(100_000)) dut (.clk(clk), .rst_n(rst_n), .rxd(rxd), .txd(txd),
        .psel(psel), .penable(penable), .pwrite(pwrite), .paddr(paddr), .pwdata(pwdata), .prdata(prdata), .pready(pready));
    always #5 clk = ~clk;
    always @(posedge clk) begin
        pready <= 0;
        if (psel && penable && !pready) begin
            pready <= 1;
            if (pwrite) mem[paddr[11:2]] <= pwdata; else prdata <= mem[paddr[11:2]];
        end
    end
    task send(input [7:0] b);
        integer k;
        begin
            rxd = 0; repeat (DIV) @(posedge clk);
            for (k = 0; k < 8; k = k + 1) begin rxd = b[k]; repeat (DIV) @(posedge clk); end
            rxd = 1; repeat (DIV) @(posedge clk);
        end
    endtask
    task recv(output [7:0] b);
        integer k, t;
        begin
            t = 0;
            while (txd && t < 4000) begin @(posedge clk); t = t + 1; end
            if (t >= 4000) begin errors = errors + 1; $display("FAIL no reply"); b = 0; end
            else begin
                repeat (DIV + DIV / 2) @(posedge clk);
                for (k = 0; k < 8; k = k + 1) begin b[k] = txd; repeat (DIV) @(posedge clk); end
                if (!txd) begin errors = errors + 1; $display("FAIL bad stop bit"); end
            end
        end
    endtask
    reg [7:0] b0, b1, b2, b3;
    initial begin
        for (i = 0; i < 1024; i = i + 1) mem[i] = 0;
        #22 rst_n = 1; repeat (5) @(posedge clk);
        fork
            begin send(8'h57); send(8'h00); send(8'h84); send(8'hCA); send(8'hFE); send(8'hBA); send(8'hBE); end
            recv(b0);
        join
        if (b0 != 8'h4B || mem[12'h084 >> 2] != 32'hCAFEBABE) begin errors = errors + 1; $display("FAIL write: ack %h mem %h", b0, mem[33]); end
        mem[12'h108 >> 2] = 32'h41492D49;
        fork
            begin send(8'h52); send(8'h01); send(8'h08); end
            begin recv(b0); recv(b1); recv(b2); recv(b3); end
        join
        if ({b0, b1, b2, b3} != 32'h41492D49) begin errors = errors + 1; $display("FAIL read %h%h%h%h", b0, b1, b2, b3); end
        fork send(8'h99); recv(b0); join
        if (b0 != 8'h3F) begin errors = errors + 1; $display("FAIL unknown cmd reply %h", b0); end
        if (errors == 0) $display("uart_apb_bridge RTL PASS write/read/unknown over 8N1 serial");
        else $fatal(1, "uart_apb_bridge FAIL (%0d)", errors);
        $finish;
    end
    initial begin #5000000; $fatal(1, "uart timeout"); end
endmodule
