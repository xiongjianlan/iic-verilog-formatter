# I2C Verilog 格式化器通信协议

## 概述

本协议定义了 PC 与 FPGA 之间通过 I2C 接口传输 Verilog 代码并进行格式化的通信规范。

## 硬件连接

```
PC (Linux/Raspberry Pi)          FPGA
+-------------------+             +-------------------+
|                   |             |                   |
|  I2C Master       |<---SDA----->|  I2C Slave        |
|  (smbus2)         |<---SCL----->|  (I2C_ADDR=0x50)  |
|                   |             |                   |
+-------------------+             +-------------------+
```

## I2C 设备地址

- **默认地址**: `0x50` (7-bit)
- **可配置**: 通过修改 `top_i2c_formatter.v` 中的 `I2C_ADDR` 参数

## 通信流程

### 1. 发送代码 (写操作)

```
[START] + [Device Addr + W] + [Data Byte 0] + ... + [Data Byte N] + [STOP]
```

- **Device Addr + W**: `0x50 << 1 | 0 = 0xA0`
- **Data**: ASCII 编码的 Verilog 代码
- **最大长度**: 4096 字节

### 2. 读取结果 (读操作)

```
[START] + [Device Addr + R] + [Len High] + [Len Low] + [Data 0] + ... + [Data N] + [STOP]
```

- **Device Addr + R**: `0x50 << 1 | 1 = 0xA1`
- **Len High/Low**: 大端序，格式化结果长度（2字节）
- **Data**: ASCII 编码的格式化后代码

## 数据格式

### 发送数据格式

原始 Verilog 代码，ASCII 编码：

```
module test (
input wire clk,
output reg data
);
...
endmodule
```

### 接收数据格式

```
[2字节长度] + [格式化代码]
```

- 长度字段：16位无符号整数，大端序
- 如果长度为 0，表示格式化还在进行中

## 时序图

### 完整通信流程

```
PC                                  FPGA
|                                    |
|---- START + ADDR(0xA0) + ACK ---->|
|                                    |
|---- Data[0] + ACK --------------->|
|---- Data[1] + ACK --------------->|
|           ...                      |
|---- Data[N] + ACK --------------->|
|---- STOP ------------------------>|
|                                    |
|         [格式化处理中...]           |
|                                    |
|---- START + ADDR(0xA1) + ACK ---->|
|                                    |
|<--- Len[15:8] + ACK --------------|
|<--- Len[7:0] + ACK ---------------|
|<--- Result[0] + ACK ---------------|
|<--- Result[1] + ACK ---------------|
|           ...                      |
|<--- Result[N] + NACK --------------|
|---- STOP ------------------------>|
|                                    |
```

## 格式化规则

FPGA 内部的格式化器按照以下规则处理代码：

### 1. 缩进规则

- **缩进大小**: 4 个空格
- **增加缩进**: `module`, `begin`, `always`, `case`, `task`, `function`, `generate`, `fork`
- **减少缩进**: `endmodule`, `end`, `endcase`, `endtask`, `endfunction`, `endgenerate`, `join`, `else`

### 2. 关键字处理

- 所有关键字转换为小写
- 关键字列表：`module`, `endmodule`, `input`, `output`, `wire`, `reg`, `always`, `begin`, `end`, `if`, `else`, `case`, `endcase`, 等

### 3. 空格规范化

- 运算符周围添加空格：`<=`, `=`, `+`, `-`, `*`, `/`, `&`, `|`, `^`
- 多个连续空格合并为单个空格
- 删除行尾空格

### 4. 注释保护

- `//` 开头的单行注释保持原样
- `/* */` 包围的多行注释保持原样

## 错误处理

### I2C 层错误

| 错误类型 | 处理方式 |
|---------|---------|
| NACK 接收 | 重试或终止通信 |
| 总线忙 | 等待后重试 |
| 超时 | 复位 I2C 总线 |

### 应用层错误

| 错误类型 | 返回值 | 处理建议 |
|---------|--------|---------|
| 代码超长 | 截断处理 | 检查代码大小 |
| 格式错误 | 原样返回 | 检查代码语法 |
| 格式化失败 | 原样返回 | 检查代码结构 |

## 示例代码

### Python 通信示例

```python
import smbus2
import time

bus = smbus2.SMBus(1)
I2C_ADDR = 0x50

# 发送代码
code = b"module test;\ninput clk;\nendmodule\n"
write = smbus2.i2c_msg.write(I2C_ADDR, code)
bus.i2c_rdwr(write)

# 等待格式化
time.sleep(0.5)

# 读取结果
read_len = smbus2.i2c_msg.read(I2C_ADDR, 2)
bus.i2c_rdwr(read_len)
data_len = int.from_bytes(bytes(read_len), 'big')

# 读取格式化后的代码
read_data = smbus2.i2c_msg.read(I2C_ADDR, data_len)
bus.i2c_rdwr(read_data)
formatted = bytes(read_data).decode('utf-8')
print(formatted)
```

## 性能指标

| 指标 | 数值 |
|-----|------|
| I2C 时钟 | 标准模式 100kHz / 快速模式 400kHz |
| 最大代码长度 | 4096 字节 |
| 格式化延迟 | < 100ms (典型) |
| 吞吐量 | 约 10KB/s @ 400kHz |

## 版本历史

| 版本 | 日期 | 说明 |
|-----|------|------|
| 1.0 | 2024-XX-XX | 初始版本 |
