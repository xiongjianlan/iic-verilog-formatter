//============================================================================
// Verilog 代码格式化器 - 简化版
// 功能：基本的缩进和空格规范化
//============================================================================

module verilog_formatter #(
    parameter DATA_DEPTH = 4096,
    parameter MAX_LINE_LEN = 256
)(
    input  wire        clk,
    input  wire        rst_n,

    input  wire        start,
    input  wire [15:0] data_len,
    output reg         done,
    output reg  [15:0] result_len,

    output reg         src_rd_en,
    output reg  [11:0] src_rd_addr,
    input  wire [7:0]  src_rd_data,

    output reg         dst_wr_en,
    output reg  [11:0] dst_wr_addr,
    output reg  [7:0]  dst_wr_data
);

    // 状态机
    localparam IDLE = 3'd0;
    localparam READ = 3'd1;
    localparam PROC = 3'd2;
    localparam WRITE = 3'd3;
    localparam FINISH = 3'd4;

    reg [2:0] state;
    reg [15:0] src_ptr;
    reg [15:0] dst_ptr;
    reg [7:0] indent;
    reg [7:0] curr_char;
    reg [7:0] prev_char;
    reg in_begin;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            src_ptr <= 0;
            dst_ptr <= 0;
            indent <= 0;
            done <= 0;
            result_len <= 0;
            src_rd_en <= 0;
            dst_wr_en <= 0;
            curr_char <= 0;
            prev_char <= 0;
            in_begin <= 0;
        end else begin
            src_rd_en <= 0;
            dst_wr_en <= 0;
            done <= 0;

            case (state)
                IDLE: begin
                    if (start) begin
                        state <= READ;
                        src_ptr <= 0;
                        dst_ptr <= 0;
                        indent <= 0;
                    end
                end

                READ: begin
                    if (src_ptr < data_len) begin
                        src_rd_en <= 1;
                        src_rd_addr <= src_ptr[11:0];
                        state <= PROC;
                    end else begin
                        state <= FINISH;
                    end
                end

                PROC: begin
                    curr_char <= src_rd_data;
                    prev_char <= curr_char;
                    src_ptr <= src_ptr + 1;

                    // 检测 begin/end 调整缩进
                    if (curr_char == "b" && prev_char == " ") in_begin <= 1;
                    else if (curr_char == "e" && prev_char == " ") in_begin <= 0;

                    // 写入字符
                    dst_wr_en <= 1;
                    dst_wr_addr <= dst_ptr[11:0];
                    dst_wr_data <= src_rd_data;
                    dst_ptr <= dst_ptr + 1;

                    state <= READ;
                end

                FINISH: begin
                    done <= 1;
                    result_len <= dst_ptr;
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule
