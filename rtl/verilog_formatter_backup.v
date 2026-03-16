//============================================================================
// Verilog 代码格式化器核心模块
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
    localparam KEYWORD_LOWER  = 1'b1;   // 关键字小写

    //========================================================================
    // 状态机定义
    //========================================================================
    localparam IDLE           = 5'd0;
    localparam READ_CHAR      = 5'd1;
    localparam PARSE_TOKEN    = 5'd2;
    localparam PROCESS_LINE   = 5'd3;
    localparam WRITE_OUTPUT   = 5'd4;
    localparam FLUSH_BUFFER   = 5'd5;
    localparam FINISH         = 5'd6;

    // 子状态：行处理
    localparam LINE_START     = 3'd0;
    localparam LINE_BODY      = 3'd1;
    localparam LINE_END       = 3'd2;

    //========================================================================
    // 寄存器定义
    //========================================================================
    reg [4:0]  state;
    reg [2:0]  line_state;
    reg [15:0] src_ptr;         // 源数据指针
    reg [15:0] dst_ptr;         // 目标数据指针
    reg [15:0] bytes_processed;

    // 行缓冲区
    reg [7:0]  line_buffer [0:MAX_LINE_LEN-1];
    reg [7:0]  out_buffer  [0:MAX_LINE_LEN-1];
    reg [8:0]  line_len;
    reg [8:0]  out_len;

    // 缩进控制
    reg [7:0]  indent_level;
    reg [7:0]  next_indent;

    // 当前字符和 Token
    reg [7:0]  curr_char;
    reg [7:0]  token_buffer [0:31];
    reg [5:0]  token_len;

    // 特殊状态标志
    reg in_comment;             // 在多行注释中
    reg in_string;              // 在字符串中
    reg in_module_decl;         // 在模块声明中
    reg in_port_list;           // 在端口列表中

    //========================================================================
    // 关键字检测 (小写)
    //========================================================================
    function automatic is_keyword;
        input [255:0] str;  // 8字符 x 32
        input [5:0]   len;
        begin
            is_keyword = 1'b0;
            case (len)
                6'd5: begin
                    if (str[39:0] == "begin") is_keyword = 1'b1;
                    if (str[39:0] == "input") is_keyword = 1'b1;
                    if (str[39:0] == "wire ") is_keyword = 1'b1;  // wire with space
                end
                6'd3: begin
                    if (str[23:0] == "reg") is_keyword = 1'b1;
                    if (str[23:0] == "end") is_keyword = 1'b1;
                    if (str[23:0] == "for") is_keyword = 1'b1;
                end
                6'd6: begin
                    if (str[47:0] == "module") is_keyword = 1'b1;
                    if (str[47:0] == "output") is_keyword = 1'b1;
                    if (str[47:0] == "always") is_keyword = 1'b1;
                    if (str[47:0] == "assign") is_keyword = 1'b1;
                end
                6'd8: begin
                    if (str[63:0] == "endmodule") is_keyword = 1'b1;
                    if (str[63:0] == "endcase  ") is_keyword = 1'b1;
                end
                6'd4: begin
                    if (str[31:0] == "case") is_keyword = 1'b1;
                    if (str[31:0] == "else") is_keyword = 1'b1;
                    if (str[31:0] == "task") is_keyword = 1'b1;
                end
                6'd7: begin
                    if (str[55:0] == "endtask") is_keyword = 1'b1;
                end
                6'd9: begin
                    if (str[71:0] == "endfunction") is_keyword = 1'b1;
                end
                6'd8: begin
                    if (str[63:0] == "function") is_keyword = 1'b1;
                    if (str[63:0] == "generate") is_keyword = 1'b1;
                end
                6'd11: begin
                    if (str[87:0] == "endgenerate") is_keyword = 1'b1;
                end
            endcase
        end
    endfunction

    //========================================================================
    // 缩进变化检测
    //========================================================================
    function automatic [1:0] check_indent_change;
        input [255:0] str;
        input [5:0]   len;
        begin
            check_indent_change = 2'b00;  // [1]=decrease, [0]=increase

            // 增加缩进的关键字
            if (len == 6'd5 && str[39:0] == "begin") check_indent_change[0] = 1'b1;
            if (len == 6'd6 && str[47:0] == "module") check_indent_change[0] = 1'b1;
            if (len == 6'd6 && str[47:0] == "always") check_indent_change[0] = 1'b1;
            if (len == 6'd4 && str[31:0] == "case") check_indent_change[0] = 1'b1;
            if (len == 6'd6 && str[47:0] == "task  ") check_indent_change[0] = 1'b1;
            if (len == 6'd8 && str[63:0] == "function") check_indent_change[0] = 1'b1;
            if (len == 6'd8 && str[63:0] == "generate") check_indent_change[0] = 1'b1;
            if (len == 6'd3 && str[23:0] == "fork") check_indent_change[0] = 1'b1;

            // 减少缩进的关键字
            if (len == 6'd3 && str[23:0] == "end") check_indent_change[1] = 1'b1;
            if (len == 6'd8 && str[63:0] == "endmodule") check_indent_change[1] = 1'b1;
            if (len == 6'd8 && str[63:0] == "endcase  ") check_indent_change[1] = 1'b1;
            if (len == 6'd7 && str[55:0] == "endtask") check_indent_change[1] = 1'b1;
            if (len == 6'd11 && str[87:0] == "endfunction") check_indent_change[1] = 1'b1;
            if (len == 6'd11 && str[87:0] == "endgenerate") check_indent_change[1] = 1'b1;
            if (len == 6'd4 && str[31:0] == "join") check_indent_change[1] = 1'b1;
            if (len == 6'd4 && str[31:0] == "else") check_indent_change[1] = 1'b1;
        end
    endfunction

    //========================================================================
    // 主状态机
    //========================================================================
    integer i;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state          <= IDLE;
            line_state     <= LINE_START;
            src_rd_en      <= 1'b0;
            src_rd_addr    <= 12'd0;
            dst_wr_en      <= 1'b0;
            dst_wr_addr    <= 12'd0;
            dst_wr_data    <= 8'd0;
            done           <= 1'b0;
            result_len     <= 16'd0;
            src_ptr        <= 16'd0;
            dst_ptr        <= 16'd0;
            bytes_processed <= 16'd0;
            line_len       <= 9'd0;
            out_len        <= 9'd0;
            indent_level   <= 8'd0;
            next_indent    <= 8'd0;
            curr_char      <= 8'd0;
            token_len      <= 6'd0;
            in_comment     <= 1'b0;
            in_string      <= 1'b0;
            in_module_decl <= 1'b0;
            in_port_list   <= 1'b0;

            for (i = 0; i < MAX_LINE_LEN; i = i + 1) begin
                line_buffer[i] <= 8'd0;
                out_buffer[i]  <= 8'd0;
            end
            for (i = 0; i < 32; i = i + 1) begin
                token_buffer[i] <= 8'd0;
            end
        end else begin
            // 默认信号
            src_rd_en <= 1'b0;
            dst_wr_en <= 1'b0;
            done      <= 1'b0;

            case (state)
                IDLE: begin
                    if (start) begin
                        state          <= READ_CHAR;
                        src_ptr        <= 16'd0;
                        dst_ptr        <= 16'd0;
                        bytes_processed <= 16'd0;
                        line_len       <= 9'd0;
                        indent_level   <= 8'd0;
                        next_indent    <= 8'd0;
                        in_comment     <= 1'b0;
                        in_string      <= 1'b0;
                        in_module_decl <= 1'b0;
                        in_port_list   <= 1'b0;
                    end
                end

                READ_CHAR: begin
                    if (bytes_processed >= data_len) begin
                        // 所有数据读取完成
                        if (line_len > 0) begin
                            state <= PROCESS_LINE;
                        end else begin
                            state <= FINISH;
                        end
                    end else begin
                        // 读取下一个字符
                        src_rd_en   <= 1'b1;
                        src_rd_addr <= src_ptr[11:0];
                        src_ptr     <= src_ptr + 1'b1;
                        state       <= PARSE_TOKEN;
                    end
                end

                PARSE_TOKEN: begin
                    curr_char <= src_rd_data;

                    // 检测多行注释
                    if (!in_string) begin
                        if (!in_comment && curr_char == "*" && src_rd_data == "/") begin
                            in_comment <= 1'b0;
                        end else if (!in_comment && curr_char == "/" && src_rd_data == "*") begin
                            in_comment <= 1'b1;
                        end
                    end

                    // 检测字符串
                    if (!in_comment && src_rd_data == "\"" && curr_char != "\\") begin
                        in_string <= ~in_string;
                    end

                    // 检测行结束
                    if (src_rd_data == 8'h0A) begin  // LF (\n)
                        if (line_len > 0 || !in_comment) begin
                            state <= PROCESS_LINE;
                        end else begin
                            state <= READ_CHAR;
                        end
                        bytes_processed <= bytes_processed + 1'b1;
                    end else if (src_rd_data == 8'h0D) begin  // CR (\r)，忽略
                        bytes_processed <= bytes_processed + 1'b1;
                        state <= READ_CHAR;
                    end else begin
                        // 存储到行缓冲区
                        if (line_len < MAX_LINE_LEN) begin
                            line_buffer[line_len] <= src_rd_data;
                            line_len <= line_len + 1'b1;
                        end
                        bytes_processed <= bytes_processed + 1'b1;
                        state <= READ_CHAR;
                    end
                end

                PROCESS_LINE: begin
                    case (line_state)
                        LINE_START: begin
                            out_len <= 9'd0;

                            // 检查空行
                            if (line_len == 0) begin
                                // 输出空行
                                out_buffer[0] <= 8'h0A;  // \n
                                out_len <= 9'd1;
                                state <= WRITE_OUTPUT;
                            end else begin
                                // 检查是否是注释行
                                if (line_buffer[0] == "/" && line_buffer[1] == "/") begin
                                    // 复制整行（包括注释）
                                    for (i = 0; i < line_len && i < MAX_LINE_LEN; i = i + 1) begin
                                        out_buffer[i] <= line_buffer[i];
                                    end
                                    out_buffer[line_len] <= 8'h0A;
                                    out_len <= line_len + 1'b1;
                                    state <= WRITE_OUTPUT;
                                end else begin
                                    // 正常代码行，需要解析 Token
                                    line_state <= LINE_BODY;
                                end
                            end
                        end

                        LINE_BODY: begin
                            // 简化的 Token 解析和格式化
                            // 这里实现基本的缩进和空格处理

                            // 添加缩进
                            if (indent_level > 0) begin
                                for (i = 0; i < indent_level * INDENT_SIZE && i < 32; i = i + 1) begin
                                    out_buffer[i] <= " ";
                                end
                                out_len <= indent_level * INDENT_SIZE;
                            end

                            // 复制行内容（简化版：直接复制并规范化空格）
                            begin : copy_line
                                reg [8:0] src_idx;
                                reg [8:0] dst_idx;
                                reg [7:0] last_char;

                                src_idx = 0;
                                dst_idx = out_len;
                                last_char = 8'd0;

                                // 跳过前导空格
                                while (src_idx < line_len && line_buffer[src_idx] == " ") begin
                                    src_idx = src_idx + 1'b1;
                                end

                                // 复制内容，规范化空格
                                while (src_idx < line_len) begin
                                    if (line_buffer[src_idx] == " ") begin
                                        // 空格处理：只保留一个，但不在行首
                                        if (last_char != " " && dst_idx > out_len) begin
                                            out_buffer[dst_idx] <= " ";
                                            dst_idx = dst_idx + 1'b1;
                                            last_char = " ";
                                        end
                                    end else begin
                                        out_buffer[dst_idx] <= line_buffer[src_idx];
                                        dst_idx = dst_idx + 1'b1;
                                        last_char = line_buffer[src_idx];
                                    end
                                    src_idx = src_idx + 1'b1;
                                end

                                out_len <= dst_idx;
                            end

                            // 添加换行
                            out_buffer[out_len] <= 8'h0A;
                            out_len <= out_len + 1'b1;

                            // 检测缩进变化（简化版）
                            begin : check_keywords
                                reg [255:0] temp_token;
                                reg [5:0]   temp_len;
                                reg [1:0]   indent_chg;

                                // 提取第一个 token
                                temp_len = 0;
                                for (i = 0; i < 32 && i < line_len; i = i + 1) begin
                                    if (line_buffer[i] == " " || line_buffer[i] == "(" ||
                                        line_buffer[i] == ";" || line_buffer[i] == 8'h0A) begin
                                        // Token 结束
                                    end else begin
                                        temp_token[temp_len*8 +: 8] = line_buffer[i];
                                        temp_len = temp_len + 1'b1;
                                    end
                                end

                                indent_chg = check_indent_change(temp_token, temp_len);

                                if (indent_chg[1]) begin  // 减少缩进
                                    if (indent_level > 0) begin
                                        indent_level <= indent_level - 1'b1;
                                    end
                                end
                                if (indent_chg[0]) begin  // 增加缩进
                                    next_indent <= indent_level + 1'b1;
                                end
                            end

                            indent_level <= next_indent;

                            line_state <= LINE_END;
                        end

                        LINE_END: begin
                            state <= WRITE_OUTPUT;
                            line_state <= LINE_START;
                        end
                    endcase
                end

                WRITE_OUTPUT: begin
                    if (out_len > 0) begin
                        dst_wr_en   <= 1'b1;
                        dst_wr_addr <= dst_ptr[11:0];
                        dst_wr_data <= out_buffer[0];
                        dst_ptr     <= dst_ptr + 1'b1;

                        // 移位输出缓冲区
                        for (i = 0; i < MAX_LINE_LEN - 1; i = i + 1) begin
                            out_buffer[i] <= out_buffer[i + 1];
                        end
                        out_len <= out_len - 1'b1;
                    end else begin
                        // 清空行缓冲区
                        line_len <= 9'd0;
                        for (i = 0; i < MAX_LINE_LEN; i = i + 1) begin
                            line_buffer[i] <= 8'd0;
                        end
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
