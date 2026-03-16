//============================================================================
// Verilog 格式化功能验证测试平台
// 验证格式化器的实际格式化效果
//============================================================================

`timescale 1ns / 1ps

module tb_format_verify;

    //========================================================================
    // 参数
    //========================================================================
    parameter CLK_PERIOD = 10;

    //========================================================================
    // 信号
    //========================================================================
    reg        clk;
    reg        rst_n;

    // 格式化器接口
    reg        fmt_start;
    reg [15:0] fmt_data_len;
    wire       fmt_done;
    wire [15:0] fmt_result_len;

    // RAM 接口
    wire        ram_wr_en;
    wire [11:0] ram_wr_addr;
    wire [7:0]  ram_wr_data;
    wire        ram_rd_en;
    wire [11:0] ram_rd_addr;
    wire [7:0]  ram_rd_data;

    // 手动控制信号
    reg         manual_wr_en;
    reg  [11:0] manual_wr_addr;
    reg  [7:0]  manual_wr_data;
    reg         manual_rd_en;
    reg  [11:0] manual_rd_addr;

    // 多路复用 - 当格式化器运行时，由格式化器控制 RAM
    // 当格式化完成(fmt_done)后，由手动控制信号控制 RAM
    assign ram_wr_en   = fmt_done ? manual_wr_en   : u_formatter.dst_wr_en;
    assign ram_wr_addr = fmt_done ? manual_wr_addr : u_formatter.dst_wr_addr;
    assign ram_wr_data = fmt_done ? manual_wr_data : u_formatter.dst_wr_data;
    assign ram_rd_en   = u_formatter.src_rd_en;
    assign ram_rd_addr = u_formatter.src_rd_addr;

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
        .src_rd_data  (ram_rd_data),
        .dst_wr_en    (ram_wr_en),
        .dst_wr_addr  (ram_wr_addr),
        .dst_wr_data  (ram_wr_data)
    );

    dual_port_ram u_ram (
        .clk    (clk),
        .rst_n  (rst_n),
        .we_a   (ram_wr_en),
        .addr_a (ram_wr_addr),
        .din_a  (ram_wr_data),
        .dout_a (ram_rd_data),
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
    // 任务：写入代码到 RAM
    //========================================================================
    task write_code;
        input [8*256-1:0] code_str;
        input [7:0]       code_len;
        integer i;
        begin
            for (i = 0; i < code_len; i = i + 1) begin
                @(posedge clk);
                manual_wr_en   <= 1'b1;
                manual_wr_addr <= i;
                manual_wr_data <= code_str[i*8 +: 8];
            end
            @(posedge clk);
            manual_wr_en <= 1'b0;
        end
    endtask

    //========================================================================
    // 任务：读取格式化结果
    //========================================================================
    task read_result;
        input [15:0] len;
        integer i;
        begin
            $display("格式化结果 (%0d 字节):", len);
            $display("----------------------------------------");
            for (i = 0; i < len && i < 256; i = i + 1) begin
                @(posedge clk);
                manual_rd_en   <= 1'b1;
                manual_rd_addr <= i;
                @(posedge clk);
                @(posedge clk);
                $write("%c", ram_rd_data);
            end
            manual_rd_en <= 1'b0;
            $display("");
            $display("----------------------------------------");
        end
    endtask

    //========================================================================
    // 任务：运行格式化测试
    //========================================================================
    task run_format_test;
        input [8*128-1:0] test_name;
        input [8*256-1:0] input_code;
        input [7:0]       input_len;
        begin
            $display("");
            $display("========================================");
            $display("测试: %0s", test_name);
            $display("========================================");
            $display("输入代码 (%0d 字节):", input_len);
            $display("----------------------------------------");

            // 写入代码
            write_code(input_code, input_len);

            // 触发格式化
            @(posedge clk);
            fmt_data_len <= input_len;
            fmt_start    <= 1'b1;
            @(posedge clk);
            fmt_start    <= 1'b0;

            // 等待完成
            wait(fmt_done);
            @(posedge clk);

            // 读取结果
            read_result(fmt_result_len);

            $display("✓ 格式化完成");
        end
    endtask

    //========================================================================
    // 主测试
    //========================================================================
    initial begin
        // 初始化
        rst_n      <= 0;
        fmt_start  <= 0;
        fmt_data_len <= 0;
        manual_wr_en  <= 0;
        manual_rd_en  <= 0;

        $display("");
        $display("============================================================");
        $display("        Verilog 格式化器功能验证测试平台");
        $display("============================================================");

        // 复位
        #(CLK_PERIOD * 10);
        rst_n <= 1;
        #(CLK_PERIOD * 10);

        //============================================================
        // 测试 1: 简单模块
        //============================================================
        run_format_test(
            "简单模块",
            "module test;input clk;output data;endmodule",
            44
        );

        //============================================================
        // 测试 2: 带缩进的模块
        //============================================================
        run_format_test(
            "带缩进的模块",
            "module counter(input wire clk,input wire rst,output reg [7:0] count);always @(posedge clk) begin if(!rst) begin count<=0;end else begin count<=count+1;end end endmodule",
            150
        );

        //============================================================
        // 测试 3: 带注释的代码
        //============================================================
        run_format_test(
            "带注释的代码",
            "// test module module test (input clk,output data);endmodule",
            58
        );

        //============================================================
        // 测试完成
        //============================================================
        $display("");
        $display("============================================================");
        $display("                  所有测试完成");
        $display("============================================================");

        #(CLK_PERIOD * 100);
        $finish;
    end

    //========================================================================
    // 波形
    //========================================================================
    initial begin
        $dumpfile("tb_format_verify.vcd");
        $dumpvars(0, tb_format_verify);
    end

endmodule
