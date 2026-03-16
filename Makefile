#============================================================================
# I2C Verilog 格式化器工程 Makefile
#============================================================================

# 工具配置
IVERILOG = iverilog
VVP = vvp
GTKWAVE = gtkwave

# 目录
RTL_DIR = rtl
SIM_DIR = sim
PC_DIR = pc_tool
BUILD_DIR = build

# 源文件
RTL_SRCS = $(RTL_DIR)/dual_port_ram.v \
           $(RTL_DIR)/verilog_formatter.v \
           $(RTL_DIR)/i2c_slave.v \
           $(RTL_DIR)/top_i2c_formatter.v

# 正式仿真测试文件
SIM_SRCS = $(SIM_DIR)/tb_i2c_formatter.v
SIM_FULL_SRCS = $(SIM_DIR)/tb_i2c_formatter_full.v
SIM_FORMAT_SRCS = $(SIM_DIR)/tb_format_verify.v

# 调试测试文件 (在 sim/debug/ 目录)
DEBUG_SRCS = $(wildcard $(SIM_DIR)/debug/tb_*.v)

# 目标
TOP = top_i2c_formatter
TB = tb_i2c_formatter
TB_FULL = tb_i2c_formatter_full

#============================================================================
# 默认目标
#============================================================================
.PHONY: all sim wave clean help pc_tool

all: $(BUILD_DIR)/$(TOP).vvp

#============================================================================
# 编译规则
#============================================================================
$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

$(BUILD_DIR)/$(TOP).vvp: $(RTL_SRCS) $(BUILD_DIR)
	$(IVERILOG) -o $@ $(RTL_SRCS)
	@echo "✓ 编译完成: $@"

$(BUILD_DIR)/$(TB).vvp: $(RTL_SRCS) $(SIM_SRCS) $(BUILD_DIR)
	$(IVERILOG) -o $@ $(RTL_SRCS) $(SIM_SRCS)
	@echo "✓ 编译完成: $@"

$(BUILD_DIR)/$(TB_FULL).vvp: $(RTL_SRCS) $(SIM_FULL_SRCS) $(BUILD_DIR)
	$(IVERILOG) -o $@ $(RTL_SRCS) $(SIM_FULL_SRCS)
	@echo "✓ 编译完成: $@"

$(BUILD_DIR)/tb_format_verify.vvp: $(RTL_SRCS) $(SIM_FORMAT_SRCS) $(BUILD_DIR)
	$(IVERILOG) -o $@ $(RTL_SRCS) $(SIM_FORMAT_SRCS)
	@echo "✓ 编译完成: $@"

# 调试测试编译规则 (自动编译所有调试测试)
$(BUILD_DIR)/tb_debug_%.vvp: $(RTL_SRCS) $(SIM_DIR)/debug/tb_debug_%.v $(BUILD_DIR)
	$(IVERILOG) -o $@ $(RTL_SRCS) $(SIM_DIR)/debug/tb_debug_%.v
	@echo "✓ 编译完成: $@

#============================================================================
# 仿真规则
#============================================================================
sim: $(BUILD_DIR)/$(TB).vvp
	cd $(BUILD_DIR) && $(VVP) $(TB).vvp
	@echo "✓ 仿真完成"

sim-full: $(BUILD_DIR)/$(TB_FULL).vvp
	cd $(BUILD_DIR) && $(VVP) $(TB_FULL).vvp
	@echo "✓ 完整测试完成"

sim-format: $(BUILD_DIR)/tb_format_verify.vvp
	cd $(BUILD_DIR) && $(VVP) tb_format_verify.vvp
	@echo "✓ 格式化验证完成"

wave: sim
	$(GTKWAVE) $(BUILD_DIR)/$(TB).vcd &
	@echo "✓ 打开波形查看器"

wave-full: sim-full
	$(GTKWAVE) $(BUILD_DIR)/$(TB_FULL).vcd &
	@echo "✓ 打开完整测试波形"

wave-format: sim-format
	$(GTKWAVE) $(BUILD_DIR)/tb_format_verify.vcd &
	@echo "✓ 打开格式化测试波形"

#============================================================================
# PC 工具
#============================================================================
pc_tool:
	@echo "安装 PC 端工具依赖..."
	pip3 install smbus2
	@echo "✓ PC 工具准备完成"
	@echo "使用方法: python3 $(PC_DIR)/i2c_formatter_tool.py --help"

#============================================================================
# 清理
#============================================================================
clean:
	rm -rf $(BUILD_DIR)
	@echo "✓ 清理完成"

#============================================================================
# 调试测试规则
#============================================================================
.PHONY: debug list-debug

list-debug:
	@echo "可用调试测试:"
	@ls -1 $(SIM_DIR)/debug/tb_*.v 2>/dev/null | sed 's|.*/tb_\(.*\)\.v|  - tb_\1|'

debug: $(patsubst $(SIM_DIR)/debug/tb_%.v,$(BUILD_DIR)/tb_debug_%.vvp,$(DEBUG_SRCS))
	@echo "✓ 所有调试测试编译完成"

#============================================================================
# 帮助
#============================================================================
help:
	@echo "I2C Verilog 格式化器工程"
	@echo "========================"
	@echo ""
	@echo "编译目标:"
	@echo "  make all       - 编译 RTL 代码"
	@echo "  make clean     - 清理生成文件"
	@echo ""
	@echo "正式仿真测试:"
	@echo "  make sim       - 运行基础仿真测试 (tb_i2c_formatter)"
	@echo "  make sim-full  - 运行完整功能测试 (tb_i2c_formatter_full)"
	@echo "  make sim-format- 运行格式化验证测试 (tb_format_verify)"
	@echo "  make wave      - 运行仿真并打开波形"
	@echo "  make wave-full - 打开完整测试波形"
	@echo "  make wave-format - 打开格式化测试波形"
	@echo ""
	@echo "调试测试:"
	@echo "  make list-debug - 列出所有调试测试"
	@echo "  make debug      - 编译所有调试测试"
	@echo ""
	@echo "PC 工具:"
	@echo "  make pc_tool   - 安装 PC 端工具依赖"
	@echo ""
	@echo "文件结构:"
	@echo "  rtl/          - Verilog RTL 源码"
	@echo "  sim/          - 正式仿真测试平台"
	@echo "  sim/debug/    - 调试测试文件"
	@echo "  pc_tool/      - PC 端 Python 工具"
	@echo "  build/        - 编译输出目录"
