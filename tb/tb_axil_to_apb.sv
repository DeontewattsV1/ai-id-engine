// SPDX-License-Identifier: MIT
// axil_to_apb against an APB register-file model with random wait states.
`timescale 1ns/1ps
module tb_axil_to_apb;
    reg clk = 0, rstn = 0;
    reg [11:0] awaddr = 0, araddr = 0; reg awvalid = 0, wvalid = 0, bready = 0, arvalid = 0, rready = 0;
    reg [31:0] wdata = 0; reg [3:0] wstrb = 4'hF;
    wire awready, wready, bvalid, arready, rvalid; wire [1:0] bresp, rresp; wire [31:0] rdata;
    wire psel, penable, pwrite; wire [11:0] paddr; wire [31:0] pwdata;
    reg [31:0] mem [0:1023]; reg [31:0] prdata = 0; reg pready = 0;
    integer errors = 0, i, apb_writes = 0;
    axil_to_apb dut (.aclk(clk), .aresetn(rstn),
        .s_awaddr(awaddr), .s_awvalid(awvalid), .s_awready(awready), .s_wdata(wdata), .s_wstrb(wstrb),
        .s_wvalid(wvalid), .s_wready(wready), .s_bresp(bresp), .s_bvalid(bvalid), .s_bready(bready),
        .s_araddr(araddr), .s_arvalid(arvalid), .s_arready(arready), .s_rdata(rdata), .s_rresp(rresp),
        .s_rvalid(rvalid), .s_rready(rready),
        .psel(psel), .penable(penable), .pwrite(pwrite), .paddr(paddr), .pwdata(pwdata),
        .prdata(prdata), .pready(pready));
    always #5 clk = ~clk;
    // APB slave: random wait states; checks the SETUP->ACCESS protocol
    always @(posedge clk) begin
        pready <= 0;
        if (psel && penable && !pready && ($random & 1)) begin
            pready <= 1;
            if (pwrite) begin mem[paddr[11:2]] <= pwdata; apb_writes = apb_writes + 1; end
            else prdata <= mem[paddr[11:2]];
        end
        if (penable && !psel) begin errors = errors + 1; $display("FAIL penable without psel"); end
    end
    task axi_write(input [11:0] a, input [31:0] d, input [3:0] s, output [1:0] resp);
        begin
            @(negedge clk); awaddr = a; wdata = d; wstrb = s; awvalid = 1; wvalid = 1; bready = 1;
            while (!(awready && wready)) @(negedge clk);
            awvalid = 0; wvalid = 0;
            while (!bvalid) @(negedge clk);
            resp = bresp; @(negedge clk); bready = 0;
        end
    endtask
    task axi_read(input [11:0] a, output [31:0] d, output [1:0] resp);
        begin
            @(negedge clk); araddr = a; arvalid = 1; rready = 1;
            while (!arready) @(negedge clk);
            arvalid = 0;
            while (!rvalid) @(negedge clk);
            d = rdata; resp = rresp; @(negedge clk); rready = 0;
        end
    endtask
    reg [1:0] r; reg [31:0] d;
    initial begin
        for (i = 0; i < 1024; i = i + 1) mem[i] = 0;
        #22 rstn = 1;
        for (i = 0; i < 32; i = i + 1) begin
            axi_write(i * 4, 32'hA5000000 ^ (i * 32'h01010101), 4'hF, r);
            if (r != 0) begin errors = errors + 1; $display("FAIL write resp %b", r); end
        end
        for (i = 0; i < 32; i = i + 1) begin
            axi_read(i * 4, d, r);
            if (d !== (32'hA5000000 ^ (i * 32'h01010101)) || r != 0) begin
                errors = errors + 1; $display("FAIL read %0d: %h", i, d);
            end
        end
        // partial write: SLVERR and no APB transfer
        i = apb_writes;
        axi_write(12'h010, 32'hDEADBEEF, 4'h3, r);
        if (r != 2'b10 || apb_writes != i) begin errors = errors + 1; $display("FAIL partial write not rejected"); end
        axi_read(12'h010, d, r);
        if (d === 32'hDEADBEEF) begin errors = errors + 1; $display("FAIL partial write reached the engine"); end
        if (errors == 0) $display("axil_to_apb RTL PASS 64 transfers + WSTRB SLVERR");
        else $fatal(1, "axil_to_apb FAIL (%0d)", errors);
        $finish;
    end
    initial begin #2000000; $fatal(1, "axil timeout"); end
endmodule
