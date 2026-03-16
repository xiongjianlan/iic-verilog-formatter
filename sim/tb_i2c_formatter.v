//============================================================================
// I2C Verilog 格式化器测试平台
//============================================================================

`timescale 1ns / 1ps

module tb_i2c_formatter;

    //========================================================================
    // 参数定义
    //========================================================================
    parameter CLK_PERIOD = 10;          // 100MHz
    parameter I2C_ADDR   = 7'h50;

    //========================================================================
    // 信号定义
    //========================================================================
    reg        clk;
    reg        rst_n;

    // I2C 信号
    wire       sda;
    reg        sda_drv;
    reg        sda_oe;
    wire       scl;
    reg        scl_drv;

    // 测试数据
    reg [7:0]  test_data [0:4095];
    integer    test_data_len;

    //========================================================================
    // I2C 线或连接
    //========================================================================
    assign sda = sda_oe ? sda_drv : 1'bz;
    assign scl = scl_drv;

    //========================================================================
    // 被测模块实例化
    //========================================================================
    top_i2c_formatter #(
        .I2C_ADDR(I2C_ADDR)
    ) uut (
        .clk  (clk),
        .rst_n(rst_n),
        .sda  (sda),
        .scl  (scl)
    );

    //========================================================================
    // 时钟生成
    //========================================================================
    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end

    //========================================================================
    // I2C 时序任务
    //========================================================================

    // I2C 起始条件
    task i2c_start;
        begin
            @(posedge clk);
            sda_oe = 1;
            sda_drv = 1;
            scl_drv = 1;
            #(CLK_PERIOD * 5);
            sda_drv = 0;
            #(CLK_PERIOD * 5);
            scl_drv = 0;
            #(CLK_PERIOD * 5);
        end
    endtask

    // I2C 停止条件
    task i2c_stop;
        begin
            @(posedge clk);
            sda_oe = 1;
            sda_drv = 0;
            scl_drv = 0;
            #(CLK_PERIOD * 5);
            scl_drv = 1;
            #(CLK_PERIOD * 5);
            sda_drv = 1;
            #(CLK_PERIOD * 5);
            sda_oe = 0;
        end
    endtask

    // 发送一个字节
    task i2c_write_byte;
        input [7:0] data;
        output ack;
        integer i;
        begin
            sda_oe = 1;
            for (i = 7; i >= 0; i = i - 1) begin
                sda_drv = data[i];
                #(CLK_PERIOD * 5);
                scl_drv = 1;
                #(CLK_PERIOD * 10);
                scl_drv = 0;
                #(CLK_PERIOD * 5);
            end

            // 读取 ACK
            sda_oe = 0;
            #(CLK_PERIOD * 5);
            scl_drv = 1;
            #(CLK_PERIOD * 5);
            ack = ~sda;
            #(CLK_PERIOD * 5);
            scl_drv = 0;
            #(CLK_PERIOD * 5);
        end
    endtask

    // 读取一个字节
    task i2c_read_byte;
        output [7:0] data;
        input send_ack;
        integer i;
        begin
            sda_oe = 0;
            data = 0;
            for (i = 7; i >= 0; i = i - 1) begin
                #(CLK_PERIOD * 5);
                scl_drv = 1;
                #(CLK_PERIOD * 5);
                data[i] = sda;
                #(CLK_PERIOD * 5);
                scl_drv = 0;
                #(CLK_PERIOD * 5);
            end

            // 发送 ACK/NACK
            sda_oe = 1;
            sda_drv = ~send_ack;
            #(CLK_PERIOD * 5);
            scl_drv = 1;
            #(CLK_PERIOD * 10);
            scl_drv = 0;
            #(CLK_PERIOD * 5);
        end
    endtask

    //========================================================================
    // 测试序列
    //========================================================================
    integer i;
    reg [7:0]  tx_data;
    reg        ack;
    reg [7:0]  rx_data;
    reg [15:0] rx_len;

    initial begin
        // 初始化
        rst_n = 0;
        sda_drv = 1;
        scl_drv = 1;
        sda_oe = 0;
        test_data_len = 0;

        // 复位
        #(CLK_PERIOD * 100);
        rst_n = 1;
        #(CLK_PERIOD * 100);

        $display("========================================");
        $display("I2C Verilog 格式化器测试开始");
        $display("========================================");

        // 准备测试代码
        test_data[0]  = "m";
        test_data[1]  = "o";
        test_data[2]  = "d";
        test_data[3]  = "u";
        test_data[4]  = "l";
        test_data[5]  = "e";
        test_data[6]  = " ";
        test_data[7]  = "t";
        test_data[8]  = "e";
        test_data[9]  = "s";
        test_data[10] = "t";
        test_data[11] = ";";
        test_data[12] = 8'h0A;  // \n
        test_data_len = 13;

        $display("测试 1: 发送代码数据");
        $display("--------------------");

        // 发送起始条件
        i2c_start();

        // 发送设备地址 + 写
        tx_data = {I2C_ADDR, 1'b0};
        i2c_write_byte(tx_data, ack);
        if (!ack) begin
            $display("错误: 设备无响应");
            $finish;
        end
        $display("✓ 设备地址 ACK 接收");

        // 发送数据
        for (i = 0; i < test_data_len; i = i + 1) begin
            i2c_write_byte(test_data[i], ack);
            if (!ack) begin
                $display("错误: 数据字节 %0d 无 ACK", i);
            end
        end
        $display("✓ 发送 %0d 字节数据", test_data_len);

        // 停止条件
        i2c_stop();
        $display("✓ 停止条件发送");

        // 等待格式化完成
        $display("");
        $display("等待格式化完成...");
        #(CLK_PERIOD * 1000);

        // 读取格式化结果
        $display("");
        $display("测试 2: 读取格式化结果");
        $display("----------------------");

        i2c_start();

        // 发送设备地址 + 读
        tx_data = {I2C_ADDR, 1'b1};
        i2c_write_byte(tx_data, ack);
        if (!ack) begin
            $display("错误: 设备无响应 (读模式)");
            $finish;
        end
        $display("✓ 读模式地址 ACK 接收");

        // 首先读取 2 字节长度
        i2c_read_byte(rx_data, 1'b1);  // ACK
        rx_len[15:8] = rx_data;
        i2c_read_byte(rx_data, 1'b1);  // ACK
        rx_len[7:0] = rx_data;

        $display("✓ 格式化结果长度: %0d 字节", rx_len);

        // 读取数据
        $display("格式化结果:");
        $display("--------------------");
        for (i = 0; i < rx_len && i < 100; i = i + 1) begin
            i2c_read_byte(rx_data, (i < rx_len - 1) ? 1'b1 : 1'b0);
            $write("%c", rx_data);
        end
        $display("");
        $display("--------------------");

        i2c_stop();

        $display("");
        $display("========================================");
        $display("测试完成");
        $display("========================================");

        #(CLK_PERIOD * 100);
        $finish;
    end

    //========================================================================
    // 波形输出
    //========================================================================
    initial begin
        $dumpfile("tb_i2c_formatter.vcd");
        $dumpvars(0, tb_i2c_formatter);
    end

    // 超时检测
    initial begin
        #(CLK_PERIOD * 100000);
        $display("错误: 测试超时");
        $finish;
    end

endmodule
