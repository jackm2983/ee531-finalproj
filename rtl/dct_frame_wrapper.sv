/*
TESTING: 
1. generate golden coeff stream for a known image in Python

2. save expected outputs to expected.mem

3. TB reads the image pixels from pixels.mem

4. TB captures DUT outputs and compares to expected.mem

5. randomize m_tready and s_tvalid to stress backpressure

*/



module dct_frame_wrapper #(
    parameter int DATA_WIDTH  = 8,
    parameter int COEFF_WIDTH = 12,
    parameter int INT_WIDTH   = 24,
    parameter int FIFO_DEPTH  = 256,

    parameter int IMG_W = 128,
    parameter int IMG_H = 128
) (
    input  logic                        clk,
    input  logic                        rst_n,

    // frame pixel stream in (raster order)
    input  logic [DATA_WIDTH-1:0]       s_tdata,
    input  logic                        s_tvalid,
    output logic                        s_tready,
    input  logic                        s_tlast,   // end-of-frame from upstream

    // frame coeff stream out (block after block)
    output logic signed [COEFF_WIDTH-1:0] m_tdata,
    output logic                        m_tvalid,
    input  logic                        m_tready,
    output logic                        m_tlast,   // end-of-frame to downstream

    output logic                        busy
);

    localparam int BLOCK_PIXELS   = 64;
    localparam int BLOCKS_TOTAL   = (IMG_W * IMG_H) / BLOCK_PIXELS;

    // core-side streams (block semantics)
    logic [DATA_WIDTH-1:0]          core_s_tdata;
    logic                           core_s_tvalid;
    logic                           core_s_tready;
    logic                           core_s_tlast;   // end-of-block into core

    logic signed [COEFF_WIDTH-1:0]  core_m_tdata;
    logic                           core_m_tvalid;
    logic                           core_m_tready;
    logic                           core_m_tlast;   // end-of-block from core
    logic                           core_busy;

    // counters
    logic [6:0] pix_in_block;     // 0..63
    int unsigned block_idx_in;    // blocks accepted (by pixels)
    int unsigned block_idx_out;   // blocks completed (by coeff tlast)
    logic frame_done_in;
    logic frame_done_out;

    // handshakes
    logic in_fire;
    logic out_fire;

    assign in_fire  = s_tvalid && s_tready;
    assign out_fire = core_m_tvalid && core_m_tready;

    // input -> core gating
    assign core_s_tdata  = s_tdata;
    assign core_s_tvalid = s_tvalid && !frame_done_in;

    // only accept input when core can accept
    assign s_tready      = core_s_tready && !frame_done_in;

    // generate end-of-block into core every 64 accepted pixels
    always_comb begin
        core_s_tlast = 1'b0;
        if (in_fire && (pix_in_block == 7'd63))
            core_s_tlast = 1'b1;
    end

    // track input block progress
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pix_in_block   <= 7'd0;
            block_idx_in   <= 0;
            frame_done_in  <= 1'b0;
        end else begin
            if (in_fire) begin
                if (pix_in_block == 7'd63) begin
                    pix_in_block <= 7'd0;
                    if (block_idx_in + 1 >= BLOCKS_TOTAL)
                        frame_done_in <= 1'b1;
                    block_idx_in <= block_idx_in + 1;
                end else begin
                    pix_in_block <= pix_in_block + 1;
                end
            end

            // optional: sanity check that upstream frame tlast aligns
            // if desired, you can assert (s_tlast) only on final pixel,
            // but this wrapper does not depend on it.
        end
    end

    // core output -> wrapper output
    assign m_tdata  = core_m_tdata;
    assign m_tvalid = core_m_tvalid;
    assign core_m_tready = m_tready;

    // generate end-of-frame on the last coeff of the last block
    always_comb begin
        m_tlast = 1'b0;
        if (core_m_tvalid && m_tready && core_m_tlast && (block_idx_out + 1 >= BLOCKS_TOTAL))
            m_tlast = 1'b1;
    end

    // track output blocks completed
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            block_idx_out  <= 0;
            frame_done_out <= 1'b0;
        end else begin
            if (out_fire && core_m_tlast) begin
                if (block_idx_out + 1 >= BLOCKS_TOTAL)
                    frame_done_out <= 1'b1;
                block_idx_out <= block_idx_out + 1;
            end
        end
    end

    // busy when core is busy or we haven't finished both sides
    always_comb begin
        busy = core_busy || !frame_done_out || !frame_done_in;
    end

    // instantiate your existing block engine
    dct_top #(
        .DATA_WIDTH  (DATA_WIDTH),
        .COEFF_WIDTH (COEFF_WIDTH),
        .INT_WIDTH   (INT_WIDTH),
        .FIFO_DEPTH  (FIFO_DEPTH)
    ) u_core (
        .clk      (clk),
        .rst_n    (rst_n),

        .s_tdata  (core_s_tdata),
        .s_tvalid (core_s_tvalid),
        .s_tready (core_s_tready),
        .s_tlast  (core_s_tlast),

        .m_tdata  (core_m_tdata),
        .m_tvalid (core_m_tvalid),
        .m_tready (core_m_tready),
        .m_tlast  (core_m_tlast),

        .busy     (core_busy)
    );

endmodule