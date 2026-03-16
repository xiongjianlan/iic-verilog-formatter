`timescale 1ns / 1ps

module tb_debug_br;
    parameter CLK_PERIOD = 10;
    reg clk, rst_n;
    reg fmt_start;
    reg [15:0] fmt_data_len;
    wire fmt_done;
    wire [15:0] fmt_result_len;
    
    reg ram_we;
    reg [11:0] ram_addr;
    reg [7:0] ram_din;
    wire [7:0] ram_dout;
    
    wire ram_wr_en, ram_rd_en;
    wire [11:0] ram_addr_a;
    wire [7:0] ram_wr_data;
    
    reg sel_formatter;
    integer i;
    
    assign ram_addr_a = sel_formatter ? (u_formatter.src_rd_en ? u_formatter.src_rd_addr : u_formatter.dst_wr_addr) : ram_addr;
    assign ram_wr_en = sel_formatter ? u_formatter.dst_wr_en : ram_we;
    assign ram_wr_data = sel_formatter ? u_formatter.dst_wr_data : ram_din;
    assign ram_rd_en = sel_formatter ? u_formatter.src_rd_en : 1'b0;
    
    verilog_formatter u_formatter (
        .clk(clk), .rst_n(rst_n),
        .start(fmt_start), .data_len(fmt_data_len),
        .done(fmt_done), .result_len(fmt_result_len),
        .src_rd_en(), .src_rd_addr(), .src_rd_data(ram_dout),
        .dst_wr_en(), .dst_wr_addr(), .dst_wr_data()
    );
    
    dual_port_ram u_ram (
        .clk(clk), .rst_n(rst_n),
        .we_a(ram_wr_en), .addr_a(ram_addr_a), .din_a(ram_wr_data), .dout_a(ram_dout),
        .we_b(1'b0), .addr_b(12'd0), .din_b(8'd0), .dout_b()
    );
    
    initial clk = 0;
    always #(CLK_PERIOD/2) clk = ~clk;
    
    // 调试输出
    always @(posedge clk) begin
        if (sel_formatter && u_formatter.state == 7) begin  // WRITE_NEWLINE
            $display("T=%0t WRITE_NEWLINE: bytes_remaining=%0d line_len=%0d dst_ptr=%0d", 
                     $time, u_formatter.bytes_remaining, u_formatter.line_len, u_formatter.dst_ptr);
        end
    end
    
    initial begin
        rst_n = 0; fmt_start = 0; fmt_data_len = 0;
        sel_formatter = 0; ram_we = 0; ram_addr = 0; ram_din = 0;
        
        #(CLK_PERIOD * 10);
        rst_n = 1;
        #(CLK_PERIOD * 10);
        
        // 写入 "module test;\n"
        @(posedge clk); ram_we = 1; ram_addr = 0; ram_din = "m";
        @(posedge clk); ram_addr = 1; ram_din = "o";
        @(posedge clk); ram_addr = 2; ram_din = "d";
        @(posedge clk); ram_addr = 3; ram_din = "u";
        @(posedge clk); ram_addr = 4; ram_din = "l";
        @(posedge clk); ram_addr = 5; ram_din = "e";
        @(posedge clk); ram_addr = 6; ram_din = " ";
        @(posedge clk); ram_addr = 7; ram_din = "t";
        @(posedge clk); ram_addr = 8; ram_din = "e";
        @(posedge clk); ram_addr = 9; ram_din = "s";
        @(posedge clk); ram_addr = 10; ram_din = "t";
        @(posedge clk); ram_addr = 11; ram_din = ";";
        @(posedge clk); ram_addr = 12; ram_din = 8'h0A;
        @(posedge clk); ram_we = 0;
        
        #(CLK_PERIOD * 5);
        
        $display("\n启动格式化器...");
        sel_formatter = 1;
        @(posedge clk);
        fmt_data_len = 13;
        fmt_start = 1;
        @(posedge clk);
        fmt_start = 0;
        
        wait(fmt_done);
        @(posedge clk);
        
        $display("\n格式化完成，结果长度=%0d", fmt_result_len);
        $finish;
    end
endmodule
