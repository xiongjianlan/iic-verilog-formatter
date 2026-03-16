//============================================================================
// Verilog 代码格式化器核心模块 - 修复版
// 功能：读取 RAM 中的 ASCII 代码，按规范格式化后写回 RAM
//============================================================================

module verilog_formatter #(
    parameter DATA_DEPTH = 4096,        // 最大数据深度
    parameter MAX_LINE_LEN = 256        // 最大行长度
)(
    input  wire        clk,
    input  wire        rst_n,

    // 控制接口
    input  wire        start,           // 开始格式化
    input  wire [15:0] data_len,        // 输入数据长度
    output reg         done,            // 格式化完成
    output reg  [15:0] result_len,      // 结果数据长度

    // 输入 RAM 接口 (原始代码)
    output reg         src_rd_en,
    output reg  [11:0] src_rd_addr,
    input  wire [7:0]  src_rd_data,

    // 输出 RAM 接口 (格式化结果)
    output reg         dst_wr_en,
    output reg  [11:0] dst_wr_addr,
    output reg  [7:0]  dst_wr_data
);

    //========================================================================
    // 格式化规则配置
    //========================================================================
    localparam INDENT_SIZE    = 4;      // 缩进空格数

    //========================================================================
    // 状态机定义
    //========================================================================
    localparam IDLE           = 4'd0;
    localparam READ_CHAR      = 4'd1;
    localparam WAIT_READ      = 4'd2;
    localparam WAIT_READ2     = 4'd3;
    localparam PROCESS_LINE   = 4'd4;
    localparam WRITE_INDENT   = 4'd5;
    localparam WRITE_CONTENT  = 4'd6;
    localparam WRITE_NEWLINE  = 4'd7;
    localparam FINISH         = 4'd8;

    //========================================================================
    // 寄存器定义
    //========================================================================
    reg [3:0]  state;
    reg [15:0] src_ptr;         // 源数据指针
    reg [15:0] dst_ptr;         // 目标数据指针
    reg [15:0] bytes_remaining;

    // 行缓冲区
    reg [7:0]  line_buffer [0:MAX_LINE_LEN-1];
    reg [8:0]  line_len;
    reg [8:0]  write_idx;       // 写入索引
    reg [8:0]  content_start;   // 内容起始位置（跳过前导空格）

    // 缩进控制
    reg [7:0]  indent_level;
    reg [7:0]  indent_to_write; // 待写入的缩进数

    // 当前字符
    reg [7:0]  curr_char;

    // 关键字检测字符串
    reg [7:0]  first_token [0:15];
    reg [4:0]  first_token_len;

    // 标志
    reg is_comment_line;
    reg is_empty_line;
    reg increase_indent_next;
    reg decrease_indent_now;

    integer i;

    //========================================================================
    // 组合逻辑：检测缩进变化关键字
    //========================================================================
    wire is_begin_keyword = (first_token_len == 5 &&
                            first_token[0] == "b" &&
                            first_token[1] == "e" &&
                            first_token[2] == "g" &&
                            first_token[3] == "i" &&
                            first_token[4] == "n");

    wire is_module_keyword = (first_token_len == 6 &&
                             first_token[0] == "m" &&
                             first_token[1] == "o" &&
                             first_token[2] == "d" &&
                             first_token[3] == "u" &&
                             first_token[4] == "l" &&
                             first_token[5] == "e");

    wire is_always_keyword = (first_token_len == 6 &&
                             first_token[0] == "a" &&
                             first_token[1] == "l" &&
                             first_token[2] == "w" &&
                             first_token[3] == "a" &&
                             first_token[4] == "y" &&
                             first_token[5] == "s");

    wire is_case_keyword = (first_token_len == 4 &&
                           first_token[0] == "c" &&
                           first_token[1] == "a" &&
                           first_token[2] == "s" &&
                           first_token[3] == "e");

    wire is_task_keyword = (first_token_len == 4 &&
                           first_token[0] == "t" &&
                           first_token[1] == "a" &&
                           first_token[2] == "s" &&
                           first_token[3] == "k");

    wire is_function_keyword = (first_token_len == 8 &&
                               first_token[0] == "f" &&
                               first_token[1] == "u" &&
                               first_token[2] == "n" &&
                               first_token[3] == "c" &&
                               first_token[4] == "t" &&
                               first_token[5] == "i" &&
                               first_token[6] == "o" &&
                               first_token[7] == "n");

    wire is_generate_keyword = (first_token_len == 8 &&
                               first_token[0] == "g" &&
                               first_token[1] == "e" &&
                               first_token[2] == "n" &&
                               first_token[3] == "e" &&
                               first_token[4] == "r" &&
                               first_token[5] == "a" &&
                               first_token[6] == "t" &&
                               first_token[7] == "e");

    wire is_fork_keyword = (first_token_len == 4 &&
                           first_token[0] == "f" &&
                           first_token[1] == "o" &&
                           first_token[2] == "r" &&
                           first_token[3] == "k");

    // 减少缩进的关键字
    wire is_end_keyword = (first_token_len == 3 &&
                          first_token[0] == "e" &&
                          first_token[1] == "n" &&
                          first_token[2] == "d");

    wire is_endmodule_keyword = (first_token_len == 9 &&
                                first_token[0] == "e" &&
                                first_token[1] == "n" &&
                                first_token[2] == "d" &&
                                first_token[3] == "m" &&
                                first_token[4] == "o" &&
                                first_token[5] == "d" &&
                                first_token[6] == "u" &&
                                first_token[7] == "l" &&
                                first_token[8] == "e");

    wire is_endcase_keyword = (first_token_len == 7 &&
                              first_token[0] == "e" &&
                              first_token[1] == "n" &&
                              first_token[2] == "d" &&
                              first_token[3] == "c" &&
                              first_token[4] == "a" &&
                              first_token[5] == "s" &&
                              first_token[6] == "e");

    wire is_endtask_keyword = (first_token_len == 7 &&
                              first_token[0] == "e" &&
                              first_token[1] == "n" &&
                              first_token[2] == "d" &&
                              first_token[3] == "t" &&
                              first_token[4] == "a" &&
                              first_token[5] == "s" &&
                              first_token[6] == "k");

    wire is_endfunction_keyword = (first_token_len == 11 &&
                                  first_token[0] == "e" &&
                                  first_token[1] == "n" &&
                                  first_token[2] == "d" &&
                                  first_token[3] == "f" &&
                                  first_token[4] == "u" &&
                                  first_token[5] == "n" &&
                                  first_token[6] == "c" &&
                                  first_token[7] == "t" &&
                                  first_token[8] == "i" &&
                                  first_token[9] == "o" &&
                                  first_token[10] == "n");

    wire is_endgenerate_keyword = (first_token_len == 11 &&
                                  first_token[0] == "e" &&
                                  first_token[1] == "n" &&
                                  first_token[2] == "d" &&
                                  first_token[3] == "g" &&
                                  first_token[4] == "e" &&
                                  first_token[5] == "n" &&
                                  first_token[6] == "e" &&
                                  first_token[7] == "r" &&
                                  first_token[8] == "a" &&
                                  first_token[9] == "t" &&
                                  first_token[10] == "e");

    wire is_join_keyword = (first_token_len == 4 &&
                           first_token[0] == "j" &&
                           first_token[1] == "o" &&
                           first_token[2] == "i" &&
                           first_token[3] == "n");

    wire is_else_keyword = (first_token_len == 4 &&
                           first_token[0] == "e" &&
                           first_token[1] == "l" &&
                           first_token[2] == "s" &&
                           first_token[3] == "e");

    wire increase_indent = is_begin_keyword || is_module_keyword || is_always_keyword ||
                          is_case_keyword || is_task_keyword || is_function_keyword ||
                          is_generate_keyword || is_fork_keyword;

    wire decrease_indent = is_end_keyword || is_endmodule_keyword || is_endcase_keyword ||
                          is_endtask_keyword || is_endfunction_keyword || is_endgenerate_keyword ||
                          is_join_keyword || is_else_keyword;

    //========================================================================
    // 主状态机
    //========================================================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state           <= IDLE;
            src_ptr         <= 16'd0;
            dst_ptr         <= 16'd0;
            bytes_remaining <= 16'd0;
            line_len        <= 9'd0;
            write_idx       <= 9'd0;
            content_start   <= 9'd0;
            indent_level    <= 8'd0;
            indent_to_write <= 8'd0;
            curr_char       <= 8'd0;
            first_token_len <= 5'd0;
            is_comment_line <= 1'b0;
            is_empty_line   <= 1'b0;
            increase_indent_next <= 1'b0;
            decrease_indent_now  <= 1'b0;
            done            <= 1'b0;
            result_len      <= 16'd0;
            src_rd_en       <= 1'b0;
            src_rd_addr     <= 12'd0;
            dst_wr_en       <= 1'b0;
            dst_wr_addr     <= 12'd0;
            dst_wr_data     <= 8'd0;

            for (i = 0; i < MAX_LINE_LEN; i = i + 1) begin
                line_buffer[i] <= 8'd0;
            end
            for (i = 0; i < 16; i = i + 1) begin
                first_token[i] <= 8'd0;
            end
        end else begin
            // 默认信号
            src_rd_en <= 1'b0;
            dst_wr_en <= 1'b0;
            done      <= 1'b0;

            case (state)
                IDLE: begin
                    if (start) begin
                        state           <= READ_CHAR;
                        src_ptr         <= 16'd0;
                        dst_ptr         <= 16'd0;
                        bytes_remaining <= data_len;
                        line_len        <= 9'd0;
                        indent_level    <= 8'd0;
                        first_token_len <= 5'd0;
                        is_comment_line <= 1'b0;
                        is_empty_line   <= 1'b0;
                        increase_indent_next <= 1'b0;
                        decrease_indent_now  <= 1'b0;
                        done            <= 1'b0;
                        result_len      <= 16'd0;

                        for (i = 0; i < MAX_LINE_LEN; i = i + 1) begin
                            line_buffer[i] <= 8'd0;
                        end
                        for (i = 0; i < 16; i = i + 1) begin
                            first_token[i] <= 8'd0;
                        end
                    end
                end

                READ_CHAR: begin
                    if (bytes_remaining == 0) begin
                        // 所有数据读取完成
                        if (line_len > 0) begin
                            state <= PROCESS_LINE;
                        end else begin
                            state <= FINISH;
                        end
                    end else begin
                        // 发起读请求
                        src_rd_en   <= 1'b1;
                        src_rd_addr <= src_ptr[11:0];
                        state       <= WAIT_READ;
                    end
                end

                WAIT_READ: begin
                    // 保持读使能，等待数据返回
                    src_rd_en <= 1'b1;
                    state <= WAIT_READ2;
                end

                WAIT_READ2: begin
                    // 保持读使能，数据现在可用
                    src_rd_en <= 1'b1;
                    curr_char <= src_rd_data;
                    src_ptr   <= src_ptr + 1'b1;
                    bytes_remaining <= bytes_remaining - 1'b1;

                    // 检测行结束
                    if (src_rd_data == 8'h0A) begin  // LF (\n)
                        state <= PROCESS_LINE;
                    end else if (src_rd_data != 8'h0D) begin  // 忽略 CR
                        // 存储到行缓冲区
                        if (line_len < MAX_LINE_LEN) begin
                            line_buffer[line_len] <= src_rd_data;
                            line_len <= line_len + 1'b1;

                            // 收集第一个 token
                            if (first_token_len < 16) begin
                                if (src_rd_data != " " && src_rd_data != "(" &&
                                    src_rd_data != ";" && src_rd_data != 8'h0A &&
                                    src_rd_data != 8'h09) begin
                                    first_token[first_token_len] <= src_rd_data;
                                    first_token_len <= first_token_len + 1'b1;
                                end else if (first_token_len > 0) begin
                                    // token 结束，不再收集
                                end
                            end
                        end
                        state <= READ_CHAR;
                    end else begin
                        state <= READ_CHAR;
                    end
                end

                PROCESS_LINE: begin
                    // 检查是否是注释行或空行
                    if (line_len >= 2 && line_buffer[0] == "/" && line_buffer[1] == "/") begin
                        is_comment_line <= 1'b1;
                        is_empty_line   <= 1'b0;
                    end else if (line_len == 0) begin
                        is_comment_line <= 1'b0;
                        is_empty_line   <= 1'b1;
                    end else begin
                        is_comment_line <= 1'b0;
                        is_empty_line   <= 1'b0;
                    end

                    // 计算内容起始位置（跳过前导空格）
                    content_start <= 9'd0;

                    // 处理缩进变化
                    decrease_indent_now <= decrease_indent;
                    increase_indent_next <= increase_indent;

                    // 准备写入
                    write_idx <= 9'd0;
                    indent_to_write <= indent_level * INDENT_SIZE;

                    // 下一状态根据行类型决定
                    state <= WRITE_INDENT;
                end

                WRITE_INDENT: begin
                    if (decrease_indent_now && indent_level > 0) begin
                        // 应用减少缩进
                        indent_level <= indent_level - 1'b1;
                        indent_to_write <= (indent_level - 1'b1) * INDENT_SIZE;
                    end

                    if (indent_to_write > 0) begin
                        dst_wr_en   <= 1'b1;
                        dst_wr_addr <= dst_ptr[11:0];
                        dst_wr_data <= " ";
                        dst_ptr     <= dst_ptr + 1'b1;
                        indent_to_write <= indent_to_write - 1'b1;
                    end else begin
                        // 缩进写入完成，开始写入内容
                        write_idx <= content_start;
                        // 注释行或空行跳过缩进直接处理
                        if (is_comment_line || is_empty_line) begin
                            state <= WRITE_CONTENT;
                        end else begin
                            state <= WRITE_CONTENT;
                        end
                    end
                end

                WRITE_CONTENT: begin
                    if (is_comment_line) begin
                        // 写入注释行内容
                        if (write_idx < line_len) begin
                            dst_wr_en   <= 1'b1;
                            dst_wr_addr <= dst_ptr[11:0];
                            dst_wr_data <= line_buffer[write_idx];
                            dst_ptr     <= dst_ptr + 1'b1;
                            write_idx   <= write_idx + 1'b1;
                        end else begin
                            // 注释行写入完成，写入换行
                            state <= WRITE_NEWLINE;
                        end
                    end else if (is_empty_line) begin
                        // 空行直接写入换行
                        state <= WRITE_NEWLINE;
                    end else begin
                        // 写入代码内容
                        // 只在开始位置跳过前导空格
                        if (write_idx < line_len) begin
                            if (line_buffer[write_idx] == " " && write_idx == content_start) begin
                                // 跳过前导空格
                                write_idx <= write_idx + 1'b1;
                                content_start <= content_start + 1'b1;
                            end else begin
                                // 写入字符（包括中间的空格）
                                dst_wr_en   <= 1'b1;
                                dst_wr_addr <= dst_ptr[11:0];
                                dst_wr_data <= line_buffer[write_idx];
                                dst_ptr     <= dst_ptr + 1'b1;
                                write_idx   <= write_idx + 1'b1;
                            end
                        end else begin
                            // 内容写入完成，写入换行
                            state <= WRITE_NEWLINE;
                        end
                    end
                end

                WRITE_NEWLINE: begin
                    dst_wr_en   <= 1'b1;
                    dst_wr_addr <= dst_ptr[11:0];
                    dst_wr_data <= 8'h0A;  // 换行符
                    dst_ptr     <= dst_ptr + 1'b1;

                    // 应用增加缩进
                    if (increase_indent_next) begin
                        indent_level <= indent_level + 1'b1;
                    end

                    // 清空行缓冲区
                    line_len <= 9'd0;
                    first_token_len <= 5'd0;
                    is_comment_line <= 1'b0;
                    is_empty_line   <= 1'b0;
                    increase_indent_next <= 1'b0;
                    decrease_indent_now  <= 1'b0;

                    for (i = 0; i < MAX_LINE_LEN; i = i + 1) begin
                        line_buffer[i] <= 8'd0;
                    end
                    for (i = 0; i < 16; i = i + 1) begin
                        first_token[i] <= 8'd0;
                    end

                    // 继续读取或结束
                    // 注意：line_len 在这里被清零，所以直接检查 bytes_remaining
                    if (bytes_remaining == 0) begin
                        state <= FINISH;
                    end else begin
                        state <= READ_CHAR;
                    end
                end

                FINISH: begin
                    done       <= 1'b1;
                    result_len <= dst_ptr;
                    state      <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule
