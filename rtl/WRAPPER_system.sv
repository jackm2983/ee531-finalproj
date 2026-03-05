// WRAPPER_system.sv
module WRAPPER_system(
    input logic clk,
    input logic rst_n
);

    logic        axis_tvalid;
    logic        axis_tready;
    logic [63:0] axis_tdata;

    // memory input module
    // memory read (a huge list of stock data) and send over AXI stream
    mem_input mem_input_inst (
        .clk(clk),
        .rst_n(rst_n),
        .m_axis_tvalid(axis_tvalid),
        .m_axis_tready(axis_tready),
        .m_axis_tdata(axis_tdata)
    );

    // trade engine
    // has the AXI interface to the memory module
    // the output is just the output of the arbiter saying the ticker and whether to buy or sell
    WRAPPER_trade_engine trade_engine_inst (
        .clk(clk),
        .rst_n(rst_n),
        .s_axis_tvalid(axis_tvalid),
        .s_axis_tready(axis_tready),
        .s_axis_tdata(axis_tdata),
        .m_axis_tvalid(),
        .m_axis_tready(1'b1),
        .m_axis_tdata()
    );

endmodule