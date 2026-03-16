//============================================================================
// Verilog 格式化功能验证测试平台 - 简化版
//============================================================================

`timescale 1ns / 1ps

module tb_format_verify_simple;

    parameter CLK_PERIOD = 10;

    reg        clk;
    reg        rst_n;

    // 格式化器接口
    reg        fmt_start;
    reg [15:0] fmt_data_len;
    wire       fmt_done;
    wire [15:0] fmt_result_len;

    // RAM 控制信号
    reg         ram_we;
    reg  [11:0] ram_addr;
    reg  [7:0]  ram_din;
    wire [7:0]  ram_dout;

    // RAM 接口（多路复用）
    wire        ram_wr_en;
    wire [11:0] ram_wr_addr;
    wire [7:0]  ram_wr_data;
    wire        ram_rd_en;
    wire [11:0] ram_rd_addr;

    // 选择信号：0=手动, 1=格式化器
    reg         sel_formatter;

    // 测试数据
    reg [7:0] test_code [0:255];
    integer i;

    //========================================================================
    // 多路复用 - 使用统一的地址信号
    //========================================================================
    wire [11:0] ram_addr_a;
    
    // 地址选择：格式化器工作时使用其地址，否则使用手动地址
    assign ram_addr_a = sel_formatter ? (u_formatter.src_rd_en ? u_formatter.src_rd_addr : u_formatter.dst_wr_addr) : ram_addr;
    assign ram_wr_en = sel_formatter ? u_formatter.dst_wr_en : ram_we;
    assign ram_wr_data = sel_formatter ? u_formatter.dst_wr_data : ram_din;
    assign ram_rd_en = sel_formatter ? u_formatter.src_rd_en : 1'b0;

    //========================================================================
    // 实例化
    //========================================================================
    verilog_formatter u_formatter (
        .clk          (clk),
        .rst_n        (rst_n),
        .start        (fmt_start),
        .data_len     (fmt_data_len),
        .done         (fmt_done),
        .result_len   (fmt_result_len),
        .src_rd_en    (),
        .src_rd_addr  (),
        .src_rd_data  (ram_dout),
        .dst_wr_en    (),
        .dst_wr_addr  (),
        .dst_wr_data  ()
    );

    dual_port_ram u_ram (
        .clk    (clk),
        .rst_n  (rst_n),
        .we_a   (ram_wr_en),
        .addr_a (ram_addr_a),
        .din_a  (ram_wr_data),
        .dout_a (ram_dout),
        .we_b   (1'b0),
        .addr_b (12'd0),
        .din_b  (8'd0),
        .dout_b ()
    );

    //========================================================================
    // 时钟
    //========================================================================
    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end

    //========================================================================
    // 主测试
    //========================================================================
    initial begin
        // 初始化
        rst_n      <= 0;
        fmt_start  <= 0;
        fmt_data_len <= 0;
        sel_formatter <= 0;
        ram_we <= 0;
        ram_addr <= 0;
        ram_din <= 0;

        // 准备测试代码: "module test;\n"
        test_code[0] = "m";
        test_code[1] = "o";
        test_code[2] = "d";
        test_code[3] = "u";
        test_code[4] = "l";
        test_code[5] = "e";
        test_code[6] = " ";
        test_code[7] = "t";
        test_code[8] = "e";
        test_code[9] = "s";
        test_code[10] = "t";
        test_code[11] = ";";
        test_code[12] = 8'h0A;  // \n

        $display("============================================================");
        $display("        Verilog 格式化器简化测试");
        $display("============================================================");

        // 复位
        #(CLK_PERIOD * 10);
        rst_n <= 1;
        #(CLK_PERIOD * 10);

        $display("写入测试代码到 RAM...");
        // 手动写入代码到 RAM
        for (i = 0; i < 13; i = i + 1) begin
            @(posedge clk);
            ram_we <= 1'b1;
            ram_addr <= i[11:0];
            ram_din <= test_code[i];
        end
        @(posedge clk);
        ram_we <= 1'b0;

        $display("切换控制权到格式化器...");
        sel_formatter <= 1'b1;

        $display("触发格式化...");
        // 触发格式化
        @(posedge clk);
        fmt_data_len <= 16'd13;
        fmt_start <= 1'b1;
        @(posedge clk);
        fmt_start <= 1'b0;

        // 等待完成
        $display("等待格式化完成...");
        wait(fmt_done);
        @(posedge clk);

        $display("格式化完成!");
        $display("结果长度: %0d 字节", fmt_result_len);

        // 切换回手动控制
        sel_formatter <= 1'b0;
        #(CLK_PERIOD * 5);

        // 读取结果
        if (fmt_result_len > 0) begin
            $display("格式化结果:");
            $display("----------------------------------------");
            for (i = 0; i < fmt_result_len && i < 256; i = i + 1) begin
                @(posedge clk);
                ram_addr <= i[11:0];
                @(posedge clk);
                $write("%c", ram_dout);
            end
            $display("");
            $display("----------------------------------------");
        end

        $display("============================================================");
        $display("                  测试完成");
        $display("============================================================");

        #(CLK_PERIOD * 100);
        $finish;
    end

    //========================================================================
    // 波形
    //========================================================================
    initial begin
        $dumpfile("tb_format_verify_simple.vcd");
        $dumpvars(0, tb_format_verify_simple);
    end

endmodule
