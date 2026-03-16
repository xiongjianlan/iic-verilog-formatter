#!/usr/bin/env python3
"""
PC 端 I2C Verilog 格式化工具
通过 I2C 接口与 FPGA 通信，发送代码并接收格式化结果
"""

import smbus2
import time
import argparse
import sys
from typing import Optional


class I2CFormatterClient:
    """I2C Verilog 格式化器客户端"""

    # I2C 设备默认地址
    DEFAULT_I2C_ADDR = 0x50
    # 最大数据包大小
    MAX_PACKET_SIZE = 32
    # 最大代码大小 (4KB)
    MAX_CODE_SIZE = 4096

    def __init__(self, bus_number: int = 1, i2c_addr: int = DEFAULT_I2C_ADDR):
        """
        初始化 I2C 客户端

        Args:
            bus_number: I2C 总线号 (通常是 1)
            i2c_addr: I2C 设备地址
        """
        self.bus_number = bus_number
        self.i2c_addr = i2c_addr
        self.bus = None

    def connect(self) -> bool:
        """连接 I2C 总线"""
        try:
            self.bus = smbus2.SMBus(self.bus_number)
            print(f"✓ 已连接到 I2C 总线 {self.bus_number}")
            return True
        except Exception as e:
            print(f"✗ 连接 I2C 总线失败: {e}")
            return False

    def disconnect(self):
        """断开 I2C 连接"""
        if self.bus:
            self.bus.close()
            self.bus = None
            print("✓ 已断开 I2C 连接")

    def write_code(self, code: str) -> bool:
        """
        发送 Verilog 代码到 FPGA

        Args:
            code: Verilog 代码字符串

        Returns:
            是否成功
        """
        if not self.bus:
            print("✗ I2C 未连接")
            return False

        # 转换为字节
        data = code.encode('utf-8')

        if len(data) > self.MAX_CODE_SIZE:
            print(f"✗ 代码太大 ({len(data)} 字节)，最大支持 {self.MAX_CODE_SIZE} 字节")
            return False

        print(f"→ 发送代码 ({len(data)} 字节)...")

        # 分块发送
        offset = 0
        chunk_size = self.MAX_PACKET_SIZE

        while offset < len(data):
            chunk = data[offset:offset + chunk_size]

            try:
                # 使用 i2c_rdwr 进行块写入
                write = smbus2.i2c_msg.write(self.i2c_addr, chunk)
                self.bus.i2c_rdwr(write)
            except Exception as e:
                print(f"✗ 发送数据失败 (偏移 {offset}): {e}")
                return False

            offset += len(chunk)
            print(f"  已发送 {offset}/{len(data)} 字节", end='\r')

        print(f"\n✓ 代码发送完成")
        return True

    def read_formatted_code(self, timeout: int = 10) -> Optional[str]:
        """
        从 FPGA 读取格式化后的代码

        Args:
            timeout: 超时时间（秒）

        Returns:
            格式化后的代码，失败返回 None
        """
        if not self.bus:
            print("✗ I2C 未连接")
            return None

        print("→ 等待格式化完成...")

        # 等待格式化完成
        start_time = time.time()
        result_data = bytearray()

        while time.time() - start_time < timeout:
            try:
                # 尝试读取数据
                # 首先读取 2 字节长度信息
                read_len = smbus2.i2c_msg.read(self.i2c_addr, 2)
                self.bus.i2c_rdwr(read_len)
                data_len = int.from_bytes(bytes(read_len), 'big')

                if data_len > 0 and data_len <= self.MAX_CODE_SIZE:
                    print(f"✓ 格式化完成，结果长度: {data_len} 字节")

                    # 读取格式化结果
                    remaining = data_len
                    while remaining > 0:
                        chunk_size = min(self.MAX_PACKET_SIZE, remaining)
                        read_chunk = smbus2.i2c_msg.read(self.i2c_addr, chunk_size)
                        self.bus.i2c_rdwr(read_chunk)
                        result_data.extend(bytes(read_chunk))
                        remaining -= chunk_size
                        print(f"  已接收 {len(result_data)}/{data_len} 字节", end='\r')

                    print(f"\n✓ 接收完成")
                    return result_data.decode('utf-8')

                elif data_len == 0:
                    # 格式化还在进行中
                    time.sleep(0.1)
                    continue
                else:
                    print(f"✗ 无效的数据长度: {data_len}")
                    return None

            except Exception as e:
                # 可能是 NACK，表示还在处理中
                time.sleep(0.1)
                continue

        print("✗ 等待格式化超时")
        return None

    def format_code(self, code: str, timeout: int = 10) -> Optional[str]:
        """
        完整的格式化流程：发送代码并接收结果

        Args:
            code: 原始 Verilog 代码
            timeout: 超时时间（秒）

        Returns:
            格式化后的代码
        """
        # 发送代码
        if not self.write_code(code):
            return None

        # 发送停止信号（空写入）
        try:
            self.bus.write_byte(self.i2c_addr, 0)
        except:
            pass

        # 读取结果
        return self.read_formatted_code(timeout)


