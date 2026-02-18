module dct_block_buf #(
    parameter int DATA_WIDTH = 9   // passed in as DATA_WIDTH+1 from top
) (
    input  logic                       clk,
    input  logic                       rst_n,

    // write port (from loader)
    input  logic                       wr_en,
    input  logic [5:0]                 wr_addr,
    input  logic signed [DATA_WIDTH-1:0] wr_data,

    // row vector read port (from ctrl)
    input  logic                       rd_en,
    input  logic [2:0]                 rd_row_sel,
    output logic signed [DATA_WIDTH-1:0] rd_row_vec [0:7]
);

    // 64-entry register file — 8 rows × 8 cols
    logic signed [DATA_WIDTH-1:0] mem [0:63];

    // write
    always_ff @(posedge clk) begin
        if (wr_en)
            mem[wr_addr] <= wr_data;
    end

    // read: combinational row extraction so ctrl sees data same cycle rd_en asserted
    // row r -> addresses {r,0}.{r,7} = r*8 + col
    always_comb begin
        if (rd_en) begin
            for (int col = 0; col < 8; col++)
                rd_row_vec[col] = mem[{rd_row_sel, 3'(col)}];
        end else begin
            for (int col = 0; col < 8; col++)
                rd_row_vec[col] = '0;
        end
    end

endmodule