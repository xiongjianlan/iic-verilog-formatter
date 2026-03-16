# I2C Verilog 代码格式化器

一个基于 FPGA 的 Verilog 代码格式化系统，通过 I2C 接口与 PC 通信。

## 系统架构

```
┌─────────────┐      I2C       ┌─────────────────────────────────────┐
│             │<--------------->│                                     │
│  PC 端工具   │                │  FPGA                               │
│  (Python)   │                │  ┌─────────┐    ┌───────────────┐   │
│             │                │  │ I2C     │    │ Verilog       │   │
│  1. 发送    │                │  │ Slave   │<--->│ Formatter    │   │
│     代码    │                │  │         │    │               │   │
│  2. 接收    │                │  └────┬────┘    └───────┬───────┘   │
│     结果    │                │       │                 │           │
│             │                │  ┌────┴────────────────┴───────┐   │
└─────────────┘                │  │      Dual Port RAM           │   │
                               │  │  (4KB 代码存储)              │   │
                               │  └─────────────────────────────┘   │
                               └─────────────────────────────────────┘
```

## 功能特性

- ✅ **I2C 通信** - 标准 I2C 接口，支持 100kHz/400kHz
- ✅ **实时格式化** - FPGA 硬件加速，毫秒级响应
- ✅ **智能缩进** - 自动识别代码块结构
- ✅ **关键字规范** - 统一关键字大小写
- ✅ **空格规范化** - 运算符周围自动添加空格
- ✅ **大容量缓存** - 4KB 代码存储空间
- ✅ **跨平台支持** - PC 端支持 Linux/Windows/macOS

## 文件结构

```
iic_verilog_formatter/
├── rtl/                      # Verilog RTL 源码
│   ├── dual_port_ram.v       # 双端口 RAM
│   ├── i2c_slave.v           # I2C Slave 控制器
│   ├── verilog_formatter.v   # 格式化器核心
│   └── top_i2c_formatter.v   # 顶层模块
├── sim/                      # 仿真测试
│   ├── tb_i2c_formatter.v        # 基础功能测试
│   ├── tb_i2c_formatter_full.v   # 完整功能测试
│   ├── tb_format_verify.v        # 格式化验证测试
│   └── debug/                    # 调试测试文件
│       ├── tb_debug_*.v          # 单元调试测试
│       ├── tb_check_mem.v        # 内存检查测试
│       ├── tb_hex.v              # 十六进制测试
│       ├── tb_ram_test.v         # RAM 测试
│       └── tb_format_verify_*.v  # 格式化调试测试
├── pc_tool/                  # PC 端工具
│   └── i2c_formatter_tool.py # Python 客户端
├── docs/                     # 文档
│   └── protocol.md           # 通信协议
├── Makefile                  # 编译脚本
└── README.md                 # 本文件
```

## 快速开始

### 1. FPGA 端

```bash
# 编译 RTL 代码
make all

# 运行仿真测试
make sim

# 查看波形
make wave
```

### 2. PC 端

```bash
# 安装依赖
make pc_tool

# 格式化单个文件
python3 pc_tool/i2c_formatter_tool.py -i input.v -o output.v

# 交互模式
python3 pc_tool/i2c_formatter_tool.py --interactive
```

## 硬件连接

```
PC/Raspberry Pi          FPGA
    SDA  <-------------->  SDA
    SCL  <-------------->  SCL
    GND  <-------------->  GND
```

- **SDA**: I2C 数据线
- **SCL**: I2C 时钟线
- **I2C 地址**: 0x50 (默认，可配置)

## 使用示例

### 原始代码

```verilog
module test_module (
input wire clk,
input wire rst_n,
output reg [7:0] data_out
);
reg [7:0] counter;
always @(posedge clk or negedge rst_n) begin
if (!rst_n) begin
counter <= 8'h00;
data_out <= 8'h00;
end else begin
counter <= counter + 1;
data_out <= counter;
end
end
endmodule
```

### 格式化后

```verilog
module test_module (
    input  wire clk,
    input  wire rst_n,
    output reg [7:0] data_out
);

    reg [7:0] counter;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            counter  <= 8'h00;
            data_out <= 8'h00;
        end else begin
            counter  <= counter + 1;
            data_out <= counter;
        end
    end

endmodule
```

## 通信协议

详见 [docs/protocol.md](docs/protocol.md)

### 基本流程

1. **发送代码**: PC 通过 I2C 写入 Verilog 代码
2. **格式化**: FPGA 自动处理并格式化代码
3. **读取结果**: PC 通过 I2C 读取格式化后的代码

## 格式化规则

| 规则 | 说明 |
|-----|------|
| 缩进 | 4 空格缩进，自动识别代码块 |
| 关键字 | 统一小写 (module, begin, end 等) |
| 运算符 | 周围添加空格 (<=, =, + 等) |
| 空格 | 合并连续空格，删除行尾空格 |
| 注释 | 保护 // 和 /* */ 注释 |

## 技术规格

| 参数 | 规格 |
|-----|------|
| I2C 时钟 | 100kHz (标准) / 400kHz (快速) |
| 设备地址 | 7'h50 (可配置) |
| 代码缓存 | 4096 字节 |
| 最大行长度 | 256 字符 |
| 格式化延迟 | < 100ms |

## 依赖

### FPGA 端
- Verilog 仿真器: Icarus Verilog / ModelSim / Vivado
- 波形查看器: GTKWave

### PC 端
- Python 3.7+
- smbus2 库

## 许可证

MIT License

## 贡献

欢迎提交 Issue 和 Pull Request！
