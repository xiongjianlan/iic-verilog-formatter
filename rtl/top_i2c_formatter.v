//============================================================================
// I2C Verilog 格式化器顶层模块
// 集成 I2C Slave、格式化器和双端口 RAM
//============================================================================

module top_i2c_formatter #(
    parameter I2C_ADDR = 7'h50          // 默认 I2C 地址
)(
    input  wire        clk,             // 系统时钟
    input  wire        rst_n,           // 复位信号，低有效

    // I2C 接口
    inout  wire        sda,             // I2C 数据线
    input  wire        scl              // I2C 时钟线
);

    //========================================================================
    // 内部信号定义
    //========================================================================

    // I2C Slave 到 RAM 的信号
    wire        i2c_ram_wr_en;
    wire [11:0] i2c_ram_wr_addr;
    wire [7:0]  i2c_ram_wr_data;
    wire        i2c_ram_rd_en;
    wire [11:0] i2c_ram_rd_addr;
    wire [7:0]  i2c_ram_rd_data;

    // 格式化器到 RAM 的信号
    wire        fmt_ram_wr_en;
    wire [11:0] fmt_ram_wr_addr;
    wire [7:0]  fmt_ram_wr_data;
    wire        fmt_ram_rd_en;
    wire [11:0] fmt_ram_rd_addr;
    wire [7:0]  fmt_ram_rd_data;

    // 格式化器控制信号
    wire        fmt_start;
    wire [15:0] fmt_data_len;
    wire        fmt_done;
    wire [15:0] fmt_result_len;

    // RAM 仲裁信号
    reg         ram_sel;                // 0: I2C 访问, 1: Formatter 访问
    wire        ram_we_a;
    wire [11:0] ram_addr_a;
    wire [7:0]  ram_din_a;
    wire [7:0]  ram_dout_a;

    //========================================================================
    // RAM 访问仲裁
    //========================================================================

    // 当格式化器工作时，RAM 由格式化器控制
    // 否则由 I2C Slave 控制
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ram_sel <= 1'b0;
        end else begin
            if (fmt_start) begin
                ram_sel <= 1'b1;  // 格式化器开始工作
            end else if (fmt_done) begin
                ram_sel <= 1'b0;  // 格式化完成，交还 I2C
            end
        end
    end

    // RAM 端口 A 多路复用
    assign ram_we_a   = ram_sel ? fmt_ram_wr_en   : i2c_ram_wr_en;
    assign ram_addr_a = ram_sel ? fmt_ram_wr_addr : i2c_ram_wr_addr;
    assign ram_din_a  = ram_sel ? fmt_ram_wr_data : i2c_ram_wr_data;

    // 数据返回
    assign i2c_ram_rd_data  = ram_dout_a;
    assign fmt_ram_rd_data  = ram_dout_a;

    //========================================================================
    // I2C Slave 模块实例化
    //========================================================================
    i2c_slave #(
        .DATA_DEPTH(4096),
        .I2C_ADDR(I2C_ADDR)
    ) u_i2c_slave (
        .clk            (clk),
        .rst_n          (rst_n),
        .sda            (sda),
        .scl            (scl),
        .fmt_start      (fmt_start),
        .fmt_data_len   (fmt_data_len),
        .fmt_done       (fmt_done),
        .fmt_result_len (fmt_result_len),
        .ram_wr_en      (i2c_ram_wr_en),
        .ram_wr_addr    (i2c_ram_wr_addr),
        .ram_wr_data    (i2c_ram_wr_data),
        .ram_rd_en      (i2c_ram_rd_en),
        .ram_rd_addr    (i2c_ram_rd_addr),
        .ram_rd_data    (i2c_ram_rd_data)
    );

    //========================================================================
    // Verilog 格式化器模块实例化
    //========================================================================
    verilog_formatter #(
        .DATA_DEPTH(4096),
        .MAX_LINE_LEN(256)
    ) u_formatter (
        .clk          (clk),
        .rst_n        (rst_n),
        .start        (fmt_start),
        .data_len     (fmt_data_len),
        .done         (fmt_done),
        .result_len   (fmt_result_len),
        .src_rd_en    (fmt_ram_rd_en),
        .src_rd_addr  (fmt_ram_rd_addr),
        .src_rd_data  (fmt_ram_rd_data),
        .dst_wr_en    (fmt_ram_wr_en),
        .dst_wr_addr  (fmt_ram_wr_addr),
        .dst_wr_data  (fmt_ram_wr_data)
    );

    //========================================================================
    // 双端口 RAM 模块实例化
    //========================================================================
    dual_port_ram #(
        .DATA_WIDTH(8),
        .ADDR_WIDTH(12),
        .DEPTH(4096)
    ) u_ram (
        .clk    (clk),
        .rst_n  (rst_n),
        .we_a   (ram_we_a),
        .addr_a (ram_addr_a),
        .din_a  (ram_din_a),
        .dout_a (ram_dout_a),
        .we_b   (1'b0),             // 端口 B 未使用
        .addr_b (12'd0),
        .din_b  (8'd0),
        .dout_b ()
    );

endmodule
