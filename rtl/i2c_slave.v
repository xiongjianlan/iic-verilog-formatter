//============================================================================
// I2C Slave 模块 - 修复版
// 修复内容：
//   1. ACK 在 SCL 第9个周期正确输出
//   2. 地址匹配严格检查
//   3. 状态机优化
//============================================================================

module i2c_slave #(
    parameter DATA_DEPTH = 4096,
    parameter I2C_ADDR   = 7'h50
)(
    input  wire        clk,
    input  wire        rst_n,

    inout  wire        sda,
    input  wire        scl,

    output reg         fmt_start,
    output reg  [15:0] fmt_data_len,
    input  wire        fmt_done,
    input  wire [15:0] fmt_result_len,

    output reg         ram_wr_en,
    output reg  [11:0] ram_wr_addr,
    output reg  [7:0]  ram_wr_data,
    output reg         ram_rd_en,
    output reg  [11:0] ram_rd_addr,
    input  wire [7:0]  ram_rd_data
);

    //========================================================================
    // I2C 信号同步
    //========================================================================
    reg [2:0] scl_sync, sda_sync;
    reg scl_stable, sda_stable;
    reg scl_prev, sda_prev;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            scl_sync <= 3'b111;
            sda_sync <= 3'b111;
        end else begin
            scl_sync <= {scl_sync[1:0], scl};
            sda_sync <= {sda_sync[1:0], sda};
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            scl_stable <= 1'b1;
            sda_stable <= 1'b1;
        end else begin
            if (scl_sync[2] == scl_sync[1] && scl_sync[1] == scl_sync[0])
                scl_stable <= scl_sync[0];
            if (sda_sync[2] == sda_sync[1] && sda_sync[1] == sda_sync[0])
                sda_stable <= sda_sync[0];
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            scl_prev <= 1'b1;
            sda_prev <= 1'b1;
        end else begin
            scl_prev <= scl_stable;
            sda_prev <= sda_stable;
        end
    end

    wire scl_rising  = scl_stable && !scl_prev;
    wire scl_falling = !scl_stable && scl_prev;
    wire start_cond  = scl_stable && !sda_stable && scl_prev && sda_prev;
    wire stop_cond   = scl_stable && sda_stable && scl_prev && !sda_prev;

    //========================================================================
    // SDA 控制
    //========================================================================
    reg sda_out_en;
    reg sda_out;
    assign sda = sda_out_en ? sda_out : 1'bz;

    //========================================================================
    // 状态机
    //========================================================================
    localparam IDLE           = 4'd0;
    localparam RX_ADDR        = 4'd1;
    localparam TX_ADDR_ACK    = 4'd2;
    localparam RX_DATA        = 4'd3;
    localparam TX_DATA_ACK    = 4'd4;
    localparam TX_DATA        = 4'd5;
    localparam RX_DATA_ACK    = 4'd6;
    localparam WAIT_FMT       = 4'd7;
    localparam TX_LEN_HIGH    = 4'd8;
    localparam TX_LEN_LOW     = 4'd9;

    reg [3:0]  state;
    reg [3:0]  bit_cnt;
    reg [7:0]  shift_reg;
    reg        addr_match;
    reg        rw_bit;

    reg [15:0] rx_byte_cnt;
    reg [15:0] tx_byte_cnt;
    reg        fmt_active;

    //========================================================================
    // 主状态机
    //========================================================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state        <= IDLE;
            bit_cnt      <= 4'd7;
            shift_reg    <= 8'd0;
            addr_match   <= 1'b0;
            rw_bit       <= 1'b0;
            sda_out_en   <= 1'b0;
            sda_out      <= 1'b1;

            rx_byte_cnt  <= 16'd0;
            tx_byte_cnt  <= 16'd0;

            ram_wr_en    <= 1'b0;
            ram_wr_addr  <= 12'd0;
            ram_wr_data  <= 8'd0;
            ram_rd_en    <= 1'b0;
            ram_rd_addr  <= 12'd0;

            fmt_start    <= 1'b0;
            fmt_data_len <= 16'd0;
            fmt_active   <= 1'b0;
        end else begin
            ram_wr_en <= 1'b0;
            ram_rd_en <= 1'b0;
            fmt_start <= 1'b0;

            case (state)
                IDLE: begin
                    sda_out_en <= 1'b0;
                    sda_out    <= 1'b1;
                    bit_cnt    <= 4'd7;

                    if (start_cond) begin
                        state <= RX_ADDR;
                    end
                end

                RX_ADDR: begin
                    if (scl_rising) begin
                        shift_reg <= {shift_reg[6:0], sda_stable};

                        if (bit_cnt == 4'd0) begin
                            // 检查地址
                            if (shift_reg[7:1] == I2C_ADDR) begin
                                addr_match <= 1'b1;
                                rw_bit     <= shift_reg[0];
                                sda_out_en <= 1'b1;
                                sda_out    <= 1'b0;  // ACK
                                state      <= TX_ADDR_ACK;
                            end else begin
                                addr_match <= 1'b0;
                                state      <= IDLE;
                            end
                        end else begin
                            bit_cnt <= bit_cnt - 1'b1;
                        end
                    end
                end

                TX_ADDR_ACK: begin
                    // 等待 SCL 下降沿后释放 SDA
                    if (scl_falling) begin
                        sda_out_en <= 1'b0;
                        bit_cnt    <= 4'd7;

                        if (rw_bit) begin
                            // 读操作
                            if (!fmt_active && rx_byte_cnt > 0) begin
                                // 触发格式化
                                fmt_start    <= 1'b1;
                                fmt_data_len <= rx_byte_cnt;
                                fmt_active   <= 1'b1;
                                state        <= WAIT_FMT;
                            end else if (fmt_done) begin
                                // 格式化完成，发送结果
                                tx_byte_cnt <= 16'd0;
                                state       <= TX_LEN_HIGH;
                            end else begin
                                // 等待格式化
                                state <= WAIT_FMT;
                            end
                        end else begin
                            // 写操作
                            state <= RX_DATA;
                        end
                    end
                end

                RX_DATA: begin
                    if (scl_rising) begin
                        shift_reg <= {shift_reg[6:0], sda_stable};

                        if (bit_cnt == 4'd0) begin
                            // 写入 RAM
                            ram_wr_en   <= 1'b1;
                            ram_wr_addr <= rx_byte_cnt[11:0];
                            ram_wr_data <= shift_reg;
                            rx_byte_cnt <= rx_byte_cnt + 1'b1;

                            // 发送 ACK
                            sda_out_en <= 1'b1;
                            sda_out    <= 1'b0;
                            state      <= TX_DATA_ACK;
                        end else begin
                            bit_cnt <= bit_cnt - 1'b1;
                        end
                    end

                    if (stop_cond) begin
                        state <= IDLE;
                    end
                end

                TX_DATA_ACK: begin
                    if (scl_falling) begin
                        sda_out_en <= 1'b0;
                        bit_cnt    <= 4'd7;
                        state      <= RX_DATA;
                    end

                    if (stop_cond) begin
                        state <= IDLE;
                    end
                end

                WAIT_FMT: begin
                    if (fmt_done) begin
                        fmt_active  <= 1'b0;
                        tx_byte_cnt <= 16'd0;
                        state       <= TX_LEN_HIGH;
                    end
                end

                TX_LEN_HIGH: begin
                    // 发送长度高字节
                    ram_rd_en   <= 1'b1;
                    ram_rd_addr <= 12'd0;  // 长度存储在 RAM 开头

                    if (scl_falling) begin
                        if (bit_cnt == 4'd7)
                            shift_reg <= fmt_result_len[15:8];
                        else
                            shift_reg <= {shift_reg[6:0], 1'b0};

                        sda_out_en <= 1'b1;
                        sda_out    <= shift_reg[7];

                        if (bit_cnt == 4'd0) begin
                            state   <= TX_LEN_LOW;
                            bit_cnt <= 4'd7;
                        end else begin
                            bit_cnt <= bit_cnt - 1'b1;
                        end
                    end
                end

                TX_LEN_LOW: begin
                    if (scl_falling) begin
                        if (bit_cnt == 4'd7)
                            shift_reg <= fmt_result_len[7:0];
                        else
                            shift_reg <= {shift_reg[6:0], 1'b0};

                        sda_out_en <= 1'b1;
                        sda_out    <= shift_reg[7];

                        if (bit_cnt == 4'd0) begin
                            state   <= TX_DATA;
                            bit_cnt <= 4'd7;
                        end else begin
                            bit_cnt <= bit_cnt - 1'b1;
                        end
                    end
                end

                TX_DATA: begin
                    if (tx_byte_cnt >= fmt_result_len) begin
                        state <= IDLE;
                    end else begin
                        ram_rd_en   <= 1'b1;
                        ram_rd_addr <= tx_byte_cnt[11:0];

                        if (scl_falling) begin
                            if (bit_cnt == 4'd7)
                                shift_reg <= ram_rd_data;
                            else
                                shift_reg <= {shift_reg[6:0], 1'b0};

                            sda_out_en <= 1'b1;
                            sda_out    <= shift_reg[7];

                            if (bit_cnt == 4'd0) begin
                                state   <= RX_DATA_ACK;
                                bit_cnt <= 4'd7;
                            end else begin
                                bit_cnt <= bit_cnt - 1'b1;
                            end
                        end
                    end
                end

                RX_DATA_ACK: begin
                    sda_out_en <= 1'b0;
                    if (scl_rising) begin
                        if (!sda_stable) begin  // ACK
                            tx_byte_cnt <= tx_byte_cnt + 1'b1;
                            state       <= TX_DATA;
                        end else begin  // NACK
                            state <= IDLE;
                        end
                    end
                end

                default: state <= IDLE;
            endcase

            if (stop_cond && state != IDLE)
                state <= IDLE;
        end
    end

endmodule
