module dct_block_loader #(
    parameter int DATA_WIDTH = 8
) (
    input  logic                      clk,
    input  logic                      rst_n,

    // axi-stream in
    input  logic [DATA_WIDTH-1:0]     s_tdata,
    input  logic                      s_tvalid,
    output logic                      s_tready,
    input  logic                      s_tlast,

    // block buffer write port
    output logic                      buf_wr_en,
    output logic [5:0]                buf_wr_addr,
    output logic signed [DATA_WIDTH:0] buf_wr_data,
    output logic                      block_ready   // 1-cycle pulse
);

    logic [5:0] pixel_cnt;
    logic       busy;

    // always ready to accept — loader never stalls upstream
    assign s_tready = 1'b1;

    // level shift: subtract 128 to center around zero
    assign buf_wr_data = signed'({1'b0, s_tdata}) - signed'(9'd128);
    assign buf_wr_en   = s_tvalid;
    assign buf_wr_addr = pixel_cnt;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pixel_cnt   <= '0;
            block_ready <= '0;
        end else begin
            block_ready <= '0;

            if (s_tvalid) begin
                if (pixel_cnt == 6'd63) begin
                    pixel_cnt   <= '0;
                    block_ready <= 1'b1;
                end else begin
                    pixel_cnt <= pixel_cnt + 1;
                end
            end
        end
    end

endmodule