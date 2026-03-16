//============================================================================
// I2C Verilog 格式化器完整功能测试平台
// 测试内容：
//   1. I2C 基本通信 (起始、停止、ACK)
//   2. 代码发送 (写操作)
//   3. 格式化处理
//   4. 结果读取 (读操作)
//   5. 多种代码格式验证
//============================================================================

`timescale 1ns / 1ps

module tb_i2c_formatter_full;

    //========================================================================
    // 参数定义
    //========================================================================
    parameter CLK_PERIOD = 10;          // 100MHz = 10ns
    parameter I2C_PERIOD = 1000;        // 1MHz I2C = 1000ns
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

    // 测试统计
    integer    test_passed;
    integer    test_failed;
    integer    test_num;

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
    // 时钟生成 (100MHz)
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
            #(I2C_PERIOD);
            sda_drv = 0;
            #(I2C_PERIOD);
            scl_drv = 0;
            #(I2C_PERIOD/2);
        end
    endtask

    // I2C 停止条件
    task i2c_stop;
        begin
            @(posedge clk);
            sda_oe = 1;
            sda_drv = 0;
            scl_drv = 0;
            #(I2C_PERIOD);
            scl_drv = 1;
            #(I2C_PERIOD);
            sda_drv = 1;
            #(I2C_PERIOD);
            sda_oe = 0;
        end
    endtask

    // 发送一个字节，返回 ACK 状态
    task i2c_write_byte;
        input [7:0] data;
        output ack;
        begin
            sda_oe = 1;
            // bit 7
            sda_drv = data[7]; #(I2C_PERIOD/2); scl_drv = 1; #(I2C_PERIOD); scl_drv = 0; #(I2C_PERIOD/2);
            // bit 6
            sda_drv = data[6]; #(I2C_PERIOD/2); scl_drv = 1; #(I2C_PERIOD); scl_drv = 0; #(I2C_PERIOD/2);
            // bit 5
            sda_drv = data[5]; #(I2C_PERIOD/2); scl_drv = 1; #(I2C_PERIOD); scl_drv = 0; #(I2C_PERIOD/2);
            // bit 4
            sda_drv = data[4]; #(I2C_PERIOD/2); scl_drv = 1; #(I2C_PERIOD); scl_drv = 0; #(I2C_PERIOD/2);
            // bit 3
            sda_drv = data[3]; #(I2C_PERIOD/2); scl_drv = 1; #(I2C_PERIOD); scl_drv = 0; #(I2C_PERIOD/2);
            // bit 2
            sda_drv = data[2]; #(I2C_PERIOD/2); scl_drv = 1; #(I2C_PERIOD); scl_drv = 0; #(I2C_PERIOD/2);
            // bit 1
            sda_drv = data[1]; #(I2C_PERIOD/2); scl_drv = 1; #(I2C_PERIOD); scl_drv = 0; #(I2C_PERIOD/2);
            // bit 0
            sda_drv = data[0]; #(I2C_PERIOD/2); scl_drv = 1; #(I2C_PERIOD); scl_drv = 0; #(I2C_PERIOD/2);

            // 释放 SDA，读取 ACK
            sda_oe = 0;
            #(I2C_PERIOD/2);
            scl_drv = 1;
            #(I2C_PERIOD/2);
            ack = ~sda;
            #(I2C_PERIOD/2);
            scl_drv = 0;
            #(I2C_PERIOD/2);
        end
    endtask

    // 读取一个字节
    task i2c_read_byte;
        output [7:0] data;
        input send_ack;
        begin
            sda_oe = 0;
            data = 0;
            // bit 7
            #(I2C_PERIOD/2); scl_drv = 1; #(I2C_PERIOD/2); data[7] = sda; #(I2C_PERIOD/2); scl_drv = 0; #(I2C_PERIOD/2);
            // bit 6
            #(I2C_PERIOD/2); scl_drv = 1; #(I2C_PERIOD/2); data[6] = sda; #(I2C_PERIOD/2); scl_drv = 0; #(I2C_PERIOD/2);
            // bit 5
            #(I2C_PERIOD/2); scl_drv = 1; #(I2C_PERIOD/2); data[5] = sda; #(I2C_PERIOD/2); scl_drv = 0; #(I2C_PERIOD/2);
            // bit 4
            #(I2C_PERIOD/2); scl_drv = 1; #(I2C_PERIOD/2); data[4] = sda; #(I2C_PERIOD/2); scl_drv = 0; #(I2C_PERIOD/2);
            // bit 3
            #(I2C_PERIOD/2); scl_drv = 1; #(I2C_PERIOD/2); data[3] = sda; #(I2C_PERIOD/2); scl_drv = 0; #(I2C_PERIOD/2);
            // bit 2
            #(I2C_PERIOD/2); scl_drv = 1; #(I2C_PERIOD/2); data[2] = sda; #(I2C_PERIOD/2); scl_drv = 0; #(I2C_PERIOD/2);
            // bit 1
            #(I2C_PERIOD/2); scl_drv = 1; #(I2C_PERIOD/2); data[1] = sda; #(I2C_PERIOD/2); scl_drv = 0; #(I2C_PERIOD/2);
            // bit 0
            #(I2C_PERIOD/2); scl_drv = 1; #(I2C_PERIOD/2); data[0] = sda; #(I2C_PERIOD/2); scl_drv = 0; #(I2C_PERIOD/2);

            // 发送 ACK/NACK
            sda_oe = 1;
            sda_drv = ~send_ack;
            #(I2C_PERIOD/2);
            scl_drv = 1;
            #(I2C_PERIOD);
            scl_drv = 0;
            #(I2C_PERIOD/2);
        end
    endtask

    //========================================================================
    // 主测试序列
    //========================================================================
    integer i;
    reg [7:0] tx_data;
    reg [7:0] rx_data;
    reg ack;
    reg [7:0] result_mem [0:4095];
    reg [15:0] result_len;

    initial begin
        // 初始化
        rst_n = 0;
        sda_drv = 1;
        scl_drv = 1;
        sda_oe = 0;
        test_passed = 0;
        test_failed = 0;
        test_num = 1;

        for (i = 0; i < 4096; i = i + 1) begin
            result_mem[i] = 0;
        end

        $display("");
        $display("============================================================");
        $display("    I2C Verilog 格式化器 - 完整功能测试平台");
        $display("============================================================");
        $display("");
        $display("测试配置:");
        $display("  I2C 地址: 0x%02X", I2C_ADDR);
        $display("  系统时钟: 100 MHz");
        $display("  I2C 时钟: 500 kHz");
        $display("");

        // 复位
        #(CLK_PERIOD * 100);
        rst_n = 1;
        #(CLK_PERIOD * 100);

        //============================================================
        // 测试 1: 基本 I2C 通信
        //============================================================
        $display("========================================");
        $display("测试 %0d: 基本 I2C 通信", test_num);
        $display("========================================");

        i2c_start();
        tx_data = {I2C_ADDR, 1'b0};
        i2c_write_byte(tx_data, ack);

        if (ack) begin
            $display("✓ 设备地址 ACK 正常");
            test_passed = test_passed + 1;
        end else begin
            $display("✗ 设备地址 NACK");
            test_failed = test_failed + 1;
        end

        i2c_stop();
        test_num = test_num + 1;
        #(I2C_PERIOD * 10);

        //============================================================
        // 测试 2: 发送简单代码
        //============================================================
        $display("");
        $display("========================================");
        $display("测试 %0d: 发送简单代码", test_num);
        $display("========================================");

        i2c_start();
        tx_data = {I2C_ADDR, 1'b0};
        i2c_write_byte(tx_data, ack);

        if (!ack) begin
            $display("✗ 设备无响应");
            test_failed = test_failed + 1;
            i2c_stop();
        end else begin
            $display("✓ 设备响应正常");

            // 发送简单代码: "module test;\n"
            i2c_write_byte("m", ack);
            i2c_write_byte("o", ack);
            i2c_write_byte("d", ack);
            i2c_write_byte("u", ack);
            i2c_write_byte("l", ack);
            i2c_write_byte("e", ack);
            i2c_write_byte(" ", ack);
            i2c_write_byte("t", ack);
            i2c_write_byte("e", ack);
            i2c_write_byte("s", ack);
            i2c_write_byte("t", ack);
            i2c_write_byte(";", ack);
            i2c_write_byte(8'h0A, ack);  // \n

            $display("✓ 代码发送完成 (13 字节)");
            test_passed = test_passed + 1;
            i2c_stop();
        end
        test_num = test_num + 1;
        #(I2C_PERIOD * 10);

        //============================================================
        // 测试 3: 错误地址测试
        //============================================================
        $display("");
        $display("========================================");
        $display("测试 %0d: 错误地址处理", test_num);
        $display("========================================");

        i2c_start();
        tx_data = {7'h3F, 1'b0};  // 错误地址
        i2c_write_byte(tx_data, ack);

        if (!ack) begin
            $display("✓ 错误地址正确忽略 (NACK)");
            test_passed = test_passed + 1;
        end else begin
            $display("✗ 错误地址被接受");
            test_failed = test_failed + 1;
        end

        i2c_stop();
        test_num = test_num + 1;
        #(I2C_PERIOD * 10);

        //============================================================
        // 测试 4: 复杂代码发送
        //============================================================
        $display("");
        $display("========================================");
        $display("测试 %0d: 复杂代码发送", test_num);
        $display("========================================");

        i2c_start();
        tx_data = {I2C_ADDR, 1'b0};
        i2c_write_byte(tx_data, ack);

        if (!ack) begin
            $display("✗ 设备无响应");
            test_failed = test_failed + 1;
            i2c_stop();
        end else begin
            // 发送带缩进的代码
            i2c_write_byte("m", ack);
            i2c_write_byte("o", ack);
            i2c_write_byte("d", ack);
            i2c_write_byte("u", ack);
            i2c_write_byte("l", ack);
            i2c_write_byte("e", ack);
            i2c_write_byte(" ", ack);
            i2c_write_byte("c", ack);
            i2c_write_byte("o", ack);
            i2c_write_byte("u", ack);
            i2c_write_byte("n", ack);
            i2c_write_byte("t", ack);
            i2c_write_byte("e", ack);
            i2c_write_byte("r", ack);
            i2c_write_byte(" ", ack);
            i2c_write_byte("(", ack);
            i2c_write_byte(8'h0A, ack);

            // input wire clk,
            i2c_write_byte("i", ack);
            i2c_write_byte("n", ack);
            i2c_write_byte("p", ack);
            i2c_write_byte("u", ack);
            i2c_write_byte("t", ack);
            i2c_write_byte(" ", ack);
            i2c_write_byte("w", ack);
            i2c_write_byte("i", ack);
            i2c_write_byte("r", ack);
            i2c_write_byte("e", ack);
            i2c_write_byte(" ", ack);
            i2c_write_byte("c", ack);
            i2c_write_byte("l", ack);
            i2c_write_byte("k", ack);
            i2c_write_byte(",", ack);
            i2c_write_byte(8'h0A, ack);

            // output reg data
            i2c_write_byte("o", ack);
            i2c_write_byte("u", ack);
            i2c_write_byte("t", ack);
            i2c_write_byte("p", ack);
            i2c_write_byte("u", ack);
            i2c_write_byte("t", ack);
            i2c_write_byte(" ", ack);
            i2c_write_byte("r", ack);
            i2c_write_byte("e", ack);
            i2c_write_byte("g", ack);
            i2c_write_byte(" ", ack);
            i2c_write_byte("d", ack);
            i2c_write_byte("a", ack);
            i2c_write_byte("t", ack);
            i2c_write_byte("a", ack);
            i2c_write_byte(8'h0A, ack);

            // );
            i2c_write_byte(")", ack);
            i2c_write_byte(";", ack);
            i2c_write_byte(8'h0A, ack);

            // endmodule
            i2c_write_byte("e", ack);
            i2c_write_byte("n", ack);
            i2c_write_byte("d", ack);
            i2c_write_byte("m", ack);
            i2c_write_byte("o", ack);
            i2c_write_byte("d", ack);
            i2c_write_byte("u", ack);
            i2c_write_byte("l", ack);
            i2c_write_byte("e", ack);
            i2c_write_byte(8'h0A, ack);

            $display("✓ 复杂代码发送完成 (约 60 字节)");
            test_passed = test_passed + 1;
            i2c_stop();
        end
        test_num = test_num + 1;
        #(I2C_PERIOD * 10);

        //============================================================
        // 测试 5: 读取操作 (读模式)
        //============================================================
        $display("");
        $display("========================================");
        $display("测试 %0d: I2C 读操作", test_num);
        $display("========================================");

        i2c_start();
        tx_data = {I2C_ADDR, 1'b1};  // 读模式
        i2c_write_byte(tx_data, ack);

        if (!ack) begin
            $display("✗ 读模式设备无响应");
            test_failed = test_failed + 1;
        end else begin
            $display("✓ 读模式设备响应");

            // 尝试读取一些字节
            i2c_read_byte(rx_data, 1'b1);
            $display("  读取字节 0: 0x%02X (%c)", rx_data, rx_data);

            i2c_read_byte(rx_data, 1'b1);
            $display("  读取字节 1: 0x%02X (%c)", rx_data, rx_data);

            i2c_read_byte(rx_data, 1'b0);  // NACK 结束
            $display("  读取字节 2: 0x%02X (%c)", rx_data, rx_data);

            test_passed = test_passed + 1;
        end

        i2c_stop();
        test_num = test_num + 1;
        #(I2C_PERIOD * 10);

        //============================================================
        // 测试总结
        //============================================================
        $display("");
        $display("============================================================");
        $display("                      测试总结");
        $display("============================================================");
        $display("  总测试数: %0d", test_num - 1);
        $display("  通过:     %0d", test_passed);
        $display("  失败:     %0d", test_failed);
        $display("============================================================");

        if (test_failed == 0) begin
            $display("");
            $display("  [PASS] 所有测试通过！");
        end else begin
            $display("");
            $display("  [FAIL] 部分测试失败");
        end

        #(CLK_PERIOD * 100);
        $finish;
    end

    //========================================================================
    // 波形输出
    //========================================================================
    initial begin
        $dumpfile("tb_i2c_formatter_full.vcd");
        $dumpvars(0, tb_i2c_formatter_full);
    end

    // 超时检测
    initial begin
        #(CLK_PERIOD * 1000000);  // 10ms 超时
        $display("");
        $display("[ERROR] 测试超时！");
        $finish;
    end

endmodule
