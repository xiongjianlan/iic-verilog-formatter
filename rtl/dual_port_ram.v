//============================================================================
// 双端口 RAM 模块
// 用于存储原始代码和格式化结果
//============================================================================

module dual_port_ram #(
    parameter DATA_WIDTH = 8,
    parameter ADDR_WIDTH = 12,          // 4KB = 4096 bytes
    parameter DEPTH      = 4096
)(
    input  wire                  clk,
    input  wire                  rst_n,

    // 端口 A：I2C Slave 和格式化器写入
    input  wire                  we_a,
    input  wire [ADDR_WIDTH-1:0] addr_a,
    input  wire [DATA_WIDTH-1:0] din_a,
    output reg  [DATA_WIDTH-1:0] dout_a,

    // 端口 B：I2C Slave 读取
    input  wire                  we_b,
    input  wire [ADDR_WIDTH-1:0] addr_b,
    input  wire [DATA_WIDTH-1:0] din_b,
    output reg  [DATA_WIDTH-1:0] dout_b
);

    // RAM 存储器
    reg [DATA_WIDTH-1:0] mem [0:DEPTH-1];

    integer i;

    // 端口 A 操作
    always @(posedge clk) begin
        if (we_a) begin
            mem[addr_a] <= din_a;
        end
        dout_a <= mem[addr_a];
    end

    // 端口 B 操作
    always @(posedge clk) begin
        if (we_b) begin
            mem[addr_b] <= din_b;
        end
        dout_b <= mem[addr_b];
    end

endmodule