def format_file(client: I2CFormatterClient, input_file: str, output_file: str) -> bool:
    """格式化文件"""
    try:
        with open(input_file, 'r', encoding='utf-8') as f:
            code = f.read()
    except Exception as e:
        print(f"✗ 无法读取文件 {input_file}: {e}")
        return False

    print(f"\n{'='*60}")
    print(f"文件: {input_file}")
    print(f"原始大小: {len(code)} 字符")
    print(f"{'='*60}\n")

    # 格式化
    formatted = client.format_code(code)

    if formatted is None:
        print("✗ 格式化失败")
        return False

    print(f"\n格式化后大小: {len(formatted)} 字符")

    # 保存结果
    try:
        with open(output_file, 'w', encoding='utf-8') as f:
            f.write(formatted)
        print(f"✓ 已保存到: {output_file}")
        return True
    except Exception as e:
        print(f"✗ 保存文件失败: {e}")
        return False


def interactive_mode(client: I2CFormatterClient):
    """交互模式"""
    print("\n" + "="*60)
    print("I2C Verilog 格式化器 - 交互模式")
    print("="*60)
    print("输入 Verilog 代码 (输入 'END' 单独一行结束):")
    print("-"*60)

    lines = []
    while True:
        try:
            line = input()
            if line.strip() == 'END':
                break
            lines.append(line)
        except EOFError:
            break

    code = '\n'.join(lines)

    if not code.strip():
        print("✗ 没有输入代码")
        return

    print(f"\n→ 发送 {len(code)} 字符...")

    formatted = client.format_code(code)

    if formatted:
        print("\n" + "="*60)
        print("格式化结果:")
        print("="*60)
        print(formatted)
        print("="*60)
    else:
        print("✗ 格式化失败")


def main():
    parser = argparse.ArgumentParser(
        description='I2C Verilog 代码格式化工具 (PC 端)',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog='''
示例:
  # 格式化单个文件
  python i2c_formatter_tool.py -i input.v -o output.v

  # 交互模式
  python i2c_formatter_tool.py --interactive

  # 指定 I2C 地址
  python i2c_formatter_tool.py -a 0x51 -i input.v -o output.v
        '''
    )

    parser.add_argument('-b', '--bus', type=int, default=1,
                       help='I2C 总线号 (默认: 1)')
    parser.add_argument('-a', '--addr', type=lambda x: int(x, 0), default=0x50,
                       help='I2C 设备地址 (默认: 0x50)')
    parser.add_argument('-i', '--input', help='输入 Verilog 文件')
    parser.add_argument('-o', '--output', help='输出文件')
    parser.add_argument('--interactive', action='store_true',
                       help='交互模式')
    parser.add_argument('-t', '--timeout', type=int, default=10,
                       help='超时时间 (秒, 默认: 10)')

    args = parser.parse_args()

    # 创建客户端
    client = I2CFormatterClient(bus_number=args.bus, i2c_addr=args.addr)

    # 连接 I2C
    if not client.connect():
        sys.exit(1)

    try:
        if args.interactive:
            interactive_mode(client)
        elif args.input:
            output_file = args.output or args.input.replace('.v', '_formatted.v')
            success = format_file(client, args.input, output_file)
            sys.exit(0 if success else 1)
        else:
            parser.print_help()
    finally:
        client.disconnect()


if __name__ == '__main__':
    main()
