module dct_top #(
    parameter int DATA_WIDTH  = 8,
    parameter int COEFF_WIDTH = 12,
    parameter int INT_WIDTH   = 24,
    parameter int FIFO_DEPTH  = 256   // >= 64 coeffs, more is safer
) (
    input  logic                       clk,
    input  logic                       rst_n,

    // axi-stream slave (pixels in)
    input  logic [DATA_WIDTH-1:0]      s_tdata,
    input  logic                       s_tvalid,
    output logic                       s_tready,
    input  logic                       s_tlast,

    // axi-stream master (quantized coeffs out)
    output logic signed [COEFF_WIDTH-1:0] m_tdata,
    output logic                       m_tvalid,
    input  logic                       m_tready,
    output logic                       m_tlast
);

    // -------------------------------------------------------
    // stage interfaces (high-level)
    // -------------------------------------------------------

    // loader -> block buffer
    logic                        blk_wr_en;
    logic [5:0]                  blk_wr_addr;
    logic signed [DATA_WIDTH:0]  blk_wr_data;
    logic                        blk_full;        // 1-cycle pulse when 8x8 ready

    // ctrl -> block buffer read (row vectors)
    logic [2:0]                  row_sel;
    logic                        blk_rd_en;
    logic signed [DATA_WIDTH:0]  blk_row_vec [0:7]; // 8 samples for selected row

    // row dct -> transpose buffer
    logic                        row_dct_start;
    logic                        row_dct_done;
    logic signed [INT_WIDTH-1:0] row_dct_vec [0:7];

    logic                        t_wr_en;
    logic [2:0]                  t_wr_row;
    logic signed [INT_WIDTH-1:0] t_wr_vec [0:7];

    // ctrl -> transpose read (col vectors)
    logic                        t_rd_en;
    logic [2:0]                  col_sel;
    logic signed [INT_WIDTH-1:0] t_col_vec [0:7];

    // col dct -> coeff stream (pre-quant)
    logic                        col_dct_start;
    logic                        col_dct_done;
    logic signed [INT_WIDTH-1:0] col_dct_vec [0:7];

    // vector->stream (64 coeffs per block, optional zigzag here or later)
    logic                        cstrm_valid;
    logic                        cstrm_ready;
    logic signed [INT_WIDTH-1:0] cstrm_data;
    logic [2:0]                  cstrm_u;
    logic [2:0]                  cstrm_v;
    logic                        cstrm_last;      // last coeff of block

    // quantizer output stream
    logic                        q_valid;
    logic                        q_ready;
    logic signed [COEFF_WIDTH-1:0] q_data;
    logic                        q_last;

    // fifo -> output pack
    logic                        f_valid;
    logic                        f_ready;
    logic signed [COEFF_WIDTH-1:0] f_data;
    logic                        f_last;

    // -------------------------------------------------------
    // loader: axi-stream pixels -> level-shifted block writes
    // -------------------------------------------------------
    dct_block_loader #(
        .DATA_WIDTH(DATA_WIDTH)
    ) u_loader (
        .clk         (clk),
        .rst_n       (rst_n),
        .s_tdata     (s_tdata),
        .s_tvalid    (s_tvalid),
        .s_tready    (s_tready),
        .s_tlast     (s_tlast),

        .buf_wr_en   (blk_wr_en),
        .buf_wr_addr (blk_wr_addr),
        .buf_wr_data (blk_wr_data),
        .block_ready (blk_full)
    );

    // -------------------------------------------------------
    // block buffer: 64 samples, row-vector read
    // (implementation can be regs or bram; wrapper just defines interface)
    // -------------------------------------------------------
    dct_block_buf #(
        .DATA_WIDTH(DATA_WIDTH+1)
    ) u_block_buf (
        .clk        (clk),
        .rst_n      (rst_n),

        .wr_en      (blk_wr_en),
        .wr_addr    (blk_wr_addr),
        .wr_data    (blk_wr_data),

        .rd_en      (blk_rd_en),
        .rd_row_sel (row_sel),
        .rd_row_vec (blk_row_vec)
    );

    // -------------------------------------------------------
    // controller: sequences row dct, transpose, col dct, and coefficient streaming
    // also gates compute based on downstream readiness (via cstrm_ready / q_ready)
    // -------------------------------------------------------
    dct_ctrl u_ctrl (
        .clk           (clk),
        .rst_n         (rst_n),

        .block_full    (blk_full),

        // block buffer row selection / read enable
        .blk_rd_en     (blk_rd_en),
        .row_sel       (row_sel),

        // row dct control
        .row_dct_start (row_dct_start),
        .row_dct_done  (row_dct_done),

        // transpose control
        .t_wr_en       (t_wr_en),
        .t_wr_row      (t_wr_row),

        .t_rd_en       (t_rd_en),
        .col_sel       (col_sel),

        // col dct control
        .col_dct_start (col_dct_start),
        .col_dct_done  (col_dct_done),

        // coefficient stream backpressure
        .cstrm_ready   (cstrm_ready),
        .q_ready       (q_ready)
    );

    // -------------------------------------------------------
    // 1d row dct: vector in -> vector out
    // -------------------------------------------------------
    dct_1d_aan #(
        .IN_WIDTH  (DATA_WIDTH+1),
        .OUT_WIDTH (INT_WIDTH)
    ) u_row_dct (
        .clk      (clk),
        .rst_n    (rst_n),
        .start    (row_dct_start),
        .data_in  (blk_row_vec),
        .data_out (row_dct_vec),
        .done     (row_dct_done)
    );

    // -------------------------------------------------------
    // transpose buffer: row-vector write, col-vector read
    // ping-pong optional inside, wrapper just exposes vector ports
    // -------------------------------------------------------
    dct_transpose_buf #(
        .WIDTH(INT_WIDTH)
    ) u_transpose (
        .clk        (clk),
        .rst_n      (rst_n),

        .wr_en      (t_wr_en),
        .wr_row     (t_wr_row),
        .wr_vec     (row_dct_vec),

        .rd_en      (t_rd_en),
        .rd_col     (col_sel),
        .rd_vec     (t_col_vec)
    );

    // -------------------------------------------------------
    // 1d col dct: vector in -> vector out
    // -------------------------------------------------------
    dct_1d_aan #(
        .IN_WIDTH  (INT_WIDTH),
        .OUT_WIDTH (INT_WIDTH)
    ) u_col_dct (
        .clk      (clk),
        .rst_n    (rst_n),
        .start    (col_dct_start),
        .data_in  (t_col_vec),
        .data_out (col_dct_vec),
        .done     (col_dct_done)
    );

    // -------------------------------------------------------
    // vector->stream: turns 8-wide col_dct_vec into 8 beats (rows 0..7),
    // and across 8 columns produces 64 beats; optional zigzag mapping here.
    // must support valid/ready to propagate backpressure safely.
    // -------------------------------------------------------
    dct_coeff_stream u_coeff_stream (
        .clk        (clk),
        .rst_n      (rst_n),

        .vec_valid  (col_dct_done),
        .vec_data   (col_dct_vec),
        .col_sel    (col_sel),

        .m_valid    (cstrm_valid),
        .m_ready    (cstrm_ready),
        .m_data     (cstrm_data),
        .m_u        (cstrm_u),
        .m_v        (cstrm_v),
        .m_last     (cstrm_last)
    );

    // -------------------------------------------------------
    // quantizer: MUST be streaming valid/ready (or wrap it to be so)
    // -------------------------------------------------------
    dct_quantizer_stream #(
        .IN_WIDTH  (INT_WIDTH),
        .OUT_WIDTH (COEFF_WIDTH)
    ) u_quant (
        .clk      (clk),
        .rst_n    (rst_n),

        .s_valid  (cstrm_valid),
        .s_ready  (cstrm_ready),
        .s_u      (cstrm_u),
        .s_v      (cstrm_v),
        .s_data   (cstrm_data),
        .s_last   (cstrm_last),

        .m_valid  (q_valid),
        .m_ready  (q_ready),
        .m_data   (q_data),
        .m_last   (q_last)
    );

    // -------------------------------------------------------
    // fifo: decouples compute from output m_tready stalls
    // (depth >= 64 coeffs per block)
    // -------------------------------------------------------
    axis_fifo #(
        .WIDTH (COEFF_WIDTH),
        .DEPTH (FIFO_DEPTH),
        .HAS_LAST(1)
    ) u_fifo (
        .clk     (clk),
        .rst_n   (rst_n),

        .s_valid (q_valid),
        .s_ready (q_ready),
        .s_data  (q_data),
        .s_last  (q_last),

        .m_valid (f_valid),
        .m_ready (f_ready),
        .m_data  (f_data),
        .m_last  (f_last)
    );

    // -------------------------------------------------------
    // output pack: maps fifo stream to axi-stream master
    // if zigzag not done earlier, do it here (but then needs buffering)
    // -------------------------------------------------------
    dct_output_pack #(
        .DATA_WIDTH(COEFF_WIDTH)
    ) u_output (
        .clk      (clk),
        .rst_n    (rst_n),

        .valid_in (f_valid),
        .data_in  (f_data),
        .last_in  (f_last),

        .m_tdata  (m_tdata),
        .m_tvalid (m_tvalid),
        .m_tready (m_tready),
        .m_tlast  (m_tlast)
    );

    assign f_ready = m_tready;

endmodule
