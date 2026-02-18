module dct_top #(
    parameter DATA_WIDTH  = 8,
    parameter COEFF_WIDTH = 12  // 11 bits + sign is typical post-quantization
) (
    input  logic                      clk,
    input  logic                      rst_n,

    // axi-stream slave (pixel in)
    input  logic [DATA_WIDTH-1:0]     s_tdata,
    input  logic                      s_tvalid,
    output logic                      s_tready,
    input  logic                      s_tlast,   // end of image row

    // axi-stream master (quantized dct coefficients out)
    output logic signed [COEFF_WIDTH-1:0] m_tdata,
    output logic                      m_tvalid,
    input  logic                      m_tready,
    output logic                      m_tlast    // end of 8x8 block
);

    // -------------------------------------------------------
    // internal signals
    // -------------------------------------------------------

    // block buffer control
    logic        buf_wr_en;
    logic [5:0]  buf_wr_addr;
    logic [5:0]  buf_rd_addr;
    logic signed [DATA_WIDTH:0] buf_wr_data;   // level shifted

    // row dct engine
    logic        row_dct_start;
    logic        row_dct_done;
    logic [2:0]  row_dct_row_sel;
    logic signed [23:0] row_dct_out [0:7];    // wide intermediate

    // transpose buffer (ping-pong)
    logic        transpose_wr_sel;            // which bank is being written
    logic [5:0]  transpose_wr_addr;
    logic [5:0]  transpose_rd_addr;

    // col dct engine
    logic        col_dct_start;
    logic        col_dct_done;
    logic [2:0]  col_dct_col_sel;
    logic signed [23:0] col_dct_out [0:7];

    // quantizer
    logic        quant_valid_in;
    logic        quant_valid_out;
    logic [2:0]  quant_row, quant_col;
    logic signed [23:0] quant_data_in;
    logic signed [COEFF_WIDTH-1:0] quant_data_out;

    // -------------------------------------------------------
    // submodules
    // -------------------------------------------------------

    // load/level-shift + write into pixel block buffer
    dct_block_loader #(
        .DATA_WIDTH(DATA_WIDTH)
    ) u_loader (
        .clk        (clk),
        .rst_n      (rst_n),
        .s_tdata    (s_tdata),
        .s_tvalid   (s_tvalid),
        .s_tready   (s_tready),
        .s_tlast    (s_tlast),
        .buf_wr_en  (buf_wr_en),
        .buf_wr_addr(buf_wr_addr),
        .buf_wr_data(buf_wr_data),  // already level-shifted
        .block_ready(row_dct_start) // pulses when 8x8 block is full
    );

    // 1d row-wise dct using aan butterfly (12 muls, 32 adds per row)
    // processes one row per ~12 pipeline stages, 8 rows back-to-back
    dct_1d_aan u_row_dct (
        .clk        (clk),
        .rst_n      (rst_n),
        .start      (row_dct_start),
        .row_sel    (row_dct_row_sel),
        .data_in    (/* slice of block buffer */),
        .data_out   (row_dct_out),
        .done       (row_dct_done)
    );

    // transpose buffer: written by row dct, read by col dct
    // implemented as dual-port bram with address swizzle for transpose
    // write: [row][col], read: [col][row] -> natural transpose
    dct_transpose_buf u_transpose (
        .clk        (clk),
        .wr_en      (row_dct_done),
        .wr_addr    (transpose_wr_addr),   // {row_idx, col_idx}
        .wr_data    (row_dct_out),
        .rd_addr    (transpose_rd_addr),   // {col_idx, row_idx} swapped
        .rd_data    (/* feeds col dct */)
    );

    // 1d col-wise dct (same aan core, reused or duplicated)
    dct_1d_aan u_col_dct (
        .clk        (clk),
        .rst_n      (rst_n),
        .start      (col_dct_start),
        .row_sel    (col_dct_col_sel),
        .data_in    (/* slice of transpose buf */),
        .data_out   (col_dct_out),
        .done       (col_dct_done)
    );

    // jpeg quantization table lookup + divide
    // Q(u,v) = round(DCT(u,v) / qtable[u][v])
    dct_quantizer #(
        .IN_WIDTH   (24),
        .OUT_WIDTH  (COEFF_WIDTH)
    ) u_quantizer (
        .clk        (clk),
        .rst_n      (rst_n),
        .valid_in   (quant_valid_in),
        .row        (quant_row),
        .col        (quant_col),
        .data_in    (quant_data_in),
        .valid_out  (quant_valid_out),
        .data_out   (quant_data_out)
    );

    // output packetizer: serializes 8x8 quantized coefficients
    // zig-zag reorder happens here (optional, matches jpeg entropy coding order)
    dct_output_pack #(
        .DATA_WIDTH(COEFF_WIDTH)
    ) u_output (
        .clk        (clk),
        .rst_n      (rst_n),
        .valid_in   (quant_valid_out),
        .data_in    (quant_data_out),
        .m_tdata    (m_tdata),
        .m_tvalid   (m_tvalid),
        .m_tready   (m_tready),
        .m_tlast    (m_tlast)
    );

endmodule