`timescale 1ns / 1ps

module tb_ram_test;
    parameter CLK_PERIOD = 10;
    
    reg clk, rst_n;
    reg we;
    reg [11:0] addr;
    reg [7:0] din;
    wire [7:0] dout;
    
    dual_port_ram u_ram (
        .clk(clk), .rst_n(rst_n),
        .we_a(we), .addr_a(addr), .din_a(din), .dout_a(dout),
        .we_b(1'b0), .addr_b(12'd0), .din_b(8'd0), .dout_b()
    );
    
    initial clk = 0;
    always #(CLK_PERIOD/2) clk = ~clk;
    
    initial begin
        rst_n = 0;
        we = 0;
        addr = 0;
        din = 0;
        
        #(CLK_PERIOD * 5);
        rst_n = 1;
        #(CLK_PERIOD * 5);
        
        $display("写入数据到 RAM...");
        @(posedge clk); we = 1; addr = 0; din = "m";
        @(posedge clk); addr = 1; din = "o";
        @(posedge clk); addr = 2; din = "d";
        @(posedge clk); we = 0;
        
        #(CLK_PERIOD * 2);
        
        $display("读取数据:");
        @(posedge clk); addr = 0;
        @(posedge clk); $display("addr=0, dout=%c (0x%02x)", dout, dout);
        @(posedge clk); addr = 1;
        @(posedge clk); $display("addr=1, dout=%c (0x%02x)", dout, dout);
        @(posedge clk); addr = 2;
        @(posedge clk); $display("addr=2, dout=%c (0x%02x)", dout, dout);
        
        #(CLK_PERIOD * 10);
        $finish;
    end
endmodule
